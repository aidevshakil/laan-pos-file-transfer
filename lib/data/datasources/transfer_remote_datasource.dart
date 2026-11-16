import 'dart:developer' as developer;
import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/errors/transfer_exception.dart';
import '../../domain/entities/upload_result.dart';
import '../models/remote_file_model.dart';

typedef ProgressCallback = void Function(int done, int total);

abstract class TransferRemoteDataSource {
  Future<List<RemoteFileModel>> getRemoteFiles(String token);

  Future<UploadResult> uploadFile({
    required String token,
    required String filePath,
    required String fileName,
    required CancelToken cancelToken,
    required ProgressCallback onProgress,
  });

  Future<void> downloadFile({
    required String token,
    required String remoteName,
    required String partialPath,
    required CancelToken cancelToken,
    required ProgressCallback onProgress,
    String? url,
  });

  Future<void> deleteRemoteFile(String token, String fileName);
}

class TransferRemoteDataSourceImpl implements TransferRemoteDataSource {
  final Dio dio;

  TransferRemoteDataSourceImpl({required this.dio});

  Options _auth(String token, {ResponseType? responseType, Map<String, dynamic>? extra}) =>
      Options(
        headers: {'Authorization': 'Bearer $token', ...?extra},
        responseType: responseType,
      );

  @override
  Future<List<RemoteFileModel>> getRemoteFiles(String token) async {
    try {
      final response = await dio.get(
        ApiConstants.getFilesEndpoint,
        options: _auth(token, responseType: ResponseType.json),
      );
      final data = response.data;
      final list = data is List
          ? data
          : (data is Map ? (data['files'] ?? data['data'] ?? data['items']) : null);
      if (list is! List) return const [];
      return list
          .map<RemoteFileModel?>((item) {
            if (item is String) return RemoteFileModel(name: item);
            if (item is Map) return RemoteFileModel.fromJson(Map<String, dynamic>.from(item));
            return null;
          })
          .whereType<RemoteFileModel>()
          .toList();
    } catch (e) {
      throw TransferException.fromError(e);
    }
  }

  @override
  Future<UploadResult> uploadFile({
    required String token,
    required String filePath,
    required String fileName,
    required CancelToken cancelToken,
    required ProgressCallback onProgress,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw const TransferException(
        TransferErrorKind.invalidFile,
        'The selected file no longer exists on this device.',
      );
    }
    final totalSize = await file.length();
    if (totalSize == 0) {
      throw const TransferException(TransferErrorKind.invalidFile, 'The selected file is empty.');
    }

    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await dio.post(
        ApiConstants.uploadEndpoint,
        data: formData,
        cancelToken: cancelToken,
        options: _auth(token).copyWith(sendTimeout: ApiConstants.sendTimeout),
        onSendProgress: (sent, total) => onProgress(sent, total > 0 ? total : totalSize),
      );

      final data = response.data;
      if (data is Map && data['success'] == false) {
        throw TransferException(
          TransferErrorKind.invalidFile,
          TransferException.serverMessage(data) ?? 'The server rejected this file.',
        );
      }
      return UploadResult.fromResponse(data, fallbackName: fileName);
    } catch (e) {
      throw TransferException.fromError(e);
    }
  }

  @override
  Future<void> downloadFile({
    required String token,
    required String remoteName,
    required String partialPath,
    required CancelToken cancelToken,
    required ProgressCallback onProgress,
    String? url,
  }) async {
    final directUrl = url != null && (url.startsWith('http://') || url.startsWith('https://'));
    final partFile = File(partialPath);
    int startByte = await partFile.exists() ? await partFile.length() : 0;

    RandomAccessFile? raf;
    try {
      final Response<ResponseBody> response;
      try {
        response = await dio.get<ResponseBody>(
          directUrl ? url : ApiConstants.getFilesEndpoint,
          queryParameters: directUrl ? null : {'file': remoteName},
          cancelToken: cancelToken,
          options: _auth(
            token,
            responseType: ResponseType.stream,
            extra: startByte > 0 ? {'Range': 'bytes=$startByte-'} : null,
          ).copyWith(receiveTimeout: ApiConstants.receiveTimeout),
        );
      } on DioException catch (e) {
        if (e.response?.statusCode == 416 && startByte > 0) return;
        rethrow;
      }

      final body = response.data;
      if (body == null) {
        throw const TransferException(TransferErrorKind.server, 'Server returned an empty response.');
      }

      final contentLength = int.tryParse(response.headers.value(Headers.contentLengthHeader) ?? '') ?? -1;
      int total;
      if (response.statusCode == 206) {
        final range = response.headers.value('content-range');
        final totalFromRange = int.tryParse(range?.split('/').last ?? '');
        total = totalFromRange ?? (contentLength >= 0 ? startByte + contentLength : -1);
      } else {
        if (startByte > 0) {
          developer.log('Server ignored Range for $remoteName; restarting from 0');
        }
        startByte = 0;
        total = contentLength;
      }

      await partFile.parent.create(recursive: true);
      raf = await partFile.open(mode: startByte > 0 ? FileMode.append : FileMode.write);
      int received = startByte;
      onProgress(received, total);

      await for (final chunk in body.stream) {
        if (cancelToken.isCancelled) break;
        await raf.writeFrom(chunk);
        received += chunk.length;
        onProgress(received, total > 0 ? total : received);
      }

      if (cancelToken.isCancelled) throw TransferException.cancelled;
      if (total > 0 && received < total) {
        throw const TransferException(
          TransferErrorKind.noConnection,
          'Connection dropped before the download finished.',
        );
      }
    } catch (e) {
      if (cancelToken.isCancelled) throw TransferException.cancelled;
      throw TransferException.fromError(e);
    } finally {
      await raf?.close();
    }
  }

  @override
  Future<void> deleteRemoteFile(String token, String fileName) async {
    try {
      await dio.delete(
        ApiConstants.deleteEndpoint,
        queryParameters: {'file': fileName},
        options: _auth(token),
      );
    } catch (e) {
      throw TransferException.fromError(e);
    }
  }
}
