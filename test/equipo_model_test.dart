import 'package:flutter_test/flutter_test.dart';
import 'package:soporte_beta/models/equipo_model.dart';

Map<String, dynamic> _mapaBase({String? discosInfo}) => {
  'id': '1',
  'folioResponsiva': '---',
  'tipo': 'Laptop',
  'marca': 'Dell',
  'modelo': 'Latitude',
  'noSerie': 'ABC123',
  'accesorios': '',
  'anoAdquisicion': 2024,
  'valorAdquisicion': 10000.0,
  'specifications': '',
  'estatus': 'Disponible',
  if (discosInfo != null) 'discosInfo': discosInfo,
};

void main() {
  test('Equipo.fromMap parsea discosInfo a lista de DiscoInfo', () {
    final eq = Equipo.fromMap(_mapaBase(
      discosInfo: '[{"unidad":"C:","totalGb":476.9,"libreGb":210.4}]',
    ));
    expect(eq.discos, isNotNull);
    expect(eq.discos!.length, 1);
    expect(eq.discos![0].unidad, 'C:');
    expect(eq.discos![0].totalGb, 476.9);
    expect(eq.discos![0].libreGb, 210.4);
  });

  test('Equipo.fromMap sin discosInfo deja discos en null', () {
    final eq = Equipo.fromMap(_mapaBase());
    expect(eq.discos, isNull);
  });

  test('Equipo.fromMap con discosInfo de varios discos parsea todos', () {
    final eq = Equipo.fromMap(_mapaBase(
      discosInfo: '[{"unidad":"C:","totalGb":100.0,"libreGb":50.0},{"unidad":"D:","totalGb":200.0,"libreGb":80.0}]',
    ));
    expect(eq.discos!.length, 2);
    expect(eq.discos![1].unidad, 'D:');
  });
}
