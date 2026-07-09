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
