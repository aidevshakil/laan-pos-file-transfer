import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../domain/entities/transfer_task.dart';

class PageBody extends StatelessWidget {
  final List<Widget> children;
  final Future<void> Function()? onRefresh;

  const PageBody({super.key, required this.children, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
    return onRefresh == null ? list : RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

class PageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const PageHeader({super.key, required this.title, required this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.35),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? count;
  final Widget? action;

  const SectionTitle(this.title, {super.key, this.count, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      count!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(color: AppColors.surfaceMuted, shape: BoxShape.circle),
              child: Icon(icon, size: 28, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            if (message != null) ...[
              const SizedBox(height: 4),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.35),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 14), action!],
          ],
        ),
      ),
    );
  }
}

class InlineMessage extends StatelessWidget {
  final String text;
  final Color color;
  final Color background;
  final IconData icon;
  final Widget? action;

  const InlineMessage({
    super.key,
    required this.text,
    required this.color,
    required this.background,
    required this.icon,
    this.action,
  });

  const InlineMessage.error(this.text, {super.key, this.action})
      : color = AppColors.danger,
        background = AppColors.dangerSoft,
        icon = Icons.error_outline_rounded;

  const InlineMessage.warning(this.text, {super.key, this.action})
      : color = AppColors.warning,
        background = AppColors.warningSoft,
        icon = Icons.wifi_off_rounded;

  const InlineMessage.info(this.text, {super.key, this.action})
      : color = AppColors.textSecondary,
        background = AppColors.surfaceMuted,
        icon = Icons.info_outline_rounded;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: color, height: 1.35)),
          ),
          ?action,
        ],
      ),
    );
  }
}

class StatusStyle {
  final String label;
  final Color color;
  final IconData icon;

  const StatusStyle(this.label, this.color, this.icon);

  factory StatusStyle.of(TransferTask t) {
    switch (t.status) {
      case TransferStatus.queued:
        return const StatusStyle('Waiting', AppColors.neutral, Icons.schedule_rounded);
      case TransferStatus.running:
        return StatusStyle(
          t.isUpload ? 'Uploading' : 'Downloading',
          AppColors.running,
          t.isUpload ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
        );
      case TransferStatus.retrying:
        return const StatusStyle('Reconnecting', AppColors.warning, Icons.wifi_off_rounded);
      case TransferStatus.paused:
        return const StatusStyle('Paused', AppColors.warning, Icons.pause_rounded);
      case TransferStatus.completed:
        return const StatusStyle('Completed', AppColors.success, Icons.check_circle_rounded);
      case TransferStatus.failed:
        return const StatusStyle('Failed', AppColors.danger, Icons.error_rounded);
    }
  }
}

class StatusPill extends StatelessWidget {
  final TransferTask task;
  const StatusPill({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final s = StatusStyle.of(task);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: s.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 12, color: s.color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              s.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: s.color),
            ),
          ),
        ],
      ),
    );
  }
}

class FileBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color background;
  final double size;

  const FileBadge({
    super.key,
    required this.icon,
    required this.color,
    required this.background,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

void showAppSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.danger : AppColors.ink,
    ));
}
