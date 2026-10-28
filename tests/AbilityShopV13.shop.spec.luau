--!nonstrict
-- Actual Shop/Registry/Provider/PlayerService/Stage functions over disposable mocks.
local count=0
local function check(v,label)assert(v,label);count+=1 end
local function load(name,env)
 local f=assert(loadstring(Sources[name],name));setfenv(f,setmetatable(env or {},{__index=getfenv()}));return f()
end
local F=load("ShopFixture",{Sources=Sources})
local s=F.New();local a=s.A;local ps=s.PS;local shop=s.Shop
local prices={Dash=0,AirJumps=750,DevilSpeed=1500,Invisible=2250,StrongSlap=3000}
check(#shop:GetCatalog("Abilities")==5,"Five abilities in the existing Shop registry")
check(s.AbilityRegistry:Get("Dash").Public.DisplayName=="Impulso","Dash ID retained with approved display name")
for id,price in pairs(prices)do
 local product=shop:GetProduct(id,"Abilities")
 check(product.Price==price and product.Metadata.PriceApproved,"Approved configurable price: "..id)
 check(product.Metadata.PurchaseEnabled==(id~="Dash") and not product.Metadata.PricePending,"Correct commercial state: "..id)
 if id~="Dash" then
  ps._data[a]=F.Profile(price+17)
  local initial=ps._data[a]
  local snapshots=#ps._snapshots
  local ok=shop:PurchaseProduct(a,id,"Abilities")
  check(ok and ps:GetCoins(a)==17 and ps:HasItem(a,"Abilities",id),"One coherent purchase: "..id)
  check(ps:GetEquippedItem(a,"Abilities")=="Dash","Purchase never equips: "..id)
  check(initial.Coins==price+17 and not initial.Inventory.Owned.Abilities[id],"Copy-on-write leaves original profile intact: "..id)
  check(ps:GetKills(a)==4 and ps._data[a].Inventory.Owned.DeathEffects.BasicKill,"Unrelated stats/cosmetics retained: "..id)
  check(#ps._snapshots==snapshots+1,"One committed data update: "..id)
  local ok2,why=shop:PurchaseProduct(a,id,"Abilities")
  check(not ok2 and why=="AlreadyOwned" and ps:GetCoins(a)==17,"Retry cannot charge twice: "..id)
  ps._data[a]=F.Profile(price-1)
  local before=ps._data[a]
  local poor,reason=shop:PurchaseProduct(a,id,"Abilities")
  check(not poor and reason=="InsufficientFunds" and ps._data[a]==before and not ps:HasItem(a,"Abilities",id),"Insufficient balance has zero mutation: "..id)
 end
end
ps._data[a]=F.Profile(10000)
local before=ps._data[a]
local ok,why=shop:PurchaseProduct(a,"Dash","Abilities")
check(not ok and why=="AlreadyOwned" and ps._data[a]==before,"Dash is a free initial entitlement and cannot be repurchased")
for _,id in ipairs({"UnknownAbility","AbilityTemplate","MovementGuard"})do
 check(not shop:PurchaseProduct(a,id,"Abilities") and ps._data[a]==before,"Unregistered product rejected: "..id)
end
check(not shop:PurchaseProduct(a,"StrongSlap","DeathEffects"),"Wrong category rejected")
check(not shop:PurchaseProduct({},"StrongSlap","Abilities"),"Invalid Player rejected by readiness contract")
s.Loaded[a]="Loading";check(not shop:PurchaseProduct(a,"StrongSlap","Abilities"),"Loading profile rejects purchase")
s.Loaded[a]="Loaded";a.Parent=nil
check(not shop:PurchaseProduct(a,"StrongSlap","Abilities"),"Disconnected Player rejects purchase")
a.Parent=s.Players;ps._shopClosing[a]=true
check(not shop:PurchaseProduct(a,"StrongSlap","Abilities"),"Closing player rejects purchase")
ps._shopClosing[a]=nil;ps:BeginShopShutdown()
check(not shop:PurchaseProduct(a,"StrongSlap","Abilities"),"Shutdown rejects purchase")
ps._shopShutdown=false
local product=s.Provider:GetProduct("StrongSlap")
for _,price in ipairs({-1,.5,0/0,math.huge})do
 local bad=table.clone(product);bad.Price=price
 local nextData,reason=s.Stage.Stage(before,bad)
 check(not nextData and reason=="InvalidPrice","Invalid price rejected before mutation")
end
local unapproved=table.clone(product);unapproved.Metadata=table.clone(product.Metadata);unapproved.Metadata.PriceApproved=false
check(not s.Stage.Stage(before,unapproved),"Unapproved ability denied even if PurchaseEnabled is forged internally")
local disabled=table.clone(product);disabled.Metadata={PurchaseEnabled=false,PriceApproved=true}
check(not s.Stage.Stage(before,disabled),"Disabled purchase denied during atomic staging")

-- Yield only in the disposable provider fixture to expose the existing lock.
local originalCan=s.Provider.CanPurchase
s.Provider.CanPurchase=function(self,...)coroutine.yield("validation-paused");return originalCan(self,...)end
local first=coroutine.create(function()check(shop:PurchaseProduct(a,"StrongSlap","Abilities"),"First concurrent purchase succeeds")end)
check(coroutine.resume(first) and shop:IsTransactionInProgress(a),"Purchase lock acquired before provider validation")
local second,reason=shop:PurchaseProduct(a,"StrongSlap","Abilities")
check(not second and reason=="TransactionInProgress","Second simultaneous request cannot enter commit")
check(coroutine.resume(first) and coroutine.status(first)=="dead","First request completes")
check(ps:GetCoins(a)==7000 and ps:HasItem(a,"Abilities","StrongSlap") and not shop:IsTransactionInProgress(a),"Exactly one charge and lock released")
s.Provider.CanPurchase=originalCan
local retry,reason=shop:PurchaseProduct(a,"StrongSlap","Abilities")
check(not retry and reason=="AlreadyOwned" and ps:GetCoins(a)==7000,"Retry after concurrent completion remains idempotent")
ps._data[a]=F.Profile(10000)
s.Provider.CanPurchase=function()error("fixture validation failure")end
local rejected,reason=shop:PurchaseProduct(a,"StrongSlap","Abilities")
check(not rejected and reason=="InternalError" and ps:GetCoins(a)==10000 and not shop:IsTransactionInProgress(a),"Exception leaves payment/property intact and releases lock")
s.Provider.CanPurchase=originalCan
ps._sendDataUpdate=function()error("fixture transport failure")end
check(shop:PurchaseProduct(a,"StrongSlap","Abilities") and ps:GetCoins(a)==7000,"Notification failure cannot roll back or falsify committed success")
check(not shop:PurchaseProduct(a,"StrongSlap","Abilities") and ps:GetCoins(a)==7000,"Retry after failed notification cannot debit again")
ps._sendDataUpdate=function(self,p)table.insert(self._snapshots,{Player=p,Data=self:GetPlayerData(p)})end

ps._data[a]=F.Profile(10000)
s.Provider.CanPurchase=function(self,...)coroutine.yield("disconnect-paused");return originalCan(self,...)end
local pending=coroutine.create(function()local accepted=shop:PurchaseProduct(a,"StrongSlap","Abilities");check(not accepted,"Disconnect during validation aborts transaction")end)
check(coroutine.resume(pending),"Pending disconnect fixture starts")
a.Parent=nil
check(coroutine.resume(pending) and ps:GetCoins(a)==10000 and not ps:HasItem(a,"Abilities","StrongSlap"),"Disconnect cannot cause partial purchase")
a.Parent=s.Players;s.Provider.CanPurchase=originalCan
local oldCharacter={};a.Character=oldCharacter
check(shop:PurchaseProduct(a,"AirJumps","Abilities"),"Purchase permitted for a loaded connected profile")
a.Character={}
check(ps:HasItem(a,"Abilities","AirJumps") and ps:GetCoins(a)==9250,"Respawn does not erase ownership or repeat payment")
check(not shop:EquipProduct(a,"Invisible","Abilities"),"Cannot equip unowned ability")
local balance=ps:GetCoins(a);local updates=#ps._snapshots
check(shop:EquipProduct(a,"AirJumps","Abilities") and ps:GetEquippedItem(a,"Abilities")=="AirJumps","Owned ability can be preferred")
check(ps:GetCoins(a)==balance and #ps._snapshots==updates+1,"Equip changes preference without Coins mutation")
updates=#ps._snapshots
check(shop:EquipProduct(a,"AirJumps","Abilities") and #ps._snapshots==updates,"Repeated equip is a no-op")
check(shop:UnequipProduct(a,"Abilities") and ps:GetEquippedItem(a,"Abilities")=="Dash","Unequip safely prefers free Dash")
updates=#ps._snapshots
check(shop:EquipProduct(a,"Dash","Abilities") and #ps._snapshots==updates and ps:GetCoins(a)==balance,"Dash equip is free and idempotent")

-- Actual schema normalizer; no load/save/provider/store calls.
local Data=load("DataService",s.Env)
local valid,normalized=Data:ValidatePlayerData(ps._data[a])
check(valid and normalized.Inventory.Owned.Abilities.AirJumps and normalized.Inventory.Owned.Abilities.Dash,"Existing data schema retains purchased ability and free Dash")
check(normalized.Coins==balance and normalized.Inventory.Equipped.Abilities=="Dash","Schema preserves Coins and preference")
local _,legacy=Data:ValidatePlayerData({Version=2,Coins=123,Wins=0,Losses=0,Kills=0})
check(legacy.Inventory.Owned.Abilities.Dash and legacy.Inventory.Equipped.Abilities=="Dash","Legacy data receives initial free entitlement")
check(s.Config.Match.PointReward==50 and s.Config.Economy.KillRewardCoins==50,"Goal/Kill rewards untouched")

-- Actual cosmetic providers; only physical asset availability is mocked here.
local originalGetService=s.Game.GetService
local model={IsA=function(_,class)return class=="Model"end}
local resources={FindFirstChild=function()return model end}
local storage={FindFirstChild=function()return resources end}
s.Game.GetService=function(self,name)return if name=="ServerStorage" then storage else originalGetService(self,name)end
local deathDefinitions=load("DeathDefinitions",{script={Parent={PointEffectDefinitions="PointDefinitions"}},require=s.Env.require})
s.Shared.DeathEffectDefinitions="DeathDefinitions"
local deathEnv=table.clone(s.Env)
deathEnv.require=function(name)return if name=="DeathDefinitions" then deathDefinitions else s.Env.require(name)end
local deathProvider=load("DeathProvider",deathEnv)
deathProvider.GetResource=function()return model end -- No VFX execution.
s.Registry:Register(deathProvider)
local playerModule={IsA=function(_,class)return class=="ModuleScript"end}
s.Game.ServerScriptService.FindFirstChild=function(_,name)
 return if name=="Services" then {FindFirstChild=function(_,id)return if id=="PlayerService" then playerModule else nil end} else nil
end
local pointEnv=table.clone(s.Env)
pointEnv.require=function(name)return if name==playerModule then ps else s.Env.require(name)end
local pointProvider=load("PointProvider",pointEnv)
s.Registry:Register(pointProvider)
check(s.Registry:GetProduct("Frost")==nil,"Legacy cosmetic identity ambiguity remains rejected")
ps._data[a]=F.Profile(3000)
check(shop:PurchaseProduct(a,"Frost","DeathEffects") and ps:GetCoins(a)==2250,"Existing Kill Effect purchase uses unchanged price/transaction")
check(shop:PurchaseProduct(a,"Frost","PointEffects") and ps:GetCoins(a)==1500,"Other cosmetic category retains independent purchase")
check(ps:HasItem(a,"DeathEffects","Frost") and ps:HasItem(a,"PointEffects","Frost") and ps:GetEquippedItem(a,"Abilities")=="Dash","Cosmetic purchases preserve separate inventories and ability preference")
check(shop:EquipProduct(a,"Frost","DeathEffects") and shop:EquipProduct(a,"Frost","PointEffects"),"Existing cosmetic equip routes remain usable")
check(ps:GetCoins(a)==1500 and ps:GetEquippedItem(a,"DeathEffects")=="Frost" and ps:GetEquippedItem(a,"PointEffects")=="Frost","Cosmetic equip remains free and category-specific")
print(string.format("PASS: %d isolated shop/economy assertions; no Studio/gameplay/cloud execution.",count))
