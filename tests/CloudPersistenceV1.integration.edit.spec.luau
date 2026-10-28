-- Real services with injected memory, two simulated servers; no Start, Play or cloud.
assert(not game:GetService('RunService'):IsRunning(),'Edit required')
local Services=game.ServerScriptService.Services
local scope=Instance.new('Folder');scope.Name='CloudPersistenceIsolated'
local count=0;local function check(v,m)assert(v,m);count+=1 end
local ok,result=pcall(function()
 local shared=game.ReplicatedStorage.Shared.Progression:Clone();shared.Name='Progression';shared.Parent=scope
 local gameplay=Services.Gameplay:Clone();gameplay.Name='Gameplay';gameplay.Parent=scope
 gameplay.SeasonState.Source=gameplay.SeasonState.Source:gsub('game.ReplicatedStorage.Shared.Progression.Model','script.Parent.Parent.Progression.Model')
 local persistence=Services.Persistence:Clone();persistence.Name='Persistence';persistence.Parent=scope
 local config=game.ReplicatedStorage.Shared.Config:Clone();config.Name='Config';config.Parent=scope
 local memory=require(persistence.InMemoryDataStore).new()
 local Environment=require(persistence.PersistenceEnvironment);local created=0
 local options={IsStudio=true,GameId=10769217377,PlaceId=1,ApprovedProductionUniverseId=10769217377,ProductionStoreName='ExistingStore',CreateInMemory=function()return memory end,CreateProduction=function()created+=1;return memory end}
 check(Environment.ResolveWithOptions(options).ProviderName=='InMemory'and created==0,'Studio never creates cloud provider')
 options.IsStudio=false;options.GameId=99
 check(Environment.ResolveWithOptions(options).Environment=='Blocked'and created==0,'Unknown universe blocked')
 options.GameId=10769217377
 check(Environment.ResolveWithOptions(options).WritesToCloud and created==1,'Approved universe selects injected production provider')
 local function service(name)
  local module=Services.ProgressionService:Clone();module.Name=name
  module.Source=module.Source:gsub("local Run=game:GetService%('RunService'%)","local Run={IsStudio=function()return false end}")
   :gsub('RS.Shared.Progression.Model','script.Parent.Progression.Model')
   :gsub('RS.Shared.Progression.Config','script.Parent.Progression.Config')
   :gsub('RS.Shared.Progression.PassCatalog','script.Parent.Progression.PassCatalog')
  module.Parent=scope;return require(module)
 end
 local a,b=service('A'),service('B');local fake={UserId=1522376993,Name='Owner'}
 function fake:IsA(class)return class=='Player'end
 function fake:GetAttribute()return nil end
 local psModule=Services.PlayerService:Clone();psModule.Name='PlayerService';psModule.Source=psModule.Source:gsub('script%.Parent%.Parent','game.ServerScriptService');psModule.Parent=scope
 local ps=require(psModule);ps.IsShopDataReady=function()return true end;ps.NotifyShopUpdate=function()end
 local pdsModule=Services.PlayerDataService:Clone();pdsModule.Name='PlayerDataService';pdsModule.Source=pdsModule.Source:gsub('require%(ReplicatedStorage.Shared.Config%)','require(script.Parent.Config)');pdsModule.Parent=scope
 local pds=require(pdsModule);pds._store=memory;pds._loadStates={};pds._saving={};pds._persistenceInfo={Environment='Production',ProviderName='RobloxDataStore',WritesToCloud=true}
 ps._getPlayerDataService=function()return pds end;ps._data={};ps._coins={};ps._ownedPointEffects={}
 pds._sessions=require(persistence.ProfileSessions).new(memory,function(raw)return pds:ValidatePlayerData(raw or {Version=2,Coins=7,Wins=0,Losses=0,Kills=0,Inventory={Owned={},Equipped={}}})end,function(player)return ps._data[player]end,{Wait=function()end})
 local loaded,data=pds:LoadPlayer(fake);check(loaded,'Real PlayerDataService obtains session')
 ps._data[fake]=data
 data.Inventory.SlapUnits.demo={UnitId='demo',OwnerUserId=fake.UserId,RewardId='Classic:Gold'}
 data.Inventory.Crates.Gold=3;data.Inventory.CrateOperations.demo={Kind='Purchase',State='Committed'}
 data.Inventory.PremiumReceipts={test={State='Applied'}}
 data.Preferences={MusicEnabled=false,MusicVolume=.25}
 check(pds:SavePlayer(fake,data),'Real service saves complete profile')
 local saved=memory:GetAsync('Player_'..fake.UserId)
 check(saved.Version==3,'Fenced profile version protects against older writers')
 check(saved.Inventory.SlapUnits.demo~=nil and saved.Inventory.Crates.Gold==3 and saved.Inventory.CrateOperations.demo~=nil,'Units/crates/journal preserved')
 check(saved.Preferences.MusicEnabled==false and saved.Preferences.MusicVolume==.25,'Preferences preserved')
 check(saved.Inventory.PremiumReceipts.test.State=='Applied','Existing receipt data preserved')
 local admin={IsAdmin=function(_,p)return p==fake end};local shop={_withShopLock=function(_,_,fn)return fn()end}
 local context={PersistenceInfo={Environment='Production',ProviderName='RobloxDataStore',WritesToCloud=true,GameId=10769217377},PersistenceProvider=memory}
 function context:GetService(name)return ({PlayerService=ps,AdminService=admin,ShopService=shop})[name]end
 for _,s in ipairs({a,b})do s:Init(context);s.HasReward=function()return true end;s.Push=function()end end
 check(a.Enabled and a.Production and a.SeasonKey=='Progression:Season:Production:v1','Production uses separate persistent season key')
 check(not a:StartStudioSeason(),'No automatic production season')
 local info=a:Admin(fake,'AdminInfo',{});check(info.Ok and #info.Presets==1 and info.Presets[1].Id=='LaunchSeason','Studio-only catalogue excluded')
 check(not a:Admin(fake,'Prepare',{Command='Start',PresetId='TestSeason',Days=60}).Ok,'Studio catalogue cannot start in production')
 local first=a:Admin(fake,'Prepare',{Command='Start',PresetId='LaunchSeason',Days=60})
 check(first.Ok,'Global season prepared')
 check(a:Admin(fake,'Apply',{Token=first.Token}).Ok,'Global season persisted')
 check(b:ReadSeason()and b.Season.Active.Id==a.Season.Active.Id,'Other server observes same edition')
 check(memory:GetAsync('Progression:Season:Studio:v1')==nil,'Production does not write Studio season')
 local M=require(shared.Model);data=ps._data[fake];data.Progression=M.Normalize(data.Progression);data.Progression.TotalXP=800;M.Edition(data.Progression,a.Season.Active).XP=800
 local reward=a:Claim(fake,1,false);check(reward.Ok,'Actual claim confirms after durable profile checkpoint')
 saved=memory:GetAsync('Player_'..fake.UserId)
 check(saved.Coins==157 and saved.Progression.Edition.Claimed['1'],'Reward and claim marker atomic in profile')
 check(not a:Claim(fake,1,false).Ok and ps._data[fake].Coins==157,'Repeated claim does not duplicate Coins')
 local ca=a:Admin(fake,'Prepare',{Command='Restart',PresetId='LaunchSeason',Days=30})
 local cb=b:Admin(fake,'Prepare',{Command='Restart',PresetId='LaunchSeason',Days=30})
 check(a:Admin(fake,'Apply',{Token=ca.Token}).Ok,'Restart creates new edition')
 check(not b:Admin(fake,'Apply',{Token=cb.Token}).Ok,'Stale admin revision rejected across servers')
 local snap=a:Snapshot(fake);check(snap.PassXP==0 and snap.TotalXP==800 and snap.Level>0,'Restart clears only pass progress')
 check(ps._data[fake].Coins==157,'Delivered rewards survive restart')
 check(pds:SavePlayer(fake,ps._data[fake],true),'Final save releases real service session')
 pds:Cleanup(fake);ps._data[fake]=nil
 local again,recovered=pds:LoadPlayer(fake);check(again and recovered.Coins==157 and recovered.Inventory.SlapUnits.demo~=nil,'Reconnect recovers complete profile')
 check(recovered.Progression.TotalXP==800 and recovered.Preferences.MusicEnabled==false,'Reconnect recovers XP and preferences')
 return 'PASS: '..count..' real-service production-path assertions; memory only'
end)
scope:Destroy();assert(ok,result);return result
