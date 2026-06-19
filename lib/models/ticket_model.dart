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

  String? escaladoA;
  String? motivoEscalado;
  String tipoTicket;
  String? categoria;
  String? area;
  String? imagenResolucion;

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
    this.escaladoA,
    this.motivoEscalado,
    this.tipoTicket = 'Incidencia',
    this.categoria,
    this.area,
    this.imagenResolucion,
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
    escaladoA: map['escaladoA'],
    motivoEscalado: map['motivoEscalado'],
    tipoTicket: map['tipoTicket'] ?? 'Incidencia',
    categoria: map['categoria'],
    area: map['area'],
    imagenResolucion: map['imagenResolucion'],
  );

  Map<String, dynamic> toMap() => {
    if (id.isNotEmpty) 'id': id,
    'usuario': usuario,
    'departamento': departamento,
    'descripcion': descripcion,
    'prioridad': prioridad,
    'estado': estado,
    'asignadoA': asignadoA,
    'fecha': fecha.toIso8601String(),
    'tipoTicket': tipoTicket,
    if (causaRaiz != null) 'causaRaiz': causaRaiz,
    if (comoSeResolvio != null) 'comoSeResolvio': comoSeResolvio,
    if (pruebasRealizadas != null) 'pruebasRealizadas': pruebasRealizadas,
    if (validadoCon != null) 'validadoCon': validadoCon,
    if (escaladoA != null) 'escaladoA': escaladoA,
    if (motivoEscalado != null) 'motivoEscalado': motivoEscalado,
    if (categoria != null) 'categoria': categoria,
    if (area != null) 'area': area,
    if (imagenResolucion != null) 'imagenResolucion': imagenResolucion,
  };
}
