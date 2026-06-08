import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ============================================================================
// CONFIGURACIÓN DE RED
// Mueve esta URL a un archivo de config o variable de entorno en producción.
// ============================================================================
const String kApiUrl = 'http://54.161.41.131:8000';
const Duration kTimeout = Duration(seconds: 15);

// Lista única de técnicos para no repetirla en múltiples lugares
const List<String> kTecnicos = ['Sin Asignar', 'Carlos', 'Benjamin', 'Julio'];

void main() {
  runApp(const SoporteBetaApp());
}

class SoporteBetaApp extends StatelessWidget {
  const SoporteBetaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Soporte Beta',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00695C),
          primary: const Color(0xFF00695C),
        ),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

// ============================================================================
// MODELOS DE DATOS
// ============================================================================
class Ticket {
  final String id;
  final String usuario;
  final String departamento;
  final String descripcion;
  final String prioridad;
  String estado;
  String asignadoA;
  final DateTime fecha;

  Ticket({
    required this.id,
    required this.usuario,
    required this.departamento,
    required this.descripcion,
    required this.prioridad,
    required this.estado,
    required this.asignadoA,
    required this.fecha,
  });

  factory Ticket.fromMap(Map<String, dynamic> map) => Ticket(
    id: map['id'],
    usuario: map['usuario'],
    departamento: map['departamento'],
    descripcion: map['descripcion'],
    prioridad: map['prioridad'] ?? 'Media',
    estado: map['estado'],
    asignadoA: map['asignadoA'],
    fecha: DateTime.parse(map['fecha']),
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'usuario': usuario,
    'departamento': departamento,
    'descripcion': descripcion,
    'prioridad': prioridad,
    'estado': estado,
    'asignadoA': asignadoA,
    'fecha': fecha.toIso8601String(),
  };
}

class Equipo {
  final String id;
  String folioResponsiva;
  final String tipo;
  final String marca;
  final String modelo;
  final String noSerie;
  final String accesorios;
  final int anoAdquisicion;
  final double valorAdquisicion;
  final String specifications;
  String estatus;
  String? empleadoAsignado;
  String? rolEmpleado;
  String ubicacion;
  String anydesk;
  String rustdesk;
  DateTime? ultimoRespaldo;
  String comentarios;

  Equipo({
    required this.id,
    required this.folioResponsiva,
    required this.tipo,
    required this.marca,
    required this.modelo,
    required this.noSerie,
    required this.accesorios,
    required this.anoAdquisicion,
    required this.valorAdquisicion,
    required this.specifications,
    required this.estatus,
    this.empleadoAsignado,
    this.rolEmpleado,
    this.ubicacion = 'Beta',
    this.anydesk = '',
    this.rustdesk = '',
    this.ultimoRespaldo,
    this.comentarios = '',
  });

  int? get diasUltimoRespaldo {
    if (ultimoRespaldo == null) return null;
    return DateTime.now().difference(ultimoRespaldo!).inDays;
  }

  double get valorActual {
    final int anosPasados = DateTime.now().year - anoAdquisicion;
    if (anosPasados <= 0) return valorAdquisicion;
    if (anosPasados >= 5) return valorAdquisicion * 0.20;
    return valorAdquisicion * (1.0 - anosPasados * 0.20);
  }

  factory Equipo.fromMap(Map<String, dynamic> map) => Equipo(
    id: map['id'],
    folioResponsiva: map['folioResponsiva'],
    tipo: map['tipo'],
    marca: map['marca'],
    modelo: map['modelo'],
    noSerie: map['noSerie'],
    accesorios: map['accesorios'],
    anoAdquisicion: map['anoAdquisicion'],
    valorAdquisicion: (map['valorAdquisicion'] ?? 0).toDouble(),
    specifications: map['specifications'] ?? '',
    estatus: map['estatus'],
    empleadoAsignado: map['empleadoAsignado'],
    rolEmpleado: map['rolEmpleado'],
    ubicacion: map['ubicacion'] ?? 'Beta',
    anydesk: map['anydesk'] ?? '',
    rustdesk: map['rustdesk'] ?? '',
    ultimoRespaldo: map['ultimoRespaldo'] != null
        ? DateTime.parse(map['ultimoRespaldo'])
        : null,
    comentarios: map['comentarios'] ?? '',
  );
}

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
}

// ============================================================================
// SERVICIO DE API (Capa separada de la UI)
// ============================================================================
class ApiService {
  final String token;
  ApiService({required this.token});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  Future<List<Ticket>> fetchTickets() async {
    final res = await http
        .get(Uri.parse('$kApiUrl/tickets'), headers: _headers)
        .timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al cargar tickets');
    final List<dynamic> data = jsonDecode(res.body);
    return data.map((e) => Ticket.fromMap(e)).toList();
  }

  Future<List<Equipo>> fetchEquipos() async {
    final res = await http
        .get(Uri.parse('$kApiUrl/equipos'), headers: _headers)
        .timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al cargar equipos');
    final List<dynamic> data = jsonDecode(res.body);
    return data.map((e) => Equipo.fromMap(e)).toList();
  }

  Future<Ticket> crearTicket(Ticket ticket) async {
    final res = await http
        .post(
          Uri.parse('$kApiUrl/tickets'),
          headers: _headers,
          body: jsonEncode(ticket.toMap()),
        )
        .timeout(kTimeout);
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('Error al crear ticket');
    }
    return Ticket.fromMap(jsonDecode(res.body));
  }

  Future<void> cambiarEstatusTicket(String ticketId, String nuevoEstado) async {
    final res = await http
        .put(
          Uri.parse('$kApiUrl/tickets/$ticketId/status'),
          headers: _headers,
          body: jsonEncode({'estado': nuevoEstado}),
        )
        .timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al actualizar estatus');
  }

  Future<void> reasignarTicket(String ticketId, String tecnico) async {
    final res = await http
        .put(
          Uri.parse('$kApiUrl/tickets/$ticketId/assign'),
          headers: _headers,
          body: jsonEncode({'asignadoA': tecnico}),
        )
        .timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al reasignar ticket');
  }

  Future<void> asignarEquipo(
    String equipoId, {
    required String empleado,
    required String rol,
    required String folio,
  }) async {
    final res = await http
        .put(
          Uri.parse('$kApiUrl/equipos/$equipoId/assign'),
          headers: _headers,
          body: jsonEncode({
            'empleadoAsignado': empleado,
            'rolEmpleado': rol,
            'folioResponsiva': folio,
            'estatus': 'Asignado',
          }),
        )
        .timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al asignar equipo');
  }

  Future<void> liberarEquipo(String equipoId) async {
    final res = await http
        .put(
          Uri.parse('$kApiUrl/equipos/$equipoId/release'),
          headers: _headers,
          body: jsonEncode({
            'empleadoAsignado': null,
            'rolEmpleado': null,
            'folioResponsiva': '---',
            'estatus': 'Disponible',
          }),
        )
        .timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al liberar equipo');
  }

  Future<void> actualizarRespaldo(String equipoId, DateTime fecha) async {
    final res = await http
        .put(
          Uri.parse('$kApiUrl/equipos/$equipoId/backup'),
          headers: _headers,
          body: jsonEncode({'ultimoRespaldo': fecha.toIso8601String()}),
        )
        .timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al actualizar respaldo');
  }
}

// ============================================================================
// HELPERS GLOBALES
// ============================================================================
Color statusColor(String estado) {
  switch (estado) {
    case 'Pendiente':
      return Colors.red.shade700;
    case 'En Proceso':
      return Colors.orange.shade800;
    case 'Resuelto':
      return Colors.green.shade700;
    default:
      return Colors.grey;
  }
}

void mostrarSnackBar(
  BuildContext context,
  String mensaje, {
  bool error = false,
}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mensaje),
      backgroundColor: error ? Colors.redAccent : null,
    ),
  );
}

// ============================================================================
// PANTALLA: LOGIN
// ============================================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final response = await http
          .post(
            Uri.parse('$kApiUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': _usernameController.text.trim().toLowerCase(),
              'password': _passwordController.text,
            }),
          )
          .timeout(kTimeout);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final session = Session(
          username: data['username'],
          nombreCompleto: data['nombreCompleto'],
          rol: data['rol'],
          // Si tu backend aún no devuelve token, usa string vacío por ahora
          token: data['token'] ?? '',
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainLayout(session: session)),
        );
      } else {
        mostrarSnackBar(
          context,
          'Credenciales incorrectas o usuario no encontrado',
          error: true,
        );
      }
    } catch (e) {
      if (mounted) {
        mostrarSnackBar(
          context,
          'Error de conexión con el servidor: $e',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Icon(
                        Icons.cloud_sync_rounded,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Soporte Beta v1.2',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Conectado a AWS Cloud',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Usuario',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Requerido'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          border: OutlineInputBorder(),
                        ),
                        onFieldSubmitted: (_) => _handleLogin(),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Requerido'
                            : null,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text('Ingresar'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ESTRUCTURA BASE Y CONTROL DE DATOS
// ============================================================================
class MainLayout extends StatefulWidget {
  final Session session;
  const MainLayout({super.key, required this.session});

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
      if (mounted)
        mostrarSnackBar(context, 'Error al cargar datos: $e', error: true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final screens = [
      DashboardScreen(tickets: _tickets, session: widget.session),
      TicketsScreen(
        tickets: _tickets,
        session: widget.session,
        api: _api,
        onRefresh: _cargarDatos,
      ),
      EquipmentScreen(
        inventario: _inventario,
        session: widget.session,
        api: _api,
        onRefresh: _cargarDatos,
      ),
      PantallaRespaldos(
        inventario: _inventario,
        api: _api,
        onRefresh: _cargarDatos,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text(
          'Soporte Beta — ${widget.session.rol}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarDatos,
            tooltip: 'Recargar datos',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.monitor_heart,
                    size: 36,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.session.nombreCompleto,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Rol TI: ${widget.session.rol}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            _drawerItem(Icons.dashboard_rounded, 'Dashboard', 0),
            _drawerItem(
              Icons.confirmation_number_rounded,
              'Tickets / Asignaciones',
              1,
            ),
            _drawerItem(Icons.computer_rounded, 'Equipos / Responsivas', 2),
            _drawerItem(Icons.backup_rounded, 'Control de Respaldos', 3),
          ],
        ),
      ),
      body: screens[_screenIndex],
    );
  }

  ListTile _drawerItem(IconData icon, String label, int index) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: _screenIndex == index,
      onTap: () {
        setState(() => _screenIndex = index);
        Navigator.pop(context);
      },
    );
  }
}

// ============================================================================
// PANTALLA: DASHBOARD
// ============================================================================
class DashboardScreen extends StatelessWidget {
  final List<Ticket> tickets;
  final Session session;

  const DashboardScreen({
    super.key,
    required this.tickets,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final visibles = session.rol == 'Admin'
        ? tickets
        : tickets
              .where(
                (t) =>
                    t.asignadoA.toLowerCase() == session.username.toLowerCase(),
              )
              .toList();

    final activos = visibles.where((t) => t.estado != 'Resuelto').length;
    final resueltos = visibles.where((t) => t.estado == 'Resuelto').length;
    final alta = visibles
        .where((t) => t.prioridad == 'Alta' && t.estado != 'Resuelto')
        .length;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            session.rol == 'Admin'
                ? 'Consola de Control Global'
                : 'Mis Tareas TI',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          _dashCard(
            icon: Icons.assignment_late_rounded,
            color: Colors.orange,
            titulo: 'Tickets Activos en Cola',
            subtitulo: '$activos solicitudes esperando atención.',
          ),
          const SizedBox(height: 12),
          _dashCard(
            icon: Icons.check_circle_rounded,
            color: Colors.green,
            titulo: 'Tickets Resueltos',
            subtitulo: '$resueltos tickets completados.',
          ),
          const SizedBox(height: 12),
          _dashCard(
            icon: Icons.priority_high_rounded,
            color: Colors.red,
            titulo: 'Prioridad Alta Pendientes',
            subtitulo: '$alta tickets críticos sin resolver.',
          ),
        ],
      ),
    );
  }

  Widget _dashCard({
    required IconData icon,
    required Color color,
    required String titulo,
    required String subtitulo,
  }) {
    return Card(
      color: color.withOpacity(0.08),
      child: ListTile(
        leading: Icon(icon, color: color, size: 40),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitulo),
      ),
    );
  }
}

// ============================================================================
// PANTALLA: GESTIÓN DE TICKETS
// ============================================================================
class TicketsScreen extends StatefulWidget {
  final List<Ticket> tickets;
  final Session session;
  final ApiService api;
  final VoidCallback onRefresh;

  const TicketsScreen({
    super.key,
    required this.tickets,
    required this.session,
    required this.api,
    required this.onRefresh,
  });

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioController = TextEditingController();
  final _deptoController = TextEditingController();
  final _descController = TextEditingController();
  String _prioridadSeleccionada = 'Media';
  String _asignadoPorDefecto = 'Sin Asignar';
  String _filtroActual = 'Activos';
  bool _guardando = false;

  @override
  void dispose() {
    _usuarioController.dispose();
    _deptoController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _openNewTicketDialog() {
    _usuarioController.clear();
    _deptoController.clear();
    _descController.clear();
    _prioridadSeleccionada = 'Media';
    _asignadoPorDefecto = 'Sin Asignar';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text(
            'Levantar Reporte Técnico',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _usuarioController,
                      decoration: const InputDecoration(
                        labelText: 'Usuario Afectado',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _deptoController,
                      decoration: const InputDecoration(
                        labelText: 'Departamento',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _prioridadSeleccionada,
                      decoration: const InputDecoration(
                        labelText: 'Prioridad',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Baja', 'Media', 'Alta']
                          .map(
                            (p) => DropdownMenuItem(value: p, child: Text(p)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setDialogState(() => _prioridadSeleccionada = val!),
                    ),
                    const SizedBox(height: 12),
                    if (widget.session.rol == 'Admin')
                      DropdownButtonFormField<String>(
                        value: _asignadoPorDefecto,
                        decoration: const InputDecoration(
                          labelText: 'Técnico Responsable',
                          border: OutlineInputBorder(),
                        ),
                        items: kTecnicos
                            .map(
                              (p) => DropdownMenuItem(value: p, child: Text(p)),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setDialogState(() => _asignadoPorDefecto = val!),
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Descripción de la falla',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Explique el problema'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            StatefulBuilder(
              builder: (ctx2, setBtn) => ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: _guardando
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        setBtn(() => _guardando = true);

                        final nuevo = Ticket(
                          id: '',
                          usuario: _usuarioController.text.trim(),
                          departamento: _deptoController.text.trim(),
                          descripcion: _descController.text.trim(),
                          prioridad: _prioridadSeleccionada,
                          estado: 'Pendiente',
                          asignadoA: widget.session.rol == 'Admin'
                              ? _asignadoPorDefecto
                              : 'Sin Asignar',
                          fecha: DateTime.now(),
                        );

                        try {
                          await widget.api.crearTicket(nuevo);
                          if (ctx.mounted) Navigator.pop(ctx);
                          widget.onRefresh();
                        } catch (e) {
                          if (ctx.mounted) {
                            mostrarSnackBar(
                              ctx,
                              'Error al crear ticket: $e',
                              error: true,
                            );
                          }
                        } finally {
                          setBtn(() => _guardando = false);
                        }
                      },
                child: _guardando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text('Registrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cambiarEstatus(Ticket ticket, String nuevoEstado) async {
    try {
      await widget.api.cambiarEstatusTicket(ticket.id, nuevoEstado);
      setState(() => ticket.estado = nuevoEstado);
    } catch (e) {
      if (mounted)
        mostrarSnackBar(context, 'Error al actualizar: $e', error: true);
    }
  }

  Future<void> _reasignar(Ticket ticket, String tecnico) async {
    try {
      await widget.api.reasignarTicket(ticket.id, tecnico);
      setState(() => ticket.asignadoA = tecnico);
    } catch (e) {
      if (mounted)
        mostrarSnackBar(context, 'Error al reasignar: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Ticket> filtrados = widget.session.rol == 'Admin'
        ? widget.tickets
        : widget.tickets
              .where(
                (t) =>
                    t.asignadoA.toLowerCase() ==
                        widget.session.username.toLowerCase() ||
                    t.asignadoA == widget.session.nombreCompleto,
              )
              .toList();

    if (_filtroActual == 'Activos') {
      filtrados = filtrados.where((t) => t.estado != 'Resuelto').toList();
    } else if (_filtroActual == 'Resueltos') {
      filtrados = filtrados.where((t) => t.estado == 'Resuelto').toList();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Consola Soporte (${filtrados.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _openNewTicketDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Nuevo'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['Activos', 'Resueltos', 'Todos']
                    .map(
                      (f) => Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: ChoiceChip(
                          label: Text(
                            f,
                            style: TextStyle(
                              fontWeight: _filtroActual == f
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          selected: _filtroActual == f,
                          onSelected: (sel) {
                            if (sel) setState(() => _filtroActual = f);
                          },
                          selectedColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtrados.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay tickets en esta categoría.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: filtrados.length,
                      itemBuilder: (context, index) {
                        final ticket = filtrados[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ExpansionTile(
                            leading: Icon(
                              Icons.circle,
                              size: 12,
                              color: ticket.prioridad == 'Alta'
                                  ? Colors.red
                                  : ticket.prioridad == 'Media'
                                  ? Colors.orange
                                  : Colors.blue,
                            ),
                            title: Text(
                              ticket.descripcion,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              'ID: ${ticket.id} • ${ticket.usuario}\nAsignado a: ${ticket.asignadoA}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor(
                                  ticket.estado,
                                ).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                ticket.estado,
                                style: TextStyle(
                                  color: statusColor(ticket.estado),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Descripción completa:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                    Text(
                                      ticket.descripcion,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    const Divider(),
                                    const Text(
                                      'Cambiar Estatus:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Wrap(
                                      spacing: 6,
                                      children:
                                          [
                                                'Pendiente',
                                                'En Proceso',
                                                'Resuelto',
                                              ]
                                              .map(
                                                (e) => ChoiceChip(
                                                  label: Text(
                                                    e,
                                                    style: const TextStyle(
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                  selected: ticket.estado == e,
                                                  onSelected: (_) =>
                                                      _cambiarEstatus(
                                                        ticket,
                                                        e,
                                                      ),
                                                ),
                                              )
                                              .toList(),
                                    ),
                                    if (widget.session.rol == 'Admin') ...[
                                      const Divider(),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'Reasignar Responsable:',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.indigo,
                                            ),
                                          ),
                                          DropdownButton<String>(
                                            value:
                                                kTecnicos.contains(
                                                  ticket.asignadoA,
                                                )
                                                ? ticket.asignadoA
                                                : 'Sin Asignar',
                                            underline: Container(),
                                            style: const TextStyle(
                                              color: Colors.black87,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                            items: kTecnicos
                                                .map(
                                                  (e) => DropdownMenuItem(
                                                    value: e,
                                                    child: Text(e),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: (tecnico) {
                                              if (tecnico != null) {
                                                _reasignar(ticket, tecnico);
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PANTALLA: INVENTARIO Y CONTROL DE RESPONSIVAS
// ============================================================================
class EquipmentScreen extends StatefulWidget {
  final List<Equipo> inventario;
  final Session session;
  final ApiService api;
  final VoidCallback onRefresh;

  const EquipmentScreen({
    super.key,
    required this.inventario,
    required this.session,
    required this.api,
    required this.onRefresh,
  });

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  final _assignFormKey = GlobalKey<FormState>();
  final _empleadoController = TextEditingController();
  final _puestoController = TextEditingController();
  final _folioController = TextEditingController();

  @override
  void dispose() {
    _empleadoController.dispose();
    _puestoController.dispose();
    _folioController.dispose();
    super.dispose();
  }

  void _liberarHardware(Equipo equipo) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text('Liberar Folio ${equipo.folioResponsiva}'),
          ],
        ),
        content: Text(
          '¿Confirmas la baja del empleado? El equipo quedará como "Disponible" y se desvinculará de "${equipo.empleadoAsignado}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.api.liberarEquipo(equipo.id);
                setState(() {
                  equipo.estatus = 'Disponible';
                  equipo.empleadoAsignado = null;
                  equipo.rolEmpleado = null;
                  equipo.folioResponsiva = '---';
                });
                if (mounted)
                  mostrarSnackBar(context, 'Hardware liberado correctamente.');
              } catch (e) {
                if (mounted)
                  mostrarSnackBar(context, 'Error al liberar: $e', error: true);
              }
            },
            child: const Text('Confirmar Baja'),
          ),
        ],
      ),
    );
  }

  void _asignarHardware(Equipo equipo) {
    _empleadoController.clear();
    _puestoController.clear();
    _folioController.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add_alt_1_rounded, color: Colors.teal),
            SizedBox(width: 8),
            Text(
              'Asignar Activo',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Form(
            key: _assignFormKey,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${equipo.marca} - ${equipo.modelo}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _empleadoController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Empleado',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ingrese el nombre'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _puestoController,
                    decoration: const InputDecoration(
                      labelText: 'Puesto / Rol',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.work),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ingrese el puesto'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _folioController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Folio de Responsiva',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Ingrese el folio'
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (!_assignFormKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              try {
                await widget.api.asignarEquipo(
                  equipo.id,
                  empleado: _empleadoController.text.trim(),
                  rol: _puestoController.text.trim(),
                  folio: _folioController.text.trim(),
                );
                setState(() {
                  equipo.estatus = 'Asignado';
                  equipo.empleadoAsignado = _empleadoController.text.trim();
                  equipo.rolEmpleado = _puestoController.text.trim();
                  equipo.folioResponsiva = _folioController.text.trim();
                });
                if (mounted) {
                  mostrarSnackBar(context, 'Activo asignado correctamente.');
                }
              } catch (e) {
                if (mounted)
                  mostrarSnackBar(context, 'Error al asignar: $e', error: true);
              }
            },
            child: const Text('Guardar Asignación'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Control de Activos y Cartas Responsivas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey.shade800,
              ),
            ),
            Text(
              '${widget.inventario.length} equipos sincronizados desde AWS',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: widget.inventario.length,
                itemBuilder: (context, index) {
                  final equipo = widget.inventario[index];
                  final esAsignado = equipo.estatus == 'Asignado';

                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ExpansionTile(
                      leading: Icon(
                        equipo.tipo == 'Laptop'
                            ? Icons.laptop_mac_rounded
                            : equipo.tipo == 'Servidor'
                            ? Icons.dns_rounded
                            : Icons.computer_rounded,
                        color: esAsignado
                            ? Colors.indigo.shade700
                            : Colors.teal.shade700,
                      ),
                      title: Text(
                        '${equipo.marca} - ${equipo.modelo}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        'S/N: ${equipo.noSerie}\nFolio Carta: ${equipo.folioResponsiva}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: esAsignado
                              ? Colors.indigo.shade50
                              : Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          equipo.estatus,
                          style: TextStyle(
                            color: esAsignado
                                ? Colors.indigo.shade700
                                : Colors.teal.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Información de Asignación:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey.shade700,
                                  fontSize: 13,
                                ),
                              ),
                              if (esAsignado) ...[
                                Text(
                                  'Empleado: ${equipo.empleadoAsignado}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                Text(
                                  'Rol/Puesto: ${equipo.rolEmpleado}',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ] else
                                Text(
                                  'Disponible en almacén. (Resguardo: ${equipo.empleadoAsignado ?? "Sistemas"})',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 13,
                                  ),
                                ),
                              const Divider(),
                              Text(
                                'Ficha Técnica e Historial:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey.shade700,
                                  fontSize: 13,
                                ),
                              ),
                              Text(
                                'Especificaciones: ${equipo.specifications}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                'Accesorios: ${equipo.accesorios}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                'Año de Adquisición: ${equipo.anoAdquisicion}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                'Valor Compra: \$${equipo.valorAdquisicion.toStringAsFixed(2)} MXN',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                'Valor Depreciado Actual: \$${equipo.valorActual.toStringAsFixed(2)} MXN',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (widget.session.rol == 'Admin') ...[
                                const Divider(),
                                SizedBox(
                                  width: double.infinity,
                                  child: esAsignado
                                      ? ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red.shade50,
                                            foregroundColor:
                                                Colors.red.shade800,
                                          ),
                                          onPressed: () =>
                                              _liberarHardware(equipo),
                                          icon: const Icon(
                                            Icons.person_remove_alt_1_rounded,
                                            size: 18,
                                          ),
                                          label: const Text(
                                            'Liberar Equipo (Baja de Empleado)',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        )
                                      : ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.teal.shade50,
                                            foregroundColor:
                                                Colors.teal.shade800,
                                          ),
                                          onPressed: () =>
                                              _asignarHardware(equipo),
                                          icon: const Icon(
                                            Icons.person_add_alt_1_rounded,
                                            size: 18,
                                          ),
                                          label: const Text(
                                            'Asignar Equipo (Vincular Responsiva)',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PANTALLA: CONTROL DE RESPALDOS
// ============================================================================
class PantallaRespaldos extends StatefulWidget {
  final List<Equipo> inventario;
  final ApiService api;
  final VoidCallback onRefresh;

  const PantallaRespaldos({
    super.key,
    required this.inventario,
    required this.api,
    required this.onRefresh,
  });

  @override
  State<PantallaRespaldos> createState() => _PantallaRespaldosState();
}

class _PantallaRespaldosState extends State<PantallaRespaldos> {
  Future<void> _actualizarRespaldo(Equipo equipo, DateTime fecha) async {
    try {
      await widget.api.actualizarRespaldo(equipo.id, fecha);
      setState(() => equipo.ultimoRespaldo = fecha);
      if (mounted) {
        mostrarSnackBar(context, 'Respaldo sincronizado con AWS');
      }
    } catch (e) {
      if (mounted) {
        mostrarSnackBar(context, 'Error al sincronizar: $e', error: true);
      }
    }
  }

  String _formatFecha(DateTime? fecha) {
    if (fecha == null) return 'Sin respaldos';
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Control de Respaldos Diarios',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade800,
            ),
          ),
          const Text(
            'Presiona el ícono de nube en cada equipo para actualizar su último respaldo.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              elevation: 2,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      Colors.grey.shade200,
                    ),
                    columns: const [
                      DataColumn(
                        label: Text(
                          'Ubicación',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Nombre / Resguardo',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Equipo (Modelo)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Anydesk',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'RUSTDESK',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Último respaldo',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Días',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Comentarios',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    rows: widget.inventario.map((equipo) {
                      final dias = equipo.diasUltimoRespaldo;
                      Color cellColor = Colors.transparent;
                      if (dias != null) {
                        cellColor = dias >= 15
                            ? Colors.red.shade300
                            : Colors.amber.shade200;
                      }

                      return DataRow(
                        cells: [
                          DataCell(Text(equipo.ubicacion)),
                          DataCell(
                            Text(equipo.empleadoAsignado ?? 'Sistemas (Stock)'),
                          ),
                          DataCell(Text(equipo.modelo)),
                          DataCell(Text(equipo.anydesk)),
                          DataCell(Text(equipo.rustdesk)),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatFecha(equipo.ultimoRespaldo),
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(
                                    Icons.cloud_upload_rounded,
                                    size: 18,
                                    color: Color(0xFF0D47A1),
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: 'Actualizar fecha de respaldo',
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          equipo.ultimoRespaldo ??
                                          DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 365),
                                      ),
                                    );
                                    if (picked != null) {
                                      _actualizarRespaldo(equipo, picked);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Container(
                              width: 50,
                              height: double.infinity,
                              color: cellColor,
                              alignment: Alignment.center,
                              child: Text(
                                dias?.toString() ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          DataCell(Text(equipo.comentarios)),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
