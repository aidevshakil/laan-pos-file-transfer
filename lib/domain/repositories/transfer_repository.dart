import '../entities/remote_file.dart';

abstract class TransferRepository {
  Future<List<RemoteFile>> getRemoteFiles();

  Future<void> uploadFile({
    required String taskId,
    required String filePath,
    required Function(int sentBytes, int totalBytes) onProgress,
  });

  Future<void> downloadFile({
    required String taskId,
    required String fileName,
    required String savePath,
    required int startByte,
    required Function(int receivedBytes, int totalBytes) onProgress,
  });

  void pauseTransfer(String taskId);
  void cancelTransfer(String taskId);
  Future<void> deleteRemoteFile(String fileName);
}
