-- Susurros: mensajes privados estilo WhatsApp.
-- Los contactos solo aparecen cuando existe al menos un mensaje, ordenados por el más reciente.

local ADDON = ...
local T = select(2, ...).T  -- traducción (Locale.lua)
local MAX_MSGS = 200         -- mensajes guardados por contacto
local ROW_H, NUM_ROWS = 44, 8 -- tamaño de la lista de contactos
local LIST_W = 200

local db
local selected            -- clave del contacto abierto (puede ser un borrador sin mensajes)
local offset = 0          -- desplazamiento de la lista
local order = {}          -- claves ordenadas por último mensaje
local rows = {}
local SetTab              -- se define más abajo
local MAX_PLAYERS = 3000  -- jugadores recordados como máximo

local SendWhisper = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage

local function IsSecret(v)
    return issecretvalue and issecretvalue(v)
end

local function Short(name)
    return Ambiguate and Ambiguate(name, "none") or name
end

local function Solid(tex, r, g, b, a)
    if tex.SetColorTexture then tex:SetColorTexture(r, g, b, a) else tex:SetTexture(r, g, b, a) end
end

local function ClassHex(class)
    local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if not c then return "ffffd100" end
    return ("ff%02x%02x%02x"):format(c.r * 255, c.g * 255, c.b * 255)
end

local function ListTime(t)
    if date("%d%m%y", t) == date("%d%m%y") then return date("%H:%M", t) end
    return date("%d/%m", t)
end

---------------------------------------------------------------------------
-- Ventana principal
---------------------------------------------------------------------------
local f = CreateFrame("Frame", "SusurrosFrame", UIParent)
f:SetSize(640, 34 + NUM_ROWS * ROW_H + 10)
f:SetPoint("CENTER")
f:SetFrameStrata("HIGH")
f:SetToplevel(true)
f:SetClampedToScreen(true)
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    db.pos = { p, rp, x, y }
end)
f:Hide()
tinsert(UISpecialFrames, "SusurrosFrame")

local bg = f:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
Solid(bg, 0.05, 0.07, 0.08, 0.95)

local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 12, -9)
title:SetText(T"Susurros")

local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 2, 2)

-- Pestañas
local function MakeTab(text, x, which)
    local t = CreateFrame("Button", nil, f)
    t:SetSize(90, 22)
    t:SetPoint("TOPLEFT", x, -6)
    local tbg = t:CreateTexture(nil, "BACKGROUND")
    tbg:SetAllPoints()
    Solid(tbg, 1, 1, 1, 0.05)
    t.sel = t:CreateTexture(nil, "BORDER")
    t.sel:SetAllPoints()
    Solid(t.sel, 0.16, 0.36, 0.30, 1)
    local fs = t:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    fs:SetPoint("CENTER")
    fs:SetText(text)
    t:SetScript("OnClick", function() SetTab(which) end)
    return t
end
local tabChats = MakeTab("Chats", 110, "chats")
local tabPlayers = MakeTab(T"Jugadores", 204, "players")
tabPlayers.sel:Hide()

-- Lista de contactos
local list = CreateFrame("Frame", nil, f)
list:SetPoint("TOPLEFT", 8, -34)
list:SetSize(LIST_W, NUM_ROWS * ROW_H)
list:EnableMouseWheel(true)
local listBg = list:CreateTexture(nil, "BACKGROUND")
listBg:SetAllPoints()
Solid(listBg, 0.09, 0.12, 0.13, 1)

local emptyList = list:CreateFontString(nil, "OVERLAY", "GameFontDisable")
emptyList:SetPoint("TOP", 0, -16)
emptyList:SetWidth(LIST_W - 20)
emptyList:SetText(T"Aún no hay conversaciones.\n\nEscribe /ws Nombre para empezar una.")

-- Panel de conversación
local chat = CreateFrame("Frame", nil, f)
chat:SetPoint("TOPLEFT", list, "TOPRIGHT", 8, 0)
chat:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -8, 10)
local chatBg = chat:CreateTexture(nil, "BACKGROUND")
chatBg:SetAllPoints()
Solid(chatBg, 0.03, 0.04, 0.05, 1)

local header = chat:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
header:SetPoint("TOPLEFT", 8, -6)

local hint = chat:CreateFontString(nil, "OVERLAY", "GameFontDisable")
hint:SetPoint("CENTER")
hint:SetText(T"Elige un contacto de la lista")

local input = CreateFrame("EditBox", "SusurrosInput", chat, "InputBoxTemplate")
input:SetPoint("BOTTOMLEFT", 12, 6)
input:SetPoint("BOTTOMRIGHT", -8, 6)
input:SetHeight(22)
input:SetAutoFocus(false)
input:SetMaxLetters(255)

local log = CreateFrame("ScrollingMessageFrame", nil, chat)
log:SetPoint("TOPLEFT", 8, -30)
log:SetPoint("BOTTOMRIGHT", input, "TOPRIGHT", -2, 6)
log:SetFontObject(ChatFontNormal)
log:SetJustifyH("LEFT")
log:SetFading(false)
log:SetMaxLines(MAX_MSGS + 60)
log:EnableMouseWheel(true)
log:SetScript("OnMouseWheel", function(self, delta)
    if delta > 0 then self:ScrollUp() else self:ScrollDown() end
end)
log:SetHyperlinksEnabled(true)
log:SetScript("OnHyperlinkClick", function(_, link, text, button)
    SetItemRef(link, text, button)
end)

---------------------------------------------------------------------------
-- Botón flotante con contador de no leídos
---------------------------------------------------------------------------
local btn = CreateFrame("Button", "SusurrosButton", UIParent)
btn:SetSize(36, 36)
btn:SetPoint("CENTER", UIParent, "CENTER", 300, -200)
btn:SetClampedToScreen(true)
btn:SetMovable(true)
btn:RegisterForDrag("LeftButton")
btn:SetScript("OnDragStart", btn.StartMoving)
btn:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    db.btnPos = { p, rp, x, y }
end)
local icon = btn:CreateTexture(nil, "ARTWORK")
icon:SetAllPoints()
icon:SetTexture("Interface\\Icons\\INV_Letter_15")
btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
local badge = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
badge:SetPoint("BOTTOMRIGHT", 2, -2)
badge:SetTextColor(0.2, 1, 0.3)
btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(T"Susurros")
    GameTooltip:AddLine(T"Clic: abrir/cerrar", 1, 1, 1)
    GameTooltip:AddLine(T"Arrastrar: mover", 1, 1, 1)
    GameTooltip:Show()
end)
btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

---------------------------------------------------------------------------
-- Refresco
---------------------------------------------------------------------------
local function RefreshBadge()
    local n = 0
    for _, c in pairs(db.chats) do n = n + (c.unread or 0) end
    badge:SetText(n > 0 and n or "")
end

local function RefreshChat()
    log:Clear()
    if not selected then
        header:SetText("")
        hint:Show()
        input:Hide()
        return
    end
    hint:Hide()
    input:Show()
    local c = db.chats[selected]
    local hex = ClassHex(c and c.class)
    header:SetText(("|c%s%s|r"):format(hex, Short(selected)))
    if not c then
        log:AddMessage(T"|cff888888Escribe un mensaje para empezar la conversación.|r")
        return
    end
    local lastDay
    for _, m in ipairs(c.msgs) do
        local day = date("%d/%m/%Y", m.t)
        if day ~= lastDay then
            log:AddMessage("|cff666666———  " .. day .. "  ———|r")
            lastDay = day
        end
        local who = m.me and T"|cff7fdc7fTú:|r" or ("|c%s%s:|r"):format(hex, Short(selected))
        log:AddMessage(("|cff888888%s|r %s %s"):format(date("%H:%M", m.t), who, m.text))
    end
    log:ScrollToBottom()
end

local function RefreshList()
    wipe(order)
    for key in pairs(db.chats) do order[#order + 1] = key end
    table.sort(order, function(a, b) return db.chats[a].last > db.chats[b].last end)

    offset = math.max(0, math.min(offset, #order - NUM_ROWS))
    emptyList:SetShown(#order == 0)

    for i = 1, NUM_ROWS do
        local row, key = rows[i], order[i + offset]
        if key then
            local c = db.chats[key]
            local last = c.msgs[#c.msgs]
            row.key = key
            row.name:SetText(("|c%s%s|r"):format(ClassHex(c.class), Short(key)))
            row.preview:SetText((last.me and T"Tú: " or "") .. last.text)
            row.time:SetText(ListTime(c.last))
            row.unread:SetText((c.unread or 0) > 0 and c.unread or "")
            row.sel:SetShown(key == selected)
            row:Show()
        else
            row.key = nil
            row:Hide()
        end
    end
    RefreshBadge()
end

local function Select(key)
    selected = key
    local c = key and db.chats[key]
    if c then c.unread = 0 end
    RefreshList()
    RefreshChat()
end

local function OpenWith(key)
    f:Show()
    SetTab("chats")
    Select(key)
    input:SetFocus()
end

---------------------------------------------------------------------------
-- Filas de contactos
---------------------------------------------------------------------------
for i = 1, NUM_ROWS do
    local row = CreateFrame("Button", nil, list)
    row:SetSize(LIST_W, ROW_H)
    row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.sel = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.sel:SetAllPoints()
    Solid(row.sel, 0.16, 0.36, 0.30, 1)

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    Solid(hl, 1, 1, 1, 0.06)

    local sep = row:CreateTexture(nil, "BORDER")
    sep:SetPoint("BOTTOMLEFT", 6, 0)
    sep:SetPoint("BOTTOMRIGHT", -6, 0)
    sep:SetHeight(1)
    Solid(sep, 1, 1, 1, 0.06)

    row.time = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.time:SetPoint("TOPRIGHT", -6, -7)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", 8, -6)
    row.name:SetPoint("RIGHT", row.time, "LEFT", -4, 0)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.unread = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.unread:SetPoint("BOTTOMRIGHT", -6, 7)
    row.unread:SetTextColor(0.2, 1, 0.3)

    row.preview = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.preview:SetPoint("BOTTOMLEFT", 8, 8)
    row.preview:SetPoint("RIGHT", row, "RIGHT", -28, 0)
    row.preview:SetJustifyH("LEFT")
    row.preview:SetWordWrap(false)
    row.preview:SetTextColor(0.65, 0.65, 0.65)

    row:SetScript("OnClick", function(self, button)
        if not self.key then return end
        if button == "RightButton" then
            if IsShiftKeyDown() then
                db.chats[self.key] = nil
                Select(selected ~= self.key and selected or nil)
            end
        else
            OpenWith(self.key)
        end
    end)
    row:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.key or "")
        GameTooltip:AddLine(T"Mayús + clic derecho: borrar conversación", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rows[i] = row
end

list:SetScript("OnMouseWheel", function(_, delta)
    offset = offset - delta
    RefreshList()
end)

---------------------------------------------------------------------------
-- Pestaña de jugadores vistos
---------------------------------------------------------------------------
local COLS, PROWS = 3, 7
local CARD_W, CARD_H, PITCH_X, PITCH_Y = 206, 44, 208, 46
local pOrder, cards = {}, {}
local pOffset, pDirty, pElapsed = 0, false, 0

local playersPanel = CreateFrame("Frame", nil, f)
playersPanel:SetPoint("TOPLEFT", 8, -34)
playersPanel:SetPoint("BOTTOMRIGHT", -8, 10)
playersPanel:EnableMouseWheel(true)
playersPanel:Hide()

local search = CreateFrame("EditBox", "SusurrosSearch", playersPanel, "InputBoxTemplate")
search:SetPoint("TOPLEFT", 60, -2)
search:SetSize(170, 20)
search:SetAutoFocus(false)
search:SetScript("OnEscapePressed", search.ClearFocus)
search:SetScript("OnEnterPressed", search.ClearFocus)
local searchLabel = playersPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
searchLabel:SetPoint("RIGHT", search, "LEFT", -10, 0)
searchLabel:SetText(T"Buscar:")
local pCount = playersPanel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
pCount:SetPoint("TOPRIGHT", -4, -7)

local function RefreshPlayers()
    pDirty = false
    wipe(pOrder)
    local filter = strtrim(search:GetText()):lower()
    local total = 0
    for key in pairs(db.players) do
        total = total + 1
        if filter == "" or key:lower():find(filter, 1, true) then pOrder[#pOrder + 1] = key end
    end
    table.sort(pOrder, function(a, b)
        local sa, sb = db.players[a].seen, db.players[b].seen
        if sa ~= sb then return sa > sb end
        return a < b
    end)
    pCount:SetText((T"%d de %d jugadores"):format(#pOrder, total))

    local maxOff = math.max(0, math.ceil(#pOrder / COLS) - PROWS)
    pOffset = math.max(0, math.min(pOffset, maxOff))

    for i, card in ipairs(cards) do
        local key = pOrder[i + pOffset * COLS]
        if key then
            local p = db.players[key]
            local c = p.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[p.class]
            local r, g, b = 0.4, 0.4, 0.4
            if c then r, g, b = c.r, c.g, c.b end
            Solid(card.bg, r, g, b, 0.28)
            Solid(card.stripe, r, g, b, 1)
            card.key = key
            card.name:SetText(Short(key))
            card.name:SetTextColor(r + (1 - r) * 0.25, g + (1 - g) * 0.25, b + (1 - b) * 0.25)
            local className = p.class and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[p.class]
            card.info:SetText((T"Nivel %s · %s"):format(p.level or "?", className or T"Clase desconocida"))
            card.time:SetText(ListTime(p.seen))
            card:Show()
        else
            card.key = nil
            card:Hide()
        end
    end
end

for i = 1, COLS * PROWS do
    local card = CreateFrame("Button", nil, playersPanel)
    card:SetSize(CARD_W, CARD_H)
    card:SetPoint("TOPLEFT", ((i - 1) % COLS) * PITCH_X, -28 - math.floor((i - 1) / COLS) * PITCH_Y)
    card:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    card.bg = card:CreateTexture(nil, "BACKGROUND")
    card.bg:SetAllPoints()
    card.stripe = card:CreateTexture(nil, "BORDER")
    card.stripe:SetPoint("TOPLEFT")
    card.stripe:SetPoint("BOTTOMLEFT")
    card.stripe:SetWidth(4)
    local hl = card:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    Solid(hl, 1, 1, 1, 0.10)

    card.time = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    card.time:SetPoint("TOPRIGHT", -6, -7)
    card.name = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    card.name:SetPoint("TOPLEFT", 12, -6)
    card.name:SetPoint("RIGHT", card.time, "LEFT", -4, 0)
    card.name:SetJustifyH("LEFT")
    card.name:SetWordWrap(false)
    card.info = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    card.info:SetPoint("BOTTOMLEFT", 12, 8)
    card.info:SetPoint("RIGHT", card, "RIGHT", -6, 0)
    card.info:SetJustifyH("LEFT")
    card.info:SetWordWrap(false)

    card:SetScript("OnClick", function(self, button)
        if not self.key then return end
        if button == "RightButton" then
            if IsShiftKeyDown() then
                db.players[self.key] = nil
                RefreshPlayers()
            end
            return
        end
        -- Si ya hay conversación con ese jugador, se abre esa.
        local target = self.key
        for key in pairs(db.chats) do
            if Short(key):lower() == Short(target):lower() then target = key break end
        end
        OpenWith(target)
    end)
    card:SetScript("OnEnter", function(self)
        local p = self.key and db.players[self.key]
        if not p then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.key)
        GameTooltip:AddLine(T"Visto por última vez: " .. date("%d/%m/%Y %H:%M", p.seen), 1, 1, 1)
        GameTooltip:AddLine(T"Clic: susurrar", 0.7, 0.7, 0.7)
        GameTooltip:AddLine(T"Mayús + clic derecho: quitar de la lista", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cards[i] = card
end

playersPanel:SetScript("OnMouseWheel", function(_, delta)
    pOffset = pOffset - delta
    RefreshPlayers()
end)
playersPanel:SetScript("OnShow", RefreshPlayers)
playersPanel:SetScript("OnUpdate", function(_, elapsed)
    pElapsed = pElapsed + elapsed
    if pDirty and pElapsed > 0.5 then
        pElapsed = 0
        RefreshPlayers()
    end
end)
search:SetScript("OnTextChanged", function()
    pOffset = 0
    if db then RefreshPlayers() end
end)

SetTab = function(which)
    local p = which == "players"
    list:SetShown(not p)
    chat:SetShown(not p)
    playersPanel:SetShown(p)
    tabChats.sel:SetShown(not p)
    tabPlayers.sel:SetShown(p)
end

-- Alta o actualización de un jugador visto.
local myKey
local function SeePlayer(name, realm, class, level)
    if IsSecret(name) or type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT then return end
    local key = name
    if not key:find("-", 1, true) then
        if not realm or realm == "" then realm = GetNormalizedRealmName and GetNormalizedRealmName() end
        if realm then key = key .. "-" .. realm end
    end
    if not myKey then
        local me, myRealm = UnitName("player"), GetNormalizedRealmName and GetNormalizedRealmName()
        if me and myRealm then myKey = me .. "-" .. myRealm end
    end
    if key == myKey or name == UnitName("player") then return end

    local p = db.players[key]
    if not p then
        p = {}
        db.players[key] = p
    end
    if type(class) == "string" then p.class = class end
    if type(level) == "number" and level > 0 then p.level = level end
    p.seen = time()
    pDirty = true
end

local function ScanUnit(unit)
    if not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then return end
    local name, realm = UnitName(unit)
    local _, class = UnitClass(unit)
    local level = UnitLevel(unit)
    if IsSecret(name) or IsSecret(realm) then return end
    if IsSecret(class) then class = nil end
    if IsSecret(level) then level = nil end
    SeePlayer(name, realm, class, level)
end
local function SeeUnit(unit) pcall(ScanUnit, unit) end

local function ScanGroup()
    for i = 1, 4 do SeeUnit("party" .. i) end
    for i = 1, 40 do SeeUnit("raid" .. i) end
end

local lastGuildScan = 0
local function ScanGuild()
    if not GetNumGuildMembers or GetTime() - lastGuildScan < 30 then return end
    lastGuildScan = GetTime()
    for i = 1, (GetNumGuildMembers()) or 0 do
        local name, _, _, level, _, _, _, _, online, _, class = GetGuildRosterInfo(i)
        if online then SeePlayer(name, nil, class, level) end
    end
end

local function ScanWho()
    if not (C_FriendList and C_FriendList.GetNumWhoResults) then return end
    for i = 1, C_FriendList.GetNumWhoResults() or 0 do
        local info = C_FriendList.GetWhoInfo(i)
        if info then SeePlayer(info.fullName, nil, info.filename, info.level) end
    end
end

local function PrunePlayers()
    local keys = {}
    for key in pairs(db.players) do keys[#keys + 1] = key end
    if #keys <= MAX_PLAYERS then return end
    table.sort(keys, function(a, b) return db.players[a].seen > db.players[b].seen end)
    for i = MAX_PLAYERS - 500, #keys do db.players[keys[i]] = nil end
end

---------------------------------------------------------------------------
-- Enviar
---------------------------------------------------------------------------
input:SetScript("OnEnterPressed", function(self)
    local text = strtrim(self:GetText())
    if text ~= "" and selected then
        SendWhisper(text, "WHISPER", nil, selected)
        self:SetText("")
    end
end)
input:SetScript("OnEscapePressed", input.ClearFocus)

f:SetScript("OnShow", function()
    if selected and db.chats[selected] then db.chats[selected].unread = 0 end
    RefreshList()
    RefreshChat()
end)

---------------------------------------------------------------------------
-- Registro de mensajes
---------------------------------------------------------------------------
local function Record(key, text, me, guid)
    local c = db.chats[key]
    if not c then
        c = { msgs = {}, unread = 0 }
        db.chats[key] = c
    end
    if not c.class and guid and GetPlayerInfoByGUID then
        local ok, _, class = pcall(GetPlayerInfoByGUID, guid)
        if ok and class then c.class = class end
    end
    local now = time()
    c.last = now
    c.msgs[#c.msgs + 1] = { t = now, me = me or nil, text = text }
    while #c.msgs > MAX_MSGS do table.remove(c.msgs, 1) end

    -- Un borrador abierto con /ws Nombre pasa a ser esta conversación.
    if selected and not db.chats[selected] and Short(selected):lower() == Short(key):lower() then
        selected = key
    end

    local viewing = f:IsShown() and selected == key
    if not me and not viewing then c.unread = (c.unread or 0) + 1 end

    RefreshList()
    if viewing then RefreshChat() end
end

---------------------------------------------------------------------------
-- Abrir / cerrar y comandos
---------------------------------------------------------------------------
function Susurros_Toggle()
    if f:IsShown() then f:Hide() else f:Show() end
end
btn:SetScript("OnClick", Susurros_Toggle)

SLASH_SUSURROS1, SLASH_SUSURROS2 = "/ws", "/susurros"
SlashCmdList.SUSURROS = function(msg)
    msg = strtrim(msg or "")
    if msg == "" then
        Susurros_Toggle()
    elseif msg:lower() == "boton" or msg:lower() == "botón" or msg:lower() == "button" then
        db.hideBtn = not db.hideBtn
        btn:SetShown(not db.hideBtn)
    else
        -- Borrador: no aparece en la lista hasta que se envíe un mensaje.
        local target = msg
        for key in pairs(db.chats) do
            if Short(key):lower() == msg:lower() or key:lower() == msg:lower() then target = key break end
        end
        OpenWith(target)
    end
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
for _, name in ipairs({
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_SAY", "CHAT_MSG_YELL",
    "CHAT_MSG_CHANNEL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE", "CHAT_MSG_GUILD",
    "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID",
    "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_INSTANCE_CHAT",
    "CHAT_MSG_INSTANCE_CHAT_LEADER", "UPDATE_MOUSEOVER_UNIT", "PLAYER_TARGET_CHANGED",
    "NAME_PLATE_UNIT_ADDED", "GROUP_ROSTER_UPDATE", "GUILD_ROSTER_UPDATE", "WHO_LIST_UPDATE",
}) do
    pcall(ev.RegisterEvent, ev, name) -- algún evento puede no existir en todos los clientes
end
ev:SetScript("OnEvent", function(_, event, a1, a2, ...)
    if event == "ADDON_LOADED" then
        if a1 ~= ADDON then return end
        SusurrosDB = SusurrosDB or {}
        db = SusurrosDB
        db.chats = db.chats or {}
        db.players = db.players or {}
        PrunePlayers()
        if db.pos then
            f:ClearAllPoints()
            f:SetPoint(db.pos[1], UIParent, db.pos[2], db.pos[3], db.pos[4])
        end
        if db.btnPos then
            btn:ClearAllPoints()
            btn:SetPoint(db.btnPos[1], UIParent, db.btnPos[2], db.btnPos[3], db.btnPos[4])
        end
        btn:SetShown(not db.hideBtn)
        RefreshBadge()
        return
    end
    if not db then return end

    -- Jugadores vistos en el mundo
    if event == "UPDATE_MOUSEOVER_UNIT" then return SeeUnit("mouseover") end
    if event == "PLAYER_TARGET_CHANGED" then return SeeUnit("target") end
    if event == "NAME_PLATE_UNIT_ADDED" then return SeeUnit(a1) end
    if event == "GROUP_ROSTER_UPDATE" then return ScanGroup() end
    if event == "GUILD_ROSTER_UPDATE" then pcall(ScanGuild) return end
    if event == "WHO_LIST_UPDATE" then pcall(ScanWho) return end

    -- Mensajes de chat
    if IsSecret(a1) or IsSecret(a2) or type(a2) ~= "string" or a2 == "" then return end
    local guid = select(10, ...) -- argumento 12 del evento
    if IsSecret(guid) or type(guid) ~= "string" then guid = nil end
    if event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_WHISPER_INFORM" then
        Record(a2, a1, event == "CHAT_MSG_WHISPER_INFORM", guid)
    end
    if guid and guid:sub(1, 7) ~= "Player-" then return end
    local class
    if guid and GetPlayerInfoByGUID then
        local ok, _, token = pcall(GetPlayerInfoByGUID, guid)
        if ok then class = token end
    end
    SeePlayer(a2, nil, class, nil)
end)
