local GROUP_ID = 484233593
local GroupService = game:GetService("GroupService")
local player = game.Players.LocalPlayer

player.Chatted:Connect(function(msg)
	if msg:lower() == "!joingroup" then 				-- Command to type in chat to show the join group prompt
		local success, result = pcall(function()
			return GroupService:PromptJoinAsync(GROUP_ID)
		end)
	end
end)
