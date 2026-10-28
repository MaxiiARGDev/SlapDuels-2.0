--!nonstrict
-- PREPARED, NOT EXECUTED. Disposable fixtures only; never Init/bootstrap, cloud, live profiles or purchases.
-- Developer isolated harness: call returned function in a disposable test environment.
return function()
 local root=game.ServerScriptService
 local Stage=require(root.Shop.ProfilePurchase)
 local Shop=require(root.Services.ShopService)
 local PS=require(root.Services.PlayerService)
 local Registry=require(root.Shop.ShopRegistry)
 local Provider=require(root.Shop.Providers.DeathEffectProvider)
 local Data=require(root.Services.PlayerDataService)
 local Points=require(root.Shop.Providers.PointEffectProvider)
 local Catalog=require(game.ReplicatedStorage.Shared.DeathEffectDefinitions)
 local Contract=require(game.ReplicatedStorage.Shared.DeathFeedbackContract)
 local Settings=require(game.ReplicatedStorage.Shared.DeathFeedbackConfig).DeathEffects
 local n=0
 local function expect(v,msg) n+=1;assert(v,msg) end
 local function profile(coins)
  return {Coins=coins,Wins=3,Losses=2,Kills=4,Inventory={Owned={PointEffects={Basic=true},DeathEffects={BasicKill=true}},Equipped={PointEffects="Basic",DeathEffects="BasicKill"}}}
 end
 for _,id in {"Frost","Void"} do
  local model=game.ServerStorage.DeathEffects:FindFirstChild(id)
  expect(model and model:IsA("Model"),"A1/A2 physical "..id)
  expect(Provider:GetResource(id)==model,"A3/A4 real compatible particles "..id)
  local product=Provider:GetProduct(id)
  expect(product.IsAvailable and Catalog[id].ModelName==id,"A5 model mapping")
  local legacy=Points:GetProduct(id)
  expect(product.Id==legacy.Id and product.Price==legacy.Price and product.Rarity==legacy.Rarity,"A6 preserve metadata")
 end
 expect(Provider:GetProduct("BasicKill").Price==0,"A7 free entitlement")
 expect(Provider:GetProduct("DefaultFall")==nil,"A8 fall never sold")
 local registry=setmetatable({_providers={},_productsById={},_productsByRobloxId={}},{__index=Registry})
 registry:Register(Points);registry:Register(Provider)
 expect(registry:GetProduct("Frost")==nil,"Ambiguous legacy request rejected")
 expect(registry:GetProduct("Frost","DeathEffects").Category=="DeathEffects","Qualified identity")
 expect(registry:GetProduct("Frost","PointEffects").Category=="PointEffects","Legacy category preserved")
 expect(registry:GetProduct("unknown","DeathEffects")==nil,"A9 unknown")
 local product=Provider:GetProduct("Frost")
 local initial=profile(1000)
 local staged,reason=Stage.Stage(initial,product)
 expect(staged and staged.Coins==250 and staged.Inventory.Owned.DeathEffects.Frost,"A13 coherent staging")
 expect(initial.Coins==1000 and not initial.Inventory.Owned.DeathEffects.Frost,"A13 input untouched")
 expect(staged.Inventory.Equipped.DeathEffects=="BasicKill","Buy does not equip")
 expect(staged.Inventory.Owned.PointEffects.Basic and staged.Kills==4,"Other data preserved")
 local duplicate,why=Stage.Stage(staged,product)
 expect(not duplicate and why=="AlreadyOwned" and staged.Coins==250,"A11 duplicate")
 local insufficient,insufficientReason=Stage.Stage(profile(749),product)
 expect(not insufficient and insufficientReason=="InsufficientFunds","A6 funds")
 for _,price in {0/0,math.huge,-1,.5} do
  local bad=table.clone(product);bad.Price=price
  local result,err=Stage.Stage(initial,bad)
  expect(not result and err=="InvalidPrice","Invalid server price")
 end
 local who={}
 local runtime=setmetatable({_data={[who]=profile(1000)},_coins={},_ownedPointEffects={},_shopClosing={},_shopShutdown=false},{__index=PS})
 runtime.IsShopDataReady=function(self,p)return p==who and self._data[p]~=nil and not self._shopClosing[p] and not self._shopShutdown end
 runtime._sendDataUpdate=function()error("fixture notification failure")end
 local ok=runtime:CommitShopPurchase(who,product)
 expect(ok and runtime._data[who].Coins==250 and runtime._data[who].Inventory.Owned.DeathEffects.Frost,"A13 notification cannot undo commit")
 ok,reason=runtime:CommitShopPurchase(who,product)
 expect(not ok and reason=="AlreadyOwned" and runtime._data[who].Coins==250,"A11 retry after notification failure")
 runtime._shopClosing[who]=true
 ok,reason=runtime:CommitShopPurchase(who,Provider:GetProduct("Void"))
 expect(not ok and reason=="DataNotLoaded","Closing rejects purchase")
 runtime._shopClosing[who]=nil;runtime:BeginShopShutdown()
 expect(not runtime:CommitShopPurchase(who,product),"Shutdown rejects purchase")
 local function subject(canPurchase)
  local data=profile(1000)
  local fake=setmetatable({_data={[who]=data},_coins={},_ownedPointEffects={}},{__index=PS})
  fake.IsShopDataReady=function()return true end;fake._sendDataUpdate=function()end
  local provider={CanPurchase=canPurchase}
  local reg={GetProduct=function(_,id,category)return if id=="Frost" and (category==nil or category=="DeathEffects") then product else nil end,GetProvider=function()return provider end}
  local shop=setmetatable({_playerService=fake,_registry=reg,_inProgressPurchases={}},{__index=Shop})
  return shop,fake
 end
 local shop,fake=subject(function()coroutine.yield("paused");return true end)
 local first=coroutine.create(function()expect(shop:PurchaseProduct(who,"Frost","DeathEffects"),"A12 first purchase")end)
 expect(coroutine.resume(first),"A12 first starts")
 ok,reason=shop:PurchaseProduct(who,"Frost","DeathEffects")
 expect(not ok and reason=="TransactionInProgress","A12 concurrent serialized")
 expect(coroutine.resume(first) and coroutine.status(first)=="dead","A12 first completes")
 expect(fake._data[who].Coins==250 and fake._data[who].Inventory.Owned.DeathEffects.Frost,"A12 one charge")
 local broken,unchanged=subject(function()error("fixture validation failure")end)
 ok,reason=broken:PurchaseProduct(who,"Frost","DeathEffects")
 expect(not ok and reason=="InternalError" and not broken:IsTransactionInProgress(who),"A13 release after exception")
 expect(unchanged._data[who].Coins==1000 and not unchanged._data[who].Inventory.Owned.DeathEffects.Frost,"A13 exception leaves profile intact")
 local inventory=profile(4000).Inventory
 local adapter={
  IsShopDataReady=function()return true end,GetInventory=function()return inventory end,
  HasItem=function(_,_,category,id)return inventory.Owned[category] and inventory.Owned[category][id]==true end,
  SetEquippedItem=function(_,_,category,id)inventory.Equipped[category]=id;return true end,
 }
 local effects=setmetatable({_playerService=adapter},{__index=Provider})
 ok,reason=effects:CanEquip(who,product)
 expect(not ok and reason=="NotOwned","A10 not owned")
 inventory.Owned.DeathEffects.Frost=true;inventory.Owned.DeathEffects.Void=true
 expect(effects:OnEquipped(who,product),"A14 equip Frost")
 expect(effects:OnEquipped(who,Provider:GetProduct("Void")) and inventory.Equipped.DeathEffects=="Void","A14 one selection")
 -- A15 respawn persistence requires the developer's real gameplay test.
 adapter.GetEquippedItem=function(_,victim,category)expect(victim==who and category=="DeathEffects","A16 victim");return effects:GetEquippedEffectId(victim) end
 expect(Contract.ResolveEffect(adapter,who,true,Catalog,Settings)=="Void","A16 victim selection")
 expect(Contract.ResolveEffect(adapter,{},false,Catalog,Settings)=="DefaultFall","A17 no attacker")
 local config=require(game.ReplicatedStorage.Shared.Config)
 expect(config.Economy.KillRewardCoins==50 and config.Match.PointReward==50,"A19 reward config unchanged")
 local hud=game.StarterGui.ShopHUD
 expect(hud.MainFrame.Tabs.DeathEffectsTab:GetAttribute("Category")=="DeathEffects" and hud.MainFrame.Body.Catalog.ProductCardTemplate~=nil,"A20 physical HUD")
 -- Save snapshot: disposable Player + fake adapter, no connected player/store.
 local player=Instance.new("Player")
 local savedSnapshot
 local fakeStore={UpdateAsync=function(_,_,transform)
  coroutine.yield("save-paused")
  savedSnapshot=transform(nil)
 end}
 local saver=setmetatable({_loadStates={[player]="Loaded"},_saving={},_store=fakeStore},{__index=Data})
 local live=profile(1000)
 local saving=coroutine.create(function()expect(saver:SavePlayer(player,live),"Snapshot save fixture")end)
 expect(coroutine.resume(saving),"Save fixture starts")
 live.Coins=250;live.Inventory.Owned.DeathEffects.Frost=true
 expect(coroutine.resume(saving) and coroutine.status(saving)=="dead","Save fixture completes")
 expect(savedSnapshot.Coins==1000 and not savedSnapshot.Inventory.Owned.DeathEffects.Frost,"A13 deep immutable purchase snapshot")
 saver._store=nil
 ok,reason=saver:SavePlayer(player,live)
 expect(not ok and reason=="DataStoreNotAvailable" and live.Coins==250 and live.Inventory.Owned.DeathEffects.Frost,"Save failure explicit; no fake durability or partial refund")
 player:Destroy()
 -- A18 requires source/session inspection plus manual third-client regression.
 -- A21/A22 are external build/diff commands. Save-failure/durability is NOT guaranteed by this suite.
 return n
end
