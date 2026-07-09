# Compila el agente a un solo .exe. Correr desde agente_windows/.
# Requiere haber creado config.py con el token real (ver config.example.py).

if (-not (Test-Path "config.py")) {
    Write-Error "Falta config.py (copia config.example.py y pon el token real antes de compilar)"
    exit 1
}

.venv\Scripts\pyinstaller.exe --onefile --name agente_soporte agente_soporte.py

Write-Host "Listo: dist\agente_soporte.exe"
