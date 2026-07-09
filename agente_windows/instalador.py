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
    try:
        shutil.copy2(origen, destino)
    except OSError as e:
        print(f"ERROR al copiar el ejecutable (¿sigue corriendo una version anterior?): {e}")
        return 1

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
    try:
        import agente_soporte

        logger = agente_soporte.configurar_logging()
        agente_soporte.modo_reporte(logger)
    except Exception as e:
        print(f"ADVERTENCIA: la instalacion quedo completa, pero el primer reporte fallo: {e}")
        print("Se reintentara automaticamente en la siguiente corrida programada.")
        return 0
    print("Instalacion completa.")
    return 0
