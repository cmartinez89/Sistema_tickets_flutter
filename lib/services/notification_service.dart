import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

class NotificationService {
  final String username;
  final String rol;
  final String token;
  Timer? _timer;

  NotificationService({
    required this.username,
    required this.rol,
    required this.token,
  });

  /// Solicita explícitamente los permisos de notificación al navegador web
  static Future<void> solicitarPermiso() async {
    try {
      // Usamos una estructura de mapa plano jsificado compatible
      final queryOptions = {'name': 'notifications'}.jsify();
      
      final permissionStatus = await web.window.navigator.permissions.query(
        queryOptions! as JSObject,
      ).toDart;
      
      // En package:web, state es un enum de tipo String en JS, usamos .value
      if (permissionStatus.state == 'prompt') {
        final resultado = await web.Notification.requestPermission().toDart;
        debugPrint('[Notificaciones] Estado de la solicitud: $resultado');
      }
    } catch (e) {
      debugPrint('[Notificaciones] Error o no soportado en este entorno: $e');
    }
  }

  /// Inicia el servicio de polling o escucha de alertas en segundo plano
  void iniciar() {
    debugPrint('[Notificaciones] Servicio iniciado para el usuario: $username');
    _timer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _revisarNuevosTickets();
    });
  }

  /// Simula o ejecuta la petición para buscar actualizaciones de soporte técnico
  Future<void> _revisarNuevosTickets() async {
    try {
      debugPrint('[Notificaciones] Verificando actualizaciones de tickets...');
    } catch (e) {
      debugPrint('[Notificaciones] Error al sincronizar alertas: $e');
    }
  }

  /// Detiene el temporizador y limpia los recursos del servicio
  void detener() {
    _timer?.cancel();
    debugPrint('[Notificaciones] Servicio detenido de forma segura.');
  }

  /// Helper estático para lanzar una alerta visual si el navegador lo permite
  static void lanzarAlertaLocal(String titulo, String cuerpo) {
    try {
      // web.Notification.permission expone directamente el valor string compatible
      if (web.Notification.permission == 'granted') {
        web.Notification(
          titulo,
          web.NotificationOptions(
            body: cuerpo,
            icon: '/favicon.png',
          ),
        );
      }
    } catch (_) {}
  }
}