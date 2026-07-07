import 'package:flutter/material.dart';
import 'models/session_model.dart';
import 'screens/login_screen.dart';
import 'screens/main_layout.dart';
import 'services/notification_service.dart';
import 'services/theme_controller.dart';
import 'utils/notif_helper.dart';
import 'firebase_options.dart';

final themeController = ThemeController();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await themeController.cargar();
  await initPlatformServices(DefaultFirebaseOptions.currentPlatform);
  runApp(const SoporteBetaApp());
}

ThemeData _construirTema(Brightness brightness) => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1A2B72),
        primary: const Color(0xFF1A2B72),
        secondary: const Color(0xFFDC0026),
        brightness: brightness,
      ),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1A2B72),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A2B72),
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF1A2B72),
        foregroundColor: Colors.white,
      ),
    );

class SoporteBetaApp extends StatelessWidget {
  const SoporteBetaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) => MaterialApp(
        title: 'Soporte Beta',
        debugShowCheckedModeBanner: false,
        theme: _construirTema(Brightness.light),
        darkTheme: _construirTema(Brightness.dark),
        themeMode: themeController.mode,
        home: const _SplashRouter(),
      ),
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
