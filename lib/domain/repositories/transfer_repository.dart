import '../entities/remote_file.dart';
import '../entities/upload_result.dart';

abstract class TransferRepository {
  Future<List<RemoteFile>> getRemoteFiles();

  Future<UploadResult> uploadFile({
    required String taskId,
    required String filePath,
    required String fileName,
    required void Function(int sentBytes, int totalBytes) onProgress,
  });

  Future<void> downloadFile({
    required String taskId,
    required String remoteName,
    required String partialPath,
    required void Function(int receivedBytes, int totalBytes) onProgress,
    String? url,
  });

  void abort(String taskId);

  Future<void> deleteRemoteFile(String fileName);
}
