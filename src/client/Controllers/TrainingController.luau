--!nonstrict
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local Config=require(RS.Shared.Config)
local player=Players.LocalPlayer
local Controller={Name='TrainingController'}
function Controller:Unbind()
 if self.Activated then self.Activated:Disconnect();self.Activated=nil end
 if self.Track then pcall(function()self.Track:Stop(0);self.Track:Destroy()end);self.Track=nil end
 self.Tool=nil
end
function Controller:Bind(tool)
 if self.Tool==tool then return end
 self:Unbind();self.Tool=tool
 local h=player.Character and player.Character:FindFirstChildOfClass('Humanoid');local animator=h and h:FindFirstChildOfClass('Animator');local animation=tool:FindFirstChild('Swing')
 if animator and animation and animation:IsA('Animation')then local ok,track=pcall(animator.LoadAnimation,animator,animation);if ok then self.Track=track;track.Priority=Enum.AnimationPriority.Action end end
 self.Activated=tool.Activated:Connect(function()self:Activate()end)
end
function Controller:Activate()
 local tool=self.Tool;local sid=player:GetAttribute('TrainingSessionId');local now=workspace:GetServerTimeNow()
 if not sid or not tool or tool.Parent~=player.Character or player:GetAttribute('MatchId')or now<self.ReadyAt or self.Pending then return end
 local h=player.Character:FindFirstChildOfClass('Humanoid');if not h or h.Health<=0 or h.PlatformStand then return end
 self.Sequence+=1;local sequence=self.Sequence;self.Pending=sequence
 local combo=Config.Combat.SlapCombo;local c=tool:FindFirstChild('Configuration');local cd=c and c:FindFirstChild('SlapCooldown')
 self.ReadyAt=now+(combo.Enabled and combo.SwingWindow+combo.MissRecovery or cd and cd.Value or Config.Combat.SlapCooldown)
 if self.Track then self.Track.Looped=false;pcall(function()self.Track:Play(.05,1,1.2)end)end
 self.ActivateRemote:FireServer(tool,sid,sequence)
 task.delay(2,function()if self.Session==sid and self.Pending==sequence then self.Pending=nil;self.Hud.Panel.Status.Text='Sin respuesta: volvé a intentar.'end end)
end
function Controller:Refresh()
 local sid=player:GetAttribute('TrainingSessionId')
 if sid~=self.Session then self:Unbind();self.Session=sid;self.Sequence=0;self.Pending=nil;self.ReadyAt=0;self.LastAck=0 end
 local visible=sid~=nil and player:GetAttribute('MatchId')==nil;self.Hud.Panel.Visible=visible
 if not visible then self:Unbind();return end
 local char=player.Character;local found
 if char then for _,o in ipairs(char:GetChildren())do if o:IsA('Tool')and o:GetAttribute('IsTrainingSlap')==true then found=o;break end end end
 if found then self:Bind(found)elseif self.Tool then self:Unbind()end
 local remaining=math.max(0,self.ReadyAt-workspace:GetServerTimeNow())
 self.Hud.Panel.Attack.Text=self.Pending and 'ESPERANDO…'or remaining>0 and string.format('RECUPERACIÓN %.1f',remaining)or 'GOLPEAR'
end
function Controller:Init()
 self.Connections={};self.Sequence=0;self.ReadyAt=0;self.LastAck=0
 self.Hud=player:WaitForChild('PlayerGui'):WaitForChild('TrainingHUD',15);assert(self.Hud,'TrainingHUD missing in Edit');self.Hud.Panel.Visible=false
 local folder=RS:WaitForChild('Remotes'):WaitForChild('Training');self.ActivateRemote=folder:WaitForChild('Activate');self.Leave=folder:WaitForChild('Leave');self.Updated=folder:WaitForChild('Updated')
 table.insert(self.Connections,self.Hud.Panel.Attack.Activated:Connect(function()self:Activate()end))
 table.insert(self.Connections,self.Hud.Panel.Exit.Activated:Connect(function()self.Leave:FireServer()end))
end
function Controller:Start()
 if not self.Hud then return end
 table.insert(self.Connections,self.Updated.OnClientEvent:Connect(function(data)
  if type(data)~='table'or data.SessionId~=self.Session or type(data.Sequence)~='number'or data.Sequence<self.LastAck then return end
  self.LastAck=data.Sequence
  if data.Sequence~=self.Pending then return end
  self.Pending=nil
  if type(data.ReadyAt)=='number'then self.ReadyAt=math.max(workspace:GetServerTimeNow(),data.ReadyAt)end
  self.Hud.Panel.Status.Text=data.Hit and '¡IMPACTO! El maniquí se recupera y vuelve a su base.'or 'Fallo o maniquí protegido durante el ragdoll.'
 end))
 table.insert(self.Connections,Run.RenderStepped:Connect(function()self:Refresh()end))
 table.insert(self.Connections,player.CharacterRemoving:Connect(function()self:Unbind()end))
end
function Controller:Destroy()
 self:Unbind();for _,c in ipairs(self.Connections or {})do c:Disconnect()end
 if self.Hud then self.Hud.Enabled=false end
end
return Controller
