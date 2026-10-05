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
CombatService._history = {} :: { [Player]: { CombatHitHistoryItem } }
CombatService._roundService = nil :: any

function CombatService:Init(context: any)
	self._context = context
	self._tags = {}
	self._history = {}
end

function CombatService:Start(context: any)
	self._context = context
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

-- Registra un impacto de combate válido entre dos jugadores
function CombatService:RegisterHit(attacker: Player, victim: Player, overrideMatchId: string?): (boolean, string?)
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

	-- 4. Resolver y validar MatchId
	local matchId = overrideMatchId
	local session: MatchSession? = nil

	if matchId then
		local roundService = self:_getRoundService()
		if roundService and type(roundService.GetSessionById) == "function" then
			session = roundService:GetSessionById(matchId)
		end
	else
		session = self:_resolveSession(victim)
		if session then
			matchId = session.Id
		end
	end

	if not matchId or not session then
		return false, "NotInMatch"
	end

	-- 5. Validar que la partida no esté cancelada y esté en estado Playing
	local currentState = session.State
	if currentState ~= Constants.RoundState.Playing then
		return false, "MatchNotPlaying"
	end

	-- 6. Validar que AMBOS pertenezcan al mismo MatchId
	local attackerSession = self:_resolveSession(attacker)
	if not attackerSession or attackerSession.Id ~= matchId then
		return false, "DifferentMatch"
	end

	-- 7. Registrar o actualizar CombatTag autoritativo
	local timestamp = os.clock()
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

	return true, nil
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
end

-- Limpia todos los CombatTags e historial de una partida
function CombatService:ClearMatch(matchId: string)
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
