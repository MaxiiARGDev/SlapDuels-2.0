-- CONFIGURATIONS
local HOVER_SCALE = 1.08
local CLICK_SCALE = 0.9
local HOVER_TIME = 0.15
local CLICK_DOWN_TIME = 0.08
local CLICK_UP_TIME = 0.1
local EASING_STYLE = Enum.EasingStyle.Quad
local EASING_DIRECTION = Enum.EasingDirection.Out
local TweenService = game:GetService("TweenService")
local UIScale = script.Parent
local Button = UIScale.Parent
-- Only the enclosing GuiButton owns input; its scale already includes decorative children.
if not Button:IsA("GuiButton") then return end
local ClickSound = UIScale:WaitForChild("Click")
local HoverSound = UIScale:WaitForChild("Hover")
local DefaultScale = UIScale.Scale
local Hovering = false
local Pressed = false
local CurrentTween
local function TweenScale(scale, time)
	if CurrentTween then
		CurrentTween:Cancel()
	end
	CurrentTween = TweenService:Create(
		UIScale,
		TweenInfo.new(time, EASING_STYLE, EASING_DIRECTION),
		{Scale = scale}
	)
	CurrentTween:Play()
	return CurrentTween
end
Button.MouseEnter:Connect(function()
	Hovering = true
	HoverSound:Play()
	if not Pressed then
		TweenScale(DefaultScale * HOVER_SCALE, HOVER_TIME)
	end
end)
Button.MouseLeave:Connect(function()
	Hovering = false
	if not Pressed then
		TweenScale(DefaultScale, HOVER_TIME)
	end
end)
Button.MouseButton1Down:Connect(function()
	Pressed = true
	ClickSound:Play()
	TweenScale(DefaultScale * CLICK_SCALE, CLICK_DOWN_TIME)
end)
Button.MouseButton1Up:Connect(function()
	Pressed = false
	if Hovering then
		TweenScale(DefaultScale * HOVER_SCALE, CLICK_UP_TIME)
	else
		TweenScale(DefaultScale, CLICK_UP_TIME)
	end
end)
