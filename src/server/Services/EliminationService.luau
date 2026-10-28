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
local CompetitiveTransit = require(script.Parent.Respawn.CompetitiveTransit)
local Types = require(ReplicatedStorage.Shared.Types)
local DeathFeedbackContract = require(ReplicatedStorage.Shared.DeathFeedbackContract)
local ArenaRespawnPolicy = require(ReplicatedStorage.Shared.ArenaRespawnPolicy)
local DeathEffectCatalog = require(ReplicatedStorage.Shared.DeathEffectDefinitions)
local DeathFeedbackSettings = require(ReplicatedStorage.Shared.DeathFeedbackConfig)

type MatchSession = Types.MatchSession
type EliminationRecord = Types.EliminationRecord

local EliminationService = {}
EliminationService.Name = "EliminationService"

-- Evento Bindable para que otros sistemas puedan suscribirse a eliminaciones confirmadas
local playerEliminatedBindable = Instance.new("BindableEvent")
EliminationService.PlayerEliminated = playerEliminatedBindable.Event

EliminationService._transits = CompetitiveTransit.new()
EliminationService._context = nil :: any
EliminationService._connections = {} :: { [string]: { RBXScriptConnection } }
EliminationService._resolvedEliminations = {} :: { [string]: boolean }
EliminationService._processingEliminations = {} :: { [Player]: number }
EliminationService._eliminationCounters = {} :: { [Player]: number }
EliminationService._activeSessions = {} :: { [string]: MatchSession }
EliminationService._isPolling = false
EliminationService._pollThread = nil :: thread?
EliminationService._combatService = nil :: any
EliminationService._playerService = nil :: any
EliminationService._roundService = nil :: any
EliminationService._spawnService = nil :: any

function EliminationService:Init(context: any)
	self._context = context
	self._transits = CompetitiveTransit.new()
	self._connections = {}
	self._resolvedEliminations = {}
	self._processingEliminations = {}
	self._eliminationCounters = {}
	self._activeSessions = {}
	self._isPolling = false
	self._pollThread = nil
end

function EliminationService:Start(context: any)
	self._context = context
	self._playerRemovingConnection = Players.PlayerRemoving:Connect(function(player)
		for sessionId in pairs(self._activeSessions) do self._transits:ForgetPlayer(sessionId,player) end
	end)
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

function EliminationService:_getActiveSession(sessionId: string): MatchSession?
	local roundService = self:_getRoundService()
	if not roundService
		or type(roundService.GetSessionById) ~= "function"
		or type(roundService.IsSessionActive) ~= "function"
		or not roundService:IsSessionActive(sessionId) then
		return nil
	end
	return roundService:GetSessionById(sessionId)
end

function EliminationService:_getParticipant(sessionId: string, player: Player): any?
	local roundService = self:_getRoundService()
	if not roundService or type(roundService.GetSessionParticipant) ~= "function" then
		return nil
	end
	return roundService:GetSessionParticipant(sessionId, player)
end

function EliminationService:_isOpposingParticipant(sessionId: string, attacker: Player, victim: Player): boolean
	local attackerParticipant = self:_getParticipant(sessionId, attacker)
	local victimParticipant = self:_getParticipant(sessionId, victim)
	return attackerParticipant ~= nil
		and victimParticipant ~= nil
		and attackerParticipant.Team ~= victimParticipant.Team
end

-- ==================================================
-- VINCULACIÓN CON MAPAS Y PARTIDAS
-- ==================================================

-- Vincula la detección de KillParts, VoidBoundary y muertes a una MatchSession activa
-- Called by ScoreService after its own zone/team validations, before any goal callbacks/yields.
function EliminationService:TryProtectGoal(session: MatchSession, player: Player, character: Model, pointId: string): boolean
 if self:_getActiveSession(session.Id) ~= session or session.State ~= Constants.RoundState.Playing then return false end
 if not self:_getParticipant(session.Id,player) or player.Character~=character or not character.Parent then return false end
 if character:GetAttribute("ArenaRespawnPending") then return false end
 local humanoid=character:FindFirstChildOfClass("Humanoid")
 if not humanoid or humanoid.Health<=0 then return false end
 return self._transits:Claim(session,player,character,character:GetAttribute("ArenaPhysicsGeneration") or 0,"Goal",pointId)
end

function EliminationService:ReleaseGoalProtections(sessionId: string)
 self._transits:ReleaseGoals(sessionId)
end

function EliminationService:BindMatch(session: MatchSession)
	if not session or not session.Id then return end
	local matchId = session.Id
	if self:_getActiveSession(matchId) ~= session then return end
	self:UnbindMatch(matchId)

	local conns: { RBXScriptConnection } = {}
	self._connections[matchId] = conns

	-- 1. Vincular partes de eliminación física (KillParts) como sensores no letales
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

	-- 2. Vincular sensor de límite de vacío (VoidBoundaryPart) como sensor no letal
	if session.InstanceInfo and session.InstanceInfo.VoidBoundaryPart then
		local voidBoundary = session.InstanceInfo.VoidBoundaryPart
		local voidConn = voidBoundary.Touched:Connect(function(otherPart)
			self:HandleVoidBoundaryTouch(voidBoundary, otherPart, session)
		end)
		table.insert(conns, voidConn)
	end

	-- 3. Escuchar Humanoid.Died en modo diagnóstico pasivo (Fase 4B Zero-Death)
	local trackPlayerDeath = function(player: Player)
		if not player then return end

		local function onCharacter(character: Model)
			self._transits:ForgetPlayer(matchId,player)
			table.insert(conns, character.Destroying:Connect(function()
				if player.Character==character then self._transits:ForgetPlayer(matchId,player) end
			end))
			local hum = character:WaitForChild("Humanoid", 5) :: Humanoid?
			if hum then
				local diedConn = hum.Died:Connect(function()
					warn(string.format("[EliminationService] [DIAGNOSTIC] Humanoid.Died detectado en '%s' durante Match '%s'. Evento absorbido pasivamente por Zero-Death (sin scoring, sin respawn).",
						player.Name, matchId))
				end)
				table.insert(conns, diedConn)
			end
		end

		if player.Character then
			onCharacter(player.Character)
		end
		table.insert(conns, player.CharacterRemoving:Connect(function() self._transits:ForgetPlayer(matchId,player) end))
		table.insert(conns, player:GetAttributeChangedSignal("MatchId"):Connect(function()
			if player:GetAttribute("MatchId")~=matchId then self._transits:ForgetPlayer(matchId,player) end
		end))
		local charConn = player.CharacterAdded:Connect(onCharacter)
		table.insert(conns, charConn)
	end

	for _, participant in ipairs(session.Participants) do
		if self:_getParticipant(matchId, participant.Player) == participant then
			trackPlayerDeath(participant.Player)
		end
	end

	-- Registrar sesión activa y arrancar polling fail-safe si corresponde
	self._activeSessions[matchId] = session
	self:_startPollingIfNeeded()

	print(string.format("[EliminationService] Vinculación completada para Match '%s' (%d KillParts, VoidBoundary: %s)",
		matchId, #killParts, tostring(session.InstanceInfo and session.InstanceInfo.VoidBoundaryPart ~= nil)))
end

-- Desvincula los listeners y limpia el registro de una partida finalizada
function EliminationService:UnbindMatch(matchId: string)
	if not matchId then return end
	self._transits:ClearSession(matchId)
	local spawn = self:_getSpawnService()
	if spawn and spawn.CancelSessionRespawns then spawn:CancelSessionRespawns(matchId, "MatchUnbound") end

	local conns = self._connections[matchId]
	if conns then
		for _, c in ipairs(conns) do
			c:Disconnect()
		end
		self._connections[matchId] = nil
	end

	-- Desregistrar sesión activa y detener polling si no quedan partidas
	self._activeSessions[matchId] = nil
	if next(self._activeSessions) == nil then
		self:_stopPolling()
	end

	-- Limpiar claves resueltas asociadas al matchId
	local prefix = matchId .. "_"
	for key, _ in pairs(self._resolvedEliminations) do
		if string.sub(key, 1, #prefix) == prefix then
			self._resolvedEliminations[key] = nil
		end
	end

	-- Limpiar debounces y contadores temporales de jugadores desconectados
	for player, _ in pairs(self._processingEliminations) do
		if not player:IsDescendantOf(Players) then
			self._processingEliminations[player] = nil
		end
	end
	for player, _ in pairs(self._eliminationCounters) do
		if not player:IsDescendantOf(Players) then
			self._eliminationCounters[player] = nil
		end
	end
end

-- ==================================================
-- SENSORES NO LETALES (Zero-Death Fase 3A / 3B)
-- ==================================================

-- Procesa el contacto con un KillPart como sensor de eliminación/caída (Humanoid.Health intacto)
function EliminationService:_publishReceipt(record: EliminationRecord,beforeRoundClose: boolean?)
 -- Deferred Bindable delivery may run after a fifth-goal terminal barrier.
 -- Deliver this same receipt synchronously before closing; normal subscriber dedup remains authoritative.
 if beforeRoundClose then
  local effects=self._context and self._context:GetService("DeathEffectService")
  if effects then
   local ok,err=pcall(function() effects:HandleConfirmed(record) end)
   if not ok then warn("[EliminationService] Sudden-death presentation failed: "..tostring(err)) end
  end
 end
 playerEliminatedBindable:Fire(record)
end

-- Third authoritative Slap hit: same receipt/award/effect/Zero-Death pipeline, at the actual victim position.
function EliminationService:HandleSlapThreshold(victim: Player,session: MatchSession,attacker: Player): boolean
 if not self:_isOpposingParticipant(session.Id,attacker,victim) then return false end
 local combat=self:_getCombatService()
 local last,matchId=combat:GetLastAttacker(victim,Config.Combat.LastHitLifetime)
 if last~=attacker or matchId~=session.Id then return false end
 return self:_processEliminationEvent(victim,session,"SlapThreshold")==true
end

function EliminationService:HandleKillPartTouch(killPart: BasePart, hitPart: BasePart, session: MatchSession)
	local player = getPlayerFromPart(hitPart)
	if not player then return end
	if not ArenaRespawnPolicy.IsContactCurrent(killPart.CFrame, killPart.Size, hitPart.Position, hitPart.Size) then return end
	self:_processEliminationEvent(player, session, "KillPart", killPart, hitPart)
end

-- Controlled impact capability; modules never call the elimination/economy service.
function EliminationService:HandleAbilityHit(victim: Player, session: MatchSession, attacker: Player, reason: string): boolean
 if reason~="StrongSlap" and reason~="AbilityImpact" then return false end
 if not self:_isOpposingParticipant(session.Id,attacker,victim) then return false end
 local last,matchId=self:_getCombatService():GetLastAttacker(victim,Config.Combat.LastHitLifetime)
 if last~=attacker or matchId~=session.Id then return false end
 return self:_processEliminationEvent(victim,session,reason)==true
end

-- Procesa el contacto con el sensor VoidBoundaryPart de la arena (Humanoid.Health intacto)
function EliminationService:HandleVoidBoundaryTouch(voidBoundary: BasePart, hitPart: BasePart, session: MatchSession)
	local player = getPlayerFromPart(hitPart)
	if not player then return end
	if not ArenaRespawnPolicy.IsContactCurrent(voidBoundary.CFrame, voidBoundary.Size, hitPart.Position, hitPart.Size) then return end
	self:_processEliminationEvent(player, session, "VoidBoundary", voidBoundary, hitPart)
end

-- Núcleo unificado de procesamiento autoritativo de salida / eliminación sin muerte física
function EliminationService:_processEliminationEvent(player: Player, session: MatchSession, source: string, boundaryPart: BasePart?, hitPart: BasePart?)
	-- 1. Validar que la instancia sea un Player conectado
	if not player or not isPlayer(player) or not player:IsDescendantOf(Players) then return end

	-- 2. Validar que la sesión esté activa y en estado válido para el lifecycle
	if not session or not session.Id then return end
	local matchId = session.Id

	local roundService = self:_getRoundService()
	if self:_getActiveSession(matchId) ~= session then return end
	local currentState = roundService:GetSessionState(matchId)

	-- Estados permitidos: Playing, PointRestartCountdown, StartCountdown, Ending
	if currentState ~= Constants.RoundState.Playing
		and currentState ~= Constants.RoundState.PointRestartCountdown
		and currentState ~= Constants.RoundState.StartCountdown
		and currentState ~= Constants.RoundState.Ending then
		return
	end

	if currentState==Constants.RoundState.Playing and not roundService:IsGameplayRoundOpen(session) then return end

	-- 3. Validar pertenencia estricta del jugador a este match específico
	if not self:_getParticipant(matchId, player) then return end
	local respawnOwner = self:_getSpawnService()
	if respawnOwner and respawnOwner.IsKillPartRespawnPending and respawnOwner:IsKillPartRespawnPending(player) then return end

	-- 4. Multi-match isolation: Validar que el boundaryPart pertenezca al contenedor de esta MatchInstance
	if boundaryPart and session.InstanceInfo then
		local container = session.InstanceInfo.Container
		if container and not boundaryPart:IsDescendantOf(container) then
			-- El sensor tocado pertenece a otra arena
			return
		end
	end

	-- Reject the exact already-resolved transit BEFORE debounce, attribution, awards or feedback.
 local character = player.Character
 if not character or not character.Parent then return end
 if hitPart and not hitPart:IsDescendantOf(character) then return end
 local humanoid=character:FindFirstChildOfClass("Humanoid")
 if not humanoid or humanoid.Health<=0 then return end
 local generation=character:GetAttribute("ArenaPhysicsGeneration") or 0
 local resolved=self._transits:Get(session,player,character,generation)
 if resolved then
  if Config.Respawn.Debug then print("[ScoreKillPart] ContactSuppressed",matchId,player.UserId,resolved.Kind,resolved.EventId,generation,source) end
  return
 end

 -- Countdown contacts can use the existing placement recovery, but are not competitive eliminations.
 -- A protected goal Character has already returned above; do not give it a second recovery.
 if currentState~=Constants.RoundState.Playing then
  if respawnOwner and respawnOwner.ResetCharacterInArena then respawnOwner:ResetCharacterInArena(player,matchId) end
  return
 end

 -- Existing debounce remains for accepted elimination attempts only.
 local now=os.clock()
 local lastTouch=self._processingEliminations[player]
 if lastTouch and now-lastTouch<0.5 then return end
 self._processingEliminations[player]=now

	-- First validated authority wins; no callback/yield before reserving this life.
 if not self._transits:Claim(session,player,character,generation,"Elimination",source) then return end
 local abilities=self._context and self._context:GetService("AbilityService")
 if abilities then abilities:CancelPlayer(player,"Eliminated") end
 local round=session.GameplayRound
 local fall=source=="KillPart" or source=="VoidBoundary" or source=="VoidBoundaryPolling"
 local suddenGoal=fall and currentState==Constants.RoundState.Playing and round~=nil
  and round.SuddenDeath and Config.Round.SuddenDeath.FallAwardsGoal
 local suddenRoundId=round and round.Id
 if suddenGoal and not roundService:TryResolveGameplayRound(session,"SuddenDeathFall") then return end

	-- Capture contact BEFORE ResetCharacterInArena; never read a later spawn position in the feed.
	local impactCFrame: CFrame? = if source=="SlapThreshold" or source=="StrongSlap" or source=="AbilityImpact" then character:GetPivot() else nil
		if boundaryPart then
			local impactPart = hitPart or character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if impactPart then impactCFrame = DeathFeedbackContract.ImpactCFrame(boundaryPart.CFrame, boundaryPart.Size, impactPart.Position) end
	end
	local rewardCoins = 0

	-- 8. Resolver atacante en CombatService (solo elegible durante Playing o PointRestartCountdown)
	local combatEligible = (currentState == Constants.RoundState.Playing or currentState == Constants.RoundState.PointRestartCountdown)
	local combatService = self:_getCombatService()
	local killer: Player? = nil

	if combatEligible and combatService and type(combatService.GetLastAttacker) == "function" then
		local attacker, attackerMatchId = combatService:GetLastAttacker(
			player,
			(Config.Combat and Config.Combat.LastHitLifetime) or 10
		)

		if attacker and attacker ~= player and isPlayer(attacker) and attacker.Parent
			and attackerMatchId == matchId
			and self:_isOpposingParticipant(matchId, attacker, player) then
			killer = attacker
		end
	end

	-- 9. Clasificación del evento: CombatElimination vs Normal Fall
	local counter = (self._eliminationCounters[player] or 0) + 1
	self._eliminationCounters[player] = counter
	local elimKey = string.format("%s_%d_%d", matchId, player.UserId, counter)
		-- Resolve the victim cosmetic and immutable presentation identity BEFORE retirement.
		local effectId = DeathFeedbackContract.ResolveEffect(self:_getPlayerService(), player, killer ~= nil, DeathEffectCatalog, DeathFeedbackSettings.DeathEffects)
		local feedbackSnapshot = table.freeze({
			SessionId=matchId, StateVersion=session.StateVersion, EliminationId=elimKey,
			VictimUserId=player.UserId, VictimName=player.DisplayName,
			KillerUserId=killer and killer.UserId, KillerName=killer and killer.DisplayName,
			EffectId=effectId, ImpactCFrame=impactCFrame, Reason=source,
			Kind=if killer then "CreditedKill" else "UnattributedFall",
			Generation=character:GetAttribute("ArenaPhysicsGeneration") or 0,
		})
		if Config.Respawn.Debug then print("[RespawnDebug] EliminationConfirmed",matchId,elimKey,player.UserId,feedbackSnapshot.Generation,currentState,source,killer and killer.UserId,effectId) end
	local deferredRespawn = false
		if currentState == Constants.RoundState.Playing and not suddenGoal
		and respawnOwner and respawnOwner.BeginKillPartRespawn then
		-- Identity/impact/attacker are already captured. Retire now, before any downstream callbacks.
			-- Touched and void polling must use the SAME retirement/quiet recovery path.
			deferredRespawn = respawnOwner:BeginKillPartRespawn(player, session, elimKey, source .. (if killer then "_Kill" else "_NormalFall"))
	end

	if killer then
		-- CASO A: COMBAT ELIMINATION (+1 Kill)
		if not self._resolvedEliminations[elimKey] then
			self._resolvedEliminations[elimKey] = true
				-- Deaths means accepted competitive eliminations, never normal zero-death falls.
				if roundService.RecordMatchPerformance then
					roundService:RecordMatchPerformance(matchId, "Elimination_" .. elimKey, nil, killer, player)
				end

			local playerService = self:_getPlayerService()
			if playerService and type(playerService.AddKill) == "function" then
					playerService:AddKill(killer, 1, "SlapElimination")
					if type(playerService.AwardConfirmedKill) == "function" then
						-- Credit once by EliminationId; only the committed amount enters the visual receipt.
						rewardCoins = playerService:AwardConfirmedKill(killer, player, matchId, elimKey)
					end
			end

			print(string.format("[EliminationService] COMBAT ELIMINATION (%s): '%s' eliminó a '%s' (+1 Kill) en Match '%s'",
				source, killer.Name, player.Name, matchId))

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
				Reason = source,
				EliminationId = elimKey,
					FeedbackSnapshot = feedbackSnapshot,
					ImpactCFrame = impactCFrame,
					RewardCoins = rewardCoins,
					StateVersion = session.StateVersion,
					ConfirmedAt = workspace:GetServerTimeNow(),
			}
			self:_publishReceipt(record,suddenGoal)
		end
	else
		-- CASO B: NORMAL FALL (+0 Kill)
		print(string.format("[EliminationService] NORMAL FALL (%s): '%s' cayó sin atacante en Match '%s' (Estado: %s)",
			source, player.Name, matchId, tostring(currentState)))

		-- Limpiar CombatTag residual si existiese
		if combatService and type(combatService.ClearCombatTag) == "function" then
			combatService:ClearCombatTag(player)
		end

		local record: EliminationRecord = {
			Victim = player,
			Killer = nil,
			MatchId = matchId,
			Timestamp = now,
			Reason = source .. "_NormalFall",
			EliminationId = elimKey,
				FeedbackSnapshot = feedbackSnapshot,
			ImpactCFrame = impactCFrame,
			RewardCoins = 0,
				StateVersion = session.StateVersion,
				ConfirmedAt = workspace:GetServerTimeNow(),
		}
		self:_publishReceipt(record,suddenGoal)
	end

	if suddenGoal then
  local score=self._context and self._context:GetService("ScoreService")
  if not score or not score:AwardSuddenDeathGoal(session,player,suddenRoundId) then
   roundService:CloseSession(matchId,{Cancelled=true,Reason="SuddenDeathGoalCommitFailed"})
  end
  return true
 end

	-- 10. Reposicionamiento del Character EXISTENTE sin matar Humanoid ni recargar rig
	local spawnService = self:_getSpawnService()
	if not deferredRespawn and spawnService and type(spawnService.ResetCharacterInArena) == "function" then
		spawnService:ResetCharacterInArena(player)
	end
	return true
end

-- ==================================================
-- POLLING FAIL-SAFE DE CAÍDAS AL VACÍO (Fase 3B)
-- ==================================================

function EliminationService:_startPollingIfNeeded()
	if self._isPolling then return end
	self._isPolling = true
	self._pollThread = task.spawn(function()
		self:_pollActiveSessions()
	end)
end

function EliminationService:_stopPolling()
	self._isPolling = false
	if self._pollThread then
		task.cancel(self._pollThread)
		self._pollThread = nil
	end
end

-- Chequeo periódico exclusivo sobre participantes de partidas activas
function EliminationService:_pollActiveSessions()
	local pollInterval = (Config.Arena and Config.Arena.VoidBoundaryPollInterval) or 0.2

	while self._isPolling do
		task.wait(pollInterval)
		if not self._isPolling then break end

		for matchId, session in pairs(self._activeSessions) do
			if not session or not session.InstanceInfo then continue end
			if self:_getActiveSession(matchId) ~= session then continue end
			local boundaryPart = session.InstanceInfo.VoidBoundaryPart
			if not boundaryPart or not boundaryPart.Parent then continue end

			local roundService = self:_getRoundService()
			local currentState = roundService:GetSessionState(matchId)
			if currentState ~= Constants.RoundState.Playing
				and currentState ~= Constants.RoundState.PointRestartCountdown
				and currentState ~= Constants.RoundState.StartCountdown
				and currentState ~= Constants.RoundState.Ending then
				continue
			end

			-- Criterio de altura: relativa a la geometría del VoidBoundary de esta MatchInstance
			local thresholdY = boundaryPart.Position.Y + (boundaryPart.Size.Y * 0.5)

			local playersToCheck: { Player } = {}
			for _, participant in ipairs(session.Participants) do
				if self:_getParticipant(matchId, participant.Player) == participant then
					table.insert(playersToCheck, participant.Player)
				end
			end

			local now = os.clock()
			for _, player in ipairs(playersToCheck) do
				if not player:IsDescendantOf(Players) then continue end

				-- Descarte rápido si ya está en procesamiento activo por Touched
				local lastTouch = self._processingEliminations[player]
				if lastTouch and (now - lastTouch) < 0.5 then
					continue
				end

				local character = player.Character
				if not character or not character.Parent then continue end
				local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not hrp then continue end

				if hrp.Position.Y <= thresholdY then
					self:_processEliminationEvent(player, session, "VoidBoundaryPolling", boundaryPart)
				end
			end
		end
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
	if self:_getActiveSession(matchId) ~= session or not self:_getParticipant(matchId, victim) then
		return false, nil
	end

	-- En arquitectura Zero-Death, las eliminaciones autoritativas ocurren exclusivamente via KillPart/VoidBoundary
	local currentState = roundService:GetSessionState(matchId)
	if currentState == Constants.RoundState.Playing or currentState == Constants.RoundState.PointRestartCountdown then
		warn(string.format("[EliminationService] [DIAGNOSTIC] OnPlayerEliminated invocado para '%s' (Razón: %s) en partida Zero-Death. Se descarta scoring o respawn secundario.",
			victim.Name, tostring(reason)))
		return false, nil
	end

	-- 3. Validar que la partida no esté cancelada ni terminada
	if session.Result == "Cancelled" then
		return false, nil
	end

	local currentCharacter=victim.Character
 if currentCharacter and self._transits:Get(session,victim,currentCharacter,currentCharacter:GetAttribute("ArenaPhysicsGeneration") or 0) then return false,nil end

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
		if attacker and attacker ~= victim and isPlayer(attacker) and attacker.Parent
			and attackerMatchId == matchId
			and self:_isOpposingParticipant(matchId, attacker, victim) then
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
