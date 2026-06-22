class ChatMessage {
  final String id;
  final String deUsuario;
  final String nombreCompleto;
  final String texto;
  final DateTime fecha;
  final String? imagen;
  final bool borrado;
  final String? borradoPor;

  ChatMessage({
    required this.id,
    required this.deUsuario,
    required this.nombreCompleto,
    required this.texto,
    required this.fecha,
    this.imagen,
    this.borrado = false,
    this.borradoPor,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
    id: map['id']?.toString() ?? '',
    deUsuario: map['deUsuario'] ?? '',
    nombreCompleto: map['nombreCompleto'] ?? '',
    texto: map['texto'] ?? '',
    fecha: DateTime.tryParse(map['fecha'] ?? '') ?? DateTime.now(),
    imagen: map['imagen'],
    borrado: map['borrado'] == true || map['borrado'] == 1,
    borradoPor: map['borradoPor'],
  );

  ChatMessage copyWith({bool? borrado, String? borradoPor}) => ChatMessage(
    id: id,
    deUsuario: deUsuario,
    nombreCompleto: nombreCompleto,
    texto: texto,
    fecha: fecha,
    imagen: imagen,
    borrado: borrado ?? this.borrado,
    borradoPor: borradoPor ?? this.borradoPor,
  );
}
