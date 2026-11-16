import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laantech_task/core/errors/transfer_exception.dart';
import 'package:laantech_task/core/services/background_transfer_service.dart';
import 'package:laantech_task/core/utils/file_utils.dart';
import 'package:laantech_task/core/utils/notification_service.dart';
import 'package:laantech_task/domain/entities/remote_file.dart';
import 'package:laantech_task/domain/entities/transfer_task.dart';
import 'package:laantech_task/domain/entities/upload_result.dart';
import 'package:laantech_task/domain/repositories/transfer_repository.dart';
import 'package:laantech_task/presentation/bloc/transfer/transfer_bloc.dart';
import 'package:laantech_task/presentation/bloc/transfer/transfer_event.dart';
import 'package:laantech_task/presentation/bloc/transfer/transfer_state.dart';

class FakeNotifications implements NotificationService {
  final results = <String>[];

  @override
  Future<void> showResult({
    required String taskId,
    required String title,
    required String body,
    required String payload,
  }) async =>
      results.add(title);

  @override
  Future<void> showProgress({
    required String taskId,
    required String title,
    required String body,
    required int percent,
    required String payload,
    bool indeterminate = false,
  }) async {}

  @override
  Future<void> cancelProgress(String taskId) async {}

  @override
  Future<void> cancelAll(String taskId) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeBackground implements BackgroundTransferService {
  int lastActive = 0;

  @override
  Future<void> sync({required int activeCount, required int percent}) async =>
      lastActive = activeCount;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRepo implements TransferRepository {
  int failuresBeforeSuccess;
  TransferException failure;
  final aborted = <String>[];
  Completer<void>? gate;
  int uploadCalls = 0;

  FakeRepo({
    this.failuresBeforeSuccess = 0,
    this.failure = const TransferException(TransferErrorKind.noConnection, 'offline'),
  });

  @override
  Future<UploadResult> uploadFile({
    required String taskId,
    required String filePath,
    required String fileName,
    required void Function(int, int) onProgress,
  }) async {
    uploadCalls++;
    if (failuresBeforeSuccess > 0) {
      failuresBeforeSuccess--;
      throw failure;
    }
    for (var i = 1; i <= 4; i++) {
      if (gate != null) await gate!.future;
      if (aborted.contains(taskId)) throw TransferException.cancelled;
      onProgress(i * 25, 100);
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    return UploadResult(remoteName: 'srv_$fileName', url: 'http://x/get?file=srv_$fileName');
  }

  @override
  void abort(String taskId) => aborted.add(taskId);

  @override
  Future<List<RemoteFile>> getRemoteFiles() async => const [];

  @override
  Future<void> downloadFile({
    required String taskId,
    required String remoteName,
    required String partialPath,
    required void Function(int, int) onProgress,
    String? url,
  }) async {}

  @override
  Future<void> deleteRemoteFile(String fileName) async {}
}

TransferBloc buildBloc(FakeRepo repo, FakeNotifications n, FakeBackground bg) => TransferBloc(
      transferRepository: repo,
      notificationService: n,
      backgroundService: bg,
      retryBaseDelay: const Duration(milliseconds: 10),
    );

Future<TransferState> waitFor(TransferBloc bloc, bool Function(TransferState) test) =>
    test(bloc.state) ? Future.value(bloc.state) : bloc.stream.firstWhere(test).timeout(const Duration(seconds: 5));

const upload = StartUploadEvent(filePath: '/tmp/catalog.csv', fileName: 'catalog.csv', fileSize: 100);

void main() {
  group('FileUtils', () {
    test('formatBytes', () {
      expect(FileUtils.formatBytes(0), '0 B');
      expect(FileUtils.formatBytes(512), '512 B');
      expect(FileUtils.formatBytes(1024), '1.0 KB');
      expect(FileUtils.formatBytes(52428800), '50.0 MB');
    });

    test('formatSpeed', () {
      expect(FileUtils.formatSpeed(1048576), '1.0 MB/s');
      expect(FileUtils.formatSpeed(0), '—');
    });

    test('safeFileName strips path traversal and illegal characters', () {
      expect(FileUtils.safeFileName('../../etc/passwd'), 'passwd');
      expect(FileUtils.safeFileName('a:b?.csv'), 'a_b_.csv');
    });
  });

  group('TransferTask', () {
    test('progress, eta and JSON round-trip', () {
      final t = TransferTask(
        id: '1',
        fileName: 'a.csv',
        localFilePath: '/a.csv',
        type: TransferType.download,
        status: TransferStatus.running,
        totalBytes: 1000,
        transferredBytes: 250,
        speedBytesPerSec: 250,
        createdAt: DateTime(2026),
        remoteFileName: 'a.csv',
      );
      expect(t.progress, 0.25);
      expect(t.percent, 25);
      expect(t.eta, const Duration(seconds: 3));
      final back = TransferTask.fromJson(t.toJson());
      expect(back.copyWith(speedBytesPerSec: 250), t);
    });

    test('copyWith can clear message explicitly', () {
      final t = TransferTask(
        id: '1',
        fileName: 'a',
        localFilePath: '/a',
        type: TransferType.upload,
        createdAt: DateTime(2026),
        message: 'x',
      );
      expect(t.copyWith().message, 'x');
      expect(t.copyWith(message: null).message, isNull);
    });
  });

  group('TransferState', () {
    test('overall progress is byte weighted', () {
      TransferTask mk(String id, int done, int total, TransferStatus s) => TransferTask(
            id: id,
            fileName: id,
            localFilePath: id,
            type: TransferType.upload,
            status: s,
            totalBytes: total,
            transferredBytes: done,
            createdAt: DateTime(2026),
          );
      final state = TransferState(tasks: [
        mk('a', 50, 100, TransferStatus.running),
        mk('b', 0, 300, TransferStatus.paused),
        mk('c', 10, 10, TransferStatus.completed),
      ]);
      expect(state.activeCount, 2);
      expect(state.overallProgress, closeTo(50 / 400, 1e-9));
    });
  });

  group('UploadResult parsing', () {
    test('reads name + url from common shapes', () {
      final r = UploadResult.fromResponse(
        {'success': true, 'file': 'photo_1.jpg', 'url': 'http://h/get?file=photo_1.jpg'},
        fallbackName: 'photo.jpg',
      );
      expect(r.remoteName, 'photo_1.jpg');
      expect(r.url, 'http://h/get?file=photo_1.jpg');
    });

    test('derives name from url, falls back to local name', () {
      expect(
        UploadResult.fromResponse({'url': 'http://h/get?file=x.csv'}, fallbackName: 'y').remoteName,
        'x.csv',
      );
      expect(UploadResult.fromResponse('OK', fallbackName: 'y.csv').remoteName, 'y.csv');
    });
  });

  group('TransferException mapping', () {
    final req = RequestOptions(path: '/upload');

    test('connection errors are retryable, auth errors are not', () {
      final net = TransferException.fromDio(
        DioException(requestOptions: req, type: DioExceptionType.connectionError),
      );
      expect(net.kind, TransferErrorKind.noConnection);
      expect(net.isRetryable, isTrue);

      final auth = TransferException.fromDio(DioException(
        requestOptions: req,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: req, statusCode: 401),
      ));
      expect(auth.kind, TransferErrorKind.unauthorized);
      expect(auth.isRetryable, isFalse);
    });

    test('5xx is retryable and server message is surfaced for 4xx', () {
      final s500 = TransferException.fromDio(DioException(
        requestOptions: req,
        type: DioExceptionType.badResponse,
        response: Response(requestOptions: req, statusCode: 503),
      ));
      expect(s500.isRetryable, isTrue);

      final bad = TransferException.fromDio(DioException(
        requestOptions: req,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: req,
          statusCode: 422,
          data: {'success': false, 'error': 'File type not allowed'},
        ),
      ));
      expect(bad.kind, TransferErrorKind.invalidFile);
      expect(bad.message, contains('File type not allowed'));
    });
  });

  group('TransferBloc engine', () {
    test('upload completes, stores server name and notifies', () async {
      final repo = FakeRepo();
      final n = FakeNotifications();
      final bloc = buildBloc(repo, n, FakeBackground())..add(upload);

      final s = await waitFor(bloc, (s) => s.tasks.isNotEmpty && s.tasks.first.isCompleted);
      expect(s.tasks.first.remoteFileName, 'srv_catalog.csv');
      expect(s.tasks.first.progress, 1.0);
      expect(n.results, contains('Upload complete'));
      await bloc.close();
    });

    test('transient failures auto-retry then succeed', () async {
      final repo = FakeRepo(failuresBeforeSuccess: 2);
      final bloc = buildBloc(repo, FakeNotifications(), FakeBackground())..add(upload);

      await waitFor(bloc, (s) => s.tasks.isNotEmpty && s.tasks.first.isRetrying);
      final s = await waitFor(bloc, (s) => s.tasks.first.isCompleted);
      expect(repo.uploadCalls, 3);
      expect(s.tasks.first.message, isNull);
      await bloc.close();
    });

    test('gives up after max retries and can be retried manually', () async {
      final repo = FakeRepo(failuresBeforeSuccess: TransferBloc.maxAutoRetries + 1);
      final n = FakeNotifications();
      final bloc = buildBloc(repo, n, FakeBackground())..add(upload);

      final failed = await waitFor(bloc, (s) => s.tasks.isNotEmpty && s.tasks.first.isFailed);
      expect(failed.tasks.first.message, 'offline');
      expect(n.results, contains('Upload failed'));

      bloc.add(RetryTransferEvent(taskId: failed.tasks.first.id));
      await waitFor(bloc, (s) => s.tasks.first.isCompleted);
      await bloc.close();
    });

    test('non-retryable errors fail immediately', () async {
      final repo = FakeRepo(
        failuresBeforeSuccess: 1,
        failure: const TransferException(TransferErrorKind.invalidFile, 'empty file'),
      );
      final bloc = buildBloc(repo, FakeNotifications(), FakeBackground())..add(upload);
      final s = await waitFor(bloc, (s) => s.tasks.isNotEmpty && s.tasks.first.isFailed);
      expect(repo.uploadCalls, 1);
      expect(s.tasks.first.message, 'empty file');
      await bloc.close();
    });

    test('pause aborts the request; resume restarts and completes', () async {
      final repo = FakeRepo()..gate = Completer<void>();
      final bg = FakeBackground();
      final bloc = buildBloc(repo, FakeNotifications(), bg)..add(upload);

      final running = await waitFor(bloc, (s) => s.tasks.isNotEmpty && s.tasks.first.isRunning);
      final id = running.tasks.first.id;
      expect(bg.lastActive, 1);

      bloc.add(PauseTransferEvent(taskId: id));
      await waitFor(bloc, (s) => s.tasks.first.isPaused);
      expect(repo.aborted, contains(id));
      repo.gate!.complete();
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.tasks.first.isPaused, isTrue, reason: 'stale attempt must not change state');

      repo.aborted.clear();
      bloc.add(ResumeTransferEvent(taskId: id));
      await waitFor(bloc, (s) => s.tasks.first.isCompleted);
      expect(bg.lastActive, 0);
      await bloc.close();
    });

    test('only maxConcurrent transfers run at once', () async {
      final repo = FakeRepo()..gate = Completer<void>();
      final bloc = buildBloc(repo, FakeNotifications(), FakeBackground());
      for (var i = 0; i < 3; i++) {
        bloc.add(StartUploadEvent(filePath: '/f$i', fileName: 'f$i', fileSize: 100));
      }
      final s = await waitFor(bloc, (s) => s.tasks.length == 3 && s.tasks.where((t) => t.isRunning).length == 2);
      expect(s.tasks.where((t) => t.isQueued).length, 1);
      repo.gate!.complete();
      await waitFor(bloc, (s) => s.tasks.every((t) => t.isCompleted));
      await bloc.close();
    });
  });
}
