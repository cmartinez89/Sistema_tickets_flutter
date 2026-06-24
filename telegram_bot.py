#!/usr/bin/env python3
"""Bot de Telegram — Soporte Beta Systems
Levanta tickets vía conversación inteligente con Claude.
"""

import json
import logging
import uuid
import requests
import pymysql
import anthropic
from datetime import datetime, timedelta
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application, CommandHandler, MessageHandler,
    ConversationHandler, CallbackQueryHandler,
    filters, ContextTypes,
)

import os
from dotenv import load_dotenv
load_dotenv('/home/ubuntu/api-soporte/.env')

TELEGRAM_TOKEN = os.environ['TELEGRAM_BOT_TOKEN']
ANTHROPIC_KEY  = os.environ['ANTHROPIC_API_KEY']
API_URL        = os.environ.get('API_URL', 'http://localhost:8000')
JWT_SECRET     = os.environ.get('JWT_SECRET_KEY', '')

DB = dict(
    host=os.environ.get('DB_HOST', 'localhost'),
    user=os.environ.get('DB_USER', 'admin_soporte'),
    password=os.environ['DB_PASSWORD'],
    database=os.environ.get('DB_NAME', 'soporte_beta'),
    charset='utf8mb4',
    cursorclass=pymysql.cursors.DictCursor,
)

REGISTRO      = 1
REGISTRO_AREA = 4
CONVERSACION  = 2
CONFIRMACION  = 3
SOLICITAR_AREA = 5

# Solicitudes de área pendientes de aprobación admin: {key: {area, user_chat_id, ticket_data, usuario}}
_pending_areas: dict = {}

logging.basicConfig(
    format='%(asctime)s %(levelname)s %(message)s',
    level=logging.INFO,
    handlers=[
        logging.FileHandler('/home/ubuntu/api-soporte/bot.log'),
        logging.StreamHandler(),
    ],
)
log = logging.getLogger(__name__)

# ─── Token JWT del bot ────────────────────────────────────────────────────────
def _bot_token() -> str:
    """Genera un JWT de larga duración para que el bot llame a la API."""
    import jwt as pyjwt
    return pyjwt.encode(
        {
            "username": "_bot_telegram",
            "rol": "Admin",
            "nombreCompleto": "Bot Telegram",
            "exp": datetime.now() + timedelta(days=365),
        },
        JWT_SECRET,
        algorithm="HS256",
    )

_BOT_JWT = _bot_token() if JWT_SECRET else ""
_API_HEADERS = {"Authorization": f"Bearer {_BOT_JWT}", "Content-Type": "application/json"}

# ─── Base de datos ────────────────────────────────────────────────────────────
def _db(): return pymysql.connect(**DB)

def usuario_por_telegram_id(tid: int):
    db = _db()
    try:
        with db.cursor() as c:
            c.execute(
                "SELECT username, nombre_completo, rol, area FROM usuarios WHERE telegram_id = %s",
                (tid,)
            )
            return c.fetchone()
    finally:
        db.close()

def usuario_por_username(username: str):
    db = _db()
    try:
        with db.cursor() as c:
            c.execute(
                "SELECT username, nombre_completo, rol, area FROM usuarios WHERE username = %s",
                (username.strip().lower(),)
            )
            return c.fetchone()
    finally:
        db.close()

def vincular_telegram(username: str, tid: int):
    db = _db()
    try:
        with db.cursor() as c:
            c.execute(
                "UPDATE usuarios SET telegram_id = %s WHERE username = %s",
                (tid, username)
            )
            db.commit()
    finally:
        db.close()

def guardar_area(username: str, area: str):
    db = _db()
    try:
        with db.cursor() as c:
            c.execute(
                "UPDATE usuarios SET area = %s WHERE username = %s",
                (area, username)
            )
            db.commit()
    finally:
        db.close()

def admins_telegram_ids() -> list:
    db = _db()
    try:
        with db.cursor() as c:
            c.execute(
                "SELECT telegram_id FROM usuarios WHERE rol = 'Admin' AND telegram_id IS NOT NULL"
            )
            return [r['telegram_id'] for r in c.fetchall()]
    finally:
        db.close()

def get_tecnicos() -> list:
    """Retorna lista de técnicos disponibles para asignar tickets."""
    db = _db()
    try:
        with db.cursor() as c:
            c.execute(
                "SELECT username, nombre_completo FROM usuarios WHERE rol IN ('Técnico', 'Admin') ORDER BY nombre_completo ASC"
            )
            return c.fetchall()
    finally:
        db.close()

def buscar_tecnico(nombre_o_username: str, tecnicos: list) -> dict | None:
    """Busca un técnico por nombre o username (tolerante a mayúsculas y parciales)."""
    if not nombre_o_username:
        return None
    q = nombre_o_username.strip().lower()
    # Coincidencia exacta primero
    for t in tecnicos:
        if t['username'].lower() == q or t['nombre_completo'].lower() == q:
            return t
    # Coincidencia parcial
    for t in tecnicos:
        if q in t['username'].lower() or q in t['nombre_completo'].lower():
            return t
    return None

# ─── Datos del sistema ────────────────────────────────────────────────────────
def _fetch_lista(ruta: str, campo: str, fallback: list) -> list:
    try:
        r = requests.get(f"{API_URL}{ruta}", headers=_API_HEADERS, timeout=5)
        if r.ok:
            return [item[campo] for item in r.json()]
    except Exception:
        pass
    return fallback

def get_areas():
    return _fetch_lista('/areas', 'nombre',
        ['Administración', 'Almacén', 'Gerencia', 'Operaciones',
         'Recursos Humanos', 'Sistemas', 'Ventas'])

def get_categorias():
    return _fetch_lista('/categorias', 'nombre',
        ['Hardware', 'Software', 'Red', 'Accesos',
         'Impresora', 'Correo electrónico', 'Otro'])

# ─── Claude ───────────────────────────────────────────────────────────────────
_ai = anthropic.Anthropic(api_key=ANTHROPIC_KEY)

SYSTEM = """\
Eres el asistente de soporte técnico de Beta Systems. Tu trabajo es recopilar la \
información necesaria para crear un ticket de soporte, de forma amable y natural.

Usuario: {nombre} — Área: {area_usuario}

Datos que DEBES obtener:
1. descripcion — qué problema o solicitud tiene el usuario (sé específico)
2. prioridad   — Alta / Media / Baja
   • Alta:  sistema caído, bloquea el trabajo completamente
   • Media: problema parcial, puede trabajar con limitaciones
   • Baja:  mejora, consulta o solicitud no urgente
3. area        — usa "{area_usuario}" si el usuario no indica otra; solo pregunta si es ambiguo
4. categoria   — tipo de problema
5. asignadoA   — username del técnico si el usuario menciona a quién asignarlo (ej: "asígnalo a julio"); \
si no lo menciona deja vacío (""), NO lo preguntes tú

Áreas disponibles:     {areas}
Categorías disponibles: {cats}
Técnicos disponibles:  {tecnicos}

Reglas:
- Máximo 2 oraciones por respuesta. No seas redundante.
- Si el usuario ya dio suficiente info, infiere los campos que puedas y solo pregunta lo que falta.
- Si el mensaje es claro ("la impresora no jala"), ya tienes el área del perfil — no la preguntes.
- Para asignadoA: si el usuario dice "asígnalo a julio" o "que lo vea juan", busca el username \
correspondiente en la lista de técnicos. Si no hay coincidencia, deja "".
- Si el usuario menciona explícitamente un área que NO está en la lista, úsala tal cual y agrega \
"area_nueva": true en el JSON. No la rechaces ni uses la más cercana.
- Cuando tengas descripcion, prioridad, area y categoria con certeza, responde ÚNICAMENTE con este \
JSON puro, sin markdown, sin backticks, sin texto antes ni después:
{{"listo":true,"descripcion":"...","prioridad":"Alta|Media|Baja","area":"...","categoria":"...","asignadoA":"username_o_vacio","area_nueva":false}}
"""

def claude(historial: list, areas: list, cats: list, tecnicos: list, usuario: dict = None) -> dict:
    """Retorna {'texto': str} o {'ticket': dict}"""
    import re
    nombre = usuario.get('nombre_completo', 'Usuario') if usuario else 'Usuario'
    area_u = usuario.get('area') or 'no especificada' if usuario else 'no especificada'
    tecnicos_str = ', '.join(f"{t['nombre_completo']} ({t['username']})" for t in tecnicos)
    system = SYSTEM.format(
        areas=", ".join(areas),
        cats=", ".join(cats),
        tecnicos=tecnicos_str,
        nombre=nombre,
        area_usuario=area_u,
    )
    resp = _ai.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=512,
        system=system,
        messages=historial,
    )
    raw = resp.content[0].text.strip()

    # Intentar parsear directo
    try:
        data = json.loads(raw)
        if data.get('listo'):
            return {'ticket': data}
    except Exception:
        pass

    # Extraer JSON aunque venga envuelto en ```json ... ``` o con texto alrededor
    match = re.search(r'\{.*?"listo"\s*:\s*true.*?\}', raw, re.DOTALL)
    if match:
        try:
            data = json.loads(match.group())
            if data.get('listo'):
                return {'ticket': data}
        except Exception:
            pass

    return {'texto': raw}

# ─── Crear ticket vía API ─────────────────────────────────────────────────────
def crear_ticket(usuario: dict, t: dict) -> str:
    payload = {
        "usuario":      usuario['username'],
        "departamento": t['area'],
        "descripcion":  t['descripcion'],
        "prioridad":    t['prioridad'],
        "estado":       "Pendiente",
        "asignadoA":    t.get('asignadoA', '') or '',
        "fecha":        datetime.now().isoformat(),
        "categoria":    t.get('categoria', 'Otro'),
        "area":         t['area'],
    }
    r = requests.post(f"{API_URL}/tickets", json=payload, headers=_API_HEADERS, timeout=10)
    r.raise_for_status()
    return r.json().get('id', 'TK-???')

# ─── Handlers ─────────────────────────────────────────────────────────────────
async def entrada(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    tid = update.effective_user.id
    usuario = usuario_por_telegram_id(tid)

    if usuario:
        ctx.user_data['usuario']   = usuario
        ctx.user_data['historial'] = []
        ctx.user_data['areas']     = get_areas()
        ctx.user_data['cats']      = get_categorias()
        ctx.user_data['tecnicos']  = get_tecnicos()

        if update.message.text and not update.message.text.startswith('/'):
            return await _procesar_mensaje(update, ctx)

        await update.message.reply_text(
            f"👋 Hola *{usuario['nombre_completo']}*\\! ¿En qué te puedo ayudar hoy?",
            parse_mode='MarkdownV2',
        )
        return CONVERSACION

    await update.message.reply_text(
        "👋 Hola\\! Soy el asistente de soporte de *Beta Systems*\\.\n\n"
        "Para continuar, escribe tu *usuario del sistema* \\(ej\\: `cmartinez`\\):",
        parse_mode='MarkdownV2',
    )
    return REGISTRO


async def registro(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    username = update.message.text.strip()
    usuario  = usuario_por_username(username)

    if not usuario:
        await update.message.reply_text(
            f"❌ No encontré el usuario `{_esc(username)}` en el sistema\\.\n"
            "Verifica que sea correcto o pide al administrador que te registre\\.\n\n"
            "Intenta de nuevo:",
            parse_mode='MarkdownV2',
        )
        return REGISTRO

    tid = update.effective_user.id
    vincular_telegram(usuario['username'], tid)
    ctx.user_data['usuario']  = usuario
    ctx.user_data['tecnicos'] = get_tecnicos()

    if usuario.get('area'):
        ctx.user_data['historial'] = []
        ctx.user_data['areas']     = get_areas()
        ctx.user_data['cats']      = get_categorias()
        await update.message.reply_text(
            f"✅ ¡Verificado\\! Hola *{_esc(usuario['nombre_completo'])}*\\.\n"
            "Tu Telegram queda vinculado, la próxima vez te reconoceré automáticamente\\.\n\n"
            "Cuéntame, ¿en qué te puedo ayudar?",
            parse_mode='MarkdownV2',
        )
        return CONVERSACION

    areas = get_areas()
    ctx.user_data['areas'] = areas
    lista = '\n'.join(f"• {a}" for a in areas)
    await update.message.reply_text(
        f"✅ ¡Verificado\\! Hola *{_esc(usuario['nombre_completo'])}*\\.\n\n"
        f"Una última cosa: ¿en qué área trabajas?\n\n{_esc(lista)}",
        parse_mode='MarkdownV2',
    )
    return REGISTRO_AREA


async def registro_area(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    texto = update.message.text.strip()
    areas = ctx.user_data.get('areas', get_areas())

    area_encontrada = next(
        (a for a in areas if texto.lower() in a.lower() or a.lower() in texto.lower()),
        None
    )

    if not area_encontrada:
        lista = '\n'.join(f"• {a}" for a in areas)
        await update.message.reply_text(
            f"No reconozco esa área\\. Por favor elige una de las siguientes:\n\n{_esc(lista)}",
            parse_mode='MarkdownV2',
        )
        return REGISTRO_AREA

    usuario = ctx.user_data['usuario']
    guardar_area(usuario['username'], area_encontrada)
    usuario['area'] = area_encontrada
    ctx.user_data['usuario']   = usuario
    ctx.user_data['historial'] = []
    ctx.user_data['cats']      = get_categorias()

    await update.message.reply_text(
        f"Perfecto\\! Área *{_esc(area_encontrada)}* guardada\\.\n\n"
        "Cuéntame, ¿en qué te puedo ayudar?",
        parse_mode='MarkdownV2',
    )
    return CONVERSACION


async def conversacion(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    return await _procesar_mensaje(update, ctx)


async def _procesar_mensaje(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    texto    = update.message.text
    historial: list = ctx.user_data.setdefault('historial', [])
    areas    = ctx.user_data.get('areas',    get_areas())
    cats     = ctx.user_data.get('cats',     get_categorias())
    tecnicos = ctx.user_data.get('tecnicos', get_tecnicos())

    historial.append({'role': 'user', 'content': texto})
    await ctx.bot.send_chat_action(update.effective_chat.id, 'typing')

    resultado = claude(historial, areas, cats, tecnicos, usuario=ctx.user_data.get('usuario'))

    if 'ticket' in resultado:
        t = resultado['ticket']
        areas = ctx.user_data.get('areas', get_areas())

        # Detectar si el área solicitada no existe en el catálogo
        area_es_nueva = t.get('area_nueva', False) or (t.get('area') and t['area'] not in areas)
        if area_es_nueva:
            ctx.user_data['ticket_pendiente'] = t
            teclado = InlineKeyboardMarkup([[
                InlineKeyboardButton("✅ Sí, solicitar", callback_data="sol_area_si"),
                InlineKeyboardButton("❌ No, elegir existente", callback_data="sol_area_no"),
            ]])
            await update.message.reply_text(
                f"El área *{_esc(t['area'])}* no existe en el sistema\\.\n"
                "¿Quieres que le solicite al administrador que la agregue?",
                parse_mode='MarkdownV2',
                reply_markup=teclado,
            )
            return SOLICITAR_AREA

        # Resolver nombre del técnico asignado para mostrarlo bonito
        asignado_username = (t.get('asignadoA') or '').strip()
        asignado_display  = ''
        if asignado_username:
            tec = buscar_tecnico(asignado_username, tecnicos)
            if tec:
                t['asignadoA']   = tec['username']
                asignado_display = tec['nombre_completo']
            else:
                t['asignadoA']   = ''
                asignado_display = ''

        ctx.user_data['ticket_pendiente'] = t

        linea_asignado = f"\n👷 Asignado a: *{_esc(asignado_display)}*" if asignado_display else ''
        resumen = (
            f"📋 *Resumen del ticket:*\n\n"
            f"📝 {_esc(t['descripcion'])}\n"
            f"🚨 Prioridad: *{_esc(t['prioridad'])}*\n"
            f"🏢 Área: {_esc(t['area'])}\n"
            f"🏷️ Categoría: {_esc(t.get('categoria','Otro'))}"
            f"{linea_asignado}\n\n"
            "¿Confirmas la creación?"
        )
        teclado = InlineKeyboardMarkup([[
            InlineKeyboardButton("✅ Confirmar", callback_data="si"),
            InlineKeyboardButton("✏️ Corregir",  callback_data="no"),
        ]])
        await update.message.reply_text(resumen, parse_mode='MarkdownV2', reply_markup=teclado)
        return CONFIRMACION

    respuesta = resultado['texto']
    historial.append({'role': 'assistant', 'content': respuesta})
    ctx.user_data['historial'] = historial
    await update.message.reply_text(respuesta)
    return CONVERSACION


async def confirmacion(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    query = update.callback_query
    await query.answer()

    if query.data == "no":
        ctx.user_data['historial'] = []
        ctx.user_data['ticket_pendiente'] = None
        await query.edit_message_text(
            "De acuerdo, cuéntame de nuevo con los cambios que necesitas:"
        )
        return CONVERSACION

    usuario = ctx.user_data['usuario']
    t       = ctx.user_data['ticket_pendiente']
    tecnicos = ctx.user_data.get('tecnicos', [])

    try:
        ticket_id = crear_ticket(usuario, t)
    except Exception as e:
        log.error(f"Error creando ticket: {e}")
        await query.edit_message_text(
            "❌ Ocurrió un error al crear el ticket\\. Intenta en unos minutos o contacta al administrador\\.",
            parse_mode='MarkdownV2',
        )
        ctx.user_data.clear()
        return ConversationHandler.END

    asignado_username = (t.get('asignadoA') or '').strip()
    asignado_display  = ''
    if asignado_username:
        tec = buscar_tecnico(asignado_username, tecnicos)
        asignado_display = tec['nombre_completo'] if tec else asignado_username

    linea_asignado = f"\n👷 Asignado a: *{_esc(asignado_display)}*" if asignado_display else '\n👷 Sin asignar'

    await query.edit_message_text(
        f"✅ *Ticket creado exitosamente*\n\n"
        f"🎫 ID: *{_esc(ticket_id)}*\n"
        f"📝 {_esc(t['descripcion'])}\n"
        f"🚨 Prioridad: {_esc(t['prioridad'])}"
        f"{linea_asignado}\n\n"
        "El equipo de TI atenderá tu solicitud\\. ¡Gracias\\!",
        parse_mode='MarkdownV2',
    )

    # Notificar admins
    linea_asignado_admin = f"\n👷 Asignado a: *{_esc(asignado_display)}*" if asignado_display else ''
    msg_admin = (
        f"🎫 *Nuevo ticket vía Telegram*\n\n"
        f"👤 {_esc(usuario['nombre_completo'])} \\(@{_esc(usuario['username'])}\\)\n"
        f"📋 {_esc(t['descripcion'])}\n"
        f"🚨 Prioridad: *{_esc(t['prioridad'])}*\n"
        f"🏢 Área: {_esc(t['area'])}\n"
        f"🏷️ Categoría: {_esc(t.get('categoria','Otro'))}"
        f"{linea_asignado_admin}\n"
        f"🆔 ID: *{_esc(ticket_id)}*"
    )
    for admin_id in admins_telegram_ids():
        try:
            await ctx.bot.send_message(admin_id, msg_admin, parse_mode='MarkdownV2')
        except Exception as e:
            log.warning(f"No se pudo notificar al admin {admin_id}: {e}")

    ctx.user_data.clear()
    return ConversationHandler.END


async def cancelar(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    ctx.user_data.clear()
    await update.message.reply_text(
        "Cancelado\\. Escribe /start cuando quieras levantar un ticket\\.",
        parse_mode='MarkdownV2',
    )
    return ConversationHandler.END


async def solicitud_area_callback(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    """El usuario decide si solicita o no la creación del área nueva."""
    query = update.callback_query
    await query.answer()

    if query.data == "sol_area_no":
        areas = ctx.user_data.get('areas', get_areas())
        lista = '\n'.join(f"• {a}" for a in areas)
        ctx.user_data['ticket_pendiente'] = None
        await query.edit_message_text(
            f"De acuerdo\\. Elige una de las áreas disponibles:\n\n{_esc(lista)}\n\n"
            "Cuéntame de nuevo con el área correcta:",
            parse_mode='MarkdownV2',
        )
        return CONVERSACION

    # sol_area_si — enviar solicitud al admin
    t       = ctx.user_data.get('ticket_pendiente', {})
    usuario = ctx.user_data.get('usuario', {})
    area    = t.get('area', '')
    key     = uuid.uuid4().hex[:8]

    _pending_areas[key] = {
        'area':         area,
        'user_chat_id': update.effective_chat.id,
        'ticket_data':  t,
        'usuario':      usuario,
    }

    teclado_admin = InlineKeyboardMarkup([[
        InlineKeyboardButton("✅ Crear área", callback_data=f"aprobar_area:{key}"),
        InlineKeyboardButton("❌ Rechazar",   callback_data=f"rechazar_area:{key}"),
    ]])
    msg_admin = (
        f"📋 *Solicitud de nueva área*\n\n"
        f"👤 {_esc(usuario.get('nombre_completo',''))} solicita crear:\n"
        f"📂 *{_esc(area)}*\n\n"
        f"Para el ticket:\n_{_esc(t.get('descripcion',''))}_"
    )
    for admin_id in admins_telegram_ids():
        try:
            await ctx.bot.send_message(
                admin_id, msg_admin,
                parse_mode='MarkdownV2',
                reply_markup=teclado_admin,
            )
        except Exception as e:
            log.warning(f"No se pudo notificar admin {admin_id}: {e}")

    await query.edit_message_text(
        "✅ Solicitud enviada al administrador\\.\n"
        "Te notificaré cuando decida\\. ¡Gracias por tu paciencia\\!",
        parse_mode='MarkdownV2',
    )
    ctx.user_data.clear()
    return ConversationHandler.END


async def admin_area_callback(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    """El admin aprueba o rechaza la creación de un área nueva."""
    query = update.callback_query
    await query.answer()

    if ':' not in query.data:
        return
    action, key = query.data.split(':', 1)
    pending = _pending_areas.get(key)

    if not pending:
        await query.edit_message_text("⚠️ Esta solicitud ya fue procesada o expiró\\.", parse_mode='MarkdownV2')
        return

    area          = pending['area']
    user_chat_id  = pending['user_chat_id']

    if action == 'aprobar_area':
        r = requests.post(f"{API_URL}/areas", json={"nombre": area}, headers=_API_HEADERS, timeout=5)
        if not r.ok:
            await query.edit_message_text(f"❌ Error al crear el área: {_esc(r.text)}", parse_mode='MarkdownV2')
            return
        try:
            ticket_id = crear_ticket(pending['usuario'], pending['ticket_data'])
        except Exception as e:
            log.error(f"Error creando ticket tras aprobar área: {e}")
            await query.edit_message_text(
                f"✅ Área *{_esc(area)}* creada, pero error al generar ticket\\.",
                parse_mode='MarkdownV2',
            )
            await ctx.bot.send_message(
                user_chat_id,
                f"✅ Área *{_esc(area)}* aprobada, pero hubo un error al crear el ticket\\.\n"
                "Escribe /start para intentarlo de nuevo\\.",
                parse_mode='MarkdownV2',
            )
            del _pending_areas[key]
            return

        await query.edit_message_text(
            f"✅ Área *{_esc(area)}* creada\\. Ticket *{_esc(ticket_id)}* generado\\.",
            parse_mode='MarkdownV2',
        )
        await ctx.bot.send_message(
            user_chat_id,
            f"✅ *El administrador aprobó el área {_esc(area)}*\\.\n\n"
            f"🎫 Ticket *{_esc(ticket_id)}* creado exitosamente\\. ¡El equipo de TI lo atenderá pronto\\!",
            parse_mode='MarkdownV2',
        )

    else:  # rechazar_area
        areas_list = get_areas()
        lista = ', '.join(areas_list)
        await query.edit_message_text(
            f"❌ Área *{_esc(area)}* rechazada\\.",
            parse_mode='MarkdownV2',
        )
        await ctx.bot.send_message(
            user_chat_id,
            f"❌ El administrador no aprobó el área *{_esc(area)}*\\.\n\n"
            f"Áreas disponibles: {_esc(lista)}\n\n"
            "Escribe /start para intentar con otra área\\.",
            parse_mode='MarkdownV2',
        )

    del _pending_areas[key]


def _esc(text: str) -> str:
    if not text:
        return ''
    for ch in r'_*[]()~`>#+-=|{}.!':
        text = text.replace(ch, f'\\{ch}')
    return text


# ─── Main ─────────────────────────────────────────────────────────────────────
def main():
    app = Application.builder().token(TELEGRAM_TOKEN).build()

    conv = ConversationHandler(
        entry_points=[
            CommandHandler('start', entrada),
            MessageHandler(filters.TEXT & ~filters.COMMAND, entrada),
        ],
        states={
            REGISTRO:       [MessageHandler(filters.TEXT & ~filters.COMMAND, registro)],
            REGISTRO_AREA:  [MessageHandler(filters.TEXT & ~filters.COMMAND, registro_area)],
            CONVERSACION:   [MessageHandler(filters.TEXT & ~filters.COMMAND, conversacion)],
            CONFIRMACION:   [CallbackQueryHandler(confirmacion)],
            SOLICITAR_AREA: [CallbackQueryHandler(solicitud_area_callback)],
        },
        fallbacks=[CommandHandler('cancelar', cancelar)],
        per_message=False,
    )

    # Handler global para que el admin apruebe/rechace nuevas áreas
    app.add_handler(CallbackQueryHandler(
        admin_area_callback, pattern=r'^(aprobar|rechazar)_area:'
    ))
    app.add_handler(conv)
    log.info("Bot iniciado — @Soporte_BSM_bot")
    app.run_polling(drop_pending_updates=True)


if __name__ == '__main__':
    main()
