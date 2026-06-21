import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:firebase_core/firebase_core.dart';

String get notifPermission => web.Notification.permission;

Future<String> requestNotifPermission() async {
  final result = await web.Notification.requestPermission().toDart;
  return result.toDart;
}

Future<void> initPlatformServices(FirebaseOptions options) async {}
Future<void> initNotifHelperIfNeeded() async {}
Future<String?> getFcmToken() async => null;

void showNotification(String title, String body) {
  if (web.Notification.permission == 'granted') {
    web.Notification(
      title,
      web.NotificationOptions(body: body, icon: '/favicon.png'),
    );
  }
}
