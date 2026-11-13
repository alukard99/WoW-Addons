local _, V = ...
local playing,stage,endsAt
local cool = {}
function V.sound(kind)
    if not V.db or V.db.muted then return end
    local now=GetTime()
    if now < (cool[kind] or 0) then return end
    cool[kind]=now+(kind=="hit" and .10 or kind=="gem" and .07 or .03)
    PlaySoundFile(V.media..kind..".ogg","SFX")
end
function V.silence()
    if playing then StopSound(playing,150) end
    playing,stage,endsAt=nil,nil,nil
end
function V.music(now)
    if V.db.muted or V.db.musicOff then
        if stage then V.silence() end
        return
    end
    local g=V.game
    local nextStage=0
    if g and (V.state=="play" or V.state=="pause" or V.state=="levelup") then
        nextStage=(g.endless or g.t>235) and 4 or g.t>150 and 3 or g.t>60 and 2 or 1
    end
    if stage~=nextStage or now>=endsAt then
        V.silence()
        local ok,handle=PlaySoundFile(V.media.."Night"..nextStage..".ogg","Music")
        playing=ok and handle or nil
        stage,endsAt=nextStage,now+128*60/84/4
    end
end
