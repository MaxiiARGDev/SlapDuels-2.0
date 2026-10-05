--!strict
-- PointFeedbackService
-- Responsable del ciclo de vida, posicionamiento físico y delegación al Controller correspondiente de Point Effects.
-- El cosmético (PointEffect) pertenece al ScoringPlayer, pero su origen físico es ScoringZone (RedWin/BlueWin).
-- La coreografía específica de cada efecto la gestiona su respectivo Controller (ej. BasicController).
-- No detecta puntos, no valida jugadores, no otorga monedas ni altera scores (responsabilidad de ScoreService).

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Types = require(ReplicatedStorage.Shared.Types)
local Config = require(ReplicatedStorage.Shared.Config)
local PointEffectDefinitions = require(ReplicatedStorage.Shared.PointEffectDefinitions)

type MatchSession = Types.MatchSession
type PointFeedbackPayload = Types.PointFeedbackPayload
type PointFeedbackBroadcast = Types.PointFeedbackBroadcast

local PointFeedbackService = {}
PointFeedbackService.Name = "PointFeedbackService"

PointFeedbackService._context = nil :: any
PointFeedbackService._processedPoints = {} :: { [string]: boolean } -- pointId -> boolean (evita duplicación de feedback)
PointFeedbackService._activeMatchEffects = {} :: { [string]: { any } } -- matchId -> lista de instancias temporales
PointFeedbackService._activeMatchHandles = {} :: { [string]: { any } } -- matchId -> lista de handles de controllers activos

-- Remotes requeridos
local function ensureRemoteFolder(parent: Instance, name: string): Folder
	local folder = parent:FindFirstChild(name)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = parent
	end
	return folder :: Folder
end

local function ensureRemoteEvent(parent: Instance, name: string): RemoteEvent
	local event = parent:FindFirstChild(name)
	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = parent
	end
	return event :: RemoteEvent
end

function PointFeedbackService:_ensureRemotes()
	local remotesFolder = ensureRemoteFolder(ReplicatedStorage, "Remotes")
	local matchFolder = ensureRemoteFolder(remotesFolder, "Match")
	ensureRemoteEvent(matchFolder, "PointFeedback")
end

function PointFeedbackService:_getRemote(eventName: string): RemoteEvent?
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local matchFolder = remotes and remotes:FindFirstChild("Match")
	local event = matchFolder and matchFolder:FindFirstChild(eventName)
	if event and event:IsA("RemoteEvent") then
		return event
	end
	return nil
end

function PointFeedbackService:_getPlayerService()
	if self._context and self._context.GetService then
		local s = self._context:GetService("PlayerService")
		if s then return s end
	end

	local servicesFolder = ServerScriptService:FindFirstChild("Services")
	local mod = servicesFolder and servicesFolder:FindFirstChild("PlayerService")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok then return result end
	end
	return nil
end

-- Obtiene el registro de controllers cargando BasicController si aún no se inicializó
function PointFeedbackService:_getControllerRegistry()
	local controllersFolder = ServerScriptService:FindFirstChild("PointEffectControllers")
	if not controllersFolder then
		return nil
	end

	-- Asegurar que BasicController esté cargado para su auto-registro
	local basicMod = controllersFolder:FindFirstChild("BasicController")
	if basicMod and basicMod:IsA("ModuleScript") then
		pcall(require, basicMod)
	end

	local registryMod = controllersFolder:FindFirstChild("PointEffectRegistry")
	if registryMod and registryMod:IsA("ModuleScript") then
		local ok, reg = pcall(require, registryMod)
		if ok then return reg end
	end
	return nil
end

-- Obtiene el servicio de Ragdoll para física de impacto
function PointFeedbackService:_getRagdollService()
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

function PointFeedbackService:Init(context)
	self._context = context
	self._processedPoints = {}
	self._activeMatchEffects = {}
	self._activeMatchHandles = {}

	self:_ensureRemotes()
end

function PointFeedbackService:Start(context)
	self._context = context
	-- Pre-cargar registro de controllers
	local _ = self:_getControllerRegistry()
	print("[PointFeedbackService] Servicio iniciado y listo para despachar PointEffects a Controllers")
end

-- Resuelve autoritativamente el EffectId equipado por el jugador anotador con fallback seguro a Basic
function PointFeedbackService:_resolvePlayerEffectId(scoringPlayer: Player?): string
	if not scoringPlayer then
		return PointEffectDefinitions.DefaultEffectId
	end

	local playerService = self:_getPlayerService()
	if not playerService or not playerService.GetEquippedPointEffect then
		return PointEffectDefinitions.DefaultEffectId
	end

	local equipped = playerService:GetEquippedPointEffect(scoringPlayer)
	if not equipped or not PointEffectDefinitions.IsValid(equipped) then
		return PointEffectDefinitions.DefaultEffectId
	end

	return equipped
end

-- Obtiene el template visual/sonoro desde ServerStorage.PointEffects[EffectId] (editable desde Studio)
function PointFeedbackService:_getEffectTemplate(effectId: string): Instance?
	local pointEffectsFolder = ServerStorage:FindFirstChild("PointEffects")
	if not pointEffectsFolder then
		warn("[PointFeedbackService] ServerStorage.PointEffects no existe")
		return nil
	end

	local template = pointEffectsFolder:FindFirstChild(effectId)
	if not template and effectId ~= PointEffectDefinitions.DefaultEffectId then
		warn(string.format("[PointFeedbackService] Template para '%s' no encontrado en ServerStorage.PointEffects. Usando fallback '%s'",
			tostring(effectId), PointEffectDefinitions.DefaultEffectId))
		template = pointEffectsFolder:FindFirstChild(PointEffectDefinitions.DefaultEffectId)
	end

	if not template then
		warn(string.format("[PointFeedbackService] Template de efecto '%s' no encontrado", tostring(effectId)))
		return nil
	end

	return template
end

-- Valida defensivamente que ScoringZone sea válida, pertenezca a la instancia y corresponda al equipo anotador
function PointFeedbackService:_validateScoringZone(session: MatchSession, payload: PointFeedbackPayload): boolean
	local scoringZone = payload.ScoringZone
	if not scoringZone or not scoringZone:IsA("BasePart") then
		warn(string.format("[PointFeedbackService] ScoringZone inválido o no es BasePart para Match '%s'", tostring(payload.MatchId)))
		return false
	end

	if not scoringZone:IsDescendantOf(Workspace) then
		warn(string.format("[PointFeedbackService] ScoringZone no es descendiente de Workspace para Match '%s'", tostring(payload.MatchId)))
		return false
	end

	local info = session.InstanceInfo
	if not info then
		warn(string.format("[PointFeedbackService] session.InstanceInfo ausente para Match '%s'", tostring(payload.MatchId)))
		return false
	end

	-- Validar que pertenezca a la instancia activa de la partida
	if info.InstanceModel and not scoringZone:IsDescendantOf(info.InstanceModel) then
		warn(string.format("[PointFeedbackService] ScoringZone no pertenece a InstanceModel de Match '%s'", tostring(payload.MatchId)))
		return false
	end

	-- Validar que corresponda al equipo que anotó
	if payload.ScoringTeam == "Red" and scoringZone ~= info.RedWin then
		warn("[PointFeedbackService] ScoringZone no coincide con info.RedWin para anotación de Red")
		return false
	elseif payload.ScoringTeam == "Blue" and scoringZone ~= info.BlueWin then
		warn("[PointFeedbackService] ScoringZone no coincide con info.BlueWin para anotación de Blue")
		return false
	end

	return true
end

-- Fallback defensivo si un controller no estuviera disponible para un efecto
function PointFeedbackService:_fallbackPlay(clone: Instance, scoringZone: BasePart, matchId: string)
	local rawDuration = clone:GetAttribute("Duration")
	local duration = if typeof(rawDuration) == "number" and rawDuration > 0 then rawDuration else 1.2

	for _, desc in ipairs(clone:GetDescendants()) do
		if desc:IsA("Sound") then
			desc.Looped = false
			local rawDelay = desc:GetAttribute("PlayDelay")
			local playDelay = if typeof(rawDelay) == "number" and rawDelay >= 0 then rawDelay else 0
			if playDelay > 0 then
				task.delay(playDelay, function() if desc and desc.Parent then desc:Play() end end)
			else
				desc:Play()
			end
		elseif desc:IsA("ParticleEmitter") then
			desc.Enabled = false
			desc.Rate = 0
			local rawCount = desc:GetAttribute("EmitCount")
			local emitCount = if typeof(rawCount) == "number" and rawCount > 0 then rawCount else 10
			local rawDelay = desc:GetAttribute("EmitDelay")
			local emitDelay = if typeof(rawDelay) == "number" and rawDelay >= 0 then rawDelay else 0
			if emitDelay > 0 then
				task.delay(emitDelay, function() if desc and desc.Parent then desc:Emit(emitCount) end end)
			else
				desc:Emit(emitCount)
			end
		end
	end

	task.delay(duration, function()
		if clone and clone.Parent then
			clone:Destroy()
		end
	end)
	Debris:AddItem(clone, duration + 1.0)
end

-- Punto de entrada principal invocado por ScoreService al validar un punto
function PointFeedbackService:PlayPoint(session: MatchSession, payload: PointFeedbackPayload): boolean
	if not session or not payload then
		warn("[PointFeedbackService] PlayPoint llamado con parámetros nulos")
		return false
	end

	local pointId = payload.PointId
	if not pointId or self._processedPoints[pointId] then
		-- Duplicación detectada: ignorar silenciosamente sin interrumpir el flujo
		return false
	end

	-- Marcar punto como procesado (protección contra doble feedback)
	self._processedPoints[pointId] = true

	-- Validación defensiva sin romper el juego
	local isValidZone = self:_validateScoringZone(session, payload)
	if not isValidZone then
		-- Warning registrado por _validateScoringZone; no rompe el scoring ni la partida
		return false
	end

	local matchId = payload.MatchId or session.Id

	-- 1. Resolver el PointEffect equipado por el ScoringPlayer (con fallback seguro a Basic)
	local scoringPlayer = payload.ScoringPlayer
	local effectId = self:_resolvePlayerEffectId(scoringPlayer)
	local effectDef = PointEffectDefinitions.Get(effectId) or PointEffectDefinitions.GetDefault()
	local resolvedEffectId = effectDef.Id

	local playerName = if scoringPlayer and scoringPlayer.Name then scoringPlayer.Name else "Unknown"
	print(string.format("[PointFeedbackService] Feedback activado para Match '%s' (Punto: %s, Equipo: %s, Jugador: %s, PointEffect: %s [%s], Origen: %s, Final: %s)",
		matchId,
		tostring(pointId),
		payload.ScoringTeam,
		playerName,
		resolvedEffectId,
		effectDef.DisplayName,
		payload.ScoringZone:GetFullName(),
		tostring(payload.IsFinalPoint)))

	-- 2. Notificar a clientes para Camera Shake y efectos locales controlados por servidor
	local remote = self:_getRemote("PointFeedback")
	if remote then
		local broadcastData: PointFeedbackBroadcast = {
			MatchId = matchId,
			PointId = pointId,
			ScoringTeam = payload.ScoringTeam,
			ScoringPlayerName = playerName,
			ScoringZonePosition = payload.ScoringZone.Position,
			EffectId = resolvedEffectId,
			IsFinalPoint = payload.IsFinalPoint,
			RedScore = payload.RedScore,
			BlueScore = payload.BlueScore,
		}
		remote:FireAllClients(broadcastData)
	end

	-- 3. Obtener template, clonar y posicionar en ScoringZone
	local template = self:_getEffectTemplate(resolvedEffectId)
	if not template then
		warn(string.format("[PointFeedbackService] Template no disponible para efecto '%s'", resolvedEffectId))
		return true
	end

	local clone = template:Clone()

	-- Posicionar con orientación neutral exactamente en la posición física de ScoringZone
	if clone:IsA("Model") then
		clone:PivotTo(CFrame.new(payload.ScoringZone.Position))
	elseif clone:IsA("BasePart") then
		clone.CFrame = CFrame.new(payload.ScoringZone.Position)
	end

	-- Parentar dentro de la instancia de la partida (ScoringZone)
	clone.Parent = payload.ScoringZone

	-- Registrar instancia activa para cleanup
	if not self._activeMatchEffects[matchId] then
		self._activeMatchEffects[matchId] = {}
	end
	table.insert(self._activeMatchEffects[matchId], clone)

	-- 4. Obtener Controller correspondiente desde PointEffectRegistry
	local registry = self:_getControllerRegistry()
	local controller = registry and registry.GetController(resolvedEffectId)

	if controller and typeof(controller.Play) == "function" then
		local playContext = {
			EffectModel = clone :: Model,
			ScoringZone = payload.ScoringZone,
			ScoringPlayer = payload.ScoringPlayer,
			MatchId = matchId,
			PointId = pointId,
			IsFinalPoint = payload.IsFinalPoint,
			Score = session.Score,
		}

		local ok, handle = pcall(function()
			return controller.Play(playContext)
		end)

		if ok and handle and typeof(handle) == "table" then
			if not self._activeMatchHandles[matchId] then
				self._activeMatchHandles[matchId] = {}
			end
			table.insert(self._activeMatchHandles[matchId], handle)
		elseif not ok then
			warn(string.format("[PointFeedbackService] Error al ejecutar controller para '%s': %s", resolvedEffectId, tostring(handle)))
			self:_fallbackPlay(clone, payload.ScoringZone, matchId)
		end
	else
		-- Fallback seguro si no hubiera controller registrado
		self:_fallbackPlay(clone, payload.ScoringZone, matchId)
	end

	-- 5. Física de lanzamiento en Ragdoll por la onda expansiva del punto
	local ragdollService = self:_getRagdollService()
	if ragdollService and payload.ScoringZone then
		local blastRadius = (Config.Ragdoll and Config.Ragdoll.BlastRadius) or 100
		local blastForce = (Config.Ragdoll and Config.Ragdoll.BlastForce) or 110
		local upRatio = (Config.Ragdoll and Config.Ragdoll.UpwardRatio) or 1.0
		local ragDuration = (Config.Ragdoll and Config.Ragdoll.DefaultDuration) or 5.0
		if payload.IsFinalPoint then
			blastForce *= 1.3
		end

		local scoringPlayer = payload.ScoringPlayer
		local scoringTeam = payload.ScoringTeam
		local function filterScoringPlayer(targetPlayer: Player?, _char: Model): boolean
			if scoringPlayer and targetPlayer == scoringPlayer then
				return false -- El jugador que anota el punto no es afectado por la explosión ni el ragdoll
			end
			if scoringTeam and session and session.Teams then
				local teamPlayers = session.Teams[scoringTeam]
				if typeof(teamPlayers) == "table" and targetPlayer and table.find(teamPlayers, targetPlayer) then
					return false -- Los compañeros del equipo anotador tampoco son afectados
				end
			end
			return true
		end

		ragdollService:BlastZone(payload.ScoringZone.Position, blastRadius, blastForce, upRatio, ragDuration, filterScoringPlayer)
	end
return true
end

-- Limpieza de recursos temporales de una partida
function PointFeedbackService:CleanupMatch(matchId: string)
	-- 1. Detener y destruir handles de controllers activos
	local handles = self._activeMatchHandles[matchId]
	if handles then
		for _, handle in ipairs(handles) do
			if typeof(handle) == "table" then
				if typeof(handle.Destroy) == "function" then
					pcall(function() handle:Destroy() end)
				elseif typeof(handle.Stop) == "function" then
					pcall(function() handle:Stop() end)
				end
			end
		end
		self._activeMatchHandles[matchId] = nil
	end

	-- 2. Limpieza de instancias físicas residuales
	local effects = self._activeMatchEffects[matchId]
	if effects then
		for _, item in ipairs(effects) do
			if typeof(item) == "Instance" then
				for _, desc in ipairs(item:GetDescendants()) do
					if desc:IsA("Sound") and desc.IsPlaying then
						pcall(function() desc:Stop() end)
					elseif desc:IsA("ParticleEmitter") then
						desc.Enabled = false
					end
				end
				item:Destroy()
			elseif typeof(item) == "RBXScriptConnection" then
				item:Disconnect()
			end
		end
		self._activeMatchEffects[matchId] = nil
	end

	print(string.format("[PointFeedbackService] Limpieza completada para Match '%s'", matchId))
end

return PointFeedbackService
