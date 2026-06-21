import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../firebase_options.dart';

final _plugin = FlutterLocalNotificationsPlugin();
bool _initialized = false;
int _notifId = 0;

const _channelId = 'soporte_beta_high';
const _channelName = 'Soporte Beta';

// Handler de background — debe ser top-level
@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }
  _showLocal(message.notification?.title ?? 'Soporte Beta', message.notification?.body ?? '');
}

void _showLocal(String title, String body) {
  _plugin.show(
    _notifId++ & 0x7FFFFFFF,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Alertas de tickets, mensajes y equipos',
        importance: Importance.max,
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

Future<void> initPlatformServices(FirebaseOptions options) async {
  await Firebase.initializeApp(options: options);
}

String get notifPermission => _initialized ? 'granted' : 'default';

Future<void> initNotifHelperIfNeeded() async {
  if (_initialized) return;
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  // Registrar handler de mensajes en background
  FirebaseMessaging.onBackgroundMessage(_bgHandler);

  // Inicializar plugin de notificaciones locales
  const initSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
  );
  await _plugin.initialize(initSettings);

  // Crear canal de alta prioridad en Android
  const channel = AndroidNotificationChannel(
    _channelId,
    _channelName,
    description: 'Alertas de tickets, mensajes y equipos',
    importance: Importance.max,
  );
  await _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // Mostrar notificaciones FCM cuando la app está en primer plano
  FirebaseMessaging.onMessage.listen((msg) {
    if (msg.notification != null) {
      _showLocal(msg.notification!.title ?? 'Soporte Beta', msg.notification!.body ?? '');
    }
  });

  // Verificar si ya hay permiso
  final androidImpl = _plugin
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  if (androidImpl != null) {
    _initialized = (await androidImpl.areNotificationsEnabled()) ?? false;
  } else {
    _initialized = true;
  }
}

Future<String> requestNotifPermission() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  // Solicitar permiso de Firebase Messaging (iOS + Android 13+)
  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;

  if (granted) {
    await initNotifHelperIfNeeded();
    _initialized = true;
  }

  return granted ? 'granted' : 'denied';
}

Future<String?> getFcmToken() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
    return await FirebaseMessaging.instance.getToken();
  } catch (_) {
    return null;
  }
}

void showNotification(String title, String body) {
  if (!_initialized) return;
  _showLocal(title, body);
}
