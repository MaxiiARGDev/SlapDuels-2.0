--!nonstrict
local Players=game:GetService("Players");local RS=game:GetService("ReplicatedStorage")
local Marketplace=game:GetService("MarketplaceService");local Policy=game:GetService("PolicyService")
local Config=require(RS.Shared.PremiumShop.PremiumShopConfig)
local Root=script.Parent.Parent.PremiumShop
local Registry=require(Root.PremiumProductRegistry);local Eligibility=require(Root.PremiumEligibility)
local Coordinator=require(Root.ReceiptCoordinator)
local Service={Name="PremiumShopService"}
local function ensure(p,n,k)local o=p:FindFirstChild(n);if o then assert(o:IsA(k),"Premium class conflict");return o end;o=Instance.new(k);o.Name=n;o.Parent=p;return o end
function Service:Init(context)
 self.Context=context;self.Registry=Registry.Load(RS.Shared);self.Rate={};self.Connections={}
 -- No durable backend is installed. Config alone can NEVER enable real payments.
 self.Receipt=Coordinator.new(self.Registry,nil,Players);self.Prices={}
end
function Service:_lobby(player)
 local rounds=self.Context:GetService("RoundService")
 return player.Parent==Players and not player:GetAttribute("MatchId")and not player:GetAttribute("ResultsSessionId")and rounds and not rounds:GetSessionForPlayer(player)
end
function Service:_price(p,player)
 if not p.DeveloperProductId then return nil,"Producto sin configurar"end
 -- Query price per player request, no hardcoded/default Robux price and no global personalized-price cache.
 local ok,info=pcall(Marketplace.GetProductInfoAsync,Marketplace,p.DeveloperProductId,Enum.InfoType.Product)
 if not ok or type(info)~="table"or type(info.PriceInRobux)~="number"or info.PriceInRobux~=info.PriceInRobux or info.PriceInRobux==math.huge or info.PriceInRobux<0 or info.PriceInRobux%1~=0 then return nil,"Precio no disponible"end
 return info.PriceInRobux,info.IsForSale==false and "No disponible"or nil
end
function Service:Catalog(player)
 if not Config.PremiumShopEnabled then return {Ok=false,Code="ShopDisabled"}end
 local policy=Eligibility.Policy(Policy,player);local products={}
 for _,id in ipairs(self.Registry.Order)do
  local p=self.Registry.ById[id];local price,priceReason=self:_price(p,player)
  local allowed,why=Eligibility.CanPurchase(Config,p,policy,self.Context:GetService("PlayerService"):IsShopDataReady(player),self:_lobby(player))
  -- Always blocked until a durable backend is explicitly installed and validated.
  allowed=allowed and self.Receipt.Backend~=nil and price~=nil and priceReason==nil
  table.insert(products,{Id=p.Id,Category=p.Category,DisplayName=p.DisplayName,Description=p.Description,Icon=p.Icon,
   PreviewModel=p.PreviewModel,CrateId=p.CrateId,SortOrder=p.SortOrder,Rewards=p.Rewards,HasRandomContents=p.HasRandomContents,
   DuplicatePolicy=p.DuplicatePolicy,PriceRobux=price,PurchaseAllowed=allowed,
   Status=why or priceReason or "DurableBackendPending",ConfigurationStatus=p.BlockedReason,
   OddsNotice=if p.HasRandomContents then "Probabilidades y elegibilidad deben consultarse antes de comprar y abrir. Stock y propiedad pueden modificar cada extracción."else nil})
 end
 return {Ok=true,Products=products,Policy=policy,PurchasesEnabled=false,BackendStatus="DurableBackendPending",DefaultCategory=Config.DefaultCategory,
  CrateProducts=self.Context:GetService("CrateService"):GetCatalog()}
end
function Service:Request(player,action,args)
 if typeof(player)~="Instance"or not player:IsA("Player")or player.Parent~=Players then return {Ok=false,Code="InvalidPlayer"}end
 local now=os.clock();if now<(self.Rate[player]or 0)then return {Ok=false,Code="RateLimited"}end;self.Rate[player]=now+.5
 if action=="Catalog"then return self:Catalog(player)end
 if action=="Odds"then
  local p=type(args)=="table"and self.Registry.ById[args.Id]
  if not p then return {Ok=false,Code="UnknownProduct"}end
  local quotes={}
  for _,item in ipairs(p.Rewards.Crates)do quotes[item.CrateId]=self.Context:GetService("CrateService"):Quote(player,item.CrateId)end
  return {Ok=true,Quotes=quotes,Notice="Cada extracción recalcula stock y propiedad; probabilidades vigentes por RewardId."}
 end
 if action=="Purchase"then
  -- Deliberately fail closed in V1.0 even if shared config is changed.
  return {Ok=false,Code="PurchasesDisabled"}
 end
 return {Ok=false,Code="InvalidAction"}
end
function Service:Start()
 local folder=ensure(ensure(RS,"Remotes","Folder"),"PremiumShop","Folder")
 ensure(folder,"Request","RemoteFunction").OnServerInvoke=function(player,action,args)return self:Request(player,action,args)end
 -- The only ProcessReceipt assignment in the project. No PromptProductPurchaseFinished grant.
 Marketplace.ProcessReceipt=function(receipt)return self.Receipt:Process(receipt)end
 table.insert(self.Connections,Players.PlayerRemoving:Connect(function(p)self.Rate[p]=nil end))
end
return Service
