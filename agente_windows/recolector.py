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
