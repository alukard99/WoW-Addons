-- Lados · ventana, tienda, menú y guardado
local ADDON, L = ...
local T = L.T -- traducción (Locale.lua)
local floor, ceil, min, max = math.floor, math.ceil, math.min, math.max
local fmt = L.fmt
local FONT = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

-- Colores del tema oscuro del juego original
local C = {
  bg = {0.067, 0.071, 0.078}, panel = {0.102, 0.106, 0.118}, ink = {0.925, 0.925, 0.933},
  muted = {0.478, 0.482, 0.506}, line = {0.165, 0.169, 0.188}, accent = {0.424, 0.608, 1},
}
local BD = {bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1}

-- ---------- Piezas de interfaz ----------
local function text(parent, size, color, layer)
  local f = parent:CreateFontString(nil, layer or "OVERLAY")
  f:SetFont(FONT, size, "")
  f:SetTextColor(color[1], color[2], color[3])
  f:SetJustifyH("LEFT"); f:SetJustifyV("TOP")
  return f
end
local function box(parent, bg, border, alpha)
  local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  f:SetBackdrop(BD)
  f:SetBackdropColor(bg[1], bg[2], bg[3], alpha or 1)
  f:SetBackdropBorderColor(border[1], border[2], border[3], 1)
  return f
end
local function setBorder(b, c) b:SetBackdropBorderColor(c[1], c[2], c[3], 1) end

local function mkButton(parent)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetBackdrop(BD); b:SetBackdropColor(C.panel[1], C.panel[2], C.panel[3], 1); setBorder(b, C.line)
  b.t1 = text(b, 12, C.ink); b.t1:SetPoint("TOPLEFT", 8, -6); b.t1:SetPoint("RIGHT", -8, 0)
  b.t2 = text(b, 11, C.muted); b.t2:SetPoint("TOPLEFT", b.t1, "BOTTOMLEFT", 0, -2); b.t2:SetPoint("RIGHT", -8, 0)
  b:SetScript("OnEnter", function(s) if s:IsEnabled() then setBorder(s, C.ink) end end)
  b:SetScript("OnLeave", function(s) setBorder(s, s.warn and C.accent or s.on and C.ink or C.line) end)
  b:SetScript("OnClick", function(s) if s.spec and s.spec.click then s.spec.click(s) end end)
  return b
end
local function setEnabled(b, on)
  b:SetEnabled(on and true or false)
  b:SetAlpha(on and 1 or 0.4)
end

-- ---------- Lista con desplazamiento ----------
-- Cada fila se describe con una tabla (spec) y se construye con marcos reutilizados.
--  {kind="text", text=, color=, size=, center=}
--  {kind="card", icon={i=}|{d=}, title=, sub=str|fn, dim=, bare=, rows={{btn, btn}, {btn}}}
--    btn = {label=, info=str|fn → texto, activo, aviso, click=fn, w=, center=}
--  {kind="seg", opts={{label=, on=, click=}}}
local function mkList(parent)
  local sf = CreateFrame("ScrollFrame", nil, parent)
  local content = CreateFrame("Frame", nil, sf)
  content:SetSize(1, 1); sf:SetScrollChild(content)
  sf:EnableMouseWheel(true)
  local bar = sf:CreateTexture(nil, "OVERLAY")
  bar:SetColorTexture(C.muted[1], C.muted[2], C.muted[3], 0.5); bar:SetWidth(3)
  local list = {sf = sf, content = content, widgets = {}, pool = {text = {}, card = {}, seg = {}}, bar = bar}
  local function drawBar()
    local h, ch = sf:GetHeight(), content:GetHeight()
    if ch <= h + 1 then bar:Hide(); return end
    local bh = max(20, h * h / ch)
    local y = sf:GetVerticalScroll() / (ch - h) * (h - bh)
    bar:ClearAllPoints(); bar:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 0, -y); bar:SetHeight(bh); bar:Show()
  end
  list.drawBar = drawBar
  sf:SetScript("OnMouseWheel", function(self, d)
    if IsControlKeyDown() and L.wheelScale then return L.wheelScale(d) end   -- Ctrl+rueda: escala de la ventana
    local maxS = max(0, content:GetHeight() - self:GetHeight())
    self:SetVerticalScroll(min(maxS, max(0, self:GetVerticalScroll() - d * 40)))
    drawBar()
  end)
  return list
end

local function getWidget(list, kind)
  local w = table.remove(list.pool[kind])
  if w then w:Show(); return w end
  local c = list.content
  if kind == "text" then
    w = CreateFrame("Frame", nil, c); w.fs = text(w, 12, C.muted); w.fs:SetPoint("TOPLEFT"); w.fs:SetPoint("RIGHT")
  elseif kind == "card" then
    w = box(c, C.panel, C.line)
    w.icon = CreateFrame("Frame", nil, w); w.icon:SetSize(26, 26)
    w.title = text(w, 12, C.ink); w.sub = text(w, 11, C.muted)
    w.btns = {}
  elseif kind == "seg" then
    w = CreateFrame("Frame", nil, c); w.btns = {}
  end
  w.kind = kind
  return w
end

local function val(x) if type(x) == "function" then return x() end; return x end

local function layoutButton(b, spec, width)
  b.spec = spec
  b:SetWidth(width)
  b.t1:SetJustifyH(spec.center and "CENTER" or "LEFT"); b.t2:SetJustifyH(spec.center and "CENTER" or "LEFT")
  b.t1:SetText(spec.label or "")
  local info, on, warn
  if type(spec.info) == "function" then info, on, warn = spec.info() else info = spec.info end
  b.t2:SetText(info or "")
  if on == nil then on = spec.enabled ~= false end
  setEnabled(b, on); b.warn = warn; b.on = spec.on
  setBorder(b, warn and C.accent or spec.on and C.ink or C.line)
  local h = 12 + b.t1:GetStringHeight()
  if info and info ~= "" then h = h + 2 + b.t2:GetStringHeight() end
  b:SetHeight(max(spec.h or 24, h))
  return b:GetHeight()
end

local function buildCard(w, spec, width)
  local pad = spec.bare and 0 or 10
  if spec.bare then w:SetBackdropColor(0, 0, 0, 0); w:SetBackdropBorderColor(0, 0, 0, 0)
  else w:SetBackdropColor(C.panel[1], C.panel[2], C.panel[3], 1); setBorder(w, C.line) end
  w:SetAlpha(spec.dim and 0.45 or 1)
  local y = -pad
  if spec.title or spec.icon then
    local left = pad
    if spec.icon then
      w.icon:ClearAllPoints(); w.icon:SetPoint("TOPLEFT", pad, y); w.icon:Show()
      L.drawIcon(w.icon, spec.icon); left = pad + 34
    else w.icon:Hide() end
    w.title:ClearAllPoints(); w.title:SetPoint("TOPLEFT", left, y); w.title:SetWidth(width - left - pad)
    w.title:SetText(spec.title or ""); w.title:Show()
    local th = spec.title and w.title:GetStringHeight() or 0
    local sub = val(spec.sub)
    if sub then
      w.sub:ClearAllPoints(); w.sub:SetPoint("TOPLEFT", left, y - th - 2); w.sub:SetWidth(width - left - pad)
      w.sub:SetText(sub); w.sub:Show(); th = th + 2 + w.sub:GetStringHeight()
    else w.sub:Hide() end
    y = y - max(spec.icon and 26 or 0, th) - 8
  else
    w.icon:Hide(); w.title:Hide(); w.sub:Hide()
  end
  local used = 0
  for _, row in ipairs(spec.rows or {}) do
    local fixed, flex = 0, 0
    for _, bs in ipairs(row) do if bs.w then fixed = fixed + bs.w else flex = flex + 1 end end
    local gap = 6
    local avail = width - 2 * pad - fixed - gap * (#row - 1)
    local x, rowH = pad, 0
    for _, bs in ipairs(row) do
      used = used + 1
      local b = w.btns[used]
      if not b then b = mkButton(w); w.btns[used] = b end
      b:Show()
      local bw = bs.w or floor(avail / max(1, flex))
      rowH = max(rowH, layoutButton(b, bs, bw))
      b:ClearAllPoints(); b:SetPoint("TOPLEFT", x, y)
      x = x + bw + gap
    end
    for k = used - #row + 1, used do w.btns[k]:SetHeight(rowH) end
    y = y - rowH - 6
  end
  for k = used + 1, #w.btns do w.btns[k]:Hide() end
  if used > 0 then y = y + 6 end
  return -y + pad
end

local function buildSeg(w, spec, width)
  local n = #spec.opts
  local bw = floor((width - 6 * (n - 1)) / n)
  for k, o in ipairs(spec.opts) do
    local b = w.btns[k]
    if not b then b = mkButton(w); w.btns[k] = b end
    b:Show()
    layoutButton(b, {label = o.label, click = o.click, on = o.on, center = true, h = 22}, bw)
    b:SetHeight(22); b:ClearAllPoints(); b:SetPoint("TOPLEFT", (k - 1) * (bw + 6), 0)
  end
  for k = n + 1, #w.btns do w.btns[k]:Hide() end
  return 22
end

local function setList(list, specs, keepScroll)
  for _, w in ipairs(list.widgets) do w:Hide(); table.insert(list.pool[w.kind], w) end
  list.widgets = {}
  local width = max(100, list.sf:GetWidth() - 8)
  list.content:SetWidth(width)
  local y = 0
  for _, spec in ipairs(specs) do
    local w = getWidget(list, spec.kind)
    w.spec = spec
    w:ClearAllPoints(); w:SetPoint("TOPLEFT", list.content, "TOPLEFT", 0, -y); w:SetWidth(width)
    local h
    if spec.kind == "text" then
      local col = spec.color or C.muted
      w.fs:SetFont(FONT, spec.size or 12, ""); w.fs:SetTextColor(col[1], col[2], col[3])
      w.fs:SetJustifyH(spec.center and "CENTER" or "LEFT"); w.fs:SetWidth(width)
      w.fs:SetText(val(spec.text) or "")
      h = w.fs:GetStringHeight() + (spec.space or 0)
    elseif spec.kind == "card" then h = buildCard(w, spec, width)
    else h = buildSeg(w, spec, width) end
    w:SetHeight(h)
    list.widgets[#list.widgets + 1] = w
    y = y + h + (spec.gap or 8)
  end
  list.content:SetHeight(max(1, y))
  if not keepScroll then list.sf:SetVerticalScroll(0)
  else list.sf:SetVerticalScroll(min(list.sf:GetVerticalScroll(), max(0, y - list.sf:GetHeight()))) end
  list.drawBar()
end

-- Actualiza textos y botones sin reconstruir (cada 0,1 s)
local function updateList(list)
  for _, w in ipairs(list.widgets) do
    local spec = w.spec
    if spec.kind == "card" then
      if type(spec.sub) == "function" then w.sub:SetText(spec.sub()) end
      for _, b in ipairs(w.btns) do
        if b:IsShown() and b.spec and type(b.spec.info) == "function" then
          local info, on, warn = b.spec.info()
          b.t2:SetText(info or "")
          setEnabled(b, on ~= false)
          if b.warn ~= warn then b.warn = warn; setBorder(b, warn and C.accent or C.line) end
        end
      end
    elseif spec.kind == "text" and type(spec.text) == "function" then
      w.fs:SetText(spec.text())
    end
  end
end

-- ---------- Ventana ----------
local F = CreateFrame("Frame", "LadosFrame", UIParent, "BackdropTemplate")
F:SetSize(1000, 640); F:SetPoint("CENTER")
F:SetBackdrop(BD); F:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.97); setBorder(F, C.line)
F:SetFrameStrata("HIGH"); F:SetToplevel(true); F:SetClampedToScreen(true)
F:SetMovable(true); F:SetResizable(true); F:EnableMouse(true)
F:Hide()
tinsert(UISpecialFrames, "LadosFrame")         -- Esc cierra la ventana

local SHOP_W = 300
local shopShown = true                         -- la tienda se puede ocultar para dejar solo el mapa
local function savePos()
  if not LadosDB then return end
  local p, _, rp, x, y = F:GetPoint()
  LadosDB.pos = {p, rp, x, y, F:GetWidth(), F:GetHeight()}
  LadosDB.scale = F:GetScale(); LadosDB.shopHidden = not shopShown
end

-- Cabecera: monedas, producción, dimensión, sonido, menú y cerrar. Se arrastra para mover la ventana.
local header = CreateFrame("Frame", nil, F)
header:SetPoint("TOPLEFT", 1, -1); header:SetPoint("TOPRIGHT", -1, -1); header:SetHeight(40)
header:EnableMouse(true); header:RegisterForDrag("LeftButton")
header:SetScript("OnDragStart", function() F:StartMoving() end)
header:SetScript("OnDragStop", function() F:StopMovingOrSizing(); savePos() end)
local hline = header:CreateTexture(nil, "ARTWORK")
hline:SetColorTexture(C.line[1], C.line[2], C.line[3], 1); hline:SetPoint("BOTTOMLEFT"); hline:SetPoint("BOTTOMRIGHT"); hline:SetHeight(1)
local coinsFS = text(header, 20, C.ink); coinsFS:SetPoint("LEFT", 16, 0); coinsFS:SetJustifyV("MIDDLE")
local cpsFS = text(header, 12, C.muted); cpsFS:SetPoint("LEFT", coinsFS, "RIGHT", 14, -2)
local dimFS = text(header, 11, C.muted); dimFS:SetPoint("LEFT", cpsFS, "RIGHT", 14, 0)

local function headerButton(label, w)
  local b = mkButton(header); b:SetSize(w, 24)
  b.t1:ClearAllPoints(); b.t1:SetPoint("CENTER"); b.t1:SetJustifyH("CENTER"); b.t1:SetText(label)
  b.t1:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
  b.spec = {}
  return b
end
local closeBtn = headerButton("X", 28); closeBtn:SetPoint("RIGHT", -8, 0)
closeBtn.spec.click = function() F:Hide() end
local menuBtn = headerButton(T"menú", 48); menuBtn:SetPoint("RIGHT", closeBtn, "LEFT", -6, 0)
local shopBtn = headerButton(T"tienda", 54); shopBtn:SetPoint("RIGHT", menuBtn, "LEFT", -6, 0)
local muteBtn = headerButton("", 96); muteBtn:SetPoint("RIGHT", shopBtn, "LEFT", -6, 0)
local function drawMute() muteBtn.t1:SetText(L.OPT.muted and T"sonido: no" or T"sonido: sí") end
muteBtn.spec.click = function() L.OPT.muted = not L.OPT.muted; drawMute() end

-- Mapa (izquierda) y tienda (derecha)
local stage = CreateFrame("Frame", nil, F)
stage:SetClipsChildren(true); stage:EnableMouse(true)
L.initDraw(stage)

local shop = CreateFrame("Frame", nil, F)
shop:SetPoint("TOPLEFT", stage, "TOPRIGHT", 0, 0); shop:SetPoint("BOTTOMRIGHT", -1, 1)
local sline = shop:CreateTexture(nil, "ARTWORK")
sline:SetColorTexture(C.line[1], C.line[2], C.line[3], 1); sline:SetPoint("TOPLEFT"); sline:SetPoint("BOTTOMLEFT"); sline:SetWidth(1)

-- ---------- Tamaño y escala ----------
-- Tamaño mínimo: con tienda hace falta su ancho; sin ella la ventana puede ser diminuta
local function minSize() if shopShown then return SHOP_W + 220, 300 end return 250, 150 end
local function applyBounds()
  local mw, mh = minSize()
  if F.SetResizeBounds then F:SetResizeBounds(mw, mh, 2400, 1600) elseif F.SetMinResize then F:SetMinResize(mw, mh) end
  if F:GetWidth() < mw or F:GetHeight() < mh then F:SetSize(max(mw, F:GetWidth()), max(mh, F:GetHeight())) end
end
-- Ancla la ventana por su esquina de arriba a la izquierda, para que crezca o encoja hacia abajo y a la derecha
local function anchorTopLeft()
  local l, t = F:GetLeft(), F:GetTop()
  if l then F:ClearAllPoints(); F:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l, t) end
end
local function layoutShop()
  stage:ClearAllPoints(); stage:SetPoint("TOPLEFT", 1, -41)
  stage:SetPoint("BOTTOMRIGHT", shopShown and (-SHOP_W - 1) or -1, 1)
  shop:SetShown(shopShown)
  shopBtn.on = shopShown; setBorder(shopBtn, shopShown and C.ink or C.line)
  local c = shopShown and C.ink or C.muted
  shopBtn.t1:SetTextColor(c[1], c[2], c[3])
end
layoutShop()
local function setShop(on, keepSize)
  if on == shopShown then return end
  anchorTopLeft()
  shopShown = on
  layoutShop()
  if on then
    if not keepSize then F:SetWidth(F:GetWidth() + SHOP_W) end
    applyBounds()
  else
    applyBounds()
    if not keepSize then F:SetWidth(max(minSize(), F:GetWidth() - SHOP_W)) end
  end
  savePos()
  if on and L.buildShop and L.inGame then L.buildShop() end
end
L.setShop = setShop
shopBtn.spec.click = function() setShop(not shopShown) end

local SCALE_MIN, SCALE_MAX = 0.5, 1.5
local SCALE_STEPS = {0.5, 0.6, 0.7, 0.8, 0.9, 1, 1.15, 1.3, 1.5}
local grip
local function setScale(s)
  s = max(SCALE_MIN, min(SCALE_MAX, floor(s * 20 + 0.5) / 20))
  local old = F:GetScale()
  if math.abs(s - old) < 0.001 then return end
  local l, t = F:GetLeft(), F:GetTop()
  F:SetScale(s)
  if l then F:ClearAllPoints(); F:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l * old / s, t * old / s) end
  savePos()
  if grip and GameTooltip and GameTooltip:IsOwned(grip) then grip:GetScript("OnEnter")(grip) end
end
L.setScale = setScale
L.wheelScale = function(d) setScale(F:GetScale() + d * 0.05) end
F:EnableMouseWheel(true)
F:SetScript("OnMouseWheel", function(_, d) if IsControlKeyDown() then L.wheelScale(d) end end)

-- Esquina: arrastrar cambia el tamaño, la rueda cambia la escala y el clic derecho la devuelve al 100%
grip = CreateFrame("Button", nil, F)
grip:SetSize(20, 20); grip:SetPoint("BOTTOMRIGHT", -1, 1); grip:SetFrameLevel(F:GetFrameLevel() + 40)
grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
grip:EnableMouseWheel(true)
grip:SetScript("OnMouseDown", function(_, button)
  if button == "RightButton" then setScale(1) return end
  anchorTopLeft(); F:StartSizing("BOTTOMRIGHT")
end)
grip:SetScript("OnMouseUp", function() F:StopMovingOrSizing(); anchorTopLeft(); savePos() end)
grip:SetScript("OnMouseWheel", function(_, d) L.wheelScale(d) end)
grip:SetScript("OnEnter", function(s)
  GameTooltip:SetOwner(s, "ANCHOR_TOPLEFT")
  GameTooltip:AddLine(T"Lados · escala " .. floor(F:GetScale() * 100 + 0.5) .. "%")
  GameTooltip:AddLine(T"Arrastra: cambiar el tamaño", 1, 1, 1)
  GameTooltip:AddLine(T"Rueda (o Ctrl+rueda en la ventana): escala", 1, 1, 1)
  GameTooltip:AddLine(T"Clic derecho: escala 100%", 1, 1, 1)
  GameTooltip:Show()
end)
grip:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- El mundo mide 2000 unidades de ancho y se ve alejado para que quepa.
-- En ventanas bajas se aleja más, para que siempre haya sitio para las figuras y las torretas.
local WORLD_W = 2000
local function resize()
  local w, h = stage:GetWidth(), stage:GetHeight()
  if not w or w <= 0 or not h or h <= 0 then return end
  L.SCALE = min(max(0.4, min(1, w / WORLD_W)), max(0.28, h / 560))
  L.W, L.H = w / L.SCALE, h / L.SCALE
  L.layoutTurrets()
end
stage:SetScript("OnSizeChanged", resize)

local function cursorWorld()
  local x, y = GetCursorPosition()
  local s = stage:GetEffectiveScale()
  return (x / s - stage:GetLeft()) / L.SCALE, (stage:GetTop() - y / s) / L.SCALE
end
stage:SetScript("OnMouseDown", function(_, button)
  if button ~= "LeftButton" or not L.inGame or L.menuOpen then return end
  L.clickMap(cursorWorld())
end)

-- ---------- Guardado ----------
local function save()
  if L.slot and L.inGame and LadosDB then LadosDB.slots[L.slot] = {S = L.S, at = time()} end
end
L.save = save

-- ---------- Avisos ----------
local toasts, toastPool = {}, {}
function L.toast(title, body)
  local t = table.remove(toastPool)
  if not t then
    t = box(stage, C.panel, C.accent)
    t:SetWidth(260); t:SetFrameLevel(stage:GetFrameLevel() + 10)
    t.a = text(t, 12, C.ink); t.a:SetPoint("TOPLEFT", 10, -8); t.a:SetWidth(240)
    t.b = text(t, 11, C.muted); t.b:SetPoint("TOPLEFT", t.a, "BOTTOMLEFT", 0, -3); t.b:SetWidth(240)
  end
  local tw = max(120, min(260, stage:GetWidth() - 20))
  t:SetWidth(tw); t.a:SetWidth(tw - 20); t.b:SetWidth(tw - 20)
  t.a:SetText(title); t.b:SetText(body); t:Show()
  t:SetHeight(20 + t.a:GetStringHeight() + t.b:GetStringHeight())
  t.life = 4.3
  table.insert(toasts, 1, t)
  while #toasts > 4 do local old = table.remove(toasts); old:Hide(); toastPool[#toastPool + 1] = old end
end
local function updateToasts(dt)
  local y = -64
  for j = #toasts, 1, -1 do
    local t = toasts[j]
    t.life = t.life - dt
    if t.life <= 0 then t:Hide(); table.remove(toasts, j); toastPool[#toastPool + 1] = t end
  end
  for _, t in ipairs(toasts) do
    t:ClearAllPoints(); t:SetPoint("TOPRIGHT", stage, "TOPRIGHT", -10, y)
    t:SetAlpha(min(1, t.life / 0.6))
    y = y - t:GetHeight() - 6
  end
end

-- Barra del jefe
local bossBar = box(stage, C.panel, C.line)
bossBar:SetSize(360, 34); bossBar:SetPoint("TOP", 0, -10); bossBar:SetFrameLevel(stage:GetFrameLevel() + 10)
bossBar.name = text(bossBar, 11, C.ink); bossBar.name:SetPoint("TOPLEFT", 10, -6)
bossBar.time = text(bossBar, 11, C.muted); bossBar.time:SetPoint("TOPRIGHT", -10, -6); bossBar.time:SetJustifyH("RIGHT")
bossBar.bg = bossBar:CreateTexture(nil, "ARTWORK")
bossBar.bg:SetColorTexture(C.line[1], C.line[2], C.line[3], 1); bossBar.bg:SetPoint("BOTTOMLEFT", 10, 7); bossBar.bg:SetPoint("BOTTOMRIGHT", -10, 7); bossBar.bg:SetHeight(6)
bossBar.fill = bossBar:CreateTexture(nil, "OVERLAY")
bossBar.fill:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1); bossBar.fill:SetPoint("LEFT", bossBar.bg, "LEFT"); bossBar.fill:SetHeight(6)
bossBar:Hide()
local function renderBoss()
  local b = L.boss
  if not b then bossBar:Hide(); return end
  local bw = max(140, min(360, stage:GetWidth() - 20))
  bossBar:SetWidth(bw); bossBar:Show()
  bossBar.name:SetText(b.name)
  bossBar.time:SetText(ceil(max(0, L.BOSS_TIME - b.t)) .. " s")
  bossBar.fill:SetWidth(max(0.01, (bw - 20) * L.bossHP(b) / b.hp0))
end

-- Modificadores activos (arriba a la izquierda del mapa)
local modBoxes = {}
local function renderMods()
  local k = 0
  for _, m in ipairs(L.MODS) do
    if L.modOn(m.key) then
      k = k + 1
      local b = modBoxes[k]
      if not b then
        b = box(stage, C.panel, C.line); b:SetSize(190, 24); b:SetFrameLevel(stage:GetFrameLevel() + 10)
        b.t = text(b, 11, C.ink); b.t:SetPoint("LEFT", 8, 1)
        b.s = text(b, 11, C.muted); b.s:SetPoint("RIGHT", -8, 1); b.s:SetJustifyH("RIGHT")
        b.bar = b:CreateTexture(nil, "OVERLAY"); b.bar:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
        b.bar:SetPoint("BOTTOMLEFT", 1, 1); b.bar:SetHeight(3)
        modBoxes[k] = b
      end
      b:ClearAllPoints(); b:SetPoint("TOPLEFT", stage, "TOPLEFT", 10, -10 - (k - 1) * 30)
      b.t:SetText(m.icon .. "  " .. m.name); b.s:SetText(ceil(L.mods[m.key]) .. " s")
      b.bar:SetWidth(max(0.01, 188 * min(1, L.mods[m.key] / m.dur))); b:Show()
    end
  end
  for j = k + 1, #modBoxes do modBoxes[j]:Hide() end
end

-- Destello al subir de dimensión
local flash = stage:CreateTexture(nil, "OVERLAY", nil, 7)
flash:SetAllPoints(); flash:SetColorTexture(C.ink[1], C.ink[2], C.ink[3], 1); flash:SetAlpha(0)
local flashT = 0

-- Recompensa al volver
local away = box(stage, C.panel, C.line)
away:SetSize(280, 120); away:SetPoint("CENTER", 0, 40); away:SetFrameLevel(stage:GetFrameLevel() + 20)
away.a = text(away, 11, C.muted); away.a:SetPoint("TOP", 0, -12); away.a:SetJustifyH("CENTER")
away.b = text(away, 20, C.ink); away.b:SetPoint("TOP", away.a, "BOTTOM", 0, -6); away.b:SetJustifyH("CENTER")
away.c = text(away, 11, C.muted); away.c:SetPoint("TOP", away.b, "BOTTOM", 0, -6); away.c:SetJustifyH("CENTER")
away.ok = mkButton(away); away.ok:SetSize(120, 24); away.ok:SetPoint("BOTTOM", 0, 10)
away.ok.t1:ClearAllPoints(); away.ok.t1:SetPoint("CENTER"); away.ok.t1:SetJustifyH("CENTER"); away.ok.t1:SetText(T"Seguir")
away.ok.spec = {click = function() away:Hide() end}
away:Hide()

local refresh
local function grantAway(sec)
  local gain
  gain, sec = L.awayGain(sec)
  if gain < 1 then return end
  L.earn(gain); save()
  L.awaySound()
  local aw = max(160, min(280, stage:GetWidth() - 10))
  away:SetWidth(aw); away:ClearAllPoints(); away:SetPoint("CENTER", 0, stage:GetHeight() > 300 and 40 or 0)
  away.a:SetWidth(aw - 16); away.c:SetWidth(aw - 16)
  away.a:SetText(T"Mientras no estabas · " .. L.fmtTime(sec) .. (sec >= L.AWAY_MAX and T" (máximo)" or ""))
  away.b:SetText("+" .. fmt(gain) .. T" monedas")
  away.c:SetText(T"tus torretas siguieron trabajando al " .. floor(L.AWAY_RATE * 100) .. "%")
  away:SetHeight(max(120, 70 + (away.a:GetStringHeight() or 12) + (away.b:GetStringHeight() or 20) + (away.c:GetStringHeight() or 12)))
  away:Show()
  if refresh then refresh() end
end

-- ---------- Tienda ----------
local TABS = {{"turrets", T"Torretas"}, {"shapes", T"Figuras"}, {"dim", T"Dimensión"}}
local tab = "turrets"
local dots = {}
local tabBtns = {}
local tabBar = CreateFrame("Frame", nil, shop)
tabBar:SetPoint("TOPLEFT", 1, 0); tabBar:SetPoint("TOPRIGHT"); tabBar:SetHeight(32)
local shopList = mkList(shop)
local buildShop

for k, t in ipairs(TABS) do
  local b = CreateFrame("Button", nil, tabBar)
  b.fs = text(b, 12, C.muted); b.fs:SetPoint("CENTER"); b.fs:SetJustifyH("CENTER"); b.fs:SetText(t[2])
  b.under = b:CreateTexture(nil, "OVERLAY"); b.under:SetColorTexture(C.ink[1], C.ink[2], C.ink[3], 1)
  b.under:SetPoint("BOTTOMLEFT"); b.under:SetPoint("BOTTOMRIGHT"); b.under:SetHeight(2)
  b.dot = b:CreateTexture(nil, "OVERLAY"); b.dot:SetTexture("Interface\\AddOns\\Lados\\texturas\\punto")
  b.dot:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1); b.dot:SetSize(7, 7); b.dot:SetPoint("LEFT", b.fs, "RIGHT", 4, 4)
  b.key = t[1]
  b:SetScript("OnClick", function(s) tab = s.key; dots[s.key] = nil; buildShop() end)
  tabBtns[k] = b
end

local function seen(k) return L.S.seen[k] ~= nil end
local function bulkInfo(getB, pre)
  return function()
    local b = getB()
    local n, c = L.quote(b)
    local p = val(pre) or ""
    return p .. (L.buyMode ~= 1 and ("×" .. n .. " · ") or "") .. fmt(c) .. T" monedas", L.S.coins >= c
  end
end
local function buy(getB) return function() if L.buyBulk(getB()) then refresh(); save() end end end
local function bulkBar()
  local function opt(v, label) return {label = label, on = L.buyMode == v, click = function() L.buyMode = v; buildShop() end} end
  return {kind = "seg", opts = {opt(1, "×1"), opt(10, "×10"), opt(math.huge, T"Máx")}}
end

local function turretsTab()
  local S, out = L.S, {}
  local B = L.BULK
  if seen("turret") then
    out[#out + 1] = {kind = "card", title = T"Torretas",
      sub = function() return S.guns .. " " .. (S.guns == 1 and T"torreta" or T"torretas") .. " · " .. fmt(L.fireRate()) .. T" lados/s · se enlazan a la figura más cercana" end,
      rows = {{{label = T"Comprar torreta", info = bulkInfo(B.turret), click = buy(B.turret)}}}}
  end
  if seen("coord") then
    out[#out + 1] = {kind = "card", bare = true, rows = {{{label = T"Coordinación · torretas +50% cadencia",
      info = bulkInfo(B.coord, function() return T"nivel " .. S.coord .. " · " end), click = buy(B.coord)}}}}
  end
  if seen("punch") then
    out[#out + 1] = {kind = "card", bare = true, rows = {{{label = T"Golpe · ×2 lados por clic",
      info = bulkInfo(B.punch, function() local p = L.punchPower(); return fmt(p) .. " " .. (p == 1 and T"lado" or T"lados") .. T" por clic · " end),
      click = buy(B.punch)}}}}
  end
  for _, u in ipairs(L.EXTRAS) do
    if seen(u.key) then
      local get = function() return B.extra(u.key) end
      local base = bulkInfo(get, function() local l = L.lvl(u.key); return l > 0 and (u.status(l) .. " · ") or "" end)
      out[#out + 1] = {kind = "card", bare = true, rows = {{{label = u.name .. " · " .. u.desc,
        info = function()
          local l = L.lvl(u.key)
          if l >= u.max then return u.status(l) .. T" · máximo", false end
          return base()
        end, click = buy(get)}}}}
    end
  end
  if #out > 0 then table.insert(out, 1, bulkBar()) end
  return out
end

local function joinList(list)
  if #list == 1 then return list[1] end
  return table.concat(list, ", ", 1, #list - 1) .. T" y " .. list[#list]
end
local function compCard(d, withBuy)
  local D = L.DESIGNS[d + 1]
  local n = L.SHAPES[D.core].sides
  local names = {}
  for k, m in ipairs(D.mods) do
    local c = 0
    for j = 0, n - 1 do if D.mods[j % #D.mods + 1] == m then c = c + 1 end end
    names[k] = c .. " " .. L.SHAPES[m].name:lower() .. "s"
  end
  local spec = {kind = "card", icon = {d = d}, title = D.name,
    sub = L.SHAPES[D.core].name .. " + " .. joinList(names) .. " · +" .. fmt(L.designValue(d)) .. T" entera" .. (#D.mods > 1 and (" (×" .. 2 ^ #D.mods .. ")") or "")}
  if withBuy then
    spec.rows = {{{label = T"Desbloquear compuesta",
      info = function() local c = L.designCost(L.S.designs); return fmt(c) .. T" monedas", L.S.coins >= c end,
      click = function() if L.buyDesign() then buildShop(); refresh(); save() end end}}}
  end
  return spec
end

local function shapesTab()
  local S, out, N = L.S, {}, L.N
  local B = L.BULK
  local function famHead(i) if L.isFamStart(i) then out[#out + 1] = {kind = "text", text = L.familyOf(i), gap = 4} end end
  for i = 0, S.unlocked - 1 do
    famHead(i)
    local SH = L.SHAPES[i]
    local spec = {kind = "card", icon = {i = i}, title = SH.name, sub = function()
      local wsum = 0
      for j = 0, S.unlocked - 1 do wsum = wsum + L.spawnWeight(j) end
      return SH.sides .. " " .. (SH.sides == 1 and T"lado" or T"lados") .. " · +" .. fmt(L.reward(i)) .. T" por figura · " ..
        floor(L.spawnWeight(i) / wsum * 100 + 0.5) .. T"% de apariciones"
    end}
    if seen("polish" .. i) then
      local gp, ga = function() return B.polish(i) end, function() return B.attract(i) end
      spec.rows = {{
        {label = T"Pulir ×2", info = bulkInfo(gp), click = buy(gp)},
        {label = T"Atraer +" .. floor(L.ATTRACT_BONUS * 100) .. "%", info = bulkInfo(ga, function()
          local a = S.attract[i]; return a > 0 and ("+" .. floor(a * L.ATTRACT_BONUS * 100) .. "% · ") or "" end), click = buy(ga)},
      }}
    end
    out[#out + 1] = spec
  end
  if S.unlocked < N and seen("unlock" .. S.unlocked) then
    local i = S.unlocked
    local SH = L.SHAPES[i]
    local fam = L.isFamStart(i) and (T"Nueva familia: " .. L.familyOf(i) .. " · ") or ""
    out[#out + 1] = {kind = "card", icon = {i = i}, title = SH.name,
      sub = fam .. SH.sides .. T" lados · +" .. fmt(SH.sides * L.sideValue(i)) .. T" por figura",
      rows = {{{label = T"Desbloquear", info = function() local c = L.unlockCost(L.S.unlocked); return fmt(c) .. T" monedas", L.S.coins >= c end,
        click = function() if L.buyUnlock() then buildShop(); refresh(); save() end end}}}}
  end
  if S.unlocked == N then
    out[#out + 1] = {kind = "text", text = T"Has desbloqueado todas las figuras. Del círculo de 1 lado al hectágono de 100."}
  end
  local comps = {}
  for d = 0, S.designs - 1 do comps[#comps + 1] = compCard(d) end
  if S.designs < #L.DESIGNS and seen("design" .. S.designs) then comps[#comps + 1] = compCard(S.designs, true) end
  if #comps > 0 then
    out[#out + 1] = {kind = "text", text = T"Compuestas · rompe los módulos para quitar el escudo del núcleo", gap = 4}
    for _, c in ipairs(comps) do out[#out + 1] = c end
  end
  if seen("polish0") then table.insert(out, 1, bulkBar()) end
  return out
end

local prestigeArm = 0
local function dimTab()
  local m = L.S.meta
  local out = {}
  out[#out + 1] = {kind = "card", title = T"Dimensión actual: " .. L.dimName(), sub = function()
    return fmt(m.aristas) .. T" aristas · " .. fmt(m.aristasTotal) .. T" ganadas · " .. L.achCount() .. T" logros · ganancias ×" ..
      string.format("%.2f", L.incomeMult())
  end}
  out[#out + 1] = {kind = "card", title = T"Subir a " .. (3 + m.dims) .. "D",
    sub = T"Reinicia monedas, torretas, mejoras y figuras. Conservas aristas, mejoras de dimensión y logros. Cada arista ganada da +" ..
      floor(L.ARISTA_BONUS * 100) .. T"% a todo para siempre.",
    rows = {{{label = T"Subir de dimensión", info = function()
      local gain, S = L.aristasFor(L.S.total), L.S
      if GetTime() > prestigeArm then prestigeArm = 0 end
      if gain == 0 then return T"necesitas ganar " .. fmt(L.BAL.prest) .. T" monedas en esta dimensión (" .. fmt(S.total) .. ")", false end
      if prestigeArm > 0 then return T"¿seguro? pulsa otra vez · +" .. fmt(gain) .. T" aristas", true, true end
      return "+" .. fmt(gain) .. " " .. (gain == 1 and T"arista" or T"aristas") .. T" · siguiente con " ..
        fmt(L.BAL.prest * ((gain + 1) / 3) ^ (1 / L.BAL.arista)), true
    end, click = function()
      if L.aristasFor(L.S.total) == 0 then return end
      if prestigeArm == 0 then prestigeArm = GetTime() + 3; refresh(); return end
      prestigeArm = 0
      if L.doPrestige() then
        tab = "dim"; for k in pairs(dots) do dots[k] = nil end
        flashT = 1.2; L.prestigeSound(); L.clearFloats()
        save(); buildShop()
      end
    end}}}}
  out[#out + 1] = {kind = "text", text = T"Mejoras de dimensión · se pagan con aristas", gap = 4}
  for _, u in ipairs(L.PERKS) do
    out[#out + 1] = {kind = "card", bare = true, rows = {{{label = u.name .. " · " .. u.desc, info = function()
      local l = L.perk(u.key)
      if l >= u.max then return u.status(l) .. T" · máximo", false end
      local c = L.perkCost(u)
      return (l > 0 and (u.status(l) .. " · ") or "") .. fmt(c) .. (c == 1 and T" arista" or T" aristas"), m.aristas >= c
    end, click = function() if L.buyPerk(u) then refresh(); save() end end}}}}
  end
  return out
end

local function tabContent(k)
  local S = L.S
  if k == "turrets" then return turretsTab() end
  if k == "shapes" then
    if S.unlocked > 1 or seen("unlock1") or seen("polish0") then return shapesTab() end
    return {}
  end
  if k == "dim" then return seen("dim") and dimTab() or {} end
end

buildShop = function()
  if not L.inGame then
    for _, b in ipairs(tabBtns) do b:Hide() end
    setList(shopList, {})
    return
  end
  local contents, visible = {}, {}
  for _, t in ipairs(TABS) do
    contents[t[1]] = tabContent(t[1])
    if #contents[t[1]] > 0 then visible[#visible + 1] = t[1] end
  end
  if #contents[tab] == 0 and #visible > 0 then tab = visible[1] end
  dots[tab] = nil
  local showTabs = #visible > 1
  local tw = (SHOP_W - 1) / max(1, #visible)
  for _, b in ipairs(tabBtns) do b:Hide() end
  for k, key in ipairs(visible) do
    for _, b in ipairs(tabBtns) do
      if b.key == key and showTabs then
        b:Show(); b:ClearAllPoints(); b:SetPoint("TOPLEFT", (k - 1) * tw, 0); b:SetSize(tw, 32)
        local on = key == tab
        b.fs:SetTextColor(unpack(on and C.ink or C.muted))
        b.under:SetShown(on); b.dot:SetShown(dots[key] and true or false)
      end
    end
  end
  shopList.sf:ClearAllPoints()
  shopList.sf:SetPoint("TOPLEFT", shop, "TOPLEFT", 14, showTabs and -42 or -14)
  shopList.sf:SetPoint("BOTTOMRIGHT", shop, "BOTTOMRIGHT", -6, 14)
  local specs = contents[tab]
  if #specs == 0 then specs = {{kind = "text", text = T"Haz clic en las figuras para romper sus lados. Tu torreta del centro dispara hacia donde pulses."}} end
  setList(shopList, specs, true)
end
L.buildShop = buildShop
shop:SetScript("OnSizeChanged", function() if L.inGame then buildShop() end end)

local function tabOf(key)
  if key == "dim" then return "dim" end
  if key:find("^unlock") or key:find("^design") or key:find("^polish") then return "shapes" end
  return "turrets"
end

-- En ventanas estrechas la cabecera esconde lo que no cabe: dimensión, producción y botón de sonido
local coinsSize = 20
local function layoutHeader()
  local W = F:GetWidth()
  local size = W < 420 and 16 or 20
  if size ~= coinsSize then coinsSize = size; coinsFS:SetFont(FONT, size, "") end
  muteBtn:SetShown(W >= 620)
  local right = 8 + 28 + 6 + 48 + 6 + 54 + (muteBtn:IsShown() and (6 + 96) or 0) + 12
  local free = W - 16 - (coinsFS:GetStringWidth() or 0) - right
  local cw = (cpsFS:GetStringWidth() or 0) + 14
  local dw = (dimFS:GetStringWidth() or 0) + 14
  cpsFS:SetShown(free >= cw); dimFS:SetShown(free >= cw + dw)
end

local function updateHeader()
  local S = L.S
  if not L.inGame then coinsFS:SetText(T"Lados"); cpsFS:SetText(""); dimFS:SetText("")
  else
    coinsFS:SetText(fmt(S.coins))
    local rate = L.cps()
    cpsFS:SetText(rate > 0 and ("~" .. fmt(rate) .. " /s") or "")
    dimFS:SetText(S.meta.dims > 0 and L.dimName() or "")
  end
  layoutHeader()
end

refresh = function()
  local keys = L.checkReveals()
  if #keys > 0 then
    L.revealSound()
    for _, key in ipairs(keys) do local t = tabOf(key); if t ~= tab then dots[t] = true end end
    buildShop()
  else
    updateList(shopList)
  end
  updateHeader()
end
L.refresh = refresh

-- ---------- Menú ----------
local menu = CreateFrame("Frame", nil, F)
menu:SetPoint("TOPLEFT", 1, -41); menu:SetPoint("BOTTOMRIGHT", -1, 1)
menu:SetFrameLevel(F:GetFrameLevel() + 30); menu:EnableMouse(true)
local mbg = menu:CreateTexture(nil, "BACKGROUND"); mbg:SetAllPoints(); mbg:SetColorTexture(C.bg[1], C.bg[2], C.bg[3], 0.82)
local mtitle = text(menu, 44, C.ink); mtitle:SetPoint("TOP", 0, -24); mtitle:SetJustifyH("CENTER"); mtitle:SetText(T"Lados")
local mtag = text(menu, 12, C.muted); mtag:SetPoint("TOP", mtitle, "BOTTOM", 0, -6); mtag:SetJustifyH("CENTER"); mtag:SetText(T"rompe figuras · compón música")
local marks = {}
for k = 0, 4 do
  local f = CreateFrame("Frame", nil, menu); f:SetSize(24, 24)
  f:SetPoint("TOP", mtag, "BOTTOM", (k - 2) * 32, -10)
  marks[k] = f
end
local menuList = mkList(menu)
menuList.sf:SetPoint("TOP", mtag, "BOTTOM", 0, -48); menuList.sf:SetPoint("BOTTOM", 0, 16); menuList.sf:SetWidth(348)

local view, viewMode = "main", ""
local confirm = nil                                -- botón que espera un segundo clic
local showView

local function mbtn(label, sub, click, enabled)
  return {kind = "card", bare = true, gap = 6, rows = {{{label = label, info = sub, click = click, enabled = enabled, h = 36}}}}
end
local function mtitleRow(t) return {kind = "text", text = string.upper(t), gap = 6} end
local function backRow() return mbtn("< Volver", nil, function() showView("main") end) end

local function readSlot(k) return LadosDB.slots[k] end
local function latestSlot()
  local best, bk
  for k = 1, 3 do local d = readSlot(k); if d and (not best or d.at > best.at) then best, bk = d, k end end
  return best, bk
end
local function summary(d)
  local s = d.S
  local dim = (s.meta and s.meta.dims or 0) > 0 and ((2 + s.meta.dims) .. "D · ") or ""
  return dim .. fmt(max(s.total or 0, s.coins or 0)) .. T" monedas · " .. s.unlocked .. " " .. (s.unlocked == 1 and T"figura" or T"figuras") ..
    " · " .. date("%d/%m %H:%M", d.at)
end

local function openMenu(v, mode)
  save(); L.menuOpen = true; menu:Show(); showView(v or "main", mode)
end
local function closeMenu()
  L.menuOpen = false; menu:Hide(); confirm = nil
end
L.openMenu = openMenu

local function startGame(k, raw, at)
  L.slot = k; L.S = L.loadState(raw); L.inGame = true
  L.clearMap(); L.clearFloats(); L.layoutTurrets()
  tab = "turrets"; for key in pairs(dots) do dots[key] = nil end
  away:Hide()
  buildShop(); closeMenu()
  if raw and at then
    local sec = time() - at
    if sec > L.AWAY_MIN then grantAway(sec) end
  end
  save()
end
L.startGame = startGame
local function quitToDemo()
  L.slot = nil; L.inGame = false; L.S = L.demoState()
  L.clearMap(); L.clearFloats(); L.layoutTurrets(); buildShop()
end

-- Pide un segundo clic durante 3 s antes de algo que no se puede deshacer
local function armed(key)
  if confirm == key then confirm = nil; return true end
  confirm = key
  C_Timer.After(3, function() if confirm == key then confirm = nil; if L.menuOpen then showView(view, viewMode) end end end)
  showView(view, viewMode)
  return false
end

local CHANNELS = {{"SFX", T"Efectos"}, {"Music", T"Música"}, {"Ambience", T"Ambiente"}, {"Master", "General"}}
local function channelName()
  for _, c in ipairs(CHANNELS) do if c[1] == L.OPT.channel then return c[2] end end
  return L.OPT.channel
end

showView = function(v, mode)
  view, viewMode = v, mode or ""
  local h = {}
  local function add(s) h[#h + 1] = s end
  if v == "main" then
    local last, lk = latestSlot()
    if L.inGame then add(mbtn(T"Continuar", T"Ranura " .. L.slot .. T" · en pausa", closeMenu))
    elseif last then add(mbtn(T"Continuar", T"Ranura " .. lk .. " · " .. summary(last), function() startGame(lk, last.S, last.at) end)) end
    add(mbtn(T"Nueva partida", nil, function() showView("slots", "new") end))
    add(mbtn(T"Cargar partida", nil, function() showView("slots", "load") end, last ~= nil))
    if L.inGame then
      add(mbtn(T"Logros", L.achCount() .. T" de " .. #L.ACHS .. " · +" .. floor(L.achCount() * L.ACH_BONUS * 100 + 0.5) .. T"% ganancias",
        function() showView("achs") end))
    end
    add(mbtn(T"Opciones", nil, function() showView("options") end))
    add(mbtn(T"Cómo jugar", nil, function() showView("help") end))
    add({kind = "text", text = "v" .. L.VERSION .. T" · /lados abre y cierra esta ventana", center = true})
  elseif v == "slots" then
    add(mtitleRow(viewMode == "new" and T"Nueva partida · elige ranura" or T"Cargar partida"))
    for k = 1, 3 do
      local d = readSlot(k)
      local playing = L.inGame and k == L.slot
      local sub = d and (summary(d) .. (playing and T" · en juego" or "")) or T"Vacía"
      local key = "slot" .. k
      if viewMode == "new" and d and confirm == key then sub = T"Ya tiene una partida: pulsa otra vez para sobrescribirla" end
      if confirm == "del" .. k then sub = T"Pulsa otra vez la X para borrarla. No se puede deshacer." end
      local row = {{label = T"Ranura " .. k, info = sub, h = 36, enabled = viewMode == "new" or d ~= nil, click = function()
        if viewMode == "new" then
          if d and not armed(key) then return end
          startGame(k, nil)
        elseif d then startGame(k, d.S, d.at) end
      end}}
      if d and viewMode == "load" then
        row[2] = {label = "X", w = 40, h = 36, center = true, click = function()
          if not armed("del" .. k) then return end
          LadosDB.slots[k] = nil
          if k == L.slot then quitToDemo() end
          showView(latestSlot() and "slots" or "main", "load")
        end}
      end
      add({kind = "card", bare = true, gap = 6, rows = {row}})
    end
    add(backRow())
  elseif v == "options" then
    add(mtitleRow(T"Opciones"))
    local function toggle(label, key, sub)
      add(mbtn(label, (L.OPT[key] and T"sí" or "no") .. (sub and (" · " .. sub) or ""), function()
        L.OPT[key] = not L.OPT[key]; drawMute(); showView("options") end))
    end
    toggle(T"Silenciar todo", "muted")
    toggle(T"Sonido de disparos", "shots")
    toggle(T"Base rítmica de fondo", "beat")
    toggle(T"Números al romper figuras", "floats")
    toggle(T"Cerrar al entrar en combate", "combatHide")
    add(mbtn(T"Canal de sonido", channelName() .. T" · el volumen se ajusta en las opciones de sonido de WoW", function()
      local idx = 1
      for k, c in ipairs(CHANNELS) do if c[1] == L.OPT.channel then idx = k end end
      L.OPT.channel = CHANNELS[idx % #CHANNELS + 1][1]
      L.tone(L.noteOf(0, 0) + 12, 0, "t")
      showView("options")
    end))
    add(mbtn(T"Escala de la ventana", floor(F:GetScale() * 100 + 0.5) .. T"% · también con la rueda sobre la esquina o Ctrl+rueda", function()
      local cur, nextS = F:GetScale(), nil
      for _, s in ipairs(SCALE_STEPS) do if s > cur + 0.01 then nextS = s; break end end
      setScale(nextS or SCALE_STEPS[1])
      showView("options")
    end))
    add(mbtn(T"Mostrar la tienda", (shopShown and T"sí" or "no") .. T" · sin ella la ventana puede ser mucho más pequeña", function()
      setShop(not shopShown); showView("options")
    end))
    add(backRow())
  elseif v == "achs" then
    add(mtitleRow(T"Logros · " .. L.achCount() .. T" de " .. #L.ACHS))
    for _, a in ipairs(L.ACHS) do
      local on = L.S.meta.ach[a[1]] ~= nil
      add({kind = "card", title = (on and "+ " or "· ") .. a[2], sub = a[3], dim = not on, gap = 6})
    end
    add(backRow())
  elseif v == "help" then
    add(mtitleRow(T"Cómo jugar"))
    add({kind = "text", color = C.ink, space = 4, text = table.concat({
      T"Las figuras entran al mapa y rebotan. Haz clic donde quieras y tu torreta del centro dispara hacia allí en línea recta: rompe un lado de la primera figura que toque. Al romper todos sus lados ganas monedas.",
      T"Cada lado es una nota: al romper figuras vas componiendo la música. Cada familia suena en su propia escala, y con la primera torreta entra una base de fondo que gana capas a medida que desbloqueas figuras.",
      T"Compra torretas para que disparen por ti: todas comparten las mejoras. Cada torreta se enlaza a una figura distinta y le manda pulsos, justo los que hacen falta para romperla, y luego pasa a otra. En Figuras puedes pulir cada figura (vale el doble) o atraerla (aparece más).",
      T"La mejora Golpe duplica los lados que rompe cada disparo tuyo (como mucho, la pieza entera).",
      T"Más adelante aparecen mejoras de combate: críticos, pulsos que rebotan o atraviesan, y explosiones al romper figuras.",
      T"De vez en cuando aparece una figura deforme que cambia de forma: solo tú puedes pulsarla, y activa un efecto temporal (Instakill, Dinero ×2, Figuras ×3...).",
      T"Desbloquea figuras con más lados: valen mucho más. Hay mejoras que solo aparecen cuando avanzas.",
      T"Las figuras compuestas tienen un núcleo con escudo: rompe antes sus módulos. Enteras pagan el doble.",
      T"Cada pocos minutos llega un jefe: una figura gigante con dos anillos de módulos blindados. Rompe los anillos de fuera hacia dentro antes de que se escape; derrotarlo paga ×" .. (L.BOSS_BONUS + 1) .. ".",
      T"Al ganar " .. fmt(L.BAL.prest) .. T" monedas en una partida puedes subir de dimensión: empiezas de cero a cambio de aristas, que dan ganancias permanentes y compran mejoras que no se pierden.",
      T"Mientras la ventana está cerrada tus torretas siguen trabajando al 50% (hasta 12 horas).",
      T"/lados abre y cierra la ventana; Esc la cierra. También puedes asignarle una tecla en Atajos de teclado > AddOns.",
      T"Tamaño: arrastra la esquina de abajo a la derecha. La rueda sobre esa esquina (o Ctrl+rueda en cualquier parte) cambia la escala, y el botón «tienda» la oculta para dejar solo el mapa. /lados mini la deja lo más pequeña posible y /lados centrar la devuelve a su tamaño normal.",
    }, "\n\n")})
    add(backRow())
  end
  setList(menuList, h)
end

-- En ventanas pequeñas el menú quita el título y estrecha la lista
local function layoutMenu()
  local w, h = menu:GetWidth(), menu:GetHeight()
  if not w or w <= 0 or not h or h <= 0 then return end
  local big = h >= 380 and w >= 380
  mtitle:SetShown(big); mtag:SetShown(big)
  for k = 0, 4 do marks[k]:SetShown(big) end
  menuList.sf:ClearAllPoints()
  if big then menuList.sf:SetPoint("TOP", mtag, "BOTTOM", 0, -48) else menuList.sf:SetPoint("TOP", menu, "TOP", 0, -10) end
  menuList.sf:SetPoint("BOTTOM", 0, big and 16 or 8)
  menuList.sf:SetWidth(max(160, min(348, w - 20)))
end
menu:SetScript("OnSizeChanged", function() layoutMenu(); if L.menuOpen then showView(view, viewMode) end end)
F:SetScript("OnSizeChanged", function() layoutHeader() end)

-- ---------- Bucle ----------
local acc, saveAcc = 0, 0
F:SetScript("OnUpdate", function(_, elapsed)
  local dt = min(0.1, elapsed)
  L.step(dt)
  if L.inGame and not L.menuOpen and stage:IsMouseOver() then L.aim(cursorWorld()) end
  L.audioUpdate()
  L.render(dt)
  updateToasts(dt)
  if flashT > 0 then flashT = max(0, flashT - dt); flash:SetAlpha(0.8 * flashT / 1.2) end
  acc = acc + dt
  if L.inGame and not L.menuOpen and acc > 0.1 then
    acc = 0
    refresh(); renderMods(); renderBoss()
    local got = L.checkAchs()
    if #got > 0 then
      L.achSound()
      for _, a in ipairs(got) do L.toast(T"Logro · " .. a[2], a[3] .. " · +" .. floor(L.ACH_BONUS * 100) .. T"% ganancias") end
    end
  end
  saveAcc = saveAcc + dt
  if saveAcc > 5 then saveAcc = 0; save() end
end)

-- Al cerrar la ventana se guarda; al volver a abrirla, las torretas cobran el tiempo que estuvo cerrada
local hiddenAt
F:SetScript("OnHide", function()
  save()
  hiddenAt = (L.inGame and not L.menuOpen) and time() or nil
end)
F:SetScript("OnShow", function()
  resize()
  if hiddenAt and L.inGame then
    local sec = time() - hiddenAt
    if sec > L.AWAY_MIN then grantAway(sec) end
  end
  hiddenAt = nil
  if L.menuOpen then showView(view, viewMode) end
end)

menuBtn.spec.click = function() if L.menuOpen then if L.inGame then closeMenu() end else openMenu() end end

-- ---------- Arranque ----------
function Lados_Toggle()
  if F:IsShown() then F:Hide() else F:Show() end
end
BINDING_HEADER_LADOS = T"Lados"
BINDING_NAME_LADOS_TOGGLE = T"Abrir o cerrar Lados"
SLASH_LADOS1 = "/lados"
SlashCmdList.LADOS = function(msg)
  msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "centrar" or msg == "center" then
    setShop(true, true); setScale(1)
    F:ClearAllPoints(); F:SetPoint("CENTER"); F:SetSize(1000, 640); savePos(); F:Show()
    return
  elseif msg == "mini" then
    setShop(false); setScale(0.7); anchorTopLeft(); F:SetSize(minSize()); savePos(); F:Show()
    return
  elseif msg == "boton" or msg == "botón" or msg == "button" then
    L.AlternarBoton()
    return
  elseif msg == "tienda" or msg == "shop" then
    setShop(not shopShown); F:Show()
    return
  elseif msg:find("^escala") or msg:find("^scale") then
    local n = tonumber(msg:match("(%d+)"))
    if n then setScale(n / 100); F:Show()
    else print(T"|cff6c9bffLados|r: escribe /lados escala 50 (de " .. floor(SCALE_MIN * 100) .. T" a " .. floor(SCALE_MAX * 100) .. ")") end
    return
  end
  Lados_Toggle()
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED"); ev:RegisterEvent("PLAYER_LOGOUT"); ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:SetScript("OnEvent", function(_, event, name)
  if event == "ADDON_LOADED" and name == ADDON then
    LadosDB = LadosDB or {}
    LadosDB.slots = LadosDB.slots or {}
    LadosDB.opt = LadosDB.opt or {}
    for k, v in pairs(L.OPT) do if LadosDB.opt[k] == nil then LadosDB.opt[k] = v end end
    L.OPT = LadosDB.opt
    local p = LadosDB.pos
    if LadosDB.shopHidden then shopShown = false; layoutShop() end
    if LadosDB.scale then F:SetScale(max(SCALE_MIN, min(SCALE_MAX, LadosDB.scale))) end
    if p then F:ClearAllPoints(); F:SetPoint(p[1], UIParent, p[2], p[3], p[4]); if p[5] then F:SetSize(p[5], p[6]) end end
    applyBounds(); layoutMenu()
    drawMute()
    for k = 0, 4 do L.drawIcon(marks[k], {i = k}) end
    L.S = L.demoState(); resize(); buildShop(); updateHeader()
    openMenu()
  elseif event == "PLAYER_LOGOUT" then
    save()
  elseif event == "PLAYER_REGEN_DISABLED" then
    if L.OPT.combatHide and F:IsShown() then
      F:Hide()
      print(T"|cff6c9bffLados|r: ventana cerrada al entrar en combate. Escribe /lados para volver.")
    end
  end
end)
