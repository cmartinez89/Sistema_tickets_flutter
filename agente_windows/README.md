# Agente de Inventario — Soporte Beta

Recolecta especificaciones del equipo (CPU, RAM, disco, red, SO) y las
reporta cada hora al sistema de Soporte. Ver el diseño completo en
`docs/superpowers/specs/2026-07-08-agente-inventario-windows-design.md`.

## Instalar en un equipo

1. Transferir `agente_soporte.exe` al equipo (por RustDesk, USB, etc.).
2. Abrir PowerShell o CMD **como Administrador**.
3. Correr:
   ```
   .\agente_soporte.exe --instalar
   ```
4. Debe terminar con "Instalacion completa." — el equipo aparece o se
   actualiza de inmediato en la pantalla de Inventario (puede aparecer
   como "Pendiente de captura" si es la primera vez que se ve ese equipo;
   hay que completarle los datos de negocio a mano: folio, valor de
   compra, a quien esta asignado).

## Verificar que esta funcionando

- Log local: `C:\ProgramData\SoporteAgente\agente.log`
- Tarea programada: Programador de Tareas de Windows → buscar
  "SoporteAgenteReporte" (corre cada hora como SYSTEM).
- Si el equipo estuvo sin internet, el ultimo reporte fallido queda en
  `C:\ProgramData\SoporteAgente\pending_report.json` y se reintenta solo
  en la siguiente corrida.

## Reinstalar / actualizar

Correr `--instalar` de nuevo con el `.exe` mas reciente — sobreescribe el
anterior y actualiza la tarea programada, sin duplicar nada.

## Limitaciones conocidas

- El RustDesk ID no se detecta automaticamente (ver spec) — se sigue
  capturando a mano en Inventario.
