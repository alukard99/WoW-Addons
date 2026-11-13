-- Ventana principal (/subastas) y botones junto a la casa de subastas.
local _, S = ...
local T = S.T -- traducción (Locale.lua)

local ventana, cuadro, textoEstado, botonOrden, campoLineas

local function nombreOrden()
  for _, o in ipairs(S.ORDENES) do
    if o.clave == SubastasDB.opciones.orden then return o.nombre end
  end
  return SubastasDB.opciones.orden
end

local function boton(padre, texto, ancho, alPulsar)
  local b = CreateFrame("Button", nil, padre, "UIPanelButtonTemplate")
  b:SetSize(ancho, 22)
  b:SetText(texto)
  b:SetScript("OnClick", alPulsar)
  return b
end

function S.refrescarEstado()
  if textoEstado then textoEstado:SetText(S.textoEstado or "") end
  if S.botonSubasta then S.botonSubasta.estado:SetText(S.textoEstado or "") end
end

-- Si faltan datos de objetos, se vuelve a exportar sola cada 2 s (hasta 10 veces)
-- mientras el juego los va recibiendo del servidor.
local REINTENTOS = 10
local reintento, reintentoPendiente = 0, false

local exportar
exportar = function(esReintento)
  if esReintento ~= true then reintento = 0 end
  local texto, aviso, incluidos, total, faltan = S.exportar()
  if not texto then
    S.estado(aviso)
    return
  end
  cuadro:SetText(texto)
  cuadro:SetCursorPosition(0)
  local listo = string.format(T"%d de %d objetos exportados (%d caracteres). Pulsa «Copiar todo».",
    incluidos, total, #texto)
  if faltan and faltan > 0 and reintento < REINTENTOS and C_Timer then
    reintento = reintento + 1
    S.estado(string.format(T"%s Reintentando (%d/%d)...", aviso, reintento, REINTENTOS))
    if not reintentoPendiente then
      reintentoPendiente = true
      C_Timer.After(2, function()
        reintentoPendiente = false
        exportar(true)
      end)
    end
  elseif faltan and faltan > 0 then
    S.estado(listo .. string.format(T" (%d sin nombre: el servidor no los ha enviado)", faltan))
  else
    S.estado(listo)
  end
end

local function copiarTodo()
  if cuadro:GetText() == "" then exportar() end
  cuadro:SetFocus()
  cuadro:HighlightText()
  -- WoW no deja a los addons escribir en el portapapeles: el texto queda seleccionado para Ctrl+C.
  S.estado(T"Texto seleccionado: pulsa Ctrl+C y pégalo en la IA.")
end

local function crearVentana()
  local f = CreateFrame("Frame", "SubastasVentana", UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(640, 480)
  f:SetPoint("CENTER")
  f:SetFrameStrata("HIGH")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)
  f:Hide()
  tinsert(UISpecialFrames, "SubastasVentana")

  local titulo = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  titulo:SetPoint("TOP", 0, -5)
  titulo:SetText(T"Subastas")

  local escanear = boton(f, T"Escanear", 90, function() S.escanear() end)
  escanear:SetPoint("TOPLEFT", 12, -30)
  local exp = boton(f, T"Exportar", 90, exportar)
  exp:SetPoint("LEFT", escanear, "RIGHT", 6, 0)
  local copiar = boton(f, T"Copiar todo", 100, copiarTodo)
  copiar:SetPoint("LEFT", exp, "RIGHT", 6, 0)

  botonOrden = boton(f, "", 150, function(self)
    local o = SubastasDB.opciones
    for i, v in ipairs(S.ORDENES) do
      if v.clave == o.orden then
        o.orden = S.ORDENES[i % #S.ORDENES + 1].clave
        break
      end
    end
    self:SetText(T"Orden: " .. nombreOrden())
    exportar()
  end)
  botonOrden:SetPoint("LEFT", copiar, "RIGHT", 6, 0)

  local etiqueta = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  etiqueta:SetPoint("LEFT", botonOrden, "RIGHT", 10, 0)
  etiqueta:SetText(T"Máx. objetos:")
  campoLineas = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  campoLineas:SetSize(50, 20)
  campoLineas:SetPoint("LEFT", etiqueta, "RIGHT", 8, 0)
  campoLineas:SetAutoFocus(false)
  campoLineas:SetNumeric(true)
  local function guardarLineas(self)
    local n = tonumber(self:GetText())
    if n and n > 0 then SubastasDB.opciones.lineas = n end
    self:SetText(SubastasDB.opciones.lineas)
    self:ClearFocus()
  end
  campoLineas:SetScript("OnEnterPressed", guardarLineas)
  campoLineas:SetScript("OnEditFocusLost", guardarLineas)
  campoLineas:SetScript("OnEscapePressed", guardarLineas)

  textoEstado = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  textoEstado:SetPoint("TOPLEFT", 14, -58)
  textoEstado:SetPoint("RIGHT", -14, 0)
  textoEstado:SetJustifyH("LEFT")

  local scroll = CreateFrame("ScrollFrame", "SubastasScroll", f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 12, -78)
  scroll:SetPoint("BOTTOMRIGHT", -32, 10)

  cuadro = CreateFrame("EditBox", nil, scroll)
  cuadro:SetMultiLine(true)
  cuadro:SetMaxLetters(0)
  cuadro:SetAutoFocus(false)
  cuadro:SetFontObject(ChatFontNormal)
  cuadro:SetWidth(590)
  cuadro:SetScript("OnEscapePressed", cuadro.ClearFocus)
  if ScrollingEdit_OnCursorChanged then
    cuadro:SetScript("OnCursorChanged", ScrollingEdit_OnCursorChanged)
    scroll:SetScript("OnUpdate", ScrollingEdit_OnUpdate)
  end
  scroll:SetScrollChild(cuadro)
  scroll:EnableMouse(true)
  scroll:SetScript("OnMouseDown", function() cuadro:SetFocus() end)

  f:SetScript("OnShow", function()
    botonOrden:SetText(T"Orden: " .. nombreOrden())
    campoLineas:SetText(SubastasDB.opciones.lineas)
    if not S.textoEstado then
      local u = S.reino().ultimo
      S.estado(u and (T"Último escaneo: " .. date("%Y-%m-%d %H:%M", u.t) .. T". Pulsa Exportar.")
        or T"Abre la casa de subastas y pulsa Escanear.")
    end
    S.refrescarEstado()
  end)
  ventana = f
end

function Subastas_Toggle()
  if not ventana then crearVentana() end
  ventana:SetShown(not ventana:IsShown())
end

S.alTerminarEscaneo = function()
  if ventana and ventana:IsShown() then exportar() end
end

-- Botones encima de la ventana de la casa de subastas.
S.alAbrirSubasta = function()
  local marco = AuctionHouseFrame or AuctionFrame
  if not marco then return end
  local b = S.botonSubasta
  if not b then
    b = boton(marco, T"Escanear", 90, function() S.escanear() end)
    local abrir = boton(b, T"Subastas", 90, Subastas_Toggle)
    abrir:SetPoint("LEFT", b, "RIGHT", 4, 0)
    b.estado = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.estado:SetPoint("RIGHT", b, "LEFT", -8, 0)
    b.estado:SetJustifyH("RIGHT")
    S.botonSubasta = b
  end
  b:SetParent(marco)
  b:ClearAllPoints()
  b:SetPoint("BOTTOMRIGHT", marco, "TOPRIGHT", -100, 2)
  b:Show()
  S.refrescarEstado()
end

SLASH_SUBASTAS1 = "/subastas"
SLASH_SUBASTAS2 = "/sub"
SlashCmdList.SUBASTAS = function(arg)
  arg = strlower(strtrim(arg or ""))
  if arg == "escanear" or arg == "scan" then
    S.escanear()
  elseif arg == "paginas" or arg == "páginas" or arg == "pages" then
    S.escanear("paginas")
  elseif arg:match("^dias %d+$") or arg:match("^days %d+$") then
    SubastasDB.opciones.dias = tonumber(arg:match("%d+"))
    S.msg(T"Se guardarán " .. SubastasDB.opciones.dias .. T" días de historial.")
  elseif arg == "boton" or arg == "botón" or arg == "button" then
    S.AlternarBoton()
  elseif arg == "borrar" or arg == "clear" then
    SubastasDB.reinos[S.claveReino()] = nil
    S.msg(T"Datos de " .. S.claveReino() .. T" borrados.")
  else
    Subastas_Toggle()
  end
end
