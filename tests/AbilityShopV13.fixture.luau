-- Pure disposable tables; actual production functions, no Studio or cloud.
local Fixture={}
function Fixture.Load(name,env)
 local fn=assert(loadstring(Sources[name],name))
 setfenv(fn,setmetatable(env or {},{__index=getfenv()}));return fn()
end
function Fixture.Profile(coins)
 return {Version=2,Coins=coins,Wins=3,Losses=2,Kills=4,Inventory={
  Owned={Abilities={Dash=true},PointEffects={Basic=true},DeathEffects={BasicKill=true}},
  Equipped={Abilities="Dash",PointEffects="Basic",DeathEffects="BasicKill"}}}
end
function Fixture.New()
 local load=Fixture.Load
 local color={fromRGB=function(...)return {...}end}
 local config=load("Config",{Color3=color,Vector3={new=function(...)return {...}end}})
 local settings=load("Definitions")
 local death=load("DeathSettings")
 local points=load("PointDefinitions")
 local stage=load("Purchase")
 local sourceFixture=load("Fixture",{Sources=Sources})
 local abilities=sourceFixture.Build({script={Parent={MovementGuard=true}},require=function()return {}end})
 local players={}
 local loaded={}
 local function player(id)
  local p={UserId=id,Name="Fixture"..id,Parent=players,__kind="Instance"}
  function p:IsA(name)return name=="Player"end
  return p
 end
 local a,b=player(-1),player(-2);loaded[a]="Loaded";loaded[b]="Loaded"
 local shared={Types="Types",Config="Config",PointEffectDefinitions="PointDefinitions",Constants="Constants",
  AbilityDefinitions="Definitions",DeathFeedbackConfig="DeathSettings"}
 local rs={Shared=shared}
 local sss={Services={PlayerService="PlayerService",AbilityRegistry="Registry"}}
 local gameMock={ReplicatedStorage=rs,ServerScriptService=sss,
  GetService=function(_,name)return ({ReplicatedStorage=rs,ServerScriptService=sss,Players=players})[name]end}
 local socialConfig=load("SocialPlayConfig")
 local streak=load("WinStreak",{game={GetService=function()return {Shared={SocialPlayConfig="SocialPlayConfig"}}end},require=function()return socialConfig end})
 local ps
 local function requireMock(name)
  return assert(({Types={},Config=config,PointDefinitions=points,Constants={},Definitions=settings,
   WinStreak=streak,DeathSettings=death,Purchase=stage,PlayerService=ps,Registry=abilities})[name],tostring(name))
 end
 local env={game=gameMock,script={Parent={Gameplay={WinStreak="WinStreak"},Parent={Shop={ProfilePurchase="Purchase"}}}},require=requireMock,
  typeof=function(value)return if type(value)=="table" and value.__kind then value.__kind else type(value)end,
  warn=function()end,print=function()end}
 local psClass=load("PlayerService",env)
 ps=setmetatable({_data={[a]=Fixture.Profile(10000),[b]=Fixture.Profile(10000)},_coins={},_shopClosing={},
  _shopShutdown=false,_ownedPointEffects={},_equippedPointEffects={},_kills={},_snapshots={},
  _playerDataService={GetLoadState=function(_,p)return loaded[p]end}},{__index=psClass})
 ps._sendDataUpdate=function(self,p)table.insert(self._snapshots,{Player=p,Data=self:GetPlayerData(p)})end
 local provider=load("Provider",env)
 local registryClass=load("ShopRegistry",env)
 local registry=setmetatable({_providers={},_productsById={},_productsByRobloxId={}},{__index=registryClass})
 registry:Register(provider)
 local shopClass=load("Shop",env)
 local shop=setmetatable({_registry=registry,_playerService=ps,_inProgressPurchases={},
  _context={GetService=function(_,name)return if name=="PlayerService" then ps else nil end}},{__index=shopClass})
 ps._context={GetService=function(_,name)return if name=="ShopService" then shop else nil end}
 return {PS=ps,PSClass=psClass,Shop=shop,ShopClass=shopClass,Provider=provider,Registry=registry,
  AbilityRegistry=abilities,Players=players,A=a,B=b,Loaded=loaded,Stage=stage,Env=env,Game=gameMock,
  Config=config,Settings=settings,Death=death,Shared=shared,RS=rs}
end
return Fixture
