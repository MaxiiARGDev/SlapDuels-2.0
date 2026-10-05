local ReplicatedStorage = game:GetService('ReplicatedStorage')
local stateEvent = ReplicatedStorage:WaitForChild('StateEvent') :: UnreliableRemoteEvent
local character = script.Parent
local humanoid = character:WaitForChild('Humanoid') :: Humanoid
local rootPart = character:WaitForChild('HumanoidRootPart') :: BasePart?

local function onClientEvent(status: boolean, launchVelocity: Vector3?)
	if not humanoid.Parent then return end
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, status)
	humanoid:ChangeState(if status then Enum.HumanoidStateType.GettingUp else Enum.HumanoidStateType.Physics)

	if not status then
		if rootPart then
			rootPart.CanCollide = false
		end
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
			task.defer(function()
				if character and character.Parent and not humanoid:GetStateEnabled(Enum.HumanoidStateType.GettingUp) then
					for _, part in ipairs(character:GetDescendants()) do
						if part:IsA("BasePart") then
							part.AssemblyLinearVelocity = launchVelocity
						end
					end
				end
			end)
		end
	else
		-- Recuperación: restaurar colisión del RootPart
		if rootPart then
			rootPart.CanCollide = true
		end
	end
end

stateEvent.OnClientEvent:Connect(onClientEvent)

