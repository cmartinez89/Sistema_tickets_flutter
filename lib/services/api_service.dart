import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ticket_model.dart';
import '../models/equipo_model.dart';
import '../models/chat_message_model.dart';
import '../models/usuario_model.dart';

const String kApiUrl = 'http://54.161.41.131:8000';
const Duration kTimeout = Duration(seconds: 15);

class ApiService {
  final String token;
  ApiService({required this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  Future<List<Ticket>> fetchTickets() async {
    final res = await http.get(Uri.parse('$kApiUrl/tickets'), headers: _headers).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al cargar tickets');
    return (jsonDecode(res.body) as List).map((e) => Ticket.fromMap(e)).toList();
  }

  Future<List<Equipo>> fetchEquipos() async {
    final res = await http.get(Uri.parse('$kApiUrl/equipos'), headers: _headers).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al cargar equipos');
    return (jsonDecode(res.body) as List).map((e) => Equipo.fromMap(e)).toList();
  }

  Future<Ticket> crearTicket(Ticket ticket) async {
    final res = await http.post(Uri.parse('$kApiUrl/tickets'), headers: _headers, body: jsonEncode(ticket.toMap())).timeout(kTimeout);
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception('Error ${res.statusCode}: ${res.body}');
    return Ticket.fromMap(jsonDecode(res.body));
  }

  Future<Equipo> crearEquipo(Equipo equipo) async {
    final res = await http.post(Uri.parse('$kApiUrl/equipos'), headers: _headers, body: jsonEncode(equipo.toMap())).timeout(kTimeout);
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception('Error al registrar equipo');
    return Equipo.fromMap(jsonDecode(res.body));
  }

  Future<void> cambiarEstatusTicket(String id, String estado) async {
    final res = await http.put(Uri.parse('$kApiUrl/tickets/$id/status'), headers: _headers, body: jsonEncode({'estado': estado})).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al actualizar estatus');
  }

  Future<void> resolverTicket(String id, {required String causaRaiz, required String comoSeResolvio, required String pruebasRealizadas, required String validadoCon}) async {
    final res = await http.put(Uri.parse('$kApiUrl/tickets/$id/resolve'), headers: _headers, body: jsonEncode({
      'estado': 'Resuelto', 'causaRaiz': causaRaiz, 'comoSeResolvio': comoSeResolvio, 'pruebasRealizadas': pruebasRealizadas, 'validadoCon': validadoCon,
    })).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al resolver ticket');
  }

  Future<void> reasignarTicket(String id, String tecnico) async {
    final res = await http.put(Uri.parse('$kApiUrl/tickets/$id/assign'), headers: _headers, body: jsonEncode({'asignadoA': tecnico})).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al reasignar');
  }

  Future<void> asignarEquipo(String id, {required String empleado, required String rol, required String folio}) async {
    final res = await http.put(Uri.parse('$kApiUrl/equipos/$id/assign'), headers: _headers, body: jsonEncode({
      'empleadoAsignado': empleado, 'rolEmpleado': rol, 'folioResponsiva': folio, 'estatus': 'Asignado',
    })).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al asignar equipo');
  }

  Future<void> liberarEquipo(String id) async {
    final res = await http.put(Uri.parse('$kApiUrl/equipos/$id/release'), headers: _headers, body: jsonEncode({
      'empleadoAsignado': null, 'rolEmpleado': null, 'folioResponsiva': '---', 'estatus': 'Disponible',
    })).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al liberar equipo');
  }

  Future<void> actualizarRespaldo(String id, DateTime fecha) async {
    final res = await http.put(Uri.parse('$kApiUrl/equipos/$id/backup'), headers: _headers, body: jsonEncode({'ultimoRespaldo': fecha.toIso8601String()})).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al actualizar respaldo');
  }

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

  Future<List<ChatMessage>> fetchMensajes() async {
    final res = await http.get(Uri.parse('$kApiUrl/mensajes'), headers: _headers).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al cargar mensajes');
    return (jsonDecode(res.body) as List).map((e) => ChatMessage.fromMap(e)).toList();
  }

  Future<void> enviarMensaje(String deUsuario, String nombreCompleto, String texto) async {
    final res = await http.post(
      Uri.parse('$kApiUrl/mensajes'),
      headers: _headers,
      body: jsonEncode({'deUsuario': deUsuario, 'nombreCompleto': nombreCompleto, 'texto': texto}),
    ).timeout(kTimeout);
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception('Error al enviar mensaje');
  }
}