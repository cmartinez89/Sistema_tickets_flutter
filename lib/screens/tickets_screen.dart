import 'package:flutter/material.dart';
import '../models/ticket_model.dart';
import '../models/session_model.dart';
import '../services/api_service.dart';

class TicketsScreen extends StatefulWidget {
  final List<Ticket> tickets;
  final Session session;
  final ApiService api;
  final VoidCallback onRefresh;

  const TicketsScreen({super.key, required this.tickets, required this.session, required this.api, required this.onRefresh});

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
  bool _clearSession = false;

  final List<String> kTecnicos = const ['Sin Asignar', 'Carlos', 'Benjamin', 'Julio'];

  Color statusColor(String estado) {
    switch (estado) {
      case 'Pendiente': return Colors.red.shade700;
      case 'En Proceso': return Colors.orange.shade800;
      case 'Resuelto': return Colors.green.shade700;
      default: return Colors.grey;
    }
  }

  void _abrirDialogoEditar(Ticket t) {
    String nuevoEstado = t.estado;
    String nuevoAsignado = t.asignadoA;
    final causaCtrl = TextEditingController(text: t.causaRaiz ?? '');
    final resolverCtrl = TextEditingController(text: t.comoSeResolvio ?? '');
    final pruebasCtrl = TextEditingController(text: t.pruebasRealizadas ?? '');
    final validadoCtrl = TextEditingController(text: t.validadoCon ?? '');
    bool guardando = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          title: Text('${t.id} — ${t.usuario}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Depto: ${t.departamento}  •  Prioridad: ${t.prioridad}', style: const TextStyle(color: Colors.blueGrey, fontSize: 13)),
                  const SizedBox(height: 6),
                  Text(t.descripcion),
                  const Divider(height: 24),
                  DropdownButtonFormField<String>(
                    initialValue: nuevoEstado,
                    decoration: const InputDecoration(labelText: 'Estado', border: OutlineInputBorder()),
                    items: ['Pendiente', 'En Proceso', 'Resuelto'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setDs(() => nuevoEstado = v!),
                  ),
                  if (widget.session.rol == 'Admin') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: nuevoAsignado,
                      decoration: const InputDecoration(labelText: 'Técnico Responsable', border: OutlineInputBorder()),
                      items: kTecnicos.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (v) => setDs(() => nuevoAsignado = v!),
                    ),
                  ],
                  if (nuevoEstado == 'Resuelto') ...[
                    const Divider(height: 24),
                    const Text('Detalle de resolución', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 10),
                    TextFormField(controller: causaCtrl, decoration: const InputDecoration(labelText: 'Causa raíz', border: OutlineInputBorder()), maxLines: 2),
                    const SizedBox(height: 10),
                    TextFormField(controller: resolverCtrl, decoration: const InputDecoration(labelText: 'Cómo se resolvió', border: OutlineInputBorder()), maxLines: 2),
                    const SizedBox(height: 10),
                    TextFormField(controller: pruebasCtrl, decoration: const InputDecoration(labelText: 'Pruebas realizadas', border: OutlineInputBorder()), maxLines: 2),
                    const SizedBox(height: 10),
                    TextFormField(controller: validadoCtrl, decoration: const InputDecoration(labelText: 'Validado con', border: OutlineInputBorder())),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.primary, foregroundColor: Colors.white),
              onPressed: guardando ? null : () async {
                setDs(() => guardando = true);
                try {
                  if (nuevoEstado == 'Resuelto') {
                    await widget.api.resolverTicket(t.id,
                      causaRaiz: causaCtrl.text.trim(),
                      comoSeResolvio: resolverCtrl.text.trim(),
                      pruebasRealizadas: pruebasCtrl.text.trim(),
                      validadoCon: validadoCtrl.text.trim(),
                    );
                  } else if (nuevoEstado != t.estado) {
                    await widget.api.cambiarEstatusTicket(t.id, nuevoEstado);
                  }
                  if (nuevoAsignado != t.asignadoA) {
                    await widget.api.reasignarTicket(t.id, nuevoAsignado);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  widget.onRefresh();
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                } finally {
                  if (ctx.mounted) setDs(() => guardando = false);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _abrirDialogoNuevo() {
    _usuarioCtrl.clear(); _deptoCtrl.clear(); _descCtrl.clear(); _prioridad = 'Media'; _asignado = 'Sin Asignar'; _clearSession = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          title: const Text('Levantar Reporte Técnico', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(controller: _usuarioCtrl, decoration: const InputDecoration(labelText: 'Usuario Afectado', border: OutlineInputBorder()), validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null),
                    const SizedBox(height: 12),
                    TextFormField(controller: _deptoCtrl, decoration: const InputDecoration(labelText: 'Departamento', border: OutlineInputBorder()), validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(initialValue: _prioridad, decoration: const InputDecoration(labelText: 'Prioridad', border: OutlineInputBorder()), items: ['Baja', 'Media', 'Alta'].map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(), onChanged: (v) => setDs(() => _prioridad = v!)),
                    const SizedBox(height: 12),
                    if (widget.session.rol == 'Admin') DropdownButtonFormField<String>(initialValue: _asignado, decoration: const InputDecoration(labelText: 'Técnico Responsable', border: OutlineInputBorder()), items: kTecnicos.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(), onChanged: (v) => setDs(() => _asignado = v!)),
                    const SizedBox(height: 12),
                    TextFormField(controller: _descCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Descripción de la falla', border: OutlineInputBorder()), validator: (v) => (v == null || v.trim().isEmpty) ? 'Explique el problema' : null),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.primary, foregroundColor: Colors.white),
              onPressed: _clearSession ? null : () async {
                if (!_formKey.currentState!.validate()) return;
                setDs(() => _clearSession = true);
                final nuevo = Ticket(id: '', usuario: _usuarioCtrl.text.trim(), departamento: _deptoCtrl.text.trim(), descripcion: _descCtrl.text.trim(), prioridad: _prioridad, estado: 'Pendiente', asignadoA: widget.session.rol == 'Admin' ? _asignado : 'Sin Asignar', fecha: DateTime.now());
                try { 
                  await widget.api.crearTicket(nuevo); 
                  if (ctx.mounted) Navigator.pop(ctx); 
                  widget.onRefresh(); 
                } catch (e) { 
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'))); 
                } finally {
                  if (ctx.mounted) setDs(() => _clearSession = false);
                }
              },
              child: const Text('Registrar'),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Ticket> lista = widget.session.rol == 'Admin' ? widget.tickets : widget.tickets.where((t) => t.asignadoA.toLowerCase() == widget.session.username.toLowerCase()).toList();
    if (_filtro == 'Activos') lista = lista.where((t) => t.estado != 'Resuelto').toList();
    if (_filtro == 'Resueltos') lista = lista.where((t) => t.estado == 'Resuelto').toList();
    // 'Todos' muestra sin filtro adicional

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Consola Soporte (${lista.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                Row(
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'Activos', label: Text('Activos')),
                        ButtonSegment(value: 'Resueltos', label: Text('Resueltos')),
                        ButtonSegment(value: 'Todos', label: Text('Todos')),
                      ],
                      selected: {_filtro},
                      onSelectionChanged: (s) => setState(() => _filtro = s.first),
                      style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(onPressed: _abrirDialogoNuevo, icon: const Icon(Icons.add, size: 16), label: const Text('Nuevo')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: lista.length,
                itemBuilder: (_, i) {
                  final t = lista[i];
                  return Card(
                    child: ListTile(
                      onTap: () => _abrirDialogoEditar(t),
                      title: Text(t.descripcion),
                      subtitle: Text('${t.id} • ${t.usuario} — ${t.departamento} • Asignado: ${t.asignadoA}'),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor(t.estado).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8)
                        ),
                        child: Text(t.estado, style: TextStyle(color: statusColor(t.estado), fontWeight: FontWeight.bold)),
                      ),
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }
}