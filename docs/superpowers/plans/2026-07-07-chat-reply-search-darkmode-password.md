# Chat reply/search + modo oscuro + fixes password/username — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Añadir responder/buscar en el chat, implementar modo oscuro elegante en toda la app, y corregir los bugs de cambio de contraseña / nombre de usuario.

**Architecture:** App Flutter Web (sin gestor de estado externo) contra backend FastAPI + MySQL en EC2. Todos los cambios son incrementales sobre archivos existentes; no se agregan dependencias nuevas (se reutiliza `shared_preferences`, ya presente, para persistir el tema).

**Tech Stack:** Flutter 3.x / Dart, FastAPI + PyMySQL (`main_api.py`), MySQL.

## Global Constraints

- No agregar paquetes nuevos a `pubspec.yaml` (regla "Ponytail" de `CLAUDE.md`: reusar lo que ya existe).
- Todo cambio de color debe usar `Theme.of(context).colorScheme.*`, nunca constantes fijas nuevas.
- El backend valida SIEMPRE la identidad desde el JWT (`current_user`), nunca desde el body — mantener ese patrón en cualquier endpoint nuevo o modificado.
- Cambios de esquema de BD deben ser idempotentes (usar `information_schema` para chequear antes de `ALTER TABLE`), porque `main_api.py` se reinicia en cada deploy sin migraciones manuales separadas.
- Backend no tiene framework de tests (`main_api.py` no tiene suite de pruebas) — verificar sintaxis con `python -m py_compile main_api.py` y verificación funcional real contra el servidor en el paso de deploy.
- Frontend: usar `flutter test` para lógica no trivial (parsing, filtros); cambios puramente visuales (sweep de colores) se verifican manualmente con `flutter run -d chrome`, sin test dedicado (son cambios triviales de estilo, no de lógica).

---

## Backend

### Task 1: Soporte de "responder a un mensaje" en el chat (backend)

**Files:**
- Modify: `main_api.py:120-127` (agregar `_ensure_schema`), `main_api.py:355-360` (`MensajeRequest`), `main_api.py:1378-1400` (`GET /mensajes`), `main_api.py:1426-1459` (`POST /mensajes`)

**Interfaces:**
- Produces: columna `mensajes.respuesta_a` (INT NULL); `MensajeRequest.respuestaA: Optional[int]`; `GET /mensajes` y el broadcast WS de `POST /mensajes` incluyen la clave `respuestaA` (int o `null`).

- [ ] **Step 1: Agregar migración idempotente de esquema**

En `main_api.py`, justo después de la función `get_db_connection` (línea 127), agregar:

```python
def _ensure_schema():
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT COUNT(*) AS c FROM information_schema.COLUMNS
                WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'mensajes' AND COLUMN_NAME = 'respuesta_a'
            """)
            if cursor.fetchone()['c'] == 0:
                cursor.execute("ALTER TABLE mensajes ADD COLUMN respuesta_a INT NULL")
                connection.commit()
    finally:
        connection.close()

_ensure_schema()
```

Esto se ejecuta una sola vez al importar el módulo (arranque de `uvicorn`); si la columna ya existe (en deploys posteriores) no hace nada.

- [ ] **Step 2: Verificar sintaxis**

Run: `python -m py_compile main_api.py`
Expected: sin salida (sin errores).

- [ ] **Step 3: Agregar `respuestaA` a `MensajeRequest`**

En `main_api.py:355-360`, reemplazar:

```python
class MensajeRequest(BaseModel):
    deUsuario: str
    nombreCompleto: str
    texto: str = ''
    imagen: Optional[str] = None
    canal: str
```

por:

```python
class MensajeRequest(BaseModel):
    deUsuario: str
    nombreCompleto: str
    texto: str = ''
    imagen: Optional[str] = None
    canal: str
    respuestaA: Optional[int] = None
```

- [ ] **Step 4: Incluir `respuestaA` en `GET /mensajes`**

En `main_api.py:1378-1400`, dentro del SELECT (línea 1385-1388), reemplazar:

```python
                    SELECT id, de_usuario AS deUsuario, nombre_completo AS nombreCompleto,
                           texto, imagen, fecha, canal,
                           COALESCE(borrado, 0) AS borrado,
                           borrado_por AS borradoPor
                    FROM mensajes ORDER BY fecha DESC LIMIT 200
```

por:

```python
                    SELECT id, de_usuario AS deUsuario, nombre_completo AS nombreCompleto,
                           texto, imagen, fecha, canal,
                           COALESCE(borrado, 0) AS borrado,
                           borrado_por AS borradoPor, respuesta_a AS respuestaA
                    FROM mensajes ORDER BY fecha DESC LIMIT 200
```

- [ ] **Step 5: Guardar y devolver `respuestaA` en `POST /mensajes`**

En `main_api.py:1426-1459`, reemplazar el bloque del INSERT y el payload:

```python
            cursor.execute(
                "INSERT INTO mensajes (de_usuario, nombre_completo, texto, imagen, fecha, canal) VALUES (%s, %s, %s, %s, %s, %s)",
                (de_usuario, nombre_completo, texto, req.imagen, ahora, req.canal)
            )
            connection.commit()
            nuevo_id = cursor.lastrowid
    finally:
        connection.close()
    payload = {
        "tipo": "chat",
        "id": str(nuevo_id),
        "deUsuario": de_usuario,
        "nombreCompleto": nombre_completo,
        "texto": texto,
        "imagen": req.imagen,
        "fecha": ahora.isoformat(),
        "canal": req.canal,
    }
```

por:

```python
            cursor.execute(
                "INSERT INTO mensajes (de_usuario, nombre_completo, texto, imagen, fecha, canal, respuesta_a) VALUES (%s, %s, %s, %s, %s, %s, %s)",
                (de_usuario, nombre_completo, texto, req.imagen, ahora, req.canal, req.respuestaA)
            )
            connection.commit()
            nuevo_id = cursor.lastrowid
    finally:
        connection.close()
    payload = {
        "tipo": "chat",
        "id": str(nuevo_id),
        "deUsuario": de_usuario,
        "nombreCompleto": nombre_completo,
        "texto": texto,
        "imagen": req.imagen,
        "fecha": ahora.isoformat(),
        "canal": req.canal,
        "respuestaA": req.respuestaA,
    }
```

- [ ] **Step 6: Verificar sintaxis de nuevo**

Run: `python -m py_compile main_api.py`
Expected: sin salida.

- [ ] **Step 7: Commit**

```bash
git add main_api.py
git commit -m "Feat: backend soporta responder a un mensaje en el chat (respuesta_a)"
```

---

### Task 2: Fix forzar_cambio_password + renombrar username (solo Admin)

**Files:**
- Modify: `main_api.py:369-373` (`UsuarioUpdateRequest`), `main_api.py:1314-1341` (`update_usuario`)

**Interfaces:**
- Produces: `UsuarioUpdateRequest.nuevoUsername: Optional[str]`; `PUT /usuarios/{username}` ahora también activa `forzar_cambio_password=1` cuando se resetea la contraseña, y renombra el username (y sus referencias) cuando se envía `nuevoUsername`.

- [ ] **Step 1: Agregar `nuevoUsername` al modelo**

En `main_api.py:369-373`, reemplazar:

```python
class UsuarioUpdateRequest(BaseModel):
    nombreCompleto: Optional[str] = None
    email: Optional[str] = None
    rol: Optional[str] = None
    password: Optional[str] = None
```

por:

```python
class UsuarioUpdateRequest(BaseModel):
    nombreCompleto: Optional[str] = None
    email: Optional[str] = None
    rol: Optional[str] = None
    password: Optional[str] = None
    nuevoUsername: Optional[str] = None
```

- [ ] **Step 2: Reescribir `update_usuario`**

En `main_api.py:1314-1341`, reemplazar la función completa:

```python
@app.put("/usuarios/{username}")
async def update_usuario(username: str, req: UsuarioUpdateRequest, current_user: dict = Depends(get_current_user)):
    if current_user.get("rol") != "Admin":
        raise HTTPException(status_code=403, detail="Solo el administrador puede modificar usuarios")
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            campos = []
            valores = []
            if req.nombreCompleto is not None:
                campos.append("nombre_completo = %s"); valores.append(req.nombreCompleto.strip())
            if req.email is not None:
                campos.append("email = %s"); valores.append(req.email.strip().lower())
            if req.rol is not None:
                campos.append("rol = %s"); valores.append(req.rol)
            if req.password is not None and req.password.strip():
                campos.append("password = %s"); valores.append(_hash_password(req.password.strip()))
                campos.append("forzar_cambio_password = 1")
            if not campos:
                raise HTTPException(status_code=400, detail="Sin campos a actualizar")
            valores.append(username)
            cursor.execute(f"UPDATE usuarios SET {', '.join(campos)} WHERE username = %s", valores)
            connection.commit()
            if cursor.rowcount == 0:
                raise HTTPException(status_code=404, detail="Usuario no encontrado")
    finally:
        connection.close()
    await manager.broadcast({"tipo": "usuarios", "accion": "actualizado"})
    return {"status": "success"}
```

por (agrega el bloque de renombrado antes del `manager.broadcast` final, dentro de la misma conexión/transacción que ya existía):

```python
@app.put("/usuarios/{username}")
async def update_usuario(username: str, req: UsuarioUpdateRequest, current_user: dict = Depends(get_current_user)):
    if current_user.get("rol") != "Admin":
        raise HTTPException(status_code=403, detail="Solo el administrador puede modificar usuarios")
    nuevo_username = None
    if req.nuevoUsername is not None:
        nuevo_username = req.nuevoUsername.strip().lower()
        if not nuevo_username:
            raise HTTPException(status_code=400, detail="El nuevo username no puede estar vacío")
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            campos = []
            valores = []
            if req.nombreCompleto is not None:
                campos.append("nombre_completo = %s"); valores.append(req.nombreCompleto.strip())
            if req.email is not None:
                campos.append("email = %s"); valores.append(req.email.strip().lower())
            if req.rol is not None:
                campos.append("rol = %s"); valores.append(req.rol)
            if req.password is not None and req.password.strip():
                campos.append("password = %s"); valores.append(_hash_password(req.password.strip()))
                campos.append("forzar_cambio_password = 1")
            if nuevo_username and nuevo_username != username:
                cursor.execute("SELECT username FROM usuarios WHERE username = %s", (nuevo_username,))
                if cursor.fetchone():
                    raise HTTPException(status_code=409, detail="Ese nombre de usuario ya existe")
                campos.append("username = %s"); valores.append(nuevo_username)
            if not campos:
                raise HTTPException(status_code=400, detail="Sin campos a actualizar")
            valores.append(username)
            cursor.execute(f"UPDATE usuarios SET {', '.join(campos)} WHERE username = %s", valores)
            if cursor.rowcount == 0:
                raise HTTPException(status_code=404, detail="Usuario no encontrado")
            if nuevo_username and nuevo_username != username:
                for tabla, columna in [
                    ("tickets", "usuario"), ("tickets", "asignado_a"),
                    ("ticket_comentarios", "usuario"),
                    ("mensajes", "de_usuario"), ("mensajes", "borrado_por"),
                    ("proyectos", "responsable_username"),
                    ("tareas", "asignado_a_username"),
                ]:
                    cursor.execute(f"UPDATE {tabla} SET {columna} = %s WHERE {columna} = %s", (nuevo_username, username))
            connection.commit()
    finally:
        connection.close()
    await manager.broadcast({"tipo": "usuarios", "accion": "actualizado"})
    return {"status": "success", "username": nuevo_username or username}
```

- [ ] **Step 3: Verificar sintaxis**

Run: `python -m py_compile main_api.py`
Expected: sin salida.

- [ ] **Step 4: Commit**

```bash
git add main_api.py
git commit -m "Fix: forzar cambio de password al resetear + soporte renombrar username (solo Admin)"
```

---

## Frontend — modelos y servicios

### Task 3: `ChatMessage` — campo `respuestaA`

**Files:**
- Modify: `lib/models/chat_message_model.dart`
- Test: `test/chat_message_model_test.dart`

**Interfaces:**
- Produces: `ChatMessage.respuestaA: int?`

- [ ] **Step 1: Escribir el test que falla**

En `test/chat_message_model_test.dart`, agregar un segundo test dentro de `main()`, después del existente:

```dart
  test('respuestaA se parsea desde el map cuando viene presente', () {
    final msg = ChatMessage.fromMap({
      'id': '2',
      'deUsuario': 'jdoe',
      'nombreCompleto': 'John Doe',
      'texto': 'respondiendo',
      'fecha': '2026-07-01T20:32:15.000000',
      'respuestaA': 1,
    });
    expect(msg.respuestaA, 1);

    final sinRespuesta = ChatMessage.fromMap({
      'id': '3',
      'deUsuario': 'jdoe',
      'nombreCompleto': 'John Doe',
      'texto': 'normal',
      'fecha': '2026-07-01T20:32:15.000000',
    });
    expect(sinRespuesta.respuestaA, null);
  });
```

- [ ] **Step 2: Correr el test y ver que falla**

Run: `flutter test test/chat_message_model_test.dart`
Expected: FAIL (`The named parameter 'respuestaA' isn't defined` o similar, porque el campo aún no existe).

- [ ] **Step 3: Agregar el campo al modelo**

En `lib/models/chat_message_model.dart`, reemplazar la clase completa:

```dart
class ChatMessage {
  final String id;
  final String deUsuario;
  final String nombreCompleto;
  final String texto;
  final DateTime fecha;
  final String? imagen;
  final bool borrado;
  final String? borradoPor;
  final String canal;
  final int? respuestaA;

  ChatMessage({
    required this.id,
    required this.deUsuario,
    required this.nombreCompleto,
    required this.texto,
    required this.fecha,
    this.imagen,
    this.borrado = false,
    this.borradoPor,
    this.canal = 'soporte',
    this.respuestaA,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) => ChatMessage(
    id: map['id']?.toString() ?? '',
    deUsuario: map['deUsuario'] ?? '',
    nombreCompleto: map['nombreCompleto'] ?? '',
    texto: map['texto'] ?? '',
    fecha: _parseFechaUtc(map['fecha']),
    imagen: map['imagen'],
    borrado: map['borrado'] == true || map['borrado'] == 1,
    borradoPor: map['borradoPor'],
    canal: map['canal'] ?? 'soporte',
    respuestaA: map['respuestaA'] == null ? null : int.tryParse(map['respuestaA'].toString()),
  );

  ChatMessage copyWith({bool? borrado, String? borradoPor}) => ChatMessage(
    id: id,
    deUsuario: deUsuario,
    nombreCompleto: nombreCompleto,
    texto: texto,
    fecha: fecha,
    imagen: imagen,
    borrado: borrado ?? this.borrado,
    borradoPor: borradoPor ?? this.borradoPor,
    canal: canal,
    respuestaA: respuestaA,
  );
}
```

- [ ] **Step 4: Correr el test y ver que pasa**

Run: `flutter test test/chat_message_model_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/models/chat_message_model.dart test/chat_message_model_test.dart
git commit -m "Feat: ChatMessage soporta campo respuestaA"
```

---

### Task 4: `api_service.dart` — enviar respuesta y renombrar usuario

**Files:**
- Modify: `lib/services/api_service.dart:176-191` (`actualizarUsuario`), `lib/services/api_service.dart:217-226` (`enviarMensaje`)

**Interfaces:**
- Consumes: `ChatMessage` (Task 3)
- Produces: `ApiService.enviarMensaje(..., {int? respuestaA})`; `ApiService.actualizarUsuario(..., {String? nuevoUsername})`

- [ ] **Step 1: Actualizar `enviarMensaje`**

En `lib/services/api_service.dart:217-226`, reemplazar:

```dart
  Future<void> enviarMensaje(String deUsuario, String nombreCompleto, String texto, {required String canal, String? imagen}) async {
    final body = <String, dynamic>{'deUsuario': deUsuario, 'nombreCompleto': nombreCompleto, 'texto': texto, 'canal': canal};
    if (imagen != null) body['imagen'] = imagen;
    final res = await http.post(
      Uri.parse('$kApiUrl/mensajes'),
      headers: _headers,
      body: jsonEncode(body),
    ).timeout(kTimeout);
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception('Error al enviar mensaje');
  }
```

por:

```dart
  Future<void> enviarMensaje(String deUsuario, String nombreCompleto, String texto, {required String canal, String? imagen, int? respuestaA}) async {
    final body = <String, dynamic>{'deUsuario': deUsuario, 'nombreCompleto': nombreCompleto, 'texto': texto, 'canal': canal};
    if (imagen != null) body['imagen'] = imagen;
    if (respuestaA != null) body['respuestaA'] = respuestaA;
    final res = await http.post(
      Uri.parse('$kApiUrl/mensajes'),
      headers: _headers,
      body: jsonEncode(body),
    ).timeout(kTimeout);
    if (res.statusCode != 200 && res.statusCode != 201) throw Exception('Error al enviar mensaje');
  }
```

- [ ] **Step 2: Actualizar `actualizarUsuario`**

En `lib/services/api_service.dart:176-191`, reemplazar:

```dart
  Future<void> actualizarUsuario({
    required String username,
    required String nombreCompleto,
    required String email,
    required String rol,
    String? password,
  }) async {
    final body = <String, dynamic>{'nombreCompleto': nombreCompleto, 'email': email, 'rol': rol};
    if (password != null) body['password'] = password;
    final res = await http.put(
      Uri.parse('$kApiUrl/usuarios/$username'),
      headers: _headers,
      body: jsonEncode(body),
    ).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception(jsonDecode(res.body)['detail'] ?? 'Error al actualizar usuario');
  }
```

por:

```dart
  Future<void> actualizarUsuario({
    required String username,
    required String nombreCompleto,
    required String email,
    required String rol,
    String? password,
    String? nuevoUsername,
  }) async {
    final body = <String, dynamic>{'nombreCompleto': nombreCompleto, 'email': email, 'rol': rol};
    if (password != null) body['password'] = password;
    if (nuevoUsername != null) body['nuevoUsername'] = nuevoUsername;
    final res = await http.put(
      Uri.parse('$kApiUrl/usuarios/$username'),
      headers: _headers,
      body: jsonEncode(body),
    ).timeout(kTimeout);
    if (res.statusCode != 200) throw Exception(jsonDecode(res.body)['detail'] ?? 'Error al actualizar usuario');
  }
```

- [ ] **Step 3: Verificar análisis estático**

Run: `flutter analyze lib/services/api_service.dart`
Expected: "No issues found!"

- [ ] **Step 4: Commit**

```bash
git add lib/services/api_service.dart
git commit -m "Feat: api_service soporta respuestaA en mensajes y nuevoUsername al actualizar usuario"
```

---

## Frontend — password / username

### Task 5: Fix validación de contraseña en primer login (4 → 6 caracteres)

**Files:**
- Modify: `lib/screens/login_screen.dart:60-63`

- [ ] **Step 1: Corregir el validador**

En `lib/screens/login_screen.dart:60-63`, reemplazar:

```dart
                  validator: (v) {
                    if (v == null || v.trim().length < 4) return 'Mínimo 4 caracteres';
                    return null;
                  },
```

por:

```dart
                  validator: (v) {
                    if (v == null || v.trim().length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
```

- [ ] **Step 2: Verificar análisis estático**

Run: `flutter analyze lib/screens/login_screen.dart`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/screens/login_screen.dart
git commit -m "Fix: validacion de nueva contrasena en primer login exige minimo 6 caracteres, igual que el backend"
```

---

### Task 6: Habilitar cambio de nombre de usuario (solo Admin)

**Files:**
- Modify: `lib/screens/users_screen.dart`, `lib/screens/main_layout.dart:304`

**Interfaces:**
- Consumes: `ApiService.actualizarUsuario(..., nuevoUsername: ...)` (Task 4)

- [ ] **Step 1: Pasar la sesión a `UsersScreen`**

En `lib/screens/users_screen.dart:1-19`, reemplazar el constructor:

```dart
import 'package:flutter/material.dart';
import '../models/usuario_model.dart';
import '../services/api_service.dart';

class UsersScreen extends StatefulWidget {
  final List<Usuario> usuarios;
  final ApiService api;
  final VoidCallback onRefresh;

  const UsersScreen({
    super.key,
    required this.usuarios,
    required this.api,
    required this.onRefresh,
  });
```

por:

```dart
import 'package:flutter/material.dart';
import '../models/session_model.dart';
import '../models/usuario_model.dart';
import '../services/api_service.dart';

class UsersScreen extends StatefulWidget {
  final List<Usuario> usuarios;
  final ApiService api;
  final Session session;
  final VoidCallback onRefresh;

  const UsersScreen({
    super.key,
    required this.usuarios,
    required this.api,
    required this.session,
    required this.onRefresh,
  });
```

- [ ] **Step 2: Habilitar el campo username al editar y enviar el rename**

En `lib/screens/users_screen.dart:52-67`, reemplazar:

```dart
                  TextFormField(
                    controller: usernameCtrl,
                    enabled: editar == null,
                    decoration: InputDecoration(
                      labelText: 'Nombre de usuario',
                      border: const OutlineInputBorder(),
                      helperText: editar == null ? 'Ej: jperez (sin espacios, minúsculas)' : null,
                      filled: editar != null,
                      fillColor: editar != null ? Colors.grey.shade100 : null,
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Requerido';
                      if (v.contains(' ')) return 'Sin espacios';
                      return null;
                    },
                  ),
```

por:

```dart
                  TextFormField(
                    controller: usernameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de usuario',
                      border: OutlineInputBorder(),
                      helperText: 'Ej: jperez (sin espacios, minúsculas)',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Requerido';
                      if (v.contains(' ')) return 'Sin espacios';
                      return null;
                    },
                  ),
```

- [ ] **Step 3: Enviar `nuevoUsername` al guardar y avisar si es auto-renombrado**

En `lib/screens/users_screen.dart:112-146`, reemplazar el bloque `onPressed` del botón de guardar:

```dart
              onPressed: guardando
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setLocal(() => guardando = true);
                      try {
                        if (editar == null) {
                          await widget.api.crearUsuario(
                            username: usernameCtrl.text.trim().toLowerCase(),
                            email: emailCtrl.text.trim().toLowerCase(),
                            nombreCompleto: nombreCtrl.text.trim(),
                            rol: rol,
                            password: passCtrl.text.trim(),
                          );
                        } else {
                          await widget.api.actualizarUsuario(
                            username: editar.username,
                            nombreCompleto: nombreCtrl.text.trim(),
                            email: emailCtrl.text.trim().toLowerCase(),
                            rol: rol,
                            password: passCtrl.text.trim().isEmpty ? null : passCtrl.text.trim(),
                          );
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        widget.onRefresh();
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                          );
                        }
                      } finally {
                        if (ctx.mounted) setLocal(() => guardando = false);
                      }
                    },
```

por:

```dart
              onPressed: guardando
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setLocal(() => guardando = true);
                      final nuevoUsername = usernameCtrl.text.trim().toLowerCase();
                      try {
                        if (editar == null) {
                          await widget.api.crearUsuario(
                            username: nuevoUsername,
                            email: emailCtrl.text.trim().toLowerCase(),
                            nombreCompleto: nombreCtrl.text.trim(),
                            rol: rol,
                            password: passCtrl.text.trim(),
                          );
                        } else {
                          final esAutoRename = nuevoUsername != editar.username && editar.username == widget.session.username;
                          await widget.api.actualizarUsuario(
                            username: editar.username,
                            nombreCompleto: nombreCtrl.text.trim(),
                            email: emailCtrl.text.trim().toLowerCase(),
                            rol: rol,
                            password: passCtrl.text.trim().isEmpty ? null : passCtrl.text.trim(),
                            nuevoUsername: nuevoUsername != editar.username ? nuevoUsername : null,
                          );
                          if (esAutoRename && ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('Cambiaste tu propio nombre de usuario: cierra sesión y vuelve a entrar con el nuevo.'), duration: Duration(seconds: 5)),
                            );
                          }
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        widget.onRefresh();
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                          );
                        }
                      } finally {
                        if (ctx.mounted) setLocal(() => guardando = false);
                      }
                    },
```

- [ ] **Step 4: Pasar `session` desde `MainLayout`**

En `lib/screens/main_layout.dart:304`, reemplazar:

```dart
        UsersScreen(usuarios: _usuarios, api: _api, onRefresh: _cargarUsuarios),
```

por:

```dart
        UsersScreen(usuarios: _usuarios, api: _api, session: widget.session, onRefresh: _cargarUsuarios),
```

- [ ] **Step 5: Verificar análisis estático**

Run: `flutter analyze lib/screens/users_screen.dart lib/screens/main_layout.dart`
Expected: "No issues found!"

- [ ] **Step 6: Commit**

```bash
git add lib/screens/users_screen.dart lib/screens/main_layout.dart
git commit -m "Feat: Admin puede renombrar el nombre de usuario de un usuario existente"
```

---

## Frontend — chat: responder y buscar

### Task 7: Responder a un mensaje (swipe + cita + scroll al original)

**Files:**
- Modify: `lib/screens/chat_screen.dart`

**Interfaces:**
- Consumes: `ChatMessage.respuestaA` (Task 3), `ApiService.enviarMensaje(..., respuestaA: ...)` (Task 4)
- Produces: estado `_respondiendoA` y helper `_buscarMensaje(id)` usados también por Task 8 (búsqueda) para el scroll-to.

- [ ] **Step 1: Agregar estado y helpers en `_ChatScreenState`**

En `lib/screens/chat_screen.dart:124-133`, reemplazar:

```dart
class _ChatScreenState extends State<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _enviando = false;
  String? _imagenSeleccionada;
  List<Usuario> _sugerencias = [];
  late String _canalActivo;

  List<ChatMessage> get _mensajesDelCanal =>
      widget.mensajes.where((m) => m.canal == _canalActivo).toList();
```

por:

```dart
class _ChatScreenState extends State<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _enviando = false;
  String? _imagenSeleccionada;
  List<Usuario> _sugerencias = [];
  late String _canalActivo;
  ChatMessage? _respondiendoA;
  final Map<String, GlobalKey> _mensajeKeys = {};

  List<ChatMessage> get _mensajesDelCanal =>
      widget.mensajes.where((m) => m.canal == _canalActivo).toList();

  GlobalKey _keyPara(String id) => _mensajeKeys.putIfAbsent(id, () => GlobalKey());

  ChatMessage? _buscarMensajePorId(String? id) {
    if (id == null) return null;
    for (final m in widget.mensajes) {
      if (m.id == id) return m;
    }
    return null;
  }

  void _irAMensaje(String id) {
    final ctx = _mensajeKeys[id]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), alignment: 0.5);
    }
  }

  void _iniciarRespuesta(ChatMessage msg) {
    setState(() => _respondiendoA = msg);
  }
```

- [ ] **Step 2: Enviar `respuestaA` y limpiar el estado al mandar el mensaje**

En `lib/screens/chat_screen.dart:197-223`, reemplazar:

```dart
  Future<void> _enviar() async {
    final texto = _inputCtrl.text.trim();
    if ((texto.isEmpty && _imagenSeleccionada == null) || _enviando) return;
    setState(() => _enviando = true);
    final imagenEnviar = _imagenSeleccionada;
    _inputCtrl.clear();
    setState(() => _imagenSeleccionada = null);
    try {
      await widget.api.enviarMensaje(
        widget.session.username,
        widget.session.nombreCompleto,
        texto,
        canal: _canalActivo,
        imagen: imagenEnviar,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
        _inputCtrl.text = texto;
        setState(() => _imagenSeleccionada = imagenEnviar);
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }
```

por:

```dart
  Future<void> _enviar() async {
    final texto = _inputCtrl.text.trim();
    if ((texto.isEmpty && _imagenSeleccionada == null) || _enviando) return;
    setState(() => _enviando = true);
    final imagenEnviar = _imagenSeleccionada;
    final respuestaAEnviar = _respondiendoA != null ? int.tryParse(_respondiendoA!.id) : null;
    _inputCtrl.clear();
    setState(() {
      _imagenSeleccionada = null;
      _respondiendoA = null;
    });
    try {
      await widget.api.enviarMensaje(
        widget.session.username,
        widget.session.nombreCompleto,
        texto,
        canal: _canalActivo,
        imagen: imagenEnviar,
        respuestaA: respuestaAEnviar,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
        _inputCtrl.text = texto;
        setState(() => _imagenSeleccionada = imagenEnviar);
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }
```

- [ ] **Step 3: Detectar swipe y mostrar la barra "respondiendo a…"**

En `lib/screens/chat_screen.dart:346-371` (dentro del `itemBuilder`), reemplazar:

```dart
                    itemBuilder: (_, reversedI) {
                      final i = mensajes.length - 1 - reversedI;
                      final msg = mensajes[i];
                      final esMio = msg.deUsuario == widget.session.username;
                      final nuevoDia = i == 0 || !_mismoDia(mensajes[i - 1].fecha, msg.fecha);
                      final mostrarNombre = !esMio &&
                          (nuevoDia || mensajes[i - 1].deUsuario != msg.deUsuario);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (nuevoDia) _SeparadorFecha(fecha: msg.fecha),
                          GestureDetector(
                            onLongPress: _puedeBorar(msg) ? () => _confirmarBorrado(msg) : null,
                            child: _BurbujaMensaje(
                              mensaje: msg,
                              esMio: esMio,
                              esAdmin: esAdmin,
                              mostrarNombre: mostrarNombre,
                              colorPrimary: primary,
                              colorUsuario: _colorDeUsuario(msg.deUsuario),
                            ),
                          ),
                        ],
                      );
                    },
```

por:

```dart
                    itemBuilder: (_, reversedI) {
                      final i = mensajes.length - 1 - reversedI;
                      final msg = mensajes[i];
                      final esMio = msg.deUsuario == widget.session.username;
                      final nuevoDia = i == 0 || !_mismoDia(mensajes[i - 1].fecha, msg.fecha);
                      final mostrarNombre = !esMio &&
                          (nuevoDia || mensajes[i - 1].deUsuario != msg.deUsuario);
                      double dragDx = 0;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (nuevoDia) _SeparadorFecha(fecha: msg.fecha),
                          GestureDetector(
                            key: _keyPara(msg.id),
                            onLongPress: _puedeBorar(msg) ? () => _confirmarBorrado(msg) : null,
                            onHorizontalDragUpdate: (d) => dragDx += d.delta.dx,
                            onHorizontalDragEnd: (_) {
                              if (dragDx.abs() > 48) _iniciarRespuesta(msg);
                              dragDx = 0;
                            },
                            child: _BurbujaMensaje(
                              mensaje: msg,
                              esMio: esMio,
                              esAdmin: esAdmin,
                              mostrarNombre: mostrarNombre,
                              colorPrimary: primary,
                              colorUsuario: _colorDeUsuario(msg.deUsuario),
                              mensajeCitado: _buscarMensajePorId(msg.respuestaA?.toString()),
                              onTapCitado: msg.respuestaA != null
                                  ? () => _irAMensaje(msg.respuestaA.toString())
                                  : null,
                            ),
                          ),
                        ],
                      );
                    },
```

- [ ] **Step 4: Agregar la barra de "respondiendo a…" sobre el input**

En `lib/screens/chat_screen.dart`, justo antes del `Container` del input (línea 452, `// Input`), agregar:

```dart
          // Reply preview bar
          if (_respondiendoA != null)
            Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  Container(width: 3, height: 34, color: primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _respondiendoA!.deUsuario == widget.session.username ? 'Tú' : _respondiendoA!.nombreCompleto,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: primary),
                        ),
                        Text(
                          _respondiendoA!.texto.isNotEmpty ? _respondiendoA!.texto : '📷 Imagen',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _respondiendoA = null),
                  ),
                ],
              ),
            ),
```

- [ ] **Step 5: Agregar el recuadro citado y el callback de tap a `_BurbujaMensaje`**

En `lib/screens/chat_screen.dart:564-579`, reemplazar la declaración de la clase:

```dart
class _BurbujaMensaje extends StatelessWidget {
  final ChatMessage mensaje;
  final bool esMio;
  final bool esAdmin;
  final bool mostrarNombre;
  final Color colorPrimary;
  final Color colorUsuario;

  const _BurbujaMensaje({
    required this.mensaje,
    required this.esMio,
    required this.esAdmin,
    required this.mostrarNombre,
    required this.colorPrimary,
    required this.colorUsuario,
  });
```

por:

```dart
class _BurbujaMensaje extends StatelessWidget {
  final ChatMessage mensaje;
  final bool esMio;
  final bool esAdmin;
  final bool mostrarNombre;
  final Color colorPrimary;
  final Color colorUsuario;
  final ChatMessage? mensajeCitado;
  final VoidCallback? onTapCitado;

  const _BurbujaMensaje({
    required this.mensaje,
    required this.esMio,
    required this.esAdmin,
    required this.mostrarNombre,
    required this.colorPrimary,
    required this.colorUsuario,
    this.mensajeCitado,
    this.onTapCitado,
  });
```

- [ ] **Step 6: Renderizar el recuadro citado dentro de la burbuja**

En `lib/screens/chat_screen.dart:669-671`, reemplazar:

```dart
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Admin badge when showing deleted message
```

por:

```dart
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Citación de mensaje respondido
                      if (mensaje.respuestaA != null)
                        GestureDetector(
                          onTap: onTapCitado,
                          child: Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: (esMio ? Colors.white : colorPrimary).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border(left: BorderSide(color: esMio ? Colors.white : colorPrimary, width: 3)),
                            ),
                            child: mensajeCitado != null
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mensajeCitado!.nombreCompleto,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: esMio ? Colors.white : colorPrimary),
                                      ),
                                      Text(
                                        mensajeCitado!.texto.isNotEmpty ? mensajeCitado!.texto : '📷 Imagen',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 11, color: esMio ? Colors.white.withValues(alpha: 0.85) : Colors.black87),
                                      ),
                                    ],
                                  )
                                : Text(
                                    'Mensaje original no disponible',
                                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: esMio ? Colors.white.withValues(alpha: 0.7) : Colors.grey.shade500),
                                  ),
                          ),
                        ),
                      // Admin badge when showing deleted message
```

- [ ] **Step 7: Verificar análisis estático**

Run: `flutter analyze lib/screens/chat_screen.dart`
Expected: "No issues found!"

- [ ] **Step 8: Commit**

```bash
git add lib/screens/chat_screen.dart
git commit -m "Feat: responder a un mensaje del chat (swipe + cita + scroll al original)"
```

---

### Task 8: Buscar mensajes dentro del canal activo

**Files:**
- Modify: `lib/screens/chat_screen.dart`

**Interfaces:**
- Consumes: `_mensajesDelCanal`, `_keyPara`, `_mensajeKeys` (Task 7)

- [ ] **Step 1: Agregar estado de búsqueda**

En `lib/screens/chat_screen.dart`, en `_ChatScreenState`, justo después de `ChatMessage? _respondiendoA;` (agregado en Task 7), agregar:

```dart
  bool _buscando = false;
  final _busquedaCtrl = TextEditingController();
  List<String> _coincidencias = [];
  int _coincidenciaActual = -1;
```

- [ ] **Step 2: Agregar la lógica de búsqueda y navegación entre coincidencias**

En `lib/screens/chat_screen.dart`, después de `_iniciarRespuesta` (agregado en Task 7), agregar:

```dart
  void _buscar(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _coincidencias = [];
        _coincidenciaActual = -1;
      });
      return;
    }
    final ids = _mensajesDelCanal.where((m) => m.texto.toLowerCase().contains(q)).map((m) => m.id).toList();
    setState(() {
      _coincidencias = ids;
      _coincidenciaActual = ids.isEmpty ? -1 : ids.length - 1;
    });
    if (_coincidencias.isNotEmpty) _irAMensaje(_coincidencias[_coincidenciaActual]);
  }

  void _siguienteCoincidencia() {
    if (_coincidencias.isEmpty) return;
    setState(() => _coincidenciaActual = (_coincidenciaActual - 1 + _coincidencias.length) % _coincidencias.length);
    _irAMensaje(_coincidencias[_coincidenciaActual]);
  }

  void _anteriorCoincidencia() {
    if (_coincidencias.isEmpty) return;
    setState(() => _coincidenciaActual = (_coincidenciaActual + 1) % _coincidencias.length);
    _irAMensaje(_coincidencias[_coincidenciaActual]);
  }

  void _cerrarBusqueda() {
    _busquedaCtrl.clear();
    setState(() {
      _buscando = false;
      _coincidencias = [];
      _coincidenciaActual = -1;
    });
  }
```

- [ ] **Step 3: Limpiar la búsqueda al cambiar de canal y liberar el controller**

En `lib/screens/chat_screen.dart:142-148`, reemplazar:

```dart
  @override
  void dispose() {
    _inputCtrl.removeListener(_detectarMencion);
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }
```

por:

```dart
  @override
  void dispose() {
    _inputCtrl.removeListener(_detectarMencion);
    _inputCtrl.dispose();
    _scrollCtrl.dispose();
    _busquedaCtrl.dispose();
    super.dispose();
  }
```

Y en `lib/screens/chat_screen.dart:300-325` (los `ChoiceChip` de canal), en el `onSelected`, reemplazar:

```dart
                      onSelected: (_) => setState(() => _canalActivo = c),
```

por:

```dart
                      onSelected: (_) => setState(() {
                        _canalActivo = c;
                        _cerrarBusqueda();
                      }),
```

- [ ] **Step 4: Alternar título/subtítulo por el campo de búsqueda en el header**

En `lib/screens/chat_screen.dart:284-297`, reemplazar:

```dart
                CircleAvatar(
                  backgroundColor: primary.withValues(alpha: 0.12),
                  child: Icon(Icons.groups_rounded, color: primary, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Chat Interno TI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text(_kCanalLabel[_canalActivo] ?? _canalActivo,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ],
            ),
          ),
```

por:

```dart
                if (!_buscando) ...[
                  CircleAvatar(
                    backgroundColor: primary.withValues(alpha: 0.12),
                    child: Icon(Icons.groups_rounded, color: primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: _buscando
                      ? TextField(
                          controller: _busquedaCtrl,
                          autofocus: true,
                          onChanged: _buscar,
                          decoration: const InputDecoration(
                            hintText: 'Buscar en este canal...',
                            border: InputBorder.none,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Chat Interno TI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text(_kCanalLabel[_canalActivo] ?? _canalActivo,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                          ],
                        ),
                ),
                if (_buscando && _coincidencias.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      '${_coincidencias.length - _coincidenciaActual}/${_coincidencias.length}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ),
                if (_buscando) ...[
                  IconButton(icon: const Icon(Icons.keyboard_arrow_up), onPressed: _anteriorCoincidencia),
                  IconButton(icon: const Icon(Icons.keyboard_arrow_down), onPressed: _siguienteCoincidencia),
                ],
                IconButton(
                  icon: Icon(_buscando ? Icons.close : Icons.search),
                  tooltip: _buscando ? 'Cerrar búsqueda' : 'Buscar en el canal',
                  onPressed: () => _buscando ? _cerrarBusqueda() : setState(() => _buscando = true),
                ),
              ],
            ),
          ),
```

- [ ] **Step 5: Resaltar la burbuja que es la coincidencia actual**

En `lib/screens/chat_screen.dart` (bloque del `itemBuilder` editado en Task 7), agregar el parámetro `resaltado` a la llamada de `_BurbujaMensaje`:

```dart
                            child: _BurbujaMensaje(
                              mensaje: msg,
                              esMio: esMio,
                              esAdmin: esAdmin,
                              mostrarNombre: mostrarNombre,
                              colorPrimary: primary,
                              colorUsuario: _colorDeUsuario(msg.deUsuario),
                              mensajeCitado: _buscarMensajePorId(msg.respuestaA?.toString()),
                              onTapCitado: msg.respuestaA != null
                                  ? () => _irAMensaje(msg.respuestaA.toString())
                                  : null,
                              resaltado: _coincidenciaActual >= 0 && _coincidencias[_coincidenciaActual] == msg.id,
                            ),
```

Y en la clase `_BurbujaMensaje` (Task 7, Step 5), agregar el campo `resaltado`:

```dart
  final ChatMessage? mensajeCitado;
  final VoidCallback? onTapCitado;
  final bool resaltado;

  const _BurbujaMensaje({
    required this.mensaje,
    required this.esMio,
    required this.esAdmin,
    required this.mostrarNombre,
    required this.colorPrimary,
    required this.colorUsuario,
    this.mensajeCitado,
    this.onTapCitado,
    this.resaltado = false,
  });
```

En el `Container` de la burbuja (línea ~656-668 tras los cambios de Task 7), agregar el borde de resaltado. Reemplazar:

```dart
                    border: borrado ? Border.all(color: Colors.red.withValues(alpha: 0.3)) : null,
```

por:

```dart
                    border: borrado
                        ? Border.all(color: Colors.red.withValues(alpha: 0.3))
                        : (resaltado ? Border.all(color: Colors.amber, width: 2) : null),
```

- [ ] **Step 6: Verificar análisis estático**

Run: `flutter analyze lib/screens/chat_screen.dart`
Expected: "No issues found!"

- [ ] **Step 7: Commit**

```bash
git add lib/screens/chat_screen.dart
git commit -m "Feat: buscar mensajes dentro del canal activo con navegacion entre coincidencias"
```

---

## Frontend — modo oscuro

### Task 9: `ThemeController` — estado y persistencia

**Files:**
- Create: `lib/services/theme_controller.dart`
- Test: `test/theme_controller_test.dart`

**Interfaces:**
- Produces: `ThemeController` (`ChangeNotifier`) con `mode: ThemeMode`, `cargar()`, `cambiar(ThemeMode)`.

- [ ] **Step 1: Escribir el test que falla**

Create `test/theme_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soporte_beta/services/theme_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('por defecto usa ThemeMode.system', () async {
    final controller = ThemeController();
    await controller.cargar();
    expect(controller.mode, ThemeMode.system);
  });

  test('cambiar() persiste y notifica el nuevo modo', () async {
    final controller = ThemeController();
    await controller.cargar();
    var notificado = false;
    controller.addListener(() => notificado = true);

    await controller.cambiar(ThemeMode.dark);

    expect(controller.mode, ThemeMode.dark);
    expect(notificado, true);

    final controller2 = ThemeController();
    await controller2.cargar();
    expect(controller2.mode, ThemeMode.dark);
  });
}
```

- [ ] **Step 2: Correr el test y ver que falla**

Run: `flutter test test/theme_controller_test.dart`
Expected: FAIL (`Error: Not found: 'package:soporte_beta/services/theme_controller.dart'`).

- [ ] **Step 3: Crear `ThemeController`**

Create `lib/services/theme_controller.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  static const _kKey = 'soporte_beta_theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    final guardado = prefs.getString(_kKey);
    _mode = switch (guardado) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    notifyListeners();
  }

  Future<void> cambiar(ThemeMode nuevo) async {
    _mode = nuevo;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, nuevo.name);
  }
}
```

- [ ] **Step 4: Correr el test y ver que pasa**

Run: `flutter test test/theme_controller_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/theme_controller.dart test/theme_controller_test.dart
git commit -m "Feat: ThemeController para modo oscuro persistente"
```

---

### Task 10: Wiring de `darkTheme`/`themeMode` en `main.dart`

**Files:**
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `ThemeController` (Task 9)

- [ ] **Step 1: Reescribir `main.dart`**

Reemplazar el archivo completo `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'models/session_model.dart';
import 'screens/login_screen.dart';
import 'screens/main_layout.dart';
import 'services/notification_service.dart';
import 'services/theme_controller.dart';
import 'utils/notif_helper.dart';
import 'firebase_options.dart';

final themeController = ThemeController();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await themeController.cargar();
  await initPlatformServices(DefaultFirebaseOptions.currentPlatform);
  runApp(const SoporteBetaApp());
}

ThemeData _construirTema(Brightness brightness) => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1A2B72),
        primary: const Color(0xFF1A2B72),
        secondary: const Color(0xFFDC0026),
        brightness: brightness,
      ),
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1A2B72),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A2B72),
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF1A2B72),
        foregroundColor: Colors.white,
      ),
    );

class SoporteBetaApp extends StatelessWidget {
  const SoporteBetaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) => MaterialApp(
        title: 'Soporte Beta',
        debugShowCheckedModeBanner: false,
        theme: _construirTema(Brightness.light),
        darkTheme: _construirTema(Brightness.dark),
        themeMode: themeController.mode,
        home: const _SplashRouter(),
      ),
    );
  }
}

class _SplashRouter extends StatefulWidget {
  const _SplashRouter();

  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter> {
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _resolver();
  }

  Future<void> _resolver() async {
    final session = await Session.restaurar();
    if (session != null && mounted) {
      await NotificationService.solicitarPermiso();
      final notifService = NotificationService(
        username: session.username,
        rol: session.rol,
        token: session.token,
      );
      notifService.iniciar();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => MainLayout(session: session, notifService: notifService)),
        );
        return;
      }
    }
    if (mounted) setState(() => _checking = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary),
        ),
      );
    }
    return const LoginScreen();
  }
}
```

Nota: se quita `drawerTheme` fijo (`backgroundColor: Colors.white`) porque el `Drawer` debe adoptar el color de superficie del tema activo (claro u oscuro) — Material3 ya le da un fondo de superficie coherente por defecto sin necesidad de fijarlo.

- [ ] **Step 2: Verificar análisis estático**

Run: `flutter analyze lib/main.dart`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "Feat: MaterialApp soporta darkTheme y themeMode persistente"
```

---

### Task 11: Selector de "Apariencia" en el Drawer

**Files:**
- Modify: `lib/screens/main_layout.dart`

**Interfaces:**
- Consumes: `themeController` global (Task 10)

- [ ] **Step 1: Importar el controller y agregar el diálogo de apariencia**

En `lib/screens/main_layout.dart:1-25`, agregar el import junto a los demás:

```dart
import '../main.dart' show themeController;
```

- [ ] **Step 2: Agregar el método `_mostrarDialogoApariencia`**

En `lib/screens/main_layout.dart`, después de `_logout` (línea 252-257), agregar:

```dart
  void _mostrarDialogoApariencia() {
    showDialog(
      context: context,
      builder: (ctx) => AnimatedBuilder(
        animation: themeController,
        builder: (ctx, _) => SimpleDialog(
          title: const Text('Apariencia'),
          children: [
            RadioListTile<ThemeMode>(
              title: const Text('Claro'),
              value: ThemeMode.light,
              groupValue: themeController.mode,
              onChanged: (v) => themeController.cambiar(v!),
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Oscuro'),
              value: ThemeMode.dark,
              groupValue: themeController.mode,
              onChanged: (v) => themeController.cambiar(v!),
            ),
            RadioListTile<ThemeMode>(
              title: const Text('Igual que el sistema'),
              value: ThemeMode.system,
              groupValue: themeController.mode,
              onChanged: (v) => themeController.cambiar(v!),
            ),
          ],
        ),
      ),
    );
  }
```

- [ ] **Step 3: Agregar la entrada al Drawer**

En `lib/screens/main_layout.dart:369-372`, reemplazar:

```dart
              // ── Chat ───────────────────────────────────────────────
              const Divider(indent: 16, endIndent: 16),
              _itemChat(),
```

por:

```dart
              // ── Chat ───────────────────────────────────────────────
              const Divider(indent: 16, endIndent: 16),
              _itemChat(),
              // ── Apariencia ───────────────────────────────────────────
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.dark_mode_rounded),
                title: const Text('Apariencia'),
                onTap: () {
                  Navigator.pop(context);
                  _mostrarDialogoApariencia();
                },
              ),
```

- [ ] **Step 4: Verificar análisis estático**

Run: `flutter analyze lib/screens/main_layout.dart`
Expected: "No issues found!"

- [ ] **Step 5: Commit**

```bash
git add lib/screens/main_layout.dart
git commit -m "Feat: selector de apariencia (claro/oscuro/sistema) en el Drawer"
```

---

### Task 12: Sweep de colores — Chat (`chat_screen.dart`)

**Files:**
- Modify: `lib/screens/chat_screen.dart`

**Tabla de mapeo** (aplica en todas las tareas de sweep, 12-17):

| Antes | Después | Uso |
|---|---|---|
| `Color(0xFFF0F2F5)` / `Color(0xFFF5F7FA)` fondo de `Scaffold`/`Container` de pantalla | `Theme.of(context).colorScheme.surfaceContainerLow` | fondo general de pantalla |
| `Colors.white` como fondo de header/card/input/dialog | `Theme.of(context).colorScheme.surface` | headers, inputs, tarjetas |
| `Colors.white` como texto/ícono sobre `primary`/`colorPrimary` (AppBar, botón primario, burbuja propia) | sin cambio — sigue siendo `Colors.white`, el primary no cambia de brillo | texto sobre superficies de color primario |
| `Colors.black87` / `Colors.black` texto | `Theme.of(context).colorScheme.onSurface` | texto principal |
| `Colors.grey.shade100`/`.shade200` fondo (chip no seleccionado, input deshabilitado, burbuja ajena) | `Theme.of(context).colorScheme.surfaceContainerHighest` | superficies secundarias |
| `Colors.grey.shade400`..`.shade600` texto secundario | `Theme.of(context).colorScheme.onSurfaceVariant` | subtítulos, hints, timestamps |
| `Colors.black.withValues(alpha: ...)` en `boxShadow` | sin cambio (las sombras se ven razonablemente en ambos temas) | sombras |

- [ ] **Step 1: Aplicar el mapeo al fondo de pantalla y headers**

En `lib/screens/chat_screen.dart:265-266`, reemplazar:

```dart
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
```

por:

```dart
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
```

En las líneas 273, 302, 380, 408, 454 (`color: Colors.white`), reemplazar cada una por `color: Theme.of(context).colorScheme.surface`.

En la línea 470 (`fillColor: const Color(0xFFF0F2F5)`), reemplazar por `fillColor: Theme.of(context).colorScheme.surfaceContainerLow`.

- [ ] **Step 2: Aplicar el mapeo a textos y superficies secundarias**

Reemplazar en todo el archivo (usar buscar/reemplazar dentro del editor, o `Edit` con `replace_all` cuando el reemplazo es idéntico en significado):
- `Colors.black87` (líneas 317, 541, 557) → `Theme.of(context).colorScheme.onSurface`.
- `Colors.grey.shade100` como `backgroundColor`/`fillColor`/`color` de superficies (líneas 315, 482, 602) → `Theme.of(context).colorScheme.surfaceContainerHighest`.
- `Colors.grey.shade200` (burbuja borrada ajena, línea 658) → `Theme.of(context).colorScheme.surfaceContainerHighest`.
- `Colors.white` como fondo de burbuja ajena (línea 659, `: Colors.white`) → `Theme.of(context).colorScheme.surface`.
- `Colors.grey.shade400/500/600` (líneas 294, 337, 398, 446, 468, 717) → `Theme.of(context).colorScheme.onSurfaceVariant`.

Nota: dejar sin cambiar los `Colors.white` que están específicamente en contraste con `colorPrimary`/`primary` (texto/ícono dentro del botón de enviar, burbuja propia, badges), porque esos siguen siendo correctos en ambos temas.

- [ ] **Step 3: Verificar visualmente**

Run: `flutter run -d chrome`
Manual: abrir el Chat, activar modo oscuro desde "Apariencia" (Drawer), confirmar que el fondo, los headers, las burbujas ajenas y los textos se ven legibles (sin blancos ni negros fijos que rompan el contraste). Confirmar también en modo claro que no cambió el aspecto original.
Expected: legible y consistente en ambos modos.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/chat_screen.dart
git commit -m "Fix: chat_screen usa colores del tema para soportar modo oscuro"
```

---

### Task 13: Sweep de colores — Login y layout principal

**Files:**
- Modify: `lib/screens/login_screen.dart`, `lib/screens/main_layout.dart`

- [ ] **Step 1: `login_screen.dart`**

Aplicar la tabla de mapeo de Task 12. Puntos concretos ya identificados:
- `backgroundColor: const Color(0xFFF0F2F8)` (línea 221) → `Theme.of(context).colorScheme.surfaceContainerLow`.
- `Colors.blueGrey` como texto secundario (líneas 49, 133, 237, 256) → `Theme.of(context).colorScheme.onSurfaceVariant`.
- El `Card` (línea 240) no fija color de fondo, así que ya hereda el de `CardTheme`/superficie — sin cambio.
- Mantener `navy`/`red` (colores de marca) y los `Colors.white` que están sobre esos colores de marca — son intencionales y funcionan igual en ambos temas.

- [ ] **Step 2: `main_layout.dart`**

Aplicar la tabla de mapeo. Puntos concretos:
- `Colors.grey[500]` en `_sectionHeader` (línea 434) → `Theme.of(context).colorScheme.onSurfaceVariant`.
- Los `Colors.white`/`Colors.white70` dentro del `DrawerHeader` (líneas 344-349) y del `AppBar` (líneas 317, 319) se mantienen — están sobre `colorScheme.primary`, que no cambia de brillo entre temas.

- [ ] **Step 3: Verificar visualmente**

Run: `flutter run -d chrome`
Manual: revisar Login y el Drawer/AppBar en modo oscuro y claro.
Expected: legible en ambos modos, sin fondos blancos fijos.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/login_screen.dart lib/screens/main_layout.dart
git commit -m "Fix: login_screen y main_layout usan colores del tema para modo oscuro"
```

---

### Task 14: Sweep de colores — Soporte (tickets, equipos, respaldos, diálogo de equipo)

**Files:**
- Modify: `lib/screens/tickets_screen.dart`, `lib/screens/equipment_screen.dart`, `lib/screens/backups_screen.dart`, `lib/screens/dialogo_nuevo_equipo.dart`

- [ ] **Step 1: Identificar colores fijos en cada archivo**

Run (por cada archivo): `grep -n "Colors\.white\|Colors\.black\|0xFF" lib/screens/tickets_screen.dart lib/screens/equipment_screen.dart lib/screens/backups_screen.dart lib/screens/dialogo_nuevo_equipo.dart`

- [ ] **Step 2: Aplicar la tabla de mapeo de Task 12**

Para cada ocurrencia encontrada en el Step 1: fondos de pantalla/card/header (`Colors.white`, hex claros tipo `0xFFF...`) → `colorScheme.surface` o `surfaceContainerLow`; texto principal (`Colors.black87`) → `colorScheme.onSurface`; texto secundario (`Colors.grey.shade400-600`) → `colorScheme.onSurfaceVariant`; superficies secundarias (`Colors.grey.shade100-200`) → `colorScheme.surfaceContainerHighest`. Dejar intactos los colores semánticos de estado (rojo de error/alerta, verde de éxito, naranja de advertencia, colores de marca `primary`/`secondary` y el texto blanco que va encima de ellos).

- [ ] **Step 3: Verificar visualmente**

Run: `flutter run -d chrome`
Manual: revisar Tickets, Equipos, Respaldos y el diálogo de "Nuevo equipo" en modo oscuro y claro.
Expected: legible en ambos modos.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/tickets_screen.dart lib/screens/equipment_screen.dart lib/screens/backups_screen.dart lib/screens/dialogo_nuevo_equipo.dart
git commit -m "Fix: pantallas de Soporte usan colores del tema para modo oscuro"
```

---

### Task 15: Sweep de colores — Desarrollo (proyectos, detalle de proyecto, tareas)

**Files:**
- Modify: `lib/screens/proyectos_screen.dart`, `lib/screens/proyecto_detalle_screen.dart`, `lib/screens/tareas_screen.dart`

- [ ] **Step 1: Identificar colores fijos**

Run: `grep -n "Colors\.white\|Colors\.black\|0xFF" lib/screens/proyectos_screen.dart lib/screens/proyecto_detalle_screen.dart lib/screens/tareas_screen.dart`

`proyecto_detalle_screen.dart` es el de mayor incidencia (50 ocurrencias) — revisar con cuidado columnas Kanban y tarjetas de tarea, que suelen tener fondos fijos por estado.

- [ ] **Step 2: Aplicar la tabla de mapeo de Task 12**

Igual criterio que Task 14. En las columnas Kanban de `proyecto_detalle_screen.dart`, si hay colores fijos por estado (ej. fondo de columna "Pendiente"/"En progreso"/"Hecho"), mantenerlos como acento pero mezclados con la superficie del tema (ej. `Color.alphaBlend(colorEstado.withValues(alpha: 0.08), Theme.of(context).colorScheme.surface)`) en vez de un blanco fijo, para que el tinte de estado siga siendo visible en oscuro sin quedar ilegible.

- [ ] **Step 3: Verificar visualmente**

Run: `flutter run -d chrome`
Manual: revisar Proyectos, el detalle de un proyecto (Kanban) y Tareas en modo oscuro y claro.
Expected: legible en ambos modos, columnas Kanban distinguibles.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/proyectos_screen.dart lib/screens/proyecto_detalle_screen.dart lib/screens/tareas_screen.dart
git commit -m "Fix: pantallas de Desarrollo usan colores del tema para modo oscuro"
```

---

### Task 16: Sweep de colores — Administración (usuarios, admin, reportes, IA)

**Files:**
- Modify: `lib/screens/users_screen.dart`, `lib/screens/admin_screen.dart`, `lib/screens/reportes_screen.dart`, `lib/screens/ai_screen.dart`

- [ ] **Step 1: Identificar colores fijos**

Run: `grep -n "Colors\.white\|Colors\.black\|0xFF" lib/screens/users_screen.dart lib/screens/admin_screen.dart lib/screens/reportes_screen.dart lib/screens/ai_screen.dart`

- [ ] **Step 2: Aplicar la tabla de mapeo de Task 12**

En `users_screen.dart`, puntos ya identificados: `Color(0xFFF5F7FA)` (línea 194) → `surfaceContainerLow`; `Colors.white` de header (línea 199) → `surface`; `Colors.grey.shade800/600/500` → `onSurface`/`onSurfaceVariant` según el caso. Aplicar el mismo criterio en `admin_screen.dart`, `reportes_screen.dart` y `ai_screen.dart` tras el grep del Step 1. Mantener los colores de rol (badge de "Admin" en azul primary, badge de otros roles en naranja) — son acentos semánticos, no fondos base.

- [ ] **Step 3: Verificar visualmente**

Run: `flutter run -d chrome`
Manual: revisar Gestión de Usuarios (incluyendo el diálogo de editar usuario de Task 6), Administración, Reportes y Asistente IA en modo oscuro y claro.
Expected: legible en ambos modos.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/users_screen.dart lib/screens/admin_screen.dart lib/screens/reportes_screen.dart lib/screens/ai_screen.dart
git commit -m "Fix: pantallas de Administracion usan colores del tema para modo oscuro"
```

---

### Task 17: Sweep de colores — Dashboard

**Files:**
- Modify: `lib/screens/dashboard_screen.dart`

- [ ] **Step 1: Identificar colores fijos**

Run: `grep -n "Colors\.white\|Colors\.black\|0xFF" lib/screens/dashboard_screen.dart`

- [ ] **Step 2: Aplicar la tabla de mapeo de Task 12**

Mismo criterio que las tareas anteriores. El Dashboard suele tener tarjetas de resumen (KPIs) con fondo blanco fijo y texto de color — pasar el fondo a `colorScheme.surface` y dejar los acentos de color (íconos, barras de progreso, semáforos de respaldo) como están, ya que son informativos y deben conservar su significado (amarillo/rojo de alerta de respaldo, etc.) en ambos temas.

- [ ] **Step 3: Verificar visualmente**

Run: `flutter run -d chrome`
Manual: revisar el Dashboard completo (bloques de Soporte y Desarrollo) en modo oscuro y claro.
Expected: legible en ambos modos, semáforos de alerta siguen siendo distinguibles.

- [ ] **Step 4: Commit**

```bash
git add lib/screens/dashboard_screen.dart
git commit -m "Fix: dashboard_screen usa colores del tema para modo oscuro"
```

---

## Verificación y despliegue

### Task 18: Verificación manual end-to-end

**Files:** (ninguno — solo verificación)

- [ ] **Step 1: Levantar la app localmente**

Run: `flutter run -d chrome`

- [ ] **Step 2: Probar modo oscuro**

Manual: abrir Drawer → Apariencia → alternar Claro/Oscuro/Sistema. Confirmar que el cambio se aplica a TODAS las pantallas visitadas (Dashboard, Tickets, Equipos, Respaldos, Proyectos, Tareas, Chat, Usuarios, Administración, Reportes, IA) y que persiste recargando la página (F5) en Chrome.

- [ ] **Step 3: Probar responder y buscar en el chat**

Manual: entrar al Chat, deslizar horizontalmente sobre un mensaje para activar "responder", enviar una respuesta y confirmar que se ve la cita en la burbuja nueva; tocar la cita y confirmar que hace scroll al mensaje original. Usar el ícono de lupa, buscar un texto presente en varios mensajes, confirmar el contador y la navegación con las flechas arriba/abajo.

- [ ] **Step 4: Probar el flujo de contraseña de primer login**

Manual: como Admin, resetear la contraseña de un usuario de prueba desde "Gestión de Usuarios" con una contraseña de 6+ caracteres. Cerrar sesión, iniciar sesión con ese usuario y esa contraseña, y confirmar que aparece el diálogo de "Cambia tu contraseña" (antes no se disparaba). Confirmar que el diálogo ya no acepta contraseñas de 4-5 caracteres (debe pedir mínimo 6).

- [ ] **Step 5: Probar renombrar un username**

Manual: como Admin, editar un usuario de prueba (no el propio) y cambiar su nombre de usuario. Confirmar que guarda sin error y que ese usuario puede seguir iniciando sesión con el nuevo username, viendo sus tickets/mensajes previos (verificando que las referencias se propagaron).

- [ ] **Step 6: Revisar consola de Chrome**

Manual: abrir DevTools → Console mientras se navega por toda la app en ambos temas, confirmar que no hay excepciones nuevas.

No hay commit en esta tarea (solo verificación).

---

### Task 19: Deploy a servidor, GitHub y README

**Files:**
- Modify: `README.md` (si aplica)

- [ ] **Step 1: Confirmar que todo está commiteado**

Run: `git status`
Expected: working tree limpio (todos los cambios de las Tasks 1-18 ya committeados).

- [ ] **Step 2: Actualizar el README si es necesario**

Revisar `README.md` — si ya documenta "chat por canales" y roles (según lo indicado en `CLAUDE.md`), agregar una breve mención de: responder/buscar mensajes en el chat, modo oscuro (Drawer → Apariencia), y que el Admin puede renombrar usuarios desde Gestión de Usuarios. Si el README no tiene una sección de "Funcionalidades" donde encaje, omitir este paso (no crear secciones nuevas sin necesidad).

- [ ] **Step 3: Desplegar el backend al servidor EC2**

Run (PowerShell, desde la raíz del repo):
```powershell
scp -i llave-aws-beta.pem -o StrictHostKeyChecking=no main_api.py ubuntu@54.161.41.131:/home/ubuntu/api-soporte/main.py
ssh -i llave-aws-beta.pem -o StrictHostKeyChecking=no ubuntu@54.161.41.131 "sudo systemctl restart soporte-api.service && sleep 2 && sudo systemctl status soporte-api.service --no-pager"
```
Expected: el servicio reinicia y queda `active (running)`.

- [ ] **Step 4: Verificar el backend en producción**

Run: `ssh -i llave-aws-beta.pem -o StrictHostKeyChecking=no ubuntu@54.161.41.131 "curl -s -o /dev/null -w '%{http_code}' https://soporte.beta.com.mx/api/mensajes"`
Expected: `401` (requiere token — confirma que el proceso responde y no crasheó al iniciar con el nuevo `_ensure_schema()`).

- [ ] **Step 5: Desplegar el frontend**

Run: `./deploy.ps1`
Expected: build exitoso y "Done! Site is live at https://soporte.beta.com.mx".

- [ ] **Step 6: Commit final de README (si se modificó) y push a GitHub**

```bash
git add README.md
git commit -m "Docs: documenta responder/buscar en chat, modo oscuro y renombrar usuario"
git push origin main
```

(Si el README no se modificó en el Step 2, omitir el `git add`/`commit` de este paso y solo hacer `git push origin main` para subir los commits de las Tasks 1-18.)

- [ ] **Step 7: Confirmar el estado final**

Run: `git status && git log --oneline -5`
Expected: working tree limpio, rama `main` al día con `origin/main`.
