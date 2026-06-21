from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import pymysql
import json
import os
import re
from datetime import datetime, date

# Cargar .env si existe (para ANTHROPIC_API_KEY y otras vars)
_env_path = os.path.join(os.path.dirname(__file__), '.env')
if os.path.exists(_env_path):
    with open(_env_path) as _f:
        for _line in _f:
            _line = _line.strip()
            if _line and not _line.startswith('#') and '=' in _line:
                _k, _v = _line.split('=', 1)
                os.environ.setdefault(_k.strip(), _v.strip())
import firebase_admin
from firebase_admin import credentials, messaging
try:
    import anthropic as _anthropic
    _ANTHROPIC_AVAILABLE = True
except ImportError:
    _ANTHROPIC_AVAILABLE = False

app = FastAPI(title="API Soporte Beta")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Firebase Admin SDK ────────────────────────────────────────────────────────
_SERVICE_ACCOUNT = os.path.join(os.path.dirname(__file__), "soporte-bsm-firebase-adminsdk-fbsvc-cd0f021b80.json")
if not firebase_admin._apps and os.path.exists(_SERVICE_ACCOUNT):
    _cred = credentials.Certificate(_SERVICE_ACCOUNT)
    firebase_admin.initialize_app(_cred)

def _send_fcm(username: str, title: str, body: str):
    """Envía notificación FCM al token registrado de un usuario. Silencioso si falla."""
    try:
        connection = get_db_connection()
        try:
            with connection.cursor() as cursor:
                cursor.execute("SELECT fcm_token FROM usuarios WHERE username = %s", (username,))
                row = cursor.fetchone()
        finally:
            connection.close()
        token = row.get('fcm_token') if row else None
        if not token or not firebase_admin._apps:
            return
        messaging.send(messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            android=messaging.AndroidConfig(priority="high"),
            token=token,
        ))
    except Exception:
        pass

def get_db_connection():
    return pymysql.connect(
        host='localhost',
        user='admin_soporte',
        password='B47e68t10a',
        database='soporte_beta',
        cursorclass=pymysql.cursors.DictCursor
    )

# ── SQL constants ──────────────────────────────────────────────────────────────

TICKET_SELECT = """
    SELECT id, usuario, departamento, descripcion, prioridad, estado,
           asignado_a AS asignadoA, fecha,
           causa_raiz AS causaRaiz, como_se_resolvio AS comoSeResolvio,
           pruebas_realizadas AS pruebasRealizadas, validado_con AS validadoCon,
           escalado_a AS escaladoA, motivo_escalado AS motivoEscalado,
           tipo_ticket AS tipoTicket, categoria, area,
           imagen_resolucion AS imagenResolucion
    FROM tickets
"""

EQUIPO_SELECT = """
    SELECT id, folio_responsiva AS folioResponsiva, folio_activo AS folioActivo,
           tipo, marca, modelo, no_serie AS noSerie, accesorios,
           ano_adquisicion AS anoAdquisicion, valor_adquisicion AS valorAdquisicion,
           specifications, estatus, empleado_asignado AS empleadoAsignado,
           rol_empleado AS rolEmpleado, ubicacion, anydesk, rustdesk,
           ultimo_respaldo AS ultimoRespaldo, comentarios,
           area, mac_address AS macAddress,
           fecha_venta AS fechaVenta, precio_venta AS precioVenta
    FROM equipos
"""

# ── Helpers ────────────────────────────────────────────────────────────────────

def _build_ticket(t: dict) -> dict:
    t['id'] = str(t['id'])
    if isinstance(t.get('fecha'), datetime):
        t['fecha'] = t['fecha'].isoformat()
    return t

def _build_equipo(e: dict) -> dict:
    e['id'] = str(e['id'])
    if isinstance(e.get('ultimoRespaldo'), datetime):
        e['ultimoRespaldo'] = e['ultimoRespaldo'].isoformat()
    if isinstance(e.get('fechaVenta'), (datetime, date)):
        e['fechaVenta'] = e['fechaVenta'].isoformat() if hasattr(e['fechaVenta'], 'isoformat') else str(e['fechaVenta'])
    return e

def _gen_folio_activo(cursor) -> str:
    year = datetime.now().year
    prefix = f"ACT-{year}-"
    cursor.execute(
        "SELECT folio_activo FROM equipos WHERE folio_activo LIKE %s ORDER BY folio_activo DESC LIMIT 1",
        (f"{prefix}%",)
    )
    row = cursor.fetchone()
    if row and row['folio_activo']:
        try:
            num = int(row['folio_activo'].split('-')[-1]) + 1
        except (ValueError, IndexError):
            num = 1
    else:
        num = 1
    return f"{prefix}{num:03d}"

def _gen_folio_responsiva(cursor) -> str:
    year = datetime.now().year
    prefix = f"RES-{year}-"
    cursor.execute(
        "SELECT folio_responsiva FROM equipos WHERE folio_responsiva LIKE %s ORDER BY folio_responsiva DESC LIMIT 1",
        (f"{prefix}%",)
    )
    row = cursor.fetchone()
    if row and row['folio_responsiva']:
        try:
            num = int(row['folio_responsiva'].split('-')[-1]) + 1
        except (ValueError, IndexError):
            num = 1
    else:
        num = 1
    return f"{prefix}{num:03d}"

def _record_historial(cursor, ticket_id: str, estado_anterior, estado_nuevo: str, usuario: str = None):
    cursor.execute(
        "INSERT INTO ticket_historial (ticket_id, estado_anterior, estado_nuevo, usuario, fecha) VALUES (%s, %s, %s, %s, %s)",
        (ticket_id, estado_anterior, estado_nuevo, usuario, datetime.now())
    )

# ============================================================================
# WEBSOCKET
# ============================================================================
class ConnectionManager:
    def __init__(self):
        self.active_connections: list[WebSocket] = []

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.active_connections.append(websocket)

    def disconnect(self, websocket: WebSocket):
        if websocket in self.active_connections:
            self.active_connections.remove(websocket)

    async def broadcast(self, message: dict):
        muertos = []
        for ws in self.active_connections:
            try:
                await ws.send_json(message)
            except Exception:
                muertos.append(ws)
        for ws in muertos:
            self.disconnect(ws)

manager = ConnectionManager()

@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket):
    await manager.connect(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)
    except Exception:
        manager.disconnect(websocket)

# ============================================================================
# MODELOS
# ============================================================================
class ConsultaAiRequest(BaseModel):
    pregunta: str

class LoginRequest(BaseModel):
    username: str
    password: str

class TicketCreateRequest(BaseModel):
    usuario: str
    departamento: str
    descripcion: str
    prioridad: str
    estado: str
    asignadoA: str
    fecha: str
    categoria: Optional[str] = None
    area: Optional[str] = None

class TicketEstatusRequest(BaseModel):
    estado: str
    usuario: Optional[str] = None

class TicketReasignarRequest(BaseModel):
    asignadoA: str

class TicketEscalarRequest(BaseModel):
    escaladoA: str
    motivoEscalado: str
    usuario: Optional[str] = None

class TicketResolverRequest(BaseModel):
    estado: str
    causaRaiz: str
    comoSeResolvio: str
    pruebasRealizadas: str
    validadoCon: str
    tipoTicket: Optional[str] = 'Incidencia'
    imagenResolucion: Optional[str] = None
    usuario: Optional[str] = None

class EquipoCreateRequest(BaseModel):
    folioResponsiva: Optional[str] = '---'
    tipo: str
    marca: str
    modelo: str
    noSerie: str
    accesorios: str
    anoAdquisicion: int
    valorAdquisicion: float
    specifications: str
    estatus: str
    empleadoAsignado: Optional[str] = None
    rolEmpleado: Optional[str] = None
    ubicacion: str = 'Beta'
    anydesk: str = ''
    rustdesk: str = ''
    comentarios: str = ''
    area: Optional[str] = None
    macAddress: Optional[str] = None

class EquipoAsignarRequest(BaseModel):
    empleadoAsignado: str
    rolEmpleado: str
    estatus: str = 'Asignado'

class EquipoLiberarRequest(BaseModel):
    empleadoAsignado: Optional[str] = None
    rolEmpleado: Optional[str] = None
    folioResponsiva: str
    estatus: str

class EquipoBackupRequest(BaseModel):
    ultimoRespaldo: str

class EquipoVenderRequest(BaseModel):
    precioVenta: float
    fechaVenta: str

class MensajeRequest(BaseModel):
    deUsuario: str
    nombreCompleto: str
    texto: str = ''
    imagen: Optional[str] = None

class UsuarioCreateRequest(BaseModel):
    username: str
    email: str
    nombreCompleto: str
    rol: str
    password: str

class UsuarioUpdateRequest(BaseModel):
    nombreCompleto: Optional[str] = None
    email: Optional[str] = None
    rol: Optional[str] = None
    password: Optional[str] = None

class CatalogoItemRequest(BaseModel):
    nombre: str

class FcmTokenRequest(BaseModel):
    fcmToken: str

# ============================================================================
# AUTENTICACION
# ============================================================================
@app.post("/login")
def login(req: LoginRequest):
    username = req.username.strip().lower()
    if '@' in username:
        username = username.split('@')[0]
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT username, nombre_completo, rol FROM usuarios WHERE username = %s AND password = %s",
                (username, req.password)
            )
            user = cursor.fetchone()
            if user:
                return {
                    "username": user["username"],
                    "nombreCompleto": user["nombre_completo"],
                    "rol": user["rol"],
                    "token": ""
                }
            raise HTTPException(status_code=401, detail="Credenciales incorrectas")
    finally:
        connection.close()

# ============================================================================
# TICKETS
# ============================================================================
@app.get("/tickets")
def get_tickets():
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute(TICKET_SELECT + " ORDER BY fecha DESC")
            tickets = cursor.fetchall()
            return [_build_ticket(t) for t in tickets]
    finally:
        connection.close()

@app.post("/tickets")
async def create_ticket(req: TicketCreateRequest):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT id FROM tickets ORDER BY CAST(SUBSTRING(id, 4) AS UNSIGNED) DESC LIMIT 1")
            last = cursor.fetchone()
            if last:
                last_num = int(last['id'].split('-')[1])
                new_id = f"TK-{last_num + 1}"
            else:
                new_id = "TK-101"
            ahora = datetime.fromisoformat(req.fecha.replace("Z", ""))
            cursor.execute(
                """INSERT INTO tickets (id, usuario, departamento, descripcion, prioridad, estado,
                   asignado_a, fecha, categoria, area)
                   VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                (new_id, req.usuario, req.departamento, req.descripcion,
                 req.prioridad, req.estado, req.asignadoA, ahora,
                 req.categoria, req.area)
            )
            _record_historial(cursor, new_id, None, req.estado, req.asignadoA)
            connection.commit()
            cursor.execute(TICKET_SELECT + " WHERE id = %s", (new_id,))
            t = cursor.fetchone()
    finally:
        connection.close()
    await manager.broadcast({"tipo": "tickets", "accion": "nuevo"})
    if req.asignadoA:
        _send_fcm(req.asignadoA, f"Nuevo ticket {new_id}", req.descripcion[:80])
    return _build_ticket(t)

@app.put("/tickets/{ticket_id}/status")
async def update_ticket_status(ticket_id: str, req: TicketEstatusRequest):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT estado FROM tickets WHERE id = %s", (ticket_id,))
            row = cursor.fetchone()
            estado_anterior = row['estado'] if row else None
            cursor.execute("UPDATE tickets SET estado = %s WHERE id = %s", (req.estado, ticket_id))
            if estado_anterior != req.estado:
                _record_historial(cursor, ticket_id, estado_anterior, req.estado, req.usuario)
            connection.commit()
    finally:
        connection.close()
    await manager.broadcast({"tipo": "tickets", "accion": "estado", "id": ticket_id})
    return {"status": "success"}

@app.put("/tickets/{ticket_id}/escalar")
async def escalar_ticket(ticket_id: str, req: TicketEscalarRequest):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT estado FROM tickets WHERE id = %s", (ticket_id,))
            row = cursor.fetchone()
            estado_anterior = row['estado'] if row else None
            cursor.execute(
                """UPDATE tickets SET estado = 'Escalado', escalado_a = %s, motivo_escalado = %s
                   WHERE id = %s""",
                (req.escaladoA, req.motivoEscalado, ticket_id)
            )
            _record_historial(cursor, ticket_id, estado_anterior, 'Escalado', req.usuario)
            connection.commit()
    finally:
        connection.close()
    await manager.broadcast({"tipo": "tickets", "accion": "escalado", "id": ticket_id})
    return {"status": "success"}

@app.put("/tickets/{ticket_id}/resolve")
async def resolve_ticket(ticket_id: str, req: TicketResolverRequest):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT estado FROM tickets WHERE id = %s", (ticket_id,))
            row = cursor.fetchone()
            estado_anterior = row['estado'] if row else None
            cursor.execute(
                """UPDATE tickets SET estado = %s, causa_raiz = %s, como_se_resolvio = %s,
                   pruebas_realizadas = %s, validado_con = %s,
                   tipo_ticket = %s, imagen_resolucion = %s
                   WHERE id = %s""",
                (req.estado, req.causaRaiz, req.comoSeResolvio,
                 req.pruebasRealizadas, req.validadoCon,
                 req.tipoTicket, req.imagenResolucion, ticket_id)
            )
            if estado_anterior != req.estado:
                _record_historial(cursor, ticket_id, estado_anterior, req.estado, req.usuario)
            connection.commit()
    finally:
        connection.close()
    await manager.broadcast({"tipo": "tickets", "accion": "resuelto", "id": ticket_id})
    return {"status": "success"}

@app.put("/tickets/{ticket_id}/assign")
async def reassign_ticket(ticket_id: str, req: TicketReasignarRequest):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("UPDATE tickets SET asignado_a = %s WHERE id = %s", (req.asignadoA, ticket_id))
            connection.commit()
    finally:
        connection.close()
    await manager.broadcast({"tipo": "tickets", "accion": "reasignado", "id": ticket_id})
    _send_fcm(req.asignadoA, f"Ticket reasignado: {ticket_id}", "Se te ha asignado un ticket")
    return {"status": "success"}

@app.get("/tickets/{ticket_id}/historial")
def get_ticket_historial(ticket_id: str):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                """SELECT id, ticket_id AS ticketId, estado_anterior AS estadoAnterior,
                          estado_nuevo AS estadoNuevo, usuario, fecha
                   FROM ticket_historial WHERE ticket_id = %s ORDER BY fecha ASC""",
                (ticket_id,)
            )
            rows = cursor.fetchall()
            for r in rows:
                r['id'] = str(r['id'])
                if isinstance(r['fecha'], datetime):
                    r['fecha'] = r['fecha'].isoformat()
            return rows
    finally:
        connection.close()

# ============================================================================
# EQUIPOS
# ============================================================================
@app.get("/equipos")
def get_equipos():
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute(EQUIPO_SELECT)
            equipos = cursor.fetchall()
            return [_build_equipo(e) for e in equipos]
    finally:
        connection.close()

@app.post("/equipos")
async def create_equipo(req: EquipoCreateRequest):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            folio_activo = _gen_folio_activo(cursor)
            cursor.execute(
                """INSERT INTO equipos (folio_responsiva, folio_activo, tipo, marca, modelo, no_serie,
                   accesorios, ano_adquisicion, valor_adquisicion, specifications, estatus,
                   empleado_asignado, rol_empleado, ubicacion, anydesk, rustdesk, comentarios,
                   area, mac_address)
                   VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                ('---', folio_activo, req.tipo, req.marca, req.modelo, req.noSerie,
                 req.accesorios, req.anoAdquisicion, req.valorAdquisicion, req.specifications,
                 req.estatus, req.empleadoAsignado, req.rolEmpleado, req.ubicacion,
                 req.anydesk, req.rustdesk, req.comentarios,
                 req.area, req.macAddress)
            )
            connection.commit()
            equipo_id = cursor.lastrowid
            cursor.execute(EQUIPO_SELECT + " WHERE id = %s", (equipo_id,))
            e = cursor.fetchone()
    finally:
        connection.close()
    await manager.broadcast({"tipo": "equipos", "accion": "nuevo"})
    return _build_equipo(e)

@app.put("/equipos/{equipo_id}/assign")
async def assign_equipo(equipo_id: str, req: EquipoAsignarRequest):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            folio_responsiva = _gen_folio_responsiva(cursor)
            cursor.execute(
                """UPDATE equipos SET empleado_asignado = %s, rol_empleado = %s,
                   folio_responsiva = %s, estatus = %s WHERE id = %s""",
                (req.empleadoAsignado, req.rolEmpleado, folio_responsiva, req.estatus, equipo_id)
            )
            connection.commit()
    finally:
        connection.close()
    await manager.broadcast({"tipo": "equipos", "accion": "asignado"})
    return {"status": "success", "folioResponsiva": folio_responsiva}

@app.put("/equipos/{equipo_id}/release")
async def release_equipo(equipo_id: str, req: EquipoLiberarRequest):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                """UPDATE equipos SET empleado_asignado = %s, rol_empleado = %s,
                   folio_responsiva = %s, estatus = %s WHERE id = %s""",
                (req.empleadoAsignado, req.rolEmpleado, req.folioResponsiva, req.estatus, equipo_id)
            )
            connection.commit()
    finally:
        connection.close()
    await manager.broadcast({"tipo": "equipos", "accion": "liberado"})
    return {"status": "success"}

@app.put("/equipos/{equipo_id}/backup")
async def update_equipo_backup(equipo_id: str, req: EquipoBackupRequest):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                "UPDATE equipos SET ultimo_respaldo = %s WHERE id = %s",
                (datetime.fromisoformat(req.ultimoRespaldo.replace("Z", "")), equipo_id)
            )
            connection.commit()
    finally:
        connection.close()
    await manager.broadcast({"tipo": "equipos", "accion": "respaldo"})
    return {"status": "success"}

@app.put("/equipos/{equipo_id}/vender")
async def vender_equipo(equipo_id: str, req: EquipoVenderRequest):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            fecha_v = datetime.fromisoformat(req.fechaVenta.replace("Z", "")).date()
            cursor.execute(
                """UPDATE equipos SET estatus = 'Vendido', precio_venta = %s, fecha_venta = %s,
                   empleado_asignado = NULL, rol_empleado = NULL WHERE id = %s""",
                (req.precioVenta, fecha_v, equipo_id)
            )
            connection.commit()
    finally:
        connection.close()
    await manager.broadcast({"tipo": "equipos", "accion": "vendido"})
    return {"status": "success"}

# ============================================================================
# CATALOGOS: CATEGORIAS / AREAS / TIPOS DE EQUIPO
# ============================================================================

# ── Categorías ────────────────────────────────────────────────────────────────
@app.get("/categorias")
def get_categorias():
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT id, nombre FROM categorias_ticket WHERE activo = 1 ORDER BY nombre ASC")
            return cursor.fetchall()
    finally:
        connection.close()

@app.post("/categorias", status_code=201)
async def create_categoria(req: CatalogoItemRequest):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("INSERT INTO categorias_ticket (nombre) VALUES (%s)", (req.nombre.strip(),))
            connection.commit()
            new_id = cursor.lastrowid
    finally:
        connection.close()
    return {"id": new_id, "nombre": req.nombre.strip()}

@app.put("/categorias/{cat_id}")
async def update_categoria(cat_id: int, req: CatalogoItemRequest):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("UPDATE categorias_ticket SET nombre = %s WHERE id = %s", (req.nombre.strip(), cat_id))
            connection.commit()
            if cursor.rowcount == 0:
                raise HTTPException(status_code=404, detail="Categoría no encontrada")
    finally:
        connection.close()
    return {"status": "success"}

@app.delete("/categorias/{cat_id}")
async def delete_categoria(cat_id: int):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("UPDATE categorias_ticket SET activo = 0 WHERE id = %s", (cat_id,))
            connection.commit()
            if cursor.rowcount == 0:
                raise HTTPException(status_code=404, detail="Categoría no encontrada")
    finally:
        connection.close()
    return {"status": "success"}

# ── Áreas ─────────────────────────────────────────────────────────────────────
@app.get("/areas")
def get_areas():
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT id, nombre FROM areas WHERE activo = 1 ORDER BY nombre ASC")
            return cursor.fetchall()
    finally:
        connection.close()

@app.post("/areas", status_code=201)
async def create_area(req: CatalogoItemRequest):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("INSERT INTO areas (nombre) VALUES (%s)", (req.nombre.strip(),))
            connection.commit()
            new_id = cursor.lastrowid
    finally:
        connection.close()
    return {"id": new_id, "nombre": req.nombre.strip()}

@app.put("/areas/{area_id}")
async def update_area(area_id: int, req: CatalogoItemRequest):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("UPDATE areas SET nombre = %s WHERE id = %s", (req.nombre.strip(), area_id))
            connection.commit()
            if cursor.rowcount == 0:
                raise HTTPException(status_code=404, detail="Área no encontrada")
    finally:
        connection.close()
    return {"status": "success"}

@app.delete("/areas/{area_id}")
async def delete_area(area_id: int):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("UPDATE areas SET activo = 0 WHERE id = %s", (area_id,))
            connection.commit()
            if cursor.rowcount == 0:
                raise HTTPException(status_code=404, detail="Área no encontrada")
    finally:
        connection.close()
    return {"status": "success"}

# ── Tipos de equipo ───────────────────────────────────────────────────────────
@app.get("/tipos-equipo")
def get_tipos_equipo():
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT id, nombre FROM tipos_equipo WHERE activo = 1 ORDER BY nombre ASC")
            return cursor.fetchall()
    finally:
        connection.close()

@app.post("/tipos-equipo", status_code=201)
async def create_tipo_equipo(req: CatalogoItemRequest):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("INSERT INTO tipos_equipo (nombre) VALUES (%s)", (req.nombre.strip(),))
            connection.commit()
            new_id = cursor.lastrowid
    finally:
        connection.close()
    return {"id": new_id, "nombre": req.nombre.strip()}

@app.put("/tipos-equipo/{tipo_id}")
async def update_tipo_equipo(tipo_id: int, req: CatalogoItemRequest):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("UPDATE tipos_equipo SET nombre = %s WHERE id = %s", (req.nombre.strip(), tipo_id))
            connection.commit()
            if cursor.rowcount == 0:
                raise HTTPException(status_code=404, detail="Tipo no encontrado")
    finally:
        connection.close()
    return {"status": "success"}

@app.delete("/tipos-equipo/{tipo_id}")
async def delete_tipo_equipo(tipo_id: int):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("UPDATE tipos_equipo SET activo = 0 WHERE id = %s", (tipo_id,))
            connection.commit()
            if cursor.rowcount == 0:
                raise HTTPException(status_code=404, detail="Tipo no encontrado")
    finally:
        connection.close()
    return {"status": "success"}

# ============================================================================
# REPORTES
# ============================================================================
@app.get("/reportes")
def get_reportes():
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            # Totales
            cursor.execute("SELECT COUNT(*) AS total FROM tickets")
            total_tickets = cursor.fetchone()['total']
            cursor.execute("SELECT COUNT(*) AS total FROM equipos")
            total_equipos = cursor.fetchone()['total']

            # Por estado
            cursor.execute("SELECT estado, COUNT(*) AS total FROM tickets GROUP BY estado")
            por_estado = {r['estado']: r['total'] for r in cursor.fetchall()}

            # Por prioridad
            cursor.execute("SELECT prioridad, COUNT(*) AS total FROM tickets GROUP BY prioridad")
            por_prioridad = {r['prioridad']: r['total'] for r in cursor.fetchall()}

            # Por técnico
            cursor.execute(
                """SELECT COALESCE(asignado_a, 'Sin asignar') AS tecnico, COUNT(*) AS total
                   FROM tickets GROUP BY asignado_a ORDER BY total DESC"""
            )
            por_tecnico = [{"tecnico": r['tecnico'], "total": r['total']} for r in cursor.fetchall()]

            # Por área
            cursor.execute(
                """SELECT COALESCE(NULLIF(area, ''), NULLIF(departamento, ''), 'Sin área') AS area,
                          COUNT(*) AS total
                   FROM tickets GROUP BY area, departamento ORDER BY total DESC"""
            )
            por_area_raw = {}
            for r in cursor.fetchall():
                key = r['area']
                por_area_raw[key] = por_area_raw.get(key, 0) + r['total']
            por_area = [{"area": k, "total": v} for k, v in sorted(por_area_raw.items(), key=lambda x: -x[1])]

            # Por categoría
            cursor.execute(
                """SELECT COALESCE(NULLIF(categoria, ''), 'Sin categoría') AS categoria, COUNT(*) AS total
                   FROM tickets GROUP BY categoria ORDER BY total DESC"""
            )
            por_categoria = [{"categoria": r['categoria'], "total": r['total']} for r in cursor.fetchall()]

            # Promedio resolución en horas
            cursor.execute(
                """SELECT AVG(TIMESTAMPDIFF(HOUR, t.fecha, h.fecha)) AS promedio
                   FROM tickets t
                   JOIN ticket_historial h ON h.ticket_id = t.id AND h.estado_nuevo = 'Resuelto'"""
            )
            row = cursor.fetchone()
            promedio = round(float(row['promedio']), 1) if row and row['promedio'] else 0.0

            # Por mes (últimos 6 meses)
            cursor.execute(
                """SELECT DATE_FORMAT(fecha, '%Y-%m') AS mes, COUNT(*) AS total
                   FROM tickets
                   WHERE fecha >= DATE_SUB(NOW(), INTERVAL 6 MONTH)
                   GROUP BY mes ORDER BY mes ASC"""
            )
            por_mes = [{"mes": r['mes'], "total": r['total']} for r in cursor.fetchall()]

            # Equipos por tipo
            cursor.execute("SELECT tipo, COUNT(*) AS total FROM equipos GROUP BY tipo ORDER BY total DESC")
            equipos_por_tipo = [{"tipo": r['tipo'], "total": r['total']} for r in cursor.fetchall()]

            # Equipos por estatus
            cursor.execute("SELECT estatus, COUNT(*) AS total FROM equipos GROUP BY estatus")
            equipos_por_estatus = {r['estatus']: r['total'] for r in cursor.fetchall()}

        return {
            "totalTickets": total_tickets,
            "totalEquipos": total_equipos,
            "porEstado": por_estado,
            "porPrioridad": por_prioridad,
            "porTecnico": por_tecnico,
            "porArea": por_area,
            "porCategoria": por_categoria,
            "promedioResolucionHoras": promedio,
            "porMes": por_mes,
            "equiposPorTipo": equipos_por_tipo,
            "equiposPorEstatus": equipos_por_estatus,
        }
    finally:
        connection.close()

# ============================================================================
# USUARIOS
# ============================================================================
@app.get("/usuarios")
def get_usuarios():
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT username, email, nombre_completo AS nombreCompleto, rol FROM usuarios ORDER BY nombre_completo ASC")
            return cursor.fetchall()
    finally:
        connection.close()

@app.post("/usuarios", status_code=201)
async def create_usuario(req: UsuarioCreateRequest):
    username = req.username.strip().lower()
    if not username:
        raise HTTPException(status_code=400, detail="El username no puede estar vacío")
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT username FROM usuarios WHERE username = %s OR email = %s", (username, req.email.lower()))
            if cursor.fetchone():
                raise HTTPException(status_code=409, detail="El usuario o correo ya existe")
            cursor.execute(
                "INSERT INTO usuarios (username, email, nombre_completo, rol, password) VALUES (%s, %s, %s, %s, %s)",
                (username, req.email.strip().lower(), req.nombreCompleto.strip(), req.rol, req.password)
            )
            connection.commit()
    finally:
        connection.close()
    await manager.broadcast({"tipo": "usuarios", "accion": "nuevo"})
    return {"username": username, "email": req.email, "nombreCompleto": req.nombreCompleto, "rol": req.rol}

@app.put("/usuarios/{username}")
async def update_usuario(username: str, req: UsuarioUpdateRequest):
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
                campos.append("password = %s"); valores.append(req.password.strip())
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

@app.delete("/usuarios/{username}")
async def delete_usuario(username: str):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("DELETE FROM usuarios WHERE username = %s", (username,))
            connection.commit()
            if cursor.rowcount == 0:
                raise HTTPException(status_code=404, detail="Usuario no encontrado")
    finally:
        connection.close()
    await manager.broadcast({"tipo": "usuarios", "accion": "eliminado"})
    return {"status": "success"}

@app.post("/usuarios/{username}/fcm-token")
async def save_fcm_token(username: str, req: FcmTokenRequest):
    token = req.fcmToken.strip()
    if not token:
        raise HTTPException(status_code=400, detail="fcmToken requerido")
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("UPDATE usuarios SET fcm_token = %s WHERE username = %s", (token, username))
            if cursor.rowcount == 0:
                raise HTTPException(status_code=404, detail="Usuario no encontrado")
            connection.commit()
    finally:
        connection.close()
    return {"status": "ok"}

# ============================================================================
# CHAT
# ============================================================================
@app.get("/mensajes")
def get_mensajes():
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT id, de_usuario AS deUsuario, nombre_completo AS nombreCompleto,
                       texto, imagen, fecha
                FROM mensajes ORDER BY fecha ASC LIMIT 200
            """)
            mensajes = cursor.fetchall()
            for m in mensajes:
                m['id'] = str(m['id'])
                if isinstance(m['fecha'], datetime):
                    m['fecha'] = m['fecha'].isoformat()
            return mensajes
    finally:
        connection.close()

@app.post("/mensajes")
async def create_mensaje(req: MensajeRequest):
    texto = req.texto.strip() if req.texto else ''
    if not texto and not req.imagen:
        raise HTTPException(status_code=400, detail="El mensaje no puede estar vacío")
    ahora = datetime.now()
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                "INSERT INTO mensajes (de_usuario, nombre_completo, texto, imagen, fecha) VALUES (%s, %s, %s, %s, %s)",
                (req.deUsuario, req.nombreCompleto, texto, req.imagen, ahora)
            )
            connection.commit()
            nuevo_id = cursor.lastrowid
    finally:
        connection.close()
    payload = {
        "tipo": "chat",
        "id": str(nuevo_id),
        "deUsuario": req.deUsuario,
        "nombreCompleto": req.nombreCompleto,
        "texto": texto,
        "imagen": req.imagen,
        "fecha": ahora.isoformat(),
    }
    await manager.broadcast(payload)
    return payload

# ============================================================================
# IA (Claude)
# ============================================================================

_ai_client = None

def _get_ai_client():
    global _ai_client
    if not _ANTHROPIC_AVAILABLE:
        raise HTTPException(status_code=503, detail="Paquete anthropic no instalado en el servidor")
    if _ai_client is None:
        api_key = os.environ.get("ANTHROPIC_API_KEY")
        if not api_key:
            raise HTTPException(status_code=503, detail="ANTHROPIC_API_KEY no configurada")
        _ai_client = _anthropic.Anthropic(api_key=api_key)
    return _ai_client

def _ai_text(response) -> str:
    return ''.join(block.text for block in response.content if block.type == 'text')

@app.post("/ai/consulta")
def ai_consulta(req: ConsultaAiRequest):
    client = _get_ai_client()
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT estado, prioridad, COUNT(*) as total FROM tickets GROUP BY estado, prioridad"
            )
            stats_tickets = cursor.fetchall()
            cursor.execute(f"""
                {TICKET_SELECT}
                WHERE estado != 'Resuelto'
                ORDER BY fecha DESC LIMIT 30
            """)
            tickets_abiertos = [_build_ticket(t) for t in cursor.fetchall()]
            cursor.execute(
                "SELECT tipo, estatus, COUNT(*) as total FROM equipos GROUP BY tipo, estatus"
            )
            stats_equipos = cursor.fetchall()
            cursor.execute("SELECT username, nombre_completo AS nombreCompleto, rol FROM usuarios")
            usuarios = cursor.fetchall()
    finally:
        connection.close()

    system = f"""Eres un asistente de soporte TI para Beta Systems. Responde en español de forma concisa y práctica.

ESTADÍSTICAS DE TICKETS (por estado y prioridad):
{json.dumps(stats_tickets, ensure_ascii=False, default=str)}

TICKETS ABIERTOS (máx 30, más recientes primero):
{json.dumps(tickets_abiertos, ensure_ascii=False, default=str)}

EQUIPOS (por tipo y estatus):
{json.dumps(stats_equipos, ensure_ascii=False, default=str)}

USUARIOS ACTIVOS:
{json.dumps(usuarios, ensure_ascii=False, default=str)}

Fecha actual: {datetime.now().strftime('%Y-%m-%d %H:%M')}"""

    with client.messages.stream(
        model="claude-opus-4-8",
        max_tokens=2048,
        thinking={"type": "adaptive"},
        system=system,
        messages=[{"role": "user", "content": req.pregunta}]
    ) as stream:
        final = stream.get_final_message()
    return {"respuesta": _ai_text(final)}


@app.post("/ai/anomalias")
def ai_anomalias():
    client = _get_ai_client()
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute(f"{TICKET_SELECT} WHERE estado != 'Resuelto' ORDER BY fecha ASC")
            tickets = [_build_ticket(t) for t in cursor.fetchall()]
            cursor.execute("""
                SELECT id, tipo, marca, modelo, empleado_asignado AS empleadoAsignado,
                       ultimo_respaldo AS ultimoRespaldo, estatus, area
                FROM equipos WHERE estatus NOT IN ('Vendido', 'Fuera de Servicio')
                ORDER BY ultimo_respaldo ASC
            """)
            equipos = cursor.fetchall()
            for e in equipos:
                e['id'] = str(e['id'])
                if isinstance(e.get('ultimoRespaldo'), datetime):
                    e['ultimoRespaldo'] = e['ultimoRespaldo'].isoformat()
            cursor.execute("""
                SELECT t.id, t.asignado_a AS asignadoA, t.categoria, t.area, t.prioridad,
                       t.fecha AS fechaCreacion,
                       (SELECT MIN(h.fecha) FROM ticket_historial h
                        WHERE h.ticket_id = t.id AND h.estado_nuevo = 'Resuelto') AS fechaResolucion
                FROM tickets t WHERE t.estado = 'Resuelto'
                ORDER BY t.fecha DESC LIMIT 30
            """)
            resueltos = cursor.fetchall()
            for r in resueltos:
                r['id'] = str(r['id'])
                for k in ['fechaCreacion', 'fechaResolucion']:
                    if isinstance(r.get(k), datetime):
                        r[k] = r[k].isoformat()
    finally:
        connection.close()

    system = """Eres un analista de TI experto en detección de anomalías en sistemas de soporte.
Analiza los datos e identifica anomalías, patrones preocupantes o situaciones urgentes.

Responde ÚNICAMENTE con JSON válido en este formato exacto:
{
  "anomalias": [
    {
      "titulo": "Título breve (máx 60 chars)",
      "severidad": "alta|media|baja",
      "descripcion": "Descripción del problema",
      "recomendacion": "Acción recomendada"
    }
  ],
  "resumen": "Resumen ejecutivo en 2-3 oraciones"
}"""

    datos = f"""TICKETS ABIERTOS:
{json.dumps(tickets, ensure_ascii=False, default=str)}

EQUIPOS ACTIVOS (con último respaldo):
{json.dumps(equipos, ensure_ascii=False, default=str)}

ÚLTIMOS 30 TICKETS RESUELTOS:
{json.dumps(resueltos, ensure_ascii=False, default=str)}

Fecha actual: {datetime.now().strftime('%Y-%m-%d %H:%M')}"""

    with client.messages.stream(
        model="claude-opus-4-8",
        max_tokens=3000,
        thinking={"type": "adaptive"},
        system=system,
        messages=[{"role": "user", "content": datos}]
    ) as stream:
        final = stream.get_final_message()

    texto = _ai_text(final)
    try:
        match = re.search(r'\{.*\}', texto, re.DOTALL)
        result = json.loads(match.group()) if match else {"anomalias": [], "resumen": texto}
    except Exception:
        result = {"anomalias": [], "resumen": texto}
    return result


@app.post("/ai/sugerencia/{ticket_id}")
def ai_sugerencia(ticket_id: str):
    client = _get_ai_client()
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute(f"{TICKET_SELECT} WHERE id = %s", (ticket_id,))
            ticket = cursor.fetchone()
            if not ticket:
                raise HTTPException(status_code=404, detail="Ticket no encontrado")
            ticket = _build_ticket(ticket)
            cursor.execute(f"""
                {TICKET_SELECT}
                WHERE estado = 'Resuelto'
                AND (categoria = %s OR area = %s OR departamento = %s)
                AND como_se_resolvio IS NOT NULL
                ORDER BY fecha DESC LIMIT 10
            """, (ticket.get('categoria'), ticket.get('area'), ticket.get('departamento')))
            similares = [_build_ticket(t) for t in cursor.fetchall()]
    finally:
        connection.close()

    system = """Eres un experto en soporte técnico de TI. Analiza el ticket y sugiere cómo resolverlo.
Responde en español con:
1. Diagnóstico probable (2-3 oraciones)
2. Pasos recomendados (lista numerada)
3. Causa raíz más probable
4. Tiempo estimado de resolución

Sé conciso y práctico. Usa el historial de tickets similares como referencia."""

    prompt = f"""TICKET A RESOLVER:
{json.dumps(ticket, ensure_ascii=False, default=str)}

TICKETS SIMILARES YA RESUELTOS:
{json.dumps(similares, ensure_ascii=False, default=str)}

Sugiere cómo resolver el ticket {ticket_id}."""

    with client.messages.stream(
        model="claude-opus-4-8",
        max_tokens=1500,
        thinking={"type": "adaptive"},
        system=system,
        messages=[{"role": "user", "content": prompt}]
    ) as stream:
        final = stream.get_final_message()
    return {"sugerencia": _ai_text(final), "ticket_id": ticket_id}
