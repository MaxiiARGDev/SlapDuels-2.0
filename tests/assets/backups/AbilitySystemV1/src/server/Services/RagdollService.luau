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
RagdollService._rootCollisions = setmetatable({}, { __mode = "k" }) :: { [Model]: boolean }

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
	if character:GetAttribute("ArenaRespawnPending") then return false end
	local owner = Players:GetPlayerFromCharacter(character)
	if owner and owner:GetAttribute("ResultsSessionId") ~= nil then return false end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return false end

	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootPart then return false end
	if self._rootCollisions[character] == nil then self._rootCollisions[character] = rootPart.CanCollide end

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
	-- Repeated hits refresh velocity/timer, not the physical rig. Replacing this
	-- list leaked the first hit's constraints/colliders beyond ResetRagdollImmediate.
	if not hasAnimationConstraints and not self._r6Instances[character] then
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
						collider.CollisionGroup = part1.CollisionGroup
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
		stateEvent:FireClient(player, false, launchVelocity, player:GetAttribute("MatchId"), character:GetAttribute("ArenaPhysicsGeneration") or 0, character)
	else
		pcall(function()
			humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)
			humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		end)
	end

	-- Programar recuperación automática
	local ragDuration = duration or (Config.Ragdoll and Config.Ragdoll.DefaultDuration) or 2.0
	if ragDuration > 0 then
		local generation = character:GetAttribute("ArenaPhysicsGeneration") or 0
		local sessionId = player and player:GetAttribute("MatchId")
		local rounds = self._context and self._context:GetService("RoundService")
		local session = player and rounds and rounds:GetSessionForPlayer(player)
		local stateVersion = session and session.StateVersion
		local deadline=os.clock()+ragDuration
		character:SetAttribute("RagdollRecoveryDeadline",deadline)
		local recovery: thread
		recovery = task.delay(math.max(0,deadline-os.clock()), function()
			local stale = self._activeTimers[character] ~= recovery or not character:IsDescendantOf(Workspace)
				or (character:GetAttribute("ArenaPhysicsGeneration") or 0) ~= generation
				or character:GetAttribute("ArenaRespawnPending") == true
				or (player ~= nil and (player.Parent ~= Players or player.Character ~= character
					or player:GetAttribute("MatchId") ~= sessionId or player:GetAttribute("ResultsSessionId") ~= nil))
				or (session ~= nil and (rounds:GetSessionForPlayer(player) ~= session
					or session.StateVersion ~= stateVersion or not rounds:IsSessionActive(session.Id)
					or session.Closing or session.Closed or session.Cancelled or session.GameplayFrozen))
			if stale then
				if self._activeTimers[character] == recovery then self._activeTimers[character] = nil end
				if Config.Respawn.Debug then warn("[RespawnDebug] StaleRagdollRecovery", player and player.UserId, generation, character:GetAttribute("ArenaEliminationId")) end
				return
			end
			self._activeTimers[character] = nil
			character:SetAttribute("RagdollRecoveryDeadline",nil)
			self:RemoveRagdoll(character)
		end)
		self._activeTimers[character] = recovery
	end

	return true
end

-- Restaura el personaje a su estado normal de locomoción notificando a RagdollStatesHandler
function RagdollService:CancelRecovery(character: Model)
 local timer=self._activeTimers[character]
 if timer then pcall(task.cancel,timer);self._activeTimers[character]=nil end
 character:SetAttribute("RagdollRecoveryDeadline",nil)
end

function RagdollService:RemoveRagdoll(character: Model): boolean
	if character then character:SetAttribute("RagdollRecoveryDeadline",nil) end
	if character and character:GetAttribute("ArenaRespawnPending") then return false end
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
		local original = self._rootCollisions[character]
		if original ~= nil then rootPart.CanCollide = original end
		self._rootCollisions[character] = nil
	end

	if humanoid and humanoid.Health > 0 then
		humanoid.PlatformStand = false
		humanoid.AutoRotate = true

		local player = Players:GetPlayerFromCharacter(character)
		local stateEvent = self:_getStateEvent()
		if player and stateEvent then
			stateEvent:FireClient(player, true, nil, player:GetAttribute("MatchId"), character:GetAttribute("ArenaPhysicsGeneration") or 0, character)
		else
			pcall(function()
				humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end)
		end
	end

	return true
end

-- Reseteo forzado e inmediato de ragdoll para reposicionamiento en arena (Zero-Death)
-- Idempotente, síncrono, cancela timers/callbacks y restaura articulaciones, colisiones y estado físico.
function RagdollService:ResetRagdollImmediate(character: Model, quietRespawn: boolean?): boolean
	if character then character:SetAttribute("RagdollRecoveryDeadline",nil) end
	if not character or not character.Parent then return false end

	-- 1. Cancelar cualquier timer pendiente para evitar callbacks diferidos
	local timer = self._activeTimers[character]
	if timer then
		pcall(task.cancel, timer)
		self._activeTimers[character] = nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart") :: BasePart?

	-- 2. Reactivar AnimationConstraints si es R15
	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("AnimationConstraint") then
			desc.Enabled = true
		end
	end

	-- 3. Limpiar instancias R6 si correspondía
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

	-- 4. Anular colapso de RootJoint / TorsoWeld residuales si existieran
	if rootPart then
		rootPart.Massless = false
		local original = self._rootCollisions[character]
		if original ~= nil then rootPart.CanCollide = original end
		self._rootCollisions[character] = nil
		local rootJoint = rootPart:FindFirstChild("RootJoint") :: Motor6D?
		if rootJoint then
			rootJoint.Enabled = true
		end
		local torsoWeld = rootPart:FindFirstChild("TorsoWeld")
		if torsoWeld then
			torsoWeld:Destroy()
		end
	end

	-- Quiet Zero-Death recovery runs with the root anchored by ArenaRespawn.
	-- Reassemble R6 at rest BEFORE teleport/collision restoration; enabling motors
	-- alone leaves ragdoll limb poses for the next solver step to correct.
	if quietRespawn and r6Instances and rootPart and rootPart.Anchored then
		local motors: { Motor6D } = {}
		for _, joint in ipairs(character:GetDescendants()) do
			if joint:IsA("Motor6D") and joint.Part0 and joint.Part1 then
				joint.Transform = CFrame.identity
				table.insert(motors, joint)
			end
		end
		local positioned: { [BasePart]: boolean } = { [rootPart] = true }
		for _ = 1, #motors do
			local progressed = false
			for _, joint in ipairs(motors) do
				local a, b = joint.Part0, joint.Part1
				if a and b and positioned[a] and not positioned[b] then
					b.CFrame = a.CFrame * joint.C0 * joint.C1:Inverse()
					positioned[b] = true
					progressed = true
				end
			end
			if not progressed then break end
		end
	end

	-- 5. Restaurar estado de locomoción en Humanoid sin alterar Health
	if humanoid and humanoid.Health > 0 then
		humanoid.PlatformStand = false
		humanoid.AutoRotate = true

		local player = Players:GetPlayerFromCharacter(character)
		local stateEvent = self:_getStateEvent()
		if player and stateEvent and not quietRespawn then
			stateEvent:FireClient(player, true, nil, player:GetAttribute("MatchId"), character:GetAttribute("ArenaPhysicsGeneration") or 0, character)
		end

		pcall(function()
			humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true)
			if quietRespawn then humanoid.Jump = false end
			humanoid:ChangeState(if quietRespawn then Enum.HumanoidStateType.Running else Enum.HumanoidStateType.GettingUp)
		end)
	end

	-- 6. Anular cualquier inercia o impulso en todas las partes del modelo
	for _, desc in ipairs(character:GetDescendants()) do
		if desc:IsA("BasePart") then
			desc.AssemblyLinearVelocity = Vector3.zero
			desc.AssemblyAngularVelocity = Vector3.zero
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
	if character:GetAttribute("ArenaRespawnPending") then return end
	local owner = Players:GetPlayerFromCharacter(character)
	if owner and owner:GetAttribute("ResultsSessionId") ~= nil then return end

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
		stateEvent:FireClient(player, false, launchVel, player:GetAttribute("MatchId"), character:GetAttribute("ArenaPhysicsGeneration") or 0, character)
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
	self._rootCollisions = setmetatable({}, { __mode = "k" })
end

function RagdollService:Start(context)
	self._context = context
	print("[RagdollService] Servicio de Ragdoll activo, integrado con ReplicatedStorage.StateEvent y RagdollStatesHandler")
end

return RagdollService
