--!nonstrict
-- Adapter to the existing Shop/Inventory and coherent Coins purchase contracts.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local ServerStorage=game:GetService("ServerStorage")
local Catalog=require(ReplicatedStorage.Shared.DeathEffectDefinitions)
local Settings=require(ReplicatedStorage.Shared.DeathFeedbackConfig).DeathEffects
local Provider={}
local function players(self)
 if self._playerService then return self._playerService end
 return require(game.ServerScriptService.Services.PlayerService)
end
function Provider:GetCategory() return "DeathEffects" end
function Provider:GetDefaultProductId() return Settings.DefaultKillEffectId end
function Provider:GetResource(id)
 local definition=type(id)=="string" and Catalog[id]
 if not definition or definition.IsShopProduct~=true or id==Settings.DefaultFallEffectId then return nil end
 local folder=ServerStorage:FindFirstChild("DeathEffects")
 local model=folder and folder:FindFirstChild(definition.ModelName)
 local origin=model and model:FindFirstChild("Origin")
 if not model or not model:IsA("Model") or not origin or not origin:IsA("BasePart") then return nil end
 local particles=0
 local duration=model:GetAttribute("Duration")
 if type(duration)~="number" or duration~=duration or duration<=0 or duration>Settings.MaxDuration then return nil end
 for _,v in model:GetDescendants() do
  if v:IsA("LuaSourceContainer") or v:IsA("Explosion") then return nil end
  if v:IsA("BasePart") and (not v.Anchored or v.CanCollide or v.CanTouch or v.CanQuery) then return nil end
  if v:IsA("ParticleEmitter") then
   local count=v:GetAttribute("EmitCount")
   local delay=v:GetAttribute("EmitDelay")
   if v.Rate~=0 or v.Enabled or v.Texture=="" or type(count)~="number" or count~=count or count<=0 or count>80
    or type(delay)~="number" or delay~=delay or delay<0 or delay+v.Lifetime.Max>duration then return nil end
   particles+=1
  end
 end
 return if particles>0 then model else nil
end
function Provider:GetProduct(id)
 local definition=type(id)=="string" and Catalog[id]
 if not definition or definition.IsShopProduct~=true or id==Settings.DefaultFallEffectId then return nil end
 return {Id=id,Category=self:GetCategory(),ProductType="Cosmetic",DisplayName=definition.DisplayName,
  Description=definition.Description,Price=definition.Price,Currency="Coins",Rarity=definition.Rarity,
  Icon=definition.Icon,IsAvailable=self:GetResource(id)~=nil,Metadata={ModelName=definition.ModelName}}
end
function Provider:GetProducts()
 local products={}
 for id in pairs(Catalog) do local product=self:GetProduct(id);if product then table.insert(products,product) end end
 table.sort(products,function(a,b)return a.Id<b.Id end)
 return products
end
function Provider:HasProduct(player,id)
 return self:GetProduct(id)~=nil and players(self):HasItem(player,self:GetCategory(),id)
end
function Provider:GetEquippedEffectId(player)
 local ps=players(self)
 local inventory=ps:GetInventory(player)
 local selected=inventory and inventory.Equipped and inventory.Equipped[self:GetCategory()]
 local product=self:GetProduct(selected)
 if product and product.IsAvailable and self:HasProduct(player,selected) then return selected end
 -- Read-only fallback: do not overwrite a future owned selection when its asset is temporarily absent.
 return self:GetDefaultProductId()
end
local function validate(self,player,product)
 local ps=players(self)
 if not ps:IsShopDataReady(player) then return false,"DataNotLoaded" end
 if type(product)~="table" or product.Category~=self:GetCategory() then return false,"InvalidCategory" end
 local actual=self:GetProduct(product.Id)
 if not actual then return false,"ProductNotFound" end
 if not actual.IsAvailable then return false,"ProductUnavailable" end
 return true
end
function Provider:CanPurchase(player,product)
 local ok,reason=validate(self,player,product);if not ok then return false,reason end
 if self:HasProduct(player,product.Id) then return false,"AlreadyOwned" end
 return true,nil
end
function Provider:OnPurchased(player,product)
 local ok,reason=self:CanPurchase(player,product);if not ok then return false,reason end
 return players(self):CommitShopPurchase(player,self:GetProduct(product.Id))
end
function Provider:CanEquip(player,product)
 local ok,reason=validate(self,player,product);if not ok then return false,reason end
 if not self:HasProduct(player,product.Id) then return false,"NotOwned" end
 if self:GetEquippedEffectId(player)==product.Id then return false,"AlreadyEquipped" end
 return true
end
function Provider:OnEquipped(player,product)
 local ok,reason=validate(self,player,product);if not ok then return false,reason end
 if not self:HasProduct(player,product.Id) then return false,"NotOwned" end
 return players(self):SetEquippedItem(player,self:GetCategory(),product.Id)
end
function Provider:OnUnequipped(player,_product)
 local product=self:GetProduct(self:GetDefaultProductId())
 local ok,reason=validate(self,player,product);if not ok then return false,reason end
 return players(self):SetEquippedItem(player,self:GetCategory(),product.Id)
end
return Provider
