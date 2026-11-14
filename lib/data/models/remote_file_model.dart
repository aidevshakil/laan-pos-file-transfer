import '../../domain/entities/remote_file.dart';

class RemoteFileModel extends RemoteFile {
  const RemoteFileModel({
    required super.name,
    super.size,
    super.url,
    super.modifiedTime,
  });

  factory RemoteFileModel.fromJson(Map<String, dynamic> json) {
    return RemoteFileModel(
      name: json['name']?.toString() ?? json['filename']?.toString() ?? 'unknown',
      size: (json['size'] is num) ? (json['size'] as num).toInt() : 0,
      url: json['url']?.toString(),
      modifiedTime: json['updated_at'] != null || json['modified'] != null
          ? DateTime.tryParse(json['updated_at']?.toString() ?? json['modified']?.toString() ?? '')
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'size': size,
      'url': url,
      'modified': modifiedTime?.toIso8601String(),
    };
  }
}
