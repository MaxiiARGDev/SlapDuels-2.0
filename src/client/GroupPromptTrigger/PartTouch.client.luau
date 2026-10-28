local GROUP_ID = 484233593
local GroupService = game:GetService("GroupService")

local part = workspace:WaitForChild("TouchPart")
local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local debounce = false

part.Touched:Connect(function(hit)
	if debounce then return end
	if hit.Parent == character then
		debounce = true
		local success, result = pcall(function()
			return GroupService:PromptJoinAsync(GROUP_ID)
		end)

		task.wait(3) -- touch cooldown here
		debounce = false
	end
end)
