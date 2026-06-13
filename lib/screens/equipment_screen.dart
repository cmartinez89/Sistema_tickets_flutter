import 'package:flutter/material.dart';
import '../models/equipo_model.dart';
import '../models/session_model.dart';
import '../services/api_service.dart';
import 'dialogo_nuevo_equipo.dart';

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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hardware liberado.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                  );
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Activo asignado.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                  );
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
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
                        '${widget.inventario.length} equipos registrados',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (widget.session.rol == 'Admin')
                  ElevatedButton.icon(
                    onPressed: () => abrirDialogoNuevoEquipo(
                      context: context,
                      api: widget.api,
                      onRefresh: widget.onRefresh,
                    ),
                    icon: const Icon(Icons.computer_rounded, size: 16),
                    label: const Text('Alta Equipo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00695C),
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
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
                                            foregroundColor: Colors.red.shade800,
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
                                            backgroundColor: Colors.teal.shade50,
                                            foregroundColor: Colors.teal.shade800,
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