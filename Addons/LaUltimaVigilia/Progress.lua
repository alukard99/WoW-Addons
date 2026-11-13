local _, V = ...
local function stats(saved)
    local s=type(saved)=="table" and saved or {}
    for _,k in ipairs({"kills","time","lv","her","abb","wins"}) do s[k]=math.max(0,tonumber(s[k]) or 0) end
    return s
end
function V.loadSave()
    LaUltimaVigiliaDB=type(LaUltimaVigiliaDB)=="table" and LaUltimaVigiliaDB or {}
    local db=LaUltimaVigiliaDB
    db.g=stats(db.g)
    db.c=type(db.c)=="table" and db.c or {}
    for i=1,10 do db.c[i]=stats(db.c[i]) end
    db.runs=tonumber(db.runs) or 0
    db.sel=math.floor(math.max(0,math.min(99,tonumber(db.sel) or 0)))
    V.db=db
    if not V.available(db.sel) then db.sel=0 end
end
function V.clock(t)
    return ("%d:%02d"):format(math.floor(t/60),math.floor(t)%60)
end
function V.character(id)
    local c,t=V.CLS[math.floor(id/10)+1],V.TRT[id%10+1]
    return c.n.." "..t.e,c,t
end
function V.requirement(id)
    local c,t=math.floor(id/10)+1,id%10+1
    if t==1 then return V.CREQ[c],V.db.g end
    return V.TREQ[t],V.db.c[c],V.CLS[c].n
end
function V.available(id)
    local r,s=V.requirement(id)
    return not r or s[r.k]>=r.n
end
function V.count()
    local n=0
    for id=0,99 do if V.available(id) then n=n+1 end end
    return n
end
function V.lockText(id)
    local r,s,who=V.requirement(id)
    if not r then return "" end
    local number=r.k=="time" and V.clock or tostring
    local what={kills="Abate "..r.n.." enemigos en total",time="Sobrevive "..V.clock(r.n).." en una vigilia",
        lv="Alcanza el nivel "..r.n,her="Derrota a un Heraldo",abb="Derrota a la Abadesa Hueca",wins="Resiste hasta el alba"}
    return what[r.k]..(who and " jugando con "..who or "")..".  "..number(math.min(s[r.k],r.n)).." / "..number(r.n)
end
function V.commit(win)
    local g,db=V.game,V.db
    local before,new={},{}
    for id=0,99 do before[id]=V.available(id) end
    local previous=g.record or {kills=0,her=0,abb=0}
    for _,s in ipairs({db.g,db.c[math.floor(g.id/10)+1]}) do
        for _,k in ipairs({"kills","her","abb"}) do s[k]=s[k]+g[k]-previous[k] end
        s.lv=math.max(s.lv,g.p.lv);s.time=math.max(s.time,math.floor(g.t))
        if win and not previous.win then s.wins=s.wins+1 end
    end
    if not g.record then db.runs=db.runs+1 end
    g.record={kills=g.kills,her=g.her,abb=g.abb,win=previous.win or win}
    for id=0,99 do if not before[id] and V.available(id) then new[#new+1]=V.character(id) end end
    return new
end
