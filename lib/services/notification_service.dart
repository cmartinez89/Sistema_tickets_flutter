import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../utils/notif_helper.dart';

const _batteryChannel = MethodChannel('com.betasystems.soporte/battery');

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
      await requestNotifPermission();
    } catch (e) {
      debugPrint('[Notificaciones] No soportado: $e');
    }
    if (!kIsWeb) {
      try {
        await _batteryChannel.invokeMethod('requestBatteryOptimizationExemption');
      } catch (_) {}
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
      showNotification(titulo, cuerpo);
    } catch (_) {}
  }
}
