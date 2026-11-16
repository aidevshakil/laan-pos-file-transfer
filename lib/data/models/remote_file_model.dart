import '../../domain/entities/remote_file.dart';

class RemoteFileModel extends RemoteFile {
  const RemoteFileModel({
    required super.name,
    super.size,
    super.url,
    super.modifiedTime,
  });

  factory RemoteFileModel.fromJson(Map<String, dynamic> json) {
    final rawSize = json['size'] ?? json['bytes'] ?? json['length'];
    final rawTime = json['modified'] ?? json['updated_at'] ?? json['mtime'] ?? json['created_at'];
    DateTime? time;
    if (rawTime is num) {
      time = DateTime.fromMillisecondsSinceEpoch(rawTime.toInt() * 1000);
    } else if (rawTime != null) {
      time = DateTime.tryParse(rawTime.toString());
    }
    return RemoteFileModel(
      name: (json['name'] ?? json['filename'] ?? json['file'] ?? 'unknown').toString(),
      size: rawSize is num ? rawSize.toInt() : int.tryParse('${rawSize ?? ''}') ?? 0,
      url: json['url']?.toString(),
      modifiedTime: time,
    );
  }
}
