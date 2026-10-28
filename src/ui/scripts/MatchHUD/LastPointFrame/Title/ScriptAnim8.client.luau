local TweenService = game:GetService("TweenService")
local label = script.Parent
local scale = label:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
scale.Parent = label
local originalScale = scale.Scale
local originalTransparency = label.TextTransparency
local currentTween
local function reset()
	if currentTween then
		currentTween:Cancel()
		currentTween = nil
	end
	scale.Scale = originalScale
	label.TextTransparency = originalTransparency
end
local function playAnimation()
	while true do
		scale.Scale = 0
		label.TextTransparency = 1
		task.wait(0.3)
		label.TextTransparency = originalTransparency
		currentTween = TweenService:Create(scale, TweenInfo.new(0.7, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {Scale = originalScale})
		currentTween:Play()
		currentTween.Completed:Wait()
		currentTween = nil
		task.wait(2.5)
	end
end
local mode = script:GetAttribute("PlayMode") or "Loop"
if mode == "Loop" then
	playAnimation()
elseif mode == "Hover" then
	local activeThread
	local target = script.Parent
	target.MouseEnter:Connect(function()
		reset()
		if activeThread then
			task.cancel(activeThread)
		end
		activeThread = task.spawn(playAnimation)
	end)
	target.MouseLeave:Connect(function()
		reset()
		if activeThread then
			task.cancel(activeThread)
			activeThread = nil
		end
	end)
elseif mode == "NoAutoScript" then
	-- script your function : 
	-- playAnimation()
end