import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/app_navigation.dart';
import '../../bloc/transfer/transfer_bloc.dart';
import '../../bloc/transfer/transfer_state.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/persistent_transfer_banner.dart';
import '../download/download_complete_screen.dart';
import '../download/download_screen.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';
import '../transfer_center/transfer_center_screen.dart';
import '../upload/upload_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  static const _pages = {
    AppTab.home: HomeScreen(),
    AppTab.upload: UploadScreen(),
    AppTab.download: DownloadScreen(),
    AppTab.transfers: TransferCenterScreen(),
    AppTab.settings: SettingsScreen(),
  };
  static const _navTabs = [AppTab.home, AppTab.transfers, AppTab.settings];

  final _nav = AppNavigation.instance;

  @override
  void initState() {
    super.initState();
    _nav.completedDownload.addListener(_showCompleted);
    WidgetsBinding.instance.addPostFrameCallback((_) => _showCompleted());
  }

  @override
  void dispose() {
    _nav.completedDownload.removeListener(_showCompleted);
    super.dispose();
  }

  void _showCompleted() {
    final id = _nav.completedDownload.value;
    if (id == null || !mounted) return;
    _nav.completedDownload.value = null;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DownloadCompleteScreen(taskId: id)));
  }

  int _navIndex(AppTab tab) => switch (tab) {
        AppTab.transfers => 1,
        AppTab.settings => 2,
        _ => 0,
      };

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;

    return ValueListenableBuilder<AppTab>(
      valueListenable: _nav.currentTab,
      builder: (context, tab, _) {
        final body = Column(
          children: [
            Expanded(
              child: SafeArea(
                bottom: false,
                child: IndexedStack(
                  index: AppTab.values.indexOf(tab),
                  children: [for (final t in AppTab.values) _pages[t]!],
                ),
              ),
            ),
            if (tab != AppTab.transfers) const PersistentTransferBanner(),
          ],
        );

        return PopScope(
          canPop: tab == AppTab.home,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _nav.goTo(AppTab.home);
          },
          child: BlocListener<TransferBloc, TransferState>(
            listenWhen: (a, b) => b.notice != null && a.notice != b.notice,
            listener: (context, state) => showAppSnack(context, state.notice!),
            child: Scaffold(
              body: wide
                  ? Row(
                      children: [
                        SafeArea(child: _Rail(index: _navIndex(tab), tabs: _navTabs)),
                        const VerticalDivider(width: 1),
                        Expanded(child: body),
                      ],
                    )
                  : body,
              bottomNavigationBar: wide
                  ? null
                  : DecoratedBox(
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: AppColors.border)),
                      ),
                      child: NavigationBar(
                        selectedIndex: _navIndex(tab),
                        onDestinationSelected: (i) => _nav.goTo(_navTabs[i]),
                        destinations: const [
                          NavigationDestination(
                            icon: Icon(Icons.home_outlined),
                            selectedIcon: Icon(Icons.home_rounded),
                            label: 'Home',
                          ),
                          NavigationDestination(
                            icon: _ActiveBadge(child: Icon(Icons.swap_vert_rounded)),
                            selectedIcon: _ActiveBadge(child: Icon(Icons.swap_vert_circle_rounded)),
                            label: 'Transfers',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.settings_outlined),
                            selectedIcon: Icon(Icons.settings_rounded),
                            label: 'Settings',
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _ActiveBadge extends StatelessWidget {
  final Widget child;
  const _ActiveBadge({required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransferBloc, TransferState>(
      buildWhen: (a, b) => a.activeCount != b.activeCount,
      builder: (context, state) => Badge(
        isLabelVisible: state.activeCount > 0,
        label: Text('${state.activeCount}'),
        backgroundColor: AppColors.primary,
        child: child,
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  final int index;
  final List<AppTab> tabs;
  const _Rail({required this.index, required this.tabs});

  @override
  Widget build(BuildContext context) {
    return NavigationRail(
      selectedIndex: index,
      labelType: NavigationRailLabelType.all,
      onDestinationSelected: (i) => AppNavigation.instance.goTo(tabs[i]),
      minWidth: 88,
      leading: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            gradient: AppColors.brandGradient,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.point_of_sale_rounded, color: Colors.white),
        ),
      ),
      destinations: const [
        NavigationRailDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: Text('Home'),
        ),
        NavigationRailDestination(
          icon: _ActiveBadge(child: Icon(Icons.swap_vert_rounded)),
          selectedIcon: _ActiveBadge(child: Icon(Icons.swap_vert_circle_rounded)),
          label: Text('Transfers'),
        ),
        NavigationRailDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings_rounded),
          label: Text('Settings'),
        ),
      ],
    );
  }
}
