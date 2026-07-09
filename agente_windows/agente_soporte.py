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
