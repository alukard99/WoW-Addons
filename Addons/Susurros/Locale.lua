-- Traducciones. El addon está escrito en español; si el juego no está en español se muestra en inglés.
local _, ns = ...
local loc = GetLocale()
local SPANISH = loc == "esES" or loc == "esMX"

local EN = {
    ["Susurros"] = "Whisper Chats",
    ["Jugadores"] = "Players",
    ["Aún no hay conversaciones.\n\nEscribe /ws Nombre para empezar una."] = "No conversations yet.\n\nType /ws Name to start one.",
    ["Elige un contacto de la lista"] = "Pick a contact from the list",
    ["Clic: abrir/cerrar"] = "Click: open/close",
    ["Arrastrar: mover"] = "Drag: move",
    ["|cff888888Escribe un mensaje para empezar la conversación.|r"] = "|cff888888Type a message to start the conversation.|r",
    ["|cff7fdc7fTú:|r"] = "|cff7fdc7fYou:|r",
    ["Tú: "] = "You: ",
    ["Mayús + clic derecho: borrar conversación"] = "Shift + right-click: delete conversation",
    ["Buscar:"] = "Search:",
    ["%d de %d jugadores"] = "%d of %d players",
    ["Nivel %s · %s"] = "Level %s · %s",
    ["Clase desconocida"] = "Unknown class",
    ["Visto por última vez: "] = "Last seen: ",
    ["Clic: susurrar"] = "Click: whisper",
    ["Mayús + clic derecho: quitar de la lista"] = "Shift + right-click: remove from the list",
}

function ns.T(s)
    if SPANISH then return s end
    return EN[s] or s
end
