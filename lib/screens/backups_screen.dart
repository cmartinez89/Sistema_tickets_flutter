import 'package:flutter/material.dart';
import '../models/equipo_model.dart';
import '../models/session_model.dart';
import '../services/api_service.dart';
import 'dialogo_nuevo_equipo.dart';

class PantallaRespaldos extends StatefulWidget {
  final List<Equipo> inventario;
  final ApiService api;
  final VoidCallback onRefresh;
  final Session session;

  const PantallaRespaldos({
    super.key,
    required this.inventario,
    required this.api,
    required this.onRefresh,
    required this.session,
  });

  @override
  State<PantallaRespaldos> createState() => _PantallaRespaldosState();
}

class _PantallaRespaldosState extends State<PantallaRespaldos> {
  String _filtroAlerta = 'Todos';
  String? _filtroArea;

  static const _alertas = ['Todos', 'Sin respaldo', 'Al día', 'Atrasado', 'Crítico'];

  List<String> get _areas {
    final set = <String>{};
    for (final eq in widget.inventario) {
      final a = (eq.area?.isNotEmpty == true ? eq.area! : eq.ubicacion);
      if (a.isNotEmpty) set.add(a);
    }
    return ['Todas', ...set.toList()..sort()];
  }

  List<Equipo> get _inventarioFiltrado {
    return widget.inventario.where((eq) {
      // Filtro área
      if (_filtroArea != null && _filtroArea != 'Todas') {
        final areaEq = eq.area?.isNotEmpty == true ? eq.area! : eq.ubicacion;
        if (areaEq != _filtroArea) return false;
      }
      // Filtro alerta
      if (_filtroAlerta != 'Todos') {
        final dias = eq.diasUltimoRespaldo;
        switch (_filtroAlerta) {
          case 'Sin respaldo':
            if (eq.ultimoRespaldo != null) return false;
          case 'Al día':
            if (dias == null || dias >= 7) return false;
          case 'Atrasado':
            if (dias == null || dias < 7 || dias >= 15) return false;
          case 'Crítico':
            if (dias == null || dias < 15) return false;
        }
      }
      return true;
    }).toList();
  }

  Future<void> _actualizar(Equipo eq, DateTime fecha) async {
    try {
      await widget.api.actualizarRespaldo(eq.id, fecha);
      setState(() => eq.ultimoRespaldo = fecha);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Respaldo sincronizado.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  String _fmt(DateTime? f) {
    if (f == null) return 'Sin respaldo';
    return '${f.day.toString().padLeft(2, '0')}/${f.month.toString().padLeft(2, '0')}/${f.year}';
  }

  Widget _badgeDias(int? dias, Color backgroundColor, Color textoColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        dias?.toString() ?? '---',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: textoColor),
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
            // Encabezado adaptivo para evitar que el botón rompa el diseño en pantallas chicas
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Column(
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
                  ],
                ),
                if (widget.session.rol == 'Admin')
                  ElevatedButton.icon(
                    onPressed: () => abrirDialogoNuevoEquipo(
                      context: context,
                      api: widget.api,
                      onRefresh: widget.onRefresh,
                    ),
                    icon: const Icon(Icons.add_to_photos_rounded, size: 16),
                    label: const Text('Alta Equipo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A2B72),
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // ── Filtros ──────────────────────────────────────────────────────
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 160,
                  child: DropdownButtonFormField<String>(
                    value: _filtroAlerta,
                    isDense: true,
                    decoration: InputDecoration(
                      labelText: 'Estado',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: _alertas.map((a) => DropdownMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (v) => setState(() => _filtroAlerta = v!),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: DropdownButtonFormField<String>(
                    value: _filtroArea ?? 'Todas',
                    isDense: true,
                    decoration: InputDecoration(
                      labelText: 'Área',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: _areas.map((a) => DropdownMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (v) => setState(() => _filtroArea = v == 'Todas' ? null : v),
                  ),
                ),
                if (_filtroAlerta != 'Todos' || (_filtroArea != null && _filtroArea != 'Todas'))
                  TextButton.icon(
                    onPressed: () => setState(() { _filtroAlerta = 'Todos'; _filtroArea = null; }),
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Limpiar', style: TextStyle(fontSize: 13)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // DETERMINACIÓN DE COLORES PARA LAS ALERTAS DE DÍAS
                  Color obtenerFondoDias(int? dias) {
                    if (dias == null) return Colors.transparent;
                    if (dias >= 15) return Colors.red.shade100;
                    if (dias >= 7) return Colors.amber.shade100;
                    return Colors.green.shade100;
                  }

                  Color obtenerTextoDias(int? dias) {
                    if (dias == null) return Colors.black87;
                    if (dias >= 15) return Colors.red.shade900;
                    if (dias >= 7) return Colors.amber.shade900;
                    return Colors.green.shade900;
                  }

                  // VISTA MOVIL (TARJETAS ESPACIADAS EN VENTANAS CHICAS)
                  final lista = _inventarioFiltrado;
                  if (constraints.maxWidth < 750) {
                    if (lista.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey.shade300),
                            const SizedBox(height: 12),
                            Text('Sin resultados', style: TextStyle(color: Colors.grey.shade400)),
                          ],
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: lista.length,
                      itemBuilder: (context, index) {
                        final eq = lista[index];
                        final dias = eq.diasUltimoRespaldo;

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      eq.empleadoAsignado ?? 'Sistemas (Stock)',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(eq.ubicacion, style: const TextStyle(fontSize: 11)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text('Modelo: ${eq.modelo}', style: const TextStyle(fontSize: 13)),
                                const Divider(height: 20),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Último Respaldo:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                        Row(
                                          children: [
                                            Text(_fmt(eq.ultimoRespaldo), style: const TextStyle(fontWeight: FontWeight.w500)),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              icon: const Icon(Icons.cloud_upload_rounded, size: 20, color: Color(0xFF0D47A1)),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () async {
                                                final picked = await showDatePicker(
                                                  context: context,
                                                  initialDate: eq.ultimoRespaldo ?? DateTime.now(),
                                                  firstDate: DateTime(2020),
                                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                                );
                                                if (picked != null) _actualizar(eq, picked);
                                              },
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text('Días:', style: TextStyle(fontSize: 11, color: Colors.grey)),
                                        const SizedBox(height: 4),
                                        _badgeDias(dias, obtenerFondoDias(dias), obtenerTextoDias(dias)),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }

                  // VISTA ESCRITORIO (TABLA TRADICIONAL COMPLETA EN PC)
                  return Card(
                    elevation: 2,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Container(
                          constraints: BoxConstraints(
                            minWidth: constraints.maxWidth,
                          ),
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(Colors.grey.shade200),
                            columnSpacing: 24,
                            columns: const [
                              DataColumn(label: Text('Ubicación', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Nombre / Resguardo', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Modelo', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Último respaldo', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Días', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: lista.map((eq) {
                              final dias = eq.diasUltimoRespaldo;

                              return DataRow(
                                cells: [
                                  DataCell(Text(eq.ubicacion)),
                                  DataCell(Text(eq.empleadoAsignado ?? 'Sistemas (Stock)')),
                                  DataCell(Text(eq.modelo)),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(_fmt(eq.ultimoRespaldo)),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.cloud_upload_rounded, size: 18, color: Color(0xFF0D47A1)),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          tooltip: 'Actualizar respaldo',
                                          onPressed: () async {
                                            final picked = await showDatePicker(
                                              context: context,
                                              initialDate: eq.ultimoRespaldo ?? DateTime.now(),
                                              firstDate: DateTime(2020),
                                              lastDate: DateTime.now().add(const Duration(days: 365)),
                                            );
                                            if (picked != null) _actualizar(eq, picked);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    _badgeDias(dias, obtenerFondoDias(dias), obtenerTextoDias(dias)),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
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