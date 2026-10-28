--!nonstrict
-- Server-owned cosmetic display. Never creates an equipped Tool or executes asset scripts.
local Players=game:GetService('Players')
local StarterPlayer=game:GetService('StarterPlayer')
local Service={Name='BackSlapService'}
local function disconnect(list)for _,c in ipairs(list)do c:Disconnect()end;table.clear(list)end
function Service.Build(template,anchor,reward)
 assert(template:IsA('Tool')and anchor:IsA('Attachment')and anchor.Parent:IsA('BasePart'),'InvalidBackSlapResource')
 local copy=template:Clone()
 local root=copy:FindFirstChild('Hand')or copy:FindFirstChild('Handle')
 if not root or not root:IsA('BasePart')then copy:Destroy();return nil end
 local mount=root:FindFirstChild('SlapBackAttachment')
 local offset=if mount and mount:IsA('Attachment')then mount.CFrame:Inverse()else CFrame.identity
 local origin=root.CFrame
 local model=Instance.new('Model');model.Name='EquippedBackSlap';model:SetAttribute('BackSlapCosmetic',true)
 model:SetAttribute('RewardId',reward.RewardId);model:SetAttribute('SlapId',reward.SlapId);model:SetAttribute('VariationId',reward.VariationId)
 for _,o in ipairs(copy:GetDescendants())do
  if o:IsA('LuaSourceContainer')or o:IsA('JointInstance')or o:IsA('Constraint')or o:IsA('BodyMover')or o:IsA('ProximityPrompt')or o:IsA('ClickDetector')then o:Destroy()
  elseif o:IsA('Highlight')and o.Adornee==copy then o.Adornee=model
  elseif o:IsA('BasePart')then o.Anchored=false;o.Massless=true;o.CanCollide=false;o.CanTouch=false;o.CanQuery=false;o.AssemblyLinearVelocity=Vector3.zero;o.AssemblyAngularVelocity=Vector3.zero end
 end
 for _,child in ipairs(copy:GetChildren())do child.Parent=model end;copy:Destroy();model.PrimaryPart=root
 local target=anchor.WorldCFrame*offset
 for _,part in ipairs(model:GetDescendants())do if part:IsA('BasePart')then
  local relative=origin:ToObjectSpace(part.CFrame);part.CFrame=target*relative
  if part~=root then local w=Instance.new('Weld');w.Name='BackSlapGeometry';w.Part0=root;w.Part1=part;w.C0=relative;w.Parent=part end
 end end
 local w=Instance.new('Weld');w.Name='BackSlapMount';w.Part0=anchor.Parent;w.Part1=root;w.C0=anchor.CFrame*offset;w.Parent=root
 return model
end
function Service:Init(context)self._context=context;self._states={};self._connections={}end
function Service:_clear(state)if state.Model then state.Model:Destroy();state.Model=nil end;state.Key=nil end
function Service:Refresh(player)
 local state=self._states and self._states[player];if not state then return end
 local char=player.Character
 if not char or char~=state.Character or state.AppearancePending then self:_clear(state);return end
 local hum=char:FindFirstChildOfClass('Humanoid')
 if not hum or hum.RigType~=Enum.HumanoidRigType.R6 or hum.Health<=0 then self:_clear(state);return end
 for _,o in ipairs(char:GetChildren())do if o:IsA('Tool')and o:GetAttribute('IsSlapWeapon')==true then self:_clear(state);return end end
 local torso=char:FindFirstChild('Torso');local anchor=torso and torso:FindFirstChild('slap_here')
 if not anchor or not anchor:IsA('Attachment')then self:_clear(state);return end
 local crates=self._context:GetService('CrateService');local ps=self._context:GetService('PlayerService')
 if not crates or not ps or not ps:IsShopDataReady(player)then self:_clear(state);return end
 local reward=crates:ResolveEquipped(player);local template=reward and crates:GetRewardTemplate(reward)
 if not template then self:_clear(state);return end
 local key=reward.RewardId
 if state.Key==key and state.Model and state.Model.Parent==char then return end
 self:_clear(state)
 local model=Service.Build(template,anchor,reward)
 if model then
  -- Same cosmetic fallback as the actual weapon; physical authored variants stay intact.
  crates:ApplyVariation(model,reward)
  model.Parent=char;state.Model=model;state.Key=key
 end
end
function Service:_queue(player)
 local state=self._states[player];if not state or state.Queued then return end;state.Queued=true
 task.defer(function()if self._states[player]==state then state.Queued=false;self:Refresh(player)end end)
end
function Service:_character(player,char)
 local state=self._states[player];if not state then return end
 disconnect(state.CharacterConnections);self:_clear(state);state.Character=char;state.AppearancePending=true
 table.insert(state.CharacterConnections,char.ChildAdded:Connect(function()self:_queue(player)end))
 table.insert(state.CharacterConnections,char.ChildRemoved:Connect(function()self:_queue(player)end))
 table.insert(state.CharacterConnections,char.DescendantAdded:Connect(function(o)if o.Name=='slap_here'then self:_queue(player)end end))
 task.spawn(function()
  local humanoid=char:WaitForChild('Humanoid',10)
  local template=StarterPlayer:FindFirstChild('StarterCharacter')
  local templateTorso=template and template:FindFirstChild('Torso')
  local authored=templateTorso and templateTorso:FindFirstChild('slap_here')
  -- A custom white R6 requires explicit avatar appearance application. Never reload the Character.
  if humanoid and humanoid:IsA('Humanoid')and humanoid.RigType==Enum.HumanoidRigType.R6 and template and player.UserId>0 then
   local ok,err=pcall(function()
    local description=Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId)
    if self._states[player]~=state or player.Character~=char or player:GetAttribute('MatchId')then description:Destroy();return end
    local applied,failure=pcall(humanoid.ApplyDescriptionAsync,humanoid,description)
    description:Destroy();if not applied then error(failure)end
   end)
   if not ok then warn('[BackSlapService] Avatar appearance unavailable for '..player.Name..': '..tostring(err))end
  end
  if self._states[player]~=state or player.Character~=char then return end
  -- Appearance may recreate body parts; restore only our authored attachment when absent.
  local torso=char:FindFirstChild('Torso')
  if torso and authored and authored:IsA('Attachment')and not torso:FindFirstChild('slap_here')then authored:Clone().Parent=torso end
  state.AppearancePending=false
  if humanoid and humanoid:IsA('Humanoid')then table.insert(state.CharacterConnections,humanoid.Died:Connect(function()self:_clear(state)end))end
  self:_queue(player)
 end)
end
function Service:_remove(player)
 local state=self._states[player];if not state then return end
 self._states[player]=nil;disconnect(state.Connections);disconnect(state.CharacterConnections);self:_clear(state)
end
function Service:_bind(player)
 if self._states[player]then return end
 local state={Connections={},CharacterConnections={}};self._states[player]=state
 table.insert(state.Connections,player.CharacterAdded:Connect(function(c)self:_character(player,c)end))
 table.insert(state.Connections,player.CharacterRemoving:Connect(function()disconnect(state.CharacterConnections);self:_clear(state);state.Character=nil end))
 table.insert(state.Connections,player.CharacterAppearanceLoaded:Connect(function()self:_queue(player)end))
 if player.Character then self:_character(player,player.Character)end
end
function Service:Start()
 table.insert(self._connections,Players.PlayerAdded:Connect(function(p)self:_bind(p)end))
 table.insert(self._connections,Players.PlayerRemoving:Connect(function(p)self:_remove(p)end))
 for _,p in ipairs(Players:GetPlayers())do self:_bind(p)end
end
return Service
