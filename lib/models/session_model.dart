class Session {
  final String username;
  final String nombreCompleto;
  final String rol;
  final String token;

  Session({
    required this.username,
    required this.nombreCompleto,
    required this.rol,
    required this.token,
  });
}