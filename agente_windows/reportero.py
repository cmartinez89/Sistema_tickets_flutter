"""Envio del reporte por HTTPS con manejo simple de fallas: si falla, se
guarda como pendiente para reintentarlo en la siguiente corrida (no hay
backoff ni cola creciente, ver spec)."""
import requests


def enviar_reporte(payload, url, token, timeout=10):
    try:
        respuesta = requests.post(
            url,
            json=payload,
            headers={"X-Agent-Token": token, "Content-Type": "application/json"},
            timeout=timeout,
        )
        return respuesta.status_code == 200
    except requests.RequestException:
        return False


def reportar_con_reintento(payload, url, token, estado):
    pendiente = estado.leer_pendiente()
    if pendiente is not None:
        # Resultado ignorado a proposito: el payload actual siempre reemplaza
        # al pendiente (exitoso o no), asi que no cambia el flujo de abajo.
        enviar_reporte(pendiente, url, token)
    exito = enviar_reporte(payload, url, token)
    if exito:
        estado.borrar_pendiente()
    else:
        estado.guardar_pendiente(payload)
    return exito
