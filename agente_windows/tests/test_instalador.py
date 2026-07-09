import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import instalador


def test_es_administrador_regresa_booleano():
    resultado = instalador.es_administrador()
    assert isinstance(resultado, bool)
