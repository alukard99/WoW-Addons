-- Artesanos: botón "Ofrecer en el mercado" en la ventana de profesiones y lectura de las
-- recetas que conoce el personaje.
local ADDON, ns = ...
local T = ns.T
local A = ns.A

local boton

local function SelectedRecipe()
    local page = ProfessionsFrame and ProfessionsFrame.CraftingPage
    local form = page and page.SchematicForm
    local info = form and form.GetRecipeInfo and form:GetRecipeInfo()
    return info and info.recipeID, info
end

local function Viewing()
    -- La ventana también puede mostrar la profesión de otro jugador o la de la hermandad.
    for _, f in ipairs({ "IsTradeSkillLinked", "IsTradeSkillGuild", "IsNPCCrafting" }) do
        local fn = C_TradeSkillUI and C_TradeSkillUI[f]
        if fn then
            local ok, res = pcall(fn)
            if ok and res then return false end
        end
    end
    return true
end

local function UpdateButton()
    if not boton then return end
    local id, info = SelectedRecipe()
    local usable = id and Viewing() and not (info and info.learned == false)
    boton:SetEnabled(usable and true or false)
    boton:SetText(id and A.MyOffer(id) and T"Editar mi oferta" or T"Ofrecer en el mercado")
end

local function OnClick()
    local id, info = SelectedRecipe()
    if not id then
        A.Print(T"Selecciona una receta en la ventana de profesiones.")
        return
    end
    if info and info.learned == false then
        A.Print(T"Aún no conoces esta receta.")
        return
    end
    A.ScanKnown()
    local o = A.MyOffer(id)
    if not o then
        local err
        o, err = A.Publish(id)
        if not o then
            A.Print(err)
            return
        end
        A.Print(string.format(T"Publicado en el mercado: %s. Ponle precio en la ventana del mercado.",
            (A.OfferInfo(o))))
    end
    A.UI.Open("mine", id)
    UpdateButton()
end

local function Hook()
    if boton or not ProfessionsFrame then return end
    boton = CreateFrame("Button", nil, ProfessionsFrame, "UIPanelButtonTemplate")
    boton:SetSize(160, 22)
    boton:SetPoint("BOTTOMRIGHT", ProfessionsFrame, "TOPRIGHT", -190, 2)
    boton:SetScript("OnClick", OnClick)
    boton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(T"Mercado de la hermandad")
        GameTooltip:AddLine(T"Publica la receta seleccionada para que tu hermandad vea que la puedes fabricar.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    boton:SetScript("OnLeave", GameTooltip_Hide)
    ProfessionsFrame:HookScript("OnShow", UpdateButton)
    if EventRegistry then
        EventRegistry:RegisterCallback("ProfessionsRecipeListMixin.Event.OnRecipeSelected", UpdateButton, boton)
    end
    UpdateButton()
end
A.UpdateProfessionButton = UpdateButton

------------------------------------------------------------------------
-- Eventos
------------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({ "ADDON_LOADED", "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "NEW_RECIPE_LEARNED" }) do
    pcall(ev.RegisterEvent, ev, e) -- no todos existen en todas las versiones
end

local scanPending, lastScan = false, 0
local function ScanSoon()
    if scanPending then return end
    scanPending = true
    C_Timer.After(1, function()
        scanPending = false
        if GetTime() - lastScan < 10 then return end
        lastScan = GetTime()
        A.ScanKnown()
        UpdateButton()
    end)
end

ev:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == ADDON or arg1 == "Blizzard_Professions" then Hook() end
    elseif event == "NEW_RECIPE_LEARNED" then
        lastScan = 0
        ScanSoon()
    else
        ScanSoon()
    end
end)
