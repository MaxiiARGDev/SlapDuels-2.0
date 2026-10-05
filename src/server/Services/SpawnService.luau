--!strict
-- SpawnService
-- Responsable de obtener los spawnpoints de la partida, posicionar a RedPlayer y BluePlayer,
-- validar que ambos spawn existan, evitar que los jugadores aparezcan dentro del suelo,
-- e integrarse con RoundService durante MapLoading y el retorno al lobby.
-- NO implementa: respawn, muerte, combate, knockback, eliminacion, checkpoints ni herramientas.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Types = require(ReplicatedStorage.Shared.Types)

type MatchSession = Types.MatchSession

local SpawnService = {}
SpawnService.Name = "SpawnService"

SpawnService._context = nil
SpawnService._lobbySpawn = nil :: SpawnLocation?
SpawnService._returnConnection = nil :: RBXScriptConnection?
SpawnService._matchRespawnConnections = {} :: { [string]: { RBXScriptConnection } }

function SpawnService:Init(context)
	self._context = context
	self._matchRespawnConnections = {}

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
	self._context = context

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
		return session.InstanceInfo.RedSpawn, session.InstanceInfo.BlueSpawn
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

-- Posiciona un personaje de jugador de forma segura sobre un spawnpart evitando que quede incrustado en el suelo
function SpawnService:TeleportCharacterToSpawn(player: Player, spawnPart: BasePart): boolean
	if not player or not spawnPart or not spawnPart:IsDescendantOf(Workspace) then
		warn("[SpawnService] Parametros de teleportacion invalidos")
		return false
	end

	local character = player.Character
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
		print(string.format("[SpawnService] Personaje de '%s' inactivo, destruido o muerto. Recargando con LoadCharacter()...", player.Name))
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

	-- Calculo de elevacion para evitar que el personaje aparezca dentro del suelo:
	-- (Mitad del grosor del spawn) + (HipHeight del Humanoid) + (Mitad de altura del RootPart) + margen de seguridad (0.5 studs)
	local spawnHalfThickness = spawnPart.Size.Y / 2
	local hipHeight = if humanoid.HipHeight > 0 then humanoid.HipHeight else 2.0
	local rootHalfHeight = rootPart.Size.Y / 2
	local safetyBuffer = 0.5

	local verticalClearance = spawnHalfThickness + hipHeight + rootHalfHeight + safetyBuffer

	-- Orientar al jugador segun la orientacion del spawn
	local targetPosition = spawnPart.Position + Vector3.new(0, verticalClearance, 0)
	local targetCFrame = CFrame.new(targetPosition) * CFrame.Angles(0, math.rad(spawnPart.Orientation.Y), 0)

	-- Detener cualquier inercia o velocidad previa del jugador
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero

	-- Si el personaje estaba en ragdoll por la explosión de un punto anterior, restaurarlo
	local ragdollService = self:_getRagdollService()
	if ragdollService then
		ragdollService:RemoveRagdoll(character)
	end

	character:PivotTo(targetCFrame)
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero

	print(string.format("[SpawnService] Jugador '%s' posicionado en '%s' (%s)",
		player.Name, spawnPart.Name, tostring(targetPosition)))

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

-- Posiciona a un jugador individual en el spawn correspondiente a su equipo dentro de la partida activa
function SpawnService:SpawnPlayerInMatch(session: MatchSession, player: Player): boolean
	if not session or not player then
		warn("[SpawnService] MatchSession o Player invalido para SpawnPlayerInMatch")
		return false
	end

	local team = self:_getPlayerTeam(session, player)
	if not team then
		warn(string.format("[SpawnService] Jugador '%s' no pertenece al Match '%s'", player.Name, session.Id))
		return false
	end

	local redSpawn, blueSpawn = self:_getSpawnPoints(session)
	local targetSpawn = if team == "Red" then redSpawn else blueSpawn

	if not targetSpawn or not targetSpawn:IsA("BasePart") or not targetSpawn:IsDescendantOf(Workspace) then
		warn(string.format("[SpawnService] Spawn de equipo '%s' no valido para Match '%s'", team, session.Id))
		return false
	end

	return self:TeleportCharacterToSpawn(player, targetSpawn)
end

-- Activa el seguimiento de CharacterAdded para respawn en arena durante Playing
function SpawnService:StartMatchRespawnTracking(session: MatchSession)
	if not session then return end
	local matchId = session.Id
	self:StopMatchRespawnTracking(matchId)

	local connections = {}
	self._matchRespawnConnections[matchId] = connections

	local trackPlayer = function(player: Player, team: "Red" | "Blue")
		if not player then return end

		local conn = player.CharacterAdded:Connect(function(character)
			print(string.format("[SpawnService] CharacterAdded for %s", player.Name))

			-- Validar que la sesión siga activa y en Playing
			if not session or not session.InstanceInfo then return end

			local roundService = self:_getRoundService()
			local currentState = (roundService and roundService:GetState()) or session.State

			-- Permitir respawn contextual en arena durante Playing, PointRestartCountdown y StartCountdown
			local isMatchActive = (currentState == Constants.RoundState.Playing
				or currentState == Constants.RoundState.PointRestartCountdown
				or currentState == Constants.RoundState.StartCountdown
				or (roundService and (roundService:GetState() == Constants.RoundState.Playing
					or roundService:GetState() == Constants.RoundState.PointRestartCountdown
					or roundService:GetState() == Constants.RoundState.StartCountdown)))
				and (session.State ~= Constants.RoundState.Ending
				and session.State ~= Constants.RoundState.ReturningToLobby
				and session.State ~= Constants.RoundState.Waiting)

			if not isMatchActive then
				print(string.format("[SpawnService] Match '%s' no está en estado activo de arena (Estado: %s), ignorando arena respawn",
					session.Id, tostring(currentState)))
				return
			end

			print(string.format("[SpawnService] Player belongs to %s", session.Id))
			local resolvedTeam = self:_getPlayerTeam(session, player) or team
			print(string.format("[SpawnService] Player team: %s", tostring(resolvedTeam)))
			print(string.format("[SpawnService] Respawning in %sSpawn", tostring(resolvedTeam)))

			task.defer(function()
				self:SpawnPlayerInMatch(session, player)
				local slapService = self:_getSlapService()
				if slapService then
					slapService:GiveSlap(player)
				end
			end)
		end)
		table.insert(connections, conn)
	end

	if session.RedTeam and #session.RedTeam > 0 then
		for _, p in ipairs(session.RedTeam) do trackPlayer(p, "Red") end
	elseif session.RedPlayer then
		trackPlayer(session.RedPlayer, "Red")
	end

	if session.BlueTeam and #session.BlueTeam > 0 then
		for _, p in ipairs(session.BlueTeam) do trackPlayer(p, "Blue") end
	elseif session.BluePlayer then
		trackPlayer(session.BluePlayer, "Blue")
	end

	print(string.format("[SpawnService] Seguimiento de respawn en arena activado para Match '%s'", matchId))
end

-- Detiene el seguimiento de respawn y desconecta los eventos CharacterAdded de la partida
function SpawnService:StopMatchRespawnTracking(matchId: string)
	local conns = self._matchRespawnConnections[matchId]
	if conns then
		for _, conn in ipairs(conns) do
			conn:Disconnect()
		end
		self._matchRespawnConnections[matchId] = nil
		print(string.format("[SpawnService] Seguimiento de respawn en arena detenido para Match '%s'", matchId))
	end
end

-- Valida spawns de la partida y posiciona a RedPlayer y BluePlayer
function SpawnService:SpawnMatchPlayers(session: MatchSession): boolean
	if not session then
		warn("[SpawnService] MatchSession invalida")
		return false
	end

	local redSpawn, blueSpawn = self:_getSpawnPoints(session)

	-- Validar que ambos spawns existan y esten en el DataModel
	if not redSpawn or not redSpawn:IsA("BasePart") or not redSpawn:IsDescendantOf(Workspace) then
		warn(string.format("[SpawnService] RedSpawn no existe o no es valido para la partida '%s'", session.Id))
		return false
	end

	if not blueSpawn or not blueSpawn:IsA("BasePart") or not blueSpawn:IsDescendantOf(Workspace) then
		warn(string.format("[SpawnService] BlueSpawn no existe o no es valido para la partida '%s'", session.Id))
		return false
	end

	local redOk = false
	local blueOk = false

	if session.RedTeam and #session.RedTeam > 0 then
		for _, player in ipairs(session.RedTeam) do
			if self:TeleportCharacterToSpawn(player, redSpawn) then
				redOk = true
			end
		end
	elseif session.RedPlayer then
		redOk = self:TeleportCharacterToSpawn(session.RedPlayer, redSpawn)
	end

	if session.BlueTeam and #session.BlueTeam > 0 then
		for _, player in ipairs(session.BlueTeam) do
			if self:TeleportCharacterToSpawn(player, blueSpawn) then
				blueOk = true
			end
		end
	elseif session.BluePlayer then
		blueOk = self:TeleportCharacterToSpawn(session.BluePlayer, blueSpawn)
	end

	print(string.format("[SpawnService] Posicionamiento completado para Match '%s': RedOk=%s, BlueOk=%s",
		session.Id, tostring(redOk), tostring(blueOk)))

	-- Asegurar que los jugadores cuenten con su Slap equipado tras el reposicionamiento
	local slapService = self:_getSlapService()
	if slapService then
		if session.RedTeam and #session.RedTeam > 0 then
			for _, p in ipairs(session.RedTeam) do slapService:GiveSlap(p) end
		elseif session.RedPlayer then
			slapService:GiveSlap(session.RedPlayer)
		end

		if session.BlueTeam and #session.BlueTeam > 0 then
			for _, p in ipairs(session.BlueTeam) do slapService:GiveSlap(p) end
		elseif session.BluePlayer then
			slapService:GiveSlap(session.BluePlayer)
		end
	end

	-- Si al menos un jugador valido fue posicionado (o ambos si ambos tienen personaje), retorna true
	return redOk or blueOk
end

-- Retorna a los jugadores al punto de spawn del lobby
function SpawnService:ReturnPlayersToLobby(redPlayer: Player?, bluePlayer: Player?)
	local lobbySpawn = self._lobbySpawn
	if not lobbySpawn or not lobbySpawn:IsDescendantOf(Workspace) then
		local lobby = Workspace:FindFirstChild("Lobby")
		lobbySpawn = lobby and lobby:FindFirstChild("SpawnLocation") :: SpawnLocation?
		self._lobbySpawn = lobbySpawn
	end

	if not lobbySpawn then
		warn("[SpawnService] No se puede retornar al lobby: SpawnLocation no encontrado")
		return
	end

	if redPlayer and redPlayer.Character then
		self:TeleportCharacterToSpawn(redPlayer, lobbySpawn)
	end

	if bluePlayer and bluePlayer.Character then
		self:TeleportCharacterToSpawn(bluePlayer, lobbySpawn)
	end

	print("[SpawnService] Jugadores retornados a Workspace.Lobby.SpawnLocation")
end

return SpawnService
