-- Artesanos: mercado de fabricación de la hermandad.
-- Cada jugador publica las recetas que sabe fabricar, con su precio (o gratis para la hermandad).
-- Las ofertas se guardan por hermandad y se comparten con el resto de miembros que tienen el
-- addon (Comm.lua); la ventana está en UI.lua y el botón de la ventana de profesiones en
-- Profession.lua.
local ADDON, ns = ...
local T = ns.T -- traducción (Locale.lua)
local A = {}
ns.A = A

A.VERSION = "1.0.0"
A.MAX_NOTE = 60 -- letras de la nota de una oferta
A.QUESTION = "Interface\\Icons\\INV_Misc_QuestionMark"

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local GetItemIcon = (C_Item and C_Item.GetItemIconByID) or GetItemIcon

------------------------------------------------------------------------
-- Utilidades
------------------------------------------------------------------------
function A.Now()
    return time()
end

function A.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(T"|cffe6b450Artesanos:|r " .. tostring(msg))
end

local function Realm()
    local r = GetNormalizedRealmName and GetNormalizedRealmName()
    if not r or r == "" then r = (GetRealmName() or ""):gsub("[%s%-]", "") end
    return r
end

-- Nombre completo "Nombre-Reino", que es como llegan los remitentes de los mensajes de addon.
function A.FullName(name)
    if not name or name == "" then return nil end
    if name:find("-", 1, true) then return name end
    return name .. "-" .. Realm()
end

function A.Me()
    return A.FullName(UnitName("player"))
end

function A.Short(name)
    if not name then return "?" end
    if Ambiguate then return Ambiguate(name, "guild") end
    return (name:gsub("%-.*$", ""))
end

function A.Ago(t)
    if not t then return "-" end
    local d = A.Now() - t
    if d < 3600 then return T"hace un rato" end
    if d < 86400 then return string.format(T"hace %d h", math.floor(d / 3600)) end
    return string.format(T"hace %d d", math.floor(d / 86400))
end

-- Precio en cobre con los iconos de las monedas; 0 es gratis.
function A.Money(copper)
    if not copper or copper <= 0 then return T"|cff33ff33Gratis|r" end
    if GetCoinTextureString then return GetCoinTextureString(copper) end
    local g, s, c = math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100
    local partes = {}
    if g > 0 then partes[#partes + 1] = g .. "g" end
    if s > 0 then partes[#partes + 1] = s .. "s" end
    if c > 0 then partes[#partes + 1] = c .. "c" end
    return table.concat(partes, " ")
end

function A.ClassColor(classFile)
    local c
    if classFile then
        if C_ClassColor and C_ClassColor.GetClassColor then c = C_ClassColor.GetClassColor(classFile) end
        if not c and RAID_CLASS_COLORS then c = RAID_CLASS_COLORS[classFile] end
    end
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

function A.QualityHex(q)
    local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c then
        if c.hex then return c.hex end
        if c.r then return string.format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255) end
    end
    return "|cffffffff"
end

------------------------------------------------------------------------
-- Objetos, hechizos y profesiones
------------------------------------------------------------------------
-- Nombre, enlace, calidad e icono de un objeto. Si el juego aún no lo tiene en caché lo pide;
-- cuando llega (GET_ITEM_INFO_RECEIVED) la ventana se refresca sola.
function A.ItemInfo(id)
    if not id or id <= 0 then return nil end
    local name, link, quality, _, _, _, _, _, _, icon = GetItemInfo(id)
    if not name and C_Item and C_Item.RequestLoadItemDataByID then
        pcall(C_Item.RequestLoadItemDataByID, id)
    end
    icon = icon or (GetItemIcon and GetItemIcon(id)) or A.QUESTION
    return name, link, quality, icon
end

function A.SpellInfo(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, id)
        if ok and info then return info.name, info.iconID end
    end
    if GetSpellInfo then
        local name, _, icon = GetSpellInfo(id)
        return name, icon
    end
end

function A.RecipeLink(id)
    local fuentes = {
        C_TradeSkillUI and C_TradeSkillUI.GetRecipeLink,
        C_Spell and C_Spell.GetSpellLink,
        GetSpellLink,
    }
    for _, f in ipairs(fuentes) do
        local ok, link = pcall(f, id)
        if ok and type(link) == "string" then return link end
    end
end

-- Lo que se ve de una oferta: nombre, enlace, calidad e icono del objeto que se fabrica,
-- o de la receta si no fabrica ningún objeto (los encantamientos, por ejemplo).
function A.OfferInfo(o)
    if o.item and o.item > 0 then
        local name, link, quality, icon = A.ItemInfo(o.item)
        if not name then name = A.SpellInfo(o.recipe) or (T"Objeto " .. o.item) end
        return name, link, quality, icon
    end
    local name, icon = A.SpellInfo(o.recipe)
    return name or (T"Receta " .. o.recipe), A.RecipeLink(o.recipe), nil, icon or A.QUESTION
end

-- Nombres de las profesiones por si el juego no sabe dar el de una que no tienes.
local PROFESIONES = {
    [129] = "Primeros auxilios", [164] = "Herrería", [165] = "Peletería", [171] = "Alquimia",
    [182] = "Herboristería", [185] = "Cocina", [186] = "Minería", [197] = "Sastrería",
    [202] = "Ingeniería", [333] = "Encantamiento", [356] = "Pesca", [393] = "Desuello",
    [755] = "Joyería", [773] = "Inscripción",
}

function A.ProfessionName(id)
    if not id or id == 0 then return T"Otras" end
    if C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName then
        local ok, name = pcall(C_TradeSkillUI.GetTradeSkillDisplayName, id)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
    if PROFESIONES[id] then return T(PROFESIONES[id]) end
    return T"Profesión " .. id
end

-- Profesión base de una receta (Herrería y no "Herrería de Rasganorte").
function A.RecipeSkill(recipeID)
    if C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillLineForRecipe then
        local ok, id, _, padre = pcall(C_TradeSkillUI.GetTradeSkillLineForRecipe, recipeID)
        if ok then
            if padre and padre > 0 then return padre end
            if id and id > 0 then return id end
        end
    end
    local known = A.Known()
    if known and known.recipes[recipeID] then return known.recipes[recipeID] end
    if C_TradeSkillUI and C_TradeSkillUI.GetBaseProfessionInfo then
        local ok, info = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
        if ok and info and info.professionID then return info.professionID end
    end
    return 0
end

-- Objeto que produce la receta y sus materiales básicos: { {itemID, cantidad}, ... }.
function A.RecipeData(recipeID)
    local o = { recipe = recipeID, item = 0, qty = 1, reagents = {} }
    if not (C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic) then return o end
    local ok, s = pcall(C_TradeSkillUI.GetRecipeSchematic, recipeID, false)
    if not (ok and s) then return o end
    o.item = s.outputItemID or 0
    o.qty = math.max(1, s.quantityMin or 1)
    local basico = Enum.CraftingReagentType and Enum.CraftingReagentType.Basic
    for _, hueco in ipairs(s.reagentSlotSchematics or {}) do
        local primero = hueco.reagents and hueco.reagents[1]
        if (basico == nil or hueco.reagentType == basico) and primero and primero.itemID
            and primero.itemID > 0 and (hueco.quantityRequired or 0) > 0 then
            o.reagents[#o.reagents + 1] = { primero.itemID, hueco.quantityRequired }
        end
    end
    return o
end

------------------------------------------------------------------------
-- Base de datos
--   ArtesanosDB.guilds["Hermandad - Reino"].crafters["Nombre-Reino"] =
--     { rev = n, seen = t, classFile = "MAGE", offers = { [recipeID] = oferta } }
--   oferta = { recipe, item, qty, skill, price (cobre, 0 = gratis), mats (pone él los
--              materiales), note, reagents = { {itemID, cantidad}, ... } }
--   ArtesanosDB.known["Nombre-Reino"] = { items = { [itemID] = recipeID },
--                                         recipes = { [recipeID] = profesión } }
------------------------------------------------------------------------
function A.GuildKey()
    if not IsInGuild() then return nil end
    local gname, _, _, grealm = GetGuildInfo("player")
    if not gname then return nil end
    if not grealm or grealm == "" then grealm = Realm() end
    return gname .. " - " .. grealm, gname
end

function A.Guild(create)
    if not A.db then return nil end
    local key, gname = A.GuildKey()
    if not key then return nil end
    local g = A.db.guilds[key]
    if not g and create then
        g = { name = gname, crafters = {} }
        A.db.guilds[key] = g
    end
    return g
end

function A.Crafter(name, create)
    local g = A.Guild(create)
    if not (g and name) then return nil end
    local c = g.crafters[name]
    if not c and create then
        c = { rev = 0, offers = {} }
        g.crafters[name] = c
    end
    return c
end

function A.Known()
    if not A.db then return nil end
    local me = A.Me()
    local k = A.db.known[me]
    if not k then
        k = { items = {}, recipes = {} }
        A.db.known[me] = k
    end
    return k
end

------------------------------------------------------------------------
-- Mis ofertas
------------------------------------------------------------------------
local function Changed()
    if A.Comm then A.Comm.ScheduleBroadcast() end
    if A.UI then A.UI.Refresh() end
end

local function Touch(c)
    c.rev = math.max((c.rev or 0) + 1, A.Now())
end

function A.MyOffer(recipeID)
    local c = A.Crafter(A.Me(), false)
    return c and c.offers[recipeID]
end

-- Publica (o actualiza los materiales de) una receta que sabes fabricar. Si ya estaba
-- publicada conserva su precio y su nota. Devuelve la oferta, o nil y el motivo.
function A.Publish(recipeID)
    if not IsInGuild() then return nil, T"Tienes que estar en una hermandad." end
    local c = A.Crafter(A.Me(), true)
    if not c then return nil, T"La hermandad aún no ha cargado; inténtalo en unos segundos." end
    local data = A.RecipeData(recipeID)
    if data.item == 0 and #data.reagents == 0 and not A.SpellInfo(recipeID) then
        return nil, T"No se pudo leer la receta. Abre la profesión y vuelve a intentarlo."
    end
    local o = c.offers[recipeID] or { price = 0, mats = false, note = "" }
    o.recipe, o.item, o.qty, o.reagents = recipeID, data.item, data.qty, data.reagents
    o.skill = A.RecipeSkill(recipeID)
    c.offers[recipeID] = o
    Touch(c)
    Changed()
    return o
end

function A.SaveOffer(recipeID, price, mats, note)
    local c = A.Crafter(A.Me(), false)
    local o = c and c.offers[recipeID]
    if not o then return end
    o.price = math.max(0, math.floor(tonumber(price) or 0))
    o.mats = mats and true or false
    o.note = note or ""
    Touch(c)
    Changed()
end

function A.RemoveOffer(recipeID)
    local c = A.Crafter(A.Me(), false)
    if not (c and c.offers[recipeID]) then return end
    c.offers[recipeID] = nil
    Touch(c)
    Changed()
end

-- Shift+clic o arrastrar un objeto (o un enlace de receta) a la ventana: si es algo que
-- sabes fabricar, se publica.
function A.PublishFromLink(link)
    if type(link) ~= "string" then return end
    local known = A.Known()
    local itemID = tonumber(link:match("item:(%d+)"))
    local spellID = tonumber(link:match("enchant:(%d+)")) or tonumber(link:match("spell:(%d+)"))
    local recipeID
    if itemID and known.items[itemID] then
        recipeID = known.items[itemID]
    elseif spellID and known.recipes[spellID] then
        recipeID = spellID
    end
    if not recipeID then
        A.Print(T"No conozco ninguna receta tuya que fabrique eso. Abre antes tu profesión para que el addon vea tus recetas.")
        return
    end
    local o, err = A.Publish(recipeID)
    if not o then A.Print(err) end
    return o
end

------------------------------------------------------------------------
-- Recetas que conoce el personaje (para poder publicar con Shift+clic)
------------------------------------------------------------------------
function A.ScanKnown()
    if not (A.db and C_TradeSkillUI and C_TradeSkillUI.GetAllRecipeIDs) then return end
    -- La ventana de profesiones también puede estar mostrando la de otro jugador.
    if C_TradeSkillUI.IsTradeSkillLinked then
        local ok, linked = pcall(C_TradeSkillUI.IsTradeSkillLinked)
        if ok and linked then return end
    end
    if C_TradeSkillUI.IsTradeSkillGuild then
        local ok, guild = pcall(C_TradeSkillUI.IsTradeSkillGuild)
        if ok and guild then return end
    end
    local ok, ids = pcall(C_TradeSkillUI.GetAllRecipeIDs)
    if not (ok and type(ids) == "table") then return end
    local skill = 0
    if C_TradeSkillUI.GetBaseProfessionInfo then
        local ok2, info = pcall(C_TradeSkillUI.GetBaseProfessionInfo)
        if ok2 and info and info.professionID then skill = info.professionID end
    end
    local known = A.Known()
    for _, id in ipairs(ids) do
        local ok2, info = pcall(C_TradeSkillUI.GetRecipeInfo, id)
        if ok2 and info and info.learned then
            known.recipes[id] = skill
            local ok3, s = pcall(C_TradeSkillUI.GetRecipeSchematic, id, false)
            if ok3 and s and s.outputItemID and s.outputItemID > 0 then
                known.items[s.outputItemID] = id
            end
        end
    end
end

------------------------------------------------------------------------
-- Lista de la hermandad
------------------------------------------------------------------------
A.roster = {}
A.rosterLoaded = false

local function LastOnline(index)
    if not GetGuildRosterLastOnline then return nil end
    local y, mo, d, h = GetGuildRosterLastOnline(index)
    if not y then return nil end
    return A.Now() - ((((y * 12 + mo) * 30 + d) * 24) + h) * 3600
end

function A.RequestRoster()
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

function A.ScanRoster()
    local n = IsInGuild() and GetNumGuildMembers() or 0
    if not n or n == 0 then return end
    wipe(A.roster)
    local g = A.Guild(true)
    for i = 1, n do
        local name, rank, rankIndex, level, class, zone, _, _, online, _, classFile = GetGuildRosterInfo(i)
        if name then
            local full = A.FullName(name)
            A.roster[full] = {
                name = full, rank = rank, rankIndex = rankIndex, level = level, class = class,
                classFile = classFile, zone = zone, online = online and true or false,
                lastOnline = online and A.Now() or LastOnline(i),
            }
            local c = g and g.crafters[full]
            if c then c.classFile = classFile end
        end
    end
    A.rosterLoaded = true
end

-- ¿Sigue en la hermandad? Mientras no ha cargado la lista se da por bueno.
function A.InGuild(name)
    return not A.rosterLoaded or A.roster[name] ~= nil or name == A.Me()
end

function A.IsOnline(name)
    if name == A.Me() then return true end
    local r = A.roster[name]
    return r and r.online or false
end

------------------------------------------------------------------------
-- Enlazar en el chat y susurrar
------------------------------------------------------------------------
local function OpenChat(text)
    local open = ChatFrame_OpenChat or (ChatFrameUtil and ChatFrameUtil.OpenChat)
    if open then open(text) end
end

function A.InsertLink(link)
    if not link then return end
    if ChatEdit_InsertLink and ChatEdit_InsertLink(link) then return end
    if ChatFrameUtil and ChatFrameUtil.InsertLink and ChatFrameUtil.InsertLink(link) then return end
    OpenChat(link)
end

function A.Whisper(name, text)
    OpenChat((SLASH_WHISPER1 or "/w") .. " " .. A.Short(name) .. " " .. (text or ""))
end

------------------------------------------------------------------------
-- Eventos
------------------------------------------------------------------------
local ev = CreateFrame("Frame")
local rosterPending = false

ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("GUILD_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_GUILD_UPDATE")
ev:RegisterEvent("GET_ITEM_INFO_RECEIVED")

local refreshPending = false
local function RefreshSoon()
    if refreshPending then return end
    refreshPending = true
    C_Timer.After(0.3, function()
        refreshPending = false
        if A.UI then A.UI.Refresh() end
    end)
end
A.RefreshSoon = RefreshSoon

ev:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON then return end
        ArtesanosDB = ArtesanosDB or {}
        A.db = ArtesanosDB
        A.db.guilds = A.db.guilds or {}
        A.db.known = A.db.known or {}
        A.db.version = 1
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(3, A.RequestRoster)
    elseif event == "GUILD_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" then
        if rosterPending then return end
        rosterPending = true
        C_Timer.After(1, function()
            rosterPending = false
            A.ScanRoster()
            RefreshSoon()
        end)
    elseif event == "GET_ITEM_INFO_RECEIVED" then
        RefreshSoon()
    end
end)

------------------------------------------------------------------------
-- Comandos
------------------------------------------------------------------------
SLASH_ARTESANOS1 = "/artesanos"
SLASH_ARTESANOS2 = "/mercado"
SLASH_ARTESANOS3 = "/crafters"
SlashCmdList.ARTESANOS = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "mis" or msg == "mine" then
        A.UI.Open("mine")
    elseif msg == "jugadores" or msg == "players" then
        A.UI.Open("players")
    elseif msg == "boton" or msg == "botón" or msg == "button" then
        A.ToggleButton()
    elseif msg == "sync" or msg == "sincronizar" then
        A.Comm.Hello()
        A.Print(T"Pidiendo las ofertas a la hermandad...")
    elseif msg == "help" or msg == "ayuda" then
        A.Print(T"/artesanos - abrir o cerrar el mercado")
        A.Print(T"/artesanos mis - tus ofertas")
        A.Print(T"/artesanos jugadores - la lista de la hermandad")
        A.Print(T"/artesanos sincronizar - volver a pedir las ofertas a la hermandad")
        A.Print(T"/artesanos boton - mostrar u ocultar el botón flotante")
    else
        A.UI.Toggle()
    end
end

function Artesanos_OnCompartmentClick()
    A.UI.Toggle()
end
