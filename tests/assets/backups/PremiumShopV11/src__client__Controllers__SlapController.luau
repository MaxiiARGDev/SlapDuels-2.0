--!strict
-- SlapController
-- Controlador cliente de Slaps.
-- Responsabilidad exclusiva:
-- 1. Detectar cuando el jugador equipa un Slap (Tool con Configuration.Power).
-- 2. Conectar al evento Tool.Activated.
-- 3. Predecir Swing inmediatamente y reconciliar solo su presentación.
-- 4. Solicitar la ejecucion autoritativa al servidor via ReplicatedStorage.Remotes.Combat.PerformSlap.
-- 5. Manejar un debounce local liviano para evitar saturar la red con clics repetidos.
-- NO calcula daño, distancia autoritativa, knockback ni fisica.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local Config = require(ReplicatedStorage.Shared.Config)

local localPlayer = Players.LocalPlayer

local SlapController = {}
SlapController.Name = "SlapController"

SlapController._context = nil :: any
SlapController._performSlapRemote = nil :: RemoteEvent?
SlapController._equippedTool = nil :: Tool?
SlapController._activatedConn = nil :: RBXScriptConnection?
SlapController._swingTrack = nil :: AnimationTrack?
SlapController._localNextSlapTime = 0
SlapController._awaitingUntil = 0
SlapController._predictionUntil = 0
SlapController._lastSequence = 0
SlapController._requestId = 0
SlapController._connections = {} :: { RBXScriptConnection }
SlapController._characterConnections = {} :: { RBXScriptConnection }
SlapController._pending = nil :: any
SlapController._scope = nil :: any
SlapController._sessionId = nil :: string?
SlapController._roundId = nil :: string?
SlapController._roundIndex = 0
SlapController._stateVersion = -1
SlapController._playing = false
SlapController._roundClosed = false
SlapController._visualStart = nil :: number?

function SlapController:_stopSwing(release: boolean?)
	local track = self._swingTrack
	if not track then return end
	pcall(function() track:Stop(0.05) end)
	if release then
		self._swingTrack = nil
		pcall(function() track:Destroy() end)
	end
end

function SlapController:GetCooldownState(now: number)
	local deadline = math.max(self._localNextSlapTime, self._predictionUntil)
	local pending = self._pending ~= nil and now < self._awaitingUntil
	local remaining = math.max(0, deadline - now)
	local blocked = remaining > 0 or now < self._awaitingUntil
	local startTime = self._visualStart or now
	local duration = math.max(0, deadline - startTime)
	local progress = if duration > 0 then math.clamp((now - startTime) / duration, 0, 1) else 1
	-- A pending result cannot visually advertise readiness when its provisional clock ends.
	if pending then progress = math.min(progress, 0.98) end
	return {
		Blocked = blocked, Pending = pending, Remaining = remaining, Deadline = deadline,
		Progress = if blocked then progress else 1,
		Text = if not blocked then "" elseif remaining > 0 then string.format("%.1f s", remaining) else "…",
	}
end

function SlapController:_hideNativeBackpack()
	if self._backpackHidden then return end
	local ok = pcall(function()
		if self._originalBackpackEnabled == nil then
			self._originalBackpackEnabled = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack)
		end
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	self._backpackHidden = ok
end

function SlapController:_renderSlot()
	local now = workspace:GetServerTimeNow()
	if not self._backpackHidden and now >= (self._nextBackpackAttempt or 0) then
		self._nextBackpackAttempt = now + 0.5; self:_hideNativeBackpack()
	end
	local root = self._slotRoot
	if not root then return end
	local tool = self._equippedTool
	local char = localPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local inMatch = localPlayer:GetAttribute("MatchId") ~= nil
		and localPlayer:GetAttribute("MatchId") == self._sessionId
	local visible = inMatch and tool ~= nil and tool.Parent == char and hum ~= nil and hum.Health > 0
		and char:GetAttribute("ArenaRespawnPending") ~= true
		and localPlayer:GetAttribute("ResultsSessionId") == nil
		and (self._matchState == "StartCountdown" or self._matchState == "Playing" or self._matchState == "PointRestartCountdown")
	root.Visible = visible
	if not visible then return end
	local slot = root.SlapSlot
	local name = tool:GetAttribute("DisplayName")
	if type(name) ~= "string" or name == "" then name = tool.ToolTip end
	if type(name) ~= "string" or name == "" then
		local configuredTool = slot:FindFirstChild("DefaultToolName")
		local configuredName = slot:FindFirstChild("DefaultDisplayName")
		name = if configuredTool and configuredName and tool.Name == configuredTool.Value then configuredName.Value else tool.Name
	end
	slot.NameLabel.Text = name or tool.Name
	slot.ToolIcon.Image = tool.TextureId
	slot.ToolIcon.Visible = tool.TextureId ~= ""
	slot.FallbackIcon.Visible = not slot.ToolIcon.Visible
	local view = self:GetCooldownState(now)
	local overlay = slot.CooldownOverlay
	overlay.Visible = view.Blocked
	overlay.CooldownTimeLabel.Text = view.Text
	overlay.CooldownBarBackground.CooldownBarFill.Size = UDim2.new(view.Progress, 0, 1, 0)
end

function SlapController:_trace(phase: string, reason: string?, data: any?)
	if not RunService:IsStudio() or ReplicatedStorage:GetAttribute("SlapDiagnosticsEnabled") ~= true then return end
	local second = math.floor(os.clock())
	if self._diagnosticSecond ~= second then self._diagnosticSecond = second; self._diagnosticCount = 0 end
	if self._diagnosticCount >= 12 then return end
	self._diagnosticCount += 1
	local p = if type(data) == "table" then data else (self._pending or {})
	print("[SlapTrace] " .. HttpService:JSONEncode({
		Build = "CombatSystemV132", Side = "Client", Phase = phase, UserId = localPlayer.UserId,
		RequestId = p.RequestId, AttackId = p.ServerAttackId or p.AttackId,
		PredictionId = p.PredictionId, SessionId = self._sessionId,
		RoundId = self._roundId, CharacterGeneration = self._scope and self._scope.Generation,
		RecoveryUntil = self._localNextSlapTime, RejectionReason = reason,
		PredictionUntil = self._predictionUntil, RequestTime = p.RequestTime,
		ReportedRecoveryUntil = p.RecoveryUntil, RecoveryType = p.Outcome,
		AttackStartTime = p.AttackStartTime, AttackWindowClosed = p.AttackWindowClosed,
		HitConfirmed = p.Hit,
		ServerTime = workspace:GetServerTimeNow(),
	}))
end

function SlapController:_resetRecovery()
	self._pending = nil; self._awaitingUntil = 0; self._localNextSlapTime = 0; self._predictionUntil = 0
	self._visualStart = nil
	self:_stopSwing()
end

function SlapController:_refreshScope()
	local char = localPlayer.Character
	local sessionId = localPlayer:GetAttribute("MatchId")
	local roundId = if sessionId == self._sessionId then self._roundId else nil
	local generation = char and (char:GetAttribute("ArenaPhysicsGeneration") or 0)
	local scope = self._scope
	if not scope or scope.Character ~= char or scope.Generation ~= generation
		or scope.SessionId ~= sessionId or scope.RoundId ~= roundId then
		self:_resetRecovery()
		self._scope = { Character = char, Generation = generation, SessionId = sessionId, RoundId = roundId }
	end
	return self._scope
end

function SlapController:_acceptMatch(data: any): boolean
	if type(data) ~= "table" or data.SessionId ~= localPlayer:GetAttribute("MatchId")
		or type(data.SessionId) ~= "string" or type(data.StateVersion) ~= "number" then return false end
	if self._sessionId ~= data.SessionId then
		self._sessionId = data.SessionId; self._roundId = nil; self._roundIndex = 0
		self._stateVersion = -1; self._roundClosed = false; self._playing = false
		self:_resetRecovery()
	end
	if data.StateVersion < self._stateVersion then return false end
	self._stateVersion = data.StateVersion
	return true
end

function SlapController:_onMatchState(state: string, data: any)
	if not self:_acceptMatch(data) then return end
	self._matchState = state
	if state ~= "Playing" then
		self._playing = false; self._roundClosed = true; self:_resetRecovery()
	end
end

function SlapController:_onCountdown(_remaining: number, label: string, data: any)
	if label ~= "PLAYING" or not self:_acceptMatch(data)
		or type(data.RoundId) ~= "string" or type(data.RoundIndex) ~= "number"
		or data.RoundIndex < self._roundIndex then return end
	if data.RoundId ~= self._roundId then
		if data.RoundIndex <= self._roundIndex then return end
		self._roundIndex = data.RoundIndex; self._roundId = data.RoundId; self._roundClosed = false
		self:_refreshScope()
	end
	if data.Resolved then self._roundClosed = true; self:_resetRecovery() end
	self._playing = not self._roundClosed
	if self._playing then self._matchState = "Playing" end
end

function SlapController:_onFeedback(data: any)
	local scope = self:_refreshScope()
	local pending = self._pending
		if type(data) ~= "table" or data.Protocol ~= 3 or not pending
		or data.RequestId ~= pending.RequestId
		or data.PredictionId ~= pending.PredictionId
		or data.Character ~= scope.Character or data.Generation ~= scope.Generation
		or data.SessionId ~= scope.SessionId or data.RoundId ~= scope.RoundId
		or type(data.Sequence) ~= "number" or data.Sequence <= self._lastSequence then
		self:_trace("FeedbackIgnored", "ObsoleteOrUnrelated", data); return
	end
	if data.Phase ~= "Started" and data.Phase ~= "Rejected" and data.Phase ~= "Result" and data.Phase ~= "Cancelled" then return end
	if data.Phase ~= "Rejected" and (type(data.AttackId) ~= "string" or data.Accepted ~= true) then return end
	if pending.ServerAttackId and data.AttackId ~= pending.ServerAttackId then return end
	local ready = data.RecoveryUntil
	if ready ~= nil and (type(ready) ~= "number" or ready ~= ready or math.abs(ready) == math.huge) then return end
	self._lastSequence = data.Sequence
	self:_trace("FeedbackReceived", data.Reason, data)
	if data.Phase == "Started" then
		-- The prediction already animated at input. Bind server identity; never replay.
		pending.ServerAttackId = data.AttackId
		return
	end
	if data.Phase == "Result" and (ready == nil or (data.Outcome ~= "Hit" and data.Outcome ~= "Miss")) then return end
	if ready then self._localNextSlapTime = math.max(self._localNextSlapTime, ready) end
	if data.Phase == "Rejected" or data.Phase == "Cancelled" or data.Reason == "SwingInvalidated" then
		-- Correct THIS prediction only; a stale reply never gets past the scope checks.
		self:_stopSwing()
		self:_trace("PredictionCancelled", data.Reason, data)
	end
	if data.WindowPending then
		-- A rejected retry cannot pretend an earlier in-flight swing ended.
		return
	end
	-- Only a confirmed result may replace the conservative local prediction.
	-- In particular, an early rejection cannot turn the input back on immediately.
	if data.Phase == "Result" then self._predictionUntil = 0 end
	self._pending = nil; self._awaitingUntil = 0
end

--------------------------------------------------------------------------------
-- Remotes
--------------------------------------------------------------------------------

function SlapController:_getPerformRemote(): RemoteEvent?
	if self._performSlapRemote then return self._performSlapRemote end

	local remotes = ReplicatedStorage:WaitForChild("Remotes", 5) :: Folder?
	local combat = remotes and remotes:WaitForChild("Combat", 5) :: Folder?
	local remote = combat and combat:WaitForChild("PerformSlap", 5) :: RemoteEvent?
	if remote and remote:IsA("RemoteEvent") then
		self._performSlapRemote = remote
		return remote
	end
	return nil
end

--------------------------------------------------------------------------------
-- Animaciones y Ciclo del Tool
--------------------------------------------------------------------------------

local function isSlapTool(tool: Instance): boolean
	if not tool:IsA("Tool") then return false end
	if tool:GetAttribute("IsSlapWeapon") ~= true then return false end
	local config = tool:FindFirstChild("Configuration")
	if config and config:FindFirstChild("Power") then
		return true
	end
	return false
end

function SlapController:_onToolEquipped(tool: Tool)
	if not isSlapTool(tool) then return end
	if self._equippedTool == tool and self._swingTrack and self._activatedConn and self._activatedConn.Connected then return end

	self:_onToolUnequipped()
	self._equippedTool = tool

	-- Preparar animacion de swing si existe
	local swingAnim = tool:FindFirstChild("Swing") :: Animation?
	local char = localPlayer.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")

	if swingAnim and swingAnim:IsA("Animation") and animator then
		local ok, track = pcall(function()
			return animator:LoadAnimation(swingAnim)
		end)
		if ok and track then
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = false
			self._swingTrack = track
		end
	end

	-- Conectar activacion del Tool
	self._activatedConn = tool.Activated:Connect(function()
		self:_onToolActivated(tool)
	end)
end

function SlapController:_onToolUnequipped()
	if self._activatedConn then
		self._activatedConn:Disconnect()
		self._activatedConn = nil
	end

	self:_stopSwing(true)

	self._equippedTool = nil
	-- Recovery belongs to the competitive life, never to this Tool.
end

function SlapController:_onToolActivated(tool: Tool)
	local scope = self:_refreshScope()
	local now = workspace:GetServerTimeNow()
	if self:GetCooldownState(now).Blocked then
		self:_trace("ClientBlocked", "RecoveryOrPending")
		return
	end
	local char = localPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not self._playing or self._roundClosed or not scope.RoundId or scope.SessionId ~= self._sessionId
		or self._equippedTool ~= tool or tool.Parent ~= char or not hum or hum.Health <= 0
		or hum.PlatformStand or hum:GetAttribute("MovementLocked") == true
		or char:GetAttribute("ArenaRespawnPending") or localPlayer:GetAttribute("ResultsSessionId") ~= nil then
		self:_trace("ClientBlocked", "CompetitiveState"); return
	end
	local remote = self:_getPerformRemote()
	if remote then
		-- Remote discovery may yield. Another input or lifecycle event can win meanwhile.
		now = workspace:GetServerTimeNow()
		if self:GetCooldownState(now).Blocked or self:_refreshScope() ~= scope
			or not self._playing or self._roundClosed or self._equippedTool ~= tool
			or tool.Parent ~= char or hum.Health <= 0 or hum.PlatformStand
			or hum:GetAttribute("MovementLocked") == true or char:GetAttribute("ArenaRespawnPending")
			or localPlayer:GetAttribute("ResultsSessionId") ~= nil then return end
		self._requestId += 1
		local predictionId = scope.SessionId .. ":Prediction:" .. tostring(localPlayer.UserId) .. ":" .. tostring(self._requestId)
		local request = { RequestId = self._requestId, PredictionId = predictionId, Character = char, Generation = scope.Generation,
			SessionId = scope.SessionId, RoundId = scope.RoundId }
		local combo = Config.Combat.SlapCombo
		local toolConfig = tool:FindFirstChild("Configuration")
		local cooldown = toolConfig and toolConfig:FindFirstChild("SlapCooldown")
		local predictedDuration = if combo.Enabled then combo.SwingWindow + combo.MissRecovery
			else (cooldown and cooldown.Value or Config.Combat.SlapCooldown)
		self._predictionUntil = now + predictedDuration
		self._visualStart = now
		self._pending = { RequestId = request.RequestId, AttackId = predictionId,
			PredictionId = predictionId, Tool = tool, RequestTime = now }
		self._awaitingUntil = now + 2 -- Transport retry only, never grants a hit or animation.
		self:_trace("ClientRequest")
		if self._swingTrack then
			pcall(function()
				self._swingTrack.Looped = false
				if self._swingTrack.IsPlaying then self._swingTrack:Stop(0) end
				self._swingTrack:Play(0.05, 1, 1.2)
			end)
		end
		self:_trace("PredictionPlayed")
		remote:FireServer(tool, request)
	end
end

--------------------------------------------------------------------------------
-- Enlace de Personaje
--------------------------------------------------------------------------------

function SlapController:_bindCharacter(character: Model)
	self._backpackHidden = false
	for _, connection in ipairs(self._characterConnections) do connection:Disconnect() end
	self._characterConnections = {}
	self:_onToolUnequipped()
	self:_refreshScope()

	-- Detectar herramientas equipadas
	table.insert(self._characterConnections, character.ChildAdded:Connect(function(child)
		if localPlayer.Character ~= character then return end
		if child:IsA("Tool") then
			self:_onToolEquipped(child)
		end
	end))

	table.insert(self._characterConnections, character.ChildRemoved:Connect(function(child)
		if child == self._equippedTool then
			self:_onToolUnequipped()
		end
	end))
	table.insert(self._characterConnections, character:GetAttributeChangedSignal("ArenaPhysicsGeneration"):Connect(function()
		self:_onToolUnequipped()
		self:_refreshScope()
		if localPlayer.Character == character then
			for _, child in ipairs(character:GetChildren()) do
				if isSlapTool(child) then self:_onToolEquipped(child); break end
			end
		end
	end))
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		table.insert(self._characterConnections, humanoid.Died:Connect(function()
			if localPlayer.Character ~= character then return end
			self._pending = nil; self._awaitingUntil = 0
			self:_onToolUnequipped()
		end))
	end

	-- Si ya tenia una herramienta equipada al iniciar
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			self:_onToolEquipped(child)
			break
		end
	end
end

--------------------------------------------------------------------------------
-- Ciclo de Vida Bootstrap
--------------------------------------------------------------------------------

function SlapController:Init(context: any)
	self._context = context
	if self._initialized then return end
	self._initialized = true
	self._connections = {}; self._characterConnections = {}
	self._requestId = 0; self._lastSequence = 0; self._scope = nil
	self._sessionId = nil; self._roundId = nil; self._roundIndex = 0; self._stateVersion = -1
	self._playing = false; self._roundClosed = false; self:_resetRecovery()
	self:_getPerformRemote()
 local combat=ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Combat")
 local feedback=combat:WaitForChild("SlapFeedback",10)
 if feedback and feedback:IsA("RemoteEvent") then
  table.insert(self._connections, feedback.OnClientEvent:Connect(function(data) self:_onFeedback(data) end))
 end
	local match = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Match")
	table.insert(self._connections, match:WaitForChild("StateChanged").OnClientEvent:Connect(function(state, data)
		self:_onMatchState(state, data)
	end))
	table.insert(self._connections, match:WaitForChild("Countdown").OnClientEvent:Connect(function(remaining, label, data)
		self:_onCountdown(remaining, label, data)
	end))
	table.insert(self._connections, localPlayer:GetAttributeChangedSignal("MatchId"):Connect(function()
		self:_refreshScope()
	end))
end

function SlapController:Start(context: any)
	self._context = context
	if self._started then return end
	self._started = true
	self:_hideNativeBackpack()
	local gui = localPlayer:FindFirstChildOfClass("PlayerGui")
	local hud = gui and gui:FindFirstChild("PlayerHUD")
	self._slotRoot = hud and hud:FindFirstChild("CombatSlots")
	if not self._slotRoot then warn("[SlapController] PlayerHUD.CombatSlots missing") end
	table.insert(self._connections, RunService.RenderStepped:Connect(function()
		if not self._slotRoot or not self._slotRoot.Parent then
			local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
			local currentHUD = playerGui and playerGui:FindFirstChild("PlayerHUD")
			self._slotRoot = currentHUD and currentHUD:FindFirstChild("CombatSlots")
		end
		self:_renderSlot()
	end))

	if localPlayer.Character then
		self:_bindCharacter(localPlayer.Character)
	end

	table.insert(self._connections, localPlayer.CharacterAdded:Connect(function(char)
		self:_bindCharacter(char)
	end))

	print("[SlapController] Controlador de Slaps iniciado y listo (CombatSystemV132 Protocol=3)")
end

function SlapController:Destroy()
	for _, connection in ipairs(self._characterConnections) do connection:Disconnect() end
	for _, connection in ipairs(self._connections) do connection:Disconnect() end
	self._characterConnections = {}; self._connections = {}
	self:_onToolUnequipped()
	self:_resetRecovery()
	if self._slotRoot then self._slotRoot.Visible = false end
	self._slotRoot = nil
	if self._originalBackpackEnabled ~= nil then
		pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, self._originalBackpackEnabled) end)
	end
	self._backpackHidden = false; self._originalBackpackEnabled = nil
	self._initialized = false; self._started = false
end

return SlapController
