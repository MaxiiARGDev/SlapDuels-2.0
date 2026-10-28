--!nonstrict
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local player=Players.LocalPlayer
local Config=require(RS.Shared.PartyMatchConfig)
local Controller={Name='PartyMatchController'}
local messages={NotLeader='Solo el líder puede realizar esta acción.',GroupTooLarge='Tu grupo supera el tamaño del equipo.',PlayerUnavailable='Un integrante está ocupado o no está listo.',QueueUnavailable='No se pudo actualizar la búsqueda. Reintentá en unos segundos.',QueueExpired='La búsqueda venció. Podés volver a buscar.',ModeUnavailable='Esta modalidad no está disponible.',MatchFound='Partida encontrada; ya no se puede cancelar.',Cancelled='Búsqueda cancelada.',Disconnected='Un integrante se desconectó.',TeleportFailed='No se pudo completar el traslado.',ReservationFailed='No se pudo reservar el servidor.',ReservationTimeout='La reserva venció.',ArrivalFailed='No llegaron todos los jugadores. Volvé al lobby para buscar otra partida.',DestinationLatency='La conexión al destino supera el límite. Volvé al lobby para reintentar.',DestinationUnavailable='El destino no está disponible.',Unavailable='Búsqueda no disponible en este servidor.',RateLimited='Esperá un momento.'}
function Controller:Notice(reason)
 self.Hud.Status.Text=messages[reason]or reason or '';self.MessageUntil=os.clock()+6
end
function Controller:Call(action,arg)
 if self.Pending then return end;self.Pending=true
 task.spawn(function()
  local ok,r=pcall(self.Remote.InvokeServer,self.Remote,action,arg);self.Pending=false
  if not ok or type(r)~='table'then self:Notice('QueueUnavailable');return end
  if r.State then self.Data=r end
  if r.Reason then self:Notice(r.Reason)end
  self:Render()
 end)
end
function Controller:Group()
 local social=self.Context:GetController('SocialPlayController');return social and social.Group
end
function Controller:InviteList()
 local list=self.Hud.InvitePanel.List
 local present={}
 local all=Players:GetPlayers();table.sort(all,function(a,b)return a.DisplayName:lower()<b.DisplayName:lower()end)
 local n=0;local g=self:Group();local leader=not g or g.Leader==player.UserId
 for _,p in ipairs(all)do if p~=player then
  n+=1;present[p.UserId]=true;local row=self.InviteRows[p.UserId]
  if not row then
   row=self.Hud.InviteTemplate:Clone();row.Name='Player_'..p.UserId;row:SetAttribute('PartyInviteRow',true)
   self.InviteRows[p.UserId]=row
   self.InviteConnections[p.UserId]=row.Invite.Activated:Connect(function()
    if row.Invite.Active then self.Context:GetController('SocialPlayController'):Invite('Group',p.UserId)end
   end)
  end
  row.LayoutOrder=n
  row.Avatar.Image='rbxthumb://type=AvatarHeadShot&id='..p.UserId..'&w=150&h=150'
  row.Username.Text=p.DisplayName..' (@'..p.Name..')'
  local available=leader and not p:GetAttribute('SocialGroupId')and not p:GetAttribute('MatchId')and not p:GetAttribute('PartyQueueTicket')and not player:GetAttribute('PartyQueueTicket')and(not g or #g.Members<4)
  row.Invite.Text=available and 'Invitar'or 'No disponible';row.Invite.Active=available;row.Invite.AutoButtonColor=available
  row.Visible=true;row.Parent=list
 end end
 for id,row in pairs(self.InviteRows)do if not present[id]then self.InviteConnections[id]:Disconnect();self.InviteConnections[id]=nil;row:Destroy();self.InviteRows[id]=nil end end
 self.Hud.InvitePanel.Empty.Visible=n==0
end
function Controller:Render()
 if not self.Hud then return end
 local g=self:Group();local members=g and g.Members or {{UserId=player.UserId,DisplayName=player.DisplayName}}
 local leader=not g or g.Leader==player.UserId;local d=self.Data or {};local state=d.State or 'Idle'
 local busy=state~='Idle'or player:GetAttribute('MatchId')~=nil or player:GetAttribute('ResultsSessionId')~=nil or player:GetAttribute('PartyQueueTicket')~=nil
 local dock=self.Hud.Dock;dock.Visible=true;dock.Count.Text=#members..' / 4'
 for i=1,4 do local slot=dock.Members['Slot'..i];local m=members[i];slot.Visible=m~=nil
  if m then slot.Avatar.Image='rbxthumb://type=AvatarHeadShot&id='..m.UserId..'&w=150&h=150';slot.Caption.Text=m.UserId==player.UserId and 'TÚ'or m.DisplayName;slot.Leader.Visible=g and m.UserId==g.Leader or not g end
 end
 dock.Members.Add.Visible=#members<4;dock.Members.Add.Active=leader and not busy;dock.Members.Add.AutoButtonColor=dock.Members.Add.Active
 dock.Play.Active=leader and not busy and d.Enabled==true;dock.Play.AutoButtonColor=dock.Play.Active
 dock.Play.Text=state=='Searching'and 'Buscando…'or not leader and 'Esperando al líder'or busy and 'En partida / traslado'or 'Jugar'
 dock.Leave.Visible=g~=nil;dock.Leave.Active=not busy
 local search=self.Hud.Search;search.Visible=state=='Searching'or state=='Matched'or state=='Teleporting'
 search.Title.Text=state=='Searching'and 'Buscando jugadores…'or state=='Teleporting'and 'Viajando a la partida…'or 'Partida encontrada'
 search.Mode.Text=d.Mode or '';search.Cancel.Visible=d.CanCancel==true
 self.Hud.Return.Visible=d.CanReturn==true;self.Hud.Return.Active=leader
 for _,mode in ipairs(Config.Modes)do local b=self.Hud.ModePanel.Modes[mode]
  local allowed=#members<=tonumber(mode:sub(1,1))and leader and not busy and d.Enabled==true and d.Modes and d.Modes[mode]==true
  b.Active=allowed;b.AutoButtonColor=allowed;b.Hint.Text=allowed and 'Buscar partida'or #members>tonumber(mode:sub(1,1))and 'Grupo demasiado grande'or 'No disponible'
  b.BackgroundTransparency=allowed and 0 or .5
 end
 if busy then self.Hud.ModePanel.Visible=false;self.Hud.InvitePanel.Visible=false end
end
function Controller:Init(context)
 self.Context=context;self.Connections={};self.InviteConnections={};self.InviteRows={}
 self.Hud=player:WaitForChild('PlayerGui'):WaitForChild('PartyMatchHUD',15);assert(self.Hud,'PartyMatchHUD missing')
 local folder=RS:WaitForChild('Remotes'):WaitForChild('PartyMatch',15);assert(folder,'PartyMatch remote missing')
 self.Remote=folder:WaitForChild('Request');self.Updated=folder:WaitForChild('Updated')
 local function bind(button,callback)table.insert(self.Connections,button.Activated:Connect(callback))end
 self.Hud.Enabled=true;self.Hud.InvitePanel.Visible=false;self.Hud.ModePanel.Visible=false;self.Hud.Search.Visible=false
 bind(self.Hud.Dock.Members.Add,function()if self.Hud.Dock.Members.Add.Active then self:InviteList();self.Hud.InvitePanel.Visible=true end end)
 bind(self.Hud.Dock.Play,function()if self.Hud.Dock.Play.Active then self:Render();self.Hud.ModePanel.Visible=true end end)
 bind(self.Hud.Dock.Leave,function()if self.Hud.Dock.Leave.Active then self.Context:GetController('SocialPlayController'):Send('Leave')end end)
 for _,name in ipairs({'InvitePanel','ModePanel'})do bind(self.Hud[name].Close,function()self.Hud[name].Visible=false end)end
 for _,mode in ipairs(Config.Modes)do bind(self.Hud.ModePanel.Modes[mode],function()if self.Hud.ModePanel.Modes[mode].Active then self:Call('Join',mode)end end)end
 bind(self.Hud.Search.Cancel,function()self:Call('Cancel')end)
 bind(self.Hud.Return,function()self:Call('Return')end)
 table.insert(self.Connections,self.Updated.OnClientEvent:Connect(function(s)self.Data=s;if s.Reason then self:Notice(s.Reason)end;self:Render()end))
end
function Controller:Start()
 if not self.Hud then return end;self:Call('State');self:Render()
 local elapsed,frames=0,0
 table.insert(self.Connections,Run.RenderStepped:Connect(function(dt)
  elapsed+=dt;frames+=1;if elapsed<1 then return end
  local fps=math.floor(frames/elapsed+.5);elapsed=0;frames=0
  local ok,ping=pcall(player.GetNetworkPing,player);local d=self.Data or {}
  self.Hud.Telemetry.Text=string.format('%d FPS  ·  %s ms  ·  Servidor %s  ·  v%d',fps,ok and tostring(math.floor(ping*1000+.5))or '—',d.Server or '…',d.Version or 0)
  self.Hud.Telemetry:SetAttribute('ServerRegion',d.Region or 'No disponible')
  self.Hud.Search.Timer.Text=string.format('%d:%02d',math.floor(math.max(0,workspace:GetServerTimeNow()-(d.Since or 0))/60),math.floor(math.max(0,workspace:GetServerTimeNow()-(d.Since or 0)))%60)
  if self.MessageUntil and os.clock()>self.MessageUntil then self.Hud.Status.Text=''end
  self:Render();if self.Hud.InvitePanel.Visible then self:InviteList()end
 end))
end
function Controller:Destroy()
 for _,c in ipairs(self.Connections or {})do c:Disconnect()end
 for _,c in pairs(self.InviteConnections or {})do c:Disconnect()end
 self.Hud=nil
end
return Controller
