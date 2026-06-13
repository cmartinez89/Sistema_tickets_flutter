import 'package:flutter/material.dart';
import '../models/session_model.dart';
import '../models/ticket_model.dart';
import '../models/equipo_model.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import 'dashboard_screen.dart';
import 'tickets_screen.dart';
import 'equipment_screen.dart';
import 'backups_screen.dart';
import 'login_screen.dart';

class MainLayout extends StatefulWidget {
  final Session session;
  final NotificationService notifService;

  const MainLayout({super.key, required this.session, required this.notifService});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _screenIndex = 1;
  List<Ticket> _tickets = [];
  List<Equipo> _inventario = [];
  bool _cargando = true;
  late final ApiService _api;

  @override
  void initState() {
    super.initState();
    _api = ApiService(token: widget.session.token);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    if (!mounted) return;
    setState(() => _cargando = true);
    try {
      final results = await Future.wait([
        _api.fetchTickets(),
        _api.fetchEquipos(),
      ]);
      if (!mounted) return;
      setState(() {
        _tickets = results[0] as List<Ticket>;
        _inventario = results[1] as List<Equipo>;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _logout() {
    widget.notifService.detener();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final screens = [
      DashboardScreen(tickets: _tickets, inventario: _inventario, session: widget.session),
      TicketsScreen(tickets: _tickets, session: widget.session, api: _api, onRefresh: _cargarDatos),
      EquipmentScreen(inventario: _inventario, session: widget.session, api: _api, onRefresh: _cargarDatos),
      PantallaRespaldos(inventario: _inventario, api: _api, onRefresh: _cargarDatos, session: widget.session),
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
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarDatos, tooltip: 'Recargar'),
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