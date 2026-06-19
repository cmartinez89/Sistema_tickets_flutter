class ChatMessage {
  final String id;
  final String deUsuario;
  final String nombreCompleto;
  final String texto;
  final DateTime fecha;

  ChatMessage({
    required this.id,
    required this.deUsuario,
    required this.nombreCompleto,
    required this.texto,
    required this.fecha,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
    id: map['id']?.toString() ?? '',
    deUsuario: map['deUsuario'] ?? '',
    nombreCompleto: map['nombreCompleto'] ?? '',
    texto: map['texto'] ?? '',
    fecha: DateTime.tryParse(map['fecha'] ?? '') ?? DateTime.now(),
  );
}
