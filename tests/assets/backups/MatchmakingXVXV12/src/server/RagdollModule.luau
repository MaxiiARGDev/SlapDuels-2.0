local RunService = game:GetService('RunService')
local Players = game:GetService('Players')
local StarterPlayer = game:GetService('StarterPlayer')
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local stateEvent = ReplicatedStorage.StateEvent
local ragdollInstances = {}

local module = {}
function module.ragdoll(character:Model)
	local torso:BasePart? = character:FindFirstChild('Torso')
	local humanoid = character:FindFirstChildWhichIsA('Humanoid')
	local rootPart = humanoid and humanoid.RootPart
	local rootJoint:Motor6D? = rootPart and rootPart:FindFirstChild('RootJoint')
	if not rootPart or not rootJoint or not torso or not humanoid then return end
	local instances = {}
	rootPart.Massless = true
	if not rootPart:FindFirstChild('TorsoWeld') then
		local torsoWeld = Instance.new('WeldConstraint',rootPart)
		torsoWeld.Part0 = rootPart
		torsoWeld.Part1 = torso
		torsoWeld.Name = 'TorsoWeld'
		table.insert(instances,torsoWeld)
	end
	rootJoint.Enabled = false
	humanoid.PlatformStand = true
	humanoid.AutoRotate = false
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		stateEvent:FireClient(player,false)
	else
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp,false)
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	end
	for _,v:Motor6D? in character:GetDescendants() do
		if not v:IsA('Motor6D') or v == rootJoint then continue end
		local part0,part1 = v.Part0,v.Part1
		local collider = Instance.new('Part',part1)
		collider.Size = part1.Size/1.7
		collider.CFrame = part1.CFrame
		collider.Massless = true
		collider.CanQuery = false
		collider.CanTouch = false
		collider.Transparency = 1
		collider.Name = 'Collider'
		table.insert(instances,collider)
		local colliderWeld = Instance.new('WeldConstraint',collider)
		colliderWeld.Part0 = collider
		colliderWeld.Part1 = part1
		table.insert(instances,colliderWeld)
		local attachment0 = Instance.new('Attachment',part0)
		attachment0.CFrame = v.C0
		attachment0.Name = part1.Name..'_RagdollAttachment0'
		table.insert(instances,attachment0)
		local attachment1 = Instance.new('Attachment',part1)
		attachment1.CFrame = v.C1
		attachment1.Name = 'RagdollAttachment1'
		table.insert(instances,attachment1)
		local ballSocket = Instance.new('BallSocketConstraint',part1)
		ballSocket.Attachment0 = attachment0
		ballSocket.Attachment1 = attachment1
		ballSocket.LimitsEnabled = true
		ballSocket.TwistLimitsEnabled = true
		ballSocket.Name = 'RagdollConstraint'
		table.insert(instances,ballSocket)
		v.Enabled = false
	end
	ragdollInstances[character] = instances
end
function module.unRagdoll(character:Model)
	local humanoid = character:FindFirstChildWhichIsA('Humanoid')
	local rootPart = humanoid and humanoid.RootPart
	if not humanoid or humanoid.Health <= 0 or not rootPart then return end
	rootPart.Massless = false
	RunService.Heartbeat:Wait()
	task.wait()
	rootPart.Anchored = true
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true
	rayParams:AddToFilter(character)
	local ray = workspace:Raycast(rootPart.Position,vector.create(0,-5,0),rayParams)
	local unragdollCFrame = ray and CFrame.new(ray.Position+ray.Normal*3) or CFrame.new(rootPart.Position)
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		stateEvent:FireClient(player,true)
	else
		humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp,true)
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	rootPart.CFrame = unragdollCFrame
	humanoid.PlatformStand = false
	humanoid.AutoRotate = true
	RunService.Heartbeat:Wait()
	rootPart.Anchored = false
	for _,v:Motor6D? in character:GetDescendants() do
		if not v:IsA('Motor6D') then continue end
		v.Enabled = true
	end
	if not ragdollInstances[character] then return end
	for _,v in ragdollInstances[character] do
		v:Destroy()
	end
	ragdollInstances[character] = nil
end
return module
