-- All paid products and receipts below are offline fixtures, never real IDs or offers.
do
 local start=assertions
 local Registry=assert(loadstring(Sources["Premium/PremiumProductRegistry"]))()
 local deaths={Frost={IsShopProduct=true},Void={IsShopProduct=true},DefaultFall={IsShopProduct=false}}
 local function premiumLoad(name)
  local f=assert(loadstring(Sources["Premium/"..name]))
  setfenv(f,setmetatable({game={GetService=function(_,id)return services[id]end},script={Parent=parent},require=function(id)return assert(loaded[id])end,
   Enum={ProductPurchaseDecision={NotProcessedYet="Pending",PurchaseGranted="Granted"},InfoType={Product="Product"}},workspace=world,
   typeof=function(v)return if type(v)=="table"and v.ClassName then "Instance"else type(v)end},{__index=getfenv()}))
  return f()
 end
 local configs=premiumLoad("PremiumShopConfig")
 local coins=premiumLoad("CoinPackages");local combos=premiumLoad("PremiumCombos")
 local registry=Registry.Build({coins,combos},C,deaths)
 check(#registry.Order==2 and not configs.PurchasesEnabled and not configs.DurableCommerceValidated,"Safe visible draft config")
 for _,id in ipairs(registry.Order)do check(registry.ById[id].BlockedReason~=nil,"Every unapproved draft blocked")end
 local premiumCount=0
 for _,id in ipairs(C.Crates.Order)do local box=C.Crates.ById[id];if box.PremiumOnly then
  premiumCount+=1;check(not E.Approved(box)and next(box.Weights)==nil and box.PriceCoins==nil,"No invented Premium odds or Coins price")
  check(not E.Stage(data(999999),box,"Purchase","bad",-1,C,S.new(),0),"Premium box cannot be bought with Coins")
 end end
 check(premiumCount==3,"Exactly three Premium definitions")
 local function product()
  return {Id="Fixture",Category="Combos",DisplayName="Offline fixture",Description="Not a commercial offer",DeveloperProductId=123,
   ContractVersion="Test",SortOrder=1,Enabled=true,PurchaseApproved=true,ContentsApproved=true,DuplicatePolicy="RestrictOwned",
   Rewards={Coins=9,Crates={{CrateId="Basic",Quantity=2}},Slaps={{SlapId="Classic",VariationId="Common"}},KillEffects={"Frost"}}}
 end
 local fixtureCatalog=I.Copy(C);fixtureCatalog.Crates.ById.Basic.Enabled=true;fixtureCatalog.Crates.ById.Basic.OddsApproved=true
 local function build(p)return Registry.Build({{p}},fixtureCatalog,deaths)end
 local registered=build(product());local offer=registered.ById.Fixture
 check(not offer.BlockedReason and offer.HasRandomContents and offer.HasPermanentContents,"Validated guaranteed combo schema")
 for _,field in ipairs({"Id","DeveloperProductId"})do
  local p1,p2=product(),product();if field=="DeveloperProductId"then p2.Id="Other"end
  check(not pcall(Registry.Build,{{p1,p2}},C,deaths),"Duplicate registry identity rejected: "..field)
 end
 for _,id in ipairs({0,-1,.5,math.huge,0/0,"123",false})do local p=product();p.DeveloperProductId=id;check(not pcall(build,p),"Invalid ProductId rejected")end
 local mutations={
  function(p)p.Rewards.Crates[1].Quantity=0 end,
  function(p)p.Rewards.Crates[1].CrateId="Missing"end,
  function(p)p.Rewards.Slaps[1].SlapId="Missing"end,
  function(p)p.Rewards.Slaps[1].VariationId="Missing"end,
  function(p)p.Rewards.KillEffects[1]="Missing"end,
  function(p)p.Rewards.KillEffects[1]="DefaultFall"end,
  function(p)p.Rewards.Coins=math.huge end,
  function(p)p.Rewards.Coins=-1 end,
  function(p)p.Rewards.Coins=.5 end,
 }
 for _,mutate in ipairs(mutations)do local p=product();mutate(p);check(not pcall(build,p),"Invalid content rejected before purchase")end
 local p=product();p.DuplicatePolicy="Unspecified";check(build(p).ById.Fixture.BlockedReason=="DuplicatePolicyPending","No invented duplicate compensation")
 local Plan=premiumLoad("PremiumGrantPlan")
 local original=data(10);local receipt={PlayerId=99,ProductId=123,PurchaseId="fixture-purchase"}
 local granted,why,replay=Plan.Stage(original,offer,receipt)
 check(granted and not replay and original.Coins==10 and original.Inventory.Crates.Basic==nil,"Pure all-or-nothing staging leaves original untouched")
 check(granted.Coins==19 and granted.Inventory.Crates.Basic==2,"Existing Coins and crate inventory schema")
 check(granted.Inventory.Owned.Slaps["Classic:Common"]and granted.Inventory.Owned.DeathEffects.Frost,"Existing slab/DeathEffects ownership schema")
 check(granted.Inventory.Owned.Abilities.Dash and granted.Wins==2 and granted.Inventory.Equipped.Abilities=="Dash","Unrelated progression/equipment unchanged")
 local replayed,_,isReplay=Plan.Stage(granted,offer,receipt);check(replayed==granted and isReplay,"PurchaseId replay does not grant twice")
 local conflict=table.clone(receipt);conflict.PlayerId=100;check(not Plan.Stage(granted,offer,conflict),"Receipt identity conflict rejected")
 local retry=table.clone(receipt);retry.PurchaseId="other";check(not Plan.Stage(granted,offer,retry),"RestrictOwned prevents duplicate permanent contents")
 local once=I.Copy(offer);once.DuplicatePolicy="OncePerPlayer";check(not Plan.Stage(granted,once,retry),"One-time purchase is explicit")
 local repeatable=I.Copy(offer);repeatable.DuplicatePolicy="RepeatableNoCompensation";local repeated=assert(Plan.Stage(granted,repeatable,retry))
 check(repeated.Coins==28 and repeated.Inventory.Crates.Basic==4,"Explicit repeatable policy has no invented compensation")
 local preserved=I.Preserve(granted.Inventory,{Owned={},Equipped={}})
 check(preserved.PremiumReceipts[receipt.PurchaseId].ProductId==123 and preserved.PremiumPurchases.Fixture,"Future receipt journal survives existing sanitation")
 local premium=I.Copy(C.Crates.ById.PremiumI);premium.Enabled=true;premium.OpeningApproved=true;premium.OddsApproved=true
 premium.Weights={Basic=3,Common=1};premium.DuplicatePolicy="AllowDuplicates"
 for _,q in ipairs({1,5,10})do
  local d=data(10);d.Inventory.Crates.PremiumI=q
  local staged=assert(E.Stage(d,premium,"Open","fixture-premium-"..q,-1,C,S.new(),function()return .99 end,nil,q))
  check(staged.Inventory.Crates.PremiumI==0 and staged.Coins==10,"Same authoritative opening engine supports Premium x"..q.." without Coins charge")
 end
 local Eligibility=premiumLoad("PremiumEligibility")
 local denied=Eligibility.Policy({GetPolicyInfoForPlayerAsync=function()error("offline policy error")end},{})
 check(not denied.RandomAllowed and not denied.TradingAllowed and not denied.Verified,"Policy failure fails closed")
 local policy=Eligibility.Policy({GetPolicyInfoForPlayerAsync=function()return {ArePaidRandomItemsRestricted=true,IsPaidItemTradingAllowed=false}end},{})
 check(not policy.RandomAllowed and not policy.TradingAllowed and policy.Verified,"Restricted policy exposed accurately")
 check(not Eligibility.CanPurchase(configs,offer,policy,true,true),"Purchases disabled independently of client")
 local active=I.Copy(configs);active.PurchasesEnabled=true;active.DurableCommerceValidated=true
 local ok,code=Eligibility.CanPurchase(active,offer,policy,true,true);check(not ok and code=="PaidRandomItemsRestricted","Combos containing boxes restricted")
 policy.RandomAllowed=true;check(Eligibility.CanPurchase(active,offer,policy,true,true),"Offline approved policy path")
 check(not Eligibility.CanPurchase(active,offer,policy,false,true)and not Eligibility.CanPurchase(active,offer,policy,true,false),"Profile/context guard")
 local Coordinator=premiumLoad("ReceiptCoordinator")
 local users={GetPlayerByUserId=function(self,id)return self.UserId==id and self.Player or nil end,UserId=99};users.Player={Parent=users}
 local receiptProcessor=Coordinator.new(registered,nil,users)
 check(receiptProcessor:Process(receipt)=="Pending","InMemory/no backend never acknowledges purchase")
 local attempts=0;local durableState=original;local fail=true
 local backend={DurableValidated=true,ApplyReceiptAtomic=function(_,_,r,definition)
  attempts+=1;if fail then error("simulated durable failure")end
  local nextData=assert(Plan.Stage(durableState,definition,r));durableState=nextData
  return {Durable=true,PurchaseId=r.PurchaseId,ProductId=r.ProductId,PlayerId=r.PlayerId}
 end}
 receiptProcessor.Backend=backend
 check(receiptProcessor:Process(receipt)=="Pending"and durableState==original,"Failure retries, no false success")
 fail=false;check(receiptProcessor:Process(receipt)=="Granted"and durableState.Coins==19,"Only durable confirmation fixture acknowledges")
 check(receiptProcessor:Process(receipt)=="Granted"and durableState.Coins==19,"Repeated receipt returns durable prior result, no double grant")
 users.Player=nil;check(receiptProcessor:Process(receipt)=="Pending","Disconnected buyer deferred")
 users.Player={Parent=users}
 for _,r in ipairs({{}, {PlayerId=-1,ProductId=123,PurchaseId="x"},{PlayerId=99,ProductId=999,PurchaseId="x"},{PlayerId=99,ProductId=123,PurchaseId=""}})do check(receiptProcessor:Process(r)=="Pending","Invalid receipt deferred without granting")end
 receiptProcessor.Backend={DurableValidated=true,ApplyReceiptAtomic=function()return {Durable=false}end}
 check(receiptProcessor:Process(receipt)=="Pending","Memory-only confirmation not sufficient")
 receiptProcessor.Backend={DurableValidated=true,ApplyReceiptAtomic=function()return {Durable=true,PurchaseId="other",PlayerId=99,ProductId=123}end}
 check(receiptProcessor:Process(receipt)=="Pending","Confirmation identity mismatch rejected")
 receiptProcessor.InFlight[receipt.PurchaseId]=true;check(receiptProcessor:Process(receipt)=="Pending","Concurrent duplicate does not invoke grant")
 receiptProcessor.InFlight[receipt.PurchaseId]=nil
 receiptProcessor.Backend={DurableValidated=true,ApplyReceiptAtomic=function()coroutine.yield("inflight");error("disconnect/save failure")end}
 local asyncResult;local thread=coroutine.create(function()asyncResult=receiptProcessor:Process(receipt)end)
 local running,phase=coroutine.resume(thread);check(running and phase=="inflight","Actual receipt handler can wait for durable confirmation")
 check(receiptProcessor:Process(receipt)=="Pending","Concurrent call while first receipt yields cannot grant again")
 users.Player=nil;coroutine.resume(thread)
 check(asyncResult=="Pending"and not receiptProcessor.InFlight[receipt.PurchaseId],"Disconnect/failure during durable attempt remains retryable, no false acknowledgement")
 -- Existing normal-store UI filters unowned Premium boxes, without removing their inventory access.
 local shop=setmetatable({_catalog=service:GetCatalog(),_playerData={Inventory={Crates={}}}},{__index=shopClass})
 check(#shop:_getProducts("Crates")==13,"Normal Shop hides unowned Premium offers")
 shop._playerData.Inventory.Crates.PremiumI=1;check(#shop:_getProducts("Crates")==14,"Owned Premium box remains accessible in existing inventory")
 local View=loaded.CrateShopView;local public
 for _,row in ipairs(service:GetCatalog())do if row.Id=="PremiumI"then public=I.Copy(row)end end
 public.Metadata.Enabled=true;public.Metadata.OpeningEnabled=true;public.Metadata.OddsApproved=true
 local state=View.State(public,{Coins=0,Inventory={Crates={PremiumI=1}}},{Ok=true,ExpiresAt=200,Outcomes={{RewardId="Classic:Basic",Percent=100,Stock={UnlimitedStock=true}}}},100,false)
 check(state.OpenEnabled and not state.BuyEnabled,"Premium owned box open independent of Coins purchase")
 -- Actual physical access validator and actual public service, with offline services.
 rs.Shared.PremiumShop={PremiumShopConfig="PremiumShopConfig",Catalog={CoinPackages="CoinPackages",PremiumCombos="PremiumCombos",PremiumCrates="PremiumCrates"}}
 rs.Shared.DeathEffectDefinitions="DeathDefinitionsFixture";loaded.DeathDefinitionsFixture=deaths
 loaded.PremiumShopConfig=configs;loaded.CoinPackages=coins;loaded.PremiumCombos=combos
 loaded.PremiumCrates={}
 for _,id in ipairs({"PremiumI","PremiumII","PremiumIII"})do table.insert(loaded.PremiumCrates,{Id=id,Category="PremiumCrates",DisplayName=id,Description="draft",CrateId=id,
  SortOrder=1,Enabled=false,PurchaseApproved=false,ContentsApproved=false,DuplicatePolicy="RepeatableNoCompensation",ContractVersion="Draft",
  Rewards={Coins=0,Crates={{CrateId=id,Quantity=1}},Slaps={},KillEffects={}}})end
 loaded.PremiumProductRegistry=premiumLoad("PremiumProductRegistry");loaded.PremiumEligibility=Eligibility;loaded.ReceiptCoordinator=Coordinator
 parent.Parent.PremiumShop={PremiumProductRegistry="PremiumProductRegistry",PremiumEligibility="PremiumEligibility",ReceiptCoordinator="ReceiptCoordinator"}
 local priceQueries=0;services.MarketplaceService={GetProductInfoAsync=function()priceQueries+=1;return {PriceInRobux=55}end}
 local native=premiumLoad("Service")
 local context={GetService=function(_,name)if name=="CrateService"then return service else return ctx:GetService(name)end end}
 native:Init(context);local publicCatalog=native:Catalog(a)
 check(native:_price(offer,a)==55,"Configured fixture price comes from Marketplace API, never a hardcoded catalog price")
 services.MarketplaceService.GetProductInfoAsync=function()return {PriceInRobux=0/0}end
 check(native:_price(offer,a)==nil,"Invalid Marketplace price not shown")
 services.MarketplaceService.GetProductInfoAsync=function()return {PriceInRobux=55,IsForSale=false}end
 check(select(2,native:_price(offer,a))=="No disponible","Marketplace unavailability is preserved")
 priceQueries=0
 check(publicCatalog.Ok and #publicCatalog.Products==5 and priceQueries==0,"Real public catalog has five unconfigured drafts; zero price requests for nil IDs")
 for _,entry in ipairs(publicCatalog.Products)do check(entry.PriceRobux==nil and not entry.PurchaseAllowed,"No invented price or sale authorization")end
 check(native:Request(a,"Purchase",{Id="Fixture",Rewards={Coins=999999},Price=0}).Code=="PurchasesDisabled","Untrusted client contents cannot grant or enable purchase")
 native.Rate[a]=nil;check(native:Request(a,"Odds",{Id="PremiumI"}).Quotes.PremiumI.Code=="CommercialApprovalPending","Premium draft odds are pending, not invented")
 local access=premiumLoad("Access");access:Init(context)
 local part={Position=vec(0),IsDescendantOf=function()return true end};local prompt={Parent=part,Enabled=true,MaxActivationDistance=12}
 access.Part=part;access.Prompt=prompt;a.Character.HumanoidRootPart.Position=vec(0)
 check(access:Validate(a,part,prompt),"Actual CoinShop validator accepts near connected lobby player")
 a.Character.HumanoidRootPart.Position=vec(12.01);check(not access:Validate(a,part,prompt),"Server rejects out-of-range prompt")
 a.Character.HumanoidRootPart.Position=vec(0);a.Attrs.MatchId="combat";check(not access:Validate(a,part,prompt),"Combat cannot open physical CoinShop")
 a.Attrs.MatchId=nil;check(not access:Validate(a,{},prompt),"Different interaction point rejected")
 prompt.Enabled=false;check(not access:Validate(a,part,prompt),"Disabled prompt rejected")
 print("PASS PremiumShopV1: "..(assertions-start).." new isolated commerce assertions; cumulative "..assertions.."; payments/gameplay NOT RUN")
end
