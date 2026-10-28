--!strict
-- MatchmakingFeedbackService
-- Responsable exclusivo del feedback audiovisual (SFX espaciales, partículas, beams y cambios de material)
-- en las plataformas de matchmaking según las directrices de GAME_SDD.md.
-- NO gestiona la lógica de emparejamiento, detección ni colas (responsabilidad de MatchmakingService).
-- La instancia física (zoneFolder) es la identidad primaria para separar estados y recursos audiovisuales.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingFeedbackService = {}
MatchmakingFeedbackService.Name = "MatchmakingFeedbackService"

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

-- Configuración de presentación audiovisual
local EFFECT_VERTICAL_OFFSET = Vector3.new(0, 4, 0)
local OCCUPIED_MATERIAL = Enum.Material.Neon

export type TeamEffectAssets = {
	effectsFolder: Instance,
	soundJoin: Sound?,
	soundJoinMusic: Sound?,
	soundLeave: Sound?,
	activateTemplate: Part?,
	beamTemplates: { Part },
}

export type ZoneFeedbackState = {
	ZoneFolder: Folder,
	EffectsFolder: Folder?,
	Pads: { [string]: BasePart }, -- teamName ("Red", "Blue") -> BasePart
	OriginalMaterials: { [string]: Enum.Material },
	TeamEffects: { [string]: TeamEffectAssets },
	ActiveClones: { [string]: Part },
	ActiveBeamClones: { [string]: { Part } },
	ActiveMusicClones: { [string]: Sound },
	PadOccupied: { [string]: boolean },
	Occupants: { [string]: Player? },
}

MatchmakingFeedbackService._context = nil :: any
MatchmakingFeedbackService._zones = {} :: { [Folder]: ZoneFeedbackState }

-- Descubre y actualiza dinámicamente todos los ParticleEmitter descendientes
local function setEmittersEnabled(instance: Instance, enabled: boolean)
	for _, desc in ipairs(instance:GetDescendants()) do
		if desc:IsA("ParticleEmitter") then
			desc.Enabled = enabled
		end
	end
	if instance:IsA("ParticleEmitter") then
		instance.Enabled = enabled
	end
end

-- Descubre y actualiza dinámicamente todos los Beams descendientes
local function setBeamsEnabled(instance: Instance, enabled: boolean)
	for _, desc in ipairs(instance:GetDescendants()) do
		if desc:IsA("Beam") then
			desc.Enabled = enabled
		end
	end
	if instance:IsA("Beam") then
		instance.Enabled = enabled
	end
end

-- Carga y configura los templates de efectos de un contenedor dado (carpeta de equipo o carpeta raíz)
local function loadTeamEffects(folder: Instance): TeamEffectAssets
	local soundJoin = folder:FindFirstChild("SoundJoin")
	local soundJoinMusic = folder:FindFirstChild("SoundJoinMusic")
	local soundLeave = folder:FindFirstChild("SoundLeave")
	local activateTemplate = folder:FindFirstChild("ActivateParticle")

	if activateTemplate and activateTemplate:IsA("BasePart") then
		activateTemplate.Anchored = true
		activateTemplate.CanCollide = false
		setEmittersEnabled(activateTemplate, false)
	end

	local beamTemplates: { Part } = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") and child ~= activateTemplate then
			local hasBeam = child:FindFirstChildOfClass("Beam") ~= nil
			if not hasBeam then
				for _, d in ipairs(child:GetDescendants()) do
					if d:IsA("Beam") then
						hasBeam = true
						break
					end
				end
			end

			if hasBeam then
				table.insert(beamTemplates, child :: Part)
				setBeamsEnabled(child, false)
			end
		end
	end

	return {
		effectsFolder = folder,
		soundJoin = (soundJoin and soundJoin:IsA("Sound")) and soundJoin or nil,
		soundJoinMusic = (soundJoinMusic and soundJoinMusic:IsA("Sound")) and soundJoinMusic or nil,
		soundLeave = (soundLeave and soundLeave:IsA("Sound")) and soundLeave or nil,
		activateTemplate = (activateTemplate and activateTemplate:IsA("Part")) and (activateTemplate :: Part) or nil,
		beamTemplates = beamTemplates,
	}
end

-- Limpia instancias temporales residuales en una carpeta
local function cleanupResidualInstances(container: Instance)
	for _, child in ipairs(container:GetChildren()) do
		if child.Name:find("ParticleInstance_") or child.Name:find("BeamInstance_") or child.Name:find("SpatialSound_") or child.Name:find("SpatialMusic_") then
			child:Destroy()
		end
	end
end

-- Reproduce un sonido espacializado en la posición de un BasePart (escuchado por todos los jugadores cercanos)
function MatchmakingFeedbackService:_playSpatialSound(soundTemplate: Sound?, targetPart: BasePart?)
	if not soundTemplate then return end

	if not targetPart then
		soundTemplate:Play()
		return
	end

	-- Clonar el sonido en el pad correspondiente para obtener audio 3D posicional nativo con sus propiedades de Studio
	local spatialClone = soundTemplate:Clone()
	spatialClone.Name = "SpatialSound_" .. soundTemplate.Name
	spatialClone.PlayOnRemove = false
	spatialClone.Parent = targetPart

	local cleanupConnection: RBXScriptConnection?
	cleanupConnection = spatialClone.Ended:Connect(function()
		if cleanupConnection then
			cleanupConnection:Disconnect()
		end
		spatialClone:Destroy()
	end)

	-- Timeout de seguridad para evitar fugas de instancias si el sonido se interrumpe
	task.delay(math.max(spatialClone.TimeLength + 1, 4), function()
		if spatialClone and spatialClone.Parent then
			spatialClone:Destroy()
		end
	end)

	spatialClone:Play()
end

function MatchmakingFeedbackService:_ensureRemotes()
	local remotesFolder = ensureRemoteFolder(ReplicatedStorage, "Remotes")
	local mmFolder = ensureRemoteFolder(remotesFolder, "Matchmaking")
	ensureRemoteEvent(mmFolder, "PadMusic")
end

function MatchmakingFeedbackService:_getRemote(eventName: string): RemoteEvent?
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local mmFolder = remotes and remotes:FindFirstChild("Matchmaking")
	local event = mmFolder and mmFolder:FindFirstChild(eventName)
	if event and event:IsA("RemoteEvent") then
		return event
	end
	return nil
end

function MatchmakingFeedbackService:Init(context)
	self._context = context
	self._zones = {}
	self:_ensureRemotes()

	-- Descubrir y registrar todas las zonas físicas existentes en Workspace.ZoneMatchmaking
	local zoneContainer = Workspace:FindFirstChild("ZoneMatchmaking")
	if not zoneContainer then
		warn("[MatchmakingFeedbackService] No se encontro Workspace.ZoneMatchmaking")
		return
	end

	for _, child in ipairs(zoneContainer:GetChildren()) do
		if child:IsA("Folder") then
			self:RegisterZone(child)
		end
	end
end

function MatchmakingFeedbackService:Start(context)
	self._context = context
	print("[MatchmakingFeedbackService] Servicio audiovisual de matchmaking iniciado y listo para múltiples zonas")
end

-- Registra una zona física específica y sus assets independientes
function MatchmakingFeedbackService:RegisterZone(zoneFolder: Folder)
	if not zoneFolder or not zoneFolder:IsA("Folder") then return end
	if self._zones[zoneFolder] then return end

	local pads: { [string]: BasePart } = {}
	local originalMaterials: { [string]: Enum.Material } = {}
	local padOccupied: { [string]: boolean } = {}

	local joinsFolder = zoneFolder:FindFirstChild("joins-parts")
	if joinsFolder then
		for _, padChild in ipairs(joinsFolder:GetChildren()) do
			if padChild:IsA("BasePart") then
				local teamAttr = padChild:GetAttribute("Team")
				local teamName = if typeof(teamAttr) == "string" and teamAttr ~= ""
					then teamAttr
					elseif padChild.Name == "Red" or padChild.Name:find("Red") then "Red"
					elseif padChild.Name == "Blue" or padChild.Name:find("Blue") then "Blue"
					else padChild.Name

				pads[teamName] = padChild
				originalMaterials[teamName] = padChild.Material
				padOccupied[teamName] = false

				-- Limpieza de sonidos residuales en el pad
				for _, c in ipairs(padChild:GetChildren()) do
					if c.Name:find("SpatialSound_") or c.Name:find("SpatialMusic_") then
						c:Destroy()
					end
				end
			end
		end
	else
		warn(string.format("[MatchmakingFeedbackService] Carpeta 'joins-parts' no encontrada en zona '%s'", zoneFolder.Name))
	end

	local teamEffects: { [string]: TeamEffectAssets } = {}
	local effectsFolder = zoneFolder:FindFirstChild("effects") :: Folder?

	if effectsFolder and (effectsFolder:IsA("Folder") or effectsFolder:IsA("Model")) then
		cleanupResidualInstances(effectsFolder)

		for teamName, _ in pairs(pads) do
			local teamFolder = effectsFolder:FindFirstChild(teamName)
			if teamFolder and (teamFolder:IsA("Folder") or teamFolder:IsA("Model")) then
				cleanupResidualInstances(teamFolder)
				teamEffects[teamName] = loadTeamEffects(teamFolder)
			else
				teamEffects[teamName] = loadTeamEffects(effectsFolder)
			end
		end
	end

	local zoneFeedbackState: ZoneFeedbackState = {
		ZoneFolder = zoneFolder,
		EffectsFolder = effectsFolder,
		Pads = pads,
		OriginalMaterials = originalMaterials,
		TeamEffects = teamEffects,
		ActiveClones = {},
		ActiveBeamClones = {},
		ActiveMusicClones = {},
		PadOccupied = padOccupied,
		Occupants = {},
	}

	self._zones[zoneFolder] = zoneFeedbackState
	print(string.format("[MatchmakingFeedbackService] Zona registrada para feedback: '%s'", zoneFolder.Name))
end

-- Desregistra una zona física y realiza cleanup completo de sus recursos
function MatchmakingFeedbackService:UnregisterZone(zoneFolder: Folder)
	local zoneState = self._zones[zoneFolder]
	if not zoneState then return end

	-- Desactivar y limpiar feedback de todos los pads de esta zona
	for teamName, isOccupied in pairs(zoneState.PadOccupied) do
		if isOccupied then
			zoneState.PadOccupied[teamName] = false
			self:_deactivateZoneFeedback(zoneState, teamName)
		end
	end

	-- Limpiar ocupantes registrados
	zoneState.Occupants = {}

	-- Detener y destruir música activa remanente
	for teamName, musicClone in pairs(zoneState.ActiveMusicClones) do
		if musicClone and musicClone.Parent then
			musicClone:Stop()
			musicClone:Destroy()
		end
	end
	zoneState.ActiveMusicClones = {}

	-- Restaurar materiales en todos los pads
	for teamName, pad in pairs(zoneState.Pads) do
		local origMat = zoneState.OriginalMaterials[teamName]
		if pad and pad.Parent and origMat then
			pad.Material = origMat
		end
	end

	self._zones[zoneFolder] = nil
	print(string.format("[MatchmakingFeedbackService] Zona desregistrada y limpiada: '%s'", zoneFolder.Name))
end

-- Actualiza el estado de ocupación de un pad en una zona física específica
function MatchmakingFeedbackService:SetPadOccupied(zoneFolder: Folder, teamName: string, isOccupied: boolean, occupant: Player?)
	if not zoneFolder then return end

	local zoneState = self._zones[zoneFolder]
	if not zoneState then
		self:RegisterZone(zoneFolder)
		zoneState = self._zones[zoneFolder]
		if not zoneState then return end
	end

	local wasOccupied = zoneState.PadOccupied[teamName] == true
	if wasOccupied == isOccupied then
		return
	end

	zoneState.PadOccupied[teamName] = isOccupied

	if isOccupied then
		self:_activateZoneFeedback(zoneState, teamName, occupant)
	else
		self:_deactivateZoneFeedback(zoneState, teamName)
	end
end

-- Activa el feedback audiovisual en una zona física y equipo específicos
function MatchmakingFeedbackService:_activateZoneFeedback(zoneState: ZoneFeedbackState, teamName: string, occupant: Player?)
	local pad = zoneState.Pads[teamName]
	if not pad then return end

	local teamAssets = zoneState.TeamEffects[teamName]
	local targetFolder = (teamAssets and teamAssets.effectsFolder) or zoneState.EffectsFolder or pad.Parent

	-- 1. Reproducir SoundJoin espacializado del color correspondiente
	if teamAssets and teamAssets.soundJoin then
		self:_playSpatialSound(teamAssets.soundJoin, pad)
	end

	-- Registrar ocupante del pad para tracking de feedback
	zoneState.Occupants[teamName] = occupant

	-- 2. Cambiar material del pad a Neon
	pad.Material = OCCUPIED_MATERIAL

	-- 3. Instanciar clon temporal de partículas correspondiente al color
	if teamAssets and teamAssets.activateTemplate then
		local previousClone = zoneState.ActiveClones[teamName]
		if previousClone and previousClone.Parent then
			previousClone:Destroy()
		end

		local clone = teamAssets.activateTemplate:Clone() :: Part
		clone.Name = "ParticleInstance_" .. teamName
		clone.CanCollide = false
		clone.CanTouch = false
		clone.CanQuery = false
		clone.Anchored = true
		clone.CastShadow = false

		-- Posicionar sobre el pad correspondiente
		local targetPosition = pad.Position + EFFECT_VERTICAL_OFFSET
		clone.CFrame = CFrame.new(targetPosition)

		-- Activar dinámicamente todos los ParticleEmitters descendientes del color
		setEmittersEnabled(clone, true)

		-- Parentar a la carpeta de efectos del color
		clone.Parent = targetFolder
		zoneState.ActiveClones[teamName] = clone
	end

	-- 4. Instanciar y activar clones de Beams correspondientes al color
	local beamClones: { Part } = {}
	if teamAssets and teamAssets.beamTemplates then
		for _, beamTemplate in ipairs(teamAssets.beamTemplates) do
			local beamClone = beamTemplate:Clone() :: Part
			beamClone.Name = "BeamInstance_" .. teamName .. "_" .. beamTemplate.Name
			beamClone.CanCollide = false
			beamClone.CanTouch = false
			beamClone.CanQuery = false
			beamClone.Anchored = true
			beamClone.CastShadow = false

			-- Posicionar relativo al pad activo
			local relCFrame = pad.CFrame:ToObjectSpace(beamTemplate.CFrame)
			beamClone.CFrame = pad.CFrame * relCFrame

			-- Activar todos los Beams dentro del clon del color
			setBeamsEnabled(beamClone, true)

			beamClone.Parent = targetFolder
			table.insert(beamClones, beamClone)
		end
	end

	zoneState.ActiveBeamClones[teamName] = beamClones

	local occupantName = occupant and occupant.Name or "Desconocido"
	print(string.format("[MatchmakingFeedbackService] Feedback activado para pad '%s' en zona '%s' (Ocupante: %s)",
		teamName, zoneState.ZoneFolder.Name, occupantName))
end

-- Desactiva el feedback audiovisual en una zona física y equipo específicos
function MatchmakingFeedbackService:_deactivateZoneFeedback(zoneState: ZoneFeedbackState, teamName: string)
	local pad = zoneState.Pads[teamName]
	local teamAssets = zoneState.TeamEffects[teamName]
	local targetFolder = (teamAssets and teamAssets.effectsFolder) or zoneState.EffectsFolder

	-- 1. Limpiar ocupante registrado del pad
	local previousOccupant = zoneState.Occupants[teamName]
	zoneState.Occupants[teamName] = nil

	-- Limpieza defensiva de cualquier clon previo en el pad
	local activeMusic = zoneState.ActiveMusicClones[teamName]
	if activeMusic then
		zoneState.ActiveMusicClones[teamName] = nil
		if activeMusic.IsPlaying then
			activeMusic:Stop()
		end
		activeMusic:Destroy()
	end

	if pad then
		local leftoverMusic = pad:FindFirstChild("SpatialMusic_" .. teamName)
		if leftoverMusic then
			if leftoverMusic:IsA("Sound") and leftoverMusic.IsPlaying then
				leftoverMusic:Stop()
			end
			leftoverMusic:Destroy()
		end
	end

	-- 1b. Reproducir SoundLeave espacializado del color correspondiente
	if pad and teamAssets and teamAssets.soundLeave then
		self:_playSpatialSound(teamAssets.soundLeave, pad)
	end

	-- 2. Restaurar exactamente el material original guardado
	local originalMaterial = zoneState.OriginalMaterials[teamName]
	if pad and originalMaterial then
		pad.Material = originalMaterial
	end

	-- 3. Limpiar la instancia temporal de partículas
	local clone = zoneState.ActiveClones[teamName]
	if clone then
		zoneState.ActiveClones[teamName] = nil
		setEmittersEnabled(clone, false)
		clone:Destroy()
	end

	-- Fallback para garantizar que no queden partículas residuales
	if targetFolder then
		local leftoverParticle = targetFolder:FindFirstChild("ParticleInstance_" .. teamName)
		if leftoverParticle then
			leftoverParticle:Destroy()
		end
	end
	if zoneState.EffectsFolder and zoneState.EffectsFolder ~= targetFolder then
		local leftoverParticle = zoneState.EffectsFolder:FindFirstChild("ParticleInstance_" .. teamName)
		if leftoverParticle then
			leftoverParticle:Destroy()
		end
	end

	-- 4. Limpiar los clones temporales de Beams
	local beamClones = zoneState.ActiveBeamClones[teamName]
	if beamClones then
		zoneState.ActiveBeamClones[teamName] = nil
		for _, bClone in ipairs(beamClones) do
			setBeamsEnabled(bClone, false)
			bClone:Destroy()
		end
	end

	-- Fallback para garantizar que no queden beams residuales
	if targetFolder then
		for _, child in ipairs(targetFolder:GetChildren()) do
			if child.Name:find("BeamInstance_" .. teamName) then
				child:Destroy()
			end
		end
	end
	if zoneState.EffectsFolder and zoneState.EffectsFolder ~= targetFolder then
		for _, child in ipairs(zoneState.EffectsFolder:GetChildren()) do
			if child.Name:find("BeamInstance_" .. teamName) then
				child:Destroy()
			end
		end
	end

	print(string.format("[MatchmakingFeedbackService] Feedback desactivado y limpiado para pad '%s' en zona '%s'",
		teamName, zoneState.ZoneFolder.Name))
end

-- Consulta de assets de equipo para una zona dada
function MatchmakingFeedbackService:GetTeamAssets(zoneFolder: Folder, teamName: string): TeamEffectAssets?
	local zoneState = self._zones[zoneFolder]
	return zoneState and zoneState.TeamEffects[teamName]
end

-- Limpieza global de todas las zonas
function MatchmakingFeedbackService:ResetAll()
	for zoneFolder, zoneState in pairs(self._zones) do
		for teamName, isOccupied in pairs(zoneState.PadOccupied) do
			if isOccupied then
				zoneState.PadOccupied[teamName] = false
				self:_deactivateZoneFeedback(zoneState, teamName)
			end
		end

		for teamName, musicClone in pairs(zoneState.ActiveMusicClones) do
			if musicClone and musicClone.Parent then
				musicClone:Stop()
				musicClone:Destroy()
			end
		end
		zoneState.ActiveMusicClones = {}
	end
end

-- Consultas de estado por zona
function MatchmakingFeedbackService:IsPadOccupied(zoneFolder: Folder, teamName: string): boolean
	local zoneState = self._zones[zoneFolder]
	return (zoneState and zoneState.PadOccupied[teamName] == true) or false
end

function MatchmakingFeedbackService:GetActiveClone(zoneFolder: Folder, teamName: string): Part?
	local zoneState = self._zones[zoneFolder]
	return zoneState and zoneState.ActiveClones[teamName]
end

function MatchmakingFeedbackService:GetActiveBeamClones(zoneFolder: Folder, teamName: string): { Part }?
	local zoneState = self._zones[zoneFolder]
	return zoneState and zoneState.ActiveBeamClones[teamName]
end

function MatchmakingFeedbackService:GetActiveMusic(zoneFolder: Folder, teamName: string): Sound?
	local zoneState = self._zones[zoneFolder]
	return zoneState and zoneState.ActiveMusicClones[teamName]
end

return MatchmakingFeedbackService
