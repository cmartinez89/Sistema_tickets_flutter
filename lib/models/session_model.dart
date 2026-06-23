import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Session {
  final String username;
  final String nombreCompleto;
  final String rol;
  final String token;

  Session({
    required this.username,
    required this.nombreCompleto,
    required this.rol,
    required this.token,
  });

  static const _kKey = 'soporte_beta_session';
  static const _kTtlMs = 7 * 24 * 60 * 60 * 1000;

  Future<void> guardar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kKey,
      jsonEncode({
        'username': username,
        'nombreCompleto': nombreCompleto,
        'rol': rol,
        'token': token,
        'ts': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  static Future<Session?> restaurar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      if (raw == null || raw.isEmpty) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final ts = (data['ts'] as num?)?.toInt() ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - ts > _kTtlMs) {
        await limpiar();
        return null;
      }
      final token = data['token'] as String? ?? '';
      // Rechazar tokens que no sean JWT válidos (3 partes separadas por '.')
      if (token.split('.').length != 3) {
        await limpiar();
        return null;
      }
      return Session(
        username: data['username'] ?? '',
        nombreCompleto: data['nombreCompleto'] ?? '',
        rol: data['rol'] ?? '',
        token: token,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> limpiar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kKey);
    } catch (_) {}
  }
}
