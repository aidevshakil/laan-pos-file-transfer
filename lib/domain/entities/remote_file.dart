import 'package:equatable/equatable.dart';

class RemoteFile extends Equatable {
  final String name;
  final int size;
  final String? url;
  final DateTime? modifiedTime;

  const RemoteFile({
    required this.name,
    this.size = 0,
    this.url,
    this.modifiedTime,
  });

  @override
  List<Object?> get props => [name, size, url, modifiedTime];
}
