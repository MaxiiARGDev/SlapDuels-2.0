--!strict
-- MatchmakingService
-- Gestiona la detección de jugadores en zonas de matchmaking genéricas (1v1, 2v2, 3v3),
-- construye el QueueSnapshot autoritativo, controla la capacidad por equipo y despacha
-- partidas hacia RoundService.
-- La instancia física (zoneFolder) es la identidad primaria interna de la zona.
-- NO se encarga de efectos audiovisuales (delegado a MatchmakingFeedbackService)
-- ni de la presentación visual del HUD (delegado a MatchmakingController).

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
	CurrentRed: { Player },
	CurrentBlue: { Player },
	State: QueueStateName,
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

-- Obtiene el Player asociado a una parte de un personaje
local function getPlayerFromPart(part: BasePart): Player?
	local current: Instance? = part
	while current and current ~= workspace do
		if current:IsA("Model") then
			local player = Players:GetPlayerFromCharacter(current)
			if player then
				return player
			end
		end
		current = current.Parent
	end
	return nil
end

-- Detecta todos los jugadores únicos sobre una lista de pads hasta la capacidad máxima
local function getOccupantsOfPads(pads: { BasePart }, maxCapacity: number): { Player }
	if #pads == 0 then return {} end

	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include

	local characterList = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(characterList, player.Character)
		end
	end
	overlapParams.FilterDescendantsInstances = characterList

	local occupants: { Player } = {}
	local seenPlayers: { [Player]: boolean } = {}

	for _, pad in ipairs(pads) do
		local touchingParts = workspace:GetPartsInPart(pad, overlapParams)
		for _, part in ipairs(touchingParts) do
			local player = getPlayerFromPart(part)
			if player and not seenPlayers[player] then
				seenPlayers[player] = true
				table.insert(occupants, player)
				if #occupants >= maxCapacity then
					return occupants
				end
			end
		end
	end

	return occupants
end

-- Determina la configuración de una zona desde sus Attributes con fallback a Config.luau
local function getZoneConfiguration(zoneFolder: Folder): MatchmakingZoneConfig
	local modeAttr = zoneFolder:GetAttribute("Mode")
	local teamSizeAttr = zoneFolder:GetAttribute("TeamSize")
	local maxPerTeamAttr = zoneFolder:GetAttribute("MaxPlayersPerTeam")
	local totalAttr = zoneFolder:GetAttribute("TotalPlayers")

	local modeName = if type(modeAttr) == "string" and modeAttr ~= "" then modeAttr else zoneFolder.Name
	local configDefaults = Config.Matchmaking and Config.Matchmaking.Modes and Config.Matchmaking.Modes[modeName]

	local teamSize = if type(teamSizeAttr) == "number" then teamSizeAttr else (configDefaults and configDefaults.TeamSize or 1)
	local maxPerTeam = if type(maxPerTeamAttr) == "number" then maxPerTeamAttr else (configDefaults and configDefaults.MaxPlayersPerTeam or teamSize)
	local totalPlayers = if type(totalAttr) == "number" then totalAttr else (configDefaults and configDefaults.TotalPlayers or (teamSize * 2))

	return {
		Mode = modeName,
		TeamSize = teamSize,
		MaxPlayersPerTeam = maxPerTeam,
		TotalPlayers = totalPlayers,
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

function MatchmakingService:Init(context)
	self._context = context
	self._zones = {}
	self._latestSnapshots = {}
	self._containerConnections = {}

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

	local config = getZoneConfiguration(zoneFolder)
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

	-- Generación de ZoneId único
	local attrId = zoneFolder:GetAttribute("ZoneId")
	local zoneId: string
	if typeof(attrId) == "string" and attrId ~= "" then
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

	local zoneData: ZoneData = {
		ZoneId = zoneId,
		Instance = zoneFolder,
		ZoneName = zoneFolder.Name,
		Config = config,
		RedPads = redPads,
		BluePads = bluePads,
		CurrentRed = {},
		CurrentBlue = {},
		State = "WAITING",
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

	self._zones[zoneFolder] = nil
	print(string.format("[MatchmakingService] Zona desregistrada y limpiada: '%s' (ZoneId=%s)",
		zoneFolder.Name, zoneData.ZoneId))
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

	for zoneFolder, zone in pairs(self._zones) do
		-- Si la zona fue destruida o desparentada, desregistrar y omitir
		if not zoneFolder or not zoneFolder:IsDescendantOf(workspace) then
			self:_unregisterZone(zoneFolder)
			continue
		end

		local redOccupants = getOccupantsOfPads(zone.RedPads, zone.Config.MaxPlayersPerTeam)
		local blueOccupants = getOccupantsOfPads(zone.BluePads, zone.Config.MaxPlayersPerTeam)

		local redChanged = not arePlayerListsEqual(zone.CurrentRed, redOccupants)
		local blueChanged = not arePlayerListsEqual(zone.CurrentBlue, blueOccupants)

		zone.CurrentRed = redOccupants
		zone.CurrentBlue = blueOccupants

		-- Actualizar feedback audiovisual discreto por instancia de zona
		if feedbackService then
			feedbackService:SetPadOccupied(zoneFolder, "Red", #redOccupants > 0, redOccupants[1])
			feedbackService:SetPadOccupied(zoneFolder, "Blue", #blueOccupants > 0, blueOccupants[1])
		end

		-- Determinar estado de la cola
		local isReady = (#redOccupants >= zone.Config.TeamSize) and (#blueOccupants >= zone.Config.TeamSize)
		local newState: QueueStateName = if isReady then "READY" else "WAITING"
		local stateChanged = zone.State ~= newState
		zone.State = newState

		-- Emitir QueueSnapshot cuando hay cambios o para sincronización
		if redChanged or blueChanged or stateChanged then
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

		-- Disparar inicio de partida cuando la cola está completa
		if isReady and roundService and roundService:IsAvailable() then
			-- Evitar colisiones si el mismo jugador estuviese en ambos lados
			if redOccupants[1] ~= blueOccupants[1] then
				print(string.format("[MatchmakingService] MATCH_READY en zona '%s' (ZoneId=%s, %s): Red (%d/%d) vs Blue (%d/%d)",
					zone.ZoneName, zone.ZoneId, zone.Config.Mode, #redOccupants, zone.Config.TeamSize, #blueOccupants, zone.Config.TeamSize))

				-- Iniciar la partida informando el ZoneId de origen
				roundService:StartMatch(redOccupants[1], blueOccupants[1], zone.ZoneId)
			end
		end
	end
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

return MatchmakingService
