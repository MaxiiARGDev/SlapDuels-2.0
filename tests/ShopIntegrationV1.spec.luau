--!nonstrict
-- PREPARED ONLY: developer isolated harness, NOT run by the agent or against live profiles.
return function()
 local root=game.ServerScriptService
 local Provider=require(root.Shop.Providers.DeathEffectProvider)
 local Points=require(root.Shop.Providers.PointEffectProvider)
 local Registry=require(root.Shop.ShopRegistry)
 local PlayerService=require(root.Services.PlayerService)
 local Data=require(root.Services.PlayerDataService)
 local Catalog=require(game.ReplicatedStorage.Shared.DeathEffectDefinitions)
 local Settings=require(game.ReplicatedStorage.Shared.DeathFeedbackConfig).DeathEffects
 local Contract=require(game.ReplicatedStorage.Shared.DeathFeedbackContract)
 local n=0
 local function expect(value,message)n+=1;assert(value,message)end
 local registry=setmetatable({_providers={},_productsById={},_productsByRobloxId={}},{__index=Registry})
 registry:Register(Points);registry:Register(Provider)
 expect(registry:GetProvider("DeathEffects")==Provider,"A1 DeathEffects registry")
 expect(registry:GetProvider("PointEffects")==Points,"A2 PointEffects remains")
 for name,category in pairs({PointEffectsTab="PointEffects",SlapsTab="Slaps",TrailsTab="Trails",DeathEffectsTab="DeathEffects"}) do
  expect(game.StarterGui.ShopHUD.MainFrame.Tabs[name]:GetAttribute("Category")==category,"A3 "..name)
 end
 local basic=Provider:GetProduct("BasicKill")
 expect(basic and basic.Price==0 and basic.IsAvailable,"A4 initial free product with resource")
 expect(Provider:GetProduct("DefaultFall")==nil and registry:GetProduct("DefaultFall")==nil,"A5 fall not a product")
 for _,id in ipairs({"Frost","Void"}) do
  local product=Points:GetProduct(id)
  expect(product~=nil and not product.IsAvailable,"A6 future PointEffect retained but unavailable "..id)
  local ok,reason=Points:CanPurchase({},product)
  expect(not ok and reason=="ProductUnavailable","A6 cannot purchase "..id)
  ok,reason=Points:CanEquip({},product)
  expect(not ok and reason=="ProductUnavailable","A7 cannot equip "..id)
 end
 expect(Provider:GetResource("BasicKill")~=nil,"A8 physical resource exists")
 expect(Provider:GetProduct("arbitrary")==nil and Provider:GetResource("DefaultFall")==nil,"A9 IDs allowlisted")
 local who={}
 local data={Inventory={Owned={DeathEffects={BasicKill=true}},Equipped={DeathEffects="BasicKill"}}}
 local ready=true
 local fake={
  IsShopDataReady=function()return ready end,
  GetInventory=function()return data.Inventory end,
  HasItem=function(_,_,category,id)return category=="DeathEffects" and data.Inventory.Owned.DeathEffects[id]==true end,
  SetEquippedItem=function(_,_,category,id)data.Inventory.Equipped[category]=id;return true end,
  AddCoins=function()error("A13 must not grant Coins")end,
  DeductCoins=function()error("A13 must not charge the free initial effect")end,
 }
 local subject=setmetatable({_playerService=fake},{__index=Provider})
 expect(subject:GetEquippedEffectId(who)=="BasicKill","A4 default selection")
 local ok,reason=subject:CanPurchase(who,basic)
 expect(not ok and reason=="AlreadyOwned","A4 no synthetic purchase/grant")
 ready=false
 ok,reason=subject:OnEquipped(who,basic)
 expect(not ok and reason=="DataNotLoaded","Unloaded profile cannot equip")
 ready=true
 expect(subject:OnEquipped(who,basic),"A4/A13 free equip uses same inventory")
 -- Contract fixture only: no effect/model/product is installed in the game.
 local realGet=subject.GetProduct
 subject.GetProduct=function(self,id)
  if id=="fixture_unowned" then return {Id=id,Category="DeathEffects",IsAvailable=true} end
  return realGet(self,id)
 end
 ok,reason=subject:CanEquip(who,{Id="fixture_unowned",Category="DeathEffects"})
 expect(not ok and reason=="NotOwned","A10 provider rejects unowned eligible fixture")
 fake.GetEquippedItem=function(_,victim,category)
  expect(victim==who and category=="DeathEffects","A11 selection belongs to victim")
  return subject:GetEquippedEffectId(victim)
 end
 expect(Contract.ResolveEffect(fake,who,true,Catalog,Settings)=="BasicKill","A11 victim effect")
 expect(Contract.ResolveEffect(fake,{},false,Catalog,Settings)=="DefaultFall","A12 fall ignores equipment")
 -- No Init/Load/Save calls: normalizer operates on disposable plain tables only.
 local valid,record=Data:ValidatePlayerData({Version=2,Coins=321,Wins=0,Losses=0,Kills=0})
 expect(valid and record.Inventory.Owned.DeathEffects.BasicKill and record.Inventory.Equipped.DeathEffects=="BasicKill","A4 additive defaults for old profiles")
 valid,record=Data:ValidatePlayerData({Version=2,Coins=321,Wins=0,Losses=0,Kills=0,Inventory={Owned={DeathEffects={future_owned=true}},Equipped={DeathEffects="future_owned"}}})
 expect(valid and record.Inventory.Equipped.DeathEffects=="future_owned" and record.Coins==321,"Preserve future owned selection and balance")
 local fakeRuntime=setmetatable({_data={},_coins={}},{__index=PlayerService})
 expect(fakeRuntime:HasItem(who,"DeathEffects","BasicKill"),"Initial implicit entitlement")
 expect(not fakeRuntime:HasItem(who,"DeathEffects","arbitrary"),"No arbitrary initial entitlement")
 return n
end
