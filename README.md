# Soporte Beta — Sistema de Tickets TI

Sistema interno de gestión de soporte técnico, inventario de equipos, control de respaldos y reportes, desarrollado en **Flutter Web** con backend **FastAPI** en **AWS EC2**.

---

## Funcionalidades

### Tickets de Soporte
- Registro de reportes con prioridad (Alta / Media / Baja), categoría y área/departamento
- Flujo de estados: **Pendiente → En Proceso → Escalado → Resuelto**
- **Escalado**: al escalar se registra a quién y el motivo
- **Resolución inteligente**: distingue Incidencia (causa raíz, solución, pruebas, validación) vs Servicio (solo validación)
- Adjuntar imagen opcional al resolver un ticket
- **Historial de tiempos por estado**: registro de cuánto tiempo duró el ticket en cada estado (en horas)
- Fecha de creación y tiempo transcurrido visible en cada tarjeta
- **Filtros** por estado (Activos/Resueltos/Todos), área y prioridad
- Chip de prioridad visible en cada tarjeta de ticket
- **Auto-asignación**: técnicos se asignan automáticamente al crear tickets; Admin puede asignar libremente o dejar sin asignar
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
- Campo de área/ubicación del equipo
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

### Administración (Admin)
- **Categorías de tickets**: dar de alta, editar y eliminar
- **Áreas/Departamentos**: dar de alta, editar y eliminar
- **Tipos de equipo**: dar de alta, editar y eliminar (Celular, Bastón, Radio, Tablet, Laptop, Desktop, Servidor)

### Sesión persistente
- Sesión guardada en `localStorage` con TTL de 7 días
- Cierre de sesión explícito limpia la sesión de inmediato

### Notificaciones en tiempo real
- WebSocket permanente con reconexión automática
- Notificaciones nativas del navegador para nuevos tickets, cambios de estado y mensajes

---

## Arquitectura

**Flutter Web PWA** conectado a FastAPI backend en AWS EC2.

```
LoginScreen → MainLayout → [Dashboard, Tickets, Equipos, Respaldos, Chat, Usuarios*, Admin*, Reportes*]
                                                                               (* Solo Admin)
```

### Estructura del proyecto

```
lib/
├── main.dart
├── models/
│   ├── session_model.dart
│   ├── ticket_model.dart        ← escaladoA, motivoEscalado, tipoTicket, categoria, area, imagenResolucion
│   ├── equipo_model.dart        ← area, macAddress, folioActivo, fechaVenta, precioVenta, esObsoleto
│   ├── chat_message_model.dart  ← imagen (base64)
│   └── usuario_model.dart
├── services/
│   ├── api_service.dart
│   ├── websocket_service.dart
│   └── notification_service.dart
└── screens/
    ├── login_screen.dart
    ├── main_layout.dart
    ├── dashboard_screen.dart
    ├── tickets_screen.dart
    ├── equipment_screen.dart
    ├── backups_screen.dart
    ├── chat_screen.dart
    ├── users_screen.dart
    ├── admin_screen.dart         ← NUEVO: CRUD de categorías, áreas y tipos de equipo
    ├── reportes_screen.dart      ← NUEVO: gráficas y métricas
    └── dialogo_nuevo_equipo.dart

main_api.py                      ← backend FastAPI
```

---

## Comandos de desarrollo

```bash
flutter pub get          # instalar dependencias
flutter run -d chrome    # desarrollo en Chrome
flutter build web        # build de producción
flutter analyze          # análisis estático
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
| `POST` | `/login` | Autenticación |
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

---

## Roles

| Rol | Permisos |
|-----|----------|
| **Admin** | Todos los tickets, reasignación, inventario completo, reportes, administración de catálogos |
| **Técnico** | Sus tickets, actualización de estado y respaldos; tickets se auto-asignan al crearse |

---

*Proyecto interno — Beta Systems TI*
