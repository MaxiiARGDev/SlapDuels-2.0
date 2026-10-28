--!nonstrict
-- Isolated contract/security tests. No Roblox process, players or persistence.
local passed=0
local function check(value,label) assert(value,label);passed+=1 end
local function load(name,env)
 local fn=assert(loadstring(Sources[name],name));setfenv(fn,setmetatable(env or {},{__index=getfenv()}));return fn()
end
local Fixture=load("Fixture",{Sources=Sources})
local environment={script={Parent={MovementGuard=true}},require=function()return {}end}
local registry,modules,options=Fixture.Build(environment)
local Registry=load("Registry")
local catalog=registry.GetPublicCatalog()
check(#catalog.Order==5 and #registry.GetDiagnostics()==0,"Exactly five valid existing abilities")
for id,expected in pairs({Dash={.2,11},StrongSlap={15,25},AirJumps={15,20},DevilSpeed={5,14},Invisible={5,35}}) do
 local e=registry:Get(id)
 check(e.Public.Duration==expected[1] and e.Public.Cooldown==expected[2],"Original timing: "..id)
 check(not e.Shop.PurchaseEnabled and not e.Shop.PriceApproved,"No new approved price: "..id)
 check(e.Public.Config==nil and e.Public.Start==nil and e.Public.Shop==nil,"Private fields excluded: "..id)
end
check(registry:Get("Dash").Config.DistanceStuds==24,"Dash distance unchanged")
check(registry:Get("StrongSlap").Assets.Cues.Impact.Lift==25,"Strong visual lift unchanged")
check(registry:Get("AirJumps").Config.AirJumpStrength==32 and registry:Get("AirJumps").Config.MaxConsecutiveAirJumps==4,"Air movement unchanged")
check(registry:Get("DevilSpeed").Config.SpeedMultiplier==2.4 and registry:Get("DevilSpeed").Config.MaxSpeed==48,"Speed balance unchanged")
check(registry:Get("Invisible").Assets.Profile=="InvisibleAvatar","Invisibility declares reviewed profile")
check(not pcall(function()catalog.Items.Dash.Cooldown=1 end),"Public catalog is deeply immutable")
check(not pcall(function()registry:Get("Dash").Config.DistanceStuds=500 end),"Server config is immutable")
check(registry:IsSealed() and registry.Register==nil,"No runtime registration API")

local function clone(t)
 if type(t)~="table" then return t end
 local c={} for k,v in pairs(t)do c[k]=clone(v)end return c
end
local function build(overrides)
 local o={} for k,v in pairs(options)do o[k]=v end
 for k,v in pairs(overrides or {})do o[k]=v end
 return Registry.Build(o)
end
local function invalid(change,reason)
 local bad=clone(modules.DashAbility);change(bad)
 local r=build({Load=function(value)return if value==modules.DashAbility then bad else value end})
 check(r:Get("Dash")==nil and #r.GetPublicCatalog().Order==4,reason.." contained to one ability")
 check(#r:GetDiagnostics()>=1,reason.." emits diagnostic")
end
invalid(function(m)m.Descriptor.Id=""end,"Invalid ID")
invalid(function(m)m.Descriptor.Cooldown=0/0 end,"Nonfinite cooldown")
invalid(function(m)m.Descriptor.Duration=-1 end,"Negative duration")
invalid(function(m)m.Descriptor.Icon="http://unsafe"end,"Invalid icon")
invalid(function(m)m.Start=nil end,"Missing Start")
invalid(function(m)m.Cancel=nil end,"Missing Cancel")
invalid(function(m)m.Step=true end,"Invalid optional callback")
invalid(function(m)m.Config.DistanceStuds=1000 end,"Out of range configuration")
invalid(function(m)m.Config.Economy=function()end end,"Undeclared executable configuration")
invalid(function(m)m.Dependencies={"UnapprovedHelper"}end,"Missing dependency")
invalid(function(m)m.Input.Primary="ExecuteClientCode"end,"Unapproved input profile")
invalid(function(m)m.Actions={Sync={Input="None"}};m.OnAction=function()end end,"Reserved action")
invalid(function(m)m.Assets.Profile="ArbitraryScript"end,"Unapproved presentation profile")
invalid(function(m)m.Assets.Key={}end,"Nonserializable asset key")
invalid(function(m)m.Shop.PurchaseEnabled=true end,"Unapproved purchase")
invalid(function(m)m.IsTemplate=true end,"Template cannot register")
invalid(function(m)m.Hooks={Profile="SetCoins",BeforeHit=function()end,Consume=function()end}end,"Economy hook denied")
local missing=build({Resolve=function(name)return if name=="DashAbility" then nil else modules[name] end})
check(missing:Get("Dash")==nil and missing:Get("StrongSlap")~=nil,"Missing ModuleScript contained")
local raised=build({Load=function(m)if m==modules.DashAbility then error("module failure")end return m end})
check(raised:Get("Dash")==nil and raised:Get("Invisible")~=nil,"Require error contained")
local noAssets=build({CheckAssets=function(a)return a.Key~="Dash","MissingEffectOrigin"end})
check(noAssets:Get("Dash")==nil and #noAssets.GetPublicCatalog().Order==4,"Missing physical asset contained")
local loaded={}
build({Manifest={"DashAbility"},Load=function(m)table.insert(loaded,m);return m end})
check(#loaded==1 and loaded[1]==modules.DashAbility,"Only explicit manifest modules execute")
local unauthorizedLoads=0
local unauthorized=build({Manifest={"Unauthorized"},Resolve=function()return {}end,IsModule=function()return false end,
 Load=function()unauthorizedLoads+=1 end})
check(unauthorizedLoads==0 and #unauthorized.GetPublicCatalog().Order==0,"Class/location approval precedes require")
local duplicate=clone(modules.StrongSlapAbility);duplicate.Descriptor.Id="Dash"
local duplicates=build({Load=function(m)return if m==modules.StrongSlapAbility then duplicate else m end})
check(duplicates:Get("Dash")==nil and duplicates:Get("StrongSlap")==nil and #duplicates.GetPublicCatalog().Order==3,"All duplicate IDs rejected")
local repeated=build({Manifest={"DashAbility","DashAbility"}})
check(#repeated.GetPublicCatalog().Order==1 and #repeated.GetDiagnostics()==1,"Repeated manifest entry diagnosed without duplicate load")
local disabled=clone(modules.DashAbility);disabled.Enabled=false
local rDisabled=build({Load=function(m)return if m==modules.DashAbility then disabled else m end})
check(not rDisabled:Get("Dash").Enabled and rDisabled.GetPublicCatalog().Items.Dash==nil,"Disabled module unavailable to public catalog")
check(Registry.Initialize(options),"Initial boot registration succeeds")
local ok,reason=Registry.Initialize(options)
check(not ok and reason=="RegistryAlreadySealed","Second initialization rejected")
local cyclic=clone(modules.DashAbility);cyclic.Actions={};cyclic.Descriptor.Extra=cyclic
cyclic.Assets.Extra=cyclic;cyclic.Shop.Extra=cyclic
local projected=build({Load=function(m)return if m==modules.DashAbility then cyclic else m end})
check(projected:Get("Dash")~=nil and projected:Get("Dash").Public.Extra==nil,"Unknown fields cannot leak cycles or server data")

local Catalog=load("Catalog")
check(Catalog.Apply(catalog) and #Catalog.Get().Order==5,"Client accepts server metadata")
check(not Catalog.Apply(catalog),"Repeated catalog version is ignored")
local bad=clone(catalog);bad.Version=2;bad.Items.Dash.Start=function()end
check(not Catalog.Apply(bad),"Executable metadata rejected by client cache")
bad=clone(catalog);bad.Version=2;bad.Items.Dash.Cooldown=0/0
check(not Catalog.Apply(bad),"Nonfinite client metadata rejected")
bad=clone(catalog);bad.Version=2;table.insert(bad.Order,"Dash")
check(not Catalog.Apply(bad),"Duplicated public ID rejected")
check(Catalog.Get().Version==1,"Invalid catalog cannot replace last valid catalog")
local Callbacks=load("Callbacks")
check(Callbacks.Call(function()return true end),"Non-yielding lifecycle accepted")
local success,why=Callbacks.Call(function()error("failure")end)
check(not success and why:find("failure"),"Lifecycle errors contained")
local late=false
success,why=Callbacks.Call(function()coroutine.yield();late=true end)
check(not success and why=="CallbackYielded" and not late,"Yielding callback closed before late resume")
local runtime=Callbacks.Runtime(table.freeze({SessionId="S",Config=registry:Get("Dash").Config}))
runtime.CustomState=2
check(runtime.CustomState==2 and runtime.Session==nil and runtime.Player==nil and runtime.Services==nil,"Runtime limits injected capabilities")
check(not pcall(function()runtime.SessionId="other"end),"Runtime identity is read-only")
check(not pcall(function()runtime.Config.DistanceStuds=1000 end),"Runtime config immutable")
local strong=registry:Get("StrongSlap")
local charge=Callbacks.Runtime({})
strong.Module.Start(charge)
check(strong.Hooks.BeforeHit(charge) and strong.Hooks.Consume(charge),"Impact hook consumes an armed charge")
check(not strong.Hooks.Consume(charge) and not strong.Hooks.BeforeHit(charge),"Impact charge cannot consume twice")
strong.Module.Cancel(charge);strong.Module.Cancel(charge)
check(charge.State=="Consumed","Cleanup is idempotent after impact consumption")
local Input=load("Input",{Vector3={zero={}},typeof=function(v)return type(v)=="table" and v.Kind or type(v)end})
check(Input.Validate("None",{Direction="malicious"}),"No-input capability ignores unrequested data")
check(not Input.Validate("Direction",{Direction={Kind="Vector3",X=0/0,Y=0,Z=0,Magnitude=0}}),"Nonfinite directional input rejected")
check(not Input.Validate("Direction",{Direction={Kind="Vector3",X=9,Y=0,Z=0,Magnitude=9}}),"Oversized direction rejected")
check(not Input.Validate("CustomExecution",{}),"Unknown input capability rejected")
check(load("Template").IsTemplate==true and not table.find(options.Manifest,"AbilityTemplate"),"Template is unregistered and explicitly rejected")
print(string.format("PASS: %d isolated registry/security assertions; no Studio/gameplay/cloud execution.",passed))
