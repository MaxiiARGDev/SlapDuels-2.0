--!nonstrict
-- Session-authorized presentation and independent Studio preview orchestrator.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Config = require(game.ReplicatedStorage.Shared.EndCinematicConfig)
local modules = script.Parent.Parent.EndCinematic.Modules
local Camera = require(modules.EndCinematicCamera)
local Transition = require(modules.EndCinematicTransition)
local Avatars = require(modules.EndCinematicAvatars)
local Animations = require(modules.EndCinematicAnimations)
local Particles = require(modules.EndCinematicParticles)
local Audio = require(modules.EndCinematicAudio)
local HUD = require(modules.EndCinematicHUD)
local Ranking = require(modules.EndCinematicRanking)
local Billboards = require(modules.EndCinematicBillboards)
local Controller = { Name = "EndCinematicController", _serial = 0 }

function Controller:Initialize()
 if self._initialized then return end
 self._initialized = true
end

function Controller:_getMusicController()
 if self._context and typeof(self._context.GetController) == "function" then
  return self._context:GetController("MusicController")
 end
 local controllers = script.Parent
 local musicScript = controllers and controllers:FindFirstChild("MusicController")
 if musicScript and musicScript:IsA("ModuleScript") then
  local ok, mod = pcall(require, musicScript)
  if ok then return mod end
 end
 return nil
end

function Controller:IsPlaying() return self._run ~= nil end

function Controller:SetPreviewOptions(floatingEnabled,billboardsEnabled)
 local run=self._run
 if not RunService:IsStudio() or not run or (run.Context and run.Context.IsMatch) then return false end
 run.FloatingEnabled=floatingEnabled
 run.BillboardsEnabled=billboardsEnabled
 if floatingEnabled then
  if run.CameraDone then Camera.StartFloating(run,run.Destination) end
 else Camera.StopFloating(run) end
 if not billboardsEnabled then Billboards.Cleanup(run)
 elseif run.CameraDone and run.WalksDone>=#run.Rigs then
  task.spawn(function()
   local ok,failure=pcall(Billboards.Play,run)
   if not ok and run:IsAlive() then warn(failure); self:Stop() end
  end)
 end
 return true
end

function Controller:Stop()
 local run = self._run
 if not run then return end
 self._run = nil
 self._serial += 1
 for _, connection in ipairs(run.Connections) do connection:Disconnect() end
 for _, tween in ipairs(run.Tweens) do tween:Cancel(); tween:Destroy() end
 -- Each subsystem cleans only its own resources; invalidation happens first.
 for _, subsystem in ipairs({ Animations, Audio, Particles, Billboards, Avatars, Transition, HUD, Camera }) do
  if subsystem.Cleanup then
   local ok, err = pcall(subsystem.Cleanup, run)
   if not ok then warn("[EndCinematic] Cleanup: " .. tostring(err)) end
  end
 end
 for _, object in ipairs(run.Resources) do object:Destroy() end
 if run.MusicReason then
  local musicController = self:_getMusicController()
  if musicController and typeof(musicController.Resume) == "function" then
   local fadeIn = (Config.Music and Config.Music.FadeInDuration) or 0.6
   musicController:Resume(run.MusicReason, run.MusicToken, fadeIn)
  end
  run.MusicReason = nil
  run.MusicToken = nil
 end
 if run.Context and run.Context.OnStopped then run.Context.OnStopped() end
end

function Controller:Destroy()
 self:Stop()
 self._initialized = false
end

local function finite(value)
 return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function Controller:Play(data, sceneContext)
 self:Initialize()
 local isMatch = sceneContext and sceneContext.IsMatch == true
 if isMatch then
  if self._serverPlayback ~= sceneContext or sceneContext.Payload ~= data then return false, "UnauthorizedContext" end
 else
  if not RunService:IsStudio() then return false, "PreviewOnly" end
  if Players.LocalPlayer:GetAttribute("MatchId") ~= nil then return false, "MatchActive" end
 end
 if self:IsPlaying() then return false, "AlreadyPlaying" end
 local stage = sceneContext and sceneContext.Scene
 if not stage then return false, "SceneContextRequired" end
 if type(data) ~= "table" or type(data.Winners) ~= "table" or (#data.Winners < 1 and data.WinningTeam ~= "Draw") or #data.Winners > Config.Winners.MaxVisible then return false, "InvalidWinners" end
 if type(data.MatchId) ~= "string" or (data.WinningTeam ~= "Red" and data.WinningTeam ~= "Blue" and data.WinningTeam ~= "Draw") or type(data.Score) ~= "table" or not finite(data.Score.Red) or not finite(data.Score.Blue) then return false, "InvalidPayload" end
 if data.EligibleParticipantCount ~= nil and (not finite(data.EligibleParticipantCount) or data.EligibleParticipantCount < 1 or data.EligibleParticipantCount % 1 ~= 0) then return false, "InvalidParticipantCount" end
 local winners = {}
 for _, w in ipairs(data.Winners) do
  if type(w) ~= "table" or not finite(w.UserId) or w.UserId == 0 or type(w.DisplayName) ~= "string" or not finite(w.Slot) then return false, "InvalidWinner" end
  table.insert(winners, table.clone(w))
 end
 table.sort(winners, function(a,b) return a.Slot == b.Slot and a.UserId < b.UserId or a.Slot < b.Slot end)
 -- Explicit Mode always wins, including XvX with only one connected winner.
 -- Legacy no-Mode previews: one winner uses 1v1; multiple winners use XvX.
 local mode = data.Mode
 if mode == nil then mode = #winners == 1 and "1v1" or "XvX" end
 if type(mode) ~= "string" or mode == "" then return false, "InvalidMode" end
 local ranking,rankingError=Ranking.Resolve(data,isMatch)
 if not ranking then return false,rankingError end
 local visible=ranking.VisibleParticipants
 local from, target, cameraError = Camera.Resolve(stage, mode)
 if not from then return false, cameraError end
 local slots = stage:FindFirstChild("Players")
 for index = 1,#visible do
  local slot = slots and slots:FindFirstChild("SlotPlayer_" .. index)
  if not slot or not slot:IsA("BasePart") then return false, "InsufficientSlots" end
 end
 if not workspace.CurrentCamera then return false, "CameraMissing" end
 local gui, hudError = HUD.Resolve()
 if not gui then return false, hudError end
 self._serial += 1
 local run = { Id = self._serial, PlaybackId = self._serial, Mode = mode, Resources = {}, Connections = {}, Tweens = {}, Tracks = {}, Rigs = {}, WalksDone = 0, Destination = target }
 self._run = run
 run.Context = sceneContext
 run.Scene = stage
 run.Ranking=ranking
 run.WinningTeam=data.WinningTeam
 run.FloatingEnabled=not sceneContext or sceneContext.FloatingEnabled~=false
 run.BillboardsEnabled=not sceneContext or sceneContext.BillboardsEnabled~=false
 if not Config.Music or Config.Music.SuspendDuringCinematic ~= false then
  local musicController = self:_getMusicController()
  if musicController and typeof(musicController.Suspend) == "function" then
   local fadeOut = (Config.Music and Config.Music.FadeOutDuration) or 0.4
   local reason = if isMatch then "EndCinematic" else "EndCinematicPreview"
   run.MusicReason = reason
   run.MusicToken = musicController:Suspend(reason, fadeOut)
  end
 end
 function run:IsAlive() return Controller._run == self and Controller._serial == self.Id end
 function run:Tween(object, duration, properties)
  if not self:IsAlive() then return false end
  local tween = TweenService:Create(object, TweenInfo.new(math.max(duration,0.001), Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), properties)
  table.insert(self.Tweens,tween)
  tween:Play()
  local result = tween.Completed:Wait()
  return self:IsAlive() and result == Enum.PlaybackState.Completed
 end
 run.Container = Instance.new("Folder")
 run.Container.Name = "EndCinematicLocal_" .. run.Id
 run.Container.Parent = workspace
 table.insert(run.Resources,run.Container)
 local function stop() if run:IsAlive() then self:Stop() end end
 run.OnRigRemoved=stop
 local function guarded(callback)
  task.spawn(function()
   local ok,err = xpcall(callback,debug.traceback)
   if not ok and run:IsAlive() then warn("[EndCinematic] " .. tostring(err)); stop() end
  end)
 end
 table.insert(run.Connections,workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(stop))
 table.insert(run.Connections,stage.Destroying:Connect(stop))
 table.insert(run.Connections,Players.LocalPlayer.CharacterAdded:Connect(stop))
 table.insert(run.Connections,Players.LocalPlayer:GetAttributeChangedSignal("MatchId"):Connect(function()
  local id = Players.LocalPlayer:GetAttribute("MatchId")
  if (isMatch and id ~= data.MatchId) or (not isMatch and id ~= nil) then stop() end
 end))
 guarded(function()
  HUD.Prepare(run,gui,sceneContext and sceneContext.OnReturn or stop)
  run.Panels = Transition.Prepare(run)
  Audio.PlayTransition(run, true)
  if not Transition.Play(run,run.Panels,true) then return end
  Camera.Prepare(run,from)
  for index,winner in ipairs(visible) do
   if not run:IsAlive() then return end
   Avatars.Prepare(run,winner,slots["SlotPlayer_" .. index],stage,target)
  end
  if not run:IsAlive() then return end
  Billboards.Prepare(run)
  Particles.Prepare(run,stage)
  Audio.Prepare(run,stage)
  task.wait(Config.Transition.ClosedHoldDuration)
  if not run:IsAlive() then return end
  if isMatch then
   sceneContext.OnPrepared()
   local deadline = os.clock() + Config.Results.PreparationTimeout
   while run:IsAlive() and not sceneContext.StartAt and os.clock() < deadline do task.wait() end
   if not run:IsAlive() then return end
   if not sceneContext.StartAt then stop(); return end
   while run:IsAlive() and workspace:GetServerTimeNow() < sceneContext.StartAt do task.wait() end
   if not run:IsAlive() then return end
  end
  Particles.Play(run); Audio.Play(run)
  guarded(function()
   Camera.Play(run,from,target)
   if run:IsAlive() then Particles.Stop(run) end
  end)
  for index,entry in ipairs(run.Rigs) do guarded(function() Animations.Play(run,entry,index) end) end
  Audio.PlayTransition(run, false)
  if not Transition.Play(run,run.Panels,false) then return end
  while run:IsAlive() and (not run.CameraDone or run.WalksDone < #run.Rigs) do task.wait() end
  task.wait(Config.HUD.ShowDelay)
  if run:IsAlive() then
   Billboards.Play(run)
   HUD.Play(run,data,winners)
  end
 end)
 return true
end
function Controller:Init(context)
 self._context = context
 self:Initialize()
 self._closedResults = self._closedResults or {}
end

function Controller:Start()
 if self._remoteConnection then return end
 local match = game.ReplicatedStorage:WaitForChild("Remotes", 10)
 match = match and match:WaitForChild("Match", 10)
 local remote = match and match:WaitForChild("EndCinematic", 10)
 local actions = match and match:WaitForChild("EndCinematicAction", 10)
 if not remote or not actions then warn("[EndCinematic] Match remotes missing"); return end
 self._closedResults = self._closedResults or {}
 self._remoteConnection = remote.OnClientEvent:Connect(function(phase, payload)
  if type(payload) ~= "table" or type(payload.SessionId) ~= "string"
   or payload.MatchId ~= payload.SessionId or type(payload.Token) ~= "string"
   or not finite(payload.StateVersion) then return end
  local id = payload.SessionId
  local pending = self._serverPlayback
  if phase == "Returned" then
   if pending and pending.Payload.SessionId == id and pending.Payload.Token == payload.Token
    and pending.Payload.StateVersion == payload.StateVersion then
    pending.Exited = true
    self._closedResults[id] = true
    self:Stop()
    self._serverPlayback = nil
   end
   return
  end
  if phase == "Start" then
   if pending and pending.Payload.SessionId == id and pending.Payload.Token == payload.Token
    and pending.Payload.StateVersion == payload.StateVersion and not pending.Exited and finite(payload.StartAt) then
    pending.StartAt = pending.StartAt or payload.StartAt
   end
   return
  end
  if phase ~= "Prepare" or self._closedResults[id] or pending then return end
  if type(payload.EligibleParticipantUserIds) ~= "table"
   or not table.find(payload.EligibleParticipantUserIds, Players.LocalPlayer.UserId)
   or payload.SceneContainer ~= "Match_" .. id or payload.SceneName ~= "ScenarioFinal" then return end
  if Players.LocalPlayer:GetAttribute("MatchId") ~= id then return end
  self:Stop() -- Stop a development preview before claiming the real presentation.
  pending = { IsMatch = true, Payload = payload, Exited = false }
  self._serverPlayback = pending
  local function send(action)
   if pending.Exited or self._serverPlayback ~= pending then return end
   actions:FireServer(action, id, payload.StateVersion, payload.Token)
  end
  pending.OnReturn = function() send("Return") end
  pending.OnPrepared = function() send("Prepared") end
  pending.OnStopped = function()
   if not pending.Exited and self._serverPlayback == pending then
    send("Failed")
    pending.Exited = true
    self._closedResults[id] = true
    self._serverPlayback = nil
   end
  end
  task.spawn(function()
   local deadline = os.clock() + Config.Results.SceneWaitTimeout
   if typeof(payload.SceneOrigin) == "Vector3" then
    task.spawn(function() pcall(function() Players.LocalPlayer:RequestStreamAroundAsync(payload.SceneOrigin, Config.Results.SceneWaitTimeout) end) end)
   end
   local scene
   while self._serverPlayback == pending and not pending.Exited and os.clock() < deadline do
    local active = workspace:FindFirstChild("ActiveMatches")
    local container = active and active:FindFirstChild(payload.SceneContainer)
    local candidate = container and container:FindFirstChild(payload.SceneName)
    if candidate and candidate:IsA("Model") and candidate:GetAttribute("SessionId") == id
     and container:GetAttribute("SessionId") == id then
     local from = Camera.Resolve(candidate, payload.Mode)
     local slots = candidate:FindFirstChild("Players")
     local descriptions = candidate:FindFirstChild("WinnerDescriptions")
     local complete = from ~= nil and slots ~= nil and descriptions ~= nil
     local visible=payload.ResultSnapshot and payload.ResultSnapshot.VisibleParticipants or payload.Winners or {}
     for index, winner in ipairs(visible) do
      complete = complete and slots:FindFirstChild("SlotPlayer_" .. index) ~= nil
       and (not winner.DescriptionKey or descriptions:FindFirstChild(winner.DescriptionKey) ~= nil)
     end
     if complete then scene = candidate; break end
    end
    task.wait(.05)
   end
   if self._serverPlayback ~= pending or pending.Exited then return end
   if not scene or Players.LocalPlayer:GetAttribute("MatchId") ~= id then
    pending.OnStopped(); return
   end
   pending.Scene = scene
   local ok, reason = self:Play(payload, pending)
   if not ok then warn("[EndCinematic] Match presentation rejected: " .. tostring(reason)); pending.OnStopped() end
  end)
 end)
end
return Controller
