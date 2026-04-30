import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/notification_model.dart';
import 'web_notification_helper_stub.dart'
  if (dart.library.html) 'web_notification_helper_web.dart' as web_notifications;

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static int _notificationId = 1;

  static Future<void> initialize() async {
    if (_initialized) return;

    if (kIsWeb) {
      _initialized = true;
      return;
    }

    const androidSettings = AndroidInitializationSettings('app_icon');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );
    const windowsSettings = WindowsInitializationSettings(
      appName: 'QueueLess',
      appUserModelId: 'com.queueless.app',
      guid: '0f3e93ae-7b1d-46ef-9384-b22b9c43ae50',
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
      windows: windowsSettings,
    );

    try {
      await _plugin.initialize(settings);
      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  static Future<bool> requestPermissions() async {
    await initialize();

    if (kIsWeb) {
      return web_notifications.requestBrowserNotificationPermission();
    }

    bool granted = true;

    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final androidResult = await android?.requestNotificationsPermission();
    if (androidResult == false) {
      granted = false;
    }

    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    final iosResult = await ios?.requestPermissions(alert: true, badge: true, sound: true);
    if (iosResult == false) {
      granted = false;
    }

    final macos = _plugin.resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
    final macosResult = await macos?.requestPermissions(alert: true, badge: true, sound: true);
    if (macosResult == false) {
      granted = false;
    }

    return granted;
  }

  static Future<void> showNotification(NotificationModel notification) async {
    await initialize();
    if (!_initialized || notification.title.trim().isEmpty || notification.body.trim().isEmpty) {
      return;
    }

    if (kIsWeb) {
      await web_notifications.showBrowserNotification(
        title: notification.title,
        body: notification.body,
      );
      return;
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'queueless_alerts',
        'QueueLess Alerts',
        channelDescription: 'Important updates from QueueLess',
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      macOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
      linux: LinuxNotificationDetails(),
      windows: WindowsNotificationDetails(),
    );

    try {
      await _plugin.show(
        _notificationId++,
        notification.title,
        notification.body,
        details,
        payload: notification.id,
      );
    } catch (_) {
      // Ignore local notification failures so in-app delivery still works.
    }
  }
}