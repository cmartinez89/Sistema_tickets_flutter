import 'dart:js_interop';
import 'package:web/web.dart' as web;

String get notifPermission => web.Notification.permission;

Future<String> requestNotifPermission() async {
  final result = await web.Notification.requestPermission().toDart;
  return result.toDart;
}

void showNotification(String title, String body) {
  if (web.Notification.permission == 'granted') {
    web.Notification(
      title,
      web.NotificationOptions(body: body, icon: '/favicon.png'),
    );
  }
}
