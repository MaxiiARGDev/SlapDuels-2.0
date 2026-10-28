--!nonstrict
-- Actual production modules; isolated adapter, no Roblox/cloud execution.
local count=0
local function check(v,s)count+=1;assert(v,s)end
local modules={};local parent=setmetatable({},{__index=function(_,k)return k end})
local shared={SlapCrates={Inventory="Inventory"}}
local env={Enum={InfoType={Product="Product"},ProductPurchaseDecision={NotProcessedYet="Pending",PurchaseGranted="Granted"}},script={Parent=parent},game={GetService=function()return {Shared=shared}end},require=function(k)return assert(modules[k],tostring(k))end}
local function load(name,key,custom)
 local f=assert(loadstring(Sources[key or "Premium/"..name],name));setfenv(f,setmetatable(custom or env,{__index=getfenv()}));local m=f();modules[name]=m;return m
end
local I=load("Inventory","Crates/Inventory")
local Grant=load("PremiumGrantPlan");local Store=load("ProfileReceiptStore");local Coord=load("ReceiptCoordinator")
local Verify=load("ProductVerifier");local Backend=load("DurableReceiptBackend");local Flow=load("PremiumPurchaseFlow")
local Reserved=load("PlaceholderProductIds")
local coins=load("CoinPackages");check(#coins==5,"five packages")
for i,n in ipairs({1000,10000,35000,100000,400000})do
 check(coins[i].Coins==n and coins[i].Rewards.Coins==n,"amount")
 check(coins[i].SuggestedRobux==({50,450,1250,3000,10000})[i],"approved draft price")
 check(coins[i].IsPlaceholder and not coins[i].PurchaseApproved and Reserved[coins[i].DeveloperProductId],"safe coin placeholder")
end
for i=1,3 do local c=load("PremiumCombo_0"..i);check(c.Id=="PremiumCombo_0"..i and c.Rewards.Coins==0 and #c.Rewards.Crates==0 and not c.ContentsApproved,"individual empty combo")end
local function copy(t)return I.Copy(t)end
local product={Id="RealFixture",DeveloperProductId=99001,IsPlaceholder=false,PurchaseApproved=true,ContentsApproved=true,DuplicatePolicy="RepeatableNoCompensation",ContractVersion="test1",Rewards={Coins=1000,Crates={{CrateId="Basic",Quantity=3}},Slaps={{SlapId="Classic",VariationId="Test"}},KillEffects={"TestEffect"}}}
local db={};local fault;local calls=0;local retries=false;local interleave
local adapter={UpdateAsync=function(_,key,fn)
 calls+=1;if fault=="before"then error("offline")end
 local v=fn(copy(db[key]));if interleave then local f=interleave;interleave=nil;f();v=fn(copy(db[key]))end;if retries then v=fn(copy(db[key]))end
 if v~=nil then db[key]=copy(v)end
 if fault=="after"then error("ambiguous acknowledgement")end
 return copy(v)
end}
local now=100;local options={Clock=function()return now end,LeaseSeconds=10}
local store=Store.new(adapter,options);local other=Store.new(adapter,options)
local profile={Version=2,Coins=10,Wins=2,Losses=1,Kills=3,Inventory=I.Extend({Owned={Abilities={Dash=true}},Equipped={Abilities="Dash"}})}
local h=assert(store:Acquire(99,"serverA",profile));local stale=copy(h)
check(h.Record.Coins==10 and h.Record.Inventory.Owned.Abilities.Dash,"legacy profile preserved")
local no,reason=other:Acquire(99,"serverB",profile);check(not no and reason=="ProfileOwnedElsewhere","cross-server fence")
local receipt={PlayerId=99,ProductId=99001,PurchaseId="r1"}
fault="before";check(not store:ApplyReceipt(h,receipt,product)and db.Player_99.Coins==10,"storage failure grants nothing")
fault=nil;retries=true;local granted=assert(store:ApplyReceipt(h,receipt,product));retries=false
check(granted.Durable and not granted.Replay and db.Player_99.Coins==1010,"coins once despite callback retry")
check(db.Player_99.Inventory.Crates.Basic==3,"closed crates credited")
check(db.Player_99.Inventory.Owned.Slaps["Classic:Test"],"slap credited")
check(db.Player_99.Inventory.Owned.DeathEffects.TestEffect,"effect credited")
check(db.Player_99.Inventory.PremiumReceipts.r1.State=="Applied","journal same profile")
check(store:ApplyReceipt(h,receipt,product).Replay and db.Player_99.Coins==1010,"durable replay")
local oldSave,oldReason=store:Save(stale,stale.Record,"stale",false);check(not oldSave and oldReason=="StaleProfileRevision","stale save cannot erase receipt")
local regressed=copy(h.Record);regressed.Inventory.PremiumReceipts={};check(not store:Save(h,regressed,"regress",false),"journal regression denied")
local saved=assert(store:Save(h,h.Record,"save1",false));check(saved.Coins==1010,"save reconciled snapshot")
check(store:Save(h,h.Record,"save1",false)._PremiumProfile.Revision==h.Revision,"save retry idempotent")
local r2=copy(receipt);r2.PurchaseId="r2";fault="after";check(not store:ApplyReceipt(h,r2,product),"ambiguous commit not acknowledged")
fault=nil;check(store:ApplyReceipt(h,r2,product).Replay and db.Player_99.Coins==2010,"retry resolves committed ambiguity")
local oldH=copy(h);now=111;local b=assert(other:Acquire(99,"serverB",profile))
check(not store:Save(oldH,oldH.Record,"late",false),"expired old server rejected")
local r3=copy(receipt);r3.PurchaseId="r3";check(not store:ApplyReceipt(oldH,r3,product),"old server receipt denied")
check(other:ApplyReceipt(b,r3,product).Durable and db.Player_99.Coins==3010,"new server receipt")
check(store:ApplyReceipt(nil,r3,product).Replay,"disconnected durable replay")
local bad=copy(r3);bad.ProductId=99002;check(not store:ApplyReceipt(nil,bad,product),"receipt identity conflict")
local broken=copy(product);broken.Rewards.KillEffects={"TestEffect"};broken.DuplicatePolicy="RestrictOwned"
local r4=copy(receipt);r4.PurchaseId="r4";check(not other:ApplyReceipt(b,r4,broken)and db.Player_99.Coins==3010 and not db.Player_99.Inventory.PremiumReceipts.r4,"partial grant rolled back")
local competing=copy(b);local r5=copy(receipt);r5.PurchaseId="r5";local r6=copy(receipt);r6.PurchaseId="r6"
interleave=function()check(other:ApplyReceipt(competing,r6,product).Durable,"second receipt commits while first waits");check(not store:Acquire(99,"thirdServer",profile),"other server cannot seize active owner during transaction")end
local raceResult,raceReason=other:ApplyReceipt(b,r5,product)
check(not raceResult and raceReason=="StaleProfileRevision"and db.Player_99.Coins==4010,"CAS retry rejects stale simultaneous receipt")
b=assert(other:Acquire(99,"serverB",profile));check(other:ApplyReceipt(b,r5,product).Durable and db.Player_99.Coins==5010,"pending competing receipt recovers exactly once")
check(other:ApplyReceipt(b,r6,product).Replay and db.Player_99.Coins==5010,"both concurrent receipts remain idempotent")
local by={ByProductId={[99001]=product}};local players={GetPlayerByUserId=function()return nil end}
local backend={DurableValidated=true,SupportsOffline=true,ApplyReceiptAtomic=function(_,_,r,p)return assert(other:ApplyReceipt(b,r,p))end}
local notified=0;local coordinator=Coord.new(by,backend,players,{Reserved=Reserved,Delivered=function()notified+=1 end})
check(coordinator:Process(r3)=="Granted","offline confirmed receipt")
check(Coord.new(by,nil,players):Process(r3)=="Pending","in-memory never acknowledged")
bad=copy(r3);bad.ProductId=99999;check(coordinator:Process(bad)=="Pending","unknown product pending")
backend.ApplyReceiptAtomic=function()error("failure")end;check(coordinator:Process(r4)=="Pending","backend exception pending")
backend.ApplyReceiptAtomic=function()return {Durable=false}end;check(coordinator:Process(r4)=="Pending","no premature confirmation")
local context={PersistenceInfo={Environment="Production",WritesToCloud=true,ProviderName="DataStore"},GetService=function()return {}end}
check(select(2,Backend.Create(context,false))=="ProfileLifecycleIntegrationPending","legacy runtime bridge explicitly blocked")
check(select(2,Backend.Create(context,true))=="TestingOrUnapprovedEnvironment","Studio durable backend blocked")
local apiCalls=0;local price=17;local promptCount=0
local market={GetProductInfoAsync=function()apiCalls+=1;return {IsForSale=true,PriceInRobux=price,Name="Fixture"}end,
 GetDeveloperProductsAsync=function()apiCalls+=1;return {IsFinished=true,GetCurrentPage=function()return {{ProductId=99001}}end}end,
 PromptProductPurchase=function(_,p,id)check(p.UserId==99 and id==99001,"registered prompt id");promptCount+=1 end}
local verifier=Verify.new(market,Reserved,false,123)
check(verifier:Verify(product)~=nil,"belongs to experience")
bad=copy(product);bad.DeveloperProductId=88888;check(not verifier:Verify(bad),"foreign product blocked")
local before=apiCalls;for _,p in ipairs(coins)do check(not verifier:Verify(p),"placeholder rejected")end;check(apiCalls==before,"placeholder zero API requests")
bad=copy(product);bad.DeveloperProductId=123456001;check(not verifier:Verify(bad)and apiCalls==before,"reserved id cannot bypass flag")
check(not Verify.new(market,Reserved,true,123):Verify(product)and apiCalls==before,"Studio zero product API requests")
local p={Id="RealFixture",ProductId=99001,IsPlaceholder=false,CommercialVerified=true,PriceRobux=17,QuoteTokens={Basic="quote"}}
local states={};local requestCount=0
local function request(action,args)requestCount+=1;check(action=="Purchase"and args.Id==p.Id and args.ProductId==nil and args.Coins==nil,"only product key and quotes");return {Ok=true,ProductId=99001,PromptAllowed=true,KnownReceipts={r0=true}}end
local flow=Flow.new(market,{UserId=99},request,function(s)table.insert(states,s)end,nil,Reserved)
check(flow:Begin(p)and promptCount==1 and flow.State=="Purchasing","real prompt API via isolated adapter")
check(not flow:Begin(p)and promptCount==1,"double-click denied")
flow:PromptClosed(99,99001,true);check(flow.State=="AwaitingConfirmation","closing prompt not success")
flow:Status({{State="Applied",ProductId=99001,ProductKey=p.Id,PurchaseId="r0"}});check(flow.Pending~=nil,"old receipt cannot confirm new purchase")
local delivered={State="Applied",ProductId=99001,ProductKey=p.Id,PurchaseId="new"};check(flow:Delivery(delivered)and flow.State=="Credited","only server delivery credits presentation")
check(not flow:Delivery(delivered),"notification dedup")
flow:PromptClosed(99,99001,false);check(flow.State=="Credited","late close does not overwrite confirmation")
price=18;check(not flow:Begin(p)and promptCount==1 and p.PriceRobux==18,"price change requires renewed input")
price=nil;check(not flow:Price(p),"unavailable price")
price=18;local reject=Flow.new(market,{UserId=99},function()return {Ok=false,Code="Restricted"}end,function()end,nil,Reserved)
check(not reject:Begin(p)and reject.State=="Restricted","authorization denial")
local failed=Flow.new(market,{UserId=99},function()error("network")end,function()end,nil,Reserved)
check(not failed:Begin(p)and failed.State=="TemporaryError"and not failed.Busy,"request exception releases busy safely")
before=apiCalls;p.IsPlaceholder=true;check(not flow:Begin(p)and apiCalls==before and promptCount==1,"placeholder cannot prompt")
local defs=load("PremiumCrateDefinitions","Crates/PremiumCrateDefinitions")
modules.PremiumCrateDefinitions=defs
local crateEnv=table.clone(env);crateEnv.script={Parent={Parent={Parent={SlapCrates={PremiumCrateDefinitions="PremiumCrateDefinitions"}}}}}
local boxes=load("PremiumCrates",nil,crateEnv);check(#boxes==3,"exactly three premium boxes")
local fakeCatalog={Crates={ById={}},Rewards={},Variations={ById={}}}
for _,d in ipairs(defs)do fakeCatalog.Crates.ById[d.CrateId]=d end
local registry=load("PremiumProductRegistry")
local combos={modules.PremiumCombo_01,modules.PremiumCombo_02,modules.PremiumCombo_03}
local reg=registry.Build({coins,combos,boxes},fakeCatalog,{})
check(#reg.Order==11,"eleven registered products")
for _,id in ipairs(reg.Order)do check(reg.ById[id].BlockedReason=="PlaceholderProduct","all products individually blocked")end
local duplicate=copy(coins[2]);duplicate.DeveloperProductId=coins[1].DeveloperProductId
check(not pcall(registry.Build,{{coins[1],duplicate}},fakeCatalog,{}),"duplicate product ID rejected")
duplicate=copy(coins[1]);duplicate.IsPlaceholder=false;duplicate.DeveloperProductId=nil
check(registry.Build({{duplicate}},fakeCatalog,{}).ById[duplicate.Id].BlockedReason=="ProductIdPending","missing product blocked")
local approvedBox=copy(boxes[1]);approvedBox.IsPlaceholder=false;approvedBox.PurchaseApproved=true;approvedBox.ContentsApproved=true
check(registry.Build({{approvedBox}},fakeCatalog,{}).ById[approvedBox.Id].BlockedReason=="CrateApprovalPending","unapproved odds block commerce")
local elig=load("PremiumEligibility");local config={PremiumShopEnabled=true,PurchasesEnabled=true,DurableCommerceValidated=true,CoinPackagesEnabled=true,CombosEnabled=true,PremiumCratesEnabled=true}
local random={Category="Combos",HasRandomContents=true}
check(not elig.CanPurchase(config,random,{Verified=true,RandomAllowed=false},true,true),"combo cannot evade paid random policy")
check(not elig.CanPurchase(config,{Category="Coins"},{Verified=false},true,true),"policy failure closed")
check(elig.CanPurchase(config,{Category="Coins"},{Verified=true,RandomAllowed=false},true,true),"guaranteed currency distinct from random contents")
check(not elig.CanPurchase(config,random,{Verified=true,RandomAllowed=true},false,true),"unloaded profile blocked")
check(not elig.CanPurchase(config,random,{Verified=true,RandomAllowed=true},true,false),"combat purchase blocked")
check(not elig.Policy({GetPolicyInfoForPlayerAsync=function()error("offline")end},{}).Verified,"PolicyService error fails closed")
print("PremiumShopV11 isolated: "..count.." assertions PASS")
