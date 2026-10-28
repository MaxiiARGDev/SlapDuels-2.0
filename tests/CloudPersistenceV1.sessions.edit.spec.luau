-- Isolated two-server simulation. Never accesses DataStoreService.
assert(not game:GetService('RunService'):IsRunning(),'Edit required')
local Profiles=require(script.ProfileSessions)
local count=0
local function check(v,m)assert(v,m);count+=1 end
local now=100;local uid=0;local records={};local ambiguous=false;local fail=false;local inCallback
local store={}
function store:UpdateAsync(key,callback)
 if fail then error('network unavailable')end
 local nextData=callback(Profiles.Copy(records[key]))
 if inCallback then inCallback()end
 if nextData~=nil then records[key]=Profiles.Copy(nextData)end
 if ambiguous then ambiguous=false;error('committed but response lost')end
 return Profiles.Copy(records[key])
end
local function normalize(raw)
 raw=raw or {Version=2,Coins=0,Inventory={SlapUnits={}},Progression={TotalXP=0},Preferences={MusicEnabled=true,MusicVolume=1}}
 if raw.Version>2 then return false,nil,'IncompatibleVersion'end
 local data=Profiles.Copy(raw);data._Session=nil;data._LastProfileWrite=nil;return true,data
end
local dataA,dataB
local options={Clock=function()return now end,Wait=function()end,Retries=2,NewId=function()uid+=1;return 'id-'..uid end}
local a=Profiles.new(store,normalize,function()return dataA end,options)
local b=Profiles.new(store,normalize,function()return dataB end,options)
local p={UserId=1}
local ok,loaded=a:Load(p);check(ok,'Fresh profile acquired');dataA=loaded
check(not b:Load(p),'Second server rejected while lease active')
dataA.Coins=50;dataA.Inventory.SlapUnits.unit={UnitId='unit',OwnerUserId=1};dataA.Progression={TotalXP=800,Edition={Id='edition',XP=800,Claimed={['1']=true}}}
check(a:Save(p),'Profile save succeeds');check(records.Player_1.Coins==50 and records.Player_1.Progression.Edition.Claimed['1'],'Coins and claim persisted together')
check(records.Player_1.Inventory.SlapUnits.unit.OwnerUserId==1,'Rich inventory survives')
dataA.Coins=75;ambiguous=true
check(a:Save(p),'Unknown outcome retried idempotently');check(records.Player_1.Coins==75,'No duplicate award after retry')
fail=true;dataA.Coins=100
check(not a:Save(p),'Outage does not report success');check(a.Handles[p].Pending~=nil,'Uncertain operation retained')
dataA.Coins=125;fail=false
check(a:Save(p),'Pending write resolved before latest snapshot');check(records.Player_1.Coins==125,'Later mutation not overwritten by older retry')
check(a:Save(p,nil,true),'Final save releases lease');check(records.Player_1._Session==nil,'Lease removed on leave')
ok,dataB=b:Load(p);check(ok and dataB.Coins==125,'Reconnect recovers coins')
check(dataB.Inventory.SlapUnits.unit~=nil and dataB.Progression.TotalXP==800,'Reconnect recovers units and EXP')
check(not a:Save(p),'Released server cannot write')
now+=181;local c=Profiles.new(store,normalize,function()return dataA end,options)
check(c:Load(p),'Expired lease recoverable after crashed server')
check(not b:Save(p),'Old server fenced after takeover');check(records.Player_1.Coins==125,'Stale writer does not corrupt profile')
local future={Version=99,Coins=900};records.Player_2=future
check(not a:Load({UserId=2}),'Future schema rejected');check(records.Player_2.Coins==900 and records.Player_2._Session==nil,'Future schema untouched')
records.Player_3={Version=2,_PremiumProfile={}}
check(not a:Load({UserId=3}),'Foreign receipt lifecycle not adopted')
-- The first deep copy must isolate later in-memory mutations.
local copy=Profiles.Copy(dataA);dataA.Inventory.SlapUnits.unit.OwnerUserId=77
check(copy.Inventory.SlapUnits.unit.OwnerUserId==1,'Snapshot isolation')
local cycle={};cycle.self=cycle;check(not pcall(Profiles.Copy,cycle),'Cyclic data rejected')
return 'PASS: '..count..' fenced persistence assertions; injected memory only'
