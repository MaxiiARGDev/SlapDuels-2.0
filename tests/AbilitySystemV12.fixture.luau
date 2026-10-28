-- Pure fixture; loads the actual five module contracts and actual Registry.Build.
local Fixture={}
function Fixture.Load(name,environment)
 local f=assert(loadstring(Sources[name],name))
 setfenv(f,setmetatable(environment or {},{__index=getfenv()}));return f()
end
function Fixture.Build(environment,decorate)
 local load=Fixture.Load
 local names={DashAbility="Dash",StrongSlapAbility="Strong",AirJumpsAbility="Air",
  DevilSpeedAbility="Speed",InvisibilityAbility="Invisible"}
 local modules={}
 for name,key in pairs(names) do
  local moduleEnvironment=environment
  if key=="Speed" then
   local config=load("Config",{Color3={fromRGB=function(...)return {...}end},Vector3={new=function(...)return {...}end}})
   local movement=load("Movement",{game={ReplicatedStorage={Shared={Config=true}}},require=function()return config end})
   moduleEnvironment=table.clone(environment or {})
   moduleEnvironment.script={Parent={Parent={Services={Respawn={MovementSpeed=movement}}}}}
   moduleEnvironment.require=function(value)return value end
  end
  modules[name]=load(key,moduleEnvironment)
  if decorate then decorate(modules[name]) end
 end
 local options={Manifest=load("Manifest"),DefaultId="Dash",Resolve=function(name)return modules[name]end,
  IsModule=function(value)return type(value)=="table"end,Load=function(value)return value end,
  HasDependency=function(name)return name=="MovementGuard"end,CheckAssets=function()return true end}
 return load("Registry").Build(options),modules,options
end
return Fixture
