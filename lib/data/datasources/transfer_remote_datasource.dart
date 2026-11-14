import 'dart:io';
import 'package:dio/dio.dart';
import '../../core/constants/api_constants.dart';
import '../models/remote_file_model.dart';
import 'dart:developer' as developer;

abstract class TransferRemoteDataSource {
  Future<List<RemoteFileModel>> getRemoteFiles(String token);

  Future<void> uploadFile({
    required String token,
    required String filePath,
    required CancelToken cancelToken,
    required Function(int sent, int total) onProgress,
  });

  Future<void> downloadFile({
    required String token,
    required String fileName,
    required String savePath,
    required int startByte,
    required CancelToken cancelToken,
    required Function(int received, int total) onProgress,
  });

  Future<void> deleteRemoteFile(String token, String fileName);
}

class TransferRemoteDataSourceImpl implements TransferRemoteDataSource {
  final Dio dio;

  TransferRemoteDataSourceImpl({required this.dio});

  @override
  Future<List<RemoteFileModel>> getRemoteFiles(String token) async {
    try {
      final response = await dio.get(
        '${ApiConstants.defaultBaseUrl}${ApiConstants.getFilesEndpoint}',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
          responseType: ResponseType.json,
        ),
      );

      developer.log('Get files response: ${response.data}');

      final List<RemoteFileModel> files = [];

      if (response.data is List) {
        for (var item in response.data) {
          if (item is String) {
            files.add(RemoteFileModel(name: item, size: 0));
          } else if (item is Map) {
            files.add(RemoteFileModel.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      } else if (response.data is Map) {
        final map = response.data as Map;
        final list = map['files'] ?? map['data'] ?? map['items'];
        if (list is List) {
          for (var item in list) {
            if (item is String) {
              files.add(RemoteFileModel(name: item, size: 0));
            } else if (item is Map) {
              files.add(RemoteFileModel.fromJson(Map<String, dynamic>.from(item)));
            }
          }
        }
      }
      return files;
    } on DioException catch (e) {
      developer.log('Error fetching files: ${e.message}');
      throw Exception('Failed to load files: ${e.message}');
    }
  }

  @override
  Future<void> uploadFile({
    required String token,
    required String filePath,
    required CancelToken cancelToken,
    required Function(int sent, int total) onProgress,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Local file does not exist: $filePath');
    }

    final fileName = file.uri.pathSegments.last;
    final totalSize = await file.length();

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
      ),
    });

    try {
      await dio.post(
        '${ApiConstants.defaultBaseUrl}${ApiConstants.uploadEndpoint}',
        data: formData,
        cancelToken: cancelToken,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
          sendTimeout: ApiConstants.sendTimeout,
        ),
        onSendProgress: (sent, total) {
          // If total is -1 (unknown chunked), use actual file size
          final reportedTotal = (total > 0) ? total : totalSize;
          onProgress(sent, reportedTotal);
        },
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        developer.log('Upload cancelled or paused by user');
        rethrow;
      }
      throw Exception('Upload failed: ${e.response?.data ?? e.message}');
    }
  }

  @override
  Future<void> downloadFile({
    required String token,
    required String fileName,
    required String savePath,
    required int startByte,
    required CancelToken cancelToken,
    required Function(int received, int total) onProgress,
  }) async {
    final file = File(savePath);

    // If starting from byte 0, delete any existing partial file
    if (startByte == 0 && await file.exists()) {
      await file.delete();
    }

    // Set HTTP Range header for resumable download (-C -)
    final headers = <String, dynamic>{
      'Authorization': 'Bearer $token',
    };

    if (startByte > 0) {
      headers['Range'] = 'bytes=$startByte-';
      developer.log('Resuming download for $fileName from byte: $startByte');
    }

    try {
      final response = await dio.get<ResponseBody>(
        '${ApiConstants.defaultBaseUrl}${ApiConstants.getFilesEndpoint}',
        queryParameters: {'file': fileName},
        cancelToken: cancelToken,
        options: Options(
          headers: headers,
          responseType: ResponseType.stream,
          receiveTimeout: ApiConstants.receiveTimeout,
        ),
      );

      final responseBody = response.data;
      if (responseBody == null) {
        throw Exception('Server returned empty response body');
      }

      // Determine total content length
      final contentLengthHeader = response.headers.value(Headers.contentLengthHeader);
      int contentLength = int.tryParse(contentLengthHeader ?? '0') ?? 0;
      final int totalLength = startByte + contentLength;

      // Open file stream in write/append mode
      final fileAccessMode = startByte > 0 ? FileMode.writeOnlyAppend : FileMode.writeOnly;
      final sink = file.openSync(mode: fileAccessMode);

      int currentDownloaded = startByte;

      try {
        await for (final chunk in responseBody.stream) {
          if (cancelToken.isCancelled) {
            break;
          }
          sink.writeFromSync(chunk);
          currentDownloaded += chunk.length;
          onProgress(currentDownloaded, totalLength > 0 ? totalLength : currentDownloaded);
        }
      } finally {
        await sink.close();
      }
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        developer.log('Download paused or cancelled');
        rethrow;
      }
      throw Exception('Download failed: ${e.message}');
    }
  }

  @override
  Future<void> deleteRemoteFile(String token, String fileName) async {
    try {
      await dio.delete(
        '${ApiConstants.defaultBaseUrl}${ApiConstants.deleteEndpoint}',
        queryParameters: {'file': fileName},
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
    } on DioException catch (e) {
      throw Exception('Delete failed: ${e.message}');
    }
  }
}
