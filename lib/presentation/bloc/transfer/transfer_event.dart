import 'package:equatable/equatable.dart';

import '../../../core/errors/transfer_exception.dart';
import '../../../domain/entities/remote_file.dart';
import '../../../domain/entities/upload_result.dart';

abstract class TransferEvent extends Equatable {
  const TransferEvent();

  @override
  List<Object?> get props => [];
}

class RestoreTransfers extends TransferEvent {}

class LoadRemoteFiles extends TransferEvent {}

class StartUploadEvent extends TransferEvent {
  final String filePath;
  final String fileName;
  final int fileSize;

  const StartUploadEvent({
    required this.filePath,
    required this.fileName,
    required this.fileSize,
  });

  @override
  List<Object?> get props => [filePath, fileName, fileSize];
}

class StartDownloadEvent extends TransferEvent {
  final RemoteFile remoteFile;

  const StartDownloadEvent({required this.remoteFile});

  @override
  List<Object?> get props => [remoteFile];
}

class _TaskEvent extends TransferEvent {
  final String taskId;
  const _TaskEvent(this.taskId);

  @override
  List<Object?> get props => [taskId];
}

class PauseTransferEvent extends _TaskEvent {
  const PauseTransferEvent({required String taskId}) : super(taskId);
}

class ResumeTransferEvent extends _TaskEvent {
  const ResumeTransferEvent({required String taskId}) : super(taskId);
}

class RetryTransferEvent extends _TaskEvent {
  const RetryTransferEvent({required String taskId}) : super(taskId);
}

class CancelTransferEvent extends _TaskEvent {
  const CancelTransferEvent({required String taskId}) : super(taskId);
}

class PauseAllTransfers extends TransferEvent {}

class ResumeAllTransfers extends TransferEvent {}

class ClearFinishedTransfers extends TransferEvent {}

class DeleteRemoteFileEvent extends TransferEvent {
  final String fileName;

  const DeleteRemoteFileEvent({required this.fileName});

  @override
  List<Object?> get props => [fileName];
}

class TransferProgressed extends _TaskEvent {
  final int runId;
  final int transferredBytes;
  final int totalBytes;
  final double speedBytesPerSec;

  const TransferProgressed({
    required String taskId,
    required this.runId,
    required this.transferredBytes,
    required this.totalBytes,
    required this.speedBytesPerSec,
  }) : super(taskId);

  @override
  List<Object?> get props => [taskId, runId, transferredBytes, totalBytes, speedBytesPerSec];
}

class TransferSucceeded extends _TaskEvent {
  final int runId;
  final UploadResult? uploadResult;

  const TransferSucceeded({required String taskId, required this.runId, this.uploadResult})
      : super(taskId);
}

class TransferErrored extends _TaskEvent {
  final int runId;
  final TransferException error;

  const TransferErrored({required String taskId, required this.runId, required this.error})
      : super(taskId);
}

class AutoRetryFired extends _TaskEvent {
  const AutoRetryFired({required String taskId}) : super(taskId);
}
