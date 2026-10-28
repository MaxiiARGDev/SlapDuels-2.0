local ReplicatedStorage = game:GetService('ReplicatedStorage')
local stateEvent = ReplicatedStorage:WaitForChild('StateEvent') :: UnreliableRemoteEvent
local character = script.Parent
local humanoid = character:WaitForChild('Humanoid') :: Humanoid
local rootPart = character:WaitForChild('HumanoidRootPart') :: BasePart?
local latestGeneration = character:GetAttribute("ArenaPhysicsGeneration") or 0
local player = game:GetService("Players").LocalPlayer
-- Character scripts may be sandboxed; read the server's diagnostic flag, never require Config here.
local currentPacket

local function onClientEvent(status: boolean, launchVelocity: Vector3?, sourceSessionId: string?, physicsGeneration: number?, sourceCharacter: Model?)
	if not humanoid.Parent or player.Character ~= character then return end
	if type(physicsGeneration) ~= "number" or sourceCharacter ~= character then return end
	local generation = physicsGeneration or 0
	if generation < math.max(latestGeneration, character:GetAttribute("ArenaPhysicsGeneration") or 0)
		or character:GetAttribute("ArenaRespawnPending") then return end
	latestGeneration = generation
	local packet = {}
	currentPacket = packet
	local function staleLaunch(): boolean
		return currentPacket ~= packet or player.Parent == nil or player.Character ~= character or not character.Parent
			or sourceSessionId ~= nil
			and (player:GetAttribute("MatchId") ~= sourceSessionId or player:GetAttribute("ResultsSessionId") == sourceSessionId)
			or character:GetAttribute("ArenaRespawnPending") == true
			or generation ~= math.max(latestGeneration, character:GetAttribute("ArenaPhysicsGeneration") or 0)
	end
		if staleLaunch() then
			if character:GetAttribute("ArenaRespawnDebug") == true then warn("[RespawnDebug] StaleStateEvent", player.UserId, generation, character:GetAttribute("ArenaEliminationId")) end
			return
		end
	humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, status)
	humanoid:ChangeState(if status then Enum.HumanoidStateType.GettingUp else Enum.HumanoidStateType.Physics)

	if not status then
			character:SetAttribute("ArenaAcceptedLaunchGeneration", generation)
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
				if not staleLaunch() and humanoid.Parent and not humanoid:GetStateEnabled(Enum.HumanoidStateType.GettingUp) then
					for _, part in ipairs(character:GetDescendants()) do
						if part:IsA("BasePart") then
							part.AssemblyLinearVelocity = launchVelocity
						end
					end
					elseif character:GetAttribute("ArenaRespawnDebug") == true then
					warn("[RespawnDebug] StaleDeferredLaunch", player.UserId, generation, character:GetAttribute("ArenaEliminationId"))
				end
			end)
		end
	else
		-- Root collision is restored by the server to its saved value, never forced true here.
	end
end

local connection = stateEvent.OnClientEvent:Connect(onClientEvent)
local removing
removing = player.CharacterRemoving:Connect(function(oldCharacter)
	if oldCharacter == character then connection:Disconnect(); removing:Disconnect() end
end)
character.Destroying:Connect(function() connection:Disconnect(); removing:Disconnect() end)

