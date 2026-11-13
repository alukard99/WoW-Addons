local addon, V = ...
local W,H = V.width,V.height
local root,canvas,hud,overlay,render,health,xp,counter,barkLabel
local screens,selected,cards = {},0,{}
local notice,expires="",0
local step=1/30
local elapsed,idleElapsed=0,0
local gold={.88,.73,.43}
local ivory={.94,.89,.78}
local muted={.69,.64,.56}
local function place(widget,parent,x,y,w,h)
    widget:SetPoint("TOPLEFT",parent,"TOPLEFT",x,-y)
    if w and h then widget:SetSize(w,h) end
    return widget
end
local function rect(parent,x,y,w,h,r,g,b,a,layer)
    local t=place(parent:CreateTexture(nil,layer or "BACKGROUND"),parent,x,y,w,h)
    t:SetColorTexture(r,g,b,a or 1)
    return t
end
local function label(parent,x,y,w,h,text,size,color,align)
    local f=place(parent:CreateFontString(nil,"OVERLAY"),parent,x,y,w,h)
    f:SetFont(STANDARD_TEXT_FONT,size,"")
    f:SetTextColor(unpack(color or ivory));f:SetShadowColor(0,0,0,.95);f:SetShadowOffset(1,-1)
    f:SetJustifyH(align or "LEFT");f:SetJustifyV("MIDDLE");f:SetText(text)
    return f
end
local function icon(parent,x,y,w,h,key)
    local t=place(parent:CreateTexture(nil,"ARTWORK"),parent,x,y,w,h)
    if key then V.paint(t,key) end
    return t
end
local function button(parent,x,y,w,h,text,action,primary)
    local b=place(CreateFrame("Button",nil,parent),parent,x,y,w,h)
    b.fill=rect(b,0,0,w,h,primary and .34 or .125,primary and .12 or .105,primary and .095 or .09,.96)
    rect(b,0,h-1,w,1,.59,.44,.26,.8,"BORDER")
    local hover=b:CreateTexture(nil,"HIGHLIGHT");hover:SetAllPoints();hover:SetColorTexture(.89,.67,.28,.16)
    b.caption=label(b,3,1,w-6,h-2,text,14,primary and ivory or gold,"CENTER")
    b:SetScript("OnClick",action)
    return b
end
local function clearInput()
    for k in pairs(V.keys) do V.keys[k]=nil end
    V.joy.on=false
end
function V.bark(msg)
    notice,expires=msg,GetTime()+4.2
end
local function menu()
    V.game=nil
    V.change("title")
end
local function start()
    V.newRun(V.db.sel)
    V.change("play")
    V.bark("La noche es larga, y tiene hambre.")
end
local function pause()
    if V.state=="play" then V.change("pause")
    elseif V.state=="pause" then V.change("play") end
end
local function chooseRoster()
    selected=V.db.sel
    V.change("chars")
end
local function pick(i)
    if V.state=="levelup" and cards[i] then V.applyCard(cards[i]) end
end
function V.reveal()
    cards=V.offers()
    V.sound("lvl")
    V.change("levelup")
end
function V.finish(win)
    local g=V.game
    g.victory=win
    g.newCharacters=V.commit(win)
    V.sound(win and "win" or "die")
    V.change("over")
end
local function fullscreen(parent)
    local f=CreateFrame("Frame",nil,parent)
    f:SetAllPoints()
    return f
end

local function titleScreen(f)
    local cover=f:CreateTexture(nil,"BACKGROUND")
    cover:SetAllPoints();cover:SetTexture(V.media.."Cover.blp")
    rect(f,44,66,48,2,.71,.46,.22)
    label(f,44,79,470,105,"La Última\nVigilia",46,ivory)
    label(f,47,200,435,58,"La abadía ha caído. Solo queda tu antorcha, y la noche viene a apagarla. Resiste cinco minutos, hasta el alba.",16,muted)
    button(f,47,282,242,40,"Encender la antorcha",start,true)
    local roster=button(f,47,332,242,34,"Vigilantes",chooseRoster)
    local best=label(f,47,375,440,28,"",14,gold)
    rect(f,46,416,738,1,.42,.33,.24,.8)
    label(f,47,426,735,44,"WASD, flechas o arrastrar con el ratón para moverte. Las armas atacan solas.\nRecoge ascuas para subir de nivel. Pulsa P o Esc para pausar.",13,muted)
    local hero=icon(f,521,189,112,138)
    local who=label(f,449,336,324,44,"",18,gold,"CENTER")
    return function()
        V.paint(hero,"hero"..V.db.sel)
        who:SetText((V.character(V.db.sel)))
        roster.caption:SetText("Vigilantes  ·  "..V.count().." / 100")
        best:SetText(V.db.g.time>0 and "Mejor vigilia  ·  "..V.clock(V.db.g.time) or "")
    end
end

local function charsScreen(f)
    rect(f,0,0,W,H,.052,.042,.036,.97)
    label(f,22,11,360,42,"Los Vigilantes",27)
    local tally=label(f,430,14,378,36,"",15,gold,"RIGHT")
    local classes,traits={},{}
    for i,class in ipairs(V.CLS) do
        local classIndex=i
        classes[i]=button(f,22,61+(i-1)*33,165,30,class.n,function()
            selected=(classIndex-1)*10;V.change("chars")
        end)
    end
    for i=1,10 do
        local traitIndex=i-1
        local x=207+traitIndex%5*120
        local y=63+math.floor(traitIndex/5)*89
        local b=button(f,x,y,113,83,"",function()
            selected=math.floor(selected/10)*10+traitIndex;V.change("chars")
        end)
        b.portrait=icon(b,34,1,45,56)
        b.text=label(b,2,57,109,24,"",11,muted,"CENTER")
        traits[i]=b
    end
    rect(f,207,251,591,1,.48,.37,.23)
    local portrait=icon(f,211,272,72,89)
    local who=label(f,299,263,496,33,"",21)
    local detail=label(f,299,299,490,63,"",14,muted)
    local req=label(f,209,370,593,44,"",14,gold)
    local choose=button(f,208,427,247,38,"Elegir",function()
        if V.available(selected) then V.db.sel=selected;menu() end
    end,true)
    button(f,468,427,143,38,"Volver",menu)
    return function()
        local name,class,trait=V.character(selected)
        local ci=math.floor(selected/10)
        tally:SetText(V.count().." de 100 desbloqueados")
        for i,b in ipairs(classes) do b.caption:SetTextColor(unpack(i-1==ci and ivory or muted)) end
        for i,b in ipairs(traits) do
            local id=ci*10+i-1
            local open=V.available(id)
            V.paint(b.portrait,"hero"..id);b.portrait:SetAlpha(open and 1 or .45)
            b.text:SetText(V.TRT[i].e)
            b.fill:SetColorTexture(id==selected and .31 or .12,id==selected and .20 or .10,.08,1)
        end
        V.paint(portrait,"hero"..selected);who:SetText(name)
        local weapons=V.UP[class.w].name
        if trait.two then
            for i,k in ipairs(V.WPN) do if k==class.w then weapons=weapons.." y "..V.UP[V.WPN[i%5+1]].name end end
        end
        detail:SetText(weapons.."\n"..class.d.."  "..trait.d)
        req:SetText(V.available(selected) and (selected==V.db.sel and "Vigilante elegido" or "Disponible") or V.lockText(selected))
        choose:SetShown(V.available(selected));choose.caption:SetText(selected==V.db.sel and "Continuar con este vigilante" or "Elegir vigilante")
    end
end

local function levelScreen(f)
    rect(f,0,0,W,H,.045,.032,.028,.92)
    label(f,20,32,W-40,56,"Una revelación",31,ivory,"CENTER")
    local sub=label(f,25,86,W-50,28,"",15,muted,"CENTER")
    local buttons={}
    for i=1,4 do
        local index=i
        local b=button(f,0,137,184,278,"",function() pick(index) end)
        b.pic=icon(b,58,13,68,68)
        b.kind=label(b,5,82,174,24,"",12,gold,"CENTER")
        b.name=label(b,6,109,172,49,"",17,ivory,"CENTER")
        b.desc=label(b,10,156,164,93,"",13,muted,"CENTER")
        label(b,8,249,168,22,"[ "..i.." ]",13,gold,"CENTER")
        buttons[i]=b
    end
    return function()
        sub:SetText("Nivel "..V.game.p.lv.."  ·  Elige con qué afrontar la oscuridad.")
        local kinds={w="Arma",r="Reliquia",a="Habilidad"}
        for i,b in ipairs(buttons) do
            local k=cards[i]
            b:SetShown(k~=nil)
            if k then
                local evo=k:sub(1,1)=="^"
                local key=evo and k:sub(2) or k
                local u=evo and V.EV[key] or V.UP[key]
                b:ClearAllPoints()
                b:SetPoint("TOPLEFT",f,"TOPLEFT",(W-(#cards*196-12))/2+(i-1)*196,-137)
                V.paint(b.pic,u and "icon_"..key..(evo and "_e" or "") or "flask")
                b.name:SetText(u and u.name or "Ración")
                local n=V.game.p.up[key] or 0
                b.kind:SetText(evo and "Evolución" or u and (kinds[u.t]..(u.max>1 and " · "..(n+1).." / "..u.max or "")) or "Consumible")
                b.desc:SetText(u and (n>0 and not evo and u.t=="w" and V.ARCHUP[u.a] or u.ds) or "Recuperas 40 de vida.")
            end
        end
    end
end

local function pauseScreen(f)
    rect(f,0,0,W,H,.055,.042,.035,.94)
    label(f,37,25,480,60,"Pausa",32)
    local items=label(f,39,112,435,266,"",15,muted)
    items:SetJustifyV("TOP")
    button(f,505,119,269,43,"Continuar",pause,true)
    local sound=button(f,505,177,269,38,"",function() V.db.muted=not V.db.muted;V.change("pause") end)
    local music=button(f,505,225,269,38,"",function() V.db.musicOff=not V.db.musicOff;V.change("pause") end)
    button(f,505,294,269,38,"Abandonar la vigilia",function() V.commit(false);menu() end)
    return function()
        local groups={w={},r={},a={}}
        for k,n in pairs(V.game.p.up) do
            local u=n>5 and V.EV[k] or V.UP[k]
            groups[u.t][#groups[u.t]+1]=u.name..(n>5 and " (evolución)" or u.max>1 and " "..n or "")
        end
        local lines={}
        for _,pair in ipairs({{"w","Armas"},{"r","Reliquias"},{"a","Habilidades"}}) do
            local list=groups[pair[1]]; table.sort(list)
            if #list>0 then lines[#lines+1]="|cffe1bb72"..pair[2].."|r\n"..table.concat(list,", ") end
        end
        items:SetText(table.concat(lines,"\n\n"))
        sound.caption:SetText("Sonido  ·  "..(V.db.muted and "desactivado" or "activado"))
        music.caption:SetText("Música  ·  "..(V.db.musicOff and "desactivada" or "activada"))
    end
end

local function overScreen(f)
    rect(f,0,0,W,H,.045,.032,.028,.93)
    local title=label(f,27,42,W-54,66,"",34,ivory,"CENTER")
    local sub=label(f,82,110,W-164,58,"",16,muted,"CENTER")
    local stats=label(f,44,187,W-88,56,"",17,gold,"CENTER")
    local unlock=label(f,53,253,W-106,64,"",14,ivory,"CENTER")
    button(f,131,350,190,41,"Otra vigilia",start,true)
    button(f,333,350,164,41,"Vigilantes",chooseRoster)
    button(f,509,350,179,41,"Menú",menu)
    local endless=button(f,288,410,256,36,"Seguir en la noche",function()
        V.game.endless=true;V.change("play");V.bark("El alba era mentira. Sigue.")
    end)
    return function()
        local g=V.game
        title:SetText(g.victory and "Amanece" or "La llama se extingue")
        sub:SetText(g.victory and "La luz entra por las vidrieras rotas. Lo que quedaba de la noche arde con ella." or "Otro nombre para las lápidas. La abadía sigue esperando.")
        stats:SetText(("Tiempo  %s     ·     Abatidos  %d     ·     Nivel  %d\nMejor vigilia  %s"):format(V.clock(g.t),g.kills,g.p.lv,V.clock(V.db.g.time)))
        unlock:SetText(#g.newCharacters>0 and "Nuevos vigilantes\n"..table.concat(g.newCharacters,", ",1,math.min(4,#g.newCharacters))..(#g.newCharacters>4 and " y "..(#g.newCharacters-4).." más" or "") or "")
        endless:SetShown(g.victory)
    end
end
local factories={title=titleScreen,chars=charsScreen,levelup=levelScreen,pause=pauseScreen,over=overScreen}
function V.change(state)
    clearInput()
    elapsed,idleElapsed=0,0
    V.state=state
    for _,s in pairs(screens) do s.frame:Hide() end
    hud:SetShown(state=="play")
    overlay:SetShown(state~="play")
    canvas:SetShown(V.game~=nil and state~="chars")
    if state=="play" and not render then render=V.makeRenderer(canvas) end
    if factories[state] then
        if not screens[state] then
            local f=fullscreen(overlay)
            screens[state]={frame=f,refresh=factories[state](f)}
        end
        screens[state].frame:Show();screens[state].refresh()
    end
    if root:IsShown() then V.music(GetTime()) end
end
local movement={A="KeyA",D="KeyD",W="KeyW",S="KeyS",LEFT="ArrowLeft",RIGHT="ArrowRight",UP="ArrowUp",DOWN="ArrowDown"}
local function keyboard(_,key)
    if V.state=="play" and movement[key] then V.keys[movement[key]]=true
    elseif (key=="P" or key=="ESCAPE") and (V.state=="play" or V.state=="pause") then pause()
    elseif V.state=="levelup" and tonumber(key) then pick(tonumber(key))
    elseif key=="ESCAPE" then
        if V.state=="chars" or V.state=="over" then menu() else root:Hide() end
    end
end
local function cursor()
    local x,y=GetCursorPosition()
    local scale=canvas:GetEffectiveScale()
    return x/scale,-y/scale
end
local function build()
    root=CreateFrame("Frame","LaUltimaVigiliaWindow",UIParent)
    root:Hide();root:SetSize(W+4,H+38);root:SetPoint("CENTER");root:SetFrameStrata("DIALOG")
    root:SetMovable(true);root:SetClampedToScreen(true);root:EnableMouse(true)
    rect(root,0,0,W+4,H+38,.33,.25,.16)
    local bar=place(CreateFrame("Frame",nil,root),root,2,2,W,32)
    rect(bar,0,0,W,32,.10,.078,.065)
    label(bar,12,0,W-80,32,"La Última Vigilia",15,gold)
    bar:EnableMouse(true);bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart",function() root:StartMoving() end)
    bar:SetScript("OnDragStop",function() root:StopMovingOrSizing() end)
    button(bar,W-91,1,88,29,"Cerrar",function() root:Hide() end)
    local clip=place(CreateFrame("Frame",nil,root),root,2,35,W,H)
    clip:SetClipsChildren(true)
    canvas=fullscreen(clip)
    hud=fullscreen(clip);hud:SetFrameLevel(canvas:GetFrameLevel()+3)
    hud:EnableMouse(true)
    hud:SetScript("OnMouseDown",function(_,b) if b=="LeftButton" then local x,y=cursor();V.joy.ox,V.joy.oy=x,y;V.joy.x,V.joy.y=x,y;V.joy.on=true end end)
    hud:SetScript("OnMouseUp",function() V.joy.on=false end)
    rect(hud,0,0,W,35,.055,.042,.034,.92)
    rect(hud,14,9,132,8,.28,.16,.13);health=rect(hud,14,9,132,8,.73,.22,.16,1,"ARTWORK")
    rect(hud,14,21,132,4,.25,.22,.16);xp=rect(hud,14,21,132,4,.86,.66,.29,1,"ARTWORK")
    counter=label(hud,160,0,525,35,"",15,ivory)
    button(hud,W-82,3,77,28,"Pausa",pause)
    barkLabel=label(hud,20,H-51,W-40,42,"",15,gold,"CENTER")
    overlay=fullscreen(clip);overlay:SetFrameLevel(hud:GetFrameLevel()+4);overlay:EnableMouse(true)
    root:EnableKeyboard(true);root:SetPropagateKeyboardInput(false)
    root:SetScript("OnKeyDown",keyboard)
    root:SetScript("OnKeyUp",function(_,k) if movement[k] then V.keys[movement[k]]=nil end end)
    root:SetScript("OnHide",function()
        root:StopMovingOrSizing();clearInput()
        if V.state=="play" then V.change("pause") end
        V.silence()
    end)
    root:SetScript("OnUpdate",function(_,dt)
        if V.state~="play" then
            idleElapsed=idleElapsed+dt
            if idleElapsed>=.25 then idleElapsed=0;V.music(GetTime()) end
            return
        end
        elapsed=math.min(elapsed+dt,3*step)
        if elapsed+1e-9<step then return end
        local now=GetTime()
        if V.joy.on then
            if IsMouseButtonDown("LeftButton") then V.joy.x,V.joy.y=cursor() else V.joy.on=false end
        end
        while V.state=="play" and elapsed+1e-9>=step do
            elapsed=math.max(0,elapsed-step)
            V.update(step)
        end
        local g=V.game
        local hpWidth=math.max(.1,math.floor(132*g.p.hp/g.p.maxhp+.5))
        local xpWidth=math.max(.1,math.floor(132*g.p.xp/g.p.need+.5))
        if health.last~=hpWidth then health:SetWidth(hpWidth);health.last=hpWidth end
        if xp.last~=xpWidth then xp:SetWidth(xpWidth);xp.last=xpWidth end
        local second,hp=math.floor(g.t),math.ceil(g.p.hp)
        if counter.sec~=second or counter.hp~=hp or counter.lv~=g.p.lv or counter.kills~=g.kills or counter.maxHp~=g.p.maxhp or counter.endless~=g.endless then
            counter:SetText(("%s%s   ·   Nivel %d   ·   %d abatidos   ·   Vida %d/%d"):format(V.clock(second),g.endless and "  ∞" or " / 5:00",g.p.lv,g.kills,hp,g.p.maxhp))
            counter.sec,counter.hp,counter.lv,counter.kills,counter.maxHp,counter.endless=second,hp,g.p.lv,g.kills,g.p.maxhp,g.endless
        end
        local message=now<expires and notice or ""
        if barkLabel.last~=message then barkLabel:SetText(message);barkLabel.last=message end
        render(g,now)
        V.music(now)
    end)
    V.state="title"
end
local function toggle()
    if root and root:IsShown() then root:Hide();return end
    if InCombatLockdown() then print("|cffe1bb72La Última Vigilia|r estará disponible al salir de combate.");return end
    if not V.db then V.loadSave() end
    if not root then build() end
    root:SetScale(math.min(1,(UIParent:GetWidth()-12)/(W+4),(UIParent:GetHeight()-12)/(H+38)))
    root:Show();V.change(V.state)
end
SLASH_LAULTIMAVIGILIA1="/vigilia"
SLASH_LAULTIMAVIGILIA2="/luv"
SlashCmdList.LAULTIMAVIGILIA=toggle
local events=CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_LOGOUT")
events:SetScript("OnEvent",function(_,event,arg)
    if event=="ADDON_LOADED" and arg==addon then V.loadSave()
    elseif event=="PLAYER_REGEN_DISABLED" and root and root:IsShown() then root:Hide()
    elseif event=="PLAYER_LOGOUT" and V.game then V.commit(false) end
end)
