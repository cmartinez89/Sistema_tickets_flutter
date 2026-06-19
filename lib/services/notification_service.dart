import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

class NotificationService {
  final String username;
  final String rol;
  final String token;

  NotificationService({
    required this.username,
    required this.rol,
    required this.token,
  });

  static Future<void> solicitarPermiso() async {
    try {
      final queryOptions = {'name': 'notifications'}.jsify();
      final permissionStatus = await web.window.navigator.permissions.query(
        queryOptions! as JSObject,
      ).toDart;
      if (permissionStatus.state == 'prompt') {
        final resultado = await web.Notification.requestPermission().toDart;
        debugPrint('[Notificaciones] Permiso: $resultado');
      }
    } catch (e) {
      debugPrint('[Notificaciones] No soportado: $e');
    }
  }

  void iniciar() {
    debugPrint('[Notificaciones] Servicio listo para: $username');
  }

  void detener() {
    debugPrint('[Notificaciones] Servicio detenido.');
  }

  static void lanzarAlertaLocal(String titulo, String cuerpo) {
    try {
      if (web.Notification.permission == 'granted') {
        web.Notification(
          titulo,
          web.NotificationOptions(body: cuerpo, icon: '/favicon.png'),
        );
      }
    } catch (_) {}
  }
}
