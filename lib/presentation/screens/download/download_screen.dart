import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/file_utils.dart';
import '../../../domain/entities/remote_file.dart';
import '../../bloc/transfer/transfer_bloc.dart';
import '../../bloc/transfer/transfer_event.dart';
import '../../bloc/transfer/transfer_state.dart';
import '../../widgets/transfer_item_tile.dart';

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final _manualFileController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load remote files list from server
    context.read<TransferBloc>().add(LoadRemoteFiles());
  }

  @override
  void dispose() {
    _manualFileController.dispose();
    super.dispose();
  }

  void _downloadFile(RemoteFile file) {
    context.read<TransferBloc>().add(StartDownloadEvent(remoteFile: file));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Downloading ${file.name} in background...'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _downloadManual() {
    final fileName = _manualFileController.text.trim();
    if (fileName.isEmpty) return;

    final manualFile = RemoteFile(name: fileName);
    _downloadFile(manualFile);
    _manualFileController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Download Catalog / Reports'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh file list',
            onPressed: () {
              context.read<TransferBloc>().add(LoadRemoteFiles());
            },
          ),
        ],
      ),
      body: BlocBuilder<TransferBloc, TransferState>(
        builder: (context, state) {
          final activeDownloads = state.tasks
              .where((t) => t.isDownload && (t.isRunning || t.isPaused || t.isQueued))
              .toList();

          return RefreshIndicator(
            onRefresh: () async {
              context.read<TransferBloc>().add(LoadRemoteFiles());
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Manual File Download Card
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.download_rounded, color: AppColors.accent, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Download Specific File by Name',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _manualFileController,
                                decoration: const InputDecoration(
                                  hintText: 'e.g. photo.jpg, catalog.csv',
                                  isDense: true,
                                  contentPadding:
                                      EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: _downloadManual,
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              child: const Text('Download'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Active Downloads Section
                  if (activeDownloads.isNotEmpty) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Text(
                        'Active Background Downloads',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    ...activeDownloads.map((task) => TransferItemTile(task: task)),
                    const SizedBox(height: 12),
                  ],

                  // Remote Files on Server Section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Available on Server',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${state.remoteFiles.length} file${state.remoteFiles.length != 1 ? "s" : ""}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (state.isLoadingFiles)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (state.remoteFiles.isEmpty)
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.folder_open_rounded, size: 40, color: AppColors.textMuted),
                          SizedBox(height: 10),
                          Text(
                            'No files found on server yet.',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Upload a catalog file from the Upload tab first or enter a file name above.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  else
                    ...state.remoteFiles.map(
                      (file) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              FileUtils.getFileIcon(file.name),
                              color: AppColors.accent,
                              size: 26,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    file.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  if (file.size > 0)
                                    Text(
                                      FileUtils.formatBytes(file.size),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.download_rounded),
                              color: AppColors.accent,
                              tooltip: 'Download',
                              onPressed: () => _downloadFile(file),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded),
                              color: AppColors.textMuted,
                              tooltip: 'Delete from server',
                              onPressed: () {
                                context
                                    .read<TransferBloc>()
                                    .add(DeleteRemoteFileEvent(fileName: file.name));
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Download History
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text(
                      'Download History',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),

                  ...state.tasks.where((t) => t.isDownload).map(
                        (task) => TransferItemTile(task: task),
                      ),

                  if (state.tasks.where((t) => t.isDownload).isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No downloads recorded yet.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
