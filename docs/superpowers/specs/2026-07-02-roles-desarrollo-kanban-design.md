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

## Fuera de alcance

- No se agrega enforcement de permisos en el backend (consistente con el resto del sistema).
- No se modifica el Gantt más allá de que ya respeta `_puedeEditar` (los desarrolladores no arrastran fechas ahí, solo ven).
- No se toca el flujo de creación de proyectos más allá de gatear `_puedeEditar` con el nuevo nombre de rol.

## Plan de entrega

1. Implementar cambios de Flutter (roles, Kanban, filtros, diálogo de detalle).
2. `flutter analyze` limpio.
3. Levantar el build localmente (`flutter run -d chrome`) para que el usuario pruebe antes de subir nada.
4. Solo tras aprobación explícita: commit + push a GitHub y `deploy.ps1` a producción.
5. Alta de los 4 usuarios en la base de datos de producción.
