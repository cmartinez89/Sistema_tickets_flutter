# Diseño: Vista de tarjetas para Inventario (Equipos/Responsivas)

Fecha: 2026-07-09

## Contexto

La pantalla de Inventario (`lib/screens/equipment_screen.dart`) hoy muestra los
equipos como una lista vertical de `ExpansionTile` (una fila que se expande
hacia abajo con el detalle). El usuario pidió, con un boceto a mano, cambiar
esto por una cuadrícula de tarjetas con colores tipo semáforo según el
estatus, y que al dar click se abra un modal con el detalle completo.

Este proyecto también expone un dato que hoy no se manda al frontend: la
información de disco(s) (`discos_info`), reportada por el agente de
inventario (ver `docs/superpowers/specs/2026-07-08-agente-inventario-windows-design.md`)
pero deliberadamente omitida del `SELECT` la vez pasada por simplicidad. El
usuario ahora pidió mostrar disco en la tarjeta, así que se agrega.

## Alcance

Incluye:
1. Backend: exponer `discos_info` en `GET /equipos` (columna ya existe en
   `equipos` desde la migración del agente; solo falta el `SELECT`).
2. Frontend: nuevo campo `discos` en el modelo `Equipo` (parseado del JSON).
3. Frontend: reemplazar la lista `ExpansionTile` por una cuadrícula de
   tarjetas (`GridView`) con color según estatus.
4. Frontend: nuevo modal de detalle que se abre al dar click en una tarjeta,
   con los botones de acción que hoy viven en el `ExpansionTile` (Editar,
   Asignar/Liberar, Imprimir Responsiva, Dar de baja) y el detalle completo.

Fuera de alcance:
- Cualquier cambio a los diálogos de Editar/Asignar/Liberar/Vender/Dar de
  baja en sí — se siguen abriendo igual, solo cambia desde dónde se
  disparan (antes: botones en el `ExpansionTile`; ahora: botones en el
  modal).
- Alternar entre vista de lista y vista de tarjetas — la cuadrícula
  reemplaza la lista por completo, no hay tarjeta+lista simultáneas.
- Cambios a la lógica de negocio de estatus/depreciación/etc.

## 1. Backend: exponer disco(s)

Modificar `EQUIPO_SELECT` en `main_api.py` para agregar:
```sql
discos_info AS discosInfo
```
Sin cambios a `_build_equipo` — pymysql regresa las columnas `JSON` de MySQL
como texto (string), así que `discosInfo` llega al frontend como un string
JSON (ej. `'[{"unidad": "C:", "totalGb": 476.9, "libreGb": 210.4}]'`) o
`null` si el equipo no tiene telemetría. El parseo lo hace el frontend.

## 2. Modelo `Equipo`: campo `discos`

Nuevo campo `List<DiscoInfo>? discos` (o una lista simple de mapas) en
`lib/models/equipo_model.dart`, parseado con `jsonDecode` del string
`discosInfo` si no es nulo. Se usa un mini-modelo `DiscoInfo` con
`unidad`, `totalGb`, `libreGb` (mismos nombres que ya usa el agente/backend,
ver spec del agente).

## 3. Tarjeta (`_TarjetaEquipo`)

**Color de fondo (semáforo), según `estatus`:**

| Estatus | Color |
|---|---|
| `Asignado` | Verde |
| `Disponible` | Rojo |
| Cualquier otro (`Vendido`, `Fuera de Servicio`, `Pendiente de captura`) | Ámbar |

Implementación: tinte de fondo suave (alpha ~0.12-0.15 sobre el color base)
más una barra sólida de acento a la izquierda (~4px) con el color completo —
así se ve "marcado" sin sacrificar legibilidad ni contraste en modo oscuro
(el tinte se calcula sobre el color base, no un hex fijo, para que siga
funcionando con el sistema de temas ya existente en la app).

**Contenido de la tarjeta:**
1. Título: `empleadoAsignado` si existe: si no, el propio `estatus`
   ("Disponible", "Vendido", "Fuera de Servicio", "Pendiente de captura").
2. Línea 2 (solo si `hostname` no es nulo): `Hostname: <hostname>` — si
   además hay `rustdesk` no vacío, se concatena: `Hostname: X · RustDesk: Y`.
3. Línea 3 (resumen de specs):
   - Si hay datos de telemetría (`cpuNucleos`, `ramTotalGb`, o `discos` no
     nulos): concatenar lo que exista, ej.
     `"8 núcleos • 16.0 GB RAM • 476.9 GB disco"`.
   - Si NO hay ningún dato de telemetría (equipo dado de alta a mano, sin
     agente instalado): una sola línea, `"Sin datos del agente"`, en
     itálica/gris.

Al tocar la tarjeta (`onTap`), se abre el modal.

**Layout de la cuadrícula:** `GridView.builder` con
`SliverGridDelegateWithMaxCrossAxisExtent` (ancho máximo por tarjeta fijo,
ej. 320px) para que el número de columnas se ajuste solo al ancho de
pantalla disponible, en vez de un número fijo de columnas.

## 4. Modal (`_ModalDetalleEquipo`)

Se abre con `showDialog`. Estructura:

**Header:**
- Usuario asignado (o "Sin asignar")
- Hostname (si existe)
- RustDesk ID (si existe)
- Marca + modelo del equipo
- Fila de botones de acción, visible solo si `_puedeGestionarActivos`
  (rol `Admin` o `Técnico Sr.`), con las mismas condiciones exactas que ya
  existen hoy (`equipment_screen.dart:662-722`), solo movidas al modal:
  - **Editar** — siempre visible.
  - **Asignar** — si `!vendido && !asignado`.
  - **Liberar** + **Imprimir Responsiva** — si `asignado`.
  - **Marcar como Vendido** — si `obsoleto && !vendido` (5+ años).
  - **Dar de baja** — si `!vendido`.
- El aviso de "Equipo con 5+ años — fuera de ciclo de vida"
  (`equipment_screen.dart:642-661`, si `obsoleto && !vendido`) se conserva,
  mostrado en la sección de detalle.

**Detalle (sección "dinámica"):**
- SO (`soNombre` + `soBuild`)
- MAC (`macAddress`)
- CPU (`cpuModelo` + `cpuNucleos`)
- IP Local (`ipLocal`)
- RAM (`ramTotalGb`)
- Disco(s) (`discos` — una línea por unidad: `C: — 476.9 GB total, 210.4 GB
  libres`)
- Año de adquisición (`anoAdquisicion`)
- Valor de Adquisición (`valorAdquisicion`)
- Valor Depreciado (`valorActual`, ya existe como getter en el modelo)
- Último reporte del agente (`ultimoReporteAgente`), si existe

Cualquier campo sin dato se omite (no se muestra una fila vacía o "N/A"
salvo donde ya sea la convención existente, ej. folio de activo).

## Fuera de alcance (recordatorio)

- Toggle lista/tarjetas.
- Cambios a los diálogos de edición/asignación/venta/baja.
- Cambios al backend más allá de exponer `discos_info`.
