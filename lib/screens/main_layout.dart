import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../models/session_model.dart';
import '../models/ticket_model.dart';
import '../models/equipo_model.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/websocket_service.dart';
import 'dashboard_screen.dart';
import 'tickets_screen.dart';
import 'equipment_screen.dart';
import 'backups_screen.dart';
import 'login_screen.dart';

const String kWsUrl = 'ws://54.161.41.131:8000/ws';

class MainLayout extends StatefulWidget {
  final Session session;
  final NotificationService notifService;

  const MainLayout({super.key, required this.session, required this.notifService});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _screenIndex = 0;
  List<Ticket> _tickets = [];
  List<Equipo> _inventario = [];
  bool _cargandoInicial = true;
  String _notifPermiso = 'default';
  late final ApiService _api;
  late final WebSocketService _ws;

  @override
  void initState() {
    super.initState();
    _api = ApiService(token: widget.session.token);
    _ws = WebSocketService(
      url: kWsUrl,
      onMensaje: () => _cargarDatos(silencioso: true),
    );
    _cargarDatos().then((_) => _ws.iniciar());
    _actualizarEstadoNotif();
  }

  @override
  void dispose() {
    _ws.detener();
    super.dispose();
  }

  Future<void> _cargarDatos({bool silencioso = false}) async {
    if (!mounted) return;
    try {
      final results = await Future.wait([
        _api.fetchTickets(),
        _api.fetchEquipos(),
      ]);
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

  void _detectarCambiosYNotificar(List<Ticket> nuevosTickets) {
    final idsConocidos = {for (final t in _tickets) t.id: t};

    for (final t in nuevosTickets) {
      final viejo = idsConocidos[t.id];

      if (viejo == null) {
        // Ticket nuevo
        final esRelevante = widget.session.rol == 'Admin' ||
            t.asignadoA.toLowerCase() == widget.session.username.toLowerCase();
        if (esRelevante) {
          NotificationService.lanzarAlertaLocal(
            'Nuevo ticket ${t.id}',
            '${t.usuario} · ${t.departamento}: ${t.descripcion}',
          );
        }
      } else if (viejo.estado != t.estado) {
        // Cambio de estado
        final esRelevante = widget.session.rol == 'Admin' ||
            t.asignadoA.toLowerCase() == widget.session.username.toLowerCase();
        if (esRelevante) {
          NotificationService.lanzarAlertaLocal(
            '${t.id} — Estado actualizado',
            '${viejo.estado} → ${t.estado}',
          );
        }
      } else if (viejo.asignadoA != t.asignadoA) {
        // Reasignación
        if (t.asignadoA.toLowerCase() == widget.session.username.toLowerCase()) {
          NotificationService.lanzarAlertaLocal(
            'Ticket asignado: ${t.id}',
            '${t.usuario} · ${t.departamento}: ${t.descripcion}',
          );
        }
      }
    }
  }

  void _actualizarEstadoNotif() {
    try {
      final permiso = web.Notification.permission == 'granted' ? 'granted'
          : web.Notification.permission == 'denied' ? 'denied' : 'default';
      if (mounted) setState(() => _notifPermiso = permiso);
    } catch (_) {}
  }

  Future<void> _pedirPermisoNotificaciones() async {
    try {
      final jsResultado = await web.Notification.requestPermission().toDart;
      final resultado = jsResultado.toDart;
      if (mounted) setState(() => _notifPermiso = resultado);
      if (resultado == 'granted' && mounted) {
        NotificationService.lanzarAlertaLocal('Notificaciones activadas', 'Recibirás alertas de tickets y cambios.');
      } else if (resultado == 'denied' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Notificaciones bloqueadas. Habilítalas en la configuración del navegador.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 4),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Las notificaciones requieren HTTPS. Próximamente disponibles en móvil.'),
          duration: Duration(seconds: 4),
        ));
      }
    }
  }

  void _logout() {
    _ws.detener();
    widget.notifService.detener();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    if (_cargandoInicial) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final screens = [
      DashboardScreen(tickets: _tickets, inventario: _inventario, session: widget.session, onNavigate: (i) => setState(() => _screenIndex = i)),
      TicketsScreen(tickets: _tickets, session: widget.session, api: _api, onRefresh: () => _cargarDatos(silencioso: true)),
      EquipmentScreen(inventario: _inventario, session: widget.session, api: _api, onRefresh: () => _cargarDatos(silencioso: true)),
      PantallaRespaldos(inventario: _inventario, api: _api, onRefresh: () => _cargarDatos(silencioso: true), session: widget.session),
    ];

    return Scaffold(
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
          ],
        ),
      ),
      body: screens[_screenIndex],
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
}
