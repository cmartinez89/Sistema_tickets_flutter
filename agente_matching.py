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
