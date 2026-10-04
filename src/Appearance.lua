-- Independently owned light and UI overlay. All calls run on the game thread.
local M={}
local function valid(o) return o~=nil and o:IsValid() end
local function same(a,b) return valid(a) and valid(b) and a:GetAddress()==b:GetAddress() end
local function need(o,label) assert(valid(o),'Unavailable '..label);return o end
local transform={Rotation={X=0,Y=0,Z=0,W=1},Translation={X=30,Y=0,Z=45},Scale3D={X=1,Y=1,Z=1}}
-- Reuse the game's vampire veins and alpha fade, independently of hunger/health.
local texturePath='/Game/_Dawnwalker/Player/VampireHunger/Material/Textures/T_BloodHunger_Stretched.T_BloodHunger_Stretched'
local function object(path) return need(StaticFindObject(path),path) end
local function signature(path,expected)
    local fn=object(path);local index=0
    fn:ForEachProperty(function(p)
        index=index+1
        local spec=expected[index]
        assert(spec and p:GetFName():ToString()==spec[1]
            and p:GetFullName():match('^(%S+)')==spec[2],'Unsupported signature: '..path)
    end)
    assert(index==#expected,'Incomplete signature: '..path)
end
function M.new(report)
    local light,host,image,owner,controller
    local hidden=false
    local lightReady=false
    local lightAttempted,overlayAttempted=false,false
    local lightCleanup,overlayCleanup=0,0
    local mode,brightness,radius,red,vignette,opacity
    local api={}
    local function releaseLight()
        if valid(light) then
            if lightCleanup>=3 then return false end
            lightCleanup=lightCleanup+1
            -- The component was returned by our AddComponentByClass call only.
            light:SetVisibility(false,false)
            light:K2_DestroyComponent(owner)
        end
        light=nil
        lightReady=false
        lightCleanup=0
    end
    local function releaseOverlay()
        if valid(host) then
            if overlayCleanup>=3 then return false end
            overlayCleanup=overlayCleanup+1
            host:RemoveFromParent()
        end
        host=nil;image=nil
        overlayCleanup=0
    end
    local function safe(label,fn)
        local ok,err=pcall(fn)
        if not ok then report(label..': '..tostring(err)) end
        return ok and err~=false
    end
    function api.release()
        local a=safe('Radius cleanup',releaseLight)
        local b=safe('Vignette cleanup',releaseOverlay)
        if a and b then
            owner=nil;controller=nil;mode=nil;brightness=nil;radius=nil;red=nil;vignette=nil;opacity=nil
            hidden=false
            lightAttempted=false;overlayAttempted=false
        end
        return a and b
    end
    function api.hide()
        if hidden then return end
        local a=safe('Radius hiding',function() if valid(light) then light:SetVisibility(false,false) end end)
        local b=safe('Vignette hiding',function() if valid(host) then host:SetVisibility(1) end end)
        if not a then safe('Radius cleanup',releaseLight) end
        if not b then safe('Vignette cleanup',releaseOverlay) end
        hidden=true
    end
    local function updateLight()
        light:SetIntensity(6.75*brightness/100)
        light:SetAttenuationRadius(radius*100) -- Unreal centimetres.
        light:SetLightColor({R=1,G=1-red/100,B=1-red/100,A=1},false)
    end
    local function makeLight()
        -- Validate the creation/cleanup contract before creating a component.
        signature('/Script/Engine.Actor:AddComponentByClass',{
            {'Class','ClassProperty'},{'bManualAttachment','BoolProperty'},
            {'RelativeTransform','StructProperty'},{'bDeferredFinish','BoolProperty'},{'ReturnValue','ObjectProperty'}})
        signature('/Script/Engine.Actor:FinishAddComponent',{
            {'Component','ObjectProperty'},{'bManualAttachment','BoolProperty'},{'RelativeTransform','StructProperty'}})
        signature('/Script/Engine.ActorComponent:K2_DestroyComponent',{{'Object','ObjectProperty'}})
        local class=object('/Script/Engine.PointLightComponent')
        light=need(owner:AddComponentByClass(class,false,transform,true),'radius light')
        assert(same(light:GetOwner(),owner),'Radius owner changed')
        light:SetVisibility(false,false)
        light:SetMobility(2) -- Movable; attachment follows the pawn without Lua updates.
        light:SetUseTemperature(false)
        light:SetUseInverseSquaredFalloff(false)
        light:SetLightFalloffExponent(8)
        -- No self-shadow from the body enclosing the light, fog glow or indirect spill.
        light:SetCastShadows(false)
        light:SetIndirectLightingIntensity(0)
        light:SetVolumetricScatteringIntensity(0)
        updateLight()
        owner:FinishAddComponent(light,false,transform)
        light:SetVisibility(true,false)
        lightReady=true
    end
    local function makeOverlay()
        assert(type(StaticConstructObject)=='function','StaticConstructObject missing')
        signature('/Script/UMG.Image:SetBrushFromTexture',{{'Texture','ObjectProperty'},{'bMatchSize','BoolProperty'}})
        signature('/Script/UMG.Image:SetColorAndOpacity',{{'InColorAndOpacity','StructProperty'}})
        local texture=StaticFindObject(texturePath)
        if not valid(texture) and type(LoadAsset)=='function' then
            texture=LoadAsset(texturePath)
            if not valid(texture) then texture=StaticFindObject(texturePath) end
        end
        if not valid(texture) then
            local loader=object('/Script/Engine.Default__KismetSystemLibrary')
            texture=loader:LoadAsset_Blocking(loader:Conv_SoftObjPathToSoftObjRef(loader:MakeSoftObjectPath(texturePath)))
        end
        need(texture,'vampire vignette texture')
        assert(texture:IsA(object('/Script/Engine.Texture2D')),'Unsupported vampire vignette texture')
        local library=object('/Script/UMG.Default__WidgetBlueprintLibrary')
        host=need(library:Create(controller,object('/Script/CommonUI.CommonActivatableWidget'),controller),'vignette host')
        -- This visual-only widget never activates, registers Back, or takes focus.
        host.bIsBackHandler=false;host.bIsBackActionDisplayedInActionBar=false
        host.bAutoActivate=false;host.bIsModal=false
        host.bSupportsActivationFocus=false;host.bAutoRestoreFocus=false
        local tree=need(host.WidgetTree,'vignette WidgetTree')
        local canvas=need(StaticConstructObject(object('/Script/UMG.CanvasPanel'),tree),'vignette canvas')
        tree.RootWidget=canvas
        canvas:SetClipping(1)
        image=need(StaticConstructObject(object('/Script/UMG.Image'),tree),'vignette image')
        local slot=need(canvas:AddChildToCanvas(image),'vignette slot')
        -- One continuous alpha mask, enlarged around its clear upper centre.
        -- All four quad edges stay outside the viewport: no interior clip seam.
        slot:SetAnchors({Minimum={X=-0.15,Y=-0.2},Maximum={X=1.15,Y=1.8}})
        slot:SetOffsets({Left=0,Top=0,Right=0,Bottom=0})
        image:SetBrushFromTexture(texture,false)
        image:SetColorAndOpacity({R=1,G=0.08,B=0.12,A=1})
        image:SetRenderOpacity(opacity/100)
        host:SetVisibility(3) -- HitTestInvisible: neither the host nor children intercept input.
        host:AddToViewport(-10)
    end
    function api.sync(scope,settings,inspect)
        if not same(owner,scope.pawn) or not same(controller,scope.pc) then
            if not api.release() then return end
            owner=scope.pawn;controller=scope.pc
        end
        local lightChanged=mode~=settings.nightVisionMode or brightness~=settings.brightnessPercent
            or radius~=settings.radiusMeters or red~=settings.redMonochrome
        local overlayChanged=vignette~=settings.vignette or opacity~=settings.vignetteOpacity
        mode=settings.nightVisionMode;brightness=settings.brightnessPercent
        radius=settings.radiusMeters;red=settings.redMonochrome
        vignette=settings.vignette;opacity=settings.vignetteOpacity
        if lightChanged then lightAttempted=false;lightCleanup=0 end
        if overlayChanged then overlayAttempted=false;overlayCleanup=0 end
        if inspect then
            if light and not valid(light) then light=nil;lightAttempted=false end
            if host and not valid(host) then host=nil;image=nil;overlayAttempted=false end
            if image and not valid(image) then overlayAttempted=false end
        end
        if mode~=0 then
            if light then safe('Radius cleanup',releaseLight) end
        elseif not lightAttempted then
            lightAttempted=true
            local ok=safe('Radius unavailable; Fullscreen remains selectable',function()
                if valid(light) and lightReady then
                    updateLight();light:SetVisibility(true,false)
                else assert(releaseLight()~=false,'Radius cleanup incomplete');makeLight() end
            end)
            if not ok then safe('Radius cleanup',releaseLight) end
        end
        if vignette~=1 or opacity==0 then
            if host then safe('Vignette cleanup',releaseOverlay) end
        elseif not overlayAttempted then
            overlayAttempted=true
            local ok=safe('Red vignette unavailable; other vision effects remain enabled',function()
                if valid(host) and valid(image) then
                    image:SetRenderOpacity(opacity/100)
                else assert(releaseOverlay()~=false,'Vignette cleanup incomplete');makeOverlay() end
            end)
            if not ok then safe('Vignette cleanup',releaseOverlay) end
        end
        if hidden then
            safe('Radius resume',function() if valid(light) and lightReady and mode==0 then light:SetVisibility(true,false) end end)
            safe('Vignette resume',function() if valid(host) and vignette==1 and opacity>0 then host:SetVisibility(3) end end)
            hidden=false
        end
    end
    return api
end
return M
