import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
          seedColor: const Color(0xFF0D47A1),
          primary: const Color(0xFF0D47A1),
        ),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

// ============================================================================
// MODELOS DE DATOS: TICKETS, INVENTARIO UNIFICADO Y SESIÓN
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

  // Campos unificados para el control de respaldos y conectividad
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
    int anosPasados = DateTime.now().year - anoAdquisicion;
    if (anosPasados <= 0) return valorAdquisicion;
    if (anosPasados >= 5) return valorAdquisicion * 0.20;
    double factorDepreciacion = 1.0 - (anosPasados * 0.20);
    return valorAdquisicion * factorDepreciacion;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'folioResponsiva': folioResponsiva,
    'tipo': tipo,
    'marca': marca,
    'modelo': modelo,
    'noSerie': noSerie,
    'accesorios': accesorios,
    'anoAdquisicion': anoAdquisicion,
    'valorAdquisicion': valorAdquisicion,
    'specifications': specifications,
    'estatus': estatus,
    'empleadoAsignado': empleadoAsignado,
    'rolEmpleado': rolEmpleado,
    'ubicacion': ubicacion,
    'anydesk': anydesk,
    'rustdesk': rustdesk,
    'ultimoRespaldo': ultimoRespaldo?.toIso8601String(),
    'comentarios': comentarios,
  };

  factory Equipo.fromMap(Map<String, dynamic> map) => Equipo(
    id: map['id'],
    folioResponsiva: map['folioResponsiva'],
    tipo: map['tipo'],
    marca: map['marca'],
    modelo: map['modelo'],
    noSerie: map['noSerie'],
    accesorios: map['accesorios'],
    anoAdquisicion: map['anoAdquisicion'],
    valorAdquisicion: map['valorAdquisicion'].toDouble(),
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
  Session({
    required this.username,
    required this.nombreCompleto,
    required this.rol,
  });
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

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      String user = _usernameController.text.trim().toLowerCase();
      String pass = _passwordController.text;
      Session? sesionActual;

      if (user == 'carlos' && pass == 'beta123') {
        sesionActual = Session(
          username: 'carlos',
          nombreCompleto: 'Carlos',
          rol: 'Admin',
        );
      } else if (user == 'benjamin' && pass == 'soporte2026') {
        sesionActual = Session(
          username: 'benjamin',
          nombreCompleto: 'Benjamín Castro',
          rol: 'Admin',
        );
      } else if (user == 'julio' && pass == 'julio123') {
        sesionActual = Session(
          username: 'julio',
          nombreCompleto: 'Julio Montelongo',
          rol: 'Tecnico',
        );
      }

      if (sesionActual != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainLayout(session: sesionActual!),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Credenciales incorrectas'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
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
                        Icons.security_rounded,
                        size: 64,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Soporte Beta',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Text(
                        'Autenticación de Personal TI',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: 'Usuario',
                          border: OutlineInputBorder(),
                        ),
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
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Ingresar'),
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
// ESTRUCTURA BASE Y CONTROL DE DATOS LOCALES
// ============================================================================
class MainLayout extends StatefulWidget {
  final Session session;
  const MainLayout({super.key, required this.session});
  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _screenIndex = 1;
  List<Ticket> _ticketsGlobales = [];
  List<Equipo> _inventarioGlobal = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosDeMemoria();
  }

  Future<void> _cargarDatosDeMemoria() async {
    final prefs = await SharedPreferences.getInstance();
    final String? ticketsString = prefs.getString('historial_tickets');
    final String? inventarioString = prefs.getString('inventario_equipos');

    setState(() {
      if (ticketsString != null) {
        final List<dynamic> decoded = jsonDecode(ticketsString);
        _ticketsGlobales = decoded.map((item) => Ticket.fromMap(item)).toList();
      } else {
        _ticketsGlobales = [
          Ticket(
            id: 'TK-101',
            usuario: 'Luis Fabela',
            departamento: 'Desarrollo',
            descripcion: 'Falla de red en nodo principal on-premise',
            prioridad: 'Alta',
            estado: 'En Proceso',
            asignadoA: 'Carlos',
            fecha: DateTime.now(),
          ),
          Ticket(
            id: 'TK-102',
            usuario: 'Gaby Gomez',
            departamento: 'Administración',
            descripcion: 'Error de timbrado en factura SAT',
            prioridad: 'Alta',
            estado: 'Pendiente',
            asignadoA: 'Julio',
            fecha: DateTime.now(),
          ),
          Ticket(
            id: 'TK-103',
            usuario: 'Operaciones',
            departamento: 'Embarques',
            descripcion: 'Impresora térmica de etiquetas no responde',
            prioridad: 'Media',
            estado: 'Pendiente',
            asignadoA: 'Julio',
            fecha: DateTime.now(),
          ),
          Ticket(
            id: 'TK-104',
            usuario: 'Ventas',
            departamento: 'Mostrador',
            descripcion: 'Configuración de VPN remota para sucursal',
            prioridad: 'Media',
            estado: 'Resuelto',
            asignadoA: 'Benjamin',
            fecha: DateTime.now(),
          ),
        ];
      }

      if (inventarioString != null) {
        final List<dynamic> decodedInv = jsonDecode(inventarioString);
        _inventarioGlobal = decodedInv
            .map((item) => Equipo.fromMap(item))
            .toList();
      } else {
        // Inicialización con la lista completa y unificada cruzando los datos de tus pantallas
        _inventarioGlobal = [
          Equipo(
            id: 'EQ-01',
            folioResponsiva: '192',
            tipo: 'Laptop',
            marca: 'DELL',
            modelo: 'Expertboock B1402',
            noSerie: 'SANXCV12388143A',
            accesorios: 'Cargador, Mochila',
            anoAdquisicion: 2025,
            valorAdquisicion: 18500.00,
            specifications: 'RAM 16GB, SSD 512GB',
            estatus: 'Asignado',
            empleadoAsignado: 'Angel Gabriel Medina Ruiz',
            rolEmpleado: 'Desarrollador',
            ubicacion: 'Beta',
            anydesk: '1 349 175 777',
            rustdesk: '479 853 389',
            ultimoRespaldo: DateTime(2026, 5, 28),
          ),
          Equipo(
            id: 'EQ-02',
            folioResponsiva: '185',
            tipo: 'Laptop',
            marca: 'Lenovo',
            modelo: 'ThinkPad E14',
            noSerie: 'LNV99382173B',
            accesorios: 'Cargador',
            anoAdquisicion: 2024,
            valorAdquisicion: 16200.00,
            specifications: 'RAM 24GB, SSD 1TB',
            estatus: 'Asignado',
            empleadoAsignado: 'Benjamin Castro',
            rolEmpleado: 'Encargado de Soporte',
            ubicacion: 'ESM',
            anydesk: '1 014 343 898',
            rustdesk: '316 674 411',
            ultimoRespaldo: DateTime(2026, 5, 29),
          ),
          Equipo(
            id: 'EQ-03',
            folioResponsiva: '---',
            tipo: 'Servidor',
            marca: 'HP',
            modelo: 'ProLiant DL360',
            noSerie: 'HPSRV883210X',
            accesorios: 'Cable de poder, Rieles',
            anoAdquisicion: 2023,
            valorAdquisicion: 45000.00,
            specifications: 'Xeon 16-Core, 64GB RAM',
            estatus: 'Disponible',
            empleadoAsignado: 'BETA 2',
            ubicacion: 'Beta',
            anydesk: '1 894 913 332',
            rustdesk: '1 632 149 529',
            comentarios: 'respaldo en aws',
          ),
          Equipo(
            id: 'EQ-04',
            folioResponsiva: '---',
            tipo: 'Desktop',
            marca: 'Generic',
            modelo: 'Beta1',
            noSerie: 'OLD-BETA1',
            accesorios: 'Ninguno',
            anoAdquisicion: 2021,
            valorAdquisicion: 12000.00,
            specifications: 'Core i3, 8GB RAM',
            estatus: 'Disponible',
            empleadoAsignado: 'BETA 1 viejo',
            ubicacion: 'Beta',
            comentarios: 'en resguardo sistemas',
          ),
          Equipo(
            id: 'EQ-05',
            folioResponsiva: '112',
            tipo: 'Laptop',
            marca: 'Lenovo',
            modelo: 'Movil67',
            noSerie: 'LNV882319A',
            accesorios: 'Cargador',
            anoAdquisicion: 2024,
            valorAdquisicion: 15000.00,
            specifications: 'Core i5, 16GB RAM',
            estatus: 'Asignado',
            empleadoAsignado: 'Horacio Martinez',
            rolEmpleado: 'Operaciones',
            ubicacion: 'ESM',
            anydesk: '488 202 029',
            rustdesk: '317 469 513',
            ultimoRespaldo: DateTime(2026, 5, 14),
            comentarios: 'incapacidad',
          ),
          Equipo(
            id: 'EQ-06',
            folioResponsiva: '115',
            tipo: 'Laptop',
            marca: 'DELL',
            modelo: 'Christian-BETA',
            noSerie: 'DLL442112B',
            accesorios: 'Cargador',
            anoAdquisicion: 2025,
            valorAdquisicion: 17000.00,
            specifications: 'Core i7, 16GB RAM',
            estatus: 'Asignado',
            empleadoAsignado: 'Julio Montelongo',
            rolEmpleado: 'Soporte',
            ubicacion: 'Beta',
            rustdesk: '1264963993',
            ultimoRespaldo: DateTime(2026, 5, 25),
          ),
        ];
      }
      _cargando = false;
    });
  }

  Future<void> _guardarTickets() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'historial_tickets',
      jsonEncode(_ticketsGlobales.map((t) => t.toMap()).toList()),
    );
  }

  Future<void> _guardarInventario() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'inventario_equipos',
      jsonEncode(_inventarioGlobal.map((e) => e.toMap()).toList()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final List<Widget> screens = [
      DashboardScreen(tickets: _ticketsGlobales, session: widget.session),
      TicketsScreen(
        tickets: _ticketsGlobales,
        session: widget.session,
        onTicketsChanged: () {
          setState(() {});
          _guardarTickets();
        },
      ),
      EquipmentScreen(
        inventario: _inventarioGlobal,
        session: widget.session,
        onInventarioChanged: () {
          setState(() {});
          _guardarInventario();
        },
      ),
      PantallaRespaldos(
        inventario: _inventarioGlobal,
        onInventarioChanged: () {
          setState(() {});
          _guardarInventario();
        },
      ), // PASAMOS LA MISMA LISTA Y CALLBACK
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text(
          'Soporte Beta — Módulo de ${widget.session.rol}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
            ),
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
            ListTile(
              leading: const Icon(Icons.dashboard_rounded),
              title: const Text('Dashboard'),
              selected: _screenIndex == 0,
              onTap: () {
                setState(() => _screenIndex = 0);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.confirmation_number_rounded),
              title: const Text('Tickets / Asignaciones'),
              selected: _screenIndex == 1,
              onTap: () {
                setState(() => _screenIndex = 1);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.computer_rounded),
              title: const Text('Equipos / Responsivas'),
              selected: _screenIndex == 2,
              onTap: () {
                setState(() => _screenIndex = 2);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.backup_rounded),
              title: const Text('Control de Respaldos'),
              selected: _screenIndex == 3,
              onTap: () {
                setState(() => _screenIndex = 3);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: screens[_screenIndex],
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
    List<Ticket> visibles = session.rol == 'Admin'
        ? tickets
        : tickets.where((t) => t.asignadoA == 'Julio').toList();
    int activos = visibles.where((t) => t.estado != 'Resuelto').length;
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
          Card(
            color: Colors.orange.shade50,
            child: ListTile(
              leading: const Icon(
                Icons.assignment_late_rounded,
                color: Colors.orange,
                size: 40,
              ),
              title: const Text(
                'Tickets Activos en Cola',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('Hay $activos solicitudes esperando atención.'),
            ),
          ),
        ],
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
  final VoidCallback onTicketsChanged;
  const TicketsScreen({
    super.key,
    required this.tickets,
    required this.session,
    required this.onTicketsChanged,
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

  void _openNewTicketDialog() {
    _usuarioController.clear();
    _deptoController.clear();
    _descController.clear();
    _prioridadSeleccionada = 'Media';
    _asignadoPorDefecto = 'Sin Asignar';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                      initialValue: _prioridadSeleccionada,
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
                        initialValue: _asignadoPorDefecto,
                        decoration: const InputDecoration(
                          labelText: 'Técnico Responsable',
                          border: OutlineInputBorder(),
                        ),
                        items: ['Sin Asignar', 'Carlos', 'Benjamin', 'Julio']
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
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  final nuevo = Ticket(
                    id: 'TK-${100 + widget.tickets.length + 1}',
                    usuario: _usuarioController.text,
                    departamento: _deptoController.text,
                    descripcion: _descController.text,
                    prioridad: _prioridadSeleccionada,
                    estado: 'Pendiente',
                    asignadoA: widget.session.rol == 'Admin'
                        ? _asignadoPorDefecto
                        : 'Sin Asignar',
                    fecha: DateTime.now(),
                  );
                  setState(() {
                    widget.tickets.insert(0, nuevo);
                  });
                  widget.onTicketsChanged();
                  Navigator.pop(context);
                }
              },
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String estado) {
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

  @override
  Widget build(BuildContext context) {
    List<Ticket> filtrados = widget.session.rol == 'Admin'
        ? widget.tickets
        : widget.tickets.where((t) => t.asignadoA == 'Julio').toList();
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
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
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
                            : (ticket.prioridad == 'Media'
                                  ? Colors.orange
                                  : Colors.blue),
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
                          color: _getStatusColor(
                            ticket.estado,
                          ).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          ticket.estado,
                          style: TextStyle(
                            color: _getStatusColor(ticket.estado),
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
                              Row(
                                children:
                                    ['Pendiente', 'En Proceso', 'Resuelto']
                                        .map(
                                          (e) => Padding(
                                            padding: const EdgeInsets.only(
                                              right: 6.0,
                                            ),
                                            child: ChoiceChip(
                                              label: Text(
                                                e,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                              selected: ticket.estado == e,
                                              onSelected: (_) {
                                                setState(() {
                                                  ticket.estado = e;
                                                });
                                                widget.onTicketsChanged();
                                              },
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
                                      value: ticket.asignadoA,
                                      underline: Container(),
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                      items:
                                          [
                                                'Sin Asignar',
                                                'Carlos',
                                                'Benjamin',
                                                'Julio',
                                              ]
                                              .map(
                                                (e) => DropdownMenuItem(
                                                  value: e,
                                                  child: Text(e),
                                                ),
                                              )
                                              .toList(),
                                      onChanged: (nuevoTecnico) {
                                        if (nuevoTecnico != null) {
                                          setState(() {
                                            ticket.asignadoA = nuevoTecnico;
                                          });
                                          widget.onTicketsChanged();
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
  final VoidCallback onInventarioChanged;
  const EquipmentScreen({
    super.key,
    required this.inventario,
    required this.session,
    required this.onInventarioChanged,
  });
  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  final _assignFormKey = GlobalKey<FormState>();
  final _empleadoController = TextEditingController();
  final _puestoController = TextEditingController();
  final _folioController = TextEditingController();

  void _liberarHardware(Equipo equipo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text('Liberar Folio ${equipo.folioResponsiva}'),
          ],
        ),
        content: Text(
          '¿Confirmas la baja del empleado? El equipo marcará como "Disponible" y se desvinculará de "${equipo.empleadoAsignado}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              setState(() {
                equipo.estatus = 'Disponible';
                equipo.empleadoAsignado = null;
                equipo.rolEmpleado = null;
                equipo.folioResponsiva = '---';
              });
              widget.onInventarioChanged();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Hardware liberado con éxito.')),
              );
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
      builder: (context) => AlertDialog(
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
                        ? 'Ingrese el nombre del colaborador'
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
                        ? 'Ingrese el número de folio'
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (_assignFormKey.currentState!.validate()) {
                setState(() {
                  equipo.estatus = 'Asignado';
                  equipo.empleadoAsignado = _empleadoController.text.trim();
                  equipo.rolEmpleado = _puestoController.text.trim();
                  equipo.folioResponsiva = _folioController.text.trim();
                });
                widget.onInventarioChanged();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Activo asignado y responsiva vinculada con éxito.',
                    ),
                    backgroundColor: Colors.teal,
                  ),
                );
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
              '${widget.inventario.length} equipos en sistemas',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: widget.inventario.length,
                itemBuilder: (context, index) {
                  final equipo = widget.inventario[index];
                  final bool esAsignado = equipo.estatus == 'Asignado';
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ExpansionTile(
                      leading: Icon(
                        equipo.tipo == 'Laptop'
                            ? Icons.laptop_mac_rounded
                            : (equipo.tipo == 'Servidor'
                                  ? Icons.dns_rounded
                                  : Icons.computer_rounded),
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
                              ] else ...[
                                Text(
                                  'Disponible en almacén. (Resguardo: ${equipo.empleadoAsignado ?? "Sistemas"})',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
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
// PANTALLA: CONTROL DE RESPALDOS INTERACTIVO (UNIFICADO)
// ============================================================================
class PantallaRespaldos extends StatefulWidget {
  final List<Equipo> inventario;
  final VoidCallback onInventarioChanged;

  const PantallaRespaldos({
    super.key,
    required this.inventario,
    required this.onInventarioChanged,
  });

  @override
  State<PantallaRespaldos> createState() => _PantallaRespaldosState();
}

class _PantallaRespaldosState extends State<PantallaRespaldos> {
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
            'Presiona el icono de calendario en la fecha para actualizar el último respaldo.',
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
                    headingRowColor: MaterialStateProperty.all(
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
                        if (dias >= 15) {
                          cellColor = Colors.red.shade300;
                        } else {
                          cellColor = Colors.amber.shade200;
                        }
                      }

                      String fechaFormateada = 'Sin respaldos';
                      if (equipo.ultimoRespaldo != null) {
                        final dia = equipo.ultimoRespaldo!.day
                            .toString()
                            .padLeft(2, '0');
                        final mes = equipo.ultimoRespaldo!.month
                            .toString()
                            .padLeft(2, '0');
                        final anio = equipo.ultimoRespaldo!.year;
                        fechaFormateada = "$dia/$mes/$anio";
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
                          // Celda de Fecha con botón interactivo para modificarla
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  fechaFormateada,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(
                                    Icons.calendar_month_rounded,
                                    size: 16,
                                    color: Color(0xFF0D47A1),
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () async {
                                    final DateTime? picked =
                                        await showDatePicker(
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
                                      setState(() {
                                        equipo.ultimoRespaldo = picked;
                                      });
                                      // Notifica a la estructura principal para redibujar y guardar en SharedPreferences
                                      widget.onInventarioChanged();
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          // Celda de días calculados automáticamente con color de alerta condicional
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
