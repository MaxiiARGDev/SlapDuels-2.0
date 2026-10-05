--!strict
-- EliminationService
-- Servicio autoritativo de resolución de eliminaciones y atribución de Kills.
-- Responsabilidad exclusiva:
-- - Detectar cuando un jugador en partida es eliminado (contacto con KillPart o Humanoid.Died).
-- - Validar que la eliminación pertenezca a una partida activa en estado Playing.
-- - Resolver el último atacante válido (LastAttacker) a través de CombatService.
-- - Validar ventana de tiempo (LastHitLifetime), pertenencia al mismo MatchId y attacker ~= victim.
-- - Otorgar autoritativamente +1 Kill al atacante vía PlayerService.
-- - Garantizar protección estricta contra Kills duplicadas (Anti-Duplicate por MatchId + Victim + EliminationId).
-- - Limpiar CombatTags una vez resuelta la Kill.
-- NO administra la lógica de puntos de partida (ScoreService) ni reposicionamiento de spawns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Types = require(ReplicatedStorage.Shared.Types)

type MatchSession = Types.MatchSession
type EliminationRecord = Types.EliminationRecord

local EliminationService = {}
EliminationService.Name = "EliminationService"

-- Evento Bindable para que otros sistemas puedan suscribirse a eliminaciones confirmadas
local playerEliminatedBindable = Instance.new("BindableEvent")
EliminationService.PlayerEliminated = playerEliminatedBindable.Event

EliminationService._context = nil :: any
EliminationService._connections = {} :: { [string]: { RBXScriptConnection } }
EliminationService._resolvedEliminations = {} :: { [string]: boolean }
EliminationService._processingEliminations = {} :: { [Player]: number }
EliminationService._combatService = nil :: any
EliminationService._playerService = nil :: any
EliminationService._roundService = nil :: any
EliminationService._spawnService = nil :: any

function EliminationService:Init(context: any)
	self._context = context
	self._connections = {}
	self._resolvedEliminations = {}
	self._processingEliminations = {}
end

function EliminationService:Start(context: any)
	self._context = context
	print("[EliminationService] Servicio de eliminación iniciado y listo")
end

-- ==================================================
-- RESOLUCIÓN DE SERVICIOS
-- ==================================================

function EliminationService:_getCombatService(): any
	if self._combatService then return self._combatService end
	if self._context and type(self._context.GetService) == "function" then
		local s = self._context:GetService("CombatService")
		if s then self._combatService = s; return s end
	end
	local servicesFolder = ServerScriptService:FindFirstChild("Services")
	local mod = servicesFolder and servicesFolder:FindFirstChild("CombatService")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok and result then self._combatService = result; return result end
	end
	return nil
end

function EliminationService:_getPlayerService(): any
	if self._playerService then return self._playerService end
	if self._context and type(self._context.GetService) == "function" then
		local s = self._context:GetService("PlayerService")
		if s then self._playerService = s; return s end
	end
	local servicesFolder = ServerScriptService:FindFirstChild("Services")
	local mod = servicesFolder and servicesFolder:FindFirstChild("PlayerService")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok and result then self._playerService = result; return result end
	end
	return nil
end

function EliminationService:_getRoundService(): any
	if self._roundService then return self._roundService end
	if self._context and type(self._context.GetService) == "function" then
		local s = self._context:GetService("RoundService")
		if s then self._roundService = s; return s end
	end
	local servicesFolder = ServerScriptService:FindFirstChild("Services")
	local mod = servicesFolder and servicesFolder:FindFirstChild("RoundService")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok and result then self._roundService = result; return result end
	end
	return nil
end

function EliminationService:_getSpawnService(): any
	if self._spawnService then return self._spawnService end
	if self._context and type(self._context.GetService) == "function" then
		local s = self._context:GetService("SpawnService")
		if s then self._spawnService = s; return s end
	end
	local servicesFolder = ServerScriptService:FindFirstChild("Services")
	local mod = servicesFolder and servicesFolder:FindFirstChild("SpawnService")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok and result then self._spawnService = result; return result end
	end
	return nil
end

local function isPlayer(p: any): boolean
	if not p then return false end
	if typeof(p) == "Instance" then
		return p:IsA("Player")
	end
	if (typeof(p) == "userdata" or typeof(p) == "table") and type(p.IsA) == "function" then
		return p:IsA("Player")
	end
	return false
end

-- Obtiene el Player a partir de cualquier BasePart del personaje de forma robusta
local function getPlayerFromPart(part: BasePart): Player?
	if not part or not part:IsA("BasePart") then return nil end
	local current: Instance? = part
	while current and current ~= workspace do
		if current:IsA("Model") then
			local humanoid = current:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local player = Players:GetPlayerFromCharacter(current)
				if player then return player end
			end
		end
		current = current.Parent
	end
	return nil
end

-- ==================================================
-- VINCULACIÓN CON MAPAS Y PARTIDAS
-- ==================================================

-- Vincula la detección de KillParts y muertes a una MatchSession activa
function EliminationService:BindMatch(session: MatchSession)
	if not session or not session.Id then return end
	local matchId = session.Id
	self:UnbindMatch(matchId)

	local conns: { RBXScriptConnection } = {}
	self._connections[matchId] = conns

	-- 1. Vincular partes de eliminación física (KillParts)
	local killParts: { BasePart } = {}
	if session.InstanceInfo then
		if session.InstanceInfo.KillParts and #session.InstanceInfo.KillParts > 0 then
			killParts = session.InstanceInfo.KillParts
		elseif session.InstanceInfo.InstanceModel then
			for _, desc in ipairs(session.InstanceInfo.InstanceModel:GetDescendants()) do
				if desc:IsA("BasePart") and desc.Name == "KillPart" then
					table.insert(killParts, desc)
				end
			end
		end
	end

	for _, killPart in ipairs(killParts) do
		local conn = killPart.Touched:Connect(function(otherPart)
			self:HandleKillPartTouch(killPart, otherPart, session)
		end)
		table.insert(conns, conn)
	end

	-- 2. Escuchar Humanoid.Died en los jugadores de la partida
	local trackPlayerDeath = function(player: Player)
		if not player then return end

		local function onCharacter(character: Model)
			local hum = character:WaitForChild("Humanoid", 5) :: Humanoid?
			if hum then
				local diedConn = hum.Died:Connect(function()
					self:OnPlayerEliminated(player, "HumanoidDied", matchId)
				end)
				table.insert(conns, diedConn)
			end
		end

		if player.Character then
			onCharacter(player.Character)
		end
		local charConn = player.CharacterAdded:Connect(onCharacter)
		table.insert(conns, charConn)
	end

	if session.RedTeam and #session.RedTeam > 0 then
		for _, p in ipairs(session.RedTeam) do trackPlayerDeath(p) end
	elseif session.RedPlayer then
		trackPlayerDeath(session.RedPlayer)
	end

	if session.BlueTeam and #session.BlueTeam > 0 then
		for _, p in ipairs(session.BlueTeam) do trackPlayerDeath(p) end
	elseif session.BluePlayer then
		trackPlayerDeath(session.BluePlayer)
	end

	print(string.format("[EliminationService] Vinculación completada para Match '%s' (%d KillParts detectadas)",
		matchId, #killParts))
end

-- Desvincula los listeners y limpia el registro de una partida finalizada
function EliminationService:UnbindMatch(matchId: string)
	if not matchId then return end

	local conns = self._connections[matchId]
	if conns then
		for _, c in ipairs(conns) do
			c:Disconnect()
		end
		self._connections[matchId] = nil
	end

	-- Limpiar claves resueltas asociadas al matchId
	local prefix = matchId .. "_"
	for key, _ in pairs(self._resolvedEliminations) do
		if string.sub(key, 1, #prefix) == prefix then
			self._resolvedEliminations[key] = nil
		end
	end

	-- Limpiar debounces temporales
	for player, _ in pairs(self._processingEliminations) do
		if not player:IsDescendantOf(Players) then
			self._processingEliminations[player] = nil
		end
	end
end

-- ==================================================
-- SENSOR NO LETAL DE KILLPART (Zero-Death Fase 3A)
-- ==================================================

-- Procesa el contacto con un KillPart como sensor de eliminación/caída (Humanoid.Health intacto)
function EliminationService:HandleKillPartTouch(killPart: BasePart, hitPart: BasePart, session: MatchSession)
	-- 1. Validar Player desde hitPart
	local player = getPlayerFromPart(hitPart)
	if not player or not player:IsDescendantOf(Players) then return end

	-- 2. Validar que la sesión esté activa y en Playing
	if not session or not session.Id then return end
	local matchId = session.Id

	local roundService = self:_getRoundService()
	local currentState = (roundService and roundService:GetState()) or session.State
	if currentState ~= Constants.RoundState.Playing and currentState ~= Constants.RoundState.PointRestartCountdown then
		return
	end

	-- 3. Validar pertenencia del jugador a este match específico
	local belongs = false
	if session.RedPlayer == player or session.BluePlayer == player then
		belongs = true
	elseif session.RedTeam and table.find(session.RedTeam, player) then
		belongs = true
	elseif session.BlueTeam and table.find(session.BlueTeam, player) then
		belongs = true
	end
	if not belongs then return end

	-- 4. Validar que el KillPart pertenezca a la MatchInstance de este match
	if session.InstanceInfo then
		local container = session.InstanceInfo.Container
		if container and not killPart:IsDescendantOf(container) then
			-- KillPart pertenece a otra arena o no está en el contenedor de este match
			return
		end
	end

	-- 5. Anti-duplicate lock: evitar que múltiples partes del cuerpo disparen eventos concurrentes
	local now = os.clock()
	local lastTouch = self._processingEliminations[player]
	if lastTouch and (now - lastTouch) < 0.5 then
		return
	end
	self._processingEliminations[player] = now

	-- 6. POINT PROTECTION:
	-- Si el jugador es el PointScorer durante PointInProgress, NO es eliminación de combate ni caída normal.
	-- NO otorgar Kill, NO reposicionar inmediatamente para no romper la cinemática del gol.
	if session.PointInProgress and session.PointScorer == player then
		print(string.format("[EliminationService] PointScorer '%s' tocó KillPart durante PointInProgress en Match '%s'. Evento absorbido.",
			player.Name, matchId))
		local combatService = self:_getCombatService()
		if combatService and type(combatService.ClearCombatTag) == "function" then
			combatService:ClearCombatTag(player)
		end
		return
	end

	-- 7. Validar estado del Character sin alterar su vida
	local character = player.Character
	if not character or not character.Parent then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	-- 8. Resolver atacante en CombatService (ventana LastHitLifetime = 10s)
	local combatService = self:_getCombatService()
	local killer: Player? = nil

	if combatService and type(combatService.GetLastAttacker) == "function" then
		local attacker, attackerMatchId, _hitTimestamp = combatService:GetLastAttacker(
			player,
			(Config.Combat and Config.Combat.LastHitLifetime) or 10
		)

		if attacker and attacker ~= player and isPlayer(attacker) and attacker.Parent and attackerMatchId == matchId then
			killer = attacker
		end
	end

	-- 9. Clasificación del evento: CombatElimination vs Normal Fall
	local charId = tostring(character:GetDebugId())
	local elimKey = string.format("%s_%d_%s", matchId, player.UserId, charId)

	if killer then
		-- CASO A: COMBAT ELIMINATION (+1 Kill)
		if not self._resolvedEliminations[elimKey] then
			self._resolvedEliminations[elimKey] = true

			local playerService = self:_getPlayerService()
			if playerService and type(playerService.AddKill) == "function" then
				playerService:AddKill(killer, 1, "SlapElimination")
			end

			print(string.format("[EliminationService] COMBAT ELIMINATION (KillPart): '%s' eliminó a '%s' (+1 Kill) en Match '%s'",
				killer.Name, player.Name, matchId))

			-- Limpiar CombatTag consumido
			if combatService and type(combatService.ClearCombatTag) == "function" then
				combatService:ClearCombatTag(player)
			end

			-- Emitir BindableEvent para sistemas de estadísticas y feed
			local record: EliminationRecord = {
				Victim = player,
				Killer = killer,
				MatchId = matchId,
				Timestamp = now,
				Reason = "KillPart",
				EliminationId = elimKey,
			}
			playerEliminatedBindable:Fire(record)
		end
	else
		-- CASO B: NORMAL FALL (+0 Kill)
		print(string.format("[EliminationService] NORMAL FALL (KillPart): '%s' cayó sin atacante en Match '%s'",
			player.Name, matchId))

		-- Limpiar CombatTag residual si existiese
		if combatService and type(combatService.ClearCombatTag) == "function" then
			combatService:ClearCombatTag(player)
		end

		local record: EliminationRecord = {
			Victim = player,
			Killer = nil,
			MatchId = matchId,
			Timestamp = now,
			Reason = "KillPart_NormalFall",
			EliminationId = elimKey,
		}
		playerEliminatedBindable:Fire(record)
	end

	-- 10. Reposicionamiento del Character EXISTENTE sin matar Humanoid ni recargar rig
	local spawnService = self:_getSpawnService()
	if spawnService and type(spawnService.ResetCharacterInArena) == "function" then
		spawnService:ResetCharacterInArena(player)
	end
end

-- ==================================================
-- RESOLUCIÓN DE ELIMINACIONES Y KILLS (Compatibilidad)
-- ==================================================

-- Invocado cuando un jugador es eliminado; resuelve la atribución de Kill de forma segura
function EliminationService:OnPlayerEliminated(victim: Player, reason: string, overrideMatchId: string?): (boolean, Player?)
	-- 1. Validar que la víctima exista y sea Player
	if not isPlayer(victim) then
		return false, nil
	end

	-- 2. Resolver y validar MatchId
	local matchId = overrideMatchId
	local roundService = self:_getRoundService()
	local session: MatchSession? = nil

	if matchId then
		if roundService and type(roundService.GetSessionById) == "function" then
			session = roundService:GetSessionById(matchId)
		end
	else
		if roundService and type(roundService.GetSessionForPlayer) == "function" then
			session = roundService:GetSessionForPlayer(victim)
			if session then
				matchId = session.Id
			end
		end
	end

	if not matchId or not session then
		-- Jugador fuera de partida o match no encontrado
		return false, nil
	end

	-- 3. Validar que la partida no esté cancelada ni terminada
	if session.Result == "Cancelled" then
		return false, nil
	end

	-- 3.1 POINT SCORER CHECK (PointScoreDeath):
	-- Si el jugador que acaba de morir es el PointScorer del match durante el flujo de PointInProgress,
	-- esta muerte es una consecuencia directa del scoring (caída al vacío post-anotación).
	-- NO es Kill, NO es eliminación normal, NO debe otorgarse kill a nadie ni alterar el match.
	if session.PointInProgress and session.PointScorer == victim then
		print(string.format("[EliminationService] PointScoreDeath detectada para '%s' en Match '%s' (Razón: %s). Muerte por anotación aislada del sistema de eliminaciones.",
			victim.Name, matchId, tostring(reason)))

		-- Limpiar CombatTag de la víctima para que un golpe previo no se atribuya erróneamente más tarde
		local combatService = self:_getCombatService()
		if combatService and type(combatService.ClearCombatTag) == "function" then
			combatService:ClearCombatTag(victim)
		end

		return false, nil
	end

	-- 4. ANTI-DUPLICATE CHECK: Cada eliminación produce exactamente 1 resolución
	local char = victim.Character
	local charId = if char then tostring(char:GetDebugId()) else tostring(victim.UserId)
	local elimKey = string.format("%s_%d_%s", matchId, victim.UserId, charId)

	if self._resolvedEliminations[elimKey] then
		-- Ya fue resuelta para este personaje / ciclo de vida
		return false, nil
	end
	self._resolvedEliminations[elimKey] = true

	-- 5. Resolver el último atacante válido mediante CombatService
	local combatService = self:_getCombatService()
	local killer: Player? = nil

	if combatService and type(combatService.GetLastAttacker) == "function" then
		local attacker, attackerMatchId, _hitTimestamp = combatService:GetLastAttacker(
			victim,
			(Config.Combat and Config.Combat.LastHitLifetime) or 10
		)

		-- 6. Validaciones estrictas sobre el atacante
		if attacker and attacker ~= victim and isPlayer(attacker) and attacker.Parent and attackerMatchId == matchId then
			killer = attacker
		end
	end

	-- 7. Limpiar CombatTag de la víctima para no reutilizar impactos previos
	if combatService and type(combatService.ClearCombatTag) == "function" then
		combatService:ClearCombatTag(victim)
	end

	-- 8. Atribución autoritativa de Kill si existe atacante válido
	if killer then
		local playerService = self:_getPlayerService()
		if playerService and type(playerService.AddKill) == "function" then
			playerService:AddKill(killer, 1, "SlapElimination")
		end

		print(string.format("[EliminationService] KILL CONFIRMADA: '%s' eliminó a '%s' en Match '%s' (Razón: %s)",
			killer.Name, victim.Name, matchId, reason or "KillPart"))
	else
		print(string.format("[EliminationService] Eliminación de '%s' en Match '%s' sin atacante válido (Razón: %s)",
			victim.Name, matchId, reason or "Fall/Suicide"))
	end

	-- 9. Emitir registro a través del BindableEvent
	local record: EliminationRecord = {
		Victim = victim,
		Killer = killer,
		MatchId = matchId,
		Timestamp = os.clock(),
		Reason = reason or "Unknown",
		EliminationId = elimKey,
	}
	playerEliminatedBindable:Fire(record)

	return true, killer
end

return EliminationService
