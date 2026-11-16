import 'dart:io';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'dart:developer' as developer;

@pragma('vm:entry-point')
void transferServiceCallback() {
  FlutterForegroundTask.setTaskHandler(_KeepAliveTaskHandler());
}

class _KeepAliveTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}
}

class BackgroundTransferService {
  BackgroundTransferService._();
  static final BackgroundTransferService instance = BackgroundTransferService._();

  static const int _serviceId = 4100;
  bool _running = false;
  bool _starting = false;
  DateTime _lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  bool get _supported => Platform.isAndroid || Platform.isIOS;

  void init() {
    if (!_supported) return;
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'laan_pos_transfer_service',
        channelName: 'Background transfer service',
        channelDescription:
            'Keeps uploads and downloads running while the app is in the background.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<void> sync({required int activeCount, required int percent}) async {
    if (!_supported) return;
    try {
      if (activeCount > 0) {
        final text = '$activeCount transfer${activeCount == 1 ? '' : 's'} in progress • $percent%';
        if (!_running && !_starting) {
          _starting = true;
          final result = await FlutterForegroundTask.startService(
            serviceId: _serviceId,
            serviceTypes: [ForegroundServiceTypes.dataSync],
            notificationTitle: 'LAAN POS is syncing files',
            notificationText: text,
            notificationInitialRoute: '/',
            callback: transferServiceCallback,
          );
          _running = result is ServiceRequestSuccess;
          _starting = false;
          _lastUpdate = DateTime.now();
        } else if (_running &&
            DateTime.now().difference(_lastUpdate) > const Duration(seconds: 2)) {
          _lastUpdate = DateTime.now();
          await FlutterForegroundTask.updateService(
            notificationTitle: 'LAAN POS is syncing files',
            notificationText: text,
          );
        }
      } else if (_running) {
        _running = false;
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      _starting = false;
      developer.log('Foreground service error: $e');
    }
  }
}
