--!nonstrict
-- Table-based scheduler/input/remote mocks only. Never invokes Studio test APIs.
local count=0
local function check(v,label)assert(v,label);count+=1 end
local function load(name,env)
 local f=assert(loadstring(Sources[name],name));setfenv(f,setmetatable(env or {},{__index=getfenv()}));return f()
end
local enabled,studio,clock=false,true,1
local output,encoded={},{}
local rs={GetAttribute=function()return enabled end}
local http={GenerateGUID=function()return "aaaa-bbbb"end,JSONEncode=function(_,row)table.insert(encoded,row);return "fixture-json"end}
local diag=load("Diagnostics",{game={PlaceId=1,GameId=2,PlaceVersion=3,GetService=function(_,name)
 return ({ReplicatedStorage=rs,RunService={IsStudio=function()return studio end},HttpService=http})[name]
end},os={clock=function()return clock end},print=function(line)table.insert(output,line)end})
check(not diag.Enabled() and diag.NewTrace()==nil,"Diagnostics are disabled by default")
check(not diag.Emit("Server","Received",{UserId=-1}) and #output==0,"Disabled logger has no output")
enabled=true;check(diag.Enabled() and diag.NewTrace()=="aaaa-bbbb","Studio opt-in enables trace IDs")
check(diag.Emit("Server","Rejected",{UserId=-1,Reason="Cooldown",Secret="fixture-secret",Callback=function()end}),"Enabled logger accepts controlled fields")
check(encoded[1].UserId==-1 and encoded[1].Secret==nil and encoded[1].Callback==nil,"Whitelist preserves original negative ID and excludes arbitrary values")
check(encoded[1].PlaceVersion==3 and encoded[1].Build=="AbilityMultiplayerFixV1","Build/place provenance is recorded")
check(diag.TraceId("aaaa-bbbb")=="aaaa-bbbb" and diag.TraceId("untrusted text")==nil,"Only bounded GUID-shaped correlation IDs accepted")
for _=1,40 do diag.Emit("Server","Spam",{UserId=-1})end
check(#output==30,"Opt-in logger has a per-user output budget")
check(diag.Emit("Server","OtherPlayer",{UserId=-2}),"Another player's diagnostics have independent budget")
studio=false
check(not diag.Enabled() and not diag.Emit("Server","OutsideStudio",{UserId=-2}),"Published environment cannot enable diagnostics")
studio=true;clock+=1.1
check(diag.Emit("Server","NextWindow",{UserId=-1}),"Budget recovers without timer threads")

-- Actual client Start bindings: E, processed input, text boxes, mobile button.
local function signal()
 local value={Callbacks={}}
 function value:Connect(callback)table.insert(self.Callbacks,callback);return {Disconnect=function()end}end
 function value:Fire(...)for _,fn in ipairs(self.Callbacks)do fn(...)end end
 return value
end
local sent={}
local request={FireServer=function(_,payload)table.insert(sent,payload)end}
local state={OnClientEvent=signal()}
local combat={WaitForChild=function(_,name)return if name=="AbilityRequest" then request else state end}
local remotes={WaitForChild=function()return combat end}
local shared={AbilityDefinitions="Definitions",AbilityCatalog="Catalog",AbilityDiagnostics="Diagnostics"}
local rsClient={Shared=shared,WaitForChild=function()return remotes end}
local hum={WalkSpeed=16,PlatformStand=false,MoveDirection={X=0,Y=0,Z=-1}}
local char={FindFirstChildOfClass=function()return hum end,GetAttribute=function(_,name)return if name=="ArenaPhysicsGeneration" then 1 else nil end}
local hud={AbilityButton={Activated=signal()},ChangeAbilityButton={Activated=signal()},AbilitySelectionFrame={}}
local player={UserId=-1,Character=char,GetAttribute=function()return "S"end,GetAttributeChangedSignal=function()return signal()end,
 WaitForChild=function()return {WaitForChild=function()return hud end}end}
local focus
local input={InputBegan=signal(),JumpRequest=signal(),GetFocusedTextBox=function()return focus end}
local render={RenderStepped=signal()}
local settings=load("Definitions")
local catalog={Get=function()return {Version=1}end,GetItem=function(_,id)return nil end,Apply=function()return true end}
catalog.GetItem=function(id)return if id=="Dash" then {Input={Primary="Direction"}} else nil end
local clientRows={}
local clientDiag={Build="AbilityMultiplayerFixV1",Enabled=function()return enabled end,NewTrace=function()return if enabled then "aaaa-bbbb" else nil end,
 Forget=function()end,Emit=function(side,phase,row)table.insert(clientRows,{Side=side,Phase=phase,Values=row})end}
local presentation={new=function()return {Clear=function()end,Tick=function()end,Reconcile=function()end}end}
local selection={new=function()return {Open=function()end,Render=function()end,Destroy=function()end}end}
local modules={AbilityPresentation="Presentation",AbilitySelection="Selection"}
local serviceMap={Players={LocalPlayer=player},ReplicatedStorage=rsClient,UserInputService=input,RunService=render}
local controller=load("AbilityController",{game={GetService=function(_,name)return serviceMap[name]end},script={Parent={Parent={Abilities=modules}}},
 require=function(name)return ({Definitions=settings,Catalog=catalog,Diagnostics=clientDiag,Presentation=presentation,Selection=selection})[name]end,
 task={spawn=function(fn)fn()end},os={clock=function()return clock end},Enum={KeyCode={E="E"}}})
controller:Init({});controller._render=function()end
enabled=false;controller:Start({})
check(#sent==1 and sent[1].Action=="Sync","Client requests authoritative state after binding existing remotes")
local snapshot={Kind="State",Revision=1,SessionId="S",RoundId="R",AbilityId="Dash",Playing=true,LifeId="L",CharacterGeneration=1}
state.OnClientEvent:Fire(snapshot)
clock+=1;input.InputBegan:Fire({KeyCode="E"},false)
check(#sent==2 and sent[2].Action=="Activate" and sent[2].TraceId==nil,"Free default Dash is requested by E with diagnostics off")
check(sent[2].SessionId=="S" and sent[2].RoundId=="R" and sent[2].LifeId=="L" and sent[2].CharacterGeneration==1,"Client preserves session/round/life/generation contract")
clock+=1;hud.AbilityButton.Activated:Fire()
check(#sent==3 and sent[3].Action=="Activate","Existing mobile/UI button follows same activation path")
clock+=1;input.InputBegan:Fire({KeyCode="E"},true)
check(#sent==3,"Processed input cannot activate ability")
focus=true;input.InputBegan:Fire({KeyCode="E"},false);focus=nil
check(#sent==3,"Typing in text box cannot activate ability")
enabled=true;clock+=1;input.InputBegan:Fire({KeyCode="E"},false)
check(#sent==4 and sent[4].TraceId=="aaaa-bbbb","Opt-in E request adds only correlation metadata")
local previous=controller._payload
state.OnClientEvent:Fire({Kind="AbilityDiagnostic",Result="Rejected",Reason="Cooldown",TraceId="aaaa-bbbb",SessionId="S",RoundId="R",AbilityId="Dash"})
check(controller._payload==previous and controller._revision==1,"Diagnostic reply never changes authoritative HUD/cooldown snapshot")
local gotResult=false
for _,r in ipairs(clientRows)do if r.Phase=="ServerResult" and r.Values.Reason=="Cooldown" then gotResult=true end end
check(gotResult,"Exact server rejection reaches requester diagnostics")
snapshot.Playing=false;clock+=1;hud.AbilityButton.Activated:Fire()
check(#sent==4,"NotPlaying remains an activation gate")
snapshot.Playing=true;hum.PlatformStand=true;clock+=1;hud.AbilityButton.Activated:Fire()
check(#sent==4,"Ragdoll/platform stand remains an activation gate")
print(string.format("PASS: %d isolated diagnostics/client-input assertions; no Studio/gameplay/cloud execution.",count))
