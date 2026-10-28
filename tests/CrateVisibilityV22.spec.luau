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
print("PASS CrateVisibilityV22: "..count.." isolated assertions; multiplayer/render NOT RUN")
