--!strict
-- SpawnService
-- Responsable de obtener los spawnpoints de la partida, posicionar a RedPlayer y BluePlayer,
-- validar que ambos spawn existan, evitar que los jugadores aparezcan dentro del suelo,
-- e integrarse con RoundService durante MapLoading y el retorno al lobby.
-- NO implementa: respawn, muerte, combate, knockback, eliminacion, checkpoints ni herramientas.

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Types = require(ReplicatedStorage.Shared.Types)
local Config = require(ReplicatedStorage.Shared.Config)
local ArenaRespawn = require(script.Parent.Respawn.ArenaRespawn)
local CharacterPhysics = require(script.Parent.Respawn.CharacterPhysics)
local MovementSpeed = require(script.Parent.Respawn.MovementSpeed)

print("[SpawnService] MovementLock diagnostic version loaded")

type MatchSession = Types.MatchSession
type SessionParticipant = Types.SessionParticipant
type SpawnBatchResult = Types.SpawnBatchResult

local SpawnService = {}
SpawnService.Name = "SpawnService"

SpawnService._context = nil
SpawnService._lobbySpawn = nil :: SpawnLocation?
SpawnService._returnConnection = nil :: RBXScriptConnection?

function SpawnService:Init(context)
	self._context = context
	self._arenaRespawn = ArenaRespawn.new(self)
	CharacterPhysics.Configure()
	self._respawnConnections = {}
	self._respawnPlayerConnections = {}
	self._movementCharacterConnections = {}

	-- Validar existencia de Workspace.Lobby.SpawnLocation
	local lobby = Workspace:FindFirstChild("Lobby")
	local spawnLocation = lobby and lobby:FindFirstChild("SpawnLocation")
	if spawnLocation and spawnLocation:IsA("SpawnLocation") then
		self._lobbySpawn = spawnLocation
	else
		warn("[SpawnService] Workspace.Lobby.SpawnLocation no encontrado o invalido")
	end
end

function SpawnService:Start(context)
	if self._movementStarted then return end
	self._movementStarted = true
	self._context = context
	local function track(player: Player)
		if self._respawnPlayerConnections[player] then return end
		self._respawnPlayerConnections[player] = {
			player.CharacterRemoving:Connect(function(character)
				self:ForgetMovementCharacter(player)
				local pending = self._arenaRespawn.Pending[player]
				if pending and pending.Character == character then self._arenaRespawn:Cancel(player, "CharacterRemoving", false) end
					CharacterPhysics.Forget(character)
			end),
			player.CharacterAdded:Connect(function(character)
				local pending = self._arenaRespawn.Pending[player]
				if pending and pending.Character ~= character then self._arenaRespawn:Cancel(player, "CharacterReplaced", false) end
					CharacterPhysics.Track(character)
				self:TrackMovementCharacter(player, character)
			end),
			player:GetAttributeChangedSignal("MatchId"):Connect(function()
				local pending = self._arenaRespawn.Pending[player]
				if pending and player:GetAttribute("MatchId") ~= pending.Session.Id then self._arenaRespawn:Cancel(player, "MatchChanged", false) end
				self:RefreshMovementSpeed(player)
			end),
		}
			if player.Character then CharacterPhysics.Track(player.Character); self:TrackMovementCharacter(player, player.Character) end
	end
	table.insert(self._respawnConnections, Players.PlayerAdded:Connect(track))
	table.insert(self._respawnConnections, Players.PlayerRemoving:Connect(function(player)
		self:ForgetMovementCharacter(player)
		self._arenaRespawn:Cancel(player, "PlayerRemoving", false)
		if player.Character then CharacterPhysics.Forget(player.Character) end
		for _,connection in ipairs(self._respawnPlayerConnections[player] or {}) do connection:Disconnect() end
		self._respawnPlayerConnections[player] = nil
	end))
	for _,player in ipairs(Players:GetPlayers()) do track(player) end

	-- Conectar a la señal de RoundService para retornar jugadores al lobby
	local roundService = self:_getRoundService()
	if roundService and roundService.ReturnPlayersToLobby then
		self._returnConnection = roundService.ReturnPlayersToLobby:Connect(function(data: any)
			if type(data) == "table" then
				self:ReturnPlayersToLobby(data.RedPlayer, data.BluePlayer)
			end
		end)
	end

	print("[SpawnService] Servicio iniciado y listo para gestionar posicionamiento de jugadores")
end

-- Resolve afresh after every yield; never retain the session of an earlier life.
function SpawnService:RefreshMovementSpeed(player, expectedCharacter)
	if player.Parent ~= Players then return end
	local character = player.Character
	if not character or not character.Parent or (expectedCharacter and character ~= expectedCharacter) then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	local rounds = self:_getRoundService()
	local session = rounds and rounds:GetSessionForPlayer(player)
	MovementSpeed.SetBase(humanoid, MovementSpeed.ResolveBase(session, player:GetAttribute("MatchId")))
end

function SpawnService:ForgetMovementCharacter(player)
	local connections = self._movementCharacterConnections[player]
	if connections then for _, connection in ipairs(connections) do connection:Disconnect() end end
	self._movementCharacterConnections[player] = nil
end

function SpawnService:TrackMovementCharacter(player, character)
	self:ForgetMovementCharacter(player)
	task.spawn(function()
		local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 10)
		if not humanoid or not humanoid:IsA("Humanoid") or player.Character ~= character or player.Parent ~= Players then return end
		self:ForgetMovementCharacter(player)
		local function refresh() self:RefreshMovementSpeed(player, character) end
		self._movementCharacterConnections[player] = {
			humanoid:GetPropertyChangedSignal("PlatformStand"):Connect(refresh),
			character:GetAttributeChangedSignal("ArenaRespawnPending"):Connect(refresh),
		}
		local rounds = self:_getRoundService()
		local session = rounds and rounds:GetSessionForPlayer(player)
		if session and player:GetAttribute("MatchId") == session.Id
			and (session.State == Constants.RoundState.StartCountdown or session.State == Constants.RoundState.PointRestartCountdown
				or session.State == Constants.RoundState.Ending) then self:LockCharacterMovement(player) end
		self:RefreshMovementSpeed(player, character)
	end)
end

function SpawnService:RefreshSessionMovement(session)
	for _, participant in ipairs(session.Participants or {}) do
		if participant.State ~= "Left" and participant.State ~= "Released" then
			self:RefreshMovementSpeed(participant.Player)
		end
	end
end

function SpawnService:_getMatchInstanceService()
	if self._context and self._context.GetService then
		local s = self._context:GetService("MatchInstanceService")
		if s then return s end
	end

	local servicesFolder = ServerScriptService:FindFirstChild("Services")
	local mod = servicesFolder and servicesFolder:FindFirstChild("MatchInstanceService")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok then return result end
	end
	return nil
end

function SpawnService:_getRoundService()
	if self._context and self._context.GetService then
		local s = self._context:GetService("RoundService")
		if s then return s end
	end

	local servicesFolder = ServerScriptService:FindFirstChild("Services")
	local mod = servicesFolder and servicesFolder:FindFirstChild("RoundService")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok then return result end
	end
	return nil
end

function SpawnService:_getRagdollService()
	if self._context and self._context.GetService then
		local s = self._context:GetService("RagdollService")
		if s then return s end
	end

	local servicesFolder = ServerScriptService:FindFirstChild("Services")
	local mod = servicesFolder and servicesFolder:FindFirstChild("RagdollService")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok then return result end
	end
	return nil
end

function SpawnService:_getSlapService()
	if self._context and self._context.GetService then
		local s = self._context:GetService("SlapService")
		if s then return s end
	end

	local servicesFolder = ServerScriptService:FindFirstChild("Services")
	local mod = servicesFolder and servicesFolder:FindFirstChild("SlapService")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok then return result end
	end
	return nil
end

function SpawnService:_getSpawnPoints(session: MatchSession): (BasePart?, BasePart?)
	-- 1. Intentar desde session.InstanceInfo si ya esta cacheado
	if session.InstanceInfo then
		return session.InstanceInfo.TeamSpawns.Red[1], session.InstanceInfo.TeamSpawns.Blue[1]
	end

	-- 2. Consultar a MatchInstanceService
	local matchInstanceService = self:_getMatchInstanceService()
	if matchInstanceService then
		return matchInstanceService:GetSpawnPoints(session.Id)
	end

	return nil, nil
end

function SpawnService:GetSpawnPoints(session: MatchSession): (BasePart?, BasePart?)
	return self:_getSpawnPoints(session)
end

local function isPlayer(p: any): boolean
	if not p then return false end
	if typeof(p) == "Instance" then
		return p:IsA("Player")
	end
	return false
end

-- Determina si un jugador pertenece activamente a una partida en curso
function SpawnService:IsPlayerInActiveMatch(player: Player): boolean
	if not player or not isPlayer(player) then return false end
	local matchId = player:GetAttribute("MatchId")
	if matchId and matchId ~= "" then
		return true
	end
	local roundService = self:_getRoundService()
	if roundService and type(roundService.GetSessionForPlayer) == "function" then
		local session = roundService:GetSessionForPlayer(player)
		if session and session.State ~= Constants.RoundState.Waiting and session.State ~= Constants.RoundState.ReturningToLobby then
			return true
		end
	end
	return false
end

-- Posiciona un personaje de jugador de forma segura sobre un spawnpart evitando que quede incrustado en el suelo
function SpawnService:TeleportCharacterToSpawn(player: Player, spawnPart: BasePart): boolean
	if not player or not spawnPart or not spawnPart:IsDescendantOf(Workspace) then
		warn("[SpawnService] Parametros de teleportacion invalidos")
		return false
	end

	local character = player.Character
	local isLobby = spawnPart == self._lobbySpawn
	local originalCharacter = character
	local originalGeneration = character and character:GetAttribute("ArenaPhysicsGeneration")
	local originalMatchId = player:GetAttribute("MatchId")
	if self._arenaRespawn then
		self._arenaRespawn:Cancel(player, "ExternalTeleport", false)
	end
	if character then character:SetAttribute("ArenaPhysicsPhase", if isLobby then "Lobby" else "Playing") end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?

	-- Validar si el personaje existe, está activo y con vida
	local isAlive = character
		and character.Parent ~= nil
		and humanoid
		and humanoid.Health > 0
		and rootPart
		and rootPart.Position.Y > (workspace.FallenPartsDestroyHeight + 100)

	if not isAlive then
		if not isLobby and self:IsPlayerInActiveMatch(player) then
			-- REGLA FASE 4B: En MATCH, NUNCA invocar player:LoadCharacter()
			warn(string.format("[SpawnService] Personaje de '%s' no listo durante MatchSession. Esperando HumanoidRootPart sin recargar rig...", player.Name))
			character = player.Character
			if character then
				rootPart = character:WaitForChild("HumanoidRootPart", 2) :: BasePart?
				humanoid = character:FindFirstChildOfClass("Humanoid")
			end
			if not character or not rootPart or not humanoid then
				warn(string.format("[SpawnService] Imposible teletransportar '%s' en partida: Character no recuperable sin LoadCharacter.", player.Name))
				return false
			end
		else
			-- LOBBY: Recarga permitida exclusivamente como mecanismo fuera de match
			print(string.format("[SpawnService] Personaje de '%s' inactivo en Lobby. Recargando con LoadCharacter()...", player.Name))
			local ok, err = pcall(function()
				player:LoadCharacter()
			end)
			if not ok then
				warn(string.format("[SpawnService] Error al forzar LoadCharacter() para '%s': %s", player.Name, tostring(err)))
				return false
			end
			character = player.Character
			if not character then
				local start = os.clock()
				while not player.Character and (os.clock() - start) < 2 do
					task.wait(0.05)
				end
				character = player.Character
			end
		end
	end

	if not character then
		warn(string.format("[SpawnService] Jugador '%s' no tiene personaje activo tras intento de carga", player.Name))
		return false
	end

	rootPart = character:WaitForChild("HumanoidRootPart", 3) :: BasePart?
	humanoid = character:FindFirstChildOfClass("Humanoid")
	if not rootPart or not humanoid then
		warn(string.format("[SpawnService] Personaje de '%s' no contiene HumanoidRootPart o Humanoid", player.Name))
		return false
	end
	if player.Character ~= character or player.Parent ~= Players then return false end
	if player:GetAttribute("MatchId") ~= originalMatchId
		or (character == originalCharacter and character:GetAttribute("ArenaPhysicsGeneration") ~= originalGeneration) then return false end
	CharacterPhysics.Restore(character)
	character:SetAttribute("ArenaPhysicsPhase", if isLobby then "Lobby" else "Playing")

	-- Si el jugador está dentro de un match, asegurar que Dead esté deshabilitado
	character:SetAttribute("ArenaPhysicsGeneration", (character:GetAttribute("ArenaPhysicsGeneration") or 0) + 1)
	if not isLobby and self:IsPlayerInActiveMatch(player) then
		pcall(function()
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
		end)
	end

	-- Calculo de elevacion para evitar que el personaje aparezca dentro del suelo:
	-- (Mitad del grosor del spawn) + (HipHeight del Humanoid) + (Mitad de altura del RootPart) + margen de seguridad (0.5 studs)
	local spawnHalfThickness = spawnPart.Size.Y / 2
	local hipHeight = if humanoid.HipHeight > 0 then humanoid.HipHeight else 2.0
	local rootHalfHeight = rootPart.Size.Y / 2
	local safetyBuffer = 0.5

	local verticalClearance = spawnHalfThickness + hipHeight + rootHalfHeight + safetyBuffer

	-- Orientar al jugador segun la orientacion del spawn
		local targetCFrame = spawnPart.CFrame * CFrame.new(0, verticalClearance, 0)

	-- Detener cualquier inercia o velocidad previa del jugador en todas sus partes
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.AssemblyLinearVelocity = Vector3.zero
			desc.AssemblyAngularVelocity = Vector3.zero
		end
	end

	-- Si el personaje estaba en ragdoll, restaurarlo inmediatamente cancelando timers pendientes
	local ragdollService = self:_getRagdollService()
	if ragdollService and type(ragdollService.ResetRagdollImmediate) == "function" then
		ragdollService:ResetRagdollImmediate(character, isLobby)
	elseif ragdollService then
		ragdollService:RemoveRagdoll(character)
	end

	character:PivotTo(targetCFrame * rootPart.CFrame:Inverse() * character:GetPivot())
	if not isLobby then
		local rounds = self:_getRoundService()
		local session = rounds and rounds:GetSessionForPlayer(player)
		if session then
			(session :: any).ArenaTransferred = true
			(session :: any).TransferredPlayers = (session :: any).TransferredPlayers or {}
			(session :: any).TransferredPlayers[player] = true
		end
	end
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.AssemblyLinearVelocity = Vector3.zero
			desc.AssemblyAngularVelocity = Vector3.zero
		end
	end

	print(string.format("[SpawnService] Jugador '%s' posicionado en '%s' (%s)",
			player.Name, spawnPart.Name, tostring(targetCFrame.Position)))

	return true
end

-- Determina el equipo de un jugador dentro de una partida activa
function SpawnService:_getPlayerTeam(session: MatchSession, player: Player): ("Red" | "Blue")?
	if not session or not player then return nil end

	if session.RedTeam and table.find(session.RedTeam, player) ~= nil then
		return "Red"
	elseif session.RedPlayer == player then
		return "Red"
	end

	if session.BlueTeam and table.find(session.BlueTeam, player) ~= nil then
		return "Blue"
	elseif session.BluePlayer == player then
		return "Blue"
	end

	return nil
end

function SpawnService:_getParticipant(session: MatchSession, player: Player): SessionParticipant?
	if not session or not player then return nil end
	for _, participant in ipairs(session.Participants or {}) do
		if participant.Player == player and participant.State ~= "Released" then
			return participant
		end
	end
	return nil
end

-- Resolver autoritativo reutilizable para carga, reinicios y recuperación de caídas.
-- La sesión registrada, el participante y la instancia física deben coincidir.
function SpawnService:ResolveParticipantSpawn(sessionId: string, player: Player): (BasePart?, string?)
	local roundService = self:_getRoundService()
	if not roundService or type(roundService.GetSessionById) ~= "function" then
		return nil, "RoundServiceUnavailable"
	end
	local session = roundService:GetSessionById(sessionId)
	if not session or session.Id ~= sessionId then return nil, "SessionNotRegistered" end
	if roundService:GetSessionForPlayer(player) ~= session then return nil, "PlayerSessionMismatch" end

	local participant = self:_getParticipant(session, player)
	if not participant then return nil, "ParticipantNotRegistered" end
	if participant.State == "Left" then return nil, "ParticipantLeft" end

	local instanceService = self:_getMatchInstanceService()
	local instanceInfo = instanceService and instanceService:GetInstance(sessionId)
	if not instanceInfo or session.InstanceInfo ~= instanceInfo or instanceInfo.MatchId ~= sessionId then
		return nil, "MatchInstanceMismatch"
	end
	local spawnPart = instanceService:GetSpawnPoint(sessionId, participant.Team, participant.Slot)
	if not spawnPart or not spawnPart:IsDescendantOf(instanceInfo.Container) then
		return nil, "SpawnUnavailable"
	end
	return spawnPart, nil
end

-- Posiciona a un jugador individual en el spawn correspondiente a su equipo dentro de la partida activa
function SpawnService:SpawnPlayerInMatch(session: MatchSession, player: Player): boolean
	if not session or not player then
		warn("[SpawnService] MatchSession o Player invalido para SpawnPlayerInMatch")
		return false
	end

	local participant = self:_getParticipant(session, player)
	if not participant then
		warn(string.format("[SpawnService] Jugador '%s' no pertenece al Match '%s'", player.Name, session.Id))
		return false
	end
	local targetSpawn, reason = self:ResolveParticipantSpawn(session.Id, player)

	if not targetSpawn or not targetSpawn:IsA("BasePart") or not targetSpawn:IsDescendantOf(Workspace) then
		warn(string.format("[SpawnService] Spawn %s/%d no valido para Match '%s': %s", participant.Team, participant.Slot, session.Id, tostring(reason)))
		return false
	end

	-- Blindaje del Humanoid al ingresar al Match (Fase 4B Zero-Death)
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			pcall(function()
				humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
			end)
		end
	end

	return self:TeleportCharacterToSpawn(player, targetSpawn)
end

-- Reposiciona el Character EXISTENTE de un jugador dentro de su MatchInstance (Zero-Death)
-- Garantiza:
-- 1. NO invoca player:LoadCharacter().
-- 2. NO reemplaza ni destruye el Character existente.
-- 3. Resuelve TeamSpawn exclusivamente desde MatchId y MatchTeam (aislamiento multi-match).
-- 4. Invoca RagdollService:ResetRagdollImmediate() para restaurar locomoción y cancelar timers.
-- 5. Anula AssemblyLinearVelocity y AssemblyAngularVelocity antes y después de PivotTo.
-- 6. Aplica elevación vertical y orientación de forma segura para no incrustar en el suelo.
function SpawnService:ResetCharacterInArena(player: Player, expectedSessionId: string?): boolean
	if not player or not player:IsDescendantOf(game:GetService("Players")) then
		warn("[SpawnService] Player invalido o desconectado para ResetCharacterInArena")
		return false
	end

	local character = player.Character
	if not character or not character.Parent or not character:IsDescendantOf(Workspace) then
		warn(string.format("[SpawnService] Jugador '%s' no tiene Character valido en Workspace", player.Name))
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not rootPart then
		warn(string.format("[SpawnService] Personaje de '%s' carece de Humanoid o HumanoidRootPart", player.Name))
		return false
	end

	local roundService = self:_getRoundService()
	local session = roundService and roundService:GetSessionForPlayer(player)
	if not session or (expectedSessionId and session.Id ~= expectedSessionId) then
		warn(string.format("[SpawnService] Sesion autoritativa ausente o distinta para '%s'", player.Name))
		return false
	end
	local participant = self:_getParticipant(session, player)
	local targetSpawn, reason = self:ResolveParticipantSpawn(session.Id, player)
	if not participant or not targetSpawn then
		warn(string.format("[SpawnService] No se pudo resolver spawn autoritativo para '%s': %s", player.Name, tostring(reason)))
		return false
	end
	local pending = self._arenaRespawn and self._arenaRespawn.Pending[player]
	if pending and pending.Thread and pending.Thread ~= coroutine.running() then
		pcall(task.cancel, pending.Thread)
		pending.Thread = nil
	end
	character:SetAttribute("ArenaPhysicsGeneration", (character:GetAttribute("ArenaPhysicsGeneration") or 0) + 1)

	-- 1. Resetear inmediatamente el estado de Ragdoll y cancelar callbacks pendientes
	local ragdollService = self:_getRagdollService()
	if ragdollService and type(ragdollService.ResetRagdollImmediate) == "function" then
		ragdollService:ResetRagdollImmediate(character, pending ~= nil)
	elseif ragdollService then
		ragdollService:RemoveRagdoll(character)
	end

	-- 2. Limpiar velocidades e impulsos antes del teleport
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.AssemblyLinearVelocity = Vector3.zero
			desc.AssemblyAngularVelocity = Vector3.zero
		end
	end

	-- 3. Calcular CFrame objetivo con elevación de seguridad
	local spawnHalfThickness = targetSpawn.Size.Y / 2
	local hipHeight = if humanoid.HipHeight > 0 then humanoid.HipHeight else 2.0
	local rootHalfHeight = rootPart.Size.Y / 2
	local safetyBuffer = 0.5
	if pending then
		-- Official rig clearance: R6 includes leg length; R15 uses HipHeight.
		local leg = character:FindFirstChild("Left Leg") :: BasePart?
		hipHeight = math.max(0, humanoid.HipHeight)
		if humanoid.RigType == Enum.HumanoidRigType.R6 and leg then hipHeight += leg.Size.Y end
		safetyBuffer = 0.05
	end
	local verticalClearance = spawnHalfThickness + hipHeight + rootHalfHeight + safetyBuffer

		local targetCFrame = targetSpawn.CFrame * CFrame.new(0, verticalClearance, 0)

	-- 4. Reposicionar el Character EXISTENTE
	if pending then
		-- Position the root exactly, independent of Model pivot offsets.
		character:PivotTo(targetCFrame * rootPart.CFrame:Inverse() * character:GetPivot())
	else
		character:PivotTo(targetCFrame)
	end

	-- 5. Limpieza física secundaria post-PivotTo para cancelar inercia residual
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
	if pending then
		local exclude: { Instance } = { character }
		for _,other in ipairs(Players:GetPlayers()) do
			if other.Character then table.insert(exclude, other.Character) end
		end
		local overlap = OverlapParams.new()
		overlap.FilterType = Enum.RaycastFilterType.Exclude
		overlap.FilterDescendantsInstances = exclude
		overlap.RespectCanCollide = true
		overlap.MaxParts = 1
		for _,body in ipairs(character:GetChildren()) do
			if body:IsA("BasePart") and #Workspace:GetPartBoundsInBox(body.CFrame, body.Size * 0.95, overlap) > 0 then
				warn("[ArenaRespawn] Unsafe spawn overlap", player.Name, targetSpawn:GetFullName(), body.Name)
				return false
			end
		end
		self._arenaRespawn:Take(player)
		self._arenaRespawn:Restore(pending)
	end

	-- 6. Garantizar que Humanoid pueda caminar y mantener Dead bloqueado (Zero-Death)
	if humanoid.Health > 0 then
		humanoid.Jump = false
		humanoid.PlatformStand = false
		local isLocked = humanoid:GetAttribute("MovementLocked") == true
		if not isLocked then
			humanoid.AutoRotate = true
		end
		pcall(function()
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end)
	end

	print(string.format("[SpawnService] ResetCharacterInArena exitoso para '%s' en '%s' (Match '%s', Team '%s')",
		player.Name, targetSpawn.Name, session.Id, participant.Team))
	CharacterPhysics.Trace(player, "ArenaPositioned", targetSpawn, session.State)
	self:RefreshMovementSpeed(player, character)

	return true
end

function SpawnService:IsKillPartRespawnPending(player: Player): boolean
	return self._arenaRespawn ~= nil and self._arenaRespawn.Pending[player] ~= nil
end

function SpawnService:BeginKillPartRespawn(player: Player, session: MatchSession, eliminationId: string, kind: string?): boolean
	local rounds = self:_getRoundService()
	if not player or player.Parent ~= Players or not session or not rounds
		or rounds:GetSessionForPlayer(player) ~= session or not rounds:IsSessionActive(session.Id)
		or not rounds:GetSessionParticipant(session.Id, player) then return false end
	if session.State ~= Constants.RoundState.Playing or session.PointInProgress or session.GameplayFrozen then return false end
	return self._arenaRespawn:Begin(player, session, eliminationId, kind)
end

function SpawnService:CancelSessionRespawns(sessionId: string, reason: string)
	if self._arenaRespawn then self._arenaRespawn:CancelSession(sessionId, reason, true) end
end

-- ==================================================
-- BLOQUEO Y RESTAURACIÓN DE MOVIMIENTO (Countdowns)
-- ==================================================

-- Obtiene la lista de jugadores participantes válidos de una MatchSession
-- Reutiliza la misma estrategia que SpawnMatchPlayers() soportando RedTeam/BlueTeam y RedPlayer/BluePlayer
function SpawnService:GetSessionParticipants(session: MatchSession?): { Player }
	if not session then return {} end
	local participants: { Player } = {}

	local addPlayer = function(p: any)
		if isPlayer(p) and p:IsDescendantOf(Players) then
			if not table.find(participants, p) then
				table.insert(participants, p)
			end
		end
	end

	if session.RedTeam and #session.RedTeam > 0 then
		for _, p in ipairs(session.RedTeam) do
			addPlayer(p)
		end
	elseif session.RedPlayer then
		addPlayer(session.RedPlayer)
	end

	if session.BlueTeam and #session.BlueTeam > 0 then
		for _, p in ipairs(session.BlueTeam) do
			addPlayer(p)
		end
	elseif session.BluePlayer then
		addPlayer(session.BluePlayer)
	end

	for index, participant in ipairs(participants) do
		warn(
			"[DEBUG Participants]",
			index,
			tostring(participant),
			typeof(participant)
		)
	end

	return participants
end

-- Bloquea autoritativamente el movimiento del Character durante countdowns (Start / PointRestart)
-- Garantiza: WalkSpeed = 0, JumpPower = 0, JumpHeight = 0, AutoRotate = false, AssemblyVelocities = 0
-- NO usa Anchored, NO usa PlatformStand, NO crea Characters nuevos.
function SpawnService:LockCharacterMovement(player: Player?): boolean
	warn(
		"[DEBUG LockCharacterMovement]",
		"player=", tostring(player),
		"typeof=", typeof(player)
	)

	if typeof(player) ~= "Instance" then
		warn("[DEBUG LockCharacterMovement] INVALID PLAYER:", tostring(player))
		return false
	end

	if not player:IsA("Player") then
		warn("[DEBUG LockCharacterMovement] INVALID CLASS:", player.ClassName)
		return false
	end

	if player.Parent ~= Players then
		warn("[DEBUG LockCharacterMovement] PLAYER NOT IN PLAYERS:", player:GetFullName())
		return false
	end

	local character = player.Character
	if not character or not character.Parent or not character:IsDescendantOf(Workspace) then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not rootPart then
		return false
	end

	self:RefreshMovementSpeed(player, character)
	local defaultJumpPower = (Config.Character and Config.Character.DefaultJumpPower) or 50
	local defaultJumpHeight = (Config.Character and Config.Character.DefaultJumpHeight) or 7.2

	if not humanoid:GetAttribute("BaseJumpPower") then
		local currentPower = humanoid.JumpPower
		humanoid:SetAttribute("BaseJumpPower", if currentPower > 0 then currentPower else defaultJumpPower)
	end
	if not humanoid:GetAttribute("BaseJumpHeight") then
		local currentHeight = humanoid.JumpHeight
		humanoid:SetAttribute("BaseJumpHeight", if currentHeight > 0 then currentHeight else defaultJumpHeight)
	end

	humanoid:SetAttribute("MovementLocked", true)
	humanoid:SetAttribute("MovementSpeedUnlockPending", nil)
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.AutoRotate = false

	-- Detener cualquier inercia o velocidad física residual
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero
	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.AssemblyLinearVelocity = Vector3.zero
			desc.AssemblyAngularVelocity = Vector3.zero
		end
	end

	return true
end

-- Restaura autoritativamente el movimiento normal del Character al pasar a PLAYING o Lobby
function SpawnService:UnlockCharacterMovement(player: Player?): boolean
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players then
		return false
	end

	local character = player.Character
	if not character or not character.Parent then
		return false
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	local defaultJumpPower = (Config.Character and Config.Character.DefaultJumpPower) or 50
	local defaultJumpHeight = (Config.Character and Config.Character.DefaultJumpHeight) or 7.2

	local baseJumpPower = humanoid:GetAttribute("BaseJumpPower")
	local baseJumpHeight = humanoid:GetAttribute("BaseJumpHeight")

	humanoid:SetAttribute("MovementLocked", nil)
	humanoid:SetAttribute("MovementSpeedUnlockPending", true)
	self:RefreshMovementSpeed(player, character)
	MovementSpeed.Apply(humanoid, true)
	humanoid.JumpPower = if typeof(baseJumpPower) == "number" and baseJumpPower > 0 then baseJumpPower else defaultJumpPower
	humanoid.JumpHeight = if typeof(baseJumpHeight) == "number" and baseJumpHeight > 0 then baseJumpHeight else defaultJumpHeight
	humanoid.AutoRotate = true

	return true
end

-- Bloquea movimiento para todos los participantes válidos de una sesión
function SpawnService:LockSessionPlayers(session: MatchSession)
	if not session then
		warn("[SpawnService] LockSessionPlayers: MatchSession nula o inválida")
		return
	end

	local participants = self:GetSessionParticipants(session)
	if #participants == 0 then
		warn(string.format("[SpawnService] LockSessionPlayers: no se encontraron participantes válidos para Match '%s'", tostring(session.Id)))
		return
	end

	if session.Mode == "1v1" and #participants < 2 then
		warn(string.format("[SpawnService] LockSessionPlayers: participante faltante en 1v1 para Match '%s' (encontrados: %d)",
			tostring(session.Id), #participants))
	end

	for _, player in ipairs(participants) do
		warn(
			"[DEBUG MovementLock]",
			"Match=", tostring(session.Id),
			"Participant=", tostring(player),
			"Type=", typeof(player),
			"Class=", if typeof(player) == "Instance" then player.ClassName else "N/A"
		)
		self:LockCharacterMovement(player)
	end
end

-- Restaura movimiento para todos los participantes válidos de una sesión
function SpawnService:UnlockSessionPlayers(session: MatchSession)
	if not session then
		warn("[SpawnService] UnlockSessionPlayers: MatchSession nula o inválida")
		return
	end

	local participants = self:GetSessionParticipants(session)
	for _, player in ipairs(participants) do
		self:UnlockCharacterMovement(player)
	end
end


-- Deprecated (Fase 4B Zero-Death): En arquitectura Zero-Death el Character es persistente y no requiere rescue reactivo
function SpawnService:StartMatchRespawnTracking(_session: MatchSession)
	-- No-op: Zero-Death elimina el ciclo de muerte/respawn nativo en partida
end

-- Deprecated (Fase 4B Zero-Death): Limpieza no requerida al no existir listeners activos
function SpawnService:StopMatchRespawnTracking(_matchId: string)
	-- No-op
end

-- Valida spawns de la partida y posiciona a RedPlayer y BluePlayer
function SpawnService:SpawnMatchPlayers(session: MatchSession): SpawnBatchResult
	local sessionId = if session then session.Id else ""
	local result: SpawnBatchResult = {
		Success = false,
		SessionId = sessionId,
		Required = 0,
		Placed = 0,
		PlacedPlayers = {},
		Failures = {},
	}
	if not session then
		warn("[SpawnService] MatchSession invalida")
		table.insert(result.Failures, { Reason = "InvalidSession" })
		return result
	end

	local participants = session.Participants or {}
	-- Resolve the whole batch before moving anyone. Never prepare only one side.
	for _, participant in ipairs(participants) do
		if participant.State ~= "Left" and participant.State ~= "Released" then
			local target, reason = self:ResolveParticipantSpawn(session.Id, participant.Player)
			if not target then
				table.insert(result.Failures, { Player=participant.Player, Reason=reason or "SpawnUnavailable" })
			end
		end
	end
	if #result.Failures > 0 then
		for _,participant in ipairs(participants) do if participant.State~="Left" and participant.State~="Released" then result.Required+=1 end end
		return result
	end
	for _, participant in ipairs(participants) do
		if participant.State ~= "Left" and participant.State ~= "Released" then
			result.Required += 1
			local spawnPart, reason = self:ResolveParticipantSpawn(session.Id, participant.Player)
			if not spawnPart then
				table.insert(result.Failures, { Player = participant.Player, UserId = participant.UserId, Team = participant.Team, Slot = participant.Slot, Reason = reason or "SpawnUnavailable" })
			elseif self:TeleportCharacterToSpawn(participant.Player, spawnPart) then
				result.Placed += 1
				table.insert(result.PlacedPlayers, participant.Player)
			else
				table.insert(result.Failures, { Player = participant.Player, UserId = participant.UserId, Team = participant.Team, Slot = participant.Slot, Reason = "TeleportFailed" })
			end
		end
	end
	result.Success = result.Required > 0 and result.Placed == result.Required and #result.Failures == 0
	print(string.format("[SpawnService] Posicionamiento Match '%s': %d/%d; Success=%s", session.Id, result.Placed, result.Required, tostring(result.Success)))

	-- Asegurar que los jugadores cuenten con su Slap equipado tras el reposicionamiento
	local slapService = self:_getSlapService()
	if result.Success and slapService then
		for _,p in ipairs(result.PlacedPlayers) do slapService:GiveSlap(p) end
	end

	return result
end

-- Retorna a los jugadores al punto de spawn del lobby reutilizando sus Characters existentes
function SpawnService:ReturnPlayersToLobby(redPlayer: any?, bluePlayer: any?): boolean
	local lobbySpawn = self._lobbySpawn
	if not lobbySpawn or not lobbySpawn:IsDescendantOf(Workspace) then
		local lobby = Workspace:FindFirstChild("Lobby")
		lobbySpawn = lobby and lobby:FindFirstChild("SpawnLocation") :: SpawnLocation?
		self._lobbySpawn = lobbySpawn
	end

	if not lobbySpawn then
		warn("[SpawnService] No se puede retornar al lobby: SpawnLocation no encontrado")
		return false
	end

	local ragdollService = self:_getRagdollService()
	local allReturned = true

	local returnSinglePlayer = function(player: Player?)
		if not player or not player:IsA("Player") or not player:IsDescendantOf(Players) then return end
		local character = player.Character
			-- Invalidate competitive work BEFORE recovery/teleport, including individual results exits.
			self._arenaRespawn:Cancel(player, "ReturnToLobby", false)
			if character then
				character:SetAttribute("ArenaPhysicsGeneration", (character:GetAttribute("ArenaPhysicsGeneration") or 0) + 1)
				character:SetAttribute("ArenaPhysicsPhase", "Lobby")
				CharacterPhysics.Restore(character)
			end
		if character and character.Parent then
			if ragdollService and type(ragdollService.ResetRagdollImmediate) == "function" then
				ragdollService:ResetRagdollImmediate(character)
			elseif ragdollService then
				ragdollService:RemoveRagdoll(character)
			end

			self:UnlockCharacterMovement(player)

			local hum = character:FindFirstChildOfClass("Humanoid")
			if hum then
				pcall(function()
					hum.PlatformStand = false
					hum.AutoRotate = true
					hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
					hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
					hum:ChangeState(Enum.HumanoidStateType.Running)
				end)
			end
		end

			if not self:TeleportCharacterToSpawn(player, lobbySpawn) then
			allReturned = false
		end
			if player.Character then CharacterPhysics.Restore(player.Character) end
			local returnedHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if returnedHumanoid then
				returnedHumanoid.Jump = false
				returnedHumanoid.PlatformStand = false
				returnedHumanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
				returnedHumanoid:ChangeState(Enum.HumanoidStateType.Running)
			end
			local rounds = self:_getRoundService()
			local returningSession = rounds and rounds:GetSessionForPlayer(player)
			CharacterPhysics.Trace(player, "LobbyReturned", lobbySpawn, returningSession and returningSession.State)

		-- Limpieza inmediata de identidad de match a nivel de player
		pcall(function()
			player:SetAttribute("MatchId", nil)
			player:SetAttribute("MatchTeam", nil)
		end)
		self:RefreshMovementSpeed(player)
	end

	local processTarget = function(target: any?)
		if not target then return end
		if type(target) == "table" and not (typeof(target) == "Instance") then
			for _, p in ipairs(target) do
				returnSinglePlayer(p)
			end
		else
			returnSinglePlayer(target)
		end
	end

	processTarget(redPlayer)
	processTarget(bluePlayer)

	print("[SpawnService] Jugadores retornados a Workspace.Lobby.SpawnLocation con estados normales restaurados")
	return allReturned
end

return SpawnService
