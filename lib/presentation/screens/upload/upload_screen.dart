import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/app_navigation.dart';
import '../../../core/utils/file_utils.dart';
import '../../../domain/entities/transfer_task.dart';
import '../../bloc/transfer/transfer_bloc.dart';
import '../../bloc/transfer/transfer_event.dart';
import '../../bloc/transfer/transfer_state.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/decorations.dart';
import '../../widgets/transfer_item_tile.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _SelectedFile {
  final String path;
  final String name;
  final int size;
  const _SelectedFile(this.path, this.name, this.size);

  bool get isImage => const {'jpg', 'jpeg', 'png', 'gif', 'webp'}.contains(FileUtils.extension(name));
}

class _UploadScreenState extends State<UploadScreen> {
  _SelectedFile? _selected;
  bool _busy = false;
  String _busyLabel = '';

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        onFileLoading: (status) {
          if (!mounted) return;
          setState(() {
            _busy = status == FilePickerStatus.picking;
            _busyLabel = 'Preparing file…';
          });
        },
      );
      if (!mounted) return;
      setState(() => _busy = false);
      final file = result?.files.singleOrNull;
      if (file == null) return;

      final error = await _validate(file.path, file.size);
      if (!mounted) return;
      if (error != null) {
        showAppSnack(context, error, error: true);
        return;
      }
      setState(() => _selected = _SelectedFile(file.path!, file.name, file.size));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showAppSnack(context, 'Could not open the file picker: $e', error: true);
    }
  }

  Future<String?> _validate(String? path, int size) async {
    if (path == null) return 'This file cannot be read. Try picking it from device storage.';
    if (!await File(path).exists()) return 'The selected file could not be found.';
    if (size <= 0) return 'The selected file is empty (0 bytes) and cannot be uploaded.';
    return null;
  }

  Future<void> _generateTestCatalog() async {
    setState(() {
      _busy = true;
      _busyLabel = 'Generating 50 MB test catalog…';
    });
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/product_catalog_50mb.csv';
      final sink = File(path).openWrite();
      sink.writeln('sku,barcode,product_name,category,price,stock_qty,tax_rate');
      const categories = ['Beverages', 'Snacks', 'Dairy', 'Bakery', 'Household', 'Personal Care'];
      final rnd = Random(42);
      const target = 50 * 1024 * 1024;
      var written = 0;
      var row = 0;
      while (written < target) {
        final buf = StringBuffer();
        for (var i = 0; i < 5000; i++, row++) {
          buf.write('SKU-${row.toString().padLeft(8, '0')},'
              '${880000000000 + row},'
              'Product item number $row,'
              '${categories[row % categories.length]},'
              '${(rnd.nextDouble() * 500 + 1).toStringAsFixed(2)},'
              '${rnd.nextInt(1000)},'
              '${rnd.nextBool() ? '5.0' : '15.0'}\n');
        }
        final chunk = buf.toString();
        sink.write(chunk);
        written += chunk.length;
        await Future<void>.delayed(Duration.zero);
      }
      await sink.close();
      final size = await File(path).length();
      if (!mounted) return;
      setState(() => _selected = _SelectedFile(path, 'product_catalog_50mb.csv', size));
    } catch (e) {
      if (mounted) showAppSnack(context, 'Could not create the test file: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _startUpload() {
    final file = _selected;
    if (file == null) return;
    context.read<TransferBloc>().add(
          StartUploadEvent(filePath: file.path, fileName: file.name, fileSize: file.size),
        );
    setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransferBloc, TransferState>(
      buildWhen: (a, b) => !identical(a.tasks, b.tasks),
      builder: (context, state) {
        final uploads = state.tasks.where((t) => t.isUpload).toList();
        final active = uploads.where((t) => t.isActive).toList();
        final featured = active.firstOrNull;
        final otherActive = active.skip(1).toList();
        final recent = uploads.where((t) => !t.isActive).take(6).toList();

        return PageBody(
          children: [
            ScreenHeader(
              title: 'Upload File',
              showBack: true,
              trailing: IconButton(
                tooltip: 'All transfers',
                icon: const Icon(Icons.swap_vert_rounded, color: AppColors.primary),
                onPressed: () => AppNavigation.instance.goTo(AppTab.transfers),
              ),
            ),
            _pickerCard(),
            if (_selected != null) ...[
              const SizedBox(height: 14),
              _selectedCard(_selected!),
            ],
            if (featured != null) ...[
              const SizedBox(height: 14),
              _UploadProgressCard(task: featured),
            ],
            const SizedBox(height: 14),
            const _BackgroundNote(),
            if (otherActive.isNotEmpty) ...[
              SectionTitle('Also uploading', count: '${otherActive.length}'),
              ...otherActive.map((t) => TransferItemTile(key: ValueKey(t.id), task: t)),
            ],
            if (recent.isNotEmpty) ...[
              SectionTitle(
                'Recent uploads',
                action: TextButton(
                  onPressed: () => AppNavigation.instance.goTo(AppTab.transfers),
                  child: const Text('See all'),
                ),
              ),
              ...recent.map((t) => TransferItemTile(key: ValueKey(t.id), task: t)),
            ],
          ],
        );
      },
    );
  }

  Widget _pickerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _busy ? null : _pickFile,
              child: DashedBorderBox(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: _busy
                      ? Column(
                          children: [
                            const SizedBox(
                              width: 34,
                              height: 34,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                            const SizedBox(height: 14),
                            Text(_busyLabel, style: const TextStyle(color: AppColors.textSecondary)),
                          ],
                        )
                      : const Column(
                          children: [
                            GradientIcon(Icons.cloud_upload_rounded, size: 62),
                            SizedBox(height: 14),
                            Text(
                              'Pick a File',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Supports images, videos & CSV\nLarge files (50 MB+) allowed',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _busy ? null : _pickFile,
              icon: const Icon(Icons.folder_open_rounded, size: 20),
              label: Text(_selected == null ? 'Choose File' : 'Choose Another File'),
            ),
            TextButton.icon(
              onPressed: _busy ? null : _generateTestCatalog,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('No large file? Create a 50 MB test CSV'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _selectedCard(_SelectedFile file) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: file.isImage
                      ? Image.file(
                          File(file.path),
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                          cacheWidth: 112,
                          errorBuilder: (_, _, _) => _fileBadge(file.name),
                        )
                      : _fileBadge(file.name),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        FileUtils.formatBytes(file.size),
                        style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  onPressed: () => setState(() => _selected = null),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.success),
              onPressed: _startUpload,
              icon: const Icon(Icons.cloud_upload_rounded, size: 20),
              label: const Text('Start Upload'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fileBadge(String name) => FileBadge(
        icon: FileUtils.getFileIcon(name),
        color: AppColors.primary,
        background: AppColors.primarySoft,
        size: 56,
      );
}

class _UploadProgressCard extends StatelessWidget {
  final TransferTask task;
  const _UploadProgressCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<TransferBloc>();
    final style = StatusStyle.of(task);
    final eta = task.eta;
    final detail = task.isRunning
        ? [
            '${FileUtils.formatBytes(task.transferredBytes)} of ${FileUtils.formatBytes(task.totalBytes)}',
            if (eta != null) '~${FileUtils.formatDuration(eta)} remaining',
          ].join(' • ')
        : (task.message ?? style.label);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                  ),
                ),
                const SizedBox(width: 8),
                StatusPill(task: task),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Upload Progress',
                    style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                ),
                Text(
                  '${task.percent}%',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: style.color),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: task.isRunning && task.totalBytes <= 0 ? null : task.progress,
                minHeight: 10,
                color: style.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              detail,
              style: TextStyle(
                fontSize: 12.5,
                color: task.isRetrying ? AppColors.warning : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: task.isPaused
                      ? _SoftButton(
                          icon: Icons.play_arrow_rounded,
                          label: 'Resume',
                          color: AppColors.primary,
                          onTap: () => bloc.add(ResumeTransferEvent(taskId: task.id)),
                        )
                      : _SoftButton(
                          icon: Icons.pause_rounded,
                          label: 'Pause',
                          color: AppColors.primary,
                          onTap: () => bloc.add(PauseTransferEvent(taskId: task.id)),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SoftButton(
                    icon: Icons.close_rounded,
                    label: 'Cancel',
                    color: AppColors.danger,
                    onTap: () async {
                      if (await confirmCancelTransfer(context, task)) {
                        bloc.add(CancelTransferEvent(taskId: task.id));
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SoftButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SoftButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackgroundNote extends StatelessWidget {
  const _BackgroundNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_rounded, color: AppColors.primary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'You can leave this screen or minimise the app.\n'
              'Uploads continue in the background and notify you when done.',
              style: TextStyle(color: AppColors.primaryDark, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
