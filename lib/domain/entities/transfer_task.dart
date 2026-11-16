import 'package:equatable/equatable.dart';

enum TransferType { upload, download }

enum TransferStatus {
  queued,
  running,

  retrying,
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
  final TransferType type;
  final TransferStatus status;
  final double speedBytesPerSec;

  final String? message;
  final DateTime createdAt;
  final DateTime? completedAt;

  final String? remoteFileName;

  final String? remoteUrl;
  final int autoRetryCount;

  const TransferTask({
    required this.id,
    required this.fileName,
    required this.localFilePath,
    required this.type,
    required this.createdAt,
    this.totalBytes = 0,
    this.transferredBytes = 0,
    this.status = TransferStatus.queued,
    this.speedBytesPerSec = 0.0,
    this.message,
    this.completedAt,
    this.remoteFileName,
    this.remoteUrl,
    this.autoRetryCount = 0,
  });

  double get progress =>
      totalBytes > 0 ? (transferredBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
  int get percent => (progress * 100).floor();

  bool get isRunning => status == TransferStatus.running;
  bool get isRetrying => status == TransferStatus.retrying;
  bool get isPaused => status == TransferStatus.paused;
  bool get isCompleted => status == TransferStatus.completed;
  bool get isFailed => status == TransferStatus.failed;
  bool get isQueued => status == TransferStatus.queued;
  bool get isActive => isRunning || isRetrying || isQueued || isPaused;
  bool get isInFlight => isRunning || isRetrying || isQueued;
  bool get isUpload => type == TransferType.upload;
  bool get isDownload => type == TransferType.download;

  String get partialPath => '$localFilePath.part';

  Duration? get eta {
    if (!isRunning || speedBytesPerSec <= 0 || totalBytes <= 0) return null;
    final remaining = totalBytes - transferredBytes;
    if (remaining <= 0) return Duration.zero;
    return Duration(seconds: (remaining / speedBytesPerSec).ceil());
  }

  static const _unset = Object();

  TransferTask copyWith({
    String? fileName,
    String? localFilePath,
    int? totalBytes,
    int? transferredBytes,
    TransferStatus? status,
    double? speedBytesPerSec,
    Object? message = _unset,
    DateTime? completedAt,
    String? remoteFileName,
    String? remoteUrl,
    int? autoRetryCount,
  }) {
    return TransferTask(
      id: id,
      type: type,
      createdAt: createdAt,
      fileName: fileName ?? this.fileName,
      localFilePath: localFilePath ?? this.localFilePath,
      totalBytes: totalBytes ?? this.totalBytes,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      status: status ?? this.status,
      speedBytesPerSec: speedBytesPerSec ?? this.speedBytesPerSec,
      message: identical(message, _unset) ? this.message : message as String?,
      completedAt: completedAt ?? this.completedAt,
      remoteFileName: remoteFileName ?? this.remoteFileName,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      autoRetryCount: autoRetryCount ?? this.autoRetryCount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'localFilePath': localFilePath,
        'totalBytes': totalBytes,
        'transferredBytes': transferredBytes,
        'type': type.name,
        'status': status.name,
        'message': message,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'remoteFileName': remoteFileName,
        'remoteUrl': remoteUrl,
      };

  factory TransferTask.fromJson(Map<String, dynamic> json) {
    T byName<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    return TransferTask(
      id: json['id'] as String,
      fileName: json['fileName'] as String,
      localFilePath: json['localFilePath'] as String,
      totalBytes: (json['totalBytes'] as num?)?.toInt() ?? 0,
      transferredBytes: (json['transferredBytes'] as num?)?.toInt() ?? 0,
      type: byName(TransferType.values, json['type'], TransferType.upload),
      status: byName(TransferStatus.values, json['status'], TransferStatus.failed),
      message: json['message'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      completedAt: DateTime.tryParse(json['completedAt'] ?? ''),
      remoteFileName: json['remoteFileName'] as String?,
      remoteUrl: json['remoteUrl'] as String?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        fileName,
        localFilePath,
        totalBytes,
        transferredBytes,
        type,
        status,
        speedBytesPerSec,
        message,
        createdAt,
        completedAt,
        remoteFileName,
        remoteUrl,
        autoRetryCount,
      ];
}
