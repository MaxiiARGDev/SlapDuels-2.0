--!nonstrict
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local Definitions=require(RS.Shared.AbilityDefinitions)
local Presentation=require(script.Parent.Parent.Abilities.AbilityPresentation)
local Selection=require(script.Parent.Parent.Abilities.AbilitySelection)
local Controller={Name="AbilityController"}
function Controller:Init(context)
 self._context=context;self._connections={};self._revision=0;self._lastRequest=0;self._presentation=Presentation.new()
end
function Controller:_send(action)
 local p=self._payload
 if not p or not p.Playing or os.clock()-self._lastRequest<Definitions.RequestInterval then return end
 local char=Players.LocalPlayer.Character
 local hum=char and char:FindFirstChildOfClass("Humanoid")
 if not hum or hum.WalkSpeed<=0 or hum.PlatformStand or char:GetAttribute("ArenaRespawnPending") then return end
 self._lastRequest=os.clock()
 self._request:FireServer({Action=action,SessionId=p.SessionId,RoundId=p.RoundId,
  CharacterGeneration=char:GetAttribute("ArenaPhysicsGeneration") or 0,AbilityId=p.AbilityId,
  ActivationId=p.ActivationId,LifeId=p.LifeId,Direction=hum.MoveDirection})
end
function Controller:_activate()
 if self._payload and self._payload.AbilityId=="AirJumps" and self._payload.ActivationId then self:_send("AirJump")
 else self:_send("Activate") end
end
function Controller:_render()
 local p=self._payload;if not p or not self._hud then return end
 local char=Players.LocalPlayer.Character
 local matching=p.SessionId~=nil and p.SessionId==Players.LocalPlayer:GetAttribute("MatchId")
 self._hud.Enabled=matching and (p.Preparing or p.Playing)
 self._selection:Tick()
 self._hud.ChangeAbilityButton.Visible=matching and self._selection:CanOpen()
 self._hud.ChangeAbilityButton.Active=self._hud.ChangeAbilityButton.Visible
 local button=self._hud.AbilityButton
 button.Visible=matching and (p.Preparing or p.Playing)
 if not button.Visible then return end
 local d=Definitions.Items[p.AbilityId]
 local t=workspace:GetServerTimeNow()
 local cooldown=math.max(0,(p.CooldownUntil or 0)-t)
 local remaining=math.max(0,(p.ActiveUntil or 0)-t)
 local hum=char and char:FindFirstChildOfClass("Humanoid")
 local blocked=not hum or hum.WalkSpeed<=0 or hum.PlatformStand or char:GetAttribute("ArenaRespawnPending")
 button.AbilityName.Text=d.DisplayName
 button.Icon.Image=d.Icon;button.Icon.Visible=d.Icon~=""
 button.CooldownLabel.Text=if not p.Playing then "PREPARACIÓN" elseif blocked then "BLOQUEADA" elseif remaining>0 then
  string.format("%s · %.1fs",if p.AbilityId=="StrongSlap" then "PREPARADA" else "ACTIVA",remaining)
  elseif cooldown>0 then string.format("%.1fs",cooldown) else (if UIS.TouchEnabled then "ACTIVAR" else "E · LISTA")
 button.CooldownOverlay.Visible=cooldown>0 and remaining<=0
 button.Active=p.Playing==true and not blocked and (cooldown<=0 or (remaining>0 and p.AbilityId=="AirJumps"))
 button.AutoButtonColor=button.Active
end
function Controller:Start(_context)
 task.spawn(function()
  local combat=RS:WaitForChild("Remotes"):WaitForChild("Combat")
  self._request=combat:WaitForChild("AbilityRequest",15)
  local state=combat:WaitForChild("AbilityState",15)
  self._hud=Players.LocalPlayer:WaitForChild("PlayerGui"):WaitForChild("AbilityHUD",15)
  if not self._request or not state or not self._hud then warn("[AbilityController] PhysicalResourcesMissing");return end
  self._selection=Selection.new(self._hud.AbilitySelectionFrame,function(id,p,requestId)
   self._request:FireServer({Action="Select",SessionId=p.SessionId,WindowId=p.WindowId,
    PreparationId=p.PreparationId,AbilityId=id,RequestId=requestId})
  end,function(p) return p.SessionId==Players.LocalPlayer:GetAttribute("MatchId") end)
  table.insert(self._connections,self._hud.ChangeAbilityButton.Activated:Connect(function()
   self._selection:Open()
  end))
  table.insert(self._connections,state.OnClientEvent:Connect(function(p)
   if type(p)~="table" then return end
   if p.Kind=="StrongImpact" then self._presentation:Impact(p);return end
   if p.Kind~="State" or type(p.Revision)~="number" or p.Revision<=self._revision then return end
   self._revision=p.Revision;self._payload=p
   self._selection:Render(p);self._presentation:Reconcile(p);self:_render()
  end))
  table.insert(self._connections,self._hud.AbilityButton.Activated:Connect(function() self:_activate() end))
  table.insert(self._connections,UIS.InputBegan:Connect(function(input,processed)
   if not processed and not UIS:GetFocusedTextBox() and input.KeyCode==Enum.KeyCode.E then self:_activate() end
  end))
  table.insert(self._connections,UIS.JumpRequest:Connect(function()
   if self._payload and self._payload.AbilityId=="AirJumps" and self._payload.ActivationId then self:_send("AirJump") end
  end))
  table.insert(self._connections,Players.LocalPlayer:GetAttributeChangedSignal("MatchId"):Connect(function()
   self._presentation:Clear();self:_render()
  end))
  table.insert(self._connections,RunService.RenderStepped:Connect(function()
   self:_render();self._presentation:Tick()
  end))
  self._request:FireServer({Action="Sync"})
 end)
end
function Controller:Destroy()
 for _,c in ipairs(self._connections) do c:Disconnect() end
 self._presentation:Clear()
 if self._selection then self._selection:Destroy() end
 if self._hud then self._hud.Enabled=false end
end
return Controller
