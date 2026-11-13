-- Traducciones. El addon está escrito en español; si el juego no está en español se muestra en inglés.
local _, ns = ...
local loc = GetLocale()
local SPANISH = loc == "esES" or loc == "esMX"

local EN = {
    ["Guardando resultados..."] = "Saving results...",
    ["Escaneo terminado: %d subastas, %d objetos distintos."] = "Scan finished: %d auctions, %d different items.",
    [" Pulsa Exportar en /subastas."] = " Press Export in /subastas.",
    ["Error al escanear: "] = "Scan error: ",
    ["Leyendo subastas... %d / %d"] = "Reading auctions... %d / %d",
    ["Escaneando páginas... %d / %d"] = "Scanning pages... %d / %d",
    ["El servidor no ha enviado la lista. El escaneo completo solo se puede hacer cada 15 minutos; "] = "The server didn't send the list. A full scan can only be done every 15 minutes; ",
    ["prueba más tarde o usa /subastas paginas."] = "try again later or use /subastas pages.",
    ["Abre la casa de subastas para escanear."] = "Open the auction house to scan.",
    ["Ya hay un escaneo en marcha."] = "A scan is already running.",
    ["Este cliente no tiene una API de subastas conocida."] = "This client has no known auction house API.",
    ["El escaneo completo vuelve a estar disponible en %d min. "] = "The full scan is available again in %d min. ",
    ["Mientras, puedes usar /subastas paginas."] = "Meanwhile you can use /subastas pages.",
    ["Pidiendo la lista completa al servidor (puede tardar un poco)..."] = "Asking the server for the full list (it may take a moment)...",
    ["Pidiendo la lista completa al servidor (el juego puede congelarse unos segundos)..."] = "Asking the server for the full list (the game may freeze for a few seconds)...",
    ["Escaneando página a página..."] = "Scanning page by page...",
    ["Escaneo cancelado: se ha cerrado la casa de subastas."] = "Scan cancelled: the auction house was closed.",
    ["gris"] = "poor",
    ["blanco"] = "common",
    ["verde"] = "uncommon",
    ["azul"] = "rare",
    ["morado"] = "epic",
    ["naranja"] = "legendary",
    ["artefacto"] = "artifact",
    ["reliquia"] = "heirloom",
    ["Volumen"] = "Volume",
    ["Más baratos"] = "Cheapest",
    ["Más caros"] = "Most expensive",
    ["Todavía no hay datos. Abre la casa de subastas y pulsa Escanear."] = "No data yet. Open the auction house and press Scan.",
    ["### DATOS"] = "### DATA",
    ["Reino: %s | Escaneo: %s | Subastas leídas: %d | Objetos: %d (se incluyen %d, orden: %s)"] = "Realm: %s | Scan: %s | Auctions read: %d | Items: %d (%d included, order: %s)",
    ["Mi oro: "] = "My gold: ",
    ["id;nombre;calidad;tipo;nv;subastas;cantidad;vendedores;min;p25;mediana;hist_p25;dias_hist;cant_hist;npc;desv_%;primeros"] = "id;name;quality;type;ilvl;auctions;quantity;sellers;min;p25;median;hist_p25;hist_days;hist_qty;npc;dev_%;first",
    ["Faltan datos de %d objetos; el juego los está cargando."] = "Data missing for %d items; the game is loading them.",
    ["%d de %d objetos exportados (%d caracteres). Pulsa «Copiar todo»."] = "%d of %d items exported (%d characters). Press \"Copy all\".",
    ["%s Reintentando (%d/%d)..."] = "%s Retrying (%d/%d)...",
    [" (%d sin nombre: el servidor no los ha enviado)"] = " (%d without a name: the server didn't send them)",
    ["Texto seleccionado: pulsa Ctrl+C y pégalo en la IA."] = "Text selected: press Ctrl+C and paste it into the AI.",
    ["Subastas"] = "AH Price Export",
    ["Escanear"] = "Scan",
    ["Exportar"] = "Export",
    ["Copiar todo"] = "Copy all",
    ["Orden: "] = "Order: ",
    ["Máx. objetos:"] = "Max items:",
    ["Último escaneo: "] = "Last scan: ",
    [". Pulsa Exportar."] = ". Press Export.",
    ["Abre la casa de subastas y pulsa Escanear."] = "Open the auction house and press Scan.",
    ["Se guardarán "] = "Keeping ",
    [" días de historial."] = " days of history.",
    ["Datos de "] = "Data for ",
    [" borrados."] = " deleted.",
    ["|cff33ccffSubastas:|r "] = "|cff33ccffAH Price Export:|r ",
}

function ns.T(s)
    if SPANISH then return s end
    return EN[s] or s
end
