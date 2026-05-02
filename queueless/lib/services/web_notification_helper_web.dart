import 'dart:html' as html;

Future<bool> requestBrowserNotificationPermission() async {
  if (!html.Notification.supported) {
    return false;
  }

  final permission = await html.Notification.requestPermission();
  return permission == 'granted';
}

Future<void> showBrowserNotification({required String title, required String body}) async {
  if (!html.Notification.supported || html.Notification.permission != 'granted') {
    return;
  }

  html.Notification(title, body: body);
}