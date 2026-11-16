import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/app_navigation.dart';
import '../../core/utils/file_utils.dart';
import '../bloc/transfer/transfer_bloc.dart';
import '../bloc/transfer/transfer_state.dart';

class PersistentTransferBanner extends StatelessWidget {
  const PersistentTransferBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransferBloc, TransferState>(
      buildWhen: (a, b) => !identical(a.tasks, b.tasks),
      builder: (context, state) {
        final active = state.activeTasks;
        return AnimatedSize(
          duration: const Duration(milliseconds: 200),
          child: active.isEmpty ? const SizedBox(width: double.infinity) : _banner(state),
        );
      },
    );
  }

  Widget _banner(TransferState state) {
    final active = state.activeTasks;
    final running = active.where((t) => t.isRunning).length;
    final reconnecting = active.where((t) => t.isRetrying).length;
    final paused = active.where((t) => t.isPaused).length;
    final percent = (state.overallProgress * 100).floor();

    final String headline;
    if (running > 0) {
      headline = '${active.length == 1 ? active.first.fileName : '${active.length} transfers'}'
          ' • $percent%';
    } else if (reconnecting > 0) {
      headline = 'Waiting for network…';
    } else {
      headline = '$paused transfer${paused == 1 ? '' : 's'} paused';
    }

    final detail = <String>[
      if (running > 0) FileUtils.formatSpeed(state.totalSpeed),
      if (reconnecting > 0) '$reconnecting reconnecting',
      if (paused > 0 && running > 0) '$paused paused',
    ].join(' • ');

    final color = running > 0
        ? AppColors.primary
        : (reconnecting > 0 ? AppColors.warning : AppColors.neutral);

    return Material(
      color: AppColors.ink,
      child: InkWell(
        onTap: () => AppNavigation.instance.goTo(AppTab.transfers),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(
              value: state.overallProgress,
              minHeight: 3,
              color: color,
              backgroundColor: Colors.white12,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
              child: Row(
                children: [
                  Icon(
                    running > 0 ? Icons.sync_rounded : Icons.pause_circle_outline_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headline,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                          ),
                        ),
                        if (detail.isNotEmpty)
                          Text(
                            detail,
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  const Text(
                    'View',
                    style: TextStyle(color: Color(0xFF93C5FD), fontWeight: FontWeight.w700),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF93C5FD)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
