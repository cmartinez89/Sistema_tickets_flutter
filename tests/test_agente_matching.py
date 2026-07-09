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
