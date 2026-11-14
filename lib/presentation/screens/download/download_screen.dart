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
        content: Text('Syncing ${file.name} to POS terminal storage in background...'),
        backgroundColor: AppColors.posAccent,
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
    return BlocBuilder<TransferBloc, TransferState>(
      builder: (context, state) {
        final activeDownloads = state.tasks
            .where((t) => t.isDownload && (t.isRunning || t.isPaused || t.isQueued))
            .toList();

        return Scaffold(
          backgroundColor: AppColors.background,
          body: RefreshIndicator(
            onRefresh: () async {
              context.read<TransferBloc>().add(LoadRemoteFiles());
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // POS Section Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.posDarkHeader,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.download_for_offline_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AUDIT REPOSITORY & CATALOG SYNC',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.3,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Fetch previously uploaded catalogs, daily sales logs & audit data',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: 'Query Server Repository',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: AppColors.border),
                        ),
                        onPressed: () {
                          context.read<TransferBloc>().add(LoadRemoteFiles());
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // MANUAL FILE FETCH SEARCH BAR (POS STYLE)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border, width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'DIRECT FILE IDENTIFIER LOOKUP',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _manualFileController,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: const InputDecoration(
                                  hintText: 'Enter file name (e.g. catalog.csv, photo.jpg)',
                                  prefixIcon: Icon(Icons.search_rounded, size: 20),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.download_rounded, size: 16),
                              label: const Text('FETCH FILE'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                              ),
                              onPressed: _downloadManual,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ACTIVE POS DOWNLOADS STREAM
                  if (activeDownloads.isNotEmpty) ...[
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.posAccent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ACTIVE INCOMING DOWNLOADS (${activeDownloads.length})',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...activeDownloads.map((task) => TransferItemTile(task: task)),
                    const SizedBox(height: 16),
                  ],

                  // SERVER INVENTORY TABLE HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'CLOUD REPOSITORY FILES',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          '${state.remoteFiles.length} REPOSITORIES FOUND',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // FILE LIST OR EMPTY STATE
                  if (state.isLoadingFiles)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text(
                              'Querying server file registry...',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (state.remoteFiles.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 36, color: AppColors.textMuted),
                          SizedBox(height: 10),
                          Text(
                            'No repository files found on server.',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Upload a catalog from the Ingest tab or fetch by exact filename.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    )
                  else
                    ...state.remoteFiles.map(
                      (file) => Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border, width: 1.2),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppColors.borderLight),
                              ),
                              child: Icon(
                                FileUtils.getFileIcon(file.name),
                                color: AppColors.posAccent,
                                size: 22,
                              ),
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
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      fontFamily: 'monospace',
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFECFDF5),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                        child: const Text(
                                          'RESUMABLE (RANGE -C -)',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.posOnline,
                                          ),
                                        ),
                                      ),
                                      if (file.size > 0) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          FileUtils.formatBytes(file.size),
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.download_rounded, size: 16),
                              label: const Text('SYNC'),
                              style: ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                backgroundColor: AppColors.posAccent,
                              ),
                              onPressed: () => _downloadFile(file),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 20),
                              color: AppColors.textMuted,
                              tooltip: 'Delete file from cloud',
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

                  const SizedBox(height: 20),

                  // DOWNLOAD HISTORY TABLE
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'DOWNLOAD AUDIT LOG',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'TOTAL: ${state.tasks.where((t) => t.isDownload).length} JOBS',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (state.tasks.where((t) => t.isDownload).isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Center(
                        child: Text(
                          'No downloads performed yet.',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                  else
                    ...state.tasks
                        .where((t) => t.isDownload)
                        .map((task) => TransferItemTile(task: task)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
