class Usuario {
  final String username;
  final String email;
  final String nombreCompleto;
  final String rol;

  const Usuario({
    required this.username,
    required this.email,
    required this.nombreCompleto,
    required this.rol,
  });

  factory Usuario.fromMap(Map<String, dynamic> map) => Usuario(
        username: map['username'] ?? '',
        email: map['email'] ?? '',
        nombreCompleto: map['nombreCompleto'] ?? '',
        rol: map['rol'] ?? 'Técnico',
      );

  String get inicial => nombreCompleto.isNotEmpty ? nombreCompleto[0].toUpperCase() : '?';
}
