import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
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
    return Scaffold(
      body: Stack(
        children: [
          // Current selected screen
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),

          // Persistent background transfer widget accessible anywhere in the app
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: PersistentTransferBanner(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.accent.withValues(alpha: 0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.cloud_upload_outlined),
            selectedIcon: Icon(Icons.cloud_upload_rounded, color: AppColors.accent),
            label: 'Upload',
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_download_outlined),
            selectedIcon: Icon(Icons.cloud_download_rounded, color: AppColors.accent),
            label: 'Download',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded, color: AppColors.accent),
            label: 'Transfer Center',
          ),
        ],
      ),
    );
  }
}
