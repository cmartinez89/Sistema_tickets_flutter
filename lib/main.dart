import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;
import 'notification_service.dart';

// ============================================================================
// CONFIGURACIÓN
// ============================================================================
const String kApiUrl = 'http://54.161.41.131:8000';
const Duration kTimeout = Duration(seconds: 15);
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
// MODELOS
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

  // Campos de resolución (se llenan al marcar como Resuelto)
  String? causaRaiz;
  String? comoSeResolvio;
  String? pruebasRealizadas;
  String? validadoCon;

  Ticket({
    required this.id,
    required this.usuario,
    required this.departamento,
    required this.descripcion,
    required this.prioridad,
    required this.estado,
    required this.asignadoA,
    required this.fecha,
    this.causaRaiz,
    this.comoSeResolvio,
    this.pruebasRealizadas,
    this.validadoCon,
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
    causaRaiz: map['causaRaiz'],
    comoSeResolvio: map['comoSeResolvio'],
    pruebasRealizadas: map['pruebasRealizadas'],
    validadoCon: map['validadoCon'],
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
    if (causaRaiz != null) 'causaRaiz': causaRaiz,
    if (comoSeResolvio != null) 'comoSeResolvio': comoSeResolvio,
    if (pruebasRealizadas != null) 'pruebasRealizadas': pruebasRealizadas,
    if (validadoCon != null) 'validadoCon': validadoCon,
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
    final int anos = DateTime.now().year - anoAdquisicion;
    if (anos <= 0) return valorAdquisicion;
    if (anos >= 5) return valorAdquisicion * 0.20;
    return valorAdquisicion * (1.0 - anos * 0.20);
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
// SERVICIO DE API
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
    return (jsonDecode(res.body) as List)
        .map((e) => Ticket.fromMap(e))
        .toList();
  }

  Future<List<Equipo>> fetchEquipos() async {
    final res = await http
        .get(Uri.parse('$kApiUrl/equipos'), headers: _headers)
        .timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al cargar equipos');
    return (jsonDecode(res.body) as List)
        .map((e) => Equipo.fromMap(e))
        .toList();
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

  Future<void> cambiarEstatusTicket(String id, String estado) async {
    final res = await http
        .put(
          Uri.parse('$kApiUrl/tickets/$id/status'),
          headers: _headers,
          body: jsonEncode({'estado': estado}),
        )
        .timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al actualizar estatus');
  }

  Future<void> resolverTicket(
    String id, {
    required String causaRaiz,
    required String comoSeResolvio,
    required String pruebasRealizadas,
    required String validadoCon,
  }) async {
    final res = await http
        .put(
          Uri.parse('$kApiUrl/tickets/$id/resolve'),
          headers: _headers,
          body: jsonEncode({
            'estado': 'Resuelto',
            'causaRaiz': causaRaiz,
            'comoSeResolvio': comoSeResolvio,
            'pruebasRealizadas': pruebasRealizadas,
            'validadoCon': validadoCon,
          }),
        )
        .timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al resolver ticket');
  }

  Future<void> reasignarTicket(String id, String tecnico) async {
    final res = await http
        .put(
          Uri.parse('$kApiUrl/tickets/$id/assign'),
          headers: _headers,
          body: jsonEncode({'asignadoA': tecnico}),
        )
        .timeout(kTimeout);
    if (res.statusCode != 200) throw Exception('Error al reasignar');
  }

  Future<void> asignarEquipo(
    String id, {
    required String empleado,
    required String rol,
    required String folio,
  }) async {
    final res = await http
        .put(
          Uri.parse('$kApiUrl/equipos/$id/assign'),
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

  Future<void> liberarEquipo(String id) async {
    final res = await http
        .put(
          Uri.parse('$kApiUrl/equipos/$id/release'),
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

  Future<void> actualizarRespaldo(String id, DateTime fecha) async {
    final res = await http
        .put(
          Uri.parse('$kApiUrl/equipos/$id/backup'),
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
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final response = await http
          .post(
            Uri.parse('$kApiUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': _userCtrl.text.trim().toLowerCase(),
              'password': _passCtrl.text,
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
          token: data['token'] ?? '',
        );

        // Solicitar permiso de notificaciones y arrancar servicio
        await NotificationService.solicitarPermiso();
        final notifService = NotificationService(
          username: session.username,
          rol: session.rol,
          token: session.token,
        );
        notifService.iniciar();

        // Registrar Service Worker
        _registrarSW();

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  MainLayout(session: session, notifService: notifService),
            ),
          );
        }
      } else {
        mostrarSnackBar(context, 'Credenciales incorrectas', error: true);
      }
    } catch (e) {
      if (mounted) {
        mostrarSnackBar(context, 'Error de conexión: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _registrarSW() {
    try {
      web.window.navigator.serviceWorker
          .register('/sw_custom.js'.toJS)
          .toDart
          .then((_) => debugPrint('[SW] Registrado correctamente'))
          .catchError((e) => debugPrint('[SW] Error al registrar: $e'));
    } catch (_) {}
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
                        controller: _userCtrl,
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
                        controller: _passCtrl,
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
                          onPressed: _loading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: _loading
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
// ESTRUCTURA BASE
// ============================================================================
class MainLayout extends StatefulWidget {
  final Session session;
  final NotificationService notifService;

  const MainLayout({
    super.key,
    required this.session,
    required this.notifService,
  });

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

  @override
  void dispose() {
    widget.notifService.detener();
    super.dispose();
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
      if (mounted) {
        mostrarSnackBar(context, 'Error al cargar datos: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _logout() {
    widget.notifService.detener();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final screens = [
      DashboardScreen(
        tickets: _tickets,
        inventario: _inventario,
        session: widget.session,
      ),
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
            tooltip: 'Recargar',
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
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
            _item(Icons.dashboard_rounded, 'Dashboard', 0),
            _item(
              Icons.confirmation_number_rounded,
              'Tickets / Asignaciones',
              1,
            ),
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

// ============================================================================
// DASHBOARD
// ============================================================================
// ============================================================================
// DONA WIDGET — Gráfica circular personalizada sin dependencias externas
// ============================================================================
class DonaWidget extends StatelessWidget {
  final double valor; // 0.0 a 1.0
  final String numero;
  final String etiqueta;
  final Color colorActivo;
  final Color colorFondo;
  final double size;

  const DonaWidget({
    super.key,
    required this.valor,
    required this.numero,
    required this.etiqueta,
    required this.colorActivo,
    this.colorFondo = const Color(0xFFE8ECF0),
    this.size = 130,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _DonaPainter(
              valor: valor.clamp(0.0, 1.0),
              colorActivo: colorActivo,
              colorFondo: colorFondo,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                numero,
                style: TextStyle(
                  fontSize: size * 0.22,
                  fontWeight: FontWeight.bold,
                  color: colorActivo,
                ),
              ),
              Text(
                etiqueta,
                style: TextStyle(
                  fontSize: size * 0.09,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonaPainter extends CustomPainter {
  final double valor;
  final Color colorActivo;
  final Color colorFondo;

  _DonaPainter({
    required this.valor,
    required this.colorActivo,
    required this.colorFondo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radio = size.width * 0.42;
    const grosor = 14.0;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radio);

    // Fondo
    canvas.drawArc(
      rect,
      -1.5708, // -90 grados (arriba)
      6.2832, // 360 grados
      false,
      Paint()
        ..color = colorFondo
        ..strokeWidth = grosor
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Arco activo
    if (valor > 0) {
      canvas.drawArc(
        rect,
        -1.5708,
        6.2832 * valor,
        false,
        Paint()
          ..color = colorActivo
          ..strokeWidth = grosor
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_DonaPainter old) =>
      old.valor != valor || old.colorActivo != colorActivo;
}

// ============================================================================
// DASHBOARD
// ============================================================================
class DashboardScreen extends StatelessWidget {
  final List<Ticket> tickets;
  final List<Equipo> inventario;
  final Session session;

  const DashboardScreen({
    super.key,
    required this.tickets,
    required this.inventario,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    // — Métricas de tickets —
    final visibles = session.rol == 'Admin'
        ? tickets
        : tickets
              .where(
                (t) =>
                    t.asignadoA.toLowerCase() == session.username.toLowerCase(),
              )
              .toList();

    final total = visibles.length;
    final pendientes = visibles.where((t) => t.estado == 'Pendiente').length;
    final enProceso = visibles.where((t) => t.estado == 'En Proceso').length;
    final resueltos = visibles.where((t) => t.estado == 'Resuelto').length;
    final alta = visibles
        .where((t) => t.prioridad == 'Alta' && t.estado != 'Resuelto')
        .length;

    // — Métricas de equipos —
    final totalEquipos = inventario.length;
    final asignados = inventario.where((e) => e.estatus == 'Asignado').length;
    final disponibles = inventario
        .where((e) => e.estatus == 'Disponible')
        .length;
    final valorTotal = inventario.fold<double>(0, (s, e) => s + e.valorActual);

    // — Métricas de respaldos —
    final conRespaldo = inventario
        .where(
          (e) =>
              e.ultimoRespaldo != null &&
              DateTime.now().difference(e.ultimoRespaldo!).inDays < 15,
        )
        .length;
    final sinRespaldo = totalEquipos - conRespaldo;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.rol == 'Admin'
                        ? 'Consola de Control Global'
                        : 'Mis Tareas TI',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Resumen general del sistema',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── SECCIÓN TICKETS ──
          _seccion(
            'Tickets de Soporte',
            Icons.confirmation_number_rounded,
            Colors.indigo,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _tarjetaDona(
                titulo: 'Pendientes',
                numero: '$pendientes',
                subtitulo: 'de $total tickets',
                valor: total > 0 ? pendientes / total : 0,
                colorActivo: Colors.red.shade600,
                icono: Icons.hourglass_top_rounded,
              ),
              _tarjetaDona(
                titulo: 'En Proceso',
                numero: '$enProceso',
                subtitulo: 'de $total tickets',
                valor: total > 0 ? enProceso / total : 0,
                colorActivo: Colors.orange.shade700,
                icono: Icons.autorenew_rounded,
              ),
              _tarjetaDona(
                titulo: 'Resueltos',
                numero: '$resueltos',
                subtitulo: 'de $total tickets',
                valor: total > 0 ? resueltos / total : 0,
                colorActivo: Colors.green.shade600,
                icono: Icons.check_circle_rounded,
              ),
              _tarjetaDona(
                titulo: 'Prioridad Alta',
                numero: '$alta',
                subtitulo: 'sin resolver',
                valor: total > 0 ? alta / total : 0,
                colorActivo: Colors.deepOrange.shade700,
                icono: Icons.priority_high_rounded,
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ── SECCIÓN EQUIPOS ──
          _seccion(
            'Inventario de Equipos',
            Icons.computer_rounded,
            Colors.teal,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _tarjetaDona(
                titulo: 'Asignados',
                numero: '$asignados',
                subtitulo: 'de $totalEquipos equipos',
                valor: totalEquipos > 0 ? asignados / totalEquipos : 0,
                colorActivo: Colors.indigo.shade600,
                icono: Icons.person_rounded,
              ),
              _tarjetaDona(
                titulo: 'Disponibles',
                numero: '$disponibles',
                subtitulo: 'en almacén',
                valor: totalEquipos > 0 ? disponibles / totalEquipos : 0,
                colorActivo: Colors.teal.shade600,
                icono: Icons.inventory_2_rounded,
              ),
              _tarjetaKPI(
                titulo: 'Valor del Inventario',
                numero: '\$${_formatMiles(valorTotal)}',
                subtitulo: 'MXN valor depreciado',
                color: Colors.blueGrey.shade700,
                icono: Icons.account_balance_wallet_rounded,
              ),
              _tarjetaKPI(
                titulo: 'Total de Equipos',
                numero: '$totalEquipos',
                subtitulo: 'registrados en sistema',
                color: Colors.blue.shade700,
                icono: Icons.devices_rounded,
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ── SECCIÓN RESPALDOS ──
          _seccion('Estado de Respaldos', Icons.backup_rounded, Colors.purple),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _tarjetaDona(
                titulo: 'Al día',
                numero: '$conRespaldo',
                subtitulo: 'últimos 15 días',
                valor: totalEquipos > 0 ? conRespaldo / totalEquipos : 0,
                colorActivo: Colors.green.shade600,
                icono: Icons.cloud_done_rounded,
              ),
              _tarjetaDona(
                titulo: 'Atrasados',
                numero: '$sinRespaldo',
                subtitulo: '+15 días sin respaldo',
                valor: totalEquipos > 0 ? sinRespaldo / totalEquipos : 0,
                colorActivo: Colors.red.shade600,
                icono: Icons.cloud_off_rounded,
              ),
            ],
          ),

          const SizedBox(height: 28),

          // ── TABLA: Tickets recientes ──
          if (session.rol == 'Admin') ...[
            _seccion(
              'Últimos Tickets Registrados',
              Icons.list_alt_rounded,
              Colors.blueGrey,
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              child: Column(
                children: visibles
                    .take(5)
                    .map(
                      (t) => ListTile(
                        dense: true,
                        leading: Icon(
                          Icons.circle,
                          size: 10,
                          color: t.prioridad == 'Alta'
                              ? Colors.red
                              : t.prioridad == 'Media'
                              ? Colors.orange
                              : Colors.blue,
                        ),
                        title: Text(
                          t.descripcion,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          '${t.id} • ${t.usuario} • ${t.asignadoA}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor(
                              t.estado,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            t.estado,
                            style: TextStyle(
                              fontSize: 11,
                              color: statusColor(t.estado),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // Encabezado de sección
  Widget _seccion(String titulo, IconData icono, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icono, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          titulo,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // Tarjeta con dona
  Widget _tarjetaDona({
    required String titulo,
    required String numero,
    required String subtitulo,
    required double valor,
    required Color colorActivo,
    required IconData icono,
  }) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: colorActivo, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: DonaWidget(
              valor: valor,
              numero: numero,
              etiqueta: '${(valor * 100).toStringAsFixed(0)}%',
              colorActivo: colorActivo,
              size: 120,
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              subtitulo,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }

  // Tarjeta solo con número (sin dona)
  Widget _tarjetaKPI({
    required String titulo,
    required String numero,
    required String subtitulo,
    required Color color,
    required IconData icono,
  }) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, color: color, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              numero,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              subtitulo,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatMiles(double valor) {
    if (valor >= 1000000) {
      return '${(valor / 1000000).toStringAsFixed(1)}M';
    } else if (valor >= 1000) {
      return '${(valor / 1000).toStringAsFixed(1)}K';
    }
    return valor.toStringAsFixed(0);
  }
}

// ============================================================================
// TICKETS
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
  final _usuarioCtrl = TextEditingController();
  final _deptoCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _prioridad = 'Media';
  String _asignado = 'Sin Asignar';
  String _filtro = 'Activos';
  bool _guardando = false;

  @override
  void dispose() {
    _usuarioCtrl.dispose();
    _deptoCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _abrirDialogoNuevo() {
    _usuarioCtrl.clear();
    _deptoCtrl.clear();
    _descCtrl.clear();
    _prioridad = 'Media';
    _asignado = 'Sin Asignar';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          title: const Text(
            'Levantar Reporte Técnico',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _usuarioCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Usuario Afectado',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _deptoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Departamento',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _prioridad,
                      decoration: const InputDecoration(
                        labelText: 'Prioridad',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Baja', 'Media', 'Alta']
                          .map(
                            (p) => DropdownMenuItem(value: p, child: Text(p)),
                          )
                          .toList(),
                      onChanged: (v) => setDs(() => _prioridad = v!),
                    ),
                    const SizedBox(height: 12),
                    if (widget.session.rol == 'Admin')
                      DropdownButtonFormField<String>(
                        initialValue: _asignado,
                        decoration: const InputDecoration(
                          labelText: 'Técnico Responsable',
                          border: OutlineInputBorder(),
                        ),
                        items: kTecnicos
                            .map(
                              (p) => DropdownMenuItem(value: p, child: Text(p)),
                            )
                            .toList(),
                        onChanged: (v) => setDs(() => _asignado = v!),
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descCtrl,
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
              builder: (ctx2, setBtn) {
                return ElevatedButton(
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
                            usuario: _usuarioCtrl.text.trim(),
                            departamento: _deptoCtrl.text.trim(),
                            descripcion: _descCtrl.text.trim(),
                            prioridad: _prioridad,
                            estado: 'Pendiente',
                            asignadoA: widget.session.rol == 'Admin'
                                ? _asignado
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
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Intercepta "Resuelto" para mostrar el diálogo de cierre
  Future<void> _cambiarEstatus(Ticket t, String estado) async {
    if (estado == 'Resuelto') {
      await _mostrarDialogoCierre(t);
      return;
    }
    try {
      await widget.api.cambiarEstatusTicket(t.id, estado);
      setState(() => t.estado = estado);
    } catch (e) {
      if (mounted) {
        mostrarSnackBar(context, 'Error: $e', error: true);
      }
    }
  }

  Future<void> _mostrarDialogoCierre(Ticket t) async {
    final causaCtrl = TextEditingController(text: t.causaRaiz ?? '');
    final resolucionCtrl = TextEditingController(text: t.comoSeResolvio ?? '');
    final pruebasCtrl = TextEditingController(text: t.pruebasRealizadas ?? '');
    final validadoCtrl = TextEditingController(text: t.validadoCon ?? '');
    final formKey = GlobalKey<FormState>();
    bool guardando = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.task_alt_rounded,
                color: Colors.green.shade700,
                size: 28,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Cierre de Ticket',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: SizedBox(
                width: 480,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Ticket ${t.id} — ${t.descripcion}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // 1. Causa raíz
                    _labelCierre(
                      '1. ¿Por qué sucedió?',
                      Icons.search_rounded,
                      Colors.orange,
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: causaCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: 'Describe la causa raíz del problema...',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Campo requerido'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    // 2. Cómo se resolvió
                    _labelCierre(
                      '2. ¿Cómo se resolvió?',
                      Icons.build_rounded,
                      Colors.blue,
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: resolucionCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText:
                            'Describe los pasos o acciones que solucionaron el problema...',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Campo requerido'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    // 3. Pruebas realizadas
                    _labelCierre(
                      '3. ¿Qué pruebas se hicieron?',
                      Icons.science_rounded,
                      Colors.purple,
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: pruebasCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText:
                            'Ej: Se reinició el servicio, se probó acceso desde 3 equipos...',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Campo requerido'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    // 4. Quién valida
                    _labelCierre(
                      '4. ¿Quién valida la resolución?',
                      Icons.verified_user_rounded,
                      Colors.teal,
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: validadoCtrl,
                      decoration: const InputDecoration(
                        hintText:
                            'Nombre del usuario o supervisor que confirmó la solución...',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Campo requerido'
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
              builder: (_, setBtn) {
                return ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: guardando
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setBtn(() => guardando = true);
                          try {
                            await widget.api.resolverTicket(
                              t.id,
                              causaRaiz: causaCtrl.text.trim(),
                              comoSeResolvio: resolucionCtrl.text.trim(),
                              pruebasRealizadas: pruebasCtrl.text.trim(),
                              validadoCon: validadoCtrl.text.trim(),
                            );
                            setState(() {
                              t.estado = 'Resuelto';
                              t.causaRaiz = causaCtrl.text.trim();
                              t.comoSeResolvio = resolucionCtrl.text.trim();
                              t.pruebasRealizadas = pruebasCtrl.text.trim();
                              t.validadoCon = validadoCtrl.text.trim();
                            });
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              mostrarSnackBar(
                                context,
                                'Ticket cerrado correctamente.',
                              );
                            }
                          } catch (e) {
                            if (ctx.mounted) {
                              mostrarSnackBar(
                                ctx,
                                'Error al cerrar: $e',
                                error: true,
                              );
                            }
                          } finally {
                            setBtn(() => guardando = false);
                          }
                        },
                  icon: guardando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.task_alt_rounded, size: 18),
                  label: const Text('Marcar como Resuelto'),
                );
              },
            ),
          ],
        ),
      ),
    );

    causaCtrl.dispose();
    resolucionCtrl.dispose();
    pruebasCtrl.dispose();
    validadoCtrl.dispose();
  }

  Widget _labelCierre(String texto, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(
          texto,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _itemResolucion(
    IconData icon,
    Color color,
    String label,
    String valor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: Colors.black87),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                TextSpan(text: valor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _reasignar(Ticket t, String tecnico) async {
    try {
      await widget.api.reasignarTicket(t.id, tecnico);
      setState(() => t.asignadoA = tecnico);
    } catch (e) {
      if (mounted) {
        mostrarSnackBar(context, 'Error: $e', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Ticket> lista = widget.session.rol == 'Admin'
        ? widget.tickets
        : widget.tickets
              .where(
                (t) =>
                    t.asignadoA.toLowerCase() ==
                        widget.session.username.toLowerCase() ||
                    t.asignadoA == widget.session.nombreCompleto,
              )
              .toList();

    if (_filtro == 'Activos') {
      lista = lista.where((t) => t.estado != 'Resuelto').toList();
    } else if (_filtro == 'Resueltos') {
      lista = lista.where((t) => t.estado == 'Resuelto').toList();
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
                  'Consola Soporte (${lista.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _abrirDialogoNuevo,
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
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            f,
                            style: TextStyle(
                              fontWeight: _filtro == f
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          selected: _filtro == f,
                          onSelected: (s) {
                            if (s) setState(() => _filtro = f);
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
              child: lista.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay tickets en esta categoría.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: lista.length,
                      itemBuilder: (_, i) {
                        final t = lista[i];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ExpansionTile(
                            leading: Icon(
                              Icons.circle,
                              size: 12,
                              color: t.prioridad == 'Alta'
                                  ? Colors.red
                                  : t.prioridad == 'Media'
                                  ? Colors.orange
                                  : Colors.blue,
                            ),
                            title: Text(
                              t.descripcion,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              'ID: ${t.id} • ${t.usuario}\nAsignado: ${t.asignadoA}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor(
                                  t.estado,
                                ).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                t.estado,
                                style: TextStyle(
                                  color: statusColor(t.estado),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Descripción:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey,
                                      ),
                                    ),
                                    Text(t.descripcion),
                                    // Mostrar detalle de resolución si ya está resuelto
                                    if (t.estado == 'Resuelto' &&
                                        t.causaRaiz != null) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          border: Border.all(
                                            color: Colors.green.shade200,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.task_alt_rounded,
                                                  color: Colors.green.shade700,
                                                  size: 16,
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Detalle de Resolución',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        Colors.green.shade800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const Divider(),
                                            _itemResolucion(
                                              Icons.search_rounded,
                                              Colors.orange,
                                              '¿Por qué sucedió?',
                                              t.causaRaiz ?? '',
                                            ),
                                            const SizedBox(height: 8),
                                            _itemResolucion(
                                              Icons.build_rounded,
                                              Colors.blue,
                                              '¿Cómo se resolvió?',
                                              t.comoSeResolvio ?? '',
                                            ),
                                            const SizedBox(height: 8),
                                            _itemResolucion(
                                              Icons.science_rounded,
                                              Colors.purple,
                                              'Pruebas realizadas',
                                              t.pruebasRealizadas ?? '',
                                            ),
                                            const SizedBox(height: 8),
                                            _itemResolucion(
                                              Icons.verified_user_rounded,
                                              Colors.teal,
                                              'Validado con',
                                              t.validadoCon ?? '',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                    const Divider(),
                                    const Text(
                                      'Cambiar Estatus:',
                                      style: TextStyle(
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
                                                  selected: t.estado == e,
                                                  onSelected: (_) =>
                                                      _cambiarEstatus(t, e),
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
                                            'Reasignar:',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.indigo,
                                            ),
                                          ),
                                          DropdownButton<String>(
                                            value:
                                                kTecnicos.contains(t.asignadoA)
                                                ? t.asignadoA
                                                : 'Sin Asignar',
                                            underline: Container(),
                                            items: kTecnicos
                                                .map(
                                                  (e) => DropdownMenuItem(
                                                    value: e,
                                                    child: Text(e),
                                                  ),
                                                )
                                                .toList(),
                                            onChanged: (v) {
                                              if (v != null) {
                                                _reasignar(t, v);
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
// EQUIPOS
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
  final _formKey = GlobalKey<FormState>();
  final _empleadoCtrl = TextEditingController();
  final _puestoCtrl = TextEditingController();
  final _folioCtrl = TextEditingController();

  @override
  void dispose() {
    _empleadoCtrl.dispose();
    _puestoCtrl.dispose();
    _folioCtrl.dispose();
    super.dispose();
  }

  void _liberarHardware(Equipo eq) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text('Liberar ${eq.folioResponsiva}'),
          ],
        ),
        content: Text(
          'El equipo quedará como "Disponible" y se desvinculará de "${eq.empleadoAsignado}".',
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
                await widget.api.liberarEquipo(eq.id);
                setState(() {
                  eq.estatus = 'Disponible';
                  eq.empleadoAsignado = null;
                  eq.rolEmpleado = null;
                  eq.folioResponsiva = '---';
                });
                if (mounted) {
                  mostrarSnackBar(context, 'Hardware liberado.');
                }
              } catch (e) {
                if (mounted) {
                  mostrarSnackBar(context, 'Error: $e', error: true);
                }
              }
            },
            child: const Text('Confirmar Baja'),
          ),
        ],
      ),
    );
  }

  void _asignarHardware(Equipo eq) {
    _empleadoCtrl.clear();
    _puestoCtrl.clear();
    _folioCtrl.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add_alt_1_rounded, color: Colors.teal),
            SizedBox(width: 8),
            Text(
              'Asignar Activo',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${eq.marca} - ${eq.modelo}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _empleadoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del Empleado',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _puestoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Puesto / Rol',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.work),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _folioCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Folio de Responsiva',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Requerido' : null,
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
              if (!_formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              try {
                await widget.api.asignarEquipo(
                  eq.id,
                  empleado: _empleadoCtrl.text.trim(),
                  rol: _puestoCtrl.text.trim(),
                  folio: _folioCtrl.text.trim(),
                );
                setState(() {
                  eq.estatus = 'Asignado';
                  eq.empleadoAsignado = _empleadoCtrl.text.trim();
                  eq.rolEmpleado = _puestoCtrl.text.trim();
                  eq.folioResponsiva = _folioCtrl.text.trim();
                });
                if (mounted) {
                  mostrarSnackBar(context, 'Activo asignado.');
                }
              } catch (e) {
                if (mounted) {
                  mostrarSnackBar(context, 'Error: $e', error: true);
                }
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
        padding: const EdgeInsets.all(12),
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
              '${widget.inventario.length} equipos desde AWS',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: widget.inventario.length,
                itemBuilder: (_, i) {
                  final eq = widget.inventario[i];
                  final asignado = eq.estatus == 'Asignado';
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ExpansionTile(
                      leading: Icon(
                        eq.tipo == 'Laptop'
                            ? Icons.laptop_mac_rounded
                            : eq.tipo == 'Servidor'
                            ? Icons.dns_rounded
                            : Icons.computer_rounded,
                        color: asignado
                            ? Colors.indigo.shade700
                            : Colors.teal.shade700,
                      ),
                      title: Text(
                        '${eq.marca} - ${eq.modelo}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        'S/N: ${eq.noSerie}\nFolio: ${eq.folioResponsiva}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: asignado
                              ? Colors.indigo.shade50
                              : Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          eq.estatus,
                          style: TextStyle(
                            color: asignado
                                ? Colors.indigo.shade700
                                : Colors.teal.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (asignado) ...[
                                Text('Empleado: ${eq.empleadoAsignado}'),
                                Text('Rol: ${eq.rolEmpleado}'),
                              ] else
                                Text(
                                  'Disponible (Resguardo: ${eq.empleadoAsignado ?? "Sistemas"})',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              const Divider(),
                              Text(
                                'Especificaciones: ${eq.specifications}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                'Accesorios: ${eq.accesorios}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                'Año adquisición: ${eq.anoAdquisicion}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                'Valor compra: \$${eq.valorAdquisicion.toStringAsFixed(2)} MXN',
                                style: const TextStyle(fontSize: 12),
                              ),
                              Text(
                                'Valor depreciado: \$${eq.valorActual.toStringAsFixed(2)} MXN',
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
                                  child: asignado
                                      ? ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red.shade50,
                                            foregroundColor:
                                                Colors.red.shade800,
                                          ),
                                          onPressed: () => _liberarHardware(eq),
                                          icon: const Icon(
                                            Icons.person_remove_alt_1_rounded,
                                            size: 18,
                                          ),
                                          label: const Text(
                                            'Liberar Equipo (Baja)',
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
                                          onPressed: () => _asignarHardware(eq),
                                          icon: const Icon(
                                            Icons.person_add_alt_1_rounded,
                                            size: 18,
                                          ),
                                          label: const Text(
                                            'Asignar Equipo (Responsiva)',
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
// RESPALDOS
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
  Future<void> _actualizar(Equipo eq, DateTime fecha) async {
    try {
      await widget.api.actualizarRespaldo(eq.id, fecha);
      setState(() => eq.ultimoRespaldo = fecha);
      if (mounted) mostrarSnackBar(context, 'Respaldo sincronizado.');
    } catch (e) {
      if (mounted) mostrarSnackBar(context, 'Error: $e', error: true);
    }
  }

  String _fmt(DateTime? f) {
    if (f == null) return 'Sin respaldo';
    return '${f.day.toString().padLeft(2, '0')}/'
        '${f.month.toString().padLeft(2, '0')}/${f.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
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
            'Presiona el ícono de nube para actualizar la fecha de respaldo.',
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
                          'Modelo',
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
                          'RustDesk',
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
                    rows: widget.inventario.map((eq) {
                      final dias = eq.diasUltimoRespaldo;
                      Color celda = Colors.transparent;
                      if (dias != null) {
                        celda = dias >= 15
                            ? Colors.red.shade300
                            : Colors.amber.shade200;
                      }
                      return DataRow(
                        cells: [
                          DataCell(Text(eq.ubicacion)),
                          DataCell(
                            Text(eq.empleadoAsignado ?? 'Sistemas (Stock)'),
                          ),
                          DataCell(Text(eq.modelo)),
                          DataCell(Text(eq.anydesk)),
                          DataCell(Text(eq.rustdesk)),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_fmt(eq.ultimoRespaldo)),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(
                                    Icons.cloud_upload_rounded,
                                    size: 18,
                                    color: Color(0xFF0D47A1),
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: 'Actualizar respaldo',
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          eq.ultimoRespaldo ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 365),
                                      ),
                                    );
                                    if (picked != null) _actualizar(eq, picked);
                                  },
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Container(
                              width: 50,
                              height: double.infinity,
                              color: celda,
                              alignment: Alignment.center,
                              child: Text(
                                dias?.toString() ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          DataCell(Text(eq.comentarios)),
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
