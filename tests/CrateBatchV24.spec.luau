--!nonstrict
-- Executes actual modules with deterministic clocks/policy/store. Never starts Studio.
local assertions=0
local function check(v,message)assertions+=1;assert(v,message)end
local function near(a,b)return math.abs(a-b)<1e-9 end
local loaded={}
local names={"OpeningConfig","BatchOpening","Registry","VariationDefinitions","SlapDefinitions","PremiumCrateDefinitions","InitialOdds","CrateDefinitions","StockDefinitions","Catalog","Inventory","Odds","Appearance","CrateShopView","OddsPresentation","StockLedger","InMemoryStock","ProductionStockAdapter","RewardVisualMetadata","CrateBatchEngine","CrateEngine","AnnouncementAdapter"}
local parent={}for _,name in ipairs(names)do parent[name]=name end
parent.Parent={Shop={Providers={CrateProviders="CrateProviders"}}};parent.Crates=parent
local function signal()
 local s={Callbacks={}};function s:Connect(f)table.insert(self.Callbacks,f);return {Disconnect=function()end}end
 return s
end
local world={GetServerTimeNow=function()return 100 end}
local objects={}
local function node(class,name)
 local n={ClassName=class,Name=name,Children={},Attrs={},Parent=true}
 function n:IsA(c)return self.ClassName==c end
 function n:FindFirstChild(key)return self.Children[key]end
 function n:GetAttribute(k)return self.Attrs[k]end
 function n:GetChildren()local a={}for _,v in pairs(self.Children)do table.insert(a,v)end;return a end
 function n:FireClient(p,packet)table.insert(objects,{Player=p,Packet=packet,Name=self.Name})end
 function n:FireAllClients(packet)table.insert(objects,{Packet=packet,Name=self.Name})end
 return setmetatable(n,{__index=function(s,k)return s.Children[k]end})
end
local rs=node("ReplicatedStorage","RS");rs.Shared={SlapCrates=parent}
local ss=node("ServerStorage","SS");ss.Attrs.CrateStudioTestsEnabled=true
local players=node("Players","Players");players.PlayerRemoving=signal()
local studio=true;local policy={ArePaidRandomItemsRestricted=false};local policyFailure=false
local guid=0
local services={ReplicatedStorage=rs,ServerStorage=ss,RunService={IsStudio=function()return studio end},Players=players,
 PolicyService={GetPolicyInfoForPlayerAsync=function()if policyFailure then error("Policy unavailable")end;return policy end},
 HttpService={GenerateGUID=function()guid+=1;return "guid-"..guid end}}
local extraEnv={};local baseEnv=getfenv()
local function load(name,key)
 local f=assert(loadstring(Sources[key or "Crates/"..name],name))
 setfenv(f,setmetatable({script={Parent=parent},game={GetService=function(_,k)return services[k]end},workspace=world,
  require=function(k)return assert(loaded[k],"Unknown require "..tostring(k))end,
  Color3={fromHSV=function(...)return {...}end,fromRGB=function(...)return {...}end},Random={new=function()return {NextNumber=function()return .99 end}end},
  typeof=function(v)return type(v)=="table" and (v.Kind or (v.ClassName and "Instance")) or type(v)end,
  print=function()end,warn=function()end}, {__index=function(_,key)return extraEnv[key] or baseEnv[key]end}))
 local result=f();loaded[name]=result;return result
end
for _,name in ipairs(names)do load(name)end
local C=loaded.Catalog;local I=loaded.Inventory;local O=loaded.Odds;local S=loaded.InMemoryStock;local E=loaded.CrateEngine
check(not loaded.AnnouncementAdapter.new(function()end):PublishGlobal("id",{}),"Global transport is inert without authorised infrastructure")
check(#C.Variations.Order==12,"12 variations")
check(#C.Crates.Order==16,"12 pending crates plus isolated fixture and three Premium drafts")
check(C.ProductionCommerceEnabled==false,"Production gate closed")
for _,id in ipairs(C.Crates.Order)do if id~="StudioTest"and not C.Crates.ById[id].PremiumOnly then
 local c=C.Crates.ById[id];check(not E.Approved(c) and c.PriceApproved==true and c.PriceCoins>0 and not c.OddsApproved and not c.Enabled and next(c.Weights)~=nil,"No invented commerce "..id)
end end
local ok=pcall(loaded.Registry.Build,{{Id="A",DisplayName="a"},{Id="A",DisplayName="b"}},"Id")
check(not ok,"Duplicate IDs rejected")
local crate=C.Crates.ById.StudioTest
local function data(coins)
 return {Coins=coins or 10,Wins=2,Inventory=I.Extend({Owned={Abilities={Dash=true},Slaps={Legacy=true}},Equipped={Abilities="Dash"}})}
end
local d=data();local stock=S.new()
check(d.Inventory.Owned.Slaps["Legacy:Basic"] and d.Inventory.Owned.Slaps.Legacy,"Legacy ownership additive")
local rows=assert(O.Resolve(crate,C,d.Inventory,stock))
check(#rows==2 and near(rows[1].Percent+rows[2].Percent,100),"Final outcomes sum to100")
check(rows[1].Reward.RewardId=="Classic:Basic" and rows[1].Percent==75,"Explicit test weights only")
local bad=table.clone(crate)
for _,weights in ipairs({{Basic=-1},{Basic=0},{Basic=math.huge},{Unknown=1},{Basic=0/0}})do
 bad.Weights=weights;check(O.Resolve(bad,C,d.Inventory,stock)==nil,"Invalid weights fail closed")
end
bad.Weights={Basic=1};bad.DuplicatePolicy="UniquePerPlayer"
check(O.Resolve(bad,C,d.Inventory,stock)==nil,"Existing Basic excluded, no results")
local alt=I.Copy(C);alt.Rewards["New:Common"]={RewardId="New:Common",SlapId="New",VariationId="Common",DisplayName="New"}
local r=assert(O.Resolve(crate,alt,d.Inventory,stock));local sum=0
for _,row in ipairs(r)do sum+=row.Percent;if row.Reward.VariationId=="Common" then check(near(row.Percent,12.5),"Variation weight divided across two Slaps")end end
check(near(sum,100),"Individual odds still sum100")
check(O.Resolve(crate,C,d.Inventory,{View=function()return nil,"Unknown"end})==nil,"Unknown stock blocks")
local poor,why=E.Stage(data(0),crate,"Purchase","poor",-1,C,stock,0)
check(not poor and why=="InsufficientFunds","Insufficient balance unchanged")
local purchase=assert(E.Stage(d,crate,"Purchase","p1",-1,C,stock,0))
check(d.Coins==10 and purchase.Coins==9 and purchase.Inventory.Crates.StudioTest==1,"Purchase stages one crate and Coins together")
check(purchase.Inventory.Owned.Abilities.Dash and purchase.Wins==2,"Unrelated profile preserved")
local again,_,receipt,replay=E.Stage(purchase,crate,"Purchase","p1",-1,C,stock,0)
check(again==purchase and replay and receipt.Kind=="Purchase","Repeated Purchase returns receipt without charging")
local conflict,err=E.Stage(purchase,crate,"Open","p1",-1,C,stock,0)
check(not conflict and err=="OperationConflict","Operation ID cannot change kind")
local opened=assert(E.Stage(purchase,crate,"Open","o1",-1,C,stock,.99))
local op=opened.Inventory.CrateOperations.o1
check(op.RewardId=="Classic:Common" and opened.Coins==9,"Reward decided before presentation without charging twice")
check(opened.Inventory.Crates.StudioTest==0 and opened.Inventory.Owned.Slaps[op.RewardId],"Open consumes exactly one crate")
check(opened.Inventory.SlapUnits[op.UnitId].OwnerUserId==-1,"Original negative Studio owner preserved")
check(stock.State.Operations[op.UnitId].State=="Reserved","Reservation survives presentation/disconnection")
E.Reconcile(opened,stock);E.Reconcile(opened,stock)
check(op.State=="Completed" and stock.State.Operations[op.UnitId].State=="Issued","Reconciliation idempotently issues reserved unit")
local second,_,same,isReplay=E.Stage(opened,crate,"Open","o1",-1,C,stock,.1)
check(second==opened and same.RewardId==op.RewardId and isReplay,"Retry never rerolls")
local noBox,noReason=E.Stage(opened,crate,"Open","o2",-1,C,stock,.1)
check(not noBox and noReason=="NoCrate","Empty box inventory rejected")
local count=0 for _ in pairs(opened.Inventory.SlapUnits)do count+=1 end
check(count==1,"One unit after retry and duplicate reconcile")
local roundTrip=I.Preserve(opened.Inventory,{Owned=I.Copy(opened.Inventory.Owned),Equipped=I.Copy(opened.Inventory.Equipped)})
check(roundTrip.SlapUnits[op.UnitId].RewardId==op.RewardId and roundTrip.CrateOperations.o1.State=="Completed","Rich inventory survives normalisation")
local limited=I.Copy(C);limited.Rewards["Classic:Common"].LimitedStock=true;limited.Rewards["Classic:Common"].TotalSupply=1;limited.Rewards["Classic:Common"].EditionId="testEdition"
limited.Variations.ById.Common.LimitedStock=true;limited.Variations.ById.Common.DefaultStock=1;limited.Variations.ById.Common.EditionId="aggregateEdition"
local shared={Buckets={},Operations={}};local first=S.new(shared);local other=S.new(shared)
local reward=limited.Rewards["Classic:Common"];local variation=limited.Variations.ById.Common
check(first:Reserve("A",-1,reward,variation),"Reserve last unit across both limits")
check(not other:Reserve("B",-2,reward,variation),"Second server sharing authoritative ledger cannot reserve last unit")
check(first:Reserve("A",-1,reward,variation),"Repeated reserve same operation idempotent")
check(not first:Reserve("A",-2,reward,variation),"Owner conflict rejected")
local left=assert(other:View(reward,variation));check(left.SoldOut and left.RemainingStock==0,"Reserved last unit excluded")
check(first:Commit("A") and first:Commit("A"),"Repeated commit no extra issue")
check(not first:Release("A"),"Issued stock cannot regenerate by compensation")
for _,b in pairs(shared.Buckets)do check(b.Issued==1 and b.Reserved==0,"Both caps debit one issuance")end
local eligible=assert(O.Resolve(crate,limited,d.Inventory,other));check(#eligible==1 and eligible[1].Percent==100,"Sold out excluded and probabilities recomputed")
local unconfigured=I.Copy(reward);unconfigured.TotalSupply=nil
check(other:View(unconfigured,variation)==nil,"No invented limited supply")
local changed=I.Copy(reward);changed.TotalSupply=2
check(other:View(changed,variation)==nil,"Supply cannot silently regenerate")
local releaseStock=S.new();check(releaseStock:Reserve("release",1,reward,variation) and releaseStock:Release("release"),"Aborted ungranted reservation released")
check(releaseStock:View(reward,variation).RemainingStock==1,"Compensation releases reservation, not issued unit")
check(not releaseStock:Reserve("release",1,reward,variation),"Released ID cannot become another grant")
-- Prepared production adapter, fake store ONLY: replayed transforms and response lost after durable update.
local stored=nil;local failAfterWrite=false
local store={UpdateAsync=function(_,_,transform)
 transform(I.Copy(stored));local updated=transform(I.Copy(stored));if updated then stored=updated end
 if failAfterWrite then error("reply lost")end;return updated
end}
local adapter=loaded.ProductionStockAdapter.new(store,"isolatedTestKey")
check(adapter:View(reward,variation)==nil,"Production snapshot unavailable blocks sale")
failAfterWrite=true;local accepted=adapter:Reserve("durableA",1,reward,variation)
check(not accepted and stored.Operations.durableA.State=="Reserved","Ambiguous response retains durable reservation")
failAfterWrite=false;check(adapter:Reserve("durableA",1,reward,variation),"Retry ambiguous reservation uses same ID")
check(not adapter:Reserve("durableB",2,reward,variation),"Atomic last unit safe after callback retry")
check(adapter:Commit("durableA"),"Commit reserved unit after retry")
-- Actual service routing, fail-closed policy, profile commit and observer scoping.
parent.StandOpeningService="StandOpeningFixture"
loaded.StandOpeningFixture={new=function()return {IsStandMode=function()return false end,Context=function()return {Mode="Spin"}end,Open=function(_,_,_,callback)return callback()end}end}
local service=load("CrateService","CrateService")
local a=node("Player","A");a.UserId=-1;a.Parent=players
local b=node("Player","B");b.UserId=-2;b.Parent=players
local c=node("Player","C");c.UserId=-3;c.Parent=players;c.Attrs.MatchId="OTHER"
local observer=node("Player","Observer");observer.UserId=-4;observer.Parent=players
local vectorMeta={}
local function vec(x)local v={X=x,Magnitude=math.abs(x),Kind="Vector3"};return setmetatable(v,vectorMeta)end
function vectorMeta.__add(x,y)return vec(x.X+y.X)end
function vectorMeta.__sub(x,y)return vec(x.X-y.X)end
function vectorMeta.__mul(x,y)return vec(x.X*y)end
for _,p in ipairs({a,b,c,observer})do p.Character=node("Model","Char");p.Character.Children.HumanoidRootPart={Position=vec(0),CFrame={LookVector=vec(1)}}end
function players:GetPlayers()return {a,b,c,observer}end
local pdata={[a]=data(),[b]=data()}
local ps={}
function ps:IsShopDataReady(p)return pdata[p]~=nil end
function ps:GetPlayerData(p)return pdata[p]end
function ps:GetInventory(p)return pdata[p].Inventory end
function ps:CommitCrateState(p,expected,nextData)
 if self.Fail then return false,"ProfileChanged"end
 check(pdata[p].Inventory==expected,"Same authoritative profile at commit");pdata[p]=nextData;return true
end
local shop={_withShopLock=function(_,_,fn)return fn()end}
local ctx={PersistenceInfo={Environment="Studio",ProviderName="InMemory",WritesToCloud=false},GetService=function(_,name)return ({PlayerService=ps,RoundService={GetSessionForPlayer=function()return nil end},ShopService=shop})[name]end}
service:Init(ctx);service._resource=function()return true end
service._reveal=node("RemoteEvent","Reveal");service._world=node("RemoteEvent","World");service._announce=node("RemoteEvent","Announce")
local quote=service:Quote(a,"Basic");check(quote.Ok and quote.ReviewOnly and not quote.PurchaseAllowed,"Pending commerce blocked on server")
policy.ArePaidRandomItemsRestricted=true
quote=service:Quote(a,"StudioTest");check(not quote.Ok and quote.Code=="PaidRandomItemsRestricted","Restricted policy cannot quote/buy")
policy.ArePaidRandomItemsRestricted=false;policyFailure=true
check(not service:Quote(a,"StudioTest").Ok,"Policy query error fails closed")
policyFailure=false;a.Attrs.MatchId="match"
check(service:Quote(a,"StudioTest").Code=="LobbyOnly","Combat blocks opening")
a.Attrs.MatchId=nil
quote=service:Quote(a,"StudioTest");check(quote.Ok,"Eligible Studio test quote")
local result=service:_transact(a,"Purchase",{CrateId="StudioTest",OperationId="servicePurchase",QuoteToken=quote.Token})
check(result.Ok and pdata[a].Coins==9,"Service purchase commits existing Coins")
result=service:_transact(a,"Open",{CrateId="StudioTest",OperationId="serviceOpen",QuoteToken=quote.Token})
check(result.Ok and pdata[a].Inventory.Crates.StudioTest==0,"Service opening grants and consumes")
local delivered=#objects
result=service:_transact(a,"Open",{CrateId="StudioTest",OperationId="serviceOpen"})
check(result.Ok and result.Replay and #objects==delivered,"Repeated opening sends no duplicate presentation")
local private=0 for _,message in ipairs(objects)do if message.Name=="Reveal"then private+=1;check(message.Player==a,"Only buyer receives HUD")end end
check(private==1,"Exactly one private reveal")
local worlds=0
for _,message in ipairs(objects)do if message.Name=="World"then worlds+=1;check(message.Player~=c,"Other-session observer excluded")end end
check(worlds==3,"Buyer plus two nearby lobby observers receive local 3D event")
local savedAnnounce=C.Variations.ById.Common.AnnounceInChat
C.Variations.ById.Common.AnnounceInChat=true
service:_present(a,crate,result.Operation);service:_present(a,crate,result.Operation)
local announcements=0 for _,message in ipairs(objects)do if message.Name=="Announce"then announcements+=1 end end
check(announcements==1,"Rare chat announcement emitted once for authoritative opening")
C.Variations.ById.Common.AnnounceInChat=savedAnnounce
local quote2=service:Quote(b,"StudioTest")
service._quotes[b].Signature="obsolete"
local before=pdata[b].Coins
check(service:_transact(b,"Purchase",{CrateId="StudioTest",OperationId="stale",QuoteToken=quote2.Token}).Code=="OddsChanged" and pdata[b].Coins==before,"Changed odds reject before charging")
quote2=service:Quote(b,"StudioTest")
check(service:_transact(b,"Purchase",{CrateId="StudioTest",OperationId="beforeFailure",QuoteToken=quote2.Token}).Ok,"Prepare closed crate for failed profile commit")
ps.Fail=true
local aborted=service:_transact(b,"Open",{CrateId="StudioTest",OperationId="failedOpen",QuoteToken=quote2.Token})
check(not aborted.Ok and pdata[b].Inventory.Crates.StudioTest==1,"Failed profile commit consumes no crate")
check(service._stock.State.Operations["-2:failedOpen"].State=="Released","Failed pre-grant profile commit releases only reserved stock")
ps.Fail=false
check(service:_transact(b,"Open",{CrateId="StudioTest",OperationId="afterFailure",QuoteToken=quote2.Token}).Ok,"New operation can retry after explicit abort")
local crashed=assert(E.Stage(purchase,crate,"Open","lostAfterGrant",-9,C,stock,.99))
local realCommit=stock.Commit;stock.Commit=function()return false,"StoreOffline"end
E.Reconcile(crashed,stock)
check(crashed.Inventory.CrateOperations.lostAfterGrant.State=="GrantCommitted","Post-grant persistence failure retains recoverable state")
check(stock.State.Operations["-9:lostAfterGrant"].State=="Reserved","Post-grant failure never releases reserved entitlement")
stock.Commit=realCommit;E.Reconcile(crashed,stock)
check(crashed.Inventory.CrateOperations.lostAfterGrant.State=="Completed","Reconnect/retry completes original grant without another crate")
studio=false;service:Init({PersistenceInfo={ProviderName="RobloxDataStore",WritesToCloud=true},GetService=ctx.GetService})
check(service._stock==nil and not service:Quote(a,"StudioTest").Ok,"Production cannot select InMemory or open commerce")
-- Provider integration and actual Shop public projection retain pending commercial flags.
studio=true;service:Init(ctx);service._resource=function()return true end
local providers=load("CrateProviders","CrateProviders").Create(service)
check(#providers[1]:GetProducts()==16 and #providers[2]:GetProducts()==12,"Providers derive catalogues without duplicated lists")
check(not providers[1]:CanPurchase(a,{Id="StudioTest"}),"Generic Shop purchase cannot bypass quoted crate API")
check(not providers[2]:CanPurchase(a,{Id="Classic:Common"}),"Individual Slap purchase forbidden")
function ps:SetEquippedItem(p,category,id)pdata[p].Inventory.Equipped[category]=id;return true end
check(providers[2]:OnEquipped(a,providers[2]:GetProduct("Classic:Common")),"Owned exact variation equips through existing inventory API")
check(not providers[2]:OnEquipped(a,providers[2]:GetProduct("Classic:Galaxy")),"Owning one variation cannot equip another")
check(service:ResolveEquipped(a).RewardId=="Classic:Common" and service:GetSlapModel(C.Rewards["Classic:Common"])=="Classic","Equipped variation resolves unchanged base template")
pdata[a].Inventory.Equipped.Slaps="missing"
check(service:ResolveEquipped(a).RewardId==C.DefaultRewardId,"Missing equipment has valid Classic fallback")
services.ServerScriptService=node("ServerScriptService","Server")
services.RunService.IsRunning=function()return true end
extraEnv.task={defer=function()end}
rs.Children.Remotes=node("Folder","Remotes");rs.Remotes.Children.Shop=node("Folder","Shop")
for _,name in ipairs({"GetCatalog","PurchaseProduct","EquipProduct","UnequipProduct"})do rs.Remotes.Shop.Children[name]=node("RemoteFunction",name)end
local remotes=load("ShopRemoteActual","ShopRemotes")
remotes:Init({GetCatalog=function()return providers[1]:GetProducts()end})
local public=rs.Remotes.Shop.GetCatalog.OnServerInvoke(a)
check(public[1].Metadata.PricePending==false and public[1].Metadata.PurchaseEnabled==false,"Public pending metadata prevents misleading zero-price purchase UI")
-- Actual presentation controller: animation endpoint and local scene cleanup, no engine claims.
local tweens,delays,clones={},{},{}
services.TextChatService={}
services.TweenService={Create=function(_,target,_,goals)
 local t={Completed={Once=function(self,f)self.Callback=f end}}
 function t:Play()for k,v in pairs(goals)do target[k]=v end;if self.Completed.Callback then self.Completed.Callback("Completed")end end
 function t:Cancel()end
 table.insert(tweens,{Target=target,Goals=goals});return t
end}
extraEnv.Enum={EasingStyle={Quint="Quint",Sine="Sine"},EasingDirection={Out="Out",InOut="InOut"},PlaybackState={Completed="Completed"}}
extraEnv.TweenInfo={new=function()return {}end}
extraEnv.UDim2={fromOffset=function(x,y)return {X={Offset=x},Y={Offset=y}}end}
extraEnv.Vector3={new=function(x)return vec(x)end}
extraEnv.CFrame={new=function()return {}end}
extraEnv.task={delay=function(_,f)table.insert(delays,f)end}
local function visual(class,name)
 local n=node(class,name)
 function n:IsA(c)return c==class or c=="GuiObject" and (class=="Frame" or class=="TextLabel") or c=="BasePart" and class=="Part"end
 function n:GetPropertyChangedSignal()return signal()end
 function n:GetDescendants()local result={}for _,child in pairs(self.Children)do table.insert(result,child);for _,desc in ipairs(child:GetDescendants())do table.insert(result,desc)end end;return result end
 function n:FindFirstChildWhichIsA(c,recurse)for _,child in pairs(self.Children)do if child:IsA(c)then return child end;if recurse then local found=child:FindFirstChildWhichIsA(c,true);if found then return found end end end end
 function n:PivotTo(cf)self.Pivot=cf end
 function n:Destroy()self.Parent=nil;self.Destroyed=true end
 function n:Clone()
  local copy=visual(self.ClassName,self.Name);for k,v in pairs(self)do if type(v)~="function" and k~="Children" then copy[k]=v end end
  copy.Children={};for k,child in pairs(self.Children)do copy.Children[k]=child:Clone()end
  table.insert(clones,copy);return copy
 end
 return n
end
local spin=visual("Frame","Spin");spin.Children.Close=visual("Frame","Close");spin.Children.Result=visual("TextLabel","Result")
spin.Children.Tick=visual("Sound","Tick");spin.Tick.SoundId="";spin.Children.Reveal=visual("Sound","Reveal");spin.Reveal.SoundId=""
spin.Children.Window=visual("Frame","Window");spin.Window.AbsoluteSize={X=700};spin.Window.Children.RollingStrip=visual("Frame","RollingStrip")
local template=visual("Frame","RewardTemplate");template.Children.Title=visual("TextLabel","Title");spin.Window.RollingStrip.Children.RewardTemplate=template
players.LocalPlayer=a
local client=load("CrateController","CrateController");client:Init({});client._spinPanel=spin
local packet={OpeningId="visual-confirmed",Operation={RewardId="Classic:Common"},Duration=4,Model="Basic",StartedAt=100,Position=vec(5)}
client:_spin(packet)
check(spin.Result.Text=="Obtuviste "..C.Rewards[packet.Operation.RewardId].DisplayName and spin.Close.Visible,"HUD reveals actual confirmed reward and enables Close after tween")
local winner
for _,o in ipairs(clones)do if o.Name=="Reward_41"then winner=o end end
check(winner and winner.Title.Text==C.Rewards[packet.Operation.RewardId].DisplayName,"Winner card uses server result, never rerolls")
check(spin.Window.RollingStrip.Position.X.Offset==700/2-(40*140+66),"Strip ends with winner centred exactly")
local tweenCount=#tweens;client:_spin(packet);check(#tweens==tweenCount,"Duplicate private packet does not animate again")
rs.Children.CrateEffects=visual("Folder","CrateEffects");local model=visual("Model","Basic");model.Children.Body=visual("Part","Body");model.Children.Lid=visual("Part","Lid");rs.CrateEffects.Children.Basic=model
rs.Children.CrateRewardPreviews=visual("Folder","CrateRewardPreviews");local preview=visual("Model","Classic");preview.Children.Hand=visual("Part","Hand");rs.CrateRewardPreviews.Children.Classic=preview
rs.Children.SlapVariationEffects=visual("Folder","SlapVariationEffects")
client:_world(packet)
local temporary for object in pairs(client._worldModels)do temporary=object end
check(temporary and temporary.Parent==world,"Nearby observer creates only local world presentation")
for _,callback in ipairs(delays)do callback()end
check(temporary.Destroyed and next(client._worldModels)==nil,"World models cleaned after reveal")
client:_world(packet);check(next(client._worldModels)==nil,"Duplicate world packet cannot recreate scene")
-- Extends the actual-module V1 fixture. No Studio, cloud or gameplay execution.
local View=loaded.CrateShopView
local order={"Basic","Common","Uncommon","Rare","Gold","Arcoiris","Emote","Wings","Epic","Legendary","Blood","Galaxy","StudioTest"}
local list=service:GetCatalog()
for i,id in ipairs(order)do check(list[i].Id==id and list[i].SortOrder==C.Crates.ById[id].SortOrder,"Server explicit order "..id)end
local shopClass=load("ShopControllerActual","ShopController")
local shopUI=setmetatable({_catalog={},_category="Crates",_cards={}},{__index=shopClass})
for i=#list,1,-1 do table.insert(shopUI._catalog,list[i])end
local sorted=shopUI:_getProducts("Crates")
for i,id in ipairs(order)do check(sorted[i].Id==id,"Actual Shop sorting ignores shuffled arrival "..id)end
table.insert(shopUI._catalog,{Id="Future",Category="Crates",SortOrder=35,Price=999})
local future=shopUI:_getProducts("Crates");check(future[4].Id=="Future" and future[5].Id=="Rare","Future crate inserted by configured position")
local ties=View.SortProducts({{Id="Z",SortOrder=1},{Id="A",SortOrder=1}},"Crates")
check(ties[1].Id=="A","SortOrder ties use stable CrateId")
local abilities=View.SortProducts({{Id="A",Price=9},{Id="Z",Price=1}},"Abilities")
check(abilities[1].Id=="Z","Other category price order unchanged")
local testProduct=providers[1]:GetProduct("StudioTest")
local snapshot={Coins=1,Inventory=I.Extend({})}
local q={Ok=true,Token="quote",ExpiresAt=130,PriceCoins=1,Outcomes={{RewardId="Classic:Basic",Percent=75,Stock={UnlimitedStock=true}},{RewardId="Classic:Common",Percent=25,Stock={UnlimitedStock=true}}}}
for i=1,12 do local state=View.State(list[i],snapshot,nil,100,false)
 check(state.PriceText==tostring(list[i].Price).." Coins"and state.Status=="Probabilidades pendientes"and not state.BuyEnabled,"No false zero price "..list[i].Id)
end
local state=View.State(testProduct,snapshot,q,100,false)
check(state.PriceText=="1 Coins" and state.BuyEnabled and not state.OpenEnabled,"Approved test price from server and no unopened box")
local poor=I.Copy(snapshot);poor.Coins=0;poor.Inventory.Crates.StudioTest=1
state=View.State(testProduct,poor,q,100,false)
check(not state.BuyEnabled and state.OpenEnabled and state.Status=="Coins insuficientes","No balance prevents buy but not opening owned box")
local pendingOdds=I.Copy(testProduct);pendingOdds.Metadata.OddsApproved=false
check(View.State(pendingOdds,snapshot,q,100,false).Status=="Probabilidades pendientes","Odds approval distinct from price approval")
check(not View.State(testProduct,snapshot,q,130,false).BuyEnabled,"Quote expires at exact deadline")
local invalid=I.Copy(q);invalid.Outcomes[1].Percent=70
check(not View.State(testProduct,snapshot,invalid,100,false).BuyEnabled,"Undisclosable distribution blocked in UI")
local unknown=I.Copy(q);unknown.Outcomes={}
check(not View.State(testProduct,snapshot,unknown,100,false).BuyEnabled,"No final outcomes cannot enable purchase")
state=View.State(testProduct,snapshot,{Ok=false,Code="NoEligibleResults"},100,false)
check(not state.BuyEnabled and not state.OpenEnabled and state.StockText=="Sin resultados disponibles","Sold out/no eligible results cannot enable action")
-- Use actual client methods against actual service/engine/profile fixture.
extraEnv.task.spawn=function(fn)fn()end;extraEnv.task.wait=function()end;extraEnv.task.defer=function()end
service:Init(ctx);service._resource=function()return true end;pdata[a]=data(2)
local flow=load("CrateFlowActual","CrateController")
local refreshes=0
function shopUI:_refreshStates()refreshes+=1 end
local flowContext={GetController=function(_,name)return if name=="ShopController"then shopUI else flow end}
flow:Init(flowContext);flow._spinPanel=spin
local panel=visual("Frame","Panel")
for _,name in ipairs({"Title","Count","Status","Outcomes","Buy","Open","ViewOdds"})do panel.Children[name]=visual("TextLabel",name)end
flow._panel=panel;flow._request={};flow:SetCatalog(service:GetCatalog())
local calls,ids={},{}
local loseReply=true;local reentry=false
function flow:_call(action,args)
 table.insert(calls,action)
 if action=="Inventory"then return {Ok=true,Inventory=pdata[a].Inventory,Snapshot={Coins=pdata[a].Coins,Inventory=I.Copy(pdata[a].Inventory)}}end
 if action=="Quote"then return service:Quote(a,args.CrateId)end
 table.insert(ids,args.OperationId)
 if action=="Purchase"and not reentry then reentry=true;self:_mutate("Purchase")end
 local result=service:_transact(a,action,args)
 if action=="Purchase"and loseReply then loseReply=false;return {Ok=false,Code="NoResponse"}end
 return result
end
flow:ShowCrate("StudioTest")
check(panel.Buy.Active and not panel.Open.Active and panel.Outcomes.Text:find("75",1,true),"Actual panel shows numeric odds before enabling purchase")
flow:_mutate("Purchase")
check(pdata[a].Coins==1 and pdata[a].Inventory.Crates.StudioTest==1,"Purchase commits right Coins and one closed box")
check(flow._pendingAction and panel.Buy.Text=="REINTENTAR","Lost response retains unresolved operation")
flow:_mutate("Purchase")
check(ids[1]==ids[2] and #ids==2,"Retry preserves OperationId; reentrant click creates no extra request")
check(pdata[a].Coins==1 and pdata[a].Inventory.Crates.StudioTest==1,"Same operation cannot double-charge or duplicate crate")
check(not flow._pendingAction and shopUI._playerData.Coins==1 and shopUI._playerData.Inventory.Crates.StudioTest==1,"Balance/inventory snapshot refreshed in Shop")
check(panel.Count.Text:find("Cajas: 1",1,true)and panel.Open.Active,"Owned crate quantity and Open refreshed")
pdata[a].Coins=0;flow:_quoteCurrent("StudioTest")
local beforeCalls=#calls;flow:_mutate("Purchase")
check(not panel.Buy.Active and #calls==beforeCalls,"Insufficient balance disables client request")
local forged=service:_transact(a,"Purchase",{CrateId="StudioTest",OperationId="forgedPrice",QuoteToken=flow._quote.Token,PriceCoins=0})
check(not forged.Ok and forged.Code=="InsufficientFunds"and pdata[a].Coins==0,"Server ignores Remote price and rejects insufficient funds")
local messagesBefore=#objects;local observed
local originalSpin=flow._spin
flow._spin=function(self,packet)observed=packet;return originalSpin(self,packet)end
flow:_mutate("Open")
check(pdata[a].Inventory.Crates.StudioTest==0 and pdata[a].Coins==0,"Opening consumes once with no additional Coin cost")
check(observed and pdata[a].Inventory.Owned.Slaps[observed.Operation.RewardId],"Spin uses actually granted Slap+variation")
for i=messagesBefore+1,#objects do local message=objects[i]
 if message.Name=="World"or message.Name=="Reveal"then check(message.Packet.Operation.RewardId==observed.Operation.RewardId,"World/HUD use same assigned reward")end
end
check(not panel.Open.Active and flow._quote==nil,"Empty inventory and stale post-open quote cannot reopen")
local v=providers[2]:GetProduct(observed.Operation.RewardId)
check(providers[2]:OnEquipped(a,v),"Awarded exact reward remains equippable")
flow:_quoteCurrent("StudioTest")
service._quotes[a].Until=-1
local expired=service:_transact(a,"Purchase",{CrateId="StudioTest",OperationId="expiredV12",QuoteToken=flow._quote.Token})
check(not expired.Ok and expired.Code=="ViewOddsFirst","Server rejects expired quote without debit")
local savedResource=service._resource;service._resource=function()return false end
flow:_quoteCurrent("StudioTest")
check(not panel.Buy.Active and not panel.Open.Active and panel.Status.Text:find("elegibles",1,true),"Actual no-results response disables both buttons")
service._resource=savedResource;policy.ArePaidRandomItemsRestricted=true
flow:_quoteCurrent("StudioTest")
check(not panel.Buy.Active and not panel.Open.Active,"Restricted policy never enables client purchase")
policy.ArePaidRandomItemsRestricted=false
-- Public projection preserves ordering, prices and approval flags.
local public=rs.Remotes.Shop.GetCatalog.OnServerInvoke(a)
check(public[1].SortOrder==10 and not public[1].Metadata.PricePending and not public[1].Metadata.OddsApproved,"Public Shop contract retains order and approvals")
-- Late Quote for a prior selection must not replace the current selection state.
shopUI._context=flowContext;shopUI._selectedId="Basic"
local detail={}
for _,name in ipairs({"NameLabel","DescriptionLabel","PriceRow","PriceLabel","StatusLabel","ActionButton","SecondaryButton"})do detail[name]=visual("TextLabel",name)end
shopUI._ui={Detail=detail}
shopUI:_renderDetail()
check(detail.PriceLabel.Text=="500 Coins"and detail.ActionButton.Text=="VER CAJA","Actual Shop detail shows pending price without crashing")
local card=visual("Frame","Card")
for _,name in ipairs({"PriceLabel","StateBadge","CoinIcon"})do card.Children[name]=visual("TextLabel",name)end
card.Children.CrateActions=visual("Frame","CrateActions")
for _,name in ipairs({"Action","StockLabel"})do card.CrateActions.Children[name]=visual("TextLabel",name)end
shopUI:_applyCardState(card,providers[1]:GetProduct("Basic"))
check(card.PriceLabel.Text=="500 Coins"and not card.CrateActions.Action.Active,"Actual card blocks pending commerce and hides zero")
flow._quoteCache.StudioTest=service:Quote(a,"StudioTest")
shopUI._playerData={Coins=0,Inventory=I.Extend({})};shopUI._playerData.Inventory.Crates.StudioTest=2
shopUI:_applyCardState(card,testProduct)
check(card.StateBadge.Text=="2 cajas"and card.CrateActions.Action.Active and card.CrateActions.Action.Text=="ABRIR","Actual acquired-card state uses quantity and offers opening with no balance")
local normalCall=flow._call
flow._call=function(self,action,args)
 if action=="Quote"then self._selectionVersion+=1;self._crateId="Basic";return q end
 return normalCall(self,action,args)
end
flow._crateId="StudioTest";flow._quote=nil
flow:_quoteCurrent("StudioTest")
check(flow._quote==nil and flow._crateId=="Basic","Late quote cannot apply to another crate")
flow._crateId="StudioTest";flow._quote=nil
flow._call=function(self,action,args)
 if action=="Quote"then
  local old=normalCall(self,action,args)
  self:SetSnapshot({Coins=99,Inventory=I.Extend({})},true)
  old.Snapshot={Coins=1,Inventory=I.Extend({})};return old
 end
 return normalCall(self,action,args)
end
flow:_quoteCurrent("StudioTest")
check(flow._data.Coins==99,"Late quote snapshot cannot overwrite newer authoritative DataUpdated")
-- Reproduce the client template missing Camera, exercising the actual preview method.
local previousInstance,previousLookAt=extraEnv.Instance,extraEnv.CFrame.lookAt
local previousVectorNew=extraEnv.Vector3.new
extraEnv.Vector3.new=function(x)return vec(x or 0)end
local created=0
extraEnv.Instance={new=function(class)check(class=="Camera","Preview creates only a local camera");created+=1;return {ClassName=class}end}
extraEnv.CFrame.lookAt=function()return {PreviewPose=true}end
local previewModel={PivotTo=function()end,GetExtentsSize=function()return {Magnitude=4}end}
local effects=node("Folder","CrateEffects");effects.Children.Basic={Clone=function()return previewModel end};rs.Children.CrateEffects=effects
local suppliedCamera=nil;local lastViewport
local template={Clone=function()
 lastViewport={WorldModel={}}
 function lastViewport:FindFirstChildWhichIsA(class)return suppliedCamera end
 return lastViewport
end}
local previewHud=node("ScreenGui","ShopHUD");previewHud.Children.CratePreviewTemplate=template
local previewUI=setmetatable({_ui={Hud=previewHud}},{__index=shopClass})
local preview=node("Frame","Preview");preview.Children.PreviewLabel={Visible=true}
previewUI:_cratePreview(preview,{Icon="",Metadata={Model="Basic"}})
check(created==1 and lastViewport.CurrentCamera.Parent==lastViewport and lastViewport.CurrentCamera.FieldOfView==45,"Missing client camera created locally and bound")
check(lastViewport.CurrentCamera.CFrame.PreviewPose and not preview.PreviewLabel.Visible,"Missing-camera preview completes without aborting catalog")
suppliedCamera={FieldOfView=45}
previewUI:_cratePreview(preview,{Icon="",Metadata={Model="Basic"}})
check(created==1 and lastViewport.CurrentCamera==suppliedCamera,"Existing camera reused without duplicates")
extraEnv.Instance=previousInstance;extraEnv.CFrame.lookAt=previousLookAt
extraEnv.Vector3.new=previousVectorNew
local official={500,1000,1750,3000,4500,7000,10000,13500,19000,27500,37500,50000}
for i=1,12 do check(list[i].Price==official[i],"Exact approved price "..list[i].Id)end
-- Extends V1.3 actual engine/Shop regression, then exercises the real stand adapter.
for _,name in ipairs({"OpeningConfig","OpeningTimeline","StandOpeningLedger","StandOpeningService"})do parent[name]=name end
local opening=I.Copy(load("OpeningConfig"));loaded.OpeningConfig=opening
-- Legacy exclusive/cooldown branches remain supported; production defaults tested in V2.4.
opening.Stand.ExclusiveOpening=true;opening.Stand.ReopenCooldown=5
opening.RewardSpin=nil -- Legacy 10.5s fixture; V2.5 tests use the real spin-aware timeline.
local timeline=load("OpeningTimeline")
local Ledger=load("StandOpeningLedger")
local plan=assert(timeline.Build(opening))
check(near(plan.Duration,10.5),"Authored timeline duration 10.5 < timeout25")
for _,stage in ipairs(plan.Stages)do
 local name,p=timeline.At(plan,stage.Start+stage.Duration*.5)
 check(name==stage.Name and near(p,.5),"Deterministic phase "..name)
end
check(timeline.At(plan,plan.Duration)=="Done","Timeline completion boundary")
local invalid=I.Copy(opening);invalid.Mode="ClientChosen";check(not timeline.Build(invalid),"Invalid mode fail closed")
invalid=I.Copy(opening);invalid.Cinematic.ChestRiseDuration=0/0;check(not timeline.Build(invalid),"NaN timing rejected")
invalid=I.Copy(opening);invalid.Stand.MaxSequenceDuration=1;check(not timeline.Build(invalid),"Timeline cannot exceed safety timeout")
local clock=100
local ledger=Ledger.new(opening,plan,function()return clock end)
local lease=assert(ledger:Acquire(-1,"Main","one"))
check(not ledger:Acquire(-2,"Main","two"),"Exclusive stand has one reservation")
check(ledger:Acquire(-1,"Main","one")==lease,"Same operation reuses lease")
check(not ledger:Acquire(-1,"Other","three"),"One active opening per player across stands")
check(ledger:Acquire(-2,"Other","two")~=nil,"Different stands independent")
check(ledger:Commit(lease,"-1:one")and not ledger:Commit(lease,"-1:one"),"Single commit identity")
clock+=plan.Stages[8].Start+.1;ledger:Step();check(lease.State=="Revealing","Server reveal state")
clock=100+plan.Duration;ledger:Step()
check(not ledger.Players[-1]and not ledger.Stands.Main,"Deadline releases exclusive stand")
check(not ledger:Acquire(-1,"Main","again"),"Personal cooldown cannot be bypassed by new operation")
check(ledger:Acquire(-3,"Main","other")~=nil,"Personal cooldown does not block another buyer")
ledger:Release(-3);clock+=4.999;check(not ledger:Acquire(-1,"Main","early"),"Cooldown rejects just before5seconds")
clock+=.001;check(ledger:Acquire(-1,"Main","ready")~=nil,"Cooldown allows exactly5seconds")
ledger:Release(-1);clock+=26;ledger:Step();check(not ledger.Players[-2],"Uncommitted reservation timeout cleans up")
local concurrent=I.Copy(opening);concurrent.Stand.ExclusiveOpening=false
local privateLedger=Ledger.new(concurrent,plan,function()return clock end)
check(privateLedger:Acquire(-1,"Main","a")and privateLedger:Acquire(-2,"Main","b"),"Private mode accepts two same-stand buyers")
check(next(privateLedger.Stands)==nil,"Private mode never claims global stand")
-- Actual stand service and the existing transaction backend.
local standClass=load("StandOpeningService")
local stand=node("Model","Stand");stand.Attrs.StandId="Main";stand.Attrs.Enabled=true
function stand:SetAttribute(k,v)self.Attrs[k]=v end
for _,name in ipairs({"InteractionPart","SpawnPoint","CameraPoint","RewardPoint"})do
 stand.Children[name]=node("Part",name);stand.Children[name].Position=vec(0)
 stand.Children[name].IsA=function(_,class)return class=="BasePart"or class=="Part"end
end
local prompt=node("ProximityPrompt","Prompt");prompt.Triggered=signal();stand.InteractionPart.Children.Prompt=prompt
function stand.InteractionPart:FindFirstChildWhichIsA(class)return class=="ProximityPrompt"and prompt end
function prompt:IsDescendantOf()return true end
local folder=node("Folder","CrateStands");folder.Children.Main=stand
world.FindFirstChild=function(_,name)return if name=="CrateStands"then folder else nil end
for _,p in ipairs({a,b,observer})do p.Character.FindFirstChildOfClass=function()return {Health=100}end end
service:Init(ctx);service._resource=function()return true end
service._stands=standClass.new(service);local stands=service._stands
stands.Remote=node("RemoteEvent","StandPresentation")
stands:SyncStands();check(prompt.Enabled and #prompt.Triggered.Callbacks==1,"Prompt bound once in Stand mode")
stands:SyncStands();check(#prompt.Triggered.Callbacks==1,"No duplicate prompt connections")
local beforeMessages=#objects;prompt.Triggered.Callbacks[1](a)
check(#objects==beforeMessages+1 and objects[#objects].Packet.Kind=="Access","Server prompt opens same Shop through Access event")
check(stands:Validate(a,"Main")==stand,"Valid near lobby buyer")
a.Character.HumanoidRootPart.Position=vec(10.001);check(select(2,stands:Validate(a,"Main"))=="StandTooFar","Distance server-enforced")
a.Character.HumanoidRootPart.Position=vec(0);a.Attrs.MatchId="active"
check(select(2,stands:Validate(a,"Main"))=="LobbyOnly","Combat cannot use stand")
a.Attrs.MatchId=nil;check(not stands:FindStand("fake"),"Unknown stand rejected")
local duplicate=node("Model","Duplicate");duplicate.Attrs.StandId="Main";folder.Children.Duplicate=duplicate
check(not stands:FindStand("Main"),"Duplicate stable StandIds rejected")
folder.Children.Duplicate=nil
pdata[a]=data(5);pdata[a].Inventory.Crates.StudioTest=2
pdata[b]=data(5);pdata[b].Inventory.Crates.StudioTest=1
local quote=service:Quote(a,"StudioTest")
local args={CrateId="StudioTest",StandId="Main",QuoteToken=quote.Token,OperationId="standOpen"}
local messages=#objects
local result=stands:Open(a,args,function()return service:_transact(a,"Open",args)end)
check(result.Ok and pdata[a].Inventory.Crates.StudioTest==1 and pdata[a].Coins==5,"Stand delegates consume/grant once, no extra price")
check(result.Presentation.Mode=="StandCinematic"and stands.Ledger.Players[a.UserId].Committed,"Presentation only after backend commitment")
local openingId=result.Operation.UnitId;local rewardId=result.Operation.RewardId;local packets=0
for i=messages+1,#objects do local event=objects[i]
 if event.Name=="StandPresentation"then
  packets+=1;check(event.Packet.OpeningId==openingId and event.Packet.Operation.RewardId==rewardId,"Spectator/buyer exact same authoritative result")
  check(event.Player~=c,"Combat observer excluded")
 end
end
check(packets==3,"Exclusive buyer plus two lobby observers")
local busy=stands:Open(b,{StandId="Main",OperationId="busy"},function()error("Busy must not reach economy")end)
check(not busy.Ok and busy.Code=="StandBusy","Second buyer blocked before economic operation")
messages=#objects
result=stands:Open(a,args,function()return service:_transact(a,"Open",args)end)
check(result.Ok and result.Replay and #objects==messages and pdata[a].Inventory.Crates.StudioTest==1,"Replay does not consume/reveal again or cancel active sequence")
stands:Release(a.UserId,"Disconnected")
check(not stands.Ledger.Stands.Main and pdata[a].Inventory.Owned.Slaps[rewardId],"Disconnect cleanup releases stand, preserves acquired reward")
local failQuote=service:Quote(b,"StudioTest")
local badArgs={StandId="Main",OperationId="invalidquote",CrateId="StudioTest",QuoteToken="invalid"}
local failed=stands:Open(b,badArgs,function()return service:_transact(b,"Open",badArgs)end)
check(not failed.Ok and not stands.Ledger.Players[b.UserId]and pdata[b].Inventory.Crates.StudioTest==1,"Failed validation releases reservation without consuming")
opening.Stand.ExclusiveOpening=false
stands.Ledger=Ledger.new(opening,plan,os.clock);stands.Active={}
messages=#objects
local qa=service:Quote(a,"StudioTest");args.OperationId="privateA";args.QuoteToken=qa.Token
result=stands:Open(a,args,function()return service:_transact(a,"Open",args)end)
local qb=service:Quote(b,"StudioTest");local bargs={StandId="Main",CrateId="StudioTest",OperationId="privateB",QuoteToken=qb.Token}
local second=stands:Open(b,bargs,function()return service:_transact(b,"Open",bargs)end)
check(result.Ok and second.Ok and result.Operation.UnitId~=second.Operation.UnitId,"Two private buyers receive different identities and rewards independently")
check(#objects==messages+2 and objects[messages+1].Player==a and objects[messages+2].Player==b,"No private presentation packets sent to spectators")
check(not stands.Ledger.Stands.Main,"No global visual lock in private mode")
stands:Release(a.UserId,"Death");check(pdata[a].Inventory.Owned.Slaps[result.Operation.RewardId],"Death cancels only presentation")
opening.Mode="Spin"
local called=0;check(stands:Open(a,{},function()called+=1;return {Ok=true}end).Ok and called==1,"Spin bypasses stand validation and uses original backend")
stands:SyncStands();check(not prompt.Enabled,"Spin disables stand interaction")
opening.Mode="StandCinematic";opening.Stand.ExclusiveOpening=true
-- Actual camera lease; never restores over another owner, new life or EndCinematic.
extraEnv.Enum.CameraType={Custom="Custom",Scriptable="Scriptable"}
local cameraLease=load("CameraLease","CameraLease")
local function camera()
 local c=node("Camera","Camera");c.CameraType="Custom";c.CameraSubject={Parent=true};c.FieldOfView=75;c.CFrame="original"
 function c:SetAttribute(k,v)self.Attrs[k]=v end
 return c
end
local cam=camera();local char={FindFirstChildOfClass=function()return "newHumanoid"end}
local saved=cameraLease.Acquire(cam,"open",char)
check(saved and cameraLease.Owns(saved),"Lobby camera lease acquired locally")
cam.CameraType="Scriptable";cam.FieldOfView=60;cam.CFrame="cinematic"
check(cameraLease.Restore(saved,char,false)and cam.CameraType=="Custom"and cam.FieldOfView==75 and cam.CFrame=="original","Camera type FOV and frame restored")
check(cam.CameraSubject==saved.Subject,"CameraSubject restored for same life")
cam.CameraType="Scriptable";check(not cameraLease.Acquire(cam,"blocked",char),"Existing Scriptable camera priority respected")
cam=camera();saved=cameraLease.Acquire(cam,"old",char);cam:SetAttribute("CrateCameraOwner","new")
check(not cameraLease.Restore(saved,char,false)and cam:GetAttribute("CrateCameraOwner")=="new","Late cleanup cannot alter newer camera owner")
cam=camera();saved=cameraLease.Acquire(cam,"life",char);cam.FieldOfView=61;cam.CFrame="newPose"
check(cameraLease.Restore(saved,{FindFirstChildOfClass=function()return "newHumanoid"end},false)and cam.CameraType=="Custom"and cam.CameraSubject=="newHumanoid"and cam.FieldOfView==61 and cam.CFrame=="newPose","Respawn does not restore old life state")
cam=camera();saved=cameraLease.Acquire(cam,"priority",char);cam.CameraType="Scriptable";cam.FieldOfView=55
check(not cameraLease.Restore(saved,char,true)and cam.CameraType=="Scriptable"and cam.FieldOfView==55,"EndCinematic priority never overwritten")
-- Real client phase/update methods with deterministic geometry; no rendered/visual claims.
local unbound={};services.ContextActionService={UnbindAction=function(_,id)table.insert(unbound,id)end}
parent.Parent.CrateOpening={CameraLease="CameraLease"}
parent.Parent.CrateOpening.CharacterVisibility="CharacterVisibility";load("CharacterVisibility","CharacterVisibility")
for _,name in ipairs({"CinematicConfig","CinematicMotion","CinematicTransition","StandPromptVisibility"})do parent[name]=name;parent.Parent.CrateOpening[name]=name;load(name,name)end
parent.Parent.CrateOpening.VisualProfile="VisualProfile";parent.Parent.CrateOpening.RewardOverlayPresenter="OverlayPresenter"
parent.VisualProfile="VisualProfile"
load("VisualProfile","VisualProfile");load("OverlayPresenter","OverlayPresenter")
for _,name in ipairs({"RewardRevealConfig","RewardRevealProfile","RewardVFX","RewardSpinMotion","RewardSpin3D","RewardGalleryLayout","RewardGallery"})do parent[name]=name;parent.Parent.CrateOpening[name]=name;load(name,name)end
players.LocalPlayer=a
local present=load("StandPresentation","StandController")
present:Init({GetController=function()return nil end})
present._hud={Enabled=true,Transition={},Flash={}}
local frameMeta={}
local function frame(x)local f={Position=vec(x or 0),UpVector=vec(1)};return setmetatable(f,frameMeta)end
function frameMeta.__mul(a,b)return frame(a.Position.X+b.Position.X)end
local oldFrame=extraEnv.CFrame
extraEnv.CFrame={new=function(x,y)return frame((x or 0)+(y or 0))end,Angles=function()return frame(0)end,lookAt=function(position)return frame(position.X)end}
local poseStand={Parent=true,SpawnPoint={CFrame=frame(100)},RewardPoint={CFrame=frame(200),Position=vec(200)}}
local emitted=0;local fx={EnergyBeam={}}
local effects={FXAnchor=fx,FindFirstChild=function()return nil end,FindFirstChildWhichIsA=function()return nil end,
 GetDescendants=function()return {{Name="FlashSparks",IsA=function(_,c)return c=="ParticleEmitter"end,Emit=function(_,count)emitted+=count end,GetAttribute=function(_,key)return if key=="BurstCount"then 24 else nil end}}end}
local chest={PivotTo=function(self,pose)self.Pose=pose end,ScaleTo=function(self,scale)self.Scale=scale end}
local rewardModel={PivotTo=function(self,pose)self.Pose=pose end,GetDescendants=function()return {}end}
local run={Id="visual",Stand=poseStand,Character=a.Character,Packet={StartedAt=0},Private=false,Chest=chest,BaseScale=1,Scene={RewardAnchor={}},Reward=rewardModel,Effects=effects,Label={},Objects={},Tweens={}}
for _,stage in ipairs(plan.Stages)do
 if stage.Name=="Outro"then continue end
 present:_update(run,stage.Start+stage.Duration*.5)
 check(run.Stage==stage.Name,"Client deterministic phase executes "..stage.Name)
 if stage.Name=="Appear"then check(chest.Scale>.15 and chest.Scale<1,"Chest appears from small authored model")
 elseif stage.Name=="Rise"then check(chest.Pose.Position.X>101 and chest.Scale==.8,"Chest rises relative to SpawnPoint")
 elseif stage.Name=="Growth"then check(chest.Scale>1 and fx.EnergyBeam.Enabled,"Chest grows with bounded energy beam")
 elseif stage.Name=="Shake"then check(chest.Scale==1.25,"Shake maintains stable base scale")
 elseif stage.Name=="Flash"then check(emitted>15,"Flash emits bounded visual particles without Explosion")
 elseif stage.Name=="Reward"then check(rewardModel.Parent==run.Scene and run.Label.Enabled and not chest.Parent,"Reward replaces chest at reveal")end
end
check(run.Scene.RewardAnchor.CFrame.Position.X==200,"Reward label follows authored RewardPoint")
local destroyed=0;present._runs.visual=run
run.Objects={{Destroy=function()destroyed+=1 end}}
present:_stop("visual","Timeout");present:_stop("visual","LateCancel")
check(destroyed==1 and not present._runs.visual,"Idempotent visual cleanup and late cancel")
present:Play({Mode="StandCinematic",OpeningId="late",StartedAt=-100,Operation={RewardId=rewardId,CrateId="StudioTest"}})
check(not present._runs.late,"Late opening packet ignored")
extraEnv.CFrame=oldFrame
-- Shared Shop opening route must not fall back to Spin for a stand result.
flow._crateId="StudioTest";flow._quoting=false;flow._busy=false;flow._pendingAction=nil
flow:SetSnapshot({Coins=0,Inventory=I.Extend({Crates={StudioTest=1}})})
flow._quoteCache.StudioTest=q;flow._quote=q
local spins=0;flow._spin=function()spins+=1 end
flow._call=function()return {Ok=true,Operation={UnitId="stand-client"},Presentation={Mode="StandCinematic"}}end
flow:_mutate("Open")
check(spins==0,"Stand result never invokes classic spin fallback")
flow._quoteCache.StudioTest=q;flow._quote=q
flow._call=function()return {Ok=true,Operation={UnitId="spin-client"}}end
flow:_mutate("Open")
check(spins==1,"Return to Spin preserves classic fallback")
local INPUT_ROWS={
{Id="Basic",Values={60,24,9,4,1.60,0.70,0.35,0.17,0.10,0.04,0.03,0.01}},
{Id="Common",Values={55.89,25.18,11.01,4.88,1.75,0.67,0.31,0.15,0.09,0.04,0.02,0.01}},
{Id="Uncommon",Values={49.02,23.81,13.72,8.21,3.48,1.11,0.36,0.14,0.08,0.04,0.02,0.01}},
{Id="Rare",Values={41.61,19.49,13.34,12.21,8.30,3.64,1.04,0.23,0.08,0.03,0.02,0.01}},
{Id="Gold",Values={36.13,15.40,9.35,11.39,12.78,9.41,4.16,1.10,0.21,0.04,0.02,0.01}},
{Id="Arcoiris",Values={32.41,13.13,6.01,6.70,11.20,13.97,10.52,4.63,1.20,0.19,0.03,0.01}},
{Id="Emote",Values={29.39,11.78,4.60,3.24,5.81,11.80,15.24,11.54,5.08,1.30,0.20,0.02}},
{Id="Wings",Values={26.39,10.56,3.98,1.97,2.11,5.83,12.74,16.63,12.63,5.54,1.41,0.21}},
{Id="Epic",Values={22.80,9.12,3.42,1.54,0.84,1.82,6.27,14.05,18.43,14.00,6.15,1.56}},
{Id="Legendary",Values={18.60,7.44,2.79,1.24,0.52,0.48,1.89,7.06,15.99,21.01,15.97,7.01}},
{Id="Blood",Values={15.00,6.00,2.25,1.00,0.40,0.20,0.40,2.19,8.50,19.32,25.43,19.31}},
{Id="Galaxy",Values={10.80,4.32,1.62,0.72,0.29,0.13,0.10,0.49,3.18,12.49,28.44,37.42}},
}
-- INPUT_ROWS is generated independently from the user's CSV by the spec composer.
local Matrix=loaded.InitialOdds;local Presentation=loaded.OddsPresentation
local mathCat={Variations={ById={}},Slaps={ById={Classic={DisplayName="Classic"}}},Rewards={}}
for _,vid in ipairs(Matrix.VariationOrder)do
 local variation=I.Copy(C.Variations.ById[vid]);variation.LimitedStock=false
 mathCat.Variations.ById[vid]=variation
 mathCat.Rewards["Classic:"..vid]={RewardId="Classic:"..vid,SlapId="Classic",VariationId=vid,DisplayName="Classic ["..vid.."]",LimitedStock=false}
end
local empty={Owned={Slaps={}}};local rng=8675309
local function randomUnit()rng=(1664525*rng+1013904223)%4294967296;return rng/4294967296 end
local allStats={};local draws=200000
for _,input in ipairs(INPUT_ROWS)do
 local crate=C.Crates.ById[input.Id];local sum=0
 check(crate.DuplicatePolicy=="UniquePerPlayer"and not crate.OddsApproved and not crate.Enabled and crate.PriceApproved,"Approvals and duplicate policy preserved "..input.Id)
 for i,vid in ipairs(Matrix.VariationOrder)do
  check(crate.Weights[vid]==input.Values[i]and crate.Weights[vid]>0,"Exact CSV weight "..input.Id..":"..vid)
  sum+=crate.Weights[vid]
 end
 check(math.abs(sum-100)<1e-10,"Original row sums100 "..input.Id)
 local rows=assert(O.Resolve(crate,mathCat,empty,S.new()))
 check(#rows==12,"Single Slap has12 eligible variations "..input.Id)
 local total=0;local seen={};local counts={}
 for _,row in ipairs(rows)do
  check(math.abs(row.Percent-crate.Weights[row.Reward.VariationId])<1e-10,"Reported probability matches original full catalog "..row.Reward.RewardId)
  local middle=total+row.Probability*.5
  check(O.Roll(rows,middle).RewardId==row.Reward.RewardId,"Tiny bucket selectable without rounding "..input.Id..":"..row.Reward.VariationId)
  total+=row.Probability;seen[row.Reward.RewardId]=row.Probability;counts[row.Reward.RewardId]=0
 end
 check(math.abs(total-1)<1e-12,"Resolved row normalized "..input.Id)
 for i=1,draws do local id=O.Roll(rows,randomUnit()).RewardId;counts[id]+=1 end
 for _,row in ipairs(rows)do
  local id=row.Reward.RewardId;local p=row.Probability;local expected=draws*p;local observed=counts[id]
  check(math.abs(observed-expected)<=7*math.sqrt(draws*p*(1-p))+2,"Seeded frequency within7sigma "..input.Id..":"..id)
  print(string.format("STATS|%s|%s|%d|%.12g|%d|%.12g",input.Id,id,draws,p,observed,observed/draws))
 end
end
check(C.Crates.ById.StudioTest.PriceCoins==1 and C.Crates.ById.StudioTest.Weights.Basic==3 and C.Crates.ById.StudioTest.Weights.Common==1,"StudioTest unchanged")
local basic=C.Crates.ById.Basic
local multi=I.Copy(mathCat);multi.Rewards["Future:Galaxy"]={RewardId="Future:Galaxy",SlapId="Future",VariationId="Galaxy",LimitedStock=false}
local rows=assert(O.Resolve(basic,multi,empty,S.new()));local galaxy=0
for _,row in ipairs(rows)do if row.Reward.VariationId=="Galaxy"then galaxy+=row.Percent;check(math.abs(row.Percent-.005)<1e-12,"Galaxy weight split across eligible Slaps")end end
check(math.abs(galaxy-.01)<1e-12,"Variation total preserved across multiple Slaps")
local owned={Owned={Slaps={["Classic:Galaxy"]=true}}}
rows=assert(O.Resolve(basic,multi,owned,S.new()))
for _,row in ipairs(rows)do if row.Reward.VariationId=="Galaxy"then check(row.Reward.SlapId=="Future"and math.abs(row.Percent-.01)<1e-12,"Owned reward excluded before candidate weight split")end end
local stock=S.new();local originalView=stock.View
function stock:View(reward,variation)
 if reward.VariationId=="Galaxy"then return {SoldOut=true,UnlimitedStock=false,RemainingStock=0}end
 return originalView(self,reward,variation)
end
local _,_,excluded
rows,_,excluded=O.Resolve(basic,mathCat,empty,stock)
check(#rows==11 and #excluded==1 and excluded[1].Reason=="SoldOut","Sold-out reward excluded and disclosed")
local normalized=0
for _,row in ipairs(rows)do normalized+=row.Percent;check(row.Reward.VariationId~="Galaxy"and math.abs(row.Percent-basic.Weights[row.Reward.VariationId]/99.99*100)<1e-10,"Sold-out distribution renormalized")end
check(math.abs(normalized-100)<1e-10,"Filtered sum100")
rows=assert(O.Resolve(basic,mathCat,empty,S.new(),function(reward)return reward.VariationId~="Galaxy"end))
check(#rows==11,"Variation with no eligible Slap is removed")
local allOwned={Owned={Slaps={}}};for id in pairs(mathCat.Rewards)do allOwned.Owned.Slaps[id]=true end
local none,reason=O.Resolve(basic,mathCat,allOwned,S.new())
check(not none and reason=="NoEligibleResults","No eligible results block resolution")
for _,bad in ipairs({-1,math.huge,0/0})do
 local invalid=I.Copy(basic);invalid.Weights.Galaxy=bad
 check(select(2,O.Resolve(invalid,mathCat,empty,S.new()))=="InvalidWeights","Invalid numeric weight rejected")
end
local invalid=I.Copy(basic);invalid.Weights.Unknown=1
check(select(2,O.Resolve(invalid,mathCat,empty,S.new()))=="InvalidWeights","Unknown variation rejected")
local approved=I.Copy(basic);approved.OddsApproved=true;approved.Enabled=true -- disposable mathematical fixture only
local profile=data(1000);profile.Inventory.Owned.Slaps={};profile.Inventory.Crates.Basic=1
local beforeCount=profile.Inventory.Crates.Basic
local noGrant,err=E.Stage(profile,approved,"Open","none",-99,mathCat,S.new(),.5,function()return false end)
check(not noGrant and err=="NoEligibleResults"and profile.Inventory.Crates.Basic==beforeCount,"Empty distribution never consumes crate")
local full=assert(O.Resolve(approved,mathCat,I.Extend(profile.Inventory),S.new()))
local unit=0;for _,row in ipairs(full)do
 local nextData,why,op=E.Stage(profile,approved,"Open","bucket-"..row.Reward.VariationId,-99,mathCat,S.new(),unit+row.Probability*.5)
 check(nextData and op.RewardId==row.Reward.RewardId,"Stage uses exact quoted distribution bucket "..row.Reward.VariationId)
 unit+=row.Probability
end
-- Actual review Quote exposes computed values but never enables payment or bypasses PolicyService.
service:Init(ctx);service._resource=function()return true end
pdata[a]=data(100000);pdata[a].Inventory.Owned.Slaps={}
policy.ArePaidRandomItemsRestricted=false
for _,id in ipairs(Matrix.VariationOrder)do
 local quote=service:Quote(a,id)
 check(quote.Ok and quote.ReviewOnly and not quote.PurchaseAllowed and #quote.Outcomes==11,"Read-only Studio review quote excludes owned default "..id)
 local sum=0;for _,row in ipairs(quote.Outcomes)do
  sum+=row.Percent;check(row.SlapName and row.VariationName and row.Color and row.Percent>0,"Authoritative presentation metadata")
  print(string.format("QUOTE|%s|%s|%.12g",id,row.RewardId,row.Percent))
 end
 check(math.abs(sum-100)<1e-10,"Quote effective sum100")
 local rejected=service:_transact(a,"Purchase",{CrateId=id,OperationId="blocked-"..id,QuoteToken=quote.Token,OddsApproved=true})
 check(not rejected.Ok and rejected.Code=="CommercialApprovalPending"and pdata[a].Coins==100000,"Review token cannot authorize commerce "..id)
end
policy.ArePaidRandomItemsRestricted=true
check(service:Quote(a,"Basic").Code=="PaidRandomItemsRestricted","Review does not bypass restricted policy")
policy.ArePaidRandomItemsRestricted=false;policyFailure=true
check(not service:Quote(a,"Basic").Ok,"Policy failure blocks review and purchase safely")
policyFailure=false
local quote=service:Quote(a,"Basic");local formatted=Presentation.Rows(quote)
check(#formatted==12 and formatted[1].RewardId=="Classic:Basic"and formatted[12].RewardId=="Classic:Galaxy"and formatted[1].Excluded,"Odds UI sorts by variation then reward, showing owned exclusion")
check(formatted[12].Text:find("0.025 %%")~=nil,"Small effective probability remains visible after owned-default renormalization")
check(Presentation.Rows({Outcomes={{RewardId="Classic:Galaxy",SlapId="Classic",VariationId="Galaxy",Percent=.01,Stock={UnlimitedStock=true}}}})[1].Text:find("0.01 %%")~=nil,"Original 0.01percent is never rounded away")
local list=node("ScrollingFrame","OddsList");local labels={};local template=node("TextLabel","RowTemplate")
function template:Clone()local l=node("TextLabel","Row");table.insert(labels,l);return l end
list.Children.RowTemplate=template;panel.Children.OddsList=list
extraEnv.Vector2={zero={}}
extraEnv.Enum.AutomaticSize={Y="Y"}
flow:_renderOdds(quote)
check(list.Visible and not panel.Outcomes.Visible and #labels==14,"Actual controller uses header + batch notice + 12 rows")
check(labels[1].Text:find("REVISIÓN",1,true)and labels[14].Text:find("0.025 %%")~=nil,"Review banner and tiny effective odds rendered without invented estimates")
panel.Children.OddsList=nil
local Profiles=loaded.VisualProfile
local Presenter=loaded.OverlayPresenter
for _,id in ipairs(C.Variations.Order)do
 local variation=C.Variations.ById[id];local profile=Profiles.For(variation)
 check(profile.Color==variation.Color and profile.Tier>=1 and profile.Tier<=6,"Registered variation color and bounded profile "..id)
 local emitter={Name="FlashSparks",GetAttribute=function(_,key)return if key=="BurstCount"then 24 else nil end}
 check(Profiles.Count(emitter,"Flash",profile)<=32 and Profiles.Count(emitter,"Rise",profile)==0,"Stage-specific bounded flash "..id)
 local streak={Name="RiseStreaks",GetAttribute=function(_,key)return if key=="BurstCount"then 6 else nil end}
 check(Profiles.Count(streak,"Rise",profile)>0 and Profiles.Count(streak,"Flash",profile)==0,"Authored RiseStreaks reused "..id)
end
local galaxy=Profiles.For(C.Variations.ById.Galaxy);local basic=Profiles.For(C.Variations.ById.Basic)
check(galaxy.Special and not basic.Special and galaxy.Light>basic.Light,"Rare treatment differs without economics changes")
local emitted=0;local list={}
for i=1,20 do table.insert(list,{Name="FlashSparks",IsA=function(_,kind)return kind=="ParticleEmitter"end,GetAttribute=function(_,key)return if key=="BurstCount"then 200 else nil end,Emit=function(_,n)emitted+=n end})end
Profiles.Emit({GetDescendants=function()return list end},"Flash",galaxy)
check(emitted==64,"Whole stage has a64particle cap")
for i=2,#plan.Stages do local at=plan.Stages[i].Start
 check(math.abs(Profiles.Rotation(plan,at-1e-7)-Profiles.Rotation(plan,at+1e-7))<1e-5,"Rotation continuous across stage "..plan.Stages[i].Name)
end
check(Profiles.Pose("Rise",0)==.5 and Profiles.Pose("Rise",1)==2.5,"Rise authored endpoints retained")
-- Actual overlay helper, engine tween targets applied immediately by the isolated fixture.
local oldUDim=extraEnv.UDim2
local udmeta={__add=function(x,y)return setmetatable({X=x.X+y.X,Y=x.Y+y.Y},getmetatable(x))end}
local function ud(x,y)return setmetatable({X=x,Y=y},udmeta)end
extraEnv.UDim2={fromScale=ud}
local function ui(class,name)
 local obj=node(class,name);obj.BackgroundTransparency=1;obj.TextTransparency=0;obj.Transparency=.2
 function obj:IsA(kind)return kind==class or kind=="GuiObject"and(class=="Frame"or class=="TextLabel")end
 return obj
end
local root=ui("Frame","RewardOverlay");root.Position=ud(.5,.75);root.BackgroundTransparency=.15;root.Visible=false
for _,name in ipairs({"Title","SlapName","VariationName"})do root.Children[name]=ui("TextLabel",name)end
root.Children.AccentStroke=ui("UIStroke","AccentStroke");root.Children.RevealScale={Scale=1}
function root:GetDescendants()return {self.Title,self.SlapName,self.VariationName,self.AccentStroke}end
local overlay=assert(Presenter.new(root))
local run={Private=true,Id="overlay-one",Tweens={}}
overlay:Show(run,C.Slaps.ById.Classic,C.Variations.ById.Galaxy)
check(root.Visible and root.SlapName.Text==C.Slaps.ById.Classic.DisplayName and root.VariationName.Text==C.Variations.ById.Galaxy.DisplayName,"Overlay uses actual registered reward names")
check(root.VariationName.TextColor3==C.Variations.ById.Galaxy.Color and root.AccentStroke.Color==C.Variations.ById.Galaxy.Color,"Overlay color comes from variation")
local tweens=#run.Tweens;overlay:Show(run,C.Slaps.ById.Classic,C.Variations.ById.Galaxy)
check(#run.Tweens==tweens,"Repeated reward phase does not duplicate overlay tweens")
overlay:Exit(run);check(root.SlapName.TextTransparency==1,"Outro fades overlay")
overlay:Reset("late-other");check(root.Visible,"Late cleanup cannot hide another opening")
overlay:Reset(run.Id);check(not root.Visible and root.Position==overlay.Position and root.SlapName.TextTransparency==0,"Cancel resets visibility authored geometry and alpha")
overlay:Show({Private=false,Id="spectator",Tweens={}},C.Slaps.ById.Classic,C.Variations.ById.Galaxy)
check(not root.Visible,"Spectator never receives private reward overlay")
extraEnv.UDim2=oldUDim
-- Current defaults, actual service/engine/stock. All profiles and Players are offline fixtures.
local actual=load("OpeningConfig")
check(actual.Stand.ExclusiveOpening==false and actual.Stand.ReopenCooldown==0,"Private default and zero cooldown")
local actualPlan=assert(timeline.Build(actual,10));check(actualPlan.Duration==12.5 and actualPlan.Duration<actual.Stand.MaxSequenceDuration,"Batch duration within safety cap")
local rules=loaded.BatchOpening
for _,q in ipairs({1,5,10})do check(rules.Quantity(q)==q,"Allowed quantity "..q)end
for _,q in ipairs({0,-1,2,4,7,11,math.huge,0/0,"5",false,{}})do check(not rules.Quantity(q),"Invalid quantity rejected")end
local ledger=Ledger.new(actual,actualPlan,function()return 500 end)
local la=assert(ledger:Acquire(-1,"Main","a",actualPlan));local lb=assert(ledger:Acquire(-2,"Main","b",actualPlan))
check(la~=lb and next(ledger.Stands)==nil,"Two buyers no global stand lease")
check(not ledger:Acquire(-1,"Main","incompatible"),"Same buyer cannot overlap operations")
ledger:Commit(la,"-1:a");ledger:Release(-1);check(ledger:Acquire(-1,"Main","immediate")~=nil,"Immediate reopen after completion")
service:Init(ctx);service._resource=function()return true end
service._stands=load("StandOpeningService").new(service)
service._stands.Remote=node("RemoteEvent","StandPresentation")
local calls=0;service._rng={NextNumber=function()calls+=1;return if calls%2==0 then .99 else .1 end}
pdata[a]=data(100);pdata[b]=data(100)
pdata[a].Inventory.Crates.StudioTest=40;pdata[b].Inventory.Crates.StudioTest=30
local function openBatch(player,quantity,id,token)
 local quote=if token then {Token=token}else service:Quote(player,"StudioTest")
 local args={CrateId="StudioTest",Quantity=quantity,OperationId=id,StandId="Main",QuoteToken=quote.Token}
 return service._stands:Open(player,args,function()return service:_transact(player,"Open",args)end),args
end
local messages=#objects
local first,args=openBatch(a,10,"tenA")
local second=openBatch(b,10,"tenB")
check(first.Ok and second.Ok,"Two players x10 simultaneously active")
check(pdata[a].Inventory.Crates.StudioTest==30 and pdata[b].Inventory.Crates.StudioTest==20,"Exact10 consumption each")
check(#first.Operation.Rewards==10 and #second.Operation.Rewards==10,"Exact10 rewards each")
check(first.Operation.BatchId~=second.Operation.BatchId and calls==20,"Independent opening identity and independent draws")
check(first.Operation.Rewards[1].RewardId~=first.Operation.Rewards[2].RewardId,"Batch does not copy a single random result")
for _,unit in ipairs(first.Operation.Rewards)do
 check(unit.EffectivePercent==(if unit.VariationId=="Basic"then 75 else 25),"Receipt carries exact draw-time effective percent")
end
check(#first.Operation.PreviewRewardIds==2,"Receipt eligible previews snapshot")
check(pdata[a].Coins==100 and pdata[b].Coins==100,"Open never buys or charges Coins")
check(next(service._stands.Ledger.Stands)==nil,"No global busy flag")
local packets=0
for i=messages+1,#objects do local event=objects[i]
 if event.Name=="StandPresentation"and event.Packet.Kind=="Opening"then
  packets+=1;check(event.Player.UserId==event.Packet.BuyerUserId and not event.Packet.Exclusive,"Private packet only to buyer")
  check(#event.Packet.Operation.Rewards==10 and event.Packet.Duration==12.5,"Exact batch packet and authoritative duration")
 end
end
check(packets==2,"No observer opening packets")
local replay=openBatch(a,10,"tenA","expired-token")
check(replay.Ok and replay.Replay and pdata[a].Inventory.Crates.StudioTest==30 and calls==20,"Retry is exact receipt, no reroll/consume")
local conflict=openBatch(a,5,"newWhileActive")
check(not conflict.Ok and conflict.Code=="OpeningInProgress","Different request blocked during cinematic")
service._stands:Release(a.UserId,"Completed");service._stands:Release(b.UserId,"Disconnected")
local five=openBatch(a,5,"fiveA");check(five.Ok and #five.Operation.Rewards==5 and pdata[a].Inventory.Crates.StudioTest==25,"Exact5 immediately after prior batch")
service._stands:Release(a.UserId,"Completed")
local one=openBatch(a,1,"oneA");check(one.Ok and not one.Operation.Rewards and pdata[a].Inventory.Crates.StudioTest==24,"x1 retains original operation contract")
check(one.Operation.EffectivePercent==(if one.Operation.VariationId=="Basic"then 75 else 25)and #one.Operation.PreviewRewardIds==2,"x1 metadata survives staging and authoritative commit")
service._stands:Release(a.UserId,"Completed")
local before=pdata[a]
local poor=I.Copy(before);poor.Inventory.Crates.StudioTest=4;pdata[a]=poor
local insufficient=openBatch(a,5,"short")
check(not insufficient.Ok and insufficient.Code=="InsufficientCrates"and pdata[a]==poor and poor.Inventory.Crates.StudioTest==4,"Insufficient inventory consumes nothing")
pdata[a]=before
local changed=openBatch(a,5,"tenA","ignored")
check(not changed.Ok and changed.Code=="OperationConflict","Same ID cannot change quantity")
-- Profile failure releases every pre-grant reservation and leaves original profile untouched.
ps.Fail=true;local pre=pdata[a];local failed=openBatch(a,5,"profileFail");ps.Fail=false
check(not failed.Ok and pdata[a]==pre,"Profile failure leaves all boxes and rewards untouched")
for index=1,5 do check(service._stock.State.Operations["-1:profileFail:"..index].State=="Released","All failed profile reservations released")end
-- A stock confirmation failure after the single profile commit retains ALL grants and reservations.
local realCommit=service._stock.Commit;local once=true
service._stock.Commit=function(self,id)if once then once=false;return false,"Injected"end;return realCommit(self,id)end
local oldCount=pdata[a].Inventory.Crates.StudioTest;local previousCalls=calls
local pending=openBatch(a,5,"recover")
check(not pending.Ok and pending.Code=="StockCommitPending","Ambiguous stock confirmation is recoverable, not a new transaction")
check(pdata[a].Inventory.Crates.StudioTest==oldCount-5 and #pending.Operation.Rewards==5,"All5 grants committed together before stock retry")
service._stock.Commit=realCommit
local recovered=openBatch(a,5,"recover","old-token")
check(recovered.Ok and recovered.Replay and recovered.Operation.State=="Completed","Retry completes original batch")
check(calls==previousCalls+5 and pdata[a].Inventory.Crates.StudioTest==oldCount-5,"Recovery never rerolls or consumes twice")
service._stands:Release(a.UserId,"Completed")
local sent=#objects;local again=openBatch(a,5,"recover","irrelevant")
check(again.Ok and again.Replay and #objects==sent,"Recovered receipt cannot replay presentation again")
-- Commit throws after writing profile: treat confirmed identity as committed, never release awarded stock.
local originalCommit=ps.CommitCrateState
ps.CommitCrateState=function(self,p,expected,nextData)local ok,why=originalCommit(self,p,expected,nextData);if ok then error("Injected after profile write")end;return ok,why end
local afterWrite=openBatch(a,5,"afterWrite");ps.CommitCrateState=originalCommit
check(afterWrite.Ok and #afterWrite.Operation.Rewards==5,"Ambiguous profile success recovered by authoritative identity")
for _,unit in ipairs(afterWrite.Operation.Rewards)do check(service._stock.State.Operations[unit.UnitId].State=="Issued","Awarded stock never released after profile success")end
service._stands:Release(a.UserId,"Completed")
for _,q in ipairs({0,2,7,"10",math.huge})do
 service._rate[a]=nil
 local invalid=service:Request(a,"Open",{CrateId="StudioTest",Quantity=q,OperationId="invalidQuantity",StandId="Main"})
 check(not invalid.Ok and invalid.Code=="InvalidQuantity","Actual remote rejects forged quantity")
end
local rate=service:Request(a,"OpeningContext",{})
check(not rate.Ok and rate.Code=="RateLimited","Anti-spam rate protection survives cooldown removal")
local cancelResult=openBatch(a,1,"cancelOwn")
local current=pdata[a];local cancel=service:Request(a,"CancelOpening",{OpeningId=cancelResult.Operation.UnitId})
check(cancel.Ok and not service._stands.Active[a.UserId]and pdata[a]==current,"Cancel releases own visual lease without undoing grant")
local following=openBatch(a,1,"afterCancel")
service._cancelRate[a]=nil
local late=service:Request(a,"CancelOpening",{OpeningId=cancelResult.Operation.UnitId})
check(not late.Ok and service._stands.Active[a.UserId].Packet.OpeningId==following.Operation.UnitId,"Late cancel cannot close newer opening")
service._cancelRate[b]=nil
service:Request(b,"CancelOpening",{OpeningId=following.Operation.UnitId})
check(service._stands.Active[a.UserId]~=nil,"Other player cannot cancel buyer opening")
service._stands:Release(a.UserId,"Completed")
-- Unique policy recomputes eligibility within one batch, without altering real definitions.
local unique=I.Copy(crate);unique.DuplicatePolicy="UniquePerPlayer";unique.Weights={}
for _,id in ipairs(C.Variations.Order)do unique.Weights[id]=1 end
local ud=data(10);ud.Inventory.Crates.StudioTest=16;local us=S.new()
local granted,why,operation=E.Stage(ud,unique,"Open","unique10",-50,C,us,function()return 0 end,nil,10)
check(granted and #operation.Rewards==10 and ud.Inventory.Crates.StudioTest==16,"Unique10 staged without mutating original")
local seen={};for _,unit in ipairs(operation.Rewards)do check(not seen[unit.RewardId],"No duplicate within unique batch");seen[unit.RewardId]=true end
for i,unit in ipairs(operation.Rewards)do check(math.abs(unit.EffectivePercent-100/(12-i))<1e-7,"Batch metadata captures conditional odds before each unique draw")end
E.Reconcile(granted,us)
local impossible,reason=E.Stage(granted,unique,"Open","notEnoughEligible",-50,C,us,function()return 0 end,nil,5)
check(not impossible and reason=="NoEligibleResults"and granted.Inventory.Crates.StudioTest==6,"Whole batch rejected when only one result remains")
for id,allocation in pairs(us.State.Operations)do if id:find("notEnoughEligible",1,true)then check(allocation.State=="Released","Failed unique batch releases staged last prize")end end
local last=assert(E.Stage(granted,unique,"Open","last",-50,C,us,0,nil,1))
check(not E.Stage(last,unique,"Open","empty",-50,C,us,0,nil,1),"Last eligible prize cannot be duplicated")
-- Exhausted limited stock halfway through a batch: zero profile mutation and no negative stock.
local limited=I.Copy(C);local reward=limited.Rewards["Classic:Common"]
reward.LimitedStock=true;reward.TotalSupply=3;reward.EditionId="batch-offline-only"
local limitedCrate=I.Copy(crate);limitedCrate.Weights={Common=1}
local ld=data(10);ld.Inventory.Crates.StudioTest=10;local ls=S.new()
local aborted,code=E.Stage(ld,limitedCrate,"Open","limited",-60,limited,ls,function()return .5 end,nil,5)
check(not aborted and code=="NoEligibleResults"and ld.Inventory.Crates.StudioTest==10,"Limited3 cannot partially satisfy x5")
local view=assert(ls:View(reward,limited.Variations.ById.Common))
check(view.RemainingStock==3 and view.IssuedCount==0,"All limited reservations rolled back")
reward.TotalSupply=15;local sharedStock={Buckets={},Operations={}};local sa,sb=S.new(sharedStock),S.new(sharedStock)
local da,db=data(10),data(10);da.Inventory.Crates.StudioTest=10;db.Inventory.Crates.StudioTest=10
local wa=assert(E.Stage(da,limitedCrate,"Open","competingA",-71,limited,sa,function()return .5 end,nil,10))
local wb=E.Stage(db,limitedCrate,"Open","competingB10",-72,limited,sb,function()return .5 end,nil,10)
check(not wb and db.Inventory.Crates.StudioTest==10,"Competing x10 sees reservations and cannot oversell remaining5")
E.Reconcile(wa,sa)
wb=assert(E.Stage(db,limitedCrate,"Open","competingB5",-72,limited,sb,function()return .5 end,nil,5));E.Reconcile(wb,sb)
check(sa:View(reward,limited.Variations.ById.Common).RemainingStock==0 and wb.Inventory.Crates.StudioTest==5,"Shared final stock issued exactly15 without negatives")
-- Inject a failure after Reserve allocated a unit; rollback still finds that identity.
local fs=S.new();local reserve=fs.Reserve;local attempts=0
fs.Reserve=function(self,...)attempts+=1;local ok,why=reserve(self,...);if attempts==3 then error("Injected reserve fault")end;return ok,why end
local broken=E.Stage(ld,crate,"Open","reserveCrash",-60,C,fs,function()return .5 end,nil,5)
check(not broken and ld.Inventory.Crates.StudioTest==10,"Staging error before consume is safe")
for _,allocation in pairs(fs.State.Operations)do check(allocation.State=="Released","Thrown reserve rolls back allocated units")end
-- Actual quantity selection state; request carries immutable quantity and operation id on retries.
flow._context={GetController=function()return nil end};flow._busy=false;flow._quoting=false;flow._pendingAction=nil
flow._data={Coins=100,Inventory={Crates={StudioTest=5}}};flow._openQuantity=10
local product=service:GetCatalog()[13]
for _,p in ipairs(service:GetCatalog())do if p.Id=="StudioTest"then product=p end end
flow._quoteCache.StudioTest=service:Quote(a,"StudioTest")
check(not flow:GetView(product).OpenEnabled,"Client cannot open10 with only5")
flow._openQuantity=5;check(flow:GetView(product).OpenEnabled,"Client permits exact owned5")
-- Pure layout/frustum bounds at portrait, landscape and ultrawide.
local layout=loaded.RewardGalleryLayout;local gc=loaded.CinematicConfig.Gallery
for _,q in ipairs({5,10})do for _,aspect in ipairs({.45,.5625,1,16/9,2.4})do
 local result=layout.Build(q,aspect,35,gc);check(#result.Positions==q,"Exact gallery slots")
 local width=result.Distance*math.tan(math.rad(35)/2)*aspect;local height=result.Distance*math.tan(math.rad(35)/2)
 for _,point in ipairs(result.Positions)do check(math.abs(point.X)+gc.Spacing/2<=width and math.abs(point.Y)+gc.RowSpacing/2<=height,"Reward fits conservative frustum")end
end end
check(C.Crates.ById.StudioTest.PriceCoins==1 and not E.Approved(C.Crates.ById.Basic),"Studio price and commercial gates preserved")
print("PASS CrateBatchV24: "..assertions.." combined isolated assertions; real multiplayer/visual NOT RUN")
