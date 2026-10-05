--!strict
-- RoundService
-- Maquina de estados del flujo de partida 1v1.
-- Controla el ciclo completo: Waiting -> MatchReady -> MatchCountdown -> MapSelection -> MapLoading -> Playing -> Ending -> ReturningToLobby -> Waiting.
-- NO implementa logica fisica de spawn ni mapas (delegado a SpawnService en fases posteriores).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local HttpService = game:GetService("HttpService")

local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Types = require(ReplicatedStorage.Shared.Types)

type RoundStateName = Types.RoundStateName
type MatchSession = Types.MatchSession
type MatchResultName = Types.MatchResultName

local RoundService = {}
RoundService.Name = "RoundService"

-- Evento / señal para que servicios externos (ej. SpawnService) se suscriban al retorno al lobby
local returnLobbyBindable = Instance.new("BindableEvent")
RoundService.ReturnPlayersToLobby = returnLobbyBindable.Event

-- Estado interno
RoundService._context = nil :: any
RoundService._state = Constants.RoundState.Waiting :: RoundStateName
RoundService._currentSession = nil :: MatchSession?
RoundService._votes = {} :: { [Player]: string }
RoundService._sessionThread = nil :: thread?
RoundService._pointRestartThread = nil :: thread?
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

function RoundService:_ensureRemotes()
	local remotesFolder = ensureRemoteFolder(ReplicatedStorage, "Remotes")
	local matchFolder = ensureRemoteFolder(remotesFolder, "Match")
	local matchmakingFolder = ensureRemoteFolder(remotesFolder, "Matchmaking")

	ensureRemoteEvent(matchFolder, "StateChanged")
	ensureRemoteEvent(matchFolder, "Countdown")
	ensureRemoteEvent(matchFolder, "MapSelection")
	ensureRemoteEvent(matchFolder, "MatchResult")
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
	self._votes = {}
	self._sessionThread = nil
	self._pointRestartThread = nil
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
		table.insert(self._connections, mapSelectionRemote.OnServerEvent:Connect(function(player: Player, mapName: string)
			self:SubmitMapVote(player, mapName)
		end))
	end

	-- Manejar desconexiones de jugadores durante la partida
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

function RoundService:GetState(): RoundStateName
	return self._state
end

function RoundService:GetSession(): MatchSession?
	return self._currentSession
end

function RoundService:GetSessionById(sessionId: string): MatchSession?
	if self._currentSession and self._currentSession.Id == sessionId then
		return self._currentSession
	end
	return nil
end

function RoundService:GetSessionForPlayer(player: Player): MatchSession?
	local session = self._currentSession
	if not session or not player then return nil end

	if session.RedPlayer == player or session.BluePlayer == player then
		return session
	end

	if session.RedTeam then
		for _, p in ipairs(session.RedTeam) do
			if p == player then return session end
		end
	end

	if session.BlueTeam then
		for _, p in ipairs(session.BlueTeam) do
			if p == player then return session end
		end
	end

	return nil
end

function RoundService:IsAvailable(): boolean
	return self._state == Constants.RoundState.Waiting and self._currentSession == nil
end

function RoundService:GetAvailableMaps(): { string }
	local mapsFolder = ServerStorage:FindFirstChild("Maps")
	if not mapsFolder then
		return {}
	end

	local maps = {}
	for _, child in ipairs(mapsFolder:GetChildren()) do
		if child:IsA("Model") or child:IsA("Folder") then
			table.insert(maps, child.Name)
		end
	end
	table.sort(maps)
	return maps
end

function RoundService:_setState(newState: RoundStateName, extraData: any?)
	self._state = newState
	if self._currentSession then
		self._currentSession.State = newState
	end
	print(string.format("[RoundService] Estado cambiado a: %s", newState))

	local remote = self:_getRemote("Match", "StateChanged")
	if remote then
		remote:FireAllClients(newState, extraData or {})
	end
end

function RoundService:_broadcastCountdown(remaining: number, label: string, payload: any?)
	local remote = self:_getRemote("Match", "Countdown")
	if remote then
		remote:FireAllClients(remaining, label, payload)
	end
end

function RoundService:_broadcastResult(result: string, winnerName: string?)
	local remote = self:_getRemote("Match", "MatchResult")
	if remote then
		remote:FireAllClients(result, winnerName)
	end
end

function RoundService:SubmitMapVote(player: Player, mapName: string): boolean
	if not self._currentSession or self._state ~= Constants.RoundState.MapSelection then
		return false
	end

	if player ~= self._currentSession.RedPlayer and player ~= self._currentSession.BluePlayer then
		return false
	end

	local availableMaps = self:GetAvailableMaps()
	local isRandom = (mapName == Constants.SpecialMapVote.Random or mapName == "Aleatorio")
	local isValidMap = table.find(availableMaps, mapName) ~= nil

	if not isRandom and not isValidMap then
		return false
	end

	self._votes[player] = isRandom and Constants.SpecialMapVote.Random or mapName

	local remote = self:_getRemote("Match", "MapSelection")
	if remote then
		remote:FireClient(player, { Voted = self._votes[player] })
	end

	return true
end

function RoundService:_isSessionValid(sessionId: string): boolean
	if not self._currentSession then
		return false
	end
	if self._currentSession.Id ~= sessionId then
		return false
	end
	return true
end

function RoundService:StartMatch(redPlayer: Player, bluePlayer: Player, matchmakingZoneId: string?): boolean
	if not self:IsAvailable() then
		warn(string.format("[RoundService] No se puede iniciar match, estado actual: %s", self._state))
		return false
	end

	if not redPlayer or not bluePlayer or redPlayer == bluePlayer then
		warn("[RoundService] Jugadores invalidos para 1v1")
		return false
	end

	local sessionId = HttpService:GenerateGUID(false)
	local session: MatchSession = {
		Id = sessionId,
		Mode = "1v1",
		RedPlayer = redPlayer,
		BluePlayer = bluePlayer,
		RedTeam = { redPlayer },
		BlueTeam = { bluePlayer },
		SelectedMap = nil,
		Result = nil,
		StartTime = nil,
		State = Constants.RoundState.MatchReady,
		Score = { Red = 0, Blue = 0 },
		MatchmakingZoneId = matchmakingZoneId,
	}

	self._currentSession = session
	self._votes = {}

	self._sessionThread = task.spawn(function()
		self:_runSession(sessionId)
	end)

	return true
end

function RoundService:_resolveMap(availableMaps: { string }): string
	local session = self._currentSession
	if not session or #availableMaps == 0 then
		return ""
	end

	local redVote = self._votes[session.RedPlayer]
	local blueVote = self._votes[session.BluePlayer]

	local isRedRandom = (redVote == Constants.SpecialMapVote.Random or redVote == "Aleatorio")
	local isBlueRandom = (blueVote == Constants.SpecialMapVote.Random or blueVote == "Aleatorio")

	local redChosen = if (redVote and not isRedRandom and table.find(availableMaps, redVote)) then redVote else nil
	local blueChosen = if (blueVote and not isBlueRandom and table.find(availableMaps, blueVote)) then blueVote else nil

	-- Regla 3: Si alguno elige "Aleatorio" -> Random entre TODOS los mapas disponibles
	if isRedRandom or isBlueRandom then
		return availableMaps[math.random(1, #availableMaps)]
	end

	-- Regla 1: Ambos eligen el mismo mapa
	if redChosen and blueChosen and redChosen == blueChosen then
		return redChosen
	end

	-- Regla 2: Cada uno elige un mapa diferente -> Random entre los dos votados
	if redChosen and blueChosen and redChosen ~= blueChosen then
		return if math.random(1, 2) == 1 then redChosen else blueChosen
	end

	-- Un solo jugador voto un mapa especifico y el otro no voto
	if redChosen and not blueChosen then
		return redChosen
	end
	if blueChosen and not redChosen then
		return blueChosen
	end

	-- Regla 4: Nadie selecciona nada -> Random entre todos los mapas disponibles
	return availableMaps[math.random(1, #availableMaps)]
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

function RoundService:_runSession(sessionId: string)
	local session = self._currentSession
	if not session or session.Id ~= sessionId then return end

	local redSnap = getTeamPlayerSnapshots(session.RedTeam or { session.RedPlayer })
	local blueSnap = getTeamPlayerSnapshots(session.BlueTeam or { session.BluePlayer })

	-- 1. MATCH_READY
	self:_setState(Constants.RoundState.MatchReady, {
		Red = session.RedPlayer.Name,
		Blue = session.BluePlayer.Name,
		RedTeam = redSnap,
		BlueTeam = blueSnap,
	})
	task.wait(0.5)
	if not self:_isSessionValid(sessionId) then return end

	-- 2. MATCH_COUNTDOWN (5 segundos)
	local countdownTime = Config.Round.MatchCountdownTime
	self:_setState(Constants.RoundState.MatchCountdown, { Duration = countdownTime })
	for t = countdownTime, 1, -1 do
		self:_broadcastCountdown(t, "LA PARTIDA COMIENZA EN")
		task.wait(1)
		if not self:_isSessionValid(sessionId) then return end
	end
	self:_broadcastCountdown(0, "LA PARTIDA COMIENZA EN")

	-- 3. MAP_SELECTION (5 segundos)
	local availableMaps = self:GetAvailableMaps()
	if #availableMaps == 0 then
		warn("[RoundService] No maps available.")
		self:_cancelSession("NoMapsAvailable")
		return
	end

	local mapSelectionTime = Config.Round.MapSelectionTime
	self:_setState(Constants.RoundState.MapSelection, {
		Maps = availableMaps,
		Duration = mapSelectionTime,
	})

	local mapSelectionRemote = self:_getRemote("Match", "MapSelection")
	if mapSelectionRemote then
		mapSelectionRemote:FireAllClients({
			Maps = availableMaps,
			Duration = mapSelectionTime,
		})
	end

	for t = mapSelectionTime, 1, -1 do
		self:_broadcastCountdown(t, "ELIGE UN MAPA")
		task.wait(1)
		if not self:_isSessionValid(sessionId) then return end
	end
	self:_broadcastCountdown(0, "ELIGE UN MAPA")

	-- 4. RESOLUCION DE MAPA
	local selectedMap = self:_resolveMap(availableMaps)
	session.SelectedMap = selectedMap
	print(string.format("[RoundService] Selected map: %s", selectedMap))

	-- 5. MAP_LOADING
	self:_setState(Constants.RoundState.MapLoading, { SelectedMap = selectedMap })

	local matchInstanceService = self:_getMatchInstanceService()
	if matchInstanceService then
		local instanceInfo = matchInstanceService:CreateInstance(session, selectedMap)
		if not instanceInfo then
			warn(string.format("[RoundService] No se pudo instanciar fisicamente el mapa '%s'", selectedMap))
			self:_cancelSession("MapInstanceCreationFailed")
			return
		end
		session.InstanceInfo = instanceInfo

		-- Validar contrato ZoneWin en la instancia clonada
		local scoreService = self:_getScoreService()
		if scoreService then
			local isValidZone = scoreService:ValidateZoneWin(session)
			if not isValidZone then
				warn(string.format("[RoundService] Missing or invalid ZoneWin contract for match '%s'", sessionId))
				self:_cancelSession("ZoneWinValidationFailed")
				return
			end
		end
	else
		local mapFolder = ServerStorage:FindFirstChild("Maps")
		local mapInstance = mapFolder and mapFolder:FindFirstChild(selectedMap)
		if not mapInstance then
			warn(string.format("[RoundService] Map '%s' not found in ServerStorage.Maps", selectedMap))
			self:_cancelSession("MapInstanceNotFound")
			return
		end
	end

	-- Posicionamiento de jugadores en spawns de la arena aislada
	local spawnService = self:_getSpawnService()
	if spawnService then
		local spawned = spawnService:SpawnMatchPlayers(session)
		if not spawned then
			warn(string.format("[RoundService] SpawnService no pudo posicionar a los jugadores para la partida '%s'", sessionId))
			self:_cancelSession("SpawnPlayersFailed")
			return
		end
	else
		warn("[RoundService] SpawnService no disponible durante MapLoading")
	end

	task.wait(1)
	if not self:_isSessionValid(sessionId) then return end

	-- 5.5 START_COUNTDOWN (Config.Match.StartCountdownTime, por defecto 5 segundos)
	-- Jugadores ya posicionados en spawns, arena cargada, scoring y match timer NO activos
	local startCountdownTime = (Config.Match and Config.Match.StartCountdownTime) or 5
	self:_setState(Constants.RoundState.StartCountdown, {
		MatchId = sessionId,
		Duration = startCountdownTime,
		Red = session.RedPlayer.Name,
		Blue = session.BluePlayer.Name,
		RedTeam = redSnap,
		BlueTeam = blueSnap,
	})

	-- Equipar Slaps autoritativos para la partida
	local slapService = self:_getSlapService()
	if slapService then
		slapService:EquipMatchPlayers(session)
	end

	for t = startCountdownTime, 1, -1 do
		self:_broadcastCountdown(t, "START_COUNTDOWN", {
			MatchId = sessionId,
			Value = t,
			Started = false,
		})
		task.wait(1)
		if not self:_isSessionValid(sessionId) then return end
	end

	-- Emisión final autoritativa de inicio ("GO" / Value=0, Started=true)
	self:_broadcastCountdown(0, "START_COUNTDOWN", {
		MatchId = sessionId,
		Value = 0,
		Started = true,
	})
	task.wait(0.5)
	if not self:_isSessionValid(sessionId) then return end

	-- 6. PLAYING (300 segundos = 5 minutos)
	-- El timer oficial de partida (RoundDuration) y el ScoreService comienzan estrictamente al entrar en Playing
	session.StartTime = os.clock()
	local roundDuration = Config.Round.RoundDuration
	self:_setState(Constants.RoundState.Playing, {
		MatchId = sessionId,
		Duration = roundDuration,
		SelectedMap = selectedMap,
		Red = session.RedPlayer.Name,
		Blue = session.BluePlayer.Name,
		RedTeam = redSnap,
		BlueTeam = blueSnap,
	})

	-- Iniciar scoring autoritativo
	local scoreService = self:_getScoreService()
	if scoreService then
		scoreService:StartScoring(session)
	end

	-- Iniciar seguimiento de respawn contextual en arena durante Playing
	local spawnService = self:_getSpawnService()
	if spawnService then
		spawnService:StartMatchRespawnTracking(session)
	end

	-- Iniciar detección y resolución de eliminaciones autoritativas
	local eliminationService = self:_getEliminationService()
	if eliminationService then
		eliminationService:BindMatch(session)
	end

	local elapsed = 0
	while elapsed < roundDuration do
		if not self:_isSessionValid(sessionId) then return end
		if session.Result ~= nil then
			-- Ganador definido antes de tiempo (por WinningScore, combate o abandono)
			break
		end

		-- Si la partida está en pausa entre puntos (PointRestartCountdown), pausar el avance del match timer
		if self._state == Constants.RoundState.PointRestartCountdown then
			task.wait(0.2)
			continue
		end

		local remaining = roundDuration - elapsed
		self:_broadcastCountdown(remaining, "PLAYING")
		task.wait(1)
		elapsed += 1
	end

	if not self:_isSessionValid(sessionId) then return end

	-- 7. CONDICION DE FINALIZACION: DETERMINAR GANADOR SI EL TIMER LLEGO A 0
	if session.Result == nil then
		local winnerResult = if scoreService then scoreService:GetWinner(session) else Constants.MatchResult.Draw
		session.Result = winnerResult
		print(string.format("[RoundService] Tiempo agotado. Resultado determinado por score final: %s", tostring(winnerResult)))
	end

	-- 8. ENDING
	local result = session.Result or Constants.MatchResult.Draw

	-- Detener scoring
	if scoreService then
		scoreService:StopScoring(session.Id)
	end

	-- Detener eliminaciones autoritativas y limpiar combate del match
	local eliminationService = self:_getEliminationService()
	if eliminationService then
		eliminationService:UnbindMatch(session.Id)
	end
	local combatService = self:_getCombatService()
	if combatService then
		combatService:ClearMatch(session.Id)
	end

	-- Detener respawn en arena al finalizar Playing
	if spawnService then
		spawnService:StopMatchRespawnTracking(session.Id)
	end

	-- Hook preparado para entrega de recompensas
	self:_processReward(session, result)

	local winnerName = nil
	if result == Constants.MatchResult.Red and session.RedPlayer then
		winnerName = session.RedPlayer.Name
	elseif result == Constants.MatchResult.Blue and session.BluePlayer then
		winnerName = session.BluePlayer.Name
	end

	self:_setState(Constants.RoundState.Ending, {
		Result = result,
		Winner = winnerName,
	})
	self:_broadcastResult(result, winnerName)

	task.wait(Config.Round.EndingDisplayTime or 4)
	if not self:_isSessionValid(sessionId) then return end

	-- 9. RETURNING_TO_LOBBY
	self:_setState(Constants.RoundState.ReturningToLobby)

	-- Retornar a los jugadores al lobby ANTES de destruir la arena
	returnLobbyBindable:Fire({
		RedPlayer = session.RedPlayer,
		BluePlayer = session.BluePlayer,
		Session = session,
	})

	-- Retirar Slaps de combate al retornar al lobby
	local slapService = self:_getSlapService()
	if slapService then
		slapService:RemoveMatchPlayers(session)
	end

	local spawnService = self:_getSpawnService()
	if spawnService then
		spawnService:ReturnPlayersToLobby(session.RedPlayer, session.BluePlayer)
	end

	-- Destruir la instancia fisica del mapa y liberar el ArenaSlot
	local matchInstanceService = self:_getMatchInstanceService()
	if matchInstanceService and session then
		matchInstanceService:DestroyInstance(session.Id)
	end

	local lobby = workspace:FindFirstChild("Lobby")
	local spawnLocation = lobby and lobby:FindFirstChild("SpawnLocation")
	if not spawnLocation then
		warn("[RoundService] Lobby SpawnLocation not found")
	end

	task.wait(Config.Round.ReturnToLobbyTime or 2)

	-- 10. LIMPIEZA Y REGRESO A WAITING
	self:_cleanupSession()
	self:_setState(Constants.RoundState.Waiting)
end

-- Inicia la secuencia autoritativa de PointRestartCountdown (3 segundos) tras un punto anotado
function RoundService:TriggerPointRestart(session: MatchSession)
	local sessionId = session.Id
	if not self:_isSessionValid(sessionId) then return end
	if self._state ~= Constants.RoundState.Playing then return end

	-- Cancelar cualquier hilo previo si existiera
	if self._pointRestartThread then
		pcall(task.cancel, self._pointRestartThread)
		self._pointRestartThread = nil
	end

	self._pointRestartThread = task.spawn(function()
		local delayTime = (Config.Match and Config.Match.PointResetDelay) or 1.5
		task.wait(delayTime)

		if not self:_isSessionValid(sessionId) or session.Result ~= nil then return end

		-- Reposicionar ambos equipos en sus spawns respectivos de la arena activa
		local spawnService = self:_getSpawnService()
		if spawnService then
			spawnService:SpawnMatchPlayers(session)
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
		self:_setState(Constants.RoundState.PointRestartCountdown, {
			MatchId = sessionId,
			Duration = countdownTime,
			Red = session.RedPlayer and session.RedPlayer.Name,
			Blue = session.BluePlayer and session.BluePlayer.Name,
			RedTeam = redSnap,
			BlueTeam = blueSnap,
		})

		-- Cuenta regresiva autoritativa: 3 -> 2 -> 1
		for t = countdownTime, 1, -1 do
			self:_broadcastCountdown(t, "START_COUNTDOWN", {
				MatchId = sessionId,
				Value = t,
				Started = false,
				Phase = "PointRestart",
			})
			task.wait(1)
			if not self:_isSessionValid(sessionId) or session.Result ~= nil then return end
		end

		-- Emisión final clímax: ¡COMIENZA! (Value = 0, Started = true)
		self:_broadcastCountdown(0, "START_COUNTDOWN", {
			MatchId = sessionId,
			Value = 0,
			Started = true,
			Phase = "PointRestart",
		})
		task.wait(0.5)
		if not self:_isSessionValid(sessionId) or session.Result ~= nil then return end

		-- Retorno autoritativo al estado Playing
		self:_setState(Constants.RoundState.Playing, {
			MatchId = sessionId,
			Duration = Config.Round.RoundDuration,
			SelectedMap = session.SelectedMap,
			Red = session.RedPlayer and session.RedPlayer.Name,
			Blue = session.BluePlayer and session.BluePlayer.Name,
			RedTeam = redSnap,
			BlueTeam = blueSnap,
		})

		-- Limpiar explícitamente el estado de PointScorer al reanudar combate
		session.PointInProgress = false
		session.PointScorer = nil
		session.PointScorerTeam = nil
		session.PointScoreTimestamp = nil
		session.PointNumber = nil

		-- Reanudar scoring en ScoreService
		if scoreService then
			scoreService:ResumeScoring(sessionId)
		end

		self._pointRestartThread = nil
		print(string.format("[RoundService] PointRestartCountdown completado para Match '%s'. Partida reanudada en PLAYING.", sessionId))
	end)
end

function RoundService:DeclareWinner(winner: MatchResultName)
	if not self._currentSession or (self._state ~= Constants.RoundState.Playing and self._state ~= Constants.RoundState.PointRestartCountdown) then
		return
	end
	if self._pointRestartThread then
		pcall(task.cancel, self._pointRestartThread)
		self._pointRestartThread = nil
	end
	self._currentSession.Result = winner
	print(string.format("[RoundService] Ganador declarado: %s", tostring(winner)))
end

-- Hook de entrega de recompensas y estadísticas server-authoritative
function RoundService:_processReward(session: MatchSession, result: MatchResultName)
	self._rewardedMatches = self._rewardedMatches or {}
	local matchId = session.Id or (session :: any).MatchId or "UNKNOWN_MATCH"
	if self._rewardedMatches[matchId] then
		print(string.format("[RoundService] Match '%s' ya fue recompensado previamente. Omitiendo duplicado.", matchId))
		return
	end
	self._rewardedMatches[matchId] = true

	local playerService = self:_getPlayerService()
	if playerService then
		if result == Constants.MatchResult.Red then
			-- Red gana (+1 Win), Blue pierde (+1 Loss)
			if session.RedTeam then
				for _, p in ipairs(session.RedTeam) do playerService:AddWin(p, "MatchWin") end
			elseif session.RedPlayer then
				playerService:AddWin(session.RedPlayer, "MatchWin")
			end

			if session.BlueTeam then
				for _, p in ipairs(session.BlueTeam) do playerService:AddLoss(p, "MatchLoss") end
			elseif session.BluePlayer then
				playerService:AddLoss(session.BluePlayer, "MatchLoss")
			end
		elseif result == Constants.MatchResult.Blue then
			-- Blue gana (+1 Win), Red pierde (+1 Loss)
			if session.BlueTeam then
				for _, p in ipairs(session.BlueTeam) do playerService:AddWin(p, "MatchWin") end
			elseif session.BluePlayer then
				playerService:AddWin(session.BluePlayer, "MatchWin")
			end

			if session.RedTeam then
				for _, p in ipairs(session.RedTeam) do playerService:AddLoss(p, "MatchLoss") end
			elseif session.RedPlayer then
				playerService:AddLoss(session.RedPlayer, "MatchLoss")
			end
		end
		-- Draw o Cancelled: no otorgan Win ni Loss
	else
		warn("[RoundService] PlayerService no disponible al procesar recompensas")
	end

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
	local session = self._currentSession
	if not session then return end
	if player ~= session.RedPlayer and player ~= session.BluePlayer then return end

	print(string.format("[RoundService] Jugador desconectado: %s durante estado %s", player.Name, self._state))

	if self._state == Constants.RoundState.Playing or self._state == Constants.RoundState.PointRestartCountdown then
		-- Si abandona durante PLAYING o PointRestartCountdown, el otro jugador es el ganador
		local winner: MatchResultName = if player == session.RedPlayer
			then Constants.MatchResult.Blue
			else Constants.MatchResult.Red

		session.Result = winner
		if self._pointRestartThread then
			pcall(task.cancel, self._pointRestartThread)
			self._pointRestartThread = nil
		end
		print(string.format("[RoundService] Partida finalizada por abandono. Ganador: %s", winner))
		-- El loop de PLAYING detectará session.Result ~= nil en el siguiente tick y pasará a Ending
	elseif self._state == Constants.RoundState.MatchReady
		or self._state == Constants.RoundState.MatchCountdown
		or self._state == Constants.RoundState.MapSelection
		or self._state == Constants.RoundState.MapLoading
		or self._state == Constants.RoundState.StartCountdown then
		-- Si abandona antes de PLAYING, cancelar la sesión y volver a Waiting
		self:_cancelSession("PlayerDisconnected")
	end
end

function RoundService:_cancelSession(reason: string)
	print(string.format("[RoundService] Sesion cancelada. Motivo: %s", reason))
	local runningThread = coroutine.running()
	if self._sessionThread and self._sessionThread ~= runningThread then
		pcall(task.cancel, self._sessionThread)
		self._sessionThread = nil
	end
	if self._pointRestartThread and self._pointRestartThread ~= runningThread then
		pcall(task.cancel, self._pointRestartThread)
		self._pointRestartThread = nil
	end

	local session = self._currentSession
	if session then
		returnLobbyBindable:Fire({
			RedPlayer = session.RedPlayer,
			BluePlayer = session.BluePlayer,
			Session = session,
			Reason = reason,
		})

		local spawnService = self:_getSpawnService()
		if spawnService then
			spawnService:StopMatchRespawnTracking(session.Id)
			spawnService:ReturnPlayersToLobby(session.RedPlayer, session.BluePlayer)
		end

		local matchInstanceService = self:_getMatchInstanceService()
		if matchInstanceService then
			matchInstanceService:DestroyInstance(session.Id)
		end

		local scoreService = self:_getScoreService()
		if scoreService then
			scoreService:CleanupSession(session.Id)
		end

		local eliminationService = self:_getEliminationService()
		if eliminationService then
			eliminationService:UnbindMatch(session.Id)
		end

		local combatService = self:_getCombatService()
		if combatService then
			combatService:ClearMatch(session.Id)
		end

		session.Result = Constants.MatchResult.Cancelled
		self:_broadcastResult(Constants.MatchResult.Cancelled, nil)
	end

	self:_setState(Constants.RoundState.ReturningToLobby, { Reason = reason })
	task.wait(1)
	self:_cleanupSession()
	self:_setState(Constants.RoundState.Waiting)
end

function RoundService:_cleanupSession()
	if self._currentSession then
		local spawnService = self:_getSpawnService()
		if spawnService then
			spawnService:StopMatchRespawnTracking(self._currentSession.Id)
		end

		local matchInstanceService = self:_getMatchInstanceService()
		if matchInstanceService then
			matchInstanceService:DestroyInstance(self._currentSession.Id)
		end

		local scoreService = self:_getScoreService()
		if scoreService then
			scoreService:CleanupSession(self._currentSession.Id)
		end
	end

	self._currentSession = nil
	self._votes = {}
	local runningThread = coroutine.running()
	if self._sessionThread then
		if self._sessionThread ~= runningThread then
			pcall(task.cancel, self._sessionThread)
		end
		self._sessionThread = nil
	end
	if self._pointRestartThread then
		if self._pointRestartThread ~= runningThread then
			pcall(task.cancel, self._pointRestartThread)
		end
		self._pointRestartThread = nil
	end
end

return RoundService
