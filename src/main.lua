-- Night Vision - Configurable. Runtime state only; no save-game writes.
local directory=assert(debug.getinfo(1,'S').source:match('^@(.+[\\/])'))
local settings={enabled=1,nightVisionMode=1,radiusMeters=6,naturalFocusSize=90,naturalSoftness=70,vignette=1,vignetteOpacity=20,
    monochrome=0,keepBloodRed=0,redBrightnessPercent=100,redMonochrome=0,brightnessPercent=200,brightnessCalculation=0,controllerInput=1,debugLogging=0}
local warnings={}
local warningCount=0
local function report(message)
    if warnings[message] or warningCount>=64 then return end
    warnings[message]=true;warningCount=warningCount+1
    print('[NightVisionConfigurable] '..message..'\n')
end
local function trace(message)
    if settings.debugLogging==1 then print('[NightVisionConfigurable] '..message..'\n') end
end
for _,name in ipairs({'ExecuteInGameThread','ExecuteInGameThreadWithDelay','CancelDelayedAction','RegisterHook','RegisterKeyBind'}) do
    if type(_G[name])~='function' then report('Required UE4SS API missing: '..name); return end
end
local function valid(o) return o~=nil and o:IsValid() end
local function same(a,b) return valid(a) and valid(b) and a:GetAddress()==b:GetAddress() end
local camera=require('Camera').new(report,directory)
local appearance=require('Appearance').new(report)
local natural=require('Natural').new(report)
local radius=require('Radius').new(report)
local inspection=require('Inspection').new(report)
local engine,gameplay,cameraClass,stickKey,vampireTag,uiManager
local scope,worker,timer,flashHandle
local loading,armed,latched,wanted=false,false,false,false
local holdStart,generation=0,0
local effectFailure,visualElapsed=nil,0
local reloadSettings
local hooks={}
local stats={count=0,elapsed=0,maximum=0,repairs=0}
local soundObjects,soundFunction,soundOrder={}
local wake,poll,toggle,syncVision

local function cancel(handle) if handle then CancelDelayedAction(handle) end end
local function endFlash() cancel(flashHandle);flashHandle=nil end
local function restoreCamera()
    endFlash()
    local ok,err=pcall(camera.release)
    if not ok then report(tostring(err));return false end
    return true
end
local function restore()
    local extras=appearance.release()
    natural.reset()
    radius.reset()
    local restored=restoreCamera()
    local inspected=inspection.reset()
    return restored and extras and inspected
end
local function clear()
    generation=generation+1
    cancel(timer);timer=nil
    if worker then cancel(worker.handle);worker=nil end
    restore()
    scope=nil;uiManager=nil;armed=false;latched=false;holdStart=0
    effectFailure=nil;visualElapsed=0
end
local function current(s)
    if loading or not s or not valid(engine) or not valid(gameplay) then return false end
    local viewport=engine.GameViewport
    return valid(viewport) and same(viewport:GetWorld(),s.world)
        and valid(s.pc) and same(s.pc:GetWorld(),s.world)
        and same(s.pc.Pawn,s.pawn) and same(s.pawn:GetWorld(),s.world)
end
local function supportsQuery(path,returnType)
    local ok,supported=pcall(function()
        local fn=StaticFindObject(path)
        if not valid(fn) then return false end
        local count,compatible=0,true
        fn:ForEachProperty(function(p)
            count=count+1
            compatible=compatible and p:GetFName():ToString()=='ReturnValue'
                and p:GetFullName():match('^(%S+)')==returnType
        end)
        return compatible and count==1
    end)
    return ok and supported
end
local function playState(s,reason)
    if s.playReason~=reason then
        s.playReason=reason
        if wanted and settings.debugLogging==1 then trace('Vision context: '..reason) end
    end
    return reason=='gameplay' or reason=='tower survey' or reason=='clue inspection' or reason=='scripted action'
end
local function playable(s,retainEffect)
    if gameplay:IsGamePaused(s.world) then return playState(s,'paused') end
    if s.pc.bShowMouseCursor==true then return playState(s,'mouse cursor') end
    local gameplayVisible=false
    if valid(uiManager) and same(uiManager:GetWorld(),s.world) then
        local ok,visible=pcall(function() return uiManager:ShouldShowGameplayWidgets() end)
        if ok and visible==false then return playState(s,'gameplay UI hidden') end
        gameplayVisible=ok and visible==true
        if not ok then uiManager=nil;report('Gameplay UI visibility unavailable; input/menu guards remain active.') end
    end
    if s.pc:IsMoveInputIgnored() then
        -- Investigation consumes its own input while normal move/look input is
        -- locked. The current local view must be the game's inspection camera.
        if inspection.matches(s.pc:GetViewTarget(),s.world) then return playState(s,'clue inspection') end
        -- Scouting locks walking while retaining the player's camera. Only this
        -- verified tower state may bypass movement locking; menus still win.
        if s.towerQueries then
            local ok,survey=pcall(function()
                local tower=s.pawn:GetActiveTower()
                return valid(tower) and same(tower:GetWorld(),s.world)
                    and s.pc:IsLookInputIgnored()==false
            end)
            if ok and survey then return playState(s,'tower survey') end
            if not ok then
                s.towerQueries=false
                report('Tower survey detection unavailable; movement/menu guards remain active.')
            end
        end
        -- Attacks and synchronised animations also lock movement. A confirmed
        -- gameplay view can retain an already enabled effect while input stays
        -- blocked. Missing UI state keeps the conservative fallback below.
        if gameplayVisible then
            return playState(s,'scripted action') and retainEffect==true
        end
        return playState(s,'movement locked')
    end
    return playState(s,'gameplay')
end
local function vampire(s)
    local asc=s.pawn.AbilitySystemComponent
    -- Missing/replacing ability data is not confirmation of human form.
    if not valid(asc) then return nil end
    local value=asc:HasMatchingGameplayTag(vampireTag)
    if type(value)=='boolean' then return value end
end
local function activeTarget(s)
    local target=s.pc:GetViewTarget()
    if not valid(target) or not same(target:GetWorld(),s.world) then inspection.reset();return nil end
    if inspection.matches(target,s.world) then
        local component,owner=inspection.target(s.pawn,target,s.world)
        return component,true,component and target or nil,owner
    end
    inspection.reset()
    local c=target:GetComponentByClass(cameraClass)
    if valid(c) and c:IsActive() and same(c:GetOwner(),target) then return c end
end
syncVision=function(pulse,inspect,scopeChecked)
    if not wanted or (not scopeChecked and not current(scope)) then return end
    local token=generation
    local form=vampire(scope)
    if token~=generation then return end
    if form==false then
        wanted=false;effectFailure=nil
        assert(restore(),'Camera restoration is incomplete')
        trace('Vision off: human form confirmed.')
        return
    end
    if form==nil then
        assert(restore(),'Effect restoration is incomplete')
        return
    end
    -- Preserve the toggle while menus/cutscenes hide every owned visual effect.
    if not playable(scope,true) then
        appearance.hide()
        natural.release()
        radius.release()
        assert(restoreCamera(),'Camera restoration is incomplete')
        inspection.release()
        return
    end
    local target,isInspection,visualTarget,visualOwner=activeTarget(scope)
    if token~=generation then return end
    visualTarget=visualTarget or target
    visualOwner=visualOwner or scope.pawn
    if form==true and visualTarget then appearance.sync(scope,settings,inspect)
    else appearance.release() end
    -- Natural owns a separate component; its failure must not suspend the
    -- separate vignette or either of the other vision modes.
    if settings.nightVisionMode==2 and form==true and visualTarget then
        if inspect or pulse~=nil then natural.sync(visualOwner,visualTarget,settings,inspect) end
    else natural.release() end
    if settings.nightVisionMode==0 and form==true and visualTarget then
        if inspect or pulse~=nil then radius.sync(visualOwner,visualTarget,settings,inspect) end
    else radius.release() end
    if effectFailure and (same(target,effectFailure.target)
        or (not valid(target) and not valid(effectFailure.target))) then
        if effectFailure.attempts>=3 or not inspect then return end
    else effectFailure=nil end
    local ok,err=pcall(function()
        if effectFailure then assert(restoreCamera(),'Camera restoration is incomplete') end
        if form==nil or not same(target,camera.camera()) then
            if camera.active() then assert(restoreCamera(),'Camera restoration is incomplete') end
        end
        if form~=true or not target then return end
        if not camera.active() then
            camera.capture(target,isInspection)
            camera.apply(settings,pulse or 0)
            trace('Vision applied to the current camera.')
        elseif pulse~=nil then camera.apply(settings,pulse)
        elseif inspect then
            local changed=camera.refresh(settings)
            if changed and settings.debugLogging==1 then stats.repairs=stats.repairs+1 end
        end
    end)
    if not ok then
        local attempts=effectFailure and effectFailure.attempts or 0
        effectFailure={target=target,attempts=attempts+1}
        restoreCamera()
        report('Camera effect suspended; toggle remains on: '..tostring(err))
    else effectFailure=nil end
end
local function sound(s,on)
    -- Optional sound uses the location overload; no delegate marshalling.
    local suffix=on and 'start' or 'end'
    local path='/Game/Audio/AK_Events/Events/UI/Gameplay/Focus_Mode/sfx_focusmode_'..suffix
    local function loaded(name)
        local value=soundObjects[name]
        if not valid(value)then value=StaticFindObject(name);soundObjects[name]=value end
        return value
    end
    local event=loaded(path..'.sfx_focusmode_'..suffix)
    local ak=loaded('/Script/AkAudio.Default__AkGameplayStatics')
    local fn=loaded('/Script/AkAudio.AkGameplayStatics:PostEventAtLocation')
    if not valid(event) or not valid(ak) or not valid(fn) then return end
    local order=soundOrder
    if not same(soundFunction,fn)then
    local expected={AkEvent='ObjectProperty',Location='StructProperty',orientation='StructProperty',
        EventName='StrProperty',WorldContextObject='ObjectProperty',ReturnValue='IntProperty'}
    local seen={};order={}
    fn:ForEachProperty(function(p)
        local name=p:GetFName():ToString()
        assert(expected[name]==p:GetFullName():match('^(%S+)') and not seen[name],'Unsupported focus sound parameter '..name)
        seen[name]=true
        if name~='ReturnValue' then order[#order+1]=name end
    end)
    for name in pairs(expected) do assert(seen[name],'Missing focus sound parameter '..name) end
    soundFunction=fn;soundOrder=order
    end
    local values={AkEvent=event,Location=s.pawn:K2_GetActorLocation(),orientation={Pitch=0,Yaw=0,Roll=0},
        EventName='',WorldContextObject=s.pawn}
    local args={}
    for i,name in ipairs(order) do args[i]=values[name] end
    ak:PostEventAtLocation(table.unpack(args))
end
local function flash()
    endFlash()
    local token=generation
    local step=0
    local function nextStep()
        flashHandle=nil
        if token~=generation or not camera.active() then return end
        local ok,err=pcall(function()
            step=step+1
            syncVision((1-step/18)^2,true)
            if token==generation and wanted and camera.active() and not effectFailure and step<18 then
                flashHandle=ExecuteInGameThreadWithDelay(25,nextStep)
            end
        end)
        if not ok then report('Activation pulse stopped: '..tostring(err));restore() end
    end
    flashHandle=ExecuteInGameThreadWithDelay(25,nextStep)
end
local function schedulePoll()
    if timer or loading or not scope or settings.enabled~=1 then return end
    if settings.controllerInput~=1 and not wanted then return end
    -- A single one-shot is chained only while controller input or vision is active.
    timer=ExecuteInGameThreadWithDelay(settings.controllerInput==1 and 50 or 250,poll)
end
toggle=function()
    if settings.enabled~=1 then return end
    if wanted then
        if current(scope) and not playable(scope) then armed=false;return end
        wanted=false;effectFailure=nil
        if restore() then
            if current(scope) then pcall(sound,scope,false) end
            trace('Vision off; owned camera values restored.')
        end
        return
    end
    if loading then return end
    if not current(scope) then clear();wake('keyboard');return end
    if not playable(scope) then armed=false;return end
    if vampire(scope)==true then
        wanted=true;visualElapsed=0
        effectFailure=camera.active() and {target=camera.camera(),attempts=0} or nil
        syncVision(1,true)
        if settings.nightVisionMode==1 and camera.active() and not effectFailure then flash() end
        local ok,err=pcall(sound,scope,true)
        if not ok then report('Optional focus sound skipped: '..tostring(err)) end
        if settings.debugLogging==1 then
            trace(string.format('Vision on: mode=%s, vignette=%d/%d%%, B&W=%d%%, red=%d%%, keep blood red=%d, red brightness=%d%%.',
                ({[0]='Radius',[1]='Fullscreen',[2]='Natural'})[settings.nightVisionMode],settings.vignette,
                settings.vignetteOpacity,settings.monochrome,settings.redMonochrome,settings.keepBloodRed,settings.redBrightnessPercent))
        end
    else trace('Activation requires vampire form.') end
    schedulePoll()
end
poll=function()
    timer=nil
    local started=settings.debugLogging==1 and os.clock() or nil
    local ok,err=pcall(function()
        if not current(scope) then clear();wake('owner changed');return end
        -- Observe changing form/camera state. Inspect external effect writes at most
        -- every 250ms; unchanged settings and camera values are never reapplied.
        visualElapsed=visualElapsed+(settings.controllerInput==1 and 50 or 250)
        local inspect=visualElapsed>=250
        if inspect then visualElapsed=0 end
        syncVision(nil,inspect,true)
        if settings.controllerInput==1 then
            local down=scope.pc:IsInputKeyDown(stickKey)
            if not down then armed=true;latched=false;holdStart=0
            elseif not playable(scope) then armed=false;holdStart=0
            elseif armed and not latched then
                local now=gameplay:GetRealTimeSeconds(scope.world)
                if holdStart==0 or now<holdStart then holdStart=now end
                if now-holdStart>=0.6 then latched=true;toggle() end
            end
        end
    end)
    if started then
        local elapsed=os.clock()-started
        stats.count=stats.count+1;stats.elapsed=stats.elapsed+elapsed;stats.maximum=math.max(stats.maximum,elapsed)
        if stats.count>=600 then
            trace(string.format('Input/vision checks: %d, camera repairs: %d, total %.3f ms, maximum %.3f ms.',stats.count,stats.repairs,stats.elapsed*1000,stats.maximum*1000))
            local detail=radius.diagnostics();if detail then trace(detail) end
            stats.count,stats.elapsed,stats.maximum,stats.repairs=0,0,0,0
        end
    end
    if not ok then clear();report('Input/vision stopped until the next lifecycle event: '..tostring(err));return end
    schedulePoll()
end
local function discover(job)
    -- Once per finite readiness window. Missing services are never scanned every retry.
    if not job.looked then
        job.looked=true
        if not valid(engine) then engine=FindFirstOf('Engine') end
        if not valid(gameplay) then gameplay=StaticFindObject('/Script/Engine.Default__GameplayStatics') end
        if not valid(cameraClass) then cameraClass=StaticFindObject('/Script/Engine.CameraComponent') end
        if not valid(uiManager) then uiManager=FindFirstOf('UIManagerSubsystem') end
        inspection.prepare()
        job.towerQueries=supportsQuery('/Script/Dawnwalker.DawnwalkerPlayerCharacter:GetActiveTower','ObjectProperty')
            and supportsQuery('/Script/Engine.Controller:IsLookInputIgnored','BoolProperty')
        if not job.towerQueries then report('Tower survey queries unavailable or incompatible; ordinary night vision remains available.') end
    end
    if not valid(engine) or not valid(gameplay) or not valid(cameraClass) then return end
    local viewport=engine.GameViewport
    if not valid(viewport) then return end
    local world=viewport:GetWorld()
    if not valid(world) then return end
    local pc=gameplay:GetPlayerController(world,0)
    if not valid(pc) or not pc:IsLocalController() or not same(pc:GetWorld(),world) then return end
    local pawn=pc.Pawn
    if not valid(pawn) or not same(pawn:GetWorld(),world) then return end
    return {pc=pc,pawn=pawn,world=world,towerQueries=job.towerQueries}
end
wake=function(reason)
    if loading or settings.enabled~=1 or worker then return end
    local job={attempts=0,generation=generation}
    worker=job
    local function attempt()
        if worker~=job or job.generation~=generation then return end
        job.handle=nil;job.attempts=job.attempts+1
        local ok,ready=pcall(discover,job)
        -- A native getter may synchronously cause a lifecycle callback.
        if worker~=job or job.generation~=generation or loading then return end
        if not ok then worker=nil;report('Readiness stopped: '..tostring(ready));return end
        if ready then
            scope=ready;armed=false;latched=false;holdStart=0
            worker=nil
            local resumed,err=pcall(syncVision,nil,true)
            if not resumed then clear();report('Vision recovery suspended: '..tostring(err));return end
            schedulePoll()
            if settings.debugLogging==1 then trace('Player ready after '..job.attempts..' attempt(s): '..reason) end
        elseif job.attempts<20 then job.handle=ExecuteInGameThreadWithDelay(250,attempt)
        else worker=nil;report('Player not ready after 20 attempts; waiting for a lifecycle event or N.') end
    end
    job.handle=ExecuteInGameThreadWithDelay(50,attempt)
end
local function guarded(fn)
    return function(...)
        local ok,err=pcall(fn,...)
        if not ok then clear();report('Operation stopped: '..tostring(err)) end
    end
end
local function apply(values)
    local enabledChanged=settings.enabled~=values.enabled
    local inputChanged=settings.controllerInput~=values.controllerInput
    local visualChanged=settings.monochrome~=values.monochrome or settings.brightnessPercent~=values.brightnessPercent
        or (settings.nightVisionMode==1 and settings.brightnessCalculation~=values.brightnessCalculation)
        or (settings.nightVisionMode==0 and settings.debugLogging~=values.debugLogging)
        or settings.keepBloodRed~=values.keepBloodRed
        or settings.redBrightnessPercent~=values.redBrightnessPercent
        or settings.radiusMeters~=values.radiusMeters
        or settings.naturalFocusSize~=values.naturalFocusSize or settings.naturalSoftness~=values.naturalSoftness
        or settings.nightVisionMode~=values.nightVisionMode or settings.vignette~=values.vignette
        or settings.vignetteOpacity~=values.vignetteOpacity or settings.redMonochrome~=values.redMonochrome
    if settings.nightVisionMode~=values.nightVisionMode then natural.reset();radius.reset() end
    for k,v in pairs(values) do settings[k]=v end
    stats.count,stats.elapsed,stats.repairs=0,0,0
    if settings.enabled~=1 then wanted=false;clear();return end
    if wanted and visualChanged then
        if effectFailure then effectFailure.attempts=0 end
        endFlash()
        syncVision(0,true)
        if settings.debugLogging==1 then
            trace(string.format('Appearance settings applied: mode=%d, brightness=%d%%, Fullscreen calculation=%s.',
                settings.nightVisionMode,settings.brightnessPercent,settings.brightnessCalculation==1 and 'Absolute' or 'Multiply'))
        end
    end
    if enabledChanged then wake('settings') end
    if inputChanged then cancel(timer);timer=nil;armed=false;latched=false;holdStart=0;schedulePoll() end
end
local function hook(path,pre,post)
    local ok,a,b=pcall(RegisterHook,path,pre,post)
    if ok and a and b then hooks[path]={a,b}
    else report('Lifecycle hook unavailable: '..path..': '..tostring(a)) end
end
ExecuteInGameThread(guarded(function()
    stickKey={KeyName=FName('Gamepad_LeftThumbstick')}
    vampireTag={TagName=FName('Player.IsVampire')}
    reloadSettings=require('Settings').start(directory,guarded(apply),report)
    hook('/Script/Engine.PlayerController:ClientRestart',guarded(clear),guarded(function() wake('client restart') end))
    -- This native UI event covers controller menus without relying on a mouse cursor.
    hook('/Script/DogwoodUI.UIManagerSubsystem:SetShowGameplayWidgets',function() end,guarded(function(context)
        local manager=context:get()
        if current(scope) and valid(manager) and same(manager:GetWorld(),scope.world) then
            uiManager=manager;syncVision(nil,true)
        end
    end))
    local lastLoading
    hook('/Script/DogwoodCombat.CombatSubsystem:OnLoadingScreenStateChanged',function() end,guarded(function(_,state)
        local value=type(state)=='number' and state or state:get()
        if type(value)~='number' or value<0 or value>4 or value==lastLoading then return end
        lastLoading=value;loading=value~=0;clear()
        if not loading then reloadSettings();wake('save loaded') end
    end))
    for _,path in ipairs({'/Script/DogwoodUI.SaveWindowBase:RequestLoadSave','/Script/Persistency.SaveSystemBlueprintFunctionLibrary:LoadLastSave','/Script/Persistency.SaveSystemBlueprintFunctionLibrary:TryQuickload'}) do
        hook(path,guarded(clear),guarded(function() wake('load requested') end))
    end
    if type(RegisterLoadMapPreHook)=='function' then RegisterLoadMapPreHook(guarded(function() loading=true;clear() end)) end
    if type(RegisterLoadMapPostHook)=='function' then RegisterLoadMapPostHook(guarded(function() loading=false;reloadSettings();wake('map loaded') end)) end
    if type(NotifyOnNewObject)=='function' then
        local ok,err=pcall(NotifyOnNewObject,'/Script/Dawnwalker.DawnwalkerPlayerCharacter',function() wake('player created') end)
        if not ok then report('Player notification unavailable: '..tostring(err)) end
    end
    RegisterKeyBind(Key.N,function() ExecuteInGameThread(guarded(toggle)) end)
    wake('startup')
end))
