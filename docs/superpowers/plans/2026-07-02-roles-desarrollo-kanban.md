# Roles de Desarrollo, Mejoras al Kanban y Chats por Canal — Plan de Implementación

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Abrir el módulo de Proyectos/Tareas a dos nuevos roles (Desarrollador Sr., Desarrollador) con permisos distintos, arreglar el bug de "no puedo ver el detalle de una tarea sin editar", y dividir el chat interno en 3 canales (Soporte, Desarrollo, General) según el rol.

**Architecture:** Cambios de cliente (Flutter) sobre el módulo existente de Proyectos/Tareas (`proyecto_detalle_screen.dart`) y navegación (`main_layout.dart`), más un cambio pequeño y aislado de backend (`main_api.py`) para el campo `canal` de los mensajes. No se agrega enforcement de permisos en el backend — se sigue el mismo patrón ya usado en todo el sistema (roles verificados en el cliente).

**Tech Stack:** Flutter Web (Dart), FastAPI + MySQL (Python) en EC2.

## Global Constraints

- Roles válidos tras este cambio: `Admin`, `Técnico`, `Técnico Sr.`, `Desarrollador Sr.`, `Desarrollador`. Se elimina `Enc. Desarrollo` y `Solo Desarrollo` del código (nadie los tiene asignados en producción — verificado).
- Ningún cambio se sube a GitHub ni se despliega a producción sin aprobación explícita del usuario (última tarea del plan).
- Nombre del paquete Flutter: `soporte_beta` (usar en imports de test: `package:soporte_beta/...`).
- Convención de email de usuarios nuevos: `usuario@beta.com.mx`.
- Backend en `/home/ubuntu/api-soporte/main.py` en el servidor (`ubuntu@54.161.41.131`, llave `llave-aws-beta.pem`); el espejo en este repo es `main_api.py` — ambos deben quedar idénticos en la sección tocada.

---

### Task 1: Backend — canal de chat (`soporte`/`desarrollo`/`general`)

**Files:**
- Modify: `main_api.py:334-338` (clase `MensajeRequest`)
- Modify: `main_api.py` (SELECT de `get_mensajes`, ya usa subquery `ORDER BY fecha DESC LIMIT 200 ... ORDER BY fecha ASC` de una sesión anterior — solo se le agrega la columna `canal`)
- Modify: `main_api.py:1331-1361` (`create_mensaje`)

**Interfaces:**
- Produces: `POST /mensajes` ahora requiere `canal` (string) en el body; responde 400 si no es uno de `soporte`/`desarrollo`/`general`. El payload de respuesta y el broadcast por WebSocket incluyen `canal`. `GET /mensajes` incluye `canal` en cada mensaje.

- [ ] **Step 1: Agregar el campo `canal` a `MensajeRequest`**

Localizar en `main_api.py`:
```python
class MensajeRequest(BaseModel):
    deUsuario: str
    nombreCompleto: str
    texto: str = ''
    imagen: Optional[str] = None
```

Reemplazar por:
```python
CANALES_VALIDOS = {'soporte', 'desarrollo', 'general'}

class MensajeRequest(BaseModel):
    deUsuario: str
    nombreCompleto: str
    texto: str = ''
    imagen: Optional[str] = None
    canal: str
```

- [ ] **Step 2: Incluir `canal` en el SELECT de mensajes**

Buscar el bloque (ya parcheado en una sesión anterior para traer los 200 más recientes):
```python
            cursor.execute("""
                SELECT * FROM (
                    SELECT id, de_usuario AS deUsuario, nombre_completo AS nombreCompleto,
                           texto, imagen, fecha,
                           COALESCE(borrado, 0) AS borrado,
                           borrado_por AS borradoPor
                    FROM mensajes ORDER BY fecha DESC LIMIT 200
                ) sub ORDER BY fecha ASC
            """)
```

Reemplazar por (se agrega `canal,`):
```python
            cursor.execute("""
                SELECT * FROM (
                    SELECT id, de_usuario AS deUsuario, nombre_completo AS nombreCompleto,
                           texto, imagen, fecha, canal,
                           COALESCE(borrado, 0) AS borrado,
                           borrado_por AS borradoPor
                    FROM mensajes ORDER BY fecha DESC LIMIT 200
                ) sub ORDER BY fecha ASC
            """)
```

- [ ] **Step 3: Validar y guardar `canal` en `create_mensaje`**

Reemplazar la función completa:
```python
@app.post("/mensajes")
async def create_mensaje(req: MensajeRequest, current_user: dict = Depends(get_current_user)):
    texto = req.texto.strip() if req.texto else ''
    if not texto and not req.imagen:
        raise HTTPException(status_code=400, detail="El mensaje no puede estar vacío")
    # Identidad siempre del token, nunca del body
    de_usuario = current_user["username"]
    nombre_completo = current_user.get("nombreCompleto") or req.nombreCompleto
    ahora = datetime.now()
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                "INSERT INTO mensajes (de_usuario, nombre_completo, texto, imagen, fecha) VALUES (%s, %s, %s, %s, %s)",
                (de_usuario, nombre_completo, texto, req.imagen, ahora)
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
    }
    await manager.broadcast(payload)
    return payload
```

por:
```python
@app.post("/mensajes")
async def create_mensaje(req: MensajeRequest, current_user: dict = Depends(get_current_user)):
    if req.canal not in CANALES_VALIDOS:
        raise HTTPException(status_code=400, detail="Canal inválido")
    texto = req.texto.strip() if req.texto else ''
    if not texto and not req.imagen:
        raise HTTPException(status_code=400, detail="El mensaje no puede estar vacío")
    # Identidad siempre del token, nunca del body
    de_usuario = current_user["username"]
    nombre_completo = current_user.get("nombreCompleto") or req.nombreCompleto
    ahora = datetime.now()
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
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
    await manager.broadcast(payload)
    return payload
```

- [ ] **Step 4: Verificar que el archivo compila (sintaxis Python)**

Run: `python -m py_compile main_api.py`
Expected: sin salida (éxito).

- [ ] **Step 5: Commit**

```bash
git add main_api.py
git commit -m "Feat: agrega canal (soporte/desarrollo/general) a los mensajes del chat"
```

---

### Task 2: Frontend — `ChatMessage` model y `ApiService.enviarMensaje`

**Files:**
- Modify: `lib/models/chat_message_model.dart`
- Modify: `lib/services/api_service.dart:217-226`

**Interfaces:**
- Consumes: nada nuevo.
- Produces: `ChatMessage.canal` (`String`, default `'soporte'`). `ApiService.enviarMensaje(String deUsuario, String nombreCompleto, String texto, {required String canal, String? imagen})`.

- [ ] **Step 1: Agregar `canal` a `ChatMessage`**

Reemplazar el archivo completo `lib/models/chat_message_model.dart` por:
```dart
DateTime _parseFechaUtc(dynamic raw) {
  final s = raw?.toString() ?? '';
  if (s.isEmpty) return DateTime.now();
  // El backend envía datetime.now().isoformat() sin sufijo de zona horaria,
  // pero el servidor corre en UTC. Sin la 'Z', DateTime.parse lo interpretaría
  // como hora local y desplazaría la hora mostrada.
  final utcStr = (s.endsWith('Z') || RegExp(r'[+-]\d\d:\d\d$').hasMatch(s)) ? s : '${s}Z';
  return DateTime.tryParse(utcStr)?.toLocal() ?? DateTime.now();
}

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
  );
}
```

- [ ] **Step 2: Ejecutar el test existente del modelo (no debe romperse)**

Run: `flutter test test/chat_message_model_test.dart`
Expected: `+1: All tests passed!`

- [ ] **Step 3: Agregar `canal` a `enviarMensaje` en `ApiService`**

Reemplazar en `lib/services/api_service.dart`:
```dart
  Future<void> enviarMensaje(String deUsuario, String nombreCompleto, String texto, {String? imagen}) async {
    final body = <String, dynamic>{'deUsuario': deUsuario, 'nombreCompleto': nombreCompleto, 'texto': texto};
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

Nota: esto rompe temporalmente la compilación de `chat_screen.dart` (llama a `enviarMensaje` sin `canal`) — se corrige en la Task 3. Es esperado, no ejecutar `flutter analyze` sobre todo el proyecto hasta terminar la Task 3.

- [ ] **Step 4: Commit**

```bash
git add lib/models/chat_message_model.dart lib/services/api_service.dart
git commit -m "Feat: agrega campo canal al modelo de chat y a enviarMensaje"
```

---

### Task 3: Frontend — `ChatScreen` con pestañas de canal

**Files:**
- Modify: `lib/screens/chat_screen.dart`

**Interfaces:**
- Consumes: `ChatMessage.canal` (Task 2), `ApiService.enviarMensaje(..., {required String canal, ...})` (Task 2).
- Produces: `ChatScreen` ahora requiere el parámetro `canales: List<String>` (no vacío). Internamente mantiene `_canalActivo` y filtra los mensajes mostrados por canal.

- [ ] **Step 1: Agregar `canales` al constructor de `ChatScreen`**

En `lib/screens/chat_screen.dart`, reemplazar:
```dart
class ChatScreen extends StatefulWidget {
  final List<ChatMessage> mensajes;
  final Session session;
  final ApiService api;
  final List<Usuario> usuarios;
  final VoidCallback? onVolver;
  final Future<void> Function(String id)? onBorrarMensaje;

  const ChatScreen({
    super.key,
    required this.mensajes,
    required this.session,
    required this.api,
    required this.usuarios,
    this.onVolver,
    this.onBorrarMensaje,
  });
```

por:
```dart
class ChatScreen extends StatefulWidget {
  final List<ChatMessage> mensajes;
  final List<String> canales;
  final Session session;
  final ApiService api;
  final List<Usuario> usuarios;
  final VoidCallback? onVolver;
  final Future<void> Function(String id)? onBorrarMensaje;

  const ChatScreen({
    super.key,
    required this.mensajes,
    required this.canales,
    required this.session,
    required this.api,
    required this.usuarios,
    this.onVolver,
    this.onBorrarMensaje,
  });
```

- [ ] **Step 2: Agregar el mapa de etiquetas de canal**

Justo debajo de `_kMeses` (antes de `bool _mismoDia`), agregar:
```dart
const _kCanalLabel = {
  'soporte': 'Soporte',
  'desarrollo': 'Desarrollo',
  'general': 'General',
};
```

- [ ] **Step 3: Agregar estado `_canalActivo` y filtrar mensajes**

Reemplazar:
```dart
class _ChatScreenState extends State<ChatScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _enviando = false;
  String? _imagenSeleccionada;
  List<Usuario> _sugerencias = [];

  @override
  void initState() {
    super.initState();
    _inputCtrl.addListener(_detectarMencion);
  }
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

  List<ChatMessage> get _mensajesDelCanal =>
      widget.mensajes.where((m) => m.canal == _canalActivo).toList();

  @override
  void initState() {
    super.initState();
    _canalActivo = widget.canales.first;
    _inputCtrl.addListener(_detectarMencion);
  }
```

- [ ] **Step 4: Enviar el canal activo al mandar un mensaje**

Reemplazar dentro de `_enviar()`:
```dart
      await widget.api.enviarMensaje(
        widget.session.username,
        widget.session.nombreCompleto,
        texto,
        imagen: imagenEnviar,
      );
```

por:
```dart
      await widget.api.enviarMensaje(
        widget.session.username,
        widget.session.nombreCompleto,
        texto,
        canal: _canalActivo,
        imagen: imagenEnviar,
      );
```

- [ ] **Step 5: Mostrar pestañas de canal y filtrar la lista de mensajes en `build()`**

Reemplazar el inicio de `build()`:
```dart
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final esAdmin = widget.session.rol == 'Admin';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
            color: Colors.white,
            child: Row(
              children: [
                if (widget.onVolver != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: widget.onVolver,
                    tooltip: 'Volver',
                  )
                else
                  const SizedBox(width: 16),
                CircleAvatar(
                  backgroundColor: primary.withValues(alpha: 0.12),
                  child: Icon(Icons.groups_rounded, color: primary, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Chat Interno TI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('Equipo de soporte', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Messages
          Expanded(
            child: widget.mensajes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('Sé el primero en escribir', style: TextStyle(color: Colors.grey.shade400)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    itemCount: widget.mensajes.length,
                    itemBuilder: (_, reversedI) {
                      final i = widget.mensajes.length - 1 - reversedI;
                      final msg = widget.mensajes[i];
                      final esMio = msg.deUsuario == widget.session.username;
                      final nuevoDia = i == 0 || !_mismoDia(widget.mensajes[i - 1].fecha, msg.fecha);
                      final mostrarNombre = !esMio &&
                          (nuevoDia || widget.mensajes[i - 1].deUsuario != msg.deUsuario);

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
                  ),
          ),
```

por:
```dart
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final esAdmin = widget.session.rol == 'Admin';
    final mensajes = _mensajesDelCanal;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(8, 10, 16, 10),
            color: Colors.white,
            child: Row(
              children: [
                if (widget.onVolver != null)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: widget.onVolver,
                    tooltip: 'Volver',
                  )
                else
                  const SizedBox(width: 16),
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
          if (widget.canales.length > 1)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: widget.canales.map((c) {
                  final activo = c == _canalActivo;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: Text(_kCanalLabel[c] ?? c),
                      selected: activo,
                      onSelected: (_) => setState(() => _canalActivo = c),
                      selectedColor: primary,
                      backgroundColor: Colors.grey.shade100,
                      labelStyle: TextStyle(
                        color: activo ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          const Divider(height: 1),

          // Messages
          Expanded(
            child: mensajes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('Sé el primero en escribir', style: TextStyle(color: Colors.grey.shade400)),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollCtrl,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    itemCount: mensajes.length,
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
                  ),
          ),
```

- [ ] **Step 6: Verificar compilación de este archivo**

Run: `flutter analyze lib/screens/chat_screen.dart`
Expected: `No issues found!` (main_layout.dart seguirá roto hasta la Task 4 — es esperado).

- [ ] **Step 7: Commit**

```bash
git add lib/screens/chat_screen.dart
git commit -m "Feat: ChatScreen muestra pestanas de canal cuando hay mas de uno disponible"
```

---

### Task 4: Frontend — roles y navegación en `main_layout.dart`

**Files:**
- Modify: `lib/screens/main_layout.dart`

**Interfaces:**
- Consumes: `ChatScreen(canales: ...)` (Task 3).
- Produces: getters `_tieneSoporte`, `_tieneDesarrollo`, `_esAdmin`, `_chatIndex`, `_canalesChat` en `_MainLayoutState`, usados por `build()`, el drawer y `_manejarMensajeWs`.

- [ ] **Step 1: Agregar los getters de rol/índice/canal**

Justo antes de `@override\n  void initState()`, agregar dentro de `_MainLayoutState`:
```dart
  bool get _tieneSoporte =>
      widget.session.rol != 'Desarrollador Sr.' && widget.session.rol != 'Desarrollador';
  bool get _tieneDesarrollo =>
      widget.session.rol == 'Admin' ||
      widget.session.rol == 'Desarrollador Sr.' ||
      widget.session.rol == 'Desarrollador';
  bool get _esAdmin => widget.session.rol == 'Admin';
  int get _chatIndex => (_tieneSoporte ? 4 : 0) + (_tieneDesarrollo ? 2 : 0);

  List<String> get _canalesChat {
    if (widget.session.rol == 'Admin') return ['soporte', 'desarrollo', 'general'];
    if (widget.session.rol == 'Desarrollador' || widget.session.rol == 'Desarrollador Sr.') {
      return ['desarrollo', 'general'];
    }
    return ['soporte', 'general'];
  }
```

- [ ] **Step 2: Filtrar notificaciones/no-leídos por canal en `_manejarMensajeWs`**

Reemplazar:
```dart
  void _manejarMensajeWs(Map<String, dynamic> datos) {
    final tipo = datos['tipo'] as String? ?? '';
    if (tipo == 'chat') {
      final msg = ChatMessage.fromMap(datos);
      if (_mensajes.any((m) => m.id == msg.id)) return;
      setState(() {
        _mensajes = [..._mensajes, msg];
        if (_screenIndex != 4) _mensajesNoLeidos++;
      });
      if (_screenIndex != 4) {
        NotificationService.lanzarAlertaLocal(
          'Mensaje de ${msg.nombreCompleto}',
          msg.texto.isNotEmpty ? msg.texto : '📷 Imagen',
        );
      }
    } else if (tipo == 'chat_borrado') {
```

por:
```dart
  void _manejarMensajeWs(Map<String, dynamic> datos) {
    final tipo = datos['tipo'] as String? ?? '';
    if (tipo == 'chat') {
      final msg = ChatMessage.fromMap(datos);
      if (_mensajes.any((m) => m.id == msg.id)) return;
      final esVisible = _canalesChat.contains(msg.canal);
      setState(() {
        _mensajes = [..._mensajes, msg];
        if (esVisible && _screenIndex != _chatIndex) _mensajesNoLeidos++;
      });
      if (esVisible && _screenIndex != _chatIndex) {
        NotificationService.lanzarAlertaLocal(
          'Mensaje de ${msg.nombreCompleto}',
          msg.texto.isNotEmpty ? msg.texto : '📷 Imagen',
        );
      }
    } else if (tipo == 'chat_borrado') {
```

- [ ] **Step 3: Reescribir `build()` para que el chat sea independiente de "tener soporte"**

Reemplazar desde `if (_cargandoInicial)` hasta el cierre de `build()` (todo el bloque que arma `screens`, el `Scaffold` de nivel superior con `floatingActionButton`, `appBar`, `drawer` y `body` — el `AppBar` interno NO cambia, solo se copia tal cual):

```dart
  @override
  Widget build(BuildContext context) {
    if (_cargandoInicial) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final screens = [
      if (_tieneSoporte) ...[
        DashboardScreen(tickets: _tickets, inventario: _inventario, session: widget.session, onNavigate: (i) => setState(() => _screenIndex = i)),
        TicketsScreen(tickets: _tickets, usuarios: _usuarios, session: widget.session, api: _api, onRefresh: () => _cargarDatos(silencioso: true)),
        EquipmentScreen(inventario: _inventario, session: widget.session, api: _api, onRefresh: () => _cargarDatos(silencioso: true)),
        PantallaRespaldos(inventario: _inventario, api: _api, onRefresh: () => _cargarDatos(silencioso: true), session: widget.session),
      ],
      if (_tieneDesarrollo) ...[
        ProyectosScreen(api: _api, session: widget.session),
        TareasScreen(api: _api, session: widget.session),
      ],
      ChatScreen(
        mensajes: _mensajes,
        canales: _canalesChat,
        session: widget.session,
        api: _api,
        usuarios: _usuarios,
        onVolver: () => setState(() => _screenIndex = _screenAnterior),
        onBorrarMensaje: (id) async {
          await _api.borrarMensaje(id);
          setState(() {
            _mensajes = _mensajes.map((m) => m.id == id ? m.copyWith(borrado: true, borradoPor: widget.session.username) : m).toList();
          });
        },
      ),
      if (_esAdmin) ...[
        UsersScreen(usuarios: _usuarios, api: _api, onRefresh: _cargarUsuarios),
        AdminScreen(api: _api),
        ReportesScreen(api: _api),
        AiScreen(api: _api, session: widget.session),
      ],
    ];

    return Scaffold(
      floatingActionButton: _screenIndex != _chatIndex ? _buildFabChat() : null,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: Text(
          'Soporte Beta — ${widget.session.rol}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(_notifPermiso == 'granted' ? Icons.notifications_active : Icons.notifications_off),
            tooltip: _notifPermiso == 'granted' ? 'Notificaciones activas' : 'Activar notificaciones',
            color: _notifPermiso == 'granted' ? Colors.greenAccent : Colors.white60,
            onPressed: _notifPermiso == 'granted' ? null : _pedirPermisoNotificaciones,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: () => _cargarDatos(silencioso: true), tooltip: 'Recargar'),
          IconButton(icon: const Icon(Icons.logout_rounded), onPressed: _logout, tooltip: 'Cerrar sesión'),
        ],
      ),
      drawer: Builder(builder: (ctx) {
        final int soporteCount = _tieneSoporte ? 4 : 0;
        final int devOffset = _tieneDesarrollo ? soporteCount : -1;
        final int adminOffset = _chatIndex + 1;

        return Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.monitor_heart, size: 36, color: Colors.white),
                    const SizedBox(height: 8),
                    Text(widget.session.nombreCompleto,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('${widget.session.rol}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              // ── Soporte Técnico ──────────────────────────────────────
              if (_tieneSoporte) ...[
                _sectionHeader('Soporte Técnico'),
                _item(Icons.dashboard_rounded, 'Dashboard', 0),
                _item(Icons.confirmation_number_rounded, 'Tickets / Asignaciones', 1),
                _item(Icons.computer_rounded, 'Equipos / Responsivas', 2),
                _item(Icons.backup_rounded, 'Control de Respaldos', 3),
              ],
              // ── Desarrollo ───────────────────────────────────────────
              if (_tieneDesarrollo) ...[
                const Divider(indent: 16, endIndent: 16),
                _sectionHeader('Desarrollo'),
                _item(Icons.folder_special_rounded, 'Proyectos', devOffset),
                _item(Icons.task_alt_rounded, 'Tareas', devOffset + 1),
              ],
              // ── Chat ───────────────────────────────────────────────
              const Divider(indent: 16, endIndent: 16),
              _itemChat(),
              // ── Administración ───────────────────────────────────────
              if (_esAdmin) ...[
                const Divider(indent: 16, endIndent: 16),
                _sectionHeader('Administración'),
                _item(Icons.manage_accounts_rounded, 'Gestión de Usuarios', adminOffset),
                _item(Icons.settings_rounded, 'Administración', adminOffset + 1),
                _item(Icons.bar_chart_rounded, 'Reportes', adminOffset + 2),
                _item(Icons.smart_toy_rounded, 'Asistente IA', adminOffset + 3),
              ],
            ],
          ),
        );
      }),
      body: _screenIndex < screens.length ? screens[_screenIndex] : screens[0],
    );
  }
```

- [ ] **Step 4: Usar `_chatIndex` en `_buildFabChat` y `_itemChat`**

Reemplazar en `_buildFabChat`:
```dart
          setState(() {
            _screenAnterior = _screenIndex;
            _screenIndex = 4;
            _mensajesNoLeidos = 0;
          });
```
(dentro de `FloatingActionButton.onPressed`) por:
```dart
          setState(() {
            _screenAnterior = _screenIndex;
            _screenIndex = _chatIndex;
            _mensajesNoLeidos = 0;
          });
```

Reemplazar en `_itemChat()`:
```dart
        title: const Text('Chat Interno'),
        selected: _screenIndex == 4,
        onTap: () {
          setState(() {
            _screenAnterior = _screenIndex;
            _screenIndex = 4;
            _mensajesNoLeidos = 0;
          });
          Navigator.pop(context);
        },
```
por:
```dart
        title: const Text('Chat Interno'),
        selected: _screenIndex == _chatIndex,
        onTap: () {
          setState(() {
            _screenAnterior = _screenIndex;
            _screenIndex = _chatIndex;
            _mensajesNoLeidos = 0;
          });
          Navigator.pop(context);
        },
```

- [ ] **Step 5: Verificar compilación**

Run: `flutter analyze lib/screens/main_layout.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/screens/main_layout.dart
git commit -m "Feat: chat interno independiente de soporte, con canales por rol"
```

---

### Task 5: Frontend — rol `Desarrollador Sr.` en el alta de usuarios

**Files:**
- Modify: `lib/screens/users_screen.dart:80-85`

**Interfaces:**
- Consumes: nada.
- Produces: el dropdown de rol ofrece `Desarrollador Sr.` en vez de `Enc. Desarrollo`, y ya no ofrece `Solo Desarrollo`.

- [ ] **Step 1: Actualizar el dropdown de roles**

Reemplazar:
```dart
                      DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'Técnico', child: Text('Técnico')),
                      DropdownMenuItem(value: 'Técnico Sr.', child: Text('Técnico Sr.')),
                      DropdownMenuItem(value: 'Enc. Desarrollo', child: Text('Enc. Desarrollo')),
                      DropdownMenuItem(value: 'Desarrollador', child: Text('Desarrollador')),
                      DropdownMenuItem(value: 'Solo Desarrollo', child: Text('Solo Desarrollo')),
```

por:
```dart
                      DropdownMenuItem(value: 'Admin', child: Text('Admin')),
                      DropdownMenuItem(value: 'Técnico', child: Text('Técnico')),
                      DropdownMenuItem(value: 'Técnico Sr.', child: Text('Técnico Sr.')),
                      DropdownMenuItem(value: 'Desarrollador Sr.', child: Text('Desarrollador Sr.')),
                      DropdownMenuItem(value: 'Desarrollador', child: Text('Desarrollador')),
```

- [ ] **Step 2: Verificar compilación**

Run: `flutter analyze lib/screens/users_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/users_screen.dart
git commit -m "Feat: renombra rol Enc. Desarrollo a Desarrollador Sr., quita Solo Desarrollo"
```

---

### Task 6: Frontend — permiso de edición en `proyectos_screen.dart`

**Files:**
- Modify: `lib/screens/proyectos_screen.dart:24-25`

**Interfaces:**
- Produces: `_puedeEditar` en `_ProyectosScreenState` es `true` para `Admin` y `Desarrollador Sr.`.

- [ ] **Step 1: Renombrar el rol en el check**

Reemplazar:
```dart
  bool get _puedeEditar =>
      widget.session.rol == 'Admin' || widget.session.rol == 'Enc. Desarrollo';
```
por:
```dart
  bool get _puedeEditar =>
      widget.session.rol == 'Admin' || widget.session.rol == 'Desarrollador Sr.';
```

- [ ] **Step 2: Verificar compilación**

Run: `flutter analyze lib/screens/proyectos_screen.dart`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
git add lib/screens/proyectos_screen.dart
git commit -m "Fix: proyectos_screen usa el rol renombrado Desarrollador Sr."
```

---

### Task 7: Frontend — Kanban: ver detalle, permiso de mover, fechas visibles

**Files:**
- Modify: `lib/screens/proyecto_detalle_screen.dart:36-37` (`_puedeEditar`)
- Modify: `lib/screens/proyecto_detalle_screen.dart:214-461` (`_KanbanView`, `_KanbanColumna`, `_TareaCard`, `_CardBody`; agrega `puedeMoverTarea` y `_DialogoVerTarea`)
- Modify: `lib/screens/proyecto_detalle_screen.dart` (llamada a `_KanbanView` dentro de `build()`, y nuevo método `_verTarea`)

**Interfaces:**
- Produces: función top-level `bool puedeMoverTarea({required String rol, required String? asignadoAUsername, required String username})` — usada también por la Task 9 (`tareas_screen.dart`).
- Produces: `_KanbanView({tareas, session, puedeEditar, onCambiarEstado, onVerDetalle})` (reemplaza los antiguos `onEditar`/`onEliminar`).

- [ ] **Step 1: Renombrar el rol en `_puedeEditar`**

Reemplazar:
```dart
  bool get _puedeEditar =>
      widget.session.rol == 'Admin' || widget.session.rol == 'Enc. Desarrollo';
```
por:
```dart
  bool get _puedeEditar =>
      widget.session.rol == 'Admin' || widget.session.rol == 'Desarrollador Sr.';
```

- [ ] **Step 2: Agregar el método `_verTarea` a `_ProyectoDetalleScreenState`**

Justo después del método `_eliminarTarea` (antes de `@override\n  Widget build(BuildContext context) {`), agregar:
```dart
  void _verTarea(Tarea t) {
    showDialog(
      context: context,
      builder: (_) => _DialogoVerTarea(
        tarea: t,
        puedeEditar: _puedeEditar,
        onEditar: () => _abrirDialogoTarea(t),
        onEliminar: () => _eliminarTarea(t),
      ),
    );
  }
```

- [ ] **Step 3: Actualizar la llamada a `_KanbanView` en `build()`**

Reemplazar:
```dart
                _KanbanView(
                  tareas: _tareas,
                  session: widget.session,
                  onCambiarEstado: _cambiarEstado,
                  onEditar: _puedeEditar ? _abrirDialogoTarea : null,
                  onEliminar: _puedeEditar ? _eliminarTarea : null,
                ),
```
por:
```dart
                _KanbanView(
                  tareas: _tareas,
                  session: widget.session,
                  puedeEditar: _puedeEditar,
                  onCambiarEstado: _cambiarEstado,
                  onVerDetalle: _verTarea,
                ),
```

(La Task 8 envuelve este mismo bloque en un `Column` con la barra de filtros — se hace ahí, no aquí, para no pisar el cambio.)

- [ ] **Step 4: Reemplazar el bloque Kanban completo (`_KanbanView` hasta el final de `_CardBody`)**

Reemplazar TODO el bloque desde `class _KanbanView extends StatelessWidget {` hasta el `}` de cierre de `class _CardBody` (líneas 214–461 del archivo original) por:

```dart
class _KanbanView extends StatelessWidget {
  final List<Tarea> tareas;
  final Session session;
  final bool puedeEditar;
  final void Function(Tarea, String) onCambiarEstado;
  final void Function(Tarea) onVerDetalle;

  const _KanbanView({
    required this.tareas,
    required this.session,
    required this.puedeEditar,
    required this.onCambiarEstado,
    required this.onVerDetalle,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _kEstados
            .map((estado) => _KanbanColumna(
                  estado: estado,
                  tareas: tareas.where((t) => t.estado == estado).toList(),
                  session: session,
                  puedeEditar: puedeEditar,
                  onDrop: (t) => onCambiarEstado(t, estado),
                  onVerDetalle: onVerDetalle,
                ))
            .toList(),
      ),
    );
  }
}

class _KanbanColumna extends StatefulWidget {
  final String estado;
  final List<Tarea> tareas;
  final Session session;
  final bool puedeEditar;
  final void Function(Tarea) onDrop;
  final void Function(Tarea) onVerDetalle;

  const _KanbanColumna({
    required this.estado,
    required this.tareas,
    required this.session,
    required this.puedeEditar,
    required this.onDrop,
    required this.onVerDetalle,
  });

  @override
  State<_KanbanColumna> createState() => _KanbanColumnaState();
}

class _KanbanColumnaState extends State<_KanbanColumna> {
  bool _accepting = false;

  @override
  Widget build(BuildContext context) {
    final color = _kEstadoColor[widget.estado]!;
    return DragTarget<Tarea>(
      onWillAcceptWithDetails: (d) => d.data.estado != widget.estado,
      onAcceptWithDetails: (d) { widget.onDrop(d.data); setState(() => _accepting = false); },
      onMove: (_) => setState(() => _accepting = true),
      onLeave: (_) => setState(() => _accepting = false),
      builder: (ctx, candidates, _) {
        return Container(
          width: 260,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: _accepting ? color.withValues(alpha: 0.08) : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _accepting ? color : Colors.grey[300]!,
              width: _accepting ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                ),
                child: Row(
                  children: [
                    Text(
                      _kEstadoLabel[widget.estado]!,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${widget.tareas.length}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              // Cards
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 120, maxHeight: 520),
                child: widget.tareas.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('Sin tareas',
                            style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(8),
                        itemCount: widget.tareas.length,
                        itemBuilder: (_, i) => _TareaCard(
                          tarea: widget.tareas[i],
                          session: widget.session,
                          puedeEditar: widget.puedeEditar,
                          onVerDetalle: () => widget.onVerDetalle(widget.tareas[i]),
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// true si el usuario puede arrastrar/mover esta tarea en el Kanban:
/// Admin y Desarrollador Sr. mueven cualquiera; un Desarrollador solo la suya.
bool puedeMoverTarea({
  required String rol,
  required String? asignadoAUsername,
  required String username,
}) =>
    rol == 'Admin' || rol == 'Desarrollador Sr.' || asignadoAUsername == username;

const List<double> _kMatrizGrises = [
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0.2126, 0.7152, 0.0722, 0, 0,
  0, 0, 0, 1, 0,
];

class _TareaCard extends StatelessWidget {
  final Tarea tarea;
  final Session session;
  final bool puedeEditar;
  final VoidCallback onVerDetalle;

  const _TareaCard({
    required this.tarea,
    required this.session,
    required this.puedeEditar,
    required this.onVerDetalle,
  });

  bool get _puedeMover => puedeEditar ||
      puedeMoverTarea(rol: session.rol, asignadoAUsername: tarea.asignadoAUsername, username: session.username);

  Color get _prioColor => switch (tarea.prioridad) {
        'alta' => Colors.red[400]!,
        'baja' => Colors.green[400]!,
        _ => Colors.blue[400]!,
      };

  @override
  Widget build(BuildContext context) {
    final body = GestureDetector(
      onTap: onVerDetalle,
      child: _CardBody(tarea: tarea, prioColor: _prioColor, atenuada: !_puedeMover),
    );
    if (!_puedeMover) return body;
    return Draggable<Tarea>(
      data: tarea,
      feedback: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(width: 244, child: _CardBody(tarea: tarea, prioColor: _prioColor)),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: body),
      child: body,
    );
  }
}

class _CardBody extends StatelessWidget {
  final Tarea tarea;
  final Color prioColor;
  final bool atenuada;

  const _CardBody({required this.tarea, required this.prioColor, this.atenuada = false});

  String _fmt(DateTime? d) =>
      d == null ? '—' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final card = Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: prioColor, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(tarea.titulo,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ],
            ),
            if (tarea.descripcion.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(tarea.descripcion,
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
            ],
            const SizedBox(height: 6),
            Row(
              children: [
                if (tarea.asignadoANombre != null) ...[
                  Icon(Icons.person_outline, size: 12, color: Colors.grey[500]),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(tarea.asignadoANombre!,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        overflow: TextOverflow.ellipsis),
                  ),
                ] else
                  const Expanded(child: SizedBox()),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: prioColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(tarea.prioridad,
                      style: TextStyle(fontSize: 10, color: prioColor, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            if (tarea.fechaInicio != null || tarea.fechaFin != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 11, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text('${_fmt(tarea.fechaInicio)} → ${_fmt(tarea.fechaFin)}',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                ],
              ),
            ],
          ],
        ),
      ),
    );
    if (!atenuada) return card;
    return Opacity(
      opacity: 0.55,
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(_kMatrizGrises),
        child: card,
      ),
    );
  }
}

class _DialogoVerTarea extends StatelessWidget {
  final Tarea tarea;
  final bool puedeEditar;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  const _DialogoVerTarea({
    required this.tarea,
    required this.puedeEditar,
    required this.onEditar,
    required this.onEliminar,
  });

  String _fmt(DateTime? d) => d == null
      ? 'Sin fecha'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _fila(String label, String valor) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ),
            Expanded(child: Text(valor, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tarea.titulo),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (tarea.descripcion.isNotEmpty) ...[
              Text(tarea.descripcion, style: TextStyle(color: Colors.grey[700])),
              const SizedBox(height: 14),
            ],
            _fila('Estado', _kEstadoLabel[tarea.estado] ?? tarea.estado),
            _fila('Prioridad', tarea.prioridad),
            _fila('Asignado a', tarea.asignadoANombre ?? 'Sin asignar'),
            _fila('Fecha inicio', _fmt(tarea.fechaInicio)),
            _fila('Fecha fin', _fmt(tarea.fechaFin)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
        if (puedeEditar) ...[
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            onPressed: () { Navigator.pop(context); onEliminar(); },
            child: const Text('Eliminar'),
          ),
          FilledButton(
            onPressed: () { Navigator.pop(context); onEditar(); },
            child: const Text('Editar'),
          ),
        ],
      ],
    );
  }
}
```

- [ ] **Step 5: Verificar compilación (los filtros de la Task 8 aún no existen — se espera un error ahí, no en este bloque)**

Run: `flutter analyze lib/screens/proyecto_detalle_screen.dart`
Expected: sin errores relacionados a `_KanbanView`, `_TareaCard`, `_CardBody`, `_DialogoVerTarea` o `puedeMoverTarea`. (Puede haber errores de `_DialogoTarea` que se resuelven en la Task 9 — si aparecen ahí, es esperado en este punto.)

- [ ] **Step 6: Commit**

```bash
git add lib/screens/proyecto_detalle_screen.dart
git commit -m "Feat: tap en tarjeta del Kanban abre detalle; drag solo si el usuario puede moverla"
```

---

### Task 8: Frontend — barra de filtros del Kanban

**Files:**
- Modify: `lib/screens/proyecto_detalle_screen.dart` (estado de filtros en `_ProyectoDetalleScreenState`, nuevas clases `_FiltrosKanban`/`_FiltroChipTarea`)

**Interfaces:**
- Consumes: `_KanbanView` de la Task 7.
- Produces: filtra la lista de tareas mostrada en el Kanban por texto, asignado y prioridad; no afecta la pestaña Gantt.

- [ ] **Step 1: Agregar estado y getter de filtros a `_ProyectoDetalleScreenState`**

Reemplazar:
```dart
class _ProyectoDetalleScreenState extends State<ProyectoDetalleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<Tarea> _tareas = [];
  bool _cargando = true;

  bool get _puedeEditar =>
      widget.session.rol == 'Admin' || widget.session.rol == 'Desarrollador Sr.';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
```

por:
```dart
class _ProyectoDetalleScreenState extends State<ProyectoDetalleScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<Tarea> _tareas = [];
  bool _cargando = true;

  final _busquedaCtrl = TextEditingController();
  String _busqueda = '';
  String? _asignadoFiltro;
  String? _prioridadFiltro;

  bool get _puedeEditar =>
      widget.session.rol == 'Admin' || widget.session.rol == 'Desarrollador Sr.';

  List<Tarea> get _tareasFiltradas => _tareas.where((t) {
        if (_busqueda.isNotEmpty &&
            !t.titulo.toLowerCase().contains(_busqueda) &&
            !t.descripcion.toLowerCase().contains(_busqueda)) {
          return false;
        }
        if (_asignadoFiltro != null && t.asignadoAUsername != _asignadoFiltro) return false;
        if (_prioridadFiltro != null && t.prioridad != _prioridadFiltro) return false;
        return true;
      }).toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargar();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _busquedaCtrl.dispose();
    super.dispose();
  }
```

- [ ] **Step 2: Envolver `_KanbanView` con la barra de filtros en `build()`**

Reemplazar (cambio hecho en la Task 7, Step 3):
```dart
                _KanbanView(
                  tareas: _tareas,
                  session: widget.session,
                  puedeEditar: _puedeEditar,
                  onCambiarEstado: _cambiarEstado,
                  onVerDetalle: _verTarea,
                ),
```
por:
```dart
                Column(
                  children: [
                    _FiltrosKanban(
                      tareas: _tareas,
                      busquedaCtrl: _busquedaCtrl,
                      onBusqueda: (v) => setState(() => _busqueda = v.toLowerCase()),
                      asignadoFiltro: _asignadoFiltro,
                      onAsignadoChanged: (v) => setState(() => _asignadoFiltro = v),
                      prioridadFiltro: _prioridadFiltro,
                      onPrioridadChanged: (v) => setState(() => _prioridadFiltro = v),
                    ),
                    Expanded(
                      child: _KanbanView(
                        tareas: _tareasFiltradas,
                        session: widget.session,
                        puedeEditar: _puedeEditar,
                        onCambiarEstado: _cambiarEstado,
                        onVerDetalle: _verTarea,
                      ),
                    ),
                  ],
                ),
```

- [ ] **Step 3: Agregar `_FiltrosKanban` y `_FiltroChipTarea`**

Insertar estas dos clases nuevas justo antes de `class _KanbanView extends StatelessWidget {`:
```dart
class _FiltrosKanban extends StatelessWidget {
  final List<Tarea> tareas;
  final TextEditingController busquedaCtrl;
  final ValueChanged<String> onBusqueda;
  final String? asignadoFiltro;
  final ValueChanged<String?> onAsignadoChanged;
  final String? prioridadFiltro;
  final ValueChanged<String?> onPrioridadChanged;

  const _FiltrosKanban({
    required this.tareas,
    required this.busquedaCtrl,
    required this.onBusqueda,
    required this.asignadoFiltro,
    required this.onAsignadoChanged,
    required this.prioridadFiltro,
    required this.onPrioridadChanged,
  });

  @override
  Widget build(BuildContext context) {
    final asignados = <String, String>{};
    for (final t in tareas) {
      if (t.asignadoAUsername != null && t.asignadoANombre != null) {
        asignados[t.asignadoAUsername!] = t.asignadoANombre!;
      }
    }
    final hayFiltros = asignadoFiltro != null || prioridadFiltro != null || busquedaCtrl.text.isNotEmpty;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(
              width: 220,
              child: TextField(
                controller: busquedaCtrl,
                onChanged: onBusqueda,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Buscar tarea...',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 10),
            _FiltroChipTarea(
              label: asignadoFiltro == null ? 'Asignado a' : (asignados[asignadoFiltro] ?? asignadoFiltro!),
              activo: asignadoFiltro != null,
              onTap: () async {
                final v = await showDialog<String?>(
                  context: context,
                  builder: (_) => SimpleDialog(
                    title: const Text('Filtrar por asignado'),
                    children: [
                      SimpleDialogOption(onPressed: () => Navigator.pop(context, null), child: const Text('Todos')),
                      ...asignados.entries.map((e) =>
                          SimpleDialogOption(onPressed: () => Navigator.pop(context, e.key), child: Text(e.value))),
                    ],
                  ),
                );
                onAsignadoChanged(v);
              },
            ),
            const SizedBox(width: 8),
            _FiltroChipTarea(
              label: prioridadFiltro ?? 'Prioridad',
              activo: prioridadFiltro != null,
              onTap: () async {
                final v = await showDialog<String?>(
                  context: context,
                  builder: (_) => SimpleDialog(
                    title: const Text('Filtrar por prioridad'),
                    children: [
                      SimpleDialogOption(onPressed: () => Navigator.pop(context, null), child: const Text('Todas')),
                      SimpleDialogOption(onPressed: () => Navigator.pop(context, 'alta'), child: const Text('Alta')),
                      SimpleDialogOption(onPressed: () => Navigator.pop(context, 'media'), child: const Text('Media')),
                      SimpleDialogOption(onPressed: () => Navigator.pop(context, 'baja'), child: const Text('Baja')),
                    ],
                  ),
                );
                onPrioridadChanged(v);
              },
            ),
            if (hayFiltros) ...[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: () {
                  busquedaCtrl.clear();
                  onBusqueda('');
                  onAsignadoChanged(null);
                  onPrioridadChanged(null);
                },
                icon: const Icon(Icons.clear, size: 14),
                label: const Text('Limpiar'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FiltroChipTarea extends StatelessWidget {
  final String label;
  final bool activo;
  final VoidCallback onTap;

  const _FiltroChipTarea({required this.label, required this.activo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: activo ? const Color(0xFF1A2B72) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: activo ? const Color(0xFF1A2B72) : Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    color: activo ? Colors.white : Colors.grey[700],
                    fontWeight: activo ? FontWeight.bold : FontWeight.normal)),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 16, color: activo ? Colors.white : Colors.grey[600]),
          ],
        ),
      ),
    );
  }
}

```

- [ ] **Step 4: Verificar compilación**

Run: `flutter analyze lib/screens/proyecto_detalle_screen.dart`
Expected: sin errores nuevos relacionados a `_FiltrosKanban`/`_FiltroChipTarea`/filtros. (El dropdown de `_DialogoTarea` se corrige en la Task 9.)

- [ ] **Step 5: Commit**

```bash
git add lib/screens/proyecto_detalle_screen.dart
git commit -m "Feat: agrega filtros de busqueda/asignado/prioridad al Kanban"
```

---

### Task 9: Frontend — asignar solo a desarrolladores + permiso consistente en `tareas_screen.dart`

**Files:**
- Modify: `lib/screens/proyecto_detalle_screen.dart:1294-1303` (`_DialogoTareaState`, dropdown "Asignar a")
- Modify: `lib/screens/tareas_screen.dart`

**Interfaces:**
- Consumes: `puedeMoverTarea` (Task 7, exportado desde `proyecto_detalle_screen.dart`).
- Produces: el dropdown de asignación en `_DialogoTarea` solo lista usuarios con rol `Desarrollador`/`Desarrollador Sr.` (más el asignado actual si ya no calificara). La lista plana de "Tareas" respeta la misma regla de movimiento que el Kanban.

- [ ] **Step 1: Filtrar el dropdown de asignación en `_DialogoTareaState`**

Agregar este getter dentro de `_DialogoTareaState`, justo antes de `void _guardar() {`:
```dart
  List<Usuario> get _asignables {
    final devs = widget.usuarios
        .where((u) => u.rol == 'Desarrollador' || u.rol == 'Desarrollador Sr.')
        .toList();
    if (_asignadoA != null && !devs.any((u) => u.username == _asignadoA)) {
      final actual = widget.usuarios.where((u) => u.username == _asignadoA);
      if (actual.isNotEmpty) devs.add(actual.first);
    }
    return devs;
  }
```

Reemplazar:
```dart
                DropdownButtonFormField<String?>(
                  value: _asignadoA,
                  decoration: const InputDecoration(labelText: 'Asignar a'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Sin asignar')),
                    ...widget.usuarios.map((u) =>
                        DropdownMenuItem(value: u.username, child: Text(u.nombreCompleto))),
                  ],
                  onChanged: (v) => setState(() => _asignadoA = v),
                ),
```
por:
```dart
                DropdownButtonFormField<String?>(
                  value: _asignadoA,
                  decoration: const InputDecoration(labelText: 'Asignar a'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Sin asignar')),
                    ..._asignables.map((u) =>
                        DropdownMenuItem(value: u.username, child: Text(u.nombreCompleto))),
                  ],
                  onChanged: (v) => setState(() => _asignadoA = v),
                ),
```

- [ ] **Step 2: Importar `puedeMoverTarea` y gatear el cambio de estado en `tareas_screen.dart`**

Al inicio de `lib/screens/tareas_screen.dart`, agregar el import:
```dart
import 'proyecto_detalle_screen.dart' show puedeMoverTarea;
```

Agregar este método en `_TareasScreenState`, justo antes de `Future<void> _cambiarEstado(...)`:
```dart
  bool _puedeMover(Tarea t) => puedeMoverTarea(
        rol: widget.session.rol,
        asignadoAUsername: t.asignadoAUsername,
        username: widget.session.username,
      );
```

Reemplazar la construcción de `_TareaFila` en el `ListView.builder`:
```dart
                      itemBuilder: (_, i) => _TareaFila(
                        tarea: lista[i],
                        estadoColor: _estadoColor,
                        estadoLabel: _estadoLabel,
                        onEstadoChanged: (e) => _cambiarEstado(lista[i], e),
                      ),
```
por:
```dart
                      itemBuilder: (_, i) => _TareaFila(
                        tarea: lista[i],
                        estadoColor: _estadoColor,
                        estadoLabel: _estadoLabel,
                        puedeMover: _puedeMover(lista[i]),
                        onEstadoChanged: (e) => _cambiarEstado(lista[i], e),
                      ),
```

- [ ] **Step 3: Gatear el `PopupMenuButton` de estado en `_TareaFila`**

Reemplazar la clase completa `_TareaFila` (constructor y campo):
```dart
class _TareaFila extends StatelessWidget {
  final Tarea tarea;
  final Map<String, Color> estadoColor;
  final Map<String, String> estadoLabel;
  final void Function(String) onEstadoChanged;

  const _TareaFila({
    required this.tarea,
    required this.estadoColor,
    required this.estadoLabel,
    required this.onEstadoChanged,
  });
```
por:
```dart
class _TareaFila extends StatelessWidget {
  final Tarea tarea;
  final Map<String, Color> estadoColor;
  final Map<String, String> estadoLabel;
  final bool puedeMover;
  final void Function(String) onEstadoChanged;

  const _TareaFila({
    required this.tarea,
    required this.estadoColor,
    required this.estadoLabel,
    required this.puedeMover,
    required this.onEstadoChanged,
  });
```

Reemplazar dentro de `build()`:
```dart
                PopupMenuButton<String>(
                  child: Chip(
                    label: Text(estadoLabel[tarea.estado] ?? tarea.estado,
                        style:
                            const TextStyle(fontSize: 11, color: Colors.white)),
                    backgroundColor: eColor,
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  itemBuilder: (_) => estadoLabel.entries
                      .map((e) =>
                          PopupMenuItem(value: e.key, child: Text(e.value)))
                      .toList(),
                  onSelected: onEstadoChanged,
                ),
```
por:
```dart
                puedeMover
                    ? PopupMenuButton<String>(
                        child: Chip(
                          label: Text(estadoLabel[tarea.estado] ?? tarea.estado,
                              style: const TextStyle(fontSize: 11, color: Colors.white)),
                          backgroundColor: eColor,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        itemBuilder: (_) => estadoLabel.entries
                            .map((e) => PopupMenuItem(value: e.key, child: Text(e.value)))
                            .toList(),
                        onSelected: onEstadoChanged,
                      )
                    : Chip(
                        label: Text(estadoLabel[tarea.estado] ?? tarea.estado,
                            style: const TextStyle(fontSize: 11, color: Colors.white)),
                        backgroundColor: eColor,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
```

- [ ] **Step 4: Verificar compilación de todo el proyecto**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 5: Commit**

```bash
git add lib/screens/proyecto_detalle_screen.dart lib/screens/tareas_screen.dart
git commit -m "Fix: asignar tarea solo a desarrolladores; lista de Tareas respeta el mismo permiso de mover que el Kanban"
```

---

### Task 10: Test — `puedeMoverTarea`

**Files:**
- Create: `test/puede_mover_tarea_test.dart`

**Interfaces:**
- Consumes: `puedeMoverTarea` de `package:soporte_beta/screens/proyecto_detalle_screen.dart` (Task 7).

- [ ] **Step 1: Escribir el test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:soporte_beta/screens/proyecto_detalle_screen.dart';

void main() {
  test('Admin y Desarrollador Sr. pueden mover cualquier tarea; un Desarrollador solo la suya', () {
    expect(
      puedeMoverTarea(rol: 'Admin', asignadoAUsername: 'lfabela', username: 'cmartinez'),
      isTrue,
    );
    expect(
      puedeMoverTarea(rol: 'Desarrollador Sr.', asignadoAUsername: 'mgallegos', username: 'lfabela'),
      isTrue,
    );
    expect(
      puedeMoverTarea(rol: 'Desarrollador', asignadoAUsername: 'mgallegos', username: 'mgallegos'),
      isTrue,
    );
    expect(
      puedeMoverTarea(rol: 'Desarrollador', asignadoAUsername: 'lfabela', username: 'mgallegos'),
      isFalse,
    );
    expect(
      puedeMoverTarea(rol: 'Desarrollador', asignadoAUsername: null, username: 'mgallegos'),
      isFalse,
    );
  });
}
```

- [ ] **Step 2: Ejecutar el test**

Run: `flutter test test/puede_mover_tarea_test.dart`
Expected: `+1: All tests passed!`

- [ ] **Step 3: Commit**

```bash
git add test/puede_mover_tarea_test.dart
git commit -m "Test: cubre la regla de permiso para mover tareas en el Kanban"
```

---

### Task 11: Verificación completa y prueba local

**Files:** ninguno (solo verificación).

- [ ] **Step 1: `flutter analyze` de todo el proyecto**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: Correr toda la suite de tests**

Run: `flutter test`
Expected: todos los tests pasan (incluye `chat_message_model_test.dart` y `puede_mover_tarea_test.dart`).

- [ ] **Step 3: Levantar la app localmente para que el usuario pruebe**

Run: `flutter run -d chrome`

Checklist manual a validar con el usuario antes de continuar (no marcar este Step como hecho hasta que el usuario confirme cada punto):
- Como Admin: se ven las 4 secciones del drawer (Soporte, Desarrollo, Chat, Administración); el chat tiene 3 pestañas (Soporte/Desarrollo/General).
- Con un usuario `Desarrollador Sr.` (crear temporalmente o simular): el drawer solo muestra Proyectos, Tareas y Chat (2 pestañas: Desarrollo/General); puede crear proyectos/tareas y asignar.
- Con un usuario `Desarrollador`: mismo menú reducido; en el Kanban, las tareas asignadas a otro desarrollador se ven en gris y no se pueden arrastrar; las propias sí; click en cualquier tarjeta abre el detalle de solo lectura.
- El detalle de tarea (click en tarjeta) muestra título, descripción, estado, prioridad, asignado y fechas; los botones Editar/Eliminar solo aparecen para Admin/Desarrollador Sr.
- La tarjeta del Kanban muestra la fecha inicio → fin.
- Los filtros de búsqueda/asignado/prioridad del Kanban funcionan y se pueden limpiar.
- El dropdown "Asignar a" al crear una tarea solo lista desarrolladores.

- [ ] **Step 4: No continuar a la Task 12 hasta que el usuario confirme explícitamente que todo lo anterior funciona bien.**

---

### Task 12: Despliegue (SOLO tras aprobación explícita del usuario)

**Files:** ninguno nuevo — despliega lo ya committeado en las Tasks 1–10.

**No ejecutar ningún step de esta tarea sin que el usuario lo pida explícitamente en la conversación**, incluso si las Tasks 1–11 ya están completas.

- [ ] **Step 1: Push a GitHub**

```bash
git push origin main
```

- [ ] **Step 2: Migración de la base de datos de producción**

```bash
ssh -i llave-aws-beta.pem -o StrictHostKeyChecking=no ubuntu@54.161.41.131 \
  "mysql -u admin_soporte -p'<password>' soporte_beta -e \"ALTER TABLE mensajes ADD COLUMN canal VARCHAR(20) NOT NULL DEFAULT 'soporte';\""
```

Run luego: `ssh -i llave-aws-beta.pem ubuntu@54.161.41.131 "mysql -u admin_soporte -p'<password>' soporte_beta -e 'DESCRIBE mensajes;'"`
Expected: la columna `canal` aparece en la salida.

- [ ] **Step 3: Copiar `main_api.py` al servidor y reiniciar el backend**

```bash
scp -i llave-aws-beta.pem -o StrictHostKeyChecking=no main_api.py ubuntu@54.161.41.131:/home/ubuntu/api-soporte/main.py
ssh -i llave-aws-beta.pem -o StrictHostKeyChecking=no ubuntu@54.161.41.131 "sudo systemctl restart soporte-api.service && sleep 2 && sudo systemctl is-active soporte-api.service"
```
Expected: `active`. Revisar además `sudo journalctl -u soporte-api.service -n 20 --no-pager` en busca de errores de arranque.

- [ ] **Step 4: Build y deploy del frontend**

```powershell
.\deploy.ps1
```
Expected: `Done! Site is live at https://soporte.beta.com.mx`

- [ ] **Step 5: Alta de los 4 usuarios en producción**

Generar los hashes bcrypt en el servidor (usa el mismo venv/librería que el backend) e insertarlos:

```bash
ssh -i llave-aws-beta.pem -o StrictHostKeyChecking=no ubuntu@54.161.41.131 bash -s <<'EOF'
source /home/ubuntu/api-soporte/venv/bin/activate
python3 <<'PYEOF'
import bcrypt, pymysql, os

usuarios = [
    ("lfabela", "lfabela@beta.com.mx", "Luis Fabela", "Desarrollador Sr."),
    ("mgallegos", "mgallegos@beta.com.mx", "Mariana Gallegos", "Desarrollador"),
    ("llira", "llira@beta.com.mx", "Elizabeth Rodriguez", "Desarrollador"),
    ("amedina", "amedina@beta.com.mx", "Angel Medina", "Desarrollador"),
]

conn = pymysql.connect(host="localhost", user="admin_soporte", password=os.environ["DB_PASSWORD"], database="soporte_beta")
try:
    with conn.cursor() as cur:
        for username, email, nombre, rol in usuarios:
            hashed = bcrypt.hashpw(b"123456", bcrypt.gensalt()).decode("utf-8")
            cur.execute(
                "INSERT INTO usuarios (username, email, nombre_completo, rol, password) VALUES (%s, %s, %s, %s, %s)",
                (username, email, nombre, rol, hashed),
            )
    conn.commit()
finally:
    conn.close()
print("usuarios creados")
PYEOF
EOF
```

Nota: `DB_PASSWORD` debe estar en el entorno del servicio (`/home/ubuntu/api-soporte/.env`) — cargarlo antes con `export $(grep DB_PASSWORD /home/ubuntu/api-soporte/.env)` si el script anterior no lo encuentra.

- [ ] **Step 6: Verificar el alta**

Run: `ssh -i llave-aws-beta.pem ubuntu@54.161.41.131 "mysql -u admin_soporte -p'<password>' soporte_beta -e 'SELECT username, nombre_completo, rol FROM usuarios;'"`
Expected: aparecen `lfabela`, `mgallegos`, `llira`, `amedina` con sus roles correctos.

- [ ] **Step 7: Confirmar con el usuario que los 4 pueden iniciar sesión y ven solo Proyectos/Tareas/Chat.**

---

## Self-Review

**Cobertura del spec:**
- §1 Roles y navegación → Tasks 4, 5.
- §2 Permisos dentro de Proyectos/Tareas → Tasks 6, 7, 9.
- §3 Tarjeta de tarea (ver detalle, fechas, drag gating, gris) → Task 7.
- §4 Filtros del Kanban → Task 8.
- §5 Asignación solo a desarrolladores → Task 9.
- §6 Alta de usuarios → Task 12, Step 5.
- §7 Tres canales de chat → Tasks 1, 2, 3, 4.
- Regla de permiso aplicada de forma consistente en la lista plana de Tareas (no estaba en el spec original, se agregó por consistencia directa con §2) → Task 9.

**Placeholders:** ninguno — todos los steps tienen código completo. La única excepción intencional es `<password>` en los comandos de la Task 12 (se reemplaza por la contraseña real de la base de datos al ejecutar, ya conocida de la sesión: no se deja en texto plano en este documento).

**Consistencia de tipos:** `puedeMoverTarea` se define una sola vez (Task 7) y se reusa en Task 9 vía import — mismo nombre y firma en ambos lugares. `ChatMessage.canal`, `ApiService.enviarMensaje(..., {required String canal})` y `ChatScreen({required canales})` usan los mismos nombres en las Tasks 2, 3 y 4.
