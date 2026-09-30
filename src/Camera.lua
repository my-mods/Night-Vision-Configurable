-- Camera-local post-processing. Only owned numeric snapshots survive a callback.
local M = {}
local components = {X=true,Y=true,Z=true,W=true}
local names = {'AutoExposureBias','BloomIntensity','BloomThreshold','VignetteIntensity','ColorSaturation'}
local function valid(o) return o ~= nil and o:IsValid() end
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function equal(a,b)
    if type(a)=='table' then
        if type(b)~='table' then return false end
        for k,v in pairs(a) do if not equal(v,b[k]) then return false end end
        return true
    end
    if type(a)=='number' and type(b)=='number' then return math.abs(a-b)<=1e-5 end
    return a==b
end
local function read(pp,name)
    if name~='ColorSaturation' then
        local v=pp[name]; assert(finite(v),'Missing/non-numeric '..name); return v
    end
    local out, field = {}, pp[name]
    for k in pairs(components) do
        local v=field[k]; assert(finite(v),'Missing saturation component '..k); out[k]=v
    end
    return out
end
local function write(pp,name,value)
    if type(value)=='table' then
        local field=pp[name]
        for k,v in pairs(value) do if not equal(field[k],v) then field[k]=v end end
    elseif not equal(pp[name],value) then pp[name]=value end
end
local function partial(value,target,before)
    if type(target)=='table' then
        for k,v in pairs(target) do if not partial(value[k],v,before[k]) then return false end end
        return true
    end
    return equal(value,target) or equal(value,before)
end
function M.new(report)
    local held
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
        for _,name in ipairs(names) do
            local field=h.fields[name]
            if field.last then
                local ok,err=pcall(function()
                    -- A later external write owns the entire property/override pair.
                    local value,flag=read(pp,name),pp['bOverride_'..name]
                    local owned=equal(value,field.last.value) and flag==field.last.override
                    if field.pending then
                        owned=partial(value,field.last.value,field.pending.value)
                            and (flag==field.last.override or flag==field.pending.override)
                    end
                    if owned then
                        write(pp,name,field.value)
                        pp['bOverride_'..name]=field.override
                    end
                    field.last=nil;field.pending=nil
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
        local h={camera=camera,address=camera:GetAddress(),name=camera:GetFullName(),owner=camera:GetOwner(),fields={}}
        h.weight=camera.PostProcessBlendWeight
        assert(finite(h.weight),'Missing camera blend weight')
        -- Validate every required field before writing any property.
        for _,name in ipairs(names) do
            local flag=pp['bOverride_'..name]
            assert(type(flag)=='boolean','Missing override flag '..name)
            h.fields[name]={value=read(pp,name),override=flag}
        end
        held=h
    end
    function api.apply(settings, pulse)
        local h=assert(held,'No camera'); assert(sameCamera(h),'Camera replaced')
        assert(not h.lastWeight or equal(h.camera.PostProcessBlendWeight,h.lastWeight),'Another effect changed camera blend weight')
        local pp=h.camera.PostProcessSettings
        local desired={AutoExposureBias=settings.brightness+(pulse or 0)*1.2,
            BloomIntensity=3+(pulse or 0)*2,BloomThreshold=0,VignetteIntensity=0.9}
        local original=h.fields.ColorSaturation
        local fraction=settings.monochrome/100
        if fraction>0 then
            local base=original.override and original.value or {X=1,Y=1,Z=1,W=1}
            desired.ColorSaturation={X=base.X*(1-fraction),Y=base.Y*(1-fraction),Z=base.Z*(1-fraction),W=base.W}
        end
        for _,name in ipairs(names) do
            local field=h.fields[name]
            local value=desired[name]
            local flag=true
            if not value then value=field.value; flag=field.override end
            if field.last and (not equal(read(pp,name),field.last.value) or pp['bOverride_'..name]~=field.last.override) then
                error('Another effect changed '..name..'; night vision stopped')
            end
            -- Journal before attempting writes so a partial setter failure is recoverable.
            field.pending={value=read(pp,name),override=pp['bOverride_'..name]}
            field.last={value=value,override=flag}
            write(pp,name,value)
            if pp['bOverride_'..name]~=flag then pp['bOverride_'..name]=flag end
            assert(equal(read(pp,name),value) and pp['bOverride_'..name]==flag,'Write verification failed: '..name)
            field.pending=nil
        end
        h.lastWeight=1
        if not equal(h.camera.PostProcessBlendWeight,1) then h.camera.PostProcessBlendWeight=1 end
        assert(equal(h.camera.PostProcessBlendWeight,1),'Blend weight write failed')
    end
    return api
end
return M
