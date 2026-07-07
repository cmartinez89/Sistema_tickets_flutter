import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ReportesScreen extends StatefulWidget {
  final ApiService api;
  const ReportesScreen({super.key, required this.api});

  @override
  State<ReportesScreen> createState() => _ReportesScreenState();
}

class _ReportesScreenState extends State<ReportesScreen> {
  Map<String, dynamic>? _datos;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (!mounted) return;
    setState(() { _cargando = true; _error = null; });
    try {
      final datos = await widget.api.fetchReportes();
      if (mounted) setState(() { _datos = datos; _cargando = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _cargando = false; });
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  int _int(dynamic v) => (v as num?)?.toInt() ?? 0;
  double _dbl(dynamic v) => (v as num?)?.toDouble() ?? 0.0;

  Map<String, int> _toIntMap(dynamic raw) {
    if (raw == null) return {};
    return (raw as Map).map((k, v) => MapEntry(k.toString(), _int(v)));
  }

  List<Map<String, dynamic>> _toList(dynamic raw) {
    if (raw == null) return [];
    return (raw as List).cast<Map<String, dynamic>>();
  }

  Color _estadoColor(String estado) => switch (estado) {
    'Pendiente'  => Colors.red.shade600,
    'En Proceso' => Colors.orange.shade700,
    'Resuelto'   => Colors.green.shade600,
    'Escalado'   => Colors.purple.shade600,
    _            => Colors.blueGrey.shade400,
  };

  Color _prioColor(String p) => switch (p) {
    'Alta'  => Colors.red.shade600,
    'Media' => Colors.amber.shade700,
    'Baja'  => Colors.green.shade600,
    _       => Colors.grey,
  };

  // ── Bar chart widget ────────────────────────────────────────────────────────

  Widget _barraHorizontal(String label, int value, int maxValue, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Stack(
                children: [
                  Container(height: 20, color: colorScheme.surfaceContainerHighest),
                  FractionallySizedBox(
                    widthFactor: maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0,
                    child: Container(
                      height: 20,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 30,
            child: Text(
              '$value',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // ── Section card ────────────────────────────────────────────────────────────

  Widget _seccion(String titulo, IconData icono, Color color, Widget child) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icono, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Text(titulo, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  // ── Summary card ────────────────────────────────────────────────────────────

  Widget _cardResumen(String titulo, String valor, String subtitulo, Color color, IconData icono) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(height: 4, color: color),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(icono, color: color, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titulo, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                        Text(valor, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
                        Text(subtitulo, style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: const Text('Reportes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Actualizar',
            onPressed: _cargar,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final colorScheme = Theme.of(context).colorScheme;
    if (_cargando) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Cargando reportes...', style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ],
      ));
    }

    if (_error != null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
          const SizedBox(height: 12),
          const Text('Error al cargar reportes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text(_error!, style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _cargar,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ]),
      );
    }

    final d = _datos!;
    final porEstado     = _toIntMap(d['porEstado']);
    final porPrioridad  = _toIntMap(d['porPrioridad']);
    final porTecnico    = _toList(d['porTecnico']);
    final porArea       = _toList(d['porArea']);
    final porCategoria  = _toList(d['porCategoria']);
    final porMes        = _toList(d['porMes']);
    final eqTipo        = _toList(d['equiposPorTipo']);
    final eqEstatus     = _toIntMap(d['equiposPorEstatus']);
    final totalTickets  = _int(d['totalTickets']);
    final totalEquipos  = _int(d['totalEquipos']);
    final promedio      = _dbl(d['promedioResolucionHoras']);
    final activos       = (_int(porEstado['Pendiente']) + _int(porEstado['En Proceso']));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Resumen cards ──────────────────────────────────────────────────
          LayoutBuilder(builder: (_, constraints) {
            final isWide = constraints.maxWidth >= 700;
            final cardW = isWide ? (constraints.maxWidth - 48) / 4 : (constraints.maxWidth - 12) / 2;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(width: cardW, child: _cardResumen('Total Tickets', '$totalTickets', 'registrados', Colors.blue.shade700, Icons.confirmation_number_rounded)),
                SizedBox(width: cardW, child: _cardResumen('Tickets Activos', '$activos', 'sin resolver', Colors.red.shade600, Icons.hourglass_top_rounded)),
                SizedBox(width: cardW, child: _cardResumen('Equipos', '$totalEquipos', 'en inventario', const Color(0xFF1A2B72), Icons.devices_rounded)),
                SizedBox(width: cardW, child: _cardResumen('Prom. Resolución', '${promedio.toStringAsFixed(1)}h', 'tiempo de cierre', Colors.orange.shade700, Icons.timer_rounded)),
              ],
            );
          }),
          const SizedBox(height: 16),

          // ── Tickets por Estado ────────────────────────────────────────────
          _seccion('Tickets por Estado', Icons.pie_chart_rounded, Colors.indigo, () {
            if (porEstado.isEmpty) return Text('Sin datos', style: TextStyle(color: colorScheme.onSurfaceVariant));
            final max = porEstado.values.fold(0, (a, b) => a > b ? a : b);
            return Column(
              children: porEstado.entries.map((e) => _barraHorizontal(e.key, e.value, max, _estadoColor(e.key))).toList(),
            );
          }()),

          // ── Tickets por Prioridad ─────────────────────────────────────────
          _seccion('Tickets por Prioridad', Icons.priority_high_rounded, Colors.deepOrange, () {
            if (porPrioridad.isEmpty) return Text('Sin datos', style: TextStyle(color: colorScheme.onSurfaceVariant));
            final max = porPrioridad.values.fold(0, (a, b) => a > b ? a : b);
            return Column(
              children: porPrioridad.entries.map((e) => _barraHorizontal(e.key, e.value, max, _prioColor(e.key))).toList(),
            );
          }()),

          // ── Tickets por Técnico ───────────────────────────────────────────
          _seccion('Tickets por Técnico', Icons.person_rounded, Colors.purple, () {
            if (porTecnico.isEmpty) return Text('Sin datos', style: TextStyle(color: colorScheme.onSurfaceVariant));
            final top = porTecnico.take(8).toList();
            final max = top.fold(0, (a, b) => a > _int(b['total']) ? a : _int(b['total']));
            return Column(
              children: top.map((e) => _barraHorizontal(
                e['tecnico']?.toString() ?? 'Sin asignar',
                _int(e['total']),
                max,
                Colors.purple.shade500,
              )).toList(),
            );
          }()),

          // ── Tickets por Área ──────────────────────────────────────────────
          _seccion('Tickets por Área', Icons.business_rounded, const Color(0xFF1A2B72), () {
            if (porArea.isEmpty) return Text('Sin datos', style: TextStyle(color: colorScheme.onSurfaceVariant));
            final top = porArea.take(8).toList();
            final max = top.fold(0, (a, b) => a > _int(b['total']) ? a : _int(b['total']));
            return Column(
              children: top.map((e) => _barraHorizontal(
                e['area']?.toString() ?? 'Sin área',
                _int(e['total']),
                max,
                const Color(0xFF1A2B72),
              )).toList(),
            );
          }()),

          // ── Tickets por Categoría ─────────────────────────────────────────
          _seccion('Tickets por Categoría', Icons.category_rounded, Colors.blueGrey, () {
            if (porCategoria.isEmpty) return Text('Sin datos', style: TextStyle(color: colorScheme.onSurfaceVariant));
            final top = porCategoria.take(8).toList();
            final max = top.fold(0, (a, b) => a > _int(b['total']) ? a : _int(b['total']));
            return Column(
              children: top.map((e) => _barraHorizontal(
                e['categoria']?.toString() ?? 'Sin categoría',
                _int(e['total']),
                max,
                Colors.blueGrey.shade500,
              )).toList(),
            );
          }()),

          // ── Tickets por Mes ───────────────────────────────────────────────
          _seccion('Tickets por Mes (últimos 6)', Icons.calendar_month_rounded, Colors.blue, () {
            if (porMes.isEmpty) return Text('Sin datos', style: TextStyle(color: colorScheme.onSurfaceVariant));
            final max = porMes.fold(0, (a, b) => a > _int(b['total']) ? a : _int(b['total']));
            return SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: porMes.map((e) {
                  final total = _int(e['total']);
                  final heightFactor = max > 0 ? total / max : 0.0;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text('$total', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                          const SizedBox(height: 2),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            height: 80 * heightFactor,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade400,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            e['mes']?.toString().substring(5) ?? '',
                            style: TextStyle(fontSize: 9, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          }()),

          // ── Equipos por Tipo ──────────────────────────────────────────────
          _seccion('Equipos por Tipo', Icons.computer_rounded, const Color(0xFF1A2B72), () {
            if (eqTipo.isEmpty) return Text('Sin datos', style: TextStyle(color: colorScheme.onSurfaceVariant));
            final max = eqTipo.fold(0, (a, b) => a > _int(b['total']) ? a : _int(b['total']));
            return Column(
              children: eqTipo.map((e) => _barraHorizontal(
                e['tipo']?.toString() ?? 'Otro',
                _int(e['total']),
                max,
                const Color(0xFF1565C0),
              )).toList(),
            );
          }()),

          // ── Equipos por Estatus ───────────────────────────────────────────
          _seccion('Equipos por Estatus', Icons.inventory_2_rounded, Colors.indigo, () {
            if (eqEstatus.isEmpty) return Text('Sin datos', style: TextStyle(color: colorScheme.onSurfaceVariant));
            Color estatusColor(String s) => switch (s) {
              'Asignado'   => Colors.indigo.shade600,
              'Disponible' => Colors.blue.shade700,
              'Vendido'    => Colors.grey.shade600,
              _            => Colors.amber.shade700,
            };
            return Wrap(
              spacing: 10,
              runSpacing: 8,
              children: eqEstatus.entries.map((e) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: estatusColor(e.key).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: estatusColor(e.key).withValues(alpha: 0.3)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(e.key, style: TextStyle(fontSize: 12, color: estatusColor(e.key), fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: estatusColor(e.key), borderRadius: BorderRadius.circular(10)),
                    child: Text('${e.value}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ]),
              )).toList(),
            );
          }()),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
