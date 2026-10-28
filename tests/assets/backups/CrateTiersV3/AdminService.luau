--!nonstrict
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local Http=game:GetService('HttpService')
local Folder=script.Parent.Parent.Admin
local Access=require(Folder.Access)
local Registry=require(Folder.CommandRegistry)
local Catalog=require(RS.Shared.SlapCrates.Catalog)
local Service={Name='AdminService'}
function Service:IsAdmin(player)
 if not player or player.Parent~=Players or Players:GetPlayerByUserId(player.UserId)~=player then return false end
 return Access.UserIds[player.UserId]==true or Run:IsStudio()and Access.StudioUserIds[player.UserId]==true
end
function Service:IsGrantableSlap(id)
 local reward=Catalog.Rewards[id];if not reward or reward.LimitedStock or reward.PremiumOnly then return false end
 local variation=Catalog.Variations.ById[reward.VariationId];local slap=Catalog.Slaps.ById[reward.SlapId]
 return variation and not variation.LimitedStock and not variation.PremiumOnly and slap and not slap.PremiumOnly
  and self.Slaps:GetSlapTemplate(slap.Model)~=nil
end
function Service:Info()
 local players={};for _,p in ipairs(Players:GetPlayers())do table.insert(players,{UserId=p.UserId,Username=p.Name,DisplayName=p.DisplayName})end
 table.sort(players,function(a,b)return a.UserId<b.UserId end)
 local slaps={};for id,r in pairs(Catalog.Rewards)do if self:IsGrantableSlap(id)then table.insert(slaps,{Id=id,Label=r.DisplayName})end end
 table.sort(slaps,function(a,b)return a.Id<b.Id end)
 return {Ok=true,Commands=Registry.Public(self.Registry),Players=players,Slaps=slaps}
end
function Service:Audit(actor,command,target,result,operation)
 local row={ActorUserId=actor.UserId,Command=command,TargetUserId=target,OperationId=operation,Ok=result.Ok==true,Reason=result.Reason,Timestamp=os.time()}
 table.insert(self.AuditRows,row);if #self.AuditRows>Access.MaxAuditEntries then table.remove(self.AuditRows,1)end
 print('[AdminAudit] '..Http:JSONEncode(row))
end
function Service:Request(actor,action,requestId,commandId,args)
 -- This check is repeated on EVERY call; button visibility is never authorization.
 if not self:IsAdmin(actor)then return {Ok=false,Reason='Forbidden'}end
 local now=workspace:GetServerTimeNow()
 if now-(self.LastRequest[actor]or -math.huge)<Access.RequestInterval then return {Ok=false,Reason='RateLimited'}end
 self.LastRequest[actor]=now
 if action=='Info'then return self:Info()end
 if action~='Execute'or type(requestId)~='string'or #requestId<8 or #requestId>96 or requestId:find('[^%w_%-]')or type(commandId)~='string'then return {Ok=false,Reason='InvalidRequest'}end
 local command=self.Registry.ById[commandId];if not command then return {Ok=false,Reason='UnknownCommand'}end
 local ok,clean=Registry.Validate(command,args,{IsStudio=Run:IsStudio(),Player=function(id)return Players:GetPlayerByUserId(id)end,Slap=function(id)return self:IsGrantableSlap(id)end})
 if not ok then return {Ok=false,Reason=clean}end
 local cache=self.Operations[actor];if not cache then cache={Count=0,Rows={}};self.Operations[actor]=cache end
 local signature=commandId;for _,field in ipairs(command.Fields)do signature..='|'..field.Name..'='..tostring(clean[field.Name])end
 local previous=cache.Rows[requestId]
 if previous then
  if previous.Signature~=signature then return {Ok=false,Reason='RequestIdConflict'}end
  return previous.Result or {Ok=false,Reason='OperationPending'}
 end
 if cache.Count>=Access.MaxRequestsPerAdminSession then return {Ok=false,Reason='SessionRequestLimit'}end
 local target=Players:GetPlayerByUserId(clean.TargetUserId)
 if not target or not self.Profiles:IsShopDataReady(target)then return {Ok=false,Reason='DataNotLoaded'}end
 local operation='Admin:'..Http:GenerateGUID(false)
 local record={Signature=signature};cache.Rows[requestId]=record;cache.Count+=1
 local success,result=pcall(command.Execute,{Actor=actor,Target=target,OperationId=operation,PlayerService=self.Profiles},clean)
 if not success or type(result)~='table'then result={Ok=false,Reason='ExecutionFailedNoAutoRetry'}end
 result.OperationId=operation;record.Result=result
 self:Audit(actor,commandId,target.UserId,result,operation)
 return result
end
function Service:Init(context)
 self.Context=context;self.Profiles=context:GetService('PlayerService');self.Slaps=context:GetService('SlapService')
 assert(self.Profiles and self.Slaps,'Admin dependencies missing')
 self.LastRequest={};self.Operations={};self.AuditRows={};self.Connections={}
 self.Registry=Registry.Build(require(Folder.CommandManifest),function(name)
  local found;for _,obj in ipairs(Folder.Commands:GetChildren())do if obj.Name==name then assert(not found,'Duplicate admin module');found=obj end end
  assert(found and found:IsA('ModuleScript'),'Unauthorized/missing admin module');return require(found)
 end)
 local remotes=RS:WaitForChild('Remotes');local folder=remotes:FindFirstChild('Admin')
 if not folder then folder=Instance.new('Folder');folder.Name='Admin';folder.Parent=remotes end
 local request=folder:FindFirstChild('Request');if not request then request=Instance.new('RemoteFunction');request.Name='Request';request.Parent=folder end
 assert(request:IsA('RemoteFunction'),'Admin remote class mismatch');self.Remote=request
end
function Service:Start()
 self.Remote.OnServerInvoke=function(actor,...)return self:Request(actor,...)end
 local function bind(p)p:SetAttribute('AdminPanelAllowed',self:IsAdmin(p))end
 for _,p in ipairs(Players:GetPlayers())do bind(p)end
 table.insert(self.Connections,Players.PlayerAdded:Connect(bind))
 table.insert(self.Connections,Players.PlayerRemoving:Connect(function(p)self.LastRequest[p]=nil;self.Operations[p]=nil end))
end
return Service
