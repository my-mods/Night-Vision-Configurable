-- Inspection hides the pawn and uses a camera without a CameraComponent.
-- Own a visible, meshless actor attached to the pawn so all modes still render
-- and the Radius helper continues to follow the player's world position.
local M={}
local transform={Rotation={X=0,Y=0,Z=0,W=1},Translation={X=0,Y=0,Z=0},Scale3D={X=1,Y=1,Z=1}}
local function valid(o) return o~=nil and o:IsValid() end
local function same(a,b) return valid(a) and valid(b) and a:GetAddress()==b:GetAddress() end
local function signature(path,expected)
    local fn=StaticFindObject(path)
    assert(valid(fn),'Missing '..path)
    local seen,count={},0
    fn:ForEachProperty(function(p)
        local name=p:GetFName():ToString()
        assert(expected[name]==p:GetFullName():match('^(%S+)') and not seen[name],'Unsupported '..path)
        seen[name]=true;count=count+1
    end)
    for name in pairs(expected) do assert(seen[name],'Missing parameter '..name) end
end
function M.new(report)
    local viewClass,component,owner,requestedPawn,requestedView
    local attempts,cleanupAttempts=0,0
    local retiring=false
    local api={}
    function api.prepare()
        local ok,value=pcall(StaticFindObject,'/Script/DogwoodWorld.InvestigationCameraActor')
        viewClass=ok and value or nil
        if not valid(viewClass) then
            viewClass=nil
            report('Clue inspection camera unavailable; ordinary night vision remains available.')
        end
    end
    function api.matches(view,world)
        if not valid(viewClass) then return false end
        local ok,result=pcall(function()
            return valid(view) and same(view:GetWorld(),world) and view:IsA(viewClass)==true
        end)
        if not ok then
            viewClass=nil
            report('Clue inspection detection unavailable until the next player context.')
        end
        return ok and result
    end
    function api.release()
        retiring=true
        if valid(component) or valid(owner) then
            if cleanupAttempts>=3 then return false end
            cleanupAttempts=cleanupAttempts+1
            -- Even a partial setter failure must still attempt destruction.
            if valid(component) then
                pcall(function() component.bEnabled=false end)
                pcall(function() component.BlendWeight=0 end)
            end
            local destroyed,result=pcall(function()
                if valid(owner) then return owner:K2_DestroyActor() end
                if valid(component) then component:K2_DestroyComponent(owner) end
            end)
            if not destroyed or result==false then
                report('Clue inspection effect cleanup incomplete; further hosts are suspended.')
                return false
            end
        end
        component=nil;owner=nil;cleanupAttempts=0;retiring=false
        return true
    end
    function api.reset()
        if not api.release() then return false end
        requestedPawn=nil;requestedView=nil;attempts=0
        return true
    end
    function api.target(pawn,view,world)
        if not valid(pawn) or not same(pawn:GetWorld(),world) or not api.matches(view,world) then return nil end
        if not same(requestedPawn,pawn) or not same(requestedView,view) then
            if not api.reset() then return nil end
            requestedPawn=pawn;requestedView=view
        elseif retiring and not api.release() then return nil end
        if valid(component) and valid(owner) and same(component:GetOwner(),owner)
            and same(owner:GetWorld(),world) then return component,owner end
        if (component or owner) and not api.release() then return nil end
        if attempts>=3 then return nil end
        attempts=attempts+1
        local ok,err=pcall(function()
            local class=StaticFindObject('/Script/Engine.PostProcessComponent')
            local actorClass=StaticFindObject('/Script/Engine.Actor')
            local sceneClass=StaticFindObject('/Script/Engine.SceneComponent')
            local gameplay=StaticFindObject('/Script/Engine.Default__GameplayStatics')
            assert(valid(class) and valid(actorClass) and valid(sceneClass) and valid(gameplay),'Missing inspection host classes')
            signature('/Script/Engine.GameplayStatics:BeginDeferredActorSpawnFromClass',{
                WorldContextObject='ObjectProperty',ActorClass='ClassProperty',SpawnTransform='StructProperty',
                CollisionHandlingOverride='EnumProperty',Owner='ObjectProperty',TransformScaleMethod='EnumProperty',ReturnValue='ObjectProperty'})
            signature('/Script/Engine.GameplayStatics:FinishSpawningActor',{
                Actor='ObjectProperty',SpawnTransform='StructProperty',TransformScaleMethod='EnumProperty',ReturnValue='ObjectProperty'})
            signature('/Script/Engine.Actor:K2_AttachToActor',{ParentActor='ObjectProperty',SocketName='NameProperty',
                LocationRule='EnumProperty',RotationRule='EnumProperty',ScaleRule='EnumProperty',bWeldSimulatedBodies='BoolProperty',ReturnValue='BoolProperty'})
            signature('/Script/Engine.Actor:K2_DestroyActor',{})
            signature('/Script/Engine.Actor:AddComponentByClass',{Class='ClassProperty',bManualAttachment='BoolProperty',
                RelativeTransform='StructProperty',bDeferredFinish='BoolProperty',ReturnValue='ObjectProperty'})
            signature('/Script/Engine.Actor:FinishAddComponent',{Component='ObjectProperty',bManualAttachment='BoolProperty',RelativeTransform='StructProperty'})
            signature('/Script/Engine.ActorComponent:K2_DestroyComponent',{Object='ObjectProperty'})
            owner=gameplay:BeginDeferredActorSpawnFromClass(world,actorClass,transform,1,pawn,0)
            assert(valid(owner) and same(owner:GetWorld(),world),'Inspection actor creation failed')
            assert(same(gameplay:FinishSpawningActor(owner,transform,0),owner),'Inspection actor did not finish spawning')
            local root=owner:AddComponentByClass(sceneClass,false,transform,true)
            assert(valid(root) and same(root:GetOwner(),owner),'Inspection root creation failed')
            owner:FinishAddComponent(root,false,transform)
            assert(same(owner.RootComponent,root),'Inspection root attachment failed')
            assert(owner:K2_AttachToActor(pawn,FName('None'),2,2,1,false)==true,'Inspection actor attachment failed')
            component=owner:AddComponentByClass(class,true,transform,true)
            assert(valid(component),'Inspection host creation failed')
            assert(component:IsA(class)==true and same(component:GetOwner(),owner),'Unexpected inspection host owner/type')
            assert(type(component.bEnabled)=='boolean' and type(component.bUnbound)=='boolean'
                and type(component.BlendWeight)=='number' and type(component.Priority)=='number','Unsupported inspection host fields')
            component.bEnabled=false;component.bUnbound=true;component.BlendWeight=1;component.Priority=999
            owner:FinishAddComponent(component,true,transform)
            component.bEnabled=true
            assert(component.bEnabled==true and component.bUnbound==true and component.BlendWeight==1,'Inspection host could not enable')
        end)
        if not ok then
            report('Clue inspection post-processing unavailable; ordinary night vision remains available: '..tostring(err))
            api.release();return nil
        end
        attempts=0
        return component,owner
    end
    return api
end
return M
