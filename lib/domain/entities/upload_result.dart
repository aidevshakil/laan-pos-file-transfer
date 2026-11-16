class UploadResult {
  final String remoteName;

  final String? url;

  const UploadResult({required this.remoteName, this.url});

  factory UploadResult.fromResponse(dynamic data, {required String fallbackName}) {
    Map? map = data is Map ? data : null;
    if (map != null && map['data'] is Map) map = map['data'] as Map;
    if (map != null && map['file'] is Map) map = map['file'] as Map;

    String? pick(List<String> keys) {
      for (final k in keys) {
        final v = map?[k];
        if (v is String && v.isNotEmpty) return v;
      }
      return null;
    }

    final url = pick(['url', 'download_url', 'downloadUrl', 'link', 'path']);
    var name = pick(['name', 'filename', 'file_name', 'file', 'stored_as', 'saved_as']);

    if (name == null && url != null) {
      final uri = Uri.tryParse(url);
      name = uri?.queryParameters['file'] ??
          (uri != null && uri.pathSegments.isNotEmpty ? uri.pathSegments.last : null);
    }
    return UploadResult(remoteName: name ?? fallbackName, url: url);
  }
}
