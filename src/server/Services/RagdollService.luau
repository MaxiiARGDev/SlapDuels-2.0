--!strict
-- RagdollService
-- Servicio central para el ciclo de vida de Ragdoll y física de impacto/lanzamiento.
-- Coordina ReplicatedStorage.StateEvent y StarterCharacterScripts.RagdollStatesHandler.
-- Soporta avatares R15 modernos (AnimationConstraint + BallSocketConstraint) y R6 clásicos (Motor6D).
-- Diseñado para la onda expansiva del Point Effect y para el futuro sistema de combate/slap.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local RagdollService = {}
RagdollService.Name = "RagdollService"

RagdollService._context = nil :: any
RagdollService._activeTimers = {} :: { [Model]: thread }
RagdollService._r6Instances = {} :: { [Model]: { Instance } }

function RagdollService:_getStateEvent(): UnreliableRemoteEvent?
	local evt = ReplicatedStorage:FindFirstChild("StateEvent")
	if evt and evt:IsA("UnreliableRemoteEvent") then
		return evt
	elseif evt and evt:IsA("RemoteEvent") then
		return evt :: any
	end
	return nil
end

-- Retorna true si el personaje se encuentra actualmente en estado Ragdoll
function RagdollService:IsRagdolled(character: Model): boolean
	if not character then return false end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false end
	return humanoid.PlatformStand == true or self._activeTimers[character] ~= nil
end

-- Pasa el personaje a estado Ragdoll físico y notifica a RagdollStatesHandler
function RagdollService:ApplyRagdoll(character: Model, duration: number?, launchVelocity: Vector3?): boolean
	if not character or not character:IsDescendantOf(Workspace) then return false end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return false end

	-- Cancelar timer previo si ya estaba en ragdoll
	local prevTimer = self._activeTimers[character]
	if prevTimer then
		pcall(task.cancel, prevTimer)
		self._activeTimers[character] = nil
	end

	local hasAnimationConstraints = false
	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("AnimationConstraint") and desc.Name ~= "Root" then
			hasAnimationConstraints = true
			desc.Enabled = false
		end
	end

	-- Si es R6 clásico (no usa AnimationConstraint sino Motor6D)
	if not hasAnimationConstraints then
		local torso = character:FindFirstChild("Torso") :: BasePart?
		local rootJoint = rootPart:FindFirstChild("RootJoint") :: Motor6D?
		if torso and rootJoint then
			rootPart.Massless = true
			local instances = {}

			if not rootPart:FindFirstChild("TorsoWeld") then
				local torsoWeld = Instance.new("WeldConstraint")
				torsoWeld.Part0 = rootPart
				torsoWeld.Part1 = torso
				torsoWeld.Name = "TorsoWeld"
				torsoWeld.Parent = rootPart
				table.insert(instances, torsoWeld)
			end
			rootJoint.Enabled = false

			for _, v in ipairs(character:GetDescendants()) do
				if v:IsA("Motor6D") and v ~= rootJoint then
					local part0, part1 = v.Part0, v.Part1
					if part0 and part1 then
						local collider = Instance.new("Part")
						collider.Size = part1.Size / 1.7
						collider.CFrame = part1.CFrame
						collider.Massless = true
						collider.CanQuery = false
						collider.CanTouch = false
						collider.Transparency = 1
						collider.Name = "Collider"
						collider.Parent = part1
						table.insert(instances, collider)

						local colliderWeld = Instance.new("WeldConstraint")
						colliderWeld.Part0 = collider
						colliderWeld.Part1 = part1
						colliderWeld.Parent = collider
						table.insert(instances, colliderWeld)

						local attachment0 = Instance.new("Attachment")
						attachment0.CFrame = v.C0
						attachment0.Name = part1.Name .. "_RagdollAttachment0"
						attachment0.Parent = part0
						table.insert(instances, attachment0)

						local attachment1 = Instance.new("Attachment")
						attachment1.CFrame = v.C1
						attachment1.Name = "RagdollAttachment1"
						attachment1.Parent = part1
						table.insert(instances, attachment1)

						local ballSocket = Instance.new("BallSocketConstraint")
						ballSocket.Attachment0 = attachment0
						ballSocket.Attachment1 = attachment1
						ballSocket.LimitsEnabled = true
						ballSocket.TwistLimitsEnabled = true
						ballSocket.Name = "RagdollConstraint"
						ballSocket.Parent = part1
						table.insert(instances, ballSocket)

						v.Enabled = false
					end
				end
			end
			self._r6Instances[character] = instances
		end
	end

	-- Configuración del Humanoid
	humanoid.PlatformStand = true
	humanoid.AutoRotate = false
	rootPart.CanCollide = false

	-- Aplicar velocidad en el servidor si se provee a todas las partes
	if launchVelocity then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then
				part.AssemblyLinearVelocity = launchVelocity
				part.AssemblyAngularVelocity = Vector3.new(
					math.random(-6, 6),
					math.random(-6, 6),
					math.random(-6, 6)
				)
			end
		end
	end

	-- Notificar al cliente mediante StateEvent para activar RagdollStatesHandler
	local player = Players:GetPlayerFromCharacter(character)
	local stateEvent = self:_getStateEvent()
	if player and stateEvent then
		stateEvent:FireClient(player, false, launchVelocity)
	else
		pcall(function()
			humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end)
	end

	-- Programar recuperación automática
	local ragDuration = duration or (Config.Ragdoll and Config.Ragdoll.DefaultDuration) or 2.0
	if ragDuration > 0 then
		self._activeTimers[character] = task.delay(ragDuration, function()
			self:RemoveRagdoll(character)
		end)
	end

	return true
end

-- Restaura el personaje a su estado normal de locomoción notificando a RagdollStatesHandler
function RagdollService:RemoveRagdoll(character: Model): boolean
	local timer = self._activeTimers[character]
	if timer then
		pcall(task.cancel, timer)
		self._activeTimers[character] = nil
	end

	if not character or not character.Parent then return false end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?

	-- 1. Reactivar AnimationConstraints si es R15
	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("AnimationConstraint") then
			desc.Enabled = true
		end
	end

	-- 2. Limpiar R6 si correspondía
	local r6Instances = self._r6Instances[character]
	if r6Instances then
		if rootPart then rootPart.Massless = false end
		for _, v in ipairs(character:GetDescendants()) do
			if v:IsA("Motor6D") then
				v.Enabled = true
			end
		end
		for _, inst in ipairs(r6Instances) do
			if inst and inst.Parent then
				inst:Destroy()
			end
		end
		self._r6Instances[character] = nil
	end

	-- 3. Restaurar Humanoid y colisión del RootPart
	if rootPart then
		rootPart.CanCollide = true
	end

	if humanoid and humanoid.Health > 0 then
		humanoid.PlatformStand = false
		humanoid.AutoRotate = true

		local player = Players:GetPlayerFromCharacter(character)
		local stateEvent = self:_getStateEvent()
		if player and stateEvent then
			stateEvent:FireClient(player, true)
		else
			pcall(function()
				humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end)
		end
	end

	return true
end

-- Calcula el vector tridimensional de impulso de lanzamiento a partir de un punto de origen
function RagdollService:ComputeLaunchVelocity(
	originPos: Vector3,
	targetPos: Vector3,
	forceMagnitude: number?,
	upwardRatio: number?
): Vector3
	local force = forceMagnitude or (Config.Ragdoll and Config.Ragdoll.BlastForce) or 110
	local upRatio = upwardRatio or (Config.Ragdoll and Config.Ragdoll.UpwardRatio) or 0.65
	upRatio = math.clamp(upRatio, 0.2, 0.9)

	local diff = targetPos - originPos
	local horizontal = Vector3.new(diff.X, 0, diff.Z)
	local horizDist = horizontal.Magnitude

	local horizDir: Vector3
	if horizDist > 0.5 then
		horizDir = horizontal.Unit
	else
		-- Directamente en el epicentro: dispersar en dirección horizontal aleatoria
		local angle = math.random() * math.pi * 2
		horizDir = Vector3.new(math.cos(angle), 0, math.sin(angle))
	end

	-- Componente vertical fuerte y garantizado para elevar al personaje por los aires (vence gravedad 196.2)
	local vertSpeed = math.max(force * upRatio * 1.3, 85)
	local horizSpeed = force * (1 - upRatio * 0.4)

	return horizDir * horizSpeed + Vector3.new(0, vertSpeed, 0)
end

-- Aplica un impulso físico de lanzamiento al personaje alejándolo de un punto de origen
function RagdollService:LaunchCharacter(character: Model, originPos: Vector3, forceMagnitude: number?, upwardRatio: number?)
	if not character or not character:IsDescendantOf(Workspace) then return end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart? or character.PrimaryPart
	if not rootPart then return end

	local launchVel = self:ComputeLaunchVelocity(originPos, rootPart.Position, forceMagnitude, upwardRatio)

	-- Asignar velocidad lineal y rotacional en el servidor a todas las partes del cuerpo
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") then
			part.AssemblyLinearVelocity = launchVel
			part.AssemblyAngularVelocity = Vector3.new(
				math.random(-6, 6),
				math.random(-6, 6),
				math.random(-6, 6)
			)
		end
	end

	-- Notificar al cliente para que su simulación local replique el lanzamiento
	local player = Players:GetPlayerFromCharacter(character)
	local stateEvent = self:_getStateEvent()
	if player and stateEvent then
		stateEvent:FireClient(player, false, launchVel)
	end
end

-- Detona una onda expansiva en originPos, enviando en ragdoll y por los aires a todos los personajes dentro del radio
function RagdollService:BlastZone(
	originPos: Vector3,
	radius: number?,
	forceMagnitude: number?,
	upwardRatio: number?,
	duration: number?,
	filterFunc: ((Player?, Model) -> boolean)?
): number
	local blastRadius = radius or (Config.Ragdoll and Config.Ragdoll.BlastRadius) or 25
	local blastForce = forceMagnitude or (Config.Ragdoll and Config.Ragdoll.BlastForce) or 110
	local upRatio = upwardRatio or (Config.Ragdoll and Config.Ragdoll.UpwardRatio) or 0.65
	local ragDuration = duration or (Config.Ragdoll and Config.Ragdoll.DefaultDuration) or 2.0

	local affectedCount = 0

	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char and char:IsDescendantOf(Workspace) then
			local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local dist = (root.Position - originPos).Magnitude
				if dist <= blastRadius then
					local allowed = true
					if filterFunc then
						allowed = filterFunc(player, char)
					end
					if allowed then
						local falloff = math.clamp(1 - (dist / blastRadius) * 0.35, 0.65, 1.0)
						local force = blastForce * falloff
						local launchVel = self:ComputeLaunchVelocity(originPos, root.Position, force, upRatio)

						self:ApplyRagdoll(char, ragDuration, launchVel)
						affectedCount += 1
					end
				end
			end
		end
	end

	return affectedCount
end

function RagdollService:Init(context)
	self._context = context
	self._activeTimers = {}
	self._r6Instances = {}
end

function RagdollService:Start(context)
	self._context = context
	print("[RagdollService] Servicio de Ragdoll activo, integrado con ReplicatedStorage.StateEvent y RagdollStatesHandler")
end

return RagdollService
