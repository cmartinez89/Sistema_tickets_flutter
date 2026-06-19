import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

typedef OnWsMensaje = void Function(Map<String, dynamic> datos);

class WebSocketService {
  final String url;
  final OnWsMensaje onMensaje;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
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
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _sub = _channel!.stream.listen(
        (data) {
          try {
            final datos = jsonDecode(data as String) as Map<String, dynamic>;
            onMensaje(datos);
          } catch (_) {
            onMensaje({});
          }
        },
        onDone: () {
          if (_activo) {
            debugPrint('[WS] Desconectado. Reconectando en 5s...');
            _reconectarTimer = Timer(const Duration(seconds: 5), _conectar);
          }
        },
        onError: (e) {
          debugPrint('[WS] Error: $e');
          if (_activo) {
            _reconectarTimer = Timer(const Duration(seconds: 5), _conectar);
          }
        },
        cancelOnError: false,
      );
      debugPrint('[WS] Conectado al servidor');
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
    _sub?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}
