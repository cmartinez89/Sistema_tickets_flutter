import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ticket_model.dart';
import '../models/equipo_model.dart';
import '../models/chat_message_model.dart';
import '../models/usuario_model.dart';
import '../models/proyecto_model.dart';
import '../models/tarea_model.dart';

const String kApiUrl = 'https://soporte.beta.com.mx/api';
const Duration kTimeout = Duration(seconds: 15);

class ApiService {
  final String token;
  ApiService({required this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  // ── Tickets ──────────────────────────────────────────────────────────────────

  Future<List<Ticket>> fetchTickets() async {
    final res = await http.get(Uri.parse('$kApiUrl/tickets'), headers: _headers).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al cargar tickets');
    return (jsonDecode(res.body) as List).map((e) => Ticket.fromMap(e)).toList();
  }

  Future<Ticket> crearTicket(Ticket ticket) async {
    final res = await http.post(Uri.parse('$kApiUrl/tickets'), headers: _headers, body: jsonEncode(ticket.toMap())).timeout(kTimeout);
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception('Error ${res.statusCode}: ${res.body}');
    return Ticket.fromMap(jsonDecode(res.body));
  }

  Future<void> cambiarEstatusTicket(String id, String estado, {String? usuario}) async {
    final res = await http.put(Uri.parse('$kApiUrl/tickets/$id/status'), headers: _headers, body: jsonEncode({'estado': estado, if (usuario != null) 'usuario': usuario})).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al actualizar estatus');
  }

  Future<void> resolverTicket(String id, {
    required String causaRaiz,
    required String comoSeResolvio,
    required String pruebasRealizadas,
    required String validadoCon,
    required String tipoTicket,
    String? imagenResolucion,
  }) async {
    final res = await http.put(Uri.parse('$kApiUrl/tickets/$id/resolve'), headers: _headers, body: jsonEncode({
      'estado': 'Resuelto',
      'causaRaiz': causaRaiz,
      'comoSeResolvio': comoSeResolvio,
      'pruebasRealizadas': pruebasRealizadas,
      'validadoCon': validadoCon,
      'tipoTicket': tipoTicket,
      if (imagenResolucion != null) 'imagenResolucion': imagenResolucion,
    })).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al resolver ticket');
  }

  Future<void> escalarTicket(String id, {required String escaladoA, required String motivoEscalado, required String usuario}) async {
    final res = await http.put(Uri.parse('$kApiUrl/tickets/$id/escalar'), headers: _headers, body: jsonEncode({
      'escaladoA': escaladoA,
      'motivoEscalado': motivoEscalado,
      'usuario': usuario,
    })).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al escalar ticket');
  }

  Future<void> reasignarTicket(String id, String tecnico) async {
    final res = await http.put(Uri.parse('$kApiUrl/tickets/$id/assign'), headers: _headers, body: jsonEncode({'asignadoA': tecnico})).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al reasignar');
  }

  Future<List<Map<String, dynamic>>> fetchHistorial(String ticketId) async {
    final res = await http.get(Uri.parse('$kApiUrl/tickets/$ticketId/historial'), headers: _headers).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al cargar historial');
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchComentarios(String ticketId) async {
    final res = await http.get(Uri.parse('$kApiUrl/tickets/$ticketId/comentarios'), headers: _headers).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al cargar comentarios');
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  Future<void> agregarComentario(String ticketId, String texto) async {
    final res = await http.post(Uri.parse('$kApiUrl/tickets/$ticketId/comentarios'), headers: _headers, body: jsonEncode({'texto': texto})).timeout(kTimeout);
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception(_parseError(res, 'Error al agregar comentario'));
  }

  // ── Equipos ──────────────────────────────────────────────────────────────────

  Future<List<Equipo>> fetchEquipos() async {
    final res = await http.get(Uri.parse('$kApiUrl/equipos'), headers: _headers).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al cargar equipos');
    return (jsonDecode(res.body) as List).map((e) => Equipo.fromMap(e)).toList();
  }

  Future<Equipo> crearEquipo(Equipo equipo) async {
    final body = equipo.toMap();
    body.remove('folioResponsiva');
    body.remove('folioActivo');
    final res = await http.post(Uri.parse('$kApiUrl/equipos'), headers: _headers, body: jsonEncode(body)).timeout(kTimeout);
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception('Error al registrar equipo');
    return Equipo.fromMap(jsonDecode(res.body));
  }

  Future<Equipo> editarEquipo(String id, Equipo equipo) async {
    final res = await http.put(Uri.parse('$kApiUrl/equipos/$id'), headers: _headers, body: jsonEncode(equipo.toMap())).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception(_parseError(res, 'Error al editar equipo'));
    return Equipo.fromMap(jsonDecode(res.body));
  }

  Future<Map<String, dynamic>> asignarEquipo(String id, {required String empleado, required String rol}) async {
    final res = await http.put(Uri.parse('$kApiUrl/equipos/$id/assign'), headers: _headers, body: jsonEncode({
      'empleadoAsignado': empleado,
      'rolEmpleado': rol,
      'estatus': 'Asignado',
    })).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al asignar equipo');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<void> liberarEquipo(String id) async {
    final res = await http.put(Uri.parse('$kApiUrl/equipos/$id/release'), headers: _headers, body: jsonEncode({
      'empleadoAsignado': null,
      'rolEmpleado': null,
      'folioResponsiva': '---',
      'estatus': 'Disponible',
    })).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al liberar equipo');
  }

  Future<void> venderEquipo(String id, double precio, String fechaVenta) async {
    final res = await http.put(Uri.parse('$kApiUrl/equipos/$id/vender'), headers: _headers, body: jsonEncode({
      'precioVenta': precio,
      'fechaVenta': fechaVenta,
    })).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al registrar venta');
  }

  Future<void> actualizarRespaldo(String id, DateTime fecha) async {
    final res = await http.put(Uri.parse('$kApiUrl/equipos/$id/backup'), headers: _headers, body: jsonEncode({'ultimoRespaldo': fecha.toIso8601String()})).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al actualizar respaldo');
  }

  Future<void> darDeBajaEquipo(String id) async {
    final res = await http.put(Uri.parse('$kApiUrl/equipos/$id/baja'), headers: _headers).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al dar de baja el equipo');
  }

  // ── Usuarios ─────────────────────────────────────────────────────────────────

  Future<List<Usuario>> fetchUsuarios() async {
    final res = await http.get(Uri.parse('$kApiUrl/usuarios'), headers: _headers).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al cargar usuarios');
    return (jsonDecode(res.body) as List).map((e) => Usuario.fromMap(e)).toList();
  }

  Future<void> crearUsuario({
    required String username,
    required String email,
    required String nombreCompleto,
    required String rol,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('$kApiUrl/usuarios'),
      headers: _headers,
      body: jsonEncode({'username': username, 'email': email, 'nombreCompleto': nombreCompleto, 'rol': rol, 'password': password}),
    ).timeout(kTimeout);
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception(jsonDecode(res.body)['detail'] ?? 'Error al crear usuario');
  }

  Future<void> actualizarUsuario({
    required String username,
    required String nombreCompleto,
    required String email,
    required String rol,
    String? password,
  }) async {
    final body = <String, dynamic>{'nombreCompleto': nombreCompleto, 'email': email, 'rol': rol};
    if (password != null) body['password'] = password;
    final res = await http.put(
      Uri.parse('$kApiUrl/usuarios/$username'),
      headers: _headers,
      body: jsonEncode(body),
    ).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception(jsonDecode(res.body)['detail'] ?? 'Error al actualizar usuario');
  }

  Future<void> eliminarUsuario(String username) async {
    final res = await http.delete(Uri.parse('$kApiUrl/usuarios/$username'), headers: _headers).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al eliminar usuario');
  }

  // ── Auth ──────────────────────────────────────────────────────────────────────

  Future<void> cambiarPassword(String username, String passwordNueva) async {
    final res = await http.post(
      Uri.parse('$kApiUrl/cambiar-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'passwordNueva': passwordNueva}),
    ).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al cambiar contraseña');
  }

  // ── Chat ─────────────────────────────────────────────────────────────────────

  Future<List<ChatMessage>> fetchMensajes() async {
    final res = await http.get(Uri.parse('$kApiUrl/mensajes'), headers: _headers).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al cargar mensajes');
    return (jsonDecode(res.body) as List).map((e) => ChatMessage.fromMap(e)).toList();
  }

  Future<void> enviarMensaje(String deUsuario, String nombreCompleto, String texto, {required String canal, String? imagen}) async {
    final body = <String, dynamic>{'deUsuario': deUsuario, 'nombreCompleto': nombreCompleto, 'texto': texto, 'canal': canal};
    if (imagen != null) body['imagen'] = imagen;
    final res = await http.post(
      Uri.parse('$kApiUrl/mensajes'),
      headers: _headers,
      body: jsonEncode(body),
    ).timeout(kTimeout);
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception('Error al enviar mensaje');
  }

  Future<void> borrarMensaje(String id) async {
    final res = await http.delete(
      Uri.parse('$kApiUrl/mensajes/$id'),
      headers: _headers,
    ).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al borrar mensaje');
  }

  // ── Catálogos ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> fetchCategorias() async {
    final res = await http.get(Uri.parse('$kApiUrl/categorias'), headers: _headers).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al cargar categorías');
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  Future<void> crearCategoria(String nombre) async {
    final res = await http.post(Uri.parse('$kApiUrl/categorias'), headers: _headers, body: jsonEncode({'nombre': nombre})).timeout(kTimeout);
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception('Error al crear categoría');
  }

  Future<void> actualizarCategoria(int id, String nombre) async {
    final res = await http.put(Uri.parse('$kApiUrl/categorias/$id'), headers: _headers, body: jsonEncode({'nombre': nombre})).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al actualizar categoría');
  }

  Future<void> eliminarCategoria(int id) async {
    final res = await http.delete(Uri.parse('$kApiUrl/categorias/$id'), headers: _headers).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al eliminar categoría');
  }

  Future<List<Map<String, dynamic>>> fetchAreas() async {
    final res = await http.get(Uri.parse('$kApiUrl/areas'), headers: _headers).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al cargar áreas');
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  Future<void> crearArea(String nombre) async {
    final res = await http.post(Uri.parse('$kApiUrl/areas'), headers: _headers, body: jsonEncode({'nombre': nombre})).timeout(kTimeout);
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception('Error al crear área');
  }

  Future<void> actualizarArea(int id, String nombre) async {
    final res = await http.put(Uri.parse('$kApiUrl/areas/$id'), headers: _headers, body: jsonEncode({'nombre': nombre})).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al actualizar área');
  }

  Future<void> eliminarArea(int id) async {
    final res = await http.delete(Uri.parse('$kApiUrl/areas/$id'), headers: _headers).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al eliminar área');
  }

  Future<List<Map<String, dynamic>>> fetchTiposEquipo() async {
    final res = await http.get(Uri.parse('$kApiUrl/tipos-equipo'), headers: _headers).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al cargar tipos de equipo');
    return (jsonDecode(res.body) as List).cast<Map<String, dynamic>>();
  }

  Future<void> crearTipoEquipo(String nombre) async {
    final res = await http.post(Uri.parse('$kApiUrl/tipos-equipo'), headers: _headers, body: jsonEncode({'nombre': nombre})).timeout(kTimeout);
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception('Error al crear tipo de equipo');
  }

  Future<void> actualizarTipoEquipo(int id, String nombre) async {
    final res = await http.put(Uri.parse('$kApiUrl/tipos-equipo/$id'), headers: _headers, body: jsonEncode({'nombre': nombre})).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al actualizar tipo de equipo');
  }

  Future<void> eliminarTipoEquipo(int id) async {
    final res = await http.delete(Uri.parse('$kApiUrl/tipos-equipo/$id'), headers: _headers).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al eliminar tipo de equipo');
  }

  // ── Proyectos ─────────────────────────────────────────────────────────────────

  String _parseError(http.Response res, String fallback) {
    try { return (jsonDecode(res.body) as Map)['detail'] as String? ?? fallback; }
    catch (_) { return '$fallback (${res.statusCode})'; }
  }

  Future<List<Proyecto>> fetchProyectos() async {
    final res = await http.get(Uri.parse('$kApiUrl/proyectos'), headers: _headers).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al cargar proyectos');
    return (jsonDecode(res.body) as List).map((e) => Proyecto.fromMap(e)).toList();
  }

  Future<Proyecto> crearProyecto(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$kApiUrl/proyectos'), headers: _headers, body: jsonEncode(data)).timeout(kTimeout);
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception(_parseError(res, 'Error al crear proyecto'));
    return Proyecto.fromMap(jsonDecode(res.body));
  }

  Future<Proyecto> actualizarProyecto(int id, Map<String, dynamic> data) async {
    final res = await http.put(Uri.parse('$kApiUrl/proyectos/$id'), headers: _headers, body: jsonEncode(data)).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception(_parseError(res, 'Error al actualizar proyecto'));
    return Proyecto.fromMap(jsonDecode(res.body));
  }

  Future<void> eliminarProyecto(int id) async {
    final res = await http.delete(Uri.parse('$kApiUrl/proyectos/$id'), headers: _headers).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al eliminar proyecto');
  }

  // ── Tareas ────────────────────────────────────────────────────────────────────

  Future<List<Tarea>> fetchTareas({int? proyectoId}) async {
    final url = proyectoId != null
        ? '$kApiUrl/tareas?proyectoId=$proyectoId'
        : '$kApiUrl/tareas';
    final res = await http.get(Uri.parse(url), headers: _headers).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al cargar tareas');
    return (jsonDecode(res.body) as List).map((e) => Tarea.fromMap(e)).toList();
  }

  Future<Tarea> crearTarea(Map<String, dynamic> data) async {
    final res = await http.post(Uri.parse('$kApiUrl/tareas'), headers: _headers, body: jsonEncode(data)).timeout(kTimeout);
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception(_parseError(res, 'Error al crear tarea'));
    return Tarea.fromMap(jsonDecode(res.body));
  }

  Future<Tarea> actualizarTarea(int id, Map<String, dynamic> data) async {
    final res = await http.put(Uri.parse('$kApiUrl/tareas/$id'), headers: _headers, body: jsonEncode(data)).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception(_parseError(res, 'Error al actualizar tarea'));
    return Tarea.fromMap(jsonDecode(res.body));
  }

  Future<void> actualizarEstadoTarea(int id, String estado) async {
    final res = await http.patch(Uri.parse('$kApiUrl/tareas/$id/estado'), headers: _headers, body: jsonEncode({'estado': estado})).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al actualizar estado');
  }

  Future<void> actualizarFechasTarea(int id, DateTime inicio, DateTime fin) async {
    final res = await http.patch(Uri.parse('$kApiUrl/tareas/$id/fechas'), headers: _headers, body: jsonEncode({
      'fechaInicio': inicio.toIso8601String().substring(0, 10),
      'fechaFin': fin.toIso8601String().substring(0, 10),
    })).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al actualizar fechas');
  }

  Future<void> eliminarTarea(int id) async {
    final res = await http.delete(Uri.parse('$kApiUrl/tareas/$id'), headers: _headers).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al eliminar tarea');
  }

  // ── IA ────────────────────────────────────────────────────────────────────────

  Future<String> fetchAiConsulta(String pregunta) async {
    final res = await http.post(Uri.parse('$kApiUrl/ai/consulta'), headers: _headers, body: jsonEncode({'pregunta': pregunta})).timeout(const Duration(seconds: 90));
    if (res.statusCode != 200) throw Exception('Error IA: ${res.body}');
    return (jsonDecode(res.body) as Map)['respuesta'] as String;
  }

  Future<Map<String, dynamic>> fetchAiAnomalias() async {
    final res = await http.post(Uri.parse('$kApiUrl/ai/anomalias'), headers: _headers).timeout(const Duration(seconds: 120));
    if (res.statusCode != 200) throw Exception('Error IA: ${res.body}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<String> fetchAiSugerencia(String ticketId) async {
    final res = await http.post(Uri.parse('$kApiUrl/ai/sugerencia/$ticketId'), headers: _headers).timeout(const Duration(seconds: 90));
    if (res.statusCode != 200) throw Exception('Error IA: ${res.body}');
    return (jsonDecode(res.body) as Map)['sugerencia'] as String;
  }

  // ── FCM Token ────────────────────────────────────────────────────────────────

  Future<void> registrarFcmToken(String username, String token) async {
    try {
      await http.post(Uri.parse('$kApiUrl/usuarios/$username/fcm-token'),
          headers: _headers, body: jsonEncode({'fcmToken': token})).timeout(kTimeout);
    } catch (_) {}
  }

  // ── Reportes ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> fetchReportes() async {
    final res = await http.get(Uri.parse('$kApiUrl/reportes'), headers: _headers).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al cargar reportes');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
