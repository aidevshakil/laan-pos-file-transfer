import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../../core/errors/transfer_exception.dart';
import '../../../core/services/app_navigation.dart';
import '../../../core/services/background_transfer_service.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/utils/notification_service.dart';
import '../../../data/datasources/local_storage.dart';
import '../../../domain/entities/transfer_task.dart';
import '../../../domain/repositories/transfer_repository.dart';
import 'transfer_event.dart';
import 'transfer_state.dart';

class TransferBloc extends Bloc<TransferEvent, TransferState> {
  final TransferRepository transferRepository;
  final NotificationService notificationService;
  final BackgroundTransferService backgroundService;
  final LocalStorage? storage;

  final Duration retryBaseDelay;

  static const int maxConcurrent = 2;
  static const int maxAutoRetries = 5;
  static const Duration _uiThrottle = Duration(milliseconds: 250);
  static const Duration _notificationThrottle = Duration(seconds: 1);

  final Uuid _uuid = const Uuid();
  int _runCounter = 0;

  final Map<String, int> _activeRuns = {};
  final Map<String, Timer> _retryTimers = {};
  final Map<String, _ProgressSampler> _samplers = {};
  Timer? _persistDebounce;

  TransferBloc({
    required this.transferRepository,
    required this.notificationService,
    required this.backgroundService,
    this.storage,
    this.retryBaseDelay = const Duration(seconds: 2),
  }) : super(const TransferState()) {
    on<RestoreTransfers>(_onRestore);
    on<LoadRemoteFiles>(_onLoadRemoteFiles);
    on<StartUploadEvent>(_onStartUpload);
    on<StartDownloadEvent>(_onStartDownload);
    on<PauseTransferEvent>(_onPause);
    on<ResumeTransferEvent>((e, emit) => _requeue(e.taskId, emit, resetRetries: false));
    on<RetryTransferEvent>((e, emit) => _requeue(e.taskId, emit, resetRetries: true));
    on<CancelTransferEvent>(_onCancel);
    on<PauseAllTransfers>(_onPauseAll);
    on<ResumeAllTransfers>(_onResumeAll);
    on<ClearFinishedTransfers>(_onClearFinished);
    on<DeleteRemoteFileEvent>(_onDeleteRemoteFile);
    on<TransferProgressed>(_onProgressed);
    on<TransferSucceeded>(_onSucceeded);
    on<TransferErrored>(_onErrored);
    on<AutoRetryFired>(_onAutoRetryFired);
  }

  @override
  void onChange(Change<TransferState> change) {
    super.onChange(change);
    if (!identical(change.currentState.tasks, change.nextState.tasks)) {
      _schedulePersist();
      final s = change.nextState;
      backgroundService.sync(
        activeCount: s.inFlightTasks.length,
        percent: (s.overallProgress * 100).floor(),
      );
    }
  }

  @override
  Future<void> close() async {
    for (final t in _retryTimers.values) {
      t.cancel();
    }
    _persistDebounce?.cancel();
    await storage?.saveTasks(state.tasks);
    return super.close();
  }

  void _schedulePersist() {
    if (storage == null) return;
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 800), () {
      storage!.saveTasks(state.tasks);
    });
  }

  Future<void> _onRestore(RestoreTransfers event, Emitter<TransferState> emit) async {
    final saved = storage?.loadTasks() ?? const <TransferTask>[];
    if (saved.isEmpty) return;
    final restored = <TransferTask>[];
    for (final t in saved) {
      if (t.isInFlight) {
        var bytes = 0;
        if (t.isDownload) {
          final part = File(t.partialPath);
          bytes = await part.exists() ? await part.length() : 0;
        }
        restored.add(t.copyWith(
          status: TransferStatus.paused,
          transferredBytes: bytes,
          speedBytesPerSec: 0,
          message: t.isUpload
              ? 'Interrupted when the app was closed. Resume to upload again.'
              : 'Interrupted when the app was closed. Resume to continue.',
        ));
      } else {
        restored.add(t);
      }
    }
    emit(state.copyWith(tasks: restored));
  }

  Future<void> _onLoadRemoteFiles(LoadRemoteFiles event, Emitter<TransferState> emit) async {
    emit(state.copyWith(isLoadingFiles: true, clearFilesError: true));
    try {
      final files = await transferRepository.getRemoteFiles();
      emit(state.copyWith(remoteFiles: files, isLoadingFiles: false, clearFilesError: true));
    } catch (e) {
      emit(state.copyWith(
        isLoadingFiles: false,
        filesError: TransferException.fromError(e).message,
      ));
    }
  }

  Future<void> _onDeleteRemoteFile(
      DeleteRemoteFileEvent event, Emitter<TransferState> emit) async {
    try {
      await transferRepository.deleteRemoteFile(event.fileName);
      emit(state.copyWith(
        remoteFiles: state.remoteFiles.where((f) => f.name != event.fileName).toList(),
        notice: '"${event.fileName}" deleted from the server.',
      ));
    } catch (e) {
      emit(state.copyWith(notice: 'Delete failed: ${TransferException.fromError(e).message}'));
    }
  }

  Future<void> _onStartUpload(StartUploadEvent event, Emitter<TransferState> emit) async {
    final task = TransferTask(
      id: _uuid.v4(),
      fileName: event.fileName,
      localFilePath: event.filePath,
      totalBytes: event.fileSize,
      type: TransferType.upload,
      status: TransferStatus.queued,
      createdAt: DateTime.now(),
    );
    emit(state.copyWith(tasks: [task, ...state.tasks]));
    _pump(emit);
  }

  Future<void> _onStartDownload(StartDownloadEvent event, Emitter<TransferState> emit) async {
    final remoteName = event.remoteFile.name;

    final existing = state.latestDownloadFor(remoteName);
    if (existing != null && existing.isActive) {
      if (existing.isPaused) _requeue(existing.id, emit, resetRetries: true);
      return;
    }

    final String savePath;
    try {
      final dir = await FileUtils.getDownloadDirectory();
      savePath = await FileUtils.uniqueFilePath(dir, FileUtils.safeFileName(remoteName));
    } catch (e) {
      emit(state.copyWith(notice: TransferException.fromError(e).message));
      return;
    }

    final task = TransferTask(
      id: _uuid.v4(),
      fileName: savePath.split(Platform.pathSeparator).last,
      localFilePath: savePath,
      totalBytes: event.remoteFile.size,
      type: TransferType.download,
      status: TransferStatus.queued,
      createdAt: DateTime.now(),
      remoteFileName: remoteName,
      remoteUrl: event.remoteFile.url,
    );
    emit(state.copyWith(tasks: [task, ...state.tasks]));
    _pump(emit);
  }

  void _pump(Emitter<TransferState> emit) {
    var running = state.tasks.where((t) => t.isRunning).length;
    if (running >= maxConcurrent) return;

    final queued = state.tasks.reversed.where((t) => t.isQueued).toList();
    final toStart = <String>{};
    for (final t in queued) {
      if (running >= maxConcurrent) break;
      toStart.add(t.id);
      running++;
    }
    if (toStart.isEmpty) return;

    emit(state.copyWith(
      tasks: _map((t) => toStart.contains(t.id)
          ? t.copyWith(status: TransferStatus.running, message: null, speedBytesPerSec: 0)
          : t),
    ));
    for (final id in toStart) {
      _startRun(_find(id)!);
    }
  }

  void _startRun(TransferTask task) {
    final runId = ++_runCounter;
    _activeRuns[task.id] = runId;
    final sampler = _samplers[task.id] = _ProgressSampler(task.transferredBytes);

    void onProgress(int done, int total) {
      if (_activeRuns[task.id] != runId || isClosed) return;
      final now = DateTime.now();
      final speed = sampler.sample(done, now);
      final isLast = total > 0 && done >= total;

      if (isLast || now.difference(sampler.lastUiEmit) >= _uiThrottle) {
        sampler.lastUiEmit = now;
        add(TransferProgressed(
          taskId: task.id,
          runId: runId,
          transferredBytes: done,
          totalBytes: total,
          speedBytesPerSec: speed,
        ));
      }
      if (isLast || now.difference(sampler.lastNotification) >= _notificationThrottle) {
        sampler.lastNotification = now;
        final pct = total > 0 ? (done * 100 ~/ total) : 0;
        notificationService.showProgress(
          taskId: task.id,
          title: '${task.isUpload ? 'Uploading' : 'Downloading'} ${task.fileName}',
          body: '$pct% • ${FileUtils.formatBytes(done)} of ${FileUtils.formatBytes(total)}'
              '${speed > 0 ? ' • ${FileUtils.formatSpeed(speed)}' : ''}',
          percent: pct,
          indeterminate: total <= 0,
          payload: AppNavigation.payloadFor(AppTab.transfers, task.id),
        );
      }
    }

    Future<void> work() async {
      try {
        if (task.isUpload) {
          final result = await transferRepository.uploadFile(
            taskId: task.id,
            filePath: task.localFilePath,
            fileName: task.fileName,
            onProgress: onProgress,
          );
          if (!isClosed) {
            add(TransferSucceeded(taskId: task.id, runId: runId, uploadResult: result));
          }
        } else {
          await transferRepository.downloadFile(
            taskId: task.id,
            remoteName: task.remoteFileName ?? task.fileName,
            partialPath: task.partialPath,
            onProgress: onProgress,
            url: task.remoteUrl,
          );
          await File(task.partialPath).rename(task.localFilePath);
          if (!isClosed) add(TransferSucceeded(taskId: task.id, runId: runId));
        }
      } catch (e) {
        if (!isClosed) {
          add(TransferErrored(taskId: task.id, runId: runId, error: TransferException.fromError(e)));
        }
      }
    }

    work();
  }

  void _onProgressed(TransferProgressed e, Emitter<TransferState> emit) {
    if (_activeRuns[e.taskId] != e.runId) return;
    emit(state.copyWith(
      tasks: _map((t) => t.id == e.taskId
          ? t.copyWith(
              transferredBytes: e.transferredBytes,
              totalBytes: e.totalBytes > 0 ? e.totalBytes : t.totalBytes,
              speedBytesPerSec: e.speedBytesPerSec,
            )
          : t),
    ));
  }

  void _onSucceeded(TransferSucceeded e, Emitter<TransferState> emit) {
    if (_activeRuns[e.taskId] != e.runId) return;
    _activeRuns.remove(e.taskId);
    _samplers.remove(e.taskId);

    final task = _find(e.taskId);
    if (task == null) return;
    final done = task.copyWith(
      status: TransferStatus.completed,
      transferredBytes: task.totalBytes > 0 ? task.totalBytes : task.transferredBytes,
      speedBytesPerSec: 0,
      completedAt: DateTime.now(),
      message: null,
      remoteFileName: e.uploadResult?.remoteName,
      remoteUrl: e.uploadResult?.url,
    );
    emit(state.copyWith(tasks: _map((t) => t.id == e.taskId ? done : t)));

    notificationService.showResult(
      taskId: done.id,
      title: done.isUpload ? 'Upload complete' : 'Download complete',
      body: done.isUpload
          ? '${done.fileName} (${FileUtils.formatBytes(done.totalBytes)}) is now on the server. Tap to view.'
          : '${done.fileName} saved to ${FileUtils.friendlyDirectory(done.localFilePath)}. Tap to open downloads.',
      payload: done.isUpload
          ? AppNavigation.payloadFor(AppTab.upload, done.id)
          : AppNavigation.downloadDonePayload(done.id),
    );

    if (done.isUpload) add(LoadRemoteFiles());
    _pump(emit);
  }

  void _onErrored(TransferErrored e, Emitter<TransferState> emit) {
    if (_activeRuns[e.taskId] != e.runId) return;
    _activeRuns.remove(e.taskId);
    final task = _find(e.taskId);
    if (task == null) return;
    final err = e.error;

    if (err.isCancelled) {
      emit(state.copyWith(tasks: _map((t) => t.id == e.taskId
          ? t.copyWith(status: TransferStatus.paused, speedBytesPerSec: 0)
          : t)));
    } else if (err.isRetryable && task.autoRetryCount < maxAutoRetries) {
      final attempt = task.autoRetryCount + 1;
      final delay = Duration(
        milliseconds: math.min(30000, retryBaseDelay.inMilliseconds << (attempt - 1)),
      );
      emit(state.copyWith(tasks: _map((t) => t.id == e.taskId
          ? t.copyWith(
              status: TransferStatus.retrying,
              autoRetryCount: attempt,
              speedBytesPerSec: 0,
              message: '${err.message} Retrying in ${delay.inSeconds}s '
                  '(attempt $attempt of $maxAutoRetries)…',
            )
          : t)));
      notificationService.showProgress(
        taskId: task.id,
        title: 'Waiting for network…',
        body: '${task.fileName}: retrying in ${delay.inSeconds}s',
        percent: task.percent,
        payload: AppNavigation.payloadFor(AppTab.transfers, task.id),
      );
      _retryTimers[e.taskId]?.cancel();
      _retryTimers[e.taskId] = Timer(delay, () {
        if (!isClosed) add(AutoRetryFired(taskId: e.taskId));
      });
    } else {
      final failed = task.copyWith(
        status: TransferStatus.failed,
        speedBytesPerSec: 0,
        message: err.message,
      );
      emit(state.copyWith(tasks: _map((t) => t.id == e.taskId ? failed : t)));
      notificationService.showResult(
        taskId: task.id,
        title: '${task.isUpload ? 'Upload' : 'Download'} failed',
        body: '${task.fileName}: ${err.message} Tap to retry.',
        payload: AppNavigation.payloadFor(AppTab.transfers, task.id),
      );
    }
    _pump(emit);
  }

  void _onAutoRetryFired(AutoRetryFired e, Emitter<TransferState> emit) {
    _retryTimers.remove(e.taskId);
    final task = _find(e.taskId);
    if (task == null || !task.isRetrying) return;
    emit(state.copyWith(tasks: _map((t) => t.id == e.taskId
        ? t.copyWith(status: TransferStatus.queued)
        : t)));
    _pump(emit);
  }

  void _stopEngineFor(String taskId) {
    _activeRuns.remove(taskId);
    _samplers.remove(taskId);
    _retryTimers.remove(taskId)?.cancel();
    transferRepository.abort(taskId);
  }

  void _onPause(PauseTransferEvent e, Emitter<TransferState> emit) {
    _pauseOne(e.taskId, emit);
    _pump(emit);
  }

  void _onPauseAll(PauseAllTransfers e, Emitter<TransferState> emit) {
    for (final t in state.inFlightTasks) {
      _pauseOne(t.id, emit);
    }
  }

  void _pauseOne(String taskId, Emitter<TransferState> emit) {
    final task = _find(taskId);
    if (task == null || !task.isInFlight) return;
    _stopEngineFor(taskId);
    emit(state.copyWith(tasks: _map((t) => t.id == taskId
        ? t.copyWith(
            status: TransferStatus.paused,
            speedBytesPerSec: 0,
            message: t.isUpload
                ? 'Paused. The server does not support partial uploads, so resuming restarts this upload.'
                : 'Paused. Resuming continues from ${FileUtils.formatBytes(t.transferredBytes)}.',
          )
        : t)));
    notificationService.cancelProgress(taskId);
  }

  void _onResumeAll(ResumeAllTransfers e, Emitter<TransferState> emit) {
    for (final t in state.tasks.where((t) => t.isPaused).toList()) {
      _requeue(t.id, emit, resetRetries: true);
    }
  }

  void _requeue(String taskId, Emitter<TransferState> emit, {required bool resetRetries}) {
    final task = _find(taskId);
    if (task == null || !(task.isPaused || task.isFailed || task.isRetrying)) return;
    _retryTimers.remove(taskId)?.cancel();
    notificationService.cancelAll(taskId);
    emit(state.copyWith(tasks: _map((t) => t.id == taskId
        ? t.copyWith(
            status: TransferStatus.queued,
            message: null,
            transferredBytes: t.isUpload ? 0 : t.transferredBytes,
            autoRetryCount: resetRetries ? 0 : t.autoRetryCount,
          )
        : t)));
    _pump(emit);
  }

  Future<void> _onCancel(CancelTransferEvent e, Emitter<TransferState> emit) async {
    final task = _find(e.taskId);
    if (task == null) return;
    _stopEngineFor(e.taskId);
    notificationService.cancelAll(e.taskId);
    emit(state.copyWith(tasks: state.tasks.where((t) => t.id != e.taskId).toList()));
    if (task.isDownload && !task.isCompleted) {
      try {
        final part = File(task.partialPath);
        if (await part.exists()) await part.delete();
      } catch (_) {}
    }
    _pump(emit);
  }

  void _onClearFinished(ClearFinishedTransfers e, Emitter<TransferState> emit) {
    for (final t in state.tasks.where((t) => t.isCompleted || t.isFailed)) {
      notificationService.cancelAll(t.id);
    }
    emit(state.copyWith(
      tasks: state.tasks.where((t) => !(t.isCompleted || t.isFailed)).toList(),
    ));
  }

  TransferTask? _find(String id) => state.tasks.where((t) => t.id == id).firstOrNull;

  List<TransferTask> _map(TransferTask Function(TransferTask) f) => state.tasks.map(f).toList();
}

class _ProgressSampler {
  int _windowBytes;
  DateTime _windowStart = DateTime.now();
  double _speed = 0;
  DateTime lastUiEmit = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime lastNotification = DateTime.fromMillisecondsSinceEpoch(0);

  _ProgressSampler(this._windowBytes);

  double sample(int bytes, DateTime now) {
    final elapsedMs = now.difference(_windowStart).inMilliseconds;
    if (elapsedMs >= 1000) {
      final instant = (bytes - _windowBytes) * 1000 / elapsedMs;
      _speed = _speed == 0 ? instant : (_speed * 0.6 + instant * 0.4);
      _windowBytes = bytes;
      _windowStart = now;
    }
    return _speed < 0 ? 0 : _speed;
  }
}
