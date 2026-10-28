--!nonstrict
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local Http=game:GetService('HttpService')
local Config=require(RS.Shared.SocialPlayConfig)
local SocialConfig=require(RS.Shared.SocialConfig)
local Engine=require(script.Parent.Gameplay.SocialPlayEngine)
local Service={Name='SocialPlayService'}
local function uid(id)return type(id)=='number'and id==id and id~=0 and id%1==0 and math.abs(id)<9007199254740992 end
function Service:Eligible(id)
 local p=uid(id)and Players:GetPlayerByUserId(id)
 if not p or p.Parent~=Players or not self.Profiles:IsShopDataReady(p)or self.Rounds:GetSessionForPlayer(p)then return false end
 local c=p.Character;local h=c and c:FindFirstChildOfClass('Humanoid')
 if not c or not c:IsDescendantOf(workspace)or not h or h.Health<=0 then return false end
 if self.Matchmaking:IsPlayerQueued(p)then return false end
 local social=self.Context:GetService('SocialService')
 return not(social and social.Engine and social.Engine.Busy[id])
end
function Service:Near(a,b)
 local p=Players:GetPlayerByUserId(a);local q=Players:GetPlayerByUserId(b)
 local x=p and p.Character and p.Character:FindFirstChild('HumanoidRootPart')
 local y=q and q.Character and q.Character:FindFirstChild('HumanoidRootPart')
 return x and y and (x.Position-y.Position).Magnitude<=SocialConfig.InspectDistance or false
end
function Service:Decorate(viewer,profile)
 local id=profile.UserId;local own=id==viewer.UserId
 profile.Actions={Challenge=not own and self.Engine:CanChallenge(viewer.UserId,id)and self:Near(viewer.UserId,id),
  Invite=not own and not self.Engine:Group(id)and self:Eligible(viewer.UserId)and self:Eligible(id)}
 return profile
end
function Service:StartDuel(grant)
 local a=Players:GetPlayerByUserId(grant.A);local b=Players:GetPlayerByUserId(grant.B)
 if not self:Eligible(grant.A)or not self:Eligible(grant.B)or self.Engine:Group(grant.A)or self.Engine:Group(grant.B)then return false,'PlayerUnavailable'end
 return self.Rounds:StartTeamMatch({ZoneId=grant.ZoneId,Mode='1v1',TeamSize=1,RedTeam={a},BlueTeam={b},ReservationToken=grant.Token})
end
function Service:FindGrant(zone,red,blue)
 local grant=self.Engine.Grants[zone]
 if not grant or workspace:GetServerTimeNow()>=grant.ExpiresAt or #red~=1 or #blue~=1 then return nil end
 if red[1]~=Players:GetPlayerByUserId(grant.A)or blue[1]~=Players:GetPlayerByUserId(grant.B)or self.Engine:Group(grant.A)or self.Engine:Group(grant.B)then return nil end
 return grant
end
function Service:ValidateDuel(token,request)
 local g=self:FindGrant(request.ZoneId,request.RedTeam,request.BlueTeam)
 return g~=nil and not g.Consumed and g.Token==token and request.Mode=='1v1'and request.TeamSize==1,'InvalidDuelReservation'
end
function Service:ConsumeDuel(token)
 for _,g in pairs(self.Engine.Grants)do if g.Token==token and not g.Consumed then g.Consumed=true;return true end end
 return false
end
function Service:DuelPrepared(zone,red,blue)
 local g=self:FindGrant(zone,red,blue)
 if not g or not g.Consumed then return false end
 local a=self.Rounds:GetSessionForPlayer(red[1]);local b=self.Rounds:GetSessionForPlayer(blue[1])
 return a~=nil and a==b and a.ZoneId==zone and not a.Closing and not a.Cancelled
end
function Service:ReleaseDuel(zone,token)
 local g=self.Engine.Grants[zone];if g and g.Token==token then self.Engine.Grants[zone]=nil end
end
function Service:CanQueueTeam(players,size)return self.Engine:CanQueueTeam(players,size)end
function Service:Request(p,action,id,value)
 local now=workspace:GetServerTimeNow()
 if now-(self.LastRequest[p]or -math.huge)<Config.RequestInterval then return {Ok=false,Reason='RateLimited'}end
 self.LastRequest[p]=now
 if action=='State'then return {Ok=true,Group=self.Engine:GroupView(p.UserId)}end
 local ok,why
 if (action=='Duel'or action=='Group')and uid(id)then ok,why=self.Engine:Invite(p.UserId,id,action)
 elseif action=='Respond'and type(id)=='string'and #id<=128 and type(value)=='boolean'then ok,why=self.Engine:Respond(p.UserId,id,value)
 elseif action=='Leave'then ok,why=self.Engine:Leave(p.UserId,false)
 elseif action=='Disband'then ok,why=self.Engine:Leave(p.UserId,true)
 else return {Ok=false,Reason='InvalidRequest'}end
 return {Ok=ok,Reason=ok and nil or why}
end
function Service:Init(context)
 self.Context=context;self.Profiles=context:GetService('PlayerService');self.Rounds=context:GetService('RoundService');self.Matchmaking=context:GetService('MatchmakingService')
 assert(self.Profiles and self.Rounds and self.Matchmaking,'SocialPlay dependencies missing')
 self.Connections={};self.LastRequest={}
 local remotes=RS:WaitForChild('Remotes')
 local function ensure(parent,name,class)
  local obj=parent:FindFirstChild(name);if obj then assert(obj:IsA(class),'SocialPlay class mismatch');return obj end
  obj=Instance.new(class);obj.Name=name;obj.Parent=parent;return obj
 end
 local folder=ensure(remotes,'SocialPlay','Folder');self.Remote=ensure(folder,'Request','RemoteFunction');self.Update=ensure(folder,'Updated','RemoteEvent')
 self.Engine=Engine.new(Config,{Clock=function()return workspace:GetServerTimeNow()end,Id=function()return Http:GenerateGUID(false)end,
  Eligible=function(id)return self:Eligible(id)end,Near=function(a,b)return self:Near(a,b)end,
  Name=function(id)local p=Players:GetPlayerByUserId(id);return p and p.DisplayName or 'Desconectado'end,
  GroupChanged=function(id,group)local p=Players:GetPlayerByUserId(id);if p then p:SetAttribute('SocialGroupId',group)end end,
  Emit=function(id,kind,data)local p=Players:GetPlayerByUserId(id);if p and p.Parent==Players then self.Update:FireClient(p,kind,data)end end,
  StartDuel=function(g)return self:StartDuel(g)end})
end
function Service:Start()
 self.Remote.OnServerInvoke=function(p,...)return self:Request(p,...)end
 table.insert(self.Connections,Players.PlayerRemoving:Connect(function(p)self.Engine:Disconnect(p.UserId);self.LastRequest[p]=nil end))
 local elapsed=0
 table.insert(self.Connections,Run.Heartbeat:Connect(function(dt)elapsed+=dt;if elapsed>=Config.RequestInterval then elapsed=0;self.Engine:Tick()end end))
end
return Service
