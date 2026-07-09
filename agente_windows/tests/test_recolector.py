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
