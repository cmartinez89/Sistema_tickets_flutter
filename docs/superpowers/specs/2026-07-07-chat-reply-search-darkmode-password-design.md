# Diseño: Responder/buscar en chat, modo oscuro, y fixes de contraseña/usuario

Fecha: 2026-07-07

## Contexto

Tres cambios independientes solicitados en una sola sesión de trabajo, agrupados en un solo paquete de implementación y despliegue:

1. Chat: responder a un mensaje (como WhatsApp) y buscar mensajes dentro de un canal.
2. Modo oscuro elegante y consistente en toda la app.
3. Bug de "cambiar contraseña al primer login" + habilitar cambio de nombre de usuario (solo Admin).

Hallazgos de la exploración previa (ver detalle en la conversación, no repetidos aquí):
- No existe ninguna función de reply/quote ni de búsqueda en el chat.
- No existe ningún tema oscuro, toggle, ni persistencia de tema. Hay ~197 colores fijos (`Colors.white`, `Colors.black87`, hex) en 16 archivos de `lib/screens`.
- El diálogo de cambio de contraseña de primer login valida mínimo 4 caracteres; el backend exige 6 → error confuso post-envío.
- El backend nunca activa `forzar_cambio_password` cuando un Admin resetea la contraseña de otro usuario desde el panel — por eso el flujo de "cambiar contraseña al primer login" no se dispara tras un reseteo de Admin.
- El campo username está deshabilitado a propósito al editar un usuario existente (`users_screen.dart`); el backend no soporta renombrar usernames. El username se referencia además en `tickets.usuario`, `tickets.asignado_a`, `ticket_comentarios.usuario`, `mensajes.de_usuario`, `mensajes.borrado_por`, `proyectos.responsable_username`, `tareas.asignado_a_username`.

## 1. Chat: responder + buscar

### Modelo y backend
- Nueva columna `respuesta_a INT NULL` en tabla `mensajes` (migración `ALTER TABLE` manual en el servidor, una sola vez).
- `MensajeRequest` (backend): nuevo campo opcional `respuestaA: Optional[int] = None`.
- `POST /mensajes`: inserta `respuesta_a`, lo incluye en el payload del broadcast WS.
- `GET /mensajes`: el SELECT incluye `respuesta_a AS respuestaA`.
- `ChatMessage` (frontend): nuevo campo `int? respuestaA`, parseado en `fromMap`/enviado en `toMap` si aplica.

### UI — Responder
- Gesto de swipe horizontal sobre la burbuja (`GestureDetector.onHorizontalDragUpdate/End`, sin paquetes nuevos) dispara "modo respuesta" al superar un umbral de arrastre.
- Barra de "respondiendo a…" arriba del `TextField` de envío: muestra autor + texto truncado del mensaje citado, con botón "x" para cancelar.
- Al enviar, se manda `respuestaA` con el id del mensaje citado; se limpia el modo respuesta.
- Burbujas con `respuestaA != null` muestran un recuadro citado (autor + texto truncado) arriba del texto del mensaje. Se busca el mensaje original en la lista ya cargada del canal (`_mensajesDelCanal`); si no está (fuera de los últimos 200), se muestra "Mensaje original no disponible". Tocar el recuadro citado, si el original está cargado, hace scroll y resalta esa burbuja brevemente.

### UI — Buscar
- Ícono de lupa en la AppBar del chat (por canal activo) alterna el título por un `TextField` de búsqueda.
- Filtro 100% en cliente sobre los mensajes ya cargados del canal actual (case-insensitive, substring sobre `texto`).
- Contador de coincidencias ("2/7") y flechas arriba/abajo para saltar entre ellas, con scroll automático a la burbuja y resaltado momentáneo (flash de fondo).
- Sin cambios de backend (alcance: mensajes ya cargados, hoy los últimos 200 mezclados entre canales — suficiente para el caso de uso actual).

## 2. Modo oscuro

### Infraestructura
- `ThemeController` (ChangeNotifier) en `lib/services/theme_controller.dart` (o similar): estado `ThemeMode` (system/light/dark), persistido en `SharedPreferences` bajo una clave propia (mismo mecanismo que ya usa `Session`, sin dependencias nuevas).
- Se carga el valor persistido antes del primer frame (en `main()`, junto al patrón existente de `_SplashRouter`).
- `main.dart`: `MaterialApp` pasa a reconstruirse (via `ListenableBuilder`/`AnimatedBuilder` sobre el controller) con `theme:` (claro, existente) + `darkTheme:` (nuevo, mismo seed color con `Brightness.dark`) + `themeMode: controller.mode`.

### Control de usuario
- Nueva entrada "Apariencia" en el Drawer de `MainLayout`, abre un diálogo simple con 3 opciones (Claro/Oscuro/Sistema) vía radio buttons. No se crea una pantalla de Ajustes nueva.

### Cobertura de estilos
- Barrido completo de los 16 archivos con colores fijos identificados (`chat_screen.dart`, `dashboard_screen.dart`, `proyecto_detalle_screen.dart`, `main_layout.dart`, `login_screen.dart`, `tickets_screen.dart`, `equipment_screen.dart`, `admin_screen.dart`, `reportes_screen.dart`, `tareas_screen.dart`, `users_screen.dart`, `proyectos_screen.dart`, `backups_screen.dart`, `dialogo_nuevo_equipo.dart`, `ai_screen.dart`, y el propio `main.dart`), reemplazando `Colors.white` / `Colors.black87` / hex fijos por `Theme.of(context).colorScheme.*` equivalentes (`surface`, `onSurface`, `surfaceContainerHighest`, `primaryContainer`, etc.).
- Caso especial burbujas de chat: la burbuja propia mantiene un acento de color (ej. `primaryContainer`) en ambos temas; las de otros usuarios usan `surfaceContainerHighest` para verse bien en oscuro.
- Verificación visual manual (Chrome, toggle claro/oscuro) en Chat, Dashboard, Tickets, Login, Equipos, y revisión rápida del resto de pantallas para confirmar que no queden fondos/textos ilegibles.

## 3. Contraseña y nombre de usuario

### Fix de validación (primer login)
- `login_screen.dart`: el mínimo de la validación de nueva contraseña pasa de 4 a 6 caracteres, con texto de ayuda alineado al backend ("mínimo 6 caracteres").

### Fix del flag de cambio forzado
- Backend, endpoint `PUT /usuarios/{username}` (reseteo de contraseña por Admin): cuando `req.password` viene con valor, el mismo UPDATE que cambia el hash también pone `forzar_cambio_password = 1`. Esto hace que el usuario afectado sea forzado a cambiar su contraseña en su próximo login, como ya indica el mensaje del propio login screen.

### Cambiar nombre de usuario (solo Admin)
- Backend: nuevo campo opcional `nuevoUsername: Optional[str]` en `UsuarioUpdateRequest`. Al recibirlo (y ser distinto del actual), dentro de una transacción:
  1. Valida que el nuevo username no esté vacío, lo normaliza (`strip().lower()`), y valida que no exista ya otro usuario con ese username.
  2. `UPDATE usuarios SET username = %s WHERE username = %s` (además de los demás campos que ya actualiza este endpoint).
  3. Propaga el rename a las tablas que referencian el username: `tickets.usuario`, `tickets.asignado_a`, `ticket_comentarios.usuario`, `mensajes.de_usuario`, `mensajes.borrado_por`, `proyectos.responsable_username`, `tareas.asignado_a_username`.
  4. Commit único; si cualquier paso falla, rollback completo y error 400/500 claro.
- Frontend `users_screen.dart`: el campo de username deja de estar deshabilitado al editar (la pantalla ya es exclusiva de Admin). Si el username cambió, se envía `nuevoUsername` en el PUT.
- Caso borde: si el Admin se renombra a sí mismo, se muestra un aviso de que debe volver a iniciar sesión (su sesión/token activos quedan con el username anterior hasta relogear). No se implementa invalidación automática de sesión — fuera de alcance.

## Fuera de alcance
- Búsqueda de mensajes en el backend / paginación de chat más allá de los últimos 200 mensajes.
- Hilos de conversación (threads) más allá de una sola referencia "responder a".
- Pantalla de "mi perfil" para que un usuario no-Admin edite su propio nombre de usuario.
- Invalidación automática de sesión al renombrar el propio usuario Admin.
