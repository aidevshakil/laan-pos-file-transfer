import 'package:equatable/equatable.dart';

import '../../../domain/entities/remote_file.dart';
import '../../../domain/entities/transfer_task.dart';

class TransferState extends Equatable {
  final List<TransferTask> tasks;
  final List<RemoteFile> remoteFiles;
  final bool isLoadingFiles;

  final String? filesError;

  final String? notice;

  const TransferState({
    this.tasks = const [],
    this.remoteFiles = const [],
    this.isLoadingFiles = false,
    this.filesError,
    this.notice,
  });

  List<TransferTask> get activeTasks => tasks.where((t) => t.isActive).toList();
  List<TransferTask> get inFlightTasks => tasks.where((t) => t.isInFlight).toList();
  List<TransferTask> get completedTasks => tasks.where((t) => t.isCompleted).toList();
  List<TransferTask> get failedTasks => tasks.where((t) => t.isFailed).toList();

  int get activeCount => activeTasks.length;
  bool get hasActiveTransfers => activeTasks.isNotEmpty;

  double get totalSpeed =>
      tasks.fold(0.0, (sum, t) => sum + (t.isRunning ? t.speedBytesPerSec : 0.0));

  double get overallProgress {
    final active = activeTasks;
    if (active.isEmpty) return 0.0;
    final total = active.fold<int>(0, (s, t) => s + t.totalBytes);
    if (total <= 0) {
      return active.fold(0.0, (s, t) => s + t.progress) / active.length;
    }
    final done = active.fold<int>(0, (s, t) => s + t.transferredBytes.clamp(0, t.totalBytes));
    return (done / total).clamp(0.0, 1.0);
  }

  TransferTask? latestDownloadFor(String remoteName) {
    for (final t in tasks) {
      if (t.isDownload && t.remoteFileName == remoteName) return t;
    }
    return null;
  }

  TransferState copyWith({
    List<TransferTask>? tasks,
    List<RemoteFile>? remoteFiles,
    bool? isLoadingFiles,
    String? filesError,
    bool clearFilesError = false,
    String? notice,
  }) {
    return TransferState(
      tasks: tasks ?? this.tasks,
      remoteFiles: remoteFiles ?? this.remoteFiles,
      isLoadingFiles: isLoadingFiles ?? this.isLoadingFiles,
      filesError: clearFilesError ? null : (filesError ?? this.filesError),
      notice: notice,
    );
  }

  @override
  List<Object?> get props => [tasks, remoteFiles, isLoadingFiles, filesError, notice];
}
