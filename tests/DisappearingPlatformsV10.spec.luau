-- Actual controller, policy and map lifecycle; all physics, tweens and players are mocks.
local count=0
local function check(v,m)assert(v,m);count+=1 end
local function signal()
 local s={Items={}}
 function s:Connect(fn)local c={Connected=true,Fn=fn};function c:Disconnect()self.Connected=false end;table.insert(self.Items,c);return c end
 function s:Fire(...)for _,v in ipairs(table.clone(self.Items))do if v.Connected then v.Fn(...)end end end
 function s:Count()local n=0;for _,v in ipairs(self.Items)do if v.Connected then n+=1 end end;return n end
 return s
end
local vm={};vm.__index=function(t,k)if k=='Magnitude'then return math.sqrt(t.X*t.X+t.Y*t.Y+t.Z*t.Z)end;return vm[k]end
local function V(x,y,z)return setmetatable({X=x,Y=y,Z=z},vm)end
vm.__add=function(a,b)return V(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
vm.__sub=function(a,b)return V(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
vm.__mul=function(a,b)if type(a)=='number'then a,b=b,a end;return V(a.X*b,a.Y*b,a.Z*b)end
function vm:Dot(b)return self.X*b.X+self.Y*b.Y+self.Z*b.Z end
local cm={};cm.__index=cm
local function CF(position,angle)
 local a=angle or 0;return setmetatable({Position=position or V(0,0,0),Angle=a,UpVector=V(-math.sin(a),math.cos(a),0)},cm)
end
function cm:PointToObjectSpace(p)local d=p-self.Position;local a=self.Angle;return V(math.cos(a)*d.X+math.sin(a)*d.Y,-math.sin(a)*d.X+math.cos(a)*d.Y,d.Z)end
function cm:PointToWorldSpace(p)local a=self.Angle;return self.Position+V(math.cos(a)*p.X-math.sin(a)*p.Y,math.sin(a)*p.X+math.cos(a)*p.Y,p.Z)end
function cm:Inverse()return CF(-1*self.Position,-self.Angle)end
cm.__mul=function(a,b)return CF(a.Position+b.Position,a.Angle+b.Angle)end
local function node(class,name)
 local n={ClassName=class,Name=name,Children={},Attrs={},Destroying=signal(),AncestryChanged=signal()}
 if class=='Part'then n.Size=V(10,1,10);n.CFrame=CF();n.Position=V(0,0,0);n.AssemblyLinearVelocity=V(0,0,0);n.CanCollide=true;n.CanQuery=true;n.Transparency=0;n.CollisionGroup='Default'end
 function n:IsA(k)return self.ClassName==k or k=='BasePart'and self.ClassName=='Part'end
 function n:FindFirstChild(k)for _,c in ipairs(self.Children)do if c.Name==k then return c end end end
 function n:FindFirstChildOfClass(k)for _,c in ipairs(self.Children)do if c:IsA(k)then return c end end end
 function n:GetChildren()return self.Children end
 function n:GetDescendants()local out={};for _,c in ipairs(self.Children)do table.insert(out,c);for _,d in ipairs(c:GetDescendants())do table.insert(out,d)end end;return out end
 function n:IsDescendantOf(parent)local p=self.Parent;while p do if p==parent then return true end;p=p.Parent end;return false end
 function n:SetAttribute(k,v)self.Attrs[k]=v end
 function n:GetAttribute(k)return self.Attrs[k]end
 function n:GetPivot()return self.CFrame or CF()end
 function n:PivotTo(cf)self.CFrame=cf end
 function n:Destroy()self.Destroying:Fire();self.Parent=nil;self.Destroyed=true;self.AncestryChanged:Fire()end
 function n:Clone()
  local c=node(self.ClassName,self.Name)
  for _,k in {'Size','CFrame','Position','CanCollide','Transparency','AssemblyLinearVelocity'}do c[k]=self[k]end
  for _,child in ipairs(self.Children)do local x=child:Clone();x.Parent=c;table.insert(c.Children,x)end
  return c
 end
 return n
end
local function put(p,n)n.Parent=p;table.insert(p.Children,n);return n end
local world=node('Workspace','Workspace');local templates=node('ServerStorage','ServerStorage');local players=node('Players','Players')
local heartbeat=signal();local clock=0;local timers={};local tweens={};local rayHit;local rays=0;local lastParams
function world:Raycast(origin,direction,params)rays+=1;lastParams=params;return rayHit end
local scheduler={delay=function(delay,fn)local t={At=clock+delay,Fn=fn};table.insert(timers,t);return t end,cancel=function(t)t.Cancelled=true end}
local tweenService={}
function tweenService:Create(part,info,goal)
 local t={Part=part,Duration=info.Duration,Goal=goal.Transparency,From=part.Transparency,Completed=signal()}
 function t:Play()self.Start=clock end
 function t:Cancel()self.Cancelled=true;self.Completed:Fire('Cancelled')end
 function t:Destroy()self.Destroyed=true end
 table.insert(tweens,t);return t
end
local function advance(dt)
 clock+=dt
 for _,t in ipairs(table.clone(timers))do if not t.Cancelled and not t.Ran and t.At<=clock then t.Ran=true;t.Fn()end end
 for _,t in ipairs(table.clone(tweens))do if t.Start and not t.Done and not t.Cancelled and not t.Destroyed then
  local a=math.min(1,(clock-t.Start)/t.Duration);t.Part.Transparency=t.From+(t.Goal-t.From)*a
  if a>=1 then t.Done=true;t.Completed:Fire('Completed')end
 end end
end
local enums={HumanoidRigType={R6='R6',R15='R15'},HumanoidStateType={Running='Running',RunningNoPhysics='RunningNoPhysics',Landed='Landed'},
 RaycastFilterType={Exclude='Exclude'},EasingStyle={Linear='Linear'},PlaybackState={Completed='Completed'},ModelStreamingMode={PersistentPerPlayer='PersistentPerPlayer'}}
local loaded={};local services={Workspace=world,ServerStorage=templates,Players=players,RunService={Heartbeat=heartbeat},TweenService=tweenService}
local game={ReplicatedStorage={Shared={DisappearingPlatformsConfig='Config',Config='MainConfig',Types='Types'}},GetService=function(_,name)return services[name]end}
services.ReplicatedStorage=game.ReplicatedStorage
local environment={game=game,workspace=world,Enum=enums,Vector3={new=V},CFrame={new=CF},RaycastParams={new=function()return{}end},
 TweenInfo={new=function(duration,style)return{Duration=duration,Style=style}end},task=scheduler,Instance={new=function(class)return node(class,class)end},
 typeof=function(v)return type(v)=='table'and v.ClassName and 'Instance'or type(v)end,print=function()end,warn=function()end,
 require=function(k)return assert(loaded[k],'Missing '..tostring(k))end,script={Parent={Platforms={PlatformPolicy='Policy'},TeamSpawnResolver='Resolver'}}}
local function load(key)local f=assert(loadstring(Sources[key],key));setfenv(f,setmetatable(table.clone(environment),{__index=getfenv()}));local v=f();loaded[key]=v;return v end
local config=load('Config');local policy=load('Policy');local service=load('Service')
check(policy.Validate(config)~=nil,'Global config valid')
for _,case in {{'FadeDuration',0},{'FadeDuration',-1},{'FadeDuration',0/0},{'FadeDelay',-1},{'DetectionInterval',0},{'DetectionInterval',math.huge},{'Enabled','true'},{'ResetDuringMatch',true},{'DisableCollisionOnFadeComplete',false}}do
 local bad=table.clone(config);bad[case[1]]=case[2];check(policy.Validate(bad)==nil,'Invalid setting rejected '..case[1])
end
local sessions,infos={},{}
local function deps()
 return{World=world,Templates=templates,Players=players,TweenService=tweenService,Heartbeat=heartbeat,
 GetSession=function(id)return sessions[id]end,GetInstance=function(id)return infos[id]end,
 GetPlayerSession=function(p)return sessions[p:GetAttribute('MatchId')]end,
 GetParticipant=function(id,p)for _,v in ipairs(sessions[id].Participants)do if v.Player==p and v.State~='Left'and v.State~='Released'then return v end end end}
end
local controller=service.new(config,deps())
local function makeMap(id,parent)
 local container=put(parent or world,node('Folder','Match_'..id));local map=put(container,node('Model','Map'))
 local geometry=put(map,node('Folder','Geometry'));local model=put(geometry,node('Model','Nested'))
 local folder=put(model,node('Folder','Deep'));local white=put(folder,node('Part','White_Part'))
 local white2=put(geometry,node('Part','White_Part'));local outside=put(map,node('Part','White_Part'))
 put(folder,node('Part','white_part'));put(folder,node('Part','Other'));put(folder,node('Model','White_Part'))
 local s={Id=id,State='Playing',Participants={},GameplayRound={Id='round',Resolved=false}}
 local info={MatchId=id,InstanceModel=map,Container=container,Geometry=geometry};s.InstanceInfo=info;sessions[id]=s;infos[id]=info
 return s,info,white,white2,outside
end
local function player(s,rig)
 local p=put(players,node('Player','P'));p:SetAttribute('MatchId',s.Id)
 local c=put(world,node('Model','Character'));p.Character=c
 local h=put(c,node('Humanoid','Humanoid'));h.Health=100;h.PlatformStand=false;h.HipHeight=rig=='R15'and 2 or 0;h.RigType=rig or 'R6';h.State='Running'
 function h:GetState()return self.State end
 local root=put(c,node('Part','HumanoidRootPart'));root.Size=V(2,2,1);root.Position=V(0,3.5,0)
 local foot=put(c,node('Part',rig=='R15'and 'LeftFoot'or 'Left Leg'));foot.Size=V(1,2,1)
 table.insert(s.Participants,{Player=p,State='Active'})
 return p,h,root
end
local function hit(part,pos,normal)rayHit={Instance=part,Position=pos or V(0,.5,0),Normal=normal or part.CFrame.UpVector}end
local s,info,white,white2,outside=makeMap('one')
check(controller:BindMap(s,info),'Authorized active clone registered')
local record=controller.Maps.one
check(record.Geometry==info.Geometry,'Geometry identified')
check(record.Parts[white]~=nil,'Nested Model + Folder discovered')
check(record.Parts[white2]~=nil,'Direct White_Part discovered')
check(record.Parts[outside]==nil,'White_Part outside Geometry excluded')
local n=0;for _ in pairs(record.Parts)do n+=1 end;check(n==2,'Other names and non-BasePart excluded')
check(white.CanCollide and white.Transparency==0,'Bind does not modify authored properties')
check(controller:BindMap(s,info)and controller.Maps.one==record and heartbeat:Count()==1,'Repeated bind no reset/no duplicate detector')
local p,h,root=player(s)
check(policy.ExpectedHeight(p.Character,h,root)==3,'R6 actual leg height included')
local p15,h15,r15=player(s,'R15');check(policy.ExpectedHeight(p15.Character,h15,r15)==3,'R15 HipHeight included')
hit(white,V(5,0,0),V(1,0,0));controller:Step(.1);check(record.Parts[white].State=='Idle','Lateral contact rejected')
hit(white,V(0,-.5,0),V(0,-1,0));controller:Step(.1);check(record.Parts[white].State=='Idle','Underside rejected')
hit(outside);controller:Step(.1);check(record.Parts[white].State=='Idle','Ray hitting unregistered object/accessory ignored')
hit(white);h.State='Freefall';h15.State='Jumping';controller:Step(.1);check(record.Parts[white].State=='Idle','Jump and freefall do not trigger')
h.State='Running';h15.State='Running';root.Position=V(0,4,0);r15.Position=V(0,4,0);controller:Step(.1)
check(record.Parts[white].State=='Idle','Too high above support rejected')
root.Position=V(0,3.5,0);r15.Position=V(0,3.5,0);root.AssemblyLinearVelocity=V(0,8,0);r15.AssemblyLinearVelocity=V(0,-12,0);controller:Step(.1)
check(record.Parts[white].State=='Idle','Fast vertical flight rejected even with stale running state')
root.AssemblyLinearVelocity=V(0,0,0);r15.AssemblyLinearVelocity=V(0,0,0)
p:SetAttribute('MatchId','wrong');p15.Parent=nil;controller:Step(.1);check(record.Parts[white].State=='Idle','Foreign/disconnected players rejected')
p:SetAttribute('MatchId',s.Id);p15.Parent=players
local old=s.Participants;s.Participants={{Player=node('Part','Decoration'),State='Active'}};controller:Step(.1);check(record.Parts[white].State=='Idle','Physical object not a Player rejected');s.Participants=old
h.PlatformStand=true;h15.Health=0;controller:Step(.1);check(record.Parts[white].State=='Idle','Ragdoll and dead players rejected');h.PlatformStand=false;h15.Health=100
local before=#tweens;controller:Step(.05);check(#tweens==before,'Detection interval honored');controller:Step(.05)
check(record.Parts[white].State=='Fading'and #tweens==before+1,'Two simultaneous players create exactly one tween')
check(lastParams.RespectCanCollide and lastParams.FilterDescendantsInstances[1]~=nil,'Physical query excludes avatar and respects collision')
check(white.CanCollide and white.Transparency==0,'Collision retained at start')
advance(1);check(math.abs(white.Transparency-.5)<.001 and white.CanCollide,'Progressive midpoint + collision still active')
controller:Step(.1);check(#tweens==before+1,'Repeated support does not restart fade')
advance(1);check(white.Transparency==1 and not white.CanCollide and record.Parts[white].State=='Disappeared','Completed fade alone removes collision')
check(not controller:_trigger(record,white),'Disappeared part cannot activate twice')
local completedTween=tweens[#tweens];check(completedTween.Destroyed and completedTween.Completed:Count()==0,'Completed tween resources released')
for _,state in {'PointRestartCountdown','Playing','Ending'}do
 s.State=state;s.PointInProgress=state=='PointRestartCountdown';controller:Step(.1)
 check(white.Transparency==1 and not white.CanCollide,'No reset during '..state)
end
s.State='Playing';s.PointInProgress=false;s.GameplayRound={Id='sudden-death'};controller:Step(.1)
check(not white.CanCollide,'Sudden death does not restore platform')
local replacement=player(s);controller:Step(.1);check(not white.CanCollide,'New Character/player does not restore platform')
-- Local orientation, not global Y. A sloped top is accepted; its side is rejected.
local rotated=node('Part','White_Part');rotated.CFrame=CF(V(2,1,0),math.rad(30))
local top=rotated.CFrame:PointToWorldSpace(V(0,.5,0));local rr={Position=top+V(0,3,0),AssemblyLinearVelocity=V(0,0,0)}
check(policy.IsTopSupport(rotated,rr,{Instance=rotated,Position=top,Normal=rotated.CFrame.UpVector},3,config),'Rotated local top accepted')
check(not policy.IsTopSupport(rotated,rr,{Instance=rotated,Position=top,Normal=V(1,0,0)},3,config),'Rotated side normal rejected')
rr.AssemblyLinearVelocity=V(16*math.cos(math.rad(30)),16*math.sin(math.rad(30)),0)
check(policy.IsTopSupport(rotated,rr,{Instance=rotated,Position=top,Normal=rotated.CFrame.UpVector},3,config),'Walking tangentially up a slope is valid support')
-- Per-map ownership and all supported team sizes.
for size=1,4 do
 local sid='mode'..size;local ms,mi,part=makeMap(sid);check(controller:BindMap(ms,mi),'Mode '..size..'v'..size..' binds')
 for _=1,size*2 do player(ms)end
 hit(part);controller:Step(.1);check(controller.Maps[sid].Parts[part].State=='Fading','All modes detect own players')
 controller:UnbindMap(sid,mi)
end
check(record.Parts[white2].State=='Idle','Other maps cannot alter this map state')
-- Configurable delay and duration; duplicate users cannot restart the delay.
local delayConfig=table.clone(config);delayConfig.FadeDelay=.4;delayConfig.FadeDuration=3
local delayed=service.new(delayConfig,deps());local ds,di,dp=makeMap('delay');player(ds);hit(dp);delayed:BindMap(ds,di);delayed:Step(.1)
local dr=delayed.Maps.delay;check(dr.Parts[dp].State=='Triggered'and dp.CanCollide,'Delay state reserves without collision change')
local beforeDelay=#tweens;delayed:Step(.1);advance(.2);check(#tweens==beforeDelay,'Delay does not start tween early')
advance(.2);check(dr.Parts[dp].State=='Fading'and tweens[#tweens].Duration==3,'Configured delay and duration applied')
advance(1.5);check(math.abs(dp.Transparency-.5)<.001 and dp.CanCollide,'Custom duration progressive midpoint')
local late=tweens[#tweens].Completed.Items[1].Fn;local savedAlpha=dp.Transparency
di.InstanceModel:Destroy();check(delayed.Maps.delay==nil and delayed.Heartbeat==nil,'Map destruction unbinds and stops detector')
late('Completed');check(dp.Transparency==savedAlpha and dp.CanCollide,'Late completed callback cannot modify removed map')
check(tweens[#tweens].Cancelled and tweens[#tweens].Destroyed,'Map teardown cancels and destroys tween')
check(di.InstanceModel.Destroying:Count()==0 and di.InstanceModel.AncestryChanged:Count()==0,'Map listeners cleaned')
local stop=service.new(delayConfig,deps());local xs,xi,xp=makeMap('cancel-delay');player(xs);stop:BindMap(xs,xi);hit(xp);stop:Step(.1)
local pending=stop.Maps[xs.Id].Parts[xp].Timer;stop:UnbindMap(xs.Id,xi);check(pending.Cancelled,'Pending delay cancelled')
pending.Fn();check(xp.CanCollide and xp.Transparency==0,'Late delay cannot mutate unbound map')
-- Terminal sessions stop callbacks even before destruction is requested.
hit(white2);controller:Step(.1);local fading=tweens[#tweens];local callback=fading.Completed.Items[1].Fn;s.Closing=true
callback('Completed');check(white2.CanCollide,'Closing session cannot commit delayed collision change')
controller:Step(.1);check(controller.Maps.one==nil,'Closed/closing sessions are removed from monitoring')
local fresh,fi,fp=makeMap('fresh');controller:BindMap(fresh,fi);check(fp.Transparency==0 and fp.CanCollide,'New clone starts pristine')
local templateSession,templateInfo=makeMap('template',templates)
check(not controller:BindMap(templateSession,templateInfo),'ServerStorage templates cannot be bound')
local absent,ai=makeMap('no-geometry');ai.InstanceModel.Children={};check(not controller:BindMap(absent,ai),'Missing Geometry rejected')
local disabledConfig=table.clone(config);disabledConfig.Enabled=false
local disabled=service.new(disabledConfig,deps());check(disabled:BindMap(fresh,fi)and disabled.Heartbeat==nil,'Disabled setting creates no monitor')
-- Actual MatchInstanceService integration (clone + ready hook + cleanup), no real models.
-- Independently load unchanged KillPart/void entry points and contact geometry.
loaded.Transit=load('Transit');loaded.ArenaPolicy=load('ArenaPolicy')
loaded.MainConfig={};loaded.Constants={};loaded.Types={};loaded.DeathContract={};loaded.Effects={};loaded.DeathSettings={}
local sh=game.ReplicatedStorage.Shared
sh.Constants='Constants';sh.DeathFeedbackContract='DeathContract';sh.ArenaRespawnPolicy='ArenaPolicy';sh.DeathEffectDefinitions='Effects';sh.DeathFeedbackConfig='DeathSettings'
environment.script={Parent={Respawn={CompetitiveTransit='Transit'},TeamSpawnResolver='Resolver'}}
function players:GetPlayerFromCharacter(c)for _,pl in ipairs(self.Children)do if pl.Character==c and pl.Parent==self then return pl end end end
local eliminations=load('Elimination');local contacts={}
local elim=setmetatable({_processEliminationEvent=function(_,pl,ss,kind,boundary,body)table.insert(contacts,{Player=pl,Session=ss,Kind=kind})end},{__index=eliminations})
local victim,_,victimRoot=player(fresh);local kill=put(fi.Container,node('Part','KillPart'));kill.Size=V(10,4,10)
victimRoot.Position=V(0,0,0);elim:HandleKillPartTouch(kill,victimRoot,fresh)
check(#contacts==1 and contacts[1].Kind=='KillPart'and contacts[1].Player==victim,'Existing KillPart entry forwards supported falling player unchanged')
victimRoot.Position=V(1000,0,0);elim:HandleKillPartTouch(kill,victimRoot,fresh)
check(#contacts==1,'KillPart rejects obsolete distant contact')
victimRoot.Position=V(0,0,0);elim:HandleVoidBoundaryTouch(kill,victimRoot,fresh)
check(#contacts==2 and contacts[2].Kind=='VoidBoundary','Existing void fallback preserved')
elim:HandleKillPartTouch(kill,node('Part','Decoration'),fresh);check(#contacts==2,'NPC/object is not a falling player')
loaded.MainConfig={Arena={BaseOrigin=V(0,0,0),Spacing=V(1000,0,0),MaxSlots=10,VoidBoundarySize=V(100,1,100),VoidBoundaryOffset=V(0,-50,0)}};loaded.Types={}
loaded.Resolver={Resolve=function(map)return {Red={map:FindFirstChild('RedSpawn')},Blue={map:FindFirstChild('BlueSpawn')}},4 end}
local instances=load('Instances');instances._allocatedSlots={};instances._instances={};instances._activeMatchesFolder=put(world,node('Folder','ActiveMatches'))
local mapTemplate=put(templates,node('Model','Template'));local tg=put(mapTemplate,node('Folder','Geometry'));local tp=put(tg,node('Part','White_Part'))
put(mapTemplate,node('Part','RedSpawn'));put(mapTemplate,node('Part','BlueSpawn'));local zone=put(mapTemplate,node('Folder','ZoneWin'));put(zone,node('Part','RedWin'));put(zone,node('Part','BlueWin'))
function instances:_validateMapTemplate()return true,nil,mapTemplate end
function instances:PrepareEndCinematic(id)self._instances[id].EndCinematic=node('Model','Cinematic')end
local registered,destroyed=0,0
instances._context={GetService=function(_,name)if name=='DisappearingPlatformsService'then return{
 BindMap=function(_,session,mapInfo)check(mapInfo.InstanceModel.Parent==mapInfo.Container and mapInfo.EndCinematic~=nil,'Bind only after clone and cinematic validation');registered+=1;return true end,
 UnbindMap=function(_,id,mapInfo)check(mapInfo==nil or not mapInfo.Container.Destroyed,'Unbind before map destruction');destroyed+=1 end}end end}
local mapSession={Id='integration',TeamSize=4};local ci=instances:CreateInstance(mapSession,'Template')
check(ci~=nil and registered==1 and ci.InstanceModel~=mapTemplate,'Actual CreateInstance registers clone once')
check(instances:CreateInstance(mapSession,'Template')==ci and registered==1,'Existing clone never re-registers/reset')
check(instances:DestroyInstance(mapSession.Id)and destroyed==1,'Actual DestroyInstance cleans platform ownership')
check(tp.Transparency==0 and tp.CanCollide and not mapTemplate.Destroyed,'Original template pristine')
controller:Destroy();stop:Destroy();delayed:Destroy()
check(heartbeat:Count()==0,'No heartbeat or map connections survive cleanup')
print('DisappearingPlatformsV10 PASS '..count..' isolated assertions; gameplay NOT RUN')
