import 'package:flutter/material.dart';
import '../models/equipo_model.dart';
import '../models/session_model.dart';
import '../services/api_service.dart';
import '../utils/print_helper.dart';
import 'dialogo_nuevo_equipo.dart';

Color colorParaEstatus(String estatus) {
  switch (estatus) {
    case 'Asignado':
      return Colors.green.shade700;
    case 'Disponible':
      return Colors.red.shade700;
    default:
      return Colors.amber.shade800;
  }
}

String resumenSpecs(Equipo eq) {
  final partes = <String>[];
  if (eq.cpuNucleos != null) partes.add('${eq.cpuNucleos} núcleos');
  if (eq.ramTotalGb != null) partes.add('${eq.ramTotalGb!.toStringAsFixed(1)} GB RAM');
  if (eq.discos != null && eq.discos!.isNotEmpty) {
    final totalGb = eq.discos!.fold<double>(0, (sum, d) => sum + (d.totalGb ?? 0));
    partes.add('${totalGb.toStringAsFixed(0)} GB disco');
  }
  if (partes.isEmpty) return 'Sin datos del agente';
  return partes.join(' • ');
}

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
  final _busquedaCtrl = TextEditingController();

  String? _filtroTipo;
  String? _filtroArea;
  String? _filtroEstatus;
  List<String> _tiposEquipo = ['Laptop', 'Desktop', 'Servidor', 'Celular', 'Bastón', 'Radio', 'Tablet'];
  List<String> _areasDisponibles = [];

  bool get _puedeGestionarActivos =>
      widget.session.rol == 'Admin' || widget.session.rol == 'Técnico Sr.';

  @override
  void initState() {
    super.initState();
    _busquedaCtrl.addListener(() => setState(() {}));
    _cargarTipos();
    _cargarAreas();
  }

  @override
  void dispose() {
    _empleadoCtrl.dispose();
    _puestoCtrl.dispose();
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarTipos() async {
    try {
      final tipos = await widget.api.fetchTiposEquipo();
      if (mounted) setState(() => _tiposEquipo = tipos.map((t) => t['nombre'] as String).toList());
    } catch (_) {}
  }

  Future<void> _cargarAreas() async {
    try {
      final areas = await widget.api.fetchAreas();
      if (mounted) {
        setState(() {
          _areasDisponibles = areas.map((a) => a['nombre'] as String).toList()..sort();
        });
      }
    } catch (_) {}
  }

  IconData _iconForTipo(String tipo) {
    switch (tipo) {
      case 'Laptop': return Icons.laptop_mac_rounded;
      case 'Servidor': return Icons.dns_rounded;
      case 'Celular': return Icons.phone_android_rounded;
      case 'Tablet': return Icons.tablet_android_rounded;
      case 'Bastón': return Icons.qr_code_scanner_rounded;
      case 'Radio': return Icons.radio_rounded;
      default: return Icons.computer_rounded;
    }
  }

  String _formatFechaStr(String? fechaStr) {
    if (fechaStr == null || fechaStr.isEmpty) return 'N/A';
    try {
      final d = DateTime.parse(fechaStr);
      return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
    } catch (_) { return fechaStr; }
  }

  String _formatFechaHora(DateTime fecha) {
    final d = fecha.toLocal();
    return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
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
        content: Text('El equipo quedará como "Disponible" y se desvinculará de "${eq.empleadoAsignado}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
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
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hardware liberado.')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF1A2B72)),
            SizedBox(width: 8),
            Text('Asignar Activo', style: TextStyle(fontWeight: FontWeight.bold)),
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
                  Text('${eq.marca} - ${eq.modelo}', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  if (eq.folioActivo != null)
                    Text('Activo: ${eq.folioActivo}', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant, fontSize: 12)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _empleadoCtrl,
                    decoration: const InputDecoration(labelText: 'Nombre del Empleado', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _puestoCtrl,
                    decoration: const InputDecoration(labelText: 'Puesto / Rol', border: OutlineInputBorder(), prefixIcon: Icon(Icons.work)),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 8),
                  Text('El folio de responsiva se generará automáticamente.', style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A2B72), foregroundColor: Colors.white),
            onPressed: () async {
              if (!_formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              try {
                final resultado = await widget.api.asignarEquipo(eq.id, empleado: _empleadoCtrl.text.trim(), rol: _puestoCtrl.text.trim());
                final folioGen = resultado['folioResponsiva']?.toString() ?? '';
                setState(() {
                  eq.estatus = 'Asignado';
                  eq.empleadoAsignado = _empleadoCtrl.text.trim();
                  eq.rolEmpleado = _puestoCtrl.text.trim();
                });
                widget.onRefresh();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(folioGen.isNotEmpty ? 'Equipo asignado. Folio: $folioGen' : 'Equipo asignado correctamente.')));
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
              }
            },
            child: const Text('Guardar Asignación'),
          ),
        ],
      ),
    );
  }

  void _venderHardware(Equipo eq) {
    final precioCtrl = TextEditingController();
    DateTime? fechaVenta;
    final formKeyVenta = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.sell_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('Registrar Venta', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Form(
            key: formKeyVenta,
            child: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${eq.marca} - ${eq.modelo}', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: precioCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Precio de Venta (MXN)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.attach_money)),
                    validator: (v) => (v == null || double.tryParse(v) == null) ? 'Ingresa un precio válido' : null,
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now(),
                      );
                      if (d != null) setDs(() => fechaVenta = d);
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Fecha de Venta', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
                      child: Text(
                        fechaVenta != null
                            ? '${fechaVenta!.day.toString().padLeft(2, '0')}/${fechaVenta!.month.toString().padLeft(2, '0')}/${fechaVenta!.year}'
                            : 'Seleccionar fecha',
                        style: TextStyle(color: fechaVenta != null ? Theme.of(ctx).colorScheme.onSurface : Theme.of(ctx).colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              onPressed: () async {
                if (!formKeyVenta.currentState!.validate()) return;
                if (fechaVenta == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Selecciona una fecha de venta')));
                  return;
                }
                Navigator.pop(ctx);
                try {
                  final fechaStr = '${fechaVenta!.year}-${fechaVenta!.month.toString().padLeft(2,'0')}-${fechaVenta!.day.toString().padLeft(2,'0')}';
                  await widget.api.venderEquipo(eq.id, double.parse(precioCtrl.text), fechaStr);
                  setState(() {
                    eq.estatus = 'Vendido';
                    eq.precioVenta = double.parse(precioCtrl.text);
                    eq.fechaVenta = fechaStr;
                  });
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Equipo registrado como vendido.')));
                } catch (e) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                }
              },
              child: const Text('Registrar Venta'),
            ),
          ],
        ),
      ),
    );
  }

  void _darDeBajaHardware(Equipo eq) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.remove_circle_outline_rounded, color: Colors.red),
          SizedBox(width: 8),
          Text('Dar de baja'),
        ]),
        content: Text('¿Dar de baja "${eq.marca} - ${eq.modelo}"?\nNo volverá a aparecer en el inventario.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.api.darDeBajaEquipo(eq.id);
                widget.onRefresh();
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Activo dado de baja.')),
                );
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                );
              }
            },
            child: const Text('Dar de baja'),
          ),
        ],
      ),
    );
  }

  void _imprimirResponsiva(Equipo eq) {
    final now = DateTime.now();
    final dia = now.day.toString().padLeft(2, '0');
    final mes = now.month.toString().padLeft(2, '0');
    final ano = now.year.toString();
    final macRow = (eq.macAddress != null && eq.macAddress!.isNotEmpty)
        ? '<tr><td>Dirección MAC</td><td>${eq.macAddress}</td></tr>'
        : '';
    final accesoriosStr = eq.accesorios.isEmpty ? 'Ninguno' : eq.accesorios;
    final anydeskStr = eq.anydesk.isEmpty ? 'N/A' : eq.anydesk;
    final areaStr = (eq.area?.isNotEmpty == true) ? eq.area! : eq.ubicacion;
    final folio = eq.folioResponsiva.isEmpty || eq.folioResponsiva == '---' ? 'N/A' : eq.folioResponsiva;
    final folioActivo = eq.folioActivo ?? 'N/A';
    final empleado = eq.empleadoAsignado ?? '';
    final rol = eq.rolEmpleado ?? '';

    final html = '''<!DOCTYPE html>
<html lang="es">
<head>
<meta charset="UTF-8">
<title>Carta Responsiva $folio</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: Arial, sans-serif; font-size: 12px; color: #333; padding: 40px; }
  h1 { text-align: center; font-size: 16px; margin-bottom: 5px; text-transform: uppercase; letter-spacing: 1px; }
  h2 { text-align: center; font-size: 13px; margin-bottom: 20px; color: #555; }
  .header-line { border-bottom: 2px solid #333; margin-bottom: 20px; padding-bottom: 10px; text-align: center; }
  .section { margin-bottom: 16px; }
  .section-title { font-weight: bold; font-size: 12px; text-transform: uppercase; border-bottom: 1px solid #ccc; margin-bottom: 8px; padding-bottom: 3px; color: #444; }
  table { width: 100%; border-collapse: collapse; margin-bottom: 12px; }
  td { padding: 5px 8px; border: 1px solid #ddd; font-size: 11px; }
  td:first-child { font-weight: bold; background: #f5f5f5; width: 35%; }
  .terms { font-size: 10px; color: #555; line-height: 1.6; margin: 16px 0; text-align: justify; }
  .signatures { display: flex; justify-content: space-around; margin-top: 60px; }
  .sig-box { text-align: center; width: 220px; }
  .sig-line { border-top: 1px solid #333; margin-bottom: 5px; padding-top: 0; }
  @media print { body { padding: 20px; } }
</style>
</head>
<body>
<div class="header-line">
  <h1>Carta Responsiva de Equipo de Cómputo</h1>
  <h2>Departamento de Sistemas — Beta</h2>
  <p>Folio: <strong>$folio</strong> &nbsp;|&nbsp; Activo: <strong>$folioActivo</strong> &nbsp;|&nbsp; Fecha: <strong>$dia/$mes/$ano</strong></p>
</div>
<div class="section">
  <div class="section-title">Datos del Empleado</div>
  <table>
    <tr><td>Nombre</td><td>$empleado</td></tr>
    <tr><td>Puesto / Rol</td><td>$rol</td></tr>
  </table>
</div>
<div class="section">
  <div class="section-title">Datos del Equipo</div>
  <table>
    <tr><td>Tipo</td><td>${eq.tipo}</td></tr>
    <tr><td>Marca</td><td>${eq.marca}</td></tr>
    <tr><td>Modelo</td><td>${eq.modelo}</td></tr>
    <tr><td>No. de Serie</td><td>${eq.noSerie}</td></tr>
    <tr><td>Especificaciones</td><td>${eq.specifications}</td></tr>
    <tr><td>Accesorios</td><td>$accesoriosStr</td></tr>
    $macRow
    <tr><td>AnyDesk ID</td><td>$anydeskStr</td></tr>
    <tr><td>Area / Ubicacion</td><td>$areaStr</td></tr>
  </table>
</div>
<div class="terms">
  <strong>TERMINOS Y CONDICIONES:</strong><br/>
  El suscrito empleado de la empresa, recibe en este acto el equipo de computo descrito anteriormente, comprometiendose a:
  <ol style="margin-left:20px; margin-top:5px;">
    <li>Utilizar el equipo exclusivamente para actividades laborales relacionadas con su puesto.</li>
    <li>Mantener el equipo en buenas condiciones, reportando cualquier dano o falla al Departamento de Sistemas.</li>
    <li>No instalar software no autorizado ni realizar modificaciones al hardware sin previa autorizacion.</li>
    <li>Entregar el equipo al momento de su renuncia, cambio de puesto o cuando el Departamento de Sistemas lo solicite.</li>
    <li>Responder economicamente por perdida, robo (por negligencia) o dano intencional al equipo.</li>
  </ol>
</div>
<div class="signatures">
  <div class="sig-box">
    <div style="height:50px;"></div>
    <div class="sig-line"></div>
    <p><strong>$empleado</strong></p>
    <p style="font-size:10px; color:#666;">Firma del Responsable</p>
  </div>
  <div class="sig-box">
    <div style="height:50px;"></div>
    <div class="sig-line"></div>
    <p><strong>Departamento de Sistemas</strong></p>
    <p style="font-size:10px; color:#666;">Sello y Firma Autorizante</p>
  </div>
</div>
<script>window.onload = function(){ window.print(); }</script>
</body>
</html>''';

    printHtml(html);
  }

  @override
  Widget build(BuildContext context) {
    List<Equipo> lista = widget.inventario.where((e) => e.estatus != 'Baja').toList();

    final busq = _busquedaCtrl.text.toLowerCase();
    if (busq.isNotEmpty) {
      lista = lista.where((e) =>
        e.marca.toLowerCase().contains(busq) ||
        e.modelo.toLowerCase().contains(busq) ||
        e.noSerie.toLowerCase().contains(busq) ||
        (e.empleadoAsignado?.toLowerCase().contains(busq) ?? false) ||
        (e.folioActivo?.toLowerCase().contains(busq) ?? false)
      ).toList();
    }
    if (_filtroTipo != null) lista = lista.where((e) => e.tipo == _filtroTipo).toList();
    if (_filtroArea != null) lista = lista.where((e) => (e.area ?? e.ubicacion) == _filtroArea).toList();
    if (_filtroEstatus != null) lista = lista.where((e) => e.estatus == _filtroEstatus).toList();

    final uniqueTipos = widget.inventario.map((e) => e.tipo).toSet().toList()..sort();
    final uniqueAreas = widget.inventario.map((e) => e.area ?? e.ubicacion).where((a) => a.isNotEmpty).toSet().toList()..sort();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
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
                      Text('Control de Activos y Cartas Responsivas',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      Text('${lista.length} de ${widget.inventario.length} equipos',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
                if (_puedeGestionarActivos)
                  ElevatedButton.icon(
                    onPressed: () => abrirDialogoNuevoEquipo(
                      context: context,
                      api: widget.api,
                      onRefresh: widget.onRefresh,
                      tiposDisponibles: _tiposEquipo,
                      areas: _areasDisponibles,
                    ),
                    icon: const Icon(Icons.computer_rounded, size: 16),
                    label: const Text('Alta Equipo'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A2B72), foregroundColor: Colors.white),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Search + filters
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 40,
                  child: TextField(
                    controller: _busquedaCtrl,
                    decoration: InputDecoration(
                      hintText: 'Buscar equipo...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      suffixIcon: busq.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () { _busquedaCtrl.clear(); setState(() {}); })
                          : null,
                    ),
                  ),
                ),
                _filterDropdown<String>(
                  hint: 'Tipo',
                  value: _filtroTipo,
                  items: uniqueTipos,
                  onChanged: (v) => setState(() => _filtroTipo = v),
                ),
                _filterDropdown<String>(
                  hint: 'Área',
                  value: _filtroArea,
                  items: uniqueAreas,
                  onChanged: (v) => setState(() => _filtroArea = v),
                ),
                _filterDropdown<String>(
                  hint: 'Estatus',
                  value: _filtroEstatus,
                  items: const ['Disponible', 'Asignado', 'Vendido', 'Fuera de Servicio'],
                  onChanged: (v) => setState(() => _filtroEstatus = v),
                ),
                if (_filtroTipo != null || _filtroArea != null || _filtroEstatus != null)
                  TextButton.icon(
                    onPressed: () => setState(() { _filtroTipo = null; _filtroArea = null; _filtroEstatus = null; }),
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('Limpiar', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: lista.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.devices_other_rounded, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(height: 8),
                      Text('Sin resultados', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    ]))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 320,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: 150,
                      ),
                      itemCount: lista.length,
                      itemBuilder: (_, i) => _tarjetaEquipo(lista[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaEquipo(Equipo eq) {
    final color = colorParaEstatus(eq.estatus);
    final titulo = eq.empleadoAsignado ?? eq.estatus;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () => _mostrarDetalle(eq),
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(_iconForTipo(eq.tipo), color: color, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('${eq.marca} - ${eq.modelo}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              if (eq.hostname != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Hostname: ${eq.hostname}${eq.rustdesk.isNotEmpty ? ' · RustDesk: ${eq.rustdesk}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                resumenSpecs(eq),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: eq.hostname == null ? FontStyle.italic : FontStyle.normal,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterDropdown<T>({
    required String hint,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          hint: Text(hint, style: const TextStyle(fontSize: 13)),
          value: value,
          isDense: true,
          items: [
            DropdownMenuItem<T>(value: null, child: Text('Todos ($hint)', style: const TextStyle(fontSize: 13))),
            ...items.map((item) => DropdownMenuItem<T>(value: item, child: Text(item.toString(), style: const TextStyle(fontSize: 13)))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
