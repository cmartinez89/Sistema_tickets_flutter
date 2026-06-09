# 🖥️ Soporte Beta — Sistema de Tickets TI

Sistema interno de gestión de soporte técnico, inventario de equipos y control de respaldos, desarrollado en **Flutter Web** y conectado a una API en **AWS EC2**.

---

## ✨ Funcionalidades

### 🎫 Tickets de Soporte
- Registro de reportes técnicos con prioridad (Alta / Media / Baja)
- Asignación de tickets a técnicos responsables
- Cambio de estatus: Pendiente → En Proceso → Resuelto
- **Cierre documentado**: al resolver un ticket se registra causa raíz, solución aplicada, pruebas realizadas y quién validó la resolución
- Filtros por estatus: Activos, Resueltos, Todos
- Vista diferenciada por rol (Admin ve todos; Técnico ve solo los suyos)

### 💻 Inventario y Responsivas
- Catálogo completo de equipos (laptops, desktops, servidores)
- Asignación de equipo a empleado con folio de carta responsiva
- Liberación de equipo al dar de baja a un colaborador
- Cálculo automático de depreciación (20% anual, mínimo 20% del valor original)
- Ficha técnica con especificaciones, accesorios y año de adquisición

### 📦 Control de Respaldos
- Tabla de seguimiento de respaldos por equipo
- Registro de ID Anydesk y RustDesk por equipo
- Alerta visual por color: amarillo (pendiente) y rojo (más de 15 días sin respaldo)
- Actualización de fecha de respaldo sincronizada con AWS

### 📊 Dashboard
- Gráficas de dona para tickets (Pendientes, En Proceso, Resueltos, Prioridad Alta)
- Métricas de inventario (Asignados, Disponibles, Valor total depreciado)
- Estado de respaldos (Al día vs Atrasados)
- Tabla de últimos tickets registrados (solo Admin)

### 🔔 Notificaciones Web
- Notificaciones nativas del navegador (Web Notifications API)
- Alertas al recibir un ticket nuevo asignado
- Alertas al cambiar el estatus de un ticket
- Alertas de equipos con más de 15 días sin respaldo
- Funciona en segundo plano mediante **Service Worker** (incluso con la app cerrada)
- Polling automático cada 60 segundos

---

## 🏗️ Arquitectura

```
Flutter Web (PWA)
      │
      ▼
  ApiService          ← capa de comunicación HTTP
      │
      ▼
 AWS EC2 (FastAPI)    ← backend REST
      │
      ▼
  Base de datos       ← almacenamiento persistente
```

```
lib/
├── main.dart                  ← UI completa + lógica de negocio
└── notification_service.dart  ← polling + Web Notifications API

web/
├── index.html                 ← registro del Service Worker
└── sw_custom.js               ← Service Worker para notificaciones en background
```

---

## 🚀 Instalación y ejecución

### Requisitos
- Flutter SDK `>=3.19.0`
- Dart `>=3.3.0`
- Chrome (para desarrollo web)

### Pasos

```bash
# 1. Clonar el repositorio
git clone https://github.com/cmartinez89/Sistema_tickets_flutter.git
cd Sistema_tickets_flutter

# 2. Instalar dependencias
flutter pub get

# 3. Correr en modo desarrollo
flutter run -d chrome

# 4. Compilar para producción
flutter build web
```

### Dependencias principales

| Paquete | Uso |
|--------|-----|
| `http` | Peticiones HTTP a la API |
| `web` | Web Notifications API y Service Worker |

---

## ⚙️ Configuración

La URL de la API se define en `lib/main.dart`:

```dart
const String kApiUrl = 'http://TU_IP_EC2:8000';
```

> ⚠️ Para producción se recomienda usar HTTPS con un dominio y certificado SSL.

---

## 👥 Roles de usuario

| Rol | Permisos |
|-----|----------|
| **Admin** | Ve todos los tickets, reasigna técnicos, gestiona inventario completo, accede al dashboard global |
| **Técnico** | Ve solo sus tickets asignados, actualiza estatus, registra respaldos |

---

## 📡 Endpoints requeridos en el backend

| Método | Ruta | Descripción |
|--------|------|-------------|
| `POST` | `/login` | Autenticación |
| `GET` | `/tickets` | Listar tickets |
| `POST` | `/tickets` | Crear ticket |
| `PUT` | `/tickets/:id/status` | Cambiar estatus |
| `PUT` | `/tickets/:id/assign` | Reasignar técnico |
| `PUT` | `/tickets/:id/resolve` | Cerrar ticket con documentación |
| `GET` | `/equipos` | Listar equipos |
| `PUT` | `/equipos/:id/assign` | Asignar equipo |
| `PUT` | `/equipos/:id/release` | Liberar equipo |
| `PUT` | `/equipos/:id/backup` | Actualizar fecha de respaldo |

---

## 🛠️ Desarrollado con

- [Flutter](https://flutter.dev/) — framework UI multiplataforma
- [FastAPI](https://fastapi.tiangolo.com/) — backend en Python
- [AWS EC2](https://aws.amazon.com/ec2/) — infraestructura en la nube

---

*Proyecto interno — Beta Systems TI*
