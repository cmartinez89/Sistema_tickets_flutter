import 'dart:convert';
import 'package:web/web.dart' as web;

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
  static const _kTtlMs = 7 * 24 * 60 * 60 * 1000; // 7 días en ms

  void guardar() {
    web.window.localStorage.setItem(
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

  static Session? restaurar() {
    try {
      final raw = web.window.localStorage.getItem(_kKey);
      if (raw == null || raw.isEmpty) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final ts = (data['ts'] as num?)?.toInt() ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - ts > _kTtlMs) {
        limpiar();
        return null;
      }
      return Session(
        username: data['username'] ?? '',
        nombreCompleto: data['nombreCompleto'] ?? '',
        rol: data['rol'] ?? '',
        token: data['token'] ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  static void limpiar() {
    try {
      web.window.localStorage.removeItem(_kKey);
    } catch (_) {}
  }
}