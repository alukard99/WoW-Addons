-- Escaneo de la casa de subastas. Hay tres formas, según lo que permita el cliente:
--   "moderno":  C_AuctionHouse.ReplicateItems (cliente moderno; lista completa, cada 15 min)
--   "todo":     QueryAuctionItems con getAll (cliente clásico; lista completa, cada 15 min)
--   "paginas":  QueryAuctionItems página a página (clásico; lento pero siempre funciona)
local _, S = ...
local T = S.T -- traducción (Locale.lua)

local POR_PAGINA = NUM_AUCTION_ITEMS_PER_PAGE or 50
local ESPERA_COMPLETO = 15 * 60

S.escaneo = nil
S.subastaAbierta = false

local function estado(texto)
  S.textoEstado = texto
  if S.refrescarEstado then S.refrescarEstado() end
end
S.estado = estado

local function hayModerno()
  return C_AuctionHouse and C_AuctionHouse.ReplicateItems and C_AuctionHouse.GetNumReplicateItems
end

local function hayClasico()
  return QueryAuctionItems and GetAuctionItemInfo and GetNumAuctionItems
end

-- ---------------------------------------------------------------- acumular
local function nuevoAcumulador()
  return { items = {}, leidas = 0 }
end

local function anotar(acc, itemID, nombre, calidad, cantidad, compraYa, vendedor)
  if not itemID or itemID == 0 then return end
  acc.leidas = acc.leidas + 1
  local it = acc.items[itemID]
  if not it then
    it = { l = {}, vend = {}, nv = 0, subastas = 0, cantidad = 0 }
    acc.items[itemID] = it
  end
  if nombre and nombre ~= "" then it.n = nombre end
  if calidad and calidad >= 0 then it.q = calidad end
  cantidad = (cantidad and cantidad > 0) and cantidad or 1
  it.subastas = it.subastas + 1
  it.cantidad = it.cantidad + cantidad
  if vendedor and vendedor ~= "" and not it.vend[vendedor] then
    it.vend[vendedor] = true
    it.nv = it.nv + 1
  end
  if compraYa and compraYa > 0 then
    it.l[#it.l + 1] = { compraYa / cantidad, cantidad }
  end
end

-- Percentil ponderado por cantidad (la lista ya está ordenada por precio unitario).
local function percentil(l, total, p)
  local objetivo, acum = total * p, 0
  for i = 1, #l do
    acum = acum + l[i][2]
    if acum >= objetivo then return l[i][1] end
  end
  return l[#l][1]
end

local function redondo(x) return math.floor(x + 0.5) end
local function porPrecio(a, b) return a[1] < b[1] end

local function guardar(acc, modo)
  local r = S.reino()
  local dia = S.hoy()
  local distintos = 0
  estado(T"Guardando resultados...")
  for id, it in pairs(acc.items) do
    distintos = distintos + 1
    local l, rec = it.l, nil
    if #l > 0 then
      table.sort(l, porPrecio)
      local total = 0
      for i = 1, #l do total = total + l[i][2] end
      -- Los 3 precios más bajos con la cantidad que hay a cada precio.
      local partes, i = {}, 1
      while i <= #l and #partes < 3 do
        local p, c = l[i][1], 0
        while i <= #l and l[i][1] == p do
          c = c + l[i][2]
          i = i + 1
        end
        partes[#partes + 1] = redondo(p) .. ":" .. c
      end
      rec = string.format("%d,%d,%d,%d,%d,%d,%s", redondo(l[1][1]), redondo(percentil(l, total, 0.25)),
        redondo(percentil(l, total, 0.5)), it.cantidad, it.subastas, it.nv, table.concat(partes, " "))
    else
      rec = string.format("0,0,0,%d,%d,%d,", it.cantidad, it.subastas, it.nv)
    end
    local g = r.items[id]
    if not g then
      g = { h = {} }
      r.items[id] = g
    end
    if it.n then g.n = it.n end
    if it.q then g.q = it.q end
    g.h[dia] = rec
    S.ceder()
  end

  -- Borrar historial viejo.
  local limite = dia - (SubastasDB.opciones.dias or 14)
  for id, g in pairs(r.items) do
    for d in pairs(g.h) do
      if d <= limite then g.h[d] = nil end
    end
    if not next(g.h) then r.items[id] = nil end
    S.ceder()
  end

  r.ultimoDia = dia
  r.ultimo = { t = time(), leidas = acc.leidas, distintos = distintos, modo = modo }
  S.escaneo = nil
  local texto = string.format(T"Escaneo terminado: %d subastas, %d objetos distintos.", acc.leidas, distintos)
  estado(texto)
  S.msg(texto .. T" Pulsa Exportar en /subastas.")
  if S.alTerminarEscaneo then S.alTerminarEscaneo() end
end

local function fallo(err)
  S.escaneo = nil
  estado(T"Error al escanear: " .. tostring(err))
end

-- ---------------------------------------------------------------- moderno
local function leerModerno()
  local e = S.escaneo
  e.leyendo = true
  local acc = e.acc
  S.tarea(function()
    local n = C_AuctionHouse.GetNumReplicateItems()
    for i = 0, n - 1 do
      local nombre, _, cantidad, calidad, _, _, _, _, _, compraYa, _, _, _, vendedor, vendedorCompleto, _, itemID,
        completo = C_AuctionHouse.GetReplicateItemInfo(i)
      anotar(acc, itemID, completo and nombre, calidad, cantidad, compraYa, vendedor or vendedorCompleto)
      if i % 500 == 0 then estado(string.format(T"Leyendo subastas... %d / %d", i, n)) end
      S.ceder()
    end
    guardar(acc, "moderno")
  end, fallo)
end

S.alEvento("REPLICATE_ITEM_LIST_UPDATE", function()
  local e = S.escaneo
  if e and e.modo == "moderno" and not e.leyendo then leerModerno() end
end)

-- ---------------------------------------------------------------- clásico
local function leerTodo()
  local e = S.escaneo
  e.leyendo = true
  local acc = e.acc
  S.tarea(function()
    local n = GetNumAuctionItems("list")
    for i = 1, n do
      local nombre, _, cantidad, calidad, _, _, _, _, _, compraYa, _, _, _, vendedor, vendedorCompleto, _, itemID =
        GetAuctionItemInfo("list", i)
      anotar(acc, itemID, nombre, calidad, cantidad, compraYa, vendedor or vendedorCompleto)
      if i % 500 == 0 then estado(string.format(T"Leyendo subastas... %d / %d", i, n)) end
      S.ceder()
    end
    guardar(acc, "todo")
  end, fallo)
end

local function pedirPagina()
  local e = S.escaneo
  e.esperando = true
  e.enviada = GetTime()
  e.ultimoEvento = nil
  QueryAuctionItems("", nil, nil, e.pagina, false, nil, false, false, nil)
end

local function leerPagina()
  local e = S.escaneo
  e.esperando = false
  local n, total = GetNumAuctionItems("list")
  for i = 1, n do
    local nombre, _, cantidad, calidad, _, _, _, _, _, compraYa, _, _, _, vendedor, vendedorCompleto, _, itemID =
      GetAuctionItemInfo("list", i)
    anotar(e.acc, itemID, nombre, calidad, cantidad, compraYa, vendedor or vendedorCompleto)
  end
  e.pagina = e.pagina + 1
  local paginas = math.max(1, math.ceil((total or 0) / POR_PAGINA))
  estado(string.format(T"Escaneando páginas... %d / %d", e.pagina, paginas))
  if e.pagina >= paginas or n == 0 then
    e.leyendo = true
    S.tarea(function() guardar(e.acc, "paginas") end, fallo)
  end
end

S.alEvento("AUCTION_ITEM_LIST_UPDATE", function()
  local e = S.escaneo
  if not e or e.leyendo then return end
  if e.modo == "todo" then
    leerTodo()
  elseif e.modo == "paginas" and e.esperando then
    -- El evento puede llegar varias veces seguidas mientras se cargan los datos:
    -- se lee la página cuando lleva un momento sin llegar.
    e.ultimoEvento = GetTime()
  end
end)

S.cadaFotograma(function()
  local e = S.escaneo
  if not e or e.leyendo then return end
  local ahora = GetTime()
  if e.modo == "paginas" then
    if e.esperando then
      if e.ultimoEvento and (ahora - e.ultimoEvento > 0.3 or ahora - e.enviada > 3) then
        leerPagina()
      elseif ahora - e.enviada > 20 then
        e.esperando = false -- sin respuesta: se vuelve a pedir la misma página
      end
    elseif CanSendAuctionQuery() then
      pedirPagina()
    end
  elseif ahora - e.inicio > 90 then
    S.escaneo = nil
    estado(T"El servidor no ha enviado la lista. El escaneo completo solo se puede hacer cada 15 minutos; "
      .. T"prueba más tarde o usa /subastas paginas.")
  end
end)

-- ---------------------------------------------------------------- arrancar
function S.escanear(forzarModo)
  if not S.subastaAbierta then
    estado(T"Abre la casa de subastas para escanear.")
    return
  end
  if S.escaneo or S.ocupado() then
    estado(T"Ya hay un escaneo en marcha.")
    return
  end

  local r = S.reino()
  local modo = forzarModo
  if not modo then
    if hayModerno() then
      modo = "moderno"
    elseif hayClasico() then
      local _, puedeTodo = CanSendAuctionQuery()
      modo = puedeTodo and "todo" or "paginas"
    end
  end
  if not modo or (modo == "moderno" and not hayModerno()) or (modo ~= "moderno" and not hayClasico()) then
    estado(T"Este cliente no tiene una API de subastas conocida.")
    return
  end

  if modo ~= "paginas" and r.ultimoCompleto and time() - r.ultimoCompleto < ESPERA_COMPLETO then
    local faltan = ESPERA_COMPLETO - (time() - r.ultimoCompleto)
    estado(string.format(T"El escaneo completo vuelve a estar disponible en %d min. "
      .. T"Mientras, puedes usar /subastas paginas.", math.ceil(faltan / 60)))
    return
  end

  S.escaneo = { modo = modo, acc = nuevoAcumulador(), inicio = GetTime(), pagina = 0 }
  if modo == "moderno" then
    r.ultimoCompleto = time()
    estado(T"Pidiendo la lista completa al servidor (puede tardar un poco)...")
    C_AuctionHouse.ReplicateItems()
  elseif modo == "todo" then
    r.ultimoCompleto = time()
    estado(T"Pidiendo la lista completa al servidor (el juego puede congelarse unos segundos)...")
    QueryAuctionItems("", nil, nil, 0, false, nil, true, false, nil)
  else
    estado(T"Escaneando página a página...")
  end
end

S.alEvento("AUCTION_HOUSE_SHOW", function()
  S.subastaAbierta = true
  if S.alAbrirSubasta then S.alAbrirSubasta() end
end)

S.alEvento("AUCTION_HOUSE_CLOSED", function()
  S.subastaAbierta = false
  local e = S.escaneo
  if e and not e.leyendo then
    S.escaneo = nil
    estado(T"Escaneo cancelado: se ha cerrado la casa de subastas.")
  end
end)
