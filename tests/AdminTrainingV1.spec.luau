-- Actual modules under disposable mocks; never runs Studio or accesses cloud.
local count=0
local function check(v,label)assert(v,label);count+=1 end
local function load(name,env)local f=assert(loadstring(Sources[name],name));setfenv(f,setmetatable(env or {},{__index=getfenv()}));return f()end
local access=load('Admin/Access')
local registry=load('Admin/CommandRegistry')
local coins=load('Admin/GrantCoins',{script={Parent={Parent={Access='Access'}}},require=function()return access end})
local slap=load('Admin/GrantSlap')
local manifest=load('Admin/CommandManifest')
local commands=registry.Build(manifest,function(id)return ({GrantCoins=coins,GrantSlap=slap})[id]end)
check(#commands.Order==2,'registered commands')
check(not pcall(registry.Build,{'GrantCoins','GrantCoins'},function()return coins end),'duplicate rejects')
check(not pcall(registry.Build,{'Unapproved'},function()return coins end),'mismatched module rejects')
check(registry.Public(commands)[1].Execute==nil,'public metadata has no execution')
local fixture=load('ShopFixture',{Sources=Sources}).New()
local ps,a,b,players=fixture.PS,fixture.A,fixture.B,fixture.Players
a.UserId=1522376993;b.UserId=22;a.DisplayName='Admin';b.DisplayName='Target'
function players:GetPlayerByUserId(id)for _,p in ipairs({a,b})do if p.Parent==self and p.UserId==id then return p end end end
function players:GetPlayers()return {a,b}end
local now,studio,guid=0,false,0
local catalog={Rewards={['Classic:Basic']={DisplayName='Classic',VariationId='Basic',SlapId='Classic'},Limited={LimitedStock=1},Premium={PremiumOnly=true}},Variations={ById={Basic={}}},Slaps={ById={Classic={Model='Classic'}}}}
local rs={Shared={SlapCrates={Catalog='Catalog'}}}
local http={GenerateGUID=function()guid+=1;return tostring(guid)end,JSONEncode=function()return '{}'end}
local cls=load('AdminService',{game={GetService=function(_,id)return ({Players=players,ReplicatedStorage=rs,RunService={IsStudio=function()return studio end},HttpService=http})[id]end},script={Parent={Parent={Admin={Access='Access',CommandRegistry='Registry'}}}},require=function(id)return ({Access=access,Registry=registry,Catalog=catalog})[id]end,workspace={GetServerTimeNow=function()return now end},print=function()end})
local service=setmetatable({Profiles=ps,Slaps={GetSlapTemplate=function()return {}end},Registry=commands,LastRequest={},Operations={},AuditRows={}},{__index=cls})
local function request(actor,id,command,args)now+=1;return service:Request(actor,'Execute',id,command,args)end
check(service:IsAdmin(a),'configured production admin')
check(not service:IsAdmin(b),'nonadmin blocked')
b.AdminPanelAllowed=true
check(request(b,'request01','GrantCoins',{TargetUserId=22,Amount=50}).Reason=='Forbidden','forged client visibility not auth')
check(service:Request(b,'Info').Reason=='Forbidden','metadata private')
check(not service:IsGrantableSlap('Limited')and not service:IsGrantableSlap('Premium'),'limited/premium blocked')
local before=ps:GetCoins(b)
local r=request(a,'request02','GrantCoins',{TargetUserId=22,Amount=50})
check(r.Ok and r.Granted==50 and ps:GetCoins(b)==before+50,'real PlayerService credits exact amount')
check(request(a,'request02','GrantCoins',{TargetUserId=22,Amount=50})==r,'same request cached')
check(ps:GetCoins(b)==before+50,'retry no double credit')
check(request(a,'request02','GrantCoins',{TargetUserId=22,Amount=51}).Reason=='RequestIdConflict','conflict blocked')
check(service:Request(a,'Execute','rate0001','GrantCoins',{TargetUserId=22,Amount=50}).Reason=='RateLimited','rate limit')
for _,amount in ipairs({0,-1,.5,math.huge,0/0,1000001,'50'})do
 check(not request(a,'invalid01','GrantCoins',{TargetUserId=22,Amount=amount}).Ok,'invalid amount')
end
check(not request(a,'invalid02','GrantCoins',{TargetUserId=22,Amount=1,Extra=true}).Ok,'extra arguments rejected')
check(not request(a,'invalid03','GrantCoins',{TargetUserId=0,Amount=1}).Ok,'zero target rejected')
check(not request(a,'invalid04','GrantCoins',{TargetUserId=999,Amount=1}).Ok,'offline target rejected')
fixture.Loaded[b]='Failed'
check(request(a,'invalid05','GrantCoins',{TargetUserId=22,Amount=1}).Reason=='DataNotLoaded','failed load blocked')
fixture.Loaded[b]='Loaded';ps._shopClosing[b]=true
check(not request(a,'invalid06','GrantCoins',{TargetUserId=22,Amount=1}).Ok,'closing profile blocked')
ps._shopClosing[b]=nil
check(request(a,'slap0001','GrantSlap',{TargetUserId=22,RewardId='Classic:Basic'}).Ok,'real inventory grant')
check(ps:HasItem(b,'Slaps','Classic:Basic'),'ownership recorded')
check(request(a,'slap0002','GrantSlap',{TargetUserId=22,RewardId='Classic:Basic'}).Reason=='AlreadyOwned','repeat slap idempotent')
check(ps:GetCoins(b)==before+50,'slap grant leaves coins')
check(not request(a,'slap0003','GrantSlap',{TargetUserId=22,RewardId='Missing'}).Ok,'unknown slap rejects')
b.UserId=-2
check(not request(a,'negative1','GrantCoins',{TargetUserId=-2,Amount=1}).Ok,'negative target production denied')
studio=true
check(request(a,'negative2','GrantCoins',{TargetUserId=-2,Amount=1}).Ok,'Studio negative target allowed')
check(not service:IsAdmin(b),'no implicit Studio admin')
check(#service.AuditRows==4,'only executed operations audited')
local state=load('TrainingState');local config=fixture.Config.Combat.SlapCombo
local record={}
check(state.Begin(record,1,0),'practice begins')
for i=2,11 do check(not state.Begin(record,i,.05),'no overlapping practice attack')end
check(state.Finish(record,1,.1,false,config,.6),'miss resolves')
check(math.abs(record.ReadyAt-.55)<1e-9,'miss closes window plus .45')
for i=12,21 do check(not state.Begin(record,i,.549),'no early attack')end
check(state.Begin(record,22,.55),'ready at deadline')
check(not state.Finish(record,1,99,true,config,.6),'old result cannot clear new pending')
check(state.Finish(record,22,.55,true,config,.6),'hit resolves')
check(math.abs(record.ReadyAt-.70)<1e-9,'hit recovery .15')
check(not state.Begin(record,22,10),'replayed sequence rejects')
local root={Anchored=true,IsA=function()return true end,SetNetworkOwner=function()end}
local hum={Health=1000};local attrs={};local home={}
local dummy={Parent=true,FindFirstChild=function()return root end,FindFirstChildOfClass=function()return hum end,GetDescendants=function()return {root}end,SetAttribute=function(_,k,v)attrs[k]=v end,PivotTo=function(_,v)check(v==home,'returns original pivot')end}
local scheduled,down,apply= nil,false,0
local ragdoll={IsRagdolled=function()return down end,ApplyRagdoll=function(_,d,duration,v)check(d==dummy and duration==0 and v=='velocity','shared ragdoll no competing timer');down=true;apply+=1;return true end,ResetRagdollImmediate=function()down=false end}
local train=load('TrainingService',{game={GetService=function()return {Shared={Config='Config',TrainingConfig='Settings'}}end},script={Parent={Gameplay={TrainingState='State'}}},require=function(id)return ({Config=fixture.Config,Settings=load('TrainingConfig'),State=state})[id]end,workspace={GetServerTimeNow=function()return 100 end},Vector3={zero='zero'},task={delay=function(t,fn)scheduled={t,fn};return scheduled end,cancel=function()end}})
train.Dummy=dummy;train.Home={CFrame=home};train.Ragdoll=ragdoll;train.Slaps={CheckTargetGeometry=function()return true end,ComputeSlapLaunchVelocity=function()return 'velocity'end}
check(train:HitDummy({},20),'NPC hit accepted')
check(not root.Anchored and scheduled[1]==3 and attrs.TrainingReadyAt==103,'three second ragdoll')
check(not train:HitDummy({},20)and apply==1,'multiple contacts protected')
scheduled[2]()
check(root.Anchored and not train.DummyDown and not down,'reassembled and anchored')
check(root.AssemblyLinearVelocity=='zero'and root.AssemblyAngularVelocity=='zero','residual velocity cleared')
check(hum.WalkSpeed==0 and hum.JumpPower==0,'NPC stationary')
train.Slaps.CheckTargetGeometry=function()return false end
check(not train:HitDummy({},20),'out of reach misses')
check(apply==1,'no extra ragdoll')
print('AdminTrainingV1 PASS: '..count..' assertions (isolated; gameplay NOT RUN)')
