local name, V = ...
local media = "Interface\\AddOns\\"..name.."\\Media\\"
V.media = media
local W,H = V.width,V.height
local sin,cos,abs,floor,min,max = math.sin,math.cos,math.abs,math.floor,math.min,math.max
local function bounded(x) return max(0,min(1,x)) end
local colors = {}
local function tint(key)
    if not key then return 1,1,1 end
    local c=colors[key]
    if not c then
        local r,g,b=key:match("^(%d+),(%d+),(%d+)$")
        if not r then r=tonumber(key:sub(2,3),16); g=tonumber(key:sub(4,5),16); b=tonumber(key:sub(6,7),16) end
        c={r/255,g/255,b/255};colors[key]=c
    end
    return c[1],c[2],c[3]
end

function V.paint(texture, key, flip)
    if texture.asset==key and texture.flip==flip then return end
    local a=V.art[key]
    local file=a and ("Ink"..a[1]..".blp") or key
    if texture.file~=file then texture:SetTexture(media..file);texture.file=file end
    if a then texture:SetTexCoord(flip and a[3] or a[2],flip and a[2] or a[3],a[4],a[5])
    else texture:SetTexCoord(0,1,0,1) end
    texture.asset,texture.flip=key,flip
end

local props={"grave","cross","tree","bones","pillar","grave","bones"}
local function hash(x,y)
    local v=sin(x*127.1+y*311.7)*43758.5453
    return v-floor(v)
end
local function byDepth(a,b) return a.y<b.y end
local zoneColor={fire="#f28b39",holy="#99d7fc",acid="#93d764",tar="#796753"}
local projectile={bolt="dagger", dagger="dagger",bone="icon_tabas",sickle="icon_hoz",star="icon_lucero",orb="disc",pellet="disc"}

function V.makeRenderer(canvas)
    local floorTex=canvas:CreateTexture(nil,"BACKGROUND")
    floorTex:SetAllPoints()
    floorTex:SetTexture(media.."Ground.blp","REPEAT","REPEAT")
    local vignette=canvas:CreateTexture(nil,"OVERLAY",nil,6)
    vignette:SetAllPoints();vignette:SetTexture(media.."vignette.blp")
    local flash=canvas:CreateTexture(nil,"OVERLAY",nil,7)
    flash:SetAllPoints();flash:Hide()
    local pools,fonts,depth = {},{},{}
    for i=1,3 do pools[i]={used=0} end
    local texts,lastTexts=0,0
    local camX,camY=0,0
    local scenery={}
    local left,right,top,bottom
    local function position(region,x,y)
        -- Half-pixel placement keeps slow movement smooth without invalidating layout for tiny fractions.
        x,y=floor(x*2+.5)*.5,floor(y*2+.5)*.5
        if region.lastX~=x or region.lastY~=y then
            region:SetPoint("CENTER",canvas,"TOPLEFT",x,-y)
            region.lastX,region.lastY=x,y
        end
    end
    local function draw(layer,key,x,y,w,h,color,alpha,flip,rotation)
        x=x-camX+W/2;y=y-camY+H/2
        local halfW,halfH=w/2,h/2
        if rotation and rotation~=0 then
            local c,s=abs(cos(rotation)),abs(sin(rotation))
            halfW,halfH=halfW*c+halfH*s,halfW*s+halfH*c
        end
        if x+halfW<0 or y+halfH<0 or x-halfW>W or y-halfH>H then return end
        local pool=pools[layer]
        pool.used=pool.used+1
        local tx=pool[pool.used]
        if not tx then
            tx=canvas:CreateTexture(nil,"ARTWORK",nil,layer-2)
            pool[pool.used]=tx
        end
        V.paint(tx,key,flip)
        alpha=alpha or 1
        if tx.lastColor~=color or tx.lastAlpha~=alpha then
            local r,g,b=tint(color)
            tx:SetVertexColor(r,g,b,alpha)
            tx.lastColor,tx.lastAlpha=color,alpha
        end
        if tx.angle~=(rotation or 0) then tx:SetRotation(rotation or 0);tx.angle=rotation or 0 end
        w,h=max(.1,floor(w*2+.5)*.5),max(.1,floor(h*2+.5)*.5)
        if tx.lastW~=w or tx.lastH~=h then
            tx:SetSize(w,h);tx.lastW,tx.lastH=w,h
        end
        position(tx,x,y)
        if tx.hidden then tx:Show();tx.hidden=false end
    end
    local function sprite(layer,key,x,y,flip,alpha)
        local a=V.art[key]
        draw(layer,key,x,y-a[7]/2+3,a[6],a[7],nil,alpha,flip)
    end
    local function line(x,y,x2,y2,width,color,alpha)
        local dx,dy=x2-x,y2-y
        local length=math.sqrt(dx*dx+dy*dy)
        draw(3,"Solid",(x+x2)/2,(y+y2)/2,length,width,color,alpha,nil,-math.atan2(dy,dx))
    end
    local function number(n)
        local x,y=n.x-camX+W/2,n.y-camY+H/2
        if x<0 or y<0 or x>W or y>H then return end
        texts=texts+1
        local label=fonts[texts]
        if not label then label=canvas:CreateFontString(nil,"OVERLAY","GameFontNormalSmall");fonts[texts]=label end
        local col,alpha=n.col or "#efe4c8",min(1,n.l*3)
        if label.lastValue~=n.v then label:SetText(n.v);label.lastValue=n.v end
        if label.lastColor~=col then label:SetTextColor(tint(col));label.lastColor=col end
        if label.lastAlpha~=alpha then label:SetAlpha(alpha);label.lastAlpha=alpha end
        position(label,x,y)
        if label.hidden then label:Show();label.hidden=false end
    end
    return function(g,now)
        for _,pool in ipairs(pools) do pool.used=0 end
        texts=0
        local p=g and g.p
        camX=p and p.x+sin(now*85)*g.shake*.4 or now*9
        camY=p and p.y-20+cos(now*93)*g.shake*.4 or 0
        local u,v=((camX-W/2)%512)/512,((camY-H/2)%512)/512
        if floorTex.lastU~=u or floorTex.lastV~=v then
            floorTex:SetTexCoord(u,u+W/512,v,v+H/512);floorTex.lastU,floorTex.lastV=u,v
        end
        if g then
            for _,q in ipairs(g.decals) do draw(1,"disc",q.x,q.y,q.r*2,q.r*.8,"#100908",.55) end
            for _,q in ipairs(g.zones) do
                if q.delay<=0 then draw(1,"mist",q.x,q.y,q.r*2,q.r*2,zoneColor[q.sc],min(1,q.l*2))
                else local f=bounded(1-q.delay/.35);sprite(3,"flask",q.sx+(q.x-q.sx)*f,q.sy+(q.y-q.sy)*f-sin(f*math.pi)*60) end
            end
            for _,q in ipairs(g.auras) do draw(1,"ring",p.x,p.y-9,q.r*2,q.r*2,q.col,.45) end
            for _,q in ipairs(g.haz) do draw(1,"ring",q.x,q.y,q.r*2,q.r*2,"#a4db74",.5+sin(now*22)*.3) end
            for _,q in ipairs(g.pend) do draw(1,"ring",q.x,q.y,q.r*2,q.r*2,"#f29353",.8) end
            for _,q in ipairs(g.mines) do sprite(1,"trap",q.x,q.y,nil,q.arm>0 and .5 or 1) end
            for _,q in ipairs(g.gems) do sprite(1,q.v>=8 and "gem2" or q.v>=3 and "gem1" or "gem0",q.x,q.y+5+sin(now*4+q.ph)*2) end
            for _,q in ipairs(g.items) do sprite(1,q.k,q.x,q.y+sin(now*5)*2) end
        end
        local x0,x1=floor((camX-W/2-70)/230),floor((camX+W/2+70)/230)
        local y0,y1=floor((camY-H/2-140)/230),floor((camY+H/2+140)/230)
        if left~=x0 or right~=x1 or top~=y0 or bottom~=y1 then
            left,right,top,bottom=x0,x1,y0,y1
            scenery={}
            for cx=x0,x1 do
              for cy=y0,y1 do
                if hash(cx,cy)<.62 and (cx~=0 or cy~=0) then
                    scenery[#scenery+1]={prop=props[1+floor(hash(cx+91,cy-17)*#props)],x=cx*230+hash(cx*3,cy*5)*170,y=cy*230+hash(cy,cx)*170}
                end
              end
            end
        end
        local n=#scenery
        for i=1,n do depth[i]=scenery[i] end
        if g then
            for _,e in ipairs(g.en) do
                if abs(e.x-camX)<W/2+65 and abs(e.y-camY)<H/2+140 then n=n+1;depth[n]=e end
            end
            n=n+1;depth[n]=p
        end
        for i=#depth,n+1,-1 do depth[i]=nil end
        table.sort(depth,byDepth)
        for _,o in ipairs(depth) do
            if o.prop then sprite(2,o.prop,o.x,o.y)
            elseif o==p then
                local bob=p.moving and abs(sin(p.walk))*3 or sin(now*2.4)*.8
                draw(2,"disc",p.x,p.y,30,10,"#080606",.65)
                sprite(2,"hero"..g.id,p.x,p.y-bob,p.fx<0,p.inv>0 and floor(now*20)%2==1 and .5 or 1)
                if p.up.barrera and g.shield>=12 then draw(2,"ring",p.x,p.y-18,44,60,"#95c9e8",.65) end
            else
                local s=o.T.s
                local wob=sin(now*(o.T.fly and 14 or 8)+o.ph)
                local h=s.h*(1+wob*.035)
                draw(2,"disc",o.x,o.y,o.T.r*2,o.T.r*.7,o.slow>0 and "#365875" or "#080606",.6)
                if o.T.charge and o.lock==1 and o.at>=.7 and o.at<1.4 then line(o.x,o.y,o.x+o.cx*190,o.y+o.cy*190,8,"#a82828",.4) end
                draw(2,o.type..(o.flash>0 and "Hit" or ""),o.x,o.y-h/2+3+(o.T.fly and wob*3 or 0),s.w,h,nil,o.T.alpha,o.fx<0)
                if o.T.elite then
                    local w=o.T.boss and 90 or 56
                    draw(2,"Solid",o.x,o.y+9,w,5,"#160d0b")
                    local f=bounded(o.hp/o.max)
                    draw(2,"Solid",o.x-w*(1-f)/2,o.y+9,w*f,3,"#dd5343")
                end
            end
        end
        if g then
            for _,o in ipairs(g.orbs) do
                local key=o.k=="g" and "dagger" or (o.k.oi==1 and "icon_cuervos" or o.k.oi==2 and "icon_escudos" or "censer")
                draw(3,key,o.x,o.y,25,25)
            end
            for _,b in ipairs(g.proj) do
                local key=projectile[b.kind] or "disc"
                local blade=key=="dagger"
                draw(3,key,b.x,b.y,blade and 30 or b.r*2,blade and 10 or b.r*2,key=="disc" and (b.col or "#f2c14e") or nil,1,nil,blade and -b.a or 0)
            end
            for _,b in ipairs(g.eproj) do draw(3,b.ar and "dagger" or "disc",b.x,b.y,b.ar and 26 or 15,b.ar and 9 or 15,"#ff806b",1,nil,-math.atan2(b.vy,b.vx)) end
            for _,s in ipairs(g.slashes) do draw(3,s.arc<.5 and "stab" or s.arc>3 and "ring" or "arc",s.x,s.y,s.R*2,s.R*2,s.col,min(1,s.l*8),nil,-s.a) end
            for _,b in ipairs(g.beams) do line(b.x,b.y,b.x+cos(b.a)*b.len,b.y+sin(b.a)*b.len,b.wd,"#ffe5a4",bounded(b.l*5)) end
            for _,b in ipairs(g.bolts) do for i=1,#b.pts-2,2 do line(b.pts[i],b.pts[i+1],b.pts[i+2],b.pts[i+3],3,b.col or "#fff6dc",bounded(b.l/b.l0)) end end
            for _,b in ipairs(g.rings) do local d=b.r*2*(1-.7*b.l/b.l0);draw(3,"ring",b.x,b.y,d,d*.8,b.col,bounded(b.l/b.l0)) end
            for _,q in ipairs(g.parts) do draw(3,"disc",q.x,q.y,q.r*2,q.r*2,q.c) end
            for _,q in ipairs(g.nums) do number(q) end
            local bright=g.flash>.02
            local opacity=bright and bounded(g.flash)*.25 or max(g.hurt*.26,p.hp/p.maxhp<.3 and .09 or 0)
            if opacity~=flash.lastOpacity or bright~=flash.bright then
                if opacity>0 then
                    if bright then flash:SetColorTexture(1,.85,.6,opacity) else flash:SetColorTexture(.65,.06,.03,opacity) end
                    if (flash.lastOpacity or 0)==0 then flash:Show() end
                elseif (flash.lastOpacity or 0)>0 then flash:Hide() end
                flash.lastOpacity,flash.bright=opacity,bright
            end
        end
        for _,pool in ipairs(pools) do
            for i=pool.used+1,pool.previous or 0 do pool[i]:Hide();pool[i].hidden=true end
            pool.previous=pool.used
        end
        for i=texts+1,lastTexts do fonts[i]:Hide();fonts[i].hidden=true end
        lastTexts=texts
    end
end
