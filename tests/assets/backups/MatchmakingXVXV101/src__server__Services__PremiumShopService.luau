--!nonstrict
local Players=game:GetService("Players");local RS=game:GetService("ReplicatedStorage")
local Marketplace=game:GetService("MarketplaceService");local Policy=game:GetService("PolicyService")
local Run=game:GetService("RunService")
local Config=require(RS.Shared.PremiumShop.PremiumShopConfig)
local Root=script.Parent.Parent.PremiumShop
local Registry=require(Root.PremiumProductRegistry);local Eligibility=require(Root.PremiumEligibility)
local Coordinator=require(Root.ReceiptCoordinator)
local Backend=require(Root.DurableReceiptBackend);local Verifier=require(Root.ProductVerifier)
local Reserved=require(RS.Shared.PremiumShop.PlaceholderProductIds)
local Service={Name="PremiumShopService"}
local function ensure(p,n,k)local o=p:FindFirstChild(n);if o then assert(o:IsA(k),"Premium class conflict");return o end;o=Instance.new(k);o.Name=n;o.Parent=p;return o end
function Service:Init(context)
 self.Context=context;self.Registry=Registry.Load(RS.Shared);self.Rate={};self.Connections={}
 self.Backend,self.BackendReason=Backend.Create(context,Run:IsStudio())
 self.Verifier=Verifier.new(Marketplace,Reserved,Run:IsStudio(),game.GameId)
 self.Receipt=Coordinator.new(self.Registry,self.Backend,Players,{Reserved=Reserved,Delivered=function(uid,result,p)
  if result.Replay then return end
  local player=Players:GetPlayerByUserId(uid)
  if player and self.Delivery then self.Delivery:FireClient(player,{PurchaseId=result.PurchaseId,ProductId=result.ProductId,ProductKey=p.Id,State="Applied"})end
 end})
end
function Service:_lobby(player)
 local rounds=self.Context:GetService("RoundService")
 return player.Parent==Players and not player:GetAttribute("MatchId")and not player:GetAttribute("ResultsSessionId")and rounds and not rounds:GetSessionForPlayer(player)
end
function Service:_authorize(player,p,tokens)
 local ok,why=Eligibility.CanPurchase(Config,p,Eligibility.Policy(Policy,player),self.Context:GetService("PlayerService"):IsShopDataReady(player),self:_lobby(player))
 if not ok then return false,why end
 if Run:IsStudio()or not self.Backend or not self.Backend.DurableValidated then return false,self.BackendReason or "DurableBackendPending"end
 local verified,reason=self.Verifier:Verify(p);if not verified then return false,reason end
 for _,item in ipairs(p.Rewards.Crates)do
  local valid,code=self.Context:GetService("CrateService"):ValidatePremiumAcquisitionQuote(player,item.CrateId,type(tokens)=="table"and tokens[item.CrateId])
  if not valid then return false,code end
 end
 local checked,ready,code=pcall(self.Backend.CanPurchase,self.Backend,player.UserId,p)
 if not checked then return false,"PersistenceTemporaryError"end
 if not ready then return false,code end
 if not self:_lobby(player)or not self.Context:GetService("PlayerService"):IsShopDataReady(player)then return false,"DataNotLoaded"end
 return true
end
function Service:_receipts(player)
 if not self.Backend then return {}end
 local ok,records=pcall(self.Backend.ReadReceipts,self.Backend,player.UserId)
 if not ok or type(records)~="table"then return nil,"PersistenceTemporaryError"end
 local result={};for purchaseId,r in pairs(records)do if r.PlayerId==player.UserId and r.State=="Applied"then table.insert(result,{PurchaseId=purchaseId,ProductId=r.ProductId,ProductKey=r.ProductKey,State=r.State})end end
 return result
end
function Service:Catalog(player)
 if not Config.PremiumShopEnabled then return {Ok=false,Code="ShopDisabled"}end
 local policy=Eligibility.Policy(Policy,player);local products={}
 for _,id in ipairs(self.Registry.Order)do
  local p=self.Registry.ById[id];local verified,verificationReason=self.Verifier:Verify(p)
  local allowed,why=Eligibility.CanPurchase(Config,p,policy,self.Context:GetService("PlayerService"):IsShopDataReady(player),self:_lobby(player))
  -- Always blocked until a durable backend is explicitly installed and validated.
  allowed=allowed and self.Backend~=nil and verified~=nil
  table.insert(products,{Id=p.Id,Category=p.Category,DisplayName=p.DisplayName,Description=p.Description,Icon=p.Icon,
   PreviewModel=p.PreviewModel,CrateId=p.CrateId,SortOrder=p.SortOrder,Rewards=p.Rewards,HasRandomContents=p.HasRandomContents,
   DuplicatePolicy=p.DuplicatePolicy,PriceRobux=nil,SuggestedRobux=p.SuggestedRobux,IsPlaceholder=p.IsPlaceholder,
   ProductId=verified and p.DeveloperProductId,CommercialVerified=verified~=nil,PurchaseAllowed=allowed,
   Status=p.BlockedReason or why or verificationReason or self.BackendReason,ConfigurationStatus=p.BlockedReason,
   OddsNotice=if p.HasRandomContents then "Probabilidades y elegibilidad deben consultarse antes de comprar y abrir. Stock y propiedad pueden modificar cada extracción."else nil})
 end
 return {Ok=true,Products=products,Policy=policy,PurchasesEnabled=Config.PurchasesEnabled and self.Backend~=nil,BackendStatus=self.BackendReason,DefaultCategory=Config.DefaultCategory,
  CrateProducts=self.Context:GetService("CrateService"):GetCatalog()}
end
function Service:Request(player,action,args)
 if typeof(player)~="Instance"or not player:IsA("Player")or player.Parent~=Players then return {Ok=false,Code="InvalidPlayer"}end
 local now=os.clock();if now<(self.Rate[player]or 0)then return {Ok=false,Code="RateLimited"}end;self.Rate[player]=now+.5
 if action=="Catalog"then return self:Catalog(player)end
 if action=="Status"then local receipts,reason=self:_receipts(player);return {Ok=receipts~=nil,Receipts=receipts,Code=reason}end
 if action=="Odds"then
  local p=type(args)=="table"and self.Registry.ById[args.Id]
  if not p then return {Ok=false,Code="UnknownProduct"}end
  local quotes={}
  for _,item in ipairs(p.Rewards.Crates)do quotes[item.CrateId]=self.Context:GetService("CrateService"):QuoteForPremium(player,item.CrateId)end
  return {Ok=true,Quotes=quotes,Notice="Cada extracción recalcula stock y propiedad; probabilidades vigentes por RewardId."}
 end
 if action=="Purchase"then
  local p=type(args)=="table"and type(args.Id)=="string"and self.Registry.ById[args.Id]
  local ok,code=self:_authorize(player,p,type(args)=="table"and args.QuoteTokens)
  if not ok then return {Ok=false,Code=code}end
  local receipts,reason=self:_receipts(player);if not receipts then return {Ok=false,Code=reason}end
  local known={};for _,r in ipairs(receipts)do known[r.PurchaseId]=true end
  return {Ok=true,PromptAllowed=true,ProductId=p.DeveloperProductId,KnownReceipts=known}
 end
 return {Ok=false,Code="InvalidAction"}
end
function Service:Start()
 local folder=ensure(ensure(RS,"Remotes","Folder"),"PremiumShop","Folder")
 ensure(folder,"Request","RemoteFunction").OnServerInvoke=function(player,action,args)return self:Request(player,action,args)end
 self.Delivery=ensure(folder,"Delivery","RemoteEvent")
 -- The only ProcessReceipt assignment in the project. No PromptProductPurchaseFinished grant.
 Marketplace.ProcessReceipt=function(receipt)return self.Receipt:Process(receipt)end
 table.insert(self.Connections,Players.PlayerRemoving:Connect(function(p)self.Rate[p]=nil end))
end
return Service
