import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../bloc/transfer/transfer_bloc.dart';
import '../../bloc/transfer/transfer_state.dart';
import '../../widgets/persistent_transfer_banner.dart';
import '../download/download_screen.dart';
import '../transfer_center/transfer_center_screen.dart';
import '../upload/upload_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    UploadScreen(),
    DownloadScreen(),
    TransferCenterScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isLandscapeOrTablet = MediaQuery.of(context).size.width >= 720;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ==========================================
            // TOP POS TERMINAL DIAGNOSTIC HEADER
            // ==========================================
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.posDarkHeader,
                border: Border(
                  bottom: BorderSide(color: Color(0xFF334155), width: 1),
                ),
              ),
              child: Row(
                children: [
                  // POS Logo & Mode
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.posAccent.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.posAccent, width: 1),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.point_of_sale_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'LAAN POS',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Terminal ID & Operator Pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'TERM: #104 • OP: CASHIER-01',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Mock Server Endpoint indicator
                  if (MediaQuery.of(context).size.width >= 600)
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.dns_rounded,
                            size: 12,
                            color: Color(0xFF38BDF8),
                          ),
                          SizedBox(width: 5),
                          Text(
                            ApiConstants.defaultBaseUrl,
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Live Cloud Sync Status Pill
                  BlocBuilder<TransferBloc, TransferState>(
                    builder: (context, state) {
                      final hasActive = state.hasActiveTransfers;
                      final count = state.activeCount;

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: hasActive
                              ? AppColors.posAccent.withValues(alpha: 0.2)
                              : AppColors.posOnline.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: hasActive
                                ? AppColors.posAccent
                                : AppColors.posOnline,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: hasActive
                                    ? AppColors.posAccent
                                    : AppColors.posOnline,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              hasActive ? 'SYNCING ($count)' : 'ONLINE / IDLE',
                              style: TextStyle(
                                color: hasActive
                                    ? Colors.white
                                    : AppColors.posOnline,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // ==========================================
            // MAIN BODY: POS SIDEBAR + WORKSPACE
            // ==========================================
            Expanded(
              child: isLandscapeOrTablet
                  ? Row(
                      children: [
                        // Left POS Sidebar Navigation
                        _buildPosSidebar(),
                        // Center Screen Content
                        Expanded(
                          child: Stack(
                            children: [
                              IndexedStack(
                                index: _currentIndex,
                                children: _screens,
                              ),
                              const Positioned(
                                left: 0,
                                right: 0,
                                bottom: 0,
                                child: PersistentTransferBanner(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Stack(
                      children: [
                        IndexedStack(index: _currentIndex, children: _screens),
                        const Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: PersistentTransferBanner(),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      // POS Handheld Bottom Navigation (for portrait/compact screens)
      bottomNavigationBar: isLandscapeOrTablet
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: AppColors.posDarkHeader,
                border: Border(
                  top: BorderSide(color: Color(0xFF334155), width: 1),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) =>
                    setState(() => _currentIndex = index),
                backgroundColor: AppColors.posDarkHeader,
                indicatorColor: AppColors.posAccent.withValues(alpha: 0.3),
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                destinations: [
                  const NavigationDestination(
                    icon: Icon(
                      Icons.upload_file_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                    selectedIcon: Icon(
                      Icons.upload_file_rounded,
                      color: Colors.white,
                    ),
                    label: 'Catalog Ingest',
                  ),
                  const NavigationDestination(
                    icon: Icon(
                      Icons.download_for_offline_rounded,
                      color: Color(0xFF94A3B8),
                    ),
                    selectedIcon: Icon(
                      Icons.download_for_offline_rounded,
                      color: Colors.white,
                    ),
                    label: 'Report Sync',
                  ),
                  NavigationDestination(
                    icon: BlocBuilder<TransferBloc, TransferState>(
                      builder: (context, state) {
                        return Badge(
                          isLabelVisible: state.hasActiveTransfers,
                          label: Text('${state.activeCount}'),
                          backgroundColor: AppColors.posAccent,
                          child: const Icon(
                            Icons.sync_alt_rounded,
                            color: Color(0xFF94A3B8),
                          ),
                        );
                      },
                    ),
                    selectedIcon: const Icon(
                      Icons.sync_alt_rounded,
                      color: Colors.white,
                    ),
                    label: 'Sync Console',
                  ),
                ],
              ),
            ),
    );
  }

  /// POS Left Sidebar (Square / Clover style)
  Widget _buildPosSidebar() {
    return Container(
      width: 220,
      color: AppColors.posSidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          _buildSidebarItem(
            index: 0,
            icon: Icons.upload_file_rounded,
            label: 'CATALOG INGEST',
            sublabel: 'Import CSV/Media >50MB',
          ),
          _buildSidebarItem(
            index: 1,
            icon: Icons.download_for_offline_rounded,
            label: 'REPORT SYNC',
            sublabel: 'Audit & Backup Download',
          ),
          BlocBuilder<TransferBloc, TransferState>(
            builder: (context, state) {
              return _buildSidebarItem(
                index: 2,
                icon: Icons.sync_alt_rounded,
                label: 'SYNC CONSOLE',
                sublabel: 'Background Transfers',
                badgeCount: state.activeCount,
              );
            },
          ),
          const Spacer(),
          // POS Terminal Storage Telemetry Footer
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TERMINAL STORAGE',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Sensible /Download',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required int index,
    required IconData icon,
    required String label,
    required String sublabel,
    int? badgeCount,
  }) {
    final isSelected = _currentIndex == index;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.posAccent : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => setState(() => _currentIndex = index),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : const Color(0xFFE2E8F0),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      Text(
                        sublabel,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.8)
                              : const Color(0xFF64748B),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                if (badgeCount != null && badgeCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black26 : AppColors.posAccent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
