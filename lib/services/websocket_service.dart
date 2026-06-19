import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

typedef OnWsMensaje = void Function(Map<String, dynamic> datos);

class WebSocketService {
  final String url;
  final OnWsMensaje onMensaje;

  web.WebSocket? _socket;
  Timer? _reconectarTimer;
  bool _activo = false;

  WebSocketService({required this.url, required this.onMensaje});

  void iniciar() {
    _activo = true;
    _conectar();
  }

  void _conectar() {
    if (!_activo) return;
    try {
      _socket = web.WebSocket(url);

      _socket!.onopen = ((web.Event _) {
        debugPrint('[WS] Conectado al servidor');
      }).toJS;

      _socket!.onmessage = ((web.MessageEvent e) {
        try {
          final texto = (e.data as JSString).toDart;
          final datos = jsonDecode(texto) as Map<String, dynamic>;
          onMensaje(datos);
        } catch (_) {
          onMensaje({});
        }
      }).toJS;

      _socket!.onclose = ((web.CloseEvent _) {
        if (_activo) {
          debugPrint('[WS] Desconectado. Reconectando en 5s...');
          _reconectarTimer = Timer(const Duration(seconds: 5), _conectar);
        }
      }).toJS;

      _socket!.onerror = ((web.Event _) {
        debugPrint('[WS] Error de conexión');
      }).toJS;
    } catch (e) {
      debugPrint('[WS] Error al iniciar: $e');
      if (_activo) {
        _reconectarTimer = Timer(const Duration(seconds: 5), _conectar);
      }
    }
  }

  void detener() {
    _activo = false;
    _reconectarTimer?.cancel();
    _socket?.close();
    _socket = null;
  }
}
