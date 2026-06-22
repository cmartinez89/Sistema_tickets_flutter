#!/usr/bin/env python3
"""Bot de Telegram — Soporte Beta Systems
Levanta tickets vía conversación inteligente con Claude.
"""

import json
import logging
import requests
import pymysql
import anthropic
from datetime import datetime
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application, CommandHandler, MessageHandler,
    ConversationHandler, CallbackQueryHandler,
    filters, ContextTypes,
)

# ─── Configuración ────────────────────────────────────────────────────────────
import os
from dotenv import load_dotenv
load_dotenv('/home/ubuntu/api-soporte/.env')

TELEGRAM_TOKEN = os.environ['TELEGRAM_BOT_TOKEN']
ANTHROPIC_KEY  = os.environ['ANTHROPIC_API_KEY']
API_URL        = os.environ.get('API_URL', 'http://localhost:8000')

DB = dict(
    host=os.environ.get('DB_HOST', 'localhost'),
    user=os.environ.get('DB_USER', 'admin_soporte'),
    password=os.environ['DB_PASSWORD'],
    database=os.environ.get('DB_NAME', 'soporte_beta'),
    charset='utf8mb4',
    cursorclass=pymysql.cursors.DictCursor,
)

REGISTRO     = 1
REGISTRO_AREA = 4
CONVERSACION = 2
CONFIRMACION = 3

logging.basicConfig(
    format='%(asctime)s %(levelname)s %(message)s',
    level=logging.INFO,
    handlers=[
        logging.FileHandler('/home/ubuntu/api-soporte/bot.log'),
        logging.StreamHandler(),
    ],
)
log = logging.getLogger(__name__)

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

# ─── Datos del sistema ────────────────────────────────────────────────────────
def _fetch_lista(ruta: str, campo: str, fallback: list) -> list:
    try:
        r = requests.get(f"{API_URL}{ruta}", timeout=5)
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

Áreas disponibles:     {areas}
Categorías disponibles: {cats}

Reglas:
- Máximo 2 oraciones por respuesta. No seas redundante.
- Si el usuario ya dio suficiente info, infiere los campos que puedas y solo pregunta lo que falta.
- Si el mensaje es claro ("la impresora no jala"), ya tienes el área del perfil — no la preguntes.
- Cuando tengas los 4 campos con certeza, responde ÚNICAMENTE con este JSON puro, sin markdown, \
sin backticks, sin texto antes ni después:
{{"listo":true,"descripcion":"...","prioridad":"Alta|Media|Baja","area":"...","categoria":"..."}}
"""

def claude(historial: list, areas: list, cats: list, usuario: dict = None) -> dict:
    """Retorna {'texto': str} o {'ticket': dict}"""
    import re
    nombre = usuario.get('nombre_completo', 'Usuario') if usuario else 'Usuario'
    area_u = usuario.get('area') or 'no especificada' if usuario else 'no especificada'
    system = SYSTEM.format(areas=", ".join(areas), cats=", ".join(cats),
                           nombre=nombre, area_usuario=area_u)
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
        "usuario":    usuario['username'],
        "departamento": t['area'],
        "descripcion": t['descripcion'],
        "prioridad":  t['prioridad'],
        "estado":     "Pendiente",
        "asignadoA":  "",
        "fecha":      datetime.now().isoformat(),
        "categoria":  t.get('categoria', 'Otro'),
        "area":       t['area'],
    }
    r = requests.post(f"{API_URL}/tickets", json=payload, timeout=10)
    r.raise_for_status()
    return r.json().get('id', 'TK-???')

# ─── Handlers ─────────────────────────────────────────────────────────────────
async def entrada(update: Update, ctx: ContextTypes.DEFAULT_TYPE):
    """Punto de entrada — cualquier mensaje o /start"""
    tid = update.effective_user.id
    usuario = usuario_por_telegram_id(tid)

    if usuario:
        # Usuario ya registrado → iniciar conversación directamente
        ctx.user_data['usuario']  = usuario
        ctx.user_data['historial'] = []
        ctx.user_data['areas']    = get_areas()
        ctx.user_data['cats']     = get_categorias()

        # Si llegó con un mensaje de texto (no solo /start), procesarlo ya
        if update.message.text and not update.message.text.startswith('/'):
            return await _procesar_mensaje(update, ctx)

        await update.message.reply_text(
            f"👋 Hola *{usuario['nombre_completo']}*\\! ¿En qué te puedo ayudar hoy?",
            parse_mode='MarkdownV2',
        )
        return CONVERSACION

    # No registrado → pedir username
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
    ctx.user_data['usuario'] = usuario

    # Si ya tiene área guardada, pasar directo a conversación
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

    # Sin área → pedirla
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

    # Buscar área más parecida (case-insensitive, coincidencia parcial)
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
    areas    = ctx.user_data.get('areas', get_areas())
    cats     = ctx.user_data.get('cats',  get_categorias())

    historial.append({'role': 'user', 'content': texto})
    await ctx.bot.send_chat_action(update.effective_chat.id, 'typing')

    resultado = claude(historial, areas, cats, usuario=ctx.user_data.get('usuario'))

    if 'ticket' in resultado:
        t = resultado['ticket']
        ctx.user_data['ticket_pendiente'] = t
        resumen = (
            f"📋 *Resumen del ticket:*\n\n"
            f"📝 {_esc(t['descripcion'])}\n"
            f"🚨 Prioridad: *{_esc(t['prioridad'])}*\n"
            f"🏢 Área: {_esc(t['area'])}\n"
            f"🏷️ Categoría: {_esc(t.get('categoria','Otro'))}\n\n"
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

    await query.edit_message_text(
        f"✅ *Ticket creado exitosamente*\n\n"
        f"🎫 ID: *{_esc(ticket_id)}*\n"
        f"📝 {_esc(t['descripcion'])}\n"
        f"🚨 Prioridad: {_esc(t['prioridad'])}\n\n"
        "El equipo de TI atenderá tu solicitud\\. ¡Gracias\\!",
        parse_mode='MarkdownV2',
    )

    # Notificar admins
    msg_admin = (
        f"🎫 *Nuevo ticket vía Telegram*\n\n"
        f"👤 {_esc(usuario['nombre_completo'])} \\(@{_esc(usuario['username'])}\\)\n"
        f"📋 {_esc(t['descripcion'])}\n"
        f"🚨 Prioridad: *{_esc(t['prioridad'])}*\n"
        f"🏢 Área: {_esc(t['area'])}\n"
        f"🏷️ Categoría: {_esc(t.get('categoria','Otro'))}\n"
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


def _esc(text: str) -> str:
    """Escapa caracteres especiales para MarkdownV2"""
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
            REGISTRO:      [MessageHandler(filters.TEXT & ~filters.COMMAND, registro)],
            REGISTRO_AREA: [MessageHandler(filters.TEXT & ~filters.COMMAND, registro_area)],
            CONVERSACION:  [MessageHandler(filters.TEXT & ~filters.COMMAND, conversacion)],
            CONFIRMACION:  [CallbackQueryHandler(confirmacion)],
        },
        fallbacks=[CommandHandler('cancelar', cancelar)],
        per_message=False,
    )

    app.add_handler(conv)
    log.info("Bot iniciado — @Soporte_BSM_bot")
    app.run_polling(drop_pending_updates=True)


if __name__ == '__main__':
    main()
