import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final _plugin = FlutterLocalNotificationsPlugin();
bool _initialized = false;
int _notifId = 0;

const _channelId = 'soporte_beta';
const _channelName = 'Soporte Beta';

String get notifPermission => _initialized ? 'granted' : 'default';

Future<void> initNotifHelperIfNeeded() async {
  if (_initialized) return;
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );
  await _plugin.initialize(initSettings);

  final androidImpl = _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (androidImpl != null) {
    _initialized = (await androidImpl.areNotificationsEnabled()) ?? false;
  } else {
    _initialized = true;
  }
}

Future<String> requestNotifPermission() async {
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    ),
  );
  await _plugin.initialize(initSettings);

  final androidImpl = _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (androidImpl != null) {
    final granted = await androidImpl.requestNotificationsPermission() ?? false;
    _initialized = granted;
    return granted ? 'granted' : 'denied';
  }

  final iosImpl = _plugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
  if (iosImpl != null) {
    final granted = await iosImpl.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    _initialized = granted;
    return granted ? 'granted' : 'denied';
  }

  _initialized = true;
  return 'granted';
}

void showNotification(String title, String body) {
  if (!_initialized) return;
  _plugin.show(
    _notifId++ & 0x7FFFFFFF,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Alertas de tickets, mensajes y equipos',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
  );
}
