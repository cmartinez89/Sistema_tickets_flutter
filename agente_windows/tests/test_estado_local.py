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
