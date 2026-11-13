-- Guild Ledger: recopila datos de la hermandad y guarda notas/aportes por jugador.
local ADDON, ns = ...
local GL = {}
ns.GL = GL

GL.CATEGORIES = {
    "Oro", "Materiales", "Crafteo", "Raid/Mazmorra", "Reclutamiento",
    "Ayuda/Guía", "Organización", "Banco: oro", "Banco: objetos", "Otro",
}

local MAX_LOG = 500
local SCAN_DELAY = 2       -- segundos entre GUILD_ROSTER_UPDATE y el escaneo
local REQUEST_EVERY = 120  -- segundos entre peticiones de roster al servidor

------------------------------------------------------------------------
-- Utilidades
------------------------------------------------------------------------
function GL.Now()
    return (time and time()) or 0
end

function GL.FormatDate(t, withTime)
    if not t or t == 0 then return "-" end
    if not date then return tostring(t) end
    return date(withTime and "%d/%m/%Y %H:%M" or "%d/%m/%Y", t)
end

function GL.Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cff88ccffGuild Ledger:|r " .. tostring(msg))
end

function GL.ShortName(name)
    if not name then return "?" end
    if Ambiguate then return Ambiguate(name, "guild") end
    return name
end

function GL.PlayerName()
    local n = UnitName("player") or "?"
    return n
end

------------------------------------------------------------------------
-- Base de datos
------------------------------------------------------------------------
function GL.GetGuildKey()
    if not IsInGuild or not IsInGuild() then return nil end
    local gname, _, _, realm = GetGuildInfo("player")
    if not gname then return nil end
    if not realm or realm == "" then
        realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or GetRealmName() or ""
    end
    return gname .. " - " .. realm, gname
end

function GL.GetGuildDB(create)
    if not GuildLedgerDB then return nil end
    local key, gname = GL.GetGuildKey()
    if not key then return nil end
    local g = GuildLedgerDB.guilds[key]
    if not g and create then
        g = { name = gname, members = {}, log = {}, created = GL.Now() }
        GuildLedgerDB.guilds[key] = g
    end
    return g
end

function GL.AddLog(g, text)
    table.insert(g.log, 1, { t = GL.Now(), text = text })
    while #g.log > MAX_LOG do table.remove(g.log) end
end

local function NewMember(name)
    return {
        name = name,
        firstSeen = GL.Now(),
        notes = "",
        contributions = {},
        history = {},
    }
end

local function AddHistory(m, text)
    table.insert(m.history, 1, { t = GL.Now(), text = text })
    while #m.history > 100 do table.remove(m.history) end
end

function GL.Totals(m)
    local count, sum = 0, 0
    for _, c in ipairs(m.contributions or {}) do
        count = count + 1
        sum = sum + (tonumber(c.amount) or 0)
    end
    return count, sum
end

function GL.AddContribution(m, cat, amount, text)
    local c = {
        t = GL.Now(),
        cat = cat or "Otro",
        amount = tonumber(amount),
        text = text or "",
        by = GL.PlayerName(),
    }
    table.insert(m.contributions, 1, c)
    return c
end

------------------------------------------------------------------------
-- Escaneo del roster
------------------------------------------------------------------------
function GL.RequestRoster()
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    elseif GuildRoster then
        GuildRoster()
    end
end

local function LastOnlineTimestamp(index)
    if not GetGuildRosterLastOnline then return nil end
    local y, mo, d, h = GetGuildRosterLastOnline(index)
    if not y then return nil end
    local hours = (((y * 12 + mo) * 30 + d) * 24) + h
    return GL.Now() - hours * 3600
end

function GL.Scan(silent)
    local g = GL.GetGuildDB(true)
    if not g then return false end
    local n = GetNumGuildMembers()
    if not n or n == 0 then return false end

    local firstScan = not g.scanned
    local present, seen = {}, 0
    local now = GL.Now()

    for i = 1, n do
        local name, rankName, rankIndex, level, classDisplay, zone,
              publicNote, officerNote, online, status, classFile = GetGuildRosterInfo(i)
        if name then
            seen = seen + 1
            present[name] = true
            local m = g.members[name]
            if not m then
                m = NewMember(name)
                g.members[name] = m
                if not firstScan then
                    GL.AddLog(g, GL.ShortName(name) .. " se ha unido a la hermandad")
                    AddHistory(m, "Se une a la hermandad")
                end
            elseif m.left then
                m.left = nil
                GL.AddLog(g, GL.ShortName(name) .. " ha vuelto a la hermandad")
                AddHistory(m, "Vuelve a la hermandad")
            end

            if m.level and level and level > m.level then
                AddHistory(m, "Sube a nivel " .. level)
                if level == (GetMaxPlayerLevel and GetMaxPlayerLevel() or 60) then
                    GL.AddLog(g, GL.ShortName(name) .. " ha llegado a nivel " .. level)
                end
            end
            if m.rank and rankName and m.rank ~= rankName then
                AddHistory(m, "Rango: " .. m.rank .. " -> " .. rankName)
                GL.AddLog(g, GL.ShortName(name) .. ": rango " .. m.rank .. " -> " .. rankName)
            end

            m.rank = rankName
            m.rankIndex = rankIndex
            m.level = level
            m.class = classDisplay
            m.classFile = classFile
            m.zone = zone
            m.publicNote = publicNote
            if officerNote and officerNote ~= "" then m.officerNote = officerNote end
            m.online = online and true or false
            if online then
                m.lastOnline = now
            else
                local lo = LastOnlineTimestamp(i)
                if lo and (not m.lastOnline or lo > m.lastOnline) then m.lastOnline = lo end
            end
            m.lastSeen = now
        end
    end

    -- Solo marcamos bajas si el roster parece completo (evita falsos positivos
    -- cuando el servidor aún no ha enviado toda la lista).
    local prev = g.count or 0
    if not firstScan and seen >= prev * 0.8 then
        for name, m in pairs(g.members) do
            if not present[name] and not m.left then
                m.left = now
                m.online = false
                AddHistory(m, "Deja la hermandad")
                GL.AddLog(g, GL.ShortName(name) .. " ha dejado la hermandad")
            end
        end
    end

    g.count = seen
    g.scanned = now
    if not silent and GL.UI and GL.UI.Refresh then GL.UI.Refresh() end
    return true
end

------------------------------------------------------------------------
-- Exportar
------------------------------------------------------------------------
local function csv(v)
    v = tostring(v or "")
    v = v:gsub("\r?\n", " ")
    if v:find("[;\"]") then v = '"' .. v:gsub('"', '""') .. '"' end
    return v
end

function GL.ExportText()
    local g = GL.GetGuildDB(false)
    if not g then return "No hay datos de hermandad." end
    local names = {}
    for name in pairs(g.members) do names[#names + 1] = name end
    table.sort(names)

    local out = {}
    out[#out + 1] = "== MIEMBROS =="
    out[#out + 1] = "Nombre;Clase;Nivel;Rango;Estado;Primera vez;Última conexión;Nº aportes;Valor total;Notas"
    for _, name in ipairs(names) do
        local m = g.members[name]
        local cnt, sum = GL.Totals(m)
        out[#out + 1] = table.concat({
            csv(name), csv(m.class), csv(m.level), csv(m.rank),
            csv(m.left and "Exmiembro" or "Miembro"),
            csv(GL.FormatDate(m.firstSeen)), csv(GL.FormatDate(m.lastOnline)),
            csv(cnt), csv(sum), csv(m.notes),
        }, ";")
    end
    out[#out + 1] = ""
    out[#out + 1] = "== APORTES =="
    out[#out + 1] = "Fecha;Jugador;Categoría;Valor;Descripción;Anotado por"
    for _, name in ipairs(names) do
        local m = g.members[name]
        for _, c in ipairs(m.contributions) do
            out[#out + 1] = table.concat({
                csv(GL.FormatDate(c.t, true)), csv(name), csv(c.cat),
                csv(c.amount or ""), csv(c.text), csv(c.by),
            }, ";")
        end
    end
    if GL.BankExportLines then GL.BankExportLines(out) end
    return table.concat(out, "\n")
end

function GL.LogText()
    local g = GL.GetGuildDB(false)
    if not g then return "No hay datos de hermandad." end
    local out = {}
    for _, e in ipairs(g.log) do
        out[#out + 1] = GL.FormatDate(e.t, true) .. "  " .. e.text
    end
    if #out == 0 then return "Aún no hay eventos registrados." end
    return table.concat(out, "\n")
end

------------------------------------------------------------------------
-- Eventos
------------------------------------------------------------------------
local ev = CreateFrame("Frame")
local scanPending = false

local function ScheduleScan()
    if scanPending then return end
    scanPending = true
    C_Timer.After(SCAN_DELAY, function()
        scanPending = false
        GL.Scan()
    end)
end

ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:RegisterEvent("GUILD_ROSTER_UPDATE")
ev:RegisterEvent("PLAYER_GUILD_UPDATE")

ev:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        GuildLedgerDB = GuildLedgerDB or {}
        GuildLedgerDB.guilds = GuildLedgerDB.guilds or {}
        GuildLedgerDB.version = 1
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(5, GL.RequestRoster)
        if not GL.ticker and C_Timer.NewTicker then
            GL.ticker = C_Timer.NewTicker(REQUEST_EVERY, GL.RequestRoster)
        end
    elseif event == "GUILD_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" then
        ScheduleScan()
    end
end)

------------------------------------------------------------------------
-- Comandos
------------------------------------------------------------------------
SLASH_GUILDLEDGER1 = "/gl"
SLASH_GUILDLEDGER2 = "/registro"
SlashCmdList["GUILDLEDGER"] = function(msg)
    msg = (msg or ""):lower():match("^%s*(.-)%s*$")
    if msg == "scan" or msg == "escanear" then
        GL.RequestRoster()
        C_Timer.After(1.5, function()
            if GL.Scan() then GL.Print("Roster actualizado.") else GL.Print("No se pudo leer el roster (¿estás en una hermandad?).") end
        end)
    elseif msg == "export" or msg == "exportar" then
        GL.UI.ShowText("Exportar (Ctrl+A, Ctrl+C)", GL.ExportText())
    elseif msg == "log" or msg == "historial" then
        GL.UI.ShowText("Historial de la hermandad", GL.LogText())
    elseif msg == "banco" or msg == "bank" then
        GL.ProcessBankLogs()
        GL.UI.ShowText("Movimientos del banco", GL.BankText())
    elseif msg == "help" or msg == "ayuda" then
        GL.Print("/gl banco - ver los movimientos del banco registrados")
        GL.Print("/gl - abrir/cerrar ventana")
        GL.Print("/gl escanear - releer el roster ahora")
        GL.Print("/gl exportar - copiar todos los datos como CSV")
        GL.Print("/gl historial - ver altas, bajas y cambios de rango")
    else
        GL.UI.Toggle()
    end
end

function GuildLedger_OnCompartmentClick()
    GL.UI.Toggle()
end
