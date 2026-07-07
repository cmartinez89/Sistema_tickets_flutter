import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soporte_beta/services/theme_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('por defecto usa ThemeMode.system', () async {
    final controller = ThemeController();
    await controller.cargar();
    expect(controller.mode, ThemeMode.system);
  });

  test('cambiar() persiste y notifica el nuevo modo', () async {
    final controller = ThemeController();
    await controller.cargar();
    var notificado = false;
    controller.addListener(() => notificado = true);

    await controller.cambiar(ThemeMode.dark);

    expect(controller.mode, ThemeMode.dark);
    expect(notificado, true);

    final controller2 = ThemeController();
    await controller2.cargar();
    expect(controller2.mode, ThemeMode.dark);
  });
}
