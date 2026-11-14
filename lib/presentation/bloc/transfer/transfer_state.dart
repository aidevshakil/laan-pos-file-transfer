import 'package:equatable/equatable.dart';
import '../../../domain/entities/remote_file.dart';
import '../../../domain/entities/transfer_task.dart';

class TransferState extends Equatable {
  final List<TransferTask> tasks;
  final List<RemoteFile> remoteFiles;
  final bool isLoadingFiles;
  final String? errorMessage;

  const TransferState({
    this.tasks = const [],
    this.remoteFiles = const [],
    this.isLoadingFiles = false,
    this.errorMessage,
  });

  /// Tasks currently running or queued
  List<TransferTask> get activeTasks =>
      tasks.where((t) => t.isRunning || t.isPaused || t.isQueued).toList();

  /// Total count of active transfers
  int get activeCount => activeTasks.length;

  /// Whether any transfer is currently active
  bool get hasActiveTransfers => activeTasks.isNotEmpty;

  /// History of completed or failed tasks
  List<TransferTask> get recentTasks =>
      tasks.where((t) => t.isCompleted || t.isFailed).toList();

  /// Running tasks only
  List<TransferTask> get runningTasks =>
      tasks.where((t) => t.isRunning).toList();

  /// Calculates aggregated overall progress (0.0 to 1.0)
  double get overallProgress {
    final active = activeTasks;
    if (active.isEmpty) return 0.0;
    final totalProgress = active.fold(0.0, (sum, t) => sum + t.progress);
    return totalProgress / active.length;
  }

  TransferState copyWith({
    List<TransferTask>? tasks,
    List<RemoteFile>? remoteFiles,
    bool? isLoadingFiles,
    String? errorMessage,
  }) {
    return TransferState(
      tasks: tasks ?? this.tasks,
      remoteFiles: remoteFiles ?? this.remoteFiles,
      isLoadingFiles: isLoadingFiles ?? this.isLoadingFiles,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [tasks, remoteFiles, isLoadingFiles, errorMessage];
}
