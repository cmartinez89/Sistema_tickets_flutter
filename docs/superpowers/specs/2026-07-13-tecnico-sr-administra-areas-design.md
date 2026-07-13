# Diseño: Técnico Sr. puede administrar catálogos (Áreas)

Fecha: 2026-07-13

## Contexto

Benjamin (usuario `bcastro`) necesita poder agregar/editar/eliminar Áreas /
Departamentos. Ese catálogo ya es un recurso completo en el backend
(`GET/POST/PUT/DELETE /areas`, ver `lib/services/api_service.dart:262-280`) y
ya tiene una UI de administración (`lib/screens/admin_screen.dart`, pestaña
"Áreas" dentro de "Administración de Catálogos"), pero hoy esa pantalla
completa solo es visible para `rol == 'Admin'` (`lib/screens/main_layout.dart:60`).

El rol `'Técnico Sr.'` ya existe en el sistema (asignable desde
`users_screen.dart`, ya usado para otros permisos en `equipment_screen.dart` y
`tickets_screen.dart`). Se decide dar el permiso por rol, no por username: todo
usuario con rol `'Técnico Sr.'` gana acceso a esta pantalla.

## Alcance

Incluye:
1. Nuevo getter `_puedeAdministrarCatalogos` en `main_layout.dart`, true si
   `rol == 'Admin'` o `rol == 'Técnico Sr.'`.
2. La pantalla `AdminScreen` (Administración de Catálogos, con sus 3 pestañas
   completas: Categorías, Áreas, Tipos de Equipo) se muestra si
   `_puedeAdministrarCatalogos` es true, tanto en la lista de `screens` como en
   el ítem del `Drawer`.
3. `UsersScreen` (Gestión de Usuarios), `ReportesScreen` y `AiScreen`
   (Asistente IA) se quedan exclusivos de `_esAdmin` (sin cambios).

Fuera de alcance:
- Cambios a `admin_screen.dart` — ya muestra las 3 pestañas, no se modifica.
- Cambios al backend — los endpoints de áreas ya existen; no hay enforcement
  de permisos en servidor (mismo patrón ya usado en todo el sistema: los
  roles se verifican solo en el cliente).
- Asignar el rol `'Técnico Sr.'` a Benjamin — es un cambio de datos vía la
  pantalla "Gestión de Usuarios" (ya existente), no de código.

## Implementación

**`lib/screens/main_layout.dart`**

Nuevo getter junto a `_esAdmin`:
```dart
bool get _puedeAdministrarCatalogos =>
    widget.session.rol == 'Admin' || widget.session.rol == 'Técnico Sr.';
```

En la lista `screens`, separar el bloque hoy gateado solo por `_esAdmin`:
```dart
if (_esAdmin) ...[
  UsersScreen(...),
],
if (_puedeAdministrarCatalogos) ...[
  AdminScreen(api: _api),
],
if (_esAdmin) ...[
  ReportesScreen(...),
  AiScreen(...),
],
```

En el `Drawer`, mismo split: el `Divider` + `_sectionHeader('Administración')`
se muestra si `_puedeAdministrarCatalogos`; el ítem "Gestión de Usuarios" solo
si `_esAdmin`; el ítem "Administración" si `_puedeAdministrarCatalogos`;
"Reportes" y "Asistente IA" solo si `_esAdmin`.

Los índices de navegación (`adminOffset`, etc.) se recalculan dinámicamente
según cuáles bloques aplican para la sesión actual — mismo patrón que ya usan
`_devOffset`/`_chatIndex` para roles con `_tieneSoporte`/`_tieneDesarrollo`.

## Testing

Verificación manual (no hay convención de widget tests en este proyecto):
login como usuario con rol `'Técnico Sr.'` y confirmar que:
- Ve el ítem "Administración" en el drawer, con las 3 pestañas.
- Puede agregar/editar/eliminar un Área.
- NO ve "Gestión de Usuarios", "Reportes" ni "Asistente IA".
Login como `Admin` y confirmar que no hay regresión (ve los 4 ítems).
