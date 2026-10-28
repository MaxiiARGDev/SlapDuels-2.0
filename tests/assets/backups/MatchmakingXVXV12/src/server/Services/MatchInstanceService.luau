--!strict
-- MatchInstanceService
-- Servicio encargado exclusivamente de crear, administrar y destruir las instancias fisicas de las partidas.
-- Asigna ArenaSlots fisicamente aislados para que los jugadores de distintas partidas no puedan verse ni interactuar.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

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

local TEAM_NAMES: { "Red" | "Blue" } = { "Red", "Blue" }

local SpawnResolver = require(script.Parent.TeamSpawnResolver)
local function resolveTeamSpawns(map: Instance)
 return SpawnResolver.Resolve(map, 1)
end

function MatchInstanceService:Init(context)
	self._context = context
	self._allocatedSlots = {}
	self._instances = {}
	self._previewScenes = {}

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
	if RunService:IsStudio() then
		local match = ReplicatedStorage.Remotes.Match
		local remote = match:FindFirstChild("EndCinematicPreview") or Instance.new("RemoteFunction")
		remote.Name = "EndCinematicPreview"
		remote.Parent = match
		remote.OnServerInvoke = function(player, action, name)
			if not RunService:IsStudio() or player.Parent ~= Players then return nil end
			if action == "Release" then
				local record = self._previewScenes[player]
				if record and type(name) == "string" and record.Scene.Name == name then self:ReleaseCinematicPreview(player) end
				return true
			end
			if action ~= "Prepare" then return nil end
			return self:PrepareCinematicPreview(player)
		end
		Players.PlayerRemoving:Connect(function(player) self:ReleaseCinematicPreview(player) end)
	end
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

function MatchInstanceService:_releaseSlot(slot: number, expectedMatchId: string?): boolean
	if expectedMatchId and self._allocatedSlots[slot] ~= expectedMatchId then
		return false
	end
	self._allocatedSlots[slot] = nil
	return true
end

function MatchInstanceService:_validateMapTemplate(mapName: string, requiredTeamSize: number?): (boolean, string?, Model?)
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

	local teamSpawns, capacity, spawnError = SpawnResolver.Resolve(mapTemplate, requiredTeamSize or 1)
	if not teamSpawns then
		return false, string.format("Mapa '%s': %s", mapName, tostring(spawnError)), nil
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
	local isValid, errReason, mapTemplate = self:_validateMapTemplate(mapName, matchSession.TeamSize or 1)
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
	local arenaTransform = CFrame.new(origin) * mapTemplate:GetPivot():Inverse()

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
	container:SetAttribute("SessionId", matchId)
	container.Parent = self._activeMatchesFolder

	-- 5. Posicionar el mapa completo mediante PivotTo en el origen del ArenaSlot
	clonedMap:PivotTo(CFrame.new(origin))
	clonedMap.Parent = container

	-- Extraer referencias cacheadas de las partes del contrato
	local geometry = clonedMap:FindFirstChild("Geometry") :: Instance
	local teamSpawns, teamCapacity = resolveTeamSpawns(clonedMap)
	local redSpawn = teamSpawns.Red[1]
	local blueSpawn = teamSpawns.Blue[1]
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

	-- Crear VoidBoundaryPart exclusivo para esta MatchInstance
	local voidBoundarySize = (Config.Arena and Config.Arena.VoidBoundarySize) or Vector3.new(500, 4, 500)
	local voidBoundaryOffset = (Config.Arena and Config.Arena.VoidBoundaryOffset) or Vector3.new(0, -50, 0)
	local voidBoundaryPosition = origin + voidBoundaryOffset

	local voidBoundaryPart = Instance.new("Part")
	voidBoundaryPart.Name = "VoidBoundaryPart"
	voidBoundaryPart.Size = voidBoundarySize
	voidBoundaryPart.CFrame = CFrame.new(voidBoundaryPosition)
	voidBoundaryPart.Anchored = true
	voidBoundaryPart.CanCollide = false
	voidBoundaryPart.CanTouch = true
	voidBoundaryPart.CanQuery = false
	voidBoundaryPart.Transparency = 1
	voidBoundaryPart.Parent = container

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
		TeamSpawns = teamSpawns,
		TeamCapacity = teamCapacity,
		ZoneWin = zoneWin,
		RedWin = redWin,
		BlueWin = blueWin,
		KillParts = killParts,
		VoidBoundaryPart = voidBoundaryPart,
		ArenaTransform = arenaTransform,
	}

	self._instances[matchId] = instanceInfo
	local ok, cinematicError = pcall(function()
		self:PrepareEndCinematic(matchId)
	end)
	if not ok or not instanceInfo.EndCinematic then
		warn("[MatchInstanceService] EndCinematic unavailable: " .. tostring(cinematicError))
		self:DestroyInstance(matchId)
		return nil
	end

	print(string.format("[MatchInstanceService] Instancia creada: Match '%s' -> Mapa '%s' en ArenaSlot %d (%s)",
		matchId, mapName, slot, tostring(origin)))

	return instanceInfo
end

function MatchInstanceService:GetInstance(matchId: string): MatchInstanceInfo?
	return self._instances[matchId]
end

-- Uses exactly the map's original-pivot -> arena transform, not a cinematic pivot.
function MatchInstanceService:_populateCinematicScene(scene: Model, delta: CFrame)
	local folder = ServerStorage:FindFirstChild("EndGames-Scenario")
	local template = folder and folder:FindFirstChild("ScenarioFinal")
	assert(template and template:IsA("Model"), "ServerStorage.EndGames-Scenario.ScenarioFinal missing")
	for _, child in ipairs(template:GetChildren()) do child:Clone().Parent = scene end
	for _, object in ipairs(scene:GetDescendants()) do
		if object:IsA("LuaSourceContainer") then object:Destroy()
		elseif object:IsA("BasePart") then
			object.CFrame = delta * object.CFrame
			object.Anchored = true
			object.CanCollide = false
			object.CanTouch = false
			object.CanQuery = false
			elseif object:IsA("BillboardGui") and object.Parent and object.Parent.Name == "BillboardAnchor" then
				-- Only the authorized client enables its scene's results UI.
				object.Enabled = false
			elseif object:IsA("ParticleEmitter") then object.Enabled = false
		elseif object:IsA("Sound") then object:Stop() end
	end
	scene.WorldPivot = delta * template:GetPivot()
	local cameras = assert(scene:FindFirstChild("TransCamera"), "CinematicCamerasMissing")
	for _, name in ipairs({ "CameraCheck-v1", "CameraCheck-v2", "CameraCheck-Only1V1" }) do
		local part = cameras:FindFirstChild(name)
		assert(part and part:IsA("BasePart"), "CinematicCameraMissing:" .. name)
	end
	local slots = assert(scene:FindFirstChild("Players"), "CinematicSlotsMissing")
	for index = 1, 5 do
		local slot = slots:FindFirstChild("SlotPlayer_" .. index)
		assert(slot and slot:IsA("BasePart"), "CinematicSlotMissing:" .. index)
	end
end

function MatchInstanceService:PrepareEndCinematic(matchId: string): Model?
	local info = self._instances[matchId]
	if not info then return nil end
	if info.EndCinematic and info.EndCinematic.Parent == info.Container then return info.EndCinematic end
	local scene = Instance.new("Model")
	scene.Name = "ScenarioFinal"
	scene:SetAttribute("SessionId", matchId)
	scene:SetAttribute("ArenaSlot", info.ArenaSlot)
	scene.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
	-- Register first so the existing rollback owns partial clones too.
	info.EndCinematic = scene
	self:_populateCinematicScene(scene, info.ArenaTransform :: CFrame)
	scene.Parent = info.Container
	return scene
end

function MatchInstanceService:ReleaseCinematicPreview(player: Player, expected: Model?)
	local record = self._previewScenes and self._previewScenes[player]
	if not record or (expected and record.Scene ~= expected) then return end
	self._previewScenes[player] = nil
	if record.Connection then record.Connection:Disconnect() end
	if record.Timer and record.Timer ~= coroutine.running() then pcall(task.cancel, record.Timer) end
	record.Scene:Destroy()
	local folder = workspace:FindFirstChild("EndCinematicPreviews")
	if folder and #folder:GetChildren() == 0 then folder:Destroy() end
end

function MatchInstanceService:PrepareCinematicPreview(player: Player): any
	if not RunService:IsStudio() or player.Parent ~= Players then return nil end
	local config = require(ReplicatedStorage.Shared.EndCinematicConfig)
	local rounds = self._context and self._context:GetService("RoundService")
	if not config.Preview.Enabled or player:GetAttribute("MatchId") ~= nil
		or (rounds and rounds:GetSessionForPlayer(player)) then return nil end
	self:ReleaseCinematicPreview(player)
	local folder = workspace:FindFirstChild("EndCinematicPreviews")
	if not folder then folder = Instance.new("Folder"); folder.Name = "EndCinematicPreviews"; folder.Parent = workspace end
	local scene = Instance.new("Model")
	scene.Name = "Preview_" .. player.UserId .. "_" .. game:GetService("HttpService"):GenerateGUID(false)
	scene.ModelStreamingMode = Enum.ModelStreamingMode.PersistentPerPlayer
	scene:SetAttribute("PreviewOwnerUserId", player.UserId)
	local ok, failure = pcall(function() self:_populateCinematicScene(scene, CFrame.identity) end)
	if not ok then scene:Destroy(); if #folder:GetChildren() == 0 then folder:Destroy() end; warn(failure); return nil end
	scene.Parent = folder
	local record = { Scene = scene }
	self._previewScenes[player] = record
	local persistentOk = pcall(function() scene:AddPersistentPlayer(player) end)
	if not persistentOk then self:ReleaseCinematicPreview(player); return nil end
	record.Connection = player:GetAttributeChangedSignal("MatchId"):Connect(function()
		if player:GetAttribute("MatchId") ~= nil then self:ReleaseCinematicPreview(player, scene) end
	end)
	record.Timer = task.delay(90, function() self:ReleaseCinematicPreview(player, scene) end)
	return { Name = scene.Name, Origin = scene:GetPivot().Position }
end

function MatchInstanceService:GetSpawnPoints(matchId: string): (BasePart?, BasePart?)
	local info = self._instances[matchId]
	if info then
		return info.TeamSpawns.Red[1], info.TeamSpawns.Blue[1]
	end
	return nil, nil
end

function MatchInstanceService:GetSpawnPoint(matchId: string, team: "Red" | "Blue", slot: number): BasePart?
	local info = self._instances[matchId]
	if not info or (team ~= "Red" and team ~= "Blue") or slot < 1 then return nil end
	return info.TeamSpawns[team][slot]
end

function MatchInstanceService:GetMapCapacity(mapName: string): number
	local ok, _, template = self:_validateMapTemplate(mapName, 1)
	if not ok or not template then return 0 end
	local _, capacity = resolveTeamSpawns(template)
	return capacity
end

function MatchInstanceService:IsMapCompatible(mapName: string, teamSize: number): (boolean, string?)
	local ok, reason = self:_validateMapTemplate(mapName, teamSize)
	self._mapValidationWarnings = self._mapValidationWarnings or {}
	local key = tostring(teamSize) .. ":" .. mapName
	if not ok and self._mapValidationWarnings[key] ~= reason then
		self._mapValidationWarnings[key] = reason
		warn(string.format("[MatchInstanceService] Mapa incompatible para %dv%d: %s", teamSize, teamSize, tostring(reason)))
	elseif ok then
		self._mapValidationWarnings[key] = nil
	end
	return ok, reason
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
		-- Recuperación idempotente: elimina solamente recursos que aún pertenezcan
		-- al SessionId solicitado. Nunca libera un slot reasignado a otra sesión.
		if self._activeMatchesFolder then
			local orphan = self._activeMatchesFolder:FindFirstChild("Match_" .. matchId)
			if orphan then
				orphan:Destroy()
			end
		end
		for slot, ownerId in pairs(self._allocatedSlots) do
			if ownerId == matchId then
				self:_releaseSlot(slot, matchId)
			end
		end
		return true
	end

	-- Destruir contenedor y modelo clonado
	if info.EndCinematic then info.EndCinematic:Destroy() end
	if info.Container and info.Container.Parent then
		info.Container:Destroy()
	end

	-- Liberar ArenaSlot
	if not self:_releaseSlot(info.ArenaSlot, matchId) then
		warn(string.format("[MatchInstanceService] ArenaSlot %d ya no pertenece a Match '%s'", info.ArenaSlot, matchId))
		return false
	end

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
