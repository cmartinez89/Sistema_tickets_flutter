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
  Color(0xFF388E3C),
  Color(0xFFF57C00),
  Color(0xFF7B1FA2),
  Color(0xFFD32F2F),
  Color(0xFF0097A7),
  Color(0xFF5D4037),
  Color(0xFF455A64),
  Color(0xFFE91E63),
  Color(0xFF00796B),
  Color(0xFF6A1B9A),
  Color(0xFF1565C0),
];

Color _colorDeUsuario(String username) {
  final hash = username.codeUnits.fold(0, (a, b) => a + b);
  return _kPaletaColores[hash % _kPaletaColores.length];
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
  final Session session;
  final ApiService api;
  final List<Usuario> usuarios;
  final VoidCallback? onVolver;

  const ChatScreen({
    super.key,
    required this.mensajes,
    required this.session,
    required this.api,
    required this.usuarios,
    this.onVolver,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _enviando = false;
  String? _imagenSeleccionada;
  List<Usuario> _sugerencias = [];

  @override
  void initState() {
    super.initState();
    _inputCtrl.addListener(_detectarMencion);
  }

  @override
  void dispose() {
    _inputCtrl.removeListener(_detectarMencion);
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
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
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mensajes.length != oldWidget.mensajes.length) {
      _scrollAlFinal();
    }
  }

  void _scrollAlFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
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
    _inputCtrl.clear();
    setState(() => _imagenSeleccionada = null);
    try {
      await widget.api.enviarMensaje(
        widget.session.username,
        widget.session.nombreCompleto,
        texto,
        imagen: imagenEnviar,
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

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
            color: Colors.white,
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
                CircleAvatar(
                  backgroundColor: primary.withValues(alpha: 0.12),
                  child: Icon(Icons.groups_rounded, color: primary, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Chat Interno TI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('Equipo de soporte', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Messages
          Expanded(
            child: widget.mensajes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('Sé el primero en escribir', style: TextStyle(color: Colors.grey.shade400)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    itemCount: widget.mensajes.length,
                    itemBuilder: (_, i) {
                      final msg = widget.mensajes[i];
                      final esMio = msg.deUsuario == widget.session.username;
                      final mostrarNombre = !esMio &&
                          (i == 0 || widget.mensajes[i - 1].deUsuario != msg.deUsuario);

                      return _BurbujaMensaje(
                        mensaje: msg,
                        esMio: esMio,
                        mostrarNombre: mostrarNombre,
                        colorPrimary: primary,
                        colorUsuario: _colorDeUsuario(msg.deUsuario),
                      );
                    },
                  ),
          ),

          // Mention suggestions
          if (_sugerencias.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 220),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
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
                    subtitle: Text('@${u.username}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                    onTap: () => _seleccionarMencion(u),
                  );
                },
              ),
            ),

          // Image preview strip
          if (_imagenSeleccionada != null)
            Container(
              color: Colors.white,
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
                                color: Colors.grey.shade200,
                                child: const Icon(Icons.image, color: Colors.grey),
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
                  Text('Imagen lista para enviar', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),

          // Input
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2))],
            ),
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _inputCtrl,
                    maxLines: null,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _enviar(),
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      filled: true,
                      fillColor: const Color(0xFFF0F2F5),
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
                  color: Colors.grey.shade100,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _seleccionarImagen,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Icon(Icons.image_rounded, color: Colors.grey.shade600, size: 20),
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
          style: TextStyle(color: esMio ? Colors.white : Colors.black87, fontSize: 14),
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
        style: TextStyle(color: esMio ? Colors.white : Colors.black87, fontSize: 14),
      ));
    }
    return RichText(text: TextSpan(children: spans));
  }
}

class _BurbujaMensaje extends StatelessWidget {
  final ChatMessage mensaje;
  final bool esMio;
  final bool mostrarNombre;
  final Color colorPrimary;
  final Color colorUsuario;

  const _BurbujaMensaje({
    required this.mensaje,
    required this.esMio,
    required this.mostrarNombre,
    required this.colorPrimary,
    required this.colorUsuario,
  });

  String _hora(DateTime fecha) {
    final h = fecha.toLocal();
    return '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final imagenBytes = _decodeImage(mensaje.imagen);

    return Padding(
      padding: EdgeInsets.only(
        top: mostrarNombre ? 12 : 3,
        bottom: 2,
      ),
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
                    color: esMio ? colorPrimary : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(esMio ? 18 : 4),
                      bottomRight: Radius.circular(esMio ? 4 : 18),
                    ),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
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
                          color: esMio ? Colors.white.withValues(alpha: 0.7) : Colors.grey.shade400,
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
