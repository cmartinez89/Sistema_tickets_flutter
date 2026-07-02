import 'package:flutter/material.dart';
import '../models/proyecto_model.dart';
import '../models/usuario_model.dart';
import '../models/session_model.dart';
import '../services/api_service.dart';
import 'proyecto_detalle_screen.dart';

class ProyectosScreen extends StatefulWidget {
  final ApiService api;
  final Session session;

  const ProyectosScreen({super.key, required this.api, required this.session});

  @override
  State<ProyectosScreen> createState() => _ProyectosScreenState();
}

class _ProyectosScreenState extends State<ProyectosScreen> {
  List<Proyecto> _proyectos = [];
  List<Usuario> _usuarios = [];
  bool _cargando = true;
  String? _error;

  bool get _puedeEditar =>
      widget.session.rol == 'Admin' || widget.session.rol == 'Desarrollador Sr.';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final results = await Future.wait([
        widget.api.fetchProyectos(),
        widget.api.fetchUsuarios(),
      ]);
      if (mounted) {
        setState(() {
          _proyectos = results[0] as List<Proyecto>;
          _usuarios = results[1] as List<Usuario>;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _cargando = false; });
    }
  }

  Future<void> _abrirDialogo([Proyecto? editando]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _DialogoProyecto(
        proyecto: editando,
        usuarios: _usuarios,
        session: widget.session,
      ),
    );
    if (result == null) return;
    try {
      if (editando == null) {
        await widget.api.crearProyecto(result);
      } else {
        await widget.api.actualizarProyecto(editando.id, result);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      _cargar();
    }
  }

  Future<void> _eliminar(Proyecto p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar proyecto'),
        content: Text('¿Eliminar "${p.nombre}"? Esto borrará todas sus tareas.'),
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
    try {
      await widget.api.eliminarProyecto(p.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      _cargar();
    }
  }

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
            FilledButton.icon(onPressed: _cargar, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      floatingActionButton: _puedeEditar
          ? FloatingActionButton.extended(
              onPressed: () => _abrirDialogo(),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo proyecto'),
            )
          : null,
      body: _proyectos.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_open, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text('Sin proyectos', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                  if (_puedeEditar) ...[
                    const SizedBox(height: 8),
                    TextButton(onPressed: () => _abrirDialogo(), child: const Text('Crear el primero')),
                  ],
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                itemCount: _proyectos.length,
                itemBuilder: (ctx, i) => _TarjetaProyecto(
                  proyecto: _proyectos[i],
                  puedeEditar: _puedeEditar,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProyectoDetalleScreen(
                        proyecto: _proyectos[i],
                        api: widget.api,
                        session: widget.session,
                        usuarios: _usuarios,
                        onProyectoActualizado: _cargar,
                      ),
                    ),
                  ),
                  onEditar: () => _abrirDialogo(_proyectos[i]),
                  onEliminar: () => _eliminar(_proyectos[i]),
                ),
              ),
            ),
    );
  }
}

class _TarjetaProyecto extends StatelessWidget {
  final Proyecto proyecto;
  final bool puedeEditar;
  final VoidCallback onTap;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _TarjetaProyecto({
    required this.proyecto,
    required this.puedeEditar,
    required this.onTap,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    final progreso = proyecto.tareasTotal > 0
        ? proyecto.tareasHecho / proyecto.tareasTotal
        : 0.0;
    final estadoColor = switch (proyecto.estado) {
      'terminado' => Colors.green,
      'pausado' => Colors.orange,
      _ => const Color(0xFF1A2B72),
    };
    final hoy = DateTime.now();
    final diasRestantes = proyecto.fechaFin.difference(hoy).inDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(proyecto.nombre,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  Chip(
                    label: Text(proyecto.estado, style: const TextStyle(fontSize: 11, color: Colors.white)),
                    backgroundColor: estadoColor,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  if (puedeEditar) ...[
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      tooltip: 'Editar',
                      onPressed: onEditar,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                      tooltip: 'Eliminar',
                      onPressed: onEliminar,
                    ),
                  ],
                ],
              ),
              if (proyecto.descripcion.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(proyecto.descripcion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    '${_fmtDate(proyecto.fechaInicio)} → ${_fmtDate(proyecto.fechaFin)}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const Spacer(),
                  if (proyecto.estado != 'terminado')
                    Text(
                      diasRestantes >= 0
                          ? '$diasRestantes días restantes'
                          : '${diasRestantes.abs()} días vencido',
                      style: TextStyle(
                        fontSize: 12,
                        color: diasRestantes < 0
                            ? Colors.red
                            : diasRestantes < 7
                                ? Colors.orange
                                : Colors.grey[600],
                        fontWeight: diasRestantes < 0 ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                ],
              ),
              if (proyecto.responsableNombre != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person_outline, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(proyecto.responsableNombre!,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progreso,
                        minHeight: 6,
                        backgroundColor: Colors.grey[200],
                        color: progreso >= 1.0 ? Colors.green : const Color(0xFF1A2B72),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${proyecto.tareasHecho}/${proyecto.tareasTotal} tareas',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

// ── Diálogo crear/editar proyecto ───────────────────────────────────────────

class _DialogoProyecto extends StatefulWidget {
  final Proyecto? proyecto;
  final List<Usuario> usuarios;
  final Session session;

  const _DialogoProyecto({this.proyecto, required this.usuarios, required this.session});

  @override
  State<_DialogoProyecto> createState() => _DialogoProyectoState();
}

class _DialogoProyectoState extends State<_DialogoProyecto> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _descripcion;
  late DateTime _fechaInicio;
  late DateTime _fechaFin;
  String _estado = 'activo';
  String? _responsable;

  @override
  void initState() {
    super.initState();
    final p = widget.proyecto;
    _nombre = TextEditingController(text: p?.nombre ?? '');
    _descripcion = TextEditingController(text: p?.descripcion ?? '');
    _fechaInicio = p?.fechaInicio ?? DateTime.now();
    _fechaFin = p?.fechaFin ?? DateTime.now().add(const Duration(days: 30));
    _estado = p?.estado ?? 'activo';
    _responsable = p?.responsableUsername;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _pickFecha(bool isInicio) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isInicio ? _fechaInicio : _fechaFin,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null) return;
    setState(() {
      if (isInicio) {
        _fechaInicio = picked;
        if (_fechaFin.isBefore(_fechaInicio)) _fechaFin = _fechaInicio.add(const Duration(days: 1));
      } else {
        _fechaFin = picked;
      }
    });
  }

  void _guardar() {
    if (!_formKey.currentState!.validate()) return;
    if (!_fechaFin.isAfter(_fechaInicio)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La fecha fin debe ser posterior a la fecha inicio')),
      );
      return;
    }
    Navigator.pop(context, {
      'nombre': _nombre.text.trim(),
      'descripcion': _descripcion.text.trim(),
      'fechaInicio': _fechaInicio.toIso8601String().substring(0, 10),
      'fechaFin': _fechaFin.toIso8601String().substring(0, 10),
      'estado': _estado,
      if (_responsable != null) 'responsableUsername': _responsable,
    });
  }

  String _fmtDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final editando = widget.proyecto != null;
    return AlertDialog(
      title: Text(editando ? 'Editar proyecto' : 'Nuevo proyecto'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nombre,
                  decoration: const InputDecoration(labelText: 'Nombre del proyecto *'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descripcion,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickFecha(true),
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Fecha inicio', border: OutlineInputBorder()),
                          child: Text(_fmtDate(_fechaInicio)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickFecha(false),
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Fecha fin', border: OutlineInputBorder()),
                          child: Text(_fmtDate(_fechaFin)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _estado,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: const [
                    DropdownMenuItem(value: 'activo', child: Text('Activo')),
                    DropdownMenuItem(value: 'pausado', child: Text('Pausado')),
                    DropdownMenuItem(value: 'terminado', child: Text('Terminado')),
                  ],
                  onChanged: (v) => setState(() => _estado = v!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  value: _responsable,
                  decoration: const InputDecoration(labelText: 'Responsable'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Sin asignar')),
                    ...widget.usuarios.map((u) => DropdownMenuItem(
                          value: u.username,
                          child: Text(u.nombreCompleto),
                        )),
                  ],
                  onChanged: (v) => setState(() => _responsable = v),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _guardar, child: Text(editando ? 'Guardar' : 'Crear')),
      ],
    );
  }
}
