-- Alianza: botón flotante. Clic: escribir en el chat de alianza; clic derecho: la línea /join. Se arrastra para moverlo y recuerda
-- dónde se dejó; /alianza boton lo oculta o lo vuelve a mostrar.
local _, ns = ...
local T = ns.T

local B = {
    nombre = "AlianzaBoton",
    icono = "Interface\\Icons\\Ability_Warrior_BattleShout",
    x = 345, y = -200,
    titulo = T"Chat de alianza",
    bd = "AlianzaDB",
    prefijo = T"|cffff8c1a[Alianza]|r ",
    comando = T"/alianza boton",
    textoClic = T"Clic: escribir en el chat de alianza",
    textoDerecho = T"Clic derecho: ver el canal y la línea para unirse",
    clic = function()
        local db = AlianzaDB
        if not (db and db.channel) then
            SlashCmdList.ALIANZA("info") -- explica cómo configurar el canal
            return
        end
        local abrir = ChatFrame_OpenChat or (ChatFrameUtil and ChatFrameUtil.OpenChat)
        if abrir then abrir("/a ") end
    end,
    derecho = function() SlashCmdList.ALIANZA("info") end,
    info = function(tip)
        local db = AlianzaDB
        if not (db and db.channel) then
            tip:AddLine(T"Sin canal configurado", 0.8, 0.8, 0.8)
            return
        end
        local id = GetChannelName(db.channel)
        tip:AddLine(string.format(T"Canal: %s", db.channel) .. "  " ..
            ((id or 0) > 0 and T"|cff33ff33conectado|r" or T"|cffff3333no conectado|r"), 0.8, 0.8, 0.8)
    end,
}

-- ---------------------------------------------------------------- igual en todos los addons
local function datos()
    local db = _G[B.bd]
    return type(db) == "table" and db or nil
end

local btn = CreateFrame("Button", B.nombre, UIParent)
btn:SetSize(36, 36)
btn:SetPoint("CENTER", UIParent, "CENTER", B.x, B.y)
btn:SetFrameStrata("MEDIUM")
btn:SetClampedToScreen(true)
btn:SetMovable(true)
btn:RegisterForDrag("LeftButton")
btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
btn:Hide()

local icon = btn:CreateTexture(nil, "ARTWORK")
icon:SetAllPoints()
icon:SetTexture(B.icono)
btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

btn:SetScript("OnDragStart", function(self)
    GameTooltip:Hide()
    self:StartMoving()
end)
btn:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    local db = datos()
    if db then db.btnPos = { p, rp, x, y } end
end)

btn:SetScript("OnClick", function(_, boton)
    if boton == "RightButton" and B.derecho then
        B.derecho()
    else
        B.clic()
    end
end)

btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(B.titulo)
    if B.info then B.info(GameTooltip) end
    GameTooltip:AddLine(B.textoClic or T"Clic: abrir o cerrar", 1, 1, 1)
    if B.textoDerecho then GameTooltip:AddLine(B.textoDerecho, 1, 1, 1) end
    GameTooltip:AddLine(T"Arrastrar: mover", 1, 1, 1)
    GameTooltip:Show()
end)
btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Lo llama el comando "boton" del addon.
function ns.AlternarBoton()
    local db = datos()
    if not db then return end
    db.hideBtn = not db.hideBtn
    btn:SetShown(not db.hideBtn)
    print(B.prefijo .. (db.hideBtn
        and string.format(T"Botón oculto. Escribe %s para volver a mostrarlo.", B.comando)
        or T"Botón visible."))
end

-- La posición se restaura al entrar, cuando ya están cargados los datos guardados.
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    local db = datos()
    if not db then return end
    local p = db.btnPos
    if type(p) == "table" and p[1] then
        btn:ClearAllPoints()
        btn:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    end
    btn:SetShown(not db.hideBtn)
end)
