--!nonstrict
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local SS=game:GetService("ServerStorage")
local RunService=game:GetService("RunService")
local PolicyService=game:GetService("PolicyService")
local Http=game:GetService("HttpService")
local Catalog=require(RS.Shared.SlapCrates.Catalog)
local Appearance=require(RS.Shared.SlapCrates.Appearance)
local Inventory=require(RS.Shared.SlapCrates.Inventory)
local Odds=require(RS.Shared.SlapCrates.Odds)
local Batch=require(RS.Shared.SlapCrates.BatchOpening)
local Engine=require(script.Parent.Crates.CrateEngine)
local Stock=require(script.Parent.Crates.InMemoryStock)
local ProductionStock=require(script.Parent.Crates.UnlimitedProductionStock)
local Announcements=require(script.Parent.Crates.AnnouncementAdapter)
local StandOpening=require(script.Parent.Crates.StandOpeningService)
local Service={Name="CrateService"}
local function ensure(parent,name,class)
 local obj=parent:FindFirstChild(name)
 if obj then assert(obj:IsA(class),"Crate resource class conflict: "..name);return obj end
 obj=Instance.new(class);obj.Name=name;obj.Parent=parent;return obj
end
function Service:Init(context)
 self._context=context;self._quotes={};self._premiumQuotes={};self._rate={};self._cancelRate={};self._connections={}
 self._announcements=Announcements.new(function(packet)self._announce:FireAllClients(packet)end)
 self._stock=if RunService:IsStudio() and context.PersistenceInfo and context.PersistenceInfo.Environment=="Studio" and context.PersistenceInfo.ProviderName=="InMemory"
  and context.PersistenceInfo.WritesToCloud==false then Stock.new() else nil
 if not RunService:IsStudio()and context.PersistenceInfo and context.PersistenceInfo.Environment=='Production'and context.PersistenceInfo.ProviderName=='RobloxDataStore'and context.PersistenceInfo.WritesToCloud==true and context.PersistenceInfo.GameId==10769217377 then
  local ok,stock=pcall(ProductionStock.new,Catalog);if ok then self._stock=stock else warn('[Crates] '..tostring(stock))end
 end
 self._rng=Random.new()
 self._stands=StandOpening.new(self)
end
function Service:_players()return self._context:GetService("PlayerService")end
function Service:ExtendInventory(inv)
 local extended=Inventory.Extend(inv)
 if self._stock then Engine.Reconcile({Inventory=extended},self._stock)end
 return extended
end
function Service:_lobby(player)
 if player:GetAttribute('PartyQueueTicket')then return false end
 local rounds=self._context:GetService("RoundService")
 return player.Parent==Players and not player:GetAttribute("MatchId") and not player:GetAttribute("ResultsSessionId")
  and rounds~=nil and rounds:GetSessionForPlayer(player)==nil
end
function Service:_resource(reward)
 local slap=Catalog.Slaps.ById[reward.SlapId];local v=Catalog.Variations.ById[reward.VariationId]
 local tool=self:GetRewardTemplate(reward)
 local profiles=RS:FindFirstChild("SlapVariationEffects")
 if not tool or not tool:IsA("Tool") or not v or not profiles or not profiles:FindFirstChild(v.VisualProfile)then return false end
 local config=tool:FindFirstChild("Configuration");local power=config and config:FindFirstChild("Power");local cooldown=config and config:FindFirstChild("SlapCooldown")
 local previews=RS:FindFirstChild("CrateRewardPreviews")
 return power~=nil and power:IsA("NumberValue") and power.Value>0 and power.Value<math.huge
  and cooldown~=nil and cooldown:IsA("NumberValue") and cooldown.Value>=0 and cooldown.Value<math.huge
  and previews~=nil and previews:FindFirstChild(reward.SlapId)~=nil
end
function Service:_eligible(player,crate,reviewQuote)
 if not self._stock then return false,"ProductionBackendBlocked" end
 if not crate or (crate.StudioOnly and (not RunService:IsStudio() or SS:GetAttribute("CrateStudioTestsEnabled")~=true)) then return false,"CrateUnavailable" end
 if not Engine.Approved(crate)and not(reviewQuote and crate.MatrixVersion=="InitialV13Review")then return false,"CommercialApprovalPending" end
 if not self:_lobby(player) then return false,"LobbyOnly" end
 if not self:_players():IsShopDataReady(player)then return false,"DataNotLoaded" end
 -- Coins may be Robux-funded. No client claims or Studio bypass of this policy.
 local ok,policy=pcall(PolicyService.GetPolicyInfoForPlayerAsync,PolicyService,player)
 if not ok or type(policy)~="table" or policy.ArePaidRandomItemsRestricted~=false then return false,"PaidRandomItemsRestricted" end
 if not self:_lobby(player) or not self:_players():IsShopDataReady(player)then return false,"DataNotLoaded" end
 return true
end
local function signature(rows,crate)
 local parts={crate.CrateId,tostring(crate.PriceCoins),crate.DuplicatePolicy}
 for _,row in ipairs(rows)do table.insert(parts,row.Reward.RewardId.."="..string.format("%.17g",row.Probability)..":"..tostring(row.Stock.RemainingStock))end
 return table.concat(parts,"|")
end
function Service:Quote(player,id)
 local crate=Catalog.Crates.ById[id];local ok,reason=self:_eligible(player,crate,true)
 if not ok then return {Ok=false,Code=reason} end
 local data=self:_players():GetPlayerData(player)
 local inv=Inventory.Extend(data.Inventory);local valid,err=Inventory.Validate(inv)
 if not valid then return {Ok=false,Code=err} end
 local rows,why,excluded=Odds.Resolve(crate,Catalog,inv,self._stock,function(r)return self:_resource(r)end)
 local function describe(reward)
  local variation=Catalog.Variations.ById[reward.VariationId]
  return {RewardId=reward.RewardId,DisplayName=reward.DisplayName,SlapId=reward.SlapId,VariationId=reward.VariationId,
   SlapName=Catalog.Slaps.ById[reward.SlapId].DisplayName,VariationName=variation.DisplayName,Color=variation.Color,SortOrder=variation.SortOrder}
 end
 local excludedPublic={}
 for _,row in ipairs(excluded or {})do local entry=describe(row.Reward);entry.Reason=row.Reason;entry.Stock=row.Stock;table.insert(excludedPublic,entry)end
 if not rows then return {Ok=false,Code=why,ExcludedOutcomes=excludedPublic} end
 local token=Http:GenerateGUID(false)
 self._quotes[player]={Token=token,CrateId=id,Until=os.clock()+30,Signature=signature(rows,crate)}
 local outcomes={}
 for _,row in ipairs(rows)do local entry=describe(row.Reward);entry.Percent=row.Percent;entry.Stock=row.Stock;table.insert(outcomes,entry)end
 return {Ok=true,Token=token,Outcomes=outcomes,Scope=self._stock.Scope,PriceCoins=crate.PriceCoins,
  ReviewOnly=not Engine.Approved(crate),PurchaseAllowed=not crate.PremiumOnly and Engine.Approved(crate),ExcludedOutcomes=excludedPublic,
  BatchOddsNotice="Cada extracción recalcula elegibilidad y stock; los premios previos del lote pueden cambiar las probabilidades siguientes.",
  ExpiresAt=workspace:GetServerTimeNow()+30,Snapshot={Coins=data.Coins,Inventory=Inventory.Copy(data.Inventory)}}
end
function Service:ValidatePremiumAcquisitionQuote(player,id,token)
 local crate=Catalog.Crates.ById[id];local ok,why=self:_eligible(player,crate)
 if not ok then return false,why end
 local q=self._premiumQuotes[player]and self._premiumQuotes[player][id]or self._quotes[player]
 if not q or q.CrateId~=id or q.Token~=token or os.clock()>=q.Until then return false,"ViewOddsFirst"end
 local data=self:_players():GetPlayerData(player)
 local rows,reason=Odds.Resolve(crate,Catalog,Inventory.Extend(data.Inventory),self._stock,function(r)return self:_resource(r)end)
 if not rows then return false,reason end
 if signature(rows,crate)~=q.Signature then return false,"OddsChanged"end
 return true
end
function Service:QuoteForPremium(player,id)
 local result=self:Quote(player,id)
 if result.Ok then self._premiumQuotes[player]=self._premiumQuotes[player]or {};self._premiumQuotes[player][id]=table.clone(self._quotes[player])end
 return result
end
function Service:_transact(player,kind,args)
 local quantity=if kind=="Open"then Batch.Quantity(args.Quantity)else 1
 if not quantity then return {Ok=false,Code="InvalidQuantity"}end
 if quantity>1 and not(self._stands and self._stands:IsStandMode())then return {Ok=false,Code="MultiOpenStandOnly"}end
 local crate=Catalog.Crates.ById[args.CrateId];local ok,why=self:_eligible(player,crate)
 if not ok then return {Ok=false,Code=why} end
 local ps=self:_players();local data=ps:GetPlayerData(player)
 local inv=Inventory.Extend(data.Inventory)
 local existing=inv.CrateOperations[args.OperationId]
 for id,operation in pairs(inv.CrateOperations)do
  if id~=args.OperationId and operation.Kind=="Open"and operation.State=="GrantCommitted"then return {Ok=false,Code="TransactionInProgress"}end
 end
 if not existing then
  local q=self._quotes[player]
  if not q or q.Token~=args.QuoteToken or q.CrateId~=args.CrateId or os.clock()>=q.Until then return {Ok=false,Code="ViewOddsFirst"} end
  local rows,reason=Odds.Resolve(crate,Catalog,inv,self._stock,function(r)return self:_resource(r)end)
  if not rows then return {Ok=false,Code=reason}end
  if q.Signature~=signature(rows,crate)then return {Ok=false,Code="OddsChanged"}end
 end
 if kind=="Open"and not existing and self._stands and self._stands:IsStandMode()then
  local row=self._stands.Ledger and self._stands.Ledger.Players[player.UserId]
  local stand=self._stands:Validate(player,args.StandId)
  if not row or row.Until<=os.clock()or row.OperationId~=args.OperationId or row.Character~=player.Character or not stand then return {Ok=false,Code="StandLeaseExpired"}end
 end
 local nextData,err,op,replayed=Engine.Stage(data,crate,kind,args.OperationId,player.UserId,Catalog,self._stock,function()return self._rng:NextNumber()end,function(r)return self:_resource(r)end,quantity)
 if not nextData then return {Ok=false,Code=err}end
 if not replayed then
  local success,committed,reason=pcall(ps.CommitCrateState,ps,player,data.Inventory,nextData)
  if not success then
   committed=ps:GetPlayerData(player)==nextData;reason="ProfileCommitFailed"
  end
  if not committed then
   if reason=='PersistencePending'then return {Ok=false,Code='PersistencePending',Operation=Inventory.Copy(op)}end
   Engine.Release(op,self._stock)
   return {Ok=false,Code=reason}
  end
 end
 -- Idempotent recovery after profile commit. A failed stock commit retains the reservation, never rerolls.
 local completed=Engine.Reconcile(nextData,self._stock)
 if kind=="Open"and not completed then return {Ok=false,Code="StockCommitPending",Operation=Inventory.Copy(op),Snapshot={Coins=nextData.Coins,Inventory=Inventory.Copy(nextData.Inventory)}}end
 if kind=="Open" and(not replayed or op.PresentationSent==false)then self:_present(player,crate,op);op.PresentationSent=true end
 return {Ok=true,Operation=Inventory.Copy(op),Replay=replayed,Crates=Inventory.Copy(nextData.Inventory.Crates),
  Snapshot={Coins=nextData.Coins,Inventory=Inventory.Copy(nextData.Inventory)}}
end
function Service:GetCatalog()
 local results={}
 for _,id in ipairs(Catalog.Crates.Order)do
  local c=Catalog.Crates.ById[id]
  if c.StudioOnly and (not RunService:IsStudio() or SS:GetAttribute("CrateStudioTestsEnabled")~=true)then continue end
  table.insert(results,{Id=id,SortOrder=c.SortOrder,Category="Crates",ProductType="Consumable",DisplayName=c.DisplayName,Description=c.Description,
   Price=c.PriceCoins or 0,Currency=if c.PremiumOnly then "Robux"else "Coins",Icon=c.Icon,Rarity=id,IsAvailable=true,
   Metadata={PriceApproved=c.PriceApproved==true,PricePending=not c.PriceApproved,OddsApproved=c.OddsApproved==true,Enabled=c.Enabled==true,
    PurchaseEnabled=not c.PremiumOnly and Engine.Approved(c) and self._stock~=nil,Model=c.Model,PremiumOnly=c.PremiumOnly==true,OpeningEnabled=Engine.Approved(c)and self._stock~=nil,
    ApprovalStatus=c.ApprovalStatus,FavouredVariations=self:_favoured(c),RollDuration=c.RollDuration,StockScope=self._stock and self._stock.Scope or "ProductionBlocked"}})
 end
 table.sort(results,function(a,b)return if a.SortOrder==b.SortOrder then a.Id<b.Id else a.SortOrder<b.SortOrder end)
 return results
end
function Service:_favoured(crate)
 local high=0;local ids={}
 for id,weight in pairs(crate.Weights)do if type(weight)=="number" and weight>high then high=weight;ids={id}elseif weight==high and weight>0 then table.insert(ids,id)end end
 table.sort(ids);return if #ids>0 then table.concat(ids,", ") else "Pendiente"
end
function Service:Request(player,action,args)
 if typeof(player)~="Instance" or not player:IsA("Player") or player.Parent~=Players then return {Ok=false,Code="InvalidPlayer"}end
 if type(action)~="string" or type(args)~="table"then return {Ok=false,Code="InvalidRequest"}end
 if action=="CancelOpening"then
  if type(args.OpeningId)~="string"or #args.OpeningId>128 then return {Ok=false,Code="InvalidOperationId"}end
  local now=os.clock();if now<(self._cancelRate[player]or 0)then return {Ok=false,Code="RateLimited"}end
  self._cancelRate[player]=now+.1
  return self._stands:Cancel(player,args.OpeningId)
 end
 local t=os.clock();if t<(self._rate[player] or 0)then return {Ok=false,Code="RateLimited"}end
 self._rate[player]=t+.25
 if action=="OpeningContext"then return {Ok=true,Presentation=self._stands:Context()}end
 if action=="Inventory" then
  if not self:_players():IsShopDataReady(player)then return {Ok=false,Code="DataNotLoaded"}end
  local data=self:_players():GetPlayerData(player)
  if self._stock then Engine.Reconcile(data,self._stock)end
  return {Ok=true,Inventory=Inventory.Extend(data.Inventory),Snapshot={Coins=data.Coins,Inventory=Inventory.Copy(data.Inventory)}}
 end
 if type(args.CrateId)~="string" or #args.CrateId>64 then return {Ok=false,Code="InvalidCrateId"}end
 if action=="Quote"then return self:Quote(player,args.CrateId)end
 if action~="Purchase" and action~="Open"then return {Ok=false,Code="InvalidAction"}end
 if action=="Open"and not Batch.Quantity(args.Quantity)then return {Ok=false,Code="InvalidQuantity"}end
 if type(args.OperationId)~="string" or #args.OperationId>64 or not args.OperationId:match("^[%w_%-]+$")then return {Ok=false,Code="InvalidOperationId"}end
 local result;local shop=self._context:GetService("ShopService")
 local ok,code=shop:_withShopLock(player,function()
  local function perform()return self:_transact(player,action,args)end
  result=if action=="Open"and self._stands then self._stands:Open(player,args,perform)else perform()
  return result.Ok,result.Code
 end)
 return result or {Ok=ok,Code=code}
end
function Service:_present(player,crate,op)
 if self._stands and self._stands:IsStandMode()then
  self._stands:Present(player,crate,op)
 else
 local packet={OpeningId=op.UnitId,Operation=Inventory.Copy(op),Duration=crate.RollDuration,Model=crate.Model,
  VFX=crate.VFX,SFX=crate.SFX,StartedAt=workspace:GetServerTimeNow()}
 self._reveal:FireClient(player,packet)
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 if root and self:_lobby(player)then
  packet.Position=root.Position+root.CFrame.LookVector*5
  for _,observer in ipairs(Players:GetPlayers())do
   local target=observer.Character and observer.Character:FindFirstChild("HumanoidRootPart")
   if target and self:_lobby(observer) and (target.Position-root.Position).Magnitude<=70 then self._world:FireClient(observer,packet)end
  end
 end
 end
 for _,unit in ipairs(Batch.Rewards(op))do
 local v=Catalog.Variations.ById[unit.VariationId]
 if v.AnnounceInChat then
  -- TextChatService system message uses only server-selected catalogue data and numeric UserId.
  self._announcements:AnnounceOnce(unit.UnitId,{OpeningId=unit.UnitId,UserId=player.UserId,PlayerName=player.Name,RewardId=unit.RewardId,CrateId=crate.CrateId})
 end
 end
end
function Service:ResolveEquipped(player)
 local ps=self:_players();if not ps:IsShopDataReady(player)then return Catalog.Rewards[Catalog.DefaultRewardId]end
 local inv=Inventory.Extend(ps:GetInventory(player));local id=inv.Equipped.Slaps
 return if Catalog.Rewards[id] and inv.Owned.Slaps[id] and self:_resource(Catalog.Rewards[id])then Catalog.Rewards[id] else Catalog.Rewards[Catalog.DefaultRewardId]
end
function Service:GetSlapModel(reward)return Catalog.Slaps.ById[reward.SlapId].Model end
function Service:GetRewardTemplate(reward)
 local slap=reward and Catalog.Slaps.ById[reward.SlapId]
 if not slap then return nil end
 local variants=SS:FindFirstChild("SlapVariations")
 local base=variants and variants:FindFirstChild(slap.VariantsFolder or reward.SlapId)
 local authored=base and base:FindFirstChild(reward.VariationId)
 if authored and authored:IsA("Tool")then return authored end
 local slaps=SS:FindFirstChild("Slaps")
 local template=slaps and slaps:FindFirstChild(slap.Model)
 return if template and template:IsA("Tool")then template else nil
end
function Service:ApplyVariation(tool,reward)
 local profile=RS:FindFirstChild("SlapVariationEffects")
 local definition=Catalog.Variations.ById[reward.VariationId]
 local template=profile and profile:FindFirstChild(definition.VisualProfile)
 tool:SetAttribute("RewardId",reward.RewardId);tool:SetAttribute("VariationId",reward.VariationId)
 tool:SetAttribute("DisplayName",reward.DisplayName)
 local hand=tool:FindFirstChild("Hand")
 if hand and hand:GetAttribute("SlapVariationAuthored")==true then return end
 local slap=Catalog.Slaps.ById[reward.SlapId]
 local variants=SS:FindFirstChild('SlapVariations')
 local folder=variants and variants:FindFirstChild(slap.VariantsFolder or reward.SlapId)
 local authored=folder and folder:FindFirstChild(reward.VariationId)
 if hand and authored and authored:IsA('Tool')then hand:SetAttribute('SlapVariationAuthored',true);return end
 if template and hand and hand:IsA("BasePart")then
  Appearance.Apply(hand,template)
  for _,child in ipairs(template:GetChildren())do
   if child:IsA("Sound") and child.Name=="Hit" and child.SoundId~=""then
    local original=hand:FindFirstChild("Hit")
    if original and original:IsA("Sound")then original.SoundId=child.SoundId;original.Volume=child.Volume;original.PlaybackSpeed=child.PlaybackSpeed end
   end
  end
 end
end
function Service:Start(context)
 self._context=context
 local remotes=ensure(ensure(RS,"Remotes","Folder"),"Crates","Folder")
 self._reveal=ensure(remotes,"Reveal","RemoteEvent");self._world=ensure(remotes,"World","RemoteEvent");self._announce=ensure(remotes,"Announce","RemoteEvent")
 if self._stands then self._stands:Start(ensure(remotes,"StandPresentation","RemoteEvent"))end
 local request=ensure(remotes,"Request","RemoteFunction")
 request.OnServerInvoke=function(p,action,args)
  local ok,result=pcall(self.Request,self,p,action,args)
  if not ok then warn("[Crates] Request failed safely: "..tostring(result));return {Ok=false,Code="InternalError"}end
  return result
 end
 local factory=require(script.Parent.Parent.Shop.Providers.CrateProviders)
 local shop=context:GetService("ShopService")
 for _,provider in ipairs(factory.Create(self))do if not shop:GetProvider(provider:GetCategory())then shop:RegisterProvider(provider)end end
 table.insert(self._connections,Players.PlayerRemoving:Connect(function(p)self._quotes[p]=nil;self._premiumQuotes[p]=nil;self._rate[p]=nil;self._cancelRate[p]=nil end))
 print("[Crates] Stock="..(self._stock and self._stock.Scope or "Unavailable"))
end
return Service
