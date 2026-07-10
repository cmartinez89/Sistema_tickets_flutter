import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soporte_beta/models/equipo_model.dart';
import 'package:soporte_beta/screens/equipment_screen.dart';

Equipo _equipo({
  String estatus = 'Disponible',
  int? cpuNucleos,
  double? ramTotalGb,
  List<DiscoInfo>? discos,
}) => Equipo(
  id: '1',
  folioResponsiva: '---',
  tipo: 'Laptop',
  marca: 'Dell',
  modelo: 'Latitude',
  noSerie: 'ABC123',
  accesorios: '',
  anoAdquisicion: 2024,
  valorAdquisicion: 10000.0,
  specifications: '',
  estatus: estatus,
  cpuNucleos: cpuNucleos,
  ramTotalGb: ramTotalGb,
  discos: discos,
);

void main() {
  group('colorParaEstatus', () {
    test('Asignado es verde', () {
      expect(colorParaEstatus('Asignado'), Colors.green.shade700);
    });
    test('Disponible es rojo', () {
      expect(colorParaEstatus('Disponible'), Colors.red.shade700);
    });
    test('Vendido, Fuera de Servicio y Pendiente de captura son ambar', () {
      expect(colorParaEstatus('Vendido'), Colors.amber.shade800);
      expect(colorParaEstatus('Fuera de Servicio'), Colors.amber.shade800);
      expect(colorParaEstatus('Pendiente de captura'), Colors.amber.shade800);
    });
  });

  group('resumenSpecs', () {
    test('sin ningun dato de telemetria regresa "Sin datos del agente"', () {
      expect(resumenSpecs(_equipo()), 'Sin datos del agente');
    });

    test('con cpu y ram concatena ambos', () {
      final r = resumenSpecs(_equipo(cpuNucleos: 8, ramTotalGb: 16.0));
      expect(r, '8 núcleos • 16.0 GB RAM');
    });

    test('con disco(s) suma el total y lo agrega al resumen', () {
      final r = resumenSpecs(_equipo(
        cpuNucleos: 4,
        ramTotalGb: 8.0,
        discos: const [
          DiscoInfo(unidad: 'C:', totalGb: 476.9, libreGb: 210.4),
        ],
      ));
      expect(r, '4 núcleos • 8.0 GB RAM • 477 GB disco');
    });

    test('con solo un dato no agrega separador de mas', () {
      expect(resumenSpecs(_equipo(cpuNucleos: 4)), '4 núcleos');
    });
  });
}
