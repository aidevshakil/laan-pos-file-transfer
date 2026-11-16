import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/file_utils.dart';
import '../../bloc/transfer/transfer_bloc.dart';
import '../../bloc/transfer/transfer_state.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/decorations.dart';

class DownloadCompleteScreen extends StatelessWidget {
  final String taskId;
  const DownloadCompleteScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: BlocBuilder<TransferBloc, TransferState>(
        builder: (context, state) {
          final task = state.tasks.where((t) => t.id == taskId).firstOrNull;
          return Stack(
            children: [
              const Align(alignment: Alignment.bottomCenter, child: WaveBackdrop(height: 140)),
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 140),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: _Celebration()),
                          const SizedBox(height: 24),
                          Text(
                            task == null ? 'Download not found' : 'Download Complete!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 10),
                          if (task != null) ...[
                            Text(
                              task.fileName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${FileUtils.formatBytes(task.totalBytes)} • saved to '
                              '${FileUtils.friendlyDirectory(task.localFilePath)}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                          ] else
                            const Text(
                              'This transfer was removed from the history.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          const SizedBox(height: 32),
                          if (task != null && task.isCompleted)
                            FilledButton.icon(
                              onPressed: () async {
                                final r = await OpenFilex.open(task.localFilePath);
                                if (r.type != ResultType.done && context.mounted) {
                                  showAppSnack(context, 'No app found to open this file.', error: true);
                                }
                              },
                              icon: const Icon(Icons.open_in_new_rounded),
                              label: const Text('Open File'),
                            ),
                          const SizedBox(height: 12),
                          FilledButton.tonal(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Done'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Celebration extends StatelessWidget {
  const _Celebration();

  @override
  Widget build(BuildContext context) {
    const colors = [AppColors.primary, AppColors.violet, Color(0xFFF59E0B), AppColors.success, AppColors.danger];
    return SizedBox(
      width: 200,
      height: 170,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < 14; i++)
            Transform.translate(
              offset: Offset(
                math.cos(i * 0.9) * (80 + (i % 3) * 8),
                math.sin(i * 0.9) * (68 + (i % 2) * 6),
              ),
              child: Transform.rotate(
                angle: i * 0.7,
                child: Container(
                  width: i.isEven ? 8 : 10,
                  height: i.isEven ? 8 : 4,
                  decoration: BoxDecoration(
                    color: colors[i % colors.length],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success.withValues(alpha: 0.12),
            ),
          ),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.success,
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(Icons.check_rounded, color: Colors.white, size: 58),
          ),
        ],
      ),
    );
  }
}
