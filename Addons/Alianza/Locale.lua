-- Traducciones. El addon está escrito en español; si el juego no está en español se muestra en inglés.
local _, ns = ...
local loc = GetLocale()
local SPANISH = loc == "esES" or loc == "esMX"

local EN = {
    ["|cffff8c1a[Alianza]|r "] = "|cffff8c1a[Guild Alliance]|r ",
    ["Escribe un mensaje: |cffffffff/a hola a todos|r"] = "Type a message: |cffffffff/a hello everyone|r",
    ["No hay canal configurado. Usa |cffffffff/alianza canal <nombre> <clave>|r."] = "No channel set up. Use |cffffffff/alianza channel <name> <password>|r.",
    ["Uniéndote al canal... vuelve a pulsar Enter con tu mensaje si no aparece."] = "Joining the channel... press Enter again with your message if it doesn't show up.",
    ["Mensaje demasiado largo, se recortó."] = "Message too long, it was trimmed.",
    ["Comandos:"] = "Commands:",
    ["  |cffffffff/a <mensaje>|r - escribir en el chat de alianza"] = "  |cffffffff/a <message>|r - write in the alliance chat",
    ["  |cffffffff/alianza <mensaje>|r - igual que /a"] = "  |cffffffff/alianza <message>|r - same as /a",
    ["  |cffffffff/alianza canal <nombre> [clave]|r - crear/unirte al canal"] = "  |cffffffff/alianza channel <name> [password]|r - create/join the channel",
    ["  |cffffffff/alianza info|r - ver la línea /join para pasársela a los demás"] = "  |cffffffff/alianza info|r - show the /join line to share with others",
    ["  |cffffffff/alianza anunciar|r - enviar la línea /join al chat de tu hermandad"] = "  |cffffffff/alianza announce|r - send the /join line to your guild chat",
    ["  |cffffffff/alianza clave <nueva>|r - cambiar la clave (si eres dueño del canal)"] = "  |cffffffff/alianza password <new>|r - change the password (if you own the channel)",
    ["  |cffffffff/alianza expulsar <jugador>|r - expulsar a alguien del canal"] = "  |cffffffff/alianza kick <player>|r - kick someone from the channel",
    ["  |cffffffff/alianza quien|r - ver quién está en el canal"] = "  |cffffffff/alianza who|r - see who is in the channel",
    ["  |cffffffff/alianza etiquetas|r - activar/desactivar <Hermandad> en los mensajes"] = "  |cffffffff/alianza tags|r - turn <Guild> tags on messages on/off",
    ["  |cffffffff/alianza salir|r - salir del canal y borrar la configuración"] = "  |cffffffff/alianza leave|r - leave the channel and clear the settings",
    ["Primero configura el canal con |cffffffff/alianza canal <nombre> <clave>|r."] = "First set up the channel with |cffffffff/alianza channel <name> <password>|r.",
    ["Uso: |cffffffff/alianza canal <nombre> [clave]|r (el nombre sin espacios)"] = "Usage: |cffffffff/alianza channel <name> [password]|r (name without spaces)",
    ["El nombre del canal no puede empezar con un número."] = "The channel name can't start with a number.",
    ["Canal configurado. Los demás se unen con: |cffffffff"] = "Channel set up. Others join with: |cffffffff",
    ["Canal: |cffffffff"] = "Channel: |cffffffff",
    ["|cff00ff00conectado (canal "] = "|cff00ff00connected (channel ",
    ["|cffff0000no conectado|r"] = "|cffff0000not connected|r",
    ["Para unirse: |cffffffff"] = "To join: |cffffffff",
    ["Después escriben con |cffffffff/<número del canal>|r, por ejemplo /5 hola"] = "Then they talk with |cffffffff/<channel number>|r, for example /5 hello",
    ["No estás en una hermandad."] = "You are not in a guild.",
    ["Chat de alianza: escribe "] = "Alliance chat: type ",
    [" y luego habla con /<número del canal>"] = " and then talk with /<channel number>",
    ["Clave cambiada (solo funciona si eres el dueño del canal). Nueva línea: |cffffffff"] = "Password changed (only works if you own the channel). New line: |cffffffff",
    ["Uso: |cffffffff/alianza expulsar <jugador>|r"] = "Usage: |cffffffff/alianza kick <player>|r",
    ["Usa el comando del juego: |cffffffff/ckick "] = "Use the game command: |cffffffff/ckick ",
    ["Mira la lista en la ventana Social > pestaña Chat."] = "Check the list in the Social window > Chat tab.",
    ["Etiquetas de hermandad "] = "Guild tags ",
    ["activadas."] = "on.",
    ["desactivadas."] = "off.",
    ["Has salido del canal de alianza."] = "You left the alliance channel.",
    ["Ya estás en el canal. Envía tu mensaje de nuevo con |cffffffff/a|r."] = "You are in the channel now. Send your message again with |cffffffff/a|r.",
}

function ns.T(s)
    if SPANISH then return s end
    return EN[s] or s
end
