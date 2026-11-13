-- Guild Ledger: interfaz
local ADDON, ns = ...
local T = ns.T -- traducción (Locale.lua)
local GL = ns.GL
local UI = {}
GL.UI = UI

local ROWS, ROW_H = 20, 19
local CROWS, CROW_H = 6, 18
local LIST_W = 470

UI.sortKey = "name"
UI.sortAsc = true
UI.offset = 0
UI.coffset = 0
UI.catIndex = 1
UI.showLeft = false
UI.onlyOnline = false
UI.filter = ""

------------------------------------------------------------------------
-- Ayudas
------------------------------------------------------------------------
local function Make(ftype, name, parent, template)
    if template then
        local ok, f = pcall(CreateFrame, ftype, name, parent, template)
        if ok and f then return f end
    end
    return CreateFrame(ftype, name, parent)
end

local function Skin(f, a)
    if f.SetBackdrop then
        f:SetBackdrop({
            bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        f:SetBackdropColor(0.05, 0.05, 0.08, a or 0.92)
        f:SetBackdropBorderColor(0.5, 0.5, 0.55, 1)
    else
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.05, 0.08, a or 0.92)
    end
end

local function Panel(parent)
    local f = Make("Frame", nil, parent, "BackdropTemplate")
    Skin(f, 0.6)
    return f
end

local function Text(parent, font, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function Button(parent, label, w, h)
    local b = Make("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 90, h or 22)
    b:SetText(label)
    return b
end

local function InputBox(parent, w)
    local e = Make("EditBox", nil, parent, "InputBoxTemplate")
    e:SetSize(w, 20)
    e:SetAutoFocus(false)
    e:SetFontObject(ChatFontNormal)
    e:SetScript("OnEscapePressed", e.ClearFocus)
    e:SetScript("OnEnterPressed", e.ClearFocus)
    e.glAcceptLinks = true
    return e
end

local function Check(parent, label, onClick)
    local c = Make("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(22, 22)
    local t = Text(c, "GameFontNormalSmall")
    t:SetPoint("LEFT", c, "RIGHT", 2, 0)
    t:SetText(label)
    c:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
    return c
end

local function MultiLine(parent, w, h)
    local box = Panel(parent)
    box:SetSize(w, h)
    local sf = Make("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 6, -6)
    sf:SetPoint("BOTTOMRIGHT", -26, 6)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject(ChatFontNormal)
    eb:SetWidth(w - 36)
    eb:SetScript("OnEscapePressed", eb.ClearFocus)
    sf:SetScrollChild(eb)
    eb.glAcceptLinks = true
    box:EnableMouse(true)
    box:SetScript("OnMouseDown", function() eb:SetFocus() end)
    box.edit = eb
    return box
end

local function ClassColor(classFile)
    local c
    if classFile then
        if C_ClassColor and C_ClassColor.GetClassColor then c = C_ClassColor.GetClassColor(classFile) end
        if not c and RAID_CLASS_COLORS then c = RAID_CLASS_COLORS[classFile] end
    end
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

local function Ago(t)
    if not t then return "-" end
    local d = GL.Now() - t
    if d < 3600 then return T"ahora" end
    if d < 86400 then return math.floor(d / 3600) .. " h" end
    return math.floor(d / 86400) .. " d"
end

------------------------------------------------------------------------
-- Datos para la lista
------------------------------------------------------------------------
local function BuildList()
    local list = {}
    local g = GL.GetGuildDB(false)
    if not g then return list, nil end
    local f = UI.filter
    for name, m in pairs(g.members) do
        local ok = true
        if m.left and not UI.showLeft then ok = false end
        if ok and UI.onlyOnline and not m.online then ok = false end
        if ok and f ~= "" then
            local hay = (name .. " " .. (m.rank or "") .. " " .. (m.class or "") .. " " .. (m.notes or "")):lower()
            if not hay:find(f, 1, true) then ok = false end
        end
        if ok then
            local cnt, sum = GL.Totals(m)
            m._cnt, m._sum = cnt, sum
            list[#list + 1] = m
        end
    end
    local key, asc = UI.sortKey, UI.sortAsc
    table.sort(list, function(a, b)
        local va, vb
        if key == "level" then va, vb = a.level or 0, b.level or 0
        elseif key == "rank" then va, vb = a.rankIndex or 99, b.rankIndex or 99
        elseif key == "points" then va, vb = a._sum * 10000 + a._cnt, b._sum * 10000 + b._cnt
        elseif key == "seen" then va, vb = a.lastOnline or 0, b.lastOnline or 0
        else va, vb = a.name:lower(), b.name:lower() end
        if va == vb then return a.name < b.name end
        if asc then return va < vb else return va > vb end
    end)
    return list, g
end

------------------------------------------------------------------------
-- Construcción de la ventana
------------------------------------------------------------------------
function UI.Build()
    if UI.frame then return end

    local f = Make("Frame", "GuildLedgerFrame", UIParent, "BackdropTemplate")
    Skin(f)
    f:SetSize(880, 540)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:Hide()
    tinsert(UISpecialFrames, "GuildLedgerFrame")
    UI.frame = f

    local title = Text(f, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetText(T"Registro de Hermandad")
    UI.title = title

    local close = Make("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() f:Hide() end)

    -- Barra superior
    local search = InputBox(f, 170)
    search:SetPoint("TOPLEFT", 20, -42)
    search:SetScript("OnTextChanged", function(self)
        UI.filter = (self:GetText() or ""):lower()
        UI.offset = 0
        UI.Refresh()
    end)
    local sl = Text(f, "GameFontDisableSmall")
    sl:SetPoint("BOTTOMLEFT", search, "TOPLEFT", -4, 2)
    sl:SetText(T"Buscar (nombre, rango, notas)")

    local cOnline = Check(f, T"Solo conectados", function(v) UI.onlyOnline = v; UI.offset = 0; UI.Refresh() end)
    cOnline:SetPoint("LEFT", search, "RIGHT", 10, 0)
    local cLeft = Check(f, T"Exmiembros", function(v) UI.showLeft = v; UI.offset = 0; UI.Refresh() end)
    cLeft:SetPoint("LEFT", cOnline, "RIGHT", 100, 0)

    local bScan = Button(f, T"Escanear", 80)
    bScan:SetPoint("TOPLEFT", f, "TOPLEFT", LIST_W + 30, -40)
    bScan:SetScript("OnClick", function()
        GL.RequestRoster()
        C_Timer.After(1.5, function() GL.Scan() end)
    end)
    local bLog = Button(f, T"Historial", 80)
    bLog:SetPoint("LEFT", bScan, "RIGHT", 4, 0)
    bLog:SetScript("OnClick", function() UI.ShowText(T"Historial de la hermandad", GL.LogText()) end)
    local bExp = Button(f, T"Exportar", 80)
    bExp:SetPoint("LEFT", bLog, "RIGHT", 4, 0)
    bExp:SetScript("OnClick", function() UI.ShowText(T"Exportar (Ctrl+A, Ctrl+C)", GL.ExportText()) end)
    local bBank = Button(f, T"Banco", 70)
    bBank:SetPoint("LEFT", bExp, "RIGHT", 4, 0)
    bBank:SetScript("OnClick", function()
        GL.ProcessBankLogs(true)
        UI.ShowText(T"Movimientos del banco", GL.BankText())
    end)

    -- Lista
    local list = Panel(f)
    list:SetPoint("TOPLEFT", 12, -70)
    list:SetSize(LIST_W, ROWS * ROW_H + 34)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        UI.offset = math.max(0, UI.offset - delta * 3)
        UI.Refresh()
    end)
    UI.list = list

    local cols = {
        { key = "name",   label = T"Nombre",  x = 8,   w = 140 },
        { key = "level",  label = T"Nv",      x = 150, w = 30 },
        { key = "rank",   label = T"Rango",   x = 184, w = 110 },
        { key = "points", label = T"Aportes", x = 298, w = 90 },
        { key = "seen",   label = T"Visto",   x = 392, w = 66 },
    }
    for _, c in ipairs(cols) do
        local h = CreateFrame("Button", nil, list)
        h:SetPoint("TOPLEFT", c.x, -6)
        h:SetSize(c.w, 18)
        local t = Text(h, "GameFontNormalSmall")
        t:SetAllPoints()
        t:SetText(c.label)
        h:SetScript("OnClick", function()
            if UI.sortKey == c.key then UI.sortAsc = not UI.sortAsc
            else UI.sortKey = c.key; UI.sortAsc = (c.key == "name" or c.key == "rank") end
            UI.Refresh()
        end)
        h:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    end

    UI.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Button", nil, list)
        r:SetSize(LIST_W - 12, ROW_H)
        r:SetPoint("TOPLEFT", 6, -26 - (i - 1) * ROW_H)
        r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        local sel = r:CreateTexture(nil, "BACKGROUND")
        sel:SetAllPoints()
        sel:SetColorTexture(0.2, 0.5, 1, 0.25)
        sel:Hide()
        r.sel = sel
        r.dot = r:CreateTexture(nil, "OVERLAY")
        r.dot:SetSize(6, 6)
        r.dot:SetPoint("LEFT", 0, 0)
        r.dot:SetColorTexture(0.2, 1, 0.2, 1)
        r.name = Text(r); r.name:SetPoint("LEFT", 10, 0); r.name:SetWidth(136)
        r.level = Text(r); r.level:SetPoint("LEFT", 146, 0); r.level:SetWidth(30)
        r.rank = Text(r); r.rank:SetPoint("LEFT", 180, 0); r.rank:SetWidth(110)
        r.points = Text(r); r.points:SetPoint("LEFT", 294, 0); r.points:SetWidth(90)
        r.seen = Text(r); r.seen:SetPoint("LEFT", 388, 0); r.seen:SetWidth(66)
        r:SetScript("OnClick", function(self)
            UI.selected = self.memberName
            UI.coffset = 0
            UI.Refresh()
        end)
        UI.rows[i] = r
    end

    local status = Text(f, "GameFontDisableSmall")
    status:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 4, -6)
    status:SetWidth(LIST_W)
    UI.status = status

    UI.BuildDetail()
end

function UI.BuildDetail()
    local f = UI.frame
    local d = Panel(f)
    d:SetPoint("TOPLEFT", f, "TOPLEFT", LIST_W + 20, -70)
    d:SetPoint("BOTTOMRIGHT", -12, 14)
    UI.detail = d

    local empty = Text(d, "GameFontDisable", "CENTER")
    empty:SetPoint("CENTER")
    empty:SetText(T"Selecciona un jugador de la lista")
    UI.empty = empty

    local body = CreateFrame("Frame", nil, d)
    body:SetAllPoints()
    UI.body = body

    local W = 370
    local name = Text(body, "GameFontNormalLarge")
    name:SetPoint("TOPLEFT", 10, -10)
    name:SetWidth(W - 190)
    UI.dName = name

    local info = body:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -4)
    info:SetWidth(W - 20)
    info:SetJustifyH("LEFT")
    info:SetSpacing(2)
    UI.dInfo = info

    local nl = Text(body, "GameFontNormal")
    nl:SetPoint("TOPLEFT", 10, -142)
    nl:SetText(T"Notas")
    local notes = MultiLine(body, W - 16, 60)
    notes:SetPoint("TOPLEFT", nl, "BOTTOMLEFT", -2, -2)
    notes.edit:SetScript("OnTextChanged", function(self, user)
        if user then
            local m = UI.SelectedMember()
            if m then m.notes = self:GetText() end
        end
    end)
    UI.dNotes = notes

    -- Nuevo aporte
    local al = Text(body, "GameFontNormal")
    al:SetPoint("TOPLEFT", notes, "BOTTOMLEFT", 2, -8)
    al:SetText(T"Añadir aporte")

    local cat = Button(body, "", 130)
    cat:SetPoint("TOPLEFT", al, "BOTTOMLEFT", 0, -4)
    cat:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    cat:SetScript("OnClick", function(self, btn)
        local n = #GL.CATEGORIES
        if btn == "RightButton" then UI.catIndex = (UI.catIndex - 2) % n + 1
        else UI.catIndex = UI.catIndex % n + 1 end
        self:SetText(T(GL.CATEGORIES[UI.catIndex]))
    end)
    cat:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(T"Categoría")
        GameTooltip:AddLine(T"Clic izq./der. para cambiar", 1, 1, 1)
        GameTooltip:Show()
    end)
    cat:SetScript("OnLeave", GameTooltip_Hide)
    cat:SetText(T(GL.CATEGORIES[UI.catIndex]))

    local amount = InputBox(body, 60)
    amount:SetPoint("LEFT", cat, "RIGHT", 52, 0)
    amount:SetNumeric(true)
    amount.glAcceptLinks = nil
    local aml = Text(body, "GameFontDisableSmall")
    aml:SetPoint("RIGHT", amount, "LEFT", -8, 0)
    aml:SetText(T"Valor")

    local desc = InputBox(body, W - 100)
    desc:SetPoint("TOPLEFT", cat, "BOTTOMLEFT", 6, -6)
    local add = Button(body, T"Añadir", 70)
    add:SetPoint("LEFT", desc, "RIGHT", 6, 0)

    local function DoAdd()
        local m = UI.SelectedMember()
        if not m then return end
        local text = desc:GetText() or ""
        local val = tonumber(amount:GetText())
        if text == "" and not val then
            GL.Print(T"Escribe una descripción o un valor.")
            return
        end
        GL.AddContribution(m, GL.CATEGORIES[UI.catIndex], val, text)
        desc:SetText("")
        amount:SetText("")
        desc:ClearFocus(); amount:ClearFocus()
        UI.coffset = 0
        UI.Refresh()
    end
    add:SetScript("OnClick", DoAdd)
    desc:SetScript("OnEnterPressed", DoAdd)


    -- Lista de aportes
    local cl = Text(body, "GameFontNormal")
    cl:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", -6, -10)
    cl:SetText(T"Aportes registrados")
    UI.cTitle = cl

    local cbox = Panel(body)
    cbox:SetPoint("TOPLEFT", cl, "BOTTOMLEFT", -2, -2)
    cbox:SetSize(W - 16, CROWS * CROW_H + 10)
    cbox:EnableMouseWheel(true)
    cbox:SetScript("OnMouseWheel", function(_, delta)
        UI.coffset = math.max(0, UI.coffset - delta)
        UI.Refresh()
    end)

    UI.crows = {}
    for i = 1, CROWS do
        local r = CreateFrame("Button", nil, cbox)
        r:SetSize(W - 28, CROW_H)
        r:SetPoint("TOPLEFT", 6, -5 - (i - 1) * CROW_H)
        r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        r.date = Text(r); r.date:SetPoint("LEFT", 0, 0); r.date:SetWidth(62)
        r.cat = Text(r, "GameFontNormalSmall"); r.cat:SetPoint("LEFT", 62, 0); r.cat:SetWidth(84)
        r.val = Text(r, "GameFontHighlightSmall", "RIGHT"); r.val:SetPoint("LEFT", 146, 0); r.val:SetWidth(40)
        r.txt = Text(r); r.txt:SetPoint("LEFT", 192, 0); r.txt:SetWidth(130)
        local del = CreateFrame("Button", nil, r)
        del:SetSize(14, 14)
        del:SetPoint("RIGHT", 0, 0)
        del:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
        del:SetScript("OnClick", function()
            local m = UI.SelectedMember()
            if m and r.index and m.contributions[r.index] then
                UI.pendingDelete = { m = m, i = r.index }
                StaticPopup_Show("GUILDLEDGER_DELETE_CONTRIB")
            end
        end)
        r:SetScript("OnEnter", function(self)
            local m = UI.SelectedMember()
            local c = m and self.index and m.contributions[self.index]
            if not c then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(T(c.cat) .. (c.amount and ("  (" .. c.amount .. ")") or ""))
            if c.text ~= "" then GameTooltip:AddLine(c.text, 1, 1, 1, true) end
            GameTooltip:AddLine(GL.FormatDate(c.t, true) .. T" - anotado por " .. (c.by or "?"), 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        r:SetScript("OnLeave", GameTooltip_Hide)
        UI.crows[i] = r
    end

    -- Olvidar exmiembro
    local seeBank = Button(body, T"Ver banco", 80)
    seeBank:SetPoint("TOPRIGHT", -8, -8)
    seeBank:SetScript("OnClick", function()
        if UI.selected then
            UI.ShowText(T"Banco - " .. GL.ShortName(UI.selected), GL.BankText(UI.selected))
        end
    end)

    local forget = Button(body, T"Borrar ficha", 90)
    forget:SetPoint("RIGHT", seeBank, "LEFT", -4, 0)
    forget:SetScript("OnClick", function()
        if UI.selected then StaticPopup_Show("GUILDLEDGER_FORGET", GL.ShortName(UI.selected)) end
    end)
    UI.forget = forget
end

StaticPopupDialogs["GUILDLEDGER_DELETE_CONTRIB"] = {
    text = T"¿Borrar este aporte?",
    button1 = YES or T"Sí",
    button2 = NO or "No",
    OnAccept = function()
        local p = UI.pendingDelete
        if p then table.remove(p.m.contributions, p.i) end
        UI.pendingDelete = nil
        UI.Refresh()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

StaticPopupDialogs["GUILDLEDGER_FORGET"] = {
    text = T"¿Borrar toda la ficha de %s (notas y aportes incluidos)?",
    button1 = YES or T"Sí",
    button2 = NO or "No",
    OnAccept = function()
        local g = GL.GetGuildDB(false)
        if g and UI.selected then g.members[UI.selected] = nil end
        UI.selected = nil
        UI.Refresh()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

------------------------------------------------------------------------
-- Refresco
------------------------------------------------------------------------
function UI.SelectedMember()
    local g = GL.GetGuildDB(false)
    if not g or not UI.selected then return nil end
    return g.members[UI.selected]
end

function UI.Refresh()
    if not UI.frame or not UI.frame:IsShown() then return end
    local list, g = BuildList()

    if g then
        UI.title:SetText(T"Registro de Hermandad - |cffffffff" .. (g.name or "") .. "|r")
    else
        UI.title:SetText(T"Registro de Hermandad")
    end

    local maxOff = math.max(0, #list - ROWS)
    if UI.offset > maxOff then UI.offset = maxOff end
    for i = 1, ROWS do
        local r = UI.rows[i]
        local m = list[i + UI.offset]
        if m then
            r.memberName = m.name
            r.name:SetText(GL.ShortName(m.name))
            if m.left then r.name:SetTextColor(0.5, 0.5, 0.5) else r.name:SetTextColor(ClassColor(m.classFile)) end
            r.level:SetText(m.level or "")
            r.rank:SetText(m.left and T"|cff888888(exmiembro)|r" or (m.rank or ""))
            if m._cnt > 0 then
                r.points:SetText(m._cnt .. (m._sum ~= 0 and (" |cffffd100(" .. m._sum .. ")|r") or ""))
            else
                r.points:SetText("|cff666666-|r")
            end
            r.seen:SetText(m.online and T"|cff33ff33en línea|r" or Ago(m.lastOnline))
            r.dot:SetShown(m.online and true or false)
            r.sel:SetShown(m.name == UI.selected)
            r:Show()
        else
            r.memberName = nil
            r:Hide()
        end
    end

    if not g then
        UI.status:SetText(T"No estás en una hermandad, o el roster aún no ha cargado.")
    else
        local total, online, gone = 0, 0, 0
        for _, m in pairs(g.members) do
            if m.left then gone = gone + 1 else
                total = total + 1
                if m.online then online = online + 1 end
            end
        end
        local shown = #list > 0 and string.format(T"%d-%d de %d", UI.offset + 1, math.min(#list, UI.offset + ROWS), #list) or "0"
        UI.status:SetText(string.format(T"Mostrando %s  ·  %d miembros, %d en línea, %d exmiembros  ·  Último escaneo: %s",
            shown, total, online, gone, GL.FormatDate(g.scanned, true)))
    end

    UI.RefreshDetail()
end

function UI.RefreshDetail()
    local m = UI.SelectedMember()
    if not m then
        UI.body:Hide()
        UI.empty:Show()
        return
    end
    UI.empty:Hide()
    UI.body:Show()

    UI.dName:SetText(GL.ShortName(m.name))
    if m.left then UI.dName:SetTextColor(0.6, 0.6, 0.6) else UI.dName:SetTextColor(ClassColor(m.classFile)) end
    UI.forget:SetShown(m.left and true or false)

    local cnt, sum = GL.Totals(m)
    local lines = {
        string.format(T"Nivel %s %s  ·  %s", m.level or "?", m.class or "", m.left and (T"|cffff6666Dejó la hermandad el " .. GL.FormatDate(m.left) .. "|r") or (m.rank or "")),
        T"Zona: " .. (m.zone or "-") .. T"   ·   Última conexión: " .. (m.online and T"|cff33ff33en línea|r" or GL.FormatDate(m.lastOnline)),
        T"Registrado desde: " .. GL.FormatDate(m.firstSeen),
        T"Nota pública: |cffcccccc" .. ((m.publicNote and m.publicNote ~= "") and m.publicNote or "-") .. "|r",
    }
    if m.officerNote then lines[#lines + 1] = T"Nota oficial: |cffcccccc" .. m.officerNote .. "|r" end
    if m.bank then
        local s = m.bank
        lines[#lines + 1] = string.format(T"Banco: |cff33ff33+%s|r / |cffff6666-%s|r  ·  objetos |cff33ff33+%d|r / |cffff6666-%d|r",
            GL.Money(s.depGold), GL.Money(s.wdGold), s.depItems, s.wdItems)
    end
    if m.history and m.history[1] then
        lines[#lines + 1] = T"|cff888888Último cambio: " .. m.history[1].text .. " (" .. GL.FormatDate(m.history[1].t) .. ")|r"
    end
    UI.dInfo:SetText(table.concat(lines, "\n"))

    if not UI.dNotes.edit:HasFocus() then
        UI.dNotes.edit:SetText(m.notes or "")
    end

    UI.cTitle:SetText(string.format(T"Aportes registrados: %d  ·  Valor total: %d", cnt, sum))
    local maxOff = math.max(0, cnt - CROWS)
    if UI.coffset > maxOff then UI.coffset = maxOff end
    for i = 1, CROWS do
        local r = UI.crows[i]
        local idx = i + UI.coffset
        local c = m.contributions[idx]
        if c then
            r.index = idx
            r.date:SetText(GL.FormatDate(c.t))
            r.cat:SetText(T(c.cat))
            r.val:SetText(c.amount or "")
            r.txt:SetText(c.text)
            r:Show()
        else
            r.index = nil
            r:Hide()
        end
    end
end

------------------------------------------------------------------------
-- Ventana de texto (exportar / historial)
------------------------------------------------------------------------
function UI.ShowText(title, text)
    if not UI.textFrame then
        local t = Make("Frame", "GuildLedgerTextFrame", UIParent, "BackdropTemplate")
        Skin(t)
        t:SetSize(640, 440)
        t:SetPoint("CENTER", 0, 20)
        t:SetFrameStrata("DIALOG")
        t:SetMovable(true)
        t:EnableMouse(true)
        t:RegisterForDrag("LeftButton")
        t:SetScript("OnDragStart", t.StartMoving)
        t:SetScript("OnDragStop", t.StopMovingOrSizing)
        tinsert(UISpecialFrames, "GuildLedgerTextFrame")
        local tt = Text(t, "GameFontNormalLarge")
        tt:SetPoint("TOPLEFT", 14, -12)
        t.title = tt
        local close = Make("Button", nil, t, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)
        close:SetScript("OnClick", function() t:Hide() end)
        local box = MultiLine(t, 612, 380)
        box:SetPoint("TOPLEFT", 14, -40)
        box.edit.glAcceptLinks = nil
        t.box = box
        UI.textFrame = t
    end
    local t = UI.textFrame
    t.title:SetText(title)
    t.box.edit:SetText(text)
    t:Show()
    t.box.edit:SetFocus()
    t.box.edit:HighlightText()
end

------------------------------------------------------------------------
function UI.Toggle()
    UI.Build()
    if UI.frame:IsShown() then
        UI.frame:Hide()
    else
        UI.frame:Show()
        GL.RequestRoster()
        GL.Scan(true)
        UI.Refresh()
    end
end

------------------------------------------------------------------------
-- Shift+clic en un objeto (o hechizo, misión...) copia su nombre en la
-- casilla de texto del addon que tenga el foco.
------------------------------------------------------------------------
local lastLink, lastTime

local function OnInsertLink(link)
    if type(link) ~= "string" then return end
    local eb = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if not eb or not eb.glAcceptLinks then return end
    -- Evita insertar dos veces si el juego llama a las dos funciones enganchadas.
    local now = GetTime()
    if link == lastLink and lastTime == now then return end
    lastLink, lastTime = link, now

    local name = link:match("|h%[(.-)%]|h") or link:match("^%[(.-)%]$") or link
    eb:Insert(name)
    -- Con el foco en el addon, el Shift+clic en la bolsa abriría además la
    -- ventana de dividir montón; la cerramos.
    C_Timer.After(0, function()
        if StackSplitFrame and StackSplitFrame:IsShown() then StackSplitFrame:Hide() end
    end)
end

if ChatFrameUtil and ChatFrameUtil.InsertLink then
    hooksecurefunc(ChatFrameUtil, "InsertLink", OnInsertLink)
end
if ChatEdit_InsertLink then
    hooksecurefunc("ChatEdit_InsertLink", OnInsertLink)
end
