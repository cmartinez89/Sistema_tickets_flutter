# Roles de Desarrollo y mejoras al Kanban — Diseño

## Contexto

El sistema ya tiene un módulo de Proyectos/Tareas (Kanban + Gantt) usado hoy solo por Admin. Se necesita abrir ese módulo a dos nuevos perfiles — Desarrollador Sr. y Desarrollador — con permisos distintos, y corregir un bug donde no hay forma de ver el detalle de una tarea sin ser editor.

El código ya tenía roles sin usar (`Enc. Desarrollo`, `Desarrollador`, `Solo Desarrollo`) con lógica parcial. Ningún usuario en la base de datos de producción tiene esos roles hoy, así que se pueden renombrar/limpiar sin riesgo de romper cuentas existentes.

## 1. Roles y navegación

- `Enc. Desarrollo` se renombra a **`Desarrollador Sr.`** (consistente con la convención `Técnico Sr.`).
- Se elimina la opción de rol `Solo Desarrollo` del formulario de alta de usuarios (redundante tras este cambio).
- `Desarrollador Sr.` y `Desarrollador` ven **únicamente** las pestañas Proyectos y Tareas en el menú lateral. No ven Dashboard, Tickets, Equipos, Respaldos ni Chat (ni el botón flotante de chat).
- Admin conserva acceso total sin cambios.

En `main_layout.dart`:
- `tieneSoporte` pasa de `rol != 'Solo Desarrollo'` a `rol != 'Desarrollador Sr.' && rol != 'Desarrollador'`.
- `tieneDesarrollo` pasa a `rol == 'Admin' || rol == 'Desarrollador Sr.' || rol == 'Desarrollador'`.

## 2. Permisos dentro de Proyectos/Tareas

| Acción | Admin | Desarrollador Sr. | Desarrollador |
|---|---|---|---|
| Crear/editar/eliminar proyectos | ✅ | ✅ | ❌ |
| Crear/editar/eliminar tareas | ✅ | ✅ | ❌ |
| Ver todas las tareas del proyecto | ✅ | ✅ | ✅ |
| Mover (drag) cualquier tarea en Kanban | ✅ | ✅ | ❌ |
| Mover (drag) solo sus tareas asignadas | — | — | ✅ |
| Ver detalle de cualquier tarea (click) | ✅ | ✅ | ✅ |
| Editar fechas en Gantt | ✅ | ✅ | ❌ (ya gateado por `_puedeEditar`) |

`_puedeEditar` (ya existente en `proyecto_detalle_screen.dart` y `proyectos_screen.dart`) pasa a comprobar `rol == 'Admin' || rol == 'Desarrollador Sr.'`.

Nueva regla de movimiento en el Kanban, independiente de `_puedeEditar`:
```
bool puedeMover(Tarea t) =>
    _puedeEditar || t.asignadoAUsername == session.username;
```

No se agrega enforcement en el backend — el resto del sistema (p. ej. `Técnico Sr.` vs `Técnico`) ya sigue el mismo patrón de confiar en el cliente para estas reglas dentro de una herramienta interna.

## 3. Tarjeta de tarea en el Kanban

Hoy la tarjeta solo tiene iconos pequeños de editar/eliminar (visibles solo si `_puedeEditar`), y no hay forma de ver la descripción completa de una tarea si no se tiene permiso de edición.

Cambios:
- Toda la tarjeta se vuelve tappable. El tap abre un diálogo `_DialogoVerTarea` de solo lectura con: título, descripción completa, estado, prioridad, asignado a, fecha inicio, fecha fin. Disponible para los tres roles.
- Dentro de `_DialogoVerTarea`, si `puedeEditar` es true, se muestran botones "Editar" (abre `_DialogoTarea` existente) y "Eliminar" (flujo de confirmación existente). Si no, el diálogo solo tiene "Cerrar".
- Se quitan los iconos sueltos de editar/eliminar de la cara de la tarjeta (ya no son necesarios: la vista es el único punto de entrada).
- La tarjeta agrega una fila con fecha inicio → fecha fin (formato `dd/mm` como en `_TareaFila`), siempre visible.
- La tarjeta solo se envuelve en `Draggable<Tarea>` cuando `puedeMover(tarea)` es true; si no, se renderiza estática (sigue siendo tappable para ver detalle).
- Cuando el rol es `Desarrollador` y la tarea NO está asignada a él, la tarjeta se pinta grayscale/opacidad reducida (aplicando `ColorFiltered` con matriz de saturación 0, u opacidad ~0.55 sobre el `_CardBody`) para diferenciarla visualmente de las suyas.

## 4. Filtros en la vista Kanban

Se agrega una barra de filtros arriba de las columnas del Kanban (dentro de la pestaña Kanban, no afecta Gantt):
- Buscador de texto libre (filtra por título/descripción, case-insensitive).
- Chip "Asignado a" — dropdown con los usuarios que tienen al menos una tarea en el proyecto, más "Todos".
- Chip "Prioridad" — alta/media/baja/Todas.

El estado no se filtra ahí porque ya se ve por columna. Los filtros solo afectan qué tarjetas se muestran; no tocan el backend (se filtra en memoria sobre `_tareas`, igual que en `tareas_screen.dart`).

## 5. Asignación de tareas

El dropdown "Asignar a" en `_DialogoTarea` se filtra para mostrar solo usuarios con `rol == 'Desarrollador' || rol == 'Desarrollador Sr.'`, en vez de todos los usuarios del sistema.

## 6. Alta de usuarios

Se crean directamente en la base de datos de producción (mismo hash bcrypt que usa `POST /usuarios`), sin tocar el flujo del admin en la UI:

| Nombre | Username | Password | Rol | Email |
|---|---|---|---|---|
| Luis Fabela | `lfabela` | `123456` | Desarrollador Sr. | lfabela@beta.com.mx |
| Mariana Gallegos | `mgallegos` | `123456` | Desarrollador | mgallegos@beta.com.mx |
| Elizabeth Rodríguez | `llira` | `123456` | Desarrollador | llira@beta.com.mx |
| Angel Medina | `amedina` | `123456` | Desarrollador | amedina@beta.com.mx |

## 7. Tres canales de chat (Soporte / Desarrollo / General)

Hoy hay un solo chat interno global. Se necesita separar por audiencia sin perder el historial actual.

**Modelo de datos:** se agrega la columna `canal VARCHAR(20) NOT NULL DEFAULT 'soporte'` a la tabla `mensajes`. Los mensajes existentes quedan como `soporte` (es el chat que ya existía). Se valida en el backend que `canal` sea uno de `soporte` | `desarrollo` | `general` (rechazar con 400 si no).

**Acceso por rol:**

| Rol | Canales visibles |
|---|---|
| Admin | Soporte, Desarrollo, General |
| Técnico, Técnico Sr. | Soporte, General |
| Desarrollador, Desarrollador Sr. | Desarrollo, General |

El chat deja de depender de `tieneSoporte`: pasa a ser un acceso independiente que **todo** usuario tiene (con el subconjunto de canales de su rol), incluyendo el botón flotante de acceso rápido. Esto implica recalcular los índices de navegación en `main_layout.dart` (hoy el chat vive dentro del bloque de Soporte en una posición fija).

**Backend:**
- `GET /mensajes` devuelve todos los mensajes (con su `canal`) sin filtrar por query param — el volumen actual (~28 mensajes históricos) no justifica paginar por canal todavía; el cliente separa por canal en memoria.
- `POST /mensajes` requiere `canal` en el body, lo valida y lo guarda; el payload de broadcast por WebSocket incluye `canal` para que cada cliente decida si le corresponde.
- `DELETE /mensajes/{id}` no cambia.

**Frontend:**
- `ChatMessage` agrega el campo `canal`.
- `ChatScreen` recibe la lista de canales disponibles para la sesión; si hay más de uno, muestra pestañas arriba para cambiar de canal (orden: canal principal del rol primero, General al final). Enviar un mensaje usa el canal activo.
- El badge de no leídos sigue siendo un solo contador agregado (no por canal) — no se pide desglose por canal en esta iteración.
- Las notificaciones de mensaje nuevo solo se disparan si el canal del mensaje entrante es uno de los canales visibles para el usuario.

## Fuera de alcance

- No se agrega enforcement de permisos en el backend para Kanban/proyectos (consistente con el resto del sistema).
- No se modifica el Gantt más allá de que ya respeta `_puedeEditar` (los desarrolladores no arrastran fechas ahí, solo ven).
- No se toca el flujo de creación de proyectos más allá de gatear `_puedeEditar` con el nuevo nombre de rol.
- No hay badge de no leídos por canal, ni límite de mensajes por canal — se revisará si el volumen de mensajes crece mucho.

## Plan de entrega

1. Implementar cambios de backend (migración `canal`, validación, broadcast).
2. Implementar cambios de Flutter (roles, Kanban, filtros, diálogo de detalle, chats por canal).
3. `flutter analyze` limpio.
4. Levantar el build localmente (`flutter run -d chrome`) para que el usuario pruebe antes de subir nada.
5. Solo tras aprobación explícita: commit + push a GitHub, migración en la base de producción y `deploy.ps1`.
6. Alta de los 4 usuarios en la base de datos de producción.
