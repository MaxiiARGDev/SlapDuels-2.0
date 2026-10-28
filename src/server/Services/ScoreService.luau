--!strict
-- ScoreService
-- Responsabilidad exclusiva:
-- - Mantener el score de cada MatchSession.
-- - Detectar anotaciones físicas en ZoneWin (RedWin y BlueWin).
-- - Validar autoritativamente en servidor las anotaciones:
--     RED + RedWin = RED +1
--     BLUE + BlueWin = BLUE +1
--     RED + BlueWin = NO SCORE
--     BLUE + RedWin = NO SCORE
-- - Evitar dobles anotaciones mediante control granular (Match + Player + Zone).
-- - Soportar reingreso (re-entry) tras salir de la zona.
-- - Detectar Match Point ("ÚLTIMO PUNTO PARA GANAR LA PARTIDA") al alcanzar WinningScore - 1.
-- - Detectar victoria inmediata al alcanzar WinningScore (5) sin esperar al timer.
-- - Informar a RoundService del resultado.
-- NO administra mapas, spawn, matchmaking, hud ni timers directamente.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ArenaRespawnPolicy = require(ReplicatedStorage.Shared.ArenaRespawnPolicy)
local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Types = require(ReplicatedStorage.Shared.Types)

type MatchSession = Types.MatchSession
type MatchScore = Types.MatchScore
type MatchResultName = Types.MatchResultName

local ScoreService = {}
ScoreService.Name = "ScoreService"

-- Estado interno
ScoreService._context = nil :: any
ScoreService._scores = {} :: { [string]: MatchScore }
ScoreService._matchPointAnnounced = {} :: { [string]: { [string]: boolean } } -- matchId -> team -> boolean
ScoreService._playersInside = {} :: { [string]: { [string]: { [Player]: boolean } } } -- matchId -> zoneName -> player -> boolean
ScoreService._pointInProgress = {} :: { [string]: boolean } -- matchId -> boolean (bloqueo atómico durante reset de punto)
ScoreService._connections = {} :: { [string]: { RBXScriptConnection } }
ScoreService._sweepThreads = {} :: { [string]: thread }
ScoreService._spatialThreads = {} :: { [string]: thread }
ScoreService._resetThreads = {} :: { [string]: thread }

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

function ScoreService:_ensureRemotes()
	local remotesFolder = ensureRemoteFolder(ReplicatedStorage, "Remotes")
	local matchFolder = ensureRemoteFolder(remotesFolder, "Match")

	ensureRemoteEvent(matchFolder, "ScoreUpdated")
	ensureRemoteEvent(matchFolder, "LastPoint")
end

function ScoreService:_getRemote(eventName: string): RemoteEvent?
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local matchFolder = remotes and remotes:FindFirstChild("Match")
	local event = matchFolder and matchFolder:FindFirstChild(eventName)
	if event and event:IsA("RemoteEvent") then
		return event
	end
	return nil
end

function ScoreService:Init(context)
	self._context = context
	self._scores = {}
	self._matchPointAnnounced = {}
	self._playersInside = {}
	self._pointInProgress = {}
	self._connections = {}
	self._sweepThreads = {}
	self._spatialThreads = {}
	self._resetThreads = {}

	self:_ensureRemotes()
end

function ScoreService:Start(context)
	self._context = context
	print("[ScoreService] Servicio de puntuación iniciado y listo")
end

function ScoreService:IsPointInProgress(matchId: string): boolean
	return self._pointInProgress[matchId] == true
end

-- Obtiene el Player a partir de cualquier BasePart del personaje de forma robusta
local function getPlayerFromPart(part: BasePart): Player?
	if not part or not part:IsA("BasePart") then return nil end

	-- Buscar hacia arriba en la jerarquía hasta encontrar un Model con Humanoid perteneciente a un Player
	local current: Instance? = part
	while current and current ~= workspace do
		if current:IsA("Model") then
			local humanoid = current:FindFirstChildOfClass("Humanoid")
			if humanoid then
				local player = Players:GetPlayerFromCharacter(current)
				if player then
					return player
				end
			end
		end
		current = current.Parent
	end
	return nil
end

function ScoreService:_getPlayerFromPart(part: BasePart): any?
	if self._customPlayerResolver then
		local p = self._customPlayerResolver(part)
		if p then return p end
	end
	return getPlayerFromPart(part)
end

function ScoreService:_getRoundService()
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

function ScoreService:_getEliminationService(): any
 return self._context and self._context:GetService("EliminationService")
end

function ScoreService:_getPlayerService()
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

function ScoreService:_getSpawnService()
	if self._context and self._context.GetService then
		local s = self._context:GetService("SpawnService")
		if s then return s end
	end

	local servicesFolder = ServerScriptService:FindFirstChild("Services")
	local mod = servicesFolder and servicesFolder:FindFirstChild("SpawnService")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok then return result end
	end
	return nil
end

function ScoreService:_getPointFeedbackService()
	if self._context and self._context.GetService then
		local s = self._context:GetService("PointFeedbackService")
		if s then return s end
	end

	local servicesFolder = ServerScriptService:FindFirstChild("Services")
	local mod = servicesFolder and servicesFolder:FindFirstChild("PointFeedbackService")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok then return result end
	end
	return nil
end

-- Valida que el mapa físico instanciado contenga el contrato ZoneWin completo
function ScoreService:ValidateZoneWin(session: MatchSession): boolean
	if not session or not session.InstanceInfo then
		warn("[ScoreService] MatchSession o InstanceInfo no disponibles para validación")
		return false
	end

	local info = session.InstanceInfo
	local zoneWin = info.ZoneWin
	local redWin = info.RedWin
	local blueWin = info.BlueWin

	if not zoneWin or not zoneWin:IsDescendantOf(workspace) then
		warn(string.format("[ScoreService] Missing ZoneWin in match '%s'", session.Id))
		return false
	end

	if not redWin or not redWin:IsA("BasePart") or not redWin:IsDescendantOf(workspace) then
		warn(string.format("[ScoreService] Missing ZoneWin.RedWin in match '%s'", session.Id))
		return false
	end

	if not blueWin or not blueWin:IsA("BasePart") or not blueWin:IsDescendantOf(workspace) then
		warn(string.format("[ScoreService] Missing ZoneWin.BlueWin in match '%s'", session.Id))
		return false
	end

	return true
end

-- Determina el equipo de un jugador dentro de la sesión (soporta 1v1 y colecciones futuras)
function ScoreService:GetPlayerTeam(session: MatchSession, player: Player): ("Red" | "Blue")?
	if not session or not player then return nil end
	local roundService = self:_getRoundService()
	if not roundService or type(roundService.GetSessionParticipant) ~= "function" then return nil end
	local participant = roundService:GetSessionParticipant(session.Id, player)
	return if participant then participant.Team else nil
end

-- Valida las reglas estrictas de anotación:
-- RED + RedWin -> Válido (anota Red)
-- BLUE + BlueWin -> Válido (anota Blue)
-- RED + BlueWin -> Inválido
-- BLUE + RedWin -> Inválido
function ScoreService:_validateScorer(session: MatchSession, zoneName: string, player: Player): (boolean, ("Red" | "Blue")?)
	local character = player.Character
	if not character or not character.Parent then return false,nil end
	local humanoid=character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health<=0 then return false,nil end
	if typeof(character) == "Instance" and character:GetAttribute("ArenaRespawnPending") then return false, nil end
	local roundService = self:_getRoundService()
	if not roundService or type(roundService.IsSessionActive) ~= "function"
		or not roundService:IsSessionActive(session.Id) then
		return false, nil
	end
	local currentState = roundService:GetSessionState(session.Id)
	if not roundService:IsGameplayRoundOpen(session) then return false,nil end

	-- 1. Verificar que el match esté en Playing
	if currentState ~= Constants.RoundState.Playing then
		return false, nil
	end

	-- 2. Verificar pertenencia de equipo
	local playerTeam = self:GetPlayerTeam(session, player)
	if not playerTeam then
		-- El jugador no pertenece a esta partida
		return false, nil
	end

	-- 3. Comparar equipo con la zona física
	if playerTeam == "Red" and zoneName == "RedWin" then
		return true, "Red"
	elseif playerTeam == "Blue" and zoneName == "BlueWin" then
		return true, "Blue"
	end

	-- Cualquier otra combinación (ej. Red en BlueWin o Blue en RedWin) no anota
	return false, nil
end

-- Inicia el seguimiento de score y eventos de detección física para una sesión
function ScoreService:StartScoring(session: MatchSession)
	if not session or not session.InstanceInfo then
		warn("[ScoreService] No se puede iniciar scoring: sesión o mapa físico inválido")
		return
	end

	local matchId = session.Id
	local roundService = self:_getRoundService()
	if not roundService or type(roundService.IsSessionActive) ~= "function"
		or not roundService:IsSessionActive(matchId)
		or roundService:GetSessionById(matchId) ~= session then
		warn(string.format("[ScoreService] No se puede iniciar scoring: sesión '%s' no vigente", matchId))
		return
	end
	self:StopScoring(matchId)

	-- Inicializar score
	local score: MatchScore = {
		Red = 0,
		Blue = 0,
	}
	self._scores[matchId] = score
	session.Score = score
	self._matchPointAnnounced[matchId] = {
		Red = false,
		Blue = false,
	}
	self._playersInside[matchId] = {
		RedWin = {},
		BlueWin = {},
	}
	self._pointInProgress[matchId] = false
	self._connections[matchId] = {}

	local info = session.InstanceInfo
	local redWin = info.RedWin
	local blueWin = info.BlueWin

	if not redWin or not blueWin then
		warn(string.format("[ScoreService] RedWin o BlueWin ausentes para match '%s'", matchId))
		return
	end

	-- Suscribir eventos de detección para RedWin
	self:_setupZoneEvents(session, "RedWin", redWin)

	-- Suscribir eventos de detección para BlueWin
	self:_setupZoneEvents(session, "BlueWin", blueWin)

	-- Hilo de verificación periódica para limpiar estados si el personaje sale sin disparar TouchEnded
	self._sweepThreads[matchId] = task.spawn(function()
		while self._scores[matchId] ~= nil do
			task.wait(0.25)
			if not roundService:IsSessionActive(matchId)
				or roundService:GetSessionById(matchId) ~= session then break end
			self:_sweepExits(session, redWin, blueWin)
		end
	end)

	-- Hilo de detección espacial continua y robusta (segunda capa para garantizar scoring sin pérdidas por tunneling)
	self._spatialThreads[matchId] = task.spawn(function()
		while self._scores[matchId] ~= nil do
			task.wait(0.05)
			if not roundService:IsSessionActive(matchId)
				or roundService:GetSessionById(matchId) ~= session then break end
			self:_checkSpatialScoring(session)
		end
	end)

	-- Emitir score inicial a los clientes
	self:_broadcastScore(matchId, score, nil, nil)

	print(string.format("[ScoreService] Scoring iniciado para Match '%s' (0 - 0)", matchId))
end

function ScoreService:_setupZoneEvents(session: MatchSession, zoneName: string, zonePart: BasePart)
	local matchId = session.Id
	local connections = self._connections[matchId]
	if not connections then return end

	local touchConn = zonePart.Touched:Connect(function(hitPart: BasePart)
		self:_onZoneTouched(session, zoneName, hitPart)
	end)
	table.insert(connections, touchConn)

	local touchEndConn = zonePart.TouchEnded:Connect(function(hitPart: BasePart)
		self:_onZoneTouchEnded(session, zoneName, zonePart, hitPart)
	end)
	table.insert(connections, touchEndConn)
end

function ScoreService:_onZoneTouched(session: MatchSession, zoneName: string, hitPart: BasePart)
	local matchId = session.Id
	local player = self:_getPlayerFromPart(hitPart)

	-- Logs de diagnóstico requeridos para validación en Studio
	if player then
		local roundService = self:_getRoundService()
		local currentState = if roundService and type(roundService.GetSessionState) == "function"
			then roundService:GetSessionState(matchId)
			else nil
		local team = self:GetPlayerTeam(session, player)
		print(string.format("[ScoreService] Zone touched: %s", zoneName))
		print(string.format("[ScoreService] Touching instance: %s (%s)", hitPart:GetFullName(), hitPart.ClassName))
		print(string.format("[ScoreService] Resolved player: %s", player.Name))
		print(string.format("[ScoreService] Player team: %s", tostring(team)))
		print(string.format("[ScoreService] Match: %s", matchId))
		print(string.format("[ScoreService] Match state: %s", tostring(currentState)))
	end

	self:_handleZoneScoring(session, zoneName, player, hitPart)
end

-- Manejador centralizado y atómico de anotación (llamado por Touched o por detección espacial)
function ScoreService:_handleZoneScoring(session: MatchSession, zoneName: string, player: Player?, hitPart: BasePart?)
	if not player then return end
	local matchId = session.Id

	-- 1. Operación atómica: Si la ronda de punto actual está bloqueada por reset o victoria, ignorar inmediatamente
	if self._pointInProgress[matchId] then
		return
	end

	local matchZones = self._playersInside[matchId]
	if not matchZones then return end
	local insideZone = matchZones[zoneName]
	if not insideZone then return end

	-- Si el jugador ya fue registrado dentro de esta zona en esta ronda, no volver a sumar (STAY -> NO SCORE)
	if insideZone[player] then
		return
	end

	-- 2. Validar pertenencia de equipo, estado Playing y zona correspondiente
	local isValid, team = self:_validateScorer(session, zoneName, player)
	if not isValid or not team then
		return
	end

	local score = self._scores[matchId]
 if not score then return end
 local character=player.Character
 if not character then return end
 local zone=if team=="Red" then session.InstanceInfo and session.InstanceInfo.RedWin else session.InstanceInfo and session.InstanceInfo.BlueWin
 if hitPart and (not hitPart:IsDescendantOf(character) or not zone
  or not ArenaRespawnPolicy.IsContactCurrent(zone.CFrame,zone.Size,hitPart.Position,hitPart.Size)) then return end
 local pointId=string.format("%s_%s_%d_%d",matchId,team,score.Red+(if team=="Red" then 1 else 0),score.Blue+(if team=="Blue" then 1 else 0))
 local elimination=self:_getEliminationService()
 -- Fail closed if the central owner is absent; never commit an unprotected goal.
 if not elimination or not elimination:TryProtectGoal(session,player,character,pointId) then return end
 if not self:_getRoundService():TryResolveGameplayRound(session,"Goal") then return end

	self:_commitPoint(session,team,player,pointId)
end

-- Called only after EliminationService reserved this round's valid sudden-death fall.
function ScoreService:AwardSuddenDeathGoal(session: MatchSession,victim: Player,roundId: string): boolean
 local round=session.GameplayRound
 if not round or round.Id~=roundId or round.Resolved~="SuddenDeathFall" or self._pointInProgress[session.Id] then return false end
 local victimTeam=self:GetPlayerTeam(session,victim)
 if not victimTeam or not self._scores[session.Id] then return false end
 local team=if victimTeam=="Red" then "Blue" else "Red"
 self:_commitPoint(session,team,nil,round.Id..":FallGoal")
 return true
end

function ScoreService:_commitPoint(session: MatchSession,team: "Red"|"Blue",player: Player?,pointId: string)
 local matchId=session.Id
	-- 3. ATÓMICO: Bloquear scoring inmediatamente para prevenir dobles eventos por Touched repetido o múltiples partes
	self._pointInProgress[matchId] = true

	-- Marcar al jugador como dentro de la zona
	if player then self._playersInside[matchId][team=="Red" and "RedWin" or "BlueWin"][player]=true end

	print(string.format("[ScoreService] Valid scoring entry"))

	-- Incrementar score autoritativo
	local score=self._scores[matchId]
	if not score then return end
	score[team] += 1
	session.Score = score

	-- Registrar atómicamente el estado del PointScorer en la sesión para RoundService y EliminationService
	session.PointInProgress = true
	session.PointScorer = player
	session.PointScorerTeam = team
	session.PointScoreTimestamp = os.clock()
	session.PointNumber = score.Red + score.Blue
		local performanceOwner = self:_getRoundService()
		if player and performanceOwner and performanceOwner.RecordMatchPerformance then
			performanceOwner:RecordMatchPerformance(matchId, string.format("Goal_%d_%d", score.Red, score.Blue), player, nil, nil)
		end

	print(string.format("[ScoreService] PointScorer registrado: '%s' (Equipo %s, Punto %d, Match %s)",
		(if player then player.Name else "SuddenDeathTeamGoal"), team, session.PointNumber, matchId))

	print(string.format("[ScoreService] %s score incremented", team))

	-- 4. Recompensa personal configurada; el gol colectivo no inventa un receptor.
	local rewardAmount = if player then Config.Match.PointReward else 0
	local playerService = self:_getPlayerService()
	if player and playerService and playerService.AddCoins then
		playerService:AddCoins(player, rewardAmount, "MatchPoint", "Goal:" .. pointId)
	end

	print(string.format("[ScoreService] ¡ANOTACIÓN! %s anotó para %s (+%d Coins). Nuevo Score: Red=%d, Blue=%d",
		(if player then player.Name else "SuddenDeathTeamGoal"), team, rewardAmount, score.Red, score.Blue))

	-- 5. Emitir actualización a los clientes
	self:_broadcastScore(matchId, score, team, if player then player.Name else nil)

	-- 6. Disparar presentación audiovisual a través de PointFeedbackService
	local winningScore = (Config.Match and Config.Match.WinningScore) or 5
	local isFinalPoint = (score[team] >= winningScore)
	local scoringZone = if team == "Red"
		then (session.InstanceInfo and session.InstanceInfo.RedWin)
		else (session.InstanceInfo and session.InstanceInfo.BlueWin)
		-- Pass presentation data to the existing terminal owner; never replay scoring.
		if isFinalPoint then
			local roundService = self:_getRoundService()
			if roundService then roundService:DeclareSessionWinner(matchId, team, {
				PointId = string.format("%s_%s_%d_%d", matchId, team, score.Red, score.Blue),
				MatchId = matchId, ScoringTeam = team, ScoringPlayer = player,
				ScoringZone = scoringZone, IsFinalPoint = true, RedScore = score.Red, BlueScore = score.Blue,
			}) end
		end

	local pointFeedbackService = self:_getPointFeedbackService()
	if not session.GameplayFrozen and pointFeedbackService and pointFeedbackService.PlayPoint then
		local pointId = string.format("%s_%s_%d_%d", matchId, team, score.Red, score.Blue)
		local ok, err = pcall(function()
			pointFeedbackService:PlayPoint(session, {
				PointId = pointId,
				MatchId = matchId,
				ScoringTeam = team,
				ScoringPlayer = player,
				ScoringZone = scoringZone :: any,
				IsFinalPoint = isFinalPoint,
				RedScore = score.Red,
				BlueScore = score.Blue,
			})
		end)
		if not ok then
			warn(string.format("[ScoreService] Error no fatal al invocar PointFeedbackService: %s", tostring(err)))
		end
	end

	-- 7. Chequeo de Match Point (WinningScore - 1)
	if score[team] == winningScore - 1 then
		local announced = self._matchPointAnnounced[matchId]
		if announced and not announced[team] then
			announced[team] = true
			self:_broadcastLastPoint(matchId, team)
		end
	end

	-- 8. Chequeo de Victoria Inmediata al alcanzar WinningScore (5)
	if isFinalPoint then
		print(string.format("[ScoreService] ¡%s ALCANZÓ EL WINNING SCORE (%d)! Victoria inmediata.", team, winningScore))
		-- NO se realiza reset de posiciones al alcanzar winningScore (la partida pasa inmediatamente a Ending)
		return
	end

	-- 9. Si aún no se alcanza WinningScore, coordinar PointRestartCountdown con RoundService
	local roundService = self:_getRoundService()
	if roundService and roundService.TriggerPointRestart then
		roundService:TriggerPointRestart(session)
	else
		self:_schedulePointReset(session)
	end
end

-- Segunda capa de detección: Consulta espacial continua para evitar pérdidas por tunneling/velocidad en Touched
function ScoreService:_checkSpatialScoring(session: MatchSession)
	local matchId = session.Id
	if self._pointInProgress[matchId] then return end
	if not session.InstanceInfo then return end

	local redWin = session.InstanceInfo.RedWin
	local blueWin = session.InstanceInfo.BlueWin
	if not redWin or not blueWin then return end

	local roundService = self:_getRoundService()
	if not roundService or type(roundService.IsSessionActive) ~= "function"
		or not roundService:IsSessionActive(matchId) then return end
	local currentState = roundService:GetSessionState(matchId)
	if currentState ~= Constants.RoundState.Playing then return end

	local redPlayers: { Player } = {}
	local bluePlayers: { Player } = {}
	for _, participant in ipairs(session.Participants) do
		if roundService:GetSessionParticipant(matchId, participant.Player) == participant then
			if participant.Team == "Red" then
				table.insert(redPlayers, participant.Player)
			else
				table.insert(bluePlayers, participant.Player)
			end
		end
	end

	-- Verificar Red en RedWin
	for _, player in ipairs(redPlayers) do
		local char = player.Character
		if char and char.Parent and char:FindFirstChildOfClass("Humanoid") then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				local overlapParams = OverlapParams.new()
				overlapParams.FilterType = Enum.RaycastFilterType.Include
				overlapParams.FilterDescendantsInstances = { char }
				local parts = workspace:GetPartsInPart(redWin, overlapParams)
				if #parts > 0 then
					self:_handleZoneScoring(session, "RedWin", player, parts[1])
					return
				end
			end
		end
	end

	-- Verificar Blue en BlueWin
	for _, player in ipairs(bluePlayers) do
		local char = player.Character
		if char and char.Parent and char:FindFirstChildOfClass("Humanoid") then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				local overlapParams = OverlapParams.new()
				overlapParams.FilterType = Enum.RaycastFilterType.Include
				overlapParams.FilterDescendantsInstances = { char }
				local parts = workspace:GetPartsInPart(blueWin, overlapParams)
				if #parts > 0 then
					self:_handleZoneScoring(session, "BlueWin", player, parts[1])
					return
				end
			end
		end
	end
end

function ScoreService:_schedulePointReset(session: MatchSession)
	local matchId = session.Id

	-- Cancelar cualquier hilo previo si existiera
	local prevThread = self._resetThreads[matchId]
	if prevThread then
		pcall(task.cancel, prevThread)
	end

	self._resetThreads[matchId] = task.spawn(function()
		local delayTime = (Config.Match and Config.Match.PointResetDelay) or 1.5
		task.wait(delayTime)

		-- Validar que la partida siga activa y en estado Playing
		if not self._scores[matchId] then return end
		local roundService = self:_getRoundService()
		if not roundService or type(roundService.IsSessionActive) ~= "function"
			or not roundService:IsSessionActive(matchId)
			or roundService:GetSessionById(matchId) ~= session
			or roundService:GetSessionState(matchId) ~= Constants.RoundState.Playing then return end

		-- Reposicionar ambos equipos en sus spawns respectivos de la arena activa
		local spawnService = self:_getSpawnService()
		if not spawnService then return end
		local result=spawnService:SpawnMatchPlayers(session)
		if not result.Success then return end

		-- Limpiar registro de presencia en zonas para la nueva ronda de punto
		self._playersInside[matchId] = {
			RedWin = {},
			BlueWin = {},
		}

		-- Breve margen de estabilización física antes de reabrir scoring
		task.wait(0.2)
		if not self._scores[matchId]
			or not roundService:IsSessionActive(matchId)
			or roundService:GetSessionById(matchId) ~= session
			or roundService:GetSessionState(matchId) ~= Constants.RoundState.Playing then return end

		self:ResumeScoring(matchId)
		roundService:BeginGameplayRound(session)
		self._resetThreads[matchId] = nil
		print(string.format("[ScoreService] Nueva ronda de punto iniciada para Match '%s'. Score acumulado: Red=%d, Blue=%d",
			matchId, session.Score.Red, session.Score.Blue))
	end)
end

function ScoreService:_onZoneTouchEnded(session: MatchSession, zoneName: string, zonePart: BasePart, hitPart: BasePart)
	local matchId = session.Id
	local player = self:_getPlayerFromPart(hitPart)
	if not player then return end

	local matchZones = self._playersInside[matchId]
	if not matchZones then return end
	local insideZone = matchZones[zoneName]
	if not insideZone or not insideZone[player] then return end

	-- Verificar si el personaje realmente salió por completo de la zona
	local character = player.Character
	if not character or not character.Parent then
		insideZone[player] = nil
		return
	end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = { character }

	local touchingParts = workspace:GetPartsInPart(zonePart, overlapParams)
	if #touchingParts == 0 then
		insideZone[player] = nil
	end
end

-- Limpieza periódica para detectar salidas de personajes que no dispararon TouchEnded
function ScoreService:_sweepExits(session: MatchSession, redWin: BasePart, blueWin: BasePart)
	local matchId = session.Id
	local matchZones = self._playersInside[matchId]
	if not matchZones then return end

	local checkZone = function(zoneName: string, zonePart: BasePart)
		local insideZone = matchZones[zoneName]
		if not insideZone then return end

		for player, isInside in pairs(insideZone) do
			if isInside then
				local character = player.Character
				if not character or not character.Parent or not player:IsDescendantOf(Players) then
					insideZone[player] = nil
				else
					local overlapParams = OverlapParams.new()
					overlapParams.FilterType = Enum.RaycastFilterType.Include
					overlapParams.FilterDescendantsInstances = { character }
					local touching = workspace:GetPartsInPart(zonePart, overlapParams)
					if #touching == 0 then
						insideZone[player] = nil
					end
				end
			end
		end
	end

	if redWin and redWin:IsDescendantOf(workspace) then
		checkZone("RedWin", redWin)
	end
	if blueWin and blueWin:IsDescendantOf(workspace) then
		checkZone("BlueWin", blueWin)
	end
end

function ScoreService:_broadcastScore(matchId: string, score: MatchScore, scoringTeam: string?, scoringPlayer: string?)
	local roundService = self:_getRoundService()
	if roundService and type(roundService.FireSessionRemote) == "function" then
		roundService:FireSessionRemote(matchId, "Match", "ScoreUpdated", {
			SessionId = matchId,
			MatchId = matchId,
			StateVersion = roundService:GetSessionById(matchId) and roundService:GetSessionById(matchId).StateVersion or nil,
			Red = score.Red,
			Blue = score.Blue,
			ScoringTeam = scoringTeam,
			ScoringPlayer = scoringPlayer,
		})
	end
end

function ScoreService:_broadcastLastPoint(matchId: string, team: string)
	local roundService = self:_getRoundService()
	if roundService and type(roundService.FireSessionRemote) == "function" then
		roundService:FireSessionRemote(matchId, "Match", "LastPoint", {
			SessionId = matchId,
			MatchId = matchId,
			StateVersion = roundService:GetSessionById(matchId) and roundService:GetSessionById(matchId).StateVersion or nil,
			Team = team,
			Message = "ÚLTIMO PUNTO PARA GANAR LA PARTIDA",
		})
	end
	print(string.format("[ScoreService] Match Point emitido para equipo '%s'", team))
end

-- Determina el ganador al finalizar el timer
function ScoreService:GetWinner(session: MatchSession): MatchResultName
	local matchId = session.Id
	local score = self._scores[matchId] or session.Score
	if not score then
		return Constants.MatchResult.Draw
	end

	if score.Red > score.Blue then
		return Constants.MatchResult.Red
	elseif score.Blue > score.Red then
		return Constants.MatchResult.Blue
	else
		return Constants.MatchResult.Draw
	end
end

function ScoreService:GetScore(matchId: string): MatchScore?
	return self._scores[matchId]
end

-- Limpia el registro de presencia de jugadores en zonas para una nueva ronda de punto
function ScoreService:ResetZonePresences(matchId: string)
	self._playersInside[matchId] = {
		RedWin = {},
		BlueWin = {},
	}
end

-- Reanuda el scoring autoritativo al finalizar el countdown y limpia el estado de punto
function ScoreService:ResumeScoring(matchId: string)
	local elimination=self:_getEliminationService()
	if elimination then elimination:ReleaseGoalProtections(matchId) end
	self._pointInProgress[matchId] = false
	self:ClearPointState(matchId)
end

-- Limpia de forma explícita el estado temporal de PointScorer asociado a la sesión del match
function ScoreService:ClearPointState(matchId: string)
	self._pointInProgress[matchId] = false
	local roundService = self:_getRoundService()
	local session = nil
	if roundService and type(roundService.GetSessionById) == "function" then
		session = roundService:GetSessionById(matchId)
	end
	if session then
		session.PointInProgress = false
		session.PointScorer = nil
		session.PointScorerTeam = nil
		session.PointScoreTimestamp = nil
		session.PointNumber = nil
	end
end

-- Pausa temporal de scoring durante secuencias o pausas
function ScoreService:PauseScoring(matchId: string)
	self._pointInProgress[matchId] = true
end

-- Detiene el scoring y desconecta eventos físicos
function ScoreService:StopScoring(matchId: string)
	self:ClearPointState(matchId)
	local conns = self._connections[matchId]
	if conns then
		for _, conn in ipairs(conns) do
			conn:Disconnect()
		end
		self._connections[matchId] = nil
	end

	local thread = self._sweepThreads[matchId]
	if thread then
		pcall(task.cancel, thread)
		self._sweepThreads[matchId] = nil
	end

	local spatialThread = self._spatialThreads[matchId]
	if spatialThread then
		pcall(task.cancel, spatialThread)
		self._spatialThreads[matchId] = nil
	end

	local resetThread = self._resetThreads[matchId]
	if resetThread then
		pcall(task.cancel, resetThread)
		self._resetThreads[matchId] = nil
	end

	self._playersInside[matchId] = nil
	self._pointInProgress[matchId] = nil
end

-- Limpieza total de recursos de una partida
function ScoreService:CleanupSession(matchId: string)
	self:StopScoring(matchId)
	self._scores[matchId] = nil
	self._matchPointAnnounced[matchId] = nil
	self._pointInProgress[matchId] = nil

	local pointFeedbackService = self:_getPointFeedbackService()
	if pointFeedbackService and pointFeedbackService.CleanupMatch then
		pointFeedbackService:CleanupMatch(matchId)
	end

	print(string.format("[ScoreService] Limpieza completada para Match '%s'", matchId))
end

return ScoreService
