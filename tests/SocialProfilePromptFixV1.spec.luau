-- Actual targeting/controller, mocked input/world/RPC only. No Studio or gameplay.
local n=0;local function check(v,m)assert(v,m);n+=1 end
local vm={};vm.__index=function(t,k)if k=='Magnitude'then return math.sqrt(t.X*t.X+t.Y*t.Y+t.Z*t.Z)end;return vm[k]end
local function V(x,y,z)return setmetatable({X=x,Y=y,Z=z},vm)end
vm.__sub=function(a,b)return V(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
vm.__mul=function(a,b)return V(a.X*b,a.Y*b,a.Z*b)end
local function signal()
 local s={Items={}};function s:Connect(fn)local c={Fn=fn,Connected=true};function c:Disconnect()self.Connected=false end;table.insert(s.Items,c);return c end
 function s:Fire()for _,c in ipairs(self.Items)do if c.Connected then c.Fn()end end end;return s
end
local function node(class,name)
 local a={ClassName=class,Name=name,Children={},Enabled=true,Attrs={}}
 function a:FindFirstChild(k)return self.Children[k]end
 function a:FindFirstChildOfClass(k)for _,c in pairs(self.Children)do if c.ClassName==k then return c end end end
 function a:IsA(k)return self.ClassName==k end
 function a:GetAttribute(k)return self.Attrs[k]end
 function a:Destroy()self.Parent=nil;self.Destroyed=true end
 if class=='ProximityPrompt'then a.Triggered=signal();function a:InputHoldBegin()self.Holding=true end;function a:InputHoldEnd()self.Holding=false end end
 return a
end
local players={};local list={}
local function character(x)
 local c=node('Model','Character');local root=node('Part','HumanoidRootPart');root.Position=V(x,0,0);root.Parent=c;c.Children[root.Name]=root
 local head=node('Part','Head');head.Position=V(x,2,0);head.Parent=c;c.Children.Head=head
 local h=node('Humanoid','Humanoid');h.Health=100;c.Children.Humanoid=h
 return c
end
local function player(id,x)local p=node('Player','P'..id);p.UserId=id;p.DisplayName=p.Name;p.Parent=players;p.Character=character(x);table.insert(list,p);return p end
local me=player(-1,0);local near=player(-2,3);local far=player(-3,7);players.LocalPlayer=me;function players:GetPlayers()return list end
function players:GetPlayerFromCharacter(c)for _,p in ipairs(list)do if p.Character==c then return p end end end
local cameraPosition=V(0,5,-8);local camera={CFrame={Position=cameraPosition},ViewportSize={X=100,Y=100}}
function camera:ScreenPointToRay()return{Origin=cameraPosition,Direction=V(0,0,1)}end;camera.ViewportPointToRay=camera.ScreenPointToRay
local world={CurrentCamera=camera};local blockBody=false;local blockCamera=false;local aim;local lastParams;local calls=0
function world:Raycast(origin,delta,params)
 if delta.Magnitude>100 then return aim and {Instance=aim.Character.Children.Head}or nil end
 calls+=1;lastParams=params
 if origin==cameraPosition then return blockCamera and {}or nil end
 return blockBody and {}or nil
end
local enum={RaycastFilterType={Exclude='Exclude'},KeyCode={F='F',ButtonY='ButtonY'},ProximityPromptExclusivity={AlwaysShow='AlwaysShow'},HighlightDepthMode={Occluded='Occluded'},
 UserInputState={Begin='Begin',End='End',Cancel='Cancel'},ContextActionResult={Pass='Pass',Sink='Sink'},ContextActionPriority={High={Value=3000}}}
local clock=0;local timers={};local focused=false
local scheduler={spawn=function(fn)fn()end,delay=function(seconds,fn)local t={At=clock+seconds,Fn=fn};table.insert(timers,t);return t end,cancel=function(t)t.Cancelled=true end}
local function advance(dt)clock+=dt;for _,t in ipairs(table.clone(timers))do if not t.Cancelled and not t.Ran and t.At<=clock then t.Ran=true;t.Fn()end end end
local cas={};function cas:BindActionAtPriority(name,fn,touch,priority,...)self.Bound={Name=name,Fn=fn,Touch=touch,Priority=priority,Keys={...}}end
function cas:UnbindAction()self.Bound=nil end
local inputService={GetMouseLocation=function()return{X=0,Y=0}end,GetFocusedTextBox=function()return focused end}
local config={InspectDistance=10,PromptHoldSeconds=.5};local loaded={Config=config,Catalog={},Viewports={}}
local rs={Shared={SocialConfig='Config',SlapCrates={Catalog='Catalog'}}}
local game={GetService=function(_,key)return ({Players=players,ReplicatedStorage=rs,RunService={},UserInputService=inputService,ContextActionService=cas,TweenService={}})[key]end}
local function load(key)
 local f=assert(loadstring(Sources[key],key));setfenv(f,setmetatable({game=game,workspace=world,Enum=enum,
 script={Parent={Parent={Social={Targeting='Targeting',ViewportPool='Viewports'}}}},Color3={fromRGB=function()return{}end},
 require=function(k)return loaded[k]end,RaycastParams={new=function()return{}end},task=scheduler,
 Instance={new=function(class)return node(class,class)end}},{__index=getfenv()}));local a=f();loaded[key]=a;return a
end
local T=load('Targeting');local C=load('Controller')
local function visible(p)return T.Visible(world,me,p,cameraPosition)end
check(T.Valid(me,near,10),'Valid nearby player')
check(T.Select(me,list,nil,10,visible)==near,'Approach alone selects closest')
check(T.Select(me,list,far,10,visible)==far,'Aimed player takes priority over nearest')
check(T.Select(me,list,me,10,visible)==near,'Own avatar never selected')
near.Attrs.MatchId='match';check(T.Select(me,list,nil,10,visible)==far,'Players in match excluded');near.Attrs.MatchId=nil
near.Parent=nil;check(T.Select(me,list,nil,10,visible)==far,'Disconnected excluded');near.Parent=players
near.Character.Children.Humanoid.Health=0;check(T.Select(me,list,nil,10,visible)==far,'Dead target excluded');near.Character.Children.Humanoid.Health=100
me.Character.Children.Humanoid.Health=0;check(T.Select(me,list,nil,10,visible)==nil,'Dead viewer excluded');me.Character.Children.Humanoid.Health=100
me.Attrs.MatchId='match';check(T.Select(me,list,nil,10,visible)==nil,'Combat hides social interaction');me.Attrs.MatchId=nil
check(visible(near)and #lastParams.FilterDescendantsInstances==2 and lastParams.FilterDescendantsInstances[2]==near.Character,'LOS excludes whole target and own avatars')
check(lastParams.RespectCanCollide,'LOS respects physical obstacles')
blockBody=true;check(not visible(near)and T.Select(me,list,nil,10,visible)==nil,'Wall between bodies prevents selection');blockBody=false
blockCamera=true;check(not visible(near),'Camera obstruction rejected');blockCamera=false
check(T.Select(me,list,near,10,function(p)return p==far end)==far,'Invisible aimed/nearest skipped for visible candidate')
local outsider=player(-9,11);check(not T.Valid(me,outsider,10),'Range enforced')
local boundary=player(-10,10);check(T.Valid(me,boundary,10),'Exact range accepted');boundary.Parent=nil
local function gui()return{Enabled=false,MainFrame={Status={Text=''}}}end
local notice={Hud={Enabled=true}};function notice:Notice(message)self.Last=message end
local controller=setmetatable({Profile=gui(),Request=gui(),Trade=gui(),Generation=0,
 Context={GetController=function(_,name)return name=='SocialPlayController'and notice end}},{__index=C})
controller.WindowBusy=function()return false end
local opened={};function controller:OpenProfile(id)table.insert(opened,id)end
controller:PollTarget();check(controller.Target==near and controller.Prompt~=nil,'Actual PollTarget creates proximity prompt without aim')
local prompt=controller.Prompt;check(prompt.RequiresLineOfSight==false and prompt.Exclusivity=='AlwaysShow','Own-body occlusion cannot hide prompt')
check(prompt.KeyboardKeyCode=='F'and prompt.GamepadKeyCode=='ButtonY'and prompt.ClickablePrompt,'Unique F/Y plus touch interaction')
check(prompt.HoldDuration==.5 and prompt.MaxActivationDistance==10,'Range/hold duration unchanged')
controller:PollTarget();check(controller.Prompt==prompt,'Stable target does not recreate prompt')
prompt.Triggered:Fire();check(#opened==1 and opened[1]==near.UserId,'Trigger opens correct profile')
check(cas.Bound==nil and controller.Prompt==nil,'Opening immediately unbinds input and consumes prompt')
controller:SetTarget(near);prompt=controller.Prompt
blockBody=true;prompt.Triggered:Fire();check(#opened==1,'Trigger rechecks obstacles');blockBody=false
near.Attrs.MatchId='match';prompt.Triggered:Fire();check(#opened==1,'Trigger rechecks match state');near.Attrs.MatchId=nil
local oldCallback=prompt.Triggered.Items[1].Fn
near.Character=character(3);controller:SetTarget(near);check(controller.Prompt~=prompt and prompt.Destroyed,'Character replacement recreates prompt')
oldCallback();check(#opened==1,'Stale callback cannot open new life')
aim=far;controller:PollTarget();check(controller.Target==far,'Aim selection works through actual poll')
controller.Profile.Enabled=true;controller:PollTarget();check(controller.Target==nil and controller.Prompt==nil and controller.Highlight==nil,'Opening profile cleans prompt and highlight')
controller:Message('visible in profile');check(controller.Profile.MainFrame.Status.Text=='visible in profile','Existing window receives status')
controller.Profile.Enabled=false;controller:Message('visible outside profile');check(notice.Last=='visible outside profile','Closed windows use existing visible Notice')
controller.WindowBusy=function()return true end;controller:PollTarget();check(controller.Target==nil,'Blocked modal window does not offer an unusable prompt')
controller.WindowBusy=function()return false end
-- Explicit keyboard/controller path, without ANY native Triggered event or mouse.
controller:SetTarget(near);local binding=cas.Bound;local openedBefore=#opened
check(binding.Priority==3000 and not binding.Touch,'Context action is scoped, prioritized and creates no extra touch UI')
binding.Fn(nil,'Begin',{KeyCode='F'});advance(.49);check(#opened==openedBefore,'No opening before 0.5 seconds')
binding.Fn(nil,'End',{KeyCode='F'});advance(.1);check(#opened==openedBefore and not controller.ProfileHold,'Early release cancels hold')
binding.Fn(nil,'Begin',{KeyCode='F'});local nativeCallback=controller.Prompt.Triggered.Items[1].Fn;advance(.5)
check(#opened==openedBefore+1 and opened[#opened]==near.UserId,'F alone opens profile without native prompt keyboard event')
nativeCallback();check(#opened==openedBefore+1,'Late native Triggered cannot open twice')
controller:SetTarget(near);binding=cas.Bound;focused=true
check(binding.Fn(nil,'Begin',{KeyCode='F'})=='Pass'and not controller.ProfileHold,'Typing in text/chat does not start a hold');focused=false
binding.Fn(nil,'Begin',{KeyCode='ButtonY'});binding.Fn(nil,'Begin',{KeyCode='ButtonY'});advance(.5)
check(#opened==openedBefore+2,'Y works and repeated Begin does not restart or duplicate hold')
controller:SetTarget(near);binding=cas.Bound;binding.Fn(nil,'Begin',{KeyCode='F'});local lateTimer=controller.ProfileHold.Thread
controller:SetTarget(far);lateTimer.Fn();check(#opened==openedBefore+2,'Target change invalidates even an uncancellable old timer')
binding=cas.Bound;binding.Fn(nil,'Begin',{KeyCode='F'});binding.Fn(nil,'Cancel',{KeyCode='F'});advance(.5)
check(#opened==openedBefore+2 and not controller.ProfileHold,'Input cancellation does not open profile')
binding.Fn(nil,'Begin',{KeyCode='F'});controller:CancelProfileHold();advance(.5)
check(#opened==openedBefore+2,'Focus loss cancellation does not open profile')
binding.Fn(nil,'Begin',{KeyCode='F'});blockBody=true;advance(.5);blockBody=false;binding.Fn(nil,'End',{KeyCode='F'})
check(#opened==openedBefore+2,'Wall appearing during hold prevents opening')
controller:SetTarget(nil);check(cas.Bound==nil and not controller.ProfileHold,'No binding or timer remains without target')
-- Invoke actual failure path, never a server or real profile.
controller.OpenProfile=nil;controller.WindowBusy=function()return false end
controller.Inspect={InvokeServer=function()return{Ok=false,Reason='OutOfRange'}end}
controller:OpenProfile(near.UserId,1);check(notice.Last=='El jugador está fuera del alcance.'and not controller.PendingProfile,'Server rejection visible with profile closed')
print('SocialProfilePromptFixV1 PASS '..n..' isolated assertions; gameplay NOT RUN')
