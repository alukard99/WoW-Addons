-- Base de datos, utilidades y un motor de tareas que reparte el trabajo pesado
-- entre varios fotogramas para que el juego no se congele.
local _, S = ...
local T = S.T -- traducción (Locale.lua)

S.DIA = 86400
S.GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo

function S.msg(texto)
  print(T"|cff33ccffSubastas:|r " .. texto)
end

function S.iniciarDB()
  SubastasDB = SubastasDB or {}
  local db = SubastasDB
  db.reinos = db.reinos or {}
  db.opciones = db.opciones or {}
  local o = db.opciones
  if o.dias == nil then o.dias = 14 end          -- días de historial que se guardan
  if o.lineas == nil then o.lineas = 1500 end    -- máximo de objetos por exportación
  if o.orden == nil then o.orden = "volumen" end
  if o.minCantidad == nil then o.minCantidad = 1 end
end

function S.claveReino()
  return (GetRealmName() or "?") .. " - " .. (UnitFactionGroup("player") or "?")
end

function S.reino()
  local k = S.claveReino()
  local r = SubastasDB.reinos[k]
  if not r then
    r = { items = {} }
    SubastasDB.reinos[k] = r
  end
  return r
end

function S.hoy()
  return math.floor(time() / S.DIA)
end

-- Cobre -> texto en oro con hasta 4 decimales ("12.5", "0.0003").
function S.oro(cobre)
  cobre = tonumber(cobre) or 0
  if cobre <= 0 then return "" end
  local t = string.format("%.4f", cobre / 10000)
  t = t:gsub("0+$", ""):gsub("%.$", "")
  return t
end

-- Registro diario guardado como texto para ocupar poco:
-- "min,p25,mediana,cantidad,subastas,vendedores,primeros" (precios en cobre por unidad).
function S.leerRegistro(s)
  local a, b, c, d, e, f, g = strsplit(",", s, 7)
  return tonumber(a) or 0, tonumber(b) or 0, tonumber(c) or 0,
    tonumber(d) or 0, tonumber(e) or 0, tonumber(f) or 0, g or ""
end

-- Motor de tareas: una corrutina que se reanuda cada fotograma con ~10 ms de presupuesto.
local motor = CreateFrame("Frame")
local inicio = 0
local tarea

function S.ceder()
  if coroutine.running() and debugprofilestop() - inicio > 10 then
    coroutine.yield()
  end
end

function S.tarea(fn, alFallar)
  tarea = { co = coroutine.create(fn), alFallar = alFallar }
end

function S.ocupado()
  return tarea ~= nil
end

local oyentesUpdate = {}
function S.cadaFotograma(fn)
  oyentesUpdate[#oyentesUpdate + 1] = fn
end

motor:SetScript("OnUpdate", function(_, dt)
  for i = 1, #oyentesUpdate do oyentesUpdate[i](dt) end
  if not tarea then return end
  inicio = debugprofilestop()
  local t = tarea
  local ok, err = coroutine.resume(t.co)
  if not ok then
    tarea = nil
    if t.alFallar then t.alFallar(err) end
    geterrorhandler()(err)
  elseif coroutine.status(t.co) == "dead" and tarea == t then
    tarea = nil
  end
end)

-- Eventos
local eventos = CreateFrame("Frame")
local manejadores = {}
function S.alEvento(nombre, fn)
  if not manejadores[nombre] then
    manejadores[nombre] = {}
    pcall(eventos.RegisterEvent, eventos, nombre) -- algunos eventos no existen en todas las versiones
  end
  table.insert(manejadores[nombre], fn)
end
eventos:SetScript("OnEvent", function(_, nombre, ...)
  local l = manejadores[nombre]
  if l then for i = 1, #l do l[i](...) end end
end)

S.alEvento("ADDON_LOADED", function(nombre)
  if nombre == "Subastas" then S.iniciarDB() end
end)
