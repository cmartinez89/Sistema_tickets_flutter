# Dashboard universal (Soporte + Desarrollo) — Diseño

## Contexto

El Dashboard principal (`DashboardScreen`) hoy solo existe dentro del bloque "Soporte" de la navegación — lo ven Admin, Técnico y Técnico Sr., y solo muestra tickets, inventario de equipos y respaldos. Los roles `Desarrollador Sr.` y `Desarrollador` (agregados en la iteración anterior, ver `2026-07-02-roles-desarrollo-kanban-design.md`) no tienen Dashboard en absoluto — solo ven Proyectos, Tareas y Chat.

Se pide que el Dashboard sea universal: todo rol lo ve como pantalla de entrada, con información relevante a su dominio (soporte y/o desarrollo).

## 1. Navegación

El Dashboard deja de estar anidado dentro del bloque "Soporte" y pasa a ser la pantalla **índice 0 para todos los roles**, sin excepción.

En `main_layout.dart`:
- `_tieneSoporte` sigue controlando solo Tickets/Equipos/Respaldos (ya no incluye Dashboard).
- `_tieneDesarrollo` sigue controlando Proyectos/Tareas, sin cambios.
- Nuevo índice de chat: `_chatIndex = 1 + (_tieneSoporte ? 3 : 0) + (_tieneDesarrollo ? 2 : 0)` (el `1` es el Dashboard, siempre presente). Para Admin y Técnico/Técnico Sr. esto da el mismo valor que hoy (6 y 4 respectivamente) — sin regresión. Para Desarrollador/Desarrollador Sr. pasa de no existir a `_chatIndex = 3` (Dashboard=0, Proyectos=1, Tareas=2, Chat=3).
- El drawer gana un ítem "Dashboard" siempre visible en el índice 0, fuera de cualquier sección condicional. Las secciones "Soporte Técnico" y "Desarrollo" mantienen sus ítems existentes (Tickets/Equipos/Respaldos y Proyectos/Tareas), cuyos índices no cambian para los roles que ya los tenían.

`MainLayout` carga `_proyectos` y `_tareas` globalmente al inicio (en paralelo con `_tickets`/`_inventario`, mismo patrón ya usado), para poder alimentar el Dashboard sin importar el rol de la sesión.

`DashboardScreen.onNavigate(int)` se reemplaza por callbacks nombrados (`onNavigateTickets`, `onNavigateEquipos`, `onNavigateRespaldos`, `onNavigateProyectos`, `onNavigateTareas`) que `MainLayout` conecta a los índices correctos — así el Dashboard no necesita saber aritmética de índices, que ahora varía según el rol.

## 2. Contenido por rol

| Rol | Bloque Soporte | Bloque Desarrollo |
|---|---|---|
| Admin | ✅ (todos los tickets/equipos, como hoy) | ✅ vista global (todos los proyectos/tareas) |
| Técnico, Técnico Sr. | ✅ (sin cambios) | ❌ no se muestra |
| Desarrollador Sr. | ❌ no se muestra | ✅ vista global (todos los proyectos/tareas) |
| Desarrollador | ❌ no se muestra | ✅ vista personal ("Mis tareas": solo las tareas asignadas a él, por estado) |

Nadie ve datos de una sección a la que no tiene acceso navegable.

**Bloque Desarrollo — tarjetas (vista global, Admin/Desarrollador Sr.):**
- Proyectos activos (donut, de tareasTotal por proyecto sumado o conteo de proyectos con estado `activo`)
- Tareas por estado: Por hacer / Haciendo / En revisión / Hecho (uno o más donuts, mismo estilo que los donuts de tickets)
- Prioridad alta pendiente (tareas con prioridad `alta` y estado distinto de `hecho`)
- Lista "Proyectos recientes" (mismo componente visual que "Últimos Tickets Registrados", ordenado por fecha de creación/inicio descendente, tope 5)

**Bloque Desarrollo — tarjetas (vista personal, Desarrollador):**
- Mismas categorías de estado (Por hacer/Haciendo/En revisión/Hecho) pero filtradas a `tarea.asignadoAUsername == session.username`
- Prioridad alta pendiente, mismo filtro
- Sin lista de "proyectos recientes" (no tiene permiso de ver el listado completo de proyectos como responsable — puede seguir accediendo a la pestaña Proyectos para eso)

Cada tarjeta navega a Proyectos o Tareas al hacer clic, usando los nuevos callbacks nombrados.

## Fuera de alcance

- No se agrega ninguna tarjeta nueva al bloque Soporte existente — permanece igual.
- No se cambia el comportamiento de `_cargarDatos` más allá de agregar la carga paralela de proyectos/tareas.
- No se pagina ni se limita la cantidad de proyectos/tareas cargadas (mismo criterio que Tickets/Equipos hoy: se trae todo).

## Plan de entrega

1. Implementar cambios de Flutter (modelo de navegación, callbacks nombrados, contenido del Dashboard por rol).
2. `flutter analyze` limpio.
3. Levantar el build localmente (`flutter run -d chrome`) para que el usuario pruebe antes de subir nada.
4. Solo tras aprobación explícita: commit + push a GitHub y `deploy.ps1` a producción.
