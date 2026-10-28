--!nonstrict
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local UIS=game:GetService("UserInputService")
local RunService=game:GetService("RunService")
local Definitions=require(RS.Shared.AbilityDefinitions)
local Catalog=require(RS.Shared.AbilityCatalog)
local Diagnostics=require(RS.Shared.AbilityDiagnostics)
local Presentation=require(script.Parent.Parent.Abilities.AbilityPresentation)
local Selection=require(script.Parent.Parent.Abilities.AbilitySelection)
local Controller={Name="AbilityController"}
function Controller:_trace(phase,reason,p,extra)
 if not Diagnostics.Enabled() then return end
 local row={UserId=Players.LocalPlayer.UserId,SessionId=p and p.SessionId,RoundId=p and p.RoundId,
  AbilityId=p and p.AbilityId,Playing=p and p.Playing,Preparing=p and p.Preparing,
  Generation=p and p.CharacterGeneration,LifeId=p and p.LifeId,Reason=reason}
 for key,value in pairs(extra or {})do row[key]=value end
 Diagnostics.Emit("Client",phase,row)
end
function Controller:Init(context)
 self._context=context;self._connections={};self._revision=0;self._lastRequest=0;self._presentation=Presentation.new()
 self._traceState=nil;self._inputSource=nil
end
function Controller:_send(action)
 local p=self._payload
 if not p or not p.Playing then self:_trace("InputBlocked","NoPlayingSnapshot",p);return end
 if os.clock()-self._lastRequest<Definitions.RequestInterval then self:_trace("InputBlocked","ClientRateLimited",p);return end
 local char=Players.LocalPlayer.Character
 local hum=char and char:FindFirstChildOfClass("Humanoid")
 if not hum or hum.WalkSpeed<=0 or hum.PlatformStand or char:GetAttribute("ArenaRespawnPending") then
  self:_trace("InputBlocked","CharacterMovementBlocked",p);return
 end
 self._lastRequest=os.clock()
 local traceId=Diagnostics.NewTrace()
 self:_trace("RequestSent",nil,p,{TraceId=traceId,Action=action,Source=self._inputSource})
 self._request:FireServer({Action=action,SessionId=p.SessionId,RoundId=p.RoundId,
  CharacterGeneration=char:GetAttribute("ArenaPhysicsGeneration") or 0,AbilityId=p.AbilityId,
  ActivationId=p.ActivationId,LifeId=p.LifeId,Direction=hum.MoveDirection,TraceId=traceId})
end
function Controller:_activate()
 local p=self._payload
 local d=p and Catalog.GetItem(p.AbilityId)
 if not d then self:_trace("InputBlocked","CatalogEntryMissing",p);return end
 self:_send(if p.ActivationId and d.Input.ActivePrimaryAction then d.Input.ActivePrimaryAction else "Activate")
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
 local d=Catalog.GetItem(p.AbilityId)
 if not d then button.Visible=false;return end
 local t=workspace:GetServerTimeNow()
 local cooldown=math.max(0,(p.CooldownUntil or 0)-t)
 local remaining=math.max(0,(p.ActiveUntil or 0)-t)
 local hum=char and char:FindFirstChildOfClass("Humanoid")
 local blocked=not hum or hum.WalkSpeed<=0 or hum.PlatformStand or char:GetAttribute("ArenaRespawnPending")
 button.AbilityName.Text=d.DisplayName
 button.Icon.Image=d.Icon;button.Icon.Visible=d.Icon~=""
 button.CooldownLabel.Text=if not p.Playing then "PREPARACIÓN" elseif blocked then "BLOQUEADA" elseif remaining>0 then
  string.format("%s · %.1fs",d.ActiveLabel,remaining)
  elseif cooldown>0 then string.format("%.1fs",cooldown) else (if UIS.TouchEnabled then "ACTIVAR" else "E · LISTA")
 button.CooldownOverlay.Visible=cooldown>0 and remaining<=0
 button.Active=p.Playing==true and not blocked and (cooldown<=0 or (remaining>0 and d.Input.ActivePrimaryAction~=nil))
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
   if p.Kind=="AbilityDiagnostic" then
    self:_trace("ServerResult",p.Reason,p,{TraceId=p.TraceId,ActivationId=p.ActivationId,Result=p.Result});return
   end
   if p.Kind=="AbilityCue" then self._presentation:Impact(p);return end
   if p.Kind~="State" or type(p.Revision)~="number" or p.Revision<=self._revision then return end
   if p.Catalog then Catalog.Apply(p.Catalog) end
   self._revision=p.Revision;self._payload=p
   if Diagnostics.Enabled() then
    local key=table.concat({tostring(p.SessionId),tostring(p.RoundId),tostring(p.State),tostring(p.AbilityId),tostring(p.ActivationId),tostring(p.LifeId),tostring(p.Playing),tostring(p.Preparing)},"/")
    if key~=self._traceState then
     self._traceState=key;self:_trace("SnapshotChanged",p.State,p,{ActivationId=p.ActivationId,CatalogVersion=Catalog.Get().Version})
    end
   end
   self._selection:Render(p);self._presentation:Reconcile(p);self:_render()
  end))
  table.insert(self._connections,self._hud.AbilityButton.Activated:Connect(function()
   self._inputSource="AbilityButton";self:_trace("InputDetected",nil,self._payload,{Source=self._inputSource});self:_activate()
  end))
  table.insert(self._connections,UIS.InputBegan:Connect(function(input,processed)
   if input.KeyCode==Enum.KeyCode.E then
    self._inputSource="E"
    self:_trace("InputDetected",if processed then "Processed" elseif UIS:GetFocusedTextBox() then "TextBoxFocused" else "Eligible",self._payload,{Source="E"})
    if not processed and not UIS:GetFocusedTextBox() then self:_activate() end
   end
  end))
  table.insert(self._connections,UIS.JumpRequest:Connect(function()
   local p=self._payload
   local d=p and Catalog.GetItem(p.AbilityId)
   if d and p.ActivationId and d.Input.JumpAction then self:_send(d.Input.JumpAction) end
  end))
  table.insert(self._connections,Players.LocalPlayer:GetAttributeChangedSignal("MatchId"):Connect(function()
   self._presentation:Clear();self:_render()
  end))
  table.insert(self._connections,RunService.RenderStepped:Connect(function()
   self:_render();self._presentation:Tick()
  end))
  self._request:FireServer({Action="Sync"})
  self:_trace("Ready",nil,nil,{RemotesReady=true,CatalogVersion=Catalog.Get().Version})
 end)
end
function Controller:Destroy()
 Diagnostics.Forget("Client",Players.LocalPlayer.UserId)
 for _,c in ipairs(self._connections) do c:Disconnect() end
 self._presentation:Clear()
 if self._selection then self._selection:Destroy() end
 if self._hud then self._hud.Enabled=false end
end
return Controller
