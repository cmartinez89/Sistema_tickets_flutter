import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/ticket_model.dart';
import '../models/session_model.dart';
import '../models/usuario_model.dart';
import '../services/api_service.dart';

Future<String?> _pickImageBase64() async {
  try {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 1024);
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  } catch (_) {
    return null;
  }
}

class TicketsScreen extends StatefulWidget {
  final List<Ticket> tickets;
  final List<Usuario> usuarios;
  final Session session;
  final ApiService api;
  final VoidCallback onRefresh;

  const TicketsScreen({
    super.key,
    required this.tickets,
    required this.usuarios,
    required this.session,
    required this.api,
    required this.onRefresh,
  });

  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _prioridad = 'Media';
  String _asignado = 'Sin Asignar';
  String _filtro = 'Activos';
  String? _filtroArea;
  String? _filtroPrioridad;
  bool _clearSession = false;
  String? _nuevaCategoria;
  String? _nuevaArea;

  List<Map<String, dynamic>> _categorias = [];
  List<Map<String, dynamic>> _areas = [];
  final _busquedaCtrl = TextEditingController();
  DateTime? _desde;
  DateTime? _hasta;

  @override
  void initState() {
    super.initState();
    _cargarCatalogos();
  }

  Future<void> _cargarCatalogos() async {
    try {
      final results = await Future.wait([
        widget.api.fetchCategorias(),
        widget.api.fetchAreas(),
      ]);
      if (mounted) {
        setState(() {
          _categorias = results[0];
          _areas = results[1];
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _usuarioCtrl.dispose();
    _descCtrl.dispose();
    _busquedaCtrl.dispose();
    super.dispose();
  }

  bool get _tieneAccesoTotal =>
      widget.session.rol == 'Admin' || widget.session.rol == 'Técnico Sr.';

  List<String> get _kTecnicos =>
      ['Sin Asignar', ...widget.usuarios.map((u) => u.username)];

  List<String> _estadosSiguientes(String actual) {
    switch (actual) {
      case 'Pendiente':
        return ['Pendiente', 'En Proceso', 'Escalado', 'Resuelto'];
      case 'En Proceso':
        return ['En Proceso', 'Escalado', 'Resuelto'];
      case 'Escalado':
        return ['Escalado', 'Resuelto'];
      default:
        return [actual];
    }
  }

  String _nombreTecnico(String username) {
    if (username == 'Sin Asignar') return 'Sin Asignar';
    final u =
        widget.usuarios.where((u) => u.username == username).firstOrNull;
    return u?.nombreCompleto ?? username;
  }

  Color statusColor(String estado) {
    switch (estado) {
      case 'Pendiente':
        return Colors.red.shade700;
      case 'En Proceso':
        return Colors.orange.shade800;
      case 'Resuelto':
        return Colors.green.shade700;
      case 'Escalado':
        return Colors.purple.shade700;
      default:
        return Colors.grey;
    }
  }

  Color _prioColor(String p) {
    switch (p) {
      case 'Alta':
        return Colors.red.shade700;
      case 'Media':
        return Colors.orange.shade700;
      case 'Baja':
        return Colors.green.shade600;
      default:
        return Colors.grey;
    }
  }

  String _formatFecha(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')} '
        '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuracion(Duration d) {
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours.remainder(24)}h';
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes}m';
  }

  String _tiempoDesde(DateTime fecha) {
    final diff = DateTime.now().difference(fecha);
    return _formatDuracion(diff);
  }

  void _abrirDialogoEditar(Ticket t) {
    String nuevoEstado = t.estado;
    String nuevoAsignado = t.asignadoA.isEmpty ? 'Sin Asignar' : t.asignadoA;
    String tipoTicket = t.tipoTicket ?? 'Incidencia';
    final causaCtrl = TextEditingController(text: t.causaRaiz ?? '');
    final resolverCtrl = TextEditingController(text: t.comoSeResolvio ?? '');
    final pruebasCtrl =
        TextEditingController(text: t.pruebasRealizadas ?? '');
    final validadoCtrl = TextEditingController(text: t.validadoCon ?? '');
    final escaladoACtrl = TextEditingController(text: t.escaladoA ?? '');
    final motivoEscaladoCtrl =
        TextEditingController(text: t.motivoEscalado ?? '');
    String? imagenBase64;
    String tipoMantenimiento = 'Preventivo';
    final queCorrigioCtrl = TextEditingController();
    List<String> imagenesMantenimiento = [];
    bool guardando = false;
    List<Map<String, dynamic>> historial = [];
    bool loadingHistorial = true;
    String? aiSugerencia;
    bool cargandoAi = false;
    List<Map<String, dynamic>> comentarios = [];
    bool loadingComentarios = true;
    bool enviandoComentario = false;
    final comentarioCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) {
          // Load historial once
          if (loadingHistorial) {
            widget.api.fetchHistorial(t.id).then((h) {
              if (ctx.mounted) setDs(() { historial = h; loadingHistorial = false; });
            }).catchError((_) {
              if (ctx.mounted) setDs(() => loadingHistorial = false);
            });
          }
          if (loadingComentarios) {
            widget.api.fetchComentarios(t.id).then((c) {
              if (ctx.mounted) setDs(() { comentarios = c; loadingComentarios = false; });
            }).catchError((_) {
              if (ctx.mounted) setDs(() => loadingComentarios = false);
            });
          }

          Future<void> enviarComentario() async {
            final texto = comentarioCtrl.text.trim();
            if (texto.isEmpty) return;
            setDs(() => enviandoComentario = true);
            try {
              await widget.api.agregarComentario(t.id, texto);
              comentarioCtrl.clear();
              final nuevos = await widget.api.fetchComentarios(t.id);
              if (ctx.mounted) {
                setDs(() { comentarios = nuevos; enviandoComentario = false; });
              }
            } catch (e) {
              if (ctx.mounted) setDs(() => enviandoComentario = false);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')));
              }
            }
          }

          Future<void> pedirSugerenciaAi() async {
            setDs(() => cargandoAi = true);
            try {
              final s = await widget.api.fetchAiSugerencia(t.id);
              if (ctx.mounted) setDs(() { aiSugerencia = s; cargandoAi = false; });
            } catch (e) {
              if (ctx.mounted) setDs(() { aiSugerencia = 'Error: $e'; cargandoAi = false; });
            }
          }

          return AlertDialog(
            title: Text(
              '${t.id} — ${t.usuario}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 460,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Depto: ${t.departamento}  •  Prioridad: ${t.prioridad}  •  Creado: ${_formatFecha(t.fecha)}',
                      style:
                          TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant, fontSize: 12),
                    ),
                    if (t.categoria != null)
                      Text('Categoría: ${t.categoria}',
                          style: TextStyle(
                              color: Theme.of(ctx).colorScheme.onSurfaceVariant, fontSize: 12)),
                    const SizedBox(height: 6),
                    Text(t.descripcion),
                    if (t.estado == 'Escalado' &&
                        t.escaladoA != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border:
                              Border.all(color: Colors.purple.shade200),
                        ),
                        child: Text(
                          'Escalado a: ${t.escaladoA}\nMotivo: ${t.motivoEscalado ?? "—"}',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.purple.shade800),
                        ),
                      ),
                    ],

                    // Sugerencia IA
                    if (t.estado != 'Resuelto') ...[
                      const SizedBox(height: 10),
                      if (aiSugerencia == null && !cargandoAi)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: pedirSugerenciaAi,
                            icon: const Icon(Icons.smart_toy_rounded, size: 16),
                            label: const Text('Sugerencia IA'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.deepPurple,
                              side: BorderSide(color: Colors.deepPurple.shade200),
                            ),
                          ),
                        )
                      else if (cargandoAi)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 10),
                            Text('Consultando IA...', style: TextStyle(fontSize: 12, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                          ]),
                        )
                      else if (aiSugerencia != null)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.deepPurple.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.deepPurple.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.smart_toy_rounded, size: 14, color: Colors.deepPurple.shade600),
                                  const SizedBox(width: 6),
                                  Text('Sugerencia IA',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.deepPurple.shade700)),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () => setDs(() => aiSugerencia = null),
                                    child: Icon(Icons.close, size: 14, color: Colors.deepPurple.shade400),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              SelectableText(
                                aiSugerencia!,
                                style: TextStyle(fontSize: 12, color: Colors.deepPurple.shade900),
                              ),
                            ],
                          ),
                        ),
                    ],

                    const Divider(height: 24),

                    // Historial timing
                    if (!loadingHistorial && historial.isNotEmpty) ...[
                      const Text(
                        'Tiempo en cada estado',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      ...List.generate(historial.length, (i) {
                        final h = historial[i];
                        final desde = DateTime.tryParse(
                                h['fecha']?.toString() ?? '') ??
                            DateTime.now();
                        final hasta = i + 1 < historial.length
                            ? DateTime.tryParse(
                                    historial[i + 1]['fecha']
                                            ?.toString() ??
                                        '') ??
                                DateTime.now()
                            : DateTime.now();
                        final dur = hasta.difference(desde);
                        return Padding(
                          padding:
                              const EdgeInsets.only(bottom: 2),
                          child: Row(
                            children: [
                              _estadoChip(
                                  h['estadoNuevo']?.toString() ??
                                      ''),
                              const SizedBox(width: 6),
                              Text(
                                _formatDuracion(dur),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        );
                      }),
                      const Divider(height: 24),
                    ],

                    // Comentarios
                    const Text(
                      'Comentarios',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    if (loadingComentarios)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2)),
                      )
                    else if (comentarios.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text('Sin comentarios',
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                      )
                    else
                      ...comentarios.map((c) => Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      c['nombreCompleto']?.toString() ??
                                          c['usuario']?.toString() ??
                                          '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11),
                                    ),
                                    Text(
                                      _formatFecha(DateTime.tryParse(
                                              c['fecha']?.toString() ??
                                                  '') ??
                                          DateTime.now()),
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(c['texto']?.toString() ?? '',
                                    style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          )),
                    if (t.estado != 'Resuelto') ...[
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: comentarioCtrl,
                              minLines: 1,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                hintText: 'Agregar comentario...',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          enviandoComentario
                              ? const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                                )
                              : IconButton(
                                  icon: const Icon(Icons.send_rounded),
                                  onPressed: enviarComentario,
                                ),
                        ],
                      ),
                    ],
                    const Divider(height: 24),

                    DropdownButtonFormField<String>(
                      value: nuevoEstado,
                      decoration: const InputDecoration(
                          labelText: 'Estado',
                          border: OutlineInputBorder(),
                          helperText: 'El estado solo avanza, no puede regresar'),
                      items: _estadosSiguientes(t.estado)
                          .map((e) => DropdownMenuItem(
                              value: e, child: Text(e)))
                          .toList(),
                      onChanged: t.estado == 'Resuelto'
                          ? null
                          : (v) => setDs(() => nuevoEstado = v!),
                    ),
                    if (_tieneAccesoTotal) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: nuevoAsignado,
                        decoration: const InputDecoration(
                            labelText: 'Técnico Responsable',
                            border: OutlineInputBorder()),
                        items: _kTecnicos
                            .map((e) => DropdownMenuItem(
                                value: e,
                                child: Text(_nombreTecnico(e))))
                            .toList(),
                        onChanged: (v) =>
                            setDs(() => nuevoAsignado = v!),
                      ),
                    ],

                    // ESCALADO fields
                    if (nuevoEstado == 'Escalado') ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: escaladoACtrl,
                        decoration: const InputDecoration(
                          labelText: 'A quién se escaló',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: motivoEscaladoCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Motivo del escalado',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],

                    // RESUELTO fields
                    if (nuevoEstado == 'Resuelto') ...[
                      const Divider(height: 24),
                      const Text(
                        'Detalle de resolución',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'Incidencia',
                              label: Text('Incidencia'),
                              icon: Icon(Icons.bug_report_rounded,
                                  size: 14)),
                          ButtonSegment(
                              value: 'Servicio',
                              label: Text('Servicio'),
                              icon: Icon(Icons.build_circle_rounded,
                                  size: 14)),
                          ButtonSegment(
                              value: 'Mantenimiento',
                              label: Text('Mant.'),
                              icon: Icon(Icons.handyman_rounded,
                                  size: 14)),
                        ],
                        selected: {tipoTicket},
                        onSelectionChanged: (s) =>
                            setDs(() => tipoTicket = s.first),
                        style: const ButtonStyle(
                            visualDensity: VisualDensity.compact),
                      ),
                      const SizedBox(height: 12),
                      if (tipoTicket == 'Incidencia') ...[
                        TextFormField(
                          controller: causaCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Causa raíz',
                              border: OutlineInputBorder()),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: resolverCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Cómo se resolvió',
                              border: OutlineInputBorder()),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: pruebasCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Pruebas realizadas',
                              border: OutlineInputBorder()),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (tipoTicket == 'Mantenimiento') ...[
                        Row(
                          children: [
                            const Text('Tipo:', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
                            const SizedBox(width: 12),
                            ChoiceChip(
                              label: const Text('Preventivo'),
                              selected: tipoMantenimiento == 'Preventivo',
                              onSelected: (_) => setDs(() => tipoMantenimiento = 'Preventivo'),
                              selectedColor: Colors.green.shade100,
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('Correctivo'),
                              selected: tipoMantenimiento == 'Correctivo',
                              onSelected: (_) => setDs(() => tipoMantenimiento = 'Correctivo'),
                              selectedColor: Colors.orange.shade100,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (tipoMantenimiento == 'Correctivo') ...[
                          TextFormField(
                            controller: queCorrigioCtrl,
                            decoration: const InputDecoration(
                                labelText: '¿Qué se corrigió?',
                                border: OutlineInputBorder()),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 10),
                        ],
                      ],
                      TextFormField(
                        controller: validadoCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Validado con',
                            border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 10),
                      // Image picker
                      if (tipoTicket == 'Mantenimiento') ...[
                        OutlinedButton.icon(
                          onPressed: () async {
                            final img = await _pickImageBase64();
                            if (img != null) setDs(() => imagenesMantenimiento.add(img));
                          },
                          icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
                          label: Text('Agregar foto${imagenesMantenimiento.isNotEmpty ? ' (${imagenesMantenimiento.length})' : ''}'),
                        ),
                        if (imagenesMantenimiento.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: imagenesMantenimiento.asMap().entries.map((e) =>
                              Chip(
                                label: Text('Foto ${e.key + 1}', style: const TextStyle(fontSize: 11)),
                                deleteIcon: const Icon(Icons.close, size: 14),
                                onDeleted: () => setDs(() => imagenesMantenimiento.removeAt(e.key)),
                              )
                            ).toList(),
                          ),
                        ],
                      ] else
                        Row(
                          children: [
                            OutlinedButton.icon(
                              onPressed: () async {
                                final img = await _pickImageBase64();
                                if (img != null) setDs(() => imagenBase64 = img);
                              },
                              icon: const Icon(Icons.image_rounded, size: 16),
                              label: Text(imagenBase64 != null
                                  ? 'Imagen adjunta ✓'
                                  : 'Adjuntar imagen (opcional)'),
                            ),
                            if (imagenBase64 != null) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.close, size: 16),
                                onPressed: () => setDs(() => imagenBase64 = null),
                                tooltip: 'Quitar imagen',
                              ),
                            ],
                          ],
                        ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Theme.of(ctx).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: guardando
                    ? null
                    : () async {
                        if (nuevoEstado == 'Resuelto' &&
                            t.estado != 'Resuelto') {
                          final confirmado = await showDialog<bool>(
                            context: ctx,
                            builder: (c2) => AlertDialog(
                              title: const Text('¿Resolver este ticket?'),
                              content: Text(
                                  'Se abrió el ${_formatFecha(t.fecha)} (hace ${_tiempoDesde(t.fecha)}). '
                                  'Al confirmar se registrará este momento como el cierre y el ticket ya no podrá modificarse. '
                                  '¿Estás seguro de que fue resuelto?'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(c2, false),
                                    child: const Text('Cancelar')),
                                ElevatedButton(
                                    onPressed: () =>
                                        Navigator.pop(c2, true),
                                    child: const Text('Sí, resolver')),
                              ],
                            ),
                          );
                          if (confirmado != true) return;
                        }
                        setDs(() => guardando = true);
                        try {
                          if (nuevoEstado == 'Resuelto') {
                            await widget.api.resolverTicket(
                              t.id,
                              causaRaiz: tipoTicket == 'Mantenimiento'
                                  ? tipoMantenimiento
                                  : causaCtrl.text.trim(),
                              comoSeResolvio: tipoTicket == 'Mantenimiento'
                                  ? (tipoMantenimiento == 'Correctivo' ? queCorrigioCtrl.text.trim() : '')
                                  : resolverCtrl.text.trim(),
                              pruebasRealizadas:
                                  pruebasCtrl.text.trim(),
                              validadoCon:
                                  validadoCtrl.text.trim(),
                              tipoTicket: tipoTicket,
                              imagenResolucion: tipoTicket == 'Mantenimiento'
                                  ? (imagenesMantenimiento.isEmpty ? null : jsonEncode(imagenesMantenimiento))
                                  : imagenBase64,
                            );
                          } else if (nuevoEstado == 'Escalado') {
                            await widget.api.escalarTicket(
                              t.id,
                              escaladoA:
                                  escaladoACtrl.text.trim(),
                              motivoEscalado:
                                  motivoEscaladoCtrl.text.trim(),
                              usuario: widget.session.username,
                            );
                          } else if (nuevoEstado != t.estado) {
                            await widget.api.cambiarEstatusTicket(
                                t.id, nuevoEstado,
                                usuario: widget.session.username);
                          }
                          if (nuevoAsignado != t.asignadoA) {
                            await widget.api
                                .reasignarTicket(t.id, nuevoAsignado);
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          widget.onRefresh();
                        } catch (e) {
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')));
                          }
                        } finally {
                          if (ctx.mounted)
                            setDs(() => guardando = false);
                        }
                      },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _estadoChip(String estado) {
    final color = statusColor(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(estado,
          style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold)),
    );
  }

  void _abrirDialogoNuevo() {
    _usuarioCtrl.clear();
    _descCtrl.clear();
    _prioridad = 'Media';
    _asignado = 'Sin Asignar';
    _nuevaCategoria = null;
    _nuevaArea = null;
    _clearSession = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDs) => AlertDialog(
          title: const Text('Levantar Reporte Técnico',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _usuarioCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Usuario Afectado',
                          border: OutlineInputBorder()),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Requerido'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _prioridad,
                      decoration: const InputDecoration(
                          labelText: 'Prioridad',
                          border: OutlineInputBorder()),
                      items: ['Baja', 'Media', 'Alta']
                          .map((p) => DropdownMenuItem(
                              value: p, child: Text(p)))
                          .toList(),
                      onChanged: (v) =>
                          setDs(() => _prioridad = v!),
                    ),
                    const SizedBox(height: 12),
                    if (_categorias.isNotEmpty)
                      DropdownButtonFormField<String?>(
                        value: _nuevaCategoria,
                        decoration: const InputDecoration(
                            labelText: 'Categoría',
                            border: OutlineInputBorder()),
                        items: [
                          const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Sin categoría')),
                          ..._categorias.map((c) =>
                              DropdownMenuItem<String?>(
                                  value: c['nombre']?.toString(),
                                  child: Text(
                                      c['nombre']?.toString() ??
                                          ''))),
                        ],
                        onChanged: (v) =>
                            setDs(() => _nuevaCategoria = v),
                      ),
                    if (_categorias.isNotEmpty)
                      const SizedBox(height: 12),
                    if (_areas.isNotEmpty)
                      DropdownButtonFormField<String?>(
                        value: _nuevaArea,
                        decoration: const InputDecoration(
                            labelText: 'Área',
                            border: OutlineInputBorder()),
                        items: [
                          const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Sin área')),
                          ..._areas.map((a) =>
                              DropdownMenuItem<String?>(
                                  value: a['nombre']?.toString(),
                                  child: Text(
                                      a['nombre']?.toString() ??
                                          ''))),
                        ],
                        onChanged: (v) =>
                            setDs(() => _nuevaArea = v),
                      ),
                    if (_areas.isNotEmpty)
                      const SizedBox(height: 12),
                    if (_tieneAccesoTotal)
                      DropdownButtonFormField<String>(
                        value: _asignado,
                        decoration: const InputDecoration(
                            labelText: 'Técnico Responsable',
                            border: OutlineInputBorder()),
                        items: _kTecnicos
                            .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(_nombreTecnico(p))))
                            .toList(),
                        onChanged: (v) =>
                            setDs(() => _asignado = v!),
                      ),
                    if (_tieneAccesoTotal)
                      const SizedBox(height: 12),
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          labelText: 'Descripción de la falla',
                          border: OutlineInputBorder()),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Explique el problema'
                              : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Theme.of(ctx).colorScheme.primary,
                  foregroundColor: Colors.white),
              onPressed: _clearSession
                  ? null
                  : () async {
                      if (!_formKey.currentState!.validate()) return;
                      setDs(() => _clearSession = true);
                      final asignado = _tieneAccesoTotal
                          ? _asignado
                          : widget.session.username;
                      final nuevo = Ticket(
                        id: '',
                        usuario: _usuarioCtrl.text.trim(),
                        departamento: _nuevaArea ?? '',
                        descripcion: _descCtrl.text.trim(),
                        prioridad: _prioridad,
                        estado: 'Pendiente',
                        asignadoA: asignado,
                        fecha: DateTime.now(),
                        categoria: _nuevaCategoria,
                        area: _nuevaArea,
                      );
                      try {
                        await widget.api.crearTicket(nuevo);
                        if (ctx.mounted) Navigator.pop(ctx);
                        widget.onRefresh();
                      } catch (e) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')));
                        }
                      } finally {
                        if (ctx.mounted)
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
    List<Ticket> lista = _tieneAccesoTotal
        ? widget.tickets
        : widget.tickets
            .where((t) =>
                t.asignadoA.toLowerCase() ==
                widget.session.username.toLowerCase())
            .toList();

    if (_filtro == 'Activos') {
      lista = lista.where((t) => t.estado != 'Resuelto').toList();
    } else if (_filtro == 'Resueltos') {
      lista = lista.where((t) => t.estado == 'Resuelto').toList();
    }
    if (_filtroArea != null) {
      lista = lista
          .where((t) =>
              t.area == _filtroArea ||
              t.departamento == _filtroArea)
          .toList();
    }
    if (_filtroPrioridad != null) {
      lista = lista
          .where((t) => t.prioridad == _filtroPrioridad)
          .toList();
    }
    final _busq = _busquedaCtrl.text.toLowerCase().trim();
    if (_busq.isNotEmpty) {
      lista = lista.where((t) =>
        t.id.toLowerCase().contains(_busq) ||
        t.usuario.toLowerCase().contains(_busq) ||
        t.descripcion.toLowerCase().contains(_busq) ||
        t.departamento.toLowerCase().contains(_busq) ||
        (t.area?.toLowerCase().contains(_busq) ?? false) ||
        (t.categoria?.toLowerCase().contains(_busq) ?? false) ||
        t.asignadoA.toLowerCase().contains(_busq)
      ).toList();
    }
    if (_desde != null) {
      lista = lista.where((t) => !t.fecha.isBefore(_desde!)).toList();
    }
    if (_hasta != null) {
      final hastaFin = _hasta!.add(const Duration(days: 1));
      lista = lista.where((t) => t.fecha.isBefore(hastaFin)).toList();
    }

    final areaOpciones = {
      ..._areas.map((a) => a['nombre']?.toString() ?? ''),
      ...widget.tickets
          .map((t) => t.departamento)
          .where((d) => d.isNotEmpty),
    }.toList()
      ..sort();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Consola Soporte (${lista.length})',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                ElevatedButton.icon(
                  onPressed: _abrirDialogoNuevo,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Nuevo'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _busquedaCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Buscar por ID, usuario, descripción, área...',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                suffixIcon: _busquedaCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () { _busquedaCtrl.clear(); setState(() {}); })
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            // Filters row
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'Activos',
                        label: Text('Activos'),
                        icon: Icon(Icons.check_circle_outline,
                            size: 14)),
                    ButtonSegment(
                        value: 'Resueltos',
                        label: Text('Resueltos')),
                    ButtonSegment(
                        value: 'Todos', label: Text('Todos')),
                  ],
                  selected: {_filtro},
                  onSelectionChanged: (s) =>
                      setState(() => _filtro = s.first),
                  style: const ButtonStyle(
                      visualDensity: VisualDensity.compact),
                ),
                if (areaOpciones.isNotEmpty)
                  DropdownButton<String?>(
                    value: _filtroArea,
                    hint: const Text('Área',
                        style: TextStyle(fontSize: 13)),
                    items: [
                      const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Todas las áreas',
                              style: TextStyle(fontSize: 13))),
                      ...areaOpciones.map((a) =>
                          DropdownMenuItem<String?>(
                              value: a,
                              child: Text(a,
                                  style: const TextStyle(
                                      fontSize: 13)))),
                    ],
                    onChanged: (v) =>
                        setState(() => _filtroArea = v),
                    underline: Container(
                        height: 1,
                        color: Colors.blueGrey.shade200),
                  ),
                DropdownButton<String?>(
                  value: _filtroPrioridad,
                  hint: const Text('Prioridad',
                      style: TextStyle(fontSize: 13)),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Todas',
                            style: TextStyle(fontSize: 13))),
                    ...['Alta', 'Media', 'Baja'].map((p) =>
                        DropdownMenuItem<String?>(
                            value: p,
                            child: Text(p,
                                style: const TextStyle(
                                    fontSize: 13)))),
                  ],
                  onChanged: (v) =>
                      setState(() => _filtroPrioridad = v),
                  underline: Container(
                      height: 1,
                      color: Colors.blueGrey.shade200),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _desde ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _desde = d);
                  },
                  icon: const Icon(Icons.calendar_today_rounded, size: 14),
                  label: Text(
                    _desde == null
                        ? 'Desde'
                        : '${_desde!.day.toString().padLeft(2, '0')}/${_desde!.month.toString().padLeft(2, '0')}/${_desde!.year}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _desde != null ? Colors.blue.shade300 : Theme.of(context).colorScheme.outlineVariant),
                    foregroundColor: _desde != null ? Colors.blue.shade700 : Theme.of(context).colorScheme.onSurfaceVariant,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _hasta ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _hasta = d);
                  },
                  icon: const Icon(Icons.calendar_month_rounded, size: 14),
                  label: Text(
                    _hasta == null
                        ? 'Hasta'
                        : '${_hasta!.day.toString().padLeft(2, '0')}/${_hasta!.month.toString().padLeft(2, '0')}/${_hasta!.year}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: _hasta != null ? Colors.blue.shade300 : Theme.of(context).colorScheme.outlineVariant),
                    foregroundColor: _hasta != null ? Colors.blue.shade700 : Theme.of(context).colorScheme.onSurfaceVariant,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
                if (_filtroArea != null || _filtroPrioridad != null || _desde != null || _hasta != null || _busquedaCtrl.text.isNotEmpty)
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _filtroArea = null;
                      _filtroPrioridad = null;
                      _desde = null;
                      _hasta = null;
                      _busquedaCtrl.clear();
                    }),
                    icon: const Icon(Icons.clear, size: 14),
                    label: const Text('Limpiar',
                        style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: lista.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inbox_rounded,
                              size: 48,
                              color: Theme.of(context).colorScheme.onSurfaceVariant),
                          const SizedBox(height: 8),
                          Text('Sin tickets',
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: lista.length,
                      itemBuilder: (_, i) {
                        final t = lista[i];
                        final sColor = statusColor(t.estado);
                        final pColor = _prioColor(t.prioridad);
                        return Card(
                          child: ListTile(
                            onTap: () => _abrirDialogoEditar(t),
                            title: Text(t.descripcion,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              '${t.id} • ${t.usuario} — ${t.departamento} • ${_formatFecha(t.fecha)} (${_tiempoDesde(t.fecha)})',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              crossAxisAlignment:
                                  CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4),
                                  decoration: BoxDecoration(
                                    color: sColor
                                        .withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    t.estado,
                                    style: TextStyle(
                                        color: sColor,
                                        fontWeight:
                                            FontWeight.bold,
                                        fontSize: 11),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2),
                                  decoration: BoxDecoration(
                                    color: pColor
                                        .withValues(alpha: 0.1),
                                    borderRadius:
                                        BorderRadius.circular(6),
                                    border: Border.all(
                                        color: pColor
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    t.prioridad,
                                    style: TextStyle(
                                        color: pColor,
                                        fontWeight:
                                            FontWeight.bold,
                                        fontSize: 10),
                                  ),
                                ),
                              ],
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
