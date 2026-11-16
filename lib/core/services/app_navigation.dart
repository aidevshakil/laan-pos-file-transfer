import 'package:flutter/foundation.dart';

enum AppTab { home, upload, download, transfers, settings }

class AppNavigation {
  AppNavigation._();
  static final AppNavigation instance = AppNavigation._();

  final ValueNotifier<AppTab> currentTab = ValueNotifier(AppTab.home);

  final ValueNotifier<String?> completedDownload = ValueNotifier(null);

  void goTo(AppTab tab) => currentTab.value = tab;

  bool get isSubPage => currentTab.value == AppTab.upload || currentTab.value == AppTab.download;

  static const String downloadDonePrefix = 'done';

  static String payloadFor(AppTab tab, String taskId) => '${tab.name}|$taskId';
  static String downloadDonePayload(String taskId) => '$downloadDonePrefix|$taskId';

  void handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    final parts = payload.split('|');
    if (parts.first == downloadDonePrefix && parts.length > 1) {
      goTo(AppTab.download);
      completedDownload.value = parts[1];
      return;
    }
    final tab = AppTab.values.where((t) => t.name == parts.first).firstOrNull;
    goTo(tab ?? AppTab.transfers);
  }
}
