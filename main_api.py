from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import pymysql
import json
from datetime import datetime

app = FastAPI(title="API Soporte Beta")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_db_connection():
    return pymysql.connect(
        host='localhost',
        user='admin_soporte',
        password='B47e68t10a',
        database='soporte_beta',
        cursorclass=pymysql.cursors.DictCursor
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

class TicketEstatusRequest(BaseModel):
    estado: str

class TicketReasignarRequest(BaseModel):
    asignadoA: str

class TicketResolverRequest(BaseModel):
    estado: str
    causaRaiz: str
    comoSeResolvio: str
    pruebasRealizadas: str
    validadoCon: str

class EquipoCreateRequest(BaseModel):
    folioResponsiva: str
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

class EquipoAsignarRequest(BaseModel):
    empleadoAsignado: str
    rolEmpleado: str
    folioResponsiva: str
    estatus: str

class EquipoLiberarRequest(BaseModel):
    empleadoAsignado: Optional[str] = None
    rolEmpleado: Optional[str] = None
    folioResponsiva: str
    estatus: str

class EquipoBackupRequest(BaseModel):
    ultimoRespaldo: str

class MensajeRequest(BaseModel):
    deUsuario: str
    nombreCompleto: str
    texto: str

# ============================================================================
# AUTENTICACION
# ============================================================================
@app.post("/login")
def login(req: LoginRequest):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT username, nombre_completo, rol FROM usuarios WHERE username = %s AND password = %s",
                (req.username, req.password)
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
            cursor.execute("""
                SELECT id, usuario, departamento, descripcion, prioridad, estado,
                       asignado_a AS asignadoA, fecha,
                       causa_raiz AS causaRaiz, como_se_resolvio AS comoSeResolvio,
                       pruebas_realizadas AS pruebasRealizadas, validado_con AS validadoCon
                FROM tickets ORDER BY fecha DESC
            """)
            tickets = cursor.fetchall()
            for t in tickets:
                t['id'] = str(t['id'])
                if isinstance(t['fecha'], datetime):
                    t['fecha'] = t['fecha'].isoformat()
            return tickets
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
            cursor.execute(
                """INSERT INTO tickets (id, usuario, departamento, descripcion, prioridad, estado, asignado_a, fecha)
                   VALUES (%s, %s, %s, %s, %s, %s, %s, %s)""",
                (new_id, req.usuario, req.departamento, req.descripcion,
                 req.prioridad, req.estado, req.asignadoA,
                 datetime.fromisoformat(req.fecha.replace("Z", "")))
            )
            connection.commit()
            cursor.execute("""
                SELECT id, usuario, departamento, descripcion, prioridad, estado,
                       asignado_a AS asignadoA, fecha,
                       causa_raiz AS causaRaiz, como_se_resolvio AS comoSeResolvio,
                       pruebas_realizadas AS pruebasRealizadas, validado_con AS validadoCon
                FROM tickets WHERE id = %s
            """, (new_id,))
            t = cursor.fetchone()
            t['id'] = str(t['id'])
            if isinstance(t['fecha'], datetime):
                t['fecha'] = t['fecha'].isoformat()
    finally:
        connection.close()
    await manager.broadcast({"tipo": "tickets", "accion": "nuevo"})
    return t

@app.put("/tickets/{ticket_id}/status")
async def update_ticket_status(ticket_id: str, req: TicketEstatusRequest):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("UPDATE tickets SET estado = %s WHERE id = %s", (req.estado, ticket_id))
            connection.commit()
    finally:
        connection.close()
    await manager.broadcast({"tipo": "tickets", "accion": "estado", "id": ticket_id})
    return {"status": "success"}

@app.put("/tickets/{ticket_id}/resolve")
async def resolve_ticket(ticket_id: str, req: TicketResolverRequest):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                """UPDATE tickets SET estado = %s, causa_raiz = %s, como_se_resolvio = %s,
                   pruebas_realizadas = %s, validado_con = %s WHERE id = %s""",
                (req.estado, req.causaRaiz, req.comoSeResolvio,
                 req.pruebasRealizadas, req.validadoCon, ticket_id)
            )
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
    return {"status": "success"}

# ============================================================================
# EQUIPOS
# ============================================================================
@app.get("/equipos")
def get_equipos():
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("""
                SELECT id, folio_responsiva AS folioResponsiva, tipo, marca, modelo,
                       no_serie AS noSerie, accesorios, ano_adquisicion AS anoAdquisicion,
                       valor_adquisicion AS valorAdquisicion, specifications, estatus,
                       empleado_asignado AS empleadoAsignado, rol_empleado AS rolEmpleado,
                       ubicacion, anydesk, rustdesk, ultimo_respaldo AS ultimoRespaldo, comentarios
                FROM equipos
            """)
            equipos = cursor.fetchall()
            for e in equipos:
                e['id'] = str(e['id'])
                if e['ultimoRespaldo'] and isinstance(e['ultimoRespaldo'], datetime):
                    e['ultimoRespaldo'] = e['ultimoRespaldo'].isoformat()
            return equipos
    finally:
        connection.close()

@app.post("/equipos")
async def create_equipo(req: EquipoCreateRequest):
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                """INSERT INTO equipos (folio_responsiva, tipo, marca, modelo, no_serie, accesorios,
                   ano_adquisicion, valor_adquisicion, specifications, estatus,
                   empleado_asignado, rol_empleado, ubicacion, anydesk, rustdesk, comentarios)
                   VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                (req.folioResponsiva, req.tipo, req.marca, req.modelo, req.noSerie,
                 req.accesorios, req.anoAdquisicion, req.valorAdquisicion, req.specifications,
                 req.estatus, req.empleadoAsignado, req.rolEmpleado, req.ubicacion,
                 req.anydesk, req.rustdesk, req.comentarios)
            )
            connection.commit()
            equipo_id = cursor.lastrowid
            cursor.execute("""
                SELECT id, folio_responsiva AS folioResponsiva, tipo, marca, modelo,
                       no_serie AS noSerie, accesorios, ano_adquisicion AS anoAdquisicion,
                       valor_adquisicion AS valorAdquisicion, specifications, estatus,
                       empleado_asignado AS empleadoAsignado, rol_empleado AS rolEmpleado,
                       ubicacion, anydesk, rustdesk, ultimo_respaldo AS ultimoRespaldo, comentarios
                FROM equipos WHERE id = %s
            """, (equipo_id,))
            e = cursor.fetchone()
            e['id'] = str(e['id'])
            if e['ultimoRespaldo'] and isinstance(e['ultimoRespaldo'], datetime):
                e['ultimoRespaldo'] = e['ultimoRespaldo'].isoformat()
    finally:
        connection.close()
    await manager.broadcast({"tipo": "equipos", "accion": "nuevo"})
    return e

@app.put("/equipos/{equipo_id}/assign")
async def assign_equipo(equipo_id: str, req: EquipoAsignarRequest):
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
    await manager.broadcast({"tipo": "equipos", "accion": "asignado"})
    return {"status": "success"}

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
                       texto, fecha
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
    if not req.texto.strip():
        raise HTTPException(status_code=400, detail="El texto no puede estar vacío")
    ahora = datetime.now()
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute(
                "INSERT INTO mensajes (de_usuario, nombre_completo, texto, fecha) VALUES (%s, %s, %s, %s)",
                (req.deUsuario, req.nombreCompleto, req.texto.strip(), ahora)
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
        "texto": req.texto.strip(),
        "fecha": ahora.isoformat(),
    }
    await manager.broadcast(payload)
    return payload
