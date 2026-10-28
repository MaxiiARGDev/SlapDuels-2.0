-- Framewisp: _spin — rotates the element around its centre in game.
-- Per-element override: add a number attribute "SpinSpeed" to any spinning
-- element in the Properties panel (degrees per second, negative spins
-- counter-clockwise) — it survives Live Sync. Safe to delete for static UI.
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

-- ========================== tune the feel here ==========================
-- SPIN_SPEED — default rotation speed, in degrees per second.
--   45 = slow ambient   ·   120 = default   ·   360 = fast loader
--   negative = counter-clockwise
-- ========================================================================
local SPIN_SPEED = 120

local function centre(el)
	if el.AnchorPoint == Vector2.new(0.5, 0.5) then return end
	if el.Parent then
		for _, ch in ipairs(el.Parent:GetChildren()) do
			if ch:IsA("UIListLayout") or ch:IsA("UIGridLayout") or ch:IsA("UITableLayout") or ch:IsA("UIPageLayout") then
				return
			end
		end
	end
	local ap, pos, sz = el.AnchorPoint, el.Position, el.Size
	el.Position = UDim2.new(
		pos.X.Scale + (0.5 - ap.X) * sz.X.Scale,
		pos.X.Offset + (0.5 - ap.X) * sz.X.Offset,
		pos.Y.Scale + (0.5 - ap.Y) * sz.Y.Scale,
		pos.Y.Offset + (0.5 - ap.Y) * sz.Y.Offset
	)
	el.AnchorPoint = Vector2.new(0.5, 0.5)
end

local spinners = {}
for _, d in ipairs(fwAll()) do
	if d:GetAttribute("FigmaSpin") and d:IsA("GuiObject") then
		centre(d)
		spinners[#spinners + 1] = d
	end
end
if #spinners == 0 then return end

RunService.Heartbeat:Connect(function(dt)
	for _, el in ipairs(spinners) do
		if el.Parent then
			local spd = el:GetAttribute("SpinSpeed")
			if type(spd) ~= "number" then spd = el:GetAttribute("FigmaSpinSpeed") end
			if type(spd) ~= "number" then spd = SPIN_SPEED end
			fwRotSet(el, "r_spin", ((el:GetAttribute("r_spin") or 0) + spd * dt) % 360)
		end
	end
end)
