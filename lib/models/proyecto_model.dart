class Proyecto {
  final int id;
  final String nombre;
  final String descripcion;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String estado; // activo | pausado | terminado
  final String? responsableUsername;
  final String? responsableNombre;
  final int tareasTotal;
  final int tareasHecho;

  const Proyecto({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.fechaInicio,
    required this.fechaFin,
    required this.estado,
    this.responsableUsername,
    this.responsableNombre,
    this.tareasTotal = 0,
    this.tareasHecho = 0,
  });

  factory Proyecto.fromMap(Map<String, dynamic> m) => Proyecto(
        id: m['id'] as int,
        nombre: m['nombre'] as String,
        descripcion: (m['descripcion'] as String?) ?? '',
        fechaInicio: DateTime.parse(m['fechaInicio'] as String),
        fechaFin: DateTime.parse(m['fechaFin'] as String),
        estado: (m['estado'] as String?) ?? 'activo',
        responsableUsername: m['responsableUsername'] as String?,
        responsableNombre: m['responsableNombre'] as String?,
        tareasTotal: (m['tareasTotal'] as int?) ?? 0,
        tareasHecho: (m['tareasHecho'] as int?) ?? 0,
      );

  Map<String, dynamic> toMap() => {
        if (id != 0) 'id': id,
        'nombre': nombre,
        'descripcion': descripcion,
        'fechaInicio': fechaInicio.toIso8601String().substring(0, 10),
        'fechaFin': fechaFin.toIso8601String().substring(0, 10),
        'estado': estado,
        if (responsableUsername != null) 'responsableUsername': responsableUsername,
      };

  Proyecto copyWith({
    int? id,
    String? nombre,
    String? descripcion,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    String? estado,
    String? responsableUsername,
    String? responsableNombre,
    int? tareasTotal,
    int? tareasHecho,
  }) =>
      Proyecto(
        id: id ?? this.id,
        nombre: nombre ?? this.nombre,
        descripcion: descripcion ?? this.descripcion,
        fechaInicio: fechaInicio ?? this.fechaInicio,
        fechaFin: fechaFin ?? this.fechaFin,
        estado: estado ?? this.estado,
        responsableUsername: responsableUsername ?? this.responsableUsername,
        responsableNombre: responsableNombre ?? this.responsableNombre,
        tareasTotal: tareasTotal ?? this.tareasTotal,
        tareasHecho: tareasHecho ?? this.tareasHecho,
      );
}
