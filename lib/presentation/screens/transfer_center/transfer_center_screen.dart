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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Transfer Operations Center'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
            Tab(text: 'Failed / Paused'),
          ],
        ),
      ),
      body: BlocBuilder<TransferBloc, TransferState>(
        builder: (context, state) {
          final activeTasks = state.activeTasks;
          final completedTasks =
              state.tasks.where((t) => t.isCompleted).toList();
          final failedOrPausedTasks =
              state.tasks.where((t) => t.isFailed || t.isPaused).toList();

          return Column(
            children: [
              // Summary Metrics Header
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    _buildMetricCard(
                      'Active',
                      '${activeTasks.length}',
                      AppColors.running,
                    ),
                    _buildDivider(),
                    _buildMetricCard(
                      'Completed',
                      '${completedTasks.length}',
                      AppColors.success,
                    ),
                    _buildDivider(),
                    _buildMetricCard(
                      'Issues',
                      '${failedOrPausedTasks.length}',
                      AppColors.failed,
                    ),
                  ],
                ),
              ),

              // Tab views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Active Tasks Tab
                    _buildTaskList(
                      activeTasks,
                      emptyMessage: 'No background transfers currently running.',
                      emptyIcon: Icons.check_circle_outline_rounded,
                      actionButtons: activeTasks.isNotEmpty
                          ? Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.pause_rounded, size: 16),
                                    label: const Text('Pause All'),
                                    onPressed: () {
                                      for (var t in activeTasks) {
                                        if (t.isRunning) {
                                          context
                                              .read<TransferBloc>()
                                              .add(PauseTransferEvent(taskId: t.id));
                                        }
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 10),
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.play_arrow_rounded, size: 16),
                                    label: const Text('Resume All'),
                                    onPressed: () {
                                      for (var t in activeTasks) {
                                        if (t.isPaused) {
                                          context
                                              .read<TransferBloc>()
                                              .add(ResumeTransferEvent(taskId: t.id));
                                        }
                                      }
                                    },
                                  ),
                                ],
                              ),
                            )
                          : null,
                    ),

                    // Completed Tasks Tab
                    _buildTaskList(
                      completedTasks,
                      emptyMessage: 'No completed transfers yet.',
                      emptyIcon: Icons.cloud_done_rounded,
                    ),

                    // Failed or Paused Tasks Tab
                    _buildTaskList(
                      failedOrPausedTasks,
                      emptyMessage: 'No failed or paused transfers.',
                      emptyIcon: Icons.thumb_up_alt_outlined,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 30,
      width: 1,
      color: AppColors.border,
    );
  }

  Widget _buildTaskList(
    List tasks, {
    required String emptyMessage,
    required IconData emptyIcon,
    Widget? actionButtons,
  }) {
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 12),
            Text(
              emptyMessage,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        if (actionButtons != null) actionButtons,
        ...tasks.map((task) => TransferItemTile(task: task)),
      ],
    );
  }
}
