# Sistema de Tickets — Beta Systems

Sistema de soporte TI para Beta Systems. Flutter Web PWA + FastAPI + MySQL en AWS EC2.

## Acceso

| Canal | URL / Contacto |
|---|---|
| Web | https://soporte.beta.com.mx |
| Bot Telegram | @Soporte_BSM_bot |
| API | https://soporte.beta.com.mx/api |

## Stack

- **Frontend**: Flutter Web (PWA) — desplegado en EC2 con nginx
- **Backend**: FastAPI (Python 3.14) — puerto 8000, proxy via nginx
- **Base de datos**: MySQL — `soporte_beta` en localhost
- **Infraestructura**: AWS EC2 Ubuntu, Cloudflare SSL, systemd

## Arquitectura

```
LoginScreen → MainLayout → [DashboardScreen, TicketsScreen, EquipmentScreen, PantallaRespaldos]
```

- **Auth**: JWT con `python-jose`, bcrypt para contraseñas
- **Estado**: `MainLayout` como dueño central, `onRefresh` callbacks
- **WebSocket**: chat en tiempo real en `/ws`
- **Bot Telegram**: `telegram_bot.py` — crea tickets por conversación con IA (Claude Haiku)
- **Monitoreo**: systemd + cron cada 5 min + alertas email/Telegram

## Roles

| Rol | Acceso |
|---|---|
| `Admin` | Todos los tickets, inventario completo, catálogos |
| `Técnico` | Solo tickets asignados a él |

## Comandos de desarrollo

```bash
flutter pub get          # instalar dependencias
flutter run -d chrome    # correr en desarrollo
flutter build web        # build web para producción
flutter build apk        # build APK Android
flutter analyze          # análisis estático
```

## Despliegue en producción

```bash
# Compilar web y subir al servidor
flutter build web --release
rsync -avz --delete build/web/ ubuntu@54.161.41.131:/var/www/soporte/

# Compilar APK
flutter build apk --release
# APK en: build/app/outputs/flutter-apk/app-release.apk
```

## Servicios en el servidor

```bash
# Ver estado
sudo systemctl status soporte-api soporte-bot

# Reiniciar
sudo systemctl restart soporte-api
sudo systemctl restart soporte-bot

# Logs
sudo journalctl -u soporte-api -n 50
sudo journalctl -u soporte-bot -n 50
tail -f /home/ubuntu/api-soporte/api.log
tail -f /home/ubuntu/api-soporte/bot.log
tail -f /home/ubuntu/api-soporte/monitor.log
```

## Subir cambios al servidor

```bash
# API
scp -i "~/Desktop/Llave AWS DB/llave-aws-beta.pem" \
  main_api.py ubuntu@54.161.41.131:/home/ubuntu/api-soporte/main.py
sudo systemctl restart soporte-api

# Bot
scp -i "~/Desktop/Llave AWS DB/llave-aws-beta.pem" \
  telegram_bot.py ubuntu@54.161.41.131:/home/ubuntu/api-soporte/telegram_bot.py
sudo systemctl restart soporte-bot
```

## Variables de entorno (.env en servidor)

```
JWT_SECRET_KEY=...
DB_PASSWORD=...
TELEGRAM_BOT_TOKEN=...
ANTHROPIC_API_KEY=...
SMTP_HOST=smtp.mail.us-east-1.awsapps.com
SMTP_PORT=465
SMTP_USER=cmartinez@beta.com.mx
SMTP_PASS=...
ALERT_TO=cmartinez@beta.com.mx
```

## Modelos de datos

- **Ticket**: `id (TK-XXX)`, usuario, departamento, descripcion, prioridad, estado, asignadoA, area, categoria, tipo_ticket
- **Equipo**: folio_activo, folio_responsiva, tipo, marca, modelo, no_serie, estatus, empleadoAsignado, ultimoRespaldo
- **Usuario**: username, nombre_completo, rol, email, telegram_id, area

## Alertas de respaldo

- 🟡 Amarillo: sin respaldo registrado
- 🔴 Rojo: último respaldo hace más de 15 días

## Monitoreo automático

- systemd reinicia los servicios automáticamente si crashean
- Cron cada 5 min verifica que la API responda
- Email + Telegram a `cmartinez@beta.com.mx` si hay caída o recuperación
