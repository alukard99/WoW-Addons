-- Lados · sonido y música
-- Cada lado es una nota. WoW solo reproduce archivos, así que las notas están grabadas en sonidos/
-- (las genera tools/wow/medios.js): t = triángulo, u = triángulo suave (acordes), s = seno,
-- q = cuadrada, b = bajo de jefe, a = bajo de fondo, seguido del número MIDI.
local _, L = ...
local floor, max, min = math.floor, math.max, math.min
local PATH = "Interface\\AddOns\\Lados\\sonidos\\"

L.OPT = L.OPT or {muted = false, shots = true, beat = true, floats = true, channel = "SFX", combatHide = true}

local queue = {}                                   -- notas que suenan un poco más tarde (arpegios)
local function playNow(file)
  if L.OPT.muted then return end
  PlaySoundFile(PATH .. file .. ".ogg", L.OPT.channel or "SFX")
end
local function play(file, delay)
  if L.OPT.muted then return end
  if not delay or delay < 0.012 then playNow(file)
  else queue[#queue + 1] = {GetTime() + delay, file} end
end
function L.sfx(name, delay) play(name, delay) end

local RANGE = {t = {36, 108}, u = {48, 108}, s = {36, 100}, q = {36, 96}, b = {36, 62}, a = {36, 60}}
local function fit(kind, m)
  local r = RANGE[kind]
  m = floor(m + 0.5)
  while m < r[1] do m = m + 12 end
  while m > r[2] do m = m - 12 end
  return m
end
function L.tone(midi, delay, kind) kind = kind or "t"; play(kind .. fit(kind, midi), delay) end
function L.arpeggio(base, steps, gap, kind)
  for j, d in ipairs(steps) do L.tone(base + d, (j - 1) * gap, kind) end
end

-- ---------- Escalas ----------
-- Cada familia suena en su propia escala de 5 notas; durante los jefes todo pasa a pentatónica menor
local PENTA = {0, 2, 4, 7, 9}
local FAM_SCALES = {[0] = PENTA, {0, 2, 5, 7, 10}, {0, 2, 3, 7, 8}, {0, 4, 6, 7, 11}}
local MINOR = {0, 3, 5, 7, 10}
local scale = nil
local function scaleOf(i) return scale or FAM_SCALES[L.famIdx(i)] end
local function midiFor(idx, sc) return 48 + 12 * floor(idx / 5) + sc[idx % 5 + 1] end
function L.noteOf(i, k) return midiFor((i * 2 + k) % 15, scaleOf(i)) end

function L.chord(i, n, delay)
  local root = L.noteOf(i, n - 1) + 12
  for m, d in ipairs({0, 4, 7}) do L.tone(root + d, delay + (m - 1) * 0.04, "u") end
end

-- Disparos: como mucho uno cada 150 ms para que muchas torretas no saturen
local lastShot = 0
function L.shotSound()
  if not L.OPT.shots then return end
  local t = GetTime()
  if t - lastShot < 0.15 then return end
  lastShot = t; playNow("shot")
end

-- Impactos de las torretas: encajados en la siguiente semicorchea, como mucho una nota por figura
local hitQ, breakQ = {}, nil
function L.queueHit(i, midi) hitQ[i] = midi end
function L.queueBreak(i, n) breakQ = {i = i, n = n} end

-- ---------- Música ----------
local bpm = 112
local function stepLen() return 60 / bpm / 4 end
local nextStep, stepN = 0, 0
local music = {level = 0, want = 0, root = 48, finish = nil}
local amb = {level = 0, bar = 0}

function L.musicStart(rootMidi) music.root = 36 + (rootMidi % 12); music.want = 1 end
function L.musicLevel(l) if music.want > 0 then music.want = l end end
-- win: true = derrotado, false = escapado, nil = cortar sin más (al salir de la partida)
function L.musicStop(win)
  music.want = 0; music.finish = win
  if win == nil then
    music.level = 0; scale = nil; bpm = 112
    for k in pairs(hitQ) do hitQ[k] = nil end
    breakQ = nil
  end
end

local function ambientWant()
  local S = L.S
  if not S or S.guns == 0 then return 0 end
  local u, F = S.unlocked, L.FAMILIES
  local w = 1
  if u >= 6 then w = w + 1 end
  if u > F[2][1] then w = w + 1 end
  if u > F[3][1] then w = w + 1 end
  if u > F[4][1] then w = w + 1 end
  return w
end

local function bossStep(k)
  local lv, r = music.level, music.root
  local fifth, oct = r + 7, r + 12
  if k % (lv >= 2 and 4 or 8) == 0 then playNow("kick") end
  local line = lv == 1 and {[0] = r, [6] = r, [10] = fifth}
    or {[0] = r, [3] = r, [6] = oct, [8] = r, [10] = fifth, [12] = r + 3, [14] = fifth}
  if line[k] then L.tone(line[k], 0, "b") end
  if lv >= 2 and k % 4 == 2 then playNow("hat") end
  if lv >= 3 and k % 2 == 1 then playNow("hat16") end
  if lv >= 3 then
    local arp = {0, 3, 7, 10, 12, 10, 7, 3}
    if k % 2 == 0 then L.tone(r + 24 + arp[(k / 2) % 8 + 1], 0, "q") end
    if k >= 12 then playNow("roll") end
  end
end

local function ambientStep(k)
  local lv = amb.level
  if lv == 0 then return end
  local r, bar = 36, amb.bar
  local fam = L.famIdx(L.S.unlocked - 1)
  local sc = FAM_SCALES[fam]
  if k == 0 or k == 8 or (bar % 2 == 1 and k == 14) then playNow("kick2") end
  if lv < 3 and k % 8 == 4 then playNow("tick") end
  if lv >= 2 then
    local line = bar % 4 == 3 and {[0] = r, [6] = r, [8] = r + 7, [12] = r + 12, [14] = r + 7} or {[0] = r, [6] = r, [10] = r + 7}
    if line[k] then L.tone(line[k], 0, "a") end
  end
  if lv >= 3 then
    if k == 0 and bar % 2 == 0 then playNow("pad" .. fam .. (bar % 4 == 2 and 1 or 0)) end
    if k % 2 == 0 then playNow(k % 4 == 2 and "mara" or "mara2") end
  end
  if lv >= 4 then
    playNow(k % 3 == 0 and "gear" or "gear2")
    if k == 4 or k == 12 then L.tone(r + 48 + sc[4], 0, "q") end
  end
  if lv >= 5 and bar % 2 == 1 and k % 2 == 0 then
    local arp = {0, 1, 2, 3, 4, 3, 2, 1}
    L.tone(r + 36 + sc[arp[(k / 2) % 8 + 1] + 1], 0, "s")
  end
end

local function musicStep(k)
  if k == 0 then                                   -- inicio de compás: aquí se aplican los cambios
    if music.finish ~= nil and music.want == 0 then
      local r = music.root + 24
      if music.finish then
        L.arpeggio(r, {0, 4, 7, 12}, 0.1, "u"); playNow("kick"); playNow("crash")
      else
        L.arpeggio(r, {0, -2, -5, -12}, 0.18, "s")
      end
      music.finish = nil; music.level = 0; scale = nil; bpm = 112
      return
    end
    if music.want ~= music.level then
      if music.want > music.level and music.level > 0 then playNow("hatup") end
      music.level = music.want
      scale = music.level > 0 and MINOR or nil
      bpm = music.level >= 3 and 128 or 112
    end
    if music.level == 0 then
      local want = (L.OPT.beat and L.inGame and not L.menuOpen) and ambientWant() or 0
      if want > amb.level then playNow("sweep") end
      if want ~= amb.level then amb.level = want; amb.bar = 0 else amb.bar = amb.bar + 1 end
    end
  end
  if music.level == 0 then ambientStep(k) else bossStep(k) end
end

-- Se llama en cada fotograma mientras la ventana está abierta
function L.audioUpdate()
  local now = GetTime()
  for j = #queue, 1, -1 do
    if queue[j][1] <= now then playNow(queue[j][2]); table.remove(queue, j) end
  end
  if nextStep == 0 or nextStep < now - 0.25 then nextStep = now end   -- vuelve de estar cerrada: sin ráfagas
  while nextStep <= now do
    local played = 0
    for i = 0, L.N - 1 do
      if hitQ[i] then
        if played < 2 then L.tone(hitQ[i], 0, "t"); played = played + 1 end   -- WoW tiene pocos canales de sonido
        hitQ[i] = nil
      end
    end
    if breakQ then L.chord(breakQ.i, breakQ.n, 0.03); breakQ = nil end
    musicStep(stepN % 16)
    stepN = stepN + 1
    nextStep = nextStep + stepLen()
  end
end

-- Pequeñas melodías de la interfaz
function L.revealSound() L.arpeggio(72, {0, 4, 7, 12}, 0.07, "t") end
function L.achSound() L.arpeggio(84, {0, 7, 12}, 0.06, "s") end
function L.awaySound() L.arpeggio(64, {0, 4, 7, 12}, 0.08, "s") end
function L.prestigeSound() L.arpeggio(48, {0, 7, 12, 16, 19, 24}, 0.09, "t") end
