# Diseño: Agente Windows de inventario automático

Fecha: 2026-07-08

## Contexto

Se pidió un agente ligero para Windows que recolecte especificaciones de cada
equipo de la empresa (100+ equipos, sin dominio/AD) y las reporte
periódicamente. La solicitud original asumía un backend en Firebase/Firestore,
pero el sistema real no usa Firestore: el backend es una API FastAPI en un
EC2 con MySQL (`soporte_beta`), la misma que usa la app Flutter. Firebase solo
se usa para `firebase_messaging` (push notifications), no como base de datos.

Ya existe una tabla `equipos` con un módulo de **gestión de activos** (folio,
marca/modelo, valor de adquisición, empleado asignado, etc., capturado a
mano), que ya tiene columnas `mac_address` y `rustdesk` sin llenar
automáticamente. Se decidió, con el usuario, construir sobre esa misma tabla
en vez de crear un almacén de telemetría separado.

## Alcance de este proyecto

Incluye:
1. Agente Windows (`.exe`, Python + PyInstaller) que recolecta specs y se
   auto-instala.
2. Endpoint nuevo en la API existente (`POST /agentes/reportar`).
3. Migración de columnas nuevas en `equipos`.
4. Instalador integrado en el mismo `.exe` (bandera `--instalar`) que registra
   una tarea programada de Windows.

Fuera de alcance (proyecto futuro):
- Cambios en `equipment_screen.dart` (Flutter) para mostrar la telemetría
  nueva en la UI.
- Alertas basadas en esta telemetría (ej. poco espacio en disco).
- Despliegue centralizado vía GPO/RMM — hoy no hay dominio ni herramienta de
  este tipo; la instalación es manual equipo por equipo (vía RustDesk), como
  ya se hace hoy para todo lo demás.

## 1. Arquitectura

```
[Agente Windows .exe]  --HTTPS POST-->  [FastAPI en EC2]  -->  [MySQL: equipos]
   (Task Scheduler,                      POST /agentes/reportar
    cada 1 hora)                         (autenticado con token compartido)
```

Sin infraestructura nueva: mismo servidor, misma base de datos que ya usa
`soporte.beta.com.mx`.

## 2. Cambios en base de datos

Migración manual (`ALTER TABLE`) en el servidor, una sola vez, siguiendo el
mismo patrón ya usado para otras columnas de este proyecto.

Nuevas columnas en `equipos`:

| Columna | Tipo | Contenido |
|---|---|---|
| `agente_uuid` | VARCHAR(36) UNIQUE NULL | UUID generado y persistido localmente por el agente en cada equipo, para identificarlo sin depender del hostname (que puede repetirse) |
| `hostname` | VARCHAR(100) NULL | Nombre de red del equipo (informativo) |
| `so_nombre` | VARCHAR(100) NULL | Ej. "Windows 11 Pro" |
| `so_build` | VARCHAR(50) NULL | Build + UBR |
| `cpu_modelo` | VARCHAR(200) NULL | |
| `cpu_nucleos` | INT NULL | Núcleos físicos |
| `ram_total_gb` | DECIMAL(6,2) NULL | RAM física instalada. Simplificado desde "total e instalada" del pedido original a un solo valor: es lo que se puede leer de forma confiable con `psutil` |
| `discos_info` | JSON NULL | `[{"unidad": "C:", "totalGb": 476.9, "libreGb": 210.4}, ...]` — soporta N discos sin cambiar el esquema |
| `ip_local` | VARCHAR(45) NULL | |
| `uptime_segundos` | BIGINT NULL | |
| `usuario_actual` | VARCHAR(100) NULL | Usuario con sesión activa al momento del reporte, puede ser NULL si nadie tiene sesión iniciada |
| `ultimo_reporte_agente` | DATETIME NULL | |

Las columnas `mac_address` y `rustdesk`, que **ya existen** y hoy se llenan a
mano, pasan a llenarse automáticamente con lo que reporte el agente.

Nuevo valor de `estatus`: `"Pendiente de captura"` — usado únicamente para
equipos creados automáticamente por el agente que un admin todavía no ha
completado con datos de negocio (folio, valor de compra, asignación). No es
un enum a nivel de base de datos (la columna ya es `varchar` libre); si un
admin edita el equipo desde la pantalla de Inventario, el dropdown existente
no incluye este valor, así que una vez editado pasa a un estatus normal.

### Lógica de matching al recibir un reporte

Para no duplicar equipos en cada corrida periódica:

1. Si `agente_uuid` del payload ya existe en algún equipo → **actualiza** esa
   fila (telemetría + `mac_address` + `rustdesk`).
2. Si no, pero `mac_address` coincide con un equipo dado de alta a mano (sin
   `agente_uuid` todavía) → **vincula** (rellena `agente_uuid` en esa fila) y
   actualiza su telemetría. Así un equipo que el admin ya capturó
   manualmente no se duplica cuando se instala el agente en él.
3. Si no coincide nada → **crea** un equipo nuevo con estatus
   `"Pendiente de captura"`, campos de negocio en placeholder
   (`folio_responsiva='---'`, `valor_adquisicion=0`, `tipo='Por clasificar'`,
   `ano_adquisicion=<año actual>`), usando `marca`/`modelo`/`no_serie` del
   payload si vinieron (mejor esfuerzo vía BIOS/WMI), más toda la telemetría.

## 3. Endpoint

`POST /agentes/reportar` en `main_api.py`, junto a los demás endpoints de
`equipos`. No usa el `Depends(get_current_user)` existente (JWT de usuario
humano) — usa autenticación por token compartido (ver sección 4).

**Request body:**
```json
{
  "agenteUuid": "5f2b7c1a-....-uuid",
  "hostname": "PC-CONTA-03",
  "usuarioActual": "jperez",
  "soNombre": "Windows 11 Pro",
  "soBuild": "22631.3527",
  "cpuModelo": "Intel Core i5-10400",
  "cpuNucleos": 6,
  "ramTotalGb": 16.0,
  "discos": [{"unidad": "C:", "totalGb": 476.9, "libreGb": 210.4}],
  "ipLocal": "192.168.1.45",
  "macAddress": "AA:BB:CC:DD:EE:FF",
  "uptimeSegundos": 305420,
  "rustdeskId": "123456789",
  "noSerie": "ABCD1234",
  "marca": "Dell",
  "modelo": "Latitude 5420"
}
```
Solo `agenteUuid` y `hostname` son obligatorios; el resto es opcional
(cualquier dato que el agente no haya podido leer se manda como `null` en
vez de tumbar el reporte completo).

**Respuesta:**
```json
{"status": "ok", "equipoId": "142", "accion": "creado"}
```
`accion` es uno de `"creado"`, `"actualizado"`, `"vinculado"`.

**Errores:** `401` si el token no coincide o falta. `400` si falta
`agenteUuid` o `hostname`.

## 4. Seguridad

- **Autenticación:** header `X-Agent-Token: <token>`, comparado contra una
  variable nueva `AGENT_SHARED_TOKEN` en el `.env` del servidor —
  **separada** de `JWT_SECRET_KEY`. Comparación con `secrets.compare_digest`
  (evita timing attacks). Un solo token compartido entre todos los agentes
  (no uno por máquina), tal como se pidió.
- **Radio de daño si el token se filtra:** alguien podría mandar reportes
  falsos o pisar telemetría de equipos existentes. No puede leer tickets,
  usuarios, ni nada fuera de este endpoint — queda acotado a la tabla
  `equipos`. Mitigación si se filtra: rotar `AGENT_SHARED_TOKEN` y
  recompilar el agente.
- El token queda embebido como constante en el `.exe` — inevitable para un
  agente 100% desatendido sin aprovisionamiento por máquina. No es
  inextraíble (cualquier binario se puede analizar), pero no es trivial de
  encontrar copiando un archivo de config a simple vista.
- El endpoint corre sobre HTTPS (nginx ya lo tiene configurado), el token no
  viaja en claro.

## 5. Agente (Python + PyInstaller)

Un solo archivo `agente_soporte.exe`, dos modos de ejecución:

- **Sin argumentos** (lo que corre Task Scheduler cada hora): recolecta
  datos y reporta.
- **`--instalar`**: se auto-instala (ver sección 6).
- **`--dry-run`**: recolecta datos e imprime el JSON sin enviarlo, para
  probar en una máquina antes de desplegar.

Se compila **con consola** (no `--noconsole`). Cuando Task Scheduler lo
corre como SYSTEM, Windows lo aísla en Session 0 y no es visible para el
usuario sin importar si el exe tiene consola o no; mantenerla sirve para dar
feedback legible cuando alguien corre `--instalar` a mano desde PowerShell.

Corre como script de un solo disparo (no un loop residente) — Task
Scheduler lo invoca, hace su trabajo en segundos y termina.

### Recolección de datos

Cada dato envuelto en su propio `try/except` — un fallo puntual no tumba el
reporte completo, ese campo se manda como `null`.

| Dato | Método |
|---|---|
| Hostname | `socket.gethostname()` |
| Usuario actual | `psutil.users()` (más confiable que `os.getlogin()`, que falla sin sesión de consola — el agente corre como SYSTEM) |
| SO nombre/build | Registro `HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion` (`ProductName`, `CurrentBuildNumber` + `UBR`) — más confiable que `platform.win32_ver()`, que a veces reporta mal Windows 11 como Windows 10 |
| CPU modelo | Registro `HKLM\HARDWARE\DESCRIPTION\System\CentralProcessor\0\ProcessorNameString` |
| CPU núcleos | `psutil.cpu_count(logical=False)` |
| RAM total | `psutil.virtual_memory().total` |
| Discos | `psutil.disk_partitions()` + `psutil.disk_usage()` por unidad fija |
| IP local | Truco de socket UDP (conectar a `8.8.8.8:80` sin mandar datos reales) para identificar la interfaz de red activa |
| MAC address | Se busca en `psutil.net_if_addrs()` la interfaz cuya IP coincide con la IP local detectada, y se toma su dirección física — evita reportar la MAC de un adaptador virtual/inactivo |
| Uptime | `time.time() - psutil.boot_time()` |
| Marca/modelo/no. serie | Paquete `wmi` (BIOS/ComputerSystem), mejor esfuerzo |
| RustDesk ID | Ejecutar `rustdesk.exe --get-id` (flag de línea de comandos, estable entre versiones) y leer stdout. Fallback: leer `C:\ProgramData\RustDesk\config\RustDesk2.toml`. **Pendiente de verificar en un equipo real antes de la implementación final** — la ruta exacta del archivo de config varía entre versiones de RustDesk |
| UUID del agente | `C:\ProgramData\SoporteAgente\agent_id.txt`; si no existe, se genera con `uuid.uuid4()` y se persiste ahí (ProgramData, no AppData de usuario, porque corre como SYSTEM) |

Dependencias nuevas: `psutil`, `requests`, `wmi` (+ `pywin32` como
dependencia de `wmi`). Resto con librería estándar.

### Manejo de fallas de red — simplificado

Como cada reporte es una foto del estado actual (no un evento histórico), no
hace falta una cola creciente con reintentos y backoff exponencial:

1. Al inicio de cada corrida, si existe `C:\ProgramData\SoporteAgente\pending_report.json`
   de una corrida anterior fallida, se intenta reenviar primero.
2. Se arma y se intenta enviar el reporte actual (timeout de 10s).
3. Si falla, se sobreescribe `pending_report.json` con el payload actual
   (no se acumulan intentos viejos — el más reciente siempre reemplaza al
   anterior, porque es el que refleja el estado real del equipo).
4. Si tiene éxito, se borra `pending_report.json` si existía.

La periodicidad de Task Scheduler (cada hora) hace las veces de reintento:
si el equipo estuvo offline varios días, en cuanto vuelva a haber red se
manda el estado más reciente, no un historial de fallos.

### Logging

`logging.handlers.RotatingFileHandler` en
`C:\ProgramData\SoporteAgente\agente.log` (1MB × 3 archivos). Una línea por
corrida con resultado (éxito/error) y qué campos no se pudieron leer.

## 6. Instalador (integrado en el mismo .exe)

```
agente_soporte.exe --instalar   (una sola vez, elevado)
  1. Verifica que corre como Administrador (si no, avisa y sale con error)
  2. Se copia a C:\Program Files\SoporteAgente\agente_soporte.exe
  3. Registra tarea programada "SoporteAgenteReporte":
     - Ejecuta el exe copiado, cada 1 hora
     - Cuenta SYSTEM, privilegios mas altos (no requiere password ni sesion)
     - Sobreescribe la tarea si ya existia (permite reinstalar/actualizar)
  4. Corre un reporte inmediatamente (no espera a la primera hora)
```

Flujo real de instalación por equipo (sin dominio/AD, vía RustDesk, como se
hace hoy para todo):
1. Transferir `agente_soporte.exe` al equipo por RustDesk.
2. Abrir PowerShell como Administrador.
3. `.\agente_soporte.exe --instalar`
4. Listo — el equipo aparece/actualiza en Inventario de inmediato.

## 7. Plan de pruebas antes del despliegue a 100+ equipos

1. `agente_soporte.exe --dry-run` en una máquina de desarrollo — revisar que
   el JSON recolectado se vea correcto.
2. Probar el endpoint de forma aislada con `curl` antes de tocar el agente.
3. Instalar en **un solo equipo real** de la empresa, confirmar que el
   registro aparece/actualiza correctamente en `equipos` (vía consulta
   directa a MySQL o la pantalla de Inventario), antes de replicar al resto.

## Fuera de alcance

- UI de Flutter para mostrar la telemetría nueva.
- Alertas basadas en esta telemetría.
- Despliegue centralizado (GPO/RMM) — instalación manual por ahora.
- Invalidación/rotación automática del token compartido.
