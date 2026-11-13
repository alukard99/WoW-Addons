-- Artesanos: ventana del mercado.
--   Mercado      todas las ofertas de la hermandad, con el icono de lo que se fabrica, sus
--                materiales en pequeño y el precio; a la derecha, el detalle con cada material.
--   Jugadores    la lista de la hermandad con las profesiones y ofertas de cada uno.
--   Mis ofertas  tus ofertas, con su precio y su nota.
local ADDON, ns = ...
local T = ns.T
local A = ns.A
local UI = {}
A.UI = UI

local W, H = 900, 560
local LIST_W = 540
local ROWS, ROW_H = 11, 38
local PROWS, PROW_H = 20, 20
local MAX_MINI = 6  -- materiales en pequeño en cada fila
local MAX_REAG = 8  -- materiales en el detalle

UI.tab = "market"
UI.offset = 0
UI.poffset = 0
UI.filter = ""
UI.pfilter = ""
UI.onlyOnline = false
UI.ponlyOnline = false
UI.onlyCrafters = true
UI.prof = nil     -- profesión elegida en el filtro
UI.crafter = nil  -- ver solo las ofertas de este jugador
UI.selected = nil -- oferta elegida ("Nombre-Reino#receta")
UI.player = nil   -- jugador elegido en la pestaña Jugadores

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
        f:SetBackdropColor(0.05, 0.05, 0.08, a or 0.94)
        f:SetBackdropBorderColor(0.6, 0.5, 0.3, 1)
    else
        local bg = f:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.05, 0.05, 0.08, a or 0.94)
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
    return e
end

local function Check(parent, label, onClick)
    local c = Make("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(22, 22)
    local t = Text(c, "GameFontNormalSmall")
    t:SetPoint("LEFT", c, "RIGHT", 2, 0)
    t:SetText(label)
    c.label = t
    c:SetScript("OnClick", function(self) onClick(self:GetChecked() and true or false) end)
    return c
end

local function Hex(r, g, b)
    return string.format("|cff%02x%02x%02x", r * 255, g * 255, b * 255)
end

local function ClassFile(name)
    local r = A.roster[name]
    if r and r.classFile then return r.classFile end
    local c = A.Crafter(name, false)
    return c and c.classFile
end

local function ColoredName(name)
    return Hex(A.ClassColor(ClassFile(name))) .. A.Short(name) .. "|r"
end

local function Icon(icon, size)
    return "|T" .. tostring(icon or A.QUESTION) .. ":" .. (size or 16) .. ":" .. (size or 16) .. ":0:0:64:64:5:59:5:59|t"
end

local function StateText(name)
    if A.IsOnline(name) then return T"|cff33ff33en línea|r" end
    local r = A.roster[name]
    return "|cff888888" .. A.Ago(r and r.lastOnline) .. "|r"
end

local function PriceText(o)
    if (o.price or 0) <= 0 then return T"|cff33ff33Gratis para la hermandad|r" end
    return A.Money(o.price)
end

-- Botón con el icono de un objeto: tooltip al pasar el ratón y Shift+clic para enlazarlo.
local function ItemButton(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    b.count:SetPoint("BOTTOMRIGHT", 2, -1)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetScript("OnEnter", function(self)
        if not self.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if not pcall(GameTooltip.SetItemByID, GameTooltip, self.itemID) then
            GameTooltip:SetText(A.ItemInfo(self.itemID) or "?")
        end
        if self.need then GameTooltip:AddLine(string.format(T"Hacen falta: %d", self.need), 1, 1, 1) end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", GameTooltip_Hide)
    b:SetScript("OnClick", function(self)
        if self.itemID and IsModifiedClick("CHATLINK") then
            local name, link = A.ItemInfo(self.itemID)
            A.InsertLink(link or name)
        end
    end)
    return b
end

local function OfferTooltip(owner, e)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local ok
    if e.o.item and e.o.item > 0 then
        ok = pcall(GameTooltip.SetItemByID, GameTooltip, e.o.item)
    else
        ok = pcall(GameTooltip.SetSpellByID, GameTooltip, e.o.recipe)
    end
    if not ok then GameTooltip:SetText(e.name or "?") end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(T"Artesano: " .. ColoredName(e.by) .. "  " .. StateText(e.by), 1, 0.82, 0)
    GameTooltip:AddLine(T"Precio: " .. PriceText(e.o), 1, 0.82, 0)
    GameTooltip:AddLine(T"Shift+clic: enlazar en el chat", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end

------------------------------------------------------------------------
-- Datos
------------------------------------------------------------------------
local function Entry(by, o)
    local name, link, quality, icon = A.OfferInfo(o)
    return {
        o = o, by = by, key = by .. "#" .. o.recipe, name = name, link = link,
        quality = quality, icon = icon, online = A.IsOnline(by),
    }
end

local function Matches(e, f)
    if f == "" then return true end
    if (e.name or ""):lower():find(f, 1, true) then return true end
    if A.Short(e.by):lower():find(f, 1, true) then return true end
    if A.ProfessionName(e.o.skill):lower():find(f, 1, true) then return true end
    if (e.o.note or ""):lower():find(f, 1, true) then return true end
    for _, g in ipairs(e.o.reagents or {}) do
        local n = A.ItemInfo(g[1])
        if n and n:lower():find(f, 1, true) then return true end
    end
    return false
end

local function CollectOffers()
    local list, profs, seen = {}, {}, {}
    local g = A.Guild(false)
    if not g then return list, profs end
    local me = A.Me()
    local crafters = 0
    -- En Mis ofertas no se aplican los filtros del Mercado (allí no se ven).
    local mine = UI.tab == "mine"
    local onlyOnline, prof, filter = not mine and UI.onlyOnline, not mine and UI.prof, mine and "" or UI.filter
    for by, c in pairs(g.crafters) do
        local inScope = A.InGuild(by) and (UI.tab ~= "mine" or by == me)
            and (UI.tab == "mine" or not UI.crafter or by == UI.crafter)
        if inScope then
            local any = false
            for _, o in pairs(c.offers) do
                local skill = o.skill or 0
                if not seen[skill] then
                    seen[skill] = true
                    profs[#profs + 1] = skill
                end
                local e = Entry(by, o)
                if (not onlyOnline or e.online) and (not prof or skill == prof) and Matches(e, filter) then
                    list[#list + 1] = e
                    any = true
                end
            end
            if any then crafters = crafters + 1 end
        end
    end
    table.sort(list, function(a, b)
        local na, nb = (a.name or ""):lower(), (b.name or ""):lower()
        if na ~= nb then return na < nb end
        if a.online ~= b.online then return a.online end
        if (a.o.price or 0) ~= (b.o.price or 0) then return (a.o.price or 0) < (b.o.price or 0) end
        return a.by < b.by
    end)
    table.sort(profs, function(x, y) return A.ProfessionName(x) < A.ProfessionName(y) end)
    return list, profs, crafters
end

local function FindOffer(key)
    if not key then return nil end
    local by, recipe = key:match("^(.*)#(%d+)$")
    local c = by and A.Crafter(by, false)
    local o = c and c.offers[tonumber(recipe)]
    return o and Entry(by, o)
end

local function PlayerOffers(name)
    local c = A.Crafter(name, false)
    local list, profs, seen = {}, {}, {}
    if not c then return list, profs end
    for _, o in pairs(c.offers) do
        list[#list + 1] = Entry(name, o)
        local s = o.skill or 0
        if not seen[s] then
            seen[s] = true
            profs[#profs + 1] = A.ProfessionName(s)
        end
    end
    table.sort(list, function(a, b) return (a.name or ""):lower() < (b.name or ""):lower() end)
    table.sort(profs)
    return list, profs
end

local function CollectPlayers()
    local list = {}
    local me = A.Me()
    local names = {}
    for name in pairs(A.roster) do names[name] = true end
    local g = A.Guild(false)
    if g and not A.rosterLoaded then
        for name in pairs(g.crafters) do names[name] = true end
    end
    local f = UI.pfilter
    for name in pairs(names) do
        local offers, profs = PlayerOffers(name)
        local p = {
            name = name, roster = A.roster[name], count = #offers, profs = profs,
            online = A.IsOnline(name),
            addon = name == me or A.Comm.users[name] ~= nil or (A.Crafter(name, false) or {}).seen ~= nil,
        }
        local ok = (not UI.ponlyOnline or p.online) and (not UI.onlyCrafters or p.count > 0)
        if ok and f ~= "" then
            local hay = (A.Short(name) .. " " .. table.concat(profs, " ")):lower()
            ok = hay:find(f, 1, true) ~= nil
        end
        if ok then list[#list + 1] = p end
    end
    table.sort(list, function(a, b)
        if a.online ~= b.online then return a.online end
        if a.count ~= b.count then return a.count > b.count end
        return a.name < b.name
    end)
    return list
end

------------------------------------------------------------------------
-- Ventana
------------------------------------------------------------------------
function UI.Build()
    if UI.frame then return end
    local f = Make("Frame", "ArtesanosFrame", UIParent, "BackdropTemplate")
    Skin(f)
    f:SetSize(W, H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    f:Hide()
    tinsert(UISpecialFrames, "ArtesanosFrame")
    UI.frame = f

    local logo = f:CreateTexture(nil, "ARTWORK")
    logo:SetSize(22, 22)
    logo:SetPoint("TOPLEFT", 12, -9)
    logo:SetTexture("Interface\\Icons\\Trade_BlackSmithing")
    logo:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    UI.title = Text(f, "GameFontNormalLarge")
    UI.title:SetPoint("LEFT", logo, "RIGHT", 6, 0)

    local close = Make("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -2, -2)
    close:SetScript("OnClick", function() f:Hide() end)

    -- Pestañas: la activa queda desactivada para que se vea cuál es.
    UI.tabs = {}
    local prev
    for _, t in ipairs({ { "market", T"Mercado" }, { "players", T"Jugadores" }, { "mine", T"Mis ofertas" } }) do
        local b = Button(f, t[2], 100)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("TOPLEFT", 14, -36) end
        b:SetScript("OnClick", function() UI.SetTab(t[1]) end)
        UI.tabs[t[1]] = b
        prev = b
    end

    UI.status = Text(f, "GameFontDisableSmall")
    UI.status:SetPoint("BOTTOMLEFT", 16, 12)
    UI.status:SetWidth(LIST_W)

    UI.BuildOffers()
    UI.BuildPlayers()
    UI.BuildDetail()
end

------------------------------------------------------------------------
-- Pestañas Mercado y Mis ofertas
------------------------------------------------------------------------
function UI.BuildOffers()
    local v = CreateFrame("Frame", nil, UI.frame)
    v:SetPoint("TOPLEFT", 0, -62)
    v:SetSize(LIST_W + 20, H - 62)
    UI.offersView = v

    -- Barra del Mercado: buscar, profesión, solo conectados y el filtro de artesano.
    local bar = CreateFrame("Frame", nil, v)
    bar:SetAllPoints()
    UI.marketBar = bar

    local search = InputBox(bar, 150)
    search:SetPoint("TOPLEFT", 20, -8)
    search:SetScript("OnTextChanged", function(self)
        UI.filter = (self:GetText() or ""):lower()
        UI.offset = 0
        UI.Refresh()
    end)
    local sl = Text(bar, "GameFontDisableSmall")
    sl:SetPoint("BOTTOMLEFT", search, "TOPLEFT", -4, 1)
    sl:SetText(T"Buscar (objeto, material, artesano)")
    UI.search = search

    local prof = Button(bar, "", 150)
    prof:SetPoint("LEFT", search, "RIGHT", 10, 0)
    prof:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    prof:SetScript("OnClick", function(_, btn)
        local profs = UI.profs or {}
        local i = 0
        for k, s in ipairs(profs) do
            if s == UI.prof then i = k end
        end
        local n = #profs + 1
        i = (btn == "RightButton") and ((i - 1) % n) or ((i + 1) % n)
        UI.prof = profs[i] -- el 0 no existe en la lista: todas
        UI.offset = 0
        UI.Refresh()
    end)
    prof:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(T"Profesión")
        GameTooltip:AddLine(T"Clic izq./der. para cambiar", 1, 1, 1)
        GameTooltip:Show()
    end)
    prof:SetScript("OnLeave", GameTooltip_Hide)
    UI.profButton = prof

    local online = Check(bar, T"Solo conectados", function(on)
        UI.onlyOnline = on
        UI.offset = 0
        UI.Refresh()
    end)
    online:SetPoint("LEFT", prof, "RIGHT", 8, 0)

    local chip = CreateFrame("Frame", nil, bar)
    chip:SetSize(LIST_W, 18)
    chip:SetPoint("TOPLEFT", 16, -32)
    chip.text = Text(chip, "GameFontNormalSmall")
    chip.text:SetPoint("LEFT", 4, 0)
    local clear = Button(chip, T"Ver todos", 80, 18)
    clear:SetPoint("LEFT", chip.text, "RIGHT", 8, 0)
    clear:SetScript("OnClick", function()
        UI.crafter = nil
        UI.offset = 0
        UI.Refresh()
    end)
    UI.chip = chip

    -- Barra de Mis ofertas: casilla para Shift+clic y hueco para arrastrar objetos.
    local mine = CreateFrame("Frame", nil, v)
    mine:SetAllPoints()
    UI.mineBar = mine

    local drop = CreateFrame("Button", nil, mine)
    drop:SetSize(36, 36)
    drop:SetPoint("TOPLEFT", 16, -4)
    drop.icon = drop:CreateTexture(nil, "ARTWORK")
    drop.icon:SetAllPoints()
    drop.icon:SetTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
    drop:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    local function Dropped()
        local kind, id, link = GetCursorInfo()
        if kind ~= "item" then return end
        ClearCursor()
        UI.PublishLink(link or ("item:" .. id))
    end
    drop:SetScript("OnReceiveDrag", Dropped)
    drop:SetScript("OnClick", Dropped)
    drop:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(T"Arrastra aquí un objeto que sepas fabricar")
        GameTooltip:Show()
    end)
    drop:SetScript("OnLeave", GameTooltip_Hide)

    local add = InputBox(mine, 200)
    add:SetPoint("LEFT", drop, "RIGHT", 12, 0)
    add.artesanosAdd = true
    add:SetScript("OnTextChanged", function(self, user)
        if user then self:SetText("") end -- solo admite enlaces (Shift+clic)
    end)
    local addLabel = Text(mine, "GameFontDisableSmall")
    addLabel:SetPoint("BOTTOMLEFT", add, "TOPLEFT", -4, 1)
    addLabel:SetText(T"Clic aquí y Shift+clic en un objeto")

    local help = mine:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    help:SetPoint("LEFT", add, "RIGHT", 12, 0)
    help:SetWidth(LIST_W - 270)
    help:SetJustifyH("LEFT")
    help:SetText(T"o abre tu profesión, elige una receta y pulsa |cffffd100Ofrecer en el mercado|r.")

    -- Lista de ofertas
    local list = Panel(v)
    list:SetPoint("TOPLEFT", 12, -54)
    list:SetSize(LIST_W, ROWS * ROW_H + 10)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        UI.offset = math.max(0, UI.offset - delta * 2)
        UI.Refresh()
    end)

    UI.emptyList = list:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    UI.emptyList:SetPoint("CENTER")
    UI.emptyList:SetWidth(LIST_W - 60)

    UI.rows = {}
    for i = 1, ROWS do
        local r = CreateFrame("Button", nil, list)
        r:SetSize(LIST_W - 12, ROW_H)
        r:SetPoint("TOPLEFT", 6, -5 - (i - 1) * ROW_H)
        r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        r.sel = r:CreateTexture(nil, "BACKGROUND")
        r.sel:SetAllPoints()
        r.sel:SetColorTexture(0.9, 0.7, 0.3, 0.18)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(32, 32)
        r.icon:SetPoint("LEFT", 3, 0)
        r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        r.name = Text(r, "GameFontNormal")
        r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 7, -1)
        r.name:SetWidth(320)
        r.price = Text(r, "GameFontHighlightSmall", "RIGHT")
        r.price:SetPoint("TOPRIGHT", -6, -4)
        r.price:SetWidth(160)
        r.dot = r:CreateTexture(nil, "OVERLAY")
        r.dot:SetSize(6, 6)
        r.dot:SetColorTexture(0.2, 1, 0.2, 1)
        r.dot:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 7, 4)
        r.by = Text(r, "GameFontHighlightSmall")
        r.by:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 16, 1)
        r.by:SetWidth(230)
        r.mini = {}
        for k = 1, MAX_MINI do r.mini[k] = ItemButton(r, 18) end
        r.more = Text(r, "GameFontDisableSmall")
        r.more:SetPoint("BOTTOMRIGHT", -6, 5)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetScript("OnClick", function(self)
            local e = self.entry
            if not e then return end
            if IsModifiedClick("CHATLINK") then
                A.InsertLink(e.link or e.name)
                return
            end
            UI.selected = e.key
            UI.Refresh()
        end)
        r:SetScript("OnEnter", function(self) if self.entry then OfferTooltip(self, self.entry) end end)
        r:SetScript("OnLeave", GameTooltip_Hide)
        UI.rows[i] = r
    end
end

local function SetRow(r, e)
    r.entry = e
    local o = e.o
    r.icon:SetTexture(e.icon or A.QUESTION)
    local qty = (o.qty or 1) > 1 and (" |cffffffffx" .. o.qty .. "|r") or ""
    r.name:SetText(A.QualityHex(e.quality) .. (e.name or "?") .. "|r" .. qty)
    r.price:SetText((o.mats and T"|cff999999con materiales|r  " or "") .. A.Money(o.price))
    r.by:SetText(A.Short(e.by) .. " |cff888888· " .. A.ProfessionName(o.skill) .. "|r")
    r.by:SetTextColor(A.ClassColor(ClassFile(e.by)))
    r.dot:SetShown(e.online and true or false)

    local reag = o.reagents or {}
    local shown = math.min(#reag, MAX_MINI)
    local extra = #reag > shown and 22 or 0
    for k = 1, MAX_MINI do
        local b = r.mini[k]
        local g = reag[k]
        if k <= shown then
            local _, _, _, icon = A.ItemInfo(g[1])
            b.itemID, b.need = g[1], g[2]
            b.icon:SetTexture(icon)
            b.count:SetText(g[2] > 1 and g[2] or "")
            b:ClearAllPoints()
            b:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -6 - extra - (shown - k) * 21, 2)
            b:Show()
        else
            b.itemID = nil
            b:Hide()
        end
    end
    r.more:SetText(extra > 0 and ("+" .. (#reag - shown)) or "")
    r.sel:SetShown(e.key == UI.selected)
end

function UI.RefreshOffers()
    local list, profs, crafters = CollectOffers()
    UI.profs = profs
    UI.list = list

    local mine = UI.tab == "mine"
    UI.marketBar:SetShown(not mine)
    UI.mineBar:SetShown(mine)
    UI.profButton:SetText(T"Profesión: " .. (UI.prof and A.ProfessionName(UI.prof) or T"todas"))
    if UI.crafter and not mine then
        UI.chip.text:SetText(T"Ofertas de " .. ColoredName(UI.crafter))
        UI.chip:Show()
    else
        UI.chip:Hide()
    end

    local maxOff = math.max(0, #list - ROWS)
    if UI.offset > maxOff then UI.offset = maxOff end
    for i = 1, ROWS do
        local e = list[i + UI.offset]
        if e then
            SetRow(UI.rows[i], e)
            UI.rows[i]:Show()
        else
            UI.rows[i].entry = nil
            UI.rows[i]:Hide()
        end
    end

    if #list > 0 then
        UI.emptyList:SetText("")
    elseif not A.Guild(false) then
        UI.emptyList:SetText(T"No estás en una hermandad, o la hermandad aún no ha cargado.")
    elseif mine then
        UI.emptyList:SetText(T"Aún no ofreces nada.\n\nAbre tu profesión, elige una receta y pulsa |cffffd100Ofrecer en el mercado|r, o arrastra aquí arriba un objeto que sepas fabricar.")
    elseif UI.filter ~= "" or UI.prof or UI.onlyOnline or UI.crafter then
        UI.emptyList:SetText(T"Ninguna oferta coincide con el filtro.")
    else
        UI.emptyList:SetText(T"Todavía no hay ofertas en la hermandad.\n\nLas ofertas aparecen cuando otros miembros con el addon publican lo que saben fabricar.")
    end

    if #list > 0 then
        UI.status:SetText(string.format(T"Mostrando %d-%d de %d ofertas de %d artesanos",
            UI.offset + 1, math.min(#list, UI.offset + ROWS), #list, crafters or 0))
    else
        UI.status:SetText("")
    end
end

-- Muestra en la lista la oferta elegida.
local function ScrollToSelected()
    for i, e in ipairs(UI.list or {}) do
        if e.key == UI.selected then
            if i <= UI.offset or i > UI.offset + ROWS then UI.offset = math.max(0, i - math.ceil(ROWS / 2)) end
            return
        end
    end
end

function UI.PublishLink(link)
    local o = A.PublishFromLink(link)
    if o then
        UI.selected = A.Me() .. "#" .. o.recipe
        UI.Refresh()
        ScrollToSelected()
        UI.Refresh()
    end
end

------------------------------------------------------------------------
-- Pestaña Jugadores
------------------------------------------------------------------------
function UI.BuildPlayers()
    local v = CreateFrame("Frame", nil, UI.frame)
    v:SetPoint("TOPLEFT", 0, -62)
    v:SetSize(LIST_W + 20, H - 62)
    UI.playersView = v

    local search = InputBox(v, 150)
    search:SetPoint("TOPLEFT", 20, -8)
    search:SetScript("OnTextChanged", function(self)
        UI.pfilter = (self:GetText() or ""):lower()
        UI.poffset = 0
        UI.Refresh()
    end)
    local sl = Text(v, "GameFontDisableSmall")
    sl:SetPoint("BOTTOMLEFT", search, "TOPLEFT", -4, 1)
    sl:SetText(T"Buscar (nombre, profesión)")

    local online = Check(v, T"Solo conectados", function(on)
        UI.ponlyOnline = on
        UI.poffset = 0
        UI.Refresh()
    end)
    online:SetPoint("LEFT", search, "RIGHT", 10, 0)
    local crafters = Check(v, T"Solo con ofertas", function(on)
        UI.onlyCrafters = on
        UI.poffset = 0
        UI.Refresh()
    end)
    crafters:SetPoint("LEFT", online, "RIGHT", 110, 0)
    crafters:SetChecked(UI.onlyCrafters)

    local list = Panel(v)
    list:SetPoint("TOPLEFT", 12, -54)
    list:SetSize(LIST_W, PROWS * PROW_H + 30)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        UI.poffset = math.max(0, UI.poffset - delta * 3)
        UI.Refresh()
    end)

    UI.emptyPlayers = list:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    UI.emptyPlayers:SetPoint("CENTER")
    UI.emptyPlayers:SetWidth(LIST_W - 60)

    local cols = {
        { T"Nombre", 12, 130 }, { T"Nv", 146, 28 }, { T"Profesiones", 178, 220 },
        { T"Ofertas", 402, 50 }, { T"Visto", 456, 76 },
    }
    for _, c in ipairs(cols) do
        local t = Text(list, "GameFontNormalSmall")
        t:SetPoint("TOPLEFT", c[2], -7)
        t:SetWidth(c[3])
        t:SetText(c[1])
    end

    UI.prows = {}
    for i = 1, PROWS do
        local r = CreateFrame("Button", nil, list)
        r:SetSize(LIST_W - 12, PROW_H)
        r:SetPoint("TOPLEFT", 6, -24 - (i - 1) * PROW_H)
        r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        r.sel = r:CreateTexture(nil, "BACKGROUND")
        r.sel:SetAllPoints()
        r.sel:SetColorTexture(0.9, 0.7, 0.3, 0.18)
        r.dot = r:CreateTexture(nil, "OVERLAY")
        r.dot:SetSize(6, 6)
        r.dot:SetPoint("LEFT", 0, 0)
        r.dot:SetColorTexture(0.2, 1, 0.2, 1)
        r.name = Text(r); r.name:SetPoint("LEFT", 6, 0); r.name:SetWidth(130)
        r.level = Text(r); r.level:SetPoint("LEFT", 140, 0); r.level:SetWidth(28)
        r.profs = Text(r); r.profs:SetPoint("LEFT", 172, 0); r.profs:SetWidth(220)
        r.count = Text(r); r.count:SetPoint("LEFT", 396, 0); r.count:SetWidth(50)
        r.seen = Text(r); r.seen:SetPoint("LEFT", 450, 0); r.seen:SetWidth(76)
        r:SetScript("OnClick", function(self)
            UI.player = self.playerName
            UI.Refresh()
        end)
        r:SetScript("OnDoubleClick", function(self) UI.ShowCrafter(self.playerName) end)
        UI.prows[i] = r
    end
end

function UI.RefreshPlayers()
    local list = CollectPlayers()
    local maxOff = math.max(0, #list - PROWS)
    if UI.poffset > maxOff then UI.poffset = maxOff end
    for i = 1, PROWS do
        local r = UI.prows[i]
        local p = list[i + UI.poffset]
        if p then
            r.playerName = p.name
            r.name:SetText(A.Short(p.name))
            r.name:SetTextColor(A.ClassColor(ClassFile(p.name)))
            r.level:SetText(p.roster and p.roster.level or "")
            r.profs:SetText(#p.profs > 0 and table.concat(p.profs, ", ") or (p.addon and T"|cff888888(sin ofertas)|r" or ""))
            r.count:SetText(p.count > 0 and p.count or "|cff666666-|r")
            r.seen:SetText(StateText(p.name))
            r.dot:SetShown(p.online and true or false)
            r.sel:SetShown(p.name == UI.player)
            r:Show()
        else
            r.playerName = nil
            r:Hide()
        end
    end
    if #list > 0 then
        UI.emptyPlayers:SetText("")
    elseif not A.rosterLoaded then
        UI.emptyPlayers:SetText(T"La lista de la hermandad aún no ha cargado.")
    elseif UI.onlyCrafters and UI.pfilter == "" and not UI.ponlyOnline then
        UI.emptyPlayers:SetText(T"Nadie ha publicado ofertas todavía. Desmarca «Solo con ofertas» para ver a toda la hermandad.")
    else
        UI.emptyPlayers:SetText(T"Nadie coincide con el filtro.")
    end
    local total, online, users = 0, 0, 0
    for name, r in pairs(A.roster) do
        total = total + 1
        if r.online then online = online + 1 end
        if name == A.Me() or A.Comm.users[name] then users = users + 1 end
    end
    UI.status:SetText(string.format(T"%d miembros, %d en línea · %d con el addon conectados en esta sesión", total, online, users))
end

function UI.ShowCrafter(name)
    if not name then return end
    UI.crafter = name
    UI.filter = ""
    if UI.search then UI.search:SetText("") end
    UI.prof = nil
    UI.SetTab(name == A.Me() and "mine" or "market")
end

------------------------------------------------------------------------
-- Panel de detalle (oferta o jugador)
------------------------------------------------------------------------
function UI.BuildDetail()
    local d = Panel(UI.frame)
    d:SetPoint("TOPLEFT", LIST_W + 20, -62)
    d:SetPoint("BOTTOMRIGHT", -12, 14)
    UI.detail = d
    local DW = W - LIST_W - 32 - 20

    UI.emptyDetail = d:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    UI.emptyDetail:SetPoint("CENTER")
    UI.emptyDetail:SetWidth(DW - 20)

    -- Oferta
    local ob = CreateFrame("Frame", nil, d)
    ob:SetAllPoints()
    UI.offerBody = ob

    local big = ItemButton(ob, 40)
    big:SetPoint("TOPLEFT", 10, -10)
    big:SetScript("OnEnter", function(self) if UI.current then OfferTooltip(self, UI.current) end end)
    big:SetScript("OnClick", function()
        local e = UI.current
        if e and IsModifiedClick("CHATLINK") then A.InsertLink(e.link or e.name) end
    end)
    UI.dIcon = big

    UI.dName = ob:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    UI.dName:SetPoint("TOPLEFT", big, "TOPRIGHT", 8, 0)
    UI.dName:SetWidth(DW - 60)
    UI.dName:SetJustifyH("LEFT")
    UI.dName:SetMaxLines(2)

    UI.dSub = Text(ob, "GameFontHighlightSmall")
    UI.dSub:SetPoint("BOTTOMLEFT", big, "BOTTOMRIGHT", 8, 0)
    UI.dSub:SetWidth(DW - 60)

    UI.dInfo = ob:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    UI.dInfo:SetPoint("TOPLEFT", big, "BOTTOMLEFT", 0, -10)
    UI.dInfo:SetWidth(DW)
    UI.dInfo:SetJustifyH("LEFT")
    UI.dInfo:SetSpacing(3)

    local rh = Text(ob, "GameFontNormal")
    rh:SetPoint("TOPLEFT", UI.dInfo, "BOTTOMLEFT", 0, -10)
    rh:SetText(T"Materiales")
    UI.dReagHeader = rh

    UI.reag = {}
    for i = 1, MAX_REAG do
        local b = ItemButton(ob, 20)
        b:SetPoint("TOPLEFT", rh, "BOTTOMLEFT", 2, -4 - (i - 1) * 23)
        b.text = Text(ob, "GameFontHighlightSmall")
        b.text:SetPoint("LEFT", b, "RIGHT", 6, 0)
        b.text:SetWidth(DW - 40)
        UI.reag[i] = b
    end

    -- Botones para las ofertas de otros
    local whisper = Button(ob, T"Susurrar", 100)
    whisper:SetPoint("BOTTOMLEFT", 10, 10)
    whisper:SetScript("OnClick", function()
        local e = UI.current
        if e then A.Whisper(e.by, string.format(T"Hola, ¿me puedes fabricar %s?", e.link or e.name)) end
    end)
    UI.bWhisper = whisper
    local link = Button(ob, T"Enlazar", 90)
    link:SetPoint("LEFT", whisper, "RIGHT", 6, 0)
    link:SetScript("OnClick", function()
        local e = UI.current
        if e then A.InsertLink(e.link or e.name) end
    end)
    UI.bLink = link
    local others = Button(ob, T"Más de este artesano", 150)
    others:SetPoint("BOTTOMLEFT", whisper, "TOPLEFT", 0, 4)
    others:SetScript("OnClick", function()
        if UI.current then UI.ShowCrafter(UI.current.by) end
    end)
    UI.bOthers = others

    -- Editor de las ofertas propias
    local ed = CreateFrame("Frame", nil, ob)
    ed:SetPoint("BOTTOMLEFT", 0, 0)
    ed:SetSize(DW + 20, 128)
    UI.editor = ed

    local sep = ed:CreateTexture(nil, "ARTWORK")
    sep:SetColorTexture(0.6, 0.5, 0.3, 0.4)
    sep:SetPoint("TOPLEFT", 8, 0)
    sep:SetSize(DW + 4, 1)

    local free = Check(ed, T"Gratis para la hermandad", function(on)
        if UI.ePrice.SetEnabled then UI.ePrice:SetEnabled(not on) end
        if on then UI.ePrice:SetText("") end
    end)
    free:SetPoint("TOPLEFT", 8, -6)
    UI.eFree = free

    local pl = Text(ed, "GameFontNormalSmall")
    pl:SetPoint("TOPLEFT", 14, -36)
    pl:SetText(T"Precio (oro):")
    local price = InputBox(ed, 60)
    price:SetPoint("LEFT", pl, "RIGHT", 10, 0)
    price:SetMaxLetters(7)
    UI.ePrice = price

    local mats = Check(ed, T"Yo pongo los materiales", function() end)
    mats:SetPoint("LEFT", price, "RIGHT", 10, 0)
    UI.eMats = mats

    local nl = Text(ed, "GameFontNormalSmall")
    nl:SetPoint("TOPLEFT", 14, -62)
    nl:SetText(T"Nota:")
    local note = InputBox(ed, DW - 50)
    note:SetPoint("LEFT", nl, "RIGHT", 10, 0)
    note:SetMaxLetters(A.MAX_NOTE)
    UI.eNote = note

    local save = Button(ed, T"Guardar", 90)
    save:SetPoint("BOTTOMLEFT", 10, 10)
    save:SetScript("OnClick", function()
        local e = UI.current
        if not e then return end
        local copper = 0
        if not UI.eFree:GetChecked() then
            local gold = tonumber(((UI.ePrice:GetText() or ""):gsub(",", "."))) or 0
            copper = math.floor(gold * 10000 + 0.5)
        end
        UI.ePrice:ClearFocus()
        UI.eNote:ClearFocus()
        A.SaveOffer(e.o.recipe, copper, UI.eMats:GetChecked(), UI.eNote:GetText() or "")
        UI.editKey = nil
        A.Print(T"Oferta guardada. Se enviará a la hermandad en unos segundos.")
    end)
    price:SetScript("OnEnterPressed", function() save:Click() end)
    note:SetScript("OnEnterPressed", function() save:Click() end)

    local remove = Button(ed, T"Quitar", 80)
    remove:SetPoint("BOTTOMRIGHT", -10, 10)
    remove:SetScript("OnClick", function()
        if UI.current then StaticPopup_Show("ARTESANOS_REMOVE", UI.current.name or "?") end
    end)
    local elink = Button(ed, T"Enlazar", 80)
    elink:SetPoint("RIGHT", remove, "LEFT", -6, 0)
    elink:SetScript("OnClick", function()
        local e = UI.current
        if e then A.InsertLink(e.link or e.name) end
    end)

    -- Jugador
    local pb = CreateFrame("Frame", nil, d)
    pb:SetAllPoints()
    UI.playerBody = pb

    UI.pName = Text(pb, "GameFontNormalLarge")
    UI.pName:SetPoint("TOPLEFT", 12, -12)
    UI.pName:SetWidth(DW)

    UI.pInfo = pb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    UI.pInfo:SetPoint("TOPLEFT", UI.pName, "BOTTOMLEFT", 0, -6)
    UI.pInfo:SetWidth(DW)
    UI.pInfo:SetJustifyH("LEFT")
    UI.pInfo:SetSpacing(3)

    UI.pOffers = pb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    UI.pOffers:SetPoint("TOPLEFT", UI.pInfo, "BOTTOMLEFT", 0, -10)
    UI.pOffers:SetWidth(DW)
    UI.pOffers:SetJustifyH("LEFT")
    UI.pOffers:SetSpacing(4)

    local see = Button(pb, T"Ver sus ofertas", 120)
    see:SetPoint("BOTTOMLEFT", 10, 10)
    see:SetScript("OnClick", function() UI.ShowCrafter(UI.player) end)
    UI.bSee = see
    local pw = Button(pb, T"Susurrar", 100)
    pw:SetPoint("LEFT", see, "RIGHT", 6, 0)
    pw:SetScript("OnClick", function()
        if UI.player then A.Whisper(UI.player, "") end
    end)
end

StaticPopupDialogs["ARTESANOS_REMOVE"] = {
    text = T"¿Quitar %s del mercado?",
    button1 = YES or T"Sí",
    button2 = NO or "No",
    OnAccept = function()
        local e = UI.current
        if e then A.RemoveOffer(e.o.recipe) end
        UI.selected = nil
        UI.Refresh()
    end,
    timeout = 0, whileDead = true, hideOnEscape = true,
}

local function GoldText(copper)
    local g = copper / 10000
    if g == math.floor(g) then return string.format("%d", g) end
    return (string.format("%.2f", g):gsub("0+$", ""))
end

function UI.RefreshOfferDetail()
    local e = FindOffer(UI.selected)
    UI.current = e
    UI.playerBody:Hide()
    if not e then
        UI.offerBody:Hide()
        UI.emptyDetail:SetText(UI.tab == "mine" and T"Elige una de tus ofertas para ponerle precio y nota."
            or T"Elige una oferta para ver sus materiales.")
        UI.emptyDetail:Show()
        return
    end
    UI.emptyDetail:Hide()
    UI.offerBody:Show()
    local o = e.o
    local mine = e.by == A.Me()

    UI.dIcon.icon:SetTexture(e.icon or A.QUESTION)
    UI.dIcon.itemID = nil
    UI.dName:SetText(A.QualityHex(e.quality) .. (e.name or "?") .. "|r")
    local sub = { A.ProfessionName(o.skill) }
    if (o.qty or 1) > 1 then sub[#sub + 1] = string.format(T"fabrica %d", o.qty) end
    UI.dSub:SetText("|cffbbbbbb" .. table.concat(sub, " · ") .. "|r")

    local lines = {
        T"Artesano: " .. ColoredName(e.by) .. "  " .. StateText(e.by),
        T"Precio: " .. PriceText(o),
        T"Materiales: " .. (o.mats and T"|cff33ff33los pone el artesano|r" or T"los pones tú"),
    }
    if (o.note or "") ~= "" then lines[#lines + 1] = T"Nota: |cffffffff" .. o.note .. "|r" end
    UI.dInfo:SetText(table.concat(lines, "\n"))

    local reag = o.reagents or {}
    UI.dReagHeader:SetText(#reag > 0 and T"Materiales" or T"Materiales: |cff888888ninguno|r")
    for i = 1, MAX_REAG do
        local b = UI.reag[i]
        local g = reag[i]
        if g then
            local name, _, quality, icon = A.ItemInfo(g[1])
            b.itemID, b.need = g[1], g[2]
            b.icon:SetTexture(icon)
            b.count:SetText("")
            local extra = (i == MAX_REAG and #reag > MAX_REAG) and string.format(T"  |cff888888(y %d más)|r", #reag - MAX_REAG) or ""
            b.text:SetText(A.QualityHex(quality) .. (name or (T"Objeto " .. g[1])) .. "|r |cffffffffx" .. g[2] .. "|r" .. extra)
            b:Show()
            b.text:Show()
        else
            b.itemID = nil
            b:Hide()
            b.text:Hide()
        end
    end

    UI.editor:SetShown(mine)
    UI.bWhisper:SetShown(not mine)
    UI.bLink:SetShown(not mine)
    UI.bOthers:SetShown(not mine and UI.crafter ~= e.by)
    if mine and UI.editKey ~= e.key then
        UI.editKey = e.key
        local free = (o.price or 0) <= 0
        UI.eFree:SetChecked(free)
        UI.ePrice:SetText(free and "" or GoldText(o.price))
        if UI.ePrice.SetEnabled then UI.ePrice:SetEnabled(not free) end
        UI.eMats:SetChecked(o.mats and true or false)
        UI.eNote:SetText(o.note or "")
    end
end

function UI.RefreshPlayerDetail()
    UI.offerBody:Hide()
    local name = UI.player
    if not name then
        UI.playerBody:Hide()
        UI.emptyDetail:SetText(T"Elige un jugador para ver lo que fabrica.")
        UI.emptyDetail:Show()
        return
    end
    UI.emptyDetail:Hide()
    UI.playerBody:Show()
    local r = A.roster[name]
    local offers, profs = PlayerOffers(name)
    UI.pName:SetText(ColoredName(name))

    local lines = {}
    if r then
        lines[#lines + 1] = string.format(T"Nivel %s %s  ·  %s", r.level or "?", r.class or "", r.rank or "")
        lines[#lines + 1] = A.IsOnline(name) and (T"|cff33ff33En línea|r  ·  " .. (r.zone or ""))
            or (T"Última conexión: " .. A.Ago(r.lastOnline))
    end
    local u = A.Comm.users[name]
    if name == A.Me() then
        lines[#lines + 1] = T"Addon: |cff33ff33sí|r (tú)"
    elseif u then
        lines[#lines + 1] = string.format(T"Addon: |cff33ff33sí|r (versión %s)", u.version or "?")
    elseif (A.Crafter(name, false) or {}).seen then
        lines[#lines + 1] = T"Addon: |cff33ff33sí|r"
    else
        lines[#lines + 1] = T"Addon: |cff888888no lo hemos visto conectado|r"
    end
    lines[#lines + 1] = T"Profesiones: " .. (#profs > 0 and table.concat(profs, ", ") or "-")
    UI.pInfo:SetText(table.concat(lines, "\n"))

    local o = {}
    local max = 14
    for i, e in ipairs(offers) do
        if i > max then
            o[#o + 1] = string.format(T"|cff888888... y %d más|r", #offers - max)
            break
        end
        o[#o + 1] = Icon(e.icon, 16) .. " " .. A.QualityHex(e.quality) .. (e.name or "?") .. "|r  " .. A.Money(e.o.price)
    end
    UI.pOffers:SetText(#offers > 0 and (string.format(T"|cffffd100Ofertas (%d)|r", #offers) .. "\n" .. table.concat(o, "\n"))
        or T"|cff888888No ofrece nada en el mercado.|r")
    UI.bSee:SetEnabled(#offers > 0)
end

------------------------------------------------------------------------
-- Refresco
------------------------------------------------------------------------
function UI.SetTab(tab)
    if UI.tab ~= tab then
        UI.offset = 0
        if tab == "mine" and UI.selected and not UI.selected:find(A.Me() .. "#", 1, true) then UI.selected = nil end
    end
    UI.tab = tab
    UI.Refresh()
end

function UI.Refresh()
    if not (UI.frame and UI.frame:IsShown()) then return end
    local g = A.Guild(false)
    UI.title:SetText(T"Mercado de Artesanos" .. (g and (" - |cffffffff" .. (g.name or "") .. "|r") or ""))
    for key, b in pairs(UI.tabs) do b:SetEnabled(key ~= UI.tab) end

    local players = UI.tab == "players"
    UI.offersView:SetShown(not players)
    UI.playersView:SetShown(players)
    if players then
        UI.RefreshPlayers()
        UI.RefreshPlayerDetail()
    else
        UI.RefreshOffers()
        UI.RefreshOfferDetail()
    end
end

function UI.Open(tab, recipeID)
    UI.Build()
    UI.frame:Show()
    A.RequestRoster()
    if recipeID then UI.selected = A.Me() .. "#" .. recipeID end
    UI.SetTab(tab or UI.tab)
    if recipeID then
        ScrollToSelected()
        UI.Refresh()
    end
end

function UI.Toggle()
    UI.Build()
    if UI.frame:IsShown() then
        UI.frame:Hide()
    else
        UI.Open()
    end
end

------------------------------------------------------------------------
-- Shift+clic en un objeto con la casilla de Mis ofertas activa: se publica.
------------------------------------------------------------------------
local lastLink, lastTime

local function OnInsertLink(link)
    if type(link) ~= "string" then return end
    local eb = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
    if not (eb and eb.artesanosAdd) then return end
    local now = GetTime()
    if link == lastLink and lastTime == now then return end -- enganchado dos veces
    lastLink, lastTime = link, now
    eb:ClearFocus()
    UI.PublishLink(link)
    -- Con el foco en una casilla, el Shift+clic en la bolsa abre además la ventana de dividir
    -- el montón; se cierra.
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
