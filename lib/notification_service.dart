import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;
import 'dart:js_interop';

const String kApiUrl = 'http://54.161.41.131:8000';
const Duration kTimeout = Duration(seconds: 15);

class NotificationService {
  final String username;
  final String rol;
  final String token;

  Timer? _timer;
  final Set<String> _ticketsConocidos = {};
  final Map<String, String> _estatusConocidos = {};
  bool _inicializado = false;

  NotificationService({
    required this.username,
    required this.rol,
    required this.token,
  });

  static Future<bool> solicitarPermiso() async {
    try {
      final resultado = await web.Notification.requestPermission().toDart;
      return resultado == 'granted';
    } catch (_) {
      return false;
    }
  }

  static bool get permisoActivo {
    try {
      return web.Notification.permission == 'granted';
    } catch (_) {
      return false;
    }
  }

  void iniciar() {
    _timer?.cancel();
    _cargarEstadoBase().then((_) {
      _inicializado = true;
      _timer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => _verificarCambios(),
      );
    });
  }

  void detener() {
    _timer?.cancel();
    _timer = null;
    _ticketsConocidos.clear();
    _estatusConocidos.clear();
    _inicializado = false;
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  Future<void> _cargarEstadoBase() async {
    try {
      final res = await http
          .get(Uri.parse('$kApiUrl/tickets'), headers: _headers)
          .timeout(kTimeout);
      if (res.statusCode != 200) return;
      final List<dynamic> data = jsonDecode(res.body);
      for (final item in data) {
        _ticketsConocidos.add(item['id'] as String);
        _estatusConocidos[item['id'] as String] = item['estado'] as String;
      }
    } catch (_) {}
  }

  Future<void> _verificarCambios() async {
    if (!_inicializado || !permisoActivo) return;
    await _verificarTickets();
    await _verificarRespaldos();
  }

  Future<void> _verificarTickets() async {
    try {
      final res = await http
          .get(Uri.parse('$kApiUrl/tickets'), headers: _headers)
          .timeout(kTimeout);
      if (res.statusCode != 200) return;
      final List<dynamic> data = jsonDecode(res.body);

      for (final item in data) {
        final id = item['id'] as String;
        final estado = item['estado'] as String;
        final asignadoA = (item['asignadoA'] as String? ?? '').toLowerCase();
        final descripcion = item['descripcion'] as String? ?? 'Sin descripción';
        final usuario = item['usuario'] as String? ?? '';
        final esMio = asignadoA == username.toLowerCase();
        final esAdmin = rol == 'Admin';

        if (!_ticketsConocidos.contains(id)) {
          _ticketsConocidos.add(id);
          _estatusConocidos[id] = estado;
          if (esMio || esAdmin) {
            _mostrarNotificacion(
              titulo: esAdmin
                  ? '📋 Nuevo ticket registrado'
                  : '📋 Nuevo ticket asignado a ti',
              cuerpo: '$id — $descripcion\nUsuario: $usuario',
            );
          }
          continue;
        }

        final estadoAnterior = _estatusConocidos[id];
        if (estadoAnterior != null &&
            estadoAnterior != estado &&
            (esMio || esAdmin)) {
          _mostrarNotificacion(
            titulo: '🔄 Ticket actualizado',
            cuerpo: '$id: $descripcion\n$estadoAnterior → $estado',
          );
        }
        _estatusConocidos[id] = estado;
      }
    } catch (_) {}
  }

  Future<void> _verificarRespaldos() async {
    try {
      final res = await http
          .get(Uri.parse('$kApiUrl/equipos'), headers: _headers)
          .timeout(kTimeout);
      if (res.statusCode != 200) return;
      final List<dynamic> data = jsonDecode(res.body);
      final List<String> criticos = [];

      for (final item in data) {
        final ultimoRespaldo = item['ultimoRespaldo'] as String?;
        final modelo = item['modelo'] as String? ?? 'Equipo';
        final empleado = item['empleadoAsignado'] as String? ?? 'Sistemas';
        if (ultimoRespaldo == null) {
          criticos.add('$modelo ($empleado) — Sin respaldo');
          continue;
        }
        final fecha = DateTime.tryParse(ultimoRespaldo);
        if (fecha == null) continue;
        final dias = DateTime.now().difference(fecha).inDays;
        if (dias >= 15) criticos.add('$modelo ($empleado) — $dias días');
      }

      if (criticos.isNotEmpty) {
        _mostrarNotificacion(
          titulo: '⚠️ ${criticos.length} equipo(s) sin respaldo reciente',
          cuerpo:
              criticos.take(3).join('\n') +
              (criticos.length > 3 ? '\n...y más' : ''),
        );
      }
    } catch (_) {}
  }

  static void _mostrarNotificacion({
    required String titulo,
    required String cuerpo,
  }) {
    try {
      if (!permisoActivo) return;
      web.Notification(
        titulo,
        web.NotificationOptions(body: cuerpo, icon: '/icons/Icon-192.png'),
      );
    } catch (_) {}
  }
}
