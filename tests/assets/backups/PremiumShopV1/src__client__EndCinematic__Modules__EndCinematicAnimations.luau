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
function Module.Play(run, entry, index)
	task.wait(Config.Winners.WalkStartDelay + (index - 1) * Config.Winners.EntryStagger)
	if not run:IsAlive() then return end
	local track
	if Config.Winners.WalkAnimationId ~= "" then
		local ok, result = pcall(function()
			local animator = entry.Model:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("Animator")
			local animation = make("Animation", { AnimationId = Config.Winners.WalkAnimationId }, run.Container)
			return animator:LoadAnimation(animation)
		end)
		if ok then track = result; table.insert(run.Tracks, track); track:Play() else warn("[EndCinematic] Animation unavailable: " .. tostring(result)) end
	end
	local alpha = make("NumberValue", { Value = 0 }, run.Container)
	table.insert(run.Connections, alpha.Changed:Connect(function(v)
		if run:IsAlive() then entry.Model:PivotTo(entry.Start:Lerp(entry.Finish, v)) end
	end))
	run:Tween(alpha, Config.Winners.WalkDuration, { Value = 1 })
	if track then track:Stop(0.15) end
	if run:IsAlive() then entry.Model:PivotTo(entry.Finish); run.WalksDone += 1 end
end


function Module.Cleanup(run)
 for _, track in ipairs(run.Tracks) do pcall(function() track:Stop(0); track:Destroy() end) end
 run.Tracks = {}
end
return Module
