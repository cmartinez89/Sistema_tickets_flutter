class Ticket {
  final String id;
  final String usuario;
  final String departamento;
  final String descripcion;
  final String prioridad;
  String estado;
  String asignadoA;
  final DateTime fecha;

  String? causaRaiz;
  String? comoSeResolvio;
  String? pruebasRealizadas;
  String? validadoCon;

  Ticket({
    required this.id,
    required this.usuario,
    required this.departamento,
    required this.descripcion,
    required this.prioridad,
    required this.estado,
    required this.asignadoA,
    required this.fecha,
    this.causaRaiz,
    this.comoSeResolvio,
    this.pruebasRealizadas,
    this.validadoCon,
  });

  factory Ticket.fromMap(Map<String, dynamic> map) => Ticket(
    id: map['id'],
    usuario: map['usuario'],
    departamento: map['departamento'],
    descripcion: map['descripcion'],
    prioridad: map['prioridad'] ?? 'Media',
    estado: map['estado'],
    asignadoA: map['asignadoA'],
    fecha: DateTime.parse(map['fecha']),
    causaRaiz: map['causaRaiz'],
    comoSeResolvio: map['comoSeResolvio'],
    pruebasRealizadas: map['pruebasRealizadas'],
    validadoCon: map['validadoCon'],
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'usuario': usuario,
    'departamento': departamento,
    'descripcion': descripcion,
    'prioridad': prioridad,
    'estado': estado,
    'asignadoA': asignadoA,
    'fecha': fecha.toIso8601String(),
    if (causaRaiz != null) 'causaRaiz': causaRaiz,
    if (comoSeResolvio != null) 'comoSeResolvio': comoSeResolvio,
    if (pruebasRealizadas != null) 'pruebasRealizadas': pruebasRealizadas,
    if (validadoCon != null) 'validadoCon': validadoCon,
  };
}