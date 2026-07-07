import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show PointerHoverEvent;
import '../models/proyecto_model.dart';
import '../models/tarea_model.dart';
import '../models/usuario_model.dart';
import '../models/session_model.dart';
import '../services/api_service.dart';

class ProyectoDetalleScreen extends StatefulWidget {
  final Proyecto proyecto;
  final ApiService api;
  final Session session;
  final List<Usuario> usuarios;
  final VoidCallback onProyectoActualizado;

  const ProyectoDetalleScreen({
    super.key,
    required this.proyecto,
    required this.api,
    required this.session,
    required this.usuarios,
    required this.onProyectoActualizado,
  });

  @override
  State<ProyectoDetalleScreen> createState() => _ProyectoDetalleScreenState();
}

class _ProyectoDetalleScreenState extends State<ProyectoDetalleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<Tarea> _tareas = [];
  bool _cargando = true;

  final _busquedaCtrl = TextEditingController();
  String _busqueda = '';
  String? _asignadoFiltro;
  String? _prioridadFiltro;

  bool get _puedeEditar =>
      widget.session.rol == 'Admin' || widget.session.rol == 'Desarrollador Sr.';

  List<Tarea> get _tareasFiltradas => _tareas.where((t) {
        if (_busqueda.isNotEmpty &&
            !t.titulo.toLowerCase().contains(_busqueda) &&
            !t.descripcion.toLowerCase().contains(_busqueda)) {
          return false;
        }
        if (_asignadoFiltro != null && t.asignadoAUsername != _asignadoFiltro) return false;
        if (_prioridadFiltro != null && t.prioridad != _prioridadFiltro) return false;
        return true;
      }).toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final tareas = await widget.api.fetchTareas(proyectoId: widget.proyecto.id);
      if (mounted) setState(() { _tareas = tareas; _cargando = false; });
    } catch (e) {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _cambiarEstado(Tarea tarea, String nuevoEstado) async {
    final antes = List<Tarea>.from(_tareas);
    setState(() {
      final i = _tareas.indexWhere((t) => t.id == tarea.id);
      if (i >= 0) _tareas[i] = tarea.copyWith(estado: nuevoEstado);
    });
    try {
      await widget.api.actualizarEstadoTarea(tarea.id, nuevoEstado);
    } catch (_) {
      if (mounted) setState(() => _tareas = antes);
    }
  }

  Future<void> _actualizarFechas(Tarea tarea) async {
    try {
      await widget.api.actualizarFechasTarea(
        tarea.id,
        tarea.fechaInicio ?? widget.proyecto.fechaInicio,
        tarea.fechaFin ?? widget.proyecto.fechaFin,
      );
      final i = _tareas.indexWhere((t) => t.id == tarea.id);
      if (i >= 0 && mounted) setState(() => _tareas[i] = tarea);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _abrirDialogoTarea([Tarea? editando]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _DialogoTarea(
        tarea: editando,
        proyecto: widget.proyecto,
        usuarios: widget.usuarios,
      ),
    );
    if (result == null) return;
    try {
      if (editando == null) {
        await widget.api.crearTarea({...result, 'proyectoId': widget.proyecto.id});
      } else {
        await widget.api.actualizarTarea(editando.id, result);
      }
      _cargar();
      widget.onProyectoActualizado();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Future<void> _eliminarTarea(Tarea t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: Text('¿Eliminar "${t.titulo}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.api.eliminarTarea(t.id);
    _cargar();
    widget.onProyectoActualizado();
  }

  void _verTarea(Tarea t) {
    showDialog(
      context: context,
      builder: (_) => _DialogoVerTarea(
        tarea: t,
        puedeEditar: _puedeEditar,
        onEditar: () => _abrirDialogoTarea(t),
        onEliminar: () => _eliminarTarea(t),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2B72),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.proyecto.nombre,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargar, tooltip: 'Recargar'),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.view_kanban_outlined), text: 'Kanban'),
            Tab(icon: Icon(Icons.bar_chart_rounded), text: 'Gantt'),
          ],
        ),
      ),
      floatingActionButton: _puedeEditar
          ? FloatingActionButton.extended(
              onPressed: () => _abrirDialogoTarea(),
              icon: const Icon(Icons.add),
              label: const Text('Nueva tarea'),
            )
          : null,
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                Column(
                  children: [
                    _FiltrosKanban(
                      tareas: _tareas,
                      busquedaCtrl: _busquedaCtrl,
                      onBusqueda: (v) => setState(() => _busqueda = v.toLowerCase()),
                      asignadoFiltro: _asignadoFiltro,
                      onAsignadoChanged: (v) => setState(() => _asignadoFiltro = v),
                      prioridadFiltro: _prioridadFiltro,
                      onPrioridadChanged: (v) => setState(() => _prioridadFiltro = v),
                    ),
                    Expanded(
                      child: _KanbanView(
                        tareas: _tareasFiltradas,
                        session: widget.session,
                        puedeEditar: _puedeEditar,
                        onCambiarEstado: _cambiarEstado,
                        onVerDetalle: _verTarea,
                      ),
                    ),
                  ],
                ),
                _GanttView(
                  proyecto: widget.proyecto,
                  tareas: _tareas,
                  canEdit: _puedeEditar,
                  onTareaFechasUpdated: _actualizarFechas,
                ),
              ],
            ),
    );
  }
}

// ── Kanban ────────────────────────────────────────────────────────────────────

const _kEstados = ['por_hacer', 'haciendo', 'en_revision', 'hecho'];
const _kEstadoLabel = {
  'por_hacer': 'Por hacer',
  'haciendo': 'Haciendo',
  'en_revision': 'En revisión',
  'hecho': 'Hecho',
};
const _kEstadoColor = {
  'por_hacer': Color(0xFF9E9E9E),
  'haciendo': Color(0xFF1565C0),
  'en_revision': Color(0xFFE65100),
  'hecho': Color(0xFF2E7D32),
};

class _FiltrosKanban extends StatelessWidget {
  final List<Tarea> tareas;
  final TextEditingController busquedaCtrl;
  final ValueChanged<String> onBusqueda;
  final String? asignadoFiltro;
  final ValueChanged<String?> onAsignadoChanged;
  final String? prioridadFiltro;
  final ValueChanged<String?> onPrioridadChanged;

  const _FiltrosKanban({
    required this.tareas,
    required this.busquedaCtrl,
    required this.onBusqueda,
    required this.asignadoFiltro,
    required this.onAsignadoChanged,
    required this.prioridadFiltro,
    required this.onPrioridadChanged,
  });

  @override
  Widget build(BuildContext context) {
    final asignados = <String, String>{};
    for (final t in tareas) {
      if (t.asignadoAUsername != null && t.asignadoANombre != null) {
        asignados[t.asignadoAUsername!] = t.asignadoANombre!;
      }
    }
    final hayFiltros = asignadoFiltro != null || prioridadFiltro != null || busquedaCtrl.text.isNotEmpty;

    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(
              width: 220,
              child: TextField(
                controller: busquedaCtrl,
                onChanged: onBusqueda,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Buscar tarea...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _FiltroChipTarea(
              label: asignadoFiltro == null ? 'Asignado a' : (asignados[asignadoFiltro] ?? asignadoFiltro!),
              activo: asignadoFiltro != null,
              onTap: () async {
                final v = await showDialog<String?>(
                  context: context,
                  builder: (_) => SimpleDialog(
                    title: const Text('Filtrar por asignado'),
                    children: [
                      SimpleDialogOption(onPressed: () => Navigator.pop(context, null), child: const Text('Todos')),
                      ...asignados.entries.map((e) =>
                          SimpleDialogOption(onPressed: () => Navigator.pop(context, e.key), child: Text(e.value))),
                    ],
                  ),
                );
                onAsignadoChanged(v);
              },
            ),
            const SizedBox(width: 8),
            _FiltroChipTarea(
              label: prioridadFiltro ?? 'Prioridad',
              activo: prioridadFiltro != null,
              onTap: () async {
                final v = await showDialog<String?>(
                  context: context,
                  builder: (_) => SimpleDialog(
                    title: const Text('Filtrar por prioridad'),
                    children: [
                      SimpleDialogOption(onPressed: () => Navigator.pop(context, null), child: const Text('Todas')),
                      SimpleDialogOption(onPressed: () => Navigator.pop(context, 'alta'), child: const Text('Alta')),
                      SimpleDialogOption(onPressed: () => Navigator.pop(context, 'media'), child: const Text('Media')),
                      SimpleDialogOption(onPressed: () => Navigator.pop(context, 'baja'), child: const Text('Baja')),
                    ],
                  ),
                );
                onPrioridadChanged(v);
              },
            ),
            if (hayFiltros) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  busquedaCtrl.clear();
                  onBusqueda('');
                  onAsignadoChanged(null);
                  onPrioridadChanged(null);
                },
                icon: const Icon(Icons.clear, size: 14),
                label: const Text('Limpiar'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FiltroChipTarea extends StatelessWidget {
  final String label;
  final bool activo;
  final VoidCallback onTap;

  const _FiltroChipTarea({required this.label, required this.activo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: activo ? const Color(0xFF1A2B72) : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: activo ? const Color(0xFF1A2B72) : cs.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: activo ? Colors.white : cs.onSurfaceVariant,
                    fontWeight: activo ? FontWeight.bold : FontWeight.normal)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: activo ? Colors.white : cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _KanbanView extends StatelessWidget {
  final List<Tarea> tareas;
  final Session session;
  final bool puedeEditar;
  final void Function(Tarea, String) onCambiarEstado;
  final void Function(Tarea) onVerDetalle;

  const _KanbanView({
    required this.tareas,
    required this.session,
    required this.puedeEditar,
    required this.onCambiarEstado,
    required this.onVerDetalle,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _kEstados
            .map((estado) => _KanbanColumna(
                  estado: estado,
                  tareas: tareas.where((t) => t.estado == estado).toList(),
                  session: session,
                  puedeEditar: puedeEditar,
                  onDrop: (t) => onCambiarEstado(t, estado),
                  onVerDetalle: onVerDetalle,
                ))
            .toList(),
      ),
    );
  }
}

class _KanbanColumna extends StatefulWidget {
  final String estado;
  final List<Tarea> tareas;
  final Session session;
  final bool puedeEditar;
  final void Function(Tarea) onDrop;
  final void Function(Tarea) onVerDetalle;

  const _KanbanColumna({
    required this.estado,
    required this.tareas,
    required this.session,
    required this.puedeEditar,
    required this.onDrop,
    required this.onVerDetalle,
  });

  @override
  State<_KanbanColumna> createState() => _KanbanColumnaState();
}

class _KanbanColumnaState extends State<_KanbanColumna> {
  bool _accepting = false;

  @override
  Widget build(BuildContext context) {
    final color = _kEstadoColor[widget.estado]!;
    final surface = Theme.of(context).colorScheme.surface;
    final outlineVariant = Theme.of(context).colorScheme.outlineVariant;
    return DragTarget<Tarea>(
      onWillAcceptWithDetails: (d) => d.data.estado != widget.estado,
      onAcceptWithDetails: (d) { widget.onDrop(d.data); setState(() => _accepting = false); },
      onMove: (_) => setState(() => _accepting = true),
      onLeave: (_) => setState(() => _accepting = false),
      builder: (ctx, candidates, _) {
        return Container(
          width: 260,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: Color.alphaBlend(color.withValues(alpha: _accepting ? 0.16 : 0.08), surface),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _accepting ? color : outlineVariant,
              width: _accepting ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: Row(
                  children: [
                    Text(
                      _kEstadoLabel[widget.estado]!,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${widget.tareas.length}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              // Cards
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 120, maxHeight: 520),
                child: widget.tareas.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('Sin tareas',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(8),
                        itemCount: widget.tareas.length,
                        itemBuilder: (_, i) => _TareaCard(
                          tarea: widget.tareas[i],
                          session: widget.session,
                          puedeEditar: widget.puedeEditar,
                          onVerDetalle: () => widget.onVerDetalle(widget.tareas[i]),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// true si el usuario puede arrastrar/mover esta tarea en el Kanban:
/// Admin y Desarrollador Sr. mueven cualquiera; un Desarrollador solo la suya.
bool puedeMoverTarea({
  required String rol,
  required String? asignadoAUsername,
  required String username,
}) =>
    rol == 'Admin' || rol == 'Desarrollador Sr.' || asignadoAUsername == username;

const List<double> _kMatrizGrises = [
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
];

class _TareaCard extends StatelessWidget {
  final Tarea tarea;
  final Session session;
  final bool puedeEditar;
  final VoidCallback onVerDetalle;

  const _TareaCard({
    required this.tarea,
    required this.session,
    required this.puedeEditar,
    required this.onVerDetalle,
  });

  bool get _puedeMover => puedeEditar ||
      puedeMoverTarea(rol: session.rol, asignadoAUsername: tarea.asignadoAUsername, username: session.username);

  Color get _prioColor => switch (tarea.prioridad) {
        'alta' => Colors.red[400]!,
        'baja' => Colors.green[400]!,
        _ => Colors.blue[400]!,
      };

  @override
  Widget build(BuildContext context) {
    final body = GestureDetector(
      onTap: onVerDetalle,
      child: _CardBody(tarea: tarea, prioColor: _prioColor, atenuada: !_puedeMover),
    );
    if (!_puedeMover) return body;
    return Draggable<Tarea>(
      data: tarea,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(width: 244, child: _CardBody(tarea: tarea, prioColor: _prioColor)),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: body),
      child: body,
    );
  }
}

class _CardBody extends StatelessWidget {
  final Tarea tarea;
  final Color prioColor;
  final bool atenuada;

  const _CardBody({required this.tarea, required this.prioColor, this.atenuada = false});

  String _fmt(DateTime? d) =>
      d == null ? '—' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final card = Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: prioColor, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(tarea.titulo,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ],
            ),
            if (tarea.descripcion.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(tarea.descripcion,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                if (tarea.asignadoANombre != null) ...[
                  Icon(Icons.person_outline, size: 12, color: cs.onSurfaceVariant),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(tarea.asignadoANombre!,
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                        overflow: TextOverflow.ellipsis),
                  ),
                ] else
                  const Expanded(child: SizedBox()),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: prioColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(tarea.prioridad,
                      style: TextStyle(fontSize: 10, color: prioColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            if (tarea.fechaInicio != null || tarea.fechaFin != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 11, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('${_fmt(tarea.fechaInicio)} → ${_fmt(tarea.fechaFin)}',
                      style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
    if (!atenuada) return card;
    return Opacity(
      opacity: 0.55,
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(_kMatrizGrises),
        child: card,
      ),
    );
  }
}

class _DialogoVerTarea extends StatelessWidget {
  final Tarea tarea;
  final bool puedeEditar;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _DialogoVerTarea({
    required this.tarea,
    required this.puedeEditar,
    required this.onEditar,
    required this.onEliminar,
  });

  String _fmt(DateTime? d) => d == null
      ? 'Sin fecha'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _fila(BuildContext context, String label, String valor) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(label,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            Expanded(child: Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tarea.titulo),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tarea.descripcion.isNotEmpty) ...[
              Text(tarea.descripcion, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 14),
            ],
            _fila(context, 'Estado', _kEstadoLabel[tarea.estado] ?? tarea.estado),
            _fila(context, 'Prioridad', tarea.prioridad),
            _fila(context, 'Asignado a', tarea.asignadoANombre ?? 'Sin asignar'),
            _fila(context, 'Fecha inicio', _fmt(tarea.fechaInicio)),
            _fila(context, 'Fecha fin', _fmt(tarea.fechaFin)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        if (puedeEditar) ...[
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () { Navigator.pop(context); onEliminar(); },
            child: const Text('Eliminar'),
          ),
          FilledButton(
            onPressed: () { Navigator.pop(context); onEditar(); },
            child: const Text('Editar'),
          ),
        ],
      ],
    );
  }
}

// ── Gantt ─────────────────────────────────────────────────────────────────────

/// Stable per-task color so adjacent bars/rows are visually distinguishable
/// regardless of priority. Keyed by task id, not list position, so it
/// doesn't shuffle when the task list re-sorts. Completed tasks stay gray.
const _kTaskPalette = [
  Color(0xFF1E88E5), Color(0xFF8E24AA), Color(0xFF00897B), Color(0xFFEF6C00),
  Color(0xFFD81B60), Color(0xFF3949AB), Color(0xFF558B2F), Color(0xFF6D4C41),
  Color(0xFF00ACC1), Color(0xFFC62828), Color(0xFF5E35B1), Color(0xFF2E7D32),
];

Color _taskColor(Tarea t) =>
    t.estado == 'hecho' ? Colors.grey[400]! : _kTaskPalette[t.id % _kTaskPalette.length];

Color _prioAccentColor(String prioridad) => switch (prioridad) {
      'alta' => const Color(0xFFE53935),
      'baja' => const Color(0xFF43A047),
      _ => Colors.transparent,
    };

enum _DragType { body, leftEdge, rightEdge }

class _DragHit {
  final int index;
  final _DragType type;
  const _DragHit(this.index, this.type);
}

class _GanttView extends StatefulWidget {
  final Proyecto proyecto;
  final List<Tarea> tareas;
  final bool canEdit;
  final void Function(Tarea) onTareaFechasUpdated;

  const _GanttView({
    required this.proyecto,
    required this.tareas,
    required this.canEdit,
    required this.onTareaFechasUpdated,
  });

  @override
  State<_GanttView> createState() => _GanttViewState();
}

class _GanttViewState extends State<_GanttView> {
  static const kLabelWidth = 180.0;
  static const kHeaderHeight = 52.0;
  static const kRowHeight = 48.0;
  static const kHandleWidth = 14.0;
  static const kMinPxPerDay = 22.0;
  static const kMaxPxPerDay = 72.0;

  double _pxPerDay = 40.0;
  double _offsetX = 0;
  double? _chartWidth;
  _DragHit? _dragHit;
  double _dragStartX = 0;
  DateTime? _origInicio;
  DateTime? _origFin;
  int? _hoverIndex;
  Offset? _hoverPos;
  int? _selectedIndex;
  late List<Tarea> _tareas;

  @override
  void initState() {
    super.initState();
    _tareas = List.from(widget.tareas);
    final diasHasta = DateTime.now().difference(widget.proyecto.fechaInicio).inDays - 2;
    _offsetX = max(0.0, diasHasta * _pxPerDay);
  }

  @override
  void didUpdateWidget(_GanttView old) {
    super.didUpdateWidget(old);
    if (old.tareas != widget.tareas) setState(() => _tareas = List.from(widget.tareas));
  }

  DateTime _efectivaInicio(Tarea t) => t.fechaInicio ?? widget.proyecto.fechaInicio;
  DateTime _efectivaFin(Tarea t) => t.fechaFin ?? widget.proyecto.fechaFin;

  double get _maxOffsetX {
    final total = widget.proyecto.fechaFin.difference(widget.proyecto.fechaInicio).inDays + 14;
    return max(0.0, total * _pxPerDay - 400);
  }

  void _zoom(double delta) {
    final newPx = (_pxPerDay + delta).clamp(kMinPxPerDay, kMaxPxPerDay);
    if (newPx == _pxPerDay) return;
    final chartW = _chartWidth ?? 600.0;
    final centerDay = (_offsetX + chartW / 2) / _pxPerDay;
    setState(() {
      _pxPerDay = newPx;
      _offsetX = (centerDay * _pxPerDay - chartW / 2).clamp(0.0, _maxOffsetX);
    });
  }

  _DragHit? _hitTest(Offset pos) {
    final rowIndex = _hitTestRow(pos);
    if (rowIndex == null) return null;
    final chartX = pos.dx - kLabelWidth + _offsetX;
    final t = _tareas[rowIndex];
    final projStart = widget.proyecto.fechaInicio;
    final startD = _efectivaInicio(t).difference(projStart).inDays.toDouble();
    final endD = _efectivaFin(t).difference(projStart).inDays.toDouble();
    final bL = startD * _pxPerDay;
    final bR = max(endD, startD + 1) * _pxPerDay;
    if (chartX <= bL + kHandleWidth) return _DragHit(rowIndex, _DragType.leftEdge);
    if (chartX >= bR - kHandleWidth) return _DragHit(rowIndex, _DragType.rightEdge);
    return _DragHit(rowIndex, _DragType.body);
  }

  /// Row + bar hit test shared by drag-start and hover. Returns the task
  /// index only if the point actually falls within that task's bar.
  int? _hitTestRow(Offset pos) {
    if (pos.dx < kLabelWidth) return null;
    final chartX = pos.dx - kLabelWidth + _offsetX;
    final chartY = pos.dy - kHeaderHeight;
    if (chartY < 0) return null;
    final projStart = widget.proyecto.fechaInicio;

    for (int i = 0; i < _tareas.length; i++) {
      final t = _tareas[i];
      final startD = _efectivaInicio(t).difference(projStart).inDays.toDouble();
      final endD = _efectivaFin(t).difference(projStart).inDays.toDouble();
      final bL = startD * _pxPerDay;
      final bR = max(endD, startD + 1) * _pxPerDay;
      final bT = i * kRowHeight + (kRowHeight - 28) / 2;
      final bB = bT + 28;

      if (chartY < bT || chartY > bB) continue;
      if (chartX < bL - 4 || chartX > bR + 4) continue;
      return i;
    }
    return null;
  }

  /// Looser hit test used for tap-to-select: any click within a row's
  /// vertical band selects it, whether on the bar, empty timeline space, or
  /// the left-panel label — clicking a task's name should find it too.
  int? _hitTestAnyRow(Offset pos) {
    if (pos.dy < kHeaderHeight) return null;
    final row = ((pos.dy - kHeaderHeight) / kRowHeight).floor();
    if (row < 0 || row >= _tareas.length) return null;
    return row;
  }

  void _onTapUp(TapUpDetails d) {
    final hit = _hitTestAnyRow(d.localPosition);
    setState(() => _selectedIndex = (_selectedIndex == hit) ? null : hit);
    if (_selectedIndex != null) _scrollToTask(_selectedIndex!);
  }

  void _scrollToTask(int index) {
    final t = _tareas[index];
    final ps = widget.proyecto.fechaInicio;
    final startD = _efectivaInicio(t).difference(ps).inDays.toDouble();
    final endD = _efectivaFin(t).difference(ps).inDays.toDouble();
    final bL = startD * _pxPerDay;
    final bR = max(endD, startD + 1) * _pxPerDay;
    final chartW = _chartWidth ?? 600.0;
    if (bL < _offsetX || bR > _offsetX + chartW) {
      final center = (bL + bR) / 2;
      setState(() => _offsetX = (center - chartW / 2).clamp(0.0, _maxOffsetX));
    }
  }

  void _onPanStart(DragStartDetails d) {
    final hit = widget.canEdit ? _hitTest(d.localPosition) : null;
    if (hit != null) {
      setState(() {
        _dragHit = hit;
        _dragStartX = d.localPosition.dx;
        _origInicio = _efectivaInicio(_tareas[hit.index]);
        _origFin = _efectivaFin(_tareas[hit.index]);
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_dragHit != null) {
      final dd = ((d.localPosition.dx - _dragStartX) / _pxPerDay).round();
      setState(() {
        final t = _tareas[_dragHit!.index];
        switch (_dragHit!.type) {
          case _DragType.body:
            _tareas[_dragHit!.index] = t.copyWith(
              fechaInicio: _origInicio!.add(Duration(days: dd)),
              fechaFin: _origFin!.add(Duration(days: dd)),
            );
          case _DragType.leftEdge:
            final ns = _origInicio!.add(Duration(days: dd));
            if (ns.isBefore(_origFin!.subtract(const Duration(days: 1)))) {
              _tareas[_dragHit!.index] = t.copyWith(fechaInicio: ns);
            }
          case _DragType.rightEdge:
            final ne = _origFin!.add(Duration(days: dd));
            if (ne.isAfter(_origInicio!.add(const Duration(days: 1)))) {
              _tareas[_dragHit!.index] = t.copyWith(fechaFin: ne);
            }
        }
      });
    } else {
      setState(() => _offsetX = (_offsetX - d.delta.dx).clamp(0.0, _maxOffsetX));
    }
  }

  void _onPanEnd(DragEndDetails _) {
    if (_dragHit != null) {
      widget.onTareaFechasUpdated(_tareas[_dragHit!.index]);
      setState(() => _dragHit = null);
    }
  }

  void _onHover(PointerHoverEvent e) {
    setState(() {
      _hoverIndex = _hitTestRow(e.localPosition);
      _hoverPos = e.localPosition;
    });
  }

  Color _prioColor(String p) => switch (p) {
        'alta' => const Color(0xFFE53935),
        'baja' => const Color(0xFF43A047),
        _ => const Color(0xFF1E88E5),
      };

  String _fmt(DateTime? d) => d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    if (widget.tareas.isEmpty) {
      final cs = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded, size: 64, color: cs.onSurfaceVariant),
            const SizedBox(height: 12),
            Text('Sin tareas aún', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Crea tareas en la vista Kanban para verlas aquí.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          ],
        ),
      );
    }

    final totalHeight = kHeaderHeight + _tareas.length * kRowHeight;
    return LayoutBuilder(
      builder: (ctx, constraints) {
        _chartWidth = constraints.maxWidth - kLabelWidth;
        return Stack(
          children: [
            MouseRegion(
              cursor: _hoverIndex != null ? SystemMouseCursors.click : MouseCursor.defer,
              onHover: _onHover,
              onExit: (_) => setState(() => _hoverIndex = null),
              child: GestureDetector(
                onTapUp: _onTapUp,
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: CustomPaint(
                  size: Size(constraints.maxWidth, max(totalHeight, constraints.maxHeight)),
                  painter: _GanttPainter(
                    proyecto: widget.proyecto,
                    tareas: _tareas,
                    offsetX: _offsetX,
                    pxPerDay: _pxPerDay,
                    dragHit: _dragHit,
                    hoverIndex: _hoverIndex,
                    selectedIndex: _selectedIndex,
                    colorScheme: Theme.of(context).colorScheme,
                  ),
                ),
              ),
            ),
            Positioned(top: 10, right: 10, child: _zoomControl()),
            if (_hoverIndex != null && _dragHit == null && _hoverPos != null)
              _buildTooltip(constraints, _hoverIndex!, _hoverPos!),
          ],
        );
      },
    );
  }

  Widget _zoomControl() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 16),
            tooltip: 'Alejar',
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            onPressed: _pxPerDay <= kMinPxPerDay ? null : () => _zoom(-8),
          ),
          Container(width: 1, height: 18, color: cs.outlineVariant),
          IconButton(
            icon: const Icon(Icons.add, size: 16),
            tooltip: 'Acercar',
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            onPressed: _pxPerDay >= kMaxPxPerDay ? null : () => _zoom(8),
          ),
        ],
      ),
    );
  }

  Widget _buildTooltip(BoxConstraints constraints, int index, Offset pos) {
    final cs = Theme.of(context).colorScheme;
    final t = _tareas[index];
    const w = 220.0;
    const approxH = 116.0;
    double left = pos.dx + 16;
    if (left + w > constraints.maxWidth) left = pos.dx - w - 16;
    double top = pos.dy + 12;
    if (top + approxH > constraints.maxHeight) {
      top = (pos.dy - approxH - 12).clamp(0.0, constraints.maxHeight);
    }

    return Positioned(
      left: left.clamp(0.0, max(0.0, constraints.maxWidth - w)),
      top: top,
      child: IgnorePointer(
        child: Container(
          width: w,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.titulo,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.event_outlined, size: 13, color: cs.onSurfaceVariant),
                const SizedBox(width: 5),
                Text('${_fmt(t.fechaInicio ?? widget.proyecto.fechaInicio)} → ${_fmt(t.fechaFin ?? widget.proyecto.fechaFin)}',
                    style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.person_outline, size: 13, color: cs.onSurfaceVariant),
                const SizedBox(width: 5),
                Text(t.asignadoANombre ?? 'Sin asignar',
                    style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
              ]),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: _prioColor(t.prioridad).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(t.prioridad.toUpperCase(),
                    style: TextStyle(fontSize: 10, color: _prioColor(t.prioridad), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GanttPainter extends CustomPainter {
  final Proyecto proyecto;
  final List<Tarea> tareas;
  final double offsetX;
  final double pxPerDay;
  final _DragHit? dragHit;
  final int? hoverIndex;
  final int? selectedIndex;
  final ColorScheme colorScheme;

  static const kLabelWidth = 180.0;
  static const kHeaderHeight = 52.0;
  static const kRowHeight = 48.0;
  static const kBarHeight = 28.0;
  static const _primary = Color(0xFF1A2B72);
  static const _selectColor = Color(0xFFFFC107);

  const _GanttPainter({
    required this.proyecto,
    required this.tareas,
    required this.offsetX,
    required this.pxPerDay,
    this.dragHit,
    this.hoverIndex,
    this.selectedIndex,
    required this.colorScheme,
  });

  DateTime _eInicio(Tarea t) => t.fechaInicio ?? proyecto.fechaInicio;
  DateTime _eFin(Tarea t) => t.fechaFin ?? proyecto.fechaFin;

  /// Local-coordinate x range of the clipped, scrollable viewport (the part
  /// of the chart actually visible on screen right now). Drawing anything
  /// meant to always fill the visible area — like the header band — must use
  /// this range rather than [0, size.width], otherwise it scrolls away as
  /// soon as offsetX is nonzero (which it is on first paint).
  double _visLeft() => offsetX;
  double _visRight(Size size) => offsetX + size.width - kLabelWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = colorScheme.surfaceContainerLow);

    // ── scrollable timeline ──
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(kLabelWidth, 0, size.width - kLabelWidth, size.height));
    canvas.translate(kLabelWidth - offsetX, 0);

    _drawWeekBands(canvas, size);
    _drawHeader(canvas, size);
    _drawGrid(canvas, size);
    _drawBars(canvas);
    _drawTodayLine(canvas, size);

    canvas.restore();

    // ── fixed left panel (drawn after restore so always on top) ──
    _drawLeftPanel(canvas, size);
    canvas.drawLine(Offset(kLabelWidth, 0), Offset(kLabelWidth, size.height),
        Paint()..color = colorScheme.outlineVariant..strokeWidth = 1);
  }

  void _drawWeekBands(Canvas canvas, Size size) {
    final totalDays = proyecto.fechaFin.difference(proyecto.fechaInicio).inDays + 14;
    DateTime cur = proyecto.fechaInicio;
    for (int d = 0; d < totalDays; d++) {
      if (_isWeekend(cur)) {
        canvas.drawRect(
          Rect.fromLTWH(d * pxPerDay, kHeaderHeight, pxPerDay, size.height - kHeaderHeight),
          Paint()..color = colorScheme.surfaceContainerHighest,
        );
      }
      cur = cur.add(const Duration(days: 1));
    }
  }

  void _drawHeader(Canvas canvas, Size size) {
    // Always fill the visible viewport, regardless of horizontal scroll.
    canvas.drawRect(
      Rect.fromLTWH(_visLeft(), 0, _visRight(size) - _visLeft(), kHeaderHeight),
      Paint()..color = _primary,
    );

    final totalDays = proyecto.fechaFin.difference(proyecto.fechaInicio).inDays + 14;
    final hoy = DateTime.now();
    final showEveryDay = pxPerDay >= 26;
    String? lastMonthKey;
    DateTime cur = proyecto.fechaInicio;

    for (int d = 0; d < totalDays; d++) {
      final x = d * pxPerDay;
      final mk = '${cur.month}-${cur.year}';
      if (lastMonthKey != mk) {
        lastMonthKey = mk;
        _text(canvas, '${_mes(cur.month)} ${cur.year}', Offset(x + 6, 5),
            const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700));
      }
      final isToday = _isSameDay(cur, hoy);
      if (showEveryDay || cur.day == 1 || cur.day % 5 == 0 || isToday) {
        if (isToday) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(x + 2, 21, pxPerDay - 4, 17), const Radius.circular(4)),
            Paint()..color = const Color(0xFFDC0026),
          );
        }
        _text(canvas, cur.day.toString(), Offset(x + pxPerDay / 2 - 5, 24),
            TextStyle(
              color: isToday ? Colors.white : (_isWeekend(cur) ? Colors.red[200]! : Colors.white),
              fontSize: 10,
              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            ));
      }
      canvas.drawLine(Offset(x, kHeaderHeight - 8), Offset(x, kHeaderHeight),
          Paint()..color = Colors.white.withValues(alpha: 0.25)..strokeWidth = 0.5);
      cur = cur.add(const Duration(days: 1));
    }

    canvas.drawLine(Offset(_visLeft(), kHeaderHeight), Offset(_visRight(size), kHeaderHeight),
        Paint()..color = Colors.black.withValues(alpha: 0.1)..strokeWidth = 1);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final mondayP = Paint()..color = colorScheme.outlineVariant..strokeWidth = 0.6;
    final monthP = Paint()..color = colorScheme.outline..strokeWidth = 1.1;
    final totalDays = proyecto.fechaFin.difference(proyecto.fechaInicio).inDays + 14;
    DateTime cur = proyecto.fechaInicio;
    for (int d = 0; d < totalDays; d++) {
      if (cur.day == 1) {
        canvas.drawLine(Offset(d * pxPerDay, kHeaderHeight), Offset(d * pxPerDay, size.height), monthP);
      } else if (cur.weekday == DateTime.monday) {
        canvas.drawLine(Offset(d * pxPerDay, kHeaderHeight), Offset(d * pxPerDay, size.height), mondayP);
      }
      cur = cur.add(const Duration(days: 1));
    }
    for (int i = 0; i <= tareas.length; i++) {
      final y = kHeaderHeight + i * kRowHeight;
      canvas.drawLine(Offset(_visLeft(), y), Offset(_visRight(size), y),
          Paint()..color = colorScheme.outlineVariant..strokeWidth = 0.5);
    }
  }

  void _drawBars(Canvas canvas) {
    final ps = proyecto.fechaInicio;
    for (int i = 0; i < tareas.length; i++) {
      final t = tareas[i];
      final isDrag = dragHit?.index == i;
      final isHover = hoverIndex == i && !isDrag;
      final isSelected = selectedIndex == i;
      final isDimmed = selectedIndex != null && !isSelected;
      final startD = _eInicio(t).difference(ps).inDays.toDouble();
      final endD = _eFin(t).difference(ps).inDays.toDouble();
      final bL = startD * pxPerDay;
      final bR = max(endD, startD + 1) * pxPerDay;
      final bT = kHeaderHeight + i * kRowHeight + (kRowHeight - kBarHeight) / 2;
      final rect = Rect.fromLTWH(bL, bT, bR - bL, kBarHeight);
      final rr = RRect.fromRectAndRadius(rect, const Radius.circular(7));
      final baseColor = _taskColor(t);
      final fade = isDimmed ? 0.35 : 1.0;

      // selection glow (drawn first, behind everything)
      if (isSelected) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.inflate(3), const Radius.circular(9)),
          Paint()
            ..color = _selectColor.withValues(alpha: 0.55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }

      // soft drop shadow
      canvas.drawRRect(
        rr.shift(const Offset(0, 2)),
        Paint()
          ..color = Colors.black.withValues(alpha: (isDrag || isHover ? 0.20 : 0.12) * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
      );

      canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              baseColor.withValues(alpha: (isDrag ? 1.0 : (isHover ? 0.95 : 0.88)) * fade),
              baseColor.withValues(alpha: (isDrag ? 0.85 : 0.72) * fade),
            ],
          ).createShader(rect),
      );

      // priority accent stripe at the left edge (clipped to the bar's rounded shape)
      final accent = _prioAccentColor(t.prioridad);
      if (accent != Colors.transparent && t.estado != 'hecho') {
        canvas.save();
        canvas.clipRRect(rr);
        canvas.drawRect(Rect.fromLTWH(bL, bT, 4, kBarHeight), Paint()..color = accent.withValues(alpha: fade));
        canvas.restore();
      }

      if (isSelected) {
        canvas.drawRRect(
            rr, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = _selectColor);
      } else if (isHover || isDrag) {
        canvas.drawRRect(
            rr, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = Colors.white.withValues(alpha: 0.85));
      }

      // Handles
      final hp = Paint()..color = baseColor.withValues(alpha: (isDrag ? 1.0 : 0.65) * fade);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(bL, bT, 10, kBarHeight), const Radius.circular(7)), hp);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(bR - 10, bT, 10, kBarHeight), const Radius.circular(7)), hp);

      if (bR - bL > 40) {
        _text(canvas, t.titulo, Offset(bL + 13, bT + 7),
            TextStyle(color: Colors.white.withValues(alpha: fade), fontSize: 11, fontWeight: FontWeight.w600),
            maxWidth: bR - bL - 26);
      }
    }
  }

  void _drawTodayLine(Canvas canvas, Size size) {
    final hoy = DateTime.now();
    if (hoy.isBefore(proyecto.fechaInicio) ||
        hoy.isAfter(proyecto.fechaFin.add(const Duration(days: 14)))) return;
    final x = hoy.difference(proyecto.fechaInicio).inDays * pxPerDay + pxPerDay / 2;
    canvas.drawLine(Offset(x, kHeaderHeight), Offset(x, size.height),
        Paint()..color = const Color(0xFFDC0026).withValues(alpha: 0.55)..strokeWidth = 1.5);

    const labelW = 38.0, labelH = 17.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(x - labelW / 2, kHeaderHeight + 5, labelW, labelH), const Radius.circular(9)),
      Paint()..color = const Color(0xFFDC0026),
    );
    final tp = TextPainter(
      text: const TextSpan(
          text: 'HOY',
          style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, kHeaderHeight + 5 + (labelH - tp.height) / 2));
  }

  void _drawLeftPanel(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, kLabelWidth, size.height), Paint()..color = colorScheme.surface);
    canvas.drawRect(Rect.fromLTWH(0, 0, kLabelWidth, kHeaderHeight), Paint()..color = _primary);
    _text(canvas, proyecto.nombre, const Offset(14, 8),
        const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
        maxWidth: kLabelWidth - 18);
    _text(canvas, '${tareas.length} tarea${tareas.length != 1 ? 's' : ''}',
        const Offset(14, 30),
        const TextStyle(color: Colors.white70, fontSize: 10.5));

    for (int i = 0; i < tareas.length; i++) {
      final t = tareas[i];
      final y = kHeaderHeight + i * kRowHeight;
      final isHover = hoverIndex == i;
      final isSelected = selectedIndex == i;
      final pc = _taskColor(t);

      canvas.drawRect(
        Rect.fromLTWH(0, y, kLabelWidth, kRowHeight),
        Paint()
          ..color = isSelected
              ? pc.withValues(alpha: 0.14)
              : (isHover
                  ? colorScheme.surfaceContainerHighest
                  : (i.isEven ? colorScheme.surfaceContainerLow : colorScheme.surface)),
      );
      if (isSelected) {
        canvas.drawRect(Rect.fromLTWH(0, y, 3, kRowHeight), Paint()..color = _selectColor);
      }

      canvas.drawCircle(Offset(14, y + kRowHeight / 2 - 8), 4, Paint()..color = pc);

      _text(canvas, t.titulo, Offset(20, y + 8),
          TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: t.estado == 'hecho' ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
              decoration: t.estado == 'hecho' ? TextDecoration.lineThrough : null),
          maxWidth: kLabelWidth - 58);

      if (t.asignadoANombre != null && t.asignadoANombre!.isNotEmpty) {
        final av = Offset(kLabelWidth - 22, y + 18);
        canvas.drawCircle(av, 10, Paint()..color = pc.withValues(alpha: 0.16));
        final initials = _initials(t.asignadoANombre!);
        final tp = TextPainter(
          text: TextSpan(text: initials, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: pc)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, av - Offset(tp.width / 2, tp.height / 2));
        _text(canvas, t.asignadoANombre!, Offset(20, y + 27),
            TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant), maxWidth: kLabelWidth - 58);
      } else {
        _text(canvas, 'Sin asignar', Offset(20, y + 27),
            TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic));
      }
    }
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, min(2, parts[0].length)).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  void _text(Canvas canvas, String text, Offset offset, TextStyle style, {double? maxWidth}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth ?? double.infinity);
    tp.paint(canvas, offset);
  }

  bool _isWeekend(DateTime d) =>
      d.weekday == DateTime.saturday || d.weekday == DateTime.sunday;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _mes(int m) =>
      const ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'][m];

  @override
  bool shouldRepaint(_GanttPainter old) =>
      old.offsetX != offsetX ||
      old.pxPerDay != pxPerDay ||
      old.tareas != tareas ||
      old.dragHit != dragHit ||
      old.hoverIndex != hoverIndex ||
      old.selectedIndex != selectedIndex ||
      old.colorScheme != colorScheme;
}

// ── Diálogo tarea ──────────────────────────────────────────────────────────

class _DialogoTarea extends StatefulWidget {
  final Tarea? tarea;
  final Proyecto proyecto;
  final List<Usuario> usuarios;

  const _DialogoTarea({this.tarea, required this.proyecto, required this.usuarios});

  @override
  State<_DialogoTarea> createState() => _DialogoTareaState();
}

class _DialogoTareaState extends State<_DialogoTarea> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titulo;
  late final TextEditingController _descripcion;
  String _estado = 'por_hacer';
  String _prioridad = 'media';
  String? _asignadoA;
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  @override
  void initState() {
    super.initState();
    final t = widget.tarea;
    _titulo = TextEditingController(text: t?.titulo ?? '');
    _descripcion = TextEditingController(text: t?.descripcion ?? '');
    _estado = t?.estado ?? 'por_hacer';
    _prioridad = t?.prioridad ?? 'media';
    _asignadoA = t?.asignadoAUsername;
    _fechaInicio = t?.fechaInicio;
    _fechaFin = t?.fechaFin;
  }

  @override
  void dispose() { _titulo.dispose(); _descripcion.dispose(); super.dispose(); }

  Future<void> _pick(bool isInicio) async {
    final p = await showDatePicker(
      context: context,
      initialDate: (isInicio ? _fechaInicio : _fechaFin) ?? widget.proyecto.fechaInicio,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (p == null) return;
    setState(() { if (isInicio) _fechaInicio = p; else _fechaFin = p; });
  }

  List<Usuario> get _asignables {
    final devs = widget.usuarios
        .where((u) => u.rol == 'Desarrollador' || u.rol == 'Desarrollador Sr.')
        .toList();
    if (_asignadoA != null && !devs.any((u) => u.username == _asignadoA)) {
      final actual = widget.usuarios.where((u) => u.username == _asignadoA);
      if (actual.isNotEmpty) devs.add(actual.first);
    }
    return devs;
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'titulo': _titulo.text.trim(),
      'descripcion': _descripcion.text.trim(),
      'estado': _estado,
      'prioridad': _prioridad,
      if (_asignadoA != null) 'asignadoAUsername': _asignadoA,
      if (_fechaInicio != null) 'fechaInicio': _fechaInicio!.toIso8601String().substring(0, 10),
      if (_fechaFin != null) 'fechaFin': _fechaFin!.toIso8601String().substring(0, 10),
    });
  }

  String _fmt(DateTime? d) => d == null
      ? 'Sin fecha'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.tarea != null ? 'Editar tarea' : 'Nueva tarea'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titulo,
                  decoration: const InputDecoration(labelText: 'Título *'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _descripcion,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _estado,
                      decoration: const InputDecoration(labelText: 'Estado'),
                      items: _kEstados.map((e) => DropdownMenuItem(value: e, child: Text(_kEstadoLabel[e]!))).toList(),
                      onChanged: (v) => setState(() => _estado = v!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _prioridad,
                      decoration: const InputDecoration(labelText: 'Prioridad'),
                      items: const [
                        DropdownMenuItem(value: 'baja', child: Text('Baja')),
                        DropdownMenuItem(value: 'media', child: Text('Media')),
                        DropdownMenuItem(value: 'alta', child: Text('Alta')),
                      ],
                      onChanged: (v) => setState(() => _prioridad = v!),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  value: _asignadoA,
                  decoration: const InputDecoration(labelText: 'Asignar a'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Sin asignar')),
                    ..._asignables.map((u) =>
                        DropdownMenuItem(value: u.username, child: Text(u.nombreCompleto))),
                  ],
                  onChanged: (v) => setState(() => _asignadoA = v),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => _pick(true),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Fecha inicio', border: OutlineInputBorder()),
                        child: Text(_fmt(_fechaInicio)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: InkWell(
                      onTap: () => _pick(false),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Fecha fin', border: OutlineInputBorder()),
                        child: Text(_fmt(_fechaFin)),
                      ),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _guardar, child: Text(widget.tarea != null ? 'Guardar' : 'Crear')),
      ],
    );
  }
}
