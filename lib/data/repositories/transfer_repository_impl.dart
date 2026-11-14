import 'package:dio/dio.dart';
import '../../domain/entities/remote_file.dart';
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

  Future<String> _getToken() async {
    final token = await authRepository.getSavedToken();
    if (token == null || token.isEmpty) {
      throw Exception('User is not authenticated. Please log in first.');
    }
    return token;
  }

  @override
  Future<List<RemoteFile>> getRemoteFiles() async {
    final token = await _getToken();
    return await remoteDataSource.getRemoteFiles(token);
  }

  @override
  Future<void> uploadFile({
    required String taskId,
    required String filePath,
    required Function(int sentBytes, int totalBytes) onProgress,
  }) async {
    final token = await _getToken();
    final cancelToken = CancelToken();
    _cancelTokens[taskId] = cancelToken;

    try {
      await remoteDataSource.uploadFile(
        token: token,
        filePath: filePath,
        cancelToken: cancelToken,
        onProgress: onProgress,
      );
    } finally {
      _cancelTokens.remove(taskId);
    }
  }

  @override
  Future<void> downloadFile({
    required String taskId,
    required String fileName,
    required String savePath,
    required int startByte,
    required Function(int receivedBytes, int totalBytes) onProgress,
  }) async {
    final token = await _getToken();
    final cancelToken = CancelToken();
    _cancelTokens[taskId] = cancelToken;

    try {
      await remoteDataSource.downloadFile(
        token: token,
        fileName: fileName,
        savePath: savePath,
        startByte: startByte,
        cancelToken: cancelToken,
        onProgress: onProgress,
      );
    } finally {
      _cancelTokens.remove(taskId);
    }
  }

  @override
  void pauseTransfer(String taskId) {
    if (_cancelTokens.containsKey(taskId)) {
      _cancelTokens[taskId]?.cancel('Paused by user');
      _cancelTokens.remove(taskId);
    }
  }

  @override
  void cancelTransfer(String taskId) {
    if (_cancelTokens.containsKey(taskId)) {
      _cancelTokens[taskId]?.cancel('Cancelled by user');
      _cancelTokens.remove(taskId);
    }
  }

  @override
  Future<void> deleteRemoteFile(String fileName) async {
    final token = await _getToken();
    await remoteDataSource.deleteRemoteFile(token, fileName);
  }
}
