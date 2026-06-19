import 'package:flutter/material.dart';
import '../models/chat_message_model.dart';
import '../models/session_model.dart';
import '../services/api_service.dart';

class ChatScreen extends StatefulWidget {
  final List<ChatMessage> mensajes;
  final Session session;
  final ApiService api;

  const ChatScreen({
    super.key,
    required this.mensajes,
    required this.session,
    required this.api,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _enviando = false;

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
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

  Future<void> _enviar() async {
    final texto = _inputCtrl.text.trim();
    if (texto.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    _inputCtrl.clear();
    try {
      await widget.api.enviarMensaje(
        widget.session.username,
        widget.session.nombreCompleto,
        texto,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
        _inputCtrl.text = texto;
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            color: Colors.white,
            child: Row(
              children: [
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
                      );
                    },
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
                const SizedBox(width: 8),
                _enviando
                    ? const SizedBox(width: 44, height: 44, child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator(strokeWidth: 2)))
                    : IconButton(
                        onPressed: _enviar,
                        icon: const Icon(Icons.send_rounded),
                        color: primary,
                        style: IconButton.styleFrom(
                          backgroundColor: primary.withValues(alpha: 0.1),
                          shape: const CircleBorder(),
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

class _BurbujaMensaje extends StatelessWidget {
  final ChatMessage mensaje;
  final bool esMio;
  final bool mostrarNombre;
  final Color colorPrimary;

  const _BurbujaMensaje({
    required this.mensaje,
    required this.esMio,
    required this.mostrarNombre,
    required this.colorPrimary,
  });

  String _hora(DateTime fecha) {
    final h = fecha.toLocal();
    return '${h.hour.toString().padLeft(2, '0')}:${h.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
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
              backgroundColor: colorPrimary.withValues(alpha: 0.15),
              child: Text(
                mensaje.nombreCompleto.isNotEmpty ? mensaje.nombreCompleto[0].toUpperCase() : '?',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colorPrimary),
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
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade600),
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
                      Text(
                        mensaje.texto,
                        style: TextStyle(color: esMio ? Colors.white : Colors.black87, fontSize: 14),
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
