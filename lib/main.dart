import 'package:flutter/material.dart';
import 'models/session_model.dart';
import 'screens/login_screen.dart';
import 'screens/main_layout.dart';
import 'services/notification_service.dart';

void main() {
  runApp(const SoporteBetaApp());
}

class SoporteBetaApp extends StatelessWidget {
  const SoporteBetaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Soporte Beta',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00695C),
          primary: const Color(0xFF00695C),
        ),
        useMaterial3: true,
      ),
      home: const _SplashRouter(),
    );
  }
}

class _SplashRouter extends StatefulWidget {
  const _SplashRouter();

  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _resolver();
  }

  Future<void> _resolver() async {
    final session = await Session.restaurar();
    if (session != null && mounted) {
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
          MaterialPageRoute(builder: (_) => MainLayout(session: session, notifService: notifService)),
        );
        return;
      }
    }
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
        ),
      );
    }
    return const LoginScreen();
  }
}
