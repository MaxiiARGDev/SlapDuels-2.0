local GROUP_ID = 484233593
local GroupService = game:GetService("GroupService")

local prompt = workspace:WaitForChild("ProxPart"):WaitForChild("ProximityPrompt")  -- change path if needed

prompt.Triggered:Connect(function(player)
	if player ~= game.Players.LocalPlayer then return end

	local success, result = pcall(function()
		return GroupService:PromptJoinAsync(GROUP_ID)
	end)
end)
