import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/file_utils.dart';
import '../../bloc/transfer/transfer_bloc.dart';
import '../../bloc/transfer/transfer_event.dart';
import '../../bloc/transfer/transfer_state.dart';
import '../../widgets/transfer_item_tile.dart';

class TransferCenterScreen extends StatefulWidget {
  const TransferCenterScreen({super.key});

  @override
  State<TransferCenterScreen> createState() => _TransferCenterScreenState();
}

class _TransferCenterScreenState extends State<TransferCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransferBloc, TransferState>(
      builder: (context, state) {
        final activeTasks = state.activeTasks;
        final completedTasks = state.tasks.where((t) => t.isCompleted).toList();
        final failedOrPausedTasks = state.tasks
            .where((t) => t.isFailed || t.isPaused)
            .toList();

        // Calculate total aggregate speed
        final totalSpeed = activeTasks.fold(
          0.0,
          (sum, t) => sum + (t.isRunning ? t.speedBytesPerSec : 0.0),
        );

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // POS Console Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.posDarkHeader,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.sync_alt_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TERMINAL DATA SYNC CONSOLE',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            'Background pipeline management, bandwidth monitoring & resilience',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // POS TELEMETRY HUD / METRICS GRID
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border, width: 1.2),
                  ),
                  child: Row(
                    children: [
                      _buildTelemetryCell(
                        title: 'ACTIVE PIPES',
                        value: '${activeTasks.length}',
                        caption: 'Background Jobs',
                        color: AppColors.posAccent,
                      ),
                      _buildDivider(),
                      _buildTelemetryCell(
                        title: 'BANDWIDTH',
                        value: FileUtils.formatSpeed(totalSpeed),
                        caption: 'Live Transfer Rate',
                        color: totalSpeed > 0
                            ? AppColors.posOnline
                            : AppColors.textSecondary,
                      ),
                      _buildDivider(),
                      _buildTelemetryCell(
                        title: 'COMPLETED',
                        value: '${completedTasks.length}',
                        caption: 'Synced Files',
                        color: AppColors.posOnline,
                      ),
                      _buildDivider(),
                      _buildTelemetryCell(
                        title: 'ATTENTION',
                        value: '${failedOrPausedTasks.length}',
                        caption: 'Paused / Failed',
                        color: failedOrPausedTasks.isNotEmpty
                            ? AppColors.failed
                            : AppColors.textMuted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // POS BULK CONTROLS BAR
                Row(
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(
                        Icons.pause_circle_outline_rounded,
                        size: 16,
                      ),
                      label: const Text('FREEZE ALL PIPES'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.posSidebar,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onPressed: activeTasks.isEmpty
                          ? null
                          : () {
                              for (var t in activeTasks) {
                                if (t.isRunning) {
                                  context.read<TransferBloc>().add(
                                    PauseTransferEvent(taskId: t.id),
                                  );
                                }
                              }
                            },
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      icon: const Icon(
                        Icons.play_circle_outline_rounded,
                        size: 16,
                      ),
                      label: const Text('RESUME ALL'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                      ),
                      onPressed: failedOrPausedTasks.isEmpty
                          ? null
                          : () {
                              for (var t in failedOrPausedTasks) {
                                if (t.isPaused) {
                                  context.read<TransferBloc>().add(
                                    ResumeTransferEvent(taskId: t.id),
                                  );
                                }
                              }
                            },
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // POS TAB BAR
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: Colors.white,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: AppColors.posDarkHeader,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    labelStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                    tabs: [
                      Tab(text: 'ACTIVE (${activeTasks.length})'),
                      Tab(text: 'COMPLETED ARCHIVE (${completedTasks.length})'),
                      Tab(
                        text: 'ISSUES / PAUSED (${failedOrPausedTasks.length})',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // TAB CONTENT
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTaskList(
                        activeTasks,
                        emptyMessage:
                            'No background transfers currently running.',
                      ),
                      _buildTaskList(
                        completedTasks,
                        emptyMessage: 'No completed sync jobs archived.',
                      ),
                      _buildTaskList(
                        failedOrPausedTasks,
                        emptyMessage:
                            'All pipes healthy. No errors or paused jobs.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTelemetryCell({
    required String title,
    required String value,
    required String caption,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontFamily: 'monospace',
              color: color,
            ),
          ),
          Text(
            caption,
            style: const TextStyle(fontSize: 9, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      height: 36,
      width: 1,
      color: AppColors.borderLight,
    );
  }

  Widget _buildTaskList(List tasks, {required String emptyMessage}) {
    if (tasks.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Center(
          child: Text(
            emptyMessage,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [...tasks.map((task) => TransferItemTile(task: task))],
    );
  }
}
