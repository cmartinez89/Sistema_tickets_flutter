import 'dart:math';
import 'package:flutter/material.dart';
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

  bool get _puedeEditar =>
      widget.session.rol == 'Admin' || widget.session.rol == 'Enc. Desarrollo';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
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
                _KanbanView(
                  tareas: _tareas,
                  session: widget.session,
                  onCambiarEstado: _cambiarEstado,
                  onEditar: _puedeEditar ? _abrirDialogoTarea : null,
                  onEliminar: _puedeEditar ? _eliminarTarea : null,
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

class _KanbanView extends StatelessWidget {
  final List<Tarea> tareas;
  final Session session;
  final void Function(Tarea, String) onCambiarEstado;
  final void Function(Tarea)? onEditar;
  final void Function(Tarea)? onEliminar;

  const _KanbanView({
    required this.tareas,
    required this.session,
    required this.onCambiarEstado,
    this.onEditar,
    this.onEliminar,
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
                  onDrop: (t) => onCambiarEstado(t, estado),
                  onEditar: onEditar,
                  onEliminar: onEliminar,
                ))
            .toList(),
      ),
    );
  }
}

class _KanbanColumna extends StatefulWidget {
  final String estado;
  final List<Tarea> tareas;
  final void Function(Tarea) onDrop;
  final void Function(Tarea)? onEditar;
  final void Function(Tarea)? onEliminar;

  const _KanbanColumna({
    required this.estado,
    required this.tareas,
    required this.onDrop,
    this.onEditar,
    this.onEliminar,
  });

  @override
  State<_KanbanColumna> createState() => _KanbanColumnaState();
}

class _KanbanColumnaState extends State<_KanbanColumna> {
  bool _accepting = false;

  @override
  Widget build(BuildContext context) {
    final color = _kEstadoColor[widget.estado]!;
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
            color: _accepting ? color.withValues(alpha: 0.08) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _accepting ? color : Colors.grey[300]!,
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
                            style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(8),
                        itemCount: widget.tareas.length,
                        itemBuilder: (_, i) => _TareaCard(
                          tarea: widget.tareas[i],
                          onEditar: widget.onEditar,
                          onEliminar: widget.onEliminar,
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

class _TareaCard extends StatelessWidget {
  final Tarea tarea;
  final void Function(Tarea)? onEditar;
  final void Function(Tarea)? onEliminar;

  const _TareaCard({required this.tarea, this.onEditar, this.onEliminar});

  Color get _prioColor => switch (tarea.prioridad) {
        'alta' => Colors.red[400]!,
        'baja' => Colors.green[400]!,
        _ => Colors.blue[400]!,
      };

  @override
  Widget build(BuildContext context) {
    final body = _CardBody(
      tarea: tarea,
      prioColor: _prioColor,
      onEditar: onEditar != null ? () => onEditar!(tarea) : null,
      onEliminar: onEliminar != null ? () => onEliminar!(tarea) : null,
    );
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
  final VoidCallback? onEditar;
  final VoidCallback? onEliminar;

  const _CardBody({required this.tarea, required this.prioColor, this.onEditar, this.onEliminar});

  @override
  Widget build(BuildContext context) {
    return Card(
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
                if (onEditar != null)
                  InkWell(onTap: onEditar,
                      child: const Icon(Icons.edit_outlined, size: 14, color: Colors.grey)),
                if (onEliminar != null) ...[
                  const SizedBox(width: 4),
                  InkWell(onTap: onEliminar,
                      child: const Icon(Icons.delete_outline, size: 14, color: Colors.redAccent)),
                ],
              ],
            ),
            if (tarea.descripcion.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(tarea.descripcion,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                if (tarea.asignadoANombre != null) ...[
                  Icon(Icons.person_outline, size: 12, color: Colors.grey[500]),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(tarea.asignadoANombre!,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
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
          ],
        ),
      ),
    );
  }
}

// ── Gantt ─────────────────────────────────────────────────────────────────────

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
  static const kPxPerDay = 40.0;
  static const kHandleWidth = 14.0;

  double _offsetX = 0;
  _DragHit? _dragHit;
  double _dragStartX = 0;
  DateTime? _origInicio;
  DateTime? _origFin;
  late List<Tarea> _tareas;

  @override
  void initState() {
    super.initState();
    _tareas = List.from(widget.tareas);
    final diasHasta = DateTime.now().difference(widget.proyecto.fechaInicio).inDays - 2;
    _offsetX = max(0.0, diasHasta * kPxPerDay);
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
    return max(0.0, total * kPxPerDay - 400);
  }

  _DragHit? _hitTest(Offset pos) {
    if (pos.dx < kLabelWidth) return null;
    final chartX = pos.dx - kLabelWidth + _offsetX;
    final chartY = pos.dy - kHeaderHeight;
    if (chartY < 0) return null;
    final projStart = widget.proyecto.fechaInicio;

    for (int i = 0; i < _tareas.length; i++) {
      final t = _tareas[i];
      final startD = _efectivaInicio(t).difference(projStart).inDays.toDouble();
      final endD = _efectivaFin(t).difference(projStart).inDays.toDouble();
      final bL = startD * kPxPerDay;
      final bR = max(endD, startD + 1) * kPxPerDay;
      final bT = i * kRowHeight + (kRowHeight - 28) / 2;
      final bB = bT + 28;

      if (chartY < bT || chartY > bB) continue;
      if (chartX < bL - 4 || chartX > bR + 4) continue;

      if (chartX <= bL + kHandleWidth) return _DragHit(i, _DragType.leftEdge);
      if (chartX >= bR - kHandleWidth) return _DragHit(i, _DragType.rightEdge);
      return _DragHit(i, _DragType.body);
    }
    return null;
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
      final dd = ((d.localPosition.dx - _dragStartX) / kPxPerDay).round();
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

  @override
  Widget build(BuildContext context) {
    if (widget.tareas.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Sin tareas aún', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
            const SizedBox(height: 4),
            Text('Crea tareas en la vista Kanban para verlas aquí.',
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      );
    }

    final totalHeight = kHeaderHeight + _tareas.length * kRowHeight;
    return LayoutBuilder(
      builder: (ctx, constraints) => GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: CustomPaint(
          size: Size(constraints.maxWidth, max(totalHeight, constraints.maxHeight)),
          painter: _GanttPainter(
            proyecto: widget.proyecto,
            tareas: _tareas,
            offsetX: _offsetX,
            dragHit: _dragHit,
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
  final _DragHit? dragHit;

  static const kLabelWidth = 180.0;
  static const kHeaderHeight = 52.0;
  static const kRowHeight = 48.0;
  static const kBarHeight = 28.0;
  static const kPxPerDay = 40.0;
  static const _primary = Color(0xFF1A2B72);

  const _GanttPainter({
    required this.proyecto,
    required this.tareas,
    required this.offsetX,
    this.dragHit,
  });

  DateTime _eInicio(Tarea t) => t.fechaInicio ?? proyecto.fechaInicio;
  DateTime _eFin(Tarea t) => t.fechaFin ?? proyecto.fechaFin;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF0F2F8));

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
        Paint()..color = Colors.grey[300]!..strokeWidth = 1);
  }

  void _drawWeekBands(Canvas canvas, Size size) {
    final totalDays = proyecto.fechaFin.difference(proyecto.fechaInicio).inDays + 14;
    for (int w = 0; w * 7 < totalDays; w++) {
      if (w.isOdd) {
        canvas.drawRect(
          Rect.fromLTWH(w * 7 * kPxPerDay, kHeaderHeight, 7 * kPxPerDay,
              size.height - kHeaderHeight),
          Paint()..color = Colors.white.withValues(alpha: 0.5),
        );
      }
    }
  }

  void _drawHeader(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(-offsetX, 0, size.width + offsetX, kHeaderHeight),
      Paint()..color = _primary,
    );

    final totalDays = proyecto.fechaFin.difference(proyecto.fechaInicio).inDays + 14;
    String? lastMonthKey;
    DateTime cur = proyecto.fechaInicio;

    for (int d = 0; d < totalDays; d++) {
      final x = d * kPxPerDay;
      final mk = '${cur.month}-${cur.year}';
      if (lastMonthKey != mk) {
        lastMonthKey = mk;
        _text(canvas, '${_mes(cur.month)} ${cur.year}', Offset(x + 4, 4),
            const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold));
      }
      if (cur.day == 1 || cur.day % 5 == 0) {
        _text(canvas, cur.day.toString(), Offset(x + 2, 32),
            TextStyle(color: _isWeekend(cur) ? Colors.red[300]! : Colors.white70, fontSize: 9));
      }
      canvas.drawLine(Offset(x, kHeaderHeight - 6), Offset(x, kHeaderHeight),
          Paint()..color = Colors.white.withValues(alpha: 0.3)..strokeWidth = 0.5);
      cur = cur.add(const Duration(days: 1));
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridP = Paint()..color = Colors.grey[300]!..strokeWidth = 0.5;
    final totalDays = proyecto.fechaFin.difference(proyecto.fechaInicio).inDays + 14;
    DateTime cur = proyecto.fechaInicio;
    for (int d = 0; d < totalDays; d++) {
      if (cur.day == 1 || cur.weekday == DateTime.monday) {
        canvas.drawLine(
            Offset(d * kPxPerDay, kHeaderHeight), Offset(d * kPxPerDay, size.height), gridP);
      }
      cur = cur.add(const Duration(days: 1));
    }
    for (int i = 0; i <= tareas.length; i++) {
      final y = kHeaderHeight + i * kRowHeight;
      canvas.drawLine(Offset(-offsetX, y), Offset(size.width, y),
          Paint()..color = Colors.grey[200]!..strokeWidth = 0.5);
    }
  }

  void _drawBars(Canvas canvas) {
    final ps = proyecto.fechaInicio;
    for (int i = 0; i < tareas.length; i++) {
      final t = tareas[i];
      final isDrag = dragHit?.index == i;
      final startD = _eInicio(t).difference(ps).inDays.toDouble();
      final endD = _eFin(t).difference(ps).inDays.toDouble();
      final bL = startD * kPxPerDay;
      final bR = max(endD, startD + 1) * kPxPerDay;
      final bT = kHeaderHeight + i * kRowHeight + (kRowHeight - kBarHeight) / 2;

      final barColor = t.estado == 'hecho'
          ? Colors.grey[400]!
          : switch (t.prioridad) {
              'alta' => const Color(0xFFE53935),
              'baja' => const Color(0xFF43A047),
              _ => const Color(0xFF1E88E5),
            };

      final rr = RRect.fromRectAndRadius(
          Rect.fromLTWH(bL, bT, bR - bL, kBarHeight), const Radius.circular(6));

      if (isDrag) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(bL + 2, bT + 3, bR - bL, kBarHeight), const Radius.circular(6)),
          Paint()..color = Colors.black.withValues(alpha: 0.2),
        );
      }

      canvas.drawRRect(rr, Paint()..color = barColor.withValues(alpha: isDrag ? 0.95 : 0.85));

      // Handles
      final hp = Paint()..color = barColor.withValues(alpha: isDrag ? 1.0 : 0.65);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(bL, bT, 10, kBarHeight), const Radius.circular(6)), hp);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(bR - 10, bT, 10, kBarHeight), const Radius.circular(6)), hp);

      if (bR - bL > 40) {
        _text(canvas, t.titulo, Offset(bL + 13, bT + 7),
            const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
            maxWidth: bR - bL - 26);
      }
    }
  }

  void _drawTodayLine(Canvas canvas, Size size) {
    final hoy = DateTime.now();
    if (hoy.isBefore(proyecto.fechaInicio) ||
        hoy.isAfter(proyecto.fechaFin.add(const Duration(days: 14)))) return;
    final x = hoy.difference(proyecto.fechaInicio).inDays * kPxPerDay;
    canvas.drawLine(Offset(x, kHeaderHeight), Offset(x, size.height),
        Paint()..color = const Color(0xFFDC0026)..strokeWidth = 2);
    _text(canvas, 'Hoy', Offset(x + 3, kHeaderHeight + 2),
        const TextStyle(color: Color(0xFFDC0026), fontSize: 9, fontWeight: FontWeight.bold));
  }

  void _drawLeftPanel(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, kLabelWidth, size.height), Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromLTWH(0, 0, kLabelWidth, kHeaderHeight), Paint()..color = _primary);
    _text(canvas, proyecto.nombre, const Offset(12, 7),
        const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
        maxWidth: kLabelWidth - 16);
    _text(canvas, '${tareas.length} tarea${tareas.length != 1 ? 's' : ''}',
        const Offset(12, 31),
        const TextStyle(color: Colors.white70, fontSize: 10));

    for (int i = 0; i < tareas.length; i++) {
      final t = tareas[i];
      final y = kHeaderHeight + i * kRowHeight;
      if (i.isEven) {
        canvas.drawRect(Rect.fromLTWH(0, y, kLabelWidth, kRowHeight),
            Paint()..color = const Color(0xFFF8F9FC));
      }
      final pc = t.estado == 'hecho'
          ? Colors.grey[400]!
          : switch (t.prioridad) {
              'alta' => const Color(0xFFE53935),
              'baja' => const Color(0xFF43A047),
              _ => const Color(0xFF1E88E5),
            };
      canvas.drawCircle(Offset(10, y + kRowHeight / 2), 4, Paint()..color = pc);
      _text(canvas, t.titulo, Offset(20, y + 10),
          TextStyle(
              fontSize: 12,
              color: t.estado == 'hecho' ? Colors.grey[500]! : Colors.grey[800]!,
              decoration: t.estado == 'hecho' ? TextDecoration.lineThrough : null),
          maxWidth: kLabelWidth - 24);
      if (t.asignadoANombre != null) {
        _text(canvas, t.asignadoANombre!, Offset(20, y + 28),
            TextStyle(fontSize: 10, color: Colors.grey[500]!), maxWidth: kLabelWidth - 24);
      }
    }
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

  String _mes(int m) =>
      const ['', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'][m];

  @override
  bool shouldRepaint(_GanttPainter old) =>
      old.offsetX != offsetX || old.tareas != tareas || old.dragHit != dragHit;
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
                    ...widget.usuarios.map((u) =>
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
