-- Framewisp: hover/press feedback for buttons (darkens their images).
-- Tag a layer "_nodim" in Figma to keep it at full brightness.
-- Safe to delete: buttons stay, only the hover effect stops.
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local gui = script.Parent
local function fwRoots()
	local list = { gui }
	for _, v in ipairs(gui:GetChildren()) do
		if v:IsA("ObjectValue") and v.Name == "FW_ExtraRoot" and v.Value then
			list[#list + 1] = v.Value
		end
	end
	return list
end
local function fwAll()
	local out = {}
	for _, r in ipairs(fwRoots()) do
		for _, d in ipairs(r:GetDescendants()) do out[#out + 1] = d end
	end
	return out
end
local function fwScaleHost(el) -- Roblox honours ONE UIScale per object
	local sc = el:FindFirstChild("FW_Scale")
	if not sc then
		sc = el:FindFirstChildWhichIsA("UIScale")
		if sc then
			sc.Name = "FW_Scale"
		else
			sc = Instance.new("UIScale")
			sc.Name = "FW_Scale"
			sc:SetAttribute("FW_Owned", true)
			sc.Parent = el
		end
	end
	return sc
end
local function fwScaleApply(host)
	local total = 1
	for _, ch in ipairs(host:GetChildren()) do
		if ch:IsA("NumberValue") then total = total * ch.Value end
	end
	host.Scale = total
end
local function fwChannel(el, key) -- every runtime writes its OWN channel; the product applies once
	local host = fwScaleHost(el)
	local ch = host:FindFirstChild(key)
	if not ch then
		ch = Instance.new("NumberValue")
		ch.Name = key
		ch.Value = 1
		ch:SetAttribute("FW_Owned", true)
		ch.Parent = host
		ch.Changed:Connect(function() fwScaleApply(host) end)
	end
	return ch
end
local function fwRotSet(el, key, deg) -- Rotation is shared by three runtimes too
	local base = el:GetAttribute("FW_RotBase")
	if base == nil then
		base = el.Rotation
		el:SetAttribute("FW_RotBase", base)
	end
	el:SetAttribute(key, deg)
	local total = 0
	for _, k in ipairs({ "r_juice", "r_spin", "r_tl", "r_hover" }) do
		local v = el:GetAttribute(k)
		if type(v) == "number" then total = total + v end
	end
	el.Rotation = base + total
end
local function findRoot()
	local fallback = nil
	for _, child in ipairs(gui:GetChildren()) do
		if child:IsA("BillboardGui") then -- _billboard: the design lives one level deeper
			local inner = child:FindFirstChildWhichIsA("GuiObject")
			if inner then return inner end
		end
		if child:IsA("ObjectValue") and child.Name == "FW_ExtraRoot" and child.Value then
			local inner = child.Value:FindFirstChildWhichIsA("GuiObject")
			if inner then return inner end
		end
		if child:IsA("GuiObject") then
			fallback = fallback or child
			if child:GetAttribute("FW_Owned") == true then return child end
		end
	end
	return fallback
end
local root = findRoot()
if not root then return end
local HOVER, PRESS = 0.8, 0.62
local TIME = 0.08
local UP_DIST, UP_TIME = 6, 0.12
local TURN_ANGLE, TURN_TIME = -5, 0.14
local LEAN_ANGLE, LEAN_TIME = -8, 0.14
-- ========================== tune the feel here ==========================
-- MAGNET_PULL — how far a _magnet button leans toward the cursor.
--   0.15 = shy   ·   0.35 = default, juicy   ·   0.6 = clingy
-- MAGNET_RADIUS — attraction zone around the button, in screen px.
--   30 = touchy   ·   60 = default   ·   120 = feels it from afar
-- ========================================================================
local MAGNET_PULL = 0.35
local MAGNET_RADIUS = 60
local GuiService = game:GetService("GuiService")
local function magnetPx() -- design px -> screen px, defined here because the loop runs first
	local r = gui:FindFirstChildWhichIsA("GuiObject")
	if not r then -- a billboard design lives one level deeper, or hangs off FW_ExtraRoot
		for _, v in ipairs(gui:GetChildren()) do
			if v:IsA("BillboardGui") then -- clickable _billboard: kept inside this ScreenGui
				r = v:FindFirstChildWhichIsA("GuiObject")
				break
			end
			if v:IsA("ObjectValue") and v.Name == "FW_ExtraRoot" and v.Value then
				r = v.Value:FindFirstChildWhichIsA("GuiObject")
				break
			end
		end
	end
	local dh = gui:GetAttribute("BB_DesignH")
	if r and type(dh) == "number" and dh > 0 and r.AbsoluteSize.Y > 1 then return r.AbsoluteSize.Y / dh end
	return 1
end
local magnets = {}
local magnetLoop = nil
local function startMagnetLoop()
	if magnetLoop then return end
	magnetLoop = RunService.RenderStepped:Connect(function(dt)
		dt = math.min(dt, 1 / 20)
		local mouse = UserInputService:GetMouseLocation()
		local inset = GuiService:GetGuiInset()
		for _, m in ipairs(magnets) do
			local b = m.btn
			if b.Parent then
				if not m.base then m.base = b.Position end
				local p = b.AbsolutePosition
				local sz = b.AbsoluteSize
				local mx, my = mouse.X - inset.X, mouse.Y - inset.Y
				local radius = m.radius * magnetPx() -- a DESIGN distance: 15 px must mean 15 px of the mockup
				local col = b:FindFirstAncestorWhichIsA("SurfaceGui")
				if col and col:GetAttribute("FW_RectW") then
					local rx, ry = col:GetAttribute("FW_RectX"), col:GetAttribute("FW_RectY")
					local rw, rh = col:GetAttribute("FW_RectW"), col:GetAttribute("FW_RectH")
					if rw and rw > 0 and rh and rh > 0 then
						local cs = col.CanvasSize
						local kx = cs.X / rw
						mx = (mouse.X - rx) * kx
						my = (mouse.Y - ry) * (cs.Y / rh)
						radius = radius * kx
					end
				end
				local par = b.Parent -- rest centre from the LAYOUT: stable, and never our own output
				local ppos = par and par:IsA("GuiObject") and par.AbsolutePosition or Vector2.new(0, 0)
				local psz = par and par:IsA("GuiObject") and par.AbsoluteSize or sz
				local cx, cy
				if par and par:IsA("GuiObject") and psz.X > 1 then
					local ap = b.AnchorPoint
					cx = ppos.X + m.base.X.Scale * psz.X + m.base.X.Offset + (0.5 - ap.X) * sz.X
					cy = ppos.Y + m.base.Y.Scale * psz.Y + m.base.Y.Offset + (0.5 - ap.Y) * sz.Y
				else
					cx = p.X + sz.X / 2 - m.ox
					cy = p.Y + sz.Y / 2 - m.oy
				end
				m.cx0, m.cy0 = cx, cy
				local dx, dy = mx - cx, my - cy
				local nearX = math.abs(dx) - sz.X / 2
				local nearY = math.abs(dy) - sz.Y / 2
				local tx, ty = 0, 0
				if math.max(nearX, nearY) < radius then
					tx = dx * m.pull
					ty = dy * m.pull
					local len = math.sqrt(tx * tx + ty * ty)
					if len > radius then
						tx = tx / len * radius
						ty = ty / len * radius
					end
				end
				local K, C = 260, 14
				m.vx = m.vx + (-K * (m.ox - tx) - C * m.vx) * dt
				m.vy = m.vy + (-K * (m.oy - ty) - C * m.vy) * dt
				m.ox = m.ox + m.vx * dt
				m.oy = m.oy + m.vy * dt
				if math.abs(m.ox - tx) < 0.2 and math.abs(m.oy - ty) < 0.2 -- settle on ANY target: writing Position every frame re-lays out the subtree
					and math.abs(m.vx) < 2 and math.abs(m.vy) < 2 then
					m.ox, m.oy, m.vx, m.vy = tx, ty, 0, 0
				end
				local px, py = math.floor(m.ox + 0.5), math.floor(m.oy + 0.5)
				if px ~= m.lastX or py ~= m.lastY then
					m.lastX, m.lastY = px, py
					b.Position = m.base + UDim2.fromOffset(px, py)
				end
			end
		end
	end)
end

local wired = setmetatable({}, { __mode = "k" })

local function dimTargets(btn)
	local t = {}
	local function insideState(inst)
		local n = inst
		while n and n ~= btn do
			if n:GetAttribute("FigmaState") ~= nil then return true end
			n = n.Parent
		end
		return false
	end
	local function add(inst, prop)
		local pick = inst:GetAttribute("FigmaColorPick") -- a layer with its own hover colour is not dimmed: the pick IS its hover look
		if type(pick) == "number" and pick >= 0 and inst:GetAttribute("FigmaColor") ~= nil then return end
		local e = { inst = inst, prop = prop, base = inst[prop], own = 0 }
		inst:GetPropertyChangedSignal(prop):Connect(function()
			if e.own == 0 then e.base = inst[prop] end
		end)
		t[#t + 1] = e
	end
	if btn:IsA("ImageButton") and btn.Image ~= "" and btn.ImageTransparency < 1 then
		add(btn, "ImageColor3")
	end
	if btn.BackgroundTransparency < 1 then
		add(btn, "BackgroundColor3")
	end
	for _, d in ipairs(btn:GetDescendants()) do
		if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d:GetAttribute("FigmaNoDim") == nil and not insideState(d) then
			add(d, "ImageColor3")
		end
	end
	if #t == 0 then
		if btn:IsA("TextButton") and btn.TextTransparency < 1 then add(btn, "TextColor3") end
		for _, d in ipairs(btn:GetDescendants()) do
			if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.TextTransparency < 1
				and d:GetAttribute("FigmaNoDim") == nil and not insideState(d) then
				add(d, "TextColor3")
			end
		end
	end
	return t
end

local function centreAnchor(btn)
	if btn.AnchorPoint == Vector2.new(0.5, 0.5) then return end
	if btn.Parent then
		for _, ch in ipairs(btn.Parent:GetChildren()) do
			if ch:IsA("UIListLayout") or ch:IsA("UIGridLayout") or ch:IsA("UITableLayout") or ch:IsA("UIPageLayout") then
				return
			end
		end
	end
	local ap, pos, sz = btn.AnchorPoint, btn.Position, btn.Size
	btn.Position = UDim2.new(
		pos.X.Scale + (0.5 - ap.X) * sz.X.Scale,
		pos.X.Offset + (0.5 - ap.X) * sz.X.Offset,
		pos.Y.Scale + (0.5 - ap.Y) * sz.Y.Scale,
		pos.Y.Offset + (0.5 - ap.Y) * sz.Y.Offset
	)
	btn.AnchorPoint = Vector2.new(0.5, 0.5)
end

local function buttonSound(btn, names, fallbackId)
	local id
	for _, a in ipairs(names) do
		id = btn:GetAttribute(a)
		if id ~= nil then break end
	end
	if id == nil then id = fallbackId end
	if type(id) == "number" then id = string.format("%.0f", id) end
	id = tostring(id)
	if id == "" or id == "0" then return nil end
	if not id:match("^rbxassetid://") then id = "rbxassetid://" .. id end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Parent = btn
	return s
end
local function voice(template)
	if not template then return end
	local s = template:Clone()
	s.Parent = template.Parent
	s.Ended:Once(function() s:Destroy() end)
	s:Play()
	Debris:AddItem(s, 15)
end

local function wire(btn)
	if wired[btn] then return end
	wired[btn] = true

	local sndHover = buttonSound(btn, { "HoverSound", "FigmaHoverSound", "SmoothHoverSound" }, "139800881181209") -- "" or 0 = silent
	local sndClick = buttonSound(btn, { "ClickSound", "FigmaClickSound", "SmoothClickSound" }, "102702078778790")
	if sndHover then btn.MouseEnter:Connect(function() voice(sndHover) end) end
	if sndClick then btn.MouseButton1Down:Connect(function() voice(sndClick) end) end

	if btn:GetAttribute("FigmaMagnet") and UserInputService.MouseEnabled then
		magnets[#magnets + 1] = {
			btn = btn,
			pull = btn:GetAttribute("MagnetPull") or btn:GetAttribute("FigmaMagnetPull") or MAGNET_PULL,
			radius = btn:GetAttribute("MagnetRadius") or btn:GetAttribute("FigmaMagnetRadius") or MAGNET_RADIUS,
			ox = 0, oy = 0, vx = 0, vy = 0,
		}
		startMagnetLoop()
	end

	if btn:GetAttribute("FigmaSmooth") then
		btn.AutoButtonColor = false
		centreAnchor(btn)
		local scale = fwChannel(btn, "k_btn") -- a channel, so an idle pulse survives the hover
		local base = scale.Value
		local hoverK = btn:GetAttribute("SmoothHover") or btn:GetAttribute("FigmaSmoothHover") or 1.08
		local pressK = btn:GetAttribute("SmoothPress") or btn:GetAttribute("FigmaSmoothPress") or 0.9
		local hovering, held, tween = false, false, nil
		local function glide(target, t)
			if tween then tween:Cancel() end
			tween = TweenService:Create(scale, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = target })
			tween:Play()
		end
		btn.MouseEnter:Connect(function()
			hovering = true
			if not held then glide(base * hoverK, 0.15) end
		end)
		btn.MouseLeave:Connect(function()
			hovering = false
			if not held then glide(base, 0.15) end
		end)
		btn.MouseButton1Down:Connect(function()
			held = true
			glide(base * pressK, 0.08)
		end)
		local function release()
			if not held then return end
			held = false
			glide(hovering and base * hoverK or base, 0.1)
		end
		btn.MouseButton1Up:Connect(release)
		UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch then
				release()
			end
		end)
	end

	local states = {} -- state -> EVERY layer of it: an icon and a frame each carry their own _hover
	for _, c in ipairs(btn:GetDescendants()) do
		local s = c:GetAttribute("FigmaState")
		if s == "hover" or s == "clicked" or s == "disabled" or s == "default" then
			local owned, n = true, c.Parent
			while n and n ~= btn do
				if n:IsA("GuiButton") then owned = false break end
				n = n.Parent
			end
			if owned then
				states[s] = states[s] or {}
				table.insert(states[s], c)
			end
		end
	end
	if next(states) then
		local function show(name)
			for s, list in pairs(states) do
				local on = (s == name) or (s == "default" and name == nil)
				for _, c in ipairs(list) do c.Visible = on end
			end
		end
		local function disabled()
			local ok, value = pcall(function() return btn.Interactable == false end)
			return (ok and value) or btn.Active == false
		end
		local function rest() show(disabled() and states.disabled and "disabled" or nil) end
		btn.MouseEnter:Connect(function() if not disabled() and states.hover then show("hover") end end)
		btn.MouseLeave:Connect(rest)
		btn.MouseButton1Down:Connect(function() if not disabled() and states.clicked then show("clicked") end end)
		btn.MouseButton1Up:Connect(function() if disabled() then rest() else show(states.hover and "hover" or nil) end end)
		btn:GetPropertyChangedSignal("Active"):Connect(rest)
		pcall(function() btn:GetPropertyChangedSignal("Interactable"):Connect(rest) end)
		rest()
		if states.hover or states.clicked then return end
	end

	if btn:GetAttribute("FigmaSmooth") then return end

	local targets = dimTargets(btn)
	if #targets == 0 then
		btn.AutoButtonColor = true
		return
	end
	btn.AutoButtonColor = false
	centreAnchor(btn)
	local hoverDim = btn:GetAttribute("HoverDim") or btn:GetAttribute("FigmaHoverDim") or HOVER
	local pressDim = btn:GetAttribute("PressDim") or btn:GetAttribute("FigmaPressDim") or PRESS
	local pressIn = btn:GetAttribute("PressScale") or btn:GetAttribute("FigmaSmoothPress") or 0.985
	local scale = fwChannel(btn, "k_press")
	local function to(k, s)
		for _, tg in ipairs(targets) do
			local c = tg.base
			tg.own = tg.own + 1
			local tw = TweenService:Create(tg.inst, TweenInfo.new(TIME), { [tg.prop] = Color3.new(c.R * k, c.G * k, c.B * k) })
			tw.Completed:Once(function()
				if tg.own > 0 then tg.own = tg.own - 1 end
			end)
			tw:Play()
		end
		TweenService:Create(scale, TweenInfo.new(TIME), { Value = s }):Play()
	end
	btn.MouseEnter:Connect(function() to(hoverDim, 1) end)
	btn.MouseLeave:Connect(function() to(1, 1) end)
	btn.MouseButton1Down:Connect(function() to(pressDim, pressIn) end)
	btn.MouseButton1Up:Connect(function() to(hoverDim, 1) end)
end

local function onScrollMoved(btn, fn)
	local sf = btn:FindFirstAncestorWhichIsA("ScrollingFrame")
	if not sf then return end
	sf:GetPropertyChangedSignal("CanvasPosition"):Connect(fn)
end
local function laidOutBy(btn)
	local p = btn.Parent
	if not p then return false end
	return p:FindFirstChildWhichIsA("UIGridLayout") ~= nil
		or p:FindFirstChildWhichIsA("UIListLayout") ~= nil
		or p:FindFirstChildWhichIsA("UITableLayout") ~= nil
		or p:FindFirstChildWhichIsA("UIPageLayout") ~= nil
end
local function slotFor(btn)
	if not laidOutBy(btn) then return end
	local slot = Instance.new("Frame")
	slot.Name = btn.Name .. "_LiftSlot"
	slot:SetAttribute("FW_LiftSlot", true)
	slot.BackgroundTransparency = 1
	slot.BorderSizePixel = 0
	slot.Size = btn.Size
	slot.Position = btn.Position
	slot.AnchorPoint = btn.AnchorPoint
	slot.LayoutOrder = btn.LayoutOrder
	slot.ZIndex = btn.ZIndex
	slot.Visible = btn.Visible
	slot.Parent = btn.Parent
	btn.AnchorPoint = Vector2.new(0, 0)
	btn.Position = UDim2.fromScale(0, 0)
	btn.Size = UDim2.fromScale(1, 1)
	btn.Parent = slot
	centreAnchor(btn)
end
local function cardAround(el)
	local n = el.Parent
	while n and n ~= gui do
		if n:IsA("GuiButton") then return n end
		n = n.Parent
	end
	return nil
end

local function wireSquish(btn)
	if not btn:GetAttribute("FigmaSquish") then return end
	if btn:GetAttribute("FW_Squish") then return end
	btn:SetAttribute("FW_Squish", true)
	slotFor(btn)
	centreAnchor(btn)
	local base = nil
	local tw = nil
	local function squash(on)
		if base == nil then base = btn.Size end
		local amp = (btn:GetAttribute("SquishAmp") or btn:GetAttribute("FigmaSquishAmp") or 10) / 100
		local t = btn:GetAttribute("SquishTime") or btn:GetAttribute("FigmaSquishTime") or 0.18
		if tw then tw:Cancel() end
		local target = on
			and UDim2.new(base.X.Scale * (1 + amp), base.X.Offset * (1 + amp), base.Y.Scale * (1 - amp), base.Y.Offset * (1 - amp))
			or base
		tw = TweenService:Create(btn, TweenInfo.new(on and t / 3 or t, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = target })
		tw:Play()
	end
	btn.MouseButton1Down:Connect(function() squash(true) end)
	btn.MouseButton1Up:Connect(function() squash(false) end)
	btn.MouseLeave:Connect(function() if base and btn.Size ~= base then squash(false) end end)
end

local function wireRipple(btn)
	if not btn:GetAttribute("FigmaRipple") then return end
	if btn:GetAttribute("FW_Ripple") then return end
	btn:SetAttribute("FW_Ripple", true)
	btn.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		local host = Instance.new("Frame")
		host.BackgroundTransparency = 1
		host.Size = UDim2.fromScale(1, 1)
		host.ClipsDescendants = true
		host:SetAttribute("FW_Owned", true)
		local corner = btn:FindFirstChildWhichIsA("UICorner")
		if corner then corner:Clone().Parent = host end
		local top = btn.ZIndex -- above the button's own content, or the wash hides under it
		for _, d in ipairs(btn:GetChildren()) do
			if d:IsA("GuiObject") and d.ZIndex > top then top = d.ZIndex end
		end
		host.ZIndex = top + 1
		host.Parent = btn
		local c = btn:GetAttribute("RippleColor") or btn:GetAttribute("FigmaRippleColor") or 16777215
		local op = btn:GetAttribute("RippleOp") or btn:GetAttribute("FigmaRippleOp") or 0.4
		local t = btn:GetAttribute("RippleTime") or btn:GetAttribute("FigmaRippleTime") or 0.45
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.BorderSizePixel = 0
		dot.BackgroundColor3 = Color3.fromRGB(math.floor(c / 65536) % 256, math.floor(c / 256) % 256, c % 256)
		dot.BackgroundTransparency = 1 - op
		dot.Position = UDim2.fromOffset(input.Position.X - btn.AbsolutePosition.X, input.Position.Y - btn.AbsolutePosition.Y)
		dot.Size = UDim2.fromOffset(0, 0)
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(1, 0)
		round.Parent = dot
		dot.Parent = host
		local sz = btn.AbsoluteSize -- reach the farthest corner from the touch, no further
		local px = input.Position.X - btn.AbsolutePosition.X
		local py = input.Position.Y - btn.AbsolutePosition.Y
		local far = math.sqrt(math.max(px, sz.X - px) ^ 2 + math.max(py, sz.Y - py) ^ 2)
		local m = far * 2 -- diameter
		dot.ZIndex = host.ZIndex
		TweenService:Create(dot, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = UDim2.fromOffset(m, m) }):Play()
		TweenService:Create(dot, TweenInfo.new(t * 0.85, Enum.EasingStyle.Quad, Enum.EasingDirection.In), -- fades as it travels
			{ BackgroundTransparency = 1 }):Play()
		task.delay(t + 0.1, function() host:Destroy() end)
	end)
end

local function wireLean(el)
	if not el:GetAttribute("FigmaLean") then return end
	if el:GetAttribute("FW_Lean") then return end
	el:SetAttribute("FW_Lean", true)
	local card = cardAround(el)
	if not card then return end
	local knob = Instance.new("NumberValue") -- rotation goes through the compositor
	knob.Name = "FW_LeanKnob"
	knob:SetAttribute("FW_Owned", true)
	knob.Parent = el
	knob.Changed:Connect(function() fwRotSet(el, "r_hover", knob.Value) end)
	local function lean(on)
		local a = el:GetAttribute("LeanAngle")
		if type(a) ~= "number" then a = el:GetAttribute("FigmaLeanAngle") end
		if type(a) ~= "number" then a = LEAN_ANGLE end
		local t = el:GetAttribute("LeanTime")
		if type(t) ~= "number" then t = el:GetAttribute("FigmaLeanTime") end
		if type(t) ~= "number" then t = LEAN_TIME end
		TweenService:Create(knob, TweenInfo.new(t, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Value = on and a or 0 }):Play()
	end
	local hovered = false
	card.MouseEnter:Connect(function() hovered = true; lean(true) end)
	card.MouseLeave:Connect(function() hovered = false; lean(false) end)
	onScrollMoved(el, function()
		if hovered then hovered = false; lean(false) end
	end)
end

local COLOR_PROP = { -- what paints each class (same rule as the Color runtime)
	Frame = "BackgroundColor3", ScrollingFrame = "BackgroundColor3", CanvasGroup = "BackgroundColor3",
	ImageLabel = "ImageColor3", ImageButton = "ImageColor3",
	TextLabel = "TextColor3", TextButton = "TextColor3", TextBox = "TextColor3",
}
local function hexColor(n)
	if type(n) ~= "number" or n < 0 then return nil end
	return Color3.fromRGB(math.floor(n / 65536) % 256, math.floor(n / 256) % 256, n % 256)
end
local function hoverCoat(el, c1, c2, angle) -- a copy of the layer that carries the gradient and fades over the original
	local coat = el:FindFirstChild("FW_HoverCoat")
	if coat then return coat end
	local fadeProp = "BackgroundTransparency"
	if (el:IsA("TextLabel") or el:IsA("TextButton") or el:IsA("TextBox")) and el.Text ~= "" then
		coat = Instance.new("TextLabel")
		coat.Text = el.Text
		coat.RichText = el.RichText == true
		coat.FontFace = el.FontFace
		coat.TextScaled = el.TextScaled == true
		coat.TextSize = el.TextSize
		coat.TextWrapped = el.TextWrapped == true
		coat.LineHeight = el.LineHeight
		coat.TextXAlignment = el.TextXAlignment
		coat.TextYAlignment = el.TextYAlignment
		coat.TextColor3 = Color3.new(1, 1, 1)
		coat.TextStrokeTransparency = 1
		coat.BackgroundTransparency = 1
		fadeProp = "TextTransparency"
	elseif el:IsA("ImageLabel") or el:IsA("ImageButton") then
		coat = Instance.new("ImageLabel")
		coat.Image = el.Image
		coat.ImageColor3 = Color3.new(1, 1, 1)
		coat.ScaleType = el.ScaleType
		coat.SliceCenter = el.SliceCenter
		coat.SliceScale = el.SliceScale
		coat.TileSize = el.TileSize
		coat.ImageRectOffset = el.ImageRectOffset
		coat.ImageRectSize = el.ImageRectSize
		coat.BackgroundTransparency = 1
		fadeProp = "ImageTransparency"
	else
		coat = Instance.new("Frame")
		coat.BackgroundColor3 = Color3.new(1, 1, 1)
		local corner = el:FindFirstChildOfClass("UICorner")
		if corner then corner:Clone().Parent = coat end
	end
	coat.Name = "FW_HoverCoat"
	coat[fadeProp] = 1
	coat.Size = UDim2.fromScale(1, 1)
	coat.ZIndex = el.ZIndex + 1
	coat:SetAttribute("FW_Owned", true)
	coat:SetAttribute("FW_FadeProp", fadeProp)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c1, c2)
	g.Rotation = angle
	g:SetAttribute("FW_Owned", true)
	g.Parent = coat
	coat.Parent = el
	if fadeProp == "TextTransparency" then -- the text scaler resizes the label later: the copy follows it
		for _, prop in ipairs({ "Text", "TextSize", "TextScaled" }) do
			el:GetPropertyChangedSignal(prop):Connect(function() coat[prop] = el[prop] end)
		end
	end
	return coat
end
local function wireHoverColor(el) -- _color inside a button: the picked colour is the HOVER colour, rest is as drawn
	if not el:GetAttribute("FigmaColor") then return end
	if el:GetAttribute("FW_HoverColor") then return end
	local card = el:IsA("GuiButton") and el or cardAround(el)
	if not card then return end
	local prop = COLOR_PROP[el.ClassName]
	if prop == "TextColor3" then
		local ok, txt = pcall(function() return el.Text end)
		if ok and txt == "" then prop = "BackgroundColor3" end -- a button shell holds no text: its fill IS its colour
	end
	if not prop then return end
	local function hoverColor()
		local c = el:GetAttribute("HoverColor")
		if typeof(c) == "Color3" then return c end
		return hexColor(el:GetAttribute("FigmaColorPick"))
	end
	local function secondColor()
		local c = el:GetAttribute("HoverColor2")
		if typeof(c) == "Color3" then return c end
		return hexColor(el:GetAttribute("FigmaColorPick2"))
	end
	if not hoverColor() then return end
	el:SetAttribute("FW_HoverColor", true)
	local rest = el[prop] -- the design's colour, read BEFORE any hover dim has touched the layer
	el:GetAttributeChangedSignal("Color"):Connect(function() -- code repainted the slot: that is the rest colour now
		local c = el:GetAttribute("Color")
		if typeof(c) == "Color3" then rest = c end
	end)
	local function secs(on)
		local t = el:GetAttribute(on and "ColorIn" or "ColorOut")
		if type(t) ~= "number" then t = el:GetAttribute(on and "FigmaColorIn" or "FigmaColorOut") end
		if type(t) ~= "number" then t = on and LEAN_TIME or 0.25 end -- leaving is slower than arriving, like a real glow cooling
		return math.max(0, t)
	end
	local function paint(on)
		local info = TweenInfo.new(secs(on), Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local c1, c2 = hoverColor(), secondColor()
		if c2 then -- a gradient: a copy of the layer carrying it fades over the original
			local angle = el:GetAttribute("HoverAngle")
			if type(angle) ~= "number" then angle = el:GetAttribute("FigmaColorAngle") or 0 end
			local coat = hoverCoat(el, c1, c2, angle)
			local g = coat:FindFirstChildOfClass("UIGradient")
			if g then g.Color = ColorSequence.new(c1, c2); g.Rotation = angle end
			TweenService:Create(coat, info, { [coat:GetAttribute("FW_FadeProp")] = on and 0 or 1 }):Play()
			return
		end
		local goal = on and c1 or rest
		TweenService:Create(el, info, { [prop] = goal }):Play()
	end
	local hovered = false
	card.MouseEnter:Connect(function() hovered = true; paint(true) end)
	card.MouseLeave:Connect(function() hovered = false; paint(false) end)
	onScrollMoved(el, function()
		if hovered then hovered = false; paint(false) end
	end)
end

local function wireTurn(btn)
	if not btn:GetAttribute("FigmaTurn") then return end
	if btn:GetAttribute("FW_Turn") then return end -- DescendantAdded re-fires on every reparent
	btn:SetAttribute("FW_Turn", true)
	slotFor(btn)
	local knob = Instance.new("NumberValue") -- rotation goes through the compositor
	knob.Name = "FW_TurnKnob"
	knob:SetAttribute("FW_Owned", true)
	knob.Parent = btn
	knob.Changed:Connect(function() fwRotSet(btn, "r_hover", knob.Value) end)
	local function turn(on)
		local a = btn:GetAttribute("TurnAngle")
		if type(a) ~= "number" then a = btn:GetAttribute("FigmaTurnAngle") end
		if type(a) ~= "number" then a = TURN_ANGLE end
		local t = btn:GetAttribute("TurnTime")
		if type(t) ~= "number" then t = btn:GetAttribute("FigmaTurnTime") end
		if type(t) ~= "number" then t = TURN_TIME end
		TweenService:Create(knob, TweenInfo.new(t, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Value = on and a or 0 }):Play()
	end
	local hovered = false
	btn.MouseEnter:Connect(function() hovered = true; turn(true) end)
	btn.MouseLeave:Connect(function() hovered = false; turn(false) end)
	onScrollMoved(btn, function()
		if hovered then hovered = false; turn(false) end
	end)
end

local function wireLift(btn)
	if not btn:GetAttribute("FigmaUp") then return end
	if btn:GetAttribute("FW_Lift") then return end
	btn:SetAttribute("FW_Lift", true)
	slotFor(btn)
	local base = nil
	local function px()
		local r = gui:FindFirstChildWhichIsA("GuiObject")
		if not r then
			for _, v in ipairs(gui:GetChildren()) do
				if v:IsA("BillboardGui") then -- clickable _billboard: kept inside this ScreenGui
					r = v:FindFirstChildWhichIsA("GuiObject")
					break
				end
				if v:IsA("ObjectValue") and v.Name == "FW_ExtraRoot" and v.Value then
					r = v.Value:FindFirstChildWhichIsA("GuiObject")
					break
				end
			end
		end
		local dh = gui:GetAttribute("BB_DesignH")
		if r and type(dh) == "number" and dh > 0 and r.AbsoluteSize.Y > 1 then return r.AbsoluteSize.Y / dh end
		return 1
	end
	local function lift(on)
		local d = btn:GetAttribute("UpDist")
		if type(d) ~= "number" then d = btn:GetAttribute("FigmaUpDist") end
		if type(d) ~= "number" then d = UP_DIST end
		local t = btn:GetAttribute("UpTime")
		if type(t) ~= "number" then t = btn:GetAttribute("FigmaUpTime") end
		if type(t) ~= "number" then t = UP_TIME end
		local info = TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		if not base then base = btn.Position end
		local goal = on and (base + UDim2.fromOffset(0, -d * px())) or base
		TweenService:Create(btn, info, { Position = goal }):Play()
	end
	local raised = false
	btn.MouseEnter:Connect(function() raised = true; lift(true) end)
	btn.MouseLeave:Connect(function() raised = false; lift(false) end)
	if btn:IsA("GuiButton") then
		btn.MouseButton1Up:Connect(function() raised = true; lift(true) end)
	end
	onScrollMoved(btn, function()
		if raised then raised = false; lift(false) end
	end)
end

local function scan(inst)
	if (inst:IsA("TextButton") or inst:IsA("ImageButton")) and inst:GetAttribute("FW_Owned") == true then
		wire(inst)
		wireLift(inst)
		wireTurn(inst)
		wireSquish(inst)
		wireRipple(inst)
	elseif inst:IsA("GuiObject") then
		wireLift(inst) -- hover effects need no button: _scroll/_canvas win the class
		wireTurn(inst)
	end
	if inst:IsA("GuiObject") then wireLean(inst); wireHoverColor(inst) end
end
scan(root)
for _, d in ipairs(root:GetDescendants()) do scan(d) end
root.DescendantAdded:Connect(scan)
