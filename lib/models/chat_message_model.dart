DateTime _parseFechaUtc(dynamic raw) {
  final s = raw?.toString() ?? '';
  if (s.isEmpty) return DateTime.now();
  // El backend envía datetime.now().isoformat() sin sufijo de zona horaria,
  // pero el servidor corre en UTC. Sin la 'Z', DateTime.parse lo interpretaría
  // como hora local y desplazaría la hora mostrada.
  final utcStr = (s.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(s)) ? s : '${s}Z';
  return DateTime.tryParse(utcStr)?.toLocal() ?? DateTime.now();
}

class ChatMessage {
  final String id;
  final String deUsuario;
  final String nombreCompleto;
  final String texto;
  final DateTime fecha;
  final String? imagen;
  final bool borrado;
  final String? borradoPor;
  final String canal;
  final int? respuestaA;

  ChatMessage({
    required this.id,
    required this.deUsuario,
    required this.nombreCompleto,
    required this.texto,
    required this.fecha,
    this.imagen,
    this.borrado = false,
    this.borradoPor,
    this.canal = 'soporte',
    this.respuestaA,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
    id: map['id']?.toString() ?? '',
    deUsuario: map['deUsuario'] ?? '',
    nombreCompleto: map['nombreCompleto'] ?? '',
    texto: map['texto'] ?? '',
    fecha: _parseFechaUtc(map['fecha']),
    imagen: map['imagen'],
    borrado: map['borrado'] == true || map['borrado'] == 1,
    borradoPor: map['borradoPor'],
    canal: map['canal'] ?? 'soporte',
    respuestaA: map['respuestaA'] == null ? null : int.tryParse(map['respuestaA'].toString()),
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
    canal: canal,
    respuestaA: respuestaA,
  );
}
