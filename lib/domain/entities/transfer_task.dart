import 'package:equatable/equatable.dart';

enum TransferType { upload, download }

enum TransferStatus {
  queued,
  running,
  paused,
  completed,
  failed,
}

class TransferTask extends Equatable {
  final String id;
  final String fileName;
  final String localFilePath;
  final int totalBytes;
  final int transferredBytes;
  final double progress; // 0.0 to 1.0
  final TransferType type;
  final TransferStatus status;
  final double speedBytesPerSec;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? remoteUrl;

  const TransferTask({
    required this.id,
    required this.fileName,
    required this.localFilePath,
    this.totalBytes = 0,
    this.transferredBytes = 0,
    this.progress = 0.0,
    required this.type,
    this.status = TransferStatus.queued,
    this.speedBytesPerSec = 0.0,
    this.errorMessage,
    required this.createdAt,
    this.completedAt,
    this.remoteUrl,
  });

  bool get isRunning => status == TransferStatus.running;
  bool get isPaused => status == TransferStatus.paused;
  bool get isCompleted => status == TransferStatus.completed;
  bool get isFailed => status == TransferStatus.failed;
  bool get isQueued => status == TransferStatus.queued;
  bool get isUpload => type == TransferType.upload;
  bool get isDownload => type == TransferType.download;

  TransferTask copyWith({
    String? id,
    String? fileName,
    String? localFilePath,
    int? totalBytes,
    int? transferredBytes,
    double? progress,
    TransferType? type,
    TransferStatus? status,
    double? speedBytesPerSec,
    String? errorMessage,
    DateTime? createdAt,
    DateTime? completedAt,
    String? remoteUrl,
  }) {
    return TransferTask(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      localFilePath: localFilePath ?? this.localFilePath,
      totalBytes: totalBytes ?? this.totalBytes,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      progress: progress ?? this.progress,
      type: type ?? this.type,
      status: status ?? this.status,
      speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
      errorMessage: errorMessage,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      remoteUrl: remoteUrl ?? this.remoteUrl,
    );
  }

  @override
  List<Object?> get props => [
        id,
        fileName,
        localFilePath,
        totalBytes,
        transferredBytes,
        progress,
        type,
        status,
        speedBytesPerSec,
        errorMessage,
        createdAt,
        completedAt,
        remoteUrl,
      ];
}
