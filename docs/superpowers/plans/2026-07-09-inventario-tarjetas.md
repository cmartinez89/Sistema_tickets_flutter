# Vista de Tarjetas para Inventario — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar la lista `ExpansionTile` de la pantalla de Inventario por una cuadrícula de tarjetas con color semáforo por estatus, y un modal de detalle al dar click, según el boceto del usuario.

**Architecture:** Se agrega `discos_info` al `SELECT` del backend (columna ya existe en BD). El modelo `Equipo` gana un campo `discos` parseado de ese JSON. `equipment_screen.dart` gana dos funciones puras de nivel superior (`colorParaEstatus`, `resumenSpecs`) para poder probarlas sin un widget test, y dos métodos nuevos en `_EquipmentScreenState` (`_tarjetaEquipo`, `_mostrarDetalle`) que reemplazan el `ListView.builder`/`ExpansionTile` actual por un `GridView.builder` + modal, siguiendo el mismo patrón ya usado en este archivo (diálogos como métodos de la clase State, no widgets separados).

**Tech Stack:** Flutter/Dart (frontend), FastAPI/pymysql (backend, solo el `SELECT`).

## Global Constraints

- Referencia: spec en `docs/superpowers/specs/2026-07-09-inventario-tarjetas-design.md`.
- Colores por estatus: `Asignado` → verde, `Disponible` → rojo, cualquier
  otro valor (`Vendido`, `Fuera de Servicio`, `Pendiente de captura`) → ámbar.
- Reemplazo completo de la lista actual — no hay toggle lista/tarjetas.
- Los botones de acción (Editar/Asignar/Liberar/Imprimir/Vender/Dar de baja)
  y sus condiciones de visibilidad exactas NO cambian, solo se mueven del
  `ExpansionTile` al modal.
- Sin cambios a los diálogos de Editar/Asignar/Vender/Dar de baja en sí
  (`_asignarHardware`, `_venderHardware`, `_darDeBajaHardware`,
  `abrirDialogoNuevoEquipo`) — se siguen llamando igual.
- Este proyecto no tiene convención de widget tests para pantallas; las
  funciones puras (lógica, no rendering) sí se prueban con `flutter test`,
  siguiendo el patrón ya usado en `test/puede_mover_tarea_test.dart`. La
  verificación visual del grid/modal es manual (Playwright contra
  producción), no un widget test.
- `main_api.py` en el servidor debe respaldarse (`cp main.py main.py.bak_...`)
  antes de cada despliegue, siguiendo la convención ya usada en este
  proyecto.

---

### Task 1: Backend — exponer `discos_info` en `GET /equipos`

**Files:**
- Modify: `main_api.py` (función `EQUIPO_SELECT`, ver contexto abajo)

**Interfaces:**
- Produces: campo `discosInfo` (string JSON o `null`) en cada objeto que
  regresa `GET /equipos`, consumido por la Task 2.

- [ ] **Step 1: Localizar `EQUIPO_SELECT` y agregar la columna**

Buscar el bloque `EQUIPO_SELECT = """..."""` en `main_api.py` (contiene
`SELECT id, folio_responsiva AS folioResponsiva, ...` y termina en
`ultimo_reporte_agente AS ultimoReporteAgente`). Agregar una línea más antes
de `FROM equipos`:

```python
           discos_info AS discosInfo
```

Quedando el final del bloque así:

```python
           ram_total_gb AS ramTotalGb, ip_local AS ipLocal,
           uptime_segundos AS uptimeSegundos, usuario_actual AS usuarioActual,
           ultimo_reporte_agente AS ultimoReporteAgente,
           discos_info AS discosInfo
    FROM equipos
"""
```

- [ ] **Step 2: Verificar sintaxis**

Run: `python -m py_compile main_api.py`
Expected: sin salida, exit code 0.

- [ ] **Step 3: Desplegar al servidor**

```bash
ssh -i llave-aws-beta.pem -o StrictHostKeyChecking=no ubuntu@54.161.41.131 "cp /home/ubuntu/api-soporte/main.py /home/ubuntu/api-soporte/main.py.bak_$(date +%Y%m%d_%H%M%S)"
scp -i llave-aws-beta.pem -o StrictHostKeyChecking=no main_api.py ubuntu@54.161.41.131:/home/ubuntu/api-soporte/main.py
ssh -i llave-aws-beta.pem -o StrictHostKeyChecking=no ubuntu@54.161.41.131 "sudo systemctl restart soporte-api.service && sleep 2 && sudo systemctl is-active soporte-api.service"
```

Expected: `active`

- [ ] **Step 4: Verificar con curl que el equipo real (id 44) trae `discosInfo`**

```bash
TOKEN=$(curl -s -X POST https://soporte.beta.com.mx/api/login -H "Content-Type: application/json" -d '{"username":"cmartinez","password":"beta123"}' | python -c "import sys,json; print(json.load(sys.stdin)['token'])")
curl -s https://soporte.beta.com.mx/api/equipos -H "Authorization: Bearer $TOKEN" | python -c "
import sys, json
data = json.load(sys.stdin)
eq = next((e for e in data if e['id']=='44'), None)
print('discosInfo:', eq.get('discosInfo'))
"
```

Expected: imprime `discosInfo: [{"unidad": "C:", ...}]` (una lista JSON, no
`None` — el equipo 44 ya tiene telemetría real reportada).

- [ ] **Step 5: Commit**

```bash
git add main_api.py
git commit -m "Add: expone discos_info en GET /equipos para la vista de tarjetas"
```

---

### Task 2: Modelo `Equipo` — campo `discos`, con TDD

**Files:**
- Modify: `lib/models/equipo_model.dart`
- Test: `test/equipo_model_test.dart` (nuevo)

**Interfaces:**
- Produces (usado por Tasks 3 y 4):
  - `class DiscoInfo { final String unidad; final double? totalGb; final double? libreGb; }`
  - `Equipo.discos` → `List<DiscoInfo>?`

- [ ] **Step 1: Escribir las pruebas (deben fallar: `DiscoInfo` no existe)**

Crear `test/equipo_model_test.dart`:

```dart
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
```

- [ ] **Step 2: Correr las pruebas y confirmar que fallan**

Run: `flutter test test/equipo_model_test.dart`
Expected: error de compilación, `Equipo` no tiene un campo/parámetro `discos`
(o `DiscoInfo` no está definido, según cómo falle primero).

- [ ] **Step 3: Implementar `DiscoInfo` y el campo `discos`**

Agregar `import 'dart:convert';` al inicio de `lib/models/equipo_model.dart`
(junto a la declaración de la clase, antes de `class Equipo`).

Agregar la clase `DiscoInfo` antes de `class Equipo`:

```dart
class DiscoInfo {
  final String unidad;
  final double? totalGb;
  final double? libreGb;

  const DiscoInfo({required this.unidad, this.totalGb, this.libreGb});

  factory DiscoInfo.fromMap(Map<String, dynamic> map) => DiscoInfo(
    unidad: map['unidad'] ?? '',
    totalGb: (map['totalGb'] as num?)?.toDouble(),
    libreGb: (map['libreGb'] as num?)?.toDouble(),
  );
}
```

En `class Equipo`, agregar el campo junto a los demás de telemetría (después
de `DateTime? ultimoReporteAgente;`):

```dart
  List<DiscoInfo>? discos;
```

En el constructor `Equipo({...})`, agregar el parámetro (después de
`this.ultimoReporteAgente,`):

```dart
    this.discos,
```

En `factory Equipo.fromMap`, agregar (después de la asignación de
`ultimoReporteAgente`):

```dart
    discos: map['discosInfo'] != null
        ? (jsonDecode(map['discosInfo']) as List)
            .map((d) => DiscoInfo.fromMap(d as Map<String, dynamic>))
            .toList()
        : null,
```

- [ ] **Step 4: Correr las pruebas y confirmar que pasan**

Run: `flutter test test/equipo_model_test.dart`
Expected: `00:0X +3: All tests passed!`

- [ ] **Step 5: Commit**

```bash
git add lib/models/equipo_model.dart test/equipo_model_test.dart
git commit -m "Add: campo discos (DiscoInfo) en el modelo Equipo, parseado de discosInfo"
```

---

### Task 3: Funciones puras `colorParaEstatus` y `resumenSpecs`, con TDD

**Files:**
- Modify: `lib/screens/equipment_screen.dart` (agrega funciones de nivel
  superior, fuera de la clase — mismo archivo, no una clase nueva)
- Test: `test/equipment_screen_test.dart` (nuevo)

**Interfaces:**
- Consumes: `Equipo`, `DiscoInfo` (Task 2).
- Produces (usado por Task 4):
  - `Color colorParaEstatus(String estatus)`
  - `String resumenSpecs(Equipo eq)`

- [ ] **Step 1: Escribir las pruebas (deben fallar: las funciones no existen)**

Crear `test/equipment_screen_test.dart`:

```dart
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
```

- [ ] **Step 2: Correr las pruebas y confirmar que fallan**

Run: `flutter test test/equipment_screen_test.dart`
Expected: error de compilación, `colorParaEstatus`/`resumenSpecs` no están
definidas.

- [ ] **Step 3: Implementar ambas funciones**

En `lib/screens/equipment_screen.dart`, agregar estas dos funciones de
**nivel superior** (fuera de cualquier clase, por ejemplo justo después de
los imports, antes de `class EquipmentScreen`):

```dart
Color colorParaEstatus(String estatus) {
  switch (estatus) {
    case 'Asignado':
      return Colors.green.shade700;
    case 'Disponible':
      return Colors.red.shade700;
    default:
      return Colors.amber.shade800;
  }
}

String resumenSpecs(Equipo eq) {
  final partes = <String>[];
  if (eq.cpuNucleos != null) partes.add('${eq.cpuNucleos} núcleos');
  if (eq.ramTotalGb != null) partes.add('${eq.ramTotalGb!.toStringAsFixed(1)} GB RAM');
  if (eq.discos != null && eq.discos!.isNotEmpty) {
    final totalGb = eq.discos!.fold<double>(0, (sum, d) => sum + (d.totalGb ?? 0));
    partes.add('${totalGb.toStringAsFixed(0)} GB disco');
  }
  if (partes.isEmpty) return 'Sin datos del agente';
  return partes.join(' • ');
}
```

- [ ] **Step 4: Correr las pruebas y confirmar que pasan**

Run: `flutter test test/equipment_screen_test.dart`
Expected: `00:0X +7: All tests passed!`

- [ ] **Step 5: Correr `flutter analyze` sobre el archivo modificado**

Run: `flutter analyze lib/screens/equipment_screen.dart`
Expected: solo los 2 issues pre-existentes ya conocidos en este archivo
(`curly_braces_in_flow_control_structures` en las líneas del `if (mounted)`
de `_darDeBajaHardware`) — ninguno nuevo introducido por este cambio.

- [ ] **Step 6: Commit**

```bash
git add lib/screens/equipment_screen.dart test/equipment_screen_test.dart
git commit -m "Add: funciones puras colorParaEstatus y resumenSpecs para la vista de tarjetas"
```

---

### Task 4: Reemplazar la lista por una cuadrícula de tarjetas

**Files:**
- Modify: `lib/screens/equipment_screen.dart`

**Interfaces:**
- Consumes: `colorParaEstatus`, `resumenSpecs` (Task 3).
- Produces (usado por Task 5): método `Widget _tarjetaEquipo(Equipo eq)` en
  `_EquipmentScreenState`, que llama a `_mostrarDetalle(eq)` en `onTap` (esa
  función se crea en la Task 5 — dejar la llamada ya escrita aquí; el
  archivo no compilará hasta que la Task 5 la agregue, lo cual es
  aceptable porque ambas tareas se hacen en la misma sesión antes de
  desplegar).

- [ ] **Step 1: Eliminar el método `_statusChip` (queda sin uso tras este cambio)**

Buscar y eliminar por completo:

```dart
  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
```

- [ ] **Step 2: Agregar el método `_tarjetaEquipo`**

Agregar este método en `_EquipmentScreenState`, junto a `_filterDropdown`
(por ejemplo, justo antes de él):

```dart
  Widget _tarjetaEquipo(Equipo eq) {
    final color = colorParaEstatus(eq.estatus);
    final titulo = eq.empleadoAsignado ?? eq.estatus;
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: InkWell(
        onTap: () => _mostrarDetalle(eq),
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(_iconForTipo(eq.tipo), color: color, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('${eq.marca} - ${eq.modelo}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              if (eq.hostname != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Hostname: ${eq.hostname}${eq.rustdesk.isNotEmpty ? ' · RustDesk: ${eq.rustdesk}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                resumenSpecs(eq),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: eq.hostname == null ? FontStyle.italic : FontStyle.normal,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
```

- [ ] **Step 3: Reemplazar el `ListView.builder` por un `GridView.builder`**

Localizar, dentro del `build()`, este bloque **completo** (empieza en
`: ListView.builder(` y termina en el `),` que cierra el `ListView.builder`,
justo antes del `),` que cierra el `Expanded`) y reemplazarlo entero:

```dart
                  : ListView.builder(
                      itemCount: lista.length,
                      itemBuilder: (_, i) {
                        final eq = lista[i];
                        final asignado = eq.estatus == 'Asignado';
                        final vendido = eq.estatus == 'Vendido';
                        final obsoleto = eq.esObsoleto;
                        final fueraServicio = obsoleto && !asignado && !vendido;

                        Color statusColor;
                        String statusLabel;
                        if (vendido) {
                          statusColor = Colors.red.shade700;
                          statusLabel = 'Vendido';
                        } else if (fueraServicio) {
                          statusColor = Colors.amber.shade800;
                          statusLabel = 'Fuera de Servicio';
                        } else if (asignado) {
                          statusColor = Colors.indigo.shade700;
                          statusLabel = 'Asignado';
                        } else {
                          statusColor = Colors.blue.shade700;
                          statusLabel = 'Disponible';
                        }

                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 5),
                          child: ExpansionTile(
                            leading: Icon(_iconForTipo(eq.tipo), color: statusColor),
                            title: Text('${eq.marca} - ${eq.modelo}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            subtitle: Text(
                              'S/N: ${eq.noSerie}${eq.folioActivo != null ? ' • Activo: ${eq.folioActivo}' : ''}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: _statusChip(statusLabel, statusColor),
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (asignado) ...[
                                      Text('Empleado: ${eq.empleadoAsignado}'),
                                      Text('Rol: ${eq.rolEmpleado}'),
                                      Text('Folio Responsiva: ${eq.folioResponsiva}'),
                                    ] else if (vendido) ...[
                                      Text('Vendido el: ${_formatFechaStr(eq.fechaVenta)}',
                                          style: const TextStyle(color: Colors.red)),
                                      if (eq.precioVenta != null)
                                        Text('Precio de venta: \$${eq.precioVenta!.toStringAsFixed(2)} MXN',
                                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                    ] else
                                      Text('Disponible (Resguardo: ${eq.empleadoAsignado ?? "Sistemas"})',
                                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
                                    const Divider(),
                                    if (eq.area != null && eq.area!.isNotEmpty)
                                      Text('Área: ${eq.area}', style: const TextStyle(fontSize: 12)),
                                    if (eq.macAddress != null && eq.macAddress!.isNotEmpty)
                                      Text('MAC: ${eq.macAddress}', style: const TextStyle(fontSize: 12)),
                                    if (eq.hostname != null) ...[
                                      const Divider(),
                                      Text('Reportado automáticamente por el agente',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
                                      const SizedBox(height: 4),
                                      Text('Hostname: ${eq.hostname}', style: const TextStyle(fontSize: 12)),
                                      if (eq.usuarioActual != null)
                                        Text('Último usuario: ${eq.usuarioActual}', style: const TextStyle(fontSize: 12)),
                                      if (eq.soNombre != null)
                                        Text('SO: ${eq.soNombre}${eq.soBuild != null ? ' (build ${eq.soBuild})' : ''}', style: const TextStyle(fontSize: 12)),
                                      if (eq.cpuModelo != null)
                                        Text('CPU: ${eq.cpuModelo}${eq.cpuNucleos != null ? ' (${eq.cpuNucleos} núcleos)' : ''}', style: const TextStyle(fontSize: 12)),
                                      if (eq.ramTotalGb != null)
                                        Text('RAM: ${eq.ramTotalGb!.toStringAsFixed(1)} GB', style: const TextStyle(fontSize: 12)),
                                      if (eq.ipLocal != null)
                                        Text('IP local: ${eq.ipLocal}', style: const TextStyle(fontSize: 12)),
                                      if (eq.uptimeFormateado != null)
                                        Text('Encendido desde hace: ${eq.uptimeFormateado}', style: const TextStyle(fontSize: 12)),
                                      if (eq.ultimoReporteAgente != null)
                                        Text('Último reporte: ${_formatFechaHora(eq.ultimoReporteAgente!)}',
                                            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                    ],
                                    Text('Especificaciones: ${eq.specifications}', style: const TextStyle(fontSize: 12)),
                                    Text('Accesorios: ${eq.accesorios}', style: const TextStyle(fontSize: 12)),
                                    Text('Año adquisición: ${eq.anoAdquisicion}', style: const TextStyle(fontSize: 12)),
                                    Text('Valor compra: \$${eq.valorAdquisicion.toStringAsFixed(2)} MXN',
                                        style: const TextStyle(fontSize: 12)),
                                    Text('Valor depreciado: \$${eq.valorActual.toStringAsFixed(2)} MXN',
                                        style: TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                    if (obsoleto && !vendido)
                                      Container(
                                        margin: const EdgeInsets.only(top: 6),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.amber.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.amber.shade300),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.warning_amber_rounded, size: 14, color: Colors.amber.shade700),
                                            const SizedBox(width: 4),
                                            Text('Equipo con 5+ años — fuera de ciclo de vida',
                                                style: TextStyle(fontSize: 11, color: Colors.amber.shade800)),
                                          ],
                                        ),
                                      ),
                                    if (_puedeGestionarActivos) ...[
                                      const Divider(),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest, foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant),
                                            onPressed: () => abrirDialogoNuevoEquipo(
                                              context: context,
                                              api: widget.api,
                                              onRefresh: widget.onRefresh,
                                              tiposDisponibles: _tiposEquipo,
                                              areas: _areasDisponibles,
                                              equipoExistente: eq,
                                            ),
                                            icon: const Icon(Icons.edit_rounded, size: 16),
                                            label: const Text('Editar', style: TextStyle(fontSize: 12)),
                                          ),
                                          if (!vendido && !asignado)
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFFE8EAF6), foregroundColor: const Color(0xFF1A2B72)),
                                              onPressed: () => _asignarHardware(eq),
                                              icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                                              label: const Text('Asignar', style: TextStyle(fontSize: 12)),
                                            ),
                                          if (asignado) ...[
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red.shade50, foregroundColor: Colors.red.shade800),
                                              onPressed: () => _liberarHardware(eq),
                                              icon: const Icon(Icons.person_remove_alt_1_rounded, size: 16),
                                              label: const Text('Liberar', style: TextStyle(fontSize: 12)),
                                            ),
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue.shade800),
                                              onPressed: () => _imprimirResponsiva(eq),
                                              icon: const Icon(Icons.print_rounded, size: 16),
                                              label: const Text('Imprimir Responsiva', style: TextStyle(fontSize: 12)),
                                            ),
                                          ],
                                          if (obsoleto && !vendido)
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.orange.shade50, foregroundColor: Colors.orange.shade800),
                                              onPressed: () => _venderHardware(eq),
                                              icon: const Icon(Icons.sell_rounded, size: 16),
                                              label: const Text('Marcar como Vendido', style: TextStyle(fontSize: 12)),
                                            ),
                                          if (!vendido)
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest, foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant),
                                              onPressed: () => _darDeBajaHardware(eq),
                                              icon: const Icon(Icons.remove_circle_outline_rounded, size: 16),
                                              label: const Text('Dar de baja', style: TextStyle(fontSize: 12)),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
```

Reemplazar **todo ese bloque, completo, tal como aparece arriba** (desde
`: ListView.builder(` hasta el `),` final que le corresponde) por:

```dart
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 320,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: 150,
                      ),
                      itemCount: lista.length,
                      itemBuilder: (_, i) => _tarjetaEquipo(lista[i]),
                    ),
```

- [ ] **Step 4: Correr `flutter analyze` — se espera un error esperado (temporal)**

Run: `flutter analyze lib/screens/equipment_screen.dart`
Expected: un error señalando que `_mostrarDetalle` no está definido — es
esperado, se agrega en la Task 5. Confirmar que NO hay ningún otro error
(el `GridView`/`_tarjetaEquipo` en sí deben compilar bien).

- [ ] **Step 5: Commit**

```bash
git add lib/screens/equipment_screen.dart
git commit -m "Refactor: reemplaza la lista ExpansionTile por una cuadricula de tarjetas"
```

(Este commit deja el proyecto sin compilar hasta la Task 5 — aceptable
dentro del mismo plan/sesión; no se despliega nada hasta que ambas tareas
estén completas.)

---

### Task 5: Modal de detalle (`_mostrarDetalle`)

**Files:**
- Modify: `lib/screens/equipment_screen.dart`

**Interfaces:**
- Consumes: `_asignarHardware`, `_liberarHardware`, `_venderHardware`,
  `_darDeBajaHardware`, `_imprimirResponsiva`, `abrirDialogoNuevoEquipo`,
  `_formatFechaStr`, `_formatFechaHora`, `_iconForTipo`, `colorParaEstatus`
  (todas ya existentes o de tareas previas).
- Produces: método `_mostrarDetalle(Equipo eq)`, resolviendo la referencia
  pendiente de la Task 4.

- [ ] **Step 1: Agregar el método `_mostrarDetalle`**

Agregar en `_EquipmentScreenState`, junto a los demás métodos de diálogo
(por ejemplo, justo antes de `_imprimirResponsiva`):

```dart
  void _mostrarDetalle(Equipo eq) {
    final asignado = eq.estatus == 'Asignado';
    final vendido = eq.estatus == 'Vendido';
    final obsoleto = eq.esObsoleto;
    final color = colorParaEstatus(eq.estatus);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(_iconForTipo(eq.tipo), color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(eq.empleadoAsignado ?? eq.estatus,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${eq.marca} - ${eq.modelo}',
                    style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                if (eq.hostname != null)
                  Text('Hostname: ${eq.hostname}', style: const TextStyle(fontSize: 12)),
                if (eq.rustdesk.isNotEmpty)
                  Text('RustDesk: ${eq.rustdesk}', style: const TextStyle(fontSize: 12)),
                if (_puedeGestionarActivos) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                            foregroundColor: Theme.of(ctx).colorScheme.onSurfaceVariant),
                        onPressed: () {
                          Navigator.pop(ctx);
                          abrirDialogoNuevoEquipo(
                            context: context,
                            api: widget.api,
                            onRefresh: widget.onRefresh,
                            tiposDisponibles: _tiposEquipo,
                            areas: _areasDisponibles,
                            equipoExistente: eq,
                          );
                        },
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: const Text('Editar', style: TextStyle(fontSize: 12)),
                      ),
                      if (!vendido && !asignado)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE8EAF6), foregroundColor: const Color(0xFF1A2B72)),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _asignarHardware(eq);
                          },
                          icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                          label: const Text('Asignar', style: TextStyle(fontSize: 12)),
                        ),
                      if (asignado) ...[
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade50, foregroundColor: Colors.red.shade800),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _liberarHardware(eq);
                          },
                          icon: const Icon(Icons.person_remove_alt_1_rounded, size: 16),
                          label: const Text('Liberar', style: TextStyle(fontSize: 12)),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade50, foregroundColor: Colors.blue.shade800),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _imprimirResponsiva(eq);
                          },
                          icon: const Icon(Icons.print_rounded, size: 16),
                          label: const Text('Imprimir Responsiva', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                      if (obsoleto && !vendido)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade50, foregroundColor: Colors.orange.shade800),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _venderHardware(eq);
                          },
                          icon: const Icon(Icons.sell_rounded, size: 16),
                          label: const Text('Marcar como Vendido', style: TextStyle(fontSize: 12)),
                        ),
                      if (!vendido)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                              foregroundColor: Theme.of(ctx).colorScheme.onSurfaceVariant),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _darDeBajaHardware(eq);
                          },
                          icon: const Icon(Icons.remove_circle_outline_rounded, size: 16),
                          label: const Text('Dar de baja', style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                ],
                const Divider(height: 24),
                if (asignado) ...[
                  Text('Empleado: ${eq.empleadoAsignado}'),
                  Text('Rol: ${eq.rolEmpleado}'),
                  Text('Folio Responsiva: ${eq.folioResponsiva}'),
                ] else if (vendido) ...[
                  Text('Vendido el: ${_formatFechaStr(eq.fechaVenta)}',
                      style: const TextStyle(color: Colors.red)),
                  if (eq.precioVenta != null)
                    Text('Precio de venta: \$${eq.precioVenta!.toStringAsFixed(2)} MXN',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ] else
                  Text('Disponible (Resguardo: ${eq.empleadoAsignado ?? "Sistemas"})',
                      style: TextStyle(color: Theme.of(ctx).colorScheme.onSurfaceVariant, fontStyle: FontStyle.italic)),
                const Divider(),
                if (eq.area != null && eq.area!.isNotEmpty)
                  Text('Área: ${eq.area}', style: const TextStyle(fontSize: 12)),
                if (eq.macAddress != null && eq.macAddress!.isNotEmpty)
                  Text('MAC: ${eq.macAddress}', style: const TextStyle(fontSize: 12)),
                if (eq.soNombre != null)
                  Text('SO: ${eq.soNombre}${eq.soBuild != null ? ' (build ${eq.soBuild})' : ''}',
                      style: const TextStyle(fontSize: 12)),
                if (eq.cpuModelo != null)
                  Text('CPU: ${eq.cpuModelo}${eq.cpuNucleos != null ? ' (${eq.cpuNucleos} núcleos)' : ''}',
                      style: const TextStyle(fontSize: 12)),
                if (eq.ipLocal != null)
                  Text('IP local: ${eq.ipLocal}', style: const TextStyle(fontSize: 12)),
                if (eq.ramTotalGb != null)
                  Text('RAM: ${eq.ramTotalGb!.toStringAsFixed(1)} GB', style: const TextStyle(fontSize: 12)),
                if (eq.discos != null)
                  for (final d in eq.discos!)
                    Text(
                      'Disco ${d.unidad}: ${d.totalGb?.toStringAsFixed(1) ?? "?"} GB total, ${d.libreGb?.toStringAsFixed(1) ?? "?"} GB libres',
                      style: const TextStyle(fontSize: 12),
                    ),
                if (eq.uptimeFormateado != null)
                  Text('Encendido desde hace: ${eq.uptimeFormateado}', style: const TextStyle(fontSize: 12)),
                if (eq.ultimoReporteAgente != null)
                  Text('Último reporte del agente: ${_formatFechaHora(eq.ultimoReporteAgente!)}',
                      style: TextStyle(fontSize: 11, color: Theme.of(ctx).colorScheme.onSurfaceVariant)),
                Text('Especificaciones: ${eq.specifications}', style: const TextStyle(fontSize: 12)),
                Text('Accesorios: ${eq.accesorios}', style: const TextStyle(fontSize: 12)),
                Text('Año adquisición: ${eq.anoAdquisicion}', style: const TextStyle(fontSize: 12)),
                Text('Valor de Adquisición: \$${eq.valorAdquisicion.toStringAsFixed(2)} MXN',
                    style: const TextStyle(fontSize: 12)),
                Text('Valor Depreciado: \$${eq.valorActual.toStringAsFixed(2)} MXN',
                    style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                if (obsoleto && !vendido)
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 14, color: Colors.amber.shade700),
                        const SizedBox(width: 4),
                        Text('Equipo con 5+ años — fuera de ciclo de vida',
                            style: TextStyle(fontSize: 11, color: Colors.amber.shade800)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }
```

- [ ] **Step 2: Correr `flutter analyze` — ya debe compilar sin errores**

Run: `flutter analyze lib/screens/equipment_screen.dart`
Expected: solo los 2 issues pre-existentes ya conocidos, cero errores,
cero issues nuevos.

- [ ] **Step 3: Correr toda la suite de tests de Flutter**

Run: `flutter test`
Expected: todos los tests pasan (incluye los de las Tasks 2 y 3, más los
preexistentes `chat_message_model_test.dart`, `theme_controller_test.dart`).

- [ ] **Step 4: Commit**

```bash
git add lib/screens/equipment_screen.dart
git commit -m "Add: modal de detalle de equipo con acciones y telemetria completa"
```

---

### Task 6: Desplegar y verificar visualmente

**Files:**
- Ninguno en el repo (build + deploy + verificación con Playwright).

**Interfaces:**
- Consumes: todo lo anterior (Tasks 1-5).

- [ ] **Step 1: Build**

```bash
flutter build web
find build/web -type f | wc -l
find build/web -iname '* 2.*'
```

Expected: 40 archivos, sin duplicados (mismo conteo que builds anteriores
de este proyecto).

- [ ] **Step 2: Backup + deploy**

```bash
ssh -i llave-aws-beta.pem -o StrictHostKeyChecking=no ubuntu@54.161.41.131 "rm -rf /home/ubuntu/web_deploy/* /home/ubuntu/web_deploy/.[!.]* 2>/dev/null; echo cleaned"
scp -i llave-aws-beta.pem -o StrictHostKeyChecking=no -r build/web/. ubuntu@54.161.41.131:/home/ubuntu/web_deploy/
ssh -i llave-aws-beta.pem -o StrictHostKeyChecking=no ubuntu@54.161.41.131 "sudo mkdir -p /var/www/soporte_backup_$(date +%Y%m%d_%H%M%S) && BK=\$(ls -dt /var/www/soporte_backup_* | head -1) && sudo cp -r /var/www/soporte/* \"\$BK/\" && sudo rm -rf /var/www/soporte/* && sudo cp -r /home/ubuntu/web_deploy/. /var/www/soporte/ && sudo chown -R www-data:www-data /var/www/soporte && sudo chmod -R a+rX /var/www/soporte && find /var/www/soporte -type f | wc -l"
```

Expected: 40 archivos en `/var/www/soporte`.

- [ ] **Step 3: Verificación visual con Playwright (login real, Admin)**

Usar el mismo patrón ya usado en este proyecto (browser Chromium headless,
`storageState` de una sesión ya loggeada si existe, o login con
`cmartinez`/`beta123`). Navegar a Equipos/Responsivas y confirmar
visualmente, con capturas de pantalla:

1. La cuadrícula de tarjetas se ve (no la lista vieja), con colores
   distintos para Asignado (verde) vs Disponible (rojo) vs otros (ámbar).
2. La tarjeta del equipo id 44 ("CoordSistemas") muestra hostname y el
   resumen de specs (núcleos, RAM, disco).
3. Una tarjeta de un equipo SIN telemetría (la mayoría de los 39 restantes)
   muestra "Sin datos del agente" en vez de líneas vacías.
4. Al dar click en la tarjeta del equipo 44, se abre el modal y muestra
   SO, CPU, IP local, RAM, disco(s), año de adquisición, valor de
   adquisición y valor depreciado.
5. Los botones de acción (Editar, Asignar/Liberar, etc.) aparecen en el
   modal y no rompen nada al probarlos (con cuidado de no dejar cambios
   de prueba en producción — cancelar en vez de confirmar, o revertir
   cualquier cambio de prueba).

- [ ] **Step 4: No hay commit para esta tarea** (solo build + despliegue +
  verificación manual; el código ya se commiteó en las tareas anteriores).

---

## Fin del plan

Con esto la pantalla de Inventario queda como cuadrícula de tarjetas con
colores semáforo y modal de detalle, según el boceto original, con la
telemetría del agente (de proyectos anteriores) totalmente integrada.
