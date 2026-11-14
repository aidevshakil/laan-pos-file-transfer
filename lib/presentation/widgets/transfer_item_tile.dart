import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/file_utils.dart';
import '../../domain/entities/transfer_task.dart';
import '../bloc/transfer/transfer_bloc.dart';
import '../bloc/transfer/transfer_event.dart';

class TransferItemTile extends StatelessWidget {
  final TransferTask task;

  const TransferItemTile({super.key, required this.task});

  Color _getStatusColor() {
    switch (task.status) {
      case TransferStatus.running:
        return AppColors.posAccent;
      case TransferStatus.paused:
        return AppColors.paused;
      case TransferStatus.completed:
        return AppColors.posOnline;
      case TransferStatus.failed:
        return AppColors.failed;
      case TransferStatus.queued:
        return AppColors.queued;
    }
  }

  String _getStatusText() {
    switch (task.status) {
      case TransferStatus.running:
        return task.isUpload ? 'UPLOADING...' : 'DOWNLOADING...';
      case TransferStatus.paused:
        return 'FROZEN / PAUSED';
      case TransferStatus.completed:
        return 'SYNCED';
      case TransferStatus.failed:
        return 'FAILED';
      case TransferStatus.queued:
        return 'BUFFER QUEUED';
    }
  }

  @override
  Widget build(BuildContext context) {
    final percent = (task.progress * 100).toInt();
    final statusColor = _getStatusColor();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // POS Hardware Type Indicator
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Icon(
                  task.isUpload
                      ? Icons.upload_file_rounded
                      : Icons.download_for_offline_rounded,
                  color: statusColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              // Metadata
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        fontFamily: 'monospace',
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            _getStatusText(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${FileUtils.formatBytes(task.transferredBytes)} / ${FileUtils.formatBytes(task.totalBytes)}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (task.isRunning && task.speedBytesPerSec > 0) ...[
                          const SizedBox(width: 8),
                          Text(
                            '• ${FileUtils.formatSpeed(task.speedBytesPerSec)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: AppColors.posAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // POS Tactile Controls
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (task.isRunning)
                    IconButton(
                      icon: const Icon(Icons.pause_circle_filled_rounded),
                      color: AppColors.paused,
                      tooltip: 'Freeze / Pause',
                      onPressed: () {
                        context.read<TransferBloc>().add(
                          PauseTransferEvent(taskId: task.id),
                        );
                      },
                    ),
                  if (task.isPaused)
                    IconButton(
                      icon: const Icon(Icons.play_circle_filled_rounded),
                      color: AppColors.posAccent,
                      tooltip: 'Resume Pipe',
                      onPressed: () {
                        context.read<TransferBloc>().add(
                          ResumeTransferEvent(taskId: task.id),
                        );
                      },
                    ),
                  if (task.isFailed)
                    IconButton(
                      icon: const Icon(Icons.replay_rounded),
                      color: AppColors.failed,
                      tooltip: 'Retry Transmission',
                      onPressed: () {
                        context.read<TransferBloc>().add(
                          RetryTransferEvent(taskId: task.id),
                        );
                      },
                    ),
                  if (task.isCompleted && task.isDownload)
                    IconButton(
                      icon: const Icon(Icons.folder_open_rounded),
                      color: AppColors.posOnline,
                      tooltip: 'Inspect File in Storage',
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await OpenFilex.open(task.localFilePath);
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Cannot open file: $e')),
                          );
                        }
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: AppColors.textMuted,
                    tooltip: 'Terminate Pipe',
                    onPressed: () {
                      context.read<TransferBloc>().add(
                        CancelTransferEvent(taskId: task.id),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          if (task.isRunning || task.isPaused) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: task.progress > 0 ? task.progress : null,
                      minHeight: 5,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$percent%',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ],
          if (task.isFailed && task.errorMessage != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: AppColors.failed,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'PIPE ERROR: ${task.errorMessage}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.failed,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
