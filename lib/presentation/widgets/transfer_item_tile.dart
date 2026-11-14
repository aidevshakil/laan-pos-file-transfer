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
        return AppColors.running;
      case TransferStatus.paused:
        return AppColors.paused;
      case TransferStatus.completed:
        return AppColors.success;
      case TransferStatus.failed:
        return AppColors.failed;
      case TransferStatus.queued:
        return AppColors.queued;
    }
  }

  String _getStatusText() {
    switch (task.status) {
      case TransferStatus.running:
        return task.isUpload ? 'Uploading...' : 'Downloading...';
      case TransferStatus.paused:
        return 'Paused';
      case TransferStatus.completed:
        return 'Completed';
      case TransferStatus.failed:
        return 'Failed';
      case TransferStatus.queued:
        return 'Queued';
    }
  }

  @override
  Widget build(BuildContext context) {
    final percent = (task.progress * 100).toInt();
    final statusColor = _getStatusColor();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  task.isUpload ? Icons.cloud_upload_rounded : Icons.cloud_download_rounded,
                  color: statusColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              // File info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getStatusText(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${FileUtils.formatBytes(task.transferredBytes)} / ${FileUtils.formatBytes(task.totalBytes)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (task.isRunning && task.speedBytesPerSec > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '• ${FileUtils.formatSpeed(task.speedBytesPerSec)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.accent,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (task.isRunning)
                    IconButton(
                      icon: const Icon(Icons.pause_circle_filled_rounded),
                      color: AppColors.paused,
                      tooltip: 'Pause',
                      onPressed: () {
                        context.read<TransferBloc>().add(
                              PauseTransferEvent(taskId: task.id),
                            );
                      },
                    ),
                  if (task.isPaused)
                    IconButton(
                      icon: const Icon(Icons.play_circle_filled_rounded),
                      color: AppColors.accent,
                      tooltip: 'Resume',
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
                      tooltip: 'Retry',
                      onPressed: () {
                        context.read<TransferBloc>().add(
                              RetryTransferEvent(taskId: task.id),
                            );
                      },
                    ),
                  if (task.isCompleted && task.isDownload)
                    IconButton(
                      icon: const Icon(Icons.folder_open_rounded),
                      color: AppColors.success,
                      tooltip: 'Open File',
                      onPressed: () async {
                        try {
                          await OpenFilex.open(task.localFilePath);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Cannot open file: $e')),
                          );
                        }
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    color: AppColors.textMuted,
                    tooltip: 'Remove',
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
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: task.progress > 0 ? task.progress : null,
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceMuted,
                      valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$percent%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
                color: AppColors.failed.withOpacity(0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.failed),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      task.errorMessage!,
                      style: const TextStyle(fontSize: 11, color: AppColors.failed),
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
