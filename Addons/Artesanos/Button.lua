-- Artesanos: botón flotante que abre el mercado. Se arrastra para moverlo y recuerda dónde se
-- dejó; /artesanos boton lo oculta o lo vuelve a mostrar.
local ADDON, ns = ...
local T = ns.T
local A = ns.A

local btn = CreateFrame("Button", "ArtesanosButton", UIParent)
btn:SetSize(36, 36)
btn:SetPoint("CENTER", UIParent, "CENTER", 300, -245) -- justo debajo del de Susurros
btn:SetFrameStrata("MEDIUM")
btn:SetClampedToScreen(true)
btn:SetMovable(true)
btn:RegisterForDrag("LeftButton")
btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
btn:Hide()

local icon = btn:CreateTexture(nil, "ARTWORK")
icon:SetAllPoints()
icon:SetTexture("Interface\\Icons\\Trade_BlackSmithing")
btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

btn:SetScript("OnDragStart", function(self)
    GameTooltip:Hide()
    self:StartMoving()
end)
btn:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    if A.db then A.db.btnPos = { p, rp, x, y } end
end)

btn:SetScript("OnClick", function(_, button)
    if button == "RightButton" then
        A.UI.Open("mine")
    else
        A.UI.Toggle()
    end
end)

btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(T"Mercado de Artesanos")
    local g = A.Guild(false)
    if g then
        local offers, crafters = 0, 0
        for name, c in pairs(g.crafters) do
            if A.InGuild(name) then
                local n = 0
                for _ in pairs(c.offers) do n = n + 1 end
                offers = offers + n
                if n > 0 then crafters = crafters + 1 end
            end
        end
        GameTooltip:AddLine(string.format(T"%d ofertas de %d artesanos", offers, crafters), 0.8, 0.8, 0.8)
    end
    GameTooltip:AddLine(T"Clic: abrir o cerrar", 1, 1, 1)
    GameTooltip:AddLine(T"Clic derecho: mis ofertas", 1, 1, 1)
    GameTooltip:AddLine(T"Arrastrar: mover", 1, 1, 1)
    GameTooltip:Show()
end)
btn:SetScript("OnLeave", GameTooltip_Hide)

function A.ToggleButton()
    if not A.db then return end
    A.db.hideBtn = not A.db.hideBtn
    btn:SetShown(not A.db.hideBtn)
    A.Print(A.db.hideBtn and T"Botón oculto. Escribe /artesanos boton para volver a mostrarlo."
        or T"Botón visible.")
end

-- La posición se restaura al entrar, cuando ya están cargados los datos guardados.
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function()
    if not A.db then return end
    local p = A.db.btnPos
    if p then
        btn:ClearAllPoints()
        btn:SetPoint(p[1], UIParent, p[2], p[3], p[4])
    end
    btn:SetShown(not A.db.hideBtn)
end)
