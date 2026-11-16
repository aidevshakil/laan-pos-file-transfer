import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/file_utils.dart';
import '../../domain/entities/remote_file.dart';
import '../../domain/entities/transfer_task.dart';
import '../bloc/transfer/transfer_bloc.dart';
import '../bloc/transfer/transfer_event.dart';
import 'common_widgets.dart';

Future<bool> confirmCancelTransfer(BuildContext context, TransferTask task) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Cancel ${task.isUpload ? 'upload' : 'download'}?'),
      content: Text('"${task.fileName}" will stop and any partial data will be discarded.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep going')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Cancel transfer'),
        ),
      ],
    ),
  );
  return ok == true;
}

Future<void> openDownloadedFile(BuildContext context, TransferTask task) async {
  final result = await OpenFilex.open(task.localFilePath);
  if (result.type != ResultType.done && context.mounted) {
    showAppSnack(context, 'No app found to open this file (${result.message}).', error: true);
  }
}

class TransferItemTile extends StatelessWidget {
  final TransferTask task;

  const TransferItemTile({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final style = StatusStyle.of(task);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _StatusCircle(task: task, color: style.color),
                  const SizedBox(width: 12),
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
                            fontSize: 14.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _subtitle(style),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: task.isFailed ? AppColors.danger : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _PrimaryAction(task: task),
                  _MoreMenu(task: task),
                ],
              ),
              if (task.isActive) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 56, right: 14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: task.isRunning && task.totalBytes <= 0 ? null : task.progress,
                      minHeight: 6,
                      color: style.color,
                    ),
                  ),
                ),
              ],
              if (task.message != null && (task.isFailed || task.isRetrying || task.isPaused)) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: task.isFailed
                      ? InlineMessage.error(task.message!)
                      : task.isRetrying
                          ? InlineMessage.warning(task.message!)
                          : InlineMessage.info(task.message!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle(StatusStyle style) {
    final size = FileUtils.formatBytes(task.totalBytes);
    switch (task.status) {
      case TransferStatus.running:
        final parts = <String>['${task.percent}%'];
        final eta = task.eta;
        if (eta != null) {
          parts.add('${FileUtils.formatDuration(eta)} remaining');
        } else {
          parts.add('${FileUtils.formatBytes(task.transferredBytes)} of $size');
        }
        if (task.speedBytesPerSec > 0) parts.add(FileUtils.formatSpeed(task.speedBytesPerSec));
        return '${task.isUpload ? 'Uploading' : 'Downloading'} • ${parts.join(' • ')}';
      case TransferStatus.queued:
        return 'Waiting to start • $size';
      case TransferStatus.retrying:
        return 'Reconnecting • ${task.percent}%';
      case TransferStatus.paused:
        return 'Paused • ${task.percent}% of $size';
      case TransferStatus.completed:
        final when = FileUtils.timeAgo(task.completedAt ?? task.createdAt);
        final where = task.isUpload
            ? (task.remoteFileName != null && task.remoteFileName != task.fileName
                ? ' • on server as ${task.remoteFileName}'
                : '')
            : ' • ${FileUtils.friendlyDirectory(task.localFilePath)}';
        return '${task.isUpload ? 'Upload' : 'Download'} complete • $size • $when$where';
      case TransferStatus.failed:
        return '${task.isUpload ? 'Upload' : 'Download'} failed • Tap retry';
    }
  }
}

class _StatusCircle extends StatelessWidget {
  final TransferTask task;
  final Color color;
  const _StatusCircle({required this.task, required this.color});

  @override
  Widget build(BuildContext context) {
    final icon = switch (task.status) {
      TransferStatus.completed => Icons.check_rounded,
      TransferStatus.failed => Icons.priority_high_rounded,
      TransferStatus.retrying => Icons.wifi_off_rounded,
      TransferStatus.paused => Icons.pause_rounded,
      _ => task.isUpload ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
    };
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: task.isCompleted || task.isFailed ? color : color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: task.isCompleted || task.isFailed ? Colors.white : color, size: 22),
    );
  }
}

class _PrimaryAction extends StatelessWidget {
  final TransferTask task;
  const _PrimaryAction({required this.task});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<TransferBloc>();
    final (IconData, String, Color, VoidCallback)? a = switch (task.status) {
      TransferStatus.running || TransferStatus.queued || TransferStatus.retrying => (
          Icons.pause_rounded,
          'Pause',
          AppColors.primary,
          () => bloc.add(PauseTransferEvent(taskId: task.id)),
        ),
      TransferStatus.paused => (
          Icons.play_arrow_rounded,
          'Resume',
          AppColors.primary,
          () => bloc.add(ResumeTransferEvent(taskId: task.id)),
        ),
      TransferStatus.failed => (
          Icons.refresh_rounded,
          'Retry',
          AppColors.primary,
          () => bloc.add(RetryTransferEvent(taskId: task.id)),
        ),
      TransferStatus.completed when task.isUpload => (
          Icons.download_rounded,
          'Download this file',
          AppColors.violet,
          () {
            bloc.add(StartDownloadEvent(
              remoteFile: RemoteFile(name: task.remoteFileName ?? task.fileName, url: task.remoteUrl),
            ));
            showAppSnack(context, 'Downloading ${task.remoteFileName ?? task.fileName} in the background…');
          },
        ),
      TransferStatus.completed when task.isDownload => (
          Icons.open_in_new_rounded,
          'Open file',
          AppColors.success,
          () => openDownloadedFile(context, task),
        ),
      _ => null,
    };
    if (a == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: a.$2,
      onPressed: a.$4,
      style: IconButton.styleFrom(backgroundColor: a.$3.withValues(alpha: 0.1)),
      icon: Icon(a.$1, color: a.$3, size: 22),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  final TransferTask task;
  const _MoreMenu({required this.task});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<TransferBloc>();
    return PopupMenuButton<String>(
      tooltip: 'More',
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 20),
      onSelected: (v) async {
        switch (v) {
          case 'cancel':
            if (await confirmCancelTransfer(context, task)) {
              bloc.add(CancelTransferEvent(taskId: task.id));
            }
          case 'remove':
            bloc.add(CancelTransferEvent(taskId: task.id));
          case 'again':
            bloc.add(StartDownloadEvent(
              remoteFile: RemoteFile(name: task.remoteFileName ?? task.fileName),
            ));
        }
      },
      itemBuilder: (_) => [
        if (task.isCompleted && task.isDownload)
          const PopupMenuItem(value: 'again', child: Text('Download again')),
        if (task.isActive)
          const PopupMenuItem(
            value: 'cancel',
            child: Text('Cancel transfer', style: TextStyle(color: AppColors.danger)),
          )
        else
          const PopupMenuItem(value: 'remove', child: Text('Remove from list')),
      ],
    );
  }
}
