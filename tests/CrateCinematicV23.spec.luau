local count=0
local function check(ok,message)assert(ok,message);count+=1 end
local signals={}
local function signal()
 local s={Rows={}};table.insert(signals,s)
 function s:Connect(fn)local c={Connected=true,Fn=fn};function c:Disconnect()self.Connected=false end;table.insert(self.Rows,c);return c end
 function s:Fire(...)for _,c in ipairs(table.clone(self.Rows))do if c.Connected then c.Fn(...)end end end
 return s
end
local methods={}
local function object(class,props)
 local values=props or {};values.Class=class;values.Children={};values.Signals={}
 values.DescendantAdded=signal();values.DescendantRemoving=signal()
 return setmetatable({V=values},{__index=function(t,k)return methods[k]or t.V[k]end,__newindex=function(t,k,v)
  local old=t.V[k];t.V[k]=v;if old~=v and t.V.Signals[k]then t.V.Signals[k]:Fire()end
 end})
end
function methods:IsA(kind)return self.Class==kind or kind=="BasePart"and(self.Class=="Part"or self.Class=="MeshPart")or kind=="Decal"and self.Class=="Texture"or kind=="Light"and self.Class=="PointLight"end
function methods:GetPropertyChangedSignal(k)if not self.Signals[k]then self.Signals[k]=signal()end;return self.Signals[k]end
function methods:IsDescendantOf(root)local p=self.Parent;while p do if p==root then return true end;p=p.Parent end;return false end
function methods:GetDescendants()local all={};for _,child in ipairs(self.Children)do table.insert(all,child);for _,v in ipairs(child:GetDescendants())do table.insert(all,v)end end;return all end
function methods:Clear()self.Cleared=(self.Cleared or 0)+1 end
local function add(root,child)
 child.Parent=root;table.insert(root.Children,child)
 local p=root;while p do p.DescendantAdded:Fire(child);for _,v in ipairs(child:GetDescendants())do p.DescendantAdded:Fire(v)end;p=p.Parent end
 return child
end
local function remove(root,child)
 local p=root;while p do p.DescendantRemoving:Fire(child);for _,v in ipairs(child:GetDescendants())do p.DescendantRemoving:Fire(v)end;p=p.Parent end
 for i,v in ipairs(root.Children)do if v==child then table.remove(root.Children,i);break end end;child.Parent=nil
end
local function person(id)
 return {UserId=id,Character=object("Model"),CharacterAdded=signal(),CharacterRemoving=signal()}
end
local a,b=person(-1),person(-2)
local players={List={a,b},LocalPlayer=a,PlayerAdded=signal(),PlayerRemoving=signal()}
function players:GetPlayers()return self.List end
local enum={HumanoidDisplayDistanceType={None="None"},CameraType={Scriptable="Scriptable"}}
local function module()local fn=assert(loadstring(Sources.CharacterVisibility));setfenv(fn,setmetatable({Enum=enum},{__index=getfenv()}));return fn()end
local V=module()
local head=add(a.Character,object("Part",{LocalTransparencyModifier=.35,Transparency=.2}))
local other=add(b.Character,object("MeshPart",{LocalTransparencyModifier=0}))
local accessory=add(a.Character,object("Accessory"));local handle=add(accessory,object("Part",{LocalTransparencyModifier=.6}))
local tool=add(b.Character,object("Tool"));local glove=add(tool,object("MeshPart",{LocalTransparencyModifier=0}))
local effects={}
for _,class in ipairs({"ParticleEmitter","Trail","Beam","BillboardGui","SurfaceGui","Highlight","PointLight","Fire","Smoke","Sparkles"})do
 effects[class]=add(head,object(class,{Enabled=class~="Smoke"}))
end
local decal=add(head,object("Texture",{Transparency=.2}));local force=add(head,object("ForceField",{Visible=true}))
local humanoid=add(a.Character,object("Humanoid",{DisplayDistanceType="Viewer",Health=100}))
function a.Character:FindFirstChildOfClass()return humanoid end
local stand=object("Part",{LocalTransparencyModifier=.2});local reward=object("MeshPart",{LocalTransparencyModifier=.1})
local lease=V.Acquire(players,"one")
check(head.LocalTransparencyModifier==1,"Own character hidden")
check(other.LocalTransparencyModifier==1,"Other character hidden")
check(head.Transparency==.2,"BasePart replicated Transparency untouched")
check(handle.LocalTransparencyModifier==1 and glove.LocalTransparencyModifier==1,"Accessory and equipped slap hidden")
for class,fx in pairs(effects)do check(fx.Enabled==false,"Character effect hidden "..class)end
check(effects.ParticleEmitter.Cleared==1 and effects.Trail.Cleared==1,"Existing particle/trail geometry cleared locally")
check(decal.Transparency==1 and force.Visible==false and humanoid.DisplayDistanceType=="None","Decals forcefield and names hidden")
check(stand.LocalTransparencyModifier==.2 and reward.LocalTransparencyModifier==.1,"Stand and reward untouched")
local late=add(b.Character,object("Part",{LocalTransparencyModifier=.7}));check(late.LocalTransparencyModifier==1,"Dynamic descendant hidden")
local c=person(-3);local newcom=add(c.Character,object("Part",{LocalTransparencyModifier=.1}))
table.insert(players.List,c);players.PlayerAdded:Fire(c);check(newcom.LocalTransparencyModifier==1,"New player hidden")
local old=b.Character;b.CharacterRemoving:Fire(old);check(other.LocalTransparencyModifier==0,"Removed life restored")
b.Character=object("Model");local respawn=add(b.Character,object("Part",{LocalTransparencyModifier=.4}));b.CharacterAdded:Fire(b.Character)
check(respawn.LocalTransparencyModifier==1,"Respawn hidden")
head.LocalTransparencyModifier=.8;check(head.LocalTransparencyModifier==1,"External camera update remains concealed")
effects.Beam.Enabled=true;check(not effects.Beam.Enabled,"External effect update remains concealed")
remove(accessory,handle);check(handle.LocalTransparencyModifier==.6 and lease.Saved[handle]==nil,"Detached accessory restored and released")
players.PlayerRemoving:Fire(c);check(newcom.LocalTransparencyModifier==.1 and lease.Players[c]==nil,"Departing player released")
check(V.Acquire(players,"one")==lease,"Same token is idempotent")
V.Release(lease)
check(head.LocalTransparencyModifier==.8,"Latest external transparency restored")
check(effects.Beam.Enabled and not effects.Smoke.Enabled,"Original/latest effect values restored")
check(respawn.LocalTransparencyModifier==.4 and glove.LocalTransparencyModifier==0,"All remaining body and tool parts restored")
check(decal.Transparency==.2 and force.Visible and humanoid.DisplayDistanceType=="Viewer","Names and surface effects restored")
check(next(lease.Saved)==nil and next(lease.Players)==nil and next(lease.Characters)==nil and next(lease.Owners)==nil and #lease.Connections==0,"No retained objects/listeners")
for _,s in ipairs(signals)do for _,connection in ipairs(s.Rows)do check(not connection.Connected,"Connection disconnected")end end
for i=1,3 do
 local first=V.Acquire(players,"next"..i);local nextLease=V.Acquire(players,"replacement"..i)
 V.Release(first);check(head.LocalTransparencyModifier==1 and not nextLease.Released,"Late release cannot clear newer opening")
 V.Release(nextLease);check(head.LocalTransparencyModifier==.8,"Consecutive opening restores nonzero value")
end
-- Separate VM/client state does not mutate spectator instances.
local spectator=person(-4);local visible=add(spectator.Character,object("Part",{LocalTransparencyModifier=.3}))
local privateLease=V.Acquire(players,"private");check(visible.LocalTransparencyModifier==.3,"Spectator client remains unchanged");V.Release(privateLease)
-- Execute real controller lifecycle, not a copied implementation.
local camera={CameraType="Custom"};local events={}
local restoreError=false
local stolen=false
local refs={CameraLease={Owns=function()return not stolen end,Restore=function()check(head.LocalTransparencyModifier==1,"Camera handoff precedes visibility release");table.insert(events,"camera");if restoreError then error("camera fixture")end;camera.CameraType="Custom"end},CharacterVisibility=V,
 VisualProfile={Emit=function()end},RewardOverlayPresenter={},OpeningConfig={Cinematic={CameraRevealDuration=.2,IntroTransitionDuration=.2,OutroTransitionDuration=.2}},OpeningTimeline={Build=function()return {}end}}
refs.BatchOpening={Quantity=function(v)return v or 1 end};refs.RewardGallery={}
refs.RewardSpin3D={};refs.RewardVFX={};refs.RewardRevealProfile={}
local shared={SlapCrates={OpeningConfig="OpeningConfig",OpeningTimeline="OpeningTimeline",Catalog="Catalog",Appearance="Appearance",BatchOpening="BatchOpening"}}
for _,name in ipairs({"CinematicConfig","CinematicMotion","CinematicTransition","StandPromptVisibility"})do refs[name]=assert(loadstring(Sources[name]))()end
local parent={Parent={CrateOpening={CameraLease="CameraLease",CharacterVisibility="CharacterVisibility",VisualProfile="VisualProfile",RewardOverlayPresenter="RewardOverlayPresenter"}}}
parent.Parent.CrateOpening.RewardGallery="RewardGallery"
for _,name in ipairs({"RewardSpin3D","RewardVFX","RewardRevealProfile"})do parent.Parent.CrateOpening[name]=name end
for _,name in ipairs({"CinematicConfig","CinematicMotion","CinematicTransition","StandPromptVisibility"})do parent.Parent.CrateOpening[name]=name end
local f=assert(loadstring(Sources.StandController))
setfenv(f,setmetatable({script={Parent=parent},Enum=enum,game={GetService=function(_,name)
 if name=="Players"then return players elseif name=="ReplicatedStorage"then return {Shared=shared} elseif name=="ContextActionService"then return {UnbindAction=function()end}end;return {}end},
 workspace={CurrentCamera=camera},require=function(key)return refs[key]or {}end,warn=function()end},{__index=getfenv()}))
local controller=f();controller:Init({GetController=function()return nil end})
function a:GetAttribute()return nil end
controller._sound=function()end;controller._fade=function()end
controller._whoosh=function()end
local function run(id,private)return {Id=id,Private=private,Lease={Camera=camera},Effects={},Objects={},Tweens={}}end
local r=run("buyer",true);controller:_phase(r,"Intro");check(head.LocalTransparencyModifier==.8,"Shop/Intro does not hide")
controller:_phase(r,"CameraReveal");check(head.LocalTransparencyModifier==1 and camera.CameraType=="Scriptable","Buyer CameraReveal hides before viewing")
controller:_phase(r,"Outro");check(head.LocalTransparencyModifier==1,"Outro retains concealment until camera returns")
controller:_restore(r);check(events[#events]=="camera"and camera.CameraType=="Custom"and head.LocalTransparencyModifier==.8,"Camera restored before visibility release")
for _,reason in ipairs({"Completed","ServerRelease","CharacterLost","CameraLost","Error","Destroy"})do
 local row=run(reason,true);controller:_phase(row,"CameraReveal");controller._runs[reason]=row
 if reason=="CharacterLost"then humanoid.Health=0 end
 if reason=="Error"then restoreError=true end
 controller:_stop(reason,reason);restoreError=false;humanoid.Health=100
 check(head.LocalTransparencyModifier==.8 and not row.Visibility and not controller._runs[reason],"Cleanup "..reason)
 controller:_stop(reason,"late");check(head.LocalTransparencyModifier==.8,"Idempotent cleanup "..reason)
end
local observer=run("observer",false);controller:_phase(observer,"CameraReveal");check(not observer.Visibility and head.LocalTransparencyModifier==.8,"Exclusive spectator never acquires visibility")
controller:Play({Mode="Spin"});check(head.LocalTransparencyModifier==.8,"Spin bypasses hiding")
for _,reason in ipairs({"Death","Respawn","CameraTaken","StandRemoved","MatchPriority"})do
 local row=run(reason,true);row.Character=a.Character;row.Stand={Parent=true};controller._runs[row.Id]=row
 controller:_phase(row,"CameraReveal")
 local original=a.Character
 if reason=="Death"then humanoid.Health=0 elseif reason=="Respawn"then a.Character=object("Model")
 elseif reason=="CameraTaken"then stolen=true elseif reason=="StandRemoved"then row.Stand.Parent=nil
 elseif reason=="MatchPriority"then a.GetAttribute=function()return "match"end end
 controller:_update(row,0)
 a.Character=original;humanoid.Health=100;stolen=false;a.GetAttribute=function()return nil end
 check(not controller._runs[row.Id] and not row.Visibility and head.LocalTransparencyModifier==.8,"Actual update interrupts "..reason)
end
local config=refs.CinematicConfig
local motion=refs.CinematicMotion
local function standalone(name,env)
 local f=assert(loadstring(Sources[name]));setfenv(f,setmetatable(env or {},{__index=getfenv()}));return f()
end
local opening=standalone("Crates/OpeningConfig")
local timeline=standalone("Crates/OpeningTimeline")
local plan=assert(timeline.Build(opening))
local expectedDuration=10.5
if opening.RewardSpin then expectedDuration+=opening.RewardSpin.SpinDuration+opening.RewardSpin.FinalPauseDuration-3 end
check(math.abs(plan.Duration-expectedDuration)<1e-6,"Shared timeline covers x1 spin and final pause")
check(config.RewardOverlayByMode.StandCinematic==false and config.RewardOverlayByMode.Spin==true,"Stand-only overlay policy")
local shown=0;controller._overlay={Show=function()shown+=1 end}
controller:_showReward({Private=true,RewardDefinition={},Profile={Special=false}})
check(shown==0,"Actual stand controller does not call overlay presenter")
controller._overlay=nil
check(motion.Cover("Intro",0,config.Transition)==0,"Intro begins open")
check(motion.Cover("Intro",1,config.Transition)==.5,"Intro closes fully")
check(motion.Cover("CameraReveal",0,config.Transition)==.5,"Camera cut concealed")
check(motion.Cover("CameraReveal",1,config.Transition)==config.Transition.Letterbox,"Reveal opens into letterbox")
check(motion.Cover("Outro",config.Transition.OutroHandoff,config.Transition)==.5,"Full blackout at camera handoff")
check(motion.Cover("Outro",1,config.Transition)==0,"Outro ends open")
local high=motion.Sample(plan,plan.Stages[2].Start,"CameraReveal",0,config.Camera)
check(high.Drop==1 and high.Fov==config.Camera.IntroFov,"Elevated wide entry")
local settle=motion.Sample(plan,plan.Stages[2].Start+config.Camera.IntroDuration,"Rise",.5,config.Camera)
check(math.abs(settle.Drop)<1e-10 and settle.Fov==0,"Entry lands at authored camera framing")
local bounce=motion.Sample(plan,plan.Stages[2].Start+config.Camera.IntroDuration*.8,"Appear",.5,config.Camera)
check(bounce.Drop<0 and bounce.Drop>-.05,"Small landing overshoot")
local impact=motion.Sample(plan,plan.Stages[7].Start,"Flash",0,config.Camera)
local calm=motion.Sample(plan,plan.Stages[7].Start+config.Camera.ImpactDuration,"Reward",.5,config.Camera)
check(impact.Impact==1 and calm.Impact<1e-12,"Impact envelope returns to zero")
for i=0,600 do
 local elapsed=plan.Duration*i/600;local stage,p=timeline.At(plan,elapsed)
 local sample=motion.Sample(plan,elapsed,stage,p,config.Camera)
 check(math.abs(sample.X)<=config.Camera.MaxPositionShake and math.abs(sample.Y)<=config.Camera.MaxPositionShake,"Shake positional cap")
 check(math.abs(sample.Pitch)<=math.rad(config.Camera.MaxDegreesShake)and math.abs(sample.Roll)<=math.rad(config.Camera.MaxDegreesShake),"Shake angular cap")
 check(motion.Cover(stage,p,config.Transition)>=0 and motion.Cover(stage,p,config.Transition)<=.5,"Shutters remain within screen")
end
-- Real local prompt lease; independent spectator prompt never enters scope.
local prompts=standalone("StandPromptVisibility")
local stand=object("Model");local prompt=add(stand,object("ProximityPrompt",{Enabled=true}))
local disabled=add(stand,object("ProximityPrompt",{Enabled=false}))
local spectatorPrompt=object("ProximityPrompt",{Enabled=true})
local lease=prompts.Acquire(stand,"buyer")
check(not prompt.Enabled and not disabled.Enabled and spectatorPrompt.Enabled,"Only selected local stand prompts hidden")
prompt.Enabled=true;check(not prompt.Enabled,"Server enable does not expose prompt during opening")
local dynamic=add(stand,object("ProximityPrompt",{Enabled=true}));check(not dynamic.Enabled,"Dynamic prompt hidden")
prompts.Release(lease);prompts.Release(lease)
check(prompt.Enabled and dynamic.Enabled and not disabled.Enabled,"Prompt exact previous state restored")
check(lease.Released and next(lease.Saved)==nil and lease.Connection==nil,"Prompt lease cleaned")
local hud={Top={},Bottom={},Overlay={Visible=false}}
function hud:FindFirstChild(name)return if name=="ShutterTop"then self.Top elseif name=="ShutterBottom"then self.Bottom else self.Overlay end
local transition=standalone("CinematicTransition",{UDim2={fromScale=function(x,y)return {X=x,Y=y}end}})
transition.Update(hud,.5);check(hud.Top.Size.Y==.5 and hud.Bottom.Size.Y==.5 and hud.Top.Visible,"Two shutters cover viewport")
transition.Reset(hud);check(not hud.Top.Visible and not hud.Bottom.Visible and not hud.Overlay.Visible,"Cleanup hides shutters without touching overlay")
print("PASS CrateCinematicV23: "..count.." isolated assertions including V2.2 lifecycle; visual acceptance NOT RUN")
