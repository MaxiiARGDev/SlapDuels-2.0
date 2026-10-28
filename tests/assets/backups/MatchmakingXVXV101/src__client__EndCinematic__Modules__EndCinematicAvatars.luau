--!nonstrict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Config = require(game.ReplicatedStorage.Shared.EndCinematicConfig)
local Module = {}
local function make(class, properties, parent)
 local object = Instance.new(class)
 for key, value in pairs(properties) do object[key] = value end
 object.Parent = parent
 return object
end
function Module.Prepare(run, winner, slot, stage, cameraEnd)
	local description
	local descriptions = run.Scene and run.Scene:FindFirstChild("WinnerDescriptions")
	local snapshot = descriptions and winner.DescriptionKey and descriptions:FindFirstChild(winner.DescriptionKey)
		local player = Players:GetPlayerByUserId(winner.AppearanceUserId or winner.UserId)
	local humanoid = player and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local resolved, failure=pcall(function()
		if snapshot and snapshot:IsA("HumanoidDescription") then description = snapshot:Clone()
	elseif humanoid then description = humanoid:GetAppliedDescription()
	elseif winner.UserId > 0 then description = Players:GetHumanoidDescriptionFromUserIdAsync(winner.UserId)
		end
		end)
		if not resolved or not description then
			warn("[EndCinematic] Appearance unavailable for "..tostring(winner.UserId)..": "..tostring(failure))
			description=Instance.new("HumanoidDescription")
		end
	if not run:IsAlive() then description:Destroy(); return end
	local ok, rig = pcall(function() return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15) end)
	description:Destroy()
	if not ok then error(rig) end
	if not run:IsAlive() then rig:Destroy(); return end
	rig.Name = "Winner_" .. tostring(winner.UserId)
	for _, object in ipairs(rig:GetDescendants()) do
		if object:IsA("LuaSourceContainer") or object:IsA("Tool") then object:Destroy()
		elseif object:IsA("BasePart") then object.CanCollide = false; object.CanTouch = false; object.CanQuery = false end
	end
	local root = assert(rig:FindFirstChild("HumanoidRootPart"), "Rig root missing")
	root.Anchored = true
	rig.Parent = run.Container
	local _, size = rig:GetBoundingBox()
	local rigHumanoid = rig:FindFirstChildOfClass("Humanoid")
	local bottomOffset = rig:GetPivot().Position.Y - root.Position.Y + rigHumanoid.HipHeight + root.Size.Y / 2
	local finish = slot.CFrame * CFrame.new(0, slot.Size.Y / 2 + bottomOffset, 0)
	-- Walk ends at the authored slot; clamp its starting point to the platform.
	local distance = math.max(0, Config.Winners.WalkDistance)
	local floor = stage.Structure:FindFirstChild("Floor")
	while distance > 0 do
		local start = finish * CFrame.new(0, 0, distance)
		local localPoint = floor.CFrame:PointToObjectSpace(start.Position)
		if math.abs(localPoint.X) + size.X / 2 + Config.Winners.PlatformMargin <= floor.Size.X / 2
			and math.abs(localPoint.Z) + size.Z / 2 + Config.Winners.PlatformMargin <= floor.Size.Z / 2
			and (start.Position - cameraEnd.Position).Magnitude >= Config.Winners.CameraClearance then break end
		distance = math.max(0, distance - 0.25)
	end
	local start = finish * CFrame.new(0, 0, distance)
	rig:PivotTo(start)
		local entry={ Model = rig, Start = start, Finish = finish, Participant = winner, CinematicSlot = winner.CinematicSlot }
		table.insert(run.Rigs, entry)
		table.insert(run.Connections,rig.Destroying:Connect(function()
			if run:IsAlive() and run.OnRigRemoved then run.OnRigRemoved() end
		end))
		return entry
end


function Module.Cleanup(run)
 for _, entry in ipairs(run.Rigs) do entry.Model:Destroy() end
 run.Rigs = {}
end
return Module
