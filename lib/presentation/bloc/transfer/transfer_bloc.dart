import 'dart:async';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../core/utils/file_utils.dart';
import '../../../core/utils/notification_service.dart';
import '../../../domain/entities/transfer_task.dart';
import '../../../domain/repositories/transfer_repository.dart';
import 'transfer_event.dart';
import 'transfer_state.dart';
import 'dart:developer' as developer;

class TransferBloc extends Bloc<TransferEvent, TransferState> {
  final TransferRepository transferRepository;
  final NotificationService notificationService;
  final Uuid _uuid = const Uuid();

  // Speed calculation helpers: taskId -> {bytes, timestamp}
  final Map<String, int> _lastReportedBytes = {};
  final Map<String, DateTime> _lastReportedTimes = {};
  final Map<String, int> _lastNotificationPercent = {};

  TransferBloc({
    required this.transferRepository,
    required this.notificationService,
  }) : super(const TransferState()) {
    on<LoadRemoteFiles>(_onLoadRemoteFiles);
    on<StartUploadEvent>(_onStartUpload);
    on<StartDownloadEvent>(_onStartDownload);
    on<PauseTransferEvent>(_onPauseTransfer);
    on<ResumeTransferEvent>(_onResumeTransfer);
    on<RetryTransferEvent>(_onRetryTransfer);
    on<CancelTransferEvent>(_onCancelTransfer);
    on<DeleteRemoteFileEvent>(_onDeleteRemoteFile);
    on<UpdateTransferProgressEvent>(_onUpdateTransferProgress);
    on<TransferCompletedEvent>(_onTransferCompleted);
    on<TransferFailedEvent>(_onTransferFailed);
  }

  Future<void> _onLoadRemoteFiles(
      LoadRemoteFiles event, Emitter<TransferState> emit) async {
    emit(state.copyWith(isLoadingFiles: true, errorMessage: null));
    try {
      final files = await transferRepository.getRemoteFiles();
      emit(state.copyWith(remoteFiles: files, isLoadingFiles: false));
    } catch (e) {
      emit(state.copyWith(
        isLoadingFiles: false,
        errorMessage: 'Failed to load remote files: ${e.toString().replaceAll('Exception: ', '')}',
      ));
    }
  }

  Future<void> _onStartUpload(
      StartUploadEvent event, Emitter<TransferState> emit) async {
    final taskId = _uuid.v4();
    final newTask = TransferTask(
      id: taskId,
      fileName: event.fileName,
      localFilePath: event.filePath,
      totalBytes: event.fileSize,
      type: TransferType.upload,
      status: TransferStatus.running,
      createdAt: DateTime.now(),
    );

    emit(state.copyWith(tasks: [newTask, ...state.tasks]));

    _executeUpload(taskId, event.filePath);
  }

  void _executeUpload(String taskId, String filePath) {
    _lastReportedBytes[taskId] = 0;
    _lastReportedTimes[taskId] = DateTime.now();
    _lastNotificationPercent[taskId] = -1;

    transferRepository.uploadFile(
      taskId: taskId,
      filePath: filePath,
      onProgress: (sent, total) {
        final now = DateTime.now();
        final lastBytes = _lastReportedBytes[taskId] ?? 0;
        final lastTime = _lastReportedTimes[taskId] ?? now;
        final durationSec = now.difference(lastTime).inMilliseconds / 1000.0;

        double speed = 0.0;
        if (durationSec >= 0.5) {
          speed = (sent - lastBytes) / durationSec;
          _lastReportedBytes[taskId] = sent;
          _lastReportedTimes[taskId] = now;
        }

        add(UpdateTransferProgressEvent(
          taskId: taskId,
          transferredBytes: sent,
          totalBytes: total,
          speedBytesPerSec: speed,
        ));

        // System Tray Notification throttle (every 5%)
        final percent = total > 0 ? ((sent / total) * 100).toInt() : 0;
        final lastPercent = _lastNotificationPercent[taskId] ?? -1;
        if (percent >= lastPercent + 5 || percent == 100) {
          _lastNotificationPercent[taskId] = percent;
          final task = _findTask(taskId);
          notificationService.showProgressNotification(
            id: taskId.hashCode.abs() % 100000,
            title: 'Uploading ${task?.fileName ?? "File"}',
            body: '$percent% • ${FileUtils.formatBytes(sent)} / ${FileUtils.formatBytes(total)}',
            progress: percent,
            maxProgress: 100,
          );
        }
      },
    ).then((_) {
      add(TransferCompletedEvent(taskId: taskId));
      // Refresh remote file list after upload succeeds
      add(LoadRemoteFiles());
    }).catchError((error) {
      if (error.toString().contains('cancel') || error.toString().contains('Paused')) {
        developer.log('Upload paused for task: $taskId');
      } else {
        add(TransferFailedEvent(
          taskId: taskId,
          errorMessage: error.toString().replaceAll('Exception: ', ''),
        ));
      }
    });
  }

  Future<void> _onStartDownload(
      StartDownloadEvent event, Emitter<TransferState> emit) async {
    final taskId = _uuid.v4();
    final downloadDir = await FileUtils.getSensibleDownloadDirectory();
    final savePath = '${downloadDir.path}/${event.remoteFile.name}';

    final newTask = TransferTask(
      id: taskId,
      fileName: event.remoteFile.name,
      localFilePath: savePath,
      totalBytes: event.remoteFile.size,
      type: TransferType.download,
      status: TransferStatus.running,
      createdAt: DateTime.now(),
      remoteUrl: event.remoteFile.url,
    );

    emit(state.copyWith(tasks: [newTask, ...state.tasks]));

    _executeDownload(taskId, event.remoteFile.name, savePath, 0);
  }

  void _executeDownload(
      String taskId, String fileName, String savePath, int startByte) {
    _lastReportedBytes[taskId] = startByte;
    _lastReportedTimes[taskId] = DateTime.now();
    _lastNotificationPercent[taskId] = -1;

    transferRepository.downloadFile(
      taskId: taskId,
      fileName: fileName,
      savePath: savePath,
      startByte: startByte,
      onProgress: (received, total) {
        final now = DateTime.now();
        final lastBytes = _lastReportedBytes[taskId] ?? startByte;
        final lastTime = _lastReportedTimes[taskId] ?? now;
        final durationSec = now.difference(lastTime).inMilliseconds / 1000.0;

        double speed = 0.0;
        if (durationSec >= 0.5) {
          speed = (received - lastBytes) / durationSec;
          _lastReportedBytes[taskId] = received;
          _lastReportedTimes[taskId] = now;
        }

        add(UpdateTransferProgressEvent(
          taskId: taskId,
          transferredBytes: received,
          totalBytes: total,
          speedBytesPerSec: speed,
        ));

        // System Tray Notification throttle (every 5%)
        final percent = total > 0 ? ((received / total) * 100).toInt() : 0;
        final lastPercent = _lastNotificationPercent[taskId] ?? -1;
        if (percent >= lastPercent + 5 || percent == 100) {
          _lastNotificationPercent[taskId] = percent;
          notificationService.showProgressNotification(
            id: taskId.hashCode.abs() % 100000,
            title: 'Downloading $fileName',
            body: '$percent% • ${FileUtils.formatBytes(received)} / ${FileUtils.formatBytes(total)}',
            progress: percent,
            maxProgress: 100,
          );
        }
      },
    ).then((_) {
      add(TransferCompletedEvent(taskId: taskId));
    }).catchError((error) {
      if (error.toString().contains('cancel') || error.toString().contains('Paused')) {
        developer.log('Download paused for task: $taskId');
      } else {
        add(TransferFailedEvent(
          taskId: taskId,
          errorMessage: error.toString().replaceAll('Exception: ', ''),
        ));
      }
    });
  }

  void _onPauseTransfer(
      PauseTransferEvent event, Emitter<TransferState> emit) {
    transferRepository.pauseTransfer(event.taskId);

    final updatedTasks = state.tasks.map((task) {
      if (task.id == event.taskId) {
        return task.copyWith(
          status: TransferStatus.paused,
          speedBytesPerSec: 0.0,
        );
      }
      return task;
    }).toList();

    emit(state.copyWith(tasks: updatedTasks));

    // Cancel notification while paused
    notificationService.cancel(event.taskId.hashCode.abs() % 100000);
  }

  Future<void> _onResumeTransfer(
      ResumeTransferEvent event, Emitter<TransferState> emit) async {
    final task = _findTask(event.taskId);
    if (task == null) return;

    final updatedTasks = state.tasks.map((t) {
      if (t.id == event.taskId) {
        return t.copyWith(
          status: TransferStatus.running,
          errorMessage: null,
        );
      }
      return t;
    }).toList();

    emit(state.copyWith(tasks: updatedTasks));

    if (task.isDownload) {
      // Check existing partial file size on disk for HTTP Range resume
      final file = File(task.localFilePath);
      final existingBytes = (await file.exists()) ? await file.length() : 0;
      _executeDownload(task.id, task.fileName, task.localFilePath, existingBytes);
    } else {
      _executeUpload(task.id, task.localFilePath);
    }
  }

  void _onRetryTransfer(
      RetryTransferEvent event, Emitter<TransferState> emit) {
    add(ResumeTransferEvent(taskId: event.taskId));
  }

  void _onCancelTransfer(
      CancelTransferEvent event, Emitter<TransferState> emit) {
    transferRepository.cancelTransfer(event.taskId);
    final updatedTasks = state.tasks.where((t) => t.id != event.taskId).toList();
    emit(state.copyWith(tasks: updatedTasks));
    notificationService.cancel(event.taskId.hashCode.abs() % 100000);
  }

  Future<void> _onDeleteRemoteFile(
      DeleteRemoteFileEvent event, Emitter<TransferState> emit) async {
    try {
      await transferRepository.deleteRemoteFile(event.fileName);
      add(LoadRemoteFiles());
    } catch (e) {
      emit(state.copyWith(
        errorMessage: 'Failed to delete file: ${e.toString().replaceAll('Exception: ', '')}',
      ));
    }
  }

  void _onUpdateTransferProgress(
      UpdateTransferProgressEvent event, Emitter<TransferState> emit) {
    final updatedTasks = state.tasks.map((task) {
      if (task.id == event.taskId) {
        final progress = event.totalBytes > 0
            ? (event.transferredBytes / event.totalBytes).clamp(0.0, 1.0)
            : 0.0;

        return task.copyWith(
          transferredBytes: event.transferredBytes,
          totalBytes: event.totalBytes > 0 ? event.totalBytes : task.totalBytes,
          progress: progress,
          speedBytesPerSec: event.speedBytesPerSec > 0
              ? event.speedBytesPerSec
              : task.speedBytesPerSec,
        );
      }
      return task;
    }).toList();

    emit(state.copyWith(tasks: updatedTasks));
  }

  void _onTransferCompleted(
      TransferCompletedEvent event, Emitter<TransferState> emit) {
    final task = _findTask(event.taskId);

    final updatedTasks = state.tasks.map((t) {
      if (t.id == event.taskId) {
        return t.copyWith(
          status: TransferStatus.completed,
          progress: 1.0,
          transferredBytes: t.totalBytes > 0 ? t.totalBytes : t.transferredBytes,
          completedAt: DateTime.now(),
          speedBytesPerSec: 0.0,
        );
      }
      return t;
    }).toList();

    emit(state.copyWith(tasks: updatedTasks));

    // Show completion notification in system tray
    if (task != null) {
      final isUp = task.isUpload;
      notificationService.showCompletionNotification(
        id: task.id.hashCode.abs() % 100000,
        title: isUp ? 'Upload Complete' : 'Download Complete',
        body: '${task.fileName} (${FileUtils.formatBytes(task.totalBytes)}) saved successfully.',
        payload: task.localFilePath,
      );
    }
  }

  void _onTransferFailed(
      TransferFailedEvent event, Emitter<TransferState> emit) {
    final task = _findTask(event.taskId);

    final updatedTasks = state.tasks.map((t) {
      if (t.id == event.taskId) {
        return t.copyWith(
          status: TransferStatus.failed,
          errorMessage: event.errorMessage,
          speedBytesPerSec: 0.0,
        );
      }
      return t;
    }).toList();

    emit(state.copyWith(tasks: updatedTasks));

    if (task != null) {
      notificationService.showCompletionNotification(
        id: task.id.hashCode.abs() % 100000,
        title: '${task.isUpload ? "Upload" : "Download"} Failed',
        body: 'Error: ${event.errorMessage}. Tap to view or retry.',
        payload: task.id,
      );
    }
  }

  TransferTask? _findTask(String taskId) {
    try {
      return state.tasks.firstWhere((t) => t.id == taskId);
    } catch (_) {
      return null;
    }
  }
}
