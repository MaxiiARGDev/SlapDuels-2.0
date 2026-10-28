-- Actual policy/public projection/negotiation modules over disposable tables.
local n=0;local function check(v,m)n+=1;assert(v,m)end
local loaded={};local parent=setmetatable({},{__index=function(_,key)return key end})
parent.Trading=parent
local shared={SlapCrates=parent,SocialConfig='SocialConfig'};local fakeServices={ReplicatedStorage={Shared=shared},Players={}}
local world={};local clock=500;world.GetServerTimeNow=function()return clock end
local function load(name)
 if loaded[name]then return loaded[name]end
 local f=assert(loadstring(Sources[name],name))
 setfenv(f,setmetatable({script={Parent=parent},game={GetService=function(_,key)return fakeServices[key]or {}end},
  workspace=world,Color3={fromRGB=function(...)return {...}end},require=load},{__index=getfenv()}))
 local result=f();loaded[name]=result;return result
end
local cfg=load('SocialConfig');local catalog=load('Catalog');local Policy=load('TradePolicy');local Public=load('PublicInventory')
local Engine=load('TradeEngine');local Tx=load('TradeTransactionService');local Recovery=load('TradeRecoveryService')
local function copy(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t end
local function same(a,b)if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end;for k,v in pairs(a)do if not same(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end
local function inventory(uid)
 local inv={Owned={Slaps={['Classic:Basic']=true}},Equipped={Slaps='Classic:Common'},SlapUnits={},CrateOperations={},Crates={}}
 local crate=catalog.Crates.Order[1]
 for i,id in ipairs({'Common','Uncommon','Rare','Gold','Arcoiris','Emote','Wings'})do
  local key=tostring(uid)..':operation-'..i;local reward='Classic:'..id
  inv.SlapUnits[key]={UnitId=key,RewardId=reward,SlapId='Classic',VariationId=id,OperationId='operation-'..i,OwnerUserId=uid,Origin='Crate'}
  inv.CrateOperations['operation-'..i]={CrateId=crate,OwnerUserId=uid,State='Completed',Kind='Open',UnitId=key,RewardId=reward}
  inv.Owned.Slaps[reward]=true
 end
 return inv
end
local inv=inventory(-1);local original=copy(inv);local unit=inv.SlapUnits['-1:operation-1']
check(Policy.Check(unit,inv,-1,catalog),'ordinary unit explicitly eligible')
check(not Policy.Check(unit,inv,-2,catalog),'different owner rejected')
for _,field in ipairs({'SlapId','VariationId','RewardId','Origin','OperationId','OwnerUserId'})do
 local bad=copy(unit);bad[field]='invented';check(not Policy.Check(bad,inv,-1,catalog),'invalid identity/provenance '..field)
end
for _,flag in ipairs({'Locked','TradeLocked','NonTradable','PremiumOnly','Temporary','TestOnly'})do local bad=copy(unit);bad[flag]=true;check(not Policy.Check(bad,inv,-1,catalog),'locked unit rejected')end
local badInv=copy(inv);badInv.CrateOperations[unit.OperationId].State='GrantCommitted';check(not Policy.Check(unit,badInv,-1,catalog),'pending stock reconciliation cannot trade')
badInv=copy(inv);badInv.CrateOperations[unit.OperationId].CrateId='PremiumOnlyUnknown';check(not Policy.Check(unit,badInv,-1,catalog),'unknown/premium source cannot be inferred from Origin=Crate')
badInv=copy(inv);badInv.CrateOperations[unit.OperationId].UnitId='another-unit';check(not Policy.Check(unit,badInv,-1,catalog),'journal must contain exact unit')
badInv=copy(inv);badInv.CrateOperations[unit.OperationId].Rewards='malformed';check(not Policy.Check(unit,badInv,-1,catalog),'malformed rich journal fails closed')
local data={Wins=12,Losses=4,Kills=17,Coins=9999,Token='private',Inventory=inv,_PremiumProfile={Token='secret'}}
local public=Public.Profile({UserId=-1,DisplayName='Visible',Name='Username'},data,catalog,cfg,1)
check(public.Stats.Wins==12 and public.Stats.Losses==4 and public.Stats.TotalKills==17,'reuse persisted stats')
check(public.Coins==nil and public.Token==nil and public._PremiumProfile==nil and public.Inventory.CrateOperations==nil,'specific public response excludes private fields')
check(public.Progression.Available==false and public.Progression.Level==nil and public.Progression.Experience==nil,'no fabricated level or EXP')
local default;for _,row in ipairs(public.Inventory)do if row.RewardId=='Classic:Basic'then default=row end end
check(#public.Inventory==8 and default and default.UnitId==nil and not default.Tradable,'default entitlement visible but no fabricated transferable identity')
check(same(original,inv),'public projection never mutates inventory')
local rows=Public.Build(data,-1,catalog);local keys={};for _,row in ipairs(rows)do if row.UnitId then keys[row.UnitId]=row end end
check(keys[unit.UnitId].Tradable and keys[unit.UnitId].Equipped,'equipped cosmetic shown without unequipping or fabricating ownership')
local pageConfig=table.clone(cfg);pageConfig.InventoryPageSize=3
check(#Public.Profile({UserId=-1},data,catalog,pageConfig,1).Inventory==3 and Public.Profile({UserId=-1},data,catalog,pageConfig,1).HasNext,'bounded pagination')
check(#Public.Profile({UserId=-1},data,catalog,pageConfig,3).Inventory==2,'last inventory page')
local dup=copy(data);local clone=copy(unit);clone.UnitId='-1:duplicate';dup.Inventory.SlapUnits[clone.UnitId]=clone
check(#Public.Build(dup,-1,catalog)==9,'existing duplicate units stay separately visible')

local function fixture()
 local f={Now=100,Eligible={[-1]=true,[-2]=true,[-3]=true},Distance=3,Emitted={},Inventories={[-1]=inventory(-1),[-2]=inventory(-2),[-3]=inventory(-3)},Commits=0}
 local serial=0
 f.Engine=Engine.new(cfg,{
  Clock=function()return f.Now end,Id=function()serial+=1;return 'trade-'..serial end,
  Eligible=function(uid)return f.Eligible[uid]==true end,Distance=function()return f.Distance end,Name=function(uid)return 'Player'..uid end,
  Unit=function(uid,id)for _,row in ipairs(Public.Build({Inventory=f.Inventories[uid]},uid,catalog))do if row.UnitId==id then return row end end end,
  Emit=function(uid,kind,packet)table.insert(f.Emitted,{UserId=uid,Kind=kind,Packet=packet})end,
  Commit=function(intent)f.Commits+=1;return Tx.Commit(intent,{PretendDurable=true})end,
 })
 function f:Invite()local ok,id=self.Engine:Invite(-1,-2);assert(ok,id);self.Id=id;return self.Engine.Trades[id]end
 function f:Act(uid,action,revision,item)return self.Engine:Act(uid,action,self.Id,revision,item)end
 function f:Negotiate()local t=self:Invite();assert(self:Act(-2,'Respond',0,true));return t end
 return f
end
local f=fixture();check(not f.Engine:Invite(-1,-1),'self invitation rejected')
f.Distance=11;check(not f.Engine:Invite(-1,-2),'distance limit');f.Distance=3
f.Distance=0/0;check(not f.Engine:Invite(-1,-2),'non-finite distance fails closed');f.Distance=3
f.Eligible[-1]=false;check(not f.Engine:Invite(-1,-2),'match/unavailable cannot invite');f.Eligible[-1]=true
local t=f:Invite();check(t.State=='Requested' and t.ExpiresAt==115,'valid invitation with fifteen-second deadline')
check(not f.Engine:Invite(-1,-2)and not f.Engine:Invite(-3,-2),'duplicate and busy target rejected')
check(not f:Act(-3,'Respond',0,true)and not f:Act(-1,'Respond',0,true),'third party and requester cannot accept for target')
check(not f:Act(-2,'Respond',1,true),'stale invitation revision rejected')
check(f:Act(-2,'Respond',0,false)and t.State=='Cancelled'and f.Engine.Busy[-1]==nil,'decline releases state')
check(not f.Engine:Invite(-1,-2),'invitation cooldown preserved after decline')
f.Engine:CancelForPlayer(-1);check(not f.Engine:Invite(-1,-2),'respawn cancellation cannot reset invite cooldown')
f=fixture();t=f:Invite();f.Now=115;f.Engine:Tick();check(t.Terminal and t.Reason=='Expired','invitation expiration')
check(not f:Act(-2,'Respond',0,true),'late acceptance rejected')
f=fixture();t=f:Negotiate();local before=copy(f.Inventories)
check(f:Act(-1,'Add',0,'-1:operation-1')and t.Revision==1,'valid unit offer')
check(not f:Act(-1,'Add',1,'-1:operation-1'),'duplicate offer rejected')
check(not f:Act(-1,'Add',1,'does-not-exist')and not f:Act(-1,'Add',1,'-2:operation-1'),'nonexistent and foreign units rejected')
check(not f:Act(-1,'Add',0,'-1:operation-2'),'stale offer revision rejected')
check(f:Act(-1,'Accept',1),'first acceptance')
check(f:Act(-2,'Add',1,'-2:operation-1')and not t.Accepted[-1]and not t.Accepted[-2]and next(t.Confirmed)==nil,'any edit invalidates both acceptances and final confirmations')
check(not f:Act(-1,'Confirm',2),'premature final confirmation rejected')
check(f:Act(-1,'Accept',2)and f:Act(-2,'Accept',2)and t.State=='SafetyCountdown'and t.Deadline==105,'two acceptances start five-second safety step')
check(not f:Act(-1,'Remove',2,'-1:operation-1'),'offers locked during safety countdown')
f.Now=104.999;f.Engine:Tick();check(t.State=='SafetyCountdown'and not f:Act(-1,'Confirm',2),'exact deadline enforced')
f.Now=105;f.Engine:Tick();check(t.State=='FinalConfirmation'and not next(t.Confirmed),'countdown never auto-confirms')
check(not f:Act(-1,'Confirm',1),'old final confirmation rejected')
check(f:Act(-1,'Confirm',2)and f.Commits==0,'one confirmation is insufficient')
check(f:Act(-2,'Confirm',2)and f.Commits==1 and t.State=='Cancelled'and t.Reason=='TradeCommitDisabled','both confirmations stop at disabled commit')
check(same(before,f.Inventories),'no transfer of equipped or unequipped objects and no duplicate ownership')
check(next(f.Engine.Reserved)==nil and not f.Engine.Busy[-1]and not f.Engine.Busy[-2],'disabled commit releases draft reservations')
check(not f:Act(-2,'Confirm',2)and f.Commits==1,'confirmation replay never calls commit twice')
local packet=f.Emitted[#f.Emitted].Packet
check(packet.TradeCommitEnabled==false and packet.Names['-1']=='Player-1'and packet.Offers['-1'][1].UnitId=='-1:operation-1','wire DTO preserves signed IDs as string keys')
for _,event in ipairs(f.Emitted)do check(event.UserId==-1 or event.UserId==-2,'no unrelated lobby player receives trade state')end
for _,kind in ipairs({'Disconnect','Match','Expired','ChangeInventory'})do
 f=fixture();t=f:Negotiate();f:Act(-1,'Add',0,'-1:operation-1')
 if kind=='Disconnect'then f.Engine:Disconnect(-2)
 elseif kind=='Match'then f.Eligible[-2]=false;f.Engine:Tick()
 elseif kind=='Expired'then f.Now=281;f.Engine:Tick()
 else f.Inventories[-1].SlapUnits['-1:operation-1']=nil;check(not f:Act(-1,'Accept',1),'removed unit cannot be accepted')end
 check(t.Terminal and next(f.Engine.Reserved)==nil and f.Commits==0,'safe cancellation '..kind)
end
f=fixture();t=f:Negotiate()
for i=1,6 do check(f:Act(-1,'Add',i-1,'-1:operation-'..i),'each of six offers accepted')end
check(not f:Act(-1,'Add',6,'-1:operation-7'),'seventh unit rejected')
check(f:Act(-1,'Remove',6,'-1:operation-1')and t.Revision==7 and #t.Offers[-1]==5,'remove updates revision')
check(f:Act(-1,'Cancel',7)and not f:Act(-1,'Cancel',7),'cancellation idempotent and no re-entry')
f.Now=131;f.Engine:Tick();check(next(f.Engine.Trades)==nil,'terminal records are bounded and reclaimed')
f=fixture();t=f:Negotiate();f.Engine.Reserved['-1:-1:operation-1']='other-trade'
check(not f:Act(-1,'Add',0,'-1:operation-1'),'reservation conflict rejected')
check(not Tx.Availability(cfg,{Environment='Studio',ProviderName='InMemory',WritesToCloud=false},true),'InMemory commit hard-disabled')
local force=table.clone(cfg);force.TradeCommitEnabled=true
check(not Tx.Availability(force,{Environment='Production',ProviderName='RobloxDataStore',WritesToCloud=true},false),'flag alone cannot enable unsupported durable bridge')
check(not Tx.Commit({}, {UpdateAsync=function()error('must never write')end}),'no backend writes even with fake adapter')
check(not Recovery.Status().DurableRecoveryAvailable and not Recovery.Reconcile('missing'),'durable recovery explicitly unavailable; never reports simulated recovery as durable')

-- Actual local targeting helper with distance witness.
local target=load('Targeting')
local function position(x)return setmetatable({X=x},{__sub=function(a,b)return {Magnitude=math.abs(a.X-b.X)}end})end
local function p(id,x)
 local v={UserId=id,Parent=true,Attributes={},Character={}}
 function v:GetAttribute(k)return self.Attributes[k]end
 function v.Character:FindFirstChild()return {Position=position(x)}end
 function v.Character:FindFirstChildOfClass()return {Health=100}end
 return v
end
local a,b=p(-1,0),p(-2,10)
check(target.Valid(a,b,10),'local valid target at exact maximum distance')
check(not target.Valid(a,a,10),'self targeting rejected')
b=p(-2,10.01);check(not target.Valid(a,b,10),'local range check beyond maximum')
b=p(-2,3);b.Attributes.MatchId='active';check(not target.Valid(a,b,10),'local presentation hides active target')
b.Attributes.MatchId=nil;a.Attributes.MatchId='active';check(not target.Valid(a,b,10),'active requester has no profile prompt')
a.Attributes.MatchId=nil;b.Parent=nil;check(not target.Valid(a,b,10),'disconnected target removed')
local pool=load('ViewportPool').new(12);local destroyed,disconnected=0,0
local view={CurrentCamera=true}
pool.Rows[view]={World={Destroy=function()destroyed+=1 end},Camera={Destroy=function()destroyed+=1 end},Connections={{Disconnect=function()disconnected+=1 end}}};pool.Count=1
pool:Remove(view);pool:Remove(view)
check(pool.Count==0 and next(pool.Rows)==nil and view.CurrentCamera==nil and destroyed==2 and disconnected==1,'viewport cleanup idempotently destroys WorldModel/camera and disconnects resize')
check(cfg.MaxActivePreviews==12 and cfg.TradeCommitEnabled==false,'render budget and commit flag')

-- Real remote handler/service methods: distance, session authority, rate limiting and public DTO.
local Service=load('SocialService');local ps=fakeServices.Players
local aa,bb=p(-1,0),p(-2,3);aa.Parent=ps;bb.Parent=ps
for _,who in ipairs({aa,bb})do
 who.Name='RealName'..who.UserId;who.DisplayName='Visible'..who.UserId
 function who.Character:IsDescendantOf(w)return w==world end
 local get=who.Character.FindFirstChild
 who.Character.FindFirstChild=function(self,k)local root=get(self,k);root.IsA=function(_,class)return class=='BasePart'end;return root end
end
local users={[-1]=aa,[-2]=bb};ps.GetPlayerByUserId=function(_,id)return users[id]end
local active={};local ready=true
Service.Profiles={IsShopDataReady=function()return ready end,GetPlayerData=function(_,who)return{Wins=5,Losses=6,Kills=7,Inventory=inventory(who.UserId),Coins=1000,_PremiumProfile={Token='never-public'}}end}
Service.Rounds={GetSessionForPlayer=function(_,who)return active[who]end};Service.LastRequest={};Service.Viewers={}
Service.Engine=Engine.new(cfg,{Clock=function()return clock end,Id=function()return 'remote-trade'end,Name=function(id)return users[id].DisplayName end,
 Eligible=function(id)return Service:Eligible(id)end,Distance=function(a,b)return Service:Distance(a,b)end,
 Unit=function(id,key)return Service:Unit(id,key)end,Emit=function()end,Commit=Tx.Commit})
local function inspect(id,page)clock+=.3;return Service:Inspect(aa,id,page)end
check(Service:Eligible(-1)and Service:Eligible(-2),'real service accepts two loaded lobby players')
local inspected=inspect(-2);check(inspected.Ok and inspected.Profile.Stats.TotalKills==7 and inspected.Profile.Coins==nil and inspected.Profile._PremiumProfile==nil,'real handler exports only public projection')
check(not Service:Inspect(aa,-2).Ok,'real handler rate limit')
check(not inspect(-1).Ok,'real handler rejects self inspection')
check(not inspect(0).Ok and not inspect('remote-id').Ok and not inspect(0/0).Ok,'invalid target identity rejected')
check(not inspect(-2,0).Ok and not inspect(-2,math.huge).Ok,'page bounds validated')
active[aa]={Id='authoritative-session'};check(not inspect(-2).Ok,'server session blocks requester even with no local MatchId attribute')
active[aa]=nil;active[bb]={Id='target-session'};check(not inspect(-2).Ok,'server session blocks active target')
active[bb]=nil;ready=false;check(not inspect(-2).Ok,'unloaded profiles blocked');ready=true
users[-2]=nil;check(not inspect(-2).Ok,'disconnected target blocked');users[-2]=bb
local rootFunction=bb.Character.FindFirstChild;bb.Character.FindFirstChild=function()return {Position=position(11),IsA=function()return true end}end
check(not inspect(-2).Ok,'server distance beyond ten studs rejected');bb.Character.FindFirstChild=rootFunction
clock+=.3;local invitation=Service:Action(aa,'Invite',-2)
check(invitation.Ok and invitation.TradeId=='remote-trade','real invitation handler')
clock+=.3;check(not Service:Action(aa,'Inventory','foreign-trade',0,1).Ok,'own inventory cannot be requested without trade membership')
clock+=.3;local owned=Service:Action(aa,'Inventory','remote-trade',0,1)
check(owned.Ok and owned.Profile.UserId==-1 and owned.Profile.Coins==nil,'own inventory during negotiation uses same public mapper')
clock+=.3;check(not Service:Action(aa,'Confirm','remote-trade',-1).Ok,'invalid remote revision rejected')
print('PASS PlayerInventoryTradingV10: '..n..' isolated assertions; durable protocol NOT IMPLEMENTED; no Studio/transfer/cloud execution')
