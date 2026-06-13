class Equipo {
  final String id;
  String folioResponsiva;
  final String tipo;
  final String marca;
  final String modelo;
  final String noSerie;
  final String accesorios;
  final int anoAdquisicion;
  final double valorAdquisicion;
  final String specifications;
  String estatus;
  String? empleadoAsignado;
  String? rolEmpleado;
  String ubicacion;
  String anydesk;
  String rustdesk;
  DateTime? ultimoRespaldo;
  String comentarios;

  Equipo({
    required this.id,
    required this.folioResponsiva,
    required this.tipo,
    required this.marca,
    required this.modelo,
    required this.noSerie,
    required this.accesorios,
    required this.anoAdquisicion,
    required this.valorAdquisicion,
    required this.specifications,
    required this.estatus,
    this.empleadoAsignado,
    this.rolEmpleado,
    this.ubicacion = 'Beta',
    this.anydesk = '',
    this.rustdesk = '',
    this.ultimoRespaldo,
    this.comentarios = '',
  });

  int? get diasUltimoRespaldo {
    if (ultimoRespaldo == null) return null;
    return DateTime.now().difference(ultimoRespaldo!).inDays;
  }

  double get valorActual {
    final int anos = DateTime.now().year - anoAdquisicion;
    if (anos <= 0) return valorAdquisicion;
    if (anos >= 5) return valorAdquisicion * 0.20;
    return valorAdquisicion * (1.0 - anos * 0.20);
  }

  factory Equipo.fromMap(Map<String, dynamic> map) => Equipo(
    id: map['id'],
    folioResponsiva: map['folioResponsiva'] ?? '---',
    tipo: map['tipo'] ?? 'Desktop',
    marca: map['marca'] ?? '',
    modelo: map['modelo'] ?? '',
    noSerie: map['noSerie'] ?? '',
    accesorios: map['accesorios'] ?? '',
    anoAdquisicion: map['anoAdquisicion'] ?? DateTime.now().year,
    valorAdquisicion: (map['valorAdquisicion'] ?? 0).toDouble(),
    specifications: map['specifications'] ?? '',
    estatus: map['estatus'] ?? 'Disponible',
    empleadoAsignado: map['empleadoAsignado'],
    rolEmpleado: map['rolEmpleado'],
    ubicacion: map['ubicacion'] ?? 'Beta',
    anydesk: map['anydesk'] ?? '',
    rustdesk: map['rustdesk'] ?? '',
    ultimoRespaldo: map['ultimoRespaldo'] != null
        ? DateTime.parse(map['ultimoRespaldo'])
        : null,
    comentarios: map['comentarios'] ?? '',
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'folioResponsiva': folioResponsiva,
    'tipo': tipo,
    'marca': marca,
    'modelo': modelo,
    'noSerie': noSerie,
    'accesorios': accesorios,
    'anoAdquisicion': anoAdquisicion,
    'valorAdquisicion': valorAdquisicion,
    'specifications': specifications,
    'estatus': estatus,
    'empleadoAsignado': empleadoAsignado,
    'rolEmpleado': rolEmpleado,
    'ubicacion': ubicacion,
    'anydesk': anydesk,
    'rustdesk': rustdesk,
    if (ultimoRespaldo != null) 'ultimoRespaldo': ultimoRespaldo!.toIso8601String(),
    'comentarios': comentarios,
  };
}