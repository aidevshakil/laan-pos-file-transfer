import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/file_utils.dart';
import '../../../domain/entities/transfer_task.dart';
import '../../bloc/transfer/transfer_bloc.dart';
import '../../bloc/transfer/transfer_event.dart';
import '../../bloc/transfer/transfer_state.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/decorations.dart';
import '../../widgets/transfer_item_tile.dart';

enum _Filter { all, ongoing, completed, failed }

class TransferCenterScreen extends StatefulWidget {
  const TransferCenterScreen({super.key});

  @override
  State<TransferCenterScreen> createState() => _TransferCenterScreenState();
}

class _TransferCenterScreenState extends State<TransferCenterScreen> {
  _Filter _filter = _Filter.all;

  List<TransferTask> _apply(TransferState s) => switch (_filter) {
        _Filter.all => s.tasks,
        _Filter.ongoing => s.activeTasks,
        _Filter.completed => s.completedTasks,
        _Filter.failed => s.failedTasks,
      };

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransferBloc, TransferState>(
      buildWhen: (a, b) => !identical(a.tasks, b.tasks),
      builder: (context, state) {
        final tasks = _apply(state);
        return PageBody(
          children: [
            ScreenHeader(title: 'Transfers', trailing: _BulkMenu(state: state)),
            if (state.hasActiveTransfers) ...[
              _SummaryCard(state: state),
              const SizedBox(height: 14),
            ],
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _chip(_Filter.all, 'All', state.tasks.length),
                  _chip(_Filter.ongoing, 'Ongoing', state.activeCount),
                  _chip(_Filter.completed, 'Completed', state.completedTasks.length),
                  _chip(_Filter.failed, 'Failed', state.failedTasks.length),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (tasks.isEmpty)
              EmptyState(
                icon: _filter == _Filter.failed ? Icons.verified_rounded : Icons.swap_vert_rounded,
                title: switch (_filter) {
                  _Filter.all => 'No transfers yet',
                  _Filter.ongoing => 'Nothing is transferring right now',
                  _Filter.completed => 'No completed transfers',
                  _Filter.failed => 'No failed transfers',
                },
                message: _filter == _Filter.all ? 'Start an upload or download from Home.' : null,
              )
            else
              ...tasks.map((t) => TransferItemTile(key: ValueKey(t.id), task: t)),
          ],
        );
      },
    );
  }

  Widget _chip(_Filter f, String label, int count) {
    final selected = _filter == f;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        selected: selected,
        showCheckmark: false,
        label: Text(count > 0 ? '$label ($count)' : label),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppColors.textSecondary,
        ),
        selectedColor: AppColors.primary,
        backgroundColor: AppColors.surface,
        shape: const StadiumBorder(),
        side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
        onSelected: (_) => setState(() => _filter = f),
      ),
    );
  }
}

class _BulkMenu extends StatelessWidget {
  final TransferState state;
  const _BulkMenu({required this.state});

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<TransferBloc>();
    final paused = state.tasks.any((t) => t.isPaused);
    final finished = state.tasks.any((t) => t.isCompleted || t.isFailed);
    return PopupMenuButton<String>(
      tooltip: 'Actions',
      icon: const Icon(Icons.tune_rounded, color: AppColors.primary),
      onSelected: (v) => switch (v) {
        'pause' => bloc.add(PauseAllTransfers()),
        'resume' => bloc.add(ResumeAllTransfers()),
        _ => bloc.add(ClearFinishedTransfers()),
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'pause',
          enabled: state.inFlightTasks.isNotEmpty,
          child: const ListTile(leading: Icon(Icons.pause_rounded), title: Text('Pause all')),
        ),
        PopupMenuItem(
          value: 'resume',
          enabled: paused,
          child: const ListTile(leading: Icon(Icons.play_arrow_rounded), title: Text('Resume all')),
        ),
        PopupMenuItem(
          value: 'clear',
          enabled: finished,
          child: const ListTile(leading: Icon(Icons.cleaning_services_outlined), title: Text('Clear finished')),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final TransferState state;
  const _SummaryCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final n = state.activeCount;
    final running = state.tasks.where((t) => t.isRunning).length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const GradientIcon(Icons.bar_chart_rounded, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$n transfer${n == 1 ? '' : 's'} in progress',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15.5),
                ),
                const SizedBox(height: 2),
                Text(
                  running > 0
                      ? '${(state.overallProgress * 100).floor()}% overall • ${FileUtils.formatSpeed(state.totalSpeed)}'
                      : 'Paused or waiting for network',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: state.overallProgress,
                    minHeight: 6,
                    color: const Color(0xFF7DA2FF),
                    backgroundColor: Colors.white12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
