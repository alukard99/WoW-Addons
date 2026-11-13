-- RecetaSubasta: linkea al chat la receta seleccionada en la ventana de profesiones con sus
-- materiales, la cantidad de cada uno y su precio en la casa de subastas.
--
-- Con la casa de subastas abierta busca cada material y se queda con el precio de compra más
-- barato por unidad. Con ella cerrada usa el último precio que vio (o el de Auctionator).
--
-- El texto que se envía sale de una plantilla por canal (pestaña Canales): cada línea de la
-- plantilla es un mensaje de chat y los {marcadores} se sustituyen por los datos de la receta.
local NOMBRE = ...

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
local EnviarChat = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage

local ESPERA_RESPUESTA = 5 -- segundos sin respuesta antes de reintentar un material
local MAX_MENSAJE = 255 -- longitud máxima de un mensaje de chat

local PLANTILLA_DEFECTO = "--------------------\n{receta}\n{materiales}\nPrecio total: {total}"

local AYUDA = table.concat({
  "Cada línea es un mensaje de chat. Marcadores:",
  "|cffffd100{receta}|r enlace de la receta    |cffffd100{nombre}|r nombre sin enlace",
  "|cffffd100{objeto}|r enlace del objeto que se fabrica",
  "|cffffd100{materiales}|r todos seguidos: [material] x2, [material] x1",
  "|cffffd100{materiales_precio}|r igual, con el precio de cada uno",
  "|cffffd100{total_material}|r precio de los materiales    |cffffd100{tarifa}|r tarifa de encantador",
  "|cffffd100{total}|r materiales + tarifa",
  "Una línea con alguno de estos se repite por cada material:",
  "|cffffd100{material}|r enlace   |cffffd100{cantidad}|r   |cffffd100{precio}|r   |cffffd100{unidad}|r precio por unidad",
}, "\n")

local CANALES = {
  { tipo = "SAY", nombre = "Decir" },
  { tipo = "PARTY", nombre = "Grupo" },
  { tipo = "RAID", nombre = "Banda" },
  { tipo = "GUILD", nombre = "Hermandad" },
  { tipo = "WHISPER", nombre = "Susurro", destino = "Nombre del jugador" },
  { tipo = "CHANNEL", nombre = "Canal nº", destino = "Número del canal (p. ej. 2 = Comercio)" },
  { tipo = "YO", nombre = "Solo yo" },
}

local db
local recetaID
local subastaAbierta = false
local escaneo -- { cola = {itemID...}, i = índice, esperando, enviada, reintento }
local pendiente -- envío a medias, un mensaje por clic: { lineas, i, tipo, destino, receta }
local pestana = "receta"
local ventana, paginaReceta, paginaCanales, botonPestanaReceta, botonPestanaCanales
local textoLineas, textoEstado, botonCanal, campoDestino, botonActualizar, botonEnviar
local botonCanalPlantilla, cuadroPlantilla, plantillaMostrada
local botonEnviarCanales, textoEstadoCanales
local ultimoEnvio -- el último envío empezado, por si el juego bloquea un mensaje del temporizador
local PAUSA_ENVIO = 1 -- segundos entre un mensaje y el siguiente
local refrescar

local function msg(texto)
  print("|cff33ccffRecetaSubasta:|r " .. texto)
end

-- ------------------------------------------------------------------ utilidades
local function dinero(cobre)
  cobre = math.floor(cobre + 0.5)
  local o, p, c = math.floor(cobre / 10000), math.floor(cobre % 10000 / 100), cobre % 100
  local partes = {}
  if o > 0 then partes[#partes + 1] = o .. (GOLD_AMOUNT_SYMBOL or "o") end
  if p > 0 then partes[#partes + 1] = p .. (SILVER_AMOUNT_SYMBOL or "p") end
  if c > 0 or #partes == 0 then partes[#partes + 1] = c .. (COPPER_AMOUNT_SYMBOL or "c") end
  return table.concat(partes, " ")
end

local function precios()
  local clave = (GetRealmName() or "?") .. " - " .. (UnitFactionGroup("player") or "?")
  db.precios[clave] = db.precios[clave] or {}
  return db.precios[clave]
end

-- Precio por unidad en cobre; nil si no se conoce.
local function precio(itemID)
  local visto = precios()[itemID]
  if visto and visto.p > 0 then return visto.p end
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  if api and api.GetAuctionPriceByItemID then
    local ok, p = pcall(api.GetAuctionPriceByItemID, NOMBRE, itemID)
    if ok and type(p) == "number" and p > 0 then return p end
  end
  return nil
end

-- Materiales básicos de la receta ({ {id = itemID, n = cantidad}, ... }) y el objeto que produce.
local function materiales(id)
  local lista = {}
  local esquema = C_TradeSkillUI.GetRecipeSchematic(id, false)
  if not (esquema and esquema.reagentSlotSchematics) then return lista end
  local basico = Enum.CraftingReagentType and Enum.CraftingReagentType.Basic
  for _, hueco in ipairs(esquema.reagentSlotSchematics) do
    local primero = hueco.reagents and hueco.reagents[1]
    if (basico == nil or hueco.reagentType == basico) and primero and primero.itemID and primero.itemID > 0
      and (hueco.quantityRequired or 0) > 0 then
      lista[#lista + 1] = { id = primero.itemID, n = hueco.quantityRequired }
    end
  end
  return lista, esquema.outputItemID
end

local function nombreReceta(id)
  local info = C_TradeSkillUI.GetRecipeInfo(id)
  return info and info.name or ("receta " .. id)
end

local function enlaceReceta(id)
  local enlace = C_TradeSkillUI.GetRecipeLink and C_TradeSkillUI.GetRecipeLink(id)
  if not enlace and C_Spell and C_Spell.GetSpellLink then enlace = C_Spell.GetSpellLink(id) end
  return enlace or nombreReceta(id)
end

local function enlaceObjeto(itemID)
  local nombre, enlace = GetItemInfo(itemID)
  if enlace then return enlace end
  if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(itemID) end
  return "[" .. (nombre or ("objeto " .. itemID)) .. "]"
end

-- ------------------------------------------------------------------ plantillas
local function canalActual()
  for _, c in ipairs(CANALES) do
    if c.tipo == db.canal then return c end
  end
  return CANALES[1]
end

local function plantilla(tipo)
  return db.plantillas[tipo] or PLANTILLA_DEFECTO
end

local MARCADORES_MATERIAL = { "{material}", "{cantidad}", "{precio}", "{unidad}" }

local function esPorMaterial(linea)
  local l = linea:lower()
  for _, marcador in ipairs(MARCADORES_MATERIAL) do
    if l:find(marcador, 1, true) then return true end
  end
  return false
end

-- Sustituye los {marcadores}; los que no se conocen se dejan tal cual.
local function sustituir(linea, valores, extra)
  return (linea:gsub("{([%w_]+)}", function(clave)
    clave = clave:lower()
    return (extra and extra[clave]) or valores[clave]
  end))
end

-- Un mensaje de chat admite 255 caracteres y los enlaces ocupan mucho: una línea
-- demasiado larga se reparte en varios mensajes cortando por las comas.
local function anadir(lineas, linea)
  if strtrim(linea) == "" then return end
  if #linea <= MAX_MENSAJE then
    lineas[#lineas + 1] = linea
    return
  end
  local actual
  for parte in (linea .. ", "):gmatch("(.-), ") do
    if actual and #actual + 2 + #parte > MAX_MENSAJE then
      lineas[#lineas + 1] = actual
      actual = nil
    end
    actual = actual and (actual .. ", " .. parte) or parte
  end
  if actual then lineas[#lineas + 1] = actual end
end

-- Los mensajes tal cual se envían al canal `tipo`.
local function construirLineas(id, tipo)
  local lista, objetoID = materiales(id)
  local total, sinPrecio = 0, 0
  local juntos, juntosPrecio, porMaterial = {}, {}, {}
  for i, m in ipairs(lista) do
    local p = precio(m.id)
    local enlace = enlaceObjeto(m.id)
    if p then
      total = total + p * m.n
    else
      sinPrecio = sinPrecio + 1
    end
    juntos[i] = enlace .. " x" .. m.n
    juntosPrecio[i] = juntos[i] .. " (" .. (p and dinero(p * m.n) or "sin precio") .. ")"
    porMaterial[i] = {
      material = enlace,
      cantidad = tostring(m.n),
      precio = p and dinero(p * m.n) or "sin precio",
      unidad = p and dinero(p) or "sin precio",
    }
  end
  local tarifa = db.tarifa or 0
  local textoTotal, textoConTarifa = dinero(total), dinero(total + tarifa)
  if sinPrecio > 0 then
    local aviso = " (sin contar " .. sinPrecio .. " sin precio en subasta)"
    textoTotal, textoConTarifa = textoTotal .. aviso, textoConTarifa .. aviso
  end
  local valores = {
    receta = enlaceReceta(id),
    nombre = nombreReceta(id),
    objeto = objetoID and objetoID > 0 and enlaceObjeto(objetoID) or enlaceReceta(id),
    materiales = table.concat(juntos, ", "),
    materiales_precio = table.concat(juntosPrecio, ", "),
    total_material = textoTotal,
    tarifa = dinero(tarifa),
    total = textoConTarifa,
    total_con_tarifa = textoConTarifa, -- nombre antiguo de {total}
  }

  local lineas = {}
  for linea in (plantilla(tipo) .. "\n"):gmatch("(.-)\r?\n") do
    if esPorMaterial(linea) then
      for i = 1, #lista do anadir(lineas, sustituir(linea, valores, porMaterial[i])) end
    else
      anadir(lineas, sustituir(linea, valores))
    end
  end
  return lineas
end

-- ------------------------------------------------------------------ escaneo
local function estado(texto)
  if textoEstado then textoEstado:SetText(texto or "") end
  if textoEstadoCanales then textoEstadoCanales:SetText(texto or "") end
end

-- Precio de compra más bajo por unidad entre los resultados que ha devuelto el servidor.
local function leerResultados(itemID)
  local minimo
  local function anotar(p)
    if p and p > 0 and (not minimo or p < minimo) then minimo = p end
  end
  pcall(function()
    for i = 1, C_AuctionHouse.GetNumCommoditySearchResults(itemID) or 0 do
      local r = C_AuctionHouse.GetCommoditySearchResultInfo(itemID, i)
      if r then anotar(r.unitPrice) end
    end
  end)
  pcall(function()
    local clave = C_AuctionHouse.MakeItemKey(itemID)
    for i = 1, C_AuctionHouse.GetNumItemSearchResults(clave) or 0 do
      local r = C_AuctionHouse.GetItemSearchResultInfo(clave, i)
      if r and r.buyoutAmount then anotar(r.buyoutAmount / math.max(1, r.quantity or 1)) end
    end
  end)
  return minimo
end

local function siguiente(precioVisto)
  local e = escaneo
  precios()[e.cola[e.i]] = { p = precioVisto or 0, t = time() }
  e.i = e.i + 1
  e.esperando, e.reintento = false, false
  if e.i > #e.cola then
    escaneo = nil
    estado("Precios actualizados. Elige el canal y pulsa Enviar.")
  end
  refrescar()
end

local function alRecibir(itemID)
  local e = escaneo
  if e and e.esperando and e.cola[e.i] == itemID then
    siguiente(leerResultados(itemID))
  end
end

local function escanear()
  if not recetaID then return end
  if not subastaAbierta then
    estado("Abre la casa de subastas para actualizar los precios.")
    return
  end
  if not (C_AuctionHouse and C_AuctionHouse.SendSearchQuery) then
    estado("Este cliente no permite buscar en la subasta; se usan los precios guardados.")
    return
  end
  local cola = {}
  for _, m in ipairs(materiales(recetaID)) do cola[#cola + 1] = m.id end
  if #cola == 0 then return end
  escaneo = { cola = cola, i = 1 }
end

local motor = CreateFrame("Frame")
motor:SetScript("OnUpdate", function()
  local e = escaneo
  if not e then return end
  local itemID = e.cola[e.i]
  if e.esperando then
    if GetTime() - e.enviada > ESPERA_RESPUESTA then
      if e.reintento then
        siguiente(leerResultados(itemID)) -- sin respuesta: se queda sin precio
      else
        e.esperando, e.reintento = false, true
      end
    end
    return
  end
  if C_AuctionHouse.IsThrottledMessageSystemReady and not C_AuctionHouse.IsThrottledMessageSystemReady() then
    return
  end
  estado(string.format("Buscando precios en la subasta... %d / %d", e.i, #e.cola))
  local orden = {}
  if Enum.AuctionHouseSortOrder and Enum.AuctionHouseSortOrder.Price then
    orden[1] = { sortOrder = Enum.AuctionHouseSortOrder.Price, reverseSort = false }
  end
  e.esperando, e.enviada = true, GetTime()
  local ok = pcall(C_AuctionHouse.SendSearchQuery, C_AuctionHouse.MakeItemKey(itemID), orden, false)
  if not ok then siguiente(nil) end
end)

-- ------------------------------------------------------------------ ventana
local function textoEnviar(texto)
  if botonEnviar then botonEnviar:SetText(texto) end
  if botonEnviarCanales then botonEnviarCanales:SetText(texto) end
end

local function descartarPendiente()
  pendiente = nil
  textoEnviar("Enviar")
end

-- Lo que se envía de verdad: si todo cabe en un solo mensaje de chat, va junto
-- (sin las líneas que son solo un separador); si no, un mensaje por línea.
local function mensajes(id, tipo)
  local lineas = construirLineas(id, tipo)
  local utiles = {}
  for _, linea in ipairs(lineas) do
    if linea:find("%w") then utiles[#utiles + 1] = linea end
  end
  local junto = table.concat(utiles, " - ")
  if #utiles > 0 and #junto <= MAX_MENSAJE then return { junto } end
  return lineas
end

-- Tras enviar un mensaje: el siguiente sale solo al cabo de PAUSA_ENVIO segundos. Si el juego
-- bloquea los envíos desde un temporizador (evento ADDON_ACTION_BLOCKED, más abajo), se
-- recuerda y a partir de entonces cada mensaje restante necesita su propio clic en Enviar.
local function avanzar(p)
  p.i = p.i + 1
  if p.i > #p.lineas then
    descartarPendiente()
    estado(p.hecho)
    return
  end
  if db.temporizadorBloqueado then
    p.auto = false
    textoEnviar(string.format("Enviar %d/%d", p.i, #p.lineas))
    estado("Pulsa Enviar otra vez para el siguiente mensaje (el juego solo admite uno por clic).")
    return
  end
  p.auto = true
  estado(string.format("Enviando... %d / %d", p.i - 1, #p.lineas))
  C_Timer.After(PAUSA_ENVIO, function()
    if pendiente ~= p or not p.auto then return end
    p.intentando = p.i
    EnviarChat(p.lineas[p.i], p.tipo, nil, p.destino)
    if p.auto then avanzar(p) end
  end)
end

local function alBloquearEnvio()
  local p = ultimoEnvio
  if not (p and p.intentando) then return end
  db.temporizadorBloqueado = true
  p.i, p.intentando, p.auto = p.intentando, nil, false
  pendiente = p
  textoEnviar(string.format("Enviar %d/%d", p.i, #p.lineas))
  estado("El juego no deja enviar mensajes con temporizador: pulsa Enviar para cada mensaje restante.")
end

local function siguienteCanal()
  local actual = canalActual()
  for i, c in ipairs(CANALES) do
    if c == actual then
      db.canal = CANALES[i % #CANALES + 1].tipo
      break
    end
  end
  refrescar()
end

refrescar = function()
  if not (ventana and ventana:IsShown()) then return end
  local canal = canalActual()
  -- Si cambia la receta o el canal, el envío a medias se descarta y se empieza de nuevo.
  if pendiente and (pendiente.receta ~= recetaID or pendiente.tipo ~= canal.tipo) then
    descartarPendiente()
  end

  paginaReceta:SetShown(pestana == "receta")
  paginaCanales:SetShown(pestana == "canales")
  botonPestanaReceta:SetEnabled(pestana ~= "receta")
  botonPestanaCanales:SetEnabled(pestana ~= "canales")

  if pestana == "canales" then
    botonCanalPlantilla:SetText("Canal: " .. canal.nombre)
    -- El cuadro solo se rellena al cambiar de canal, para no mover el cursor mientras se escribe.
    if plantillaMostrada ~= canal.tipo then
      plantillaMostrada = canal.tipo
      cuadroPlantilla:SetText(plantilla(canal.tipo))
    end
    ventana:SetHeight(470)
    return
  end

  botonCanal:SetText("Canal: " .. canal.nombre)
  campoDestino:SetShown(canal.destino ~= nil)
  if not campoDestino:HasFocus() then campoDestino:SetText(db.destinos[canal.tipo] or "") end
  botonActualizar:SetEnabled(subastaAbierta and not escaneo)
  if not recetaID then
    textoLineas:SetText("Abre una profesión y selecciona una receta.")
  else
    textoLineas:SetText(table.concat(mensajes(recetaID, canal.tipo), "\n"))
  end
  ventana:SetHeight(150 + textoLineas:GetStringHeight())
end

local function enviar()
  if not recetaID then
    estado("No hay ninguna receta seleccionada.")
    return
  end
  local canal = canalActual()
  local destino
  if canal.tipo == "WHISPER" then
    destino = strtrim(db.destinos.WHISPER or "")
    if destino == "" then
      estado("Escribe el nombre del jugador al que susurrar (pestaña Receta, junto al canal).")
      return
    end
  elseif canal.tipo == "CHANNEL" then
    destino = tonumber(db.destinos.CHANNEL)
    if not destino then
      estado("Escribe el número del canal, p. ej. 2 para Comercio (pestaña Receta, junto al canal).")
      return
    end
  end
  local hecho = "Enviado a " .. canal.nombre .. (destino and (" " .. destino) or "") .. "."

  if canal.tipo == "YO" then
    for _, linea in ipairs(mensajes(recetaID, canal.tipo)) do print(linea) end
    estado(hecho)
    return
  end

  local p = pendiente
  if p and p.auto then return end -- ya se está enviando solo
  if not (p and p.tipo == canal.tipo and p.destino == destino and p.receta == recetaID) then
    local lineas = mensajes(recetaID, canal.tipo)
    if #lineas == 0 then
      estado("La plantilla de este canal está vacía (pestaña Canales).")
      return
    end
    p = { lineas = lineas, i = 1, tipo = canal.tipo, destino = destino, receta = recetaID, hecho = hecho }
    pendiente = p
  end
  p.intentando = nil
  ultimoEnvio = p
  EnviarChat(p.lineas[p.i], p.tipo, nil, p.destino)
  avanzar(p)
end

local function boton(padre, texto, ancho, alPulsar)
  local b = CreateFrame("Button", nil, padre, "UIPanelButtonTemplate")
  b:SetSize(ancho, 22)
  b:SetText(texto)
  b:SetScript("OnClick", alPulsar)
  return b
end

local function cambiarPestana(nueva)
  pestana = nueva
  plantillaMostrada = nil
  if cuadroPlantilla then cuadroPlantilla:ClearFocus() end
  refrescar()
end

local function crearPaginaReceta(f)
  local pag = CreateFrame("Frame", nil, f)
  pag:SetPoint("TOPLEFT", 0, -56)
  pag:SetPoint("BOTTOMRIGHT")

  textoLineas = pag:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  textoLineas:SetPoint("TOPLEFT", 14, -6)
  textoLineas:SetPoint("RIGHT", -14, 0)
  textoLineas:SetJustifyH("LEFT")
  textoLineas:SetSpacing(3)

  botonCanal = boton(pag, "", 130, siguienteCanal)
  botonCanal:SetPoint("BOTTOMLEFT", 12, 12)

  campoDestino = CreateFrame("EditBox", nil, pag, "InputBoxTemplate")
  campoDestino:SetSize(90, 20)
  campoDestino:SetPoint("LEFT", botonCanal, "RIGHT", 10, 0)
  campoDestino:SetAutoFocus(false)
  campoDestino:SetScript("OnEnterPressed", campoDestino.ClearFocus)
  campoDestino:SetScript("OnEscapePressed", campoDestino.ClearFocus)
  campoDestino:SetScript("OnTextChanged", function(self, delUsuario)
    if delUsuario then db.destinos[canalActual().tipo] = self:GetText() end
  end)
  campoDestino:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText(canalActual().destino or "")
    GameTooltip:Show()
  end)
  campoDestino:SetScript("OnLeave", function() GameTooltip:Hide() end)

  botonEnviar = boton(pag, "Enviar", 90, enviar)
  botonEnviar:SetPoint("BOTTOMRIGHT", -12, 12)
  botonActualizar = boton(pag, "Actualizar precios", 130, function()
    escanear()
    refrescar()
  end)
  botonActualizar:SetPoint("RIGHT", botonEnviar, "LEFT", -6, 0)

  textoEstado = pag:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  textoEstado:SetPoint("BOTTOMLEFT", 14, 42)
  textoEstado:SetPoint("RIGHT", -14, 0)
  textoEstado:SetJustifyH("LEFT")

  paginaReceta = pag
end

local function crearPaginaCanales(f)
  local pag = CreateFrame("Frame", nil, f)
  pag:SetPoint("TOPLEFT", 0, -56)
  pag:SetPoint("BOTTOMRIGHT")

  botonCanalPlantilla = boton(pag, "", 130, siguienteCanal)
  botonCanalPlantilla:SetPoint("TOPLEFT", 12, -4)

  local restaurar = boton(pag, "Restaurar", 90, function()
    local tipo = canalActual().tipo
    db.plantillas[tipo] = nil
    plantillaMostrada = nil
    descartarPendiente()
    refrescar()
  end)
  restaurar:SetPoint("LEFT", botonCanalPlantilla, "RIGHT", 6, 0)

  botonEnviarCanales = boton(pag, "Enviar", 90, function() enviar() end)
  botonEnviarCanales:SetPoint("TOPRIGHT", -12, -4)

  textoEstadoCanales = pag:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  textoEstadoCanales:SetPoint("BOTTOMLEFT", 14, 12)
  textoEstadoCanales:SetPoint("RIGHT", -14, 0)
  textoEstadoCanales:SetJustifyH("LEFT")

  local fondo = CreateFrame("Frame", nil, pag)
  fondo:SetPoint("TOPLEFT", 14, -34)
  fondo:SetPoint("RIGHT", -14, 0)
  fondo:SetHeight(120)
  local textura = fondo:CreateTexture(nil, "BACKGROUND")
  textura:SetAllPoints()
  textura:SetColorTexture(0, 0, 0, 0.5)

  cuadroPlantilla = CreateFrame("EditBox", nil, fondo)
  cuadroPlantilla:SetMultiLine(true)
  cuadroPlantilla:SetMaxLetters(0)
  cuadroPlantilla:SetAutoFocus(false)
  cuadroPlantilla:SetFontObject(ChatFontNormal)
  cuadroPlantilla:SetPoint("TOPLEFT", 6, -6)
  cuadroPlantilla:SetPoint("BOTTOMRIGHT", -6, 6)
  cuadroPlantilla:SetScript("OnEscapePressed", cuadroPlantilla.ClearFocus)
  cuadroPlantilla:SetScript("OnTextChanged", function(self, delUsuario)
    if not delUsuario then return end
    local texto = self:GetText()
    db.plantillas[canalActual().tipo] = texto ~= PLANTILLA_DEFECTO and texto or nil
    descartarPendiente()
  end)
  fondo:EnableMouse(true)
  fondo:SetScript("OnMouseDown", function() cuadroPlantilla:SetFocus() end)

  -- Tarifa de encantador: valor del marcador {tarifa}, en oro, plata y cobre.
  local etiquetaTarifa = pag:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  etiquetaTarifa:SetPoint("TOPLEFT", fondo, "BOTTOMLEFT", 0, -14)
  etiquetaTarifa:SetText("Tarifa de encantador |cffffd100{tarifa}|r:")

  local camposTarifa = {}
  local function guardarTarifa()
    local function valor(campo) return tonumber(campo:GetText()) or 0 end
    db.tarifa = valor(camposTarifa[1]) * 10000 + valor(camposTarifa[2]) * 100 + valor(camposTarifa[3])
    descartarPendiente()
  end
  local tarifa = db.tarifa or 0
  local partes = {
    { nombre = "oro", ancho = 60, letras = 6, valor = math.floor(tarifa / 10000) },
    { nombre = "plata", ancho = 32, letras = 2, valor = math.floor(tarifa % 10000 / 100) },
    { nombre = "cobre", ancho = 32, letras = 2, valor = tarifa % 100 },
  }
  local anterior = etiquetaTarifa
  for i, parte in ipairs(partes) do
    local campo = CreateFrame("EditBox", nil, pag, "InputBoxTemplate")
    campo:SetSize(parte.ancho, 20)
    campo:SetPoint("LEFT", anterior, "RIGHT", 14, 0)
    campo:SetAutoFocus(false)
    campo:SetNumeric(true)
    campo:SetMaxLetters(parte.letras)
    campo:SetText(parte.valor > 0 and tostring(parte.valor) or "")
    campo:SetScript("OnEnterPressed", campo.ClearFocus)
    campo:SetScript("OnEscapePressed", campo.ClearFocus)
    campo:SetScript("OnTextChanged", function(_, delUsuario)
      if delUsuario then guardarTarifa() end
    end)
    local etiqueta = pag:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    etiqueta:SetPoint("LEFT", campo, "RIGHT", 4, 0)
    etiqueta:SetText(parte.nombre)
    camposTarifa[i] = campo
    anterior = etiqueta
  end

  local ayuda = pag:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  ayuda:SetPoint("TOPLEFT", fondo, "BOTTOMLEFT", 0, -44)
  ayuda:SetPoint("RIGHT", -14, 0)
  ayuda:SetJustifyH("LEFT")
  ayuda:SetSpacing(4)
  ayuda:SetText(AYUDA)

  paginaCanales = pag
end

local function crearVentana()
  local f = CreateFrame("Frame", "RecetaSubastaVentana", UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(480, 200)
  f:SetPoint("CENTER", 0, 120)
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)
  f:Hide()
  tinsert(UISpecialFrames, "RecetaSubastaVentana")

  local titulo = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  titulo:SetPoint("TOP", 0, -5)
  titulo:SetText("Receta con precios de subasta")

  -- Pestañas: la activa queda desactivada (en gris) para que se vea cuál es.
  botonPestanaReceta = boton(f, "Receta", 90, function() cambiarPestana("receta") end)
  botonPestanaReceta:SetPoint("TOPLEFT", 12, -30)
  botonPestanaCanales = boton(f, "Canales", 90, function() cambiarPestana("canales") end)
  botonPestanaCanales:SetPoint("LEFT", botonPestanaReceta, "RIGHT", 4, 0)

  crearPaginaReceta(f)
  crearPaginaCanales(f)
  ventana = f
end

local function recetaSeleccionada()
  local pagina = ProfessionsFrame and ProfessionsFrame.CraftingPage
  local form = pagina and pagina.SchematicForm
  local info = form and form.GetRecipeInfo and form:GetRecipeInfo()
  return info and info.recipeID
end

local function mostrar()
  if not ventana then crearVentana() end
  recetaID = recetaSeleccionada() or recetaID
  pestana = "receta"
  ventana:Show()
  if not recetaID then
    estado("")
  elseif subastaAbierta then
    escanear()
  else
    estado("Precios guardados. Abre la casa de subastas para actualizarlos.")
  end
  refrescar()
end

local function alternar()
  if ventana and ventana:IsShown() then
    ventana:Hide()
  else
    mostrar()
  end
end

-- Botón encima de la ventana de profesiones.
local botonProfesiones
local function engancharProfesiones()
  if botonProfesiones or not ProfessionsFrame then return end
  botonProfesiones = boton(ProfessionsFrame, "Linkear con precios", 150, mostrar)
  botonProfesiones:SetPoint("BOTTOMRIGHT", ProfessionsFrame, "TOPRIGHT", -30, 2)
  if EventRegistry then
    EventRegistry:RegisterCallback("ProfessionsRecipeListMixin.Event.OnRecipeSelected", function(_, info)
      local id = info and info.recipeID
      if not id or id == recetaID then return end
      recetaID = id
      if ventana and ventana:IsShown() then
        escaneo = nil
        if subastaAbierta then
          escanear()
        else
          estado("Precios guardados. Abre la casa de subastas para actualizarlos.")
        end
        refrescar()
      end
    end, botonProfesiones)
  end
end

-- ------------------------------------------------------------------ eventos
local eventos = CreateFrame("Frame")
for _, nombre in ipairs({
  "ADDON_LOADED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED", "GET_ITEM_INFO_RECEIVED",
  "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED", "ADDON_ACTION_BLOCKED",
  "ADDON_ACTION_FORBIDDEN",
}) do
  pcall(eventos.RegisterEvent, eventos, nombre) -- no todos existen en todas las versiones
end

eventos:SetScript("OnEvent", function(_, evento, arg)
  if evento == "ADDON_LOADED" then
    if arg == NOMBRE then
      RecetaSubastaDB = RecetaSubastaDB or {}
      db = RecetaSubastaDB
      db.precios = db.precios or {}
      db.destinos = db.destinos or {}
      db.plantillas = db.plantillas or {}
      db.canal = db.canal or "SAY"
      engancharProfesiones()
    elseif arg == "Blizzard_Professions" then
      engancharProfesiones()
    end
  elseif evento == "AUCTION_HOUSE_SHOW" then
    subastaAbierta = true
    if ventana and ventana:IsShown() and recetaID then escanear() end
    refrescar()
  elseif evento == "AUCTION_HOUSE_CLOSED" then
    subastaAbierta = false
    if escaneo then
      escaneo = nil
      estado("Búsqueda cancelada: se ha cerrado la casa de subastas.")
    end
    refrescar()
  elseif evento == "COMMODITY_SEARCH_RESULTS_UPDATED" then
    alRecibir(arg)
  elseif evento == "ITEM_SEARCH_RESULTS_UPDATED" then
    alRecibir(type(arg) == "table" and arg.itemID or arg)
  elseif evento == "ADDON_ACTION_BLOCKED" or evento == "ADDON_ACTION_FORBIDDEN" then
    if arg == NOMBRE then alBloquearEnvio() end
  elseif evento == "GET_ITEM_INFO_RECEIVED" then
    refrescar() -- ha llegado el enlace de algún material
  end
end)

SLASH_RECETASUBASTA1 = "/receta"
SLASH_RECETASUBASTA2 = "/recetasubasta"
SlashCmdList.RECETASUBASTA = function()
  if not db then return end
  if not recetaID and not recetaSeleccionada() then
    msg("Abre una profesión y selecciona una receta.")
  end
  alternar()
end
