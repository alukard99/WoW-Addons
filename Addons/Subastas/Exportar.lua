-- Convierte el último escaneo y el historial en texto para pegarlo en una IA.
local _, S = ...

local CALIDADES = { [0] = "gris", "blanco", "verde", "azul", "morado", "naranja", "artefacto", "reliquia" }

S.ORDENES = {
  { clave = "volumen", nombre = "Volumen" },
  { clave = "baratos", nombre = "Más baratos" },
  { clave = "caros", nombre = "Más caros" },
}

local INSTRUCCIONES = [[
Eres un analista experto de la casa de subastas de World of Warcraft: Forever.
Abajo tienes un volcado de la casa de subastas de mi reino. Analízalo y dime, con nombres de objetos y cifras:
1. Reventa: qué objetos me conviene comprar ahora para revenderlos más caros. Para cada uno: cuántas unidades
   comprar, a qué precio máximo, a qué precio ponerlos a la venta y la ganancia esperada tras la comisión.
2. Qué objetos están ahora por debajo de su precio habitual (comparando el mínimo con el histórico).
3. Qué objetos están por encima de su precio habitual (buenos para vender si los tengo).
4. Objetos que se venden al vendedor NPC por más de lo que cuestan en subasta (comprar y vender al NPC).
5. Riesgos: poca cantidad o pocos vendedores, pocos días de historial, posibles manipulaciones de precio,
   mercados lentos donde costaría vender.
Ten en cuenta que la casa de subastas se queda un 5% de comisión al vender (15% en la neutral) y que poner
algo a la venta cuesta un depósito que se pierde si no se vende. No me recomiendes gastar más oro del que tengo.

Formato de los datos: una línea por objeto, campos separados por ";". Precios en oro por unidad.
id = ID del objeto | calidad | tipo/subtipo | nv = nivel de objeto
subastas = número de subastas | cantidad = unidades a la venta | vendedores = vendedores distintos
min / p25 / mediana = precio de compra inmediata más bajo, percentil 25 y mediana (ponderados por unidades)
hist_p25 = mediana del p25 diario de los días anteriores | dias_hist = días con datos | cant_hist = cantidad media
npc = precio de venta al vendedor NPC | desv_% = cuánto se aleja el mínimo actual del hist_p25
primeros = los tres precios más bajos con las unidades que hay a cada uno (precio x unidades)
Vacío = sin datos.
]]

local function mediana(l)
  if #l == 0 then return nil end
  table.sort(l)
  local m = math.floor((#l + 1) / 2)
  if #l % 2 == 1 then return l[m] end
  return (l[m] + l[m + 1]) / 2
end

local function limpiar(t)
  return (tostring(t or ""):gsub("[;\r\n]", ","))
end

function S.exportar()
  local r = S.reino()
  local o = SubastasDB.opciones
  if not r.ultimoDia then
    return nil, "Todavía no hay datos. Abre la casa de subastas y pulsa Escanear."
  end

  local filas, faltanNombres = {}, 0
  for id, g in pairs(r.items) do
    local rec = g.h[r.ultimoDia]
    if rec then
      local min, p25, med, cant, sub, vend, prim = S.leerRegistro(rec)
      if cant >= (o.minCantidad or 1) then
        local hist, cants = {}, 0
        for d, s in pairs(g.h) do
          if d ~= r.ultimoDia then
            local _, hp25, _, hc = S.leerRegistro(s)
            if hp25 > 0 then
              hist[#hist + 1] = hp25
              cants = cants + hc
            end
          end
        end
        local dias = #hist
        local histP25 = mediana(hist)

        -- La información del objeto solo está si el juego la tiene en caché; si no, GetItemInfo
        -- la pide al servidor y devuelve nil. Se guarda en la base de datos para no depender de la caché.
        local nombre, _, calidad, nivel, _, tipo, subtipo, _, _, _, npc = S.GetItemInfo(id)
        if nombre then
          g.n, g.q, g.lv, g.t, g.st, g.v = nombre, calidad, nivel, tipo, subtipo, npc
        elseif not g.t then
          faltanNombres = faltanNombres + 1
          if C_Item and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(id) end
        end
        calidad = calidad or g.q
        nivel = nivel or g.lv
        tipo = tipo or g.t
        subtipo = subtipo or g.st
        npc = npc or g.v

        local desv
        if histP25 and histP25 > 0 and min > 0 then desv = (min / histP25 - 1) * 100 end

        local primeros = {}
        for p, c in prim:gmatch("(%d+):(%d+)") do
          primeros[#primeros + 1] = S.oro(p) .. "x" .. c
        end

        filas[#filas + 1] = {
          desv = desv,
          volumen = (p25 > 0 and p25 or med) * cant,
          texto = table.concat({
            id, limpiar(g.n or ("item:" .. id)), CALIDADES[calidad or -1] or "",
            limpiar(tipo) .. (subtipo and subtipo ~= tipo and ("/" .. limpiar(subtipo)) or ""),
            (nivel and nivel > 1) and nivel or "",
            -- 0 vendedores = el servidor no envió el nombre del vendedor (normal en el escaneo completo).
            sub, cant, vend > 0 and vend or "", S.oro(min), S.oro(p25), S.oro(med),
            histP25 and S.oro(histP25) or "", dias, dias > 0 and math.floor(cants / dias + 0.5) or "",
            S.oro(npc), desv and string.format("%+.0f", desv) or "", table.concat(primeros, " "),
          }, ";"),
        }
      end
    end
  end

  local orden = o.orden
  table.sort(filas, function(a, b)
    if orden ~= "volumen" then
      -- Los que tienen historial primero, ordenados por desviación.
      if (a.desv ~= nil) ~= (b.desv ~= nil) then return a.desv ~= nil end
      if a.desv and a.desv ~= b.desv then
        if orden == "baratos" then return a.desv < b.desv end
        return a.desv > b.desv
      end
    end
    return a.volumen > b.volumen
  end)

  local total = #filas
  local limite = math.min(total, o.lineas or 1500)
  local u = r.ultimo or {}
  local lineas = {
    INSTRUCCIONES,
    "### DATOS",
    string.format("Reino: %s | Escaneo: %s | Subastas leídas: %d | Objetos: %d (se incluyen %d, orden: %s)",
      S.claveReino(), date("%Y-%m-%d %H:%M", u.t or time()), u.leidas or 0, total, limite, orden),
    "Mi oro: " .. S.oro(GetMoney()),
    "id;nombre;calidad;tipo;nv;subastas;cantidad;vendedores;min;p25;mediana;hist_p25;dias_hist;cant_hist;npc;desv_%;primeros",
  }
  for i = 1, limite do lineas[#lineas + 1] = filas[i].texto end

  local aviso
  if faltanNombres > 0 then
    aviso = string.format("Faltan datos de %d objetos; el juego los está cargando.", faltanNombres)
  end
  return table.concat(lineas, "\n"), aviso, limite, total, faltanNombres
end
