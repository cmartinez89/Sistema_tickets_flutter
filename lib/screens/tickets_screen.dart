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
  final String _filtro = 'Activos';
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

  void _abrirDialogoNuevo() {
    _usuarioCtrl.clear(); _deptoCtrl.clear(); _descCtrl.clear(); _prioridad = 'Media'; _asignado = 'Sin Asignar';
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
              style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
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
                  setDs(() => _clearSession = false); 
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

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Consola Soporte (${lista.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                ElevatedButton.icon(onPressed: _abrirDialogoNuevo, icon: const Icon(Icons.add, size: 16), label: const Text('Nuevo')),
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
                      title: Text(t.descripcion),
                      subtitle: Text('ID: ${t.id} • Asignado a: ${t.asignadoA}'),
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