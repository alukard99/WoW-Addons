-- Lados · lógica del juego (traducción de index.html a Lua)
-- Los índices de figura empiezan en 0, como en el juego original, para que las fórmulas de equilibrio
-- sean idénticas. S.polish[0] es el círculo.
local _, L = ...
local T = L.T -- traducción (Locale.lua)
L.VERSION = "1.1.0"

local pi, sin, cos, floor, ceil, min, max, sqrt, abs = math.pi, math.sin, math.cos, math.floor, math.ceil, math.min, math.max, math.sqrt, math.abs
local random = math.random
local function hypot(x, y) return sqrt(x * x + y * y) end
local log10 = math.log10 or function(x) return math.log(x) / math.log(10) end
L.hypot = hypot

-- Funciones que pone otro archivo (sonido, dibujo, interfaz). Hasta entonces no hacen nada.
local function call(name, ...) local f = L[name]; if f then return f(...) end end

-- ---------- Figuras ----------
local function regular(n)
  local v = {}
  for k = 0, n - 1 do local a = -pi / 2 + k * 2 * pi / n; v[#v + 1] = {cos(a), sin(a)} end
  return v
end
local function starVerts(p, inner)
  local v = {}
  for k = 0, 2 * p - 1 do
    local a, r = -pi / 2 + k * pi / p, (k % 2 == 1) and inner or 1
    v[#v + 1] = {r * cos(a), r * sin(a)}
  end
  return v
end
local function gearVerts(t)
  local P, ri, v = 2 * pi / t, 0.78, {}
  local steps = {{ri, 0}, {1, 0.12}, {1, 0.38}, {ri, 0.5}}
  for k = 0, t - 1 do
    local a = -pi / 2 + k * P
    for _, rf in ipairs(steps) do v[#v + 1] = {rf[1] * cos(a + rf[2] * P), rf[1] * sin(a + rf[2] * P)} end
  end
  return v
end
local SHAPE_DEFS = {
  {T"Círculo", false}, {T"Triángulo", regular(3)}, {T"Cuadrado", regular(4)}, {T"Pentágono", regular(5)},
  {T"Hexágono", regular(6)}, {T"Heptágono", regular(7)}, {T"Octágono", regular(8)}, {T"Eneágono", regular(9)},
  {T"Decágono", regular(10)}, {T"Endecágono", regular(11)}, {T"Dodecágono", regular(12)},
  {T"Pentagrama", starVerts(5, 0.45)}, {T"Hexagrama", starVerts(6, 0.55)}, {T"Heptagrama", starVerts(7, 0.55)},
  {T"Octagrama", starVerts(8, 0.6)}, {T"Decagrama", starVerts(10, 0.65)}, {T"Dodecagrama", starVerts(12, 0.7)},
  {T"Engranaje VI", gearVerts(6)}, {T"Engranaje VIII", gearVerts(8)}, {T"Engranaje X", gearVerts(10)}, {T"Engranaje XII", gearVerts(12)},
  {T"Hectágono", regular(100)},
}
local FAMILIES = {{0, T"Polígonos"}, {11, T"Estrellas"}, {17, T"Engranajes"}, {21, "Final"}}

-- hsl(h 70% 55%) → rgb, igual que el CSS del juego
local function hsl(h, s, l)
  local a = s * min(l, 1 - l)
  local function f(n) local k = (n + h / 30) % 12; return l - a * max(-1, min(k - 3, 9 - k, 1)) end
  return f(0), f(8), f(4)
end
L.hsl = hsl

local SHAPES, N = {}, #SHAPE_DEFS
for k, def in ipairs(SHAPE_DEFS) do
  local i, verts = k - 1, def[2] or nil
  local hue = (210 + i * 137.508) % 360
  local r, g, b = hsl(hue, 0.7, 0.55)
  SHAPES[i] = {name = def[1], verts = verts, sides = verts and #verts or 1, hue = hue, r = r, g = g, b = b}
end
L.SHAPES, L.N, L.FAMILIES = SHAPES, N, FAMILIES

local function famIdx(i) local c = 0; for _, f in ipairs(FAMILIES) do if i >= f[1] then c = c + 1 end end; return c - 1 end
local function familyOf(i) return FAMILIES[famIdx(i) + 1][2] end
local function isFamStart(i) for _, f in ipairs(FAMILIES) do if f[1] == i then return true end end; return false end
L.famIdx, L.familyOf, L.isFamStart = famIdx, familyOf, isFamStart

-- ---------- Equilibrio ----------
local BAL = {unlock = 13, polish = 8, coord = 15, wall = 30, arista = 0.15, gun = 4, power = 2.5, prest = 1e11}
L.BAL = BAL
local function famWall(i) return BAL.wall ^ famIdx(i) end
local function sideValue(i) return i < 2 and 1 or 5 ^ (i - 1) end
local function unlockCost(i) return floor(25 * BAL.unlock ^ (i - 1) * famWall(i) + 0.5) end
local GUN_STEPS = {25, 1500, 3e4, 5e5, 2e6}
local GUN_BASE = GUN_STEPS[1]
local function gunCost(lv)
  lv = lv or L.S.guns
  if lv < #GUN_STEPS then return GUN_STEPS[lv + 1] end
  return ceil(GUN_STEPS[#GUN_STEPS] * BAL.gun ^ (lv - #GUN_STEPS + 1))
end
local function shapeBase(i) return i == 0 and 25 or 75 * 6 ^ (i - 1) * famWall(i) end
local function polishBase(i) return i == 0 and 100 or shapeBase(i) * 5 end
local function polishCost(i, lv) return ceil(polishBase(i) * BAL.polish ^ (lv or L.S.polish[i])) end
local ATTRACT_GROWTH, ATTRACT_BONUS = 5, 0.5
local function attractCost(i, lv) return ceil(shapeBase(i) * 3 * ATTRACT_GROWTH ^ (lv or L.S.attract[i])) end
local function coordCost(lv) return ceil(500 * BAL.coord ^ (lv or L.S.coord)) end
L.sideValue, L.unlockCost, L.ATTRACT_BONUS = sideValue, unlockCost, ATTRACT_BONUS

local mods = {}                                   -- modificador → segundos que le quedan
local function modOn(k) return (mods[k] or 0) > 0 end
L.mods, L.modOn = mods, modOn

local function lvl(k) return L.S.ups[k] or 0 end
local function perk(k) return L.S.meta.perks[k] or 0 end
local function totalTurrets() return L.S.guns end
L.lvl, L.perk = lvl, perk

-- se rellena más abajo (los logros miran cuántos modificadores hay activos)
local MODS

local function plural(n, one, many) return n == 1 and one or many end

local EXTRAS = {
  {key = "crit", name = T"Crítico", desc = T"+5% de impactos con daño ×5", max = 10, base = 1e3, growth = 7,
   req = function() return totalTurrets() >= 3 end, status = function(l) return (l * 5) .. T"% críticos" end},
  {key = "bounce", name = T"Rebote", desc = T"el pulso salta a otra figura cercana", max = 10, base = 5e3, growth = 12,
   req = function() return totalTurrets() >= 4 and L.S.unlocked >= 3 end, status = function(l) return l .. " " .. plural(l, T"rebote", T"rebotes") end},
  {key = "pierce", name = T"Atravesar", desc = T"el pulso daña lo que cruza de camino", max = 10, base = 5e4, growth = 15,
   req = function() return L.S.unlocked >= 5 end, status = function(l) return T"atraviesa " .. l end},
  {key = "blast", name = T"Explosión", desc = T"al romperse, daña lo cercano de su nivel o menor", max = 10, base = 2.5e5, growth = 15,
   req = function() return L.S.unlocked >= 6 end, status = function(l) return l .. " " .. plural(l, T"lado", T"lados") .. T" de daño" end},
}
L.EXTRAS = EXTRAS
local function extraCost(u, lv) return ceil(u.base * u.growth ^ (lv or lvl(u.key))) end
local CRIT_MULT = 5
local function critChance() return 0.05 * lvl("crit") end
local function punchCost(lv) return ceil(300 * 8 ^ (lv or L.S.punch)) end
local function punchPower() return 2 ^ L.S.punch * (modOn("smash") and 10 or 1) end
local function speed() return BAL.power * 1.5 ^ L.S.coord * 1.25 ^ perk("vet") end
local function fireRate() return L.S.guns * speed() * (modOn("frenzy") and 3 or 1) end
local function reward(i) return SHAPES[i].sides * sideValue(i) * 2 ^ L.S.polish[i] end
L.punchPower, L.fireRate, L.reward = punchPower, fireRate, reward

-- ---------- Números ----------
local SUF = {"", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"}
local function fmt(n)
  if n ~= n then return "0" end
  if n < 1000 then
    if n < 10 and n % 1 ~= 0 then return (string.format("%.1f", n):gsub("%.0$", "")) end
    return string.format("%d", floor(n))
  end
  local e = floor(log10(n) / 3)
  if e >= #SUF then return (string.format("%.2e", n):gsub("%+", "")) end
  local s = string.format("%.2f", n / 1000 ^ e)
  s = s:gsub("0+$", ""):gsub("%.$", "")
  return s .. SUF[e + 1]
end
L.fmt = fmt
local function fmtTime(sec)
  local h, m, s = floor(sec / 3600), floor(sec % 3600 / 60), floor(sec % 60)
  if h > 0 then return h .. " h " .. m .. " min" end
  if m > 0 then return m .. " min " .. s .. " s" end
  return s .. " s"
end
L.fmtTime = fmtTime

-- ---------- Dimensiones (prestigio) ----------
local function aristasFor(total) return total < BAL.prest and 0 or floor(3 * (total / BAL.prest) ^ BAL.arista) end
local ARISTA_BONUS = 0.02
local function startCoins(lv) return lv > 0 and 100 * 10 ^ (lv - 1) or 0 end
local PERKS = {
  {key = "mult", name = T"Resonancia", desc = T"×1,5 a todas las ganancias", base = 1, growth = 2.2, max = 50,
   status = function(l) return "×" .. fmt(1.5 ^ l) end},
  {key = "vet", name = T"Torretas veteranas", desc = T"+25% de cadencia en todas las torretas", base = 2, growth = 2.5, max = 30,
   status = function(l) return "×" .. fmt(1.25 ^ l) .. T" cadencia" end},
  {key = "seed", name = T"Semilla", desc = T"empiezas cada dimensión con monedas", base = 1, growth = 3, max = 20,
   status = function(l) return fmt(startCoins(l)) .. T" al empezar" end},
  {key = "memory", name = T"Memoria geométrica", desc = T"empiezas con una figura más desbloqueada", base = 5, growth = 4, max = 9,
   status = function(l) return (l + 1) .. T" figuras al empezar" end},
  {key = "anomaly", name = T"Imán de anomalías", desc = T"modificadores más frecuentes y largos", base = 3, growth = 3, max = 8,
   status = function(l) return string.format(T"×%.1f frecuencia · ×%.1f duración", 1 / 0.85 ^ l, 1 + 0.2 * l) end},
}
L.PERKS, L.ARISTA_BONUS, L.aristasFor = PERKS, ARISTA_BONUS, aristasFor
local function perkCost(u) return ceil(u.base * u.growth ^ perk(u.key)) end
local function dimName() return (2 + L.S.meta.dims) .. "D" end
L.perkCost, L.dimName = perkCost, dimName

-- ---------- Logros ----------
local ACH_BONUS = 0.02
local function st() return L.S.meta.stats end
local function activeMods() local c = 0; for _, m in ipairs(MODS) do if modOn(m.key) then c = c + 1 end end; return c end
local ACHS = {
  {"first", T"Primer lado", T"Rompe tu primera figura", function() return st().broken >= 1 end},
  {"circ100", T"Cien círculos", T"Rompe 100 círculos", function() return (st().per[0] or 0) >= 100 end},
  {"b1k", T"Mil figuras", T"Rompe 1.000 piezas", function() return st().broken >= 1e3 end},
  {"b10k", T"Diez mil", T"Rompe 10.000 piezas", function() return st().broken >= 1e4 end},
  {"b100k", T"Cien mil", T"Rompe 100.000 piezas", function() return st().broken >= 1e5 end},
  {"t1", T"Primera torreta", T"Compra una torreta", function() return totalTurrets() >= 1 end},
  {"t50", T"Batería", T"Ten 10 torretas a la vez", function() return totalTurrets() >= 10 end},
  {"t200", T"Arsenal", T"Ten 25 torretas a la vez", function() return totalTurrets() >= 25 end},
  {"polys", T"Polígonos completos", T"Desbloquea el dodecágono", function() return L.S.unlocked >= 11 end},
  {"stars", T"Estrellado", T"Desbloquea el pentagrama", function() return L.S.unlocked >= 12 end},
  {"gears", T"Engranado", T"Desbloquea el primer engranaje", function() return L.S.unlocked >= 18 end},
  {"hecto", T"Cien lados", T"Desbloquea el hectágono", function() return L.S.unlocked >= N end},
  {"comp1", T"Desmontaje", T"Rompe una figura compuesta entera", function() return st().comps >= 1 end},
  {"comp100", T"Arquitecto", T"Rompe 100 figuras compuestas", function() return st().comps >= 100 end},
  {"clicks", T"Manos firmes", T"Haz 1.000 clics sobre figuras", function() return st().clicks >= 1e3 end},
  {"punch5", T"Puño de acero", T"Sube Golpe a nivel 5", function() return L.S.punch >= 5 end},
  {"pulse1m", T"Red de enlaces", T"Envía 1.000.000 de pulsos", function() return (st().pulses or 0) >= 1e6 end},
  {"mod1", T"Anomalía", T"Activa un modificador", function() return st().mods >= 1 end},
  {"mod3", T"Caos controlado", T"Ten 3 modificadores activos a la vez", function() return activeMods() >= 3 end},
  {"chain5", T"Reacción en cadena", T"Rompe 5 piezas con una sola explosión", function() return st().chain >= 5 end},
  {"m1e6", T"Millonario", T"Gana 1M monedas en total", function() return st().lifetime >= 1e6 end},
  {"m1e12", T"Billonario", T"Gana 1T monedas en total", function() return st().lifetime >= 1e12 end},
  {"m1e18", T"Trillonario", T"Gana 1Qi monedas en total", function() return st().lifetime >= 1e18 end},
  {"boss1", T"Cazador", T"Derrota a un jefe", function() return st().bosses >= 1 end},
  {"boss10", T"Matagigantes", T"Derrota a 10 jefes", function() return st().bosses >= 10 end},
  {"dim1", T"Otra dimensión", T"Sube de dimensión por primera vez", function() return L.S.meta.dims >= 1 end},
  {"dim5", T"Viajero", T"Sube de dimensión 5 veces", function() return L.S.meta.dims >= 5 end},
}
L.ACHS, L.ACH_BONUS = ACHS, ACH_BONUS
local function achCount() local c = 0; for _, a in ipairs(ACHS) do if L.S.meta.ach[a[1]] then c = c + 1 end end; return c end
L.achCount = achCount
local function incomeMult()
  return (1 + ARISTA_BONUS * L.S.meta.aristasTotal) * 1.5 ^ perk("mult") * (1 + ACH_BONUS * achCount())
end
L.incomeMult = incomeMult

-- ---------- Estado ----------
local function zeros() local t = {}; for i = 0, N - 1 do t[i] = 0 end; return t end
local function newStats() return {broken = 0, per = {}, comps = 0, clicks = 0, mods = 0, chain = 0, lifetime = 0, bosses = 0, pulses = 0} end
local function newMeta() return {dims = 0, aristas = 0, aristasTotal = 0, perks = {}, ach = {}, stats = newStats()} end
local function fresh()
  return {coins = 0, total = 0, unlocked = 1, seen = {}, guns = 0, polish = zeros(), attract = zeros(),
    coord = 0, designs = 0, punch = 0, ups = {}, meta = newMeta()}
end
L.fresh = fresh
function L.demoState() local s = fresh(); s.unlocked = N; s.designs = 7; return s end
local function earn(n) local S = L.S; S.coins = S.coins + n; S.total = S.total + n; S.meta.stats.lifetime = S.meta.stats.lifetime + n end
L.earn = earn
local function startRun(meta)
  local s = fresh(); s.meta = meta
  s.unlocked = min(N, 1 + (meta.perks.memory or 0))
  s.coins = startCoins(meta.perks.seed or 0); s.total = s.coins
  if meta.dims > 0 then s.seen.dim = 1 end
  return s
end
-- Completa una partida guardada con los campos que falten (por si una versión nueva añade alguno)
function L.loadState(raw)
  if type(raw) ~= "table" then return fresh() end
  for k, v in pairs(fresh()) do if raw[k] == nil then raw[k] = v end end
  for i = 0, N - 1 do raw.polish[i] = raw.polish[i] or 0; raw.attract[i] = raw.attract[i] or 0 end
  local m = newMeta()
  for k, v in pairs(m) do if raw.meta[k] == nil then raw.meta[k] = v end end
  for k, v in pairs(newStats()) do if raw.meta.stats[k] == nil then raw.meta.stats[k] = v end end
  raw.unlocked = min(raw.unlocked, N)
  raw.total = max(raw.total, raw.coins)
  return raw
end

L.S = L.demoState()
L.inGame, L.menuOpen = false, true

-- ---------- Figuras compuestas ----------
local DESIGNS = {
  {name = T"Molino", core = 2, mods = {1}},
  {name = T"Estrella", core = 3, mods = {1}},
  {name = T"Flor", core = 4, mods = {0}},
  {name = T"Panal", core = 4, mods = {2, 0}},
  {name = T"Corona", core = 6, mods = {3, 1}},
  {name = T"Mandala", core = 8, mods = {5, 2}},
  {name = T"Rosetón", core = 10, mods = {7, 4, 1}},
}
L.DESIGNS = DESIGNS                                     -- DESIGNS[d + 1] es el diseño d
local function designTop(d) local D = DESIGNS[d + 1]; local t = D.core; for _, m in ipairs(D.mods) do t = max(t, m) end; return t end
local function designCost(d) return unlockCost(designTop(d)) * 4 * 2 ^ (#DESIGNS[d + 1].mods - 1) end
local COMP_CHANCE = 0.3
L.designCost = designCost

local function designParts(d, rm)
  rm = rm or 17
  local D = DESIGNS[d + 1]
  local n = SHAPES[D.core].sides
  if n >= 8 then rm = 20 end
  local rc = max(34, 1.15 * rm / sin(pi / n))
  local parts = {{i = D.core, r = rc, ox = 0, oy = 0, rot = 0, layer = 0}}
  local apo = rc * cos(pi / n)
  for k = 0, n - 1 do
    local mod = D.mods[k % #D.mods + 1]
    local m = SHAPES[mod].sides
    local mApo = m == 1 and rm or rm * cos(pi / m)
    local a = -pi / 2 + (k + 0.5) * 2 * pi / n
    local dist = apo + mApo + 3
    parts[#parts + 1] = {i = mod, r = rm, ox = cos(a) * dist, oy = sin(a) * dist, rot = a + pi / 2, layer = 1}
  end
  return parts
end
L.designParts = designParts
local function designMult(parts)
  local kinds, c = {}, 0
  for k = 2, #parts do if not kinds[parts[k].i] then kinds[parts[k].i] = true; c = c + 1 end end
  return 2 ^ c
end
function L.designValue(d)
  local ps, sum = designParts(d), 0
  for _, p in ipairs(ps) do sum = sum + reward(p.i) end
  return sum * designMult(ps)
end

-- ---------- Mapa ----------
-- Todo vive en coordenadas del mundo; W y H son el tamaño del mundo (la ventana a escala SCALE).
L.W, L.H, L.SCALE, L.floorY = 1200, 900, 0.5, 860
local SPAWN_EVERY = 0.6
-- Algo menos de figuras que en el juego original: en WoW cada lado es un objeto de la interfaz
local function maxOnMap() return min(30, 8 + 2 * L.S.unlocked) end
local ents, dying, bullets, rings, powerups = {}, {}, {}, {}, {}
L.ents, L.dying, L.bullets, L.rings, L.powerups = ents, dying, bullets, rings, powerups
local spawnT = SPAWN_EVERY
local streamT = {}
for i = 0, N - 1 do streamT[i] = 0 end

local function mkPart(p)
  p.hits, p.incoming, p.flash, p.dead, p.layer, p.mul = 0, 0, 0, false, p.layer or 0, p.mul or 1
  return p
end
local function isCore(e, p) return p == e.parts[1] end
local function shielded(e, p)
  for _, q in ipairs(e.parts) do if not q.dead and q.layer > p.layer then return true end end
  return false
end
local function spare(p) return (SHAPES[p.i].sides - p.hits) * p.mul - p.incoming end
local function free(p) return spare(p) > 1e-9 end
local function targetable(e, p) return not p.dead and not shielded(e, p) and free(p) end
local function boundR(e)
  local R = 0
  for _, p in ipairs(e.parts) do if not p.dead then R = max(R, hypot(p.ox, p.oy) + p.r) end end
  return R
end
local function partPos(e, p)
  local c, s = cos(e.a), sin(e.a)
  return e.x + p.ox * c - p.oy * s, e.y + p.ox * s + p.oy * c, e.a + p.rot
end
L.shielded, L.partPos = shielded, partPos

local function removeEnt(e)
  for j = #ents, 1, -1 do if ents[j] == e then table.remove(ents, j); break end end
  e.gone = true
end

local function baseWeight(i) return 1.25 ^ i end
local function spawnWeight(i) return baseWeight(i) * (1 + ATTRACT_BONUS * L.S.attract[i]) end
L.spawnWeight = spawnWeight
local function pickType()
  local S = L.S
  if S.designs > 0 and random() < COMP_CHANCE then return {d = floor(random() * S.designs)} end
  local total = 0
  for i = 0, S.unlocked - 1 do total = total + spawnWeight(i) end
  local roll = random() * total
  for i = 0, S.unlocked - 1 do roll = roll - spawnWeight(i); if roll < 0 then return {i = i} end end
  return {i = S.unlocked - 1}
end
local function shapeR(i) return 26 + 6 * sqrt(SHAPES[i].sides) end

local function spawn(what)
  what = what or pickType()
  local comp = what.d ~= nil
  local parts = comp and designParts(what.d) or {{i = what.i, r = shapeR(what.i), ox = 0, oy = 0, rot = 0}}
  for _, p in ipairs(parts) do mkPart(p) end
  local e = {parts = parts, a = random() * 6.28, va = (random() - 0.5) * (comp and 0.6 or 1.2), inside = false}
  e.R = boundR(e)
  local W, fy, r = L.W, L.floorY, e.R
  local edge = floor(random() * 3)
  e.x = edge == 1 and W + r or edge == 2 and -r or random() * W
  e.y = edge == 0 and -r or random() * max(1, fy - 2 * r) + r
  local tx, ty = W * (0.15 + random() * 0.7), fy * (0.15 + random() * 0.7)
  local sp = comp and 45 + random() * 35 or 70 + random() * 80
  local d = hypot(tx - e.x, ty - e.y); if d == 0 then d = 1 end
  e.vx, e.vy = (tx - e.x) / d * sp, (ty - e.y) / d * sp
  ents[#ents + 1] = e
  return e
end
L.spawn = spawn

-- ---------- Jefes ----------
local BOSS_TIME, BOSS_BONUS, BOSS_MIN_SHAPES = 120, 3, 3
local BOSS_FIRST = 150
local function bossGap() return 240 + random() * 120 end
local bossT = BOSS_FIRST
L.boss, L.BOSS_TIME, L.BOSS_BONUS = nil, BOSS_TIME, BOSS_BONUS
local BOSS_NAMES = {T"Coloso", T"Titán", T"Leviatán", T"Monolito", T"Behemot"}
local function bossHP(e)
  local hp = 0
  for _, p in ipairs(e.parts) do if not p.dead then hp = hp + (SHAPES[p.i].sides - p.hits) * p.mul end end
  return hp
end
L.bossHP = bossHP

local function noteOf(i, k) return call("noteOf", i, k) or 60 end

local function spawnBoss()
  local S = L.S
  local top = S.unlocked - 1
  local function sub(k) return max(0, top - k) end
  local rc, r1, r2 = 70, 24, 18
  local d1 = rc + r1 + 14
  local d2 = d1 + r1 + r2 + 14
  local parts = {{i = top, r = rc, ox = 0, oy = 0, rot = 0, layer = 0}}
  local function ring(count, types, r, dist, layer, off)
    for k = 0, count - 1 do
      local a = -pi / 2 + (k + off) * 2 * pi / count
      parts[#parts + 1] = {i = types[k % #types + 1], r = r, ox = cos(a) * dist, oy = sin(a) * dist, rot = a + pi / 2, layer = layer}
    end
  end
  ring(6, {sub(1), sub(2)}, r1, d1, 1, 0.5)
  ring(12, {sub(2), sub(3), sub(1)}, r2, d2, 2, 0)
  local R0 = d2 + r2
  local f = min(1, L.floorY * 0.4 / R0, L.W * 0.4 / R0)
  for _, q in ipairs(parts) do q.r, q.ox, q.oy = q.r * f, q.ox * f, q.oy * f end
  local LAYER_SECS = {[0] = 12, 14, 16}
  local rate = fireRate() * 0.7 + 0.5 * punchPower()
  for layer = 0, 2 do
    local need = 0
    for _, q in ipairs(parts) do if q.layer == layer then need = need + SHAPES[q.i].sides end end
    for _, q in ipairs(parts) do if q.layer == layer then q.mul = max(1, LAYER_SECS[layer] * rate / need) end end
  end
  for _, p in ipairs(parts) do mkPart(p) end
  local e = {parts = parts, a = 0, va = 0.12, inside = false, boss = true, paid = 0, t = 0,
    name = BOSS_NAMES[floor(random() * #BOSS_NAMES) + 1] .. " · " .. SHAPES[top].name}
  e.R = boundR(e)
  e.x, e.y, e.vx, e.vy = L.W / 2, -e.R, (random() - 0.5) * 40, 70
  e.hp0 = bossHP(e)
  ents[#ents + 1] = e; L.boss = e
  call("musicStart", noteOf(top, 0))
  call("toast", T"¡Llega un jefe!", e.name .. T" · rompe sus anillos de fuera hacia dentro")
end

local function updateBoss(dt)
  local boss = L.boss
  if not boss then
    if L.S.unlocked >= BOSS_MIN_SHAPES then
      bossT = bossT - dt
      if bossT <= 0 then spawnBoss() end
    end
    return
  end
  boss.t = boss.t + dt
  local top = 0
  for _, p in ipairs(boss.parts) do if not p.dead then top = max(top, p.layer) end end
  call("musicLevel", 3 - top)
  if boss.t > BOSS_TIME then
    boss.leaving, boss.inside, boss.vy, boss.vx = true, false, -160, 0
    call("toast", T"El jefe ha escapado", T"Lo que rompiste ya está cobrado. Volverá otro.")
    call("musicStop", false)
    L.boss = nil; bossT = bossGap()
  end
end
local function bossDefeated(e)
  local s = L.S.meta.stats
  s.bosses = (s.bosses or 0) + 1
  if e == L.boss then L.boss = nil; bossT = bossGap() end
  call("musicStop", true)
  call("toast", T"¡Jefe derrotado!", e.name .. T" · paga ×" .. (BOSS_BONUS + 1) .. T" lo que valían sus piezas")
end

-- ---------- Flujo de figuras para las torretas ----------
local SUPPLY = 0.7
local function streamMax() return min(25, 4 + 2 * L.S.unlocked) end
local function streamRate(i)
  local S = L.S
  local wsum, ssum = 0, 0
  for j = 0, S.unlocked - 1 do wsum = wsum + baseWeight(j); ssum = ssum + baseWeight(j) * SHAPES[j].sides end
  local feed = min(streamMax(), SUPPLY * fireRate() / (ssum / wsum))
  return feed * baseWeight(i) / wsum * (1 + ATTRACT_BONUS * S.attract[i])
end

local function updateShapes(dt)
  local S = L.S
  spawnT = spawnT + dt
  local gen = modOn("rain") and 3 or 1
  local extra = gen > 1 and 15 or 0
  local room = L.boss and ceil(maxOnMap() / 2) or maxOnMap()
  if spawnT >= SPAWN_EVERY / gen and #ents < room + extra then spawnT = 0; spawn() end
  local cap = maxOnMap() + 12 + extra
  for i = 0, S.unlocked - 1 do
    local r = streamRate(i) * gen
    if r > 0 then
      streamT[i] = streamT[i] + r * dt
      while streamT[i] >= 1 and #ents < cap do streamT[i] = streamT[i] - 1; spawn({i = i}) end
      streamT[i] = min(streamT[i], 1)
    end
  end
  local W, fy = L.W, L.floorY
  for _, e in ipairs(ents) do
    e.x, e.y, e.a = e.x + e.vx * dt, e.y + e.vy * dt, e.a + e.va * dt
    for _, p in ipairs(e.parts) do p.flash = max(0, p.flash - dt * 6) end
    local R = e.R
    if not e.leaving then
      if not e.inside then
        if e.x > R and e.x < W - R and e.y > R and e.y < fy - R then e.inside = true end
      else
        if e.x < R then e.x = R; e.vx = abs(e.vx) end
        if e.x > W - R then e.x = W - R; e.vx = -abs(e.vx) end
        if e.y < R then e.y = R; e.vy = abs(e.vy) end
        if e.y > fy - R then e.y = fy - R; e.vy = -abs(e.vy) end
      end
    end
  end
  for j = #ents, 1, -1 do local e = ents[j]; if e.leaving and e.y < -e.R then table.remove(ents, j); e.gone = true end end
  for j = #dying, 1, -1 do local d = dying[j]; d.t = d.t + dt; if d.t > 0.22 then table.remove(dying, j) end end
  for j = #rings, 1, -1 do local r = rings[j]; r.t = r.t + dt; if r.t > 0.3 then table.remove(rings, j) end end
end

-- ---------- Daño ----------
local explode
local function damage(e, p, dmg, x, y, byPlayer, fromBlast)
  local S = L.S
  local i = p.i
  local n = SHAPES[i].sides
  local k = floor(p.hits)
  if byPlayer then dmg = min(dmg, (n - p.hits) * p.mul) end
  p.hits = p.hits + dmg / p.mul; p.flash = 1
  if byPlayer then
    local notes = max(1, min(6, ceil(dmg), n - k))
    for j = 0, notes - 1 do call("tone", noteOf(i, (k + j) % n), j * 0.035, "t") end
  else
    call("queueHit", i, noteOf(i, k % n))
  end
  if p.hits < n - 1e-9 then return end
  p.dead = true
  local wx, wy, wa = partPos(e, p)
  dying[#dying + 1] = {x = wx, y = wy, a = wa, p = p, t = 0}
  local r, label = reward(i) * p.hits / n * p.mul, ""
  if e.boss then e.paid = e.paid + r end
  if isCore(e, p) and e.boss then
    r = r + BOSS_BONUS * e.paid; label = T" ¡jefe!"
  elseif isCore(e, p) and #e.parts > 1 then
    local mult = designMult(e.parts)
    local sum = 0
    for _, q in ipairs(e.parts) do sum = sum + reward(q.i) end
    r = r + sum * (mult - 1); label = " ×" .. mult
  end
  if modOn("money") then r = r * 2 end
  r = r * incomeMult()
  local stats = S.meta.stats
  stats.broken = stats.broken + 1; stats.per[i] = (stats.per[i] or 0) + 1
  if isCore(e, p) and #e.parts > 1 and not e.boss then stats.comps = stats.comps + 1 end
  if isCore(e, p) and e.boss then bossDefeated(e) end
  if isCore(e, p) then removeEnt(e)
  else
    e.R = boundR(e)
    if not e.boss then e.vx, e.vy = e.vx * 1.06, e.vy * 1.06 end
  end
  earn(r)
  -- Acorde al romperse (no el círculo ni el triángulo: con sus notas basta)
  if n > 3 then
    if byPlayer then call("chord", i, n, 0.06) else call("queueBreak", i, n) end
  end
  call("floatText", "+" .. fmt(r) .. label, x, y, SHAPES[i].r, SHAPES[i].g, SHAPES[i].b)
  if lvl("blast") > 0 and not fromBlast then explode(wx, wy, i) end
end

-- ---------- Explosión ----------
local BLAST_R = 120
L.BLAST_R = BLAST_R
local lastBoom = 0
explode = function(x, y, level)
  rings[#rings + 1] = {x = x, y = y, t = 0}
  local now = GetTime()
  if now - lastBoom > 0.08 then lastBoom = now; call("sfx", "boom") end
  local hits = {}
  for _, e in ipairs(ents) do
    for _, p in ipairs(e.parts) do
      if not p.dead and p.i <= level and not shielded(e, p) then
        local px, py = partPos(e, p)
        if hypot(px - x, py - y) <= BLAST_R + p.r then hits[#hits + 1] = {e, p, px, py} end
      end
    end
  end
  local chain = 0
  for _, h in ipairs(hits) do
    local e, p = h[1], h[2]
    if not p.dead and free(p) then
      damage(e, p, min(lvl("blast"), spare(p)), h[3], h[4], false, true)
      if p.dead then chain = chain + 1 end
    end
  end
  local s = L.S.meta.stats
  s.chain = max(s.chain, chain)
end

-- ---------- Modificadores temporales ----------
MODS = {
  {key = "kill", name = "Instakill", icon = "X", dur = 10, turrets = true, desc = T"las torretas rompen la pieza de un disparo"},
  {key = "money", name = T"Dinero ×2", icon = "×2", dur = 20, turrets = false, desc = T"todo paga el doble"},
  {key = "frenzy", name = T"Frenesí", icon = "»", dur = 12, turrets = true, desc = T"torretas ×3 cadencia"},
  {key = "rain", name = T"Figuras ×3", icon = "×3", dur = 15, turrets = false, desc = T"se generan 3 veces más figuras"},
  {key = "smash", name = T"Golpe ×10", icon = "×10", dur = 15, turrets = false, desc = T"tus clics rompen 10 veces más"},
}
L.MODS = MODS
local PU_LIFE = 14
L.PU_LIFE = PU_LIFE
local puT = 25

local function spawnPowerup()
  local pool = {}
  for _, m in ipairs(MODS) do if not m.turrets or totalTurrets() > 0 then pool[#pool + 1] = m end end
  local m = pool[floor(random() * #pool) + 1]
  local n = 7 + floor(random() * 3)
  local a, sp = random() * pi * 2, 40 + random() * 30
  local verts = {}
  for k = 1, n do verts[k] = {ph = random() * 6.28, sp = 1.5 + random() * 2.5} end
  powerups[#powerups + 1] = {m = m, x = L.W * (0.2 + random() * 0.6), y = L.floorY * (0.2 + random() * 0.6),
    vx = cos(a) * sp, vy = sin(a) * sp, r = 50, t = 0, verts = verts}
end

local function updatePowerups(dt)
  puT = puT - dt
  if puT <= 0 then spawnPowerup(); puT = (40 + random() * 40) * 0.85 ^ perk("anomaly") end
  local W, fy = L.W, L.floorY
  for j = #powerups, 1, -1 do
    local u = powerups[j]
    u.t = u.t + dt
    u.x, u.y = u.x + u.vx * dt, u.y + u.vy * dt
    if u.x < u.r or u.x > W - u.r then u.vx = -u.vx end
    if u.y < u.r or u.y > fy - u.r then u.vy = -u.vy end
    u.x, u.y = max(u.r, min(W - u.r, u.x)), max(u.r, min(fy - u.r, u.y))
    if u.t > PU_LIFE then table.remove(powerups, j) end
  end
  for _, m in ipairs(MODS) do
    if (mods[m.key] or 0) > 0 then
      mods[m.key] = mods[m.key] - dt
      if mods[m.key] <= 0 then mods[m.key] = 0; call("tone", 60, 0, "s") end
    end
  end
end

local function activatePowerup(u)
  for j = #powerups, 1, -1 do if powerups[j] == u then table.remove(powerups, j) end end
  local dur = u.m.dur * (1 + 0.2 * perk("anomaly"))
  mods[u.m.key] = max(mods[u.m.key] or 0, dur)
  local s = L.S.meta.stats; s.mods = s.mods + 1
  call("arpeggio", 67, {0, 4, 7, 11, 14, 19}, 0.05, "t")
  call("floatText", u.m.name, u.x, u.y, 0.93, 0.93, 0.94)
end
local function pickPowerup(px, py)
  for _, u in ipairs(powerups) do if hypot(px - u.x, py - u.y) < u.r + 14 then return u end end
end

-- ---------- Torretas ----------
local PULSE_SPEED, MAX_SHOTS = 900, 5
local VIS_MAX = 60                                -- torretas dibujadas (si hay más, cada una dispara por varias)
local T_SLOT, T_ROW = 22, 22
local tlist = {}
L.tlist = tlist
local HERO_GAP = 26
local hero = {x = 0, y = 0, ang = -pi / 2, kick = 0}
L.hero = hero

function L.layoutTurrets()
  local S, W, H = L.S, L.W, L.H
  local vis = min(S.guns, VIS_MAX)
  for n = #tlist + 1, vis do tlist[n] = {n = n, acc = random(), ang = -pi / 2, col = nil, link = nil} end
  for n = #tlist, vis + 1, -1 do tlist[n] = nil end
  local perRow = max(2, floor((W - 40 - 2 * HERO_GAP) / T_SLOT))
  local rows = max(1, ceil(#tlist / perRow))
  for k0 = 0, #tlist - 1 do
    local t = tlist[k0 + 1]
    local row = floor(k0 / perRow)
    local inRow = min(perRow, #tlist - row * perRow)
    local m, left = k0 % perRow, floor(inRow / 2)
    if m < left then t.x = W / 2 - HERO_GAP - (left - 1 - m) * T_SLOT - T_SLOT / 2
    else t.x = W / 2 + HERO_GAP + (m - left) * T_SLOT + T_SLOT / 2 end
    t.y = H - 14 - row * T_ROW
  end
  hero.x, hero.y = W / 2, H - 16
  L.floorY = H - 26 - rows * T_ROW
end

local function nearestTarget(x, y, skip, range)
  local best, bd = nil, range or math.huge
  local boss = L.boss
  local pool = ents
  if boss and boss.inside then
    for _, p in ipairs(boss.parts) do
      if targetable(boss, p) and not (skip and skip[p]) then pool = {boss}; break end
    end
  end
  for _, e in ipairs(pool) do
    if e.inside then
      for _, p in ipairs(e.parts) do
        if targetable(e, p) and not (skip and skip[p]) then
          local px, py = partPos(e, p)
          local d = hypot(px - x, py - y)
          if d < bd then bd = d; best = {e = e, p = p} end
        end
      end
    end
  end
  return best
end
local function alive(l) return l and not l.p.dead and not l.e.gone end
L.alive = alive

local function pulse(t, e, p, dmg)
  local crit = random() < critChance()
  if crit then dmg = dmg * CRIT_MULT end
  p.incoming = p.incoming + dmg
  local s = L.S.meta.stats; s.pulses = (s.pulses or 0) + 1
  call("shotSound")
  local ax, ay = partPos(e, p)
  local d = hypot(ax - t.x, ay - t.y); if d == 0 then d = 1 end
  bullets[#bullets + 1] = {i = p.i, x = t.x, y = t.y, vx = (ax - t.x) / d * PULSE_SPEED, vy = (ay - t.y) / d * PULSE_SPEED,
    target = {e = e, p = p}, dmg = dmg, res = dmg, crit = crit, life = 0,
    pierce = lvl("pierce"), bounces = lvl("bounce"), hitParts = {}}
end

local function collectFree(pool, taken)
  local out = {}
  for _, e in ipairs(pool) do
    if e.inside then
      for _, p in ipairs(e.parts) do
        if targetable(e, p) and not taken[p] then
          local x, y = partPos(e, p)
          out[#out + 1] = {e = e, p = p, x = x, y = y}
        end
      end
    end
  end
  return out
end
local function bySpan(a, b) return a[1] < b[1] end

local function updateTurrets(dt)
  local S = L.S
  local taken = {}
  local idle = {}
  for _, t in ipairs(tlist) do
    if not alive(t.link) or not targetable(t.link.e, t.link.p) then t.link = nil else taken[t.link.p] = true end
    if not t.link then idle[#idle + 1] = t end
  end
  if #idle > 0 then
    local fr = (L.boss and L.boss.inside) and collectFree({L.boss}, taken) or {}
    if #fr == 0 then fr = collectFree(ents, taken) end
    if #fr > 0 then
      if #idle * #fr <= 3000 then
        -- Primero la pareja torreta-pieza más próxima de todas, luego la siguiente...
        local pairs_ = {}
        for _, t in ipairs(idle) do for _, f in ipairs(fr) do pairs_[#pairs_ + 1] = {hypot(f.x - t.x, f.y - t.y), t, f} end end
        table.sort(pairs_, bySpan)
        for _, pr in ipairs(pairs_) do
          local t, f = pr[2], pr[3]
          if not t.link and not taken[f.p] then t.link = {e = f.e, p = f.p}; t.col = f.p.i; taken[f.p] = true end
        end
      else
        -- Muchas a la vez: cada torreta toma la libre más cercana (más barato)
        for _, t in ipairs(idle) do
          local best, bd = nil, math.huge
          for _, f in ipairs(fr) do
            if not taken[f.p] then local d = hypot(f.x - t.x, f.y - t.y); if d < bd then bd = d; best = f end end
          end
          if best then t.link = {e = best.e, p = best.p}; t.col = best.p.i; taken[best.p] = true end
        end
      end
    end
  end
  local vis, total = max(1, #tlist), fireRate()
  local supply = 1 / SPAWN_EVERY
  for i = 0, S.unlocked - 1 do supply = supply + streamRate(i) end
  local allShots = min(total, vis * MAX_SHOTS, max(4, supply * 1.5))
  if allShots <= 0 then return end
  local shots, dmg = allShots / vis, total / allShots
  for _, t in ipairs(tlist) do
    if not t.link then t.acc = min(t.acc, 1)
    else
      t.acc = t.acc + shots * dt
      while t.acc >= 1 and t.link do
        t.acc = t.acc - 1
        pulse(t, t.link.e, t.link.p, dmg)
        if not targetable(t.link.e, t.link.p) then
          taken[t.link.p] = nil
          local nxt = nearestTarget(t.x, t.y, taken)
          t.link = nxt
          if nxt then t.col = nxt.p.i; taken[nxt.p] = true end
        end
      end
      if t.link then local px, py = partPos(t.link.e, t.link.p); t.ang = math.atan2(py - t.y, px - t.x) end
    end
  end
end

-- ---------- Disparo del jugador ----------
local HERO_SPEED = 1900
function L.heroFire(tx, ty)
  hero.ang = math.atan2(ty - hero.y, tx - hero.x); hero.kick = 1
  local c, s = cos(hero.ang), sin(hero.ang)
  bullets[#bullets + 1] = {player = true, x = hero.x + c * 18, y = hero.y + s * 18, vx = c * HERO_SPEED, vy = s * HERO_SPEED,
    dmg = punchPower(), life = 0}
  call("sfx", "hero")
end
local function touching(x, y)
  local best
  for _, e in ipairs(ents) do
    for _, p in ipairs(e.parts) do
      if not p.dead then
        local px, py = partPos(e, p)
        if hypot(px - x, py - y) <= p.r + 4 and (not best or p.layer > best.p.layer) then best = {e = e, p = p, px = px, py = py} end
      end
    end
  end
  return best
end
local function moveHeroShot(b, dt)
  local steps = max(1, ceil(HERO_SPEED * dt / 12))
  for _ = 1, steps do
    b.x, b.y = b.x + b.vx * dt / steps, b.y + b.vy * dt / steps
    local hit = touching(b.x, b.y)
    if hit then
      if shielded(hit.e, hit.p) then hit.p.flash = 1; call("sfx", "thud"); return true end
      local s = L.S.meta.stats; s.clicks = s.clicks + 1
      damage(hit.e, hit.p, b.dmg, hit.px, hit.py, true)
      return true
    end
  end
  return b.x < -30 or b.x > L.W + 30 or b.y < -30 or b.y > L.H + 30
end

local function retarget(b)
  local best = nearestTarget(b.x, b.y, b.hitParts)
  if not best then
    local bd = math.huge
    for _, e in ipairs(ents) do
      if e.inside then
        for _, p in ipairs(e.parts) do
          if not p.dead and not shielded(e, p) then
            local px, py = partPos(e, p)
            local d = hypot(px - b.x, py - b.y)
            if d < bd then bd = d; best = {e = e, p = p} end
          end
        end
      end
    end
  end
  if best then b.res = b.dmg; b.i = best.p.i; best.p.incoming = best.p.incoming + b.res end
  return best
end

local function pulseHit(b, e, p)
  local dmg = b.dmg
  if modOn("kill") then dmg = b.dmg + max(0, p.mul > 1 and min(b.dmg * 4, spare(p)) or spare(p)) end
  damage(e, p, dmg, b.x, b.y, false)
  b.hitParts[p] = true
  if b.bounces > 0 then
    local nxt = nearestTarget(b.x, b.y, b.hitParts, 450)
    if nxt then
      b.bounces = b.bounces - 1; b.life = 0; b.i = nxt.p.i; b.res = b.dmg
      b.target = nxt; nxt.p.incoming = nxt.p.incoming + b.dmg
      return true
    end
  end
  return false
end

local function updateBullets(dt)
  hero.kick = max(0, hero.kick - dt * 7)
  for j = #bullets, 1, -1 do
    local b = bullets[j]
    b.life = b.life + dt
    if b.player then
      if moveHeroShot(b, dt) then table.remove(bullets, j) end
    else
      local keep = true
      if not alive(b.target) then
        b.target = retarget(b)
        if not b.target then keep = false end
      end
      if keep then
        local e, p = b.target.e, b.target.p
        local px, py = partPos(e, p)
        local dx, dy = px - b.x, py - b.y
        local d = hypot(dx, dy)
        if d <= p.r or d <= PULSE_SPEED * dt then
          p.incoming = max(0, p.incoming - b.res)
          keep = pulseHit(b, e, p)
        else
          b.vx, b.vy = dx / d * PULSE_SPEED, dy / d * PULSE_SPEED
          b.x, b.y = b.x + b.vx * dt, b.y + b.vy * dt
          if b.pierce > 0 then
            for _, e2 in ipairs(ents) do
              if e2.inside and b.pierce > 0 then
                for _, q in ipairs(e2.parts) do
                  if b.pierce <= 0 then break end
                  if q ~= p and not q.dead and not shielded(e2, q) and not b.hitParts[q] and free(q) then
                    local qx, qy = partPos(e2, q)
                    if hypot(qx - b.x, qy - b.y) <= q.r then
                      b.hitParts[q] = true; b.pierce = b.pierce - 1
                      damage(e2, q, min(b.dmg, spare(q)), qx, qy, false)
                    end
                  end
                end
              end
            end
          end
        end
      end
      if not keep then table.remove(bullets, j) end
    end
  end
end

-- ---------- Clic en el mapa ----------
function L.clickMap(px, py)
  local pu = pickPowerup(px, py)
  if pu then activatePowerup(pu); return end
  if py >= hero.y - 4 then return end
  L.heroFire(px, py)
end
function L.aim(px, py)
  if py < hero.y - 4 then hero.ang = math.atan2(py - hero.y, px - hero.x) end
end

-- ---------- Tienda: qué se ve y qué cuesta ----------
local REQS = {
  turret = function() return L.S.total >= GUN_BASE * 0.6 end,
  polish = function(i) return L.S.guns >= 1 and L.S.total >= polishBase(i) * 0.3 end,
  punch = function() return L.S.unlocked >= 4 end,
  coord = function() return totalTurrets() >= 2 end,
  unlock = function(i) return L.S.total >= unlockCost(i) * 0.5 end,
  design = function(d) return L.S.unlocked > designTop(d) and L.S.total >= designCost(d) * 0.5 end,
}
L.designTop = designTop
function L.checkReveals()
  local S = L.S
  local changed = {}
  local function test(key, ok) if not S.seen[key] and ok then S.seen[key] = 1; changed[#changed + 1] = key end end
  test("turret", REQS.turret())
  for i = 0, S.unlocked - 1 do test("polish" .. i, REQS.polish(i)) end
  test("coord", REQS.coord()); test("punch", REQS.punch())
  for _, u in ipairs(EXTRAS) do test(u.key, u.req()) end
  if S.unlocked < N then test("unlock" .. S.unlocked, REQS.unlock(S.unlocked)) end
  if S.designs < #DESIGNS then test("design" .. S.designs, REQS.design(S.designs)) end
  test("dim", S.total >= BAL.prest / 10 or S.meta.dims > 0)
  return changed
end

-- Producción esperada de las torretas (si siempre tienen figuras a las que disparar)
function L.cps()
  local S = L.S
  local ws, wv = 0, 0
  for i = 0, S.unlocked - 1 do
    local w = spawnWeight(i)
    ws = ws + w; wv = wv + w * sideValue(i) * 2 ^ S.polish[i]
  end
  return ws > 0 and fireRate() * (wv / ws) * incomeMult() or 0
end

-- Compras por niveles: nivel actual, precio de cada nivel, máximo y cómo se aplican
L.buyMode = 1                                      -- 1, 10 o math.huge (Máx)
L.BULK = {
  turret = function() return {L = L.S.guns, cost = gunCost, max = math.huge, add = function(n) L.S.guns = L.S.guns + n; L.layoutTurrets() end} end,
  polish = function(i) return {L = L.S.polish[i], cost = function(l) return polishCost(i, l) end, max = math.huge, add = function(n) L.S.polish[i] = L.S.polish[i] + n end} end,
  attract = function(i) return {L = L.S.attract[i], cost = function(l) return attractCost(i, l) end, max = math.huge, add = function(n) L.S.attract[i] = L.S.attract[i] + n end} end,
  coord = function() return {L = L.S.coord, cost = coordCost, max = math.huge, add = function(n) L.S.coord = L.S.coord + n end} end,
  punch = function() return {L = L.S.punch, cost = punchCost, max = math.huge, add = function(n) L.S.punch = L.S.punch + n end} end,
  extra = function(k)
    local u; for _, x in ipairs(EXTRAS) do if x.key == k then u = x end end
    return {L = lvl(k), cost = function(l) return extraCost(u, l) end, max = u.max, add = function(n) L.S.ups[k] = lvl(k) + n end}
  end,
}
function L.quote(b)
  local room = b.max - b.L
  if room <= 0 then return 0, 0 end
  local n, c = 0, 0
  if L.buyMode == math.huge then
    while n < room and n < 1000 do
      local x = b.cost(b.L + n)
      if c + x > L.S.coins then break end
      c = c + x; n = n + 1
    end
    if n == 0 then return 1, b.cost(b.L) end
    return n, c
  end
  for k = 0, min(L.buyMode, room) - 1 do c = c + b.cost(b.L + k); n = n + 1 end
  return n, c
end
function L.buyBulk(b)
  local n, c = L.quote(b)
  if n == 0 or L.S.coins < c then return false end
  L.S.coins = L.S.coins - c; b.add(n)
  return true
end
function L.buyUnlock()
  local S = L.S
  if S.unlocked >= N then return false end
  local c = unlockCost(S.unlocked)
  if S.coins < c then return false end
  S.coins = S.coins - c; S.unlocked = S.unlocked + 1; spawn({i = S.unlocked - 1})
  return true
end
function L.buyDesign()
  local S = L.S
  if S.designs >= #DESIGNS then return false end
  local c = designCost(S.designs)
  if S.coins < c then return false end
  S.coins = S.coins - c; S.designs = S.designs + 1; spawn({d = S.designs - 1})
  return true
end
function L.buyPerk(u)
  local m = L.S.meta
  local c = perkCost(u)
  if m.aristas < c or perk(u.key) >= u.max then return false end
  m.aristas = m.aristas - c; m.perks[u.key] = perk(u.key) + 1
  if u.key == "vet" then L.layoutTurrets() end
  return true
end

-- ---------- Partidas ----------
function L.clearMap()
  for k in pairs(ents) do ents[k] = nil end
  for k in pairs(dying) do dying[k] = nil end
  for k in pairs(bullets) do bullets[k] = nil end
  for k in pairs(rings) do rings[k] = nil end
  for k in pairs(powerups) do powerups[k] = nil end
  for k in pairs(mods) do mods[k] = 0 end
  for k in pairs(tlist) do tlist[k] = nil end
  for i = 0, N - 1 do streamT[i] = 0 end
  puT, spawnT, bossT = 25, SPAWN_EVERY, BOSS_FIRST
  L.boss = nil
  call("musicStop", nil)
end

function L.doPrestige()
  local S = L.S
  local gain = aristasFor(S.total)
  if gain <= 0 then return false end
  local m = S.meta
  m.aristas = m.aristas + gain; m.aristasTotal = m.aristasTotal + gain; m.dims = m.dims + 1
  L.S = startRun(m)
  L.clearMap(); L.layoutTurrets()
  return true
end

function L.checkAchs()
  if not L.inGame then return {} end
  local got = {}
  for _, a in ipairs(ACHS) do
    if not L.S.meta.ach[a[1]] and a[4]() then L.S.meta.ach[a[1]] = time and time() or 1; got[#got + 1] = a end
  end
  return got
end

-- Progreso sin conexión: las torretas siguen al 50% mientras la ventana está cerrada (máximo 12 h)
local AWAY_MIN, AWAY_MAX, AWAY_RATE = 10, 12 * 3600, 0.5
L.AWAY_MIN, L.AWAY_MAX, L.AWAY_RATE = AWAY_MIN, AWAY_MAX, AWAY_RATE
function L.awayGain(sec)
  sec = min(sec, AWAY_MAX)
  return L.cps() * sec * AWAY_RATE, sec
end

-- ---------- Un paso de simulación ----------
function L.step(dt)
  local playing = L.inGame and not L.menuOpen
  updateShapes(dt)                                 -- con el menú abierto las figuras siguen como fondo
  if playing then updateTurrets(dt); updateBullets(dt); updatePowerups(dt); updateBoss(dt) end
end
