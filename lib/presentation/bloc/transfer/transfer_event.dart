import 'package:equatable/equatable.dart';
import '../../../domain/entities/remote_file.dart';

abstract class TransferEvent extends Equatable {
  const TransferEvent();

  @override
  List<Object?> get props => [];
}

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

class PauseTransferEvent extends TransferEvent {
  final String taskId;

  const PauseTransferEvent({required this.taskId});

  @override
  List<Object?> get props => [taskId];
}

class ResumeTransferEvent extends TransferEvent {
  final String taskId;

  const ResumeTransferEvent({required this.taskId});

  @override
  List<Object?> get props => [taskId];
}

class RetryTransferEvent extends TransferEvent {
  final String taskId;

  const RetryTransferEvent({required this.taskId});

  @override
  List<Object?> get props => [taskId];
}

class CancelTransferEvent extends TransferEvent {
  final String taskId;

  const CancelTransferEvent({required this.taskId});

  @override
  List<Object?> get props => [taskId];
}

class DeleteRemoteFileEvent extends TransferEvent {
  final String fileName;

  const DeleteRemoteFileEvent({required this.fileName});

  @override
  List<Object?> get props => [fileName];
}

class UpdateTransferProgressEvent extends TransferEvent {
  final String taskId;
  final int transferredBytes;
  final int totalBytes;
  final double speedBytesPerSec;

  const UpdateTransferProgressEvent({
    required this.taskId,
    required this.transferredBytes,
    required this.totalBytes,
    required this.speedBytesPerSec,
  });

  @override
  List<Object?> get props => [
        taskId,
        transferredBytes,
        totalBytes,
        speedBytesPerSec,
      ];
}

class TransferCompletedEvent extends TransferEvent {
  final String taskId;

  const TransferCompletedEvent({required this.taskId});

  @override
  List<Object?> get props => [taskId];
}

class TransferFailedEvent extends TransferEvent {
  final String taskId;
  final String errorMessage;

  const TransferFailedEvent({
    required this.taskId,
    required this.errorMessage,
  });

  @override
  List<Object?> get props => [taskId, errorMessage];
}
