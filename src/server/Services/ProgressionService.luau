--!nonstrict
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local Http=game:GetService('HttpService')
local M=require(RS.Shared.Progression.Model)
local Config=require(RS.Shared.Progression.Config)
local Catalog=require(RS.Shared.Progression.PassCatalog)
local Slaps=require(RS.Shared.SlapCrates.Catalog)
local SeasonState=require(script.Parent.Gameplay.SeasonState)
local Service={Name='ProgressionService'}
local KEY='Progression:Season:Studio:v1'
local function ensure(parent,name,class)
 local o=parent:FindFirstChild(name);if o then assert(o:IsA(class),'Progression class conflict');return o end
 o=Instance.new(class);o.Name=name;o.Parent=parent;return o
end
function Service:Init(context)
 self.Context=context;self.Sessions={};self.Connections={};self.Rate={};self.Challenges={};self.Season={Revision=0};self.SeasonAvailable=false
 local info=context.PersistenceInfo
 self.Enabled=Run:IsStudio()and info and info.Environment=='Studio'and info.ProviderName=='InMemory'and info.WritesToCloud==false
 self.Production=not Run:IsStudio()and Config.ProductionEnabled==true and info and info.Environment=='Production'and info.ProviderName=='RobloxDataStore'and info.WritesToCloud==true and info.GameId==10769217377
 self.Enabled=self.Enabled or self.Production
 self.SeasonKey=self.Production and 'Progression:Season:Production:v1'or KEY
 self.Store=self.Enabled and context.PersistenceProvider or nil
 local folder=ensure(ensure(RS,'Remotes','Folder'),'Progression','Folder')
 self.Remote=ensure(folder,'Request','RemoteFunction');self.Changed=ensure(folder,'Changed','RemoteEvent')
end
function Service:ReadSeason()
 if not self.Enabled then return false end
 local ok,row=pcall(self.Store.GetAsync,self.Store,self.SeasonKey or KEY,true)
 if not ok or row~=nil and not SeasonState.Valid(row)then self.SeasonAvailable=false;return false end
 self.Season=row or {Revision=0};self.SeasonAvailable=true;return true
end
function Service:Snapshot(player)
 local ps=self.Context:GetService('PlayerService');local data=ps:GetPlayerData(player);local p=M.Normalize(data.Progression)
 local level,current,cost=M.Level(p.TotalXP)
 local season=self.SeasonAvailable and self.Season.Active or nil;local active=M.Active(season,os.time())
 local edition=season and p.Edition and p.Edition.Id==season.Id and p.Edition or nil
 return {Ok=true,Enabled=self.Enabled==true,Reason=not self.Enabled and 'StudioOnlyPendingProductionValidation'or not self.SeasonAvailable and 'SeasonUnavailable'or nil,
  TotalXP=p.TotalXP,Level=level,LevelXP=current,LevelCost=cost,Season=M.Copy(season),Revision=self.Season.Revision,
  Active=active,PassXP=edition and edition.XP or 0,Stage=season and M.Stage(p,season)or 0,Claimed=edition and M.Copy(edition.Claimed)or {},ServerTime=workspace:GetServerTimeNow(),PremiumEnabled=false}
end
function Service:Push(player,receipt)
 if player.Parent==Players then self.Changed:FireClient(player,self:Snapshot(player),receipt)end
end
function Service:StateChanged(session,old,new)
 if not self.Enabled then return end
 local track=self.Sessions[session.Id]
 if not track and new=='Playing'then
  local active=self.SeasonAvailable and self.Season.Active
  track={StartedAt=os.time(),EditionId=M.Active(active,os.time())and active.Id or nil,Playing=0,Attacks={}}
  self.Sessions[session.Id]=track
 end
 if not track then return end
 if old=='Playing'and track.Since then track.Playing+=math.max(0,os.clock()-track.Since);track.Since=nil end
 if new=='Playing'then track.Since=os.clock()end
end
function Service:AcceptedAttack(session,player)
 if not self.Enabled or session.State~='Playing'then return end
 local t=self.Sessions[session.Id];if not t then return end
 local a=t.Attacks[player.UserId]or {};t.Attacks[player.UserId]=a
 a.First=a.First or os.clock();a.Last=os.clock()
end
function Service:Settle(session,result)
 local t=self.Sessions[session.Id];if not self.Enabled or not t then return end
 if t.Since then t.Playing+=math.max(0,os.clock()-t.Since);t.Since=nil end
 if not self:ReadSeason()then error('ProgressionSeasonUnavailable')end
 local season=self.SeasonAvailable and self.Season.Active or nil
 local ps=self.Context:GetService('PlayerService')
 for _,part in ipairs(session.Participants)do
  local player=part.Player
  if player.Parent==Players and ps:IsShopDataReady(player)then
   local stats=part.MatchStats or {};local a=t.Attacks[part.UserId]or {}
   local match={Id=session.Id,StartedAt=t.StartedAt,EditionId=t.EditionId,Playing=t.Playing,FirstAttack=a.First,LastAttack=a.Last,
    Goals=stats.Goals or 0,Kills=stats.Kills or 0,Connected=true,Left=part.State=='Left'or part.State=='Released',Cancelled=session.Cancelled or result=='Cancelled',Won=part.Team==result}
   local current=ps._data[player];local nextP,receipt,applied=M.Award(current.Progression,match,season,os.time())
   if applied then
    local nextData=M.Copy(current);nextData.Progression=nextP
    if ps:CommitProgression(player,current,nextData)then self:Push(player,receipt)end
   elseif receipt.Code=='Ineligible'and not match.Left then
    self:Push(player,receipt)
   end
  end
 end
 self.Sessions[session.Id]=nil
end
function Service:Forget(sessionId)self.Sessions[sessionId]=nil end
function Service:HasReward(reward)
 if not reward then return false end
 if reward.Kind=='Coins'then return M.Integer(reward.Amount)and reward.Amount>0 end
 if reward.Kind=='Slap'then local definition=Slaps.Rewards[reward.Id];return definition~=nil and self.Context:GetService('CrateService'):GetRewardTemplate(definition)~=nil end
 if reward.Kind=='Effect'then
  if reward.Category~='PointEffects'and reward.Category~='DeathEffects'then return false end
  local root=game.ServerStorage:FindFirstChild(reward.Category);return root~=nil and root:FindFirstChild(reward.Id)~=nil
 end
 return false
end
function Service:Claim(player,stage,all)
 if not self:ReadSeason()then return {Ok=false,Reason='SeasonUnavailable'}end
 local ps=self.Context:GetService('PlayerService');local shop=self.Context:GetService('ShopService')
 local response
 local locked,reason=shop:_withShopLock(player,function()
  if not ps:IsShopDataReady(player)or player:GetAttribute('MatchId')or player:GetAttribute('ResultsSessionId')then return false,'LobbyOnly'end
  local season=self.Season.Active;local now=os.time()
  if not M.Active(season,now)then return false,'SeasonExpired'end
  local current=ps._data[player];local nextData=M.Copy(current);local granted={}
  local first,last=if all then 1 else stage,if all then season.Stages else stage
  if not M.Integer(first)or first<1 or first>season.Stages then return false,'InvalidStage'end
  for i=first,last do
   local reward=season.Rewards[i]
   if not self:HasReward(reward)then return false,'RewardMissing'end
   local staged,delivery=M.Claim(nextData,season,now,i,player.UserId,Slaps)
   if staged then nextData=staged;table.insert(granted,{Stage=i,Reward=delivery})
   elseif not all or(delivery~='AlreadyClaimed'and delivery~='StageLocked')then return false,delivery end
  end
  if #granted==0 then return false,'NothingToClaim'end
  local committed,why=ps:CommitProgression(player,current,nextData)
  if not committed then return false,why or 'ProfileChanged'end
  response={Ok=true,Granted=granted};return true
 end)
 if not locked then return {Ok=false,Reason=reason}end
 self:Push(player);return response
end
function Service:Admin(player,action,args)
 local admin=self.Context:GetService('AdminService')
 if not admin or not admin:IsAdmin(player)then return {Ok=false,Reason='Forbidden'}end
 if not self:ReadSeason()then return {Ok=false,Reason='SeasonUnavailable'}end
 if action=='AdminInfo'then
  local rows={};for _,id in ipairs(Catalog.Order)do local d=Catalog.ById[id];if not self.Production or not d.StudioOnly then table.insert(rows,{Id=id,DisplayName=d.DisplayName})end end
  return {Ok=true,Presets=rows,Revision=self.Season.Revision,Season=self.Season.Active}
 end
 if action=='Prepare'then
  local command=args.Command;local definition=Catalog.ById[args.PresetId]
  if self.Production and command~='End'and definition and definition.StudioOnly then return {Ok=false,Reason='StudioCatalogOnly'}end
  if command~='Start'and command~='Restart'and command~='End'then return {Ok=false,Reason='InvalidCommand'}end
  if command~='End'and(not definition or not M.Integer(args.Days)or args.Days<1 or args.Days>365)then return {Ok=false,Reason='InvalidDuration'}end
  if command~='End'then for i=1,definition.Stages do if not self:HasReward(definition.Rewards[i])then return {Ok=false,Reason='RewardMissing',Stage=i}end end end
  if command=='Start'and M.Active(self.Season.Active,os.time())then return {Ok=false,Reason='SeasonAlreadyActive'}end
  local token=Http:GenerateGUID(false)
  self.Challenges[player]={Token=token,Command=command,PresetId=args.PresetId,Days=args.Days,Revision=self.Season.Revision,Until=os.clock()+30,Operation=Http:GenerateGUID(false),Edition=Http:GenerateGUID(false)}
  return {Ok=true,Token=token,Warning=command=='Start'and(self.Production and 'Iniciar temporada global persistente en esta experiencia.'or 'Iniciar temporada para todos los jugadores del entorno de prueba.')or 'Se perderán EXP del pase y premios pendientes. Se conservan nivel y premios entregados.'}
 end
 local c=self.Challenges[player]
 if action~='Apply'or not c or c.Token~=args.Token or os.clock()>c.Until then return {Ok=false,Reason='ConfirmationExpired'}end
 local row,why;local ok,err=pcall(function()
  row=self.Store:UpdateAsync(self.SeasonKey or KEY,function(old)
   local nextRow,reason=SeasonState.Apply(old,c.Revision,c.Command,Catalog.ById[c.PresetId],c.Days,c.Edition,c.Operation,os.time(),player.UserId);why=reason;return nextRow
  end)
 end)
 if not ok or not row then return {Ok=false,Reason=ok and why or 'SeasonWriteUnconfirmed'}end
 if row.LastOperation~=c.Operation then return {Ok=false,Reason='SeasonChanged'}end
 self.Season=row;self.SeasonAvailable=true
 print('[ProgressionAdmin] '..Http:JSONEncode({Actor=player.UserId,Command=c.Command,Revision=row.Revision,Edition=row.Active and row.Active.Id,Environment=self.Production and 'Production'or 'Studio'}))
 for _,p in ipairs(Players:GetPlayers())do self:Push(p)end
 return {Ok=true,Reason='SeasonUpdated',Revision=row.Revision}
end
function Service:Request(player,action,args)
 if not self.Enabled then return {Ok=false,Reason='StudioOnlyPendingProductionValidation'}end
 if type(action)~='string'or type(args)~='table'then return {Ok=false,Reason='InvalidRequest'}end
 local now=os.clock();if now-(self.Rate[player]or -math.huge)<.3 then return {Ok=false,Reason='RateLimited'}end;self.Rate[player]=now
 if action=='Snapshot'then return self:Snapshot(player)end
 if action=='Claim'or action=='ClaimAll'then return self:Claim(player,args.Stage,action=='ClaimAll')end
 return self:Admin(player,action,args)
end
function Service:StartStudioSeason()
 local info=self.Context.PersistenceInfo;local setting=Config.StudioAutoSeason
 if not Run:IsStudio()or not self.Enabled or not info or info.Environment~='Studio'or info.ProviderName~='InMemory'or info.WritesToCloud~=false then return false,'EnvironmentBlocked'end
 if not setting or setting.Enabled~=true then return false,'Disabled'end
 if not self:ReadSeason()then return false,'SeasonUnavailable'end
 -- Seed only a fresh store. Never undo an admin end/reset or replace an edition.
 if self.Season.Revision~=0 or self.Season.Active~=nil then return false,'ExistingSeasonState'end
 local definition=Catalog.ById[setting.PresetId]
 if not definition or definition.StudioOnly~=true or not M.Integer(setting.Days)or setting.Days<1 or setting.Days>365 then return false,'InvalidStudioSeasonConfig'end
 for i=1,definition.Stages do if not self:HasReward(definition.Rewards[i])then return false,'RewardMissing'end end
 local edition='Studio:'..Http:GenerateGUID(false);local operation=Http:GenerateGUID(false)
 local ok,row=pcall(self.Store.UpdateAsync,self.Store,KEY,function(old)
  if old~=nil and(not SeasonState.Valid(old)or old.Revision~=0 or old.Active~=nil)then return nil end
  return SeasonState.Apply(old,0,'Start',definition,setting.Days,edition,operation,os.time(),0)
 end)
 if not ok or not row or row.LastOperation~=operation then return false,'StudioSeasonUnconfirmed'end
 self.Season=row;self.SeasonAvailable=true
 print('[Progression] Studio season auto-started: '..definition.Id..' / InMemory / WritesToCloud=false')
 return true,'Started'
end
function Service:Start()
 self.Remote.OnServerInvoke=function(p,a,args)
  local ok,result=pcall(self.Request,self,p,a,args);if not ok then warn('[Progression] '..tostring(result));return {Ok=false,Reason='RequestFailed'}end;return result
 end
 if not self.Enabled then print('[Progression] Disabled in unapproved environment');return end
 local _,reason=self:StartStudioSeason()
 if not self.Production and reason~='Started'and reason~='Disabled'and reason~='ExistingSeasonState'then warn('[Progression] Studio auto-season: '..reason)end
 self:ReadSeason()
 table.insert(self.Connections,Players.PlayerRemoving:Connect(function(p)self.Rate[p]=nil;self.Challenges[p]=nil end))
 task.spawn(function()while self.Enabled do task.wait(self.Production and(15+math.random()*5)or 5);if self:ReadSeason()then for _,p in ipairs(Players:GetPlayers())do self:Push(p)end end end end)
 print(self.Production and '[Progression] Ready: Production / RobloxDataStore / WritesToCloud=true; activation by admin only; Premium disabled'or '[Progression] Ready: Studio / InMemory / WritesToCloud=false; Premium disabled')
end
return Service
