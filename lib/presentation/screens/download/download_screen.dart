import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/app_navigation.dart';
import '../../../core/utils/file_utils.dart';
import '../../../domain/entities/remote_file.dart';
import '../../../domain/entities/transfer_task.dart';
import '../../bloc/transfer/transfer_bloc.dart';
import '../../bloc/transfer/transfer_event.dart';
import '../../bloc/transfer/transfer_state.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/decorations.dart';
import '../../widgets/transfer_item_tile.dart';

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final _search = TextEditingController();
  bool _searching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    context.read<TransferBloc>().add(LoadRemoteFiles());
    AppNavigation.instance.currentTab.addListener(_onTabChanged);
  }

  void _onTabChanged() {
    if (AppNavigation.instance.currentTab.value == AppTab.download && mounted) {
      context.read<TransferBloc>().add(LoadRemoteFiles());
    }
  }

  @override
  void dispose() {
    AppNavigation.instance.currentTab.removeListener(_onTabChanged);
    _search.dispose();
    super.dispose();
  }

  void _reload() => context.read<TransferBloc>().add(LoadRemoteFiles());

  void _download(RemoteFile file) {
    context.read<TransferBloc>().add(StartDownloadEvent(remoteFile: file));
    showAppSnack(context, 'Downloading ${file.name} in the background…');
  }

  Future<void> _confirmDelete(RemoteFile file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete from server?'),
        content: Text('"${file.name}" will be permanently removed from the server. '
            'Copies already downloaded to this device are kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      context.read<TransferBloc>().add(DeleteRemoteFileEvent(fileName: file.name));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransferBloc, TransferState>(
      builder: (context, state) {
        if (state.filesError != null && state.remoteFiles.isEmpty && !state.isLoadingFiles) {
          return _ErrorView(message: state.filesError!, onRetry: _reload);
        }

        final q = _query.toLowerCase();
        final files = state.remoteFiles.where((f) => f.name.toLowerCase().contains(q)).toList();
        final downloads = state.tasks.where((t) => t.isDownload).toList();
        final active = downloads.where((t) => t.isActive).toList();
        final recent = downloads.where((t) => !t.isActive).take(6).toList();

        return PageBody(
          onRefresh: () async {
            final bloc = context.read<TransferBloc>()..add(LoadRemoteFiles());
            await bloc.stream.firstWhere((s) => !s.isLoadingFiles);
          },
          children: [
            ScreenHeader(
              title: 'Download Files',
              showBack: true,
              trailing: IconButton(
                tooltip: _searching ? 'Close search' : 'Search',
                icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
                onPressed: () => setState(() {
                  _searching = !_searching;
                  if (!_searching) {
                    _search.clear();
                    _query = '';
                  }
                }),
              ),
            ),
            if (_searching) ...[
              TextField(
                controller: _search,
                autofocus: true,
                onChanged: (v) => setState(() => _query = v.trim()),
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search server files',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (state.filesError != null) ...[
              InlineMessage.error(
                state.filesError!,
                action: TextButton(onPressed: _reload, child: const Text('Retry')),
              ),
              const SizedBox(height: 12),
            ],
            if (active.isNotEmpty) ...[
              ...active.map((t) => TransferItemTile(key: ValueKey(t.id), task: t)),
              const SizedBox(height: 4),
            ],
            if (state.isLoadingFiles && state.remoteFiles.isEmpty)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (files.isEmpty)
              EmptyState(
                icon: _query.isEmpty ? Icons.cloud_off_rounded : Icons.search_off_rounded,
                title: _query.isEmpty ? 'No files on the server yet' : 'No file matches "$_query"',
                message: _query.isEmpty
                    ? 'Upload a file first and it will show up here.'
                    : 'You can still try downloading it by its exact name.',
                action: _query.isEmpty
                    ? OutlinedButton.icon(
                        onPressed: () => AppNavigation.instance.goTo(AppTab.upload),
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Go to Upload'),
                      )
                    : FilledButton.icon(
                        onPressed: () => _download(RemoteFile(name: _query)),
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Download by name'),
                      ),
              )
            else
              ...files.map((f) => _RemoteFileCard(
                    key: ValueKey(f.name),
                    file: f,
                    task: state.latestDownloadFor(f.name),
                    onDownload: () => _download(f),
                    onDelete: () => _confirmDelete(f),
                  )),
            if (recent.isNotEmpty) ...[
              SectionTitle(
                'Recent downloads',
                action: TextButton(
                  onPressed: () => AppNavigation.instance.goTo(AppTab.transfers),
                  child: const Text('See all'),
                ),
              ),
              ...recent.map((t) => TransferItemTile(key: ValueKey(t.id), task: t)),
            ],
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Files are saved to Download/LAAN POS',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          ],
        );
      },
    );
  }
}

class FileTypeStyle {
  final IconData icon;
  final Color color;
  const FileTypeStyle(this.icon, this.color);

  factory FileTypeStyle.of(String name) {
    final icon = FileUtils.getFileIcon(name);
    switch (FileUtils.extension(name)) {
      case 'csv':
      case 'xls':
      case 'xlsx':
        return FileTypeStyle(icon, AppColors.success);
      case 'pdf':
        return FileTypeStyle(icon, AppColors.violet);
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'webp':
        return FileTypeStyle(icon, const Color(0xFFF59E0B));
      case 'mp4':
      case 'mov':
      case 'mkv':
      case 'avi':
      case 'webm':
        return FileTypeStyle(icon, AppColors.danger);
      default:
        return FileTypeStyle(icon, AppColors.primary);
    }
  }
}

class _RemoteFileCard extends StatelessWidget {
  final RemoteFile file;
  final TransferTask? task;
  final VoidCallback onDownload;
  final VoidCallback onDelete;

  const _RemoteFileCard({
    super.key,
    required this.file,
    required this.task,
    required this.onDownload,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final type = FileTypeStyle.of(file.name);
    final meta = <String>[
      if (file.size > 0) FileUtils.formatBytes(file.size),
      if (file.modifiedTime != null) DateFormat('MMM d, y').format(file.modifiedTime!),
    ].join(' • ');
    final t = task;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
          child: Row(
            children: [
              FileBadge(
                icon: type.icon,
                color: type.color,
                background: type.color.withValues(alpha: 0.12),
                size: 50,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                    ),
                    if (meta.isNotEmpty || (t != null && !t.isActive))
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          t?.isCompleted == true
                              ? 'Downloaded${meta.isEmpty ? '' : ' • $meta'}'
                              : t?.isFailed == true
                                  ? 'Last download failed'
                                  : meta,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: t?.isCompleted == true
                                ? AppColors.success
                                : t?.isFailed == true
                                    ? AppColors.danger
                                    : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    _action(context),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'More',
                icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted),
                onSelected: (v) => v == 'delete' ? onDelete() : onDownload(),
                itemBuilder: (_) => [
                  if (t?.isCompleted == true)
                    const PopupMenuItem(value: 'again', child: Text('Download again')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete from server', style: TextStyle(color: AppColors.danger)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(BuildContext context) {
    final t = task;
    if (t != null && t.isActive) {
      return Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: t.isRunning && t.totalBytes <= 0 ? null : t.progress,
                minHeight: 8,
                color: StatusStyle.of(t).color,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${t.percent}%',
            style: TextStyle(fontWeight: FontWeight.w800, color: StatusStyle.of(t).color),
          ),
        ],
      );
    }
    final small = FilledButton.styleFrom(
      minimumSize: const Size(0, 38),
      padding: const EdgeInsets.symmetric(horizontal: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
    );
    if (t != null && t.isCompleted) {
      return Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.tonalIcon(
          style: small,
          onPressed: () => OpenFilex.open(t.localFilePath),
          icon: const Icon(Icons.open_in_new_rounded, size: 16),
          label: const Text('Open'),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.icon(
        style: small,
        onPressed: onDownload,
        icon: const Icon(Icons.download_rounded, size: 18),
        label: const Text('Download'),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final m = message.toLowerCase();
    final offline = m.contains('connection') || m.contains('internet') || m.contains('timed out');
    return Stack(
      children: [
        const Align(alignment: Alignment.bottomCenter, child: WaveBackdrop(height: 110)),
        SafeArea(
          child: Column(
            children: [
              const ScreenHeader(title: 'Download Files', showBack: true),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 110),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: HaloIllustration(
                              icon: offline ? Icons.wifi_rounded : Icons.cloud_off_rounded,
                              badge: Icons.error_rounded,
                              size: 150,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            offline ? 'No Internet Connection' : "Couldn't load files",
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14.5, color: AppColors.textSecondary, height: 1.4),
                          ),
                          const SizedBox(height: 28),
                          FilledButton(onPressed: onRetry, child: const Text('Retry')),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: () => AppNavigation.instance.goTo(AppTab.home),
                            child: const Text('Go Back'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
