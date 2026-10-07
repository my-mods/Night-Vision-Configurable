-- Owns only the original Radius post-process component. Game-thread calls only.
local M={}
local base='/Game/NightVisionConfigurable/BP_RadiusVisionComponent.BP_RadiusVisionComponent_C'
local transform={Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}}
local function valid(o) return o~=nil and o:IsValid() end
local function same(a,b) return valid(a) and valid(b) and a:GetAddress()==b:GetAddress() end
local function need(o,label) assert(valid(o),'Unavailable '..label);return o end
local function object(path) return need(StaticFindObject(path),path) end
local function signature(path,expected,blueprint)
    local count=0
    object(path):ForEachProperty(function(p)
        count=count+1
        local spec=expected[count]
        assert(spec and p:GetFName():ToString()==spec[1]
            and p:GetFullName():match('^(%S+)')==spec[2],'Unsupported signature: '..path)
        -- Owned Blueprint functions place parameters before generated locals.
        -- ForEachProperty includes both; UE4SS separately enforces NumParms
        -- when invoking the function, before marshalling or ProcessEvent.
        if blueprint and count==#expected then return true end
    end)
    assert(count==#expected,'Incomplete signature: '..path)
end
function M.new(report)
    local component,owner,camera
    local attempts,cleanupAttempts=0,0
    local reported=false
    local brightness,radius,tint,logging
    local retiring=false
    local requestedPawn,requestedCamera,requestedBrightness,requestedRadius,requestedTint,requestedLogging
    local api={}
    local function diagnostic(reason)
        if reported then return end
        reported=true
        report('Radius unavailable; Natural and Fullscreen remain available: '..tostring(reason))
    end
    function api.release()
        retiring=true
        if valid(component) then
            if cleanupAttempts>=3 then return false end
            cleanupAttempts=cleanupAttempts+1
            -- Attempt destruction even if disabling or a partial setter fails.
            pcall(function() component:SetComponentTickEnabled(false) end)
            local disabled=pcall(function() component.bEnabled=false end)
            local zeroed=pcall(function() component.BlendWeight=0 end)
            local destroyed,err=pcall(function() component:K2_DestroyComponent(owner) end)
            if not destroyed then
                diagnostic(err)
                -- Retain ownership for a bounded retry; never create another copy.
                return false
            end
            if not disabled and not zeroed and valid(component) then
                diagnostic('Component did not disable or complete destruction')
                return false
            end
        end
        component=nil;owner=nil;camera=nil
        brightness=nil;radius=nil;tint=nil;logging=nil
        cleanupAttempts=0
        retiring=false
        return true
    end
    function api.reset()
        if not api.release() then return false end
        attempts=0;reported=false
        requestedPawn=nil;requestedCamera=nil;requestedBrightness=nil;requestedRadius=nil;requestedTint=nil;requestedLogging=nil
        return true
    end
    local function configure(settings)
        component:ConfigureRadius(settings.brightnessPercent,settings.radiusMeters,settings.redMonochrome)
        component:ConfigureRadiusLogging(settings.logLevel==4)
    end
    local function create(pawn,target,settings)
        signature('/Script/Engine.Actor:AddComponentByClass',{
            {'Class','ClassProperty'},{'bManualAttachment','BoolProperty'},
            {'RelativeTransform','StructProperty'},{'bDeferredFinish','BoolProperty'},{'ReturnValue','ObjectProperty'}})
        signature('/Script/Engine.Actor:FinishAddComponent',{
            {'Component','ObjectProperty'},{'bManualAttachment','BoolProperty'},{'RelativeTransform','StructProperty'}})
        signature('/Script/Engine.ActorComponent:K2_DestroyComponent',{{'Object','ObjectProperty'}})
        local class=StaticFindObject(base)
        if not valid(class) then
            -- UE4SS LoadAsset queries the game's asset registry, which does not
            -- contain this original mod package. Resolve the mounted class directly.
            local library='/Script/Engine.KismetSystemLibrary'
            signature(library..':MakeSoftClassPath',{{'PathString','StrProperty'},{'ReturnValue','StructProperty'}})
            signature(library..':Conv_SoftClassPathToSoftClassRef',{{'SoftClassPath','StructProperty'},{'ReturnValue','SoftClassProperty'}})
            signature(library..':LoadClassAsset_Blocking',{{'AssetClass','SoftClassProperty'},{'ReturnValue','ClassProperty'}})
            local system=object('/Script/Engine.Default__KismetSystemLibrary')
            local path=system:MakeSoftClassPath(base)
            local reference=system:Conv_SoftClassPathToSoftClassRef(path)
            class=system:LoadClassAsset_Blocking(reference)
        end
        need(class,'cooked Radius helper class after direct load: '..base)
        signature(base..':InitializeRadius',{{'ReturnValue','BoolProperty'}},true)
        signature(base..':ConfigureRadius',{{'BrightnessPercent','FloatProperty'},
            {'RadiusMeters','FloatProperty'},{'RedTintPercent','FloatProperty'}},true)
        signature(base..':ConfigureRadiusLogging',{{'Enabled','BoolProperty'}},true)
        need(StaticFindObject(base..':UpdateRadiusOrigin'),'Radius origin update')
        signature('/Script/Engine.ActorComponent:SetComponentTickEnabled',{{'bEnabled','BoolProperty'}})
        owner=pawn;camera=target
        component=need(owner:AddComponentByClass(class,true,transform,true),'Radius component')
        assert(same(component:GetOwner(),owner),'Radius component owner changed')
        assert(component:IsA(object('/Script/Engine.PostProcessComponent')),'Unsupported Radius component type')
        assert(component.bEnabled==false and component.bUnbound==true
            and component.BlendWeight==1,'Unsupported Radius component defaults')
        assert(component:InitializeRadius()==true,'Radius material initialization failed')
        configure(settings)
        component:UpdateRadiusOrigin()
        owner:FinishAddComponent(component,true,transform)
        component:SetComponentTickEnabled(true)
        component.bEnabled=true
        assert(component.bEnabled==true,'Radius component could not enable')
    end
    function api.sync(pawn,target,settings,inspect)
        if settings.nightVisionMode~=0 or not valid(pawn) or not valid(target) then
            return api.reset()
        end
        if retiring and not api.release() then return false end
        if not same(requestedPawn,pawn) or not same(requestedCamera,target) then
            if not api.release() then return false end
            attempts=0
        elseif requestedBrightness~=settings.brightnessPercent or requestedRadius~=settings.radiusMeters
            or requestedTint~=settings.redMonochrome or requestedLogging~=settings.logLevel then
            attempts=0
        end
        requestedPawn=pawn;requestedCamera=target;requestedBrightness=settings.brightnessPercent
        requestedRadius=settings.radiusMeters;requestedTint=settings.redMonochrome;requestedLogging=settings.logLevel
        local changed=brightness~=settings.brightnessPercent or radius~=settings.radiusMeters
            or tint~=settings.redMonochrome or logging~=settings.logLevel
        if component and inspect and not valid(component) then component=nil end
        if valid(component) and not changed then return true end
        if not valid(component) and (attempts>=3 or (attempts>0 and not inspect)) then return false end
        if not valid(component) then attempts=attempts+1 end
        local ok,err=pcall(function()
            if valid(component) then
                configure(settings)
            else
                create(pawn,target,settings)
            end
            brightness=settings.brightnessPercent;radius=settings.radiusMeters;tint=settings.redMonochrome;logging=settings.logLevel
            attempts=0 -- Successful recreation after a menu is not a failed retry.
        end)
        if not ok then diagnostic(err);api.release();return false end
        return true
    end
    function api.diagnostics()
        if logging~=4 or not valid(component) then return nil end
        local ok,result=pcall(function()
            local checks,writes=component.RadiusChecks,component.RadiusWrites
            assert(type(checks)=='number' and type(writes)=='number')
            return string.format('Radius movement checks: %d, material origin writes: %d (current component).',checks,writes)
        end)
        if ok then return result end
        diagnostic(result)
    end
    function api.active() return valid(component) end
    return api
end
return M
