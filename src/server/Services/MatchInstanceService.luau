--!strict
-- MatchInstanceService
-- Servicio encargado exclusivamente de crear, administrar y destruir las instancias fisicas de las partidas.
-- Asigna ArenaSlots fisicamente aislados para que los jugadores de distintas partidas no puedan verse ni interactuar.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

type MatchSession = Types.MatchSession
type MatchInstanceInfo = Types.MatchInstanceInfo

local MatchInstanceService = {}
MatchInstanceService.Name = "MatchInstanceService"

MatchInstanceService._context = nil
MatchInstanceService._activeMatchesFolder = nil :: Folder?
MatchInstanceService._allocatedSlots = {} :: { [number]: string } -- ArenaSlot -> MatchId
MatchInstanceService._instances = {} :: { [string]: MatchInstanceInfo } -- MatchId -> MatchInstanceInfo

function MatchInstanceService:Init(context)
	self._context = context
	self._allocatedSlots = {}
	self._instances = {}

	-- Localizar o crear de forma segura Workspace.ActiveMatches
	local activeMatches = workspace:FindFirstChild("ActiveMatches")
	if not activeMatches then
		activeMatches = Instance.new("Folder")
		activeMatches.Name = "ActiveMatches"
		activeMatches.Parent = workspace
	end
	self._activeMatchesFolder = activeMatches :: Folder
end

function MatchInstanceService:Start(context)
	print("[MatchInstanceService] Servicio iniciado y listo para gestionar instancias de partida")
end

function MatchInstanceService:GetSlotOrigin(slot: number): Vector3
	local baseOrigin = (Config.Arena and Config.Arena.BaseOrigin) or Vector3.new(10000, 500, 0)
	local spacing = (Config.Arena and Config.Arena.Spacing) or Vector3.new(10000, 0, 0)
	return baseOrigin + spacing * slot
end

function MatchInstanceService:_allocateSlot(matchId: string): number?
	local maxSlots = (Config.Arena and Config.Arena.MaxSlots) or 100

	-- Buscar el menor ArenaSlot disponible (garantiza reutilización de slots liberados)
	for slot = 0, maxSlots - 1 do
		if self._allocatedSlots[slot] == nil then
			self._allocatedSlots[slot] = matchId
			return slot
		end
	end

	warn(string.format("[MatchInstanceService] No hay ArenaSlots disponibles (Capacidad: %d)", maxSlots))
	return nil
end

function MatchInstanceService:_releaseSlot(slot: number)
	self._allocatedSlots[slot] = nil
end

function MatchInstanceService:_validateMapTemplate(mapName: string): (boolean, string?, Model?)
	local mapsFolder = ServerStorage:FindFirstChild("Maps")
	if not mapsFolder then
		return false, "ServerStorage.Maps no existe", nil
	end

	local mapTemplate = mapsFolder:FindFirstChild(mapName)
	if not mapTemplate then
		return false, string.format("Mapa '%s' no encontrado en ServerStorage.Maps", mapName), nil
	end

	if not mapTemplate:IsA("Model") then
		return false, string.format("Mapa '%s' no es un Model (es %s)", mapName, mapTemplate.ClassName), nil
	end

	local geometry = mapTemplate:FindFirstChild("Geometry")
	if not geometry then
		return false, string.format("Mapa '%s' no contiene 'Geometry'", mapName), nil
	end

	local redSpawn = mapTemplate:FindFirstChild("RedSpawn")
	if not redSpawn or not redSpawn:IsA("BasePart") then
		return false, string.format("Mapa '%s' no contiene 'RedSpawn' valido (debe ser BasePart)", mapName), nil
	end

	local blueSpawn = mapTemplate:FindFirstChild("BlueSpawn")
	if not blueSpawn or not blueSpawn:IsA("BasePart") then
		return false, string.format("Mapa '%s' no contiene 'BlueSpawn' valido (debe ser BasePart)", mapName), nil
	end

	local zoneWin = mapTemplate:FindFirstChild("ZoneWin")
	if not zoneWin then
		return false, string.format("Mapa '%s' no contiene 'ZoneWin'", mapName), nil
	end

	local redWin = zoneWin:FindFirstChild("RedWin")
	if not redWin or not redWin:IsA("BasePart") then
		return false, string.format("Mapa '%s' no contiene 'ZoneWin.RedWin' valido (debe ser BasePart)", mapName), nil
	end

	local blueWin = zoneWin:FindFirstChild("BlueWin")
	if not blueWin or not blueWin:IsA("BasePart") then
		return false, string.format("Mapa '%s' no contiene 'ZoneWin.BlueWin' valido (debe ser BasePart)", mapName), nil
	end

	return true, nil, mapTemplate :: Model
end

function MatchInstanceService:CreateInstance(matchSession: MatchSession, mapName: string): MatchInstanceInfo?
	if not matchSession or type(matchSession.Id) ~= "string" or matchSession.Id == "" then
		warn("[MatchInstanceService] MatchSession invalida o sin ID")
		return nil
	end

	local matchId = matchSession.Id

	-- Evitar duplicados para una misma partida activa
	if self._instances[matchId] ~= nil then
		warn(string.format("[MatchInstanceService] La partida '%s' ya posee una instancia activa", matchId))
		return self._instances[matchId]
	end

	-- 1. Validar contrato de mapa
	local isValid, errReason, mapTemplate = self:_validateMapTemplate(mapName)
	if not isValid or not mapTemplate then
		warn(string.format("[MatchInstanceService] Error al validar mapa: %s", tostring(errReason)))
		return nil
	end

	-- 2. Reservar ArenaSlot libre
	local slot = self:_allocateSlot(matchId)
	if slot == nil then
		return nil
	end

	local origin = self:GetSlotOrigin(slot)

	-- 3. Clonar el mapa
	local clonedMap = mapTemplate:Clone()

	-- 4. Crear contenedor de partida en Workspace.ActiveMatches
	if not self._activeMatchesFolder or not self._activeMatchesFolder.Parent then
		local activeMatches = workspace:FindFirstChild("ActiveMatches")
		if not activeMatches then
			activeMatches = Instance.new("Folder")
			activeMatches.Name = "ActiveMatches"
			activeMatches.Parent = workspace
		end
		self._activeMatchesFolder = activeMatches :: Folder
	end

	local container = Instance.new("Folder")
	container.Name = "Match_" .. matchId
	container.Parent = self._activeMatchesFolder

	-- 5. Posicionar el mapa completo mediante PivotTo en el origen del ArenaSlot
	clonedMap:PivotTo(CFrame.new(origin))
	clonedMap.Parent = container

	-- Extraer referencias cacheadas de las partes del contrato
	local geometry = clonedMap:FindFirstChild("Geometry") :: Instance
	local redSpawn = clonedMap:FindFirstChild("RedSpawn") :: BasePart
	local blueSpawn = clonedMap:FindFirstChild("BlueSpawn") :: BasePart
	local zoneWin = clonedMap:FindFirstChild("ZoneWin") :: Instance
	local redWin = zoneWin and zoneWin:FindFirstChild("RedWin") :: BasePart
	local blueWin = zoneWin and zoneWin:FindFirstChild("BlueWin") :: BasePart

	-- Extraer referencias a KillParts si existen en el mapa
	local killParts: { BasePart } = {}
	for _, desc in ipairs(clonedMap:GetDescendants()) do
		if desc:IsA("BasePart") and desc.Name == "KillPart" then
			table.insert(killParts, desc)
		end
	end

	local instanceInfo: MatchInstanceInfo = {
		MatchId = matchId,
		MapName = mapName,
		ArenaSlot = slot,
		Origin = origin,
		InstanceModel = clonedMap,
		Container = container,
		Geometry = geometry,
		RedSpawn = redSpawn,
		BlueSpawn = blueSpawn,
		ZoneWin = zoneWin,
		RedWin = redWin,
		BlueWin = blueWin,
		KillParts = killParts,
	}

	self._instances[matchId] = instanceInfo

	print(string.format("[MatchInstanceService] Instancia creada: Match '%s' -> Mapa '%s' en ArenaSlot %d (%s)",
		matchId, mapName, slot, tostring(origin)))

	return instanceInfo
end

function MatchInstanceService:GetInstance(matchId: string): MatchInstanceInfo?
	return self._instances[matchId]
end

function MatchInstanceService:GetSpawnPoints(matchId: string): (BasePart?, BasePart?)
	local info = self._instances[matchId]
	if info then
		return info.RedSpawn, info.BlueSpawn
	end
	return nil, nil
end

function MatchInstanceService:GetZoneWin(matchId: string): (BasePart?, BasePart?)
	local info = self._instances[matchId]
	if info then
		return info.RedWin, info.BlueWin
	end
	return nil, nil
end

function MatchInstanceService:DestroyInstance(matchId: string): boolean
	local info = self._instances[matchId]
	if not info then
		-- Limpieza segura de contenedor huérfano si existiese
		if self._activeMatchesFolder then
			local orphan = self._activeMatchesFolder:FindFirstChild("Match_" .. matchId)
			if orphan then
				orphan:Destroy()
			end
		end
		return false
	end

	-- Destruir contenedor y modelo clonado
	if info.Container and info.Container.Parent then
		info.Container:Destroy()
	end

	-- Liberar ArenaSlot
	self:_releaseSlot(info.ArenaSlot)

	-- Limpiar registro
	self._instances[matchId] = nil

	print(string.format("[MatchInstanceService] Instancia destruida: Match '%s', ArenaSlot %d liberado",
		matchId, info.ArenaSlot))

	return true
end

function MatchInstanceService:GetAllocatedSlots(): { [number]: string }
	return self._allocatedSlots
end

return MatchInstanceService
