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
local Engine=require(script.Parent.Crates.CrateEngine)
local Stock=require(script.Parent.Crates.InMemoryStock)
local Announcements=require(script.Parent.Crates.AnnouncementAdapter)
local Service={Name="CrateService"}
local function ensure(parent,name,class)
 local obj=parent:FindFirstChild(name)
 if obj then assert(obj:IsA(class),"Crate resource class conflict: "..name);return obj end
 obj=Instance.new(class);obj.Name=name;obj.Parent=parent;return obj
end
function Service:Init(context)
 self._context=context;self._quotes={};self._rate={};self._connections={}
 self._announcements=Announcements.new(function(packet)self._announce:FireAllClients(packet)end)
 self._stock=if RunService:IsStudio() and context.PersistenceInfo and context.PersistenceInfo.Environment=="Studio" and context.PersistenceInfo.ProviderName=="InMemory"
  and context.PersistenceInfo.WritesToCloud==false then Stock.new() else nil
 self._rng=Random.new()
end
function Service:_players()return self._context:GetService("PlayerService")end
function Service:ExtendInventory(inv)return Inventory.Extend(inv)end
function Service:_lobby(player)
 local rounds=self._context:GetService("RoundService")
 return player.Parent==Players and not player:GetAttribute("MatchId") and not player:GetAttribute("ResultsSessionId")
  and rounds~=nil and rounds:GetSessionForPlayer(player)==nil
end
function Service:_resource(reward)
 local slap=Catalog.Slaps.ById[reward.SlapId];local v=Catalog.Variations.ById[reward.VariationId]
 local slaps=SS:FindFirstChild("Slaps");local tool=slaps and slap and slaps:FindFirstChild(slap.Model)
 local profiles=RS:FindFirstChild("SlapVariationEffects")
 if not tool or not tool:IsA("Tool") or not v or not profiles or not profiles:FindFirstChild(v.VisualProfile)then return false end
 local config=tool:FindFirstChild("Configuration");local power=config and config:FindFirstChild("Power");local cooldown=config and config:FindFirstChild("SlapCooldown")
 local previews=RS:FindFirstChild("CrateRewardPreviews")
 return power~=nil and power:IsA("NumberValue") and power.Value>0 and power.Value<math.huge
  and cooldown~=nil and cooldown:IsA("NumberValue") and cooldown.Value>=0 and cooldown.Value<math.huge
  and previews~=nil and previews:FindFirstChild(reward.SlapId)~=nil
end
function Service:_eligible(player,crate)
 if not self._stock then return false,"ProductionBackendBlocked" end
 if not crate or (crate.StudioOnly and (not RunService:IsStudio() or SS:GetAttribute("CrateStudioTestsEnabled")~=true)) then return false,"CrateUnavailable" end
 if not Engine.Approved(crate) then return false,"CommercialApprovalPending" end
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
 local crate=Catalog.Crates.ById[id];local ok,reason=self:_eligible(player,crate)
 if not ok then return {Ok=false,Code=reason} end
 local data=self:_players():GetPlayerData(player)
 local inv=Inventory.Extend(data.Inventory);local valid,err=Inventory.Validate(inv)
 if not valid then return {Ok=false,Code=err} end
 local rows,why=Odds.Resolve(crate,Catalog,inv,self._stock,function(r)return self:_resource(r)end)
 if not rows then return {Ok=false,Code=why} end
 local token=Http:GenerateGUID(false)
 self._quotes[player]={Token=token,CrateId=id,Until=os.clock()+30,Signature=signature(rows,crate)}
 local outcomes={}
 for _,row in ipairs(rows)do table.insert(outcomes,{RewardId=row.Reward.RewardId,DisplayName=row.Reward.DisplayName,
  SlapId=row.Reward.SlapId,VariationId=row.Reward.VariationId,Percent=row.Percent,Stock=row.Stock})end
 return {Ok=true,Token=token,Outcomes=outcomes,Scope=self._stock.Scope,PriceCoins=crate.PriceCoins,
  ExpiresAt=workspace:GetServerTimeNow()+30,Snapshot={Coins=data.Coins,Inventory=Inventory.Copy(data.Inventory)}}
end
function Service:_transact(player,kind,args)
 local crate=Catalog.Crates.ById[args.CrateId];local ok,why=self:_eligible(player,crate)
 if not ok then return {Ok=false,Code=why} end
 local ps=self:_players();local data=ps:GetPlayerData(player)
 local inv=Inventory.Extend(data.Inventory)
 local existing=inv.CrateOperations[args.OperationId]
 if not existing then
  local q=self._quotes[player]
  if not q or q.Token~=args.QuoteToken or q.CrateId~=args.CrateId or os.clock()>=q.Until then return {Ok=false,Code="ViewOddsFirst"} end
  local rows,reason=Odds.Resolve(crate,Catalog,inv,self._stock,function(r)return self:_resource(r)end)
  if not rows then return {Ok=false,Code=reason}end
  if q.Signature~=signature(rows,crate)then return {Ok=false,Code="OddsChanged"}end
 end
 local nextData,err,op,replayed=Engine.Stage(data,crate,kind,args.OperationId,player.UserId,Catalog,self._stock,self._rng:NextNumber(),function(r)return self:_resource(r)end)
 if not nextData then return {Ok=false,Code=err}end
 if not replayed then
  local committed,reason=ps:CommitCrateState(player,data.Inventory,nextData)
  if not committed then
   if op.UnitId then self._stock:Release(op.UnitId)end
   return {Ok=false,Code=reason}
  end
 end
 -- Idempotent recovery after profile commit. A failed stock commit retains the reservation, never rerolls.
 Engine.Reconcile(nextData,self._stock)
 if kind=="Open" and not replayed then self:_present(player,crate,op)end
 return {Ok=true,Operation=Inventory.Copy(op),Replay=replayed,Crates=Inventory.Copy(nextData.Inventory.Crates),
  Snapshot={Coins=nextData.Coins,Inventory=Inventory.Copy(nextData.Inventory)}}
end
function Service:GetCatalog()
 local results={}
 for _,id in ipairs(Catalog.Crates.Order)do
  local c=Catalog.Crates.ById[id]
  if c.StudioOnly and (not RunService:IsStudio() or SS:GetAttribute("CrateStudioTestsEnabled")~=true)then continue end
  table.insert(results,{Id=id,SortOrder=c.SortOrder,Category="Crates",ProductType="Consumable",DisplayName=c.DisplayName,Description=c.Description,
   Price=c.PriceCoins or 0,Currency="Coins",Icon=c.Icon,Rarity=id,IsAvailable=true,
   Metadata={PriceApproved=c.PriceApproved==true,PricePending=not c.PriceApproved,OddsApproved=c.OddsApproved==true,Enabled=c.Enabled==true,
    PurchaseEnabled=Engine.Approved(c) and self._stock~=nil,Model=c.Model,
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
 local t=os.clock();if t<(self._rate[player] or 0)then return {Ok=false,Code="RateLimited"}end
 self._rate[player]=t+.25
 if action=="Inventory" then
  if not self:_players():IsShopDataReady(player)then return {Ok=false,Code="DataNotLoaded"}end
  local data=self:_players():GetPlayerData(player)
  if self._stock then Engine.Reconcile(data,self._stock)end
  return {Ok=true,Inventory=Inventory.Extend(data.Inventory),Snapshot={Coins=data.Coins,Inventory=Inventory.Copy(data.Inventory)}}
 end
 if type(args.CrateId)~="string" or #args.CrateId>64 then return {Ok=false,Code="InvalidCrateId"}end
 if action=="Quote"then return self:Quote(player,args.CrateId)end
 if action~="Purchase" and action~="Open"then return {Ok=false,Code="InvalidAction"}end
 if type(args.OperationId)~="string" or #args.OperationId>64 or not args.OperationId:match("^[%w_%-]+$")then return {Ok=false,Code="InvalidOperationId"}end
 local result;local shop=self._context:GetService("ShopService")
 local ok,code=shop:_withShopLock(player,function()
  result=self:_transact(player,action,args);return result.Ok,result.Code
 end)
 return result or {Ok=ok,Code=code}
end
function Service:_present(player,crate,op)
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
 local v=Catalog.Variations.ById[op.VariationId]
 if v.AnnounceInChat then
  -- TextChatService system message uses only server-selected catalogue data and numeric UserId.
  self._announcements:AnnounceOnce(op.UnitId,{OpeningId=op.UnitId,UserId=player.UserId,PlayerName=player.Name,RewardId=op.RewardId,CrateId=crate.CrateId})
 end
end
function Service:ResolveEquipped(player)
 local ps=self:_players();if not ps:IsShopDataReady(player)then return Catalog.Rewards[Catalog.DefaultRewardId]end
 local inv=Inventory.Extend(ps:GetInventory(player));local id=inv.Equipped.Slaps
 return if Catalog.Rewards[id] and inv.Owned.Slaps[id] and self:_resource(Catalog.Rewards[id])then Catalog.Rewards[id] else Catalog.Rewards[Catalog.DefaultRewardId]
end
function Service:GetSlapModel(reward)return Catalog.Slaps.ById[reward.SlapId].Model end
function Service:ApplyVariation(tool,reward)
 local profile=RS:FindFirstChild("SlapVariationEffects")
 local definition=Catalog.Variations.ById[reward.VariationId]
 local template=profile and profile:FindFirstChild(definition.VisualProfile)
 tool:SetAttribute("RewardId",reward.RewardId);tool:SetAttribute("VariationId",reward.VariationId)
 tool:SetAttribute("DisplayName",reward.DisplayName)
 local hand=tool:FindFirstChild("Hand")
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
 local request=ensure(remotes,"Request","RemoteFunction")
 request.OnServerInvoke=function(p,action,args)
  local ok,result=pcall(self.Request,self,p,action,args)
  if not ok then warn("[Crates] Request failed safely: "..tostring(result));return {Ok=false,Code="InternalError"}end
  return result
 end
 local factory=require(script.Parent.Parent.Shop.Providers.CrateProviders)
 local shop=context:GetService("ShopService")
 for _,provider in ipairs(factory.Create(self))do if not shop:GetProvider(provider:GetCategory())then shop:RegisterProvider(provider)end end
 table.insert(self._connections,Players.PlayerRemoving:Connect(function(p)self._quotes[p]=nil;self._rate[p]=nil end))
 print("[Crates] SalesProduction=BLOCKED Stock="..(self._stock and self._stock.Scope or "Unavailable"))
end
return Service
