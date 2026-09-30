-- Night Vision - Configurable. Runtime state only; no save-game writes.
local directory=assert(debug.getinfo(1,'S').source:match('^@(.+[\\/])'))
local settings={enabled=1,monochrome=0,brightness=-0.5,controllerInput=1,debugLogging=0}
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
local camera=require('Camera').new(report)
local engine,gameplay,cameraClass,stickKey,vampireTag
local scope,worker,timer,flashHandle
local loading,armed,latched=false,false,false
local holdStart,generation=0,0
local reloadSettings
local hooks={}
local stats={count=0,elapsed=0}
local wake,poll,toggle

local function cancel(handle) if handle then CancelDelayedAction(handle) end end
local function endFlash() cancel(flashHandle);flashHandle=nil end
local function restore()
    endFlash()
    local ok,err=pcall(camera.release)
    if not ok then report(tostring(err));return false end
    return true
end
local function clear()
    generation=generation+1
    cancel(timer);timer=nil
    if worker then cancel(worker.handle);worker=nil end
    restore()
    scope=nil;armed=false;latched=false;holdStart=0
end
local function current(s)
    if loading or not s or not valid(engine) or not valid(gameplay) then return false end
    local viewport=engine.GameViewport
    return valid(viewport) and same(viewport:GetWorld(),s.world)
        and valid(s.pc) and same(s.pc:GetWorld(),s.world)
        and same(s.pc.Pawn,s.pawn) and same(s.pawn:GetWorld(),s.world)
end
local function playable(s)
    return not gameplay:IsGamePaused(s.world) and s.pc.bShowMouseCursor~=true
        and not s.pc:IsMoveInputIgnored()
end
local function vampire(s)
    local asc=s.pawn.AbilitySystemComponent
    return valid(asc) and asc:HasMatchingGameplayTag(vampireTag)==true
end
local function activeTarget(s)
    local target=s.pc:GetViewTarget()
    if not valid(target) or not same(target:GetWorld(),s.world) then return nil end
    local c=target:GetComponentByClass(cameraClass)
    if valid(c) and c:IsActive() and same(c:GetOwner(),target) then return c end
end
local function sound(s,on)
    -- Optional sound uses the location overload; no delegate marshalling.
    local suffix=on and 'start' or 'end'
    local path='/Game/Audio/AK_Events/Events/UI/Gameplay/Focus_Mode/sfx_focusmode_'..suffix
    local event=StaticFindObject(path..'.sfx_focusmode_'..suffix)
    local ak=StaticFindObject('/Script/AkAudio.Default__AkGameplayStatics')
    local fn=StaticFindObject('/Script/AkAudio.AkGameplayStatics:PostEventAtLocation')
    if not valid(event) or not valid(ak) or not valid(fn) then return end
    local expected={AkEvent='ObjectProperty',Location='StructProperty',orientation='StructProperty',
        EventName='StrProperty',WorldContextObject='ObjectProperty',ReturnValue='IntProperty'}
    local order,seen={},{}
    fn:ForEachProperty(function(p)
        local name=p:GetFName():ToString()
        assert(expected[name]==p:GetFullName():match('^(%S+)') and not seen[name],'Unsupported focus sound parameter '..name)
        seen[name]=true
        if name~='ReturnValue' then order[#order+1]=name end
    end)
    for name in pairs(expected) do assert(seen[name],'Missing focus sound parameter '..name) end
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
            if not current(scope) or not same(activeTarget(scope),camera.camera()) or not vampire(scope) then restore();return end
            step=step+1
            camera.apply(settings,(1-step/18)^2)
            if step<18 then flashHandle=ExecuteInGameThreadWithDelay(25,nextStep) end
        end)
        if not ok then report('Activation pulse stopped: '..tostring(err));restore() end
    end
    flashHandle=ExecuteInGameThreadWithDelay(25,nextStep)
end
local function schedulePoll()
    if timer or loading or not scope or settings.enabled~=1 then return end
    if settings.controllerInput~=1 and not camera.active() then return end
    -- A single one-shot is chained only while controller input or vision is active.
    timer=ExecuteInGameThreadWithDelay(settings.controllerInput==1 and 50 or 250,poll)
end
toggle=function()
    if loading or settings.enabled~=1 then return end
    if not current(scope) then clear();wake('keyboard');return end
    if not playable(scope) then armed=false;return end
    if camera.active() then
        if restore() then pcall(sound,scope,false);trace('Vision off; owned camera values restored.') end
    elseif vampire(scope) then
        local target=activeTarget(scope)
        if not target then report('No active camera on the current player view target; vision unchanged.');return end
        camera.capture(target)
        camera.apply(settings,1)
        flash()
        local ok,err=pcall(sound,scope,true)
        if not ok then report('Optional focus sound skipped: '..tostring(err)) end
        trace('Vision on.')
    else trace('Activation requires vampire form.') end
    schedulePoll()
end
poll=function()
    timer=nil
    local started=settings.debugLogging==1 and os.clock() or nil
    local ok,err=pcall(function()
        if not current(scope) then clear();wake('owner changed');return end
        -- Observe dynamic ownership only. No config I/O, global scans or settings reapply.
        if camera.active() and (not vampire(scope) or not same(activeTarget(scope),camera.camera())) then
            assert(restore(),'Camera restoration is incomplete; waiting for a lifecycle event')
        end
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
        stats.count=stats.count+1;stats.elapsed=stats.elapsed+(os.clock()-started)
        if stats.count>=600 then
            trace(string.format('Input/vision checks: %d, total %.3f ms.',stats.count,stats.elapsed*1000))
            stats.count,stats.elapsed=0,0
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
    return {pc=pc,pawn=pawn,world=world}
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
            worker=nil;schedulePoll()
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
    local visualChanged=settings.monochrome~=values.monochrome or settings.brightness~=values.brightness
    for k,v in pairs(values) do settings[k]=v end
    stats.count,stats.elapsed=0,0
    if settings.enabled~=1 then clear();return end
    if camera.active() and visualChanged then
        endFlash()
        if current(scope) and same(activeTarget(scope),camera.camera()) then camera.apply(settings,0)
        else restore() end
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
    local lastLoading
    hook('/Script/DogwoodCombat.CombatSubsystem:OnLoadingScreenStateChanged',function() end,guarded(function(_,state)
        local value=type(state)=='number' and state or state:get()
        if type(value)~='number' or value<0 or value>4 or value==lastLoading then return end
        lastLoading=value;loading=value~=0;clear()
        if not loading then reloadSettings();wake('save loaded') end
    end))
    for _,path in ipairs({'/Script/DogwoodUI.SaveWindowBase:RequestLoadSave','/Script/Persistency.SaveSystemBlueprintFunctionLibrary:LoadLastSave','/Script/Persistency.SaveSystemBlueprintFunctionLibrary:TryQuickload'}) do
        hook(path,guarded(clear),function() end)
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
