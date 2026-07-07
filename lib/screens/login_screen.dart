import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/session_model.dart';
import '../services/api_service.dart' as api_service;
import '../services/notification_service.dart';
import 'main_layout.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<bool> _mostrarDialogoCambioPassword(String username, String token) async {
    final nuevaCtrl = TextEditingController();
    final confirmarCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool guardando = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Cambia tu contraseña', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tu contraseña fue reseteada por el administrador. Por seguridad, elige una nueva contraseña para continuar.',
                  style: TextStyle(fontSize: 13, color: Colors.blueGrey),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: nuevaCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nueva contraseña',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmarCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirmar contraseña',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_reset_outlined),
                  ),
                  validator: (v) {
                    if (v != nuevaCtrl.text) return 'Las contraseñas no coinciden';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            guardando
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC0026),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      setStateDialog(() => guardando = true);
                      try {
                        final tmpApi = api_service.ApiService(token: token);
                        await tmpApi.cambiarPassword(username, nuevaCtrl.text.trim());
                        if (ctx.mounted) Navigator.of(ctx).pop(true);
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                          );
                        }
                        setStateDialog(() => guardando = false);
                      }
                    },
                    child: const Text('Guardar y continuar'),
                  ),
          ],
        ),
      ),
    );

    nuevaCtrl.dispose();
    confirmarCtrl.dispose();
    return result == true;
  }

  void _mostrarOlvideContrasena() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Olvidaste tu contraseña?'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Contacta al administrador del sistema para restablecer tu contraseña.'),
            SizedBox(height: 12),
            Text('El administrador puede actualizar tu contraseña desde el Panel de Gestión de Usuarios.', style: TextStyle(color: Colors.blueGrey, fontSize: 13)),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    // Acepta "cmartinez" o "cmartinez@beta.com.mx" → normaliza al prefijo
    String input = _userCtrl.text.trim().toLowerCase();
    if (input.contains('@')) {
      input = input.split('@').first;
    }

    try {
      final response = await http.post(
        Uri.parse('${api_service.kApiUrl}/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': input,
          'password': _passCtrl.text,
        }),
      ).timeout(api_service.kTimeout);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final session = Session(
          username: data['username'],
          nombreCompleto: data['nombreCompleto'],
          rol: data['rol'],
          token: data['token'] ?? '',
        );

        if (data['forzarCambioPassword'] == true && mounted) {
          final cambiada = await _mostrarDialogoCambioPassword(session.username, session.token);
          if (!cambiada) return;
        }

        await session.guardar();

        await NotificationService.solicitarPermiso();
        final notifService = NotificationService(
          username: session.username,
          rol: session.rol,
          token: session.token,
        );
        notifService.iniciar();

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MainLayout(session: session, notifService: notifService),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credenciales incorrectas'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de conexión: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const navy = Color(0xFF1A2B72);
    const red = Color(0xFFDC0026);
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Header con logo fuera de la card
                Image.asset('assets/logo.png', height: 80),
                const SizedBox(height: 12),
                const Text(
                  'Beta Systems',
                  style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: navy, letterSpacing: 0.5),
                ),
                const Text(
                  'Sistema de Soporte TI',
                  style: TextStyle(fontSize: 13, color: Colors.blueGrey),
                ),
                const SizedBox(height: 28),
                Card(
                  elevation: 4,
                  shadowColor: Colors.black26,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 400),
                    padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Iniciar sesión',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: navy)),
                          const SizedBox(height: 4),
                          const Text('Ingresa tus credenciales para continuar',
                              style: TextStyle(fontSize: 12, color: Colors.blueGrey)),
                          const SizedBox(height: 24),
                      TextFormField(
                        controller: _userCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Usuario o correo',
                          hintText: 'cmartinez o cmartinez@beta.com.mx',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock_outline_rounded),
                        ),
                        onFieldSubmitted: (_) => _handleLogin(),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _mostrarOlvideContrasena,
                          child: const Text('¿Olvidaste tu contraseña?'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: red,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Ingresar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}