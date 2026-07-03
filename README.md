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
LoginScreen → MainLayout → [DashboardScreen, TicketsScreen, EquipmentScreen, PantallaRespaldos,
                            ProyectosScreen, TareasScreen (Kanban + Gantt), ChatScreen]
```

- **Auth**: JWT con `python-jose`, bcrypt para contraseñas
- **Estado**: `MainLayout` como dueño central (tickets, equipos, proyectos, tareas, usuarios, mensajes), `onRefresh` callbacks
- **Dashboard**: pantalla de entrada para todos los roles — muestra el bloque de Soporte y/o el de Desarrollo según a qué tenga acceso cada quien
- **Proyectos/Tareas**: Kanban + Gantt por proyecto; los desarrolladores solo pueden mover (drag) las tareas que tienen asignadas, aunque ven todas las del proyecto
- **Chat**: 3 canales (Soporte, Desarrollo, General) vía WebSocket en `/ws`, visibles según el rol
- **Bot Telegram**: `telegram_bot.py` — crea tickets por conversación con IA (Claude Haiku)
- **Monitoreo**: systemd + cron cada 5 min + alertas email/Telegram

## Roles

| Rol | Acceso |
|---|---|
| `Admin` | Todo: tickets, inventario, catálogos, proyectos/tareas, los 3 canales de chat, gestión de usuarios |
| `Técnico` | Solo tickets asignados a él; chat Soporte + General |
| `Técnico Sr.` | Todos los tickets e inventario; chat Soporte + General |
| `Desarrollador Sr.` | Solo Proyectos/Tareas/Chat — crea proyectos y tareas, asigna desarrolladores, mueve cualquier tarea; chat Desarrollo + General |
| `Desarrollador` | Solo Proyectos/Tareas/Chat — ve todas las tareas del proyecto pero solo mueve las suyas; chat Desarrollo + General |

## Comandos de desarrollo

```bash
flutter pub get          # instalar dependencias
flutter run -d chrome    # correr en desarrollo
flutter build web        # build web para producción
flutter build apk        # build APK Android
flutter analyze          # análisis estático
```

## Despliegue en producción

```powershell
# Build + deploy del frontend (build web, scp, permisos, fix de service worker)
.\deploy.ps1

# Compilar APK
flutter build apk --release
# APK en: build/app/outputs/flutter-apk/app-release.apk
```

Si el cambio toca el backend, copiar `main_api.py` al servidor y reiniciar el servicio antes de correr `deploy.ps1` (ver sección "Subir cambios al servidor"). Si agrega una columna/tabla nueva, correr la migración en MySQL antes de reiniciar la API.

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
- **Proyecto**: nombre, descripcion, fechaInicio, fechaFin, estado (activo/pausado/terminado), responsableUsername
- **Tarea**: proyectoId, titulo, descripcion, estado (por_hacer/haciendo/en_revision/hecho), prioridad, asignadoAUsername, fechaInicio, fechaFin
- **Mensaje (chat)**: deUsuario, nombreCompleto, texto, imagen, fecha, canal (soporte/desarrollo/general), borrado

## Alertas de respaldo

- 🟡 Amarillo: sin respaldo registrado
- 🔴 Rojo: último respaldo hace más de 15 días

## Monitoreo automático

- systemd reinicia los servicios automáticamente si crashean
- Cron cada 5 min verifica que la API responda
- Email + Telegram a `cmartinez@beta.com.mx` si hay caída o recuperación
