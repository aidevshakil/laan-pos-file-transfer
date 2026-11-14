import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class FileUtils {
  FileUtils._();

  /// Formats byte count to human-readable string (e.g. 52.4 MB)
  static String formatBytes(int bytes, [int decimals = 1]) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = (bytes > 0) ? (bytes.toString().length - 1) ~/ 3 : 0;
    if (i >= suffixes.length) i = suffixes.length - 1;
    final num = bytes / (1 << (i * 10));
    return '${num.toStringAsFixed(decimals)} ${suffixes[i]}';
  }

  /// Formats transfer speed (e.g. 2.4 MB/s)
  static String formatSpeed(double bytesPerSecond) {
    if (bytesPerSecond <= 0) return '0 KB/s';
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }

  /// Returns an appropriate icon based on file extension
  static IconData getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
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
        return Icons.image_rounded;
      case 'mp4':
      case 'mkv':
      case 'avi':
      case 'mov':
        return Icons.video_file_rounded;
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

  /// Gets a sensible location in device storage to save downloaded files.
  /// On Android, prefers the standard Downloads directory or ApplicationDocumentsDirectory.
  static Future<Directory> getSensibleDownloadDirectory() async {
    Directory? directory;
    if (Platform.isAndroid) {
      try {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) {
          directory = await getExternalStorageDirectory();
        }
      } catch (_) {
        directory = await getApplicationDocumentsDirectory();
      }
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    return directory ?? await getApplicationDocumentsDirectory();
  }
}
