-- Lados · dibujo del mapa
-- WoW no tiene canvas: cada lado es una línea de la interfaz y cada punto una textura.
-- Se reutilizan de un fotograma a otro (crear objetos de interfaz es caro y no se pueden borrar).
local _, L = ...
local floor, ceil, min, max, sin, cos, pi, abs = math.floor, math.ceil, math.min, math.max, math.sin, math.cos, math.pi, math.abs
local TEX = "Interface\\AddOns\\Lados\\texturas\\"

local canvas
local lines, nl, shownL = {}, 0, 0
local texs, nt, shownT = {}, 0, 0
local INK = {0.925, 0.925, 0.933}
local LINE = {0.165, 0.169, 0.188}
local PANEL = {0.102, 0.106, 0.118}

function L.initDraw(frame) canvas = frame end

-- ---------- Primitivas (coordenadas del mundo) ----------
local function line(x1, y1, x2, y2, w, r, g, b, a)
  nl = nl + 1
  local ln = lines[nl]
  if not ln then ln = canvas:CreateLine(nil, "ARTWORK"); lines[nl] = ln end
  local s = L.SCALE
  ln:SetStartPoint("TOPLEFT", canvas, x1 * s, -y1 * s)
  ln:SetEndPoint("TOPLEFT", canvas, x2 * s, -y2 * s)
  local th = max(1, w * s * 1.15)
  if ln._w ~= th then ln:SetThickness(th); ln._w = th end
  if ln._r ~= r or ln._g ~= g or ln._b ~= b or ln._a ~= a then
    ln:SetColorTexture(r, g, b, a); ln._r, ln._g, ln._b, ln._a = r, g, b, a
  end
  if nl > shownL then ln:Show() end
end

-- d: diámetro en unidades del mundo · sub: subcapa (lo de número mayor queda encima)
local function sprite(file, x, y, d, r, g, b, a, sub)
  nt = nt + 1
  local t = texs[nt]
  if not t then t = canvas:CreateTexture(nil, "OVERLAY"); texs[nt] = t end
  if t._f ~= file then t:SetTexture(TEX .. file); t._f = file end
  sub = sub or 0
  if t._sub ~= sub then t:SetDrawLayer("OVERLAY", sub); t._sub = sub end
  local s = L.SCALE
  t:ClearAllPoints()
  t:SetPoint("CENTER", canvas, "TOPLEFT", x * s, -y * s)
  local px = max(1, d * s)
  t:SetSize(px, px)
  if t._r ~= r or t._g ~= g or t._b ~= b or t._a ~= a then
    t:SetVertexColor(r, g, b, a); t._r, t._g, t._b, t._a = r, g, b, a
  end
  if nt > shownT then t:Show() end
end

-- ---------- Figuras ----------
-- Punto del contorno en la posición t (0..n) de la lista de vértices: los polígonos de muchos lados
-- se dibujan con menos segmentos (36 como mucho), así el hectágono no necesita 100 líneas.
local MAX_SEG = 36
local function polyPoint(verts, n, t)
  local k = floor(t)
  local f = t - k
  local a, b = verts[k % n + 1], verts[(k + 1) % n + 1]
  return a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f
end
local function contour(x, y, ang, R, verts, n, from, to, w, r, g, b, a)
  if to <= from then return end
  local c, s = cos(ang), sin(ang)
  local count = n <= MAX_SEG and (to - from) or max(1, ceil((to - from) * MAX_SEG / n))
  local px, py
  for k = 0, count do
    local vx, vy = polyPoint(verts, n, from + (to - from) * k / count)
    vx, vy = vx * R, vy * R
    local X, Y = x + vx * c - vy * s, y + vx * s + vy * c
    if px then line(px, py, X, Y, w, r, g, b, a) end
    px, py = X, Y
  end
end

local function drawPart(x, y, ang, p, scale, alpha, shield)
  local SH = L.SHAPES[p.i]
  local n = SH.sides
  local broken = min(n, floor(p.hits))
  local R = p.r * scale * (1 - p.flash * 0.06)
  local r, g, b = SH.r, SH.g, SH.b
  if not SH.verts then
    if broken > 0 then sprite("aro2", x, y, 2 * R, r, g, b, alpha * 0.12)
    else sprite("aro", x, y, 2 * R, r, g, b, alpha * (shield and 0.35 or 1)) end
  else
    if broken > 0 then contour(x, y, ang, R, SH.verts, n, 0, broken, 2, r, g, b, alpha * 0.12) end
    if broken < n then
      local w = p.r < 25 and 4 or (n > 30 and 3.5 or 5)
      contour(x, y, ang, R, SH.verts, n, broken, n, w, r, g, b, alpha * (shield and 0.35 or 1))
    end
  end
  if shield then sprite("discontinuo", x, y, 2 * R * 0.55, r, g, b, alpha * (0.35 + p.flash * 0.6)) end
end

local function arc(x, y, R, a0, a1, w, r, g, b, a)
  local count = max(1, ceil(abs(a1 - a0) / (2 * pi) * 48))
  local px, py = x + cos(a0) * R, y + sin(a0) * R
  for k = 1, count do
    local t = a0 + (a1 - a0) * k / count
    local X, Y = x + cos(t) * R, y + sin(t) * R
    line(px, py, X, Y, w, r, g, b, a)
    px, py = X, Y
  end
end

local function drawEnt(e, now)
  if e.boss then                                   -- jefe: halo que late y anillo de tiempo restante
    local pulse = 0.5 + 0.5 * sin(now / 0.3)
    local left = max(0, 1 - e.t / L.BOSS_TIME)
    sprite("aro2", e.x, e.y, 2 * (e.R + 14 + 4 * pulse), INK[1], INK[2], INK[3], 0.1 + 0.12 * pulse)
    if left > 0 then arc(e.x, e.y, e.R + 26, -pi / 2, -pi / 2 + left * pi * 2, 4, INK[1], INK[2], INK[3], 0.45) end
  end
  for _, p in ipairs(e.parts) do
    if not p.dead then
      local x, y, a = L.partPos(e, p)
      drawPart(x, y, a, p, 1, 1, L.shielded(e, p))
    end
  end
end

-- ---------- Modificadores (figuras deformes) ----------
local labels = {}
local function puLabel(k)
  local f = labels[k]
  if not f then
    f = canvas:CreateFontString(nil, "OVERLAY")
    f:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    f:SetTextColor(INK[1], INK[2], INK[3])
    labels[k] = f
  end
  return f
end
local function drawPowerups()
  local used = 0
  for _, u in ipairs(L.powerups) do
    local n = #u.verts
    local grow = min(1, u.t / 0.4)
    local blink = u.t > L.PU_LIFE - 3 and 0.35 + 0.65 * abs(sin(u.t * 9)) or 1
    local rot = u.t * 0.4
    local r, g, b = L.hsl((u.t * 90) % 360, 0.8, 0.55)
    local px, py, fx, fy
    for k = 1, n do
      local v = u.verts[k]
      local rr = u.r * grow * (0.7 + 0.3 * sin(u.t * v.sp + v.ph))
      local a = (k - 1) * 2 * pi / n + rot
      local X, Y = u.x + rr * cos(a), u.y + rr * sin(a)
      if px then line(px, py, X, Y, 5, r, g, b, blink) else fx, fy = X, Y end
      px, py = X, Y
    end
    line(px, py, fx, fy, 5, r, g, b, blink)
    used = used + 1
    local f = puLabel(used)
    f:ClearAllPoints(); f:SetPoint("CENTER", canvas, "TOPLEFT", u.x * L.SCALE, -u.y * L.SCALE)
    f:SetText(u.m.icon); f:SetAlpha(blink); f:Show()
  end
  for k = used + 1, #labels do labels[k]:Hide() end
end

-- ---------- Números que suben al romper ----------
local floats, fpool = {}, {}
function L.floatText(txt, x, y, r, g, b)
  if not canvas or not L.OPT.floats or #floats > 25 then return end
  local f = table.remove(fpool)
  if not f then
    f = canvas:CreateFontString(nil, "OVERLAY")
    f:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
  end
  f:SetText(txt); f:SetTextColor(r, g, b); f:Show()
  floats[#floats + 1] = {f = f, x = x, y = y, t = 0}
end
local function drawFloats(dt)
  for j = #floats, 1, -1 do
    local o = floats[j]
    o.t = o.t + dt
    if o.t > 0.9 then o.f:Hide(); fpool[#fpool + 1] = o.f; table.remove(floats, j)
    else
      o.f:ClearAllPoints()
      o.f:SetPoint("CENTER", canvas, "TOPLEFT", o.x * L.SCALE, -o.y * L.SCALE + 10 + 40 * o.t / 0.9)
      o.f:SetAlpha(1 - o.t / 0.9)
    end
  end
end
function L.clearFloats()
  for j = #floats, 1, -1 do floats[j].f:Hide(); fpool[#fpool + 1] = floats[j].f; floats[j] = nil end
end

-- ---------- Torretas ----------
local function drawTurrets()
  local W, fy = L.W, L.floorY
  line(0, fy, W, fy, 1.5, LINE[1], LINE[2], LINE[3], 1)
  for _, t in ipairs(L.tlist) do
    line(t.x, t.y, t.x + cos(t.ang) * 11, t.y + sin(t.ang) * 11, 3.5, INK[1], INK[2], INK[3], 1)
    if t.col then local SH = L.SHAPES[t.col]; sprite("punto", t.x, t.y, 12, SH.r, SH.g, SH.b, 1, 1)
    else sprite("punto", t.x, t.y, 12, LINE[1], LINE[2], LINE[3], 1, 1) end
  end
  -- Torreta del jugador: más grande, hueca y con un cañón que retrocede al disparar
  local h = L.hero
  local len = 22 - h.kick * 6
  line(h.x, h.y, h.x + cos(h.ang) * len, h.y + sin(h.ang) * len, 6, INK[1], INK[2], INK[3], 1)
  sprite("punto", h.x, h.y, 25, INK[1], INK[2], INK[3], 1, 2)
  sprite("punto", h.x, h.y, 19, PANEL[1], PANEL[2], PANEL[3], 1, 3)
  sprite("punto", h.x, h.y, 7 + h.kick * 4, INK[1], INK[2], INK[3], 1, 4)
end

-- ---------- Fotograma ----------
function L.render(dt)
  if not canvas then return end
  nl, nt = 0, 0
  local now = GetTime()
  for _, e in ipairs(L.ents) do drawEnt(e, now) end
  for _, d in ipairs(L.dying) do drawPart(d.x, d.y, d.a, d.p, 1 + d.t / 0.22 * 0.35, 1 - d.t / 0.22) end
  drawPowerups()
  for _, r in ipairs(L.rings) do
    local k = r.t / 0.3
    sprite("aro2", r.x, r.y, 2 * L.BLAST_R * (0.3 + 0.7 * k), INK[1], INK[2], INK[3], 0.5 * (1 - k))
  end
  -- Enlaces: una línea tenue de cada torreta a su pieza, del color de la pieza
  for _, t in ipairs(L.tlist) do
    if L.alive(t.link) then
      local px, py = L.partPos(t.link.e, t.link.p)
      local SH = L.SHAPES[t.link.p.i]
      line(t.x + cos(t.ang) * 11, t.y + sin(t.ang) * 11, px, py, 1.5, SH.r, SH.g, SH.b, 0.22)
    end
  end
  for _, b in ipairs(L.bullets) do
    if b.player then
      local v = L.hypot(b.vx, b.vy); if v == 0 then v = 1 end
      line(b.x, b.y, b.x - b.vx / v * 26, b.y - b.vy / v * 26, 2, INK[1], INK[2], INK[3], 0.35)
      sprite("punto", b.x, b.y, 9, INK[1], INK[2], INK[3], 1, 5)
    else
      local SH = L.SHAPES[b.i]
      if b.crit then
        sprite("punto", b.x, b.y, 18, SH.r, SH.g, SH.b, 0.25, 5)
        sprite("punto", b.x, b.y, 9, SH.r, SH.g, SH.b, 1, 6)
      else
        sprite("punto", b.x, b.y, 7, SH.r, SH.g, SH.b, 1, 5)
      end
    end
  end
  drawTurrets()
  drawFloats(dt)
  -- Esconde lo que sobró del fotograma anterior
  for k = nl + 1, shownL do lines[k]:Hide() end
  for k = nt + 1, shownT do texs[k]:Hide() end
  shownL, shownT = nl, nt
end

-- ---------- Iconos de la tienda ----------
-- Dibuja una figura (o una compuesta) dentro de un marco pequeño, en píxeles desde su centro.
local function iconLine(f, x1, y1, x2, y2, w, r, g, b)
  f._n = f._n + 1
  local ln = f._ln[f._n]
  if not ln then ln = f:CreateLine(nil, "ARTWORK"); f._ln[f._n] = ln end
  ln:SetStartPoint("CENTER", f, x1, -y1); ln:SetEndPoint("CENTER", f, x2, -y2)
  ln:SetThickness(w); ln:SetColorTexture(r, g, b, 1); ln:Show()
end
local function iconRing(f, x, y, d, r, g, b)
  f._nr = f._nr + 1
  local t = f._rg[f._nr]
  if not t then t = f:CreateTexture(nil, "ARTWORK"); t:SetTexture(TEX .. "aro"); f._rg[f._nr] = t end
  t:ClearAllPoints(); t:SetPoint("CENTER", f, "CENTER", x, -y); t:SetSize(d, d); t:SetVertexColor(r, g, b, 1); t:Show()
end
local function iconPoly(f, ox, oy, R, rot, verts, n, w, r, g, b)
  local c, s = cos(rot), sin(rot)
  local px, py
  for k = 0, n do
    local v = verts[k % n + 1]
    local X, Y = ox + (v[1] * c - v[2] * s) * R, oy + (v[1] * s + v[2] * c) * R
    if px then iconLine(f, px, py, X, Y, w, r, g, b) end
    px, py = X, Y
  end
end
local regularCache = {}
local function regular(n)
  if not regularCache[n] then
    local v = {}
    for k = 0, n - 1 do local a = -pi / 2 + k * 2 * pi / n; v[#v + 1] = {cos(a), sin(a)} end
    regularCache[n] = v
  end
  return regularCache[n]
end
function L.drawIcon(f, what)
  f._ln = f._ln or {}; f._rg = f._rg or {}
  f._n, f._nr = 0, 0
  local size = f:GetWidth() / 2 - 1
  if what.i then
    local SH = L.SHAPES[what.i]
    if not SH.verts then iconRing(f, 0, 0, size * 2, SH.r, SH.g, SH.b)
    else iconPoly(f, 0, 0, size * 0.9, 0, SH.verts, SH.sides, 1.6, SH.r, SH.g, SH.b) end
  elseif what.d then
    local ps = L.designParts(what.d)
    local R = 0
    for _, p in ipairs(ps) do R = max(R, L.hypot(p.ox, p.oy) + p.r) end
    local k = size / (R + 4)
    for _, p in ipairs(ps) do
      local SH = L.SHAPES[p.i]
      if SH.sides == 1 then iconRing(f, p.ox * k, p.oy * k, 2 * p.r * k, SH.r, SH.g, SH.b)
      else iconPoly(f, p.ox * k, p.oy * k, p.r * k, p.rot, regular(SH.sides), SH.sides, 1, SH.r, SH.g, SH.b) end
    end
  end
  for k = f._n + 1, #f._ln do f._ln[k]:Hide() end
  for k = f._nr + 1, #f._rg do f._rg[k]:Hide() end
end
