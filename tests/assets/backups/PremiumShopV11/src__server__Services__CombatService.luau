--!strict
-- CombatService
-- Registro autoritativo centralizado de combate y CombatTags.
-- Responsabilidad exclusiva:
-- - Registrar impactos válidos (Slaps) entre jugadores en una partida.
-- - Asociar CombatTags al MatchId correspondiente y timestamp del impacto.
-- - Mantener el último atacante válido (LastAttacker) con ventana de expiración (LastHitLifetime).
-- - Validar que atacante y víctima pertenezcan al mismo Match y la partida esté en estado Playing.
-- - Proveer estructura extensible para futuras asistencias y estadísticas de combate.
-- NO administra la eliminación física ni otorga puntos directamente.

local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Types = require(ReplicatedStorage.Shared.Types)

type CombatTag = Types.CombatTag
type CombatHitHistoryItem = Types.CombatHitHistoryItem
type MatchSession = Types.MatchSession

local CombatService = {}
CombatService.Name = "CombatService"

CombatService._context = nil :: any
CombatService._tags = {} :: { [Player]: CombatTag }
CombatService._lifeHits = {} :: { [Player]: any }
CombatService._history = {} :: { [Player]: { CombatHitHistoryItem } }
CombatService._roundService = nil :: any

function CombatService:Init(context: any)
	self._context = context
	self._tags = {}
	self._history = {}
	self._lifeHits = {}
end

function CombatService:Start(context: any)
	self._context = context
	Players.PlayerRemoving:Connect(function(player) self:ClearCombatTag(player) end)
	print("[CombatService] Servicio de combate iniciado y listo")
end

function CombatService:_getRoundService(): any
	if self._roundService then
		return self._roundService
	end
	if self._context and type(self._context.GetService) == "function" then
		local s = self._context:GetService("RoundService")
		if s then
			self._roundService = s
			return s
		end
	end
	local servicesFolder = ServerScriptService:FindFirstChild("Services")
	local mod = servicesFolder and servicesFolder:FindFirstChild("RoundService")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok and result then
			self._roundService = result
			return result
		end
	end
	return nil
end

function CombatService:_resolveSession(player: Player): MatchSession?
	local roundService = self:_getRoundService()
	if roundService and type(roundService.GetSessionForPlayer) == "function" then
		return roundService:GetSessionForPlayer(player)
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

-- ==================================================
-- REGISTRO DE IMPACTOS Y COMBAT TAGS
-- ==================================================

-- One server clock and one scoped record for selection and final hit admission.
-- Do not use PlatformStand/timer callbacks: scheduler delay must not extend immunity.
function CombatService:IsHitProtected(victim: Player, session: MatchSession): boolean
	local hits = self._lifeHits[victim]
	local character = victim.Character
	return hits ~= nil and character ~= nil and hits.Character == character
		and hits.Session == session and hits.SessionId == session.Id
		and hits.RoundId == (session.GameplayRound and session.GameplayRound.Id)
		and hits.Generation == (character:GetAttribute("ArenaPhysicsGeneration") or 0)
		and os.clock() < (hits.ProtectedUntil or 0)
end

-- Registra un impacto de combate válido entre dos jugadores
function CombatService:RegisterHit(attacker: Player, victim: Player, overrideMatchId: string?, skipComboCount: boolean?): (boolean, string?, number?)
	-- 1. Validar que ambos jugadores existan y sean instancias Player
	if not isPlayer(attacker) then
		return false, "InvalidAttacker"
	end
	if not isPlayer(victim) then
		return false, "InvalidVictim"
	end

	-- 2. Validar que attacker ~= victim (rechazar auto-ataque)
	if attacker == victim then
		return false, "SelfAttack"
	end

	-- 3. Validar que sigan en el DataModel
	if not attacker.Parent or not victim.Parent then
		return false, "PlayerNotDescendant"
	end
	for _, player in ipairs({ attacker, victim }) do
		local character = player.Character
		if typeof(character) == "Instance" and character:GetAttribute("ArenaRespawnPending") then
			return false, "ParticipantRespawning"
		end
	end

	-- 4. Resolver y validar MatchId
	local roundService = self:_getRoundService()
	if not roundService then
		return false, "RoundServiceUnavailable"
	end

	local victimSession = self:_resolveSession(victim)
	local matchId = overrideMatchId or (victimSession and victimSession.Id)
	local session: MatchSession? = if matchId and type(roundService.GetSessionById) == "function"
		then roundService:GetSessionById(matchId)
		else nil

	if not matchId or not session then
		return false, "NotInMatch"
	end
	if session.Closing or session.Cancelled or session.Closed then
		return false, "SessionClosing"
	end

	-- 5. Validar identidad, vigencia y estado de la sesión explícita
	if victimSession ~= session
		or type(roundService.IsSessionActive) ~= "function"
		or not roundService:IsSessionActive(matchId) then
		return false, "DifferentMatch"
	end
	local currentState = if type(roundService.GetSessionState) == "function"
		then roundService:GetSessionState(matchId)
		else nil
	if currentState ~= Constants.RoundState.Playing then
		return false, "MatchNotPlaying"
	end

	if not roundService:IsGameplayRoundOpen(session) then return false,"RoundNotOpen" end

	-- 6. Validar que AMBOS pertenezcan al mismo MatchId
	local attackerSession = self:_resolveSession(attacker)
	if attackerSession ~= session then
		return false, "DifferentMatch"
	end
	if type(roundService.GetSessionParticipant) ~= "function" then
		return false, "ParticipantRegistryUnavailable"
	end
	local attackerParticipant = roundService:GetSessionParticipant(matchId, attacker)
	local victimParticipant = roundService:GetSessionParticipant(matchId, victim)
	if not attackerParticipant or not victimParticipant then
		return false, "NotInMatch"
	end
	if attackerParticipant.State == "Left" or attackerParticipant.State == "Released"
		or victimParticipant.State == "Left" or victimParticipant.State == "Released" then
		return false, "ParticipantInactive"
	end
	if attackerParticipant.Team == victimParticipant.Team then
		return false, "SameTeam"
	end

	local character=victim.Character
 if not character then return false,"VictimNotSpawned" end
 local generation=character:GetAttribute("ArenaPhysicsGeneration") or 0
 local roundId=session.GameplayRound.Id
 if self:IsHitProtected(victim, session) then return false,"VictimHitProtected" end
 local hits=self._lifeHits[victim]
 if not hits or hits.Session~=session or hits.SessionId~=session.Id or hits.RoundId~=roundId or hits.Character~=character or hits.Generation~=generation then
  hits={Session=session,SessionId=session.Id,RoundId=roundId,Character=character,Generation=generation,Count=0}
  self._lifeHits[victim]=hits
 end
 if not skipComboCount then hits.Count+=1 end

	-- 7. Registrar o actualizar CombatTag autoritativo
	local timestamp = os.clock()
	-- Reserve before any physics/ability side effects; rejected contacts never refresh it.
	hits.ProtectedUntil = timestamp + Config.Combat.DefaultSlapKnockdownDuration
	local tag: CombatTag = {
		Victim = victim,
		Attacker = attacker,
		MatchId = matchId,
		Timestamp = timestamp,
		HitId = HttpService:GenerateGUID(false),
	}

	self._tags[victim] = tag

	-- 8. Registrar en historial para futuras asistencias y métricas
	if not self._history[victim] then
		self._history[victim] = {}
	end
	table.insert(self._history[victim], {
		Attacker = attacker,
		Timestamp = timestamp,
		Damage = 0,
	})

	print(string.format("[CombatService] Hit registrado: '%s' golpeó a '%s' en Match '%s'",
		attacker.Name, victim.Name, matchId))

	return true, nil, hits.Count
end

-- Retorna el CombatTag activo de una víctima
function CombatService:GetCombatTag(victim: Player): CombatTag?
	if not victim then return nil end
	return self._tags[victim]
end

-- Resuelve el último atacante válido de una víctima considerando ventana de expiración
function CombatService:GetLastAttacker(victim: Player, maxLifetime: number?): (Player?, string?, number?)
	if not victim then return nil, nil, nil end

	local tag = self._tags[victim]
	if not tag then
		return nil, nil, nil
	end

	-- Validar ventana de expiración (LastHitLifetime)
	local lifetime = maxLifetime or (Config.Combat and Config.Combat.LastHitLifetime) or 10
	local elapsed = os.clock() - tag.Timestamp
	if elapsed > lifetime then
		return nil, nil, nil
	end

	-- Validar que el atacante siga siendo un Player válido en el juego
	local attacker = tag.Attacker
	if not isPlayer(attacker) or not attacker.Parent then
		return nil, nil, nil
	end

	return attacker, tag.MatchId, tag.Timestamp
end

-- Limpia el CombatTag de una víctima tras una eliminación o reset
function CombatService:ClearCombatTag(victim: Player)
	if not victim then return end
	self._tags[victim] = nil
	self._history[victim] = nil
	self._lifeHits[victim] = nil
end

-- Limpia todos los CombatTags e historial de una partida
function CombatService:ClearMatch(matchId: string)
	for player,hits in pairs(self._lifeHits) do if hits.SessionId==matchId then self._lifeHits[player]=nil end end
	if not matchId then return end
	for victim, tag in pairs(self._tags) do
		if tag.MatchId == matchId then
			self._tags[victim] = nil
			self._history[victim] = nil
		end
	end
end

-- Retorna el historial de impactos recibidos por una víctima (para futuras asistencias)
function CombatService:GetHitHistory(victim: Player): { CombatHitHistoryItem }
	if not victim or not self._history[victim] then
		return {}
	end
	return table.clone(self._history[victim])
end

return CombatService
