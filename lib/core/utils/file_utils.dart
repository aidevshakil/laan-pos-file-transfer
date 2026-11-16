import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class FileUtils {
  FileUtils._();

  static const String downloadFolderName = 'LAAN POS';

  static String formatBytes(int bytes, [int decimals = 1]) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double value = bytes.toDouble();
    while (value >= 1024 && i < suffixes.length - 1) {
      value /= 1024;
      i++;
    }
    return '${value.toStringAsFixed(i == 0 ? 0 : decimals)} ${suffixes[i]}';
  }

  static String formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond <= 0) return '—';
    return '${formatBytes(bytesPerSecond.round())}/s';
  }

  static String formatDuration(Duration d) {
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    return '${d.inSeconds}s';
  }

  static String timeAgo(DateTime time, [DateTime? now]) {
    final d = (now ?? DateTime.now()).difference(time);
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  static String extension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot <= 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  }

  static IconData getFileIcon(String fileName) {
    switch (extension(fileName)) {
      case 'csv':
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_rounded;
      case 'pdf':
        return Icons.picture_as_pdf_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
      case 'heic':
        return Icons.image_rounded;
      case 'mp4':
      case 'mkv':
      case 'avi':
      case 'mov':
      case 'webm':
        return Icons.movie_rounded;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return Icons.folder_zip_rounded;
      case 'json':
      case 'xml':
      case 'txt':
        return Icons.description_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }

  static Future<Directory> getDownloadDirectory() async {
    if (Platform.isAndroid) {
      final public = Directory('/storage/emulated/0/Download/$downloadFolderName');
      if (await _isWritable(public)) return public;

      final external = await getExternalStorageDirectory();
      if (external != null) {
        final dir = Directory('${external.path}/Download');
        if (await _isWritable(dir)) return dir;
      }
    }
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/Downloads');
    await dir.create(recursive: true);
    return dir;
  }

  static Future<bool> _isWritable(Directory dir) async {
    try {
      await dir.create(recursive: true);
      final probe = File('${dir.path}/.write_probe');
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  static String safeFileName(String name) {
    final cleaned = name.split(RegExp(r'[\\/]')).last.replaceAll(RegExp(r'[<>:"|?*\x00-\x1F]'), '_').trim();
    return cleaned.isEmpty ? 'download' : cleaned;
  }

  static Future<String> uniqueFilePath(Directory dir, String fileName) async {
    final dot = fileName.lastIndexOf('.');
    final base = dot > 0 ? fileName.substring(0, dot) : fileName;
    final ext = dot > 0 ? fileName.substring(dot) : '';
    var candidate = '${dir.path}${Platform.pathSeparator}$fileName';
    var n = 1;
    while (await File(candidate).exists() || await File('$candidate.part').exists()) {
      candidate = '${dir.path}${Platform.pathSeparator}$base ($n)$ext';
      n++;
    }
    return candidate;
  }

  static String friendlyDirectory(String filePath) {
    final dir = File(filePath).parent.path;
    const root = '/storage/emulated/0/';
    if (dir.startsWith(root)) return dir.substring(root.length);
    final idx = dir.indexOf('/Android/data/');
    if (idx >= 0) return 'App storage${dir.substring(dir.lastIndexOf('/'))}';
    return dir;
  }
}
