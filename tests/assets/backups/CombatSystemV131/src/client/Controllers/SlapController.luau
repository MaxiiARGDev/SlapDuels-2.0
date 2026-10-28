--!strict
-- SlapController
-- Controlador cliente de Slaps.
-- Responsabilidad exclusiva:
-- 1. Detectar cuando el jugador equipa un Slap (Tool con Configuration.Power).
-- 2. Conectar al evento Tool.Activated.
-- 3. Reproducir Swing solo tras la aceptación autoritativa de esta solicitud.
-- 4. Solicitar la ejecucion autoritativa al servidor via ReplicatedStorage.Remotes.Combat.PerformSlap.
-- 5. Manejar un debounce local liviano para evitar saturar la red con clics repetidos.
-- NO calcula daño, distancia autoritativa, knockback ni fisica.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

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

function SlapController:_trace(phase: string, reason: string?, data: any?)
	if not RunService:IsStudio() or ReplicatedStorage:GetAttribute("SlapDiagnosticsEnabled") ~= true then return end
	local second = math.floor(os.clock())
	if self._diagnosticSecond ~= second then self._diagnosticSecond = second; self._diagnosticCount = 0 end
	if self._diagnosticCount >= 12 then return end
	self._diagnosticCount += 1
	local p = data or self._pending or {}
	print("[SlapTrace] " .. HttpService:JSONEncode({
		Build = "CombatSystemV13", Side = "Client", Phase = phase, UserId = localPlayer.UserId,
		RequestId = p.RequestId, AttackId = p.AttackId, SessionId = self._sessionId,
		RoundId = self._roundId, Generation = self._scope and self._scope.Generation,
		RecoveryUntil = self._localNextSlapTime, RejectionReason = reason,
		ReportedRecoveryUntil = p.RecoveryUntil, RecoveryType = p.Outcome,
		AttackStartTime = p.AttackStartTime, AttackWindowClosed = p.AttackWindowClosed,
		HitConfirmed = p.Hit,
		ServerTime = workspace:GetServerTimeNow(),
	}))
end

function SlapController:_resetRecovery()
	self._pending = nil; self._awaitingUntil = 0; self._localNextSlapTime = 0
	if self._swingTrack then pcall(function() self._swingTrack:Stop(0.05) end) end
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
end

function SlapController:_onFeedback(data: any)
	local scope = self:_refreshScope()
	local pending = self._pending
	if type(data) ~= "table" or data.Protocol ~= 2 or not pending
		or data.RequestId ~= pending.RequestId
		or data.Character ~= scope.Character or data.Generation ~= scope.Generation
		or data.SessionId ~= scope.SessionId or data.RoundId ~= scope.RoundId
		or type(data.Sequence) ~= "number" or data.Sequence <= self._lastSequence then
		self:_trace("FeedbackIgnored", "ObsoleteOrUnrelated", data); return
	end
	if data.Phase ~= "Started" and data.Phase ~= "Rejected" and data.Phase ~= "Result" and data.Phase ~= "Cancelled" then return end
	if data.Phase ~= "Rejected" and (type(data.AttackId) ~= "string" or data.Accepted ~= true) then return end
	if pending.AttackId and data.AttackId ~= pending.AttackId then return end
	local ready = data.RecoveryUntil
	if ready ~= nil and (type(ready) ~= "number" or ready ~= ready or math.abs(ready) == math.huge) then return end
	self._lastSequence = data.Sequence
	self:_trace("FeedbackReceived", data.Reason, data)
	if data.Phase == "Started" then
		if pending.AttackId then return end -- Never replay a second Started for the same request.
		pending.AttackId = data.AttackId
		-- No optimistic animation: a rejected request has no visual attack.
		if self._equippedTool == pending.Tool and self._swingTrack then
			pcall(function() self._swingTrack:Play(0.05, 1, 1.2) end)
		end
		return
	end
	if ready then self._localNextSlapTime = math.max(self._localNextSlapTime, ready) end
	if data.WindowPending then
		-- A rejected retry cannot pretend an earlier in-flight swing ended.
		return
	end
	if data.Phase == "Cancelled" or data.Reason == "SwingInvalidated" then
		if self._swingTrack then pcall(function() self._swingTrack:Stop(0.05) end) end
	end
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
	local config = tool:FindFirstChild("Configuration")
	if config and config:FindFirstChild("Power") then
		return true
	end
	return false
end

function SlapController:_onToolEquipped(tool: Tool)
	if not isSlapTool(tool) then return end

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

	if self._swingTrack then
		pcall(function()
			self._swingTrack:Stop(0.1)
		end)
		self._swingTrack = nil
	end

	self._equippedTool = nil
	-- Recovery belongs to the competitive life, never to this Tool.
end

function SlapController:_onToolActivated(tool: Tool)
	local scope = self:_refreshScope()
	local now = workspace:GetServerTimeNow()
	if now < self._localNextSlapTime or now < self._awaitingUntil then
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
		self._requestId += 1
		local request = { RequestId = self._requestId, Character = char, Generation = scope.Generation,
			SessionId = scope.SessionId, RoundId = scope.RoundId }
		self._pending = { RequestId = request.RequestId, Tool = tool }
		self._awaitingUntil = now + 2 -- Transport retry only, never grants a hit or animation.
		self:_trace("ClientRequest")
		remote:FireServer(tool, request)
	end
end

--------------------------------------------------------------------------------
-- Enlace de Personaje
--------------------------------------------------------------------------------

function SlapController:_bindCharacter(character: Model)
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
		self:_refreshScope()
	end))

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

	if localPlayer.Character then
		self:_bindCharacter(localPlayer.Character)
	end

	table.insert(self._connections, localPlayer.CharacterAdded:Connect(function(char)
		self:_bindCharacter(char)
	end))

	print("[SlapController] Controlador de Slaps iniciado y listo (CombatSystemV13 Protocol=2)")
end

return SlapController
