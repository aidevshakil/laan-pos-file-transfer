import 'package:dio/dio.dart';

import '../../core/errors/transfer_exception.dart';
import '../../domain/entities/remote_file.dart';
import '../../domain/entities/upload_result.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/transfer_repository.dart';
import '../datasources/transfer_remote_datasource.dart';

class TransferRepositoryImpl implements TransferRepository {
  final TransferRemoteDataSource remoteDataSource;
  final AuthRepository authRepository;

  final Map<String, CancelToken> _cancelTokens = {};

  TransferRepositoryImpl({
    required this.remoteDataSource,
    required this.authRepository,
  });

  Future<String> _token() async {
    final token = await authRepository.getSavedToken();
    if (token == null || token.isEmpty) {
      throw const TransferException(
        TransferErrorKind.unauthorized,
        'You are not logged in. Please log in again.',
      );
    }
    return token;
  }

  Future<T> _tracked<T>(String taskId, Future<T> Function(CancelToken) run) async {
    final cancelToken = CancelToken();
    _cancelTokens[taskId] = cancelToken;
    try {
      return await run(cancelToken);
    } finally {
      if (identical(_cancelTokens[taskId], cancelToken)) _cancelTokens.remove(taskId);
    }
  }

  @override
  Future<List<RemoteFile>> getRemoteFiles() async =>
      remoteDataSource.getRemoteFiles(await _token());

  @override
  Future<UploadResult> uploadFile({
    required String taskId,
    required String filePath,
    required String fileName,
    required void Function(int, int) onProgress,
  }) async {
    final token = await _token();
    return _tracked(
      taskId,
      (ct) => remoteDataSource.uploadFile(
        token: token,
        filePath: filePath,
        fileName: fileName,
        cancelToken: ct,
        onProgress: onProgress,
      ),
    );
  }

  @override
  Future<void> downloadFile({
    required String taskId,
    required String remoteName,
    required String partialPath,
    required void Function(int, int) onProgress,
    String? url,
  }) async {
    final token = await _token();
    return _tracked(
      taskId,
      (ct) => remoteDataSource.downloadFile(
        token: token,
        remoteName: remoteName,
        partialPath: partialPath,
        cancelToken: ct,
        onProgress: onProgress,
        url: url,
      ),
    );
  }

  @override
  void abort(String taskId) => _cancelTokens.remove(taskId)?.cancel('aborted');

  @override
  Future<void> deleteRemoteFile(String fileName) async =>
      remoteDataSource.deleteRemoteFile(await _token(), fileName);
}
