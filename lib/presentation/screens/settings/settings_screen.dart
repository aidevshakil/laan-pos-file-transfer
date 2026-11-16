import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/file_utils.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../../bloc/auth/auth_state.dart';
import '../../bloc/transfer/transfer_bloc.dart';
import '../../bloc/transfer/transfer_event.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/decorations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with WidgetsBindingObserver {
  bool? _batteryUnrestricted;
  String? _downloadDir;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final dir = await FileUtils.getDownloadDirectory();
      bool? battery;
      if (Platform.isAndroid) battery = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      if (!mounted) return;
      setState(() {
        _downloadDir = dir.path;
        _batteryUnrestricted = battery;
      });
    } catch (_) {}
  }

  Future<void> _logout() async {
    final transfers = context.read<TransferBloc>();
    final auth = context.read<AuthBloc>();
    final busy = transfers.state.inFlightTasks.isNotEmpty;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: Text(busy
            ? 'Transfers in progress will be paused. You can resume them after logging in again.'
            : 'You will need to log in again to upload or download files.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
        ],
      ),
    );
    if (ok != true) return;
    transfers.add(PauseAllTransfers());
    auth.add(LogoutRequested());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final username = auth is AuthAuthenticated && auth.username.isNotEmpty ? auth.username : 'Operator';

    return PageBody(
      children: [
        const ScreenHeader(title: 'Settings'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: const BoxDecoration(gradient: AppColors.brandGradient, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(
                    username[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        ApiConstants.defaultBaseUrl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SectionTitle('Background transfers'),
        _Group(children: [
          if (Platform.isAndroid)
            _Tile(
              icon: Icons.battery_charging_full_rounded,
              color: _batteryUnrestricted == true ? AppColors.success : AppColors.warning,
              title: 'Battery optimisation',
              subtitle: _batteryUnrestricted == true
                  ? 'Unrestricted — large transfers can run with the screen off.'
                  : 'Restricted. Some phones stop background transfers. Tap to allow unrestricted use.',
              onTap: _batteryUnrestricted == true
                  ? null
                  : () => FlutterForegroundTask.openIgnoreBatteryOptimizationSettings(),
            ),
          const _Tile(
            icon: Icons.sync_rounded,
            color: AppColors.primary,
            title: 'Auto-retry on poor network',
            subtitle: 'Up to 5 retries with back-off (2s → 30s). Downloads resume where they stopped.',
          ),
          const _Tile(
            icon: Icons.notifications_active_outlined,
            color: AppColors.violet,
            title: 'Notifications',
            subtitle: 'Progress while running, plus a notification when each transfer finishes.',
          ),
        ]),
        const SectionTitle('Storage'),
        _Group(children: [
          _Tile(
            icon: Icons.folder_rounded,
            color: const Color(0xFFF59E0B),
            title: 'Download folder',
            subtitle: _downloadDir == null ? 'Checking…' : FileUtils.friendlyDirectory('$_downloadDir/x'),
          ),
          _Tile(
            icon: Icons.cleaning_services_rounded,
            color: AppColors.neutral,
            title: 'Clear transfer history',
            subtitle: 'Removes completed and failed entries. Files on the device are kept.',
            onTap: () {
              context.read<TransferBloc>().add(ClearFinishedTransfers());
              showAppSnack(context, 'Finished transfers cleared.');
            },
          ),
        ]),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.dangerSoft, width: 1.5),
          ),
          onPressed: _logout,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Log out'),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Column(
            children: [
              GradientIcon(Icons.point_of_sale_rounded, size: 36),
              SizedBox(height: 8),
              Text('LAAN POS File Sync • v1.0.0', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 64),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _Tile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.35),
                  ),
                ],
              ),
            ),
            if (onTap != null) const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
