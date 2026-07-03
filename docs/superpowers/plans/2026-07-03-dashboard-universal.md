# Dashboard Universal (Soporte + Desarrollo) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hacer que el Dashboard principal sea la pantalla de entrada para todos los roles, mostrando el bloque de Soporte y/o el de Desarrollo según a qué tenga acceso cada quien.

**Architecture:** El Dashboard deja de vivir dentro del bloque condicional "Soporte" en `main_layout.dart` y pasa a ser la pantalla índice 0 incondicional para toda sesión. `MainLayout` carga `proyectos` y `tareas` globalmente (mismo patrón que ya usa para `tickets`/`inventario`) y se los pasa al Dashboard junto con callbacks de navegación nombrados (reemplazando el `onNavigate(int)` genérico, ya que el índice de cada pantalla ahora varía según la combinación de roles).

**Tech Stack:** Flutter Web (Dart).

## Global Constraints

- Roles existentes: `Admin`, `Técnico`, `Técnico Sr.`, `Desarrollador Sr.`, `Desarrollador`.
- Nadie ve datos de una sección de la app a la que no tiene acceso navegable.
- Admin ve ambos bloques con vista global. Técnico/Técnico Sr. ven solo Soporte (sin cambios). Desarrollador Sr. ve solo Desarrollo con vista global. Desarrollador ve solo Desarrollo con vista personal ("Mis tareas": solo las suyas).
- No se agrega ninguna tarjeta nueva al bloque Soporte existente — permanece igual.
- No se pagina ni se limita la cantidad de proyectos/tareas cargadas (mismo criterio que Tickets/Equipos: se trae todo).

---

### Task 1: `main_layout.dart` — Dashboard universal y carga de datos de desarrollo

**Files:**
- Modify: `lib/screens/main_layout.dart`

**Interfaces:**
- Produces: `_MainLayoutState._proyectos` (`List<Proyecto>`), `_MainLayoutState._tareas` (`List<Tarea>`), `_MainLayoutState._devOffset` (`int` getter — índice de la pantalla Proyectos; Tareas está en `_devOffset + 1`). `_chatIndex` cambia de fórmula pero mantiene el mismo tipo/uso.
- Consumes: `DashboardScreen` con la nueva firma de constructor (`proyectos`, `tareas`, `onNavigateTickets`, `onNavigateEquipos`, `onNavigateRespaldos`, `onNavigateProyectos`, `onNavigateTareas` — todas `VoidCallback`) que produce la Task 2. Este task se implementa PRIMERO, así que al terminar `flutter analyze` mostrará errores en la construcción de `DashboardScreen` hasta que la Task 2 la actualice — eso es esperado, no lo arregles aquí.

- [ ] **Step 1: Agregar imports de `Proyecto`/`Tarea`**

Reemplazar en `lib/screens/main_layout.dart`:
```dart
import '../models/session_model.dart';
import '../models/ticket_model.dart';
import '../models/equipo_model.dart';
import '../models/chat_message_model.dart';
import '../models/usuario_model.dart';
```
por:
```dart
import '../models/session_model.dart';
import '../models/ticket_model.dart';
import '../models/equipo_model.dart';
import '../models/proyecto_model.dart';
import '../models/tarea_model.dart';
import '../models/chat_message_model.dart';
import '../models/usuario_model.dart';
```

- [ ] **Step 2: Agregar estado `_proyectos`/`_tareas` y los getters `_devOffset`/`_chatIndex`**

Reemplazar:
```dart
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

  bool get _tieneSoporte =>
      widget.session.rol != 'Desarrollador Sr.' && widget.session.rol != 'Desarrollador';
  bool get _tieneDesarrollo =>
      widget.session.rol == 'Admin' ||
      widget.session.rol == 'Desarrollador Sr.' ||
      widget.session.rol == 'Desarrollador';
  bool get _esAdmin => widget.session.rol == 'Admin';
  int get _chatIndex => (_tieneSoporte ? 4 : 0) + (_tieneDesarrollo ? 2 : 0);
```
por:
```dart
  int _screenIndex = 0;
  int _screenAnterior = 0;
  List<Ticket> _tickets = [];
  List<Equipo> _inventario = [];
  List<Proyecto> _proyectos = [];
  List<Tarea> _tareas = [];
  List<ChatMessage> _mensajes = [];
  List<Usuario> _usuarios = [];
  int _mensajesNoLeidos = 0;
  bool _cargandoInicial = true;
  String _notifPermiso = 'default';
  late final ApiService _api;
  late final WebSocketService _ws;

  bool get _tieneSoporte =>
      widget.session.rol != 'Desarrollador Sr.' && widget.session.rol != 'Desarrollador';
  bool get _tieneDesarrollo =>
      widget.session.rol == 'Admin' ||
      widget.session.rol == 'Desarrollador Sr.' ||
      widget.session.rol == 'Desarrollador';
  bool get _esAdmin => widget.session.rol == 'Admin';

  // Índice 0 es el Dashboard, siempre presente para toda sesión.
  int get _devOffset => 1 + (_tieneSoporte ? 3 : 0);
  int get _chatIndex => _devOffset + (_tieneDesarrollo ? 2 : 0);
```

- [ ] **Step 3: Cargar proyectos y tareas en paralelo con tickets/equipos**

Reemplazar:
```dart
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
```
por:
```dart
  Future<void> _cargarDatos({bool silencioso = false}) async {
    if (!mounted) return;
    try {
      final results = await Future.wait([
        _api.fetchTickets(),
        _api.fetchEquipos(),
        _api.fetchProyectos(),
        _api.fetchTareas(),
      ]);
      if (!mounted) return;
      final nuevosTickets = results[0] as List<Ticket>;
      final nuevosEquipos = results[1] as List<Equipo>;
      final nuevosProyectos = results[2] as List<Proyecto>;
      final nuevasTareas = results[3] as List<Tarea>;
      if (silencioso) _detectarCambiosYNotificar(nuevosTickets);
      setState(() {
        _tickets = nuevosTickets;
        _inventario = nuevosEquipos;
        _proyectos = nuevosProyectos;
        _tareas = nuevasTareas;
        _cargandoInicial = false;
      });
    } catch (e) {
```

- [ ] **Step 4: Reescribir la construcción de `screens` en `build()`**

Reemplazar:
```dart
    final screens = [
      if (_tieneSoporte) ...[
        DashboardScreen(tickets: _tickets, inventario: _inventario, session: widget.session, onNavigate: (i) => setState(() => _screenIndex = i)),
        TicketsScreen(tickets: _tickets, usuarios: _usuarios, session: widget.session, api: _api, onRefresh: () => _cargarDatos(silencioso: true)),
        EquipmentScreen(inventario: _inventario, session: widget.session, api: _api, onRefresh: () => _cargarDatos(silencioso: true)),
        PantallaRespaldos(inventario: _inventario, api: _api, onRefresh: () => _cargarDatos(silencioso: true), session: widget.session),
      ],
      if (_tieneDesarrollo) ...[
        ProyectosScreen(api: _api, session: widget.session),
        TareasScreen(api: _api, session: widget.session),
      ],
```
por:
```dart
    final screens = [
      DashboardScreen(
        tickets: _tickets,
        inventario: _inventario,
        proyectos: _proyectos,
        tareas: _tareas,
        session: widget.session,
        onNavigateTickets: () => setState(() => _screenIndex = 1),
        onNavigateEquipos: () => setState(() => _screenIndex = 2),
        onNavigateRespaldos: () => setState(() => _screenIndex = 3),
        onNavigateProyectos: () => setState(() => _screenIndex = _devOffset),
        onNavigateTareas: () => setState(() => _screenIndex = _devOffset + 1),
      ),
      if (_tieneSoporte) ...[
        TicketsScreen(tickets: _tickets, usuarios: _usuarios, session: widget.session, api: _api, onRefresh: () => _cargarDatos(silencioso: true)),
        EquipmentScreen(inventario: _inventario, session: widget.session, api: _api, onRefresh: () => _cargarDatos(silencioso: true)),
        PantallaRespaldos(inventario: _inventario, api: _api, onRefresh: () => _cargarDatos(silencioso: true), session: widget.session),
      ],
      if (_tieneDesarrollo) ...[
        ProyectosScreen(api: _api, session: widget.session),
        TareasScreen(api: _api, session: widget.session),
      ],
```

- [ ] **Step 5: Actualizar el drawer — Dashboard incondicional, `devOffset` local reemplazado por el getter**

Reemplazar:
```dart
      drawer: Builder(builder: (ctx) {
        final int soporteCount = _tieneSoporte ? 4 : 0;
        final int devOffset = _tieneDesarrollo ? soporteCount : -1;
        final int adminOffset = _chatIndex + 1;

        return Drawer(
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
                    Text(widget.session.nombreCompleto,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(widget.session.rol,
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              // ── Soporte Técnico ──────────────────────────────────────
              if (_tieneSoporte) ...[
                _sectionHeader('Soporte Técnico'),
                _item(Icons.dashboard_rounded, 'Dashboard', 0),
                _item(Icons.confirmation_number_rounded, 'Tickets / Asignaciones', 1),
                _item(Icons.computer_rounded, 'Equipos / Responsivas', 2),
                _item(Icons.backup_rounded, 'Control de Respaldos', 3),
              ],
              // ── Desarrollo ───────────────────────────────────────────
              if (_tieneDesarrollo) ...[
                const Divider(indent: 16, endIndent: 16),
                _sectionHeader('Desarrollo'),
                _item(Icons.folder_special_rounded, 'Proyectos', devOffset),
                _item(Icons.task_alt_rounded, 'Tareas', devOffset + 1),
              ],
              // ── Chat ───────────────────────────────────────────────
              const Divider(indent: 16, endIndent: 16),
              _itemChat(),
              // ── Administración ───────────────────────────────────────
              if (_esAdmin) ...[
                const Divider(indent: 16, endIndent: 16),
                _sectionHeader('Administración'),
                _item(Icons.manage_accounts_rounded, 'Gestión de Usuarios', adminOffset),
                _item(Icons.settings_rounded, 'Administración', adminOffset + 1),
                _item(Icons.bar_chart_rounded, 'Reportes', adminOffset + 2),
                _item(Icons.smart_toy_rounded, 'Asistente IA', adminOffset + 3),
              ],
            ],
          ),
        );
      }),
```
por:
```dart
      drawer: Builder(builder: (ctx) {
        final int adminOffset = _chatIndex + 1;

        return Drawer(
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
                    Text(widget.session.nombreCompleto,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(widget.session.rol,
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              _item(Icons.dashboard_rounded, 'Dashboard', 0),
              // ── Soporte Técnico ──────────────────────────────────────
              if (_tieneSoporte) ...[
                const Divider(indent: 16, endIndent: 16),
                _sectionHeader('Soporte Técnico'),
                _item(Icons.confirmation_number_rounded, 'Tickets / Asignaciones', 1),
                _item(Icons.computer_rounded, 'Equipos / Responsivas', 2),
                _item(Icons.backup_rounded, 'Control de Respaldos', 3),
              ],
              // ── Desarrollo ───────────────────────────────────────────
              if (_tieneDesarrollo) ...[
                const Divider(indent: 16, endIndent: 16),
                _sectionHeader('Desarrollo'),
                _item(Icons.folder_special_rounded, 'Proyectos', _devOffset),
                _item(Icons.task_alt_rounded, 'Tareas', _devOffset + 1),
              ],
              // ── Chat ───────────────────────────────────────────────
              const Divider(indent: 16, endIndent: 16),
              _itemChat(),
              // ── Administración ───────────────────────────────────────
              if (_esAdmin) ...[
                const Divider(indent: 16, endIndent: 16),
                _sectionHeader('Administración'),
                _item(Icons.manage_accounts_rounded, 'Gestión de Usuarios', adminOffset),
                _item(Icons.settings_rounded, 'Administración', adminOffset + 1),
                _item(Icons.bar_chart_rounded, 'Reportes', adminOffset + 2),
                _item(Icons.smart_toy_rounded, 'Asistente IA', adminOffset + 3),
              ],
            ],
          ),
        );
      }),
```

- [ ] **Step 6: Verificar compilación (se esperan errores solo en la construcción de `DashboardScreen`)**

Run: `flutter analyze lib/screens/main_layout.dart`
Expected: errores únicamente sobre los parámetros de `DashboardScreen` (`onNavigate`, falta `proyectos`/`tareas`, etc.) — se resuelven en la Task 2. Ningún otro error.

- [ ] **Step 7: Commit**

```bash
git add lib/screens/main_layout.dart
git commit -m "Feat: Dashboard universal — carga proyectos/tareas globalmente y recalcula indices de navegacion"
```

---

### Task 2: `dashboard_screen.dart` — contenido por rol (Soporte y/o Desarrollo)

**Files:**
- Modify: `lib/screens/dashboard_screen.dart` (reemplazo completo del archivo)

**Interfaces:**
- Consumes: `Proyecto` (`lib/models/proyecto_model.dart`: `nombre`, `estado`, `fechaInicio`, `tareasTotal`, `tareasHecho`), `Tarea` (`lib/models/tarea_model.dart`: `estado`, `prioridad`, `asignadoAUsername`), y los 5 callbacks nombrados que ahora construye `main_layout.dart` (Task 1): `onNavigateTickets`, `onNavigateEquipos`, `onNavigateRespaldos`, `onNavigateProyectos`, `onNavigateTareas` (todos `VoidCallback`).
- Produces: `DashboardScreen` con constructor `{tickets, inventario, proyectos, tareas, session, onNavigateTickets, onNavigateEquipos, onNavigateRespaldos, onNavigateProyectos, onNavigateTareas}`, todos `required`.

- [ ] **Step 1: Reemplazar el archivo completo**

Reemplazar TODO el contenido de `lib/screens/dashboard_screen.dart` por:

```dart
import 'package:flutter/material.dart';
import '../models/ticket_model.dart';
import '../models/equipo_model.dart';
import '../models/proyecto_model.dart';
import '../models/tarea_model.dart';
import '../models/session_model.dart';

class DashboardScreen extends StatelessWidget {
  final List<Ticket> tickets;
  final List<Equipo> inventario;
  final List<Proyecto> proyectos;
  final List<Tarea> tareas;
  final Session session;
  final VoidCallback onNavigateTickets;
  final VoidCallback onNavigateEquipos;
  final VoidCallback onNavigateRespaldos;
  final VoidCallback onNavigateProyectos;
  final VoidCallback onNavigateTareas;

  const DashboardScreen({
    super.key,
    required this.tickets,
    required this.inventario,
    required this.proyectos,
    required this.tareas,
    required this.session,
    required this.onNavigateTickets,
    required this.onNavigateEquipos,
    required this.onNavigateRespaldos,
    required this.onNavigateProyectos,
    required this.onNavigateTareas,
  });

  bool get _soporteVisible =>
      session.rol != 'Desarrollador Sr.' && session.rol != 'Desarrollador';
  bool get _desarrolloVisible =>
      session.rol == 'Admin' || session.rol == 'Desarrollador Sr.' || session.rol == 'Desarrollador';
  bool get _vistaGlobalDesarrollo => session.rol == 'Admin' || session.rol == 'Desarrollador Sr.';

  String get _tituloHeader => switch (session.rol) {
        'Admin' => 'Consola de Control Global',
        'Desarrollador Sr.' => 'Consola de Desarrollo',
        'Desarrollador' => 'Mis Tareas de Desarrollo',
        _ => 'Mis Tareas TI',
      };

  @override
  Widget build(BuildContext context) {
    final visibles = session.rol == 'Admin'
        ? tickets
        : tickets.where((t) => t.asignadoA.toLowerCase() == session.username.toLowerCase()).toList();

    final total = visibles.length;
    final pendientes = visibles.where((t) => t.estado == 'Pendiente').length;
    final enProceso = visibles.where((t) => t.estado == 'En Proceso').length;
    final resueltos = visibles.where((t) => t.estado == 'Resuelto').length;
    final escalados = visibles.where((t) => t.estado == 'Escalado').length;
    final alta = visibles.where((t) => t.prioridad == 'Alta' && t.estado != 'Resuelto').length;

    final totalEquipos = inventario.length;
    final asignados = inventario.where((e) => e.estatus == 'Asignado').length;
    final disponibles = inventario.where((e) => e.estatus == 'Disponible').length;
    final valorTotal = inventario.fold<double>(0, (s, e) => s + e.valorActual);

    final conRespaldo = inventario
        .where((e) => e.ultimoRespaldo != null && DateTime.now().difference(e.ultimoRespaldo!).inDays < 15)
        .length;
    final sinRespaldo = totalEquipos - conRespaldo;

    final recientes = session.rol == 'Admin'
        ? (List<Ticket>.from(tickets)..sort((a, b) => b.fecha.compareTo(a.fecha))).take(5).toList()
        : <Ticket>[];

    final tareasVisibles = _vistaGlobalDesarrollo
        ? tareas
        : tareas.where((t) => t.asignadoAUsername == session.username).toList();

    final totalProyectos = proyectos.length;
    final proyectosActivos = proyectos.where((p) => p.estado == 'activo').length;

    final totalTareasVisibles = tareasVisibles.length;
    final tareasPorHacer = tareasVisibles.where((t) => t.estado == 'por_hacer').length;
    final tareasHaciendo = tareasVisibles.where((t) => t.estado == 'haciendo').length;
    final tareasEnRevision = tareasVisibles.where((t) => t.estado == 'en_revision').length;
    final tareasAltaPendiente =
        tareasVisibles.where((t) => t.prioridad == 'alta' && t.estado != 'hecho').length;

    final proyectosRecientes = _vistaGlobalDesarrollo
        ? (List<Proyecto>.from(proyectos)..sort((a, b) => b.fechaInicio.compareTo(a.fechaInicio))).take(5).toList()
        : <Proyecto>[];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: LayoutBuilder(
        builder: (context, constraints) {
          int col = 1;
          double cardHeight = 88;
          if (constraints.maxWidth >= 1100) {
            col = 4;
            cardHeight = 132;
          } else if (constraints.maxWidth >= 650) {
            col = 2;
            cardHeight = 120;
          }
          final narrow = col == 1;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headerCard(),
                if (_soporteVisible && (pendientes > 0 || alta > 0 || sinRespaldo > 0 || escalados > 0)) ...[
                  const SizedBox(height: 14),
                  _alertStrip(pendientes: pendientes, alta: alta, sinRespaldo: sinRespaldo, escalados: escalados),
                ],
                const SizedBox(height: 28),

                if (_soporteVisible) ...[
                  _sectionHeader('Tickets de Soporte', Icons.confirmation_number_rounded, Colors.indigo),
                  const SizedBox(height: 14),
                  _cardGrid(col: col, cardHeight: cardHeight, children: [
                    _cardDonut(titulo: 'Pendientes', numero: '$pendientes', subtitulo: 'de $total tickets', progreso: total > 0 ? pendientes / total : 0, color: Colors.red.shade600, icono: Icons.hourglass_top_rounded, narrow: narrow, onTap: onNavigateTickets),
                    _cardDonut(titulo: 'En Proceso', numero: '$enProceso', subtitulo: 'de $total tickets', progreso: total > 0 ? enProceso / total : 0, color: Colors.orange.shade700, icono: Icons.autorenew_rounded, narrow: narrow, onTap: onNavigateTickets),
                    _cardDonut(titulo: 'Resueltos', numero: '$resueltos', subtitulo: 'de $total tickets', progreso: total > 0 ? resueltos / total : 0, color: Colors.green.shade600, icono: Icons.check_circle_rounded, narrow: narrow, onTap: onNavigateTickets),
                    _cardDonut(titulo: 'Prioridad Alta', numero: '$alta', subtitulo: 'sin resolver', progreso: total > 0 ? alta / total : 0, color: Colors.deepOrange.shade700, icono: Icons.priority_high_rounded, narrow: narrow, onTap: onNavigateTickets),
                  ]),
                  const SizedBox(height: 32),

                  _sectionHeader('Inventario de Equipos', Icons.computer_rounded, const Color(0xFF1A2B72)),
                  const SizedBox(height: 14),
                  _cardGrid(col: col, cardHeight: cardHeight, children: [
                    _cardDonut(titulo: 'Asignados', numero: '$asignados', subtitulo: 'de $totalEquipos equipos', progreso: totalEquipos > 0 ? asignados / totalEquipos : 0, color: Colors.indigo.shade600, icono: Icons.person_rounded, narrow: narrow, onTap: onNavigateEquipos),
                    _cardDonut(titulo: 'Disponibles', numero: '$disponibles', subtitulo: 'en almacén', progreso: totalEquipos > 0 ? disponibles / totalEquipos : 0, color: Colors.blue.shade700, icono: Icons.inventory_2_rounded, narrow: narrow, onTap: onNavigateEquipos),
                    _cardStat(titulo: 'Valor del Inventario', numero: '\$${_formatMiles(valorTotal)}', subtitulo: 'MXN depreciado', color: Colors.blueGrey.shade700, icono: Icons.account_balance_wallet_rounded, narrow: narrow, onTap: onNavigateEquipos),
                    _cardStat(titulo: 'Total de Equipos', numero: '$totalEquipos', subtitulo: 'registrados', color: Colors.blue.shade700, icono: Icons.devices_rounded, narrow: narrow, onTap: onNavigateEquipos),
                  ]),
                  const SizedBox(height: 32),

                  _sectionHeader('Estado de Respaldos', Icons.backup_rounded, Colors.purple),
                  const SizedBox(height: 14),
                  _cardGrid(col: col, cardHeight: cardHeight, children: [
                    _cardDonut(titulo: 'Al día', numero: '$conRespaldo', subtitulo: 'últimos 15 días', progreso: totalEquipos > 0 ? conRespaldo / totalEquipos : 0, color: Colors.green.shade600, icono: Icons.cloud_done_rounded, narrow: narrow, onTap: onNavigateRespaldos),
                    _cardDonut(titulo: 'Atrasados', numero: '$sinRespaldo', subtitulo: '+15 días sin respaldo', progreso: totalEquipos > 0 ? sinRespaldo / totalEquipos : 0, color: Colors.red.shade600, icono: Icons.cloud_off_rounded, narrow: narrow, onTap: onNavigateRespaldos),
                  ]),

                  if (recientes.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _sectionHeader('Últimos Tickets Registrados', Icons.history_rounded, Colors.blueGrey),
                    const SizedBox(height: 14),
                    _recentTicketsCard(recientes),
                  ],
                ],

                if (_desarrolloVisible) ...[
                  if (_soporteVisible) const SizedBox(height: 32),
                  _sectionHeader('Proyectos', Icons.folder_special_rounded, Colors.teal),
                  const SizedBox(height: 14),
                  _cardGrid(col: col, cardHeight: cardHeight, children: [
                    _cardStat(titulo: 'Proyectos Activos', numero: '$proyectosActivos', subtitulo: 'de $totalProyectos totales', color: Colors.teal.shade700, icono: Icons.folder_special_rounded, narrow: narrow, onTap: onNavigateProyectos),
                  ]),
                  const SizedBox(height: 32),

                  _sectionHeader(_vistaGlobalDesarrollo ? 'Tareas del Equipo' : 'Mis Tareas', Icons.task_alt_rounded, Colors.deepPurple),
                  const SizedBox(height: 14),
                  _cardGrid(col: col, cardHeight: cardHeight, children: [
                    _cardDonut(titulo: 'Por hacer', numero: '$tareasPorHacer', subtitulo: 'de $totalTareasVisibles tareas', progreso: totalTareasVisibles > 0 ? tareasPorHacer / totalTareasVisibles : 0, color: Colors.grey.shade600, icono: Icons.pending_actions_rounded, narrow: narrow, onTap: onNavigateTareas),
                    _cardDonut(titulo: 'Haciendo', numero: '$tareasHaciendo', subtitulo: 'de $totalTareasVisibles tareas', progreso: totalTareasVisibles > 0 ? tareasHaciendo / totalTareasVisibles : 0, color: Colors.blue.shade700, icono: Icons.autorenew_rounded, narrow: narrow, onTap: onNavigateTareas),
                    _cardDonut(titulo: 'En revisión', numero: '$tareasEnRevision', subtitulo: 'de $totalTareasVisibles tareas', progreso: totalTareasVisibles > 0 ? tareasEnRevision / totalTareasVisibles : 0, color: Colors.orange.shade700, icono: Icons.rate_review_rounded, narrow: narrow, onTap: onNavigateTareas),
                    _cardDonut(titulo: 'Prioridad alta', numero: '$tareasAltaPendiente', subtitulo: 'sin terminar', progreso: totalTareasVisibles > 0 ? tareasAltaPendiente / totalTareasVisibles : 0, color: Colors.deepOrange.shade700, icono: Icons.priority_high_rounded, narrow: narrow, onTap: onNavigateTareas),
                  ]),

                  if (proyectosRecientes.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _sectionHeader('Proyectos Recientes', Icons.history_rounded, Colors.blueGrey),
                    const SizedBox(height: 14),
                    _recentProjectsCard(proyectosRecientes),
                  ],
                ],
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _headerCard() {
    final now = DateTime.now();
    const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    final fecha = '${now.day} ${meses[now.month - 1]} ${now.year}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A2B72), Color(0xFF0D1A4A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: const Color(0xFF1A2B72).withValues(alpha: 0.4), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.monitor_heart_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tituloHeader,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 3),
                Text(session.nombreCompleto, style: const TextStyle(fontSize: 13, color: Colors.white70)),
                Text(fecha, style: const TextStyle(fontSize: 11, color: Colors.white54)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
            ),
            child: Text(session.rol, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _alertStrip({required int pendientes, required int alta, required int sinRespaldo, int escalados = 0}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (pendientes > 0) _alertChip('$pendientes pendiente${pendientes > 1 ? 's' : ''}', Colors.red.shade600, Icons.hourglass_top_rounded, onNavigateTickets),
                if (alta > 0) _alertChip('$alta prioridad alta', Colors.deepOrange.shade700, Icons.priority_high_rounded, onNavigateTickets),
                if (escalados > 0) _alertChip('$escalados escalado${escalados > 1 ? 's' : ''}', Colors.purple.shade700, Icons.escalator_warning_rounded, onNavigateTickets),
                if (sinRespaldo > 0) _alertChip('$sinRespaldo sin respaldo', Colors.amber.shade800, Icons.cloud_off_rounded, onNavigateRespaldos),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _alertChip(String label, Color color, IconData icon, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 11, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String titulo, IconData icono, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icono, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(titulo, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: Colors.grey.shade200)),
      ],
    );
  }

  Widget _cardGrid({required int col, required double cardHeight, required List<Widget> children}) {
    return LayoutBuilder(
      builder: (_, constraints) {
        const spacing = 14.0;
        final itemW = (constraints.maxWidth - spacing * (col - 1)) / col;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children.map((c) => SizedBox(width: itemW, height: cardHeight, child: c)).toList(),
        );
      },
    );
  }

  Widget _cardShell({required Color color, required Widget child, VoidCallback? onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        mouseCursor: onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(height: 4, color: color),
                Expanded(
                  child: Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 10), child: child),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _cardDonut({
    required String titulo,
    required String numero,
    required String subtitulo,
    required double progreso,
    required Color color,
    required IconData icono,
    required bool narrow,
    VoidCallback? onTap,
  }) {
    return _cardShell(
      onTap: onTap,
      color: color,
      child: narrow
          ? Row(children: [
              _ring(numero, progreso, color, 62),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(children: [
                      Icon(icono, color: color, size: 13),
                      const SizedBox(width: 5),
                      Expanded(child: Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                    const SizedBox(height: 4),
                    Text(subtitulo, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ])
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icono, color: color, size: 13),
                  const SizedBox(width: 5),
                  Expanded(child: Text(titulo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
                const Spacer(),
                Center(child: _ring(numero, progreso, color, 52)),
                const SizedBox(height: 6),
                Center(child: Text(subtitulo, style: TextStyle(fontSize: 10, color: Colors.grey.shade500), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
    );
  }

  Widget _ring(String numero, double progreso, Color color, double size) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: progreso,
            strokeWidth: size > 55 ? 6.5 : 5.5,
            color: color,
            backgroundColor: color.withValues(alpha: 0.13),
          ),
          Text(numero, style: TextStyle(fontSize: size > 55 ? 17 : 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _cardStat({
    required String titulo,
    required String numero,
    required String subtitulo,
    required Color color,
    required IconData icono,
    required bool narrow,
    VoidCallback? onTap,
  }) {
    return _cardShell(
      onTap: onTap,
      color: color,
      child: narrow
          ? Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                child: Icon(icono, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(titulo, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(numero, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(subtitulo, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            ])
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icono, color: color, size: 13),
                  const SizedBox(width: 5),
                  Expanded(child: Text(titulo, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                ]),
                const Spacer(),
                Text(numero, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(subtitulo, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
              ],
            ),
    );
  }

  Widget _recentTicketsCard(List<Ticket> recientes) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: recientes.asMap().entries.map((entry) {
            return _ticketRow(entry.value, isLast: entry.key == recientes.length - 1, onTap: onNavigateTickets);
          }).toList(),
        ),
      ),
    );
  }

  Widget _ticketRow(Ticket t, {required bool isLast, VoidCallback? onTap}) {
    final estadoColor = switch (t.estado) {
      'Pendiente' => Colors.red.shade600,
      'En Proceso' => Colors.orange.shade700,
      'Resuelto' => Colors.green.shade600,
      _ => Colors.grey,
    };
    final prioColor = t.prioridad == 'Alta'
        ? Colors.deepOrange.shade700
        : (t.prioridad == 'Media' ? Colors.amber.shade700 : Colors.grey.shade500);

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: estadoColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.confirmation_number_rounded, color: estadoColor, size: 15),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.descripcion, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${t.usuario} · ${t.departamento}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _statusChip(t.estado, estadoColor),
                  const SizedBox(height: 3),
                  Text(t.prioridad, style: TextStyle(fontSize: 10, color: prioColor, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.grey.shade100),
      ],
    );
  }

  Widget _recentProjectsCard(List<Proyecto> recientes) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: recientes.asMap().entries.map((entry) {
            return _projectRow(entry.value, isLast: entry.key == recientes.length - 1, onTap: onNavigateProyectos);
          }).toList(),
        ),
      ),
    );
  }

  Widget _projectRow(Proyecto p, {required bool isLast, VoidCallback? onTap}) {
    final estadoColor = switch (p.estado) {
      'terminado' => Colors.green.shade600,
      'pausado' => Colors.orange.shade700,
      _ => const Color(0xFF1A2B72),
    };

    return Column(
      children: [
        InkWell(
          onTap: onTap,
          mouseCursor: SystemMouseCursors.click,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: estadoColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.folder_special_rounded, color: estadoColor, size: 15),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.nombre, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('${p.tareasHecho}/${p.tareasTotal} tareas', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _statusChip(p.estado, estadoColor),
              ],
            ),
          ),
        ),
        if (!isLast) Divider(height: 1, color: Colors.grey.shade100),
      ],
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }

  String _formatMiles(double valor) {
    if (valor >= 1000000) return '${(valor / 1000000).toStringAsFixed(1)}M';
    if (valor >= 1000) return '${(valor / 1000).toStringAsFixed(1)}K';
    return valor.toStringAsFixed(0);
  }
}
```

- [ ] **Step 2: Verificar compilación de todo el proyecto**

Run: `flutter analyze`
Expected: `No issues found!` salvo los lints preexistentes ya conocidos (deprecaciones `value`→`initialValue`, `sort_child_properties_last` en `tareas_screen.dart`, `dead_code` en `tickets_screen.dart`, etc. — ninguno nuevo relacionado a `dashboard_screen.dart` o `main_layout.dart`).

- [ ] **Step 3: Ejecutar la suite de tests**

Run: `flutter test`
Expected: `+2: All tests passed!` (sin cambios respecto a los tests existentes — este task no agrega tests nuevos, ya que el contenido es puramente de presentación condicionado por rol, mismo patrón sin tests que el resto de `dashboard_screen.dart`).

- [ ] **Step 4: Commit**

```bash
git add lib/screens/dashboard_screen.dart
git commit -m "Feat: Dashboard muestra bloque de Desarrollo (global o personal segun rol) junto al de Soporte"
```

---

### Task 3: Verificación local

**Files:** ninguno (solo verificación).

- [ ] **Step 1: `flutter analyze` de todo el proyecto**

Run: `flutter analyze`
Expected: mismo resultado que el Step 2 de la Task 2 (sin issues nuevos).

- [ ] **Step 2: Levantar la app localmente para que el usuario pruebe**

Run: `flutter run -d chrome`

Checklist manual a validar con el usuario antes de continuar:
- Con Admin: el Dashboard muestra ambos bloques (Soporte arriba, Desarrollo abajo), con estadísticas globales de proyectos/tareas.
- El drawer muestra "Dashboard" como primer ítem para todos los roles, incluyendo Desarrollador/Desarrollador Sr.
- Las tarjetas del bloque Desarrollo navegan correctamente a Proyectos/Tareas al hacer clic.
- Las tarjetas del bloque Soporte siguen navegando correctamente a Tickets/Equipos/Respaldos (sin regresión).
- El botón flotante de chat y el ítem de chat en el drawer siguen funcionando en la posición correcta para cada rol.

- [ ] **Step 3: No continuar a subir/desplegar hasta que el usuario confirme explícitamente que todo lo anterior funciona bien.**

## Self-Review

**Cobertura del spec:**
- §1 Navegación (Dashboard universal, carga global de proyectos/tareas, callbacks nombrados) → Task 1.
- §2 Contenido por rol (Admin ambos globales, Técnico/Técnico Sr. solo soporte, Desarrollador Sr. desarrollo global, Desarrollador solo sus tareas) → Task 2.
- Fuera de alcance (sin tarjetas nuevas en Soporte, sin paginación) → respetado, Task 2 no toca las secciones de Soporte más que envolverlas en `if (_soporteVisible)`.

**Placeholders:** ninguno — todo el código está completo en cada step.

**Consistencia de tipos:** `DashboardScreen`'s nuevos campos (`proyectos: List<Proyecto>`, `tareas: List<Tarea>`, los 5 `VoidCallback`) se definen en la Task 2 y se usan con los mismos nombres exactos en la construcción de la Task 1. `_devOffset`/`_chatIndex` se usan consistentemente en `build()` y en el `drawer` dentro de `main_layout.dart`.
