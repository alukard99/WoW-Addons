-- The simulation uses world pixels, seconds and radians, independently of UI scale.
local _, V = ...
local G
local keys = {}
V.keys = keys
local joy = {on=false}
V.joy = joy
local W, H, ZOOM, RUN = 832, 488, 1, 300
V.width, V.height = W, H
local UP, EV, ET, FIRST = V.UP, V.EV, V.ET, V.FIRST
local TAU, cY, cS = math.pi * 2, "#f2c14e", "#d9d4c4"
local random = math.random
local function active(v) return v ~= nil and v ~= false and v ~= 0 and v ~= "" end
local function kin(v) if active(v) then return v end end
local function round(v) return math.floor(v + .5) end
local function hypot(x, y) return math.sqrt(x*x + y*y) end
local function rnd(a, b)
    if b then return a + random() * (b-a) end
    return random() * (a or 1)
end
local function clear(t) for k in pairs(t) do t[k] = nil end end
local function append(t, ...)
    for i = 1, select("#", ...) do t[#t+1] = select(i, ...) end
end
local function merge(t, extra)
    if extra then for k, v in pairs(extra) do t[k] = v end end
    return t
end
local function contains(t, value)
    for i = 1, #t do if t[i] == value then return true end end
    return false
end
local function dropFirst(t, n)
    local last = #t
    for i = 1, last-n do t[i] = t[i+n] end
    for i = last-n+1, last do t[i] = nil end
end
local function retain(t, predicate)
    local nextIndex = 1
    for i = 1, #t do
        if predicate(t[i]) then t[nextIndex] = t[i]; nextIndex = nextIndex+1 end
    end
    for i = nextIndex, #t do t[i] = nil end
    return t
end
local function selectFrom(t, predicate)
    local found = {}
    for i = 1, #t do if predicate(t[i]) then found[#found+1] = t[i] end end
    return found
end
local SFX = setmetatable({}, {__index = function(t, name)
    t[name] = function() V.sound(name) end
    return t[name]
end})
local function bark(message) V.bark(message) end
local function endRun(win) V.finish(win) end
local function openLevelUp() V.reveal() end
local function updHud() end

local recalc, spawn, ringPos, spawnWave, nearTo, aimAt, num, heal, raw, hit, kill, dropGem, hurtPlayer, gridKey, forNear, areaHit, strikeAt, addZone, orbiters, shoot, weapons, update, ARCH

recalc = function()
    local p = G.p
    local M = G.M
    local s = {hp = 0, ar = 0, rg = 0, mi = 0, spd = 0, pk = 0, xp = 0, area = 0, ps = 0, dur = 0, amt = 0, crit = 0.05, critm = 1.5, kb = 0, luck = 0, dodge = 0, thorns = 0, inv = 0, lsk = 0, low = 0, still = 0, move = 0, vet = 0, elite = 0, first = 0, last = 0, torch = 0, flaskm = 0, hpp = 0, mag = 0, cd = 1}
    for k in pairs(p.up) do
        local u = UP[k]
        local n = p.up[k]
        if active(u.s) then
            for a in pairs(u.s) do
                if (a == "cd") then
                    s.cd = s.cd * math.pow(u.s[a], n)
                else
                    s[a] = s[a] + (u.s[a] * n)
                end
            end
        end
    end
    if active(p.up.martir) then
        s.hp = s.hp - 20
        s.mi = s.mi + 0.25
    end
    if active(p.up.coloso) then
        s.hp = s.hp + 50
        s.spd = s.spd - 0.1
        s.area = s.area + 0.15
    end
    if active(p.up.pacto) then
        s.xp = s.xp + 0.3
        s.hp = s.hp - 15
    end
    s.mi = ((1 + s.mi) * M.mi)
    s.spd = ((1 + s.spd) * M.spd)
    s.pk = ((1 + s.pk) * M.pk)
    s.xp = ((1 + s.xp) * M.xp)
    s.cd = s.cd * M.cd
    s.ar = s.ar + M.ar
    s.rg = s.rg + M.rg
    s.area = s.area + 1
    s.ps = s.ps + 1
    s.dur = s.dur + 1
    s.kb = s.kb + 1
    local mh = math.max(20, round((((active(G.glass) and 50 or (100 + M.hp)) + s.hp) * (1 + s.hpp))))
    if active(p.maxhp) then
        local d = (mh - p.maxhp)
        p.maxhp = mh
        if (d > 0) then
            p.hp = p.hp + d
        end
        p.hp = math.min(p.hp, mh)
    else
        p.hp = mh
        p.maxhp = p.hp
    end
    G.ST = s
end

spawn = function(enemyType, x, y)
    local T = ET[enemyType]
    local hs = (active(T.elite) and (1 + (G.t / 400)) or (1 + (G.t / 150)))
    local e = {T = T, type = enemyType, x = x, y = y, hp = (T.hp * hs), max = (T.hp * hs), kx = 0, ky = 0, flash = 0, oc = {0, 0, 0, 0}, ph = rnd(TAU), fx = 1, at = rnd(2, 4), slow = 0, slowS = 1, burn = 0, bd = 0, bt = 0, dead = false}
    append(G.en, e)
    return e
end

ringPos = function(extra)
    if extra == nil then extra = 60 end
    local a = rnd(TAU)
    local r = (((hypot(W, H) / 2) / ZOOM) + extra)
    return {(G.p.x + (math.cos(a) * r)), (G.p.y + (math.sin(a) * r))}
end

spawnWave = function(dt)
    local t = G.t
    local rate = ((1.5 + (t * 0.036)) * (active(G.endless) and 1.3 or 1))
    G.spawnAcc = G.spawnAcc + (rate * dt)
    while (G.spawnAcc >= 1) do
        repeat
            G.spawnAcc = G.spawnAcc - 1
            if (#G.en >= 330) then
                break
            end
            local r = random()
            local ty = "ghoul"
            local tb = {{"brute", ((t > 120) and math.min(0.14, (0.05 + ((t - 120) / 2500))) or 0)}, {"knight", ((t > 170) and math.min(0.06, (0.03 + ((t - 170) / 3000))) or 0)}, {"bloat", ((t > 140) and 0.045 or 0)}, {"wraith", ((t > 100) and 0.07 or 0)}, {"archer", ((t > 75) and 0.06 or 0)}, {"rat", ((t > 40) and 0.06 or 0)}, {"cult", ((t > 55) and 0.23 or 0)}, {"bat", ((t > 25) and 0.18 or 0)}}
            local q = r
            for _, tuple in ipairs(tb) do
                local k, w = unpack(tuple)
                if (q < w) then
                    ty = k
                    break
                end
                q = q - w
            end
            if (ty == "archer") then
                local c = 0
                for _, e in ipairs(G.en) do
                    if active(e.T.shoot) then
                        c = c + 1
                    end
                end
                if (c >= 12) then
                    ty = "ghoul"
                end
            end
            local x, y = unpack(ringPos())
            if (ty == "rat") then
                for i = 0, 4 - 1 do
                    spawn(ty, (x + rnd((-26), 26)), (y + rnd((-26), 26)))
                end
            else
                spawn(ty, x, y)
            end
            if (active(FIRST[ty]) and (not active(G.ev[("f" .. ty)]))) then
                G.ev[("f" .. ty)] = 1
                bark(FIRST[ty])
            end
        until true
    end
    local ev = G.ev
    local sw = math.floor((t / 40))
    if ((sw > 0) and (ev.sw ~= sw)) then
        ev.sw = sw
        local n = (14 + (sw * 4))
        local r = (((hypot(W, H) / 2) / ZOOM) + 40)
        local ty = (((sw % 3) == 0) and "rat" or (active((sw % 2)) and "bat" or "ghoul"))
        for i = 0, n - 1 do
            local a = ((i / n) * TAU)
            spawn(ty, (G.p.x + (math.cos(a) * r)), (G.p.y + (math.sin(a) * r)))
        end
        if (sw == 1) then
            bark("Se cierran en círculo. Rompe el cerco.")
        end
    end
    if ((t >= 120) and (not active(ev.h1))) then
        ev.h1 = 1
        local x, y = unpack(ringPos())
        spawn("herald", x, y)
        SFX.boss()
        bark("Un Heraldo. Aún recuerda cómo se mata.")
    end
    if ((t >= 200) and (not active(ev.h2))) then
        ev.h2 = 1
        for i = 0, 2 - 1 do
            local x, y = unpack(ringPos())
            spawn("herald", x, y)
        end
        SFX.boss()
        bark("Vienen dos. La abadía no perdona.")
    end
    if ((t >= 240) and (not active(ev.b))) then
        ev.b = 1
        local x, y = unpack(ringPos(20))
        spawn("abbess", x, y)
        SFX.boss()
        G.shake = 14
        bark("La Abadesa Hueca abandona su capilla.")
    end
    if (((t >= 285) and (not active(ev.d))) and (not active(G.endless))) then
        ev.d = 1
        bark("El cielo clarea. Aguanta.")
    end
    if active(G.endless) then
        local hk = math.floor(((t - RUN) / 45))
        if ((hk > 0) and (ev.eh ~= hk)) then
            ev.eh = hk
            local x, y = unpack(ringPos())
            spawn((((hk % 3) == 0) and "abbess" or "herald"), x, y)
            SFX.boss()
        end
    end
end

nearTo = function(x, y, excl, maxd)
    if maxd == nil then maxd = 1000000000 end
    local b = nil
    local bd = (maxd * maxd)
    for _, e in ipairs(G.en) do
        repeat
            if ((e.hp <= 0) or (active(excl) and active(contains(excl, e)))) then
                break
            end
            local d = (((e.x - x) ^ 2) + ((e.y - y) ^ 2))
            if (d < bd) then
                bd = d
                b = e
            end
        until true
    end
    return b
end

aimAt = function(range)
    local p = G.p
    local e = nearTo(p.x, p.y, nil, range)
    return (active(e) and math.atan2((e.y - p.y), (e.x - p.x)) or math.atan2(p.dy, p.dx))
end

num = function(x, y, v, col)
    if (#G.nums > 70) then
        table.remove(G.nums, 1)
    end
    append(G.nums, {x = (x + rnd((-6), 6)), y = y, v = ((type(v) == "number") and round(v) or v), l = 0.6, col = col})
end

heal = function(v)
    local p = G.p
    p.hp = math.min(p.maxhp, (p.hp + v))
end

raw = function(e, d)
    if (e.hp <= 0) then
        return
    end
    e.hp = e.hp - d
    if (e.hp <= 0) then
        kill(e)
    end
end

hit = function(e, dmg, kx, ky, o)
    if kx == nil then kx = 0 end
    if ky == nil then ky = 0 end
    if (e.hp <= 0) then
        return
    end
    local S = G.ST
    local p = G.p
    local m = (S.mi * G.dm)
    if active(e.T.elite) then
        m = m * (1 + S.elite)
    end
    if (active(S.first) and (e.hp >= e.max)) then
        m = m * (1 + S.first)
    end
    if (active(S.last) and (e.hp < (e.max * 0.3))) then
        m = m * (1 + S.last)
    end
    if active(S.torch) then
        local dx = (e.x - p.x)
        local dy = (e.y - p.y)
        if (((dx * dx) + (dy * dy)) < 12100) then
            m = m * (1 + S.torch)
        end
    end
    local crit = (random() < (S.crit + (kin((active(o) and o.crit)) or 0)))
    if active(crit) then
        m = m * S.critm
    end
    local base = dmg
    dmg = dmg * m
    if (active(o) and active(o.slow)) then
        e.slow = 0.7
        e.slowS = o.slow
    end
    if (active(o) and active(o.burn)) then
        e.burn = 2.5
        e.bd = math.max(e.bd, (5 * S.mi))
    end
    e.hp = e.hp - dmg
    e.flash = 0.1
    local kb = (((e.T.heavy == nil) and 1 or e.T.heavy) * S.kb)
    e.kx = e.kx + (kx * kb)
    e.ky = e.ky + (ky * kb)
    num(e.x, (e.y - (e.T.s.h * 0.6)), dmg, (active(crit) and "#f2c14e" or nil))
    SFX.hit()
    if (not (active(o) and active(o.np))) then
        local u = p.up
        if (active(u.escarcha) and (random() < 0.15)) then
            e.slow = 2
            e.slowS = 0.5
        end
        if (active(u.tizon) and (random() < 0.15)) then
            e.burn = 3
            e.bd = math.max(e.bd, (6 * S.mi))
        end
        if (active(crit) and active(u.vamp)) then
            heal(1)
        end
        if (active(crit) and active(u.critexp)) then
            append(G.rings, {x = e.x, y = e.y, r = 50, l = 0.25, l0 = 0.25, col = "242,193,78"})
            areaHit(e.x, e.y, 50, (base * 0.5), 0, {np = 1})
        end
        if (active(u.cadena) and (random() < 0.1)) then
            local o2 = nearTo(e.x, e.y, {e}, 150)
            if active(o2) then
                append(G.bolts, {pts = {e.x, (e.y - 12), o2.x, (o2.y - 12)}, l = 0.15, l0 = 0.15, x = o2.x, y = o2.y, sm = 1, col = "#f2c14e"})
                hit(o2, (base * 0.6), 0, 0, {np = 1})
            end
        end
        if (((active(u.ejecutor) and (not active(e.T.elite))) and (e.hp > 0)) and (e.hp < (e.max * 0.12))) then
            e.hp = 0
        end
    end
    if (e.hp <= 0) then
        kill(e)
    end
end

kill = function(e)
    if active(e.dead) then
        return
    end
    e.dead = true
    e.hp = 0
    G.kills = G.kills + 1
    local T = e.T
    local u = G.p.up
    local S = G.ST
    if active(T.boss) then
        G.abb = G.abb + 1
    else
        if active(T.elite) then
            G.her = G.her + 1
        end
    end
    if (#G.parts < 260) then
        for i = 0, (active(T.elite) and 26 or 6) - 1 do
            local a = rnd(TAU)
            local s = rnd(40, (active(T.elite) and 260 or 150))
            append(G.parts, {x = e.x, y = (e.y - 10), vx = (math.cos(a) * s), vy = ((math.sin(a) * s) - 40), l = rnd(0.25, 0.6), r = rnd(1.5, (active(T.elite) and 5 or 3.5)), c = ((random() < 0.6) and "#090707" or "#6e120d")})
        end
    end
    if (#G.decals > 140) then
        table.remove(G.decals, 1)
    end
    append(G.decals, {x = e.x, y = e.y, r = (T.r * rnd(0.9, 1.5)), a = rnd(TAU), s = rnd(0.4, 0.75)})
    if active(T.elite) then
        for i = 0, (1 + (active(u.botin) and 1 or 0)) - 1 do
            append(G.items, {k = "chest", x = (e.x + (i * 30)), y = e.y})
        end
        G.shake = 12
        for i = 0, 12 - 1 do
            dropGem((e.x + rnd((-40), 40)), (e.y + rnd((-40), 40)), (active(T.boss) and 8 or 3))
        end
    else
        dropGem(e.x, e.y, T.xp)
        if (random() < ((0.012 * (1 + S.luck)) * (active(u.alquimia) and 3 or 1))) then
            append(G.items, {k = "flask", x = (e.x + 8), y = e.y})
        end
    end
    if active(T.burst) then
        append(G.haz, {x = e.x, y = e.y, r = 72, t = 0.8, t0 = 0.8})
    end
    if active(T.boss) then
        bark("Hasta lo hueco puede romperse.")
    end
    if active(S.lsk) then
        heal(S.lsk)
    end
    if (active(u.sed) and ((G.kills % 50) == 0)) then
        heal(10)
        num(G.p.x, (G.p.y - 50), "+10", "#7fd08a")
    end
    if active(u.frenesi) then
        G.frenzy = 2
    end
    if ((active(u.cadaver) and (G.depth < 2)) and (random() < 0.12)) then
        G.depth = G.depth + 1
        append(G.rings, {x = e.x, y = e.y, r = 60, l = 0.3, l0 = 0.3, col = "150,200,110"})
        areaHit(e.x, e.y, 60, 22, 90, {np = 1})
        G.depth = G.depth - 1
    end
end

dropGem = function(x, y, v)
    if (active(G.p.up.rojas) and (random() < 0.1)) then
        v = v * 3
    end
    if (#G.gems > 320) then
        local chosen = G.gems[1 + math.floor((random() * #G.gems))]
        chosen.v = chosen.v + v
        return
    end
    append(G.gems, {x = x, y = y, v = v, m = false, ph = rnd(TAU)})
end

hurtPlayer = function(d, e)
    local p = G.p
    local S = G.ST
    local u = p.up
    if (p.inv > 0) then
        return
    end
    if (random() < S.dodge) then
        p.inv = 0.3
        num(p.x, (p.y - 52), "esquiva", "#8fb6c9")
        return
    end
    if (active(u.barrera) and (G.shield >= 12)) then
        G.shield = 0
        p.inv = 0.6
        append(G.rings, {x = p.x, y = (p.y - 14), r = 60, l = 0.3, l0 = 0.3, col = "111,168,201"})
        return
    end
    d = math.max(1, (d - S.ar))
    p.hp = p.hp - d
    p.inv = ((0.5 + S.inv) + (active(u.sombra) and 0.6 or 0))
    G.shake = math.max(G.shake, 7)
    G.hurt = 1
    SFX.hurt()
    if (active(S.thorns) and active(e)) then
        hit(e, S.thorns, 0, 0, {np = 1})
    end
    if active(u.onda) then
        append(G.rings, {x = p.x, y = (p.y - 10), r = 110, l = 0.3, l0 = 0.3, col = "201,53,42"})
        areaHit(p.x, p.y, 110, 25, 400, {np = 1})
    end
    if active(u.adrenalina) then
        G.adr = 3
    end
    if ((p.hp <= (p.maxhp * 0.3)) and (not active(G.ev.low))) then
        G.ev.low = 1
        bark("La sangre es tinta; no la malgastes.")
    end
end

gridKey = function(cx, cy)
    return ((cx * 4099) + cy)
end

forNear = function(x, y, r, cb)
    local g = G.grid
    local c0 = math.floor(((x - r) / 64))
    local c1 = math.floor(((x + r) / 64))
    local r0 = math.floor(((y - r) / 64))
    local r1 = math.floor(((y + r) / 64))
    for cx = c0, c1 do
        for cy = r0, r1 do
            local a = g[gridKey(cx, cy)]
            if active(a) then
                for i = 0, #a - 1 do
                    local e = a[1 + i]
                    if (e.hp > 0) then
                        cb(e)
                    end
                end
            end
        end
    end
end

areaHit = function(x, y, r, dmg, kb, o)
    if kb == nil then kb = 0 end
    forNear(x, y, (r + 34), function(e)
        local dx = (e.x - x)
        local dy = (e.y - y)
        local d = hypot(dx, dy)
        if (d < (r + e.T.r)) then
            local n = (kin(d) or 1)
            hit(e, dmg, ((dx / n) * kb), ((dy / n) * kb), o)
        end
    end)
end

strikeAt = function(x, y, r, dmg, small)
    local pts = {}
    local bx = (x + rnd((-60), 60))
    for k = 0, 7 do
        local f = (k / 7)
        append(pts, ((bx + ((x - bx) * f)) + ((k < 7) and rnd((-14), 14) or 0)), (y - (520 * (1 - f))))
    end
    append(G.bolts, {x = x, y = y, pts = pts, l = 0.22, l0 = 0.22, r = r})
    areaHit(x, y, r, dmg, 60)
    if (not active(small)) then
        G.shake = math.max(G.shake, 3)
        G.flash = 0.5
        SFX.bolt()
    end
end

addZone = function(x, y, r, dmg, dur, sc, slow, delay, sx, sy)
    if (#G.zones > 40) then
        table.remove(G.zones, 1)
    end
    append(G.zones, {x = x, y = y, sx = sx, sy = sy, r = r, dmg = dmg, delay = (kin(delay) or 0), l = dur, tick = 0, sc = (kin(sc) or "fire"), slow = slow})
end

orbiters = function(k, cnt, R, spd, dmg, kb, col, oi)
    local p = G.p
    for i = 0, cnt - 1 do
        local a = (((G.orbA * spd) + ((i / cnt) * TAU)) + oi)
        local x = (p.x + (math.cos(a) * R))
        local y = ((p.y - 14) + (math.sin(a) * R))
        append(G.orbs, {x = x, y = y, col = col, k = k})
        forNear(x, y, 40, function(e)
            if (e.oc[1 + oi] > 0) then
                return
            end
            local dx = (e.x - x)
            local dy = ((e.y - 10) - y)
            if (((dx * dx) + (dy * dy)) < ((e.T.r + 13) ^ 2)) then
                e.oc[1 + oi] = 0.45
                local q = (kin(hypot((e.x - p.x), (e.y - p.y))) or 1)
                hit(e, dmg, (((e.x - p.x) / q) * kb), (((e.y - p.y) / q) * kb), ((type(k) == "table") and k.ho or nil))
            end
        end)
    end
end

shoot = function(u, D, a, A, extra)
    local p = G.p
    local S = G.ST
    local sp = (u.sp * S.ps)
    append(G.proj, merge({x = p.x, y = (p.y - 14), vx = (math.cos(a) * sp), vy = (math.sin(a) * sp), a = a, dmg = D, pierce = (u.pierce + (active(p.up.punteria) and 2 or 0)), l = (u.life * (active(u.ret) and 1.7 or 1)), l0 = u.life, t = 0, kind = u.kind, col = u.col, r = ((kin(u.r) or 7) * (active(u.r) and A or 1)), ret = u.ret, home = u.home, rehit = u.rehit, kbv = (kin(u.kbv) or 0.2), ho = u.ho, hitL = {}}, extra))
end

ARCH = {slash = function(u, n, D, bon, A)
    local p = G.p
    local R = (u.R * A)
    local a = (active(u.face) and ((p.fx > 0) and 0 or math.pi) or aimAt((R * 1.6)))
    local dirs = (((n >= 4) and (u.arc < 3)) and {a, (a + math.pi)} or {a})
    SFX.slash()
    for _, d in ipairs(dirs) do
        append(G.slashes, {x = p.x, y = (p.y - 14), a = d, R = R, l = 0.2, arc = u.arc, col = u.col})
        forNear(p.x, p.y, (R + 30), function(e)
            local dx = (e.x - p.x)
            local dy = (e.y - p.y)
            local dist = hypot(dx, dy)
            if (dist > (R + e.T.r)) then
                return
            end
            local da = (math.atan2(dy, dx) - d)
            da = math.atan2(math.sin(da), math.cos(da))
            if ((math.abs(da) < (u.arc + (e.T.r / (dist + 1)))) or (dist < (e.T.r + 14))) then
                local q = (kin(dist) or 1)
                hit(e, D, ((dx / q) * u.kb), ((dy / q) * u.kb), (kin(u.ho) or (active(u.crit) and {crit = u.crit} or nil)))
            end
        end)
    end
end, proj = function(u, n, D, bon, A)
    local p = G.p
    local cnt = (u.n + bon)
    local a = ((u.aim == "face") and math.atan2(p.dy, p.dx) or aimAt(520))
    for i = 0, cnt - 1 do
        shoot(u, D, ((u.aim == "rand") and rnd(TAU) or (a + ((i - ((cnt - 1) / 2)) * u.spread))), A)
    end
end, zone = function(u, n, D, bon, A)
    local p = G.p
    local S = G.ST
    local cnt = (1 + math.floor(bon / 2))
    local c = selectFrom(G.en, function(e)
        return ((math.abs((e.x - p.x)) < 300) and (math.abs((e.y - p.y)) < 300))
    end)
    for i = 0, cnt - 1 do
        local tx = (p.x + rnd((-150), 150))
        local ty = (p.y + rnd((-150), 150))
        if active(#c) then
            local e = c[1 + math.floor((random() * #c))]
            tx = (e.x + rnd((-10), 10))
            ty = (e.y + rnd((-10), 10))
        end
        addZone(tx, ty, (u.r * A), D, (u.dur * S.dur), u.sc, u.slow, 0.35, p.x, (p.y - 20))
    end
end, orbit = function(u, n, D, bon, A)
    orbiters(u, (u.n + bon), (u.R * math.sqrt(A)), (u.sp / 2.7), D, u.kb, u.col, u.oi)
end, strike = function(u, n, D, bon, A)
    local p = G.p
    local vw = ((W / ZOOM) / 2)
    local vh = ((H / ZOOM) / 2)
    local c = selectFrom(G.en, function(e)
        return ((math.abs((e.x - p.x)) < vw) and (math.abs((e.y - p.y)) < vh))
    end)
    local cnt = (u.n + bon)
    if active(u.near) then
        table.sort(c, function(a, b)
            local ax, ay = a.x-p.x, a.y-p.y
            local bx, by = b.x-p.x, b.y-p.y
            return ax*ax+ay*ay < bx*bx+by*by
        end)
    end
    for i = 0, cnt - 1 do
        if not active(#c) then break end
        local e = (active(u.near) and table.remove(c, 1) or table.remove(c, 1 + math.floor((random() * #c))))
        if active(u.delay) then
            append(G.pend, {x = e.x, y = e.y, t = u.delay, t0 = u.delay, r = (u.r * A), dmg = D, zone = u.zone})
        else
            strikeAt(e.x, e.y, (u.r * A), D, u.near)
        end
    end
end, aura = function(u, n, D, bon, A, dt, k)
    local p = G.p
    local r = ((u.r * A) * (1 + (0.08 * (n - 1))))
    append(G.auras, {r = r, col = u.col})
    p.cd[k] = ((kin(p.cd[k]) or 0) - dt)
    if (p.cd[k] <= 0) then
        p.cd[k] = 0.45
        areaHit(p.x, p.y, r, D, 0, (kin(u.ho) or (active(u.burn) and {burn = 1} or nil)))
    end
end, nova = function(u, n, D, bon, A)
    local cnt = (u.n + (2 * bon))
    local o = rnd(TAU)
    for i = 0, cnt - 1 do
        shoot({sp = u.sp, pierce = (kin(u.pierce) or 1), life = u.life, kind = "orb", col = cY, r = 6}, D, (o + ((i / cnt) * TAU)), A)
    end
end, wave = function(u, n, D, bon, A)
    local p = G.p
    local r = (u.r * A)
    append(G.rings, {x = p.x, y = (p.y - 10), r = r, l = 0.35, l0 = 0.35, col = "111,168,201"})
    areaHit(p.x, p.y, r, D, u.kb)
    SFX.slash()
end, mine = function(u, n, D, bon, A)
    local p = G.p
    for i = 0, bon do
        if (#G.mines >= 14) then
            table.remove(G.mines, 1)
        end
        append(G.mines, {x = (p.x + (active(i) and rnd((-50), 50) or 0)), y = (p.y + (active(i) and rnd((-50), 50) or 0)), r = (u.r * A), dmg = D, l = u.life, arm = 0.4})
    end
end, chain = function(u, n, D, bon)
    local p = G.p
    local cur = nearTo(p.x, p.y, nil, 330)
    if (not active(cur)) then
        return
    end
    local hl = {}
    local pts = {p.x, (p.y - 14)}
    local j = ((u.jumps + bon) + 1)
    while (active(cur) and (j > 0)) do
        j = j - 1
        append(hl, cur)
        append(pts, cur.x, (cur.y - 12))
        hit(cur, D)
        cur = nearTo(cur.x, cur.y, hl, u.range)
    end
    append(G.bolts, {pts = pts, l = 0.18, l0 = 0.18, x = 0, y = 0, sm = 1, col = "#bfe3ff"})
    SFX.bolt()
end, beam = function(u, n, D, bon, A)
    local p = G.p
    local cnt = (1 + math.floor(bon / 2))
    local wd = (u.wd * A)
    for i = 0, cnt - 1 do
        local a = aimAt(u.len)
        if active(i) then
            local c = G.en[1 + math.floor((random() * #G.en))]
            if active(c) then
                a = math.atan2((c.y - p.y), (c.x - p.x))
            end
        end
        local cx = math.cos(a)
        local cy = math.sin(a)
        append(G.beams, {x = p.x, y = (p.y - 14), a = a, len = u.len, wd = wd, l = 0.2})
        for _, e in ipairs(G.en) do
            repeat
                if (e.hp <= 0) then
                    break
                end
                local dx = (e.x - p.x)
                local dy = (e.y - p.y)
                local al = ((dx * cx) + (dy * cy))
                if ((al < 0) or (al > u.len)) then
                    break
                end
                if (math.abs(((dx * cy) - (dy * cx))) < ((wd / 2) + e.T.r)) then
                    hit(e, D, (cx * 120), (cy * 120))
                end
            until true
        end
    end
    SFX.bolt()
end}

weapons = function(dt)
    local p = G.p
    local S = G.ST
    local u0 = p.up
    local cm = (S.cd * ((G.frenzy > 0) and 0.82 or 1))
    clear(G.orbs)
    clear(G.auras)
    G.orbA = G.orbA + (dt * 2.7)
    for k in pairs(u0) do
        repeat
            if (UP[k].t ~= "w") then
                break
            end
            local n = u0[k]
            local u = ((n > 5) and EV[k] or UP[k])
            local D = (u.d * (1 + (0.28 * (n - 1))))
            local bon = ((((n >= 2) and 1 or 0) + ((n >= 4) and 1 or 0)) + S.amt)
            local A = ((1 + (0.15 * (((n >= 3) and 1 or 0) + ((n >= 5) and 1 or 0)))) * S.area)
            local f = ARCH[u.a]
            if ((u.a == "orbit") or (u.a == "aura")) then
                f(u, n, D, bon, A, dt, k)
                break
            end
            if (p.cd[k] == nil) then
                p.cd[k] = (0.4 + (random() * 0.6))
            end
            p.cd[k] = p.cd[k] - dt
            if (p.cd[k] <= 0) then
                p.cd[k] = (u.cd * cm)
                f(u, n, D, bon, A, dt, k)
                if (active(u0.eco) and (random() < 0.15)) then
                    p.cd[k] = 0.15
                end
            end
        until true
    end
    if active(u0.guardia) then
        orbiters("g", 2, 52, 1.5, 12, 160, cS, 3)
    end
    if active(u0.campanada) then
        G.tcamp = G.tcamp + dt
        if (G.tcamp >= 9) then
            G.tcamp = 0
            append(G.rings, {x = p.x, y = (p.y - 10), r = 150, l = 0.4, l0 = 0.4, col = "201,53,42"})
            areaHit(p.x, p.y, 150, 30, 380)
            G.shake = math.max(G.shake, 4)
            SFX.boss()
        end
    end
    if (active(u0.estela) and active(p.moving)) then
        G.ttrail = G.ttrail - dt
        if (G.ttrail <= 0) then
            G.ttrail = 0.3
            addZone(p.x, p.y, 24, 5, (1.5 * S.dur), "fire")
        end
    end
    G.shield = G.shield + dt
    if active(S.mag) then
        G.tmag = G.tmag + dt
        if (G.tmag >= (36 - (6 * S.mag))) then
            G.tmag = 0
            for _, g in ipairs(G.gems) do
                g.m = true
            end
        end
    end
end

update = function(dt)
    local p = G.p
    local S = G.ST
    local u = p.up
    G.t = G.t + dt
    local mx = 0
    local my = 0
    if (active(keys.KeyA) or active(keys.ArrowLeft)) then
        mx = mx - 1
    end
    if (active(keys.KeyD) or active(keys.ArrowRight)) then
        mx = mx + 1
    end
    if (active(keys.KeyW) or active(keys.ArrowUp)) then
        my = my - 1
    end
    if (active(keys.KeyS) or active(keys.ArrowDown)) then
        my = my + 1
    end
    local mag = hypot(mx, my)
    if (mag > 0) then
        mx = mx / mag
        my = my / mag
        mag = 1
    end
    if active(joy.on) then
        local dx = (joy.x - joy.ox)
        local dy = (joy.y - joy.oy)
        local d = hypot(dx, dy)
        if (d > 6) then
            local k = math.min(1, (d / 46))
            mx = ((dx / d) * k)
            my = ((dy / d) * k)
            mag = k
            if (d > 60) then
                joy.ox = (joy.x - ((dx / d) * 60))
                joy.oy = (joy.y - ((dy / d) * 60))
            end
        end
    end
    local hpf = (p.hp / p.maxhp)
    G.adr = G.adr - dt
    G.frenzy = G.frenzy - dt
    p.moving = (mag > 0.05)
    if active(p.moving) then
        local s = (((150 * S.spd) * ((G.adr > 0) and 1.35 or 1)) * ((active(u.ultima) and (hpf < 0.25)) and 1.2 or 1))
        p.x = p.x + ((mx * s) * dt)
        p.y = p.y + ((my * s) * dt)
        local q = hypot(mx, my)
        p.dx = (mx / q)
        p.dy = (my / q)
        if (math.abs(mx) > 0.15) then
            p.fx = ((mx > 0) and 1 or (-1))
        end
        p.walk = p.walk + ((dt * 11) * mag)
        p.still = 0
    else
        p.still = p.still + dt
    end
    G.dm = ((((((1 + ((hpf < 0.5) and S.low or 0)) + (active(p.moving) and S.move or S.still)) + (S.vet * p.lv)) + (active(u.berserker) and ((1 - hpf) * 0.5) or 0)) + ((active(u.ultima) and (hpf < 0.25)) and 0.4 or 0)) + (active(u.multitud) and math.min(0.3, (#G.en * 0.001)) or 0))
    p.inv = p.inv - dt
    local rg = (S.rg + ((active(u.santuario) and (p.still > 1)) and 3 or 0))
    if active(rg) then
        heal((rg * dt))
    end
    spawnWave(dt)
    local grid = G.grid
    clear(grid)
    for _, e in ipairs(G.en) do
        local k = gridKey(math.floor((e.x / 64)), math.floor((e.y / 64)))
        local a = grid[k]
        if (not active(a)) then
            a = {}
            grid[k] = a
        end
        append(a, e)
    end
    local far = (((hypot(W, H) / ZOOM) * 0.5) + 420)
    for _, e in ipairs(G.en) do
        repeat
            if (e.hp <= 0) then
                break
            end
            local T = e.T
            local dx = (p.x - e.x)
            local dy = (p.y - e.y)
            local d = (kin(hypot(dx, dy)) or 1)
            if (d > far) then
                local x, y = unpack(ringPos())
                e.x = x
                e.y = y
                e.ky = 0
                e.kx = e.ky
                break
            end
            local spd = T.spd
            if (e.slow > 0) then
                e.slow = e.slow - dt
                spd = spd * (active(T.elite) and math.max(0.7, e.slowS) or e.slowS)
            end
            if (e.burn > 0) then
                e.burn = e.burn - dt
                e.bt = e.bt - dt
                if (e.bt <= 0) then
                    e.bt = 0.5
                    num(e.x, (e.y - (e.T.s.h * 0.5)), (e.bd * 0.5), "#f2a83c")
                    raw(e, (e.bd * 0.5))
                    if (e.hp <= 0) then
                        break
                    end
                end
            end
            if active(T.elite) then
                e.at = e.at - dt
                if active(T.boss) then
                    if (e.at <= 0) then
                        e.at = 3.2
                        local n = 12
                        local o = rnd(TAU)
                        for i = 0, n - 1 do
                            local a = (o + ((i / n) * TAU))
                            append(G.eproj, {x = e.x, y = (e.y - 40), vx = (math.cos(a) * 120), vy = (math.sin(a) * 120), l = 5})
                        end
                        if (#G.en < 320) then
                            for i = 0, 4 - 1 do
                                local a = rnd(TAU)
                                spawn("cult", (e.x + (math.cos(a) * 70)), (e.y + (math.sin(a) * 70)))
                            end
                        end
                    end
                else
                    if (e.at <= 0) then
                        e.at = 4.5
                    end
                    if (e.at < 0.9) then
                        spd = spd * 3.2
                    else
                        if (e.at < 1.5) then
                            spd = spd * 0.15
                        end
                    end
                end
            end
            local ux = (dx / d)
            local uy = (dy / d)
            if active(T.weave) then
                local w = (math.sin(((G.t * 3) + e.ph)) * 0.9)
                local nx = (ux - (uy * w))
                local ny = (uy + (ux * w))
                local q = (kin(hypot(nx, ny)) or 1)
                ux = (nx / q)
                uy = (ny / q)
            else
                if active(T.shoot) then
                    e.at = e.at - dt
                    if (d < 170) then
                        ux = (-ux)
                        uy = (-uy)
                        spd = spd * 0.7
                    else
                        if (d < 240) then
                            local sd = ((e.ph < math.pi) and 1 or (-1))
                            local ox = ux
                            ux = ((-uy) * sd)
                            uy = (ox * sd)
                            spd = spd * 0.5
                        end
                    end
                    if (e.at <= 0) then
                        e.at = rnd(2.6, 3.4)
                        if ((d < 430) and (#G.eproj < 60)) then
                            local ax = (p.x - e.x)
                            local ay = ((p.y - 14) - (e.y - 22))
                            local q = (kin(hypot(ax, ay)) or 1)
                            append(G.eproj, {x = e.x, y = (e.y - 22), vx = ((ax / q) * 190), vy = ((ay / q) * 190), l = 3, dmg = 9, ar = 1})
                        end
                    end
                else
                    if active(T.charge) then
                        e.at = e.at - dt
                        if (e.at <= 0) then
                            e.at = rnd(4.5, 6)
                            e.lock = 0
                        end
                        if (e.at < 1.4) then
                            if (not active(e.lock)) then
                                if (d > 380) then
                                    e.at = 2
                                else
                                    e.lock = 1
                                    e.cx = ux
                                    e.cy = uy
                                end
                            end
                            if active(e.lock) then
                                if (e.at < 0.7) then
                                    ux = e.cx
                                    uy = e.cy
                                    spd = spd * 6.5
                                else
                                    spd = 0
                                    if active((math.floor((G.t * 12)) % 2)) then
                                        e.flash = 0.06
                                    end
                                end
                            end
                        end
                    end
                end
            end
            e.x = e.x + (((ux * spd) + e.kx) * dt)
            e.y = e.y + (((uy * spd) + e.ky) * dt)
            local dec = math.exp(((-9) * dt))
            e.kx = e.kx * dec
            e.ky = e.ky * dec
            e.fx = ((dx > 0) and 1 or (-1))
            e.flash = e.flash - dt
            local oc = e.oc
            oc[1] = oc[1] - dt
            oc[2] = oc[2] - dt
            oc[3] = oc[3] - dt
            oc[4] = oc[4] - dt
            if (d < (T.r + 11)) then
                hurtPlayer(T.dmg, e)
            end
        until true
    end
    for _, e in ipairs(G.en) do
        repeat
            if (active(e.T.boss) or active(e.T.ghost)) then
                break
            end
            local cx = math.floor((e.x / 64))
            local cy = math.floor((e.y / 64))
            for ax = (cx - 1), (cx + 1) do
                for ay = (cy - 1), (cy + 1) do
                    repeat
                        local a = grid[gridKey(ax, ay)]
                        if (not active(a)) then
                            break
                        end
                        for i = 0, #a - 1 do
                            repeat
                                local o = a[1 + i]
                                if (o == e) then
                                    break
                                end
                                local dx = (e.x - o.x)
                                local dy = (e.y - o.y)
                                local rr = ((e.T.r + o.T.r) * 0.85)
                                local d2 = ((dx * dx) + (dy * dy))
                                if ((d2 < (rr * rr)) and (d2 > 0.01)) then
                                    local d = math.sqrt(d2)
                                    local push = ((((rr - d) / d) * 0.5) * (active(o.T.elite) and 1 or 0.5))
                                    e.x = e.x + (dx * push)
                                    e.y = e.y + (dy * push)
                                end
                            until true
                        end
                    until true
                end
            end
        until true
    end
    weapons(dt)
    if (#G.proj > 260) then
        dropFirst(G.proj, (#G.proj - 260))
    end
    for _, b in ipairs(G.proj) do
        repeat
            b.t = b.t + dt
            if active(b.home) then
                b.ht = ((kin(b.ht) or 0) - dt)
                if (b.ht <= 0) then
                    b.ht = 0.15
                    local nr = nearTo(b.x, b.y, b.hitL, 500)
                    if active(nr) then
                        local a = math.atan2(((nr.y - 10) - b.y), (nr.x - b.x))
                        local sp = hypot(b.vx, b.vy)
                        b.vx = (math.cos(a) * sp)
                        b.vy = (math.sin(a) * sp)
                        b.a = a
                    end
                end
            end
            if active(b.ret) then
                if ((not active(b.back)) and (b.t > (b.l0 * 0.5))) then
                    b.back = 1
                    clear(b.hitL)
                end
                if active(b.back) then
                    local dx = (p.x - b.x)
                    local dy = ((p.y - 14) - b.y)
                    local d = (kin(hypot(dx, dy)) or 1)
                    local sp = hypot(b.vx, b.vy)
                    b.vx = ((dx / d) * sp)
                    b.vy = ((dy / d) * sp)
                    if (d < 20) then
                        b.l = 0
                    end
                end
            end
            if active(b.rehit) then
                b.rt = ((kin(b.rt) or 0) + dt)
                if (b.rt > b.rehit) then
                    b.rt = 0
                    clear(b.hitL)
                end
            end
            b.x = b.x + (b.vx * dt)
            b.y = b.y + (b.vy * dt)
            b.l = b.l - dt
            if (b.l <= 0) then
                break
            end
            forNear(b.x, (b.y + 10), (b.r + 24), function(e)
                if ((b.l <= 0) or active(contains(b.hitL, e))) then
                    return
                end
                local dx = (e.x - b.x)
                local dy = ((e.y - 10) - b.y)
                if (((dx * dx) + (dy * dy)) < ((e.T.r + b.r) ^ 2)) then
                    append(b.hitL, e)
                    hit(e, b.dmg, (b.vx * b.kbv), (b.vy * b.kbv), b.ho)
                    b.pierce = b.pierce - 1
                    if (b.pierce < 0) then
                        if (active(u.rebote) and (not active(b.bn))) then
                            b.bn = 1
                            b.pierce = 0
                            local nx = nearTo(b.x, b.y, b.hitL, 260)
                            if active(nx) then
                                local a = math.atan2(((nx.y - 10) - b.y), (nx.x - b.x))
                                local sp = hypot(b.vx, b.vy)
                                b.vx = (math.cos(a) * sp)
                                b.vy = (math.sin(a) * sp)
                                b.a = a
                                b.l = math.max(b.l, 0.6)
                            else
                                b.l = 0
                            end
                        else
                            b.l = 0
                        end
                    end
                end
            end)
        until true
    end
    G.proj = retain(G.proj, function(b)
        return (b.l > 0)
    end)
    for _, b in ipairs(G.eproj) do
        b.x = b.x + (b.vx * dt)
        b.y = b.y + (b.vy * dt)
        b.l = b.l - dt
        local dx = (b.x - p.x)
        local dy = (b.y - (p.y - 14))
        if (((dx * dx) + (dy * dy)) < (17 * 17)) then
            hurtPlayer((kin(b.dmg) or 14))
            b.l = 0
        end
    end
    G.eproj = retain(G.eproj, function(b)
        return (b.l > 0)
    end)
    for _, z in ipairs(G.zones) do
        repeat
            if (z.delay > 0) then
                z.delay = z.delay - dt
                break
            end
            z.l = z.l - dt
            z.tick = z.tick - dt
            if (z.tick <= 0) then
                z.tick = 0.3
                areaHit(z.x, z.y, z.r, z.dmg, 0, (active(z.slow) and {slow = z.slow} or nil))
            end
        until true
    end
    G.zones = retain(G.zones, function(z)
        return (z.l > 0)
    end)
    for _, q in ipairs(G.pend) do
        q.t = q.t - dt
        if (q.t <= 0) then
            strikeAt(q.x, q.y, q.r, q.dmg)
            G.shake = math.max(G.shake, 6)
            if active(q.zone) then
                addZone(q.x, q.y, (q.r * 0.7), (q.dmg * 0.1), (2.5 * S.dur), "fire")
            end
        end
    end
    G.pend = retain(G.pend, function(q)
        return (q.t > 0)
    end)
    for _, q in ipairs(G.haz) do
        q.t = q.t - dt
        if (q.t <= 0) then
            append(G.rings, {x = q.x, y = q.y, r = q.r, l = 0.3, l0 = 0.3, col = "150,200,110"})
            areaHit(q.x, q.y, q.r, 25, 160, {np = 1})
            local dx = (p.x - q.x)
            local dy = (p.y - q.y)
            if (((dx * dx) + (dy * dy)) < (q.r * q.r)) then
                hurtPlayer(16)
            end
            G.shake = math.max(G.shake, 4)
        end
    end
    G.haz = retain(G.haz, function(q)
        return (q.t > 0)
    end)
    for _, m in ipairs(G.mines) do
        repeat
            m.l = m.l - dt
            m.arm = m.arm - dt
            if (m.arm > 0) then
                break
            end
            local trig = false
            forNear(m.x, m.y, 20, function(e)
                if ((((e.x - m.x) ^ 2) + ((e.y - m.y) ^ 2)) < ((e.T.r + 12) ^ 2)) then
                    trig = true
                end
            end)
            if active(trig) then
                m.l = 0
                append(G.rings, {x = m.x, y = m.y, r = m.r, l = 0.3, l0 = 0.3, col = "242,168,60"})
                areaHit(m.x, m.y, m.r, m.dmg, 200)
                G.shake = math.max(G.shake, 3)
            end
        until true
    end
    G.mines = retain(G.mines, function(m)
        return (m.l > 0)
    end)
    for _, s in ipairs(G.slashes) do
        s.l = s.l - dt
    end
    G.slashes = retain(G.slashes, function(s)
        return (s.l > 0)
    end)
    for _, b in ipairs(G.bolts) do
        b.l = b.l - dt
    end
    G.bolts = retain(G.bolts, function(b)
        return (b.l > 0)
    end)
    for _, b in ipairs(G.rings) do
        b.l = b.l - dt
    end
    G.rings = retain(G.rings, function(b)
        return (b.l > 0)
    end)
    for _, b in ipairs(G.beams) do
        b.l = b.l - dt
    end
    G.beams = retain(G.beams, function(b)
        return (b.l > 0)
    end)
    G.en = retain(G.en, function(e)
        return (e.hp > 0)
    end)
    local pr = (62 * S.pk)
    local pr2 = (pr * pr)
    for _, g in ipairs(G.gems) do
        local dx = (p.x - g.x)
        local dy = ((p.y - 8) - g.y)
        local d2 = ((dx * dx) + (dy * dy))
        if ((not active(g.m)) and (d2 < pr2)) then
            g.m = true
        end
        if active(g.m) then
            local d = (kin(math.sqrt(d2)) or 1)
            local s = math.max(320, ((150 * S.spd) * 2.2))
            g.x = g.x + (((dx / d) * s) * dt)
            g.y = g.y + (((dy / d) * s) * dt)
            if (d < 16) then
                p.xp = p.xp + (g.v * S.xp)
                g.v = (-g.v)
                if active(u.cosecha) then
                    heal(0.25)
                end
                SFX.gem()
            end
        end
    end
    G.gems = retain(G.gems, function(g)
        return (g.v > 0)
    end)
    while (p.xp >= p.need) do
        p.xp = p.xp - p.need
        p.lv = p.lv + 1
        p.need = math.floor(((4 + (p.lv * 3)) + ((p.lv * p.lv) * 0.4)))
        G.pending = G.pending + 1
    end
    for _, it in ipairs(G.items) do
        local dx = (p.x - it.x)
        local dy = (p.y - it.y)
        if (((dx * dx) + (dy * dy)) < (26 * 26)) then
            it.done = 1
            if (it.k == "flask") then
                local h = (25 * (1 + S.flaskm))
                heal(h)
                num(p.x, (p.y - 50), ("+" .. round(h)), "#7fd08a")
            else
                heal(30)
                G.pending = G.pending + (1 + ((random() < (S.luck * 0.5)) and 1 or 0))
                for _, g in ipairs(G.gems) do
                    g.m = true
                end
            end
        end
    end
    G.items = retain(G.items, function(i)
        return (not active(i.done))
    end)
    for _, q in ipairs(G.parts) do
        q.x = q.x + (q.vx * dt)
        q.y = q.y + (q.vy * dt)
        q.vy = q.vy + (300 * dt)
        q.l = q.l - dt
    end
    G.parts = retain(G.parts, function(q)
        return (q.l > 0)
    end)
    for _, n in ipairs(G.nums) do
        n.y = n.y - (34 * dt)
        n.l = n.l - dt
    end
    G.nums = retain(G.nums, function(n)
        return (n.l > 0)
    end)
    G.shake = G.shake * math.exp(((-7) * dt))
    G.hurt = math.max(0, (G.hurt - (dt * 2.2)))
    G.flash = math.max(0, (G.flash - (dt * 4)))
    if (p.hp <= 0) then
        if (active(u.revive) and (not active(G.revived))) then
            G.revived = 1
            p.hp = (p.maxhp * 0.5)
            p.inv = 2.5
            G.flash = 1
            append(G.rings, {x = p.x, y = (p.y - 10), r = 220, l = 0.5, l0 = 0.5, col = "246,236,208"})
            areaHit(p.x, p.y, 220, 60, 500, {np = 1})
            bark("Todavía no. La vigilia no ha terminado.")
        else
            p.hp = 0
            updHud()
            endRun(false)
            return
        end
    end
    if (((not active(G.endless)) and (not active(G.won))) and (G.t >= RUN)) then
        G.won = true
        for _, e in ipairs(G.en) do
            if (#G.parts < 260) then
                for i = 0, 4 - 1 do
                    local a = rnd(TAU)
                    local s = rnd(40, 150)
                    append(G.parts, {x = e.x, y = (e.y - 10), vx = (math.cos(a) * s), vy = ((math.sin(a) * s) - 40), l = rnd(0.25, 0.6), r = rnd(1.5, 3.5), c = "#f2c14e"})
                end
            end
        end
        G.en = {}
        G.eproj = {}
        updHud()
        endRun(true)
        return
    end
    if (G.pending > 0) then
        openLevelUp()
    end
    updHud()
end

V.update = update

function V.newRun(id)
    local class = V.CLS[math.floor(id / 10)+1]
    local trait = V.TRT[id % 10+1]
    local mods = {hp=0, spd=1, mi=1, cd=1, pk=1, ar=0, rg=0, xp=1}
    for _, source in ipairs({class.m, trait.m}) do
        for k, value in pairs(source) do
            if k == "hp" or k == "ar" or k == "rg" then mods[k] = mods[k]+value
            else mods[k] = mods[k]*value end
        end
    end
    local upgrades = {[class.w]=1}
    if trait.two then
        for i, weapon in ipairs(V.WPN) do
            if weapon == class.w then upgrades[V.WPN[i % #V.WPN+1]]=1 end
        end
    end
    G = {
        id=id, M=mods, glass=trait.glass, t=0, kills=0, her=0, abb=0,
        p={x=0,y=0,hp=0,maxhp=0,inv=0,lv=1,xp=0,need=5,fx=1,dx=1,dy=0,walk=0,still=0,up=upgrades,cd={}},
        en={},proj={},eproj={},zones={},slashes={},bolts={},gems={},items={},parts={},decals={},nums={},mines={},
        pend={},haz={},rings={},beams={},orbs={},auras={},ev={},grid={},spawnAcc=0,pending=0,shake=0,hurt=0,
        orbA=0,flash=0,dm=1,frenzy=0,adr=0,shield=12,tcamp=0,tmag=0,ttrail=0,depth=0
    }
    clear(keys)
    recalc()
    V.game = G
    return G
end

function V.offers()
    local owned, pool, cards = {w=0,r=0,a=0}, {}, {}
    local up = G.p.up
    local caps = {w=up.arsenal and 6 or 5, r=5, a=5}
    local count = up.erudito and 4 or 3
    for k, n in pairs(up) do
        local category = UP[k].t
        owned[category] = owned[category]+1
        if n == 5 and V.EVO[k] and up[V.EVO[k][1]] and #cards < count then cards[#cards+1]="^"..k end
    end
    local total = 0
    for k, item in pairs(UP) do
        if (up[k] or 0) < item.max and (up[k] or owned[item.t] < caps[item.t]) then
            local weight = up[k] and 4 or (item.t=="w" and 1.3 or 1)
            pool[#pool+1]={k,weight}
            total=total+weight
        end
    end
    while #cards<count and #pool>0 do
        local draw = random()*total
        for i, entry in ipairs(pool) do
            draw=draw-entry[2]
            if draw<=0 or i==#pool then
                cards[#cards+1]=entry[1]
                total=total-entry[2]
                table.remove(pool,i)
                break
            end
        end
    end
    if #cards==0 then cards[1]="_heal" end
    return cards
end

function V.applyCard(k)
    local p=G.p
    if k=="_heal" then heal(40)
    elseif k:sub(1,1)=="^" then
        local weapon=k:sub(2)
        p.up[weapon]=6
        p.cd[weapon]=nil
        G.flash=1
        G.rings[#G.rings+1]={x=p.x,y=p.y-10,r=180,l=.5,l0=.5,col="242,193,78"}
        SFX.win()
        bark("El acero recuerda su nombre: "..EV[weapon].name..".")
    else
        p.up[k]=(p.up[k] or 0)+1
        recalc()
    end
    G.pending=G.pending-1
    if G.pending>0 then V.reveal(); return end
    V.change("play")
    p.inv=math.max(p.inv,.6)
    if p.up.imanalmas then for _, gem in ipairs(G.gems) do gem.m=true end end
    if p.up.final then
        local count=0
        for _, e in ipairs(G.en) do
            if math.abs(e.x-p.x)<W/2 and math.abs(e.y-p.y)<H/2 then
                strikeAt(e.x,e.y,30,40,true)
                count=count+1
                if count>=46 then break end
            end
        end
        if count>0 then G.flash=.8; SFX.bolt() end
    end
end
