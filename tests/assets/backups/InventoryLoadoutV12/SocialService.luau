--!nonstrict
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local Http=game:GetService('HttpService')
local Config=require(RS.Shared.SocialConfig)
local Catalog=require(RS.Shared.SlapCrates.Catalog)
local Public=require(script.Parent.Trading.PublicInventory)
local Engine=require(script.Parent.Trading.TradeEngine)
local Transaction=require(script.Parent.Trading.TradeTransactionService)
local Service={Name='SocialService'}
local function uid(n)return type(n)=='number'and n==n and n~=0 and math.abs(n)<9007199254740992 and n%1==0 end
function Service:Eligible(id)
 local p=uid(id)and Players:GetPlayerByUserId(id)
 if not p or p.Parent~=Players or not self.Profiles:IsShopDataReady(p)then return false end
 if self.Rounds:GetSessionForPlayer(p)then return false end
 local c=p.Character;local h=c and c:FindFirstChildOfClass('Humanoid');local root=c and c:FindFirstChild('HumanoidRootPart')
 return c~=nil and c:IsDescendantOf(workspace)and h~=nil and h.Health>0 and root~=nil and root:IsA('BasePart')
end
function Service:Distance(a,b)
 local x=Players:GetPlayerByUserId(a);local y=Players:GetPlayerByUserId(b)
 local r=x and x.Character and x.Character:FindFirstChild('HumanoidRootPart');local s=y and y.Character and y.Character:FindFirstChild('HumanoidRootPart')
 return r and s and (r.Position-s.Position).Magnitude or math.huge
end
function Service:Unit(id,key)
 local p=Players:GetPlayerByUserId(id)
 if not p or not self.Profiles:IsShopDataReady(p)then return nil end
 for _,row in ipairs(Public.Build(self.Profiles:GetPlayerData(p),id,Catalog))do if row.UnitId==key then return row end end
end
function Service:AllowRequest(p)
 local now=workspace:GetServerTimeNow();local last=self.LastRequest[p]or -math.huge
 if now-last<Config.RequestIntervalSeconds then return false end
 self.LastRequest[p]=now;return true
end
function Service:Inspect(p,targetId,page)
 if not self:AllowRequest(p)then return {Ok=false,Reason='RateLimited'}end
 page=page or 1
 if not Config.ProfileInspectionEnabled or not uid(targetId)or type(page)~='number'or page~=page or page%1~=0 or page<1 or page>10000 then return {Ok=false,Reason='InvalidRequest'}end
 local ok,why=self.Engine:_pair(p.UserId,targetId,true)
 if not ok then return {Ok=false,Reason=why}end
 local target=Players:GetPlayerByUserId(targetId)
 local result=Public.Profile(target,self.Profiles:GetPlayerData(target),Catalog,Config,page)
 result.ProfileMode='OtherPlayerProfile'
 local play=self.Context and self.Context:GetService('SocialPlayService');if play then play:Decorate(p,result)end
 self.Viewers[p]=targetId;return {Ok=true,Profile=result}
end
-- No target or client mode argument: the authenticated caller owns this read-only view.
function Service:SelfProfile(p,page)
 if not self:AllowRequest(p)then return {Ok=false,Reason='RateLimited'}end
 if page==nil then page=1 end
 if not Config.ProfileInspectionEnabled or type(page)~='number'or page~=page or page%1~=0 or page<1 or page>10000 then return {Ok=false,Reason='InvalidRequest'}end
 if not uid(p.UserId)or Players:GetPlayerByUserId(p.UserId)~=p or not self:Eligible(p.UserId)then return {Ok=false,Reason='PlayerUnavailable'}end
 local data=self.Profiles:GetPlayerData(p)
 local count=#Public.Build(data,p.UserId,Catalog)
 page=math.min(page,math.max(1,math.ceil(count/Config.InventoryPageSize)))
 local result=Public.Profile(p,data,Catalog,Config,page)
 result.ProfileMode='SelfProfile'
 local play=self.Context and self.Context:GetService('SocialPlayService');if play then play:Decorate(p,result)end
 self.Viewers[p]=p.UserId
 return {Ok=true,Profile=result}
end
function Service:Action(p,action,id,revision,value)
 if not self:AllowRequest(p)then return {Ok=false,Reason='RateLimited'}end
 if action=='Invite'then
  if not uid(id)then return {Ok=false,Reason='InvalidTarget'}end
  local target=Players:GetPlayerByUserId(id)
  if target and target:GetAttribute('TradeInvitationsDisabled')==true then return {Ok=false,Reason='InvitationsDisabled'}end
  local ok,why=self.Engine:Invite(p.UserId,id);return {Ok=ok,Reason=ok and nil or why,TradeId=ok and why or nil}
 end
 if type(action)~='string'or #action>16 or type(id)~='string'or #id>128 or type(revision)~='number'or revision~=revision or revision<0 or revision%1~=0 then return {Ok=false,Reason='InvalidRequest'}end
 if action=='Inventory'then
  local t=self.Engine.Trades[id]
  if not t or t.Terminal or (p.UserId~=t.A and p.UserId~=t.B)or t.Revision~=revision or not self:Eligible(p.UserId)then return {Ok=false,Reason='NotParticipant'}end
  local page=value or 1
  if type(page)~='number'or page~=page or page%1~=0 or page<1 or page>10000 then return {Ok=false,Reason='InvalidPage'}end
  return {Ok=true,Profile=Public.Profile(p,self.Profiles:GetPlayerData(p),Catalog,Config,page)}
 end
 local ok,why=self.Engine:Act(p.UserId,action,id,revision,value);return {Ok=ok,Reason=why}
end
function Service:Init(context)
 self.Context=context;self.Profiles=context:GetService('PlayerService');self.Rounds=context:GetService('RoundService')
 assert(self.Profiles and self.Rounds,'Social dependencies unavailable')
 self.LastRequest={};self.Viewers={};self.Connections={};self.CharacterConnections={}
 local remotes=RS:WaitForChild('Remotes');local folder=remotes:FindFirstChild('Social')
 local function ensure(parent,name,class)local p=parent:FindFirstChild(name);if p then assert(p:IsA(class),'Social remote class mismatch');return p end;local n=Instance.new(class);n.Name=name;n.Parent=parent;return n end
 folder=folder or ensure(remotes,'Social','Folder')
 self.Update=ensure(folder,'Updated','RemoteEvent')
 self.SelfProfileRemote=ensure(folder,'SelfProfile','RemoteFunction')
 self.InspectRemote=ensure(folder,'Inspect','RemoteFunction');self.ActionRemote=ensure(folder,'Action','RemoteFunction')
 self.Engine=Engine.new(Config,{
  Clock=function()return workspace:GetServerTimeNow()end,Id=function()return Http:GenerateGUID(false)end,
  Eligible=function(id)return self:Eligible(id)end,Distance=function(a,b)return self:Distance(a,b)end,
  Name=function(id)local p=Players:GetPlayerByUserId(id);return p and p.DisplayName or 'Desconectado'end,
  Unit=function(id,key)return self:Unit(id,key)end,Commit=Transaction.Commit,
  Emit=function(id,kind,payload)local p=Players:GetPlayerByUserId(id);if p then self.Update:FireClient(p,kind,payload)end end,
 })
 self.CommitAvailable,self.CommitReason=Transaction.Availability(Config,context.PersistenceInfo,RunService:IsStudio())
 assert(not self.CommitAvailable,'Real trade commit must remain disabled')
end
function Service:ValidateViewers()
  for p,target in pairs(self.Viewers)do
   if not self:Eligible(p.UserId)or not self:Eligible(target)or (p.UserId~=target and not(self:Distance(p.UserId,target)<=Config.InspectDistance))then
    self.Viewers[p]=nil;if p.Parent==Players then self.Update:FireClient(p,'ProfileUnavailable',{UserId=target})end
   end
  end
end
function Service:Start()
 self.SelfProfileRemote.OnServerInvoke=function(p,page)return self:SelfProfile(p,page)end
 self.InspectRemote.OnServerInvoke=function(p,...)return self:Inspect(p,...)end
 self.ActionRemote.OnServerInvoke=function(p,...)return self:Action(p,...)end
 local function bind(p)
  if self.CharacterConnections[p]then self.CharacterConnections[p]:Disconnect()end
  self.CharacterConnections[p]=p.CharacterRemoving:Connect(function()self.Engine:CancelForPlayer(p.UserId)end)
 end
 for _,p in ipairs(Players:GetPlayers())do bind(p)end
 table.insert(self.Connections,Players.PlayerAdded:Connect(bind))
 table.insert(self.Connections,Players.PlayerRemoving:Connect(function(p)
  self.Engine:Disconnect(p.UserId);self.Viewers[p]=nil;self.LastRequest[p]=nil
  if self.CharacterConnections[p]then self.CharacterConnections[p]:Disconnect();self.CharacterConnections[p]=nil end
 end))
 local elapsed=0
 table.insert(self.Connections,RunService.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<0.25 then return end;elapsed=0;self.Engine:Tick()
  self:ValidateViewers()
 end))
 print('[SocialService] Inspection/invitations ready; TradeCommitEnabled=false; '..self.CommitReason)
end
return Service
