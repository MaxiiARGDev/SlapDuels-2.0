--!nonstrict
-- Local movement-state cleanup only. Server attributes decide retirement and respawn.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Input=game:GetService("UserInputService")
local player=Players.LocalPlayer
local character=script.Parent
local humanoid=character:WaitForChild("Humanoid")
local connections={}
local jumpTouches={}
local buttons={}
local paused=false
local observedRevision=0
local focused=true
local savedJumping,savedAutoJump
local barrier
local settledGeneration
local lobbyGeneration
-- No cross-sandbox module dependency: diagnostics are selected by the server.
local function heldJump()
 if not focused then return false end
 if Input:IsKeyDown(Enum.KeyCode.Space) or next(jumpTouches)~=nil then return true end
 for _,pad in ipairs(Input:GetConnectedGamepads()) do if Input:IsGamepadButtonDown(pad,Enum.KeyCode.ButtonA) then return true end end
 return false
end
local function release()
 if not paused or player.Character~=character or character:GetAttribute("ArenaRespawnPending") then return end
 if barrier then barrier:Disconnect() end
 local generation=character:GetAttribute("ArenaPhysicsGeneration")
 local sessionId=player:GetAttribute("MatchId")
 -- Clear held state at a physics boundary, after default input has processed key/touch release.
 barrier=RunService.PreSimulation:Connect(function()
  barrier:Disconnect();barrier=nil
  if player.Character~=character or not humanoid.Parent or character:GetAttribute("ArenaRespawnPending")
   or player:GetAttribute("MatchId")~=sessionId
   or generation~=character:GetAttribute("ArenaPhysicsGeneration") then return end
  humanoid.Jump=false
  -- The slap owner can still have local Physics/angular velocity when the server
  -- returns ownership. Settle once at the first playable physics boundary,
  -- including when old jump input is held. Never zero later legitimate movement.
  if settledGeneration~=generation then
   -- A valid NEW hit delivered after respawn must retain its competitive physics.
   if character:GetAttribute("ArenaAcceptedLaunchGeneration")~=generation then
    for _,part in ipairs(character:GetDescendants()) do
     if part:IsA("BasePart") then part.AssemblyLinearVelocity=Vector3.zero;part.AssemblyAngularVelocity=Vector3.zero end
    end
    humanoid.PlatformStand=false
    humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp,true)
    humanoid:ChangeState(Enum.HumanoidStateType.Running)
   end
   settledGeneration=generation
   if character:GetAttribute("ArenaRespawnDebug")==true then
    local root=character:FindFirstChild("HumanoidRootPart")
    print("[RespawnDebug] ClientSettled",player.UserId,character:GetAttribute("ArenaEliminationId"),generation,
     humanoid:GetState().Name,root and root.AssemblyLinearVelocity,root and root.AssemblyAngularVelocity)
   end
  end
  if heldJump() then return end
  humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,savedJumping)
  humanoid.AutoJumpEnabled=savedAutoJump
  paused=false
 end)
end
local function pause()
  if barrier then barrier:Disconnect();barrier=nil end
  if not paused then
   savedJumping=humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping)
   savedAutoJump=humanoid.AutoJumpEnabled
  end
  paused=true
  humanoid.Jump=false
  humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping,false)
  humanoid.AutoJumpEnabled=false
end
local function refresh()
 -- Revision survives replication coalescing when a 0ms retirement is already complete.
 local revision=character:GetAttribute("ArenaRespawnRevision") or 0
 if revision~=observedRevision then observedRevision=revision;pause() end
 local generation=character:GetAttribute("ArenaPhysicsGeneration")
 if character:GetAttribute("ArenaPhysicsPhase")=="Lobby" and lobbyGeneration~=generation then
  lobbyGeneration=generation;pause()
 end
 if character:GetAttribute("ArenaRespawnPending") then pause() else release() end
end
local function trackButton(object)
 if object.Name~="JumpButton" or not object:IsA("GuiButton") or buttons[object] then return end
 buttons[object]=true
 table.insert(connections,object.InputBegan:Connect(function(input)
  if input.UserInputType==Enum.UserInputType.Touch then jumpTouches[input]=true end
 end))
 table.insert(connections,object.InputEnded:Connect(function(input)jumpTouches[input]=nil;release()end))
end
local playerGui=player:WaitForChild("PlayerGui")
for _,object in ipairs(playerGui:GetDescendants()) do trackButton(object) end
table.insert(connections,playerGui.DescendantAdded:Connect(trackButton))
table.insert(connections,Input.InputEnded:Connect(function(input)jumpTouches[input]=nil;release()end))
table.insert(connections,Input.WindowFocusReleased:Connect(function()focused=false;table.clear(jumpTouches);release()end))
table.insert(connections,Input.WindowFocused:Connect(function()focused=true;release()end))
table.insert(connections,character:GetAttributeChangedSignal("ArenaRespawnPending"):Connect(refresh))
table.insert(connections,character:GetAttributeChangedSignal("ArenaPhysicsGeneration"):Connect(refresh))
table.insert(connections,character:GetAttributeChangedSignal("ArenaRespawnRevision"):Connect(refresh))
table.insert(connections,character:GetAttributeChangedSignal("ArenaPhysicsPhase"):Connect(refresh))
table.insert(connections,player:GetAttributeChangedSignal("MatchId"):Connect(refresh))
table.insert(connections,humanoid:GetPropertyChangedSignal("Jump"):Connect(function()if paused and humanoid.Jump then humanoid.Jump=false end end))
table.insert(connections,character.Destroying:Connect(function()
 if barrier then barrier:Disconnect() end
 for _,connection in ipairs(connections) do connection:Disconnect() end
end))
refresh()
