class Tarea {
  final int id;
  final int proyectoId;
  final String proyectoNombre;
  final String titulo;
  final String descripcion;
  final String estado; // por_hacer | haciendo | en_revision | hecho
  final DateTime? fechaInicio;
  final DateTime? fechaFin;
  final String? asignadoAUsername;
  final String? asignadoANombre;
  final String prioridad; // baja | media | alta
  final DateTime creadoEn;

  const Tarea({
    required this.id,
    required this.proyectoId,
    required this.proyectoNombre,
    required this.titulo,
    required this.descripcion,
    required this.estado,
    this.fechaInicio,
    this.fechaFin,
    this.asignadoAUsername,
    this.asignadoANombre,
    required this.prioridad,
    required this.creadoEn,
  });

  factory Tarea.fromMap(Map<String, dynamic> m) => Tarea(
        id: m['id'] as int,
        proyectoId: m['proyectoId'] as int,
        proyectoNombre: (m['proyectoNombre'] as String?) ?? '',
        titulo: m['titulo'] as String,
        descripcion: (m['descripcion'] as String?) ?? '',
        estado: (m['estado'] as String?) ?? 'por_hacer',
        fechaInicio:
            m['fechaInicio'] != null ? DateTime.parse(m['fechaInicio'] as String) : null,
        fechaFin:
            m['fechaFin'] != null ? DateTime.parse(m['fechaFin'] as String) : null,
        asignadoAUsername: m['asignadoAUsername'] as String?,
        asignadoANombre: m['asignadoANombre'] as String?,
        prioridad: (m['prioridad'] as String?) ?? 'media',
        creadoEn: DateTime.parse(m['creadoEn'] as String),
      );

  Map<String, dynamic> toMap() => {
        if (id != 0) 'id': id,
        'proyectoId': proyectoId,
        'titulo': titulo,
        'descripcion': descripcion,
        'estado': estado,
        'prioridad': prioridad,
        if (fechaInicio != null)
          'fechaInicio': fechaInicio!.toIso8601String().substring(0, 10),
        if (fechaFin != null)
          'fechaFin': fechaFin!.toIso8601String().substring(0, 10),
        if (asignadoAUsername != null) 'asignadoAUsername': asignadoAUsername,
      };

  Tarea copyWith({
    int? id,
    int? proyectoId,
    String? proyectoNombre,
    String? titulo,
    String? descripcion,
    String? estado,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    String? asignadoAUsername,
    String? asignadoANombre,
    String? prioridad,
    DateTime? creadoEn,
    bool clearFechaInicio = false,
    bool clearFechaFin = false,
  }) =>
      Tarea(
        id: id ?? this.id,
        proyectoId: proyectoId ?? this.proyectoId,
        proyectoNombre: proyectoNombre ?? this.proyectoNombre,
        titulo: titulo ?? this.titulo,
        descripcion: descripcion ?? this.descripcion,
        estado: estado ?? this.estado,
        fechaInicio: clearFechaInicio ? null : (fechaInicio ?? this.fechaInicio),
        fechaFin: clearFechaFin ? null : (fechaFin ?? this.fechaFin),
        asignadoAUsername: asignadoAUsername ?? this.asignadoAUsername,
        asignadoANombre: asignadoANombre ?? this.asignadoANombre,
        prioridad: prioridad ?? this.prioridad,
        creadoEn: creadoEn ?? this.creadoEn,
      );
}
