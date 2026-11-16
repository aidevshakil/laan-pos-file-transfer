import 'dart:developer' as developer;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../services/app_navigation.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static const String progressChannelId = 'laan_pos_transfer_progress';
  static const String resultChannelId = 'laan_pos_transfer_result';

  String? launchPayload;

  Future<void> initialize() async {
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        developer.log('Notification tapped: ${response.payload}');
        AppNavigation.instance.handlePayload(response.payload);
      },
    );

    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      launchPayload = launch!.notificationResponse?.payload;
    }

    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      await android.createNotificationChannel(const AndroidNotificationChannel(
        progressChannelId,
        'Transfer progress',
        description: 'Live progress of uploads and downloads',
        importance: Importance.low,
        showBadge: false,
      ));
      await android.createNotificationChannel(const AndroidNotificationChannel(
        resultChannelId,
        'Transfer results',
        description: 'Shown when an upload or download finishes or fails',
        importance: Importance.high,
      ));
      await android.requestNotificationsPermission();
    }
  }

  static int progressIdFor(String taskId) => (taskId.hashCode & 0x3fffffff) * 2 % 0x7ffffffe;
  static int resultIdFor(String taskId) => progressIdFor(taskId) + 1;

  Future<void> showProgress({
    required String taskId,
    required String title,
    required String body,
    required int percent,
    required String payload,
    bool indeterminate = false,
  }) async {
    final details = AndroidNotificationDetails(
      progressChannelId,
      'Transfer progress',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: percent.clamp(0, 100),
      indeterminate: indeterminate,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      category: AndroidNotificationCategory.progress,
    );
    await _safe(() => _plugin.show(
          progressIdFor(taskId),
          title,
          body,
          NotificationDetails(android: details),
          payload: payload,
        ));
  }

  Future<void> showResult({
    required String taskId,
    required String title,
    required String body,
    required String payload,
  }) async {
    await cancelProgress(taskId);
    final details = AndroidNotificationDetails(
      resultChannelId,
      'Transfer results',
      importance: Importance.high,
      priority: Priority.high,
      autoCancel: true,
      styleInformation: BigTextStyleInformation(body),
    );
    await _safe(() => _plugin.show(
          resultIdFor(taskId),
          title,
          body,
          NotificationDetails(
            android: details,
            iOS: const DarwinNotificationDetails(),
          ),
          payload: payload,
        ));
  }

  Future<void> cancelProgress(String taskId) =>
      _safe(() => _plugin.cancel(progressIdFor(taskId)));

  Future<void> cancelAll(String taskId) async {
    await _safe(() => _plugin.cancel(progressIdFor(taskId)));
    await _safe(() => _plugin.cancel(resultIdFor(taskId)));
  }

  Future<void> _safe(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      developer.log('Notification error: $e');
    }
  }
}
