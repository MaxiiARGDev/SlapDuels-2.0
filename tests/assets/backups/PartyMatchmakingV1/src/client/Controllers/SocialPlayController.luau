--!nonstrict
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local player=Players.LocalPlayer
local Controller={Name='SocialPlayController'}
local reasons={InGroup='El desafío requiere que ambos estén sin grupo.',AlreadyGrouped='Ese jugador ya tiene grupo.',GroupUnavailable='Solo el líder puede invitar y debe haber espacio.',GroupChanged='El grupo cambió. Enviá otra invitación.',GroupBusy='Salgan de la cola/partida antes de modificar el grupo.',NotLeader='Solo el líder puede disolver el grupo.',PlayerUnavailable='Jugador no disponible o en cola/partida.',OutOfRange='Acercate al jugador.',InviteCooldown='Esperá antes de enviar otra solicitud.',RoundUnavailable='Hay una partida en curso. Intentá nuevamente después.',Expired='La solicitud expiró.',Declined='Solicitud rechazada.',Accepted='Solicitud aceptada.',RateLimited='Esperá un momento.',InvalidRequest='Solicitud no válida.',DuelStartFailed='No se pudo iniciar el desafío.'}
function Controller:Notice(reason)
 if not self.Hud then return end
 self.NoticeToken=(self.NoticeToken or 0)+1;local token=self.NoticeToken
 self.Hud.Notice.Text=reasons[reason]or tostring(reason or '')
 self.Hud.Notice.Visible=true
 task.delay(4,function()if self.NoticeToken==token then self.Hud.Notice.Visible=false end end)
end
function Controller:Send(action,id,value,callback)
 if self.Pending then return end;self.Pending=true
 task.spawn(function()
  local ok,response=pcall(self.Remote.InvokeServer,self.Remote,action,id,value)
  self.Pending=false
  if not ok or type(response)~='table'then self:Notice('DuelStartFailed');return end
  if not response.Ok then self:Notice(response.Reason)end
  if callback then callback(response)end
 end)
end
function Controller:Invite(kind,target)
 if target==player.UserId or player:GetAttribute('MatchId')then return end
 if kind=='Duel'and (player:GetAttribute('SocialGroupId')or target and Players:GetPlayerByUserId(target)and Players:GetPlayerByUserId(target):GetAttribute('SocialGroupId'))then return end
 self:Send(kind,target)
end
function Controller:RenderGroup(group)
 self.Group=group;local panel=self.Hud.GroupPanel
 panel.Visible=group~=nil and self:GroupPanelAllowed()
 if not group then return end
 local names={};for _,member in ipairs(group.Members)do table.insert(names,(member.UserId==group.Leader and '★ 'or '')..member.DisplayName)end
 panel.Members.Text='GRUPO '..#group.Members..'/4\n'..table.concat(names,' · ')
 panel.Disband.Visible=group.Leader==player.UserId;panel.Disband.Active=panel.Disband.Visible
end
function Controller:GroupPanelAllowed()
 if player:GetAttribute('MatchId')or self.Hud.RequestPanel.Visible then return false end
 local gui=player:FindFirstChild('PlayerGui');if not gui then return false end
 for _,name in ipairs({'PlayerProfileHUD','TradeHUD','TradeRequestHUD','ShopHUD','PremiumShopHUD','SettingsGUI','CrateOpeningHUD'})do
  local hud=gui:FindFirstChild(name);local main=hud and hud:FindFirstChild('MainFrame')
  if hud and hud.Enabled and (name=='CrateOpeningHUD'or main and main.Visible)then return false end
 end
 return true
end
function Controller:Init(context)
 if self.Initialized then return end;self.Initialized=true
 self.Context=context;self.Connections={};self.Hud=player:WaitForChild('PlayerGui'):WaitForChild('SocialPlayHUD',15)
 assert(self.Hud,'SocialPlayHUD missing in Edit')
 local folder=RS:WaitForChild('Remotes'):WaitForChild('SocialPlay')
 self.Remote=folder:WaitForChild('Request');self.Updated=folder:WaitForChild('Updated')
 self.Hud.Enabled=true;self.Hud.RequestPanel.Visible=false;self.Hud.GroupPanel.Visible=false;self.Hud.Notice.Visible=false
 local function bind(button,fn)table.insert(self.Connections,button.Activated:Connect(fn))end
 bind(self.Hud.RequestPanel.Accept,function()if self.Request then self:Send('Respond',self.Request.Id,true)end end)
 bind(self.Hud.RequestPanel.Decline,function()if self.Request then self:Send('Respond',self.Request.Id,false)end end)
 bind(self.Hud.GroupPanel.Leave,function()self:Send('Leave')end)
 bind(self.Hud.GroupPanel.Disband,function()self:Send('Disband')end)
end
function Controller:Start()
 if self.Started or not self.Updated then return end;self.Started=true
 table.insert(self.Connections,self.Updated.OnClientEvent:Connect(function(kind,data)
  if kind=='Group'then self:RenderGroup(data)
  elseif kind=='Request'then
   self.Request=data;local incoming=data.To==player.UserId
   local panel=self.Hud.RequestPanel;panel.Visible=true
   panel.Message.Text=incoming and (data.FromName..(data.Kind=='Duel'and ' te desafía a un 1v1.'or ' te invita a su grupo.'))or ('Solicitud enviada a '..data.ToName)
   panel.Accept.Visible=incoming;panel.Accept.Active=incoming;panel.Decline.Visible=incoming;panel.Decline.Active=incoming
  elseif kind=='RequestClosed'then
   if self.Request and self.Request.Id==data.Id then self.Request=nil;self.Hud.RequestPanel.Visible=false;self:Notice(data.Reason)end
  elseif kind=='Notice'then self:Notice(data.Reason)end
 end))
 table.insert(self.Connections,player:GetAttributeChangedSignal('MatchId'):Connect(function()
  self:RenderGroup(self.Group)
  if player:GetAttribute('MatchId')then self.Hud.RequestPanel.Visible=false end
 end))
 table.insert(self.Connections,Run.RenderStepped:Connect(function()
  self.Hud.GroupPanel.Visible=self.Group~=nil and self:GroupPanelAllowed()
  local req=self.Request
  if req then
   self.Hud.RequestPanel.Countdown.Text=math.max(0,math.ceil(req.ExpiresAt-workspace:GetServerTimeNow()))..' s'
   if workspace:GetServerTimeNow()>=req.ExpiresAt then self.Hud.RequestPanel.Visible=false;self.Request=nil end
  end
 end))
 self:Send('State',nil,nil,function(response)if response.Ok then self:RenderGroup(response.Group)end end)
end
function Controller:Destroy()
 for _,c in ipairs(self.Connections or {})do c:Disconnect()end
 self.Connections={};self.Started=false;self.Initialized=false;self.NoticeToken=(self.NoticeToken or 0)+1
 if self.Hud then self.Hud.Enabled=false end
end
return Controller
