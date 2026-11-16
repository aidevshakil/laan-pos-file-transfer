import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/app_navigation.dart';
import '../../../core/utils/file_utils.dart';
import '../../../domain/entities/transfer_task.dart';
import '../../bloc/transfer/transfer_bloc.dart';
import '../../bloc/transfer/transfer_state.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/decorations.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = AppNavigation.instance;
    return BlocBuilder<TransferBloc, TransferState>(
      buildWhen: (a, b) => !identical(a.tasks, b.tasks),
      builder: (context, state) {
        final recent = state.tasks.take(4).toList();
        return PageBody(
          children: [
            ScreenHeader(
              title: 'LAAN POS',
              subtitle: 'File Transfer Hub',
              trailing: _TransfersBell(count: state.activeCount),
            ),
            _HeroCard(state: state),
            const SectionTitle('Quick Actions'),
            Row(
              children: [
                Expanded(
                  child: _QuickAction(
                    icon: Icons.cloud_upload_rounded,
                    title: 'Upload File',
                    caption: 'Catalogs, media',
                    color: AppColors.primary,
                    background: AppColors.primarySoft,
                    onTap: () => nav.goTo(AppTab.upload),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickAction(
                    icon: Icons.download_rounded,
                    title: 'Download File',
                    caption: 'Reports, exports',
                    color: AppColors.violet,
                    background: AppColors.violetSoft,
                    onTap: () => nav.goTo(AppTab.download),
                  ),
                ),
              ],
            ),
            SectionTitle(
              'Recent Transfers',
              action: state.tasks.isEmpty
                  ? null
                  : TextButton.icon(
                      onPressed: () => nav.goTo(AppTab.transfers),
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text('View All'),
                    ),
            ),
            if (recent.isEmpty)
              const EmptyState(
                icon: Icons.swap_vert_rounded,
                title: 'No transfers yet',
                message: 'Upload a catalog or download a report to get started.',
              )
            else
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < recent.length; i++) ...[
                      if (i > 0) const Divider(indent: 68, endIndent: 16),
                      _RecentRow(task: recent[i]),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TransfersBell extends StatelessWidget {
  final int count;
  const _TransfersBell({required this.count});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Transfers',
      onPressed: () => AppNavigation.instance.goTo(AppTab.transfers),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        backgroundColor: AppColors.danger,
        child: const Icon(Icons.notifications_none_rounded, color: AppColors.primary),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final TransferState state;
  const _HeroCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final uploads = state.tasks.where((t) => t.isUpload && t.isCompleted).length;
    final downloads = state.tasks.where((t) => t.isDownload && t.isCompleted).length;
    final active = state.activeCount;
    final progress = state.overallProgress;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _HeroStat(
              icon: Icons.cloud_upload_rounded,
              value: '$uploads',
              label: 'Uploads',
              color: const Color(0xFF7DA2FF),
            ),
          ),
          SizedBox(
            width: 112,
            height: 112,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: active == 0 ? 1 : progress,
                    strokeWidth: 9,
                    strokeCap: StrokeCap.round,
                    color: active == 0 ? const Color(0xFF34D399) : const Color(0xFF7DA2FF),
                    backgroundColor: Colors.white12,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (active == 0)
                      const Icon(Icons.check_rounded, color: Colors.white, size: 30)
                    else
                      Text(
                        '${(progress * 100).floor()}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    Text(
                      active == 0 ? 'All synced' : '$active active',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _HeroStat(
              icon: Icons.download_rounded,
              value: '$downloads',
              label: 'Downloads',
              color: const Color(0xFFB3A6FF),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _HeroStat({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900),
        ),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String caption;
  final Color color;
  final Color background;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.title,
    required this.caption,
    required this.color,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
          child: Column(
            children: [
              Icon(icon, size: 38, color: color),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  final TransferTask task;
  const _RecentRow({required this.task});

  @override
  Widget build(BuildContext context) {
    final style = StatusStyle.of(task);
    final verb = switch (task.status) {
      TransferStatus.completed => task.isUpload ? 'Uploaded' : 'Downloaded',
      TransferStatus.failed => 'Failed',
      _ => '${style.label} ${task.percent}%',
    };
    return InkWell(
      onTap: () => AppNavigation.instance.goTo(AppTab.transfers),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: style.color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(
                task.isCompleted
                    ? Icons.check_rounded
                    : task.isFailed
                        ? Icons.priority_high_rounded
                        : (task.isUpload ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded),
                color: style.color,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$verb • ${FileUtils.formatBytes(task.totalBytes)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              FileUtils.timeAgo(task.completedAt ?? task.createdAt),
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
