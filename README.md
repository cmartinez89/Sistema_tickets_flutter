# Soporte Beta — Sistema de Tickets TI

Sistema interno de gestión de soporte técnico, inventario de equipos, control de respaldos y reportes, desarrollado en **Flutter Web** con backend **FastAPI** en **AWS EC2**.

---

## Funcionalidades

### Tickets de Soporte
- Registro de reportes con prioridad (Alta / Media / Baja), categoría y área/departamento
- Flujo de estados: **Pendiente → En Proceso → Escalado → Resuelto**
- **Escalado**: al escalar se registra a quién y el motivo
- **Resolución inteligente**: distingue Incidencia (causa raíz, solución, pruebas, validación), Servicio (solo validación) y **Mantenimiento** (preventivo/correctivo; si correctivo registra qué se corrigió; permite adjuntar múltiples fotos)
- Adjuntar imagen(es) al resolver un ticket (múltiples para Mantenimiento)
- **Historial de tiempos por estado**: registro de cuánto tiempo duró el ticket en cada estado (en horas)
- Fecha de creación y tiempo transcurrido visible en cada tarjeta
- **Búsqueda global** en tiempo real: busca por ID, usuario, descripción, área, categoría o técnico asignado
- **Filtros de fecha** (Desde / Hasta) combinables con los demás filtros
- **Filtros** por estado (Activos/Resueltos/Todos), área y prioridad
- Chip de prioridad visible en cada tarjeta de ticket
- **Auto-asignación**: técnicos se asignan automáticamente al crear tickets; Admin puede asignar libremente o dejar sin asignar
- El campo Departamento se elimina del formulario — se usa el Área seleccionada como departamento automáticamente
- Vista diferenciada por rol (Admin ve todos; Técnico ve solo los suyos)

### Chat Interno
- Chat en tiempo real via WebSocket entre técnicos y administrador
- **Envío de imágenes** en el chat
- Colores únicos por usuario (paleta determinista de 12 tonos)
- Badge rojo con contador de mensajes no leídos
- Botón flotante (FAB) visible en toda la aplicación

### Inventario y Responsivas
- Catálogo de equipos: Laptop, Desktop, Servidor, Celular, Bastón, Radio, Tablet
- **Folio de activo auto-generado** al registrar (ACT-YYYY-NNN)
- **Folio de responsiva auto-generado** al asignar (RES-YYYY-NNN)
- Dirección MAC para Celular, Laptop, Desktop y Servidor
- Campo de área/ubicación con **selector de área** (dropdown) al registrar equipo
- **Alta de equipo disponible para Técnicos** (no solo Admin)
- **Impresión de Carta Responsiva** desde el navegador (nueva ventana con formato para imprimir)
- **Gestión de obsolescencia**: equipos ≥ 5 años se marcan como "Fuera de Servicio" y solo pueden venderse
- **Registrar venta**: precio y fecha de venta de equipos dados de baja
- Cálculo automático de depreciación (20% anual, piso del 20%)
- **Búsqueda y filtros** por tipo, área y estatus
- Asignación/liberación de equipos a empleados

### Control de Respaldos
- Seguimiento de último respaldo por equipo con alerta visual:
  - Amarillo: sin respaldo registrado
  - Rojo: más de 15 días sin respaldo
- **Búsqueda por texto** (modelo, marca o nombre de empleado)
- **Filtros** por estado de alerta y área
- **Alta de equipo** disponible para Técnicos desde esta pantalla

### Dashboard
- Resumen de tickets: Pendientes, En Proceso, Resueltos, Prioridad Alta, **Escalados**
- Métricas de inventario: Asignados, Disponibles, Valor total depreciado
- Estado de respaldos: Al día vs Atrasados
- Últimos tickets registrados

### Módulo de Reportes (Admin)
- Tickets por estado, prioridad, técnico, área y categoría
- Gráficas de barras horizontales para comparación visual
- Tendencia mensual de tickets (últimos 6 meses)
- Equipos por tipo y por estatus
- Tiempo promedio de resolución en horas

### Asistente IA (Admin) — Claude claude-opus-4-8
- **Asistente en lenguaje natural**: el admin puede hacer preguntas en español sobre el sistema ("¿qué técnico tiene más carga?", "¿cuántos tickets pendientes hay?", etc.). Claude recibe contexto real de la BD en cada consulta.
- **Detección de anomalías**: análisis bajo demanda de todos los tickets abiertos, equipos sin respaldo y tiempos de resolución. Devuelve lista de anomalías con severidad (alta / media / baja) y recomendación de acción.
- **Sugerencia de resolución**: botón "Sugerencia IA" en cada ticket no resuelto. Claude analiza el ticket y tickets similares ya resueltos para sugerir diagnóstico, pasos y tiempo estimado.

### Administración (Admin)
- **Categorías de tickets**: dar de alta, editar y eliminar
- **Áreas/Departamentos**: dar de alta, editar y eliminar
- **Tipos de equipo**: dar de alta, editar y eliminar (Celular, Bastón, Radio, Tablet, Laptop, Desktop, Servidor)
- **Gestión de usuarios**: reseteo de contraseñas desde el panel; al resetear se fuerza cambio en el próximo inicio de sesión

### Identidad visual
- Colores corporativos Beta Systems: navy `#1A2B72`, rojo `#DC0026` y azul `#4E9FE0`
- Logo Beta como ícono de la app (web favicon, Android launcher y round icons)
- Pantalla de login rediseñada con logo, tipografía y botón en color corporativo

### Sesión persistente
- Sesión guardada en `localStorage` con TTL de 7 días
- Cierre de sesión explícito limpia la sesión de inmediato
- Al retomar la app desde background, el WebSocket se reconecta y los tickets se actualizan automáticamente
- **Cambio forzado de contraseña**: si el admin resetea la contraseña de un usuario, al hacer login se muestra un modal obligatorio para elegir una nueva antes de acceder al sistema

### Notificaciones en tiempo real
- WebSocket permanente con reconexión automática
- Notificaciones nativas del navegador para nuevos tickets, cambios de estado y mensajes

### Notificaciones Push Android (FCM)
- **Firebase Cloud Messaging** integrado con `firebase_messaging` + `flutter_local_notifications`
- El token FCM se registra automáticamente en el backend al iniciar sesión
- El técnico recibe notificación push cuando se le asigna un ticket nuevo o se le reasigna uno existente
- Las notificaciones llegan aunque la app esté en segundo plano o cerrada
- Canales de alta prioridad configurados en Android (vibración + sonido)
- Al primer inicio solicita exención de optimización de batería (necesario en Samsung para notificaciones en background)

---

## Arquitectura

**Flutter Web PWA** conectado a FastAPI backend en AWS EC2.

```
LoginScreen → MainLayout → [Dashboard, Tickets, Equipos, Respaldos, Chat, Usuarios*, Admin*, Reportes*, AsistenteIA*]
                                                                               (* Solo Admin)
```

### Estructura del proyecto

```
lib/
├── main.dart                    ← inicializa Firebase antes de runApp()
├── firebase_options.dart        ← opciones FCM (generado de google-services.json)
├── models/
│   ├── session_model.dart
│   ├── ticket_model.dart        ← escaladoA, motivoEscalado, tipoTicket, categoria, area, imagenResolucion
│   ├── equipo_model.dart        ← area, macAddress, folioActivo, fechaVenta, precioVenta, esObsoleto
│   ├── chat_message_model.dart  ← imagen (base64)
│   └── usuario_model.dart
├── services/
│   ├── api_service.dart         ← registrarFcmToken(), fetchAiConsulta/Anomalias/Sugerencia()
│   ├── websocket_service.dart
│   └── notification_service.dart
├── utils/
│   ├── notif_helper.dart        ← export condicional web/nativo
│   ├── notif_helper_stub.dart   ← FCM + flutter_local_notifications (Android/iOS)
│   └── notif_helper_web.dart    ← Web Notifications API (Chrome/PWA)
└── screens/
    ├── login_screen.dart
    ├── main_layout.dart         ← registra token FCM al iniciar sesión
    ├── dashboard_screen.dart
    ├── tickets_screen.dart      ← botón "Sugerencia IA" en detalle de ticket
    ├── equipment_screen.dart
    ├── backups_screen.dart
    ├── chat_screen.dart
    ├── users_screen.dart
    ├── admin_screen.dart
    ├── reportes_screen.dart
    ├── ai_screen.dart           ← Asistente IA + Detección de Anomalías (Admin)
    └── dialogo_nuevo_equipo.dart

main_api.py                      ← backend FastAPI (incluye endpoints /ai/*)
android/app/google-services.json ← config Firebase Android (no commiteado en repo público)
```

---

## Comandos de desarrollo

```bash
flutter pub get              # instalar dependencias
flutter run -d chrome        # desarrollo en Chrome
flutter build web            # build de producción web (PWA)
flutter build apk --release  # build APK Android
flutter run -d <iphone_id>   # instalar en iPhone (requiere Xcode + CocoaPods)
flutter analyze              # análisis estático
```

## Despliegue

```bash
# Web → EC2
rsync -avz --delete -e "ssh -i llave-aws-beta.pem" build/web/ ubuntu@54.161.41.131:/var/www/soporte/

# Android → Samsung (USB debug)
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# iOS → iPhone (requiere CocoaPods instalado)
cd ios && pod install && cd ..
flutter run --release -d <device_id>

# Backend API (en EC2)
# kill $(lsof -t -i:8000)
# source venv/bin/activate && nohup uvicorn main:app --host 0.0.0.0 --port 8000 > api.log 2>&1 &
```

---

## Configuración

```dart
// lib/services/api_service.dart
const String kApiUrl = 'http://54.161.41.131:8000';

// lib/screens/main_layout.dart
const String kWsUrl = 'ws://54.161.41.131:8000/ws';
```

---

## Backend (FastAPI)

- **Servidor**: AWS EC2 Ubuntu `54.161.41.131:8000`
- **DB**: MySQL 8.4, base `soporte_beta`

### Endpoints REST

| Método | Ruta | Descripción |
|--------|------|-------------|
| `POST` | `/login` | Autenticación — retorna `forzarCambioPassword` si el admin reseteó la contraseña |
| `POST` | `/cambiar-password` | Cambiar contraseña y limpiar flag de cambio forzado |
| `GET/POST` | `/tickets` | Listar / crear ticket |
| `PUT` | `/tickets/:id/status` | Cambiar estado |
| `PUT` | `/tickets/:id/assign` | Reasignar técnico |
| `PUT` | `/tickets/:id/resolve` | Cerrar con documentación e imagen |
| `PUT` | `/tickets/:id/escalar` | Escalar ticket |
| `GET` | `/tickets/:id/historial` | Historial de tiempos por estado |
| `GET/POST` | `/equipos` | Listar / registrar equipo (folio auto) |
| `PUT` | `/equipos/:id/assign` | Asignar (genera folio responsiva) |
| `PUT` | `/equipos/:id/release` | Liberar equipo |
| `PUT` | `/equipos/:id/vender` | Registrar venta |
| `PUT` | `/equipos/:id/backup` | Actualizar respaldo |
| `GET/POST/PUT/DELETE` | `/categorias` | CRUD categorías de ticket |
| `GET/POST/PUT/DELETE` | `/areas` | CRUD áreas/departamentos |
| `GET/POST/PUT/DELETE` | `/tipos-equipo` | CRUD tipos de equipo |
| `GET` | `/reportes` | Métricas y datos para gráficas |
| `GET/POST` | `/mensajes` | Historial / enviar mensaje (con imagen) |
| `WS` | `/ws` | Canal WebSocket tiempo real |
| `POST` | `/usuarios/:username/fcm-token` | Registrar token FCM del dispositivo |
| `POST` | `/ai/consulta` | Consulta en lenguaje natural al asistente IA |
| `POST` | `/ai/anomalias` | Análisis de anomalías del sistema vía IA |
| `POST` | `/ai/sugerencia/:ticket_id` | Sugerencia de resolución para un ticket vía IA |

---

## Roles

| Rol | Permisos |
|-----|----------|
| **Admin** | Todos los tickets, reasignación, inventario completo, reportes, administración de catálogos |
| **Técnico** | Sus tickets, actualización de estado y respaldos; tickets se auto-asignan al crearse |

---

*Proyecto interno — Beta Systems TI*
