-- Extends V1.3 actual engine/Shop regression, then exercises the real stand adapter.
for _,name in ipairs({"OpeningConfig","OpeningTimeline","StandOpeningLedger","StandOpeningService"})do parent[name]=name end
local opening=I.Copy(load("OpeningConfig"));loaded.OpeningConfig=opening
-- Legacy exclusive/cooldown branches remain supported; production defaults tested in V2.4.
opening.Stand.ExclusiveOpening=true;opening.Stand.ReopenCooldown=5
opening.RewardSpin=nil -- Legacy 10.5s fixture; V2.5 tests use the real spin-aware timeline.
local timeline=load("OpeningTimeline")
local Ledger=load("StandOpeningLedger")
local plan=assert(timeline.Build(opening))
check(near(plan.Duration,10.5),"Authored timeline duration 10.5 < timeout25")
for _,stage in ipairs(plan.Stages)do
 local name,p=timeline.At(plan,stage.Start+stage.Duration*.5)
 check(name==stage.Name and near(p,.5),"Deterministic phase "..name)
end
check(timeline.At(plan,plan.Duration)=="Done","Timeline completion boundary")
local invalid=I.Copy(opening);invalid.Mode="ClientChosen";check(not timeline.Build(invalid),"Invalid mode fail closed")
invalid=I.Copy(opening);invalid.Cinematic.ChestRiseDuration=0/0;check(not timeline.Build(invalid),"NaN timing rejected")
invalid=I.Copy(opening);invalid.Stand.MaxSequenceDuration=1;check(not timeline.Build(invalid),"Timeline cannot exceed safety timeout")
local clock=100
local ledger=Ledger.new(opening,plan,function()return clock end)
local lease=assert(ledger:Acquire(-1,"Main","one"))
check(not ledger:Acquire(-2,"Main","two"),"Exclusive stand has one reservation")
check(ledger:Acquire(-1,"Main","one")==lease,"Same operation reuses lease")
check(not ledger:Acquire(-1,"Other","three"),"One active opening per player across stands")
check(ledger:Acquire(-2,"Other","two")~=nil,"Different stands independent")
check(ledger:Commit(lease,"-1:one")and not ledger:Commit(lease,"-1:one"),"Single commit identity")
clock+=plan.Stages[8].Start+.1;ledger:Step();check(lease.State=="Revealing","Server reveal state")
clock=100+plan.Duration;ledger:Step()
check(not ledger.Players[-1]and not ledger.Stands.Main,"Deadline releases exclusive stand")
check(not ledger:Acquire(-1,"Main","again"),"Personal cooldown cannot be bypassed by new operation")
check(ledger:Acquire(-3,"Main","other")~=nil,"Personal cooldown does not block another buyer")
ledger:Release(-3);clock+=4.999;check(not ledger:Acquire(-1,"Main","early"),"Cooldown rejects just before5seconds")
clock+=.001;check(ledger:Acquire(-1,"Main","ready")~=nil,"Cooldown allows exactly5seconds")
ledger:Release(-1);clock+=26;ledger:Step();check(not ledger.Players[-2],"Uncommitted reservation timeout cleans up")
local concurrent=I.Copy(opening);concurrent.Stand.ExclusiveOpening=false
local privateLedger=Ledger.new(concurrent,plan,function()return clock end)
check(privateLedger:Acquire(-1,"Main","a")and privateLedger:Acquire(-2,"Main","b"),"Private mode accepts two same-stand buyers")
check(next(privateLedger.Stands)==nil,"Private mode never claims global stand")
-- Actual stand service and the existing transaction backend.
local standClass=load("StandOpeningService")
local stand=node("Model","Stand");stand.Attrs.StandId="Main";stand.Attrs.Enabled=true
function stand:SetAttribute(k,v)self.Attrs[k]=v end
for _,name in ipairs({"InteractionPart","SpawnPoint","CameraPoint","RewardPoint"})do
 stand.Children[name]=node("Part",name);stand.Children[name].Position=vec(0)
 stand.Children[name].IsA=function(_,class)return class=="BasePart"or class=="Part"end
end
local prompt=node("ProximityPrompt","Prompt");prompt.Triggered=signal();stand.InteractionPart.Children.Prompt=prompt
function stand.InteractionPart:FindFirstChildWhichIsA(class)return class=="ProximityPrompt"and prompt end
function prompt:IsDescendantOf()return true end
local folder=node("Folder","CrateStands");folder.Children.Main=stand
world.FindFirstChild=function(_,name)return if name=="CrateStands"then folder else nil end
for _,p in ipairs({a,b,observer})do p.Character.FindFirstChildOfClass=function()return {Health=100}end end
service:Init(ctx);service._resource=function()return true end
service._stands=standClass.new(service);local stands=service._stands
stands.Remote=node("RemoteEvent","StandPresentation")
stands:SyncStands();check(prompt.Enabled and #prompt.Triggered.Callbacks==1,"Prompt bound once in Stand mode")
stands:SyncStands();check(#prompt.Triggered.Callbacks==1,"No duplicate prompt connections")
local beforeMessages=#objects;prompt.Triggered.Callbacks[1](a)
check(#objects==beforeMessages+1 and objects[#objects].Packet.Kind=="Access","Server prompt opens same Shop through Access event")
check(stands:Validate(a,"Main")==stand,"Valid near lobby buyer")
a.Character.HumanoidRootPart.Position=vec(10.001);check(select(2,stands:Validate(a,"Main"))=="StandTooFar","Distance server-enforced")
a.Character.HumanoidRootPart.Position=vec(0);a.Attrs.MatchId="active"
check(select(2,stands:Validate(a,"Main"))=="LobbyOnly","Combat cannot use stand")
a.Attrs.MatchId=nil;check(not stands:FindStand("fake"),"Unknown stand rejected")
local duplicate=node("Model","Duplicate");duplicate.Attrs.StandId="Main";folder.Children.Duplicate=duplicate
check(not stands:FindStand("Main"),"Duplicate stable StandIds rejected")
folder.Children.Duplicate=nil
pdata[a]=data(5);pdata[a].Inventory.Crates.StudioTest=2
pdata[b]=data(5);pdata[b].Inventory.Crates.StudioTest=1
local quote=service:Quote(a,"StudioTest")
local args={CrateId="StudioTest",StandId="Main",QuoteToken=quote.Token,OperationId="standOpen"}
local messages=#objects
local result=stands:Open(a,args,function()return service:_transact(a,"Open",args)end)
check(result.Ok and pdata[a].Inventory.Crates.StudioTest==1 and pdata[a].Coins==5,"Stand delegates consume/grant once, no extra price")
check(result.Presentation.Mode=="StandCinematic"and stands.Ledger.Players[a.UserId].Committed,"Presentation only after backend commitment")
local openingId=result.Operation.UnitId;local rewardId=result.Operation.RewardId;local packets=0
for i=messages+1,#objects do local event=objects[i]
 if event.Name=="StandPresentation"then
  packets+=1;check(event.Packet.OpeningId==openingId and event.Packet.Operation.RewardId==rewardId,"Spectator/buyer exact same authoritative result")
  check(event.Player~=c,"Combat observer excluded")
 end
end
check(packets==3,"Exclusive buyer plus two lobby observers")
local busy=stands:Open(b,{StandId="Main",OperationId="busy"},function()error("Busy must not reach economy")end)
check(not busy.Ok and busy.Code=="StandBusy","Second buyer blocked before economic operation")
messages=#objects
result=stands:Open(a,args,function()return service:_transact(a,"Open",args)end)
check(result.Ok and result.Replay and #objects==messages and pdata[a].Inventory.Crates.StudioTest==1,"Replay does not consume/reveal again or cancel active sequence")
stands:Release(a.UserId,"Disconnected")
check(not stands.Ledger.Stands.Main and pdata[a].Inventory.Owned.Slaps[rewardId],"Disconnect cleanup releases stand, preserves acquired reward")
local failQuote=service:Quote(b,"StudioTest")
local badArgs={StandId="Main",OperationId="invalidquote",CrateId="StudioTest",QuoteToken="invalid"}
local failed=stands:Open(b,badArgs,function()return service:_transact(b,"Open",badArgs)end)
check(not failed.Ok and not stands.Ledger.Players[b.UserId]and pdata[b].Inventory.Crates.StudioTest==1,"Failed validation releases reservation without consuming")
opening.Stand.ExclusiveOpening=false
stands.Ledger=Ledger.new(opening,plan,os.clock);stands.Active={}
messages=#objects
local qa=service:Quote(a,"StudioTest");args.OperationId="privateA";args.QuoteToken=qa.Token
result=stands:Open(a,args,function()return service:_transact(a,"Open",args)end)
local qb=service:Quote(b,"StudioTest");local bargs={StandId="Main",CrateId="StudioTest",OperationId="privateB",QuoteToken=qb.Token}
local second=stands:Open(b,bargs,function()return service:_transact(b,"Open",bargs)end)
check(result.Ok and second.Ok and result.Operation.UnitId~=second.Operation.UnitId,"Two private buyers receive different identities and rewards independently")
check(#objects==messages+2 and objects[messages+1].Player==a and objects[messages+2].Player==b,"No private presentation packets sent to spectators")
check(not stands.Ledger.Stands.Main,"No global visual lock in private mode")
stands:Release(a.UserId,"Death");check(pdata[a].Inventory.Owned.Slaps[result.Operation.RewardId],"Death cancels only presentation")
opening.Mode="Spin"
local called=0;check(stands:Open(a,{},function()called+=1;return {Ok=true}end).Ok and called==1,"Spin bypasses stand validation and uses original backend")
stands:SyncStands();check(not prompt.Enabled,"Spin disables stand interaction")
opening.Mode="StandCinematic";opening.Stand.ExclusiveOpening=true
-- Actual camera lease; never restores over another owner, new life or EndCinematic.
extraEnv.Enum.CameraType={Custom="Custom",Scriptable="Scriptable"}
local cameraLease=load("CameraLease","CameraLease")
local function camera()
 local c=node("Camera","Camera");c.CameraType="Custom";c.CameraSubject={Parent=true};c.FieldOfView=75;c.CFrame="original"
 function c:SetAttribute(k,v)self.Attrs[k]=v end
 return c
end
local cam=camera();local char={FindFirstChildOfClass=function()return "newHumanoid"end}
local saved=cameraLease.Acquire(cam,"open",char)
check(saved and cameraLease.Owns(saved),"Lobby camera lease acquired locally")
cam.CameraType="Scriptable";cam.FieldOfView=60;cam.CFrame="cinematic"
check(cameraLease.Restore(saved,char,false)and cam.CameraType=="Custom"and cam.FieldOfView==75 and cam.CFrame=="original","Camera type FOV and frame restored")
check(cam.CameraSubject==saved.Subject,"CameraSubject restored for same life")
cam.CameraType="Scriptable";check(not cameraLease.Acquire(cam,"blocked",char),"Existing Scriptable camera priority respected")
cam=camera();saved=cameraLease.Acquire(cam,"old",char);cam:SetAttribute("CrateCameraOwner","new")
check(not cameraLease.Restore(saved,char,false)and cam:GetAttribute("CrateCameraOwner")=="new","Late cleanup cannot alter newer camera owner")
cam=camera();saved=cameraLease.Acquire(cam,"life",char);cam.FieldOfView=61;cam.CFrame="newPose"
check(cameraLease.Restore(saved,{FindFirstChildOfClass=function()return "newHumanoid"end},false)and cam.CameraType=="Custom"and cam.CameraSubject=="newHumanoid"and cam.FieldOfView==61 and cam.CFrame=="newPose","Respawn does not restore old life state")
cam=camera();saved=cameraLease.Acquire(cam,"priority",char);cam.CameraType="Scriptable";cam.FieldOfView=55
check(not cameraLease.Restore(saved,char,true)and cam.CameraType=="Scriptable"and cam.FieldOfView==55,"EndCinematic priority never overwritten")
-- Real client phase/update methods with deterministic geometry; no rendered/visual claims.
local unbound={};services.ContextActionService={UnbindAction=function(_,id)table.insert(unbound,id)end}
parent.Parent.CrateOpening={CameraLease="CameraLease"}
parent.Parent.CrateOpening.CharacterVisibility="CharacterVisibility";load("CharacterVisibility","CharacterVisibility")
for _,name in ipairs({"CinematicConfig","CinematicMotion","CinematicTransition","StandPromptVisibility"})do parent[name]=name;parent.Parent.CrateOpening[name]=name;load(name,name)end
parent.Parent.CrateOpening.VisualProfile="VisualProfile";parent.Parent.CrateOpening.RewardOverlayPresenter="OverlayPresenter"
parent.VisualProfile="VisualProfile"
load("VisualProfile","VisualProfile");load("OverlayPresenter","OverlayPresenter")
for _,name in ipairs({"RewardRevealConfig","RewardRevealProfile","RewardVFX","RewardSpinMotion","RewardSpin3D","RewardGalleryLayout","RewardGallery"})do parent[name]=name;parent.Parent.CrateOpening[name]=name;load(name,name)end
players.LocalPlayer=a
local present=load("StandPresentation","StandController")
present:Init({GetController=function()return nil end})
present._hud={Enabled=true,Transition={},Flash={}}
local frameMeta={}
local function frame(x)local f={Position=vec(x or 0),UpVector=vec(1)};return setmetatable(f,frameMeta)end
function frameMeta.__mul(a,b)return frame(a.Position.X+b.Position.X)end
local oldFrame=extraEnv.CFrame
extraEnv.CFrame={new=function(x,y)return frame((x or 0)+(y or 0))end,Angles=function()return frame(0)end,lookAt=function(position)return frame(position.X)end}
local poseStand={Parent=true,SpawnPoint={CFrame=frame(100)},RewardPoint={CFrame=frame(200),Position=vec(200)}}
local emitted=0;local fx={EnergyBeam={}}
local effects={FXAnchor=fx,FindFirstChild=function()return nil end,FindFirstChildWhichIsA=function()return nil end,
 GetDescendants=function()return {{Name="FlashSparks",IsA=function(_,c)return c=="ParticleEmitter"end,Emit=function(_,count)emitted+=count end,GetAttribute=function(_,key)return if key=="BurstCount"then 24 else nil end}}end}
local chest={PivotTo=function(self,pose)self.Pose=pose end,ScaleTo=function(self,scale)self.Scale=scale end}
local rewardModel={PivotTo=function(self,pose)self.Pose=pose end,GetDescendants=function()return {}end}
local run={Id="visual",Stand=poseStand,Character=a.Character,Packet={StartedAt=0},Private=false,Chest=chest,BaseScale=1,Scene={RewardAnchor={}},Reward=rewardModel,Effects=effects,Label={},Objects={},Tweens={}}
for _,stage in ipairs(plan.Stages)do
 if stage.Name=="Outro"then continue end
 present:_update(run,stage.Start+stage.Duration*.5)
 check(run.Stage==stage.Name,"Client deterministic phase executes "..stage.Name)
 if stage.Name=="Appear"then check(chest.Scale>.15 and chest.Scale<1,"Chest appears from small authored model")
 elseif stage.Name=="Rise"then check(chest.Pose.Position.X>101 and chest.Scale==.8,"Chest rises relative to SpawnPoint")
 elseif stage.Name=="Growth"then check(chest.Scale>1 and fx.EnergyBeam.Enabled,"Chest grows with bounded energy beam")
 elseif stage.Name=="Shake"then check(chest.Scale==1.25,"Shake maintains stable base scale")
 elseif stage.Name=="Flash"then check(emitted>15,"Flash emits bounded visual particles without Explosion")
 elseif stage.Name=="Reward"then check(rewardModel.Parent==run.Scene and run.Label.Enabled and not chest.Parent,"Reward replaces chest at reveal")end
end
check(run.Scene.RewardAnchor.CFrame.Position.X==200,"Reward label follows authored RewardPoint")
local destroyed=0;present._runs.visual=run
run.Objects={{Destroy=function()destroyed+=1 end}}
present:_stop("visual","Timeout");present:_stop("visual","LateCancel")
check(destroyed==1 and not present._runs.visual,"Idempotent visual cleanup and late cancel")
present:Play({Mode="StandCinematic",OpeningId="late",StartedAt=-100,Operation={RewardId=rewardId,CrateId="StudioTest"}})
check(not present._runs.late,"Late opening packet ignored")
extraEnv.CFrame=oldFrame
-- Shared Shop opening route must not fall back to Spin for a stand result.
flow._crateId="StudioTest";flow._quoting=false;flow._busy=false;flow._pendingAction=nil
flow:SetSnapshot({Coins=0,Inventory=I.Extend({Crates={StudioTest=1}})})
flow._quoteCache.StudioTest=q;flow._quote=q
local spins=0;flow._spin=function()spins+=1 end
flow._call=function()return {Ok=true,Operation={UnitId="stand-client"},Presentation={Mode="StandCinematic"}}end
flow:_mutate("Open")
check(spins==0,"Stand result never invokes classic spin fallback")
flow._quoteCache.StudioTest=q;flow._quote=q
flow._call=function()return {Ok=true,Operation={UnitId="spin-client"}}end
flow:_mutate("Open")
check(spins==1,"Return to Spin preserves classic fallback")
print("PASS SlapCratesV2: "..assertions.." combined deterministic assertions; no gameplay/cloud")
