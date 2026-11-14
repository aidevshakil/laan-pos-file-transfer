import 'package:flutter_test/flutter_test.dart';
import 'package:laantech_task/core/utils/file_utils.dart';
import 'package:laantech_task/domain/entities/transfer_task.dart';
import 'package:laantech_task/presentation/bloc/transfer/transfer_state.dart';

void main() {
  group('FileUtils Unit Tests', () {
    test('formatBytes formats 0 bytes properly', () {
      expect(FileUtils.formatBytes(0), '0 B');
    });

    test('formatBytes formats Kilobytes properly', () {
      expect(FileUtils.formatBytes(1024), '1.0 KB');
    });

    test('formatBytes formats Megabytes properly (>50MB)', () {
      expect(FileUtils.formatBytes(52428800), '50.0 MB');
    });

    test('formatSpeed formats transfer rate properly', () {
      expect(FileUtils.formatSpeed(1048576), '1.00 MB/s');
      expect(FileUtils.formatSpeed(51200), '50.0 KB/s');
    });
  });

  group('TransferTask Entity & State Tests', () {
    test('TransferTask state getters return expected flags', () {
      final task = TransferTask(
        id: '1',
        fileName: 'test.csv',
        localFilePath: '/path/test.csv',
        type: TransferType.upload,
        status: TransferStatus.running,
        totalBytes: 1000,
        transferredBytes: 500,
        progress: 0.5,
        createdAt: DateTime.now(),
      );

      expect(task.isRunning, isTrue);
      expect(task.isPaused, isFalse);
      expect(task.isCompleted, isFalse);
      expect(task.isUpload, isTrue);
    });

    test('TransferState calculates overall progress and active count correctly', () {
      final task1 = TransferTask(
        id: '1',
        fileName: 'catalog.csv',
        localFilePath: '/path/catalog.csv',
        type: TransferType.upload,
        status: TransferStatus.running,
        progress: 0.4,
        createdAt: DateTime.now(),
      );

      final task2 = TransferTask(
        id: '2',
        fileName: 'report.pdf',
        localFilePath: '/path/report.pdf',
        type: TransferType.download,
        status: TransferStatus.paused,
        progress: 0.6,
        createdAt: DateTime.now(),
      );

      final state = TransferState(tasks: [task1, task2]);

      expect(state.activeCount, 2);
      expect(state.hasActiveTransfers, isTrue);
      expect(state.overallProgress, closeTo(0.5, 0.01));
    });
  });
}
