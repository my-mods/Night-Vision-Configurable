-- Camera-local post-processing. Only owned numeric snapshots survive a callback.
local M = {}
local vectors = {ColorSaturation={'X','Y','Z','W'},SceneColorTint={'R','G','B','A'}}
local names = {'AutoExposureBias','BloomIntensity','BloomThreshold','ColorSaturation'}
local function valid(o) return o ~= nil and o:IsValid() end
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function equal(a,b)
    if type(a)=='table' then
        if type(b)~='table' then return false end
        if a.isObject then
            if not b.isObject then return false end
            local av,bv=valid(a.reference),valid(b.reference)
            return (not av and not bv) or (av and bv and a.reference:GetAddress()==b.reference:GetAddress())
        end
        for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
        return true
    end
    if type(a)=='number' and type(b)=='number' then return math.abs(a-b)<=1e-5 end
    return a==b
end
local function read(pp,name)
    if name=='ColorGradingLUT' then return {isObject=true,reference=pp[name]} end
    if not vectors[name] then
        local v=pp[name]; assert(finite(v),'Missing/non-numeric '..name); return v
    end
    local out, field = {}, pp[name]
    for _,k in ipairs(vectors[name]) do
        local v=field[k]; assert(finite(v),'Missing '..name..' component '..k); out[k]=v
    end
    return out
end
local function write(pp,name,value)
    if name=='ColorGradingLUT' then
        if not equal(read(pp,name),value) then pp[name]=value.reference end
    elseif type(value)=='table' then
        local field=pp[name]
        for k,v in pairs(value) do if not equal(field[k],v) then field[k]=v end end
    elseif not equal(pp[name],value) then pp[name]=value end
end
local function partial(value,target,before)
    if type(target)=='table' and target.isObject then return equal(value,target) or equal(value,before) end
    if type(target)=='table' then
        for k,v in pairs(target) do if not partial(value[k],v,before[k]) then return false end end
        return true
    end
    return equal(value,target) or equal(value,before)
end
function M.new(report,directory)
    local held
    local bloodTexture=require('BloodColour').new(directory)
    local api = {}
    local function sameCamera(h)
        return valid(h.camera) and h.camera:GetAddress()==h.address
            and h.camera:GetFullName()==h.name and valid(h.owner)
            and valid(h.camera:GetOwner()) and h.camera:GetOwner():GetAddress()==h.owner:GetAddress()
    end
    function api.active() return held ~= nil end
    function api.camera() return held and held.camera end
    function api.release()
        local h=held
        if not h then return end
        if not sameCamera(h) then held=nil; return end
        local pp=h.camera.PostProcessSettings
        local failures={}
        for _,name in ipairs(h.names) do
            local field=h.fields[name]
            if field.last then
                local ok,err=pcall(function()
                    -- A later external write owns the entire property/override pair.
                    local value,flag=read(pp,name),pp['bOverride_'..name]
                    local owned=equal(value,field.last.value) and flag==field.last.override
                    if field.restoring then
                        owned=partial(value,field.last.value,field.value)
                            and (flag==field.last.override or flag==field.override)
                    elseif field.pending then
                        owned=partial(value,field.last.value,field.pending.value)
                            and (flag==field.last.override or flag==field.pending.override)
                    end
                    if owned then
                        field.restoring=true
                        write(pp,name,field.value)
                        pp['bOverride_'..name]=field.override
                    end
                    field.last=nil;field.pending=nil;field.restoring=nil
                end)
                if not ok then failures[#failures+1]=name..': '..tostring(err) end
            end
        end
        if h.lastWeight and equal(h.camera.PostProcessBlendWeight,h.lastWeight) then
            h.camera.PostProcessBlendWeight=h.weight
        end
        if #failures>0 then error('Restoration failed: '..table.concat(failures,', ')) end
        held=nil
    end
    function api.capture(camera)
        assert(not held,'Previous camera still owned')
        assert(valid(camera) and camera:IsActive() and valid(camera:GetOwner()),'Inactive camera')
        local pp=camera.PostProcessSettings
        local h={camera=camera,address=camera:GetAddress(),name=camera:GetFullName(),owner=camera:GetOwner(),fields={},names={}}
        h.weight=camera.PostProcessBlendWeight
        assert(finite(h.weight),'Missing camera blend weight')
        -- Validate every required field before writing any property.
        for _,name in ipairs(names) do
            local flag=pp['bOverride_'..name]
            assert(type(flag)=='boolean','Missing override flag '..name)
            h.fields[name]={value=read(pp,name),override=flag}
            h.names[#h.names+1]=name
        end
        -- Missing tint support must not disable Radius illumination or B&W.
        local ok,tint=pcall(function()
            local flag=pp.bOverride_SceneColorTint;assert(type(flag)=='boolean')
            return {value=read(pp,'SceneColorTint'),override=flag}
        end)
        if ok then h.fields.SceneColorTint=tint;h.names[#h.names+1]='SceneColorTint' end
        held=h
    end
    function api.apply(settings, pulse)
        local h=assert(held,'No camera'); assert(sameCamera(h),'Camera replaced')
        local pp=h.camera.PostProcessSettings
        -- Natural owns its colour treatment inside the oval material. Restore
        -- our camera overrides on mode changes; retain other effects' baselines.
        local monochrome=settings.nightVisionMode==2 and 0 or settings.monochrome
        local keepRed=settings.keepBloodRed==1 and monochrome>0
        if not keepRed or h.lutBrightness~=settings.redBrightnessPercent then h.lutAttempted=nil end
        if keepRed and not h.lutAttempted then
            h.lutAttempted=true
            h.lutBrightness=settings.redBrightnessPercent
            local ok,value=pcall(function()
                if not h.fields.ColorGradingLUT then
                    local fields={}
                    for _,name in ipairs({'ColorGradingLUT','ColorGradingIntensity'}) do
                        local flag=pp['bOverride_'..name]
                        assert(type(flag)=='boolean','Missing override flag '..name)
                        fields[name]={value=read(pp,name),override=flag}
                    end
                    for _,name in ipairs({'ColorGradingLUT','ColorGradingIntensity'}) do
                        h.fields[name]=fields[name];h.names[#h.names+1]=name
                    end
                end
                -- A Lua wrapper does not keep an Unreal texture alive. Do not
                -- displace another effect's LUT and risk losing its only owner.
                assert(not valid(h.fields.ColorGradingLUT.value.reference),'The camera already uses another colour lookup texture')
                return bloodTexture(h.owner,settings.redBrightnessPercent)
            end)
            if ok then h.lut=value
            else h.lut=nil;report('Keep blood red unavailable; regular Black & White remains active: '..tostring(value)) end
        end
        keepRed=keepRed and valid(h.lut)
        -- A game effect can replace these values without replacing the camera.
        -- Adopt only externally changed values as the new restoration baseline.
        local weight=h.camera.PostProcessBlendWeight
        assert(finite(weight),'Missing camera blend weight')
        if h.lastWeight and not equal(weight,h.lastWeight) then h.weight=weight end
        for _,name in ipairs(h.names) do
            local field=h.fields[name]
            local value,flag=read(pp,name),pp['bOverride_'..name]
            assert(type(flag)=='boolean','Missing override flag '..name)
            if field.last then
                if not equal(value,field.last.value) then field.value=value;field.override=flag end
                if flag~=field.last.override then field.override=flag end
            end
        end
        if keepRed and valid(h.fields.ColorGradingLUT.value.reference) then
            keepRed=false
            report('Keep blood red suspended: another camera colour lookup texture takes priority; regular Black & White remains active.')
        end
        -- Brightness scales scene colour without replacing the game's exposure/bloom.
        -- Radius illumination and its red colour belong to the attached light only.
        local desired={}
        local fullscreen=settings.nightVisionMode==1
        local brightness=fullscreen and (settings.brightnessPercent/100)*2^((pulse or 0)*1.2) or 1
        local original=h.fields.ColorSaturation
        local red=fullscreen and settings.redMonochrome/100 or 0
        if (red>0 or brightness~=1) and not h.fields.SceneColorTint then
            red=0;brightness=1
            report('Fullscreen brightness/red tint unavailable: camera colour tint is unsupported; Radius and Black & White remain enabled.')
        end
        local fraction=keepRed and 0 or 1-(1-monochrome/100)*(1-red)
        if keepRed then
            desired.ColorGradingLUT={isObject=true,reference=h.lut}
            desired.ColorGradingIntensity=monochrome/100
        end
        if fraction>0 then
            local base=original.override and original.value or {X=1,Y=1,Z=1,W=1}
            desired.ColorSaturation={X=base.X*(1-fraction),Y=base.Y*(1-fraction),Z=base.Z*(1-fraction),W=base.W}
        end
        if red>0 or brightness~=1 then
            local tint=h.fields.SceneColorTint
            local base=tint.override and tint.value or {R=1,G=1,B=1,A=1}
            desired.SceneColorTint={R=base.R*brightness,G=base.G*(1-red)*brightness,B=base.B*(1-red)*brightness,A=base.A}
        end
        for _,name in ipairs(h.names) do
            local field=h.fields[name]
            local value=desired[name]
            local flag=true
            if not value then value=field.value; flag=field.override end
            -- Journal before attempting writes so a partial setter failure is recoverable.
            field.pending={value=read(pp,name),override=pp['bOverride_'..name]}
            field.last={value=value,override=flag}
            write(pp,name,value)
            if pp['bOverride_'..name]~=flag then pp['bOverride_'..name]=flag end
            assert(equal(read(pp,name),value) and pp['bOverride_'..name]==flag,'Write verification failed: '..name)
            field.pending=nil
        end
        local blend=(brightness~=1 or fraction>0 or keepRed) and 1 or h.weight
        h.lastWeight=blend
        if not equal(h.camera.PostProcessBlendWeight,blend) then h.camera.PostProcessBlendWeight=blend end
        assert(equal(h.camera.PostProcessBlendWeight,blend),'Blend weight write failed')
    end
    function api.refresh(settings)
        local h=assert(held,'No camera');assert(sameCamera(h),'Camera replaced')
        local pp=h.camera.PostProcessSettings
        local changed=not equal(h.camera.PostProcessBlendWeight,h.lastWeight)
        for _,name in ipairs(h.names) do
            local field=h.fields[name]
            if field.last and (not equal(read(pp,name),field.last.value)
                or pp['bOverride_'..name]~=field.last.override) then changed=true end
        end
        if changed then api.apply(settings,0) end
        return changed
    end
    return api
end
return M
