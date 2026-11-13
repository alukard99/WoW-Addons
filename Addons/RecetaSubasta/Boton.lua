-- RecetaSubasta: botón flotante. Clic: abrir o cerrar la ventana de la receta. Se arrastra para moverlo y recuerda
-- dónde se dejó; /receta boton lo oculta o lo vuelve a mostrar.
local _, ns = ...
local T = ns.T

local B = {
    nombre = "RecetaSubastaBoton",
    icono = "Interface\\Icons\\INV_Scroll_03",
    x = 390, y = -200,
    titulo = T"Receta con precios de subasta",
    bd = "RecetaSubastaDB",
    prefijo = T"|cff33ccffRecetaSubasta:|r ",
    comando = T"/receta boton",
    clic = function() SlashCmdList.RECETASUBASTA("") end,
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
