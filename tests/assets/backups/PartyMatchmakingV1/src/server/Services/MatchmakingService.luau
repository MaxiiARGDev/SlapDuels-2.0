--!strict
-- MatchmakingService
-- Gestiona la detección de jugadores en zonas de matchmaking genéricas (1v1, 2v2, 3v3),
-- construye el QueueSnapshot autoritativo, controla la capacidad por equipo y despacha
-- partidas hacia RoundService.
-- La instancia física (zoneFolder) es la identidad primaria interna de la zona.
-- NO se encarga de efectos audiovisuales (delegado a MatchmakingFeedbackService)
-- ni de la presentación visual del HUD (delegado a MatchmakingController).

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

type QueueSnapshot = Types.QueueSnapshot
type MatchmakingZoneConfig = Types.MatchmakingZoneConfig
type QueueStateName = Types.QueueStateName

export type ZoneData = {
	ZoneId: string,
	Instance: Folder,
	ZoneName: string,
	Config: MatchmakingZoneConfig,
	RedPads: { BasePart },
	BluePads: { BasePart },
	PadOccupants: { [BasePart]: { Player } },
	OccupantLastSeen: { [Player]: number },
	CandidateArrivals: { [Player]: number },
	CandidateLastSeen: { [Player]: number },
	CurrentRed: { Player },
	CurrentBlue: { Player },
	State: QueueStateName,
	ActiveReservation: Types.TeamMatchReservation?,
	LastModeNotPlayableWarn: string?,
}

local MatchmakingService = {}
MatchmakingService.Name = "MatchmakingService"

MatchmakingService._context = nil :: any
MatchmakingService._zones = {} :: { [Folder]: ZoneData }
MatchmakingService._latestSnapshots = {} :: { [string]: QueueSnapshot }
MatchmakingService._checkConnection = nil :: RBXScriptConnection?
MatchmakingService._lastCheck = 0
MatchmakingService._queueStatusRemote = nil :: RemoteEvent?
MatchmakingService._containerConnections = {} :: { RBXScriptConnection }
MatchmakingService._testCharacterMap = {} :: { [Model]: any }

-- Obtiene el Player asociado a una parte de un personaje
local function getPlayerFromPart(part: BasePart): Player?
	local current: Instance? = part
	while current and current ~= workspace do
		if current:IsA("Model") then
			local player = Players:GetPlayerFromCharacter(current)
			if player then
				return player
			end
			if MatchmakingService._testCharacterMap and MatchmakingService._testCharacterMap[current] then
				return MatchmakingService._testCharacterMap[current]
			end
		end
		current = current.Parent
	end
	return nil
end

local PAD_DETECTION_HEIGHT = 6.0
local OCCUPANT_GRACE_PERIOD = 0.8 -- Segundos de gracia para tolerar saltos y fluctuaciones espaciales

-- Valida si un jugador está conectado, con personaje instanciado en workspace y Humanoid vivo
local function isPlayerAliveAndValid(player: any): boolean
	local isRealPlayer = typeof(player) == "Instance" and player:IsA("Player") and player:IsDescendantOf(Players)
	local isSimulated = typeof(player) == "table" and player.IsSimulatedPlayer == true
	if not isRealPlayer and not isSimulated then return false end

	local character = player.Character
	if not character or not character:IsDescendantOf(workspace) then return false end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end
	return true
end

-- Detecta los jugadores físicos dentro del volumen de un pad usando GetPartBoundsInBox
local function getPhysicallyPresentPlayersOnPad(pad: BasePart, overlapParams: OverlapParams): { Player }
	local boxCFrame = pad.CFrame * CFrame.new(0, (pad.Size.Y / 2) + (PAD_DETECTION_HEIGHT / 2), 0)
	local boxSize = Vector3.new(pad.Size.X, PAD_DETECTION_HEIGHT, pad.Size.Z)
	local touchingParts = workspace:GetPartBoundsInBox(boxCFrame, boxSize, overlapParams)

	local presentList: { Player } = {}
	local seen: { [Player]: boolean } = {}

	for _, part in ipairs(touchingParts) do
		local player = getPlayerFromPart(part)
		if player and not seen[player] then
			if isPlayerAliveAndValid(player) then
				seen[player] = true
				table.insert(presentList, player)
			end
		end
	end

	return presentList
end

-- Actualiza autoritativamente la ocupación de un conjunto de pads (equipo) aplicando
-- prioridad por orden de llegada (FIFO), reserva por plaza, grace period y prevención de doble ocupación.
local function updateTeamOccupants(
	zone: ZoneData,
	pads: { BasePart },
	maxTeamCapacity: number,
	otherTeamOccupantsSet: { [Player]: boolean },
	overlapParams: OverlapParams,
	now: number,
	service: any
): { Player }
	if #pads == 0 or maxTeamCapacity <= 0 then
		return {}
	end

	local padCapacity = math.max(1, math.ceil(maxTeamCapacity / #pads))

	-- 1. Detección física en cada pad del equipo
	local presentByPad: { [BasePart]: { [Player]: boolean } } = {}
	local allPresentOnTeam: { [Player]: boolean } = {}

	for _, pad in ipairs(pads) do
		local presentList = getPhysicallyPresentPlayersOnPad(pad, overlapParams)
		local padSet: { [Player]: boolean } = {}
		for _, p in ipairs(presentList) do
			padSet[p] = true
			allPresentOnTeam[p] = true
		end
		presentByPad[pad] = padSet
	end

	-- 2. Retención de ocupantes existentes (con grace period)
	local assignedThisTeam: { [Player]: boolean } = {}
	local teamOccupantsList: { Player } = {}

	for _, pad in ipairs(pads) do
		local currentOccupants = zone.PadOccupants[pad] or {}
		local retained: { Player } = {}
		local presentSet = presentByPad[pad] or {}

		for _, occupant in ipairs(currentOccupants) do
			if not isPlayerAliveAndValid(occupant) then
				-- Jugador muerto o desconectado: liberación inmediata sin periodo de gracia
				zone.OccupantLastSeen[occupant] = nil
				zone.CandidateArrivals[occupant] = nil
				zone.CandidateLastSeen[occupant] = nil
			elseif assignedThisTeam[occupant] or otherTeamOccupantsSet[occupant] then
				-- Conflicto: ya asignado a otra plaza o al equipo contrario
				zone.OccupantLastSeen[occupant] = nil
				zone.CandidateArrivals[occupant] = nil
				zone.CandidateLastSeen[occupant] = nil
			else
				if presentSet[occupant] then
					-- Físicamente presente: retiene plaza y actualiza marca temporal
					zone.OccupantLastSeen[occupant] = now
					assignedThisTeam[occupant] = true
					table.insert(retained, occupant)
					table.insert(teamOccupantsList, occupant)
				else
					-- Ausente físicamente en este frame: comprobar periodo de gracia (tolerancia a saltos/jitter)
					local lastSeen = zone.OccupantLastSeen[occupant] or 0
					if (now - lastSeen) <= OCCUPANT_GRACE_PERIOD then
						assignedThisTeam[occupant] = true
						table.insert(retained, occupant)
						table.insert(teamOccupantsList, occupant)
					else
						-- Gracia expirada: abandono confirmado, liberar plaza
						zone.OccupantLastSeen[occupant] = nil
						zone.CandidateArrivals[occupant] = nil
						zone.CandidateLastSeen[occupant] = nil
					end
				end
			end
		end

		zone.PadOccupants[pad] = retained
	end

	-- 3. Registro de candidatos esperando en los pads
	for _, pad in ipairs(pads) do
		local presentSet = presentByPad[pad] or {}
		for p in pairs(presentSet) do
			if not assignedThisTeam[p] and not otherTeamOccupantsSet[p] then
				if not service:_isPlayerOccupantInOtherZone(p, zone) then
					if zone.CandidateArrivals[p] == nil then
						zone.CandidateArrivals[p] = now
					end
					zone.CandidateLastSeen[p] = now
				end
			end
		end
	end

	-- 4. Asignación de plazas disponibles por orden de llegada (FIFO)
	for _, pad in ipairs(pads) do
		local retained = zone.PadOccupants[pad] or {}
		local padSlotsAvailable = padCapacity - #retained
		local teamSlotsAvailable = maxTeamCapacity - #teamOccupantsList

		if padSlotsAvailable > 0 and teamSlotsAvailable > 0 then
			local presentSet = presentByPad[pad] or {}
			local candidates: { Player } = {}

			for p in pairs(presentSet) do
				if not assignedThisTeam[p]
					and not otherTeamOccupantsSet[p]
					and not service:_isPlayerOccupantInOtherZone(p, zone)
					and not table.find(retained, p) then
					table.insert(candidates, p)
				end
			end

			-- Ordenar candidatos por orden de llegada estricto
			table.sort(candidates, function(a, b)
				local timeA = zone.CandidateArrivals[a] or math.huge
				local timeB = zone.CandidateArrivals[b] or math.huge
				if timeA == timeB then
					return a.UserId < b.UserId
				end
				return timeA < timeB
			end)

			local toAssign = math.min(padSlotsAvailable, teamSlotsAvailable, #candidates)
			for i = 1, toAssign do
				local chosen = candidates[i]
				table.insert(retained, chosen)
				table.insert(teamOccupantsList, chosen)
				assignedThisTeam[chosen] = true
				zone.OccupantLastSeen[chosen] = now
			end

			zone.PadOccupants[pad] = retained
		end
	end

	-- 5. Limpieza de candidatos que se retiraron (respetando gracia para evitar pérdida por salto)
	for candidate, lastSeen in pairs(zone.CandidateLastSeen) do
		if not allPresentOnTeam[candidate] and not assignedThisTeam[candidate] then
			if (now - lastSeen) > OCCUPANT_GRACE_PERIOD then
				zone.CandidateArrivals[candidate] = nil
				zone.CandidateLastSeen[candidate] = nil
			end
		end
	end

	return teamOccupantsList
end

-- Attributes describe an authorized mode; they never define a new mode or its capacity.
local function getZoneConfiguration(zoneFolder: Folder): (MatchmakingZoneConfig?, string?)
	local modeAttr = zoneFolder:GetAttribute("Mode")
	local teamSizeAttr = zoneFolder:GetAttribute("TeamSize")
	local maxPerTeamAttr = zoneFolder:GetAttribute("MaxPlayersPerTeam")
	local totalAttr = zoneFolder:GetAttribute("TotalPlayers")

	local modeName = if type(modeAttr) == "string" and modeAttr ~= "" then modeAttr else zoneFolder.Name
	local configDefaults = Config.Matchmaking and Config.Matchmaking.Modes and Config.Matchmaking.Modes[modeName]

	if not configDefaults then return nil, "UnknownMode" end
	for _, entry in ipairs({
		{ Value = teamSizeAttr, Expected = configDefaults.TeamSize },
		{ Value = maxPerTeamAttr, Expected = configDefaults.MaxPlayersPerTeam },
		{ Value = totalAttr, Expected = configDefaults.TotalPlayers },
	}) do
		if entry.Value ~= nil and entry.Value ~= entry.Expected then
			return nil, "ModeCapacityMismatch"
		end
	end

	return {
		Mode = modeName,
		TeamSize = configDefaults.TeamSize,
		MaxPlayersPerTeam = configDefaults.MaxPlayersPerTeam,
		TotalPlayers = configDefaults.TotalPlayers,
	}
end

-- Verifica si un ZoneId ya está tomado por otra zona activa
function MatchmakingService:_isZoneIdTaken(zoneId: string, currentFolder: Folder): boolean
	for folder, data in pairs(self._zones) do
		if folder ~= currentFolder and data.ZoneId == zoneId then
			return true
		end
	end
	return false
end

-- Verifica si un jugador ya ocupa autoritativamente un pad en otra zona diferente
function MatchmakingService:_isPlayerOccupantInOtherZone(player: Player, currentZone: ZoneData): boolean
	for _, zone in pairs(self._zones) do
		if zone ~= currentZone then
			if table.find(zone.CurrentRed, player) or table.find(zone.CurrentBlue, player) then
				return true
			end
		end
	end
	return false
end

function MatchmakingService:Init(context)
	self._context = context
	self._zones = {}
	self._latestSnapshots = {}
	self._containerConnections = {}
	_G.MatchmakingService = self

	-- Garantizar Remote de estado de cola
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local mmFolder = remotes and remotes:FindFirstChild("Matchmaking")
	local queueRemote = mmFolder and mmFolder:FindFirstChild("QueueStatus")
	if queueRemote and queueRemote:IsA("RemoteEvent") then
		self._queueStatusRemote = queueRemote
	end

	-- Descubrir zonas en Workspace.ZoneMatchmaking
	local zoneContainer = workspace:FindFirstChild("ZoneMatchmaking")
	if not zoneContainer then
		warn("[MatchmakingService] No se encontro Workspace.ZoneMatchmaking")
		return
	end

	-- Registrar todas las zonas existentes
	for _, child in ipairs(zoneContainer:GetChildren()) do
		if child:IsA("Folder") then
			self:_registerZone(child)
		end
	end

	-- Conectar descubrimiento dinámico en tiempo de ejecución (Runtime Add / Remove)
	table.insert(self._containerConnections, zoneContainer.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Folder") then
			-- Dar un frame para asegurar inicialización de atributos y jerarquía en caso de clonación
			task.defer(function()
				if child.Parent == zoneContainer then
					self:_registerZone(child)
				end
			end)
		end
	end))

	table.insert(self._containerConnections, zoneContainer.ChildRemoved:Connect(function(child: Instance)
		if child:IsA("Folder") then
			self:_unregisterZone(child)
		end
	end))
end

function MatchmakingService:_registerZone(zoneFolder: Folder)
	if not zoneFolder or not zoneFolder:IsA("Folder") then return end
	if self._zones[zoneFolder] then return end

	local config, configError = getZoneConfiguration(zoneFolder)
	if not config then
		-- Decorative folders have no join pads and are not matchmaking zones.
		if zoneFolder:FindFirstChild("joins-parts") then
			warn(string.format("[MatchmakingService] Zona rechazada '%s': %s", zoneFolder.Name, tostring(configError)))
		end
		return
	end
	local joinsFolder = zoneFolder:FindFirstChild("joins-parts")

	local redPads: { BasePart } = {}
	local bluePads: { BasePart } = {}

	if joinsFolder then
		for _, part in ipairs(joinsFolder:GetChildren()) do
			if part:IsA("BasePart") then
				local teamAttr = part:GetAttribute("Team")
				if teamAttr == "Red" or part.Name == "Red" or part.Name:find("Red") then
					table.insert(redPads, part)
				elseif teamAttr == "Blue" or part.Name == "Blue" or part.Name:find("Blue") then
					table.insert(bluePads, part)
				end
			end
		end
	end

	if #redPads == 0 or #bluePads == 0 then
		warn(string.format("[MatchmakingService] Zona rechazada '%s': MissingTeamPads", zoneFolder.Name))
		return
	end
	table.sort(redPads, function(a, b) return a.Name < b.Name end)
	table.sort(bluePads, function(a, b) return a.Name < b.Name end)

	-- Generación de ZoneId único
	local attrId = zoneFolder:GetAttribute("ZoneId")
	local zoneId: string
	if typeof(attrId) == "string" and attrId ~= "" then
		if self:_isZoneIdTaken(attrId, zoneFolder) then
			warn(string.format("[MatchmakingService] Zona rechazada '%s': DuplicateZoneId", zoneFolder.Name))
			return
		end
		zoneId = attrId
	else
		local baseId = "Zone_" .. zoneFolder.Name
		local uniqueId = baseId
		local counter = 1
		while self:_isZoneIdTaken(uniqueId, zoneFolder) do
			counter += 1
			uniqueId = string.format("%s_%d", baseId, counter)
		end
		zoneId = uniqueId
	end

	local padOccupants: { [BasePart]: { Player } } = {}
	for _, pad in ipairs(redPads) do
		padOccupants[pad] = {}
	end
	for _, pad in ipairs(bluePads) do
		padOccupants[pad] = {}
	end

	local zoneData: ZoneData = {
		ZoneId = zoneId,
		Instance = zoneFolder,
		ZoneName = zoneFolder.Name,
		Config = config,
		RedPads = redPads,
		BluePads = bluePads,
		PadOccupants = padOccupants,
		OccupantLastSeen = {},
		CandidateArrivals = {},
		CandidateLastSeen = {},
		CurrentRed = {},
		CurrentBlue = {},
		State = "WAITING",
		ActiveReservation = nil,
		LastModeNotPlayableWarn = nil,
	}

	-- Registrar en MatchmakingFeedbackService
	local feedbackService = self:_getFeedbackService()
	if feedbackService then
		feedbackService:RegisterZone(zoneFolder)
	end

	self._zones[zoneFolder] = zoneData
	print(string.format("[MatchmakingService] Zona registrada: '%s' (ZoneId=%s, Modo=%s, TeamSize=%d, MaxTotal=%d)",
		zoneFolder.Name, zoneId, config.Mode, config.TeamSize, config.TotalPlayers))
end

function MatchmakingService:_unregisterZone(zoneFolder: Folder)
	local zoneData = self._zones[zoneFolder]
	if not zoneData then return end

	-- Cleanup en feedback audiovisual
	local feedbackService = self:_getFeedbackService()
	if feedbackService then
		feedbackService:UnregisterZone(zoneFolder)
	end

	-- Emitir snapshot vacío final a los clientes si la zona tenía jugadores
	if #zoneData.CurrentRed > 0 or #zoneData.CurrentBlue > 0 then
		if self._queueStatusRemote then
			local finalSnapshot: QueueSnapshot = {
				ZoneId = zoneData.ZoneId,
				ZoneName = zoneData.ZoneName,
				Mode = zoneData.Config.Mode,
				TeamSize = zoneData.Config.TeamSize,
				MaxPlayersPerTeam = zoneData.Config.MaxPlayersPerTeam,
				TotalPlayers = zoneData.Config.TotalPlayers,
				Red = {},
				Blue = {},
				State = "WAITING",
			}
			self._queueStatusRemote:FireAllClients(finalSnapshot)
		end
	end

	-- Limpieza de caché de snapshots
	self._latestSnapshots[zoneData.ZoneId] = nil
	self._latestSnapshots[zoneData.ZoneName] = nil

	-- Limpieza de tablas de ocupación
	table.clear(zoneData.PadOccupants)
	table.clear(zoneData.OccupantLastSeen)
	table.clear(zoneData.CandidateArrivals)
	table.clear(zoneData.CandidateLastSeen)
	table.clear(zoneData.CurrentRed)
	table.clear(zoneData.CurrentBlue)
	zoneData.ActiveReservation = nil

	self._zones[zoneFolder] = nil
	print(string.format("[MatchmakingService] Zona desregistrada y limpiada: '%s' (ZoneId=%s)",
		zoneFolder.Name, zoneData.ZoneId))
end

-- Limpia de forma inmediata reservas huérfanas al desconectarse un jugador
function MatchmakingService:_handlePlayerRemoving(player: Player)
	local needsUpdate = false
	for _, zone in pairs(self._zones) do
		zone.OccupantLastSeen[player] = nil
		zone.CandidateArrivals[player] = nil
		zone.CandidateLastSeen[player] = nil

		for pad, occupants in pairs(zone.PadOccupants) do
			local idx = table.find(occupants, player)
			if idx then
				table.remove(occupants, idx)
				needsUpdate = true
			end
		end
	end

	if needsUpdate then
		self:_updateQueue()
	end
end

function MatchmakingService:Start(context)
	self._context = context

	-- Monitoreo de ocupación cada 0.3s
	self._checkConnection = RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - self._lastCheck < 0.3 then return end
		self._lastCheck = now
		self:_updateQueue()
	end)

	-- Limpieza inmediata cuando un jugador se desconecta del servidor
	Players.PlayerRemoving:Connect(function(player: Player)
		self:_handlePlayerRemoving(player)
	end)

	print("[MatchmakingService] Servicio de matchmaking genérico iniciado")
end

function MatchmakingService:_getRoundService()
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

function MatchmakingService:_getFeedbackService()
	if self._context and self._context.GetService then
		local s = self._context:GetService("MatchmakingFeedbackService")
		if s then return s end
	end

	local servicesFolder = ServerScriptService:FindFirstChild("Services")
	local mod = servicesFolder and servicesFolder:FindFirstChild("MatchmakingFeedbackService")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok then return result end
	end
	return nil
end

-- Compara si dos listas de jugadores son idénticas
local function arePlayerListsEqual(a: { Player }, b: { Player }): boolean
	if #a ~= #b then return false end
	for i = 1, #a do
		if a[i] ~= b[i] then return false end
	end
	return true
end

function MatchmakingService:_updateQueue()
	local feedbackService = self:_getFeedbackService()
	local roundService = self:_getRoundService()
	local now = os.clock()

	-- Construir lista de personajes para OverlapParams
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	local characterList = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(characterList, player.Character)
		end
	end
	if self._testCharacterMap then
		for charModel, _ in pairs(self._testCharacterMap) do
			if charModel:IsDescendantOf(workspace) then
				table.insert(characterList, charModel)
			end
		end
	end
	overlapParams.FilterDescendantsInstances = characterList

	for zoneFolder, zone in pairs(self._zones) do
		-- Si la zona fue destruida o desparentada, desregistrar y omitir
		if not zoneFolder or not zoneFolder:IsDescendantOf(workspace) then
			self:_unregisterZone(zoneFolder)
			continue
		end

		-- Conjunto de ocupantes actuales de Blue para pasárselo a Red
		local currentBlueSet: { [Player]: boolean } = {}
		for _, p in ipairs(zone.CurrentBlue) do
			currentBlueSet[p] = true
		end

		local redOccupants = updateTeamOccupants(
			zone,
			zone.RedPads,
			zone.Config.MaxPlayersPerTeam,
			currentBlueSet,
			overlapParams,
			now,
			self
		)

		-- Conjunto de ocupantes actualizados de Red para pasárselo a Blue
		local currentRedSet: { [Player]: boolean } = {}
		for _, p in ipairs(redOccupants) do
			currentRedSet[p] = true
		end

		local blueOccupants = updateTeamOccupants(
			zone,
			zone.BluePads,
			zone.Config.MaxPlayersPerTeam,
			currentRedSet,
			overlapParams,
			now,
			self
		)

		local redChanged = not arePlayerListsEqual(zone.CurrentRed, redOccupants)
		local blueChanged = not arePlayerListsEqual(zone.CurrentBlue, blueOccupants)

		zone.CurrentRed = redOccupants
		zone.CurrentBlue = blueOccupants
		if roundService and roundService.CancelPreparationIfOccupancyLost then
			roundService:CancelPreparationIfOccupancyLost(zone.ZoneId)
		end

		-- Actualizar feedback audiovisual discreto por instancia de zona
		if feedbackService then
			feedbackService:SetPadOccupied(zoneFolder, "Red", #redOccupants > 0, redOccupants[1])
			feedbackService:SetPadOccupied(zoneFolder, "Blue", #blueOccupants > 0, blueOccupants[1])
		end

		-- Determinar candidatos comprometidos según TeamSize
		local committedRed: { Player } = {}
		for i = 1, math.min(#redOccupants, zone.Config.TeamSize) do
			table.insert(committedRed, redOccupants[i])
		end
		local committedBlue: { Player } = {}
		for i = 1, math.min(#blueOccupants, zone.Config.TeamSize) do
			table.insert(committedBlue, blueOccupants[i])
		end

		-- Verificar que los equipos sean disjuntos
		local disjoint = true
		for _, r in ipairs(committedRed) do
			if table.find(committedBlue, r) then
				disjoint = false
				break
			end
		end

		-- Verificar que ninguno de los participantes esté registrado en otra partida
		local anyAlreadyInMatch = false
		if roundService and roundService.GetSessionForPlayer then
			for _, p in ipairs(committedRed) do
				if roundService:GetSessionForPlayer(p) ~= nil then
					anyAlreadyInMatch = true
					break
				end
			end
			if not anyAlreadyInMatch then
				for _, p in ipairs(committedBlue) do
					if roundService:GetSessionForPlayer(p) ~= nil then
						anyAlreadyInMatch = true
						break
					end
				end
			end
		end

		local socialPlay=self:_socialPlay()
   local groupsReady=not socialPlay or (socialPlay:CanQueueTeam(committedRed,zone.Config.TeamSize)and socialPlay:CanQueueTeam(committedBlue,zone.Config.TeamSize))
   local isReady = groupsReady and (#committedRed == zone.Config.TeamSize)
			and (#committedBlue == zone.Config.TeamSize)
			and disjoint
			and not anyAlreadyInMatch

		-- Gestionar token autoritativo de reserva
		if isReady then
			-- Comprobar si la reserva existente sigue siendo válida para la misma plantilla
			local currentRes = zone.ActiveReservation
			local needsNewRes = true
			if currentRes and (os.clock() <= currentRes.ExpiresAt) then
				if currentRes.Mode == zone.Config.Mode
					and currentRes.TeamSize == zone.Config.TeamSize
					and #currentRes.RedTeam == #committedRed
					and #currentRes.BlueTeam == #committedBlue
				then
					local matches = true
					for i = 1, #committedRed do
						if currentRes.RedTeam[i] ~= committedRed[i] then
							matches = false
							break
						end
					end
					if matches then
						for i = 1, #committedBlue do
							if currentRes.BlueTeam[i] ~= committedBlue[i] then
								matches = false
								break
							end
						end
					end
					if matches then
						needsNewRes = false
					end
				end
			end

			if needsNewRes then
				self:CreateReservation(zone.ZoneId, zone.Config.Mode, zone.Config.TeamSize, committedRed, committedBlue)
			end
		else
			-- Si no está listo, invalidar cualquier reserva previa
			zone.ActiveReservation = nil
		end

		local newState: QueueStateName = if isReady then "READY" else "WAITING"
		local stateChanged = zone.State ~= newState
		zone.State = newState

		-- Emitir QueueSnapshot cuando hay cambios o para sincronización
		if redChanged or blueChanged or stateChanged or (zone :: any).ForceSnapshot then
			(zone :: any).ForceSnapshot = nil
			local snapshot: QueueSnapshot = {
				ZoneId = zone.ZoneId,
				ZoneName = zone.ZoneName,
				Mode = zone.Config.Mode,
				TeamSize = zone.Config.TeamSize,
				MaxPlayersPerTeam = zone.Config.MaxPlayersPerTeam,
				TotalPlayers = zone.Config.TotalPlayers,
				Red = redOccupants,
				Blue = blueOccupants,
				State = newState,
			}

			self._latestSnapshots[zone.ZoneId] = snapshot
			self._latestSnapshots[zone.ZoneName] = snapshot

			if self._queueStatusRemote then
				self._queueStatusRemote:FireAllClients(snapshot)
			end
		end

		-- Disparar inicio de partida cuando la cola está lista y RoundService disponible
		if isReady and roundService and roundService:IsAvailable() then
			local token = if zone.ActiveReservation then zone.ActiveReservation.Token else nil
			local admissionRequest: Types.TeamMatchAdmissionRequest = {
				ZoneId = zone.ZoneId,
				Mode = zone.Config.Mode,
				TeamSize = zone.Config.TeamSize,
				RedTeam = committedRed,
				BlueTeam = committedBlue,
				ReservationToken = token,
			}

			local ok, reason = roundService:StartTeamMatch(admissionRequest)
			if not ok then
				if reason == "ModeNotPlayable" then
					if zone.LastModeNotPlayableWarn ~= zone.Config.Mode then
						zone.LastModeNotPlayableWarn = zone.Config.Mode
						print(string.format("[MatchmakingService] Modalidad '%s' en zona '%s' admitida estructuralmente pero bloqueada para juego real (ModeNotPlayable)",
							zone.Config.Mode, zone.ZoneId))
					end
				else
					-- No silenciar otros errores
				end
			else
				zone.LastModeNotPlayableWarn = nil
			end
		end
	end
end

-- A party remains a complete cohort on the same physical team; no remote teleports.
function MatchmakingService:IsPlayerQueued(player: Player): boolean
 for _,zone in pairs(self._zones)do
  if table.find(zone.CurrentRed,player)or table.find(zone.CurrentBlue,player)then return true end
 end
 return false
end
function MatchmakingService:_socialPlay(): any
 return self._context and self._context:GetService('SocialPlayService')
end

-- Consulta de snapshot público (por Folder, ZoneId o ZoneName)
function MatchmakingService:GetQueueSnapshot(identifier: any): QueueSnapshot?
	if typeof(identifier) == "Instance" and identifier:IsA("Folder") then
		local data = self._zones[identifier]
		return data and self._latestSnapshots[data.ZoneId]
	elseif typeof(identifier) == "string" then
		return self._latestSnapshots[identifier]
	end
	return self._latestSnapshots["1v1"] or next(self._latestSnapshots)
end

-- Consulta de configuración de zona
function MatchmakingService:GetZoneConfig(identifier: any): MatchmakingZoneConfig?
	if typeof(identifier) == "Instance" and identifier:IsA("Folder") then
		local data = self._zones[identifier]
		return data and data.Config
	elseif typeof(identifier) == "string" then
		for _, data in pairs(self._zones) do
			if data.ZoneId == identifier or data.ZoneName == identifier then
				return data.Config
			end
		end
	end
	return nil
end

-- Obtiene la tabla completa de zonas registradas
function MatchmakingService:GetAllZones(): { [Folder]: ZoneData }
	return self._zones
end

-- Crea una reserva autoritativa para una plantilla lista
function MatchmakingService:CreateReservation(
	zoneId: string,
	mode: string,
	teamSize: number,
	redTeam: { Player },
	blueTeam: { Player },
	ttlSeconds: number?
): Types.TeamMatchReservation?
	local targetZone: ZoneData? = nil
	for _, z in pairs(self._zones) do
		if z.ZoneId == zoneId then
			targetZone = z
			break
		end
	end
	if not targetZone then return nil end

	local ttl = ttlSeconds or (Config.Matchmaking and Config.Matchmaking.ReservationTTL) or 15
	local now = os.clock()
	local token = HttpService:GenerateGUID(false)

	local redCopy: { Player } = {}
	for _, p in ipairs(redTeam) do table.insert(redCopy, p) end
	local blueCopy: { Player } = {}
	for _, p in ipairs(blueTeam) do table.insert(blueCopy, p) end

	local reservation: Types.TeamMatchReservation = {
		Token = token,
		ZoneId = zoneId,
		Mode = mode,
		TeamSize = teamSize,
		RedTeam = redCopy,
		BlueTeam = blueCopy,
		CreatedAt = now,
		ExpiresAt = now + ttl,
	}

	targetZone.ActiveReservation = reservation
	return reservation
end

-- Obtiene la reserva autoritativa activa de una zona
function MatchmakingService:GetActiveReservation(zoneId: string): Types.TeamMatchReservation?
	for _, z in pairs(self._zones) do
		if z.ZoneId == zoneId then
			return z.ActiveReservation
		end
	end
	return nil
end

-- Valida que un token corresponda exactamente a la plantilla y zona activa sin haber expirado
function MatchmakingService:ValidateReservation(
	token: string,
	request: Types.TeamMatchAdmissionRequest
): (boolean, string?)
 if type(request.ZoneId)=='string'and request.ZoneId:sub(1,5)=='Duel:'then
  local play=self:_socialPlay();if not play then return false,'SocialPlayUnavailable'end
  return play:ValidateDuel(token,request)
 end

	if not token or token == "" then
		return false, "MissingReservationToken"
	end

	local foundZone: ZoneData? = nil
	for _, z in pairs(self._zones) do
		if z.ActiveReservation and z.ActiveReservation.Token == token then
			foundZone = z
			break
		end
	end

	if not foundZone or not foundZone.ActiveReservation then
		return false, "ReservationNotFound"
	end

	local res = foundZone.ActiveReservation
	local now = os.clock()
	if now > res.ExpiresAt then
		foundZone.ActiveReservation = nil
		return false, "ReservationExpired"
	end

	if res.ZoneId ~= request.ZoneId then
		return false, "ReservationZoneMismatch"
	end

	if res.Mode ~= request.Mode then
		return false, "ReservationModeMismatch"
	end

	if res.TeamSize ~= request.TeamSize then
		return false, "ReservationTeamSizeMismatch"
	end

	if #res.RedTeam ~= #request.RedTeam or #res.BlueTeam ~= #request.BlueTeam then
		return false, "ReservationRosterMismatch"
	end

	for i = 1, #res.RedTeam do
		if res.RedTeam[i] ~= request.RedTeam[i] then
			return false, "ReservationRosterMismatch"
		end
	end

	for i = 1, #res.BlueTeam do
		if res.BlueTeam[i] ~= request.BlueTeam[i] then
			return false, "ReservationRosterMismatch"
		end
	end

	return true, nil
end

-- Consume de forma atómica una reserva al ser admitida la partida
function MatchmakingService:ConsumeReservation(token: string): boolean
 local play=self:_socialPlay();if play and play:ConsumeDuel(token)then return true end
	for _, z in pairs(self._zones) do
		if z.ActiveReservation and z.ActiveReservation.Token == token then
			z.ActiveReservation = nil
			return true
		end
	end
	return false
end

-- Invalida de forma explícita la reserva de una zona
-- Preserve physical occupancy/FIFO; only invalidate this preparation's reservation.
function MatchmakingService:ReleasePreparation(zoneId: string, token: string?)
 if zoneId:sub(1,5)=='Duel:'then local play=self:_socialPlay();if play then play:ReleaseDuel(zoneId,token)end;return end
	for _,zone in pairs(self._zones) do
		if zone.ZoneId == zoneId then
			if zone.ActiveReservation and zone.ActiveReservation.Token == token then zone.ActiveReservation = nil end
			(zone :: any).ForceSnapshot = true
			return
		end
	end
end

function MatchmakingService:InvalidateReservation(zoneId: string)
	for _, z in pairs(self._zones) do
		if z.ZoneId == zoneId then
			z.ActiveReservation = nil
			break
		end
	end
end

-- Verifica de manera server-authoritative si los jugadores siguen siendo los ocupantes registrados de su zona
function MatchmakingService:ArePlayersInZone(
	zoneId: string,
	redPlayerOrTeam: Player | { Player },
	bluePlayerOrTeam: Player | { Player },
	requirePhysical: boolean?
): boolean
	if not zoneId or not redPlayerOrTeam or not bluePlayerOrTeam then
		return false
	end

	local redList: { Player } = if typeof(redPlayerOrTeam) == "table" and not (redPlayerOrTeam :: any).IsSimulatedPlayer then (redPlayerOrTeam :: { Player }) else { redPlayerOrTeam :: Player }
	local blueList: { Player } = if typeof(bluePlayerOrTeam) == "table" and not (bluePlayerOrTeam :: any).IsSimulatedPlayer then (bluePlayerOrTeam :: { Player }) else { bluePlayerOrTeam :: Player }

	if #redList == 0 or #blueList == 0 then
		return false
	end

	for _, p in ipairs(redList) do
		if not isPlayerAliveAndValid(p) then return false end
	end
	for _, p in ipairs(blueList) do
		if not isPlayerAliveAndValid(p) then return false end
	end

 if zoneId:sub(1,5)=='Duel:'then
  local play=self:_socialPlay();return play~=nil and play:DuelPrepared(zoneId,redList,blueList)
 end

	-- 1. Resolver la zona mediante ZoneId
	local targetZone: ZoneData? = nil
	for _, zone in pairs(self._zones) do
		if zone.ZoneId == zoneId then
			targetZone = zone
			break
		end
	end

	if not targetZone then
		return false
	end

	-- Verificar existencia de la instancia física
	if not targetZone.Instance or not targetZone.Instance:IsDescendantOf(workspace) then
		return false
	end

	-- 2. Verificar que todos los jugadores de cada equipo están registrados en la zona
	for _, p in ipairs(redList) do
		if not table.find(targetZone.CurrentRed, p) then
			return false
		end
	end
	for _, p in ipairs(blueList) do
		if not table.find(targetZone.CurrentBlue, p) then
			return false
		end
	end

	if requirePhysical then
		local params=OverlapParams.new()
		params.FilterType=Enum.RaycastFilterType.Include
		local characters={}
		for _,list in ipairs({redList,blueList}) do for _,p in ipairs(list) do table.insert(characters,p.Character) end end
		params.FilterDescendantsInstances=characters
		for _,entry in ipairs({{Pads=targetZone.RedPads,Players=redList},{Pads=targetZone.BluePads,Players=blueList}}) do
			local present={}
			for _,pad in ipairs(entry.Pads) do for _,p in ipairs(getPhysicallyPresentPlayersOnPad(pad,params)) do present[p]=true end end
			for _,p in ipairs(entry.Players) do if not present[p] then return false end end
		end
	end
	return true
end

return MatchmakingService
