// sw_custom.js
// Coloca este archivo en: web/sw_custom.js
// ============================================================================
// SERVICE WORKER PERSONALIZADO — Soporte Beta
// Permite recibir notificaciones incluso con la app cerrada.
// Funciona junto al flutter_service_worker.js generado por Flutter.
// ============================================================================

const SW_VERSION = 'soporte-beta-v1';
const API_URL = 'http://54.161.41.131:8000';
const POLL_INTERVAL_MS = 60 * 1000; // 1 minuto

// --------------------------------------------------------------------------
// INSTALACIÓN Y ACTIVACIÓN
// --------------------------------------------------------------------------
self.addEventListener('install', (event) => {
  console.log(`[SW] ${SW_VERSION} instalado`);
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  console.log(`[SW] ${SW_VERSION} activado`);
  event.waitUntil(self.clients.claim());
});

// --------------------------------------------------------------------------
// ESTADO DEL SERVICE WORKER
// Persiste entre ciclos de polling usando variables en el scope del SW.
// --------------------------------------------------------------------------
let swState = {
  username: null,
  rol: null,
  token: null,
  ticketsConocidos: new Set(),
  estatusConocidos: {},
  respaldosAlertados: new Set(),
  inicializado: false,
  pollTimer: null,
};

// --------------------------------------------------------------------------
// COMUNICACIÓN CON LA APP (postMessage)
// La app Flutter envía sesión y comandos al SW via MessageChannel.
// --------------------------------------------------------------------------
self.addEventListener('message', (event) => {
  const { type, payload } = event.data || {};

  switch (type) {
    case 'INIT_SESSION':
      // La app acaba de hacer login — guarda sesión e inicia polling
      swState.username = payload.username;
      swState.rol = payload.rol;
      swState.token = payload.token || '';
      swState.ticketsConocidos = new Set();
      swState.estatusConocidos = {};
      swState.respaldosAlertados = new Set();
      swState.inicializado = false;

      console.log(`[SW] Sesión recibida: ${swState.username} (${swState.rol})`);
      cargarEstadoBase().then(() => {
        swState.inicializado = true;
        iniciarPolling();
      });
      break;

    case 'STOP_SESSION':
      // Logout — detiene polling y limpia estado
      detenerPolling();
      swState.username = null;
      swState.token = null;
      swState.inicializado = false;
      console.log('[SW] Sesión cerrada, polling detenido.');
      break;

    case 'PING':
      // La app verifica que el SW responde
      event.source?.postMessage({ type: 'PONG', version: SW_VERSION });
      break;
  }
});

// --------------------------------------------------------------------------
// POLLING
// --------------------------------------------------------------------------
function iniciarPolling() {
  detenerPolling(); // Cancela cualquier timer previo
  swState.pollTimer = setInterval(verificarCambios, POLL_INTERVAL_MS);
  console.log(`[SW] Polling iniciado cada ${POLL_INTERVAL_MS / 1000}s`);
}

function detenerPolling() {
  if (swState.pollTimer) {
    clearInterval(swState.pollTimer);
    swState.pollTimer = null;
  }
}

// --------------------------------------------------------------------------
// CABECERAS HTTP
// --------------------------------------------------------------------------
function getHeaders() {
  const headers = { 'Content-Type': 'application/json' };
  if (swState.token) {
    headers['Authorization'] = `Bearer ${swState.token}`;
  }
  return headers;
}

// --------------------------------------------------------------------------
// CARGA DE ESTADO BASE (sin notificar)
// --------------------------------------------------------------------------
async function cargarEstadoBase() {
  try {
    const res = await fetch(`${API_URL}/tickets`, { headers: getHeaders() });
    if (!res.ok) return;
    const tickets = await res.json();
    for (const t of tickets) {
      swState.ticketsConocidos.add(t.id);
      swState.estatusConocidos[t.id] = t.estado;
    }
    console.log(`[SW] Estado base cargado: ${swState.ticketsConocidos.size} tickets`);
  } catch (e) {
    console.warn('[SW] Error cargando estado base:', e);
  }
}

// --------------------------------------------------------------------------
// VERIFICACIÓN DE CAMBIOS
// --------------------------------------------------------------------------
async function verificarCambios() {
  if (!swState.inicializado || !swState.username) return;
  console.log('[SW] Verificando cambios...');
  await verificarTickets();
  await verificarRespaldos();
}

async function verificarTickets() {
  try {
    const res = await fetch(`${API_URL}/tickets`, { headers: getHeaders() });
    if (!res.ok) return;
    const tickets = await res.json();

    for (const t of tickets) {
      const esMio = (t.asignadoA || '').toLowerCase() === swState.username.toLowerCase();
      const esAdmin = swState.rol === 'Admin';

      // Ticket nuevo
      if (!swState.ticketsConocidos.has(t.id)) {
        swState.ticketsConocidos.add(t.id);
        swState.estatusConocidos[t.id] = t.estado;

        if (esMio || esAdmin) {
          await mostrarNotificacion({
            titulo: esAdmin ? '📋 Nuevo ticket registrado' : '📋 Nuevo ticket asignado a ti',
            cuerpo: `${t.id} — ${t.descripcion}\nUsuario: ${t.usuario}`,
            tag: `ticket-nuevo-${t.id}`,
            data: { tipo: 'ticket', id: t.id },
          });
        }
        continue;
      }

      // Cambio de estatus
      const estadoAnterior = swState.estatusConocidos[t.id];
      if (estadoAnterior && estadoAnterior !== t.estado && (esMio || esAdmin)) {
        await mostrarNotificacion({
          titulo: '🔄 Ticket actualizado',
          cuerpo: `${t.id}: ${t.descripcion}\n${estadoAnterior} → ${t.estado}`,
          tag: `ticket-status-${t.id}`,
          data: { tipo: 'ticket', id: t.id },
        });
      }
      swState.estatusConocidos[t.id] = t.estado;
    }
  } catch (e) {
    console.warn('[SW] Error verificando tickets:', e);
  }
}

async function verificarRespaldos() {
  try {
    const res = await fetch(`${API_URL}/equipos`, { headers: getHeaders() });
    if (!res.ok) return;
    const equipos = await res.json();

    const criticos = [];
    for (const eq of equipos) {
      if (!eq.ultimoRespaldo) {
        criticos.push(`${eq.modelo} — Sin respaldo registrado`);
        continue;
      }
      const fecha = new Date(eq.ultimoRespaldo);
      const dias = Math.floor((Date.now() - fecha.getTime()) / (1000 * 60 * 60 * 24));
      if (dias >= 15) {
        criticos.push(`${eq.modelo} (${eq.empleadoAsignado || 'Sistemas'}) — ${dias} días`);
      }
    }

    if (criticos.length > 0) {
      // Solo notifica si la lista cambió
      const key = criticos.join('|');
      if (!swState.respaldosAlertados.has(key)) {
        swState.respaldosAlertados.clear();
        swState.respaldosAlertados.add(key);
        await mostrarNotificacion({
          titulo: `⚠️ ${criticos.length} equipo(s) sin respaldo reciente`,
          cuerpo: criticos.slice(0, 3).join('\n') + (criticos.length > 3 ? '\n...y más' : ''),
          tag: 'respaldos-alerta',
          data: { tipo: 'respaldo' },
        });
      }
    }
  } catch (e) {
    console.warn('[SW] Error verificando respaldos:', e);
  }
}

// --------------------------------------------------------------------------
// MOSTRAR NOTIFICACIÓN
// --------------------------------------------------------------------------
async function mostrarNotificacion({ titulo, cuerpo, tag, data = {} }) {
  try {
    await self.registration.showNotification(titulo, {
      body: cuerpo,
      tag: tag,
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      requireInteraction: false,
      data: data,
    });
    console.log(`[SW] Notificación enviada: ${titulo}`);
  } catch (e) {
    console.warn('[SW] Error mostrando notificación:', e);
  }
}

// --------------------------------------------------------------------------
// CLICK EN NOTIFICACIÓN → Abre o enfoca la app
// --------------------------------------------------------------------------
self.addEventListener('notificationclick', (event) => {
  event.notification.close();

  event.waitUntil(
    self.clients.matchAll({ type: 'window', includeUncontrolled: true })
      .then((clientList) => {
        // Si la app ya está abierta, la enfoca
        for (const client of clientList) {
          if ('focus' in client) {
            client.focus();
            // Envía mensaje a la app para navegar a la sección correcta
            client.postMessage({
              type: 'NOTIFICATION_CLICK',
              data: event.notification.data,
            });
            return;
          }
        }
        // Si no está abierta, la abre
        if (self.clients.openWindow) {
          return self.clients.openWindow('/');
        }
      })
  );
});
