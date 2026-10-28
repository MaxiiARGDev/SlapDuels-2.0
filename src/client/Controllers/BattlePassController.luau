--!nonstrict
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Http=game:GetService('HttpService')
local Controller={Name='BattlePassController'}
local player=Players.LocalPlayer
local messages={SeasonExpired='La temporada terminó. Los premios pendientes caducaron.',StageLocked='Todavía no alcanzaste esta etapa.',AlreadyClaimed='Ya reclamaste este premio.',NothingToClaim='No tenés premios pendientes.',LobbyOnly='Reclamá tus premios desde el lobby.',SeasonChanged='La temporada cambió. Actualizá antes de confirmar.',SeasonAlreadyActive='Ya hay un pase activo. Usá Reiniciar o Finalizar con confirmación.',ConfirmationExpired='Confirmación vencida. Prepará la acción otra vez.',RewardMissing='Ese premio no está disponible.',StudioOnlyPendingProductionValidation='Pase de prueba: todavía no habilitado en producción.',Forbidden='Acceso denegado.',RateLimited='Esperá un momento.',SeasonUnavailable='No se pudo consultar la temporada.',SeasonWriteUnconfirmed='No se pudo confirmar el cambio. Reintentá la misma confirmación.',SeasonUpdated='Temporada actualizada.',InvalidDuration='Duración válida: 1 a 365 días.'}
local function remaining(ends)
 local n=math.max(0,math.floor(ends-workspace:GetServerTimeNow()))
 return string.format('%dd %02dh %02dm',math.floor(n/86400),math.floor(n%86400/3600),math.floor(n%3600/60))
end
function Controller:Call(action,args)
 local ok,r=pcall(self.Remote.InvokeServer,self.Remote,action,args or {})
 return if ok and type(r)=='table'then r else {Ok=false,Reason='Sin respuesta; consultá el estado antes de repetir.'}
end
function Controller:Message(r,label)label.Text=messages[r.Reason]or r.Reason or(r.Ok and 'Recompensa entregada.'or 'No se pudo completar.')end
-- Presentation only: snapshots remain the source of truth for both progressions.
function Controller:ProgressView(s,now)
 local level=s.Level or 0;local cost=math.max(1,s.LevelCost or 100);local xp=math.clamp(s.LevelXP or 0,0,cost)
 local v={PlayerTitle=string.format('JUGADOR · NIVEL %d → %d',level,level+1),PlayerXP=string.format('%d / %d EXP',xp,cost),PlayerRatio=xp/cost,PlayerHint=string.format('Faltan %d EXP para subir de nivel',cost-xp),PassTitle='PASE DE BATALLA',PassXP='Sin temporada activa',PassRatio=0,Reward='Activá una temporada para progresar',Pending=0}
 local season=s.Season
 if not season then return v end
 if not s.Active or now>=season.EndsAt then v.PassXP='Temporada finalizada';v.Reward='Los premios pendientes caducaron';return v end
 local stages=season.Stages;local stage=math.clamp(s.Stage or 0,0,stages)
 for i=1,stage do if not(s.Claimed or {})[tostring(i)]then v.Pending+=1 end end
 if stage>=stages then v.PassTitle='PASE · COMPLETADO';v.PassXP=string.format('%d / %d ETAPAS',stages,stages);v.PassRatio=1;v.Reward='Alcanzaste todas las etapas';return v end
 local step=math.max(1,season.StageXP);local progress=math.clamp((s.PassXP or 0)-stage*step,0,step)
 v.PassTitle=string.format('PASE · ETAPA %d → %d',stage,stage+1);v.PassXP=string.format('%d / %d EXP DEL PASE',progress,step);v.PassRatio=progress/step
 local reward=season.Rewards[stage+1];v.Reward='Próximo: '..(reward and reward.Label or 'Premio de temporada')
 return v
end
function Controller:PaintProgress(container,s)
 if not container then return end
 local v=self:ProgressView(s,workspace:GetServerTimeNow())
 local function paint(card,title,xp,ratio,hint)
  card.Title.Text=title;card.XP.Text=xp;card.Track.Fill.Size=UDim2.fromScale(ratio,1);card.Hint.Text=hint
 end
 paint(container.Player,v.PlayerTitle,v.PlayerXP,v.PlayerRatio,v.PlayerHint)
 paint(container.Pass,v.PassTitle,v.PassXP,v.PassRatio,v.Reward)
 container.Pass.Open.Text=v.Pending>0 and string.format('VER PASE · %d POR RECLAMAR',v.Pending)or 'VER PASE'
 local dot=container.Pass.Open:FindFirstChild('ClaimDot');if dot then dot.Visible=v.Pending>0 end
end
function Controller:RenderProfile()
 local social=self.Context and self.Context:GetController('SocialController')
 if self.Hud then self.Hud.ProgressCards.Visible=false end
 if not social or not social.Profile or not social.ProfileTarget then return end
 local m=social.Profile.MainFrame;local cards=m:FindFirstChild('ProgressCards');if not cards then return end
 local own=social.ProfileTarget==player.UserId
 cards.Visible=not social.ArticlesVisible;cards.Pass.Visible=own
 if own and self.Data then self:PaintProgress(cards,self.Data)
 else
  local target=Players:GetPlayerByUserId(social.ProfileTarget);local level=target and target:GetAttribute('Level')or 0
  cards.Player.Title.Text='JUGADOR · NIVEL '..tostring(level);cards.Player.XP.Text=own and 'Cargando progreso…'or 'Nivel permanente'
  cards.Player.Hint.Text=own and 'Consultando al servidor'or 'La EXP del pase es privada';cards.Player.Track.Fill.Size=UDim2.fromScale(0,1)
  if own then cards.Pass.Title.Text='PASE DE BATALLA';cards.Pass.XP.Text='Cargando…';cards.Pass.Hint.Text='Consultando al servidor';cards.Pass.Track.Fill.Size=UDim2.fromScale(0,1)end
 end
end
function Controller:OpenPass()if self.Hud then self.Hud.MainFrame.Visible=true;self.Hud.ProgressCards.Visible=false end end
function Controller:Render(snapshot,receipt)
 if not snapshot or not snapshot.Ok then return end
 self.Data=snapshot;self.Hud.OpenButton.Visible=snapshot.Enabled
 self.Hud.Bar.Visible=false
 self.Hud.Bar.Level.Text='NIVEL '..snapshot.Level
 self.Hud.Bar.XP.Text=snapshot.LevelXP..' / '..snapshot.LevelCost..' EXP'
 self.Hud.Bar.Track.Fill.Size=UDim2.fromScale(math.clamp(snapshot.LevelXP/snapshot.LevelCost,0,1),1)
 self.Hud.Bar.Visible=false -- Replaced by the two explicitly labelled progress cards.
 self.Hud.ProgressCards.Visible=false
 self:PaintProgress(self.Hud.ProgressCards,snapshot)
 self:PaintProgress(self.Hud.MainFrame.ProgressCards,snapshot)
 self:RenderProfile()
 local frame=self.Hud.MainFrame;local season=snapshot.Season
 frame.Title.Text=season and season.DisplayName or 'PASE DE BATALLA'
 frame.Progress.Text=season and('Etapa '..snapshot.Stage..' / '..season.Stages..' · '..snapshot.PassXP..' EXP')or 'No hay una temporada activa.'
 frame.ClaimAll.Active=snapshot.Active;frame.ClaimAll.AutoButtonColor=snapshot.Active
 for _,o in ipairs(frame.Rewards:GetChildren())do if o:IsA('Frame')then o:Destroy()end end
 if season then for i,reward in ipairs(season.Rewards)do
  local row=self.Hud.RewardTemplate:Clone();row.Name='Stage_'..i;row.LayoutOrder=i;row.Visible=true
  row.Stage.Text='ETAPA '..i;row.Reward.Text=reward.Label;row.Cost.Text=(i*season.StageXP)..' EXP'
  local claimed=snapshot.Claimed[tostring(i)]==true;local unlocked=snapshot.Stage>=i
  row.Claim.Text=claimed and 'RECLAMADO'or not snapshot.Active and 'FINALIZADO'or unlocked and 'RECLAMAR'or 'BLOQUEADO'
  row.Claim.Active=not claimed and unlocked and snapshot.Active;row.Claim.AutoButtonColor=row.Claim.Active
  row.Claim.TextTransparency=row.Claim.Active and 0 or .4;row.Parent=frame.Rewards
  row.Claim.Activated:Connect(function()if row.Claim.Active then self:Claim(i)end end)
 end end
 if receipt then
  local reasons={MinimumPlaying='Sin EXP: la partida no alcanzó 60 segundos de juego.',Participation='Sin EXP: necesitás participación activa.',Cancelled='Sin EXP: partida cancelada.',Left='Sin EXP: no completaste la partida.'}
  local summary=receipt.Code=='Ineligible'and reasons[receipt.Reason]or string.format('Jugador +%d EXP  |  Pase +%d EXP',receipt.XP,receipt.PassXP)
  frame.Status.Text=receipt.Code=='Ineligible'and summary or string.format('+%d EXP · Completar %d · Victoria %d · Goles %d · Kills %d',receipt.XP,receipt.Base,receipt.Victory,receipt.Goals,receipt.Kills)
  self.Hud.Notice.Text=summary;self.Hud.Notice.Visible=false;self.NoticeVersion=(self.NoticeVersion or 0)+1;local version=self.NoticeVersion
  task.delay(6,function()if self.Hud and self.NoticeVersion==version then self.Hud.Notice.Visible=false end end)
 end
 self:Tick()
end
function Controller:Tick()
 if not self.Data then return end;local s=self.Data.Season
 local text=if s and workspace:GetServerTimeNow()<s.EndsAt then 'Termina en '..remaining(s.EndsAt)else s and 'Temporada finalizada'or 'Próximamente'
 self.Hud.MainFrame.Remaining.Text=text
 self.Hud.Bar.Visible=false;self.Hud.ProgressCards.Visible=false;self.Hud.Notice.Visible=false
 self.Hud.MainFrame.ProgressCards.Player.Visible=false
 local pending=self:ProgressView(self.Data,workspace:GetServerTimeNow()).Pending
 local dot=self.Hud.OpenButton:FindFirstChild('ClaimDot');if dot then dot.Visible=pending>0 end
 self:PaintProgress(self.Hud.ProgressCards,self.Data);self:PaintProgress(self.Hud.MainFrame.ProgressCards,self.Data);self:RenderProfile()
 if s and workspace:GetServerTimeNow()>=s.EndsAt then
  self.Hud.MainFrame.ClaimAll.Active=false
  for _,row in ipairs(self.Hud.MainFrame.Rewards:GetChildren())do if row:IsA('Frame')and row:FindFirstChild('Claim')then row.Claim.Active=false;row.Claim.AutoButtonColor=false;if row.Claim.Text~='RECLAMADO'then row.Claim.Text='FINALIZADO'end end end
 end
 if self.Admin and self.Admin.Visible then self.Admin.Current.Text=s and(s.DisplayName..' · '..text)or 'Sin pase activo'end
end
function Controller:Claim(stage)
 if self.Busy then return end;self.Busy=true
 task.spawn(function()
  local r=self:Call(stage and 'Claim'or 'ClaimAll',{Stage=stage})
  self:Message(r,self.Hud.MainFrame.Status);self.Busy=false
  task.wait(.35);local snapshot=self:Call('Snapshot');if snapshot.Ok then self:Render(snapshot)end
 end)
end
function Controller:AdminInfo()
 if self.AdminBusy then return end;self.AdminBusy=true
 task.spawn(function()
  local r=self:Call('AdminInfo');self.AdminBusy=false
  if not r.Ok then self:Message(r,self.Admin.Status);return end
  self.Presets=r.Presets;self.PresetIndex=1
  self:Preset();self:Tick()
 end)
end
function Controller:Preset()
 local d=self.Presets and self.Presets[self.PresetIndex or 1]
 self.Admin.Preset.Text=d and d.DisplayName or 'Sin catálogos'
end
function Controller:Prepare(command)
 if self.AdminBusy then return end
 local preset=self.Presets and self.Presets[self.PresetIndex or 1];if not preset then return end
 self.AdminBusy=true;self.Token=nil;self.Admin.Confirm.Visible=false
 task.spawn(function()
  local r=self:Call('Prepare',{Command=command,PresetId=preset.Id,Days=tonumber(self.Admin.Days.Text)})
  self.AdminBusy=false
  if r.Ok then self.Token=r.Token;self.Admin.Status.Text=r.Warning;self.Admin.Confirm.Text='CONFIRMAR '..({Start='INICIO',Restart='REINICIO',End='FINALIZACIÓN'})[command];self.Admin.Confirm.Visible=true
  else self:Message(r,self.Admin.Status)end
 end)
end
function Controller:Apply()
 if self.AdminBusy or not self.Token then return end;self.AdminBusy=true;local token=self.Token
 task.spawn(function()
  local r=self:Call('Apply',{Token=token});self.AdminBusy=false;self:Message(r,self.Admin.Status)
  if r.Ok or r.Reason=='ConfirmationExpired'or r.Reason=='SeasonChanged'then self.Token=nil;self.Admin.Confirm.Visible=false end
 end)
end
function Controller:Init(context)
 self.Context=context
 self.Connections={};self.Hud=player:WaitForChild('PlayerGui'):WaitForChild('ProgressionHUD',15);assert(self.Hud,'ProgressionHUD missing')
 local folder=RS:WaitForChild('Remotes'):WaitForChild('Progression',15);assert(folder,'Progression remote missing')
 self.Remote=folder:WaitForChild('Request');self.Hud.MainFrame.Visible=false;self.Hud.OpenButton.Visible=false;self.Hud.Bar.Visible=false
 local function bind(button,fn)table.insert(self.Connections,button.Activated:Connect(fn))end
 bind(self.Hud.OpenButton,function()self.Hud.MainFrame.Visible=not self.Hud.MainFrame.Visible end)
 bind(self.Hud.MainFrame.Close,function()self.Hud.MainFrame.Visible=false end)
 bind(self.Hud.MainFrame.ClaimAll,function()if self.Hud.MainFrame.ClaimAll.Active then self:Claim()end end)
 self.Hud.ProgressCards.Visible=false
 bind(self.Hud.ProgressCards.Pass.Open,function()self:OpenPass()end)
 bind(self.Hud.MainFrame.ProgressCards.Pass.Open,function()self:OpenPass()end)
 local profile=player.PlayerGui:WaitForChild('PlayerProfileHUD',15)
 if profile then bind(profile.MainFrame.ProgressCards.Pass.Open,function()self:OpenPass()end)end
 local changed=folder:WaitForChild('Changed',15);assert(changed and changed:IsA('RemoteEvent'),'Progression Changed RemoteEvent missing')
 table.insert(self.Connections,changed.OnClientEvent:Connect(function(s,r)self:Render(s,r)end))
 local adminHUD=player.PlayerGui:WaitForChild('AdminHUD',15)
 self.Admin=adminHUD.MainFrame:WaitForChild('SeasonPanel',15)
 bind(adminHUD.MainFrame.SeasonsButton,function()
  if player:GetAttribute('AdminPanelAllowed')then self.Admin.Visible=true;self.Token=nil;self.Admin.Confirm.Visible=false;self:AdminInfo()end
 end)
 bind(self.Admin.Close,function()self.Admin.Visible=false;self.Token=nil end)
 bind(self.Admin.Preset,function()self.PresetIndex=(self.PresetIndex or 1)%math.max(1,#(self.Presets or {}))+1;self.Token=nil;self.Admin.Confirm.Visible=false;self:Preset()end)
 bind(self.Admin.Start,function()self:Prepare('Start')end);bind(self.Admin.Restart,function()self:Prepare('Restart')end);bind(self.Admin.Finish,function()self:Prepare('End')end);bind(self.Admin.Confirm,function()self:Apply()end)
 table.insert(self.Connections,player:GetAttributeChangedSignal('AdminPanelAllowed'):Connect(function()if not player:GetAttribute('AdminPanelAllowed')then self.Admin.Visible=false;self.Token=nil end end))
end
function Controller:Start()
 task.spawn(function()task.wait(1);local r=self:Call('Snapshot');if r.Ok then self:Render(r)end end)
 task.spawn(function()while self.Hud and self.Hud.Parent do task.wait(1);self:Tick()end end)
end
function Controller:Destroy()for _,c in ipairs(self.Connections or {})do c:Disconnect()end;self.Hud=nil end
return Controller
