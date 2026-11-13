-- Guild Ledger: registro de movimientos del banco de hermandad.
-- El juego solo envía el registro mientras el banco está abierto, y solo guarda
-- los movimientos más recientes de cada pestaña. Por eso, cada vez que se abre
-- el banco comparamos el registro con el de la última vez y guardamos lo nuevo.
local ADDON, ns = ...
local GL = ns.GL

local MAX_BANK_LOG = 5000
local floor = math.floor

local function MoneyTab()
    return (MAX_GUILDBANK_TABS or 8) + 1
end

function GL.Money(copper)
    copper = tonumber(copper) or 0
    local g = floor(copper / 10000)
    local s = floor(copper / 100) % 100
    local c = copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = g .. "o" end
    if s > 0 then parts[#parts + 1] = s .. "p" end
    if c > 0 or #parts == 0 then parts[#parts + 1] = c .. "c" end
    return table.concat(parts, " ")
end

local function ItemName(link)
    if not link then return "?" end
    return link:match("|h%[(.-)%]|h") or link
end

local function ItemId(link)
    return link and link:match("item:(%d+)") or tostring(link or "")
end

local function HoursAgo(y, mo, d, h)
    return (((y or 0) * 12 + (mo or 0)) * 30 + (d or 0)) * 24 + (h or 0)
end

local function TabLabel(tab)
    if tab == MoneyTab() then return "Oro" end
    local name = GetGuildBankTabInfo and GetGuildBankTabInfo(tab)
    if name and name ~= "" then return name end
    return "Pestaña " .. tostring(tab)
end

local function BankDB(g)
    g.bank = g.bank or {}
    local b = g.bank
    b.tabs = b.tabs or {}
    b.log = b.log or {}
    if b.newestFirst == nil then b.newestFirst = true end
    return b
end

function GL.FindMember(g, name)
    if not name then return nil end
    if g.members[name] then return g.members[name] end
    local pref = name .. "-"
    for key, m in pairs(g.members) do
        if key:sub(1, #pref) == pref then return m end
    end
    return nil
end

------------------------------------------------------------------------
-- Lectura
------------------------------------------------------------------------
local function ReadTab(tab)
    local list = {}
    local isMoney = (tab == MoneyTab())
    local n
    if isMoney then
        n = GetNumGuildBankMoneyTransactions and GetNumGuildBankMoneyTransactions() or 0
    else
        n = GetNumGuildBankTransactions and GetNumGuildBankTransactions(tab) or 0
    end
    for i = 1, n do
        local e
        if isMoney then
            local typ, name, amount, y, mo, d, h = GetGuildBankMoneyTransaction(i)
            e = { type = typ, name = name, amount = amount, ago = HoursAgo(y, mo, d, h), money = true }
            e.sig = table.concat({ "m", tostring(typ), tostring(name), tostring(amount) }, "|")
        else
            local typ, name, link, count, tab1, tab2, y, mo, d, h = GetGuildBankTransaction(tab, i)
            e = { type = typ, name = name, item = link, count = count, tab1 = tab1, tab2 = tab2,
                  ago = HoursAgo(y, mo, d, h) }
            e.sig = table.concat({ "i", tostring(typ), tostring(name), ItemId(link), tostring(count),
                                   tostring(tab1), tostring(tab2) }, "|")
        end
        if e.type then list[#list + 1] = e end
    end
    return list
end

-- Devuelve la lista ordenada de más antiguo a más reciente.
local function Chronological(b, list)
    local n = #list
    if n >= 2 then
        if list[1].ago > list[n].ago then b.newestFirst = false
        elseif list[1].ago < list[n].ago then b.newestFirst = true end
    end
    if b.newestFirst then
        local r = {}
        for i = n, 1, -1 do r[#r + 1] = list[i] end
        return r
    end
    return list
end

-- Busca el mayor solapamiento entre el final del registro anterior y el
-- principio del actual; lo que queda después son movimientos nuevos.
local function FirstNewIndex(prev, cur)
    local np, nc = #prev, #cur
    for k = math.min(np, nc), 1, -1 do
        local ok = true
        for j = 1, k do
            if prev[np - k + j] ~= cur[j].sig then ok = false; break end
        end
        if ok then return k + 1 end
    end
    return 1
end

------------------------------------------------------------------------
-- Registro
------------------------------------------------------------------------
local function Record(g, b, tab, e, touched)
    local ts = GL.Now() - e.ago * 3600
    local entry = {
        t = ts, tab = TabLabel(tab), type = e.type, name = e.name,
        item = e.item, count = e.count, amount = e.amount,
        tab1 = e.tab1, tab2 = e.tab2,
    }
    b.log[#b.log + 1] = entry
    while #b.log > MAX_BANK_LOG do table.remove(b.log, 1) end

    local m = GL.FindMember(g, e.name)
    if not m then return end
    m.bank = m.bank or { depGold = 0, wdGold = 0, depItems = 0, wdItems = 0, repairs = 0 }
    local s = m.bank
    if e.money then
        local amt = tonumber(e.amount) or 0
        if e.type == "deposit" then
            s.depGold = s.depGold + amt
            table.insert(m.contributions, 1, {
                t = ts, cat = "Banco: oro", amount = floor(amt / 10000),
                text = "Depósito en el banco: " .. GL.Money(amt), by = "Banco", auto = true,
            })
            touched[m] = true
        elseif e.type == "withdraw" then
            s.wdGold = s.wdGold + amt
        elseif e.type == "repair" then
            s.wdGold = s.wdGold + amt
            s.repairs = s.repairs + amt
        end
    else
        local cnt = tonumber(e.count) or 1
        if e.type == "deposit" then
            s.depItems = s.depItems + cnt
            table.insert(m.contributions, 1, {
                t = ts, cat = "Banco: objetos", amount = nil,
                text = cnt .. "x " .. ItemName(e.item) .. " (" .. entry.tab .. ")", by = "Banco", auto = true,
            })
            touched[m] = true
        elseif e.type == "withdraw" then
            s.wdItems = s.wdItems + cnt
        end
    end
end

function GL.ProcessBankLogs(silent)
    local g = GL.GetGuildDB(true)
    if not g then return 0 end
    local b = BankDB(g)
    local touched, added = {}, 0

    local tabs = {}
    local num = GetNumGuildBankTabs and GetNumGuildBankTabs() or 0
    for t = 1, num do tabs[#tabs + 1] = t end
    tabs[#tabs + 1] = MoneyTab()

    for _, tab in ipairs(tabs) do
        local cur = ReadTab(tab)
        if #cur > 0 then
            cur = Chronological(b, cur)
            local key = tostring(tab)
            local prev = b.tabs[key] or {}
            local start = FirstNewIndex(prev, cur)
            for i = start, #cur do
                Record(g, b, tab, cur[i], touched)
                added = added + 1
            end
            local sigs = {}
            for i, e in ipairs(cur) do sigs[i] = e.sig end
            b.tabs[key] = sigs
        end
    end

    for m in pairs(touched) do
        table.sort(m.contributions, function(a, c) return (a.t or 0) > (c.t or 0) end)
    end
    if added > 0 then
        b.lastRead = GL.Now()
        if not silent then GL.Print("Banco: " .. added .. " movimientos nuevos registrados.") end
        if GL.UI and GL.UI.Refresh then GL.UI.Refresh() end
    end
    return added
end

function GL.QueryBankLogs()
    if not QueryGuildBankLog then return end
    local num = GetNumGuildBankTabs and GetNumGuildBankTabs() or 0
    for t = 1, num do QueryGuildBankLog(t) end
    QueryGuildBankLog(MoneyTab())
end

------------------------------------------------------------------------
-- Texto para mostrar / exportar
------------------------------------------------------------------------
local VERB = {
    deposit = "deposita", withdraw = "retira", move = "mueve",
    repair = "retira para reparar", buyTab = "compra pestaña",
    withdrawForTab = "retira para pestaña", depositSummary = "ingreso de la hermandad",
}

function GL.BankLine(e)
    local who = GL.ShortName(e.name)
    local verb = VERB[e.type] or tostring(e.type)
    local what
    if e.amount then
        what = GL.Money(e.amount)
    else
        what = (e.count or 1) .. "x " .. ItemName(e.item)
        if e.type == "move" and e.tab1 and e.tab2 then
            what = what .. " (" .. TabLabel(e.tab1) .. " -> " .. TabLabel(e.tab2) .. ")"
        else
            what = what .. " (" .. (e.tab or "?") .. ")"
        end
    end
    return who, verb, what
end

local function Matches(e, filterName)
    if not filterName then return true end
    if e.name == filterName then return true end
    return e.name and (filterName:sub(1, #e.name + 1) == e.name .. "-")
end

function GL.BankText(filterName)
    local g = GL.GetGuildDB(false)
    if not g or not g.bank or #g.bank.log == 0 then
        return "Aún no hay movimientos registrados.\n\nAbre el banco de la hermandad para que el addon lea su registro."
    end
    local out = {}
    if filterName then
        local m = g.members[filterName]
        local s = m and m.bank
        if s then
            out[#out + 1] = string.format("Oro: +%s depositado / -%s retirado (%s en reparaciones)",
                GL.Money(s.depGold), GL.Money(s.wdGold), GL.Money(s.repairs))
            out[#out + 1] = string.format("Objetos: +%d depositados / -%d retirados", s.depItems, s.wdItems)
            out[#out + 1] = ""
        end
    end
    for i = #g.bank.log, 1, -1 do
        local e = g.bank.log[i]
        if Matches(e, filterName) then
            local who, verb, what = GL.BankLine(e)
            out[#out + 1] = string.format("~%s  %s %s %s", GL.FormatDate(e.t, true), who, verb, what)
        end
    end
    if #out == 0 then return "Este jugador no tiene movimientos en el banco registrados." end
    out[#out + 1] = ""
    out[#out + 1] = "(Las horas son aproximadas: el juego solo indica \"hace X horas\".)"
    return table.concat(out, "\n")
end

function GL.BankExportLines(out)
    local g = GL.GetGuildDB(false)
    if not g or not g.bank then return end
    out[#out + 1] = ""
    out[#out + 1] = "== BANCO =="
    out[#out + 1] = "Fecha aprox.;Jugador;Acción;Objeto;Cantidad;Oro (cobre);Pestaña"
    for _, e in ipairs(g.bank.log) do
        out[#out + 1] = table.concat({
            GL.FormatDate(e.t, true), tostring(e.name or ""), tostring(e.type or ""),
            e.item and ItemName(e.item) or "", tostring(e.count or ""), tostring(e.amount or ""),
            tostring(e.tab or ""),
        }, ";")
    end
end

------------------------------------------------------------------------
-- Eventos
------------------------------------------------------------------------
local ev = CreateFrame("Frame")
local function SafeRegister(event) pcall(ev.RegisterEvent, ev, event) end
SafeRegister("GUILDBANKFRAME_OPENED")
SafeRegister("PLAYER_INTERACTION_MANAGER_FRAME_SHOW")
SafeRegister("GUILDBANKLOG_UPDATE")

local pending = false
local function ScheduleProcess()
    if pending then return end
    pending = true
    C_Timer.After(1.5, function()
        pending = false
        GL.ProcessBankLogs()
    end)
end

local function OnBankOpened()
    GL.QueryBankLogs()
    -- Algunos servidores tardan en contestar; reintentamos una vez.
    C_Timer.After(3, function() GL.QueryBankLogs() end)
end

ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "GUILDBANKFRAME_OPENED" then
        OnBankOpened()
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        local t = Enum and Enum.PlayerInteractionType and Enum.PlayerInteractionType.GuildBanker
        if t and arg1 == t then OnBankOpened() end
    elseif event == "GUILDBANKLOG_UPDATE" then
        ScheduleProcess()
    end
end)
