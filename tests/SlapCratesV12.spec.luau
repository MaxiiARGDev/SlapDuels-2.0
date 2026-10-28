--!nonstrict
-- Executes actual modules with deterministic clocks/policy/store. Never starts Studio.
local assertions=0
local function check(v,message)assertions+=1;assert(v,message)end
local function near(a,b)return math.abs(a-b)<1e-9 end
local loaded={}
local names={"Registry","VariationDefinitions","SlapDefinitions","CrateDefinitions","StockDefinitions","Catalog","Inventory","Odds","Appearance","CrateShopView","StockLedger","InMemoryStock","ProductionStockAdapter","CrateEngine","AnnouncementAdapter"}
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
check(#C.Crates.Order==13,"12 pending crates plus isolated fixture")
check(C.ProductionCommerceEnabled==false,"Production gate closed")
for _,id in ipairs(C.Crates.Order)do if id~="StudioTest" then
 local c=C.Crates.ById[id];check(not E.Approved(c) and c.PriceCoins==nil and next(c.Weights)==nil,"No invented commerce "..id)
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
local quote=service:Quote(a,"Basic");check(not quote.Ok and quote.Code=="CommercialApprovalPending","Pending commerce blocked on server")
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
check(#providers[1]:GetProducts()==13 and #providers[2]:GetProducts()==12,"Providers derive catalogues without duplicated lists")
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
check(public[1].Metadata.PricePending==true and public[1].Metadata.PurchaseEnabled==false,"Public pending metadata prevents misleading zero-price purchase UI")
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
 check(state.PriceText=="Precio pendiente"and not state.BuyEnabled,"No false zero price "..list[i].Id)
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
check(public[1].SortOrder==10 and public[1].Metadata.PricePending and not public[1].Metadata.OddsApproved,"Public Shop contract retains order and approvals")
-- Late Quote for a prior selection must not replace the current selection state.
shopUI._context=flowContext;shopUI._selectedId="Basic"
local detail={}
for _,name in ipairs({"NameLabel","DescriptionLabel","PriceRow","PriceLabel","StatusLabel","ActionButton","SecondaryButton"})do detail[name]=visual("TextLabel",name)end
shopUI._ui={Detail=detail}
shopUI:_renderDetail()
check(detail.PriceLabel.Text=="Precio pendiente"and detail.ActionButton.Text=="VER CAJA","Actual Shop detail shows pending price without crashing")
local card=visual("Frame","Card")
for _,name in ipairs({"PriceLabel","StateBadge","CoinIcon"})do card.Children[name]=visual("TextLabel",name)end
card.Children.CrateActions=visual("Frame","CrateActions")
for _,name in ipairs({"Action","StockLabel"})do card.CrateActions.Children[name]=visual("TextLabel",name)end
shopUI:_applyCardState(card,providers[1]:GetProduct("Basic"))
check(card.PriceLabel.Text=="Precio pendiente"and not card.CrateActions.Action.Active,"Actual card blocks pending commerce and hides zero")
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
print("PASS SlapCratesV12: "..assertions.." isolated assertions including base crates regression; gameplay/cloud NOT RUN")
