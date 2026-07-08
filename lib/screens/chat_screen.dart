import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/chat_message_model.dart';
import '../models/session_model.dart';
import '../models/usuario_model.dart';
import '../services/api_service.dart';

const _kPaletaColores = [
  Color(0xFF1976D2),
  Color(0xFF5C6BC0),
  Color(0xFFF57C00),
  Color(0xFF7B1FA2),
  Color(0xFFD32F2F),
  Color(0xFF0097A7),
  Color(0xFF5D4037),
  Color(0xFF455A64),
  Color(0xFFE91E63),
  Color(0xFF8D6E63),
  Color(0xFF6A1B9A),
  Color(0xFF1565C0),
];

Color _colorDeUsuario(String username) {
  final hash = username.codeUnits.fold(0, (a, b) => a + b);
  return _kPaletaColores[hash % _kPaletaColores.length];
}

const _kMeses = [
  'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
  'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
];

const _kCanalLabel = {
  'soporte': 'Soporte',
  'desarrollo': 'Desarrollo',
  'general': 'General',
};

bool _mismoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

String _etiquetaFecha(DateTime fecha) {
  final hoy = DateTime.now();
  final ayer = hoy.subtract(const Duration(days: 1));
  if (_mismoDia(fecha, hoy)) return 'Hoy';
  if (_mismoDia(fecha, ayer)) return 'Ayer';
  final mismoAnio = fecha.year == hoy.year;
  return '${fecha.day} de ${_kMeses[fecha.month - 1]}${mismoAnio ? '' : ' de ${fecha.year}'}';
}

class _SeparadorFecha extends StatelessWidget {
  final DateTime fecha;

  const _SeparadorFecha({required this.fecha});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 3, offset: const Offset(0, 1))],
          ),
          child: Text(
            _etiquetaFecha(fecha),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

Future<String?> _pickChatImage() async {
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

Uint8List? _decodeImage(String? dataUrl) {
  if (dataUrl == null || !dataUrl.contains(',')) return null;
  try {
    return base64Decode(dataUrl.split(',')[1]);
  } catch (_) {
    return null;
  }
}

class ChatScreen extends StatefulWidget {
  final List<ChatMessage> mensajes;
  final List<String> canales;
  final Session session;
  final ApiService api;
  final List<Usuario> usuarios;
  final VoidCallback? onVolver;
  final Future<void> Function(String id)? onBorrarMensaje;

  const ChatScreen({
    super.key,
    required this.mensajes,
    required this.canales,
    required this.session,
    required this.api,
    required this.usuarios,
    this.onVolver,
    this.onBorrarMensaje,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _inputFocus = FocusNode();
  final _scrollCtrl = ScrollController();
  bool _enviando = false;
  String? _imagenSeleccionada;
  List<Usuario> _sugerencias = [];
  late String _canalActivo;
  ChatMessage? _respondiendoA;
  final Map<String, GlobalKey> _mensajeKeys = {};
  bool _buscando = false;
  final _busquedaCtrl = TextEditingController();
  List<String> _coincidencias = [];
  int _coincidenciaActual = -1;

  List<ChatMessage> get _mensajesDelCanal =>
      widget.mensajes.where((m) => m.canal == _canalActivo).toList();

  GlobalKey _keyPara(String id) => _mensajeKeys.putIfAbsent(id, () => GlobalKey());

  ChatMessage? _buscarMensajePorId(String? id) {
    if (id == null) return null;
    for (final m in widget.mensajes) {
      if (m.id == id) return m;
    }
    return null;
  }

  void _irAMensaje(String id) {
    final ctx = _mensajeKeys[id]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.5);
    }
  }

  void _iniciarRespuesta(ChatMessage msg) {
    setState(() => _respondiendoA = msg);
    _inputFocus.requestFocus();
  }

  void _buscar(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _coincidencias = [];
        _coincidenciaActual = -1;
      });
      return;
    }
    final ids = _mensajesDelCanal.where((m) => m.texto.toLowerCase().contains(q)).map((m) => m.id).toList();
    setState(() {
      _coincidencias = ids;
      _coincidenciaActual = ids.isEmpty ? -1 : ids.length - 1;
    });
    if (_coincidencias.isNotEmpty) _irAMensaje(_coincidencias[_coincidenciaActual]);
  }

  void _siguienteCoincidencia() {
    if (_coincidencias.isEmpty) return;
    setState(() => _coincidenciaActual = (_coincidenciaActual - 1 + _coincidencias.length) % _coincidencias.length);
    _irAMensaje(_coincidencias[_coincidenciaActual]);
  }

  void _anteriorCoincidencia() {
    if (_coincidencias.isEmpty) return;
    setState(() => _coincidenciaActual = (_coincidenciaActual + 1) % _coincidencias.length);
    _irAMensaje(_coincidencias[_coincidenciaActual]);
  }

  void _cerrarBusqueda() {
    _busquedaCtrl.clear();
    setState(() {
      _buscando = false;
      _coincidencias = [];
      _coincidenciaActual = -1;
    });
  }

  @override
  void initState() {
    super.initState();
    _canalActivo = widget.canales.first;
    _inputCtrl.addListener(_detectarMencion);
  }

  @override
  void dispose() {
    _inputCtrl.removeListener(_detectarMencion);
    _inputCtrl.dispose();
    _inputFocus.dispose();
    _scrollCtrl.dispose();
    _busquedaCtrl.dispose();
    super.dispose();
  }

  void _detectarMencion() {
    final text = _inputCtrl.text;
    final cursor = _inputCtrl.selection.baseOffset;
    if (cursor < 0 || text.isEmpty) {
      if (_sugerencias.isNotEmpty) setState(() => _sugerencias = []);
      return;
    }
    final antes = text.substring(0, cursor);
    final atIdx = antes.lastIndexOf('@');
    if (atIdx == -1) {
      if (_sugerencias.isNotEmpty) setState(() => _sugerencias = []);
      return;
    }
    final query = antes.substring(atIdx + 1);
    if (query.contains(' ') || query.contains('\n')) {
      if (_sugerencias.isNotEmpty) setState(() => _sugerencias = []);
      return;
    }
    final filtrados = widget.usuarios
        .where((u) =>
            u.username != widget.session.username &&
            (u.username.toLowerCase().contains(query.toLowerCase()) ||
                u.nombreCompleto.toLowerCase().contains(query.toLowerCase())))
        .toList();
    setState(() => _sugerencias = filtrados);
  }

  void _seleccionarMencion(Usuario u) {
    final text = _inputCtrl.text;
    final cursor = _inputCtrl.selection.baseOffset;
    final antes = text.substring(0, cursor);
    final atIdx = antes.lastIndexOf('@');
    final nuevo = '${text.substring(0, atIdx)}@${u.username} ${text.substring(cursor)}';
    _inputCtrl.value = TextEditingValue(
      text: nuevo,
      selection: TextSelection.collapsed(offset: atIdx + u.username.length + 2),
    );
    setState(() => _sugerencias = []);
    _inputFocus.requestFocus();
  }

  Future<void> _seleccionarImagen() async {
    final result = await _pickChatImage();
    if (result != null && mounted) {
      setState(() => _imagenSeleccionada = result);
    }
  }

  Future<void> _enviar() async {
    final texto = _inputCtrl.text.trim();
    if ((texto.isEmpty && _imagenSeleccionada == null) || _enviando) return;
    setState(() => _enviando = true);
    final imagenEnviar = _imagenSeleccionada;
    final respuestaAEnviar = _respondiendoA != null ? int.tryParse(_respondiendoA!.id) : null;
    _inputCtrl.clear();
    setState(() {
      _imagenSeleccionada = null;
      _respondiendoA = null;
    });
    try {
      await widget.api.enviarMensaje(
        widget.session.username,
        widget.session.nombreCompleto,
        texto,
        canal: _canalActivo,
        imagen: imagenEnviar,
        respuestaA: respuestaAEnviar,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
        _inputCtrl.text = texto;
        setState(() => _imagenSeleccionada = imagenEnviar);
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _confirmarBorrado(ChatMessage msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar mensaje'),
        content: const Text('¿Eliminar este mensaje? Los demás usuarios verán que fue eliminado.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await widget.onBorrarMensaje?.call(msg.id);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al borrar: $e'), backgroundColor: Colors.redAccent),
                  );
                }
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  bool _puedeBorar(ChatMessage msg) {
    if (msg.borrado) return false;
    return widget.session.rol == 'Admin' || msg.deUsuario == widget.session.username;
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final esAdmin = widget.session.rol == 'Admin';
    final mensajes = _mensajesDelCanal;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
            color: Theme.of(context).colorScheme.surface,
            child: Row(
              children: [
                if (widget.onVolver != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: widget.onVolver,
                    tooltip: 'Volver',
                  )
                else
                  const SizedBox(width: 16),
                if (!_buscando) ...[
                  CircleAvatar(
                    backgroundColor: primary.withValues(alpha: 0.12),
                    child: Icon(Icons.groups_rounded, color: primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: _buscando
                      ? TextField(
                          controller: _busquedaCtrl,
                          autofocus: true,
                          onChanged: _buscar,
                          decoration: const InputDecoration(
                            hintText: 'Buscar en este canal...',
                            border: InputBorder.none,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Chat Interno TI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(_kCanalLabel[_canalActivo] ?? _canalActivo,
                                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          ],
                        ),
                ),
                if (_buscando && _coincidencias.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      '${_coincidencias.length - _coincidenciaActual}/${_coincidencias.length}',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                if (_buscando) ...[
                  IconButton(icon: const Icon(Icons.keyboard_arrow_up), onPressed: _anteriorCoincidencia),
                  IconButton(icon: const Icon(Icons.keyboard_arrow_down), onPressed: _siguienteCoincidencia),
                ],
                IconButton(
                  icon: Icon(_buscando ? Icons.close : Icons.search),
                  tooltip: _buscando ? 'Cerrar búsqueda' : 'Buscar en el canal',
                  onPressed: () => _buscando ? _cerrarBusqueda() : setState(() => _buscando = true),
                ),
              ],
            ),
          ),
          if (widget.canales.length > 1)
            Container(
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: widget.canales.map((c) {
                  final activo = c == _canalActivo;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(_kCanalLabel[c] ?? c),
                      selected: activo,
                      onSelected: (_) => setState(() {
                        _canalActivo = c;
                        _cerrarBusqueda();
                      }),
                      selectedColor: primary,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      labelStyle: TextStyle(
                        color: activo ? Colors.white : Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          const Divider(height: 1),

          // Messages
          Expanded(
            child: mensajes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Text('Sé el primero en escribir', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    itemCount: mensajes.length,
                    itemBuilder: (_, reversedI) {
                      final i = mensajes.length - 1 - reversedI;
                      final msg = mensajes[i];
                      final esMio = msg.deUsuario == widget.session.username;
                      final nuevoDia = i == 0 || !_mismoDia(mensajes[i - 1].fecha, msg.fecha);
                      final mostrarNombre = !esMio &&
                          (nuevoDia || mensajes[i - 1].deUsuario != msg.deUsuario);
                      double dragDx = 0;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (nuevoDia) _SeparadorFecha(fecha: msg.fecha),
                          GestureDetector(
                            key: _keyPara(msg.id),
                            onLongPress: _puedeBorar(msg) ? () => _confirmarBorrado(msg) : null,
                            onHorizontalDragUpdate: (d) => dragDx += d.delta.dx,
                            onHorizontalDragEnd: (_) {
                              if (dragDx.abs() > 48) _iniciarRespuesta(msg);
                              dragDx = 0;
                            },
                            child: _BurbujaMensaje(
                              mensaje: msg,
                              esMio: esMio,
                              esAdmin: esAdmin,
                              mostrarNombre: mostrarNombre,
                              colorPrimary: primary,
                              colorUsuario: _colorDeUsuario(msg.deUsuario),
                              mensajeCitado: _buscarMensajePorId(msg.respuestaA?.toString()),
                              onTapCitado: msg.respuestaA != null
                                  ? () => _irAMensaje(msg.respuestaA.toString())
                                  : null,
                              resaltado: _coincidenciaActual >= 0 && _coincidencias[_coincidenciaActual] == msg.id,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          // Mention suggestions
          if (_sugerencias.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8, offset: const Offset(0, -2))],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _sugerencias.length,
                itemBuilder: (_, i) {
                  final u = _sugerencias[i];
                  final color = _colorDeUsuario(u.username);
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 18,
                      backgroundColor: color.withValues(alpha: 0.15),
                      child: Text(u.inicial, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                    title: Text(u.nombreCompleto, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: Text('@${u.username}', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                    onTap: () => _seleccionarMencion(u),
                  );
                },
              ),
            ),

          // Image preview strip
          if (_imagenSeleccionada != null)
            Container(
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Builder(
                          builder: (_) {
                            final bytes = _decodeImage(_imagenSeleccionada);
                            if (bytes == null) {
                              return Container(
                                width: 70, height: 70,
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: Icon(Icons.image, color: Theme.of(context).colorScheme.onSurfaceVariant),
                              );
                            }
                            return Image.memory(bytes, width: 70, height: 70, fit: BoxFit.cover);
                          },
                        ),
                      ),
                      Positioned(
                        top: -6,
                        right: -6,
                        child: GestureDetector(
                          onTap: () => setState(() => _imagenSeleccionada = null),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Text('Imagen lista para enviar', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),

          // Reply preview bar
          if (_respondiendoA != null)
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  Container(width: 3, height: 34, color: primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _respondiendoA!.deUsuario == widget.session.username ? 'Tú' : _respondiendoA!.nombreCompleto,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: primary),
                        ),
                        Text(
                          _respondiendoA!.texto.isNotEmpty ? _respondiendoA!.texto : '📷 Imagen',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _respondiendoA = null),
                  ),
                ],
              ),
            ),

          // Input
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2))],
            ),
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    focusNode: _inputFocus,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _enviar(),
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Image button
                Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _seleccionarImagen,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(Icons.image_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant, size: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Send button
                _enviando
                    ? SizedBox(
                        width: 44,
                        height: 44,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: CircularProgressIndicator(strokeWidth: 2, color: primary),
                        ),
                      )
                    : Material(
                        color: primary,
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _enviar,
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(Icons.send_rounded, color: Colors.white, size: 22),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TextoConMenciones extends StatelessWidget {
  final String texto;
  final bool esMio;
  final Color colorPrimary;

  const _TextoConMenciones({required this.texto, required this.esMio, required this.colorPrimary});

  @override
  Widget build(BuildContext context) {
    final regex = RegExp(r'@\w+');
    final spans = <TextSpan>[];
    int last = 0;
    for (final m in regex.allMatches(texto)) {
      if (m.start > last) {
        spans.add(TextSpan(
          text: texto.substring(last, m.start),
          style: TextStyle(color: esMio ? Colors.white : Theme.of(context).colorScheme.onSurface, fontSize: 14),
        ));
      }
      spans.add(TextSpan(
        text: m.group(0),
        style: TextStyle(
          color: esMio ? Colors.white : colorPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ));
      last = m.end;
    }
    if (last < texto.length) {
      spans.add(TextSpan(
        text: texto.substring(last),
        style: TextStyle(color: esMio ? Colors.white : Theme.of(context).colorScheme.onSurface, fontSize: 14),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }
}

class _BurbujaMensaje extends StatelessWidget {
  final ChatMessage mensaje;
  final bool esMio;
  final bool esAdmin;
  final bool mostrarNombre;
  final Color colorPrimary;
  final Color colorUsuario;
  final ChatMessage? mensajeCitado;
  final VoidCallback? onTapCitado;
  final bool resaltado;

  const _BurbujaMensaje({
    required this.mensaje,
    required this.esMio,
    required this.esAdmin,
    required this.mostrarNombre,
    required this.colorPrimary,
    required this.colorUsuario,
    this.mensajeCitado,
    this.onTapCitado,
    this.resaltado = false,
  });

  String _hora(DateTime fecha) {
    final h = fecha.toLocal();
    return '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final imagenBytes = _decodeImage(mensaje.imagen);
    final borrado = mensaje.borrado;

    // Usuario normal ve burbujas vacías para mensajes eliminados
    if (borrado && !esAdmin) {
      return Padding(
        padding: EdgeInsets.only(top: mostrarNombre ? 12 : 3, bottom: 2),
        child: Row(
          mainAxisAlignment: esMio ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!esMio) const SizedBox(width: 38),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.block_rounded, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    'Este mensaje fue eliminado',
                    style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            if (esMio) const SizedBox(width: 4),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(top: mostrarNombre ? 12 : 3, bottom: 2),
      child: Row(
        mainAxisAlignment: esMio ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!esMio) ...[
            CircleAvatar(
              radius: 15,
              backgroundColor: colorUsuario.withValues(alpha: 0.18),
              child: Text(
                mensaje.nombreCompleto.isNotEmpty ? mensaje.nombreCompleto[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorUsuario),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: esMio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (mostrarNombre && !esMio)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      mensaje.nombreCompleto,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colorUsuario),
                    ),
                  ),
                Container(
                  constraints: const BoxConstraints(maxWidth: 480),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: borrado
                        ? (esMio ? colorPrimary.withValues(alpha: 0.5) : Theme.of(context).colorScheme.surfaceContainerHighest)
                        : (esMio ? colorPrimary : Theme.of(context).colorScheme.surface),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(esMio ? 18 : 4),
                      bottomRight: Radius.circular(esMio ? 4 : 18),
                    ),
                    border: borrado
                        ? Border.all(color: Colors.red.withValues(alpha: 0.3))
                        : (resaltado ? Border.all(color: Colors.amber, width: 2) : null),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Citación de mensaje respondido
                      if (mensaje.respuestaA != null)
                        GestureDetector(
                          onTap: onTapCitado,
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: (esMio ? Colors.white : colorPrimary).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border(left: BorderSide(color: esMio ? Colors.white : colorPrimary, width: 3)),
                            ),
                            child: mensajeCitado != null
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mensajeCitado!.nombreCompleto,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: esMio ? Colors.white : colorPrimary),
                                      ),
                                      Text(
                                        mensajeCitado!.texto.isNotEmpty ? mensajeCitado!.texto : '📷 Imagen',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 11, color: esMio ? Colors.white.withValues(alpha: 0.85) : Theme.of(context).colorScheme.onSurface),
                                      ),
                                    ],
                                  )
                                : Text(
                                    'Mensaje original no disponible',
                                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: esMio ? Colors.white.withValues(alpha: 0.7) : Theme.of(context).colorScheme.onSurfaceVariant),
                                  ),
                          ),
                        ),
                      // Admin badge when showing deleted message
                      if (borrado && esAdmin)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.delete_outline_rounded, size: 12, color: Colors.red.shade300),
                              const SizedBox(width: 4),
                              Text(
                                'Eliminado por ${mensaje.borradoPor ?? '?'}',
                                style: TextStyle(fontSize: 10, color: Colors.red.shade300, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      // Image if present
                      if (imagenBytes != null) ...[
                        GestureDetector(
                          onTap: () => showDialog(
                            context: context,
                            builder: (_) => Dialog(
                              child: InteractiveViewer(
                                child: Image.memory(imagenBytes),
                              ),
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(imagenBytes, width: 220, fit: BoxFit.cover),
                          ),
                        ),
                        if (mensaje.texto.isNotEmpty) const SizedBox(height: 6),
                      ],
                      if (mensaje.texto.isNotEmpty)
                        _TextoConMenciones(
                          texto: mensaje.texto,
                          esMio: esMio,
                          colorPrimary: colorPrimary,
                        ),
                      const SizedBox(height: 3),
                      Text(
                        _hora(mensaje.fecha),
                        style: TextStyle(
                          fontSize: 10,
                          color: esMio ? Colors.white.withValues(alpha: 0.7) : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (esMio) const SizedBox(width: 4),
        ],
      ),
    );
  }
}
