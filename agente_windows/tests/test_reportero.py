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
