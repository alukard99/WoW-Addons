-- Alianza: chat común entre varias hermandades.
-- Usa un canal de chat normal con clave. Solo quien lo administra
-- necesita el addon; los demás se unen con /join <canal> <clave>
-- y escriben con /<número del canal>.

local ADDON_NAME = ...
local T = select(2, ...).T  -- traducción (Locale.lua)
local MAX_MSG = 255

local DEFAULTS = {
    channel = nil,      -- nombre del canal
    password = nil,     -- clave del canal
    guildTags = true,   -- mostrar <Hermandad> delante de los mensajes cuando se conoce
}

local db
local guildCache = {}   -- nombre del jugador -> hermandad
local pendingMsg        -- mensaje a enviar en cuanto entremos al canal
local frame = CreateFrame("Frame")

---------------------------------------------------------------------------
-- Utilidades
---------------------------------------------------------------------------

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(T"|cffff8c1a[Alianza]|r " .. msg)
end

local function IsMyChannel(name)
    return db and db.channel and name and name:lower() == db.channel:lower()
end

-- Corta un texto a maxBytes sin romper caracteres UTF-8 (ñ, á, etc.)
local function Utf8Truncate(s, maxBytes)
    if #s <= maxBytes then return s, false end
    s = s:sub(1, maxBytes)
    local i = #s
    while i > 0 do
        local b = s:byte(i)
        if b < 0x80 then
            break
        elseif b >= 0xC0 then
            s = s:sub(1, i - 1)
            break
        end
        i = i - 1
    end
    return s, true
end

---------------------------------------------------------------------------
-- Hermandad de cada jugador (para la etiqueta <Hermandad>)
-- El juego no dice la hermandad en los mensajes de canal, así que se
-- recuerda la de los jugadores que ves: objetivo, ratón, placas de nombre,
-- grupo y tu propia hermandad.
---------------------------------------------------------------------------

local function CacheUnit(unit)
    if not UnitExists(unit) or not UnitIsPlayer(unit) then return end
    local guild = GetGuildInfo(unit)
    local name = GetUnitName(unit, true)
    if guild and name then
        guildCache[Ambiguate(name, "none")] = guild
    end
end

local function CacheGroup()
    local prefix, count = "party", GetNumSubgroupMembers()
    if IsInRaid() then prefix, count = "raid", GetNumGroupMembers() end
    for i = 1, count do
        CacheUnit(prefix .. i)
    end
end

local function CacheMyGuild()
    local guild = GetGuildInfo("player")
    if not guild then return end
    for i = 1, GetNumGuildMembers() do
        local name = GetGuildRosterInfo(i)
        if name then
            guildCache[Ambiguate(name, "none")] = guild
        end
    end
end

---------------------------------------------------------------------------
-- Canal
---------------------------------------------------------------------------

local function ChannelId()
    if not db.channel then return 0 end
    local id = GetChannelName(db.channel)
    return id or 0
end

local function ShowChannelInChat()
    if db.channel and ChatFrame_AddChannel then
        ChatFrame_AddChannel(DEFAULT_CHAT_FRAME, db.channel)
    end
end

local function JoinAllianceChannel()
    if not db.channel then return end
    if ChannelId() == 0 then
        JoinChannelByName(db.channel, db.password)
    end
    C_Timer.After(1, ShowChannelInChat)
end

local function LeaveAllianceChannel(name)
    if name and GetChannelName(name) ~= 0 then
        LeaveChannelByName(name)
    end
end

local function JoinLine()
    return "/join " .. db.channel .. (db.password and (" " .. db.password) or "")
end

---------------------------------------------------------------------------
-- Enviar
---------------------------------------------------------------------------

local function SendAlliance(text)
    text = text and strtrim(text) or ""
    if text == "" then
        Print(T"Escribe un mensaje: |cffffffff/a hola a todos|r")
        return
    end
    if not db.channel then
        Print(T"No hay canal configurado. Usa |cffffffff/alianza canal <nombre> <clave>|r.")
        return
    end

    local body, cut = Utf8Truncate(text, MAX_MSG)
    local id = ChannelId()
    if id == 0 then
        pendingMsg = body
        Print(T"Uniéndote al canal... vuelve a pulsar Enter con tu mensaje si no aparece.")
        JoinAllianceChannel()
        return
    end
    SendChatMessage(body, "CHANNEL", nil, id)
    if cut then
        Print(T"Mensaje demasiado largo, se recortó.")
    end
end

---------------------------------------------------------------------------
-- Filtro: añade <Hermandad> a los mensajes del canal
---------------------------------------------------------------------------

local function ChannelFilter(_, _, msg, author, ...)
    if not db or not db.guildTags then return false end
    local channelName = select(7, ...) -- arg9 = nombre base del canal
    if not IsMyChannel(channelName) or not author then return false end
    local guild = guildCache[Ambiguate(author, "none")]
    if guild then
        return false, "|cff9d9d9d<" .. guild .. ">|r " .. msg, author, ...
    end
    return false
end

---------------------------------------------------------------------------
-- Comandos
---------------------------------------------------------------------------

local function ShowHelp()
    Print(T"Comandos:")
    print(T"  |cffffffff/a <mensaje>|r - escribir en el chat de alianza")
    print(T"  |cffffffff/alianza <mensaje>|r - igual que /a")
    print(T"  |cffffffff/alianza canal <nombre> [clave]|r - crear/unirte al canal")
    print(T"  |cffffffff/alianza info|r - ver la línea /join para pasársela a los demás")
    print(T"  |cffffffff/alianza anunciar|r - enviar la línea /join al chat de tu hermandad")
    print(T"  |cffffffff/alianza clave <nueva>|r - cambiar la clave (si eres dueño del canal)")
    print(T"  |cffffffff/alianza expulsar <jugador>|r - expulsar a alguien del canal")
    print(T"  |cffffffff/alianza quien|r - ver quién está en el canal")
    print(T"  |cffffffff/alianza etiquetas|r - activar/desactivar <Hermandad> en los mensajes")
    print(T"  |cffffffff/alianza salir|r - salir del canal y borrar la configuración")
end

local function RequireChannel()
    if not db.channel then
        Print(T"Primero configura el canal con |cffffffff/alianza canal <nombre> <clave>|r.")
        return false
    end
    return true
end

local function HandleAlianza(input)
    input = strtrim(input or "")
    local cmd, rest = input:match("^(%S+)%s*(.-)$")
    cmd = cmd and cmd:lower()

    if input == "" or cmd == "ayuda" or cmd == "help" then
        ShowHelp()

    elseif cmd == "canal" or cmd == "channel" then
        local name, password = rest:match("^(%S+)%s*(%S*)$")
        if not name then
            Print(T"Uso: |cffffffff/alianza canal <nombre> [clave]|r (el nombre sin espacios)")
            return
        end
        if name:match("^%d") then
            Print(T"El nombre del canal no puede empezar con un número.")
            return
        end
        if db.channel and not IsMyChannel(name) then
            LeaveAllianceChannel(db.channel)
        end
        db.channel = name
        db.password = password ~= "" and password or nil
        JoinAllianceChannel()
        Print(T"Canal configurado. Los demás se unen con: |cffffffff" .. JoinLine() .. "|r")

    elseif cmd == "info" then
        if not RequireChannel() then return end
        local id = ChannelId()
        Print(T"Canal: |cffffffff" .. db.channel .. "|r - " ..
            (id ~= 0 and (T"|cff00ff00conectado (canal " .. id .. ")|r") or T"|cffff0000no conectado|r"))
        Print(T"Para unirse: |cffffffff" .. JoinLine() .. "|r")
        Print(T"Después escriben con |cffffffff/<número del canal>|r, por ejemplo /5 hola")

    elseif cmd == "anunciar" or cmd == "announce" then
        if not RequireChannel() then return end
        if not IsInGuild() then
            Print(T"No estás en una hermandad.")
            return
        end
        SendChatMessage(T"Chat de alianza: escribe " .. JoinLine() ..
            T" y luego habla con /<número del canal>", "GUILD")

    elseif cmd == "clave" or cmd == "password" then
        if not RequireChannel() then return end
        local newPassword = rest ~= "" and rest or nil
        if SetChannelPassword then
            SetChannelPassword(db.channel, newPassword or "")
        end
        db.password = newPassword
        Print(T"Clave cambiada (solo funciona si eres el dueño del canal). Nueva línea: |cffffffff" ..
            JoinLine() .. "|r")

    elseif cmd == "expulsar" or cmd == "kick" then
        if not RequireChannel() then return end
        if rest == "" then
            Print(T"Uso: |cffffffff/alianza expulsar <jugador>|r")
            return
        end
        if ChannelKick then
            ChannelKick(db.channel, rest)
        else
            Print(T"Usa el comando del juego: |cffffffff/ckick " .. db.channel .. " " .. rest .. "|r")
        end

    elseif cmd == "quien" or cmd == "quién" or cmd == "who" then
        if not RequireChannel() then return end
        if ListChannelByName then
            ListChannelByName(db.channel)
        else
            Print(T"Mira la lista en la ventana Social > pestaña Chat.")
        end

    elseif cmd == "etiquetas" or cmd == "tags" then
        db.guildTags = not db.guildTags
        Print(T"Etiquetas de hermandad " .. (db.guildTags and T"activadas." or T"desactivadas."))

    elseif cmd == "salir" or cmd == "leave" then
        LeaveAllianceChannel(db.channel)
        db.channel, db.password = nil, nil
        Print(T"Has salido del canal de alianza.")

    else
        SendAlliance(input)
    end
end

SLASH_ALIANZA1 = "/alianza"
SlashCmdList["ALIANZA"] = HandleAlianza

SLASH_ALIANZAMSG1 = "/a"
SlashCmdList["ALIANZAMSG"] = SendAlliance

---------------------------------------------------------------------------
-- Eventos
---------------------------------------------------------------------------

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("GUILD_ROSTER_UPDATE")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("CHANNEL_UI_UPDATE")

frame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON_NAME then return end
        AlianzaDB = AlianzaDB or {}
        db = AlianzaDB
        for k, v in pairs(DEFAULTS) do
            if db[k] == nil then db[k] = v end
        end
        ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", ChannelFilter)

    elseif event == "PLAYER_ENTERING_WORLD" then
        local isLogin, isReload = ...
        if IsInGuild() then
            if C_GuildInfo and C_GuildInfo.GuildRoster then
                C_GuildInfo.GuildRoster()
            elseif GuildRoster then
                GuildRoster()
            end
        end
        CacheGroup()
        if isLogin or isReload then
            -- Esperar a que se unan General/Comercio para no cambiarles el número
            C_Timer.After(8, JoinAllianceChannel)
        end

    elseif event == "GUILD_ROSTER_UPDATE" then
        CacheMyGuild()

    elseif event == "GROUP_ROSTER_UPDATE" then
        CacheGroup()

    elseif event == "PLAYER_TARGET_CHANGED" then
        CacheUnit("target")

    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        CacheUnit("mouseover")

    elseif event == "NAME_PLATE_UNIT_ADDED" then
        CacheUnit((...))

    elseif event == "CHANNEL_UI_UPDATE" then
        -- Si había un mensaje esperando a que entráramos al canal, enviarlo
        if pendingMsg and ChannelId() ~= 0 then
            Print(T"Ya estás en el canal. Envía tu mensaje de nuevo con |cffffffff/a|r.")
            pendingMsg = nil
        end
    end
end)
