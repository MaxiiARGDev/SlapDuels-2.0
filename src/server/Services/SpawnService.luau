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

type MatchSession = Types.MatchSession

local SpawnService = {}
SpawnService.Name = "SpawnService"

SpawnService._context = nil
SpawnService._lobbySpawn = nil :: SpawnLocation?
SpawnService._returnConnection = nil :: RBXScriptConnection?

function SpawnService:Init(context)
	self._context = context

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
		if self:IsPlayerInActiveMatch(player) then
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

	-- Si el jugador está dentro de un match, asegurar que Dead esté deshabilitado
	if self:IsPlayerInActiveMatch(player) then
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
function SpawnService:ResetCharacterInArena(player: Player): boolean
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

	-- Resolver identidad server-authoritative
	local matchId = player:GetAttribute("MatchId") :: string?
	local team = player:GetAttribute("MatchTeam") :: string?

	-- Fallback a RoundService si los atributos no estuvieran en el jugador
	if not matchId or not team then
		local roundService = self:_getRoundService()
		if roundService and roundService.GetSessionForPlayer then
			local session = roundService:GetSessionForPlayer(player)
			if session then
				matchId = session.Id
				team = self:_getPlayerTeam(session, player)
			end
		end
	end

	if not matchId or not team then
		warn(string.format("[SpawnService] No se pudo resolver MatchId/MatchTeam para '%s'", player.Name))
		return false
	end

	-- Resolver spawn físico de la MatchInstance correspondiente (sin búsquedas globales)
	local matchInstanceService = self:_getMatchInstanceService()
	if not matchInstanceService then
		warn("[SpawnService] MatchInstanceService no disponible")
		return false
	end

	local instanceInfo = matchInstanceService:GetInstance(matchId)
	if not instanceInfo then
		warn(string.format("[SpawnService] MatchInstance no encontrada para MatchId '%s'", matchId))
		return false
	end

	local targetSpawn = if team == "Red" then instanceInfo.RedSpawn else instanceInfo.BlueSpawn
	if not targetSpawn or not targetSpawn:IsA("BasePart") or not targetSpawn:IsDescendantOf(Workspace) then
		warn(string.format("[SpawnService] TeamSpawn '%s' no valido para Match '%s'", tostring(team), matchId))
		return false
	end

	-- 1. Resetear inmediatamente el estado de Ragdoll y cancelar callbacks pendientes
	local ragdollService = self:_getRagdollService()
	if ragdollService and type(ragdollService.ResetRagdollImmediate) == "function" then
		ragdollService:ResetRagdollImmediate(character)
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
	local verticalClearance = spawnHalfThickness + hipHeight + rootHalfHeight + safetyBuffer

	local targetPosition = targetSpawn.Position + Vector3.new(0, verticalClearance, 0)
	local targetCFrame = CFrame.new(targetPosition) * CFrame.Angles(0, math.rad(targetSpawn.Orientation.Y), 0)

	-- 4. Reposicionar el Character EXISTENTE
	character:PivotTo(targetCFrame)

	-- 5. Limpieza física secundaria post-PivotTo para cancelar inercia residual
	rootPart.AssemblyLinearVelocity = Vector3.zero
	rootPart.AssemblyAngularVelocity = Vector3.zero

	-- 6. Garantizar que Humanoid pueda caminar y mantener Dead bloqueado (Zero-Death)
	if humanoid.Health > 0 then
		humanoid.PlatformStand = false
		humanoid.AutoRotate = true
		pcall(function()
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)
			humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end)
	end

	print(string.format("[SpawnService] ResetCharacterInArena exitoso para '%s' en '%s' (Match '%s', Team '%s')",
		player.Name, targetSpawn.Name, matchId, team))

	return true
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

	local restoreHumanoid = function(player: Player?)
		if not player or not player.Character then return end
		local hum = player.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			pcall(function()
				hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
			end)
		end
	end

	if redPlayer and redPlayer.Character then
		restoreHumanoid(redPlayer)
		self:TeleportCharacterToSpawn(redPlayer, lobbySpawn)
	end

	if bluePlayer and bluePlayer.Character then
		restoreHumanoid(bluePlayer)
		self:TeleportCharacterToSpawn(bluePlayer, lobbySpawn)
	end

	print("[SpawnService] Jugadores retornados a Workspace.Lobby.SpawnLocation con estados normales restaurados")
end

return SpawnService
