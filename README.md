# Soporte Beta — Sistema de Tickets TI

Sistema interno de gestión de soporte técnico, inventario de equipos y control de respaldos, desarrollado en **Flutter Web** con backend **FastAPI** en **AWS EC2**.

---

## Funcionalidades

### Tickets de Soporte
- Registro de reportes con prioridad (Alta / Media / Baja) y asignación a técnico
- Flujo de estados: Pendiente → En Proceso → Resuelto
- Cierre documentado: causa raíz, solución aplicada, pruebas realizadas y validación
- Filtros por estado: Activos, Resueltos, Todos
- Vista diferenciada por rol (Admin ve todos; Técnico ve solo los suyos)

### Inventario y Responsivas
- Catálogo de equipos (laptops, desktops, servidores) con ficha técnica completa
- Asignación a empleado con folio de carta responsiva y liberación de equipo
- Cálculo automático de depreciación (20% anual, piso del 20% del valor original)
- Registro de ID Anydesk y RustDesk por equipo

### Control de Respaldos
- Seguimiento de último respaldo por equipo con alerta visual por color:
  - Amarillo: sin respaldo registrado
  - Rojo: más de 15 días sin respaldo
- Actualización de fecha de respaldo sincronizada con la API

### Dashboard
- Gráficas de dona: Pendientes, En Proceso, Resueltos, Prioridad Alta
- Métricas de inventario: Asignados, Disponibles, Valor total depreciado
- Estado de respaldos: Al día vs Atrasados
- Últimos 5 tickets registrados (solo Admin)

### Notificaciones en tiempo real (WebSocket)
- Conexión permanente al backend mediante WebSocket
- La UI se actualiza automáticamente cuando cualquier usuario hace un cambio
- Notificaciones nativas del navegador (Web Notifications API) para:
  - Tickets nuevos asignados al usuario
  - Cambios de estado en tickets del usuario
  - Reasignaciones
- Reconexión automática si se pierde la conexión

---

## Arquitectura

```
Flutter Web (PWA)
      │
      ├── HTTP REST  ──►  FastAPI /tickets, /equipos, /login
      │
      └── WebSocket  ──►  FastAPI /ws  (actualizaciones en tiempo real)
                               │
                          MySQL (AWS EC2)
```

### Estructura del proyecto

```
lib/
├── main.dart
├── models/
│   ├── session_model.dart
│   ├── ticket_model.dart
│   └── equipo_model.dart
├── services/
│   ├── api_service.dart          ← HTTP REST (kApiUrl, kTimeout)
│   ├── websocket_service.dart    ← WebSocket con reconexión automática
│   └── notification_service.dart ← Web Notifications API
└── screens/
    ├── login_screen.dart
    ├── main_layout.dart          ← estado central, WS, detección de cambios
    ├── dashboard_screen.dart
    ├── tickets_screen.dart
    ├── equipment_screen.dart
    ├── backups_screen.dart
    └── dialogo_nuevo_equipo.dart

main_api.py                       ← backend FastAPI (subir a EC2)
```

---

## Instalación

### Requisitos
- Flutter SDK `>=3.12.0`
- Dart `>=3.12.0`
- Chrome (para desarrollo web)

### Pasos

```bash
git clone https://github.com/cmartinez89/Sistema_tickets_flutter.git
cd Sistema_tickets_flutter
flutter pub get
flutter run -d chrome
flutter build web   # build de producción
```

### Dependencias

| Paquete | Uso |
|--------|-----|
| `http` | Peticiones REST a la API |
| `web`  | WebSocket, Web Notifications API |

---

## Configuración

La URL del backend se define en dos archivos:

```dart
// lib/services/api_service.dart
const String kApiUrl = 'http://TU_IP_EC2:8000';

// lib/screens/main_layout.dart
const String kWsUrl = 'ws://TU_IP_EC2:8000/ws';
```

Para cambiar de servidor, edita solo esas dos constantes.

> Para producción se recomienda HTTPS/WSS con dominio y certificado SSL.

---

## Backend (FastAPI)

El archivo `main_api.py` va en el servidor EC2. Para desplegarlo:

```bash
# Copiar al servidor
scp main_api.py ubuntu@TU_IP_EC2:/home/ubuntu/api-soporte/

# Reiniciar el servicio
ssh ubuntu@TU_IP_EC2 "sudo systemctl restart api-soporte"
```

### Endpoints REST

| Método | Ruta | Descripción |
|--------|------|-------------|
| `POST` | `/login` | Autenticación |
| `GET` | `/tickets` | Listar tickets |
| `POST` | `/tickets` | Crear ticket |
| `PUT` | `/tickets/:id/status` | Cambiar estado |
| `PUT` | `/tickets/:id/assign` | Reasignar técnico |
| `PUT` | `/tickets/:id/resolve` | Cerrar ticket con documentación |
| `GET` | `/equipos` | Listar equipos |
| `POST` | `/equipos` | Registrar equipo |
| `PUT` | `/equipos/:id/assign` | Asignar equipo a empleado |
| `PUT` | `/equipos/:id/release` | Liberar equipo |
| `PUT` | `/equipos/:id/backup` | Actualizar fecha de respaldo |
| `WS`  | `/ws` | Canal WebSocket para actualizaciones en tiempo real |

---

## Roles

| Rol | Permisos |
|-----|----------|
| **Admin** | Todos los tickets, reasignación de técnicos, inventario completo, dashboard global |
| **Técnico** | Solo sus tickets asignados, actualización de estado y respaldos |

---

*Proyecto interno — Beta Systems TI*
