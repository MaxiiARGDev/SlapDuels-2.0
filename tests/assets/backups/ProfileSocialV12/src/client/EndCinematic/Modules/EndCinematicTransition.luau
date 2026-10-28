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
function Module.Prepare(run)
	local gui = make("ScreenGui", { Name = "EndCinematicTransition", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 10000 }, Players.LocalPlayer.PlayerGui)
	table.insert(run.Resources, gui)
	-- Full-height, oversized rotated panels: diagonal inner edges with overlap.
	local panels = {}
	for index, sign in ipairs({ -1, 1 }) do
		local panel = make("Frame", { Name = index == 1 and "Left" or "Right", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromScale(2, 6), Position = UDim2.fromScale(0.5 + sign * 3, 0.5), Rotation = Config.Transition.Angle, BackgroundColor3 = Config.Transition.Color, BorderSizePixel = 0, ZIndex = 10 }, gui)
		table.insert(panels, panel)
	end
	return panels
end

function Module.Play(run, panels, closed)
	local duration = closed and Config.Transition.CloseDuration or Config.Transition.OpenDuration
	local tweens = {}
	for index, panel in ipairs(panels) do
		local sign = index == 1 and -1 or 1
		local target = UDim2.fromScale(0.5 + sign * (closed and 0.94 or 3), 0.5)
		local tween = TweenService:Create(panel, TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), { Position = target })
		table.insert(run.Tweens, tween); table.insert(tweens, tween); tween:Play()
	end
	tweens[1].Completed:Wait()
	return run:IsAlive()
end


function Module.Cleanup(run)
 if run.Panels and run.Panels[1].Parent then run.Panels[1].Parent:Destroy() end
 run.Panels = nil
end
return Module
