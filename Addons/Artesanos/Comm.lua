-- Artesanos: reparto de las ofertas entre los miembros de la hermandad que tienen el addon.
--
-- Cada jugador lleva un número de revisión que sube cada vez que cambia sus ofertas. Mensajes
-- (campos separados por ~):
--   H~proto~rev~versión   al conectarse, a la hermandad: "estoy aquí y mis ofertas van por rev"
--   V~proto~rev~versión   respuesta al H, a la hermandad: la revisión de cada uno
--   S~nombre*rev;...      resumen de los artesanos que conoce quien lo envía (también de los que
--                         están desconectados), para que nadie se quede sin sus ofertas
--   Q~nombre              susurro: "mándame las ofertas de nombre"
--   B~nombre~rev~n        empieza una lista de n ofertas
--   O~nombre~rev~oferta^oferta...
--   E~nombre~rev          fin de la lista: se guarda si llegaron las n y la revisión es más nueva
-- Al cambiar tus ofertas se envía la lista entera a la hermandad.
local ADDON, ns = ...
local A = ns.A
local Comm = {}
A.Comm = Comm

local PREFIX = "Artesanos"
local PROTO = 1
local MAX = 255 -- longitud máxima de un mensaje de addon

local Send = (C_ChatInfo and C_ChatInfo.SendAddonMessage) or SendAddonMessage
local Register = (C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix) or RegisterAddonMessagePrefix

Comm.users = {} -- ["Nombre-Reino"] = { version, t } de quien tiene el addon

------------------------------------------------------------------------
-- Cola de envío: el servidor solo deja mandar unos pocos mensajes seguidos por prefijo y
-- luego uno por segundo, así que los mensajes salen poco a poco.
------------------------------------------------------------------------
local queue = {}
local tokens, MAX_TOKENS, REGEN = 6, 6, 1

local pump = CreateFrame("Frame")
pump:Hide()
pump:SetScript("OnUpdate", function(self, elapsed)
    tokens = math.min(MAX_TOKENS, tokens + elapsed * REGEN)
    while tokens >= 1 and queue[1] do
        local m = queue[1]
        local ok, res = pcall(Send, PREFIX, m.text, m.channel, m.target)
        if not ok then
            table.remove(queue, 1) -- error del propio envío (destino no válido...): se descarta
        elseif res == false or (type(res) == "number" and res ~= 0) then
            -- El servidor lo ha frenado: se reintenta dentro de un rato.
            tokens = 0
            m.tries = (m.tries or 0) + 1
            if m.tries > 8 then table.remove(queue, 1) end
            break
        else
            table.remove(queue, 1)
            tokens = tokens - 1
        end
    end
    if not queue[1] then self:Hide() end
end)

local function Enqueue(text, channel, target)
    if channel == "GUILD" and not IsInGuild() then return end
    for _, m in ipairs(queue) do
        if m.text == text and m.channel == channel and m.target == target then return end
    end
    queue[#queue + 1] = { text = text, channel = channel, target = target }
    pump:Show()
end

------------------------------------------------------------------------
-- Codificación de las ofertas
--   receta,objeto,precio,banderas,profesión,cantidad,material*n;material*n,nota
------------------------------------------------------------------------
local function Clean(s)
    return (tostring(s or ""):gsub("[|~%^\r\n]", " "))
end

-- Corta a `max` bytes sin dejar un carácter UTF-8 a medias.
local function Cut(s, max)
    if #s <= max then return s end
    s = s:sub(1, math.max(0, max))
    local i = #s
    while i > 0 do
        local b = s:byte(i)
        if b < 128 then break end
        if b >= 192 then
            local need = (b >= 240 and 4) or (b >= 224 and 3) or 2
            if #s - i + 1 < need then s = s:sub(1, i - 1) end
            break
        end
        i = i - 1
    end
    return s
end

local function Encode(o, room)
    local r = {}
    for i, g in ipairs(o.reagents or {}) do r[i] = g[1] .. "*" .. g[2] end
    local base = table.concat({
        o.recipe, o.item or 0, o.price or 0, o.mats and 1 or 0, o.skill or 0, o.qty or 1,
        table.concat(r, ";"),
    }, ",") .. ","
    return base .. Cut(Clean(o.note), math.max(0, room - #base))
end

local function Decode(s)
    local recipe, item, price, flags, skill, qty, reag, note =
        s:match("^(%d+),(%d+),(%d+),(%d+),(%d+),(%d+),([^,]*),(.*)$")
    if not recipe then return nil end
    local o = {
        recipe = tonumber(recipe), item = tonumber(item), price = tonumber(price),
        mats = (tonumber(flags) or 0) % 2 == 1, skill = tonumber(skill), qty = tonumber(qty),
        note = note or "", reagents = {},
    }
    for id, n in reag:gmatch("(%d+)%*(%d+)") do
        o.reagents[#o.reagents + 1] = { tonumber(id), tonumber(n) }
    end
    return o
end
Comm.Encode, Comm.Decode = Encode, Decode -- para las pruebas

-- Mensajes con la lista de ofertas de `name` (B, O..., E).
local function ListMessages(name, c)
    local rev = c.rev or 0
    local head = "O~" .. name .. "~" .. rev .. "~"
    local codes = {}
    for _, o in pairs(c.offers) do codes[#codes + 1] = Encode(o, MAX - #head) end
    table.sort(codes)
    local out = { "B~" .. name .. "~" .. rev .. "~" .. #codes }
    local cur
    for _, e in ipairs(codes) do
        if cur and #cur + 1 + #e > MAX then
            out[#out + 1] = cur
            cur = nil
        end
        cur = cur and (cur .. "^" .. e) or (head .. e)
    end
    if cur then out[#out + 1] = cur end
    out[#out + 1] = "E~" .. name .. "~" .. rev
    return out
end
Comm.ListMessages = ListMessages

local function SendList(name, c, channel, target)
    for _, m in ipairs(ListMessages(name, c)) do Enqueue(m, channel, target) end
end

------------------------------------------------------------------------
-- Recepción
------------------------------------------------------------------------
local inbound = {} -- [remitente .. "\1" .. nombre] = { rev, n, offers }
local wanted = {}  -- [nombre] = { rev, t }: listas ya pedidas, para no pedirlas dos veces
local lastSummary = 0
local replyPending, summaryPending = false, false

local function MyRev()
    local c = A.Crafter(A.Me(), false)
    return c and c.rev or 0
end

local function Split(s)
    local t = {}
    for part in (s .. "~"):gmatch("(.-)~") do t[#t + 1] = part end
    return t
end

-- Alguien (holder) tiene las ofertas de `name` en la revisión `rev`: si son más nuevas que las
-- nuestras, se le piden.
local function Check(name, rev, holder)
    rev = tonumber(rev)
    if not (name and name ~= "" and rev and holder) then return end
    local c = A.Crafter(name, false)
    if rev <= (c and c.rev or 0) then return end
    local w = wanted[name]
    if w and w.rev >= rev and GetTime() - w.t < 30 then return end
    wanted[name] = { rev = rev, t = GetTime() }
    Enqueue("Q~" .. name, "WHISPER", holder)
end

local function SendSummary()
    local g = A.Guild(false)
    if not g then return end
    local parts = {}
    for name, c in pairs(g.crafters) do
        if (c.rev or 0) > 0 and A.InGuild(name) then parts[#parts + 1] = name .. "*" .. c.rev end
    end
    local cur
    for _, p in ipairs(parts) do
        if cur and #cur + 1 + #p > MAX then
            Enqueue(cur, "GUILD")
            cur = nil
        end
        cur = cur and (cur .. ";" .. p) or ("S~" .. p)
    end
    if cur then Enqueue(cur, "GUILD") end
end

-- Respuesta a un H: la revisión propia enseguida y, si nadie lo ha hecho ya, el resumen.
local function AnswerHello()
    if not replyPending then
        replyPending = true
        C_Timer.After(0.5 + math.random() * 2.5, function()
            replyPending = false
            Enqueue("V~" .. PROTO .. "~" .. MyRev() .. "~" .. A.VERSION, "GUILD")
        end)
    end
    if not summaryPending then
        summaryPending = true
        local hello = GetTime()
        C_Timer.After(2 + math.random() * 5, function()
            summaryPending = false
            if lastSummary < hello then SendSummary() end
        end)
    end
end

local function Commit(sender, name, rev)
    local key = sender .. "\1" .. name
    local l = inbound[key]
    inbound[key] = nil
    if not (l and l.rev == rev and #l.offers == l.n) then return end
    local cur = A.Crafter(name, false)
    if cur and rev <= (cur.rev or 0) then return end
    local c = A.Crafter(name, true)
    if not c then return end
    wipe(c.offers)
    for _, o in ipairs(l.offers) do c.offers[o.recipe] = o end
    c.rev = rev
    if sender == name then c.seen = A.Now() end
    local r = A.roster[name]
    if r then c.classFile = r.classFile end
    if wanted[name] and wanted[name].rev <= rev then wanted[name] = nil end
    A.RefreshSoon()
end

local handlers = {}

handlers.H = function(sender, f)
    Comm.users[sender] = { version = f[4], t = A.Now() }
    Check(sender, f[3], sender)
    AnswerHello()
end

handlers.V = function(sender, f)
    Comm.users[sender] = { version = f[4], t = A.Now() }
    Check(sender, f[3], sender)
end

handlers.S = function(sender, f, text)
    lastSummary = GetTime()
    for name, rev in text:sub(3):gmatch("([^;*]+)%*(%d+)") do
        Check(name, rev, sender)
    end
end

handlers.Q = function(sender, f)
    local name = f[2]
    local c = A.Crafter(name, false)
    if c and (c.rev or 0) > 0 then SendList(name, c, "WHISPER", sender) end
end

handlers.B = function(sender, f)
    local name, rev, n = f[2], tonumber(f[3]), tonumber(f[4])
    if not (name and rev and n) then return end
    inbound[sender .. "\1" .. name] = { rev = rev, n = n, offers = {} }
    if n == 0 then Commit(sender, name, rev) end
end

handlers.O = function(sender, f)
    local name, rev = f[2], tonumber(f[3])
    local l = inbound[sender .. "\1" .. (name or "")]
    if not (l and l.rev == rev and f[4]) then return end
    for code in f[4]:gmatch("[^%^]+") do
        local o = Decode(code)
        if o then l.offers[#l.offers + 1] = o end
    end
end

handlers.E = function(sender, f)
    local rev = tonumber(f[3])
    if f[2] and rev then Commit(sender, f[2], rev) end
end

function Comm.OnMessage(text, sender)
    if not (A.db and sender) then return end
    sender = A.FullName(sender)
    if sender == A.Me() then return end -- nuestros propios mensajes a la hermandad vuelven
    if not A.InGuild(sender) then return end -- los susurros de fuera de la hermandad no cuentan
    local kind = text:sub(1, 1)
    local h = handlers[kind]
    if not h or text:sub(2, 2) ~= "~" then return end
    h(sender, Split(text), text)
end

------------------------------------------------------------------------
-- Envío
------------------------------------------------------------------------
function Comm.Hello()
    if not IsInGuild() then return end
    Enqueue("H~" .. PROTO .. "~" .. MyRev() .. "~" .. A.VERSION, "GUILD")
end

-- Tras cambiar tus ofertas: la lista entera a la hermandad, unos segundos después del último
-- cambio para no mandarla varias veces mientras editas.
local broadcastId = 0
function Comm.ScheduleBroadcast()
    broadcastId = broadcastId + 1
    local id = broadcastId
    C_Timer.After(3, function()
        if id ~= broadcastId then return end
        local me = A.Me()
        local c = A.Crafter(me, false)
        if c then SendList(me, c, "GUILD") end
    end)
end

function Comm.Pending()
    return #queue
end

------------------------------------------------------------------------
-- Eventos
------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_GUILD_UPDATE")
ev:RegisterEvent("CHAT_MSG_ADDON")

local helloDone = false
local function HelloSoon()
    if helloDone then return end
    C_Timer.After(8, function()
        if helloDone or not IsInGuild() then return end
        helloDone = true
        Comm.Hello()
    end)
end

ev:SetScript("OnEvent", function(_, event, prefix, text, channel, sender)
    if event == "CHAT_MSG_ADDON" then
        if prefix == PREFIX and (channel == "GUILD" or channel == "WHISPER") then
            Comm.OnMessage(text, sender)
        end
    elseif event == "PLAYER_LOGIN" then
        if Register then pcall(Register, PREFIX) end
        HelloSoon()
    elseif event == "PLAYER_GUILD_UPDATE" then
        HelloSoon()
    end
end)
