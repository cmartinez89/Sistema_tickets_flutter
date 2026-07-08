# Agente Windows de Inventario Automático — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Un agente Windows (.exe) que recolecta specs de cada equipo y las reporta cada hora a la API FastAPI existente, la cual crea/actualiza/vincula registros en la tabla `equipos` de MySQL — sin Firebase, sin infraestructura nueva.

**Architecture:** Endpoint nuevo `POST /agentes/reportar` en `main_api.py` (autenticado con token compartido), lógica de decisión pura factorizada en `agente_matching.py` para poder probarla sin FastAPI/DB. El agente Windows vive en `agente_windows/` como módulos Python independientes (recolección, estado local, envío HTTP) empaquetados con PyInstaller en un solo `.exe` que también sabe auto-instalarse.

**Tech Stack:** Python 3.14 (venv dedicado para el agente), FastAPI + pymysql (backend existente), `psutil` + `wmi`/`pywin32` + `requests` (agente), PyInstaller (empaquetado), pytest (pruebas).

## Global Constraints

- Referencia: spec en `docs/superpowers/specs/2026-07-08-agente-inventario-windows-design.md`.
- El backend corre en el EC2 (`ubuntu@54.161.41.131`, ver `/home/ubuntu/api-soporte/main.py`) y solo se puede probar de verdad contra la base de datos real desplegando ahí — no hay entorno local con acceso a MySQL. La lógica de decisión pura se prueba localmente sin desplegar; el resto se prueba con `curl` contra `https://soporte.beta.com.mx/api` después de desplegar.
- El agente Windows sí se puede probar de verdad en esta máquina de desarrollo (es Windows). Usar un venv dedicado en `agente_windows/.venv` — el Python 3.12 global de esta máquina tiene un paquete `enum34` roto que rompe PyInstaller; un venv nuevo desde Python 3.14 no tiene ese problema (ya verificado).
- No se sube ningún secreto real a git: `agente_windows/config.py` (con el token real) va en `.gitignore`; solo se commitea `config.example.py` con placeholders.
- `rustdeskId` siempre se manda como `null` en esta versión (ver spec, sección "Nota sobre RustDesk ID") — no implementar ninguna lógica de lectura del ID de RustDesk.
- Todo el texto de UI/logs/comentarios en español, siguiendo la convención del resto del proyecto.

---

### Task 1: Migración de base de datos

**Files:**
- Ninguno en el repo (migración manual en el servidor, mismo patrón ya usado para columnas anteriores de este proyecto — no hay carpeta de migraciones versionadas).

**Interfaces:**
- Produces: columnas nuevas en `equipos` que las Tasks 3 y 4 usan: `agente_uuid`, `hostname`, `so_nombre`, `so_build`, `cpu_modelo`, `cpu_nucleos`, `ram_total_gb`, `discos_info`, `ip_local`, `uptime_segundos`, `usuario_actual`, `ultimo_reporte_agente`.

- [ ] **Step 1: Conectarse al servidor y respaldar la estructura actual (por si acaso)**

```bash
ssh -i llave-aws-beta.pem -o StrictHostKeyChecking=no ubuntu@54.161.41.131 "mysql -u admin_soporte -p\$(grep DB_PASSWORD /home/ubuntu/api-soporte/.env | cut -d= -f2) soporte_beta -e 'DESCRIBE equipos;' > /home/ubuntu/equipos_schema_antes_agente.txt 2>&1"
```

- [ ] **Step 2: Ejecutar el ALTER TABLE**

```bash
ssh -i llave-aws-beta.pem -o StrictHostKeyChecking=no ubuntu@54.161.41.131 "mysql -u admin_soporte -p\$(grep DB_PASSWORD /home/ubuntu/api-soporte/.env | cut -d= -f2) soporte_beta -e \"
ALTER TABLE equipos
  ADD COLUMN agente_uuid VARCHAR(36) NULL UNIQUE,
  ADD COLUMN hostname VARCHAR(100) NULL,
  ADD COLUMN so_nombre VARCHAR(100) NULL,
  ADD COLUMN so_build VARCHAR(50) NULL,
  ADD COLUMN cpu_modelo VARCHAR(200) NULL,
  ADD COLUMN cpu_nucleos INT NULL,
  ADD COLUMN ram_total_gb DECIMAL(6,2) NULL,
  ADD COLUMN discos_info JSON NULL,
  ADD COLUMN ip_local VARCHAR(45) NULL,
  ADD COLUMN uptime_segundos BIGINT NULL,
  ADD COLUMN usuario_actual VARCHAR(100) NULL,
  ADD COLUMN ultimo_reporte_agente DATETIME NULL;
\""
```

- [ ] **Step 3: Verificar que las columnas quedaron creadas**

```bash
ssh -i llave-aws-beta.pem -o StrictHostKeyChecking=no ubuntu@54.161.41.131 "mysql -u admin_soporte -p\$(grep DB_PASSWORD /home/ubuntu/api-soporte/.env | cut -d= -f2) soporte_beta -e 'DESCRIBE equipos;'"
```

Expected: la salida incluye las 12 columnas nuevas listadas arriba, cada una con `Null = YES`.

- [ ] **Step 4: No hay commit para esta tarea** (cambio solo en el servidor, no en el repo). Continuar a la Task 2.

---

### Task 2: `agente_matching.py` — lógica de decisión pura, con TDD

**Files:**
- Create: `agente_matching.py` (raíz del repo, junto a `main_api.py`)
- Test: `tests/test_agente_matching.py`

**Interfaces:**
- Produces (usado por Task 3):
  - `token_valido(token_recibido: str|None, token_esperado: str) -> bool`
  - `decidir_accion_equipo(equipo_por_uuid: dict|None, equipo_por_mac: dict|None) -> tuple[str, int|None]` — retorna `("actualizar", id)`, `("vincular", id)` o `("crear", None)`
  - `campos_a_actualizar(payload: dict) -> dict` — dict de columna→valor listo para un `UPDATE`, excluyendo claves cuyo valor en `payload` es `None`
  - `campos_equipo_nuevo(payload: dict, anio_actual: int) -> dict` — dict de columna→valor listo para un `INSERT`

- [ ] **Step 1: Instalar pytest**

```bash
pip install pytest
```

- [ ] **Step 2: Escribir las pruebas (deben fallar porque `agente_matching.py` no existe todavía)**

Crear `tests/test_agente_matching.py`:

```python
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from agente_matching import (
    token_valido,
    decidir_accion_equipo,
    campos_a_actualizar,
    campos_equipo_nuevo,
)


def test_token_valido_coincide():
    assert token_valido("abc123", "abc123") is True


def test_token_valido_no_coincide():
    assert token_valido("abc123", "otro") is False


def test_token_valido_vacio():
    assert token_valido("", "abc123") is False
    assert token_valido(None, "abc123") is False
    assert token_valido("abc123", "") is False


def test_decidir_accion_por_uuid():
    accion, equipo_id = decidir_accion_equipo({"id": 5}, None)
    assert accion == "actualizar"
    assert equipo_id == 5


def test_decidir_accion_por_mac():
    accion, equipo_id = decidir_accion_equipo(None, {"id": 9})
    assert accion == "vincular"
    assert equipo_id == 9


def test_decidir_accion_uuid_tiene_prioridad_sobre_mac():
    accion, equipo_id = decidir_accion_equipo({"id": 5}, {"id": 9})
    assert accion == "actualizar"
    assert equipo_id == 5


def test_decidir_accion_crear():
    accion, equipo_id = decidir_accion_equipo(None, None)
    assert accion == "crear"
    assert equipo_id is None


def test_campos_a_actualizar_excluye_nulos():
    payload = {"hostname": "PC-1", "cpuModelo": None, "ramTotalGb": 16.0}
    campos = campos_a_actualizar(payload)
    assert campos == {"hostname": "PC-1", "ram_total_gb": 16.0}


def test_campos_a_actualizar_no_pisa_rustdesk_con_null():
    payload = {"hostname": "PC-1", "rustdeskId": None}
    campos = campos_a_actualizar(payload)
    assert "rustdesk" not in campos


def test_campos_a_actualizar_incluye_rustdesk_si_viene():
    payload = {"hostname": "PC-1", "rustdeskId": "123456"}
    campos = campos_a_actualizar(payload)
    assert campos["rustdesk"] == "123456"


def test_campos_a_actualizar_serializa_discos_a_json():
    payload = {"discos": [{"unidad": "C:", "totalGb": 100.0, "libreGb": 50.0}]}
    campos = campos_a_actualizar(payload)
    assert campos["discos_info"] == '[{"unidad": "C:", "totalGb": 100.0, "libreGb": 50.0}]'


def test_campos_equipo_nuevo_usa_placeholders_si_faltan_datos():
    nuevo = campos_equipo_nuevo({}, 2026)
    assert nuevo["marca"] == "Desconocido"
    assert nuevo["estatus"] == "Pendiente de captura"
    assert nuevo["valor_adquisicion"] == 0
    assert nuevo["ano_adquisicion"] == 2026


def test_campos_equipo_nuevo_usa_datos_del_payload_si_vienen():
    nuevo = campos_equipo_nuevo(
        {"marca": "Dell", "modelo": "Latitude 5420", "noSerie": "ABCD1234"}, 2026
    )
    assert nuevo["marca"] == "Dell"
    assert nuevo["modelo"] == "Latitude 5420"
    assert nuevo["no_serie"] == "ABCD1234"
```

- [ ] **Step 3: Correr las pruebas y confirmar que fallan**

Run: `python -m pytest tests/test_agente_matching.py -v`
Expected: `ModuleNotFoundError: No module named 'agente_matching'`

- [ ] **Step 4: Implementar `agente_matching.py`**

```python
"""Logica pura para el endpoint POST /agentes/reportar.

Sin dependencias de FastAPI ni de la base de datos, para poder probarla
de forma aislada.
"""
import json
import secrets


def token_valido(token_recibido, token_esperado):
    if not token_recibido or not token_esperado:
        return False
    return secrets.compare_digest(token_recibido, token_esperado)


def decidir_accion_equipo(equipo_por_uuid, equipo_por_mac):
    if equipo_por_uuid is not None:
        return ("actualizar", equipo_por_uuid["id"])
    if equipo_por_mac is not None:
        return ("vincular", equipo_por_mac["id"])
    return ("crear", None)


def campos_a_actualizar(payload):
    mapa = {
        "hostname": payload.get("hostname"),
        "so_nombre": payload.get("soNombre"),
        "so_build": payload.get("soBuild"),
        "cpu_modelo": payload.get("cpuModelo"),
        "cpu_nucleos": payload.get("cpuNucleos"),
        "ram_total_gb": payload.get("ramTotalGb"),
        "ip_local": payload.get("ipLocal"),
        "mac_address": payload.get("macAddress"),
        "uptime_segundos": payload.get("uptimeSegundos"),
        "usuario_actual": payload.get("usuarioActual"),
        "rustdesk": payload.get("rustdeskId"),
    }
    campos = {k: v for k, v in mapa.items() if v is not None}
    if payload.get("discos") is not None:
        campos["discos_info"] = json.dumps(payload["discos"])
    return campos


def campos_equipo_nuevo(payload, anio_actual):
    return {
        "folio_responsiva": "---",
        "tipo": "Por clasificar",
        "marca": payload.get("marca") or "Desconocido",
        "modelo": payload.get("modelo") or "Desconocido",
        "no_serie": payload.get("noSerie") or "",
        "accesorios": "",
        "ano_adquisicion": anio_actual,
        "valor_adquisicion": 0,
        "specifications": "",
        "estatus": "Pendiente de captura",
        "ubicacion": "Beta",
        "anydesk": "",
        "comentarios": "Creado automaticamente por el agente de inventario.",
    }
```

- [ ] **Step 5: Correr las pruebas y confirmar que pasan**

Run: `python -m pytest tests/test_agente_matching.py -v`
Expected: 13 passed

- [ ] **Step 6: Commit**

```bash
git add agente_matching.py tests/test_agente_matching.py
git commit -m "Add: logica pura de matching para el endpoint de reporte del agente"
```

---

### Task 3: Endpoint `POST /agentes/reportar` en `main_api.py`

**Files:**
- Modify: `main_api.py:1` (import), `main_api.py:5` (import typing), `main_api.py:28` (junto a `_jwt_secret`), `main_api.py:333` (después de `EquipoCreateRequest`), y agregar el endpoint junto a los demás de `equipos` (después de `dar_de_baja_equipo`, alrededor de la línea 822 en el archivo actual).

**Interfaces:**
- Consumes: `token_valido`, `decidir_accion_equipo`, `campos_a_actualizar`, `campos_equipo_nuevo` de `agente_matching.py` (Task 2).
- Produces: endpoint `POST /agentes/reportar`, variable de entorno `AGENT_SHARED_TOKEN`.

- [ ] **Step 1: Agregar el import de `agente_matching` y de `Header`/`List`**

En `main_api.py`, modificar la línea 1:

```python
from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect, Depends, Header
```

Y la línea 5:

```python
from typing import Optional, List
```

- [ ] **Step 2: Agregar el import del módulo nuevo, justo después de los imports existentes (después de la línea `import bcrypt as _bcrypt_lib`)**

```python
from agente_matching import (
    token_valido,
    decidir_accion_equipo,
    campos_a_actualizar,
    campos_equipo_nuevo,
)
```

- [ ] **Step 3: Agregar la lectura del token compartido, junto a `_jwt_secret` (después de la línea `_jwt_secret = os.environ.get('JWT_SECRET_KEY', '')` y su chequeo de `RuntimeError`)**

```python
_agent_shared_token = os.environ.get('AGENT_SHARED_TOKEN', '')
```

No se agrega un `raise RuntimeError` si falta — a diferencia del JWT de usuarios, si este falta el endpoint de agentes simplemente rechaza todo con 401 en vez de tumbar toda la API.

- [ ] **Step 4: Agregar la dependencia de autenticación, justo después de la función `get_current_user`**

```python
def verify_agent_token(x_agent_token: Optional[str] = Header(None)):
    if not token_valido(x_agent_token, _agent_shared_token):
        raise HTTPException(status_code=401, detail="Token de agente invalido")
```

- [ ] **Step 5: Agregar los modelos de request, después de `EquipoCreateRequest` (línea 333, antes de `class EquipoUpdateRequest`)**

```python
class DiscoInfoRequest(BaseModel):
    unidad: str
    totalGb: Optional[float] = None
    libreGb: Optional[float] = None

class AgenteReporteRequest(BaseModel):
    agenteUuid: str
    hostname: str
    usuarioActual: Optional[str] = None
    soNombre: Optional[str] = None
    soBuild: Optional[str] = None
    cpuModelo: Optional[str] = None
    cpuNucleos: Optional[int] = None
    ramTotalGb: Optional[float] = None
    discos: Optional[List[DiscoInfoRequest]] = None
    ipLocal: Optional[str] = None
    macAddress: Optional[str] = None
    uptimeSegundos: Optional[int] = None
    rustdeskId: Optional[str] = None
    noSerie: Optional[str] = None
    marca: Optional[str] = None
    modelo: Optional[str] = None
```

- [ ] **Step 6: Agregar el endpoint, después de `dar_de_baja_equipo` (después del bloque que termina con `return {"status": "success"}` de esa función, antes del comentario `# CATALOGOS`)**

```python
@app.post("/agentes/reportar")
async def reportar_agente(req: AgenteReporteRequest, _auth: None = Depends(verify_agent_token)):
    payload = req.model_dump()
    connection = get_db_connection()
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT id FROM equipos WHERE agente_uuid = %s", (req.agenteUuid,))
            equipo_uuid = cursor.fetchone()

            equipo_mac = None
            if not equipo_uuid and req.macAddress:
                cursor.execute(
                    "SELECT id FROM equipos WHERE mac_address = %s AND agente_uuid IS NULL",
                    (req.macAddress,),
                )
                equipo_mac = cursor.fetchone()

            accion, equipo_id = decidir_accion_equipo(equipo_uuid, equipo_mac)
            campos = campos_a_actualizar(payload)
            campos["ultimo_reporte_agente"] = datetime.now()

            if accion == "crear":
                nuevos = campos_equipo_nuevo(payload, datetime.now().year)
                nuevos.update(campos)
                nuevos["agente_uuid"] = req.agenteUuid
                columnas = list(nuevos.keys())
                valores = list(nuevos.values())
                marcadores = ", ".join(["%s"] * len(columnas))
                cursor.execute(
                    f"INSERT INTO equipos ({', '.join(columnas)}) VALUES ({marcadores})",
                    valores,
                )
                equipo_id = cursor.lastrowid
            else:
                if accion == "vincular":
                    campos["agente_uuid"] = req.agenteUuid
                sets = ", ".join(f"{col} = %s" for col in campos.keys())
                valores = list(campos.values()) + [equipo_id]
                cursor.execute(f"UPDATE equipos SET {sets} WHERE id = %s", valores)
            connection.commit()
    finally:
        connection.close()
    await manager.broadcast({"tipo": "equipos", "accion": "agente"})
    return {"status": "ok", "equipoId": str(equipo_id), "accion": accion}
```

- [ ] **Step 7: Verificación local de sintaxis (no requiere las dependencias instaladas, solo compila)**

Run: `python -m py_compile main_api.py`
Expected: sin salida, exit code 0. (La prueba funcional real se hace en la Task 4, después de desplegar, porque este archivo necesita `JWT_SECRET_KEY` y conexión a MySQL para poder ejecutarse, y esas solo existen en el servidor.)

- [ ] **Step 8: Commit**

```bash
git add main_api.py
git commit -m "Add: endpoint POST /agentes/reportar con autenticacion por token compartido"
```

---

### Task 4: Desplegar el backend y probar el endpoint end-to-end

**Files:**
- Ninguno en el repo (despliegue + pruebas manuales con `curl`).

**Interfaces:**
- Consumes: endpoint de la Task 3, columnas de la Task 1.

- [ ] **Step 1: Generar el token compartido y agregarlo al `.env` del servidor**

```bash
python -c "import secrets; print(secrets.token_urlsafe(32))"
```

Copiar el valor impreso. Luego:

```bash
ssh -i llave-aws-beta.pem -o StrictHostKeyChecking=no ubuntu@54.161.41.131 "echo 'AGENT_SHARED_TOKEN=<PEGAR_EL_VALOR_AQUI>' >> /home/ubuntu/api-soporte/.env"
```

Guardar ese mismo valor — se necesita también en la Task 5 del agente (`config.py`).

- [ ] **Step 2: Respaldar el `main.py` actual del servidor y subir el nuevo**

```bash
ssh -i llave-aws-beta.pem -o StrictHostKeyChecking=no ubuntu@54.161.41.131 "cp /home/ubuntu/api-soporte/main.py /home/ubuntu/api-soporte/main.py.bak_agente_$(date +%Y%m%d_%H%M%S)"
scp -i llave-aws-beta.pem -o StrictHostKeyChecking=no main_api.py ubuntu@54.161.41.131:/home/ubuntu/api-soporte/main.py
scp -i llave-aws-beta.pem -o StrictHostKeyChecking=no agente_matching.py ubuntu@54.161.41.131:/home/ubuntu/api-soporte/agente_matching.py
```

- [ ] **Step 3: Reiniciar el servicio y confirmar que sigue vivo**

```bash
ssh -i llave-aws-beta.pem -o StrictHostKeyChecking=no ubuntu@54.161.41.131 "sudo systemctl restart soporte-api.service && sleep 2 && sudo systemctl status soporte-api.service --no-pager | head -5"
```

Expected: `Active: active (running)`. Si no, revisar `tail -50 /home/ubuntu/api-soporte/api.log` para el traceback y corregir antes de seguir.

- [ ] **Step 4: Probar que sin token da 401**

```bash
curl -s -o /dev/null -w "%{http_code}\n" -X POST https://soporte.beta.com.mx/api/agentes/reportar \
  -H "Content-Type: application/json" \
  -d '{"agenteUuid":"test","hostname":"test"}'
```

Expected: `401`

- [ ] **Step 5: Probar creación de un equipo nuevo (usar el token real del Step 1)**

```bash
TOKEN="<pegar el token del Step 1>"
curl -s -X POST https://soporte.beta.com.mx/api/agentes/reportar \
  -H "Content-Type: application/json" \
  -H "X-Agent-Token: $TOKEN" \
  -d '{
    "agenteUuid": "11111111-1111-1111-1111-111111111111",
    "hostname": "PC-TEST-AGENTE (borrar)",
    "cpuModelo": "CPU de prueba",
    "cpuNucleos": 4,
    "ramTotalGb": 8.0,
    "macAddress": "AA:AA:AA:AA:AA:01"
  }'
```

Expected: `{"status":"ok","equipoId":"<algun numero>","accion":"creado"}`. Anotar el `equipoId` retornado como `EQUIPO_A`.

- [ ] **Step 6: Probar que reportar el mismo `agenteUuid` actualiza en vez de duplicar**

```bash
curl -s -X POST https://soporte.beta.com.mx/api/agentes/reportar \
  -H "Content-Type: application/json" \
  -H "X-Agent-Token: $TOKEN" \
  -d '{
    "agenteUuid": "11111111-1111-1111-1111-111111111111",
    "hostname": "PC-TEST-AGENTE (borrar)",
    "cpuNucleos": 8
  }'
```

Expected: `{"status":"ok","equipoId":"<mismo EQUIPO_A>","accion":"actualizado"}`

- [ ] **Step 7: Probar el caso de vinculación — crear un equipo manual con MAC conocida (usando el login de un Admin) y confirmar que el agente lo vincula en vez de duplicar**

```bash
# Login para obtener un token de usuario (usar credenciales de Admin reales)
LOGIN_TOKEN=$(curl -s -X POST https://soporte.beta.com.mx/api/login \
  -H "Content-Type: application/json" \
  -d '{"username":"cmartinez","password":"<password real>"}' | python -c "import sys,json; print(json.load(sys.stdin)['token'])")

# Crear equipo manual con MAC conocida
curl -s -X POST https://soporte.beta.com.mx/api/equipos \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $LOGIN_TOKEN" \
  -d '{
    "tipo": "Laptop", "marca": "Test", "modelo": "Test (borrar)", "noSerie": "TEST-BORRAR",
    "accesorios": "", "anoAdquisicion": 2026, "valorAdquisicion": 1, "specifications": "",
    "estatus": "Disponible", "macAddress": "AA:AA:AA:AA:AA:02"
  }'
```

Anotar el `id` retornado como `EQUIPO_B`. Luego:

```bash
curl -s -X POST https://soporte.beta.com.mx/api/agentes/reportar \
  -H "Content-Type: application/json" \
  -H "X-Agent-Token: $TOKEN" \
  -d '{
    "agenteUuid": "22222222-2222-2222-2222-222222222222",
    "hostname": "PC-TEST-AGENTE-B (borrar)",
    "macAddress": "AA:AA:AA:AA:AA:02"
  }'
```

Expected: `{"status":"ok","equipoId":"<mismo EQUIPO_B>","accion":"vinculado"}`

- [ ] **Step 8: Limpiar los equipos de prueba**

```bash
curl -s -X DELETE https://soporte.beta.com.mx/api/equipos/$EQUIPO_A -H "Authorization: Bearer $LOGIN_TOKEN"
curl -s -X DELETE https://soporte.beta.com.mx/api/equipos/$EQUIPO_B -H "Authorization: Bearer $LOGIN_TOKEN"
```

Expected: ambos `{"status":"success"}`

- [ ] **Step 9: No hay commit para esta tarea** (fue solo despliegue + pruebas manuales; el código ya se commiteó en la Task 3). Continuar a la Task 5.

---

### Task 5: Entorno de desarrollo del agente Windows

**Files:**
- Create: `agente_windows/requirements.txt`
- Create: `agente_windows/config.example.py`
- Create: `agente_windows/.gitignore`

**Interfaces:**
- Produces: venv en `agente_windows/.venv` usado por todas las tareas siguientes del agente; constantes `API_URL`, `AGENT_TOKEN` (vía `config.py`, no versionado).

- [ ] **Step 1: Crear la carpeta y el venv**

```bash
mkdir agente_windows
cd agente_windows
python -m venv .venv
```

- [ ] **Step 2: Crear `requirements.txt`**

```
psutil
requests
wmi
pywin32
pytest
pyinstaller
```

- [ ] **Step 3: Instalar dependencias en el venv**

```bash
.venv/Scripts/python.exe -m pip install -r requirements.txt
```

Run: `.venv/Scripts/python.exe -m pip list`
Expected: la lista incluye `psutil`, `requests`, `wmi`, `pywin32`, `pytest`, `pyinstaller`, sin errores.

- [ ] **Step 4: Crear `config.example.py`**

```python
# Copiar este archivo como config.py y reemplazar AGENT_TOKEN con el valor
# real generado en la Task 4 del plan de implementacion (el mismo que se
# puso en AGENT_SHARED_TOKEN en el .env del servidor). config.py NO se sube
# a git.

API_URL = "https://soporte.beta.com.mx/api/agentes/reportar"
AGENT_TOKEN = "CAMBIAR_ANTES_DE_COMPILAR"
```

- [ ] **Step 5: Crear `config.py` local para desarrollo (copiando el ejemplo, con el token real del Step 1 de la Task 4)**

```bash
cp config.example.py config.py
```

Editar `config.py` y reemplazar `AGENT_TOKEN` con el token real generado en la Task 4.

- [ ] **Step 6: Crear `.gitignore` dentro de `agente_windows/`**

```
.venv/
config.py
build/
dist/
*.spec
*.log
__pycache__/
```

- [ ] **Step 7: Commit** (nota: `config.py` no se sube por el `.gitignore`, solo `config.example.py`)

```bash
cd ..
git add agente_windows/requirements.txt agente_windows/config.example.py agente_windows/.gitignore
git commit -m "Add: entorno base del agente Windows (requirements, config de ejemplo)"
```

---

### Task 6: `estado_local.py` — UUID persistente y cola de un solo pendiente, con TDD

**Files:**
- Create: `agente_windows/estado_local.py`
- Test: `agente_windows/tests/test_estado_local.py`

**Interfaces:**
- Produces (usado por Tasks 8 y 9):
  - `BASE_DIR` (constante, `Path(r"C:\ProgramData\SoporteAgente")`)
  - `obtener_uuid_agente(base_dir=BASE_DIR) -> str`
  - `guardar_pendiente(payload: dict, base_dir=BASE_DIR) -> None`
  - `leer_pendiente(base_dir=BASE_DIR) -> dict | None`
  - `borrar_pendiente(base_dir=BASE_DIR) -> None`

- [ ] **Step 1: Escribir las pruebas**

Crear `agente_windows/tests/test_estado_local.py`:

```python
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from estado_local import obtener_uuid_agente, guardar_pendiente, leer_pendiente, borrar_pendiente


def test_obtener_uuid_agente_genera_uno_nuevo_si_no_existe(tmp_path):
    valor = obtener_uuid_agente(base_dir=tmp_path)
    assert len(valor) == 36
    assert (tmp_path / "agent_id.txt").exists()


def test_obtener_uuid_agente_reutiliza_el_existente(tmp_path):
    primero = obtener_uuid_agente(base_dir=tmp_path)
    segundo = obtener_uuid_agente(base_dir=tmp_path)
    assert primero == segundo


def test_guardar_y_leer_pendiente(tmp_path):
    payload = {"hostname": "PC-1", "cpuNucleos": 4}
    guardar_pendiente(payload, base_dir=tmp_path)
    assert leer_pendiente(base_dir=tmp_path) == payload


def test_leer_pendiente_sin_archivo_regresa_none(tmp_path):
    assert leer_pendiente(base_dir=tmp_path) is None


def test_borrar_pendiente(tmp_path):
    guardar_pendiente({"a": 1}, base_dir=tmp_path)
    borrar_pendiente(base_dir=tmp_path)
    assert leer_pendiente(base_dir=tmp_path) is None


def test_guardar_pendiente_sobreescribe_no_acumula(tmp_path):
    guardar_pendiente({"version": 1}, base_dir=tmp_path)
    guardar_pendiente({"version": 2}, base_dir=tmp_path)
    assert leer_pendiente(base_dir=tmp_path) == {"version": 2}
```

- [ ] **Step 2: Correr las pruebas y confirmar que fallan**

Run: `agente_windows/.venv/Scripts/python.exe -m pytest agente_windows/tests/test_estado_local.py -v`
Expected: `ModuleNotFoundError: No module named 'estado_local'`

- [ ] **Step 3: Implementar `agente_windows/estado_local.py`**

```python
"""Persistencia local del agente: UUID de identidad y el ultimo reporte
pendiente de reenviar. Vive en C:\\ProgramData porque el agente corre como
SYSTEM (via Task Scheduler), no en el perfil de un usuario especifico.
"""
import json
import uuid
from pathlib import Path

BASE_DIR = Path(r"C:\ProgramData\SoporteAgente")


def obtener_uuid_agente(base_dir=BASE_DIR):
    base_dir = Path(base_dir)
    base_dir.mkdir(parents=True, exist_ok=True)
    archivo = base_dir / "agent_id.txt"
    if archivo.exists():
        contenido = archivo.read_text(encoding="utf-8").strip()
        if contenido:
            return contenido
    nuevo = str(uuid.uuid4())
    archivo.write_text(nuevo, encoding="utf-8")
    return nuevo


def guardar_pendiente(payload, base_dir=BASE_DIR):
    base_dir = Path(base_dir)
    base_dir.mkdir(parents=True, exist_ok=True)
    archivo = base_dir / "pending_report.json"
    archivo.write_text(json.dumps(payload), encoding="utf-8")


def leer_pendiente(base_dir=BASE_DIR):
    archivo = Path(base_dir) / "pending_report.json"
    if not archivo.exists():
        return None
    try:
        return json.loads(archivo.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None


def borrar_pendiente(base_dir=BASE_DIR):
    archivo = Path(base_dir) / "pending_report.json"
    if archivo.exists():
        archivo.unlink()
```

- [ ] **Step 4: Correr las pruebas y confirmar que pasan**

Run: `agente_windows/.venv/Scripts/python.exe -m pytest agente_windows/tests/test_estado_local.py -v`
Expected: 6 passed

- [ ] **Step 5: Commit**

```bash
git add agente_windows/estado_local.py agente_windows/tests/test_estado_local.py
git commit -m "Add: persistencia local del agente (UUID + reporte pendiente)"
```

---

### Task 7: `recolector.py` — recolección de datos de Windows

**Files:**
- Create: `agente_windows/recolector.py`
- Test: `agente_windows/tests/test_recolector.py`

**Interfaces:**
- Produces (usado por Task 9):
  - `obtener_hostname() -> str | None`
  - `obtener_usuario_actual() -> str | None`
  - `obtener_so_info() -> tuple[str|None, str|None]` (nombre, build)
  - `obtener_cpu_modelo() -> str | None`
  - `obtener_cpu_nucleos() -> int | None`
  - `obtener_ram_total_gb() -> float | None`
  - `obtener_discos() -> list[dict]` (cada uno con `unidad`, `totalGb`, `libreGb`)
  - `obtener_ip_y_mac() -> tuple[str|None, str|None]`
  - `obtener_uptime_segundos() -> int | None`
  - `obtener_info_bios() -> dict` (con claves `marca`, `modelo`, `noSerie`)

Nota: esta máquina de desarrollo es Windows real, así que las pruebas de
esta tarea corren contra hardware real, no contra mocks — son un genuino
chequeo de humo, no solo una formalidad.

- [ ] **Step 1: Escribir las pruebas**

Crear `agente_windows/tests/test_recolector.py`:

```python
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import recolector


def test_obtener_hostname_no_vacio():
    assert recolector.obtener_hostname()


def test_obtener_cpu_nucleos_positivo():
    nucleos = recolector.obtener_cpu_nucleos()
    assert nucleos is not None and nucleos >= 1


def test_obtener_ram_total_gb_razonable():
    ram = recolector.obtener_ram_total_gb()
    assert ram is not None and ram > 0


def test_obtener_so_info_no_vacio():
    nombre, build = recolector.obtener_so_info()
    assert nombre is not None
    assert "Windows" in nombre


def test_obtener_cpu_modelo_no_vacio():
    assert recolector.obtener_cpu_modelo()


def test_obtener_discos_incluye_al_menos_uno():
    discos = recolector.obtener_discos()
    assert len(discos) >= 1
    assert discos[0]["totalGb"] > 0


def test_obtener_ip_y_mac():
    ip, mac = recolector.obtener_ip_y_mac()
    assert ip is not None
    assert mac is not None
    assert ":" in mac


def test_obtener_uptime_positivo():
    uptime = recolector.obtener_uptime_segundos()
    assert uptime is not None and uptime >= 0


def test_obtener_info_bios_regresa_dict_con_claves():
    info = recolector.obtener_info_bios()
    assert set(info.keys()) == {"marca", "modelo", "noSerie"}
```

- [ ] **Step 2: Correr las pruebas y confirmar que fallan**

Run: `agente_windows/.venv/Scripts/python.exe -m pytest agente_windows/tests/test_recolector.py -v`
Expected: `ModuleNotFoundError: No module named 'recolector'`

- [ ] **Step 3: Implementar `agente_windows/recolector.py`**

```python
"""Recoleccion de especificaciones del equipo. Cada funcion es defensiva:
si algo falla, regresa None (o una lista vacia) en vez de propagar la
excepcion, para que un solo dato faltante no tumbe todo el reporte.
"""
import socket
import time
import winreg

import psutil


def obtener_hostname():
    try:
        return socket.gethostname()
    except Exception:
        return None


def obtener_usuario_actual():
    try:
        usuarios = psutil.users()
        if not usuarios:
            return None
        return usuarios[0].name
    except Exception:
        return None


def obtener_so_info():
    try:
        clave = winreg.OpenKey(
            winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Windows NT\CurrentVersion"
        )
        nombre = winreg.QueryValueEx(clave, "ProductName")[0]
        build = winreg.QueryValueEx(clave, "CurrentBuildNumber")[0]
        try:
            ubr = winreg.QueryValueEx(clave, "UBR")[0]
            build = f"{build}.{ubr}"
        except FileNotFoundError:
            pass
        winreg.CloseKey(clave)
        return nombre, build
    except Exception:
        return None, None


def obtener_cpu_modelo():
    try:
        clave = winreg.OpenKey(
            winreg.HKEY_LOCAL_MACHINE, r"HARDWARE\DESCRIPTION\System\CentralProcessor\0"
        )
        modelo = winreg.QueryValueEx(clave, "ProcessorNameString")[0]
        winreg.CloseKey(clave)
        return modelo.strip()
    except Exception:
        return None


def obtener_cpu_nucleos():
    try:
        return psutil.cpu_count(logical=False)
    except Exception:
        return None


def obtener_ram_total_gb():
    try:
        return round(psutil.virtual_memory().total / (1024 ** 3), 2)
    except Exception:
        return None


def obtener_discos():
    discos = []
    try:
        for particion in psutil.disk_partitions():
            if not particion.fstype:
                continue
            try:
                uso = psutil.disk_usage(particion.mountpoint)
            except OSError:
                continue
            discos.append(
                {
                    "unidad": particion.device,
                    "totalGb": round(uso.total / (1024 ** 3), 2),
                    "libreGb": round(uso.free / (1024 ** 3), 2),
                }
            )
    except Exception:
        pass
    return discos


def obtener_ip_y_mac():
    ip_local = None
    mac = None
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        try:
            s.connect(("8.8.8.8", 80))
            ip_local = s.getsockname()[0]
        finally:
            s.close()
    except Exception:
        return None, None
    try:
        for direcciones in psutil.net_if_addrs().values():
            ips = [d.address for d in direcciones if d.family == socket.AF_INET]
            if ip_local in ips:
                for d in direcciones:
                    if d.family == psutil.AF_LINK:
                        mac = d.address.upper().replace("-", ":")
                        break
                break
    except Exception:
        pass
    return ip_local, mac


def obtener_uptime_segundos():
    try:
        return int(time.time() - psutil.boot_time())
    except Exception:
        return None


def obtener_info_bios():
    try:
        import wmi

        conexion = wmi.WMI()
        producto = conexion.Win32_ComputerSystem()[0]
        bios = conexion.Win32_BIOS()[0]
        return {
            "marca": producto.Manufacturer,
            "modelo": producto.Model,
            "noSerie": bios.SerialNumber.strip() if bios.SerialNumber else None,
        }
    except Exception:
        return {"marca": None, "modelo": None, "noSerie": None}
```

- [ ] **Step 4: Correr las pruebas y confirmar que pasan**

Run: `agente_windows/.venv/Scripts/python.exe -m pytest agente_windows/tests/test_recolector.py -v`
Expected: 9 passed. Si `test_obtener_info_bios_regresa_dict_con_claves` falla por un error de `wmi` (por ejemplo `pywin32` sin inicializar COM en el hilo de pytest), revisar el traceback — puede requerir `pythoncom.CoInitialize()` antes de crear `wmi.WMI()`; si es necesario, agregarlo dentro del `try` de `obtener_info_bios`.

- [ ] **Step 5: Commit**

```bash
git add agente_windows/recolector.py agente_windows/tests/test_recolector.py
git commit -m "Add: recoleccion de especificaciones de Windows (CPU, RAM, disco, red, SO, BIOS)"
```

---

### Task 8: `reportero.py` — envío HTTP con reintento, con TDD (mocks de red)

**Files:**
- Create: `agente_windows/reportero.py`
- Test: `agente_windows/tests/test_reportero.py`

**Interfaces:**
- Consumes: interfaz de `estado_local.py` (Task 6): `leer_pendiente()`, `guardar_pendiente(payload)`, `borrar_pendiente()`.
- Produces (usado por Task 9):
  - `enviar_reporte(payload: dict, url: str, token: str, timeout=10) -> bool`
  - `reportar_con_reintento(payload: dict, url: str, token: str, estado) -> bool` — `estado` es cualquier objeto/módulo con los 3 métodos de `estado_local`.

- [ ] **Step 1: Escribir las pruebas**

Crear `agente_windows/tests/test_reportero.py`:

```python
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import reportero


class FakeEstado:
    def __init__(self, pendiente=None):
        self.pendiente = pendiente
        self.guardado = None
        self.borrado = False

    def leer_pendiente(self):
        return self.pendiente

    def guardar_pendiente(self, payload):
        self.guardado = payload

    def borrar_pendiente(self):
        self.borrado = True


def test_enviar_reporte_exito(monkeypatch):
    class RespuestaFalsa:
        status_code = 200

    monkeypatch.setattr(reportero.requests, "post", lambda *a, **kw: RespuestaFalsa())
    assert reportero.enviar_reporte({"a": 1}, "http://x", "token") is True


def test_enviar_reporte_falla_por_status(monkeypatch):
    class RespuestaFalsa:
        status_code = 401

    monkeypatch.setattr(reportero.requests, "post", lambda *a, **kw: RespuestaFalsa())
    assert reportero.enviar_reporte({"a": 1}, "http://x", "token") is False


def test_enviar_reporte_falla_por_excepcion(monkeypatch):
    def post_falla(*args, **kwargs):
        raise reportero.requests.RequestException("sin red")

    monkeypatch.setattr(reportero.requests, "post", post_falla)
    assert reportero.enviar_reporte({"a": 1}, "http://x", "token") is False


def test_reportar_con_reintento_exito_borra_pendiente(monkeypatch):
    monkeypatch.setattr(reportero, "enviar_reporte", lambda *a, **kw: True)
    estado = FakeEstado(pendiente=None)
    exito = reportero.reportar_con_reintento({"a": 1}, "http://x", "token", estado)
    assert exito is True
    assert estado.borrado is True
    assert estado.guardado is None


def test_reportar_con_reintento_falla_guarda_pendiente(monkeypatch):
    monkeypatch.setattr(reportero, "enviar_reporte", lambda *a, **kw: False)
    estado = FakeEstado(pendiente=None)
    exito = reportero.reportar_con_reintento({"a": 1}, "http://x", "token", estado)
    assert exito is False
    assert estado.guardado == {"a": 1}


def test_reportar_con_reintento_reenvia_pendiente_primero(monkeypatch):
    llamadas = []

    def enviar_falso(payload, url, token, timeout=10):
        llamadas.append(payload)
        return True

    monkeypatch.setattr(reportero, "enviar_reporte", enviar_falso)
    estado = FakeEstado(pendiente={"viejo": True})
    reportero.reportar_con_reintento({"nuevo": True}, "http://x", "token", estado)
    assert llamadas == [{"viejo": True}, {"nuevo": True}]
```

- [ ] **Step 2: Correr las pruebas y confirmar que fallan**

Run: `agente_windows/.venv/Scripts/python.exe -m pytest agente_windows/tests/test_reportero.py -v`
Expected: `ModuleNotFoundError: No module named 'reportero'`

- [ ] **Step 3: Implementar `agente_windows/reportero.py`**

```python
"""Envio del reporte por HTTPS con manejo simple de fallas: si falla, se
guarda como pendiente para reintentarlo en la siguiente corrida (no hay
backoff ni cola creciente, ver spec)."""
import requests


def enviar_reporte(payload, url, token, timeout=10):
    try:
        respuesta = requests.post(
            url,
            json=payload,
            headers={"X-Agent-Token": token, "Content-Type": "application/json"},
            timeout=timeout,
        )
        return respuesta.status_code == 200
    except requests.RequestException:
        return False


def reportar_con_reintento(payload, url, token, estado):
    pendiente = estado.leer_pendiente()
    if pendiente is not None:
        enviar_reporte(pendiente, url, token)
    exito = enviar_reporte(payload, url, token)
    if exito:
        estado.borrar_pendiente()
    else:
        estado.guardar_pendiente(payload)
    return exito
```

- [ ] **Step 4: Correr las pruebas y confirmar que pasan**

Run: `agente_windows/.venv/Scripts/python.exe -m pytest agente_windows/tests/test_reportero.py -v`
Expected: 6 passed

- [ ] **Step 5: Commit**

```bash
git add agente_windows/reportero.py agente_windows/tests/test_reportero.py
git commit -m "Add: envio del reporte por HTTPS con reintento de un solo pendiente"
```

---

### Task 9: `agente_soporte.py` — punto de entrada (normal / --dry-run / --instalar)

**Files:**
- Create: `agente_windows/agente_soporte.py`

**Interfaces:**
- Consumes: `estado_local.obtener_uuid_agente` (Task 6); todas las funciones de `recolector` (Task 7); `reportero.reportar_con_reintento` (Task 8); `API_URL`, `AGENT_TOKEN` de `config.py` (Task 5).
- Produces (usado por Task 10): `configurar_logging() -> Logger`, `modo_reporte(logger) -> int`.

- [ ] **Step 1: Implementar `agente_windows/agente_soporte.py`**

```python
"""Punto de entrada del agente. Sin argumentos: recolecta y reporta (lo
que ejecuta Task Scheduler cada hora). --dry-run: solo imprime el JSON.
--instalar: se auto-instala (ver instalador.py).
"""
import argparse
import json
import logging
import logging.handlers
import sys
from pathlib import Path

import estado_local
import recolector
import reportero
from config import API_URL, AGENT_TOKEN

LOG_DIR = Path(r"C:\ProgramData\SoporteAgente")


def configurar_logging():
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    logger = logging.getLogger("agente_soporte")
    logger.setLevel(logging.INFO)
    if not logger.handlers:
        handler = logging.handlers.RotatingFileHandler(
            LOG_DIR / "agente.log", maxBytes=1_000_000, backupCount=3, encoding="utf-8"
        )
        handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
        logger.addHandler(handler)
    return logger


def armar_payload():
    so_nombre, so_build = recolector.obtener_so_info()
    ip_local, mac = recolector.obtener_ip_y_mac()
    bios = recolector.obtener_info_bios()
    return {
        "agenteUuid": estado_local.obtener_uuid_agente(),
        "hostname": recolector.obtener_hostname(),
        "usuarioActual": recolector.obtener_usuario_actual(),
        "soNombre": so_nombre,
        "soBuild": so_build,
        "cpuModelo": recolector.obtener_cpu_modelo(),
        "cpuNucleos": recolector.obtener_cpu_nucleos(),
        "ramTotalGb": recolector.obtener_ram_total_gb(),
        "discos": recolector.obtener_discos(),
        "ipLocal": ip_local,
        "macAddress": mac,
        "uptimeSegundos": recolector.obtener_uptime_segundos(),
        "rustdeskId": None,
        "marca": bios["marca"],
        "modelo": bios["modelo"],
        "noSerie": bios["noSerie"],
    }


def modo_reporte(logger):
    payload = armar_payload()
    exito = reportero.reportar_con_reintento(payload, API_URL, AGENT_TOKEN, estado_local)
    if exito:
        logger.info("Reporte enviado correctamente. hostname=%s", payload["hostname"])
    else:
        logger.warning(
            "No se pudo enviar el reporte, se guardo como pendiente. hostname=%s",
            payload["hostname"],
        )
    return 0 if exito else 1


def modo_dry_run():
    payload = armar_payload()
    print(json.dumps(payload, indent=2, ensure_ascii=False))
    return 0


def modo_instalar():
    import instalador

    return instalador.instalar()


def main():
    parser = argparse.ArgumentParser(description="Agente de inventario Soporte Beta")
    parser.add_argument(
        "--instalar", action="store_true", help="Instala el agente y registra la tarea programada"
    )
    parser.add_argument(
        "--dry-run", action="store_true", help="Recolecta datos y los imprime sin enviarlos"
    )
    args = parser.parse_args()

    if args.dry_run:
        return modo_dry_run()
    if args.instalar:
        return modo_instalar()

    logger = configurar_logging()
    return modo_reporte(logger)


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: Probar `--dry-run` en esta máquina de desarrollo**

Run: `agente_windows/.venv/Scripts/python.exe agente_windows/agente_soporte.py --dry-run`
Expected: un JSON impreso con `hostname`, `cpuModelo`, `ramTotalGb`, `discos` (al menos uno), `ipLocal`, `macAddress`, `uptimeSegundos` con valores reales de esta máquina, y `rustdeskId: null`. Revisar a simple vista que ningún campo importante salga `null` inesperadamente (si `marca`/`modelo`/`noSerie` salen `null`, no es bloqueante — es mejor esfuerzo vía WMI).

- [ ] **Step 3: Commit**

```bash
git add agente_windows/agente_soporte.py
git commit -m "Add: punto de entrada del agente (modo reporte y --dry-run)"
```

---

### Task 10: `instalador.py` — auto-instalación

**Files:**
- Create: `agente_windows/instalador.py`
- Test: `agente_windows/tests/test_instalador.py`

**Interfaces:**
- Consumes: `agente_soporte.configurar_logging()`, `agente_soporte.modo_reporte(logger)` (Task 9).
- Produces: `es_administrador() -> bool`, `instalar() -> int`.

- [ ] **Step 1: Implementar `agente_windows/instalador.py`**

```python
"""Auto-instalacion: copia el ejecutable a Program Files y registra la
tarea programada. Requiere correr en una terminal como Administrador.
"""
import ctypes
import shutil
import subprocess
import sys
from pathlib import Path

INSTALL_DIR = Path(r"C:\Program Files\SoporteAgente")
EXE_NAME = "agente_soporte.exe"
TASK_NAME = "SoporteAgenteReporte"


def es_administrador():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin() != 0
    except Exception:
        return False


def _ruta_ejecutable_actual():
    if getattr(sys, "frozen", False):
        return Path(sys.executable)
    return Path(sys.argv[0]).resolve()


def instalar():
    if not es_administrador():
        print("ERROR: este comando debe correr en una terminal como Administrador.")
        return 1

    origen = _ruta_ejecutable_actual()
    INSTALL_DIR.mkdir(parents=True, exist_ok=True)
    destino = INSTALL_DIR / EXE_NAME
    print(f"Copiando {origen} -> {destino}")
    shutil.copy2(origen, destino)

    print(f"Registrando tarea programada '{TASK_NAME}'...")
    resultado = subprocess.run(
        [
            "schtasks", "/Create", "/TN", TASK_NAME,
            "/TR", f'"{destino}"',
            "/SC", "HOURLY", "/MO", "1",
            "/RU", "SYSTEM", "/RL", "HIGHEST", "/F",
        ],
        capture_output=True,
        text=True,
    )
    if resultado.returncode != 0:
        print("ERROR al registrar la tarea programada:")
        print(resultado.stdout)
        print(resultado.stderr)
        return 1
    print("Tarea programada registrada correctamente.")

    print("Enviando el primer reporte...")
    import agente_soporte

    logger = agente_soporte.configurar_logging()
    agente_soporte.modo_reporte(logger)
    print("Instalacion completa.")
    return 0
```

- [ ] **Step 2: Escribir una prueba mínima (chequeo de humo, no depende de privilegios reales)**

Crear `agente_windows/tests/test_instalador.py`:

```python
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import instalador


def test_es_administrador_regresa_booleano():
    resultado = instalador.es_administrador()
    assert isinstance(resultado, bool)
```

- [ ] **Step 3: Correr la prueba**

Run: `agente_windows/.venv/Scripts/python.exe -m pytest agente_windows/tests/test_instalador.py -v`
Expected: 1 passed

- [ ] **Step 4: Commit**

```bash
git add agente_windows/instalador.py agente_windows/tests/test_instalador.py
git commit -m "Add: auto-instalador del agente (copia a Program Files + tarea programada)"
```

**Nota importante para quien ejecute este plan:** el resto de la verificación de `instalar()` (que de verdad copie el archivo y registre la tarea) requiere una terminal elevada como Administrador — no disponible en un entorno de agente automatizado sandboxeado. Esa verificación queda para la Task 12 (prueba en un equipo real), donde el usuario sí tiene esos privilegios.

---

### Task 11: Empaquetado con PyInstaller

**Files:**
- Create: `agente_windows/build.ps1`

**Interfaces:**
- Consumes: `agente_windows/agente_soporte.py` y todos sus módulos (Tasks 6-10).
- Produces: `agente_windows/dist/agente_soporte.exe`

- [ ] **Step 1: Crear el script de build `agente_windows/build.ps1`**

```powershell
# Compila el agente a un solo .exe. Correr desde agente_windows/.
# Requiere haber creado config.py con el token real (ver config.example.py).

if (-not (Test-Path "config.py")) {
    Write-Error "Falta config.py (copia config.example.py y pon el token real antes de compilar)"
    exit 1
}

.venv\Scripts\pyinstaller.exe --onefile --name agente_soporte agente_soporte.py

Write-Host "Listo: dist\agente_soporte.exe"
```

- [ ] **Step 2: Compilar**

```bash
cd agente_windows
powershell -File build.ps1
```

Expected: termina con `Listo: dist\agente_soporte.exe` y el archivo `agente_windows/dist/agente_soporte.exe` existe.

- [ ] **Step 3: Probar el exe compilado con `--dry-run`**

Run: `agente_windows/dist/agente_soporte.exe --dry-run`
Expected: el mismo JSON que en la Task 9, Step 2 (confirma que el empaquetado no rompió nada).

- [ ] **Step 4: Commit**

```bash
cd ..
git add agente_windows/build.ps1
git commit -m "Add: script de build del agente con PyInstaller"
```

---

### Task 12: Prueba en un equipo real y documentación para IT

**Files:**
- Create: `agente_windows/README.md`

**Interfaces:**
- Consumes: `agente_windows/dist/agente_soporte.exe` (Task 11).

- [ ] **Step 1: Crear `agente_windows/README.md`**

```markdown
# Agente de Inventario — Soporte Beta

Recolecta especificaciones del equipo (CPU, RAM, disco, red, SO) y las
reporta cada hora al sistema de Soporte. Ver el diseño completo en
`docs/superpowers/specs/2026-07-08-agente-inventario-windows-design.md`.

## Instalar en un equipo

1. Transferir `agente_soporte.exe` al equipo (por RustDesk, USB, etc.).
2. Abrir PowerShell o CMD **como Administrador**.
3. Correr:
   ```
   .\agente_soporte.exe --instalar
   ```
4. Debe terminar con "Instalacion completa." — el equipo aparece o se
   actualiza de inmediato en la pantalla de Inventario (puede aparecer
   como "Pendiente de captura" si es la primera vez que se ve ese equipo;
   hay que completarle los datos de negocio a mano: folio, valor de
   compra, a quien esta asignado).

## Verificar que esta funcionando

- Log local: `C:\ProgramData\SoporteAgente\agente.log`
- Tarea programada: Programador de Tareas de Windows → buscar
  "SoporteAgenteReporte" (corre cada hora como SYSTEM).
- Si el equipo estuvo sin internet, el ultimo reporte fallido queda en
  `C:\ProgramData\SoporteAgente\pending_report.json` y se reintenta solo
  en la siguiente corrida.

## Reinstalar / actualizar

Correr `--instalar` de nuevo con el `.exe` mas reciente — sobreescribe el
anterior y actualiza la tarea programada, sin duplicar nada.

## Limitaciones conocidas

- El RustDesk ID no se detecta automaticamente (ver spec) — se sigue
  capturando a mano en Inventario.
```

- [ ] **Step 2: Instalar en un solo equipo real de la empresa**

Transferir `agente_windows/dist/agente_soporte.exe` a un equipo real (no de prueba/desarrollo) por RustDesk, correr `.\agente_soporte.exe --instalar` en una PowerShell elevada, y confirmar en la terminal que imprime "Instalacion completa." sin errores.

- [ ] **Step 3: Confirmar en la base de datos que el equipo quedó registrado correctamente**

```bash
ssh -i llave-aws-beta.pem -o StrictHostKeyChecking=no ubuntu@54.161.41.131 "mysql -u admin_soporte -p\$(grep DB_PASSWORD /home/ubuntu/api-soporte/.env | cut -d= -f2) soporte_beta -e \"SELECT id, hostname, estatus, cpu_modelo, ram_total_gb, ultimo_reporte_agente FROM equipos WHERE agente_uuid IS NOT NULL ORDER BY id DESC LIMIT 5;\""
```

Expected: aparece el equipo recién instalado, con `estatus = 'Pendiente de captura'` (si era nuevo) y datos de CPU/RAM reales del equipo.

- [ ] **Step 4: Commit**

```bash
git add agente_windows/README.md
git commit -m "Docs: README de instalacion del agente para IT"
```

---

## Fin del plan

Con esto el agente queda funcional de punta a punta: recolecta, reporta,
se auto-instala, y ya se probó en al menos un equipo real. El rollout a
los 100+ equipos restantes es repetir la Task 12, Step 2 por cada uno —
no requiere más cambios de código.
