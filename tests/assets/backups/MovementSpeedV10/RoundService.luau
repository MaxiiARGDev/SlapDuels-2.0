--!strict
-- RoundService
-- Maquina de estados del flujo de partida 1v1.
-- Controla el ciclo completo: Waiting -> MatchReady -> MatchCountdown -> MapSelection -> MapLoading -> Playing -> Ending -> ReturningToLobby -> Waiting.
-- NO implementa logica fisica de spawn ni mapas (delegado a SpawnService en fases posteriores).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local RoundClock = require(script.Parent.Gameplay.RoundClock)
local Types = require(ReplicatedStorage.Shared.Types)
local CinematicConfig = require(ReplicatedStorage.Shared.EndCinematicConfig)
local CinematicRanking = require(ReplicatedStorage.Shared.EndCinematicRanking)

type RoundStateName = Types.RoundStateName
type MatchSession = Types.MatchSession
type MatchResultName = Types.MatchResultName
type SessionId = Types.SessionId
type SessionParticipant = Types.SessionParticipant

local RoundService = {}
RoundService.Name = "RoundService"

-- Evento / señal para que servicios externos (ej. SpawnService) se suscriban al retorno al lobby
local returnLobbyBindable = Instance.new("BindableEvent")
RoundService.ReturnPlayersToLobby = returnLobbyBindable.Event

-- Estado interno
RoundService._context = nil :: any
-- Adaptadores temporales para consumidores 1v1. El estado autoritativo vive en MatchSession.
RoundService._state = Constants.RoundState.Waiting :: RoundStateName
RoundService._currentSession = nil :: MatchSession?
RoundService._sessionsById = {} :: { [SessionId]: MatchSession }
RoundService._sessionIdByUserId = {} :: { [number]: SessionId }
RoundService._participantByPlayer = {} :: { [Player]: SessionParticipant }
RoundService._closedSessionIds = {} :: { [SessionId]: boolean }
RoundService._maxConcurrentSessions = 1
RoundService._connections = {} :: { RBXScriptConnection }

-- Utilidad para garantizar existencia de Remotes
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

local function runCleanupStep(label: string, callback: () -> ())
	local ok, err = pcall(callback)
	if not ok then
		warn(string.format("[RoundService] Falló limpieza '%s': %s", label, tostring(err)))
	end
end

function RoundService:_ensureRemotes()
	local remotesFolder = ensureRemoteFolder(ReplicatedStorage, "Remotes")
	local matchFolder = ensureRemoteFolder(remotesFolder, "Match")
	local matchmakingFolder = ensureRemoteFolder(remotesFolder, "Matchmaking")

	ensureRemoteEvent(matchFolder, "StateChanged")
	ensureRemoteEvent(matchFolder, "Countdown")
	ensureRemoteEvent(matchFolder, "MapSelection")
	ensureRemoteEvent(matchFolder, "MatchResult")
	ensureRemoteEvent(matchFolder, "EndCinematic")
	ensureRemoteEvent(matchFolder, "EndCinematicAction")
	ensureRemoteEvent(matchmakingFolder, "QueueStatus")
end

function RoundService:_getRemote(folderName: string, eventName: string): RemoteEvent?
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotes then return nil end
	local folder = remotes:FindFirstChild(folderName)
	if not folder then return nil end
	local event = folder:FindFirstChild(eventName)
	if event and event:IsA("RemoteEvent") then
		return event
	end
	return nil
end

function RoundService:Init(context)
	self._context = context
	self._state = Constants.RoundState.Waiting
	self._currentSession = nil
	self._sessionsById = {}
	self._sessionIdByUserId = {}
	self._participantByPlayer = {}
	self._maxConcurrentSessions = 1
	self._connections = {}
	self._rewardedMatches = {}

	-- Validar existencia de Workspace.Lobby.SpawnLocation
	local lobby = workspace:FindFirstChild("Lobby")
	local spawnLocation = lobby and lobby:FindFirstChild("SpawnLocation")
	if not spawnLocation then
		warn("[RoundService] Lobby SpawnLocation not found")
	end

	-- Garantizar Remotes requeridos
	self:_ensureRemotes()

	-- Manejar votos de mapa desde clientes
	local mapSelectionRemote = self:_getRemote("Match", "MapSelection")
	if mapSelectionRemote then
		table.insert(self._connections, mapSelectionRemote.OnServerEvent:Connect(function(player: Player, mapName: string, sessionId: SessionId?)
			self:SubmitMapVote(player, mapName, sessionId)
		end))
	end

	-- Manejar desconexiones de jugadores durante la partida
	local cinematicAction = self:_getRemote("Match", "EndCinematicAction")
	if cinematicAction then
		table.insert(self._connections, cinematicAction.OnServerEvent:Connect(function(player, action, sessionId, version, token)
			self:HandleCinematicAction(player, action, sessionId, version, token)
		end))
	end

	table.insert(self._connections, Players.PlayerRemoving:Connect(function(player: Player)
		self:_handlePlayerLeaving(player)
	end))
end

function RoundService:Start(context)
	self._context = context
	print("[RoundService] Servicio iniciado. Estado: Waiting")
end

function RoundService:_getMatchInstanceService()
	if self._context and self._context.GetService then
		local s = self._context:GetService("MatchInstanceService")
		if s then return s end
	end

	local servicesFolder = game:GetService("ServerScriptService"):FindFirstChild("Services")
	local mod = servicesFolder and servicesFolder:FindFirstChild("MatchInstanceService")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok then return result end
	end
	return nil
end

function RoundService:_getSpawnService()
	if self._context and self._context.GetService then
		local s = self._context:GetService("SpawnService")
		if s then return s end
	end

	local servicesFolder = game:GetService("ServerScriptService"):FindFirstChild("Services")
	local mod = servicesFolder and servicesFolder:FindFirstChild("SpawnService")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok then return result end
	end
	return nil
end

function RoundService:_getScoreService()
	if self._context and self._context.GetService then
		local s = self._context:GetService("ScoreService")
		if s then return s end
	end

	local servicesFolder = game:GetService("ServerScriptService"):FindFirstChild("Services")
	local mod = servicesFolder and servicesFolder:FindFirstChild("ScoreService")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok then return result end
	end
	return nil
end

function RoundService:_getPlayerService()
	if self._context and self._context.GetService then
		local s = self._context:GetService("PlayerService")
		if s then return s end
	end

	local servicesFolder = game:GetService("ServerScriptService"):FindFirstChild("Services")
	local mod = servicesFolder and servicesFolder:FindFirstChild("PlayerService")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok then return result end
	end
	return nil
end

function RoundService:_getCombatService()
	if self._context and self._context.GetService then
		local s = self._context:GetService("CombatService")
		if s then return s end
	end

	local servicesFolder = game:GetService("ServerScriptService"):FindFirstChild("Services")
	local mod = servicesFolder and servicesFolder:FindFirstChild("CombatService")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok then return result end
	end
	return nil
end

function RoundService:_getEliminationService()
	if self._context and self._context.GetService then
		local s = self._context:GetService("EliminationService")
		if s then return s end
	end

	local servicesFolder = game:GetService("ServerScriptService"):FindFirstChild("Services")
	local mod = servicesFolder and servicesFolder:FindFirstChild("EliminationService")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok then return result end
	end
	return nil
end

function RoundService:_getSlapService()
	if self._context and self._context.GetService then
		local s = self._context:GetService("SlapService")
		if s then return s end
	end

	local servicesFolder = game:GetService("ServerScriptService"):FindFirstChild("Services")
	local mod = servicesFolder and servicesFolder:FindFirstChild("SlapService")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok then return result end
	end
	return nil
end

function RoundService:_getMatchmakingService()
	if self._context and self._context.GetService then
		local s = self._context:GetService("MatchmakingService")
		if s then return s end
	end

	local servicesFolder = game:GetService("ServerScriptService"):FindFirstChild("Services")
	local mod = servicesFolder and servicesFolder:FindFirstChild("MatchmakingService")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok then return result end
	end
	return nil
end

local function countSessions(sessionsById: { [SessionId]: MatchSession }): number
	local count = 0
	for _ in pairs(sessionsById) do
		count += 1
	end
	return count
end

local VALID_TRANSITIONS: { [RoundStateName]: { [RoundStateName]: boolean } } = {
	[Constants.RoundState.Waiting] = {
		[Constants.RoundState.MatchReady] = true,
		[Constants.RoundState.ReturningToLobby] = true,
	},
	[Constants.RoundState.MatchReady] = {
		[Constants.RoundState.MatchCountdown] = true,
		[Constants.RoundState.ReturningToLobby] = true,
	},
	[Constants.RoundState.MatchCountdown] = {
		[Constants.RoundState.MapSelection] = true,
		[Constants.RoundState.ReturningToLobby] = true,
	},
	[Constants.RoundState.MapSelection] = {
		[Constants.RoundState.MapLoading] = true,
		[Constants.RoundState.ReturningToLobby] = true,
	},
	[Constants.RoundState.MapLoading] = {
		[Constants.RoundState.StartCountdown] = true,
		[Constants.RoundState.ReturningToLobby] = true,
	},
	[Constants.RoundState.StartCountdown] = {
		[Constants.RoundState.Playing] = true,
		[Constants.RoundState.ReturningToLobby] = true,
	},
	[Constants.RoundState.Playing] = {
		[Constants.RoundState.PointRestartCountdown] = true,
		[Constants.RoundState.Ending] = true,
		[Constants.RoundState.ReturningToLobby] = true,
	},
	[Constants.RoundState.PointRestartCountdown] = {
		[Constants.RoundState.Playing] = true,
		[Constants.RoundState.Ending] = true,
		[Constants.RoundState.ReturningToLobby] = true,
	},
	[Constants.RoundState.Ending] = {
		[Constants.RoundState.ReturningToLobby] = true,
	},
	[Constants.RoundState.ReturningToLobby] = {},
}

function RoundService:GetSession(sessionId: SessionId?): MatchSession?
	if sessionId then
		return self._sessionsById[sessionId]
	end
	if countSessions(self._sessionsById) ~= 1 then
		return nil
	end
	for _, session in pairs(self._sessionsById) do
		return session
	end
	return nil
end

function RoundService:GetActiveSessions(): { MatchSession }
	local list = {}
	for _, session in pairs(self._sessionsById) do
		if self:_isRegisteredSession(session) then
			table.insert(list, session)
		end
	end
	return list
end

function RoundService:GetState(): RoundStateName
	local session = self:GetSession()
	return if session then session.State else Constants.RoundState.Waiting
end

function RoundService:GetSessionById(sessionId: SessionId): MatchSession?
	return self._sessionsById[sessionId]
end

function RoundService:GetSessionState(sessionId: SessionId): RoundStateName?
	local session = self._sessionsById[sessionId]
	return if session then session.State else nil
end

function RoundService:IsSessionActive(sessionId: SessionId): boolean
	local session = self._sessionsById[sessionId]
	return session ~= nil
		and self:_isRegisteredSession(session)
end

-- Temporary performance counters only. Called from already accepted scoring/elimination events.
function RoundService:RecordMatchPerformance(sessionId: SessionId, eventId: string, scorer: Player?, killer: Player?, victim: Player?): boolean
	local session = self._sessionsById[sessionId]
	if not session or not self:IsSessionActive(sessionId) or session.GameplayFrozen
		or (session.State ~= Constants.RoundState.Playing and session.State ~= Constants.RoundState.PointRestartCountdown) then return false end
	local updates = {}
	if scorer then table.insert(updates, { Player = scorer, Metric = "Goals" }) end
	if killer and victim then
		table.insert(updates, { Player = killer, Metric = "Kills" })
		table.insert(updates, { Player = victim, Metric = "Deaths" })
	end
	if #updates == 0 then return false end
	for _, update in ipairs(updates) do
		local participant = self:GetSessionParticipant(sessionId, update.Player)
		if not participant or not participant.MatchStats then return false end
		update.Participant = participant
	end
	session.MatchStatEvents = session.MatchStatEvents or {}
	if session.MatchStatEvents[eventId] then return false end
	session.MatchStatEvents[eventId] = true
	for _, update in ipairs(updates) do update.Participant.MatchStats[update.Metric] += 1 end
	return true
end

function RoundService:CaptureCinematicRanking(session: MatchSession): any
	local rows = {}
	for _, participant in ipairs(session.Participants) do
		local player, stats = participant.Player, participant.MatchStats
		table.insert(rows, { UserId = participant.UserId, DisplayName = player.DisplayName or player.Name,
			Username = player.Name, Team = participant.Team, CompetitiveSlot = participant.Slot,
			DescriptionKey = tostring(participant.UserId), Goals = stats and stats.Goals,
			Kills = stats and stats.Kills, Deaths = stats and stats.Deaths })
	end
	return CinematicRanking.Build(rows, session.Result, session.Mode,
		{ SessionId = session.Id, StateVersion = session.StateVersion })
end

function RoundService:GetSessionParticipant(sessionId: SessionId, player: Player): SessionParticipant?
	if not player then return nil end
	local session = self._sessionsById[sessionId]
	if not session or not self:_isRegisteredSession(session) then
		return nil
	end
	if self._sessionIdByUserId[player.UserId] ~= sessionId then
		return nil
	end
	local participant = self._participantByPlayer[player]
	if not participant or participant.UserId ~= player.UserId then
		return nil
	end
	if participant.State == "Left" or participant.State == "Released" then
		return nil
	end
	local isReal = typeof(player) == "Instance" and player:IsA("Player")
	local isSimulated = typeof(player) == "table" and (player :: any).IsSimulatedPlayer == true
	if isReal and player.Parent ~= Players then
		return nil
	end
	if isSimulated and (player :: any).IsConnected == false then
		return nil
	end
	return participant
end

function RoundService:_getSessionRecipients(session: MatchSession): { Player }
	local recipients: { Player } = {}
	for _, participant in ipairs(session.Participants) do
		local player = participant.Player
		if player.Parent == Players
			and participant.State ~= "Left"
			and participant.State ~= "Released"
			and self._sessionsById[session.Id] == session
			and self._participantByPlayer[player] == participant
			and self._sessionIdByUserId[participant.UserId] == session.Id then
			table.insert(recipients, player)
		end
	end
	return recipients
end

function RoundService:_applySessionIdentity(session: MatchSession, payload: any?): any
	local data = if type(payload) == "table" then table.clone(payload) else {}
	data.SessionId = session.Id
	data.MatchId = session.Id
	data.StateVersion = session.StateVersion
	local participantUserIds: { number } = {}
	local participantTeams: { [number]: string } = {}
	for _, participant in ipairs(session.Participants) do
		table.insert(participantUserIds, participant.UserId)
		participantTeams[participant.UserId] = participant.Team
	end
	data.ParticipantUserIds = participantUserIds
	data.ParticipantTeams = participantTeams
	return data
end

function RoundService:FireSessionRemote(sessionId: SessionId, folderName: string, eventName: string, ...: any): number
	local session = self._sessionsById[sessionId]
	if not session or session.Closed then return 0 end
	local remote = self:_getRemote(folderName, eventName)
	if not remote then return 0 end
	local sent = 0
	local args = table.pack(...)
	for _, player in ipairs(self:_getSessionRecipients(session)) do
		local ok = pcall(function()
			remote:FireClient(player, table.unpack(args, 1, args.n))
		end)
		if ok then sent += 1 end
	end
	return sent
end

function RoundService:_isRegisteredSession(session: MatchSession): boolean
	return self._sessionsById[session.Id] == session
		and not session.Closing
		and not session.Cancelled
		and not session.Closed
end

function RoundService:SetSessionState(sessionId: SessionId, newState: RoundStateName, extraData: any?, allowClosing: boolean?): boolean
	local session = self._sessionsById[sessionId]
	if not session or self._sessionsById[sessionId] ~= session or session.Closed then
		return false
	end
	if session.Closing and not allowClosing then
		return false
	end
	if session.GameplayFrozen and newState ~= Constants.RoundState.Ending and newState ~= Constants.RoundState.ReturningToLobby then
		return false
	end

	local allowed = VALID_TRANSITIONS[session.State]
	if not allowed or not allowed[newState] then
		return false
	end

	local progression = self._context and self._context:GetService("ProgressionService")
	if progression then progression:StateChanged(session, session.State, newState) end
	session.State = newState
	session.StateVersion += 1
	self._state = newState -- Adaptador temporal para consumidores 1v1 existentes.
	print(string.format("[RoundService] Estado de sesión '%s' cambiado a: %s (v%d)", sessionId, newState, session.StateVersion))

	local payload = self:_applySessionIdentity(session, extraData)
	self:FireSessionRemote(sessionId, "Match", "StateChanged", newState, payload)
	return true
end

function RoundService:GetRegisteredSessionCount(): number
	return countSessions(self._sessionsById)
end

function RoundService:GetSessionIdForUserId(userId: number): SessionId?
	return self._sessionIdByUserId[userId]
end

function RoundService:GetSessionForUserId(userId: number): MatchSession?
	local sessionId = self:GetSessionIdForUserId(userId)
	return if sessionId then self:GetSessionById(sessionId) else nil
end

function RoundService:GetParticipantForPlayer(player: Player): SessionParticipant?
	return self._participantByPlayer[player]
end

function RoundService:GetSessionForPlayer(player: Player): MatchSession?
	if not player then return nil end
	local sessionId = self._sessionIdByUserId[player.UserId]
	return if sessionId then self._sessionsById[sessionId] else nil
end

function RoundService:_unregisterParticipant(participant: SessionParticipant, sessionId: SessionId)
	local player = participant.Player
	if self._participantByPlayer[player] == participant then
		self._participantByPlayer[player] = nil
	end
	if self._sessionIdByUserId[participant.UserId] == sessionId then
		self._sessionIdByUserId[participant.UserId] = nil
	end
end

function RoundService:_releaseSession(session: MatchSession)
	session.Closing = true
	session.Votes = {}
	session.RemainingTime = nil
	for _, participant in ipairs(session.Participants) do
		self:_unregisterParticipant(participant, session.Id)
		participant.State = "Released"
	end

	if self._sessionsById[session.Id] == session then
		self._sessionsById[session.Id] = nil
	end
	if self._currentSession == session then
		self._currentSession = nil
	end
	session.Closed = true
	local progression = self._context and self._context:GetService("ProgressionService")
	if progression then progression:Forget(session.Id) end
	self._closedSessionIds[session.Id] = true
end

function RoundService:_registerSession(session: MatchSession): (boolean, string?)
	if countSessions(self._sessionsById) >= self._maxConcurrentSessions then
		return false, "ConcurrentSessionLimitReached"
	end
	if self._sessionsById[session.Id] then
		return false, "DuplicateSessionId"
	end

	local playersSeen: { [any]: boolean } = {}
	local userIdsSeen: { [number]: boolean } = {}
	for _, participant in ipairs(session.Participants) do
		local player = participant.Player
		local isReal = typeof(player) == "Instance" and player:IsA("Player")
		local isSim = typeof(player) == "table" and (player :: any).IsSimulatedPlayer == true
		if not isReal and not isSim then
			return false, "InvalidParticipant"
		end
		if isReal and (player.Parent ~= Players and not player:IsDescendantOf(Players)) then
			return false, "ParticipantDisconnected"
		end
		if isSim and (player :: any).IsConnected == false then
			return false, "ParticipantDisconnected"
		end
		if player.UserId ~= participant.UserId then
			return false, "ParticipantUserIdMismatch"
		end
		if playersSeen[player] or userIdsSeen[participant.UserId] then
			return false, "DuplicateParticipant"
		end
		if self._participantByPlayer[player] or self._sessionIdByUserId[participant.UserId] then
			return false, "ParticipantAlreadyRegistered"
		end
		playersSeen[player] = true
		userIdsSeen[participant.UserId] = true
	end

	-- Las validaciones terminan antes de la primera escritura. El rollback mantiene
	-- la admisión atómica incluso si una futura extensión añade una operación falible.
	local registered: { SessionParticipant } = {}
	local ok, err = pcall(function()
		self._sessionsById[session.Id] = session
		for _, participant in ipairs(session.Participants) do
			table.insert(registered, participant)
			self._participantByPlayer[participant.Player] = participant
			self._sessionIdByUserId[participant.UserId] = session.Id
		end
	end)
	if not ok then
		for _, participant in ipairs(registered) do
			self:_unregisterParticipant(participant, session.Id)
		end
		self._sessionsById[session.Id] = nil
		return false, string.format("AdmissionWriteFailed:%s", tostring(err))
	end

	return true, nil
end

function RoundService:IsModePlayable(mode: string): boolean
	if Config.Round and (Config.Round :: any).PlayableModes then
		return (Config.Round :: any).PlayableModes[mode] == true
	end
	return mode == "1v1"
end

-- Conserva el UserId original. Los IDs negativos existen únicamente en los
-- clientes locales de Studio; producción exige IDs estrictamente positivos.
function RoundService:_isParticipantUserIdValid(userId: any, studioOverride: boolean?): boolean
	if typeof(userId) ~= "number" or userId ~= userId or userId == math.huge or userId == -math.huge then
		return false
	end
	local isStudio = if studioOverride ~= nil then studioOverride else RunService:IsStudio()
	return if isStudio then userId ~= 0 else userId > 0
end

function RoundService:AdmitSession(
	requestOrRedPlayers: any,
	bluePlayers: { Player }?,
	mode: string?,
	zoneId: string?,
	reservationToken: string?
): (MatchSession?, string?)
	local request: Types.TeamMatchAdmissionRequest
	if type(requestOrRedPlayers) == "table" and (requestOrRedPlayers.RedTeam ~= nil or requestOrRedPlayers.Mode ~= nil) then
		request = requestOrRedPlayers
	else
		request = {
			ZoneId = zoneId or "1v1",
			Mode = mode or "1v1",
			TeamSize = (type(requestOrRedPlayers) == "table" and #requestOrRedPlayers) or 1,
			RedTeam = requestOrRedPlayers,
			BlueTeam = bluePlayers or {},
			ReservationToken = reservationToken,
		}
	end

	if type(request) ~= "table" then
		return nil, "InvalidRequest"
	end

	local reqMode = request.Mode
	if type(reqMode) ~= "string" or reqMode == "" then
		return nil, "InvalidMode"
	end

	local modeConfig = Config.Matchmaking and Config.Matchmaking.Modes and Config.Matchmaking.Modes[reqMode]
	if not modeConfig then
		return nil, "UnknownMode"
	end

	local expectedTeamSize = modeConfig.TeamSize
	local teamSize = request.TeamSize or expectedTeamSize
	if teamSize ~= expectedTeamSize or teamSize <= 0 then
		return nil, "InvalidTeamSize"
	end

	local redTeam = request.RedTeam
	local blueTeam = request.BlueTeam
	if type(redTeam) ~= "table" or type(blueTeam) ~= "table" then
		return nil, "InvalidTeams"
	end

	if #redTeam ~= teamSize or #blueTeam ~= teamSize then
		return nil, "IncompleteTeam"
	end

	local reqZoneId = request.ZoneId
	if type(reqZoneId) ~= "string" or reqZoneId == "" then
		return nil, "InvalidZoneId"
	end

	if countSessions(self._sessionsById) >= self._maxConcurrentSessions then
		return nil, "ConcurrentSessionLimitReached"
	end

 local socialPlay=self._context and self._context:GetService('SocialPlayService')
 if socialPlay then
  for _,team in ipairs({redTeam,blueTeam})do
   local complete,reason=socialPlay:CanQueueTeam(team,teamSize)
   if not complete then return nil,reason end
  end
 end

	-- Validación estricta de token de reserva si fue provisto
	if request.ReservationToken ~= nil then
		local mmService = self:_getMatchmakingService()
		if mmService and typeof(mmService.ValidateReservation) == "function" then
			local valid, err = mmService:ValidateReservation(request.ReservationToken, request)
			if not valid then
				return nil, err or "InvalidReservationToken"
			end
		end
	end

	local participants: { SessionParticipant } = {}
	local playersSeen: { [any]: boolean } = {}
	local userIdsSeen: { [number]: boolean } = {}

	for slotIndex, player in ipairs(redTeam) do
		local isReal = typeof(player) == "Instance" and player:IsA("Player")
		local isSim = typeof(player) == "table" and (player :: any).IsSimulatedPlayer == true
		if not isReal and not isSim then
			return nil, "InvalidParticipant"
		end
		if isReal and (player.Parent ~= Players and not player:IsDescendantOf(Players)) then
			return nil, "ParticipantDisconnected"
		end
		if isSim and (player :: any).IsConnected == false then
			return nil, "ParticipantDisconnected"
		end

		local userId = player.UserId
		if not self:_isParticipantUserIdValid(userId) then
			return nil, "InvalidParticipantUserId"
		end
		if playersSeen[player] or userIdsSeen[userId] then
			return nil, "DuplicateParticipant"
		end
		if self._participantByPlayer[player] or self._sessionIdByUserId[userId] then
			return nil, "ParticipantAlreadyRegistered"
		end
		playersSeen[player] = true
		userIdsSeen[userId] = true

		table.insert(participants, {
			Player = player,
			UserId = userId,
			Team = "Red",
			Slot = slotIndex,
			State = "Reserved",
		})
	end

	for slotIndex, player in ipairs(blueTeam) do
		local isReal = typeof(player) == "Instance" and player:IsA("Player")
		local isSim = typeof(player) == "table" and (player :: any).IsSimulatedPlayer == true
		if not isReal and not isSim then
			return nil, "InvalidParticipant"
		end
		if isReal and (player.Parent ~= Players and not player:IsDescendantOf(Players)) then
			return nil, "ParticipantDisconnected"
		end
		if isSim and (player :: any).IsConnected == false then
			return nil, "ParticipantDisconnected"
		end

		local userId = player.UserId
		if not self:_isParticipantUserIdValid(userId) then
			return nil, "InvalidParticipantUserId"
		end
		if playersSeen[player] or userIdsSeen[userId] then
			return nil, "DuplicateParticipant"
		end
		if self._participantByPlayer[player] or self._sessionIdByUserId[userId] then
			return nil, "ParticipantAlreadyRegistered"
		end
		playersSeen[player] = true
		userIdsSeen[userId] = true

		table.insert(participants, {
			Player = player,
			UserId = userId,
			Team = "Blue",
			Slot = slotIndex,
			State = "Reserved",
		})
	end

		for _, participant in ipairs(participants) do participant.MatchStats = { Goals = 0, Kills = 0, Deaths = 0 } end
		local sessionId: SessionId = HttpService:GenerateGUID(false)
	local session: MatchSession = {
		Id = sessionId,
		Mode = reqMode,
		TeamSize = teamSize,
		ZoneId = reqZoneId,
		ReservationToken = request.ReservationToken,
		Participants = participants,
			MatchStatEvents = {},
		-- Referencias derivadas para conservar los contratos 1v1 actuales.
		RedPlayer = redTeam[1],
		BluePlayer = blueTeam[1],
		RedTeam = redTeam,
		BlueTeam = blueTeam,
		SelectedMap = nil,
		Result = nil,
		StartTime = nil,
		State = Constants.RoundState.Waiting,
		StateVersion = 0,
		Votes = {},
		SessionThread = nil,
		PointRestartThread = nil,
		RemainingTime = nil,
		Closing = false,
		Cancelled = false,
		Closed = false,
		CloseStarted = false,
		CloseSteps = {},
		CloseErrors = {},
		Score = { Red = 0, Blue = 0 },
		MatchmakingZoneId = reqZoneId,
	}

	local registered, reason = self:_registerSession(session)
	if not registered then
		return nil, reason
	end

	if request.ReservationToken ~= nil then
		local mmService = self:_getMatchmakingService()
		if mmService and typeof(mmService.ConsumeReservation) == "function" then
			mmService:ConsumeReservation(request.ReservationToken)
		end
	end

	return session, nil
end

RoundService.AdmitTeamSession = RoundService.AdmitSession
RoundService._admitSession = RoundService.AdmitSession

function RoundService:IsAvailable(): boolean
	return countSessions(self._sessionsById) < self._maxConcurrentSessions
end

function RoundService:GetAvailableMaps(teamSize: number?): { string }
	local mapsFolder = ServerStorage:FindFirstChild("Maps")
	if not mapsFolder then
		return {}
	end

	local maps = {}
	local matchInstanceService = self:_getMatchInstanceService()
	for _, child in ipairs(mapsFolder:GetChildren()) do
		if child:IsA("Model") or child:IsA("Folder") then
			local compatible = true
			if matchInstanceService and type(matchInstanceService.IsMapCompatible) == "function" then
				compatible = matchInstanceService:IsMapCompatible(child.Name, teamSize or 1)
			end
			if compatible then table.insert(maps, child.Name) end
		end
	end
	table.sort(maps)
	return maps
end

function RoundService:_setState(newState: RoundStateName, extraData: any?)
	local session = self:GetSession()
	if session then
		return self:SetSessionState(session.Id, newState, extraData)
	end
	if newState == Constants.RoundState.Waiting then
		self._state = newState
		return true
	end
	return false
end

function RoundService:_broadcastCountdown(sessionId: SessionId, remaining: number, label: string, payload: any?)
	local session = self._sessionsById[sessionId]
	if not session or session.Closed then return end
	session.RemainingTime = remaining
	local data = self:_applySessionIdentity(session, payload)
	data.CountdownToken = session.Id
	self:FireSessionRemote(sessionId, "Match", "Countdown", remaining, label, data)
end

function RoundService:_broadcastResult(sessionId: SessionId, result: string, winnerName: string?)
	local session = self._sessionsById[sessionId]
	if not session or session.Closed then return end
	local metadata = self:_applySessionIdentity(session, { Result = result, Winner = winnerName })
	self:FireSessionRemote(sessionId, "Match", "MatchResult", result, winnerName, metadata)
end

function RoundService:SubmitMapVote(player: Player, mapName: string, expectedSessionId: SessionId?): boolean
	if type(expectedSessionId) ~= "string" or expectedSessionId == "" then
		return false
	end
	local session = self:GetSessionForPlayer(player)
	if not session or not self:_isRegisteredSession(session) or session.State ~= Constants.RoundState.MapSelection then
		return false
	end
	if expectedSessionId ~= session.Id then
		return false
	end

	local availableMaps = self:GetAvailableMaps(session.TeamSize)
	local isRandom = (mapName == Constants.SpecialMapVote.Random or mapName == "Aleatorio")
	local isValidMap = table.find(availableMaps, mapName) ~= nil

	if not isRandom and not isValidMap then
		return false
	end

	session.Votes[player] = isRandom and Constants.SpecialMapVote.Random or mapName

	local remote = self:_getRemote("Match", "MapSelection")
	if remote then
		remote:FireClient(player, self:_applySessionIdentity(session, { Voted = session.Votes[player] }))
	end

	return true
end

function RoundService:_isSessionValid(sessionId: SessionId): boolean
	local session = self._sessionsById[sessionId]
	return session ~= nil and self:_isRegisteredSession(session)
end

function RoundService:StartMatch(redPlayer: Player, bluePlayer: Player, matchmakingZoneId: string?): boolean
	local reservationToken = nil
	local mmService = self:_getMatchmakingService()
	if mmService and typeof(mmService.GetActiveReservation) == "function" and matchmakingZoneId then
		local res = mmService:GetActiveReservation(matchmakingZoneId)
		if res then
			reservationToken = res.Token
		end
	end

	local started, _reason = self:StartTeamMatch({
		ZoneId = matchmakingZoneId or "1v1",
		Mode = "1v1",
		TeamSize = 1,
		RedTeam = { redPlayer },
		BlueTeam = { bluePlayer },
		ReservationToken = reservationToken,
	})
	return started
end

function RoundService:StartTeamMatch(
	requestOrRedPlayers: any,
	bluePlayers: { Player }?,
	mode: string?,
	matchmakingZoneId: string?,
	reservationToken: string?
): (boolean, string?)
	local request: Types.TeamMatchAdmissionRequest
	if type(requestOrRedPlayers) == "table" and (requestOrRedPlayers.RedTeam ~= nil or requestOrRedPlayers.Mode ~= nil) then
		request = requestOrRedPlayers
	else
		request = {
			ZoneId = matchmakingZoneId or "1v1",
			Mode = mode or "1v1",
			TeamSize = (type(requestOrRedPlayers) == "table" and #requestOrRedPlayers) or 1,
			RedTeam = requestOrRedPlayers or {},
			BlueTeam = bluePlayers or {},
			ReservationToken = reservationToken,
		}
	end

	-- 1. Bloqueo explícito de inicio real de partidas para modalidades no habilitadas en combate/spawns (Fase 2A)
	if not self:IsModePlayable(request.Mode) then
		warn(string.format("[RoundService] Inicio real bloqueado para modo '%s' (solo 1v1 habilitado para combate en Fase 2A)", tostring(request.Mode)))
		return false, "ModeNotPlayable"
	end

	-- 2. Capacidad global disponible
	if not self:IsAvailable() then
		warn(string.format("[RoundService] No se puede iniciar match, estado actual: %s", self:GetState()))
		return false, "RoundUnavailable"
	end

	-- 3. Admisión atómica de la sesión
	local session, reason = self:AdmitSession(request)
	if not session then
		warn(string.format("[RoundService] Admisión rechazada: %s", tostring(reason)))
		return false, reason
	end

	self._currentSession = session
	session.SessionThread = task.spawn(function()
		local ok, err = xpcall(function()
			self:_runSession(session.Id)
		end, debug.traceback)
		if not ok then
			warn(string.format("[RoundService] Error asíncrono en sesión '%s': %s", session.Id, tostring(err)))
			self:CloseSession(session.Id, {
				Cancelled = true,
				Result = Constants.MatchResult.Cancelled,
				Reason = "SessionThreadError",
			})
		end
	end)

	return true, nil
end

function RoundService:_resolveMap(sessionId: SessionId, availableMaps: { string }): string
	local session = self._sessionsById[sessionId]
	if not session or #availableMaps == 0 then
		return ""
	end

	-- Compatibilidad observable 1v1: un voto Random conserva la regla histórica
	-- de resolver entre todos los mapas, y dos votos distintos empatan entre sí.
	if session.TeamSize == 1 then
		local redVote = session.Votes[session.RedPlayer]
		local blueVote = session.Votes[session.BluePlayer]
		local isRedRandom = (redVote == Constants.SpecialMapVote.Random or redVote == "Aleatorio")
		local isBlueRandom = (blueVote == Constants.SpecialMapVote.Random or blueVote == "Aleatorio")
		local redChosen = if (redVote and not isRedRandom and table.find(availableMaps, redVote)) then redVote else nil
		local blueChosen = if (blueVote and not isBlueRandom and table.find(availableMaps, blueVote)) then blueVote else nil

		if isRedRandom or isBlueRandom then
			return availableMaps[math.random(1, #availableMaps)]
		elseif redChosen and blueChosen and redChosen == blueChosen then
			return redChosen
		elseif redChosen and blueChosen then
			return if math.random(1, 2) == 1 then redChosen else blueChosen
		elseif redChosen then
			return redChosen
		elseif blueChosen then
			return blueChosen
		end
		return availableMaps[math.random(1, #availableMaps)]
	end

	-- XvX: cada participante activo aporta exactamente un voto. Random se
	-- materializa como una elección compatible individual antes del conteo.
	local voteCounts: { [string]: number } = {}
	for _, participant in ipairs(session.Participants) do
		if self:GetSessionParticipant(sessionId, participant.Player) == participant then
			local vote = session.Votes[participant.Player]
			if vote == Constants.SpecialMapVote.Random or vote == "Aleatorio" then
				vote = availableMaps[math.random(1, #availableMaps)]
			end
			if vote and table.find(availableMaps, vote) then
				voteCounts[vote] = (voteCounts[vote] or 0) + 1
			end
		end
	end

	local highest = 0
	local tiedMaps: { string } = {}
	for _, mapName in ipairs(availableMaps) do
		local count = voteCounts[mapName] or 0
		if count > highest then
			highest = count
			tiedMaps = { mapName }
		elseif count > 0 and count == highest then
			table.insert(tiedMaps, mapName)
		end
	end

	if highest == 0 then
		return availableMaps[math.random(1, #availableMaps)]
	end
	return tiedMaps[math.random(1, #tiedMaps)]
end

local function getTeamPlayerSnapshots(players: { Player }?): { { Name: string, UserId: number, DisplayName: string } }
	local res = {}
	if players then
		for _, p in ipairs(players) do
			if p and p.Parent then
				table.insert(res, {
					Name = p.Name,
					UserId = p.UserId,
					DisplayName = p.DisplayName,
				})
			end
		end
	end
	return res
end

local function assignMatchIdentity(session: MatchSession)
	for _, participant in ipairs(session.Participants) do
		local player = participant.Player
		if player and typeof(player) == "Instance" and player:IsA("Player") and player.Parent then
			player:SetAttribute("MatchId", session.Id)
			player:SetAttribute("MatchTeam", participant.Team)
			participant.State = "Active"
		elseif player and typeof(player) == "table" and (player :: any).IsSimulatedPlayer == true then
			participant.State = "Active"
		end
	end
end

local function clearMatchIdentity(session: MatchSession?)
	if not session then return end
	for _, participant in ipairs(session.Participants) do
		local player = participant.Player
		if player and typeof(player) == "Instance" and player:IsA("Player")
			and player:GetAttribute("MatchId") == session.Id then
			runCleanupStep("ClearMatchIdentity", function()
				player:SetAttribute("MatchId", nil)
				player:SetAttribute("MatchTeam", nil)
			end)
		end
	end
end

-- Gameplay V2: one session loop polls the CURRENT round; no timer task per restart.
function RoundService:BeginGameplayRound(session: MatchSession)
 local previous=session.GameplayRound
 session.GameplayRound=RoundClock.Start(session.Id,if previous then previous.Index+1 else 1,
  Config.Round.RoundDuration,os.clock(),workspace:GetServerTimeNow())
 local combat=self:_getCombatService()
 if combat then combat:ClearMatch(session.Id) end
 local abilities=self._context and self._context:GetService("AbilityService")
 if abilities then abilities:BeginRound(session) end
 self:PublishGameplayRound(session)
end

function RoundService:PublishGameplayRound(session: MatchSession)
 local round=session.GameplayRound
 if not round then return end
 local remaining=if round.Resolved then 0 else RoundClock.Remaining(round,os.clock())
 self:_broadcastCountdown(session.Id,remaining,"PLAYING",{
  RoundId=round.Id,RoundIndex=round.Index,Deadline=round.NetworkDeadline,
  Resolved=round.Resolved,SuddenDeath=round.SuddenDeath and round.Resolved==nil,
 })
end

function RoundService:UpdateGameplayRound(session: MatchSession): boolean
 local round=session.GameplayRound
 if not round or round.Resolved then return false end
 local now=os.clock()
 if now>=round.Deadline then
  if RoundClock.Resolve(round,"Timeout",now) then
   self:CancelGameplayRecoveries(session)
   self:PublishGameplayRound(session)
   local score=self:_getScoreService()
   self:BeginSessionResults(session.Id,if score then score:GetWinner(session) else Constants.MatchResult.Draw)
  end
  return false
 end
 local sudden=Config.Round.SuddenDeath
 if sudden.Enabled and not round.SuddenDeath and round.Deadline-now<=sudden.StartAtRemainingSeconds then
  round.SuddenDeath=true
  self:PublishGameplayRound(session)
 end
 return true
end

function RoundService:IsGameplayRoundOpen(session: MatchSession): boolean
 if not self:_isRegisteredSession(session) or session.State~=Constants.RoundState.Playing
  or session.PointInProgress or session.Closing or session.Closed or session.Cancelled or session.GameplayFrozen then return false end
 return self:UpdateGameplayRound(session)
end

function RoundService:TryResolveGameplayRound(session: MatchSession,kind: string): boolean
 if not self:IsGameplayRoundOpen(session) then return false end
 if not RoundClock.Resolve(session.GameplayRound,kind,os.clock()) then
  self:UpdateGameplayRound(session);return false
 end
 self:CancelGameplayRecoveries(session)
 self:PublishGameplayRound(session)
 return true
end

function RoundService:CancelGameplayRecoveries(session: MatchSession)
 local abilities=self._context and self._context:GetService("AbilityService")
 if abilities then abilities:CancelSession(session.Id,"RoundResolved") end
 local ragdoll=self._context and self._context:GetService("RagdollService")
 if ragdoll and ragdoll.CancelRecovery then
  for _,member in ipairs(session.Participants) do
   if member.Player.Character then ragdoll:CancelRecovery(member.Player.Character) end
  end
 end
end

function RoundService:ValidatePreparationParticipants(session: MatchSession, requireCharacter: boolean?): (boolean, string?)
 if not session or self._sessionsById[session.Id] ~= session then return false,"SessionNotRegistered" end
 local seen = {}
 for _,team in ipairs({"Red","Blue"}) do
  local roster = if team == "Red" then session.RedTeam else session.BlueTeam
  if not roster or #roster ~= session.TeamSize then return false,"IncompleteTeam" end
  for slot,player in ipairs(roster) do
   local participant=self:GetSessionParticipant(session.Id,player)
   if not participant or participant.Team~=team or participant.Slot~=slot or seen[player] then return false,"PreparationParticipantMismatch" end
   seen[player]=true
   if requireCharacter then
    local character=player.Character
    local humanoid=character and character:FindFirstChildOfClass("Humanoid")
    local root=character and character:FindFirstChild("HumanoidRootPart")
    if not character or not character:IsDescendantOf(workspace) or not humanoid or humanoid.Health<=0
     or not root or not root:IsA("BasePart") then return false,"PreparationCharacterUnavailable" end
   end
  end
 end
 return true,nil
end

function RoundService:_runSession(sessionId: string)
	local session = self._sessionsById[sessionId]
	if not session or not self:_isRegisteredSession(session) then return end

	-- Bloqueo defensivo en ejecución de sesión si el modo no está habilitado para combate
	if not self:IsModePlayable(session.Mode) then
		warn(string.format("[RoundService] _runSession abortado: modo '%s' no habilitado para combate en Fase 2A", session.Mode))
		self:CloseSession(sessionId, { Cancelled = true, Reason = "ModeNotPlayable" })
		return
	end

	local redSnap = getTeamPlayerSnapshots(session.RedTeam or { session.RedPlayer })
	local blueSnap = getTeamPlayerSnapshots(session.BlueTeam or { session.BluePlayer })

	local mmService = self:_getMatchmakingService()
	if not self:ValidatePreparationParticipants(session, false) then
		self:_cancelSession("InvalidPreparationParticipants",sessionId);return
	end

	-- 1. MATCH_READY
	assignMatchIdentity(session)

	if not self:SetSessionState(sessionId, Constants.RoundState.MatchReady, {
		Red = session.RedPlayer.Name,
		Blue = session.BluePlayer.Name,
		RedTeam = redSnap,
		BlueTeam = blueSnap,
	}) then return end
	task.wait(0.5)
	if not self:_isSessionValid(sessionId) then return end

	-- Verificación pre-countdown: si alguno abandonó durante MatchReady (0.5s)
	if session.MatchmakingZoneId and mmService then
		if not mmService:ArePlayersInZone(session.MatchmakingZoneId, session.RedTeam, session.BlueTeam) then
			self:_cancelMatchPreparation("PlayerLeftQueuePad", sessionId)
			return
		end
	end

	-- 2. MATCH_COUNTDOWN (5 segundos)
	local countdownTime = Config.Round.MatchCountdownTime
	if not self:SetSessionState(sessionId, Constants.RoundState.MatchCountdown, { Duration = countdownTime }) then return end
	for t = countdownTime, 1, -1 do
		if not self:ValidatePreparationParticipants(session, false) then self:_cancelSession("InvalidPreparationParticipants",sessionId);return end
		-- Validación periódica pre-compromiso: ¿ambos siguen físicamente en sus pads?
		if session.MatchmakingZoneId and mmService then
			if not mmService:ArePlayersInZone(session.MatchmakingZoneId, session.RedTeam, session.BlueTeam) then
				self:_cancelMatchPreparation("PlayerLeftQueuePad", sessionId)
				return
			end
		end

		self:_broadcastCountdown(sessionId, t, "LA PARTIDA COMIENZA EN")
		task.wait(1)
		if not self:_isSessionValid(sessionId) then return end
	end
	self:_broadcastCountdown(sessionId, 0, "LA PARTIDA COMIENZA EN")

	-- 2.5 GATE FINAL AUTORITATIVO ANTES DE COMPROMETER LA PARTIDA EN MAPSELECTION
	if session.MatchmakingZoneId and mmService then
		if not mmService:ArePlayersInZone(session.MatchmakingZoneId, session.RedTeam, session.BlueTeam) then
			self:_cancelMatchPreparation("PlayerLeftQueuePad", sessionId)
			return
		end
	end

	-- 3. MAP_SELECTION (5 segundos)
	local availableMaps = self:GetAvailableMaps(session.TeamSize)
	if #availableMaps == 0 then
		warn("[RoundService] No maps available.")
		self:_cancelSession("NoMapsAvailable", sessionId)
		return
	end

	local mapSelectionTime = Config.Round.MapSelectionTime
	if not self:SetSessionState(sessionId, Constants.RoundState.MapSelection, {
		Maps = availableMaps,
		Duration = mapSelectionTime,
	}) then return end

	self:FireSessionRemote(sessionId, "Match", "MapSelection", self:_applySessionIdentity(session, {
			MatchId = sessionId,
			Maps = availableMaps,
			Duration = mapSelectionTime,
		}))

	for t = mapSelectionTime, 1, -1 do
		self:_broadcastCountdown(sessionId, t, "ELIGE UN MAPA")
		task.wait(1)
		if not self:_isSessionValid(sessionId) then return end
	end
	self:_broadcastCountdown(sessionId, 0, "ELIGE UN MAPA")

	-- 4. RESOLUCION DE MAPA
	local selectedMap = self:_resolveMap(sessionId, availableMaps)
	session.SelectedMap = selectedMap
	print(string.format("[RoundService] Selected map: %s", selectedMap))

	-- 5. MAP_LOADING
	if not self:ValidatePreparationParticipants(session,true)
		or (session.MatchmakingZoneId and mmService and not mmService:ArePlayersInZone(session.MatchmakingZoneId,session.RedTeam,session.BlueTeam,true)) then
		self:_cancelSession("PreparationOccupancyLost",sessionId);return
	end
	if not self:SetSessionState(sessionId, Constants.RoundState.MapLoading, { SelectedMap = selectedMap }) then return end

	local matchInstanceService = self:_getMatchInstanceService()
	if matchInstanceService then
		local instanceInfo = matchInstanceService:CreateInstance(session, selectedMap)
		if not instanceInfo then
			warn(string.format("[RoundService] No se pudo instanciar fisicamente el mapa '%s'", selectedMap))
			self:_cancelSession("MapInstanceCreationFailed", sessionId)
			return
		end
		session.InstanceInfo = instanceInfo

		-- Validar contrato ZoneWin en la instancia clonada
		local scoreService = self:_getScoreService()
		if scoreService then
			local isValidZone = scoreService:ValidateZoneWin(session)
			if not isValidZone then
				warn(string.format("[RoundService] Missing or invalid ZoneWin contract for match '%s'", sessionId))
				self:_cancelSession("ZoneWinValidationFailed", sessionId)
				return
			end
		end
	else
		local mapFolder = ServerStorage:FindFirstChild("Maps")
		local mapInstance = mapFolder and mapFolder:FindFirstChild(selectedMap)
		if not mapInstance then
			warn(string.format("[RoundService] Map '%s' not found in ServerStorage.Maps", selectedMap))
			self:_cancelSession("MapInstanceNotFound", sessionId)
			return
		end
	end

	-- Posicionamiento de jugadores en spawns de la arena aislada
	local spawnService = self:_getSpawnService()
	if spawnService then
		if not self:ValidatePreparationParticipants(session,true)
			or (session.MatchmakingZoneId and mmService and not mmService:ArePlayersInZone(session.MatchmakingZoneId,session.RedTeam,session.BlueTeam,true)) then
			self:_cancelSession("PreparationOccupancyLost",sessionId);return
		end
		local spawnResult = spawnService:SpawnMatchPlayers(session)
		if not spawnResult.Success then
			warn(string.format("[RoundService] Spawn incompleto para '%s': %d/%d, fallos=%d", sessionId, spawnResult.Placed, spawnResult.Required, #spawnResult.Failures))
			self:_cancelSession("SpawnPlayersFailed", sessionId)
			return
		end
	else
		warn("[RoundService] SpawnService no disponible durante MapLoading")
		self:_cancelSession("SpawnServiceUnavailable",sessionId)
		return
	end

	task.wait(1)
	if not self:_isSessionValid(sessionId) then return end
	if not self:ValidatePreparationParticipants(session, true) then
		self:_cancelSession("PreparationIncomplete",sessionId);return
	end

	-- 5.5 START_COUNTDOWN (Config.Match.StartCountdownTime, por defecto 5 segundos)
	-- Jugadores ya posicionados en spawns, arena cargada, scoring y match timer NO activos
	local startCountdownTime = (Config.Match and Config.Match.StartCountdownTime) or 5
	if not self:SetSessionState(sessionId, Constants.RoundState.StartCountdown, {
		MatchId = sessionId,
		Duration = startCountdownTime,
		Red = session.RedPlayer.Name,
		Blue = session.BluePlayer.Name,
		RedTeam = redSnap,
		BlueTeam = blueSnap,
	}) then return end

	-- Bloqueo autoritativo de locomoción durante StartCountdown (WalkSpeed=0, JumpPower=0, AutoRotate=false)
	if spawnService then
		spawnService:LockSessionPlayers(session)
	end

	-- Equipar Slaps autoritativos para la partida
	local slapService = self:_getSlapService()
	if slapService then
		slapService:EquipMatchPlayers(session)
	end

	local abilities = self._context and self._context:GetService("AbilityService")
	local abilityWindow = abilities and abilities:PrepareSelection(session, startCountdownTime)
	if abilities and not abilityWindow then return end
	for t = startCountdownTime, 1, -1 do
		if not self:ValidatePreparationParticipants(session, true) then self:_cancelSession("PreparationIncomplete",sessionId);return end
		self:_broadcastCountdown(sessionId, t, "START_COUNTDOWN", {
			MatchId = sessionId,
			Value = t,
			Started = false,
		})
		task.wait(1)
		if not self:_isSessionValid(sessionId) then return end
	end

	if abilities then abilities:FinishSelection(session, abilityWindow) end
	-- Emisión final autoritativa de inicio ("GO" / Value=0, Started=true)
	self:_broadcastCountdown(sessionId, 0, "START_COUNTDOWN", {
		MatchId = sessionId,
		Value = 0,
		Started = true,
	})
	task.wait(0.5)
	if not self:_isSessionValid(sessionId) then return end

	-- 6. PLAYING: each competitive round receives its own 180-second deadline.
	if not self:ValidatePreparationParticipants(session, true) then self:_cancelSession("PreparationIncomplete",sessionId);return end
	-- El timer oficial de partida (RoundDuration) y el ScoreService comienzan estrictamente al entrar en Playing
	session.StartTime = os.clock()
	local roundDuration = Config.Round.RoundDuration
	if not self:SetSessionState(sessionId, Constants.RoundState.Playing, {
		MatchId = sessionId,
		Duration = roundDuration,
		SelectedMap = selectedMap,
		Red = session.RedPlayer.Name,
		Blue = session.BluePlayer.Name,
		RedTeam = redSnap,
		BlueTeam = blueSnap,
	}) then return end


	-- Iniciar scoring autoritativo
	local scoreService = self:_getScoreService()
	if scoreService then
		scoreService:StartScoring(session)
	end

	-- Iniciar detección y resolución de eliminaciones autoritativas
	local eliminationService = self:_getEliminationService()
	if eliminationService then
		eliminationService:BindMatch(session)
	end

	-- Restaurar movimiento normal inmediatamente al pasar a PLAYING
	if spawnService then
		spawnService:UnlockSessionPlayers(session)
	end

	self:BeginGameplayRound(session)
 local lastPublished=-1
 local lastRoundId=""
 while self:_isSessionValid(sessionId) and session.Result==nil do
  local round=session.GameplayRound
  if round and not round.Resolved and session.State==Constants.RoundState.Playing and not session.PointInProgress then
   if self:UpdateGameplayRound(session) then
    local remaining=RoundClock.Remaining(round,os.clock())
    if lastPublished~=remaining or lastRoundId~=round.Id then
     lastPublished=remaining;lastRoundId=round.Id;self:PublishGameplayRound(session)
    end
   end
  end
  task.wait(0.05)
 end

	if not self:_isSessionValid(sessionId) then return end

	-- Timeout uses the same terminal barrier as the fifth point.
	local result = session.Result
	if result == nil then result = if scoreService then scoreService:GetWinner(session) else Constants.MatchResult.Draw end
	self:BeginSessionResults(sessionId, result)
end

-- Inicia la secuencia autoritativa de PointRestartCountdown (3 segundos) tras un punto anotado
function RoundService:TriggerPointRestart(session: MatchSession)
	local sessionId = session.Id
	if not self:_isSessionValid(sessionId) or session.State ~= Constants.RoundState.Playing then return end
	local respawns = self:_getSpawnService()
	if respawns and respawns.CancelSessionRespawns then respawns:CancelSessionRespawns(sessionId, "PointRestart") end

	-- Cancelar cualquier hilo previo si existiera
	if session.PointRestartThread then
		pcall(task.cancel, session.PointRestartThread)
		session.PointRestartThread = nil
	end

	session.PointRestartThread = task.spawn(function()
		local delayTime = (Config.Match and Config.Match.PointResetDelay) or 1.5
		task.wait(delayTime)

		if not self:_isSessionValid(sessionId) or session.Result ~= nil then return end

		-- Reposicionar ambos equipos en sus spawns respectivos de la arena activa y bloquear locomoción
		local spawnService = self:_getSpawnService()
		if spawnService then
			local spawnResult = spawnService:SpawnMatchPlayers(session)
			if not spawnResult.Success then
				warn(string.format("[RoundService] Reinicio de punto incompleto para '%s': %d/%d", sessionId, spawnResult.Placed, spawnResult.Required))
				self:_cancelSession("PointRestartSpawnFailed", sessionId)
				return
			end
			spawnService:LockSessionPlayers(session)
		end

		-- Limpiar registros de presencia en zonas en ScoreService
		local scoreService = self:_getScoreService()
		if scoreService then
			scoreService:ResetZonePresences(sessionId)
		end

		local countdownTime = (Config.Match and Config.Match.PointRestartCountdownTime) or 3
		local redSnap = getTeamPlayerSnapshots(session.RedTeam or { session.RedPlayer })
		local blueSnap = getTeamPlayerSnapshots(session.BlueTeam or { session.BluePlayer })

		-- Transición de estado a PointRestartCountdown
		if not self:SetSessionState(sessionId, Constants.RoundState.PointRestartCountdown, {
			MatchId = sessionId,
			Duration = countdownTime,
			Red = session.RedPlayer and session.RedPlayer.Name,
			Blue = session.BluePlayer and session.BluePlayer.Name,
			RedTeam = redSnap,
			BlueTeam = blueSnap,
		}) then return end

		-- Cuenta regresiva autoritativa: 3 -> 2 -> 1
		local abilities = self._context and self._context:GetService("AbilityService")
		local abilityWindow = abilities and abilities:PrepareSelection(session, countdownTime)
		if abilities and not abilityWindow then return end
		for t = countdownTime, 1, -1 do
			self:_broadcastCountdown(sessionId, t, "START_COUNTDOWN", {
				MatchId = sessionId,
				Value = t,
				Started = false,
				Phase = "PointRestart",
			})
			task.wait(1)
			if not self:_isSessionValid(sessionId) or session.Result ~= nil then return end
		end

		if abilities then abilities:FinishSelection(session, abilityWindow) end
		-- Emisión final clímax: ¡COMIENZA! (Value = 0, Started = true)
		self:_broadcastCountdown(sessionId, 0, "START_COUNTDOWN", {
			MatchId = sessionId,
			Value = 0,
			Started = true,
			Phase = "PointRestart",
		})
		task.wait(0.5)
		if not self:_isSessionValid(sessionId) or session.Result ~= nil then return end

		-- Retorno autoritativo al estado Playing
		if not self:SetSessionState(sessionId, Constants.RoundState.Playing, {
			MatchId = sessionId,
			Duration = Config.Round.RoundDuration,
			SelectedMap = session.SelectedMap,
			Red = session.RedPlayer and session.RedPlayer.Name,
			Blue = session.BluePlayer and session.BluePlayer.Name,
			RedTeam = redSnap,
			BlueTeam = blueSnap,
		}) then return end

		-- Restaurar movimiento normal inmediatamente al reanudar PLAYING
		if spawnService then
			spawnService:UnlockSessionPlayers(session)
		end

		-- Limpiar explícitamente el estado de PointScorer al reanudar combate
		session.PointInProgress = false
		session.PointScorer = nil
		session.PointScorerTeam = nil
		session.PointScoreTimestamp = nil
		session.PointNumber = nil

		-- New deadline begins only once this departure becomes playable.
		if scoreService then scoreService:ResumeScoring(sessionId) end
		self:BeginGameplayRound(session)

		if self:_isSessionValid(sessionId) then
			session.PointRestartThread = nil
		end
		print(string.format("[RoundService] PointRestartCountdown completado para Match '%s'. Partida reanudada en PLAYING.", sessionId))
	end)
end

function RoundService:DeclareSessionWinner(sessionId: SessionId, winner: MatchResultName, finalGoal: any?): boolean
	local session = self._sessionsById[sessionId]
	if not session or session.Result ~= nil or not self:_isRegisteredSession(session)
		or (session.State ~= Constants.RoundState.Playing and session.State ~= Constants.RoundState.PointRestartCountdown) then
		return false
	end
	if session.PointRestartThread then
		pcall(task.cancel, session.PointRestartThread)
		session.PointRestartThread = nil
	end
	return self:BeginSessionResults(sessionId, winner, finalGoal)
end

-- Adaptador 1v1 temporal para ScoreService. Retirar cuando el consumidor envíe SessionId.
function RoundService:DeclareWinner(winner: MatchResultName, sessionId: SessionId?): boolean
	local resolvedId = sessionId
	if not resolvedId then
		local session = self:GetSession()
		resolvedId = session and session.Id or nil
	end
	return if resolvedId then self:DeclareSessionWinner(resolvedId, winner) else false
end

-- Hook de entrega de recompensas y estadísticas server-authoritative
function RoundService:_processReward(session: MatchSession, result: MatchResultName)
	self._rewardedMatches = self._rewardedMatches or {}
	self._rewardedPlayers = self._rewardedPlayers or {}
	local matchId = session.Id or (session :: any).MatchId or "UNKNOWN_MATCH"
	if self._rewardedMatches[matchId] then
		print(string.format("[RoundService] Match '%s' ya fue recompensado previamente. Omitiendo duplicado.", matchId))
		return
	end
	local playerService = self:_getPlayerService()
	if playerService then
		local function isConnected(player: any): boolean
			if typeof(player) == "Instance" and player:IsA("Player") then
				return player.Parent == Players
			end
			return typeof(player) == "table"
				and player.IsSimulatedPlayer == true
				and player.IsConnected ~= false
		end

		local winningTeam = if result == Constants.MatchResult.Red then "Red"
			elseif result == Constants.MatchResult.Blue then "Blue" else nil
		if winningTeam then
			local hasConnectedWinner = false
			for _, participant in ipairs(session.Participants) do
				if participant.Team == winningTeam
					and participant.State ~= "Left"
					and participant.State ~= "Released"
					and isConnected(participant.Player) then
					hasConnectedWinner = true
					break
				end
			end
			if not hasConnectedWinner then
				self._rewardedMatches[matchId] = true
				print(string.format("[RoundService] Match '%s' terminó sin ganador conectado; no se aplican estadísticas", matchId))
				return
			end
		end

		local rewardedPlayers = self._rewardedPlayers[matchId] or {}
		self._rewardedPlayers[matchId] = rewardedPlayers
		local function award(player: Player, kind: string)
			-- PlayerService vuelve a registrar datos si recibe un Player ya removido.
			-- No recrear perfiles después de PlayerRemoving; el cierre debe poder
			-- finalizar sin dejar registros huérfanos.
			if not isConnected(player) then
				print(string.format("[RoundService] Estadística %s omitida para '%s': jugador desconectado", kind, player.Name))
				return
			end
			local key = string.format("%d:%s", player.UserId, kind)
			if rewardedPlayers[key] then return end
			if playerService.RecordStreakResult then playerService:RecordStreakResult(player,matchId,kind)end
				if kind == "Win" then
				playerService:AddWin(player, "MatchWin")
			else
				playerService:AddLoss(player, "MatchLoss")
			end
			rewardedPlayers[key] = true
		end

		if result == Constants.MatchResult.Red or result == Constants.MatchResult.Blue then
			for _, participant in ipairs(session.Participants) do
				if participant.State ~= "Left" and participant.State ~= "Released" then
					award(participant.Player, if participant.Team == result then "Win" else "Loss")
				end
			end
		end
  if result==Constants.MatchResult.Draw and playerService.RecordStreakResult then
   for _,participant in ipairs(session.Participants)do
    if participant.State~='Left' and participant.State~='Released' and isConnected(participant.Player)then
     playerService:RecordStreakResult(participant.Player,matchId,'Draw')
    end
   end
  end
		-- Draw o Cancelled: no otorgan Win ni Loss
	else
		warn("[RoundService] PlayerService no disponible al procesar recompensas")
		error("PlayerServiceUnavailable")
	end
	self._rewardedMatches[matchId] = true

	local allPlayers: { Player } = {}
	if session.RedTeam then
		for _, p in ipairs(session.RedTeam) do table.insert(allPlayers, p) end
	elseif session.RedPlayer then
		table.insert(allPlayers, session.RedPlayer)
	end
	if session.BlueTeam then
		for _, p in ipairs(session.BlueTeam) do table.insert(allPlayers, p) end
	elseif session.BluePlayer then
		table.insert(allPlayers, session.BluePlayer)
	end

	local rewardPayload: Types.MatchRewardPayload = {
		MatchId = session.Id,
		WinningTeam = result,
		Result = result,
		Players = allPlayers,
	}

	print(string.format("[RoundService] Estadísticas y recompensas procesadas para Match '%s' (Resultado: %s, %d jugadores)",
		session.Id, tostring(result), #allPlayers))
end

function RoundService:_handlePlayerLeaving(player: Player)
	local participant = self:GetParticipantForPlayer(player)
	if not participant then return end
	local session = self:GetSessionForPlayer(player)
	if not session then return end
	participant.State = "Left"
	self:_unregisterParticipant(participant, session.Id)

	-- Limpiar atributos del jugador que abandona
	player:SetAttribute("MatchId", nil)
	player:SetAttribute("MatchTeam", nil)

	print(string.format("[RoundService] Jugador desconectado: %s durante estado %s", player.Name, session.State))
	if session.Results and session.Results.Viewers[player] then
		local viewer = session.Results.Viewers[player]
		viewer.Returned = true
		if viewer.RespawnConnection then viewer.RespawnConnection:Disconnect(); viewer.RespawnConnection = nil end
		self:_releaseEndingCharacter(session, player)
	end
	if session.Closing or session.Closed then return end

	if session.State == Constants.RoundState.Playing or session.State == Constants.RoundState.PointRestartCountdown then
		local activeRed = 0
		local activeBlue = 0
		for _, remaining in ipairs(session.Participants) do
			if self:GetSessionParticipant(session.Id, remaining.Player) == remaining then
				if remaining.Team == "Red" then activeRed += 1 else activeBlue += 1 end
			end
		end

		local abandonmentResult: MatchResultName? = nil
		if activeRed == 0 and activeBlue == 0 then
			abandonmentResult = Constants.MatchResult.Draw
		elseif activeRed == 0 then
			abandonmentResult = Constants.MatchResult.Blue
		elseif activeBlue == 0 then
			abandonmentResult = Constants.MatchResult.Red
		end

		if abandonmentResult then
			local mutableSession = session :: any
			local resultSource = mutableSession.ResultSource
			if session.Result == nil or resultSource == "Abandonment" then
				session.Result = abandonmentResult
				mutableSession.ResultSource = "Abandonment"
				print(string.format("[RoundService] Resultado por abandono: %s (Red activos=%d, Blue activos=%d)",
					abandonmentResult, activeRed, activeBlue))
			end
			if session.PointRestartThread then
				pcall(task.cancel, session.PointRestartThread)
				session.PointRestartThread = nil
			end
		else
			print(string.format("[RoundService] La sesión continúa tras abandono (Red activos=%d, Blue activos=%d)", activeRed, activeBlue))
		end
		-- El loop de PLAYING solo finaliza cuando un equipo queda vacío.
	elseif session.State == Constants.RoundState.Waiting
		or session.State == Constants.RoundState.MatchReady
		or session.State == Constants.RoundState.MatchCountdown
		or session.State == Constants.RoundState.MapSelection
		or session.State == Constants.RoundState.MapLoading
		or session.State == Constants.RoundState.StartCountdown then
		-- Si abandona antes de PLAYING, cancelar la sesión y volver a Waiting
		self:_cancelSession("PlayerDisconnected", session.Id)
	end
end

-- Characters stay on safe arena spawns, anchored, while only visual rigs act.
function RoundService:_protectEndingCharacter(session: MatchSession, player: Player)
	player:SetAttribute("ResultsSessionId", session.Id)
 local character = player.Character
 if not character then return end
 session.EndingCharacters = session.EndingCharacters or {}
 local saved = session.EndingCharacters[player]
 if saved and saved.Character == character then return end
 local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
 if not root then return end
 local spawn = self:_getSpawnService()
 if session.Results and session.Results.Celebrating then
  -- Preserve the goal viewpoint, but cancel ragdoll/inertia before anchoring.
  local ragdoll = self._context and self._context:GetService("RagdollService")
  if ragdoll then ragdoll:ResetRagdollImmediate(character) end
 else
  if spawn then spawn:ResetCharacterInArena(player, session.Id) end
 end
 session.EndingCharacters[player] = { Character = character, Root = root, Anchored = root.Anchored }
 if spawn then spawn:LockCharacterMovement(player) end
 for _, part in ipairs(character:GetDescendants()) do
  if part:IsA("BasePart") then part.AssemblyLinearVelocity = Vector3.zero; part.AssemblyAngularVelocity = Vector3.zero end
 end
 root.Anchored = true
end

function RoundService:_releaseEndingCharacter(session: MatchSession, player: Player)
 local saved = session.EndingCharacters and session.EndingCharacters[player]
 if saved and saved.Root.Parent then saved.Root.Anchored = saved.Anchored end
 if session.EndingCharacters then session.EndingCharacters[player] = nil end
 if player:GetAttribute("ResultsSessionId") == session.Id then player:SetAttribute("ResultsSessionId", nil) end
 if player:GetAttribute("FinalGoalSessionId") == session.Id then player:SetAttribute("FinalGoalSessionId", nil) end
end

function RoundService:_returnResultsPlayer(session: MatchSession, player: Player): boolean
 local results = session.Results
 local viewer = results and results.Viewers[player]
 if not viewer then return false end
 if viewer.Returned then return true end
 if viewer.Returning then return false end
 viewer.Returning = true
 local succeeded, returned = xpcall(function()
 local remote = self:_getRemote("Match", "EndCinematic")
 if player.Parent == Players and remote then
  remote:FireClient(player, "Returned", { SessionId = session.Id, MatchId = session.Id, StateVersion = results.Version, Token = results.Token })
 end
 local ok = true
 if player.Parent == Players then
  local spawn = self:_getSpawnService()
  local success, returned = pcall(function()
   return spawn and spawn:ReturnPlayersToLobby({ player }, nil)
  end)
  ok = success and returned == true
 end
 if not ok then return false end
 self:_releaseEndingCharacter(session, player)
 local slap = self:_getSlapService()
 if slap and player.Parent == Players then slap:UnlockPlayer(player); slap:RemoveSlaps(player) end
 local savedConnection = viewer.RespawnConnection
 if savedConnection then savedConnection:Disconnect(); viewer.RespawnConnection = nil end
 if results.Scene and results.Scene.Parent then pcall(function() results.Scene:RemovePersistentPlayer(player) end) end
 -- Clear only this player's legacy match HUD and music, without ending peers.
 if player.Parent == Players then
  local stateRemote = self:_getRemote("Match", "StateChanged")
  if stateRemote then
   local payload = self:_applySessionIdentity(session, { Reason = "ResultsExited" })
   payload.StateVersion = session.StateVersion + 1
   stateRemote:FireClient(player, Constants.RoundState.ReturningToLobby, payload)
  end
 end
 viewer.Returned = true
 local participant = self._participantByPlayer[player]
 if participant and self._sessionIdByUserId[participant.UserId] == session.Id then
  participant.State = "Released"
  self:_unregisterParticipant(participant, session.Id)
 end
 return true
 end, debug.traceback)
 viewer.Returning = false
 if not succeeded then warn("[RoundService] Results return failed: " .. tostring(returned)) end
 return succeeded and returned == true
end

function RoundService:HandleCinematicAction(player: Player, action: any, sessionId: any, version: any, token: any): boolean
 if type(sessionId) ~= "string" or type(action) ~= "string" then return false end
 local session = self._sessionsById[sessionId]
 local results = session and session.Results
 local viewer = results and results.Viewers[player]
 if not session or session.Closed or session.State ~= Constants.RoundState.Ending
  or not results or not viewer or results.Token ~= token or results.Version ~= version then return false end
 if viewer.Returned then return action == "Return" end
 if self._sessionIdByUserId[player.UserId] ~= sessionId or self._participantByPlayer[player] ~= viewer.Participant then return false end
 if action == "Prepared" then
  viewer.Prepared = true
 elseif action == "Return" or action == "Failed" then
  return self:_returnResultsPlayer(session, player)
 else
  return false
 end
 return true
end

function RoundService:GetResultsDuration(): number
 local transition, camera, winners, hud = CinematicConfig.Transition, CinematicConfig.Camera, CinematicConfig.Winners, CinematicConfig.HUD
 local walks = winners.WalkStartDelay + (winners.MaxVisible - 1) * winners.EntryStagger + winners.WalkDuration
 return math.max(transition.OpenDuration, camera.TravelDuration + (if camera.ArrivalBounceEnabled then camera.ArrivalBounceDuration else 0), walks)
  + hud.ShowDelay + CinematicConfig.Billboards.ShowDelay
  + math.max(hud.FadeDuration, CinematicConfig.Billboards.FadeDuration) + CinematicConfig.Results.ViewDuration
end

function RoundService:BeginSessionResults(sessionId: SessionId, result: MatchResultName, finalGoal: any?): boolean
 local session = self._sessionsById[sessionId]
 if not session or session.Closed or session.GameplayFrozen or session.Cancelled then return false end
 if result ~= Constants.MatchResult.Red and result ~= Constants.MatchResult.Blue and result ~= Constants.MatchResult.Draw then return false end
 if session.Result ~= nil and session.Result ~= result then return false end
 -- No yielding before the authority barrier and state version are committed.
 session.Result = result
 if session.GameplayRound and not session.GameplayRound.Resolved then session.GameplayRound.Resolved="Closed" end
 self:CancelGameplayRecoveries(session)
 session.GameplayFrozen = true
 session.Closing = true
 if session.PointRestartThread then pcall(task.cancel, session.PointRestartThread); session.PointRestartThread = nil end
 if not self:SetSessionState(sessionId, Constants.RoundState.Ending, { Result = result, Cinematic = true }, true) then return false end
 local token = HttpService:GenerateGUID(false)
 local results = { Token = token, Version = session.StateVersion, Viewers = {}, Scene = nil, Started = false,
  Celebrating = finalGoal ~= nil and CinematicConfig.FinalGoal.CelebrationEnabled == true }
 session.Results = results
 results.Snapshot = self:CaptureCinematicRanking(session)
 for _, participant in ipairs(session.Participants) do
  local player = participant.Player
  if participant.State ~= "Left" and participant.State ~= "Released" and player.Parent == Players then
   results.Viewers[player] = { Participant = participant, Prepared = false, Returned = false }
  end
 end
 -- Stop competitive triggers before any physical repositioning can yield.
 local elimination = self:_getEliminationService()
 if elimination then elimination:UnbindMatch(sessionId) end
 local combat = self:_getCombatService()
 if combat then combat:ClearMatch(sessionId) end
 local feedback = self._context and self._context:GetService("PointFeedbackService")
 if feedback then feedback:CleanupMatch(sessionId) end
 local slap = self:_getSlapService()
 for player in pairs(results.Viewers) do
  if results.Celebrating then player:SetAttribute("FinalGoalSessionId", sessionId) end
  if slap then slap:UnlockPlayer(player); slap:RemoveSlaps(player) end
  self:_protectEndingCharacter(session, player)
  results.Viewers[player].RespawnConnection = player.CharacterAdded:Connect(function()
   task.defer(function()
    if self._sessionsById[sessionId] == session and not results.Viewers[player].Returned then
     self:_returnResultsPlayer(session, player)
    end
   end)
  end)
 end
 -- Defer StopScoring: a fifth point may currently run inside its spatial thread.
 session.ResultsThread = task.defer(function()
  local ok, failure = xpcall(function()
   if not self:CloseSession(sessionId, { Result = result, AwardRewards = true, DeferCleanup = true, Reason = "EndCinematic" }) then
    self:CloseSession(sessionId, { Reason = "ResultsSetupFailed" })
    return
   end
   local instances = self:_getMatchInstanceService()
   local info = instances and instances:GetInstance(sessionId)
   local scene = info and info.EndCinematic
   if not scene or not scene.Parent then self:CloseSession(sessionId, { Reason = "CinematicSceneMissing" }); return end
   results.Scene = scene
   local winners = {}
   local eligible = {}
   local descriptions = Instance.new("Folder")
   descriptions.Name = "WinnerDescriptions"
   descriptions.Parent = scene
   for _, participant in ipairs(session.Participants) do
    local player = participant.Player
    local descriptionKey = tostring(participant.UserId)
    local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    local captured, description = pcall(function() return humanoid and humanoid:GetAppliedDescription() end)
    if not captured or not description then description = Instance.new("HumanoidDescription") end
    description.Name = descriptionKey
    description.Parent = descriptions
    if results.Viewers[player] then
     table.insert(eligible, participant.UserId)
    end
    if participant.Team == result then
      local entry = { UserId = participant.UserId, DisplayName = player.DisplayName, Team = participant.Team, Slot = participant.Slot, DescriptionKey = descriptionKey }
      table.insert(winners, entry)
    end
   end
   table.sort(winners, function(a,b) return a.Slot == b.Slot and a.UserId < b.UserId or a.Slot < b.Slot end)
   if results.Celebrating then
    local config = CinematicConfig.FinalGoal
    local began = workspace:GetServerTimeNow()
    local minimum = math.max(0, config.CelebrationDuration)
    local maximum = math.max(minimum, config.MaxFeedbackWait)
    -- Run a potentially yielding cosmetic controller separately; the wait is bounded.
    local completed = feedback == nil
    local effectThread = if feedback then task.spawn(function()
     local played, failure = pcall(function() feedback:PlayPoint(session, finalGoal, token) end)
     completed = true
     if not played then warn("[RoundService] Final goal feedback: " .. tostring(failure)) end
    end) else nil
    results.FeedbackThread = effectThread
    while self._sessionsById[sessionId] == session and not session.Closed and results.Celebrating do
     local elapsed = workspace:GetServerTimeNow() - began
     local active = feedback and feedback.HasActiveFeedback and feedback:HasActiveFeedback(sessionId)
     if elapsed >= maximum or (elapsed >= minimum and (not config.WaitForFeedback or (completed and not active))) then break end
     task.wait(0.05)
    end
    if effectThread and coroutine.status(effectThread) ~= "dead" then pcall(task.cancel, effectThread) end
    results.FeedbackThread = nil
    results.Celebrating = false
    if feedback then feedback:CleanupMatch(sessionId) end
    for player in pairs(results.Viewers) do
     if player:GetAttribute("FinalGoalSessionId") == sessionId then player:SetAttribute("FinalGoalSessionId", nil) end
    end
    if self._sessionsById[sessionId] ~= session or session.Closed or session.State ~= Constants.RoundState.Ending then return end
    print(string.format("[RoundService] FinalGoal celebration completed for '%s' after %.3fs", sessionId, workspace:GetServerTimeNow() - began))
   end
   local remote = self:_getRemote("Match", "EndCinematic")
   local payload = self:_applySessionIdentity(session, {
    Token = token, Mode = session.Mode, TeamSize = session.TeamSize, WinningTeam = result,
    Score = table.clone(session.Score or { Red = 0, Blue = 0 }), Winners = winners,
    ResultSnapshot = results.Snapshot,
    EligibleParticipantUserIds = eligible, EligibleParticipantCount = #eligible,
    SceneContainer = info.Container.Name, SceneName = scene.Name,
    SceneOrigin = scene:GetPivot().Position,
   })
   for player, viewer in pairs(results.Viewers) do
    if player.Parent == Players and not viewer.Returned then
     scene:AddPersistentPlayer(player)
     local personal = table.clone(payload)
     personal.LocalTeam = viewer.Participant.Team
     remote:FireClient(player, "Prepare", personal)
    end
   end
   local preparationDeadline = workspace:GetServerTimeNow() + CinematicConfig.Results.PreparationTimeout
   local deadline = preparationDeadline + self:GetResultsDuration() + CinematicConfig.Results.StartLeadTime
   while self._sessionsById[sessionId] == session and not session.Closed do
    local remaining = 0
    local prepared = true
    local now = workspace:GetServerTimeNow()
    for player, viewer in pairs(results.Viewers) do
     if not viewer.Returned then
      if player.Parent ~= Players or (not viewer.Prepared and now >= preparationDeadline) or now >= deadline then
       self:_returnResultsPlayer(session, player)
      end
      if not viewer.Returned then remaining += 1; prepared = prepared and viewer.Prepared end
     end
    end
    if remaining == 0 then break end
    if prepared and not results.Started then
     results.Started = true
     local startAt = now + CinematicConfig.Results.StartLeadTime
     deadline = startAt + self:GetResultsDuration()
     for player, viewer in pairs(results.Viewers) do
      if not viewer.Returned then remote:FireClient(player, "Start", { SessionId = sessionId, MatchId = sessionId, StateVersion = results.Version, Token = token, StartAt = startAt }) end
     end
    end
    task.wait(0.1)
   end
   self:CloseSession(sessionId, { Reason = "ResultsCompleted" })
  end, debug.traceback)
  if not ok then
   warn("[RoundService] Results failed: " .. tostring(failure))
   self:CloseSession(sessionId, { Reason = "ResultsError" })
  end
 end)
 return true
end

function RoundService:_runCloseStep(session: MatchSession, key: string, callback: () -> any): boolean
	session.CloseSteps = session.CloseSteps or {}
	session.CloseErrors = session.CloseErrors or {}
	if session.CloseSteps[key] then return true end

	for attempt = 1, 2 do
		local ok, result = pcall(callback)
		if ok and result ~= false then
			session.CloseSteps[key] = true
			session.CloseErrors[key] = nil
			return true
		end
		session.CloseErrors[key] = if ok then "OperationReturnedFalse" else tostring(result)
		warn(string.format("[RoundService] Cierre '%s' falló para '%s' (intento %d/2): %s",
			key, session.Id, attempt, session.CloseErrors[key]))
	end
	return false
end

-- Coordinador único de cierre. Una sesión permanece registrada y sus participantes
-- quedan en cuarentena hasta que todos los recursos críticos se hayan liberado.
-- SessionId is the unique preparation token. Closed preparations cannot be resumed.
function RoundService:CancelPreparationIfOccupancyLost(zoneId: string)
	local matchmaking = self:_getMatchmakingService()
	if not matchmaking then return end
	for _,session in pairs(self._sessionsById) do
		local state=session.State
		if session.ZoneId==zoneId and not session.Closing and not (session :: any).ArenaTransferred
			and (state==Constants.RoundState.MatchReady or state==Constants.RoundState.MatchCountdown
				or state==Constants.RoundState.MapSelection or state==Constants.RoundState.MapLoading)
			and not matchmaking:ArePlayersInZone(zoneId,session.RedTeam,session.BlueTeam) then
			self:CloseSession(session.Id,{Cancelled=true,Reason="PlayerLeftQueuePad"})
		end
	end
end

function RoundService:_closePrematch(session: MatchSession, reason: string?): boolean
	if self._sessionsById[session.Id] ~= session or (session :: any).ArenaTransferred then return false end
	session.Closing = true
	session.Cancelled = true
	(session :: any).PreparationCancelled = true
	session.Votes = {}
	session.RemainingTime = nil
	if session.SessionThread and session.SessionThread ~= coroutine.running() then pcall(task.cancel, session.SessionThread) end
	session.SessionThread = nil
	if session.PointRestartThread then pcall(task.cancel, session.PointRestartThread);session.PointRestartThread=nil end
	-- A failed map preflight may already own an empty clone/slot. No characters were moved.
	local instances = self:_getMatchInstanceService()
	if not self:_runCloseStep(session,"PrematchInstance",function()
		if instances then return instances:DestroyInstance(session.Id) end
		return session.InstanceInfo == nil
	end) then return false end
	session.StateVersion += 1
	self:FireSessionRemote(session.Id,"Match","StateChanged",Constants.RoundState.Waiting,
		self:_applySessionIdentity(session,{PrematchCancelled=true,Reason=reason,CountdownToken=session.Id}))
	clearMatchIdentity(session)
	local matchmaking = self:_getMatchmakingService()
	if matchmaking and matchmaking.ReleasePreparation then matchmaking:ReleasePreparation(session.ZoneId,session.ReservationToken) end
	self:_releaseSession(session)
	self._state = Constants.RoundState.Waiting
	return true
end

function RoundService:CloseSession(sessionId: SessionId, options: any?): boolean
	local session = self._sessionsById[sessionId]
	if not session then return self._closedSessionIds[sessionId] == true end
	if session.Closed then return true end
	options = options or {}
	local preArena = session.State == Constants.RoundState.Waiting
		or session.State == Constants.RoundState.MatchReady or session.State == Constants.RoundState.MatchCountdown
		or session.State == Constants.RoundState.MapSelection or session.State == Constants.RoundState.MapLoading
		or session.State == Constants.RoundState.StartCountdown
	if preArena and not (session :: any).ArenaTransferred and not session.GameplayRound and not session.Results then
		return self:_closePrematch(session,options.Reason)
	end
	if options.DeferCleanup ~= true and session.Results then
		session.Results.Celebrating = false
		if session.Results.FeedbackThread then pcall(task.cancel, session.Results.FeedbackThread); session.Results.FeedbackThread = nil end
		local feedback = self._context and self._context:GetService("PointFeedbackService")
		if feedback then feedback:CleanupMatch(session.Id) end
	end
	if options.DeferCleanup ~= true and session.ResultsThread and session.ResultsThread ~= coroutine.running() then
		pcall(task.cancel, session.ResultsThread)
		session.ResultsThread = nil
	end

	if not session.CloseStarted then
		if session.GameplayRound and not session.GameplayRound.Resolved then session.GameplayRound.Resolved="Closed" end
		self:CancelGameplayRecoveries(session)
		session.CloseStarted = true
		session.Closing = true
		session.Cancelled = options.Cancelled == true
		if session.Result == nil then
			session.Result = options.Result or (if session.Cancelled then Constants.MatchResult.Cancelled else Constants.MatchResult.Draw)
		end
		session.Votes = {}
		session.RemainingTime = nil
		(session :: any).AwardRewards = options.AwardRewards == true

		local runningThread = coroutine.running()
		if session.SessionThread and session.SessionThread ~= runningThread then
			pcall(task.cancel, session.SessionThread)
		end
		session.SessionThread = nil
		if session.PointRestartThread and session.PointRestartThread ~= runningThread then
			pcall(task.cancel, session.PointRestartThread)
		end
		session.PointRestartThread = nil
	end

	local scoreService = self:_getScoreService()
	local beginOk = self:_runCloseStep(session, "StopScoring", function()
		if scoreService then scoreService:StopScoring(session.Id) end
		return true
	end)

	if (session :: any).AwardRewards == true and not session.Cancelled then
		beginOk = self:_runCloseStep(session, "Rewards", function()
			self:_processReward(session, session.Result :: MatchResultName)
				local progression = self._context and self._context:GetService("ProgressionService")
				if progression then progression:Settle(session, session.Result) end
			return true
		end) and beginOk
	end

	if options.DeferCleanup == true then
		return beginOk
	end

	if session.State ~= Constants.RoundState.ReturningToLobby then
		self:SetSessionState(session.Id, Constants.RoundState.ReturningToLobby, { Reason = options.Reason }, true)
	end
	if session.Cancelled and not session.CloseSteps.CancelNotification then
		self:_broadcastCountdown(session.Id, 0, "CANCELLED", { Cancelled = true })
		self:_broadcastResult(session.Id, Constants.MatchResult.Cancelled, nil)
		session.CloseSteps.CancelNotification = true
	end

	local eliminationService = self:_getEliminationService()
	local combatService = self:_getCombatService()
	local slapService = self:_getSlapService()
	local spawnService = self:_getSpawnService()
	local matchInstanceService = self:_getMatchInstanceService()

	local criticalOk = beginOk
	criticalOk = self:_runCloseStep(session, "Abilities", function()
		local abilities = self._context and self._context:GetService("AbilityService")
		if abilities then abilities:CleanupSession(session.Id,"Closed") end
		return true
	end) and criticalOk
	criticalOk = self:_runCloseStep(session, "Eliminations", function()
		if eliminationService then eliminationService:UnbindMatch(session.Id) end
		return true
	end) and criticalOk
	criticalOk = self:_runCloseStep(session, "CombatTags", function()
		if combatService then combatService:ClearMatch(session.Id) end
		return true
	end) and criticalOk
	criticalOk = self:_runCloseStep(session, "RestoreAndReturn", function()
		if session.Results then
			local returned = true
			for player in pairs(session.Results.Viewers) do
				if not self:_returnResultsPlayer(session, player) then returned = false end
			end
			return returned
		end
		if not spawnService then return session.InstanceInfo == nil end
		local participants = spawnService:GetSessionParticipants(session)
		if not session.GameplayRound and (session :: any).TransferredPlayers then
			-- Partial initial transfer: restore only those actually moved; pad occupants stay put.
			participants = {}
			for player in pairs((session :: any).TransferredPlayers) do table.insert(participants,player) end
		end
		return spawnService:ReturnPlayersToLobby(participants, nil)
	end) and criticalOk
	criticalOk = self:_runCloseStep(session, "Slaps", function()
		if slapService then
			local isSimulated = false
			for _, part in ipairs(session.Participants) do
				if typeof(part.Player) == "table" and (part.Player :: any).IsSimulatedPlayer then
					isSimulated = true
					break
				end
			end
			if not isSimulated then
				for _, participant in ipairs(session.Participants) do
					if participant.State ~= "Left" and participant.State ~= "Released" then
						slapService:UnlockPlayer(participant.Player)
						slapService:RemoveSlaps(participant.Player)
					end
				end
			end
		end
		return true
	end) and criticalOk
	criticalOk = self:_runCloseStep(session, "Identity", function()
		clearMatchIdentity(session)
		return true
	end) and criticalOk
	criticalOk = self:_runCloseStep(session, "InstanceAndArenaSlot", function()
			-- A failed physical return retains the scene and slot for quarantine/retry.
			if not criticalOk then return false end
		if matchInstanceService then return matchInstanceService:DestroyInstance(session.Id) end
		return session.InstanceInfo == nil
	end) and criticalOk
	criticalOk = self:_runCloseStep(session, "ScoreResources", function()
		if scoreService then scoreService:CleanupSession(session.Id) end
		return true
	end) and criticalOk

	if not criticalOk then
		warn(string.format("[RoundService] Sesión '%s' permanece en cuarentena; cierre parcial pendiente", session.Id))
		return false
	end

	self:_releaseSession(session)
	self:_setState(Constants.RoundState.Waiting, { Reason = options.Reason })
	print(string.format("[RoundService] Sesión '%s' cerrada sin recursos pendientes", session.Id))
	return true
end

function RoundService:_cancelMatchPreparation(reason: string, sessionId: SessionId?)
	local session = if sessionId then self._sessionsById[sessionId] else self:GetSession()
	if not session or (session.State ~= Constants.RoundState.MatchReady and session.State ~= Constants.RoundState.MatchCountdown) then return end
	self:CloseSession(session.Id, { Cancelled = true, Result = Constants.MatchResult.Cancelled, Reason = reason })
end

function RoundService:_cancelSession(reason: string, sessionId: SessionId?)
	local session = if sessionId then self._sessionsById[sessionId] else self:GetSession()
	if not session then return end
	self:CloseSession(session.Id, { Cancelled = true, Result = Constants.MatchResult.Cancelled, Reason = reason })
end

-- Adaptador interno para consumidores anteriores; todo converge en CloseSession.
function RoundService:_cleanupSession(sessionId: SessionId?)
	local session = if sessionId then self._sessionsById[sessionId] else self:GetSession()
	if session then self:CloseSession(session.Id) end
end

return RoundService
