import 'package:flutter/material.dart';
import '../models/tarea_model.dart';
import '../models/proyecto_model.dart';
import '../models/session_model.dart';
import '../services/api_service.dart';

class TareasScreen extends StatefulWidget {
  final ApiService api;
  final Session session;

  const TareasScreen({super.key, required this.api, required this.session});

  @override
  State<TareasScreen> createState() => _TareasScreenState();
}

class _TareasScreenState extends State<TareasScreen> {
  List<Tarea> _tareas = [];
  List<Proyecto> _proyectos = [];
  bool _cargando = true;
  String? _error;
  int? _proyectoFiltro;
  String? _estadoFiltro;
  String? _prioridadFiltro;

  static const _estadoLabel = {
    'por_hacer': 'Por hacer',
    'haciendo': 'Haciendo',
    'en_revision': 'En revisión',
    'hecho': 'Hecho',
  };

  static const _estadoColor = {
    'por_hacer': Color(0xFF9E9E9E),
    'haciendo': Color(0xFF1565C0),
    'en_revision': Color(0xFFE65100),
    'hecho': Color(0xFF2E7D32),
  };

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final results = await Future.wait([
        widget.api.fetchTareas(),
        widget.api.fetchProyectos(),
      ]);
      if (mounted) {
        setState(() {
          _tareas = results[0] as List<Tarea>;
          _proyectos = results[1] as List<Proyecto>;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _cargando = false; });
    }
  }

  List<Tarea> get _tareasFiltradas => _tareas.where((t) {
        if (_proyectoFiltro != null && t.proyectoId != _proyectoFiltro) return false;
        if (_estadoFiltro != null && t.estado != _estadoFiltro) return false;
        if (_prioridadFiltro != null && t.prioridad != _prioridadFiltro) return false;
        return true;
      }).toList();

  void _limpiarFiltros() => setState(() {
        _proyectoFiltro = null;
        _estadoFiltro = null;
        _prioridadFiltro = null;
      });

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            FilledButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar')),
          ],
        ),
      );
    }

    final lista = _tareasFiltradas;
    final hayFiltros =
        _proyectoFiltro != null || _estadoFiltro != null || _prioridadFiltro != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Icon(Icons.filter_list, size: 18, color: Colors.grey),
                  const SizedBox(width: 8),
                  _FiltroChip(
                    label: _proyectoFiltro == null
                        ? 'Proyecto'
                        : _proyectos.firstWhere((p) => p.id == _proyectoFiltro).nombre,
                    activo: _proyectoFiltro != null,
                    onTap: () async {
                      final p = await _pickProyecto();
                      setState(() => _proyectoFiltro = p);
                    },
                  ),
                  const SizedBox(width: 8),
                  _FiltroChip(
                    label: _estadoFiltro == null
                        ? 'Estado'
                        : _estadoLabel[_estadoFiltro]!,
                    activo: _estadoFiltro != null,
                    onTap: () async {
                      final e = await _pickEstado();
                      setState(() => _estadoFiltro = e);
                    },
                  ),
                  const SizedBox(width: 8),
                  _FiltroChip(
                    label: _prioridadFiltro ?? 'Prioridad',
                    activo: _prioridadFiltro != null,
                    onTap: () async {
                      final pr = await _pickPrioridad();
                      setState(() => _prioridadFiltro = pr);
                    },
                  ),
                  if (hayFiltros) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _limpiarFiltros,
                      icon: const Icon(Icons.clear, size: 14),
                      label: const Text('Limpiar'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ],
                  const SizedBox(width: 16),
                  Text('${lista.length} tarea${lista.length != 1 ? 's' : ''}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: lista.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.task_outlined, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('Sin tareas',
                            style: TextStyle(fontSize: 18, color: Colors.grey[500])),
                        if (hayFiltros) ...[
                          const SizedBox(height: 8),
                          TextButton(
                              onPressed: _limpiarFiltros,
                              child: const Text('Quitar filtros')),
                        ],
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _cargar,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: lista.length,
                      itemBuilder: (_, i) => _TareaFila(
                        tarea: lista[i],
                        estadoColor: _estadoColor,
                        estadoLabel: _estadoLabel,
                        onEstadoChanged: (e) => _cambiarEstado(lista[i], e),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
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

  Future<int?> _pickProyecto() => showDialog<int?>(
        context: context,
        builder: (_) => SimpleDialog(
          title: const Text('Filtrar por proyecto'),
          children: [
            SimpleDialogOption(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Todos')),
            ..._proyectos.map((p) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, p.id),
                  child: Text(p.nombre),
                )),
          ],
        ),
      );

  Future<String?> _pickEstado() => showDialog<String?>(
        context: context,
        builder: (_) => SimpleDialog(
          title: const Text('Filtrar por estado'),
          children: [
            SimpleDialogOption(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Todos')),
            ..._estadoLabel.entries.map((e) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, e.key),
                  child: Text(e.value),
                )),
          ],
        ),
      );

  Future<String?> _pickPrioridad() => showDialog<String?>(
        context: context,
        builder: (_) => SimpleDialog(
          title: const Text('Filtrar por prioridad'),
          children: [
            SimpleDialogOption(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Todas')),
            SimpleDialogOption(
                onPressed: () => Navigator.pop(context, 'alta'),
                child: const Text('Alta')),
            SimpleDialogOption(
                onPressed: () => Navigator.pop(context, 'media'),
                child: const Text('Media')),
            SimpleDialogOption(
                onPressed: () => Navigator.pop(context, 'baja'),
                child: const Text('Baja')),
          ],
        ),
      );
}

class _FiltroChip extends StatelessWidget {
  final String label;
  final bool activo;
  final VoidCallback onTap;

  const _FiltroChip({required this.label, required this.activo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: activo ? const Color(0xFF1A2B72) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: activo ? const Color(0xFF1A2B72) : Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: activo ? Colors.white : Colors.grey[700],
                    fontWeight: activo ? FontWeight.bold : FontWeight.normal)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down,
                size: 16,
                color: activo ? Colors.white : Colors.grey[600]),
          ],
        ),
      ),
    );
  }
}

class _TareaFila extends StatelessWidget {
  final Tarea tarea;
  final Map<String, Color> estadoColor;
  final Map<String, String> estadoLabel;
  final void Function(String) onEstadoChanged;

  const _TareaFila({
    required this.tarea,
    required this.estadoColor,
    required this.estadoLabel,
    required this.onEstadoChanged,
  });

  Color get _prioColor => switch (tarea.prioridad) {
        'alta' => Colors.red[400]!,
        'baja' => Colors.green[400]!,
        _ => Colors.blue[400]!,
      };

  String _fmt(DateTime? d) => d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final eColor = estadoColor[tarea.estado] ?? Colors.grey;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 36,
              decoration: BoxDecoration(
                  color: _prioColor, borderRadius: BorderRadius.circular(3)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tarea.titulo,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        decoration: tarea.estado == 'hecho'
                            ? TextDecoration.lineThrough
                            : null,
                        color: tarea.estado == 'hecho'
                            ? Colors.grey[500]
                            : Colors.grey[800],
                      )),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(tarea.proyectoNombre,
                          style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      if (tarea.asignadoANombre != null) ...[
                        Text(' · ',
                            style: TextStyle(color: Colors.grey[400])),
                        Icon(Icons.person_outline,
                            size: 11, color: Colors.grey[400]),
                        const SizedBox(width: 2),
                        Text(tarea.asignadoANombre!,
                            style:
                                TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PopupMenuButton<String>(
                  child: Chip(
                    label: Text(estadoLabel[tarea.estado] ?? tarea.estado,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.white)),
                    backgroundColor: eColor,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  itemBuilder: (_) => estadoLabel.entries
                      .map((e) =>
                          PopupMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onSelected: onEstadoChanged,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_fmt(tarea.fechaInicio)} → ${_fmt(tarea.fechaFin)}',
                  style: TextStyle(fontSize: 10, color: Colors.grey[400]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
