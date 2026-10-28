local GROUP_ID = 484233593
local GroupService = game:GetService("GroupService")

task.wait(10) -- how long the script waits after you join before prompting the join group.

local success, result = pcall(function()
	return GroupService:PromptJoinAsync(GROUP_ID)
end)