# deploy.ps1 — Build y deploy Flutter web al servidor
param([string]$Key = "llave-aws-beta.pem")

$SERVER = "ubuntu@54.161.41.131"
$WEBROOT = "/var/www/soporte"

Write-Host "Building Flutter web..." -ForegroundColor Cyan
flutter build web --release
if ($LASTEXITCODE -ne 0) { Write-Host "Build failed" -ForegroundColor Red; exit 1 }

Write-Host "Deploying to server..." -ForegroundColor Cyan
scp -i $Key -o StrictHostKeyChecking=no -r build/web/* "${SERVER}:${WEBROOT}/"

Write-Host "Fixing service worker reload loop..." -ForegroundColor Cyan
$fixScript = @'
import re

# Quita serviceWorkerSettings para evitar reload loop infinito
with open("/var/www/soporte/flutter_bootstrap.js") as f:
    content = f.read()
fixed = re.sub(r'_flutter\.loader\.load\(\{[\s\S]*?\}\);', '_flutter.loader.load({});', content)
with open("/var/www/soporte/flutter_bootstrap.js", "w") as f:
    f.write(fixed)

# Reemplaza flutter_service_worker.js con version que no causa loop
with open("/var/www/soporte/flutter_service_worker.js", "w") as f:
    f.write('"use strict";\nself.addEventListener("install", () => { self.skipWaiting(); });\nself.addEventListener("activate", (event) => { event.waitUntil(self.clients.claim()); });\n')

print("Service worker patches applied")
'@

$fixScript | Set-Content "$env:TEMP\fix_sw_deploy.py" -Encoding UTF8
scp -i $Key -o StrictHostKeyChecking=no "$env:TEMP\fix_sw_deploy.py" "${SERVER}:/tmp/fix_sw_deploy.py"
ssh -i $Key -o StrictHostKeyChecking=no $SERVER "python3 /tmp/fix_sw_deploy.py"

Write-Host "Done! Site is live at https://soporte.beta.com.mx" -ForegroundColor Green
