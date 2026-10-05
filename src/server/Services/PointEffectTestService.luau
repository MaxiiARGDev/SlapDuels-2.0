--!strict
-- PointEffectTestService
-- Herramienta exclusiva de desarrollo y testing para Point Effects.
-- Permite probar cosméticos directamente en Workspace.PointEffectTest.TestPart
-- sin iniciar partidas, sin ScoreService, sin Coins, sin MatchScore ni alterar el gameplay.
-- Reutiliza autoritativamente PointEffectRegistry y los Controllers de coreografía.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local PointEffectTestService = {}
PointEffectTestService.Name = "PointEffectTestService"

PointEffectTestService._context = nil :: any
PointEffectTestService._cooldowns = {} :: { [BasePart]: number }
PointEffectTestService._activeHandles = {} :: { [BasePart]: { any } }
PointEffectTestService._touchingPlayers = {} :: { [BasePart]: { [Player]: boolean } }
PointEffectTestService._connections = {} :: { RBXScriptConnection }

-- Resuelve el catálogo de PointEffectRegistry
function PointEffectTestService:_getRegistry()
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

-- Obtiene el template visual/sonoro desde ServerStorage.PointEffects[EffectId]
function PointEffectTestService:_getEffectTemplate(effectId: string): Instance?
	local pointEffectsFolder = ServerStorage:FindFirstChild("PointEffects")
	if not pointEffectsFolder then
		warn("[PointEffectTestService] ServerStorage.PointEffects no existe")
		return nil
	end

	local template = pointEffectsFolder:FindFirstChild(effectId)
	if not template then
		warn(string.format("[PointEffectTestService] Template para '%s' no encontrado en ServerStorage.PointEffects", tostring(effectId)))
		return nil
	end

	return template
end

-- Obtiene el RemoteEvent PointFeedback de ReplicatedStorage.Remotes.Match
function PointEffectTestService:_getFeedbackRemote(): RemoteEvent?
	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local matchFolder = remotes and remotes:FindFirstChild("Match")
	local pointFeedback = matchFolder and matchFolder:FindFirstChild("PointFeedback")
	if pointFeedback and pointFeedback:IsA("RemoteEvent") then
		return pointFeedback
	end
	return nil
end

-- Obtiene el servicio de Ragdoll para física de impacto
function PointEffectTestService:_getRagdollService()
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

-- Extrae el Player desde un BasePart del personaje
local function getPlayerFromHit(hit: BasePart): Player?
	if not hit or not hit:IsA("BasePart") then return nil end
	local current: Instance? = hit
	while current and current ~= Workspace do
		if current:IsA("Model") then
			local hum = current:FindFirstChildOfClass("Humanoid")
			if hum then
				return Players:GetPlayerFromCharacter(current)
			end
		end
		current = current.Parent
	end
	return nil
end

-- Ejecuta la prueba de un cosmético sobre el TestPart
function PointEffectTestService:_triggerTest(part: BasePart, player: Player?)
	if not part or not part:IsDescendantOf(Workspace) then return end

	-- Si el jugador ya se encuentra en estado Ragdoll, ignorar activación para evitar bucles
	if player and player.Character then
		local ragdollService = self:_getRagdollService()
		if ragdollService and ragdollService:IsRagdolled(player.Character) then
			return
		end
	end

	-- 1. Verificación de Cooldown
	local rawCooldown = part:GetAttribute("Cooldown")
	local cooldown = if typeof(rawCooldown) == "number" and rawCooldown >= 0 then rawCooldown else 1.0

	local now = os.clock()
	local lastTime = self._cooldowns[part] or 0
	if (now - lastTime) < cooldown then
		-- Cooldown activo: ignorar activaciones repetidas
		return
	end
	self._cooldowns[part] = now

	-- 2. Lectura y validación de EffectId
	local rawEffectId = part:GetAttribute("EffectId")
	if not rawEffectId or typeof(rawEffectId) ~= "string" or rawEffectId == "" then
		warn(string.format("[PointEffectTestService] TestPart '%s' tiene EffectId vacío o inválido", part:GetFullName()))
		return
	end
	local effectId = rawEffectId

	-- 3. Localizar template del efecto en ServerStorage.PointEffects
	local template = self:_getEffectTemplate(effectId)
	if not template then
		return
	end

	-- 4. Obtener Controller correspondiente desde PointEffectRegistry
	local registry = self:_getRegistry()
	local controller = registry and registry.GetController(effectId)
	if not controller or typeof(controller.Play) ~= "function" then
		warn(string.format("[PointEffectTestService] Controller no disponible para '%s'", effectId))
		return
	end

	-- 5. Clonar y posicionar físicamente en TestPart
	local clone = template:Clone()
	if clone:IsA("Model") then
		clone:PivotTo(CFrame.new(part.Position))
	elseif clone:IsA("BasePart") then
		clone.CFrame = CFrame.new(part.Position)
	end
	clone.Parent = part

	-- 6. Construir contexto de prueba compatible
	local isFinalPoint = (part:GetAttribute("IsFinalPoint") == true)
	local testPointId = string.format("TEST_%s_%d", effectId, math.floor(now * 1000))
	local testContext = {
		EffectModel = clone :: Model,
		ScoringZone = part,
		OriginPart = part,
		ScoringPlayer = player,
		MatchId = "TEST",
		PointId = testPointId,
		IsFinalPoint = isFinalPoint,
		Score = { Red = 0, Blue = 0 },
	}

	-- 7. Ejecutar coreografía mediante el controller
	local ok, handle = pcall(function()
		return controller.Play(testContext)
	end)

	if ok and handle and typeof(handle) == "table" then
		if not self._activeHandles[part] then
			self._activeHandles[part] = {}
		end
		table.insert(self._activeHandles[part], handle)
	elseif not ok then
		warn(string.format("[PointEffectTestService] Error al reproducir '%s': %s", effectId, tostring(handle)))
		if clone and clone.Parent then
			clone:Destroy()
		end
		return
	end

	-- 8. Broadcast a clientes vía RemoteEvent PointFeedback (para PointCameraFX y feedback de cámara)
	local feedbackRemote = self:_getFeedbackRemote()
	if feedbackRemote then
		local broadcastData = {
			MatchId = "TEST",
			PointId = testPointId,
			ScoringTeam = "Test",
			ScoringPlayer = player,
			ScoringPlayerName = if player then player.Name else "Touched",
			ScoringZonePosition = part.Position,
			IsFinalPoint = isFinalPoint,
			EffectId = effectId,
		}
		feedbackRemote:FireAllClients(broadcastData)
	end

	local playerName = if player then player.Name else "Touched"
	print(string.format("[PointEffectTestService] PointEffect '%s' ejecutado en TestPart (Invocador: %s, PointId: %s, Final: %s)",
		effectId, playerName, testPointId, tostring(isFinalPoint)))

	-- 9. Física de lanzamiento en Ragdoll por la onda expansiva
	local ragdollService = self:_getRagdollService()
	if ragdollService then
		local rawRadius = part:GetAttribute("RagdollRadius")
		local rawForce = part:GetAttribute("RagdollForce")
		local rawDuration = part:GetAttribute("RagdollDuration")
		local rawUpRatio = part:GetAttribute("UpwardRatio")

		local blastRadius = if typeof(rawRadius) == "number" then rawRadius else (Config.Ragdoll and Config.Ragdoll.BlastRadius) or 100
		local blastForce = if typeof(rawForce) == "number" then rawForce else (Config.Ragdoll and Config.Ragdoll.BlastForce) or 110
		local ragDuration = if typeof(rawDuration) == "number" then rawDuration else (Config.Ragdoll and Config.Ragdoll.DefaultDuration) or 5.0
		local upRatio = if typeof(rawUpRatio) == "number" then rawUpRatio else (Config.Ragdoll and Config.Ragdoll.UpwardRatio) or 1.0
		if isFinalPoint then
			blastForce *= 1.3
		end

		local affectScorer = part:GetAttribute("AffectScorer") == true
		local function filterScoringPlayer(targetPlayer: Player?, _char: Model): boolean
			if not affectScorer and player and targetPlayer == player then
				return false -- El jugador que anota el punto no es afectado por la explosión ni el ragdoll
			end
			return true
		end

		ragdollService:BlastZone(part.Position, blastRadius, blastForce, upRatio, ragDuration, filterScoringPlayer)
	end
end

-- Configura y registra un TestPart con Attributes, ProximityPrompt y conexiones
function PointEffectTestService:RegisterTestPart(part: BasePart)
	if not part or not part:IsA("BasePart") then return end

	-- Asegurar atributos por defecto
	if part:GetAttribute("EffectId") == nil then
		part:SetAttribute("EffectId", "Basic")
	end
	if part:GetAttribute("Cooldown") == nil then
		part:SetAttribute("Cooldown", 1)
	end
	if part:GetAttribute("IsFinalPoint") == nil then
		part:SetAttribute("IsFinalPoint", false)
	end
	if part:GetAttribute("RagdollForce") == nil then
		part:SetAttribute("RagdollForce", (Config.Ragdoll and Config.Ragdoll.BlastForce) or 110)
	end
	if part:GetAttribute("RagdollRadius") == nil then
		part:SetAttribute("RagdollRadius", (Config.Ragdoll and Config.Ragdoll.BlastRadius) or 100)
	end
	if part:GetAttribute("RagdollDuration") == nil then
		part:SetAttribute("RagdollDuration", (Config.Ragdoll and Config.Ragdoll.DefaultDuration) or 5.0)
	end
	if part:GetAttribute("UpwardRatio") == nil then
		part:SetAttribute("UpwardRatio", (Config.Ragdoll and Config.Ragdoll.UpwardRatio) or 1.0)
	end
	if part:GetAttribute("AffectScorer") == nil then
		part:SetAttribute("AffectScorer", false)
	end

	-- Asegurar ProximityPrompt para activación manual (permite activarlo desde lejos para probar la distancia)
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.Name = "TestPrompt"
		prompt.ActionText = "Probar efecto"
		prompt.ObjectText = "Point Effect Test"
		prompt.MaxActivationDistance = 35
		prompt.RequiresLineOfSight = false
		prompt.Parent = part
	else
		prompt.MaxActivationDistance = 35
	end

	-- Conexión ProximityPrompt
	local promptConn = prompt.Triggered:Connect(function(player: Player)
		self:_triggerTest(part, player)
	end)
	table.insert(self._connections, promptConn)

	-- Conexión Touched (sólo para personajes vivos que no estén actualmente en ragdoll ni ya dentro del part)
	local touchConn = part.Touched:Connect(function(hit: BasePart)
		local player = getPlayerFromHit(hit)
		if not player or not player.Character then return end

		local ragdollService = self:_getRagdollService()
		if ragdollService and ragdollService:IsRagdolled(player.Character) then
			return
		end

		if not self._touchingPlayers[part] then
			self._touchingPlayers[part] = {}
		end
		if self._touchingPlayers[part][player] then
			return
		end
		self._touchingPlayers[part][player] = true

		self:_triggerTest(part, player)
	end)
	table.insert(self._connections, touchConn)

	-- Conexión TouchEnded para permitir volver a activar al salir y re-entrar
	local touchEndConn = part.TouchEnded:Connect(function(hit: BasePart)
		local player = getPlayerFromHit(hit)
		if player and self._touchingPlayers[part] then
			self._touchingPlayers[part][player] = nil
		end
	end)
	table.insert(self._connections, touchEndConn)

	print(string.format("[PointEffectTestService] TestPart registrado: %s [EffectId=%s, Cooldown=%s, AffectScorer=%s]",
		part:GetFullName(), tostring(part:GetAttribute("EffectId")), tostring(part:GetAttribute("Cooldown")), tostring(part:GetAttribute("AffectScorer"))))
end

-- Crea la estructura física predeterminada en Workspace si no existe
function PointEffectTestService:EnsureDefaultTestSetup(): (Folder, BasePart)
	local container = Workspace:FindFirstChild("PointEffectTest") :: Folder?
	if not container then
		container = Instance.new("Folder")
		container.Name = "PointEffectTest"
		container.Parent = Workspace
	end

	local testPart = container:FindFirstChild("TestPart") :: BasePart?
	if not testPart then
		local part = Instance.new("Part")
		part.Name = "TestPart"
		part.Size = Vector3.new(4, 0.6, 4)
		part.Position = Vector3.new(35, 0.5, -115) -- Cerca del Spawn del Lobby
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(255, 170, 0)
		part.Anchored = true
		part.CanCollide = true
		part:SetAttribute("EffectId", "Basic")
		part:SetAttribute("Cooldown", 1)
		part.Parent = container
		testPart = part
	end

	-- Indicador visual del radio de explosión en el suelo
	local adorn = testPart:FindFirstChild("BlastRadiusIndicator") :: CylinderHandleAdornment?
	if not adorn then
		adorn = Instance.new("CylinderHandleAdornment")
		adorn.Name = "BlastRadiusIndicator"
		adorn.Adornee = testPart
		adorn.Radius = (testPart:GetAttribute("RagdollRadius")) or 25
		adorn.Height = 0.05
		adorn.CFrame = CFrame.Angles(math.rad(90), 0, 0)
		adorn.Color3 = Color3.fromRGB(255, 170, 0)
		adorn.Transparency = 0.85
		adorn.AlwaysOnTop = false
		adorn.Parent = testPart
	end

	return container, testPart
end

function PointEffectTestService:Init(context)
	self._context = context
	self._cooldowns = {}
	self._activeHandles = {}
	self._touchingPlayers = {}
	self._connections = {}
end

function PointEffectTestService:Start(context)
	self._context = context

	-- 1. Crear o localizar la estructura en Workspace
	local container, defaultPart = self:EnsureDefaultTestSetup()
	self:RegisterTestPart(defaultPart)

	-- 2. Registrar cualquier otro part dentro de Workspace.PointEffectTest
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("BasePart") and child ~= defaultPart then
			self:RegisterTestPart(child)
		end
	end

	-- 3. Escuchar adiciones dinámicas en tiempo de ejecución (útil en Studio)
	local childConn = container.ChildAdded:Connect(function(child: Instance)
		if child:IsA("BasePart") then
			self:RegisterTestPart(child)
		end
	end)
	table.insert(self._connections, childConn)

	print("[PointEffectTestService] Servicio de testing de Point Effects activo y listo")
end

-- Limpieza de efectos activos de un TestPart específico o de todos
function PointEffectTestService:CleanupTest(part: BasePart?)
	if part then
		local handles = self._activeHandles[part]
		if handles then
			for _, h in ipairs(handles) do
				if typeof(h) == "table" and typeof(h.Destroy) == "function" then
					pcall(function() h:Destroy() end)
				end
			end
			self._activeHandles[part] = nil
		end
	else
		for _, handles in pairs(self._activeHandles) do
			for _, h in ipairs(handles) do
				if typeof(h) == "table" and typeof(h.Destroy) == "function" then
					pcall(function() h:Destroy() end)
				end
			end
		end
		self._activeHandles = {}
	end
end

return PointEffectTestService
