import 'package:flutter_test/flutter_test.dart';
import 'package:soporte_beta/screens/proyecto_detalle_screen.dart';

void main() {
  test('Admin y Desarrollador Sr. pueden mover cualquier tarea; un Desarrollador solo la suya', () {
    expect(
      puedeMoverTarea(rol: 'Admin', asignadoAUsername: 'lfabela', username: 'cmartinez'),
      isTrue,
    );
    expect(
      puedeMoverTarea(rol: 'Desarrollador Sr.', asignadoAUsername: 'mgallegos', username: 'lfabela'),
      isTrue,
    );
    expect(
      puedeMoverTarea(rol: 'Desarrollador', asignadoAUsername: 'mgallegos', username: 'mgallegos'),
      isTrue,
    );
    expect(
      puedeMoverTarea(rol: 'Desarrollador', asignadoAUsername: 'lfabela', username: 'mgallegos'),
      isFalse,
    );
    expect(
      puedeMoverTarea(rol: 'Desarrollador', asignadoAUsername: null, username: 'mgallegos'),
      isFalse,
    );
  });
}
