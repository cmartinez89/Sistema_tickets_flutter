import 'package:flutter/material.dart';
import '../utils/notif_helper.dart';
import '../models/session_model.dart';
import '../models/ticket_model.dart';
import '../models/equipo_model.dart';
import '../models/chat_message_model.dart';
import '../models/usuario_model.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/websocket_service.dart';
import 'dashboard_screen.dart';
import 'tickets_screen.dart';
import 'equipment_screen.dart';
import 'backups_screen.dart';
import 'chat_screen.dart';
import 'users_screen.dart';
import 'admin_screen.dart';
import 'reportes_screen.dart';
import 'ai_screen.dart';
import 'login_screen.dart';

const String kWsBaseUrl = 'ws://54.161.41.131:8000/ws';

class MainLayout extends StatefulWidget {
  final Session session;
  final NotificationService notifService;

  const MainLayout({super.key, required this.session, required this.notifService});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with WidgetsBindingObserver {
  int _screenIndex = 0;
  int _screenAnterior = 0;
  List<Ticket> _tickets = [];
  List<Equipo> _inventario = [];
  List<ChatMessage> _mensajes = [];
  List<Usuario> _usuarios = [];
  int _mensajesNoLeidos = 0;
  bool _cargandoInicial = true;
  String _notifPermiso = 'default';
  late final ApiService _api;
  late final WebSocketService _ws;

  @override
  void initState() {
    super.initState();
    _api = ApiService(token: widget.session.token);
    _ws = WebSocketService(url: '$kWsBaseUrl?token=${Uri.encodeComponent(widget.session.token)}', onMensaje: _manejarMensajeWs);
    _cargarDatos().then((_) {
      _ws.iniciar();
      _cargarMensajes();
      _cargarUsuarios();
    });
    _actualizarEstadoNotif();
    _registrarFcmToken();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _ws.iniciar();
      _cargarDatos(silencioso: true);
    }
  }

  Future<void> _registrarFcmToken() async {
    try {
      final token = await getFcmToken();
      if (token != null) {
        await _api.registrarFcmToken(widget.session.username, token);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ws.detener();
    super.dispose();
  }

  // ── Datos principales ──────────────────────────────────────────────────────

  Future<void> _cargarDatos({bool silencioso = false}) async {
    if (!mounted) return;
    try {
      final results = await Future.wait([_api.fetchTickets(), _api.fetchEquipos()]);
      if (!mounted) return;
      final nuevosTickets = results[0] as List<Ticket>;
      final nuevosEquipos = results[1] as List<Equipo>;
      if (silencioso) _detectarCambiosYNotificar(nuevosTickets);
      setState(() {
        _tickets = nuevosTickets;
        _inventario = nuevosEquipos;
        _cargandoInicial = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _cargandoInicial = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _cargarMensajes() async {
    try {
      final msgs = await _api.fetchMensajes();
      if (mounted) setState(() => _mensajes = msgs);
    } catch (_) {}
  }

  Future<void> _cargarUsuarios() async {
    try {
      final lista = await _api.fetchUsuarios();
      if (mounted) setState(() => _usuarios = lista);
    } catch (_) {}
  }

  // ── WebSocket ──────────────────────────────────────────────────────────────

  void _manejarMensajeWs(Map<String, dynamic> datos) {
    final tipo = datos['tipo'] as String? ?? '';
    if (tipo == 'chat') {
      final msg = ChatMessage.fromMap(datos);
      if (_mensajes.any((m) => m.id == msg.id)) return;
      setState(() {
        _mensajes = [..._mensajes, msg];
        if (_screenIndex != 4) _mensajesNoLeidos++;
      });
      if (_screenIndex != 4) {
        NotificationService.lanzarAlertaLocal(
          'Mensaje de ${msg.nombreCompleto}',
          msg.texto.isNotEmpty ? msg.texto : '📷 Imagen',
        );
      }
    } else if (tipo == 'chat_borrado') {
      final id = datos['id']?.toString() ?? '';
      final borradoPor = datos['borradoPor']?.toString() ?? '';
      setState(() {
        _mensajes = _mensajes.map((m) => m.id == id ? m.copyWith(borrado: true, borradoPor: borradoPor) : m).toList();
      });
    } else if (tipo == 'usuarios') {
      _cargarUsuarios();
    } else {
      _cargarDatos(silencioso: true);
    }
  }

  // ── Notificaciones de tickets ──────────────────────────────────────────────

  void _detectarCambiosYNotificar(List<Ticket> nuevosTickets) {
    final idsConocidos = {for (final t in _tickets) t.id: t};
    for (final t in nuevosTickets) {
      final viejo = idsConocidos[t.id];
      if (viejo == null) {
        final esRelevante = widget.session.rol == 'Admin' ||
            t.asignadoA.toLowerCase() == widget.session.username.toLowerCase();
        if (esRelevante) {
          NotificationService.lanzarAlertaLocal('Nuevo ticket ${t.id}', '${t.usuario} · ${t.departamento}: ${t.descripcion}');
        }
      } else if (viejo.estado != t.estado) {
        final esRelevante = widget.session.rol == 'Admin' ||
            t.asignadoA.toLowerCase() == widget.session.username.toLowerCase();
        if (esRelevante) {
          NotificationService.lanzarAlertaLocal('${t.id} — Estado actualizado', '${viejo.estado} → ${t.estado}');
        }
      } else if (viejo.asignadoA != t.asignadoA &&
          t.asignadoA.toLowerCase() == widget.session.username.toLowerCase()) {
        NotificationService.lanzarAlertaLocal('Ticket asignado: ${t.id}', '${t.usuario} · ${t.departamento}: ${t.descripcion}');
      }
    }
  }

  // ── Permisos de notificación ───────────────────────────────────────────────

  void _actualizarEstadoNotif() async {
    try {
      await initNotifHelperIfNeeded();
      final permiso = notifPermission;
      final estado = permiso == 'granted' ? 'granted' : permiso == 'denied' ? 'denied' : 'default';
      if (mounted) setState(() => _notifPermiso = estado);
    } catch (_) {}
  }

  Future<void> _pedirPermisoNotificaciones() async {
    try {
      final resultado = await requestNotifPermission();
      if (mounted) setState(() => _notifPermiso = resultado);
      if (resultado == 'granted' && mounted) {
        NotificationService.lanzarAlertaLocal('Notificaciones activadas', 'Recibirás alertas de tickets y cambios.');
      } else if (resultado == 'denied' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Notificaciones bloqueadas. Habilítalas en la configuración.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 4),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Las notificaciones no están disponibles en esta plataforma.'),
          duration: Duration(seconds: 4),
        ));
      }
    }
  }

  // ── Sesión ─────────────────────────────────────────────────────────────────

  Future<void> _logout() async {
    _ws.detener();
    widget.notifService.detener();
    await Session.limpiar();
    if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_cargandoInicial) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final screens = [
      DashboardScreen(tickets: _tickets, inventario: _inventario, session: widget.session, onNavigate: (i) => setState(() => _screenIndex = i)),
      TicketsScreen(tickets: _tickets, usuarios: _usuarios, session: widget.session, api: _api, onRefresh: () => _cargarDatos(silencioso: true)),
      EquipmentScreen(inventario: _inventario, session: widget.session, api: _api, onRefresh: () => _cargarDatos(silencioso: true)),
      PantallaRespaldos(inventario: _inventario, api: _api, onRefresh: () => _cargarDatos(silencioso: true), session: widget.session),
      ChatScreen(
        mensajes: _mensajes,
        session: widget.session,
        api: _api,
        usuarios: _usuarios,
        onVolver: () => setState(() => _screenIndex = _screenAnterior),
        onBorrarMensaje: (id) async {
          await _api.borrarMensaje(id);
          setState(() {
            _mensajes = _mensajes.map((m) => m.id == id ? m.copyWith(borrado: true, borradoPor: widget.session.username) : m).toList();
          });
        },
      ),
      if (widget.session.rol == 'Admin') ...[
        UsersScreen(
          usuarios: _usuarios,
          api: _api,
          onRefresh: _cargarUsuarios,
        ),
        AdminScreen(api: _api),
        ReportesScreen(api: _api),
        AiScreen(api: _api, session: widget.session),
      ],
    ];

    return Scaffold(
      floatingActionButton: _screenIndex != 4
          ? _buildFabChat()
          : null,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text(
          'Soporte Beta — ${widget.session.rol}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(_notifPermiso == 'granted' ? Icons.notifications_active : Icons.notifications_off),
            tooltip: _notifPermiso == 'granted' ? 'Notificaciones activas' : 'Activar notificaciones',
            color: _notifPermiso == 'granted' ? Colors.greenAccent : Colors.white60,
            onPressed: _notifPermiso == 'granted' ? null : _pedirPermisoNotificaciones,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _cargarDatos(silencioso: true), tooltip: 'Recargar'),
          IconButton(icon: const Icon(Icons.logout_rounded), onPressed: _logout, tooltip: 'Cerrar sesión'),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.monitor_heart, size: 36, color: Colors.white),
                  const SizedBox(height: 8),
                  Text(widget.session.nombreCompleto, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Rol TI: ${widget.session.rol}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            _item(Icons.dashboard_rounded, 'Dashboard', 0),
            _item(Icons.confirmation_number_rounded, 'Tickets / Asignaciones', 1),
            _item(Icons.computer_rounded, 'Equipos / Responsivas', 2),
            _item(Icons.backup_rounded, 'Control de Respaldos', 3),
            _itemChat(),
            if (widget.session.rol == 'Admin') ...[
              const Divider(),
              _item(Icons.manage_accounts_rounded, 'Gestión de Usuarios', 5),
              _item(Icons.settings_rounded, 'Administración', 6),
              _item(Icons.bar_chart_rounded, 'Reportes', 7),
              _item(Icons.smart_toy_rounded, 'Asistente IA', 8),
            ],
          ],
        ),
      ),
      body: _screenIndex < screens.length ? screens[_screenIndex] : screens[0],
    );
  }

  Widget _buildFabChat() {
    final color = Theme.of(context).colorScheme.primary;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        FloatingActionButton(
          heroTag: 'fab_chat',
          backgroundColor: color,
          foregroundColor: Colors.white,
          tooltip: 'Chat Interno',
          onPressed: () {
            setState(() {
              _screenAnterior = _screenIndex;
              _screenIndex = 4;
              _mensajesNoLeidos = 0;
            });
          },
          child: const Icon(Icons.chat_rounded),
        ),
        if (_mensajesNoLeidos > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                '$_mensajesNoLeidos',
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  ListTile _item(IconData icon, String label, int index) => ListTile(
        leading: Icon(icon),
        title: Text(label),
        selected: _screenIndex == index,
        onTap: () {
          setState(() => _screenIndex = index);
          Navigator.pop(context);
        },
      );

  ListTile _itemChat() => ListTile(
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.chat_rounded),
            if (_mensajesNoLeidos > 0)
              Positioned(
                right: -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    '$_mensajesNoLeidos',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        title: const Text('Chat Interno'),
        selected: _screenIndex == 4,
        onTap: () {
          setState(() {
            _screenAnterior = _screenIndex;
            _screenIndex = 4;
            _mensajesNoLeidos = 0;
          });
          Navigator.pop(context);
        },
      );
}
