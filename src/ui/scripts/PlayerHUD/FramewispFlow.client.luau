-- Framewisp: _flow animates a fill, its outline, or both. Safe to delete.
-- FlowMove: 0 seamless Offset (default), 1 Rotation. FlowOn: 0 fill, 1 stroke, 2 both.
-- FlowMode: 0 original colors, 1 rainbow. _stroke keeps priority over the outline.
-- FlowAngle defaults to the original angle; FlowDirection defaults to that angle.
-- FlowSpeed: cycles/sec (0..4); FlowRotate: signed degrees/sec (-3600..3600).
-- With no explicit speed, legacy FlowTime still controls seconds per full pass.
-- FlowStretch: gradient width (0.5..4); FlowPhase: 0..1 of the mirrored period.
-- FlowOffsetX/Y default to the original gradient offset. Manual Flow* overrides FigmaFlow*.
-- FlowCount: 1..8 Offset bands; Rotation and reduced motion keep the authored stops.
-- Dense bands simplify once, then limit density to preserve an Own color/alpha peak.
-- Textured fills animate a private clone of the hidden FigmaFlowOverlay silhouette.
-- Original image RGB/alpha and the template are readonly; overlay intensity defaults to .35.
-- A generated FigmaFlowSurface Canvas composites the fill below foreground UI;
-- its outer wrapper retains the Flow controls and native stroke ownership.
-- FlowFillBrightness defaults to .9; FlowOutlineBrightness defaults to 1.15.
-- Both preserve HSV hue in 0..2 without altering alpha; 1 restores the chosen palette.
-- Dimming scales Value; boosting scales Value and Saturation, never mixes in white.
-- FlowContrast defaults to .35: RGB-only light band, source palette/alpha unchanged.
-- A private FigmaFlowStrokeOwn outline uses only Stroke* controls and raw source RGB/alpha.
local RunService = game:GetService("RunService")
local gui = script.Parent
local roots = { gui }
for _, v in ipairs(gui:GetChildren()) do
	if v:IsA("ObjectValue") and v.Name == "FW_ExtraRoot" and v.Value then
		roots[#roots + 1] = v.Value
	end
end
local function number(el, key, fallback, lo, hi)
	local v = el:GetAttribute(key)
	if type(v) ~= "number" or v ~= v or math.abs(v) == math.huge then v = el:GetAttribute("Figma" .. key) end
	if type(v) ~= "number" or v ~= v or math.abs(v) == math.huge then return fallback end
	return math.clamp(v, lo, hi)
end
local function inside(el)
	for _, root in ipairs(roots) do
		if el == root or el:IsDescendantOf(root) then return true end
	end
	return false
end
local function visible(el)
	local p = el
	while p do
		if p:IsA("GuiObject") and not p.Visible then return false end
		if (p:IsA("ScreenGui") or p:IsA("SurfaceGui") or p:IsA("BillboardGui")) and not p.Enabled then return false end
		p = p.Parent
	end
	return true
end
local function reduced(el)
	local p = el
	while p do
		if p:GetAttribute("FW_ReduceMotion") == true then return true end
		p = p.Parent
	end
	return gui:GetAttribute("FW_ReduceMotion") == true
end
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 79, 79)),
	ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 176, 59)),
	ColorSequenceKeypoint.new(0.34, Color3.fromRGB(247, 226, 74)),
	ColorSequenceKeypoint.new(0.50, Color3.fromRGB(93, 222, 130)),
	ColorSequenceKeypoint.new(0.67, Color3.fromRGB(78, 178, 255)),
	ColorSequenceKeypoint.new(0.84, Color3.fromRGB(163, 122, 255)),
	ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 79, 79)),
})
local SHINE = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.new(0.35, 0.35, 0.35)),
	ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
	ColorSequenceKeypoint.new(1, Color3.new(0.35, 0.35, 0.35)),
})
local SHINE_ALPHA = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.35),
	NumberSequenceKeypoint.new(0.5, 0),
	NumberSequenceKeypoint.new(1, 0.35),
})
local OPAQUE = NumberSequence.new(0)
local moving, watched, connections = {}, {}, {}
local overlayOwners, outlineOwners, templateHooks, surfaceHooks = {}, {}, {}, {}
local ownerTables = { overlayOwners, outlineOwners }
local queueSync, watchTemplate, watchSurface
local stopped = false
local function active(el, key)
	local value = el:GetAttribute(key)
	return value ~= nil and value ~= false and value ~= 0
end
local function surfaceOwner(surface)
	if surface and surface:IsA("CanvasGroup") and active(surface, "FigmaFlowSurface")
		and not surface:GetAttribute("FigmaNodeId") and surface.Parent and surface.Parent:IsA("GuiObject") then
		return surface.Parent
	end
	return nil
end
local function templateOwner(template)
	local parent = template.Parent
	if not parent or not parent:IsA("GuiObject") then return nil end
	return surfaceOwner(parent) or parent
end
local function paintParent(el, template)
	local parent = template and template.Parent
	if parent == el or surfaceOwner(parent) == el then return parent end
	return nil
end
local function interpolate(a, b, t, color)
	return color and a:Lerp(b, t) or a + (b - a) * t
end
local function sample(keys, u, color)
	local x = u % 2
	if x > 1 then x = 2 - x end
	for i = 2, #keys do
		local a, b = keys[i - 1], keys[i]
		if x <= b.Time then
			local t = (x - a.Time) / (b.Time - a.Time)
			return interpolate(a.Value, b.Value, t, color), color and 0 or interpolate(a.Envelope or 0, b.Envelope or 0, t, false)
		end
	end
	local last = keys[#keys]
	return last.Value, color and 0 or (last.Envelope or 0)
end
local function windowKeys(keys, span)
	local times = {}
	for _, key in ipairs(keys) do times[#times + 1] = key.Time end
	for i = #keys - 1, 2, -1 do times[#times + 1] = 2 - keys[i].Time end
	local n = #times
	local whole = math.floor(span / 2)
	local remainder = span - whole * 2
	local largest = 0
	if remainder > 1e-10 then
		for i = 1, n do
			local j = i
			while j < i + n do
				local time = times[(j - 1) % n + 1] + math.floor((j - 1) / n) * 2
				if time - times[i] >= remainder then break end
				j += 1
			end
			largest = math.max(largest, j - i)
		end
	end
	return whole * n + largest + 2
end
local function sourceError(a, b, c, color)
	local t = (b.Time - a.Time) / (c.Time - a.Time)
	if color then
		return math.max(math.abs(b.Value.R - interpolate(a.Value.R, c.Value.R, t, false)),
			math.abs(b.Value.G - interpolate(a.Value.G, c.Value.G, t, false)), math.abs(b.Value.B - interpolate(a.Value.B, c.Value.B, t, false)))
	end
	return math.max(math.abs(b.Value - interpolate(a.Value, c.Value, t, false)),
		math.abs((b.Envelope or 0) - interpolate(a.Envelope or 0, c.Envelope or 0, t, false)))
end
local function fitSource(source, stretch, color)
	local keys = {}
	for _, key in ipairs(source) do
		if #keys > 0 and keys[#keys].Time == key.Time then keys[#keys] = key
		else keys[#keys + 1] = key end
	end
	local minimum = 2
	for i = 2, #keys - 1 do
		if sourceError(keys[1], keys[i], keys[#keys], color) > 1e-10 then minimum = 3;break end
	end
	local approximated = false
	while #keys > minimum and windowKeys(keys, 1 / stretch) > 20 do
		local best, index = math.huge, 2
		for i = 2, #keys - 1 do
			local error = sourceError(keys[i - 1], keys[i], keys[i + 1], color)
			if error < best then best, index = error, i end
		end
		if best > 1e-10 then approximated = true end
		table.remove(keys, index)
	end
	local safe = stretch
	if windowKeys(keys, 1 / safe) > 20 then
		local lo, hi = safe, math.max(1, safe)
		for _ = 1, 40 do
			local mid = (lo + hi) / 2
			if windowKeys(keys, 1 / mid) > 20 then lo = mid else hi = mid end
		end
		safe = hi
	end
	return keys, safe, approximated or safe > stretch + 1e-10
end
local function translated(keys, first, stretch, color)
	local points = {}
	local function add(u, key)
		local time = (u - first) * stretch
		if time > 0 and time < 1 then points[#points + 1] = { time = time, value = key.Value, envelope = color and 0 or (key.Envelope or 0) } end
	end
	for cycle = math.floor(first / 2), math.floor((first + 1 / stretch) / 2) do
		for _, key in ipairs(keys) do
			add(cycle * 2 + key.Time, key)
			add(cycle * 2 + 2 - key.Time, key)
		end
	end
	table.sort(points, function(a, b) return a.time < b.time end)
	local function keypoint(time, value, envelope)
		return color and ColorSequenceKeypoint.new(time, value) or NumberSequenceKeypoint.new(time, value, envelope)
	end
	local value, envelope = sample(keys, first, color)
	local out = { keypoint(0, value, envelope) }
	for _, point in ipairs(points) do
		local key = keypoint(point.time, point.value, point.envelope)
		if key.Time > 0 and key.Time < 1 then
			if key.Time > out[#out].Time then out[#out + 1] = key
			elseif key.Time == out[#out].Time then out[#out] = key end
		end
	end
	value, envelope = sample(keys, first + 1 / stretch, color)
	out[#out + 1] = keypoint(1, value, envelope)
	return color and ColorSequence.new(out) or NumberSequence.new(out)
end
local function setTint(host, m, white)
	if m.white == white then return end
	m.white = white
	if m.tintKey then host[m.tintKey] = white and Color3.new(1, 1, 1) or m.tint end
	if m.nativeOutline then host:SetAttribute("FW_FlowWhite", white and true or m.strokeWhite) end
end
local function opacityAlpha(m, source, opacity)
	if opacity == 1 then return source end
	if m.opacity == opacity and m.opacitySource == source then return m.opacityAlpha end
	local keys = {}
	for _, key in ipairs(source.Keypoints) do
		keys[#keys + 1] = NumberSequenceKeypoint.new(key.Time, 1 - (1 - key.Value) * opacity, (key.Envelope or 0) * opacity)
	end
	m.opacity, m.opacitySource, m.opacityAlpha = opacity, source, NumberSequence.new(keys)
	return m.opacityAlpha
end
local function contrastColor(m, source, contrast)
	if contrast == 0 then return source end
	if m.contrast == contrast and m.contrastSource == source then return m.contrastColor end
	local times = { 0.5 }
	for _, key in ipairs(source.Keypoints) do times[#times + 1] = key.Time end
	table.sort(times)
	local keys, previous = {}, nil
	for _, time in ipairs(times) do
		if time ~= previous then
			local c = sample(source.Keypoints, time, true)
			local gain = 1 - contrast * math.abs(2 * time - 1)
			keys[#keys + 1] = ColorSequenceKeypoint.new(time, Color3.new(c.R * gain, c.G * gain, c.B * gain))
			previous = time
		end
	end
	if #keys > 20 then keys = fitSource(keys, 1, true) end -- budget before creating a sequence
	m.contrast, m.contrastSource, m.contrastColor = contrast, source, ColorSequence.new(keys)
	return m.contrastColor
end
local function brightnessColor(m, source, brightness)
	if brightness == 1 then return source end
	if m.brightness == brightness and m.brightnessSource == source then return m.brightnessColor end
	local keys = {}
	for _, key in ipairs(source.Keypoints) do
		local c = key.Value
		local color
		if brightness <= 1 then
			color = Color3.new(c.R * brightness, c.G * brightness, c.B * brightness)
		else
			local maximum, minimum = math.max(c.R, c.G, c.B), math.min(c.R, c.G, c.B)
			local delta = maximum - minimum
			local value = math.min(1, maximum * brightness)
			local saturation = maximum > 0 and math.min(1, delta / maximum * brightness) or 0
			local low = value * (1 - saturation)
			local function channel(v)
				return delta > 0 and low + (v - minimum) / delta * (value - low) or value -- keeps Hue
			end
			color = Color3.new(channel(c.R), channel(c.G), channel(c.B))
		end
		keys[#keys + 1] = ColorSequenceKeypoint.new(key.Time, color)
	end
	m.brightness, m.brightnessSource, m.brightnessColor = brightness, source, ColorSequence.new(keys)
	return m.brightnessColor
end
local function release(host, removing)
	local m = moving[host]
	if not m then return end
	moving[host] = nil
	if m.overlay then
		local state = m.state
		if state and state.host == host then state.host = nil end
		if host ~= removing and host.Parent and host:GetAttribute("FW_FlowOverlay") == true then
			if removing then task.defer(function() if host.Parent then host:Destroy() end end)
			else host:Destroy() end
		end
		return
	end
	if m.grad and m.grad.Parent == host then
		if m.made then
			if m.grad ~= removing then m.grad:Destroy() end
		else
			m.grad.Color = m.color
			m.grad.Transparency = m.alpha
			m.grad.Rotation = m.rotation
			m.grad.Offset = m.offset
		end
	end
	if m.tintKey then host[m.tintKey] = m.tint end
	if m.nativeOutline then host:SetAttribute("FW_FlowWhite", m.strokeWhite) end
	host:SetAttribute("FW_FlowCountEffective", m.countEffective)
	host:SetAttribute("FW_FlowCountApprox", m.countApprox)
end
local function paintStrokeOwn(host, m, dt)
	local el, grad = m.el, m.grad
	local still = reduced(el) or (m.paintParent and reduced(m.paintParent))
	local mode = number(el, "StrokeMode", 0, 0, 1) >= 0.5 and 1 or 0
	if m.mode ~= mode then m.mode, m.turn, m.travel = mode, 0, 0 end
	local angle = number(el, "StrokeAngle", m.rotation, -360, 360)
	if not still then
		if mode == 0 then m.turn = (m.turn + dt * number(el, "StrokeRotate", 45, -360, 360)) % 360
		else
			local direction = number(el, "StrokeDirection", 0, -360, 360)
			local projection = (direction - angle) % 180 == 90 and 0 or math.cos(math.rad(direction - angle))
			m.travel = (m.travel + dt * number(el, "StrokeSpeed", 0.35, 0, 4) * projection) % 1
		end
	end
	grad.Rotation = (angle + (not still and mode == 0 and (m.turn + number(el, "StrokePhase", 0, 0, 1) * 360) or 0)) % 360
	local x = number(el, "StrokeOffsetX", m.offset.X, -2, 2)
	local y = number(el, "StrokeOffsetY", m.offset.Y, -2, 2)
	if still or mode == 0 then
		if m.currentColor ~= m.color then grad.Color = m.color; m.currentColor = m.color end
		if m.currentAlpha ~= m.alpha then grad.Transparency = m.alpha; m.currentAlpha = m.alpha end
		m.first, m.requested = nil, nil
		grad.Offset = Vector2.new(x, y)
		return
	end
	grad.Offset = Vector2.new(0, 0)
	local requested = number(el, "StrokeStretch", 1, 0.5, 4)
	if m.requested ~= requested then
		local c, cs = fitSource(m.color.Keypoints, requested, true)
		local a, as = fitSource(m.alpha.Keypoints, requested, false)
		m.colors, m.alphas, m.stretch, m.requested = c, a, math.max(cs, as), requested
		m.first = nil
	end
	local size = el.AbsoluteSize
	local w, h = math.max(size.X, 1), math.max(size.Y, 1)
	local cos, sin = math.cos(math.rad(angle)), math.sin(math.rad(angle))
	local length = math.abs(cos) * w + math.abs(sin) * h
	local rest = (cos * w * x + sin * h * y) / length
	local first = (-0.5 - rest) / m.stretch + 0.5 - 2 * ((m.travel + number(el, "StrokePhase", 0, 0, 1)) % 1)
	if m.first == first then return end
	grad.Color = translated(m.colors, first, m.stretch, true)
	grad.Transparency = translated(m.alphas, first, m.stretch, false)
	m.first, m.currentColor, m.currentAlpha = first, grad.Color, grad.Transparency
end
local function paint(host, m, dt)
	if m.strokeOwn then paintStrokeOwn(host, m, dt); return end
	local el, grad = m.el, m.grad
	local still = reduced(el)
	local mode = number(el, "FlowMove", 0, 0, 1) >= 0.5 and 1 or 0
	if m.mode ~= mode then m.mode, m.turn, m.travel = mode, 0, 0 end
	local rainbow = number(el, "FlowMode", 0, 0, 1) >= 0.5
	local sourceRotation = rainbow and m.rainbowRotation or m.rotation
	local sourceOffset = rainbow and m.rainbowOffset or m.offset
	local angle = number(el, "FlowAngle", sourceRotation, -360, 360)
	local duration = number(el, "FlowTime", 2, 0.05, math.huge)
	if not still then
		if mode == 1 then
			m.turn = (m.turn + dt * number(el, "FlowRotate", 360 / duration, -3600, 3600)) % 360
		else
			local direction = number(el, "FlowDirection", angle, -360, 360)
			local projection = (direction - angle) % 180 == 90 and 0 or math.cos(math.rad(direction - angle))
			m.travel = (m.travel + dt * number(el, "FlowSpeed", 1 / duration, 0, 4) * projection) % 1
		end
	end
	local phase = number(el, "FlowPhase", 0, 0, 1)
	grad.Rotation = (angle + (not still and mode == 1 and (m.turn + phase * 360) or 0)) % 360
	local x = number(el, "FlowOffsetX", sourceOffset.X, -2, 2)
	local y = number(el, "FlowOffsetY", sourceOffset.Y, -2, 2)
	local fallback = m.fallback or m.made and not m.seeded
	local color = still and (m.fallback and not rainbow and m.fallbackStillColor or m.color)
		or (rainbow and m.rainbowColor or (fallback and (m.fallbackOwnColor or SHINE) or m.color))
	local alpha = still and m.alpha or (fallback and not rainbow and (m.fallbackOwnAlpha or SHINE_ALPHA) or m.alpha)
	if not still then
		alpha = opacityAlpha(m, alpha, number(el, "FlowOpacity", m.overlay and 0.35 or 1, 0, 1))
		color = contrastColor(m, color, number(el, "FlowContrast", 0.35, 0, 1))
		color = brightnessColor(m, color, m.outline and number(el, "FlowOutlineBrightness", 1.15, 0, 2) or number(el, "FlowFillBrightness", 0.9, 0, 2))
	end
	setTint(host, m, not still and (m.outline or rainbow))
	if still or mode == 1 then
		if m.currentColor ~= color then grad.Color = color; m.currentColor = color end
		if m.currentAlpha ~= alpha then grad.Transparency = alpha; m.currentAlpha = alpha end
		m.first, m.requested = nil, nil
		host:SetAttribute("FW_FlowCountEffective", m.countEffective)
		host:SetAttribute("FW_FlowCountApprox", m.countApprox)
		grad.Offset = Vector2.new(x, y)
		return
	end
	grad.Offset = Vector2.new(0, 0)
	local authoredStretch = number(el, "FlowStretch", 1, 0.5, 4)
	local count = math.floor(number(el, "FlowCount", 1, 1, 8) + 0.5)
	local requested = authoredStretch / count
	if m.requested ~= requested or m.count ~= count or m.sourceColor ~= color or m.sourceAlpha ~= alpha then
		local c, cs, ca = fitSource(color.Keypoints, requested, true)
		local a, as, aa = fitSource(alpha.Keypoints, requested, false)
		local stretch = math.max(cs, as)
		m.colors, m.alphas = c, a
		m.stretch, m.requested, m.count = stretch, requested, count
		m.sourceColor, m.sourceAlpha = color, alpha
		if count > 1 then
			host:SetAttribute("FW_FlowCountEffective", authoredStretch / stretch)
			host:SetAttribute("FW_FlowCountApprox", (ca or aa) and true or nil)
			if (ca or aa) and not m.countWarned then
				m.countWarned = true
				warn("[Framewisp] _flow bands approximated to fit 20 gradient keys; Own color/alpha peaks are retained. See FW_FlowCountEffective.")
			end
		else
			host:SetAttribute("FW_FlowCountEffective", m.countEffective)
			host:SetAttribute("FW_FlowCountApprox", m.countApprox)
		end
		m.first = nil
	end
	local stretch = m.stretch
	local size = el.AbsoluteSize
	local w, h = math.max(size.X, 1), math.max(size.Y, 1)
	local cos, sin = math.cos(math.rad(angle)), math.sin(math.rad(angle))
	local length = math.abs(cos) * w + math.abs(sin) * h
	local rest = (cos * w * x + sin * h * y) / length
	local first = (-0.5 - rest) / stretch + 0.5 - 2 * ((m.travel + phase) % 1)
	if m.first == first then return end
	local outputColor = translated(m.colors, first, stretch, true)
	local outputAlpha = translated(m.alphas, first, stretch, false)
	grad.Color, grad.Transparency = outputColor, outputAlpha
	m.first, m.currentColor, m.currentAlpha = first, outputColor, outputAlpha
end
local function acquire(el, host, overlay, state, outline, strokeOwn, palette)
	if moving[host] or not inside(el) then return end
	local grad = host:FindFirstChildWhichIsA("UIGradient")
	local m = { el = el, made = grad == nil, turn = 0, travel = 0, outline = host:IsA("UIStroke") or outline, nativeOutline = host:IsA("UIStroke"), overlay = overlay,
		state = state, strokeOwn = strokeOwn, paintParent = overlay and host.Parent or nil }
	moving[host] = m -- reserve before parenting a generated gradient fires DescendantAdded
	if not grad then
		grad = Instance.new("UIGradient")
		grad.Name = "FW_FlowGradient"
		grad:SetAttribute("FW_Owned", true)
	end
	if m.made and m.nativeOutline and palette then
		grad.Color, grad.Transparency, grad.Rotation, grad.Offset = palette.Color, palette.Transparency, palette.Rotation, palette.Offset
		m.seeded = true -- a solid outline shares the chosen fill palette, without a permanent source gradient
	end
	m.grad, m.color, m.alpha, m.rotation, m.offset = grad, grad.Color, grad.Transparency, grad.Rotation, grad.Offset
	m.rainbowColor, m.rainbowRotation, m.rainbowOffset = RAINBOW, m.rotation, m.offset
	local sourcePalette = m.made and m.nativeOutline and palette or grad
	local function paletteAttribute(key)
		if type(sourcePalette.GetAttribute) == "function" then return sourcePalette:GetAttribute(key) end
		return sourcePalette[key]
	end
	m.fallback = paletteAttribute("FigmaFlowPaletteFallback") == 1
	local rawPalette = paletteAttribute("FigmaFlowRainbow")
	m.rawPalette = rawPalette
	if type(rawPalette) == "string" then
		local ok, data = pcall(function() return game:GetService("HttpService"):JSONDecode(rawPalette) end)
		if ok and type(data) == "table" and type(data.stops) == "table" and #data.stops >= 2 and #data.stops <= 20 then
			local points, last, valid = {}, -1, true
			for _, stop in ipairs(data.stops) do
				if type(stop) ~= "table" or type(stop.p) ~= "number" or stop.p ~= stop.p or stop.p <= last or stop.p < 0 or stop.p > 1 then valid = false; break end
				for _, key in ipairs({"r", "g", "b"}) do if type(stop[key]) ~= "number" or stop[key] ~= stop[key] or stop[key] < 0 or stop[key] > 1 then valid = false end end
				if not valid then break end
				points[#points + 1] = ColorSequenceKeypoint.new(stop.p, Color3.fromRGB(math.floor(stop.r * 255 + .5), math.floor(stop.g * 255 + .5), math.floor(stop.b * 255 + .5)))
				last = stop.p
			end
			if valid and points[1].Time == 0 and points[#points].Time == 1 then
				m.rainbowColor = ColorSequence.new(points)
				local fallbackColor = data.fallbackColor
				if m.fallback and type(fallbackColor) == "table" then
					local validColor = true
					for _, key in ipairs({"r", "g", "b", "a"}) do
						local value = fallbackColor[key]
						if type(value) ~= "number" or value ~= value or value < 0 or value > 1 then validColor = false end
					end
					if validColor then
						local tint = Color3.fromRGB(math.floor(fallbackColor.r * 255 + .5), math.floor(fallbackColor.g * 255 + .5), math.floor(fallbackColor.b * 255 + .5))
						m.fallbackStillColor = ColorSequence.new(tint)
						m.fallbackOwnColor = ColorSequence.new({ColorSequenceKeypoint.new(0, Color3.new(tint.R * .35, tint.G * .35, tint.B * .35)),
							ColorSequenceKeypoint.new(.5, tint), ColorSequenceKeypoint.new(1, Color3.new(tint.R * .35, tint.G * .35, tint.B * .35))})
						m.fallbackOwnAlpha = NumberSequence.new({NumberSequenceKeypoint.new(0, 1 - .65 * fallbackColor.a),
							NumberSequenceKeypoint.new(.5, 1 - fallbackColor.a), NumberSequenceKeypoint.new(1, 1 - .65 * fallbackColor.a)})
					end
				end
				if type(data.rotation) == "number" and data.rotation == data.rotation and math.abs(data.rotation) <= 360 then m.rainbowRotation = data.rotation end
				if type(data.offset) == "table" and type(data.offset.x) == "number" and type(data.offset.y) == "number"
					and data.offset.x == data.offset.x and data.offset.y == data.offset.y and math.abs(data.offset.x) <= 2 and math.abs(data.offset.y) <= 2 then
					m.rainbowOffset = Vector2.new(data.offset.x, data.offset.y)
				end
			end
		end
	end
	m.currentColor, m.currentAlpha = m.color, m.alpha
	m.countEffective, m.countApprox = host:GetAttribute("FW_FlowCountEffective"), host:GetAttribute("FW_FlowCountApprox")
	if m.nativeOutline then
		m.tintKey, m.strokeWhite = "Color", host:GetAttribute("FW_FlowWhite")
	elseif host:IsA("TextLabel") or host:IsA("TextButton") or host:IsA("TextBox") then m.tintKey = "TextColor3"
	elseif host:IsA("ImageLabel") or host:IsA("ImageButton") then m.tintKey = "ImageColor3"
	else m.tintKey = "BackgroundColor3" end
	m.tint = host[m.tintKey]
	if m.made then grad.Parent = host end
	paint(host, m, 0)
end
local function overlayTemplate(el, outline)
	local function find(host)
		for _, child in ipairs(host:GetChildren()) do
			if child:IsA("ImageLabel") and not child.Visible and active(child, "FigmaFlowOverlay") and not child:GetAttribute("FW_FlowOverlay")
				and active(child, "FigmaFlowOutline") == (outline == true) then return child end
		end
	end
	local direct = find(el)
	if direct then return direct end
	for _, child in ipairs(el:GetChildren()) do
		if surfaceOwner(child) == el then
			local template = find(child)
			if template then return template end
		end
	end
	return nil
end
local function overlayClone(el, template, state)
	local parent = paintParent(el, template)
	if not parent then return end
	local ok, host = pcall(function() return template:Clone() end)
	if not ok or not host then
		if not state.warned then state.warned = true; warn("[Framewisp] _flow silhouette cannot be cloned; original texture is preserved.") end
		return
	end
	for _, child in ipairs(host:GetChildren()) do
		if not child:IsA("UIGradient") and not child:IsA("UICorner") then child:Destroy() end
	end
	local nodes = host:GetDescendants(); nodes[#nodes + 1] = host
	for _, node in ipairs(nodes) do
		for key in pairs(node:GetAttributes()) do
			if (key:sub(1, 5) == "Figma" and not (node:IsA("UIGradient") and (key == "FigmaGradient" or key == "FigmaFlowRainbow" or key == "FigmaFlowPaletteFallback"))) or key:sub(1, 3) == "FW_" then
				node:SetAttribute(key, nil)
			end
		end
	end
	host.Name = state.outline and "FW_FlowOutline" or "FW_FlowOverlay"
	host:SetAttribute("FW_Owned", true)
	host:SetAttribute("FW_FlowOverlay", true)
	if state.outline then host:SetAttribute("FW_FlowOutline", true) end
	host.Visible = true
	host.Active = false
	host.Selectable = false
	state.host = host -- reserve before parenting fires DescendantAdded
	host.Parent = parent
	acquire(el, host, true, state, state.outline, state.strokeOwn)
end
local function syncOutline(el, template, on)
	local state = outlineOwners[el]
	if template then
		if not state then state = { outline = true }; outlineOwners[el] = state end
		if template.Parent ~= el then watchSurface(template.Parent) end
		watchTemplate(template, el)
	end
	if not state then return end
	local parent = paintParent(el, template)
	local strokeOwn = template ~= nil and active(template, "FigmaFlowStrokeOwn") and active(el, "FigmaStroke")
	if state.template ~= template or state.paintParent ~= parent or state.strokeOwn ~= strokeOwn then
		if state.host then release(state.host) end
		state.template, state.paintParent, state.strokeOwn = template, parent, strokeOwn
	end
	state.allowed = parent ~= nil and (strokeOwn or (on >= 1 and not active(el, "FigmaStroke")))
		and visible(el) and visible(parent) and not reduced(el) and not reduced(parent)
	if state.allowed and template then
		if not state.host then overlayClone(el, template, state) end
	elseif state.host then release(state.host) end
end
local function sync(el)
	if not el.Parent or not inside(el) or not active(el, "FigmaFlow") then
		for _, owners in ipairs(ownerTables) do local state = owners[el]; if state then state.allowed = false end end
		for host, m in pairs(moving) do if m.el == el then release(host) end end
		return
	end
	local on = math.floor(number(el, "FlowOn", 0, 0, 2) + 0.5)
	local template = overlayTemplate(el)
	local state = overlayOwners[el]
	if template then
		if not state then state = {}; overlayOwners[el] = state end
		if template.Parent ~= el then watchSurface(template.Parent) end
		watchTemplate(template, el)
	end
	if state then
		release(el) -- a missing known silhouette cannot fall back to the RGB source
		local parent = paintParent(el, template)
		if state.template ~= template or state.paintParent ~= parent then
			if state.host then release(state.host) end
			state.template, state.paintParent = template, parent
		end
		state.allowed = (on == 0 or on == 2) and parent ~= nil and visible(el) and visible(parent) and not reduced(el) and not reduced(parent)
		if state.allowed and template then
			if not state.host then overlayClone(el, template, state) end
		elseif state.host then release(state.host) end
	elseif on == 0 or on == 2 then acquire(el, el) else release(el) end
	local outline = overlayTemplate(el, true)
	syncOutline(el, outline, on)
	local found = outline ~= nil
	local paletteHost = template or el
	local source = moving[paletteHost] -- source palette precedes fill brightness/alpha
	local palette = paletteHost:FindFirstChildWhichIsA("UIGradient")
	if source then
		palette = (not source.made or source.seeded)
			and { Color = source.color, Transparency = source.alpha, Rotation = source.rotation, Offset = source.offset,
				FigmaFlowRainbow = source.rawPalette, FigmaFlowPaletteFallback = source.fallback and 1 or nil } or nil
	end
	for _, st in ipairs(el:GetChildren()) do
		if st:IsA("UIStroke") then
			found = true
			if not outline and on >= 1 and not active(el, "FigmaStroke") then acquire(el, st, nil, nil, nil, nil, palette)
			else release(st) end -- _stroke owns the outline; _flow can still own the fill
		end
	end
	if not found and on == 1 and not active(el, "FigmaStroke") then
		warn(("[Framewisp] _flow on %q asks for the stroke, but the layer has none — add one in Figma."):format(el.Name))
	end
end
queueSync = function(el)
	local hooks = watched[el]
	if not hooks or hooks.pending or not inside(el) then return end
	hooks.pending = true
	task.defer(function() -- the other runtime restores its design first, in either subscription order
		hooks.pending = false
		if not stopped and watched[el] == hooks and inside(el) then sync(el) end
	end)
end
watchTemplate = function(template, el)
	local previous = templateHooks[template]
	if previous then
		if previous.el == el then return end
		local owners = previous.outline and outlineOwners or overlayOwners
		local state = owners[previous.el]
		if state and state.host then release(state.host) end
		for _, hook in ipairs(previous) do hook:Disconnect() end
		queueSync(previous.el)
	end
	local hooks = { el = el, outline = active(template, "FigmaFlowOutline") }
	templateHooks[template] = hooks
	local function refresh()
		for _, owners in ipairs(ownerTables) do
			local state = owners[el]
			if state and state.template == template and state.host then release(state.host) end
		end
		queueSync(el)
	end
	hooks.refresh = refresh
	hooks[#hooks + 1] = template:GetPropertyChangedSignal("Parent"):Connect(function()
		refresh()
		local owner = templateOwner(template)
		if owner then queueSync(owner) end
	end)
	for _, key in ipairs({ "Archivable", "Visible", "Image", "ImageColor3", "ImageTransparency", "ImageRectOffset", "ImageRectSize", "ScaleType", "Size", "Position", "AnchorPoint", "Rotation", "ZIndex" }) do
		hooks[#hooks + 1] = template:GetPropertyChangedSignal(key):Connect(refresh)
	end
	for _, key in ipairs({ "FigmaFlowOverlay", "FigmaFlowOutline", "FigmaFlowStrokeOwn" }) do
		hooks[#hooks + 1] = template:GetAttributeChangedSignal(key):Connect(refresh)
	end
	local function watchGradient(gradient)
		if not gradient:IsA("UIGradient") then return end
		for _, key in ipairs({ "Color", "Transparency", "Rotation", "Offset" }) do
			hooks[#hooks + 1] = gradient:GetPropertyChangedSignal(key):Connect(refresh)
		end
		hooks[#hooks + 1] = gradient:GetAttributeChangedSignal("FigmaGradient"):Connect(refresh)
		hooks[#hooks + 1] = gradient:GetAttributeChangedSignal("FigmaFlowRainbow"):Connect(refresh)
		hooks[#hooks + 1] = gradient:GetAttributeChangedSignal("FigmaFlowPaletteFallback"):Connect(refresh)
	end
	for _, child in ipairs(template:GetChildren()) do watchGradient(child) end
	hooks[#hooks + 1] = template.ChildAdded:Connect(function(child) watchGradient(child); refresh() end)
	hooks[#hooks + 1] = template.ChildRemoved:Connect(refresh)
end
watchSurface = function(surface)
	if surfaceHooks[surface] then return end
	local hooks = { el = surfaceOwner(surface) }
	surfaceHooks[surface] = hooks
	local function refreshSurface()
		local previous = hooks.el
		hooks.el = surfaceOwner(surface)
		if previous then
			for _, owners in ipairs(ownerTables) do
				local state = owners[previous]
				if state and state.paintParent == surface and state.host then release(state.host) end
			end
			queueSync(previous)
		end
		if hooks.el then
			for _, child in ipairs(surface:GetChildren()) do
				if active(child, "FigmaFlowOverlay") then watchTemplate(child, hooks.el) end
			end
			queueSync(hooks.el)
		end
	end
	hooks[#hooks + 1] = surface:GetPropertyChangedSignal("Parent"):Connect(refreshSurface)
	hooks[#hooks + 1] = surface:GetAttributeChangedSignal("FigmaFlowSurface"):Connect(refreshSurface)
	hooks[#hooks + 1] = surface:GetAttributeChangedSignal("FigmaNodeId"):Connect(refreshSurface)
end
local function wire(el)
	if not el:IsA("GuiObject") or not inside(el) or el:GetAttribute("FW_FlowOverlay") == true then return end
	if surfaceOwner(el) then watchSurface(el); queueSync(surfaceOwner(el)); return end
	if active(el, "FigmaFlowOverlay") then
		local owner = templateOwner(el)
		if owner then watchTemplate(el, owner); queueSync(owner) end
		return
	end
	if not watched[el] then
		local hooks = {}
		watched[el] = hooks
		hooks[#hooks + 1] = el:GetAttributeChangedSignal("FigmaStroke"):Connect(function()
			if active(el, "FigmaStroke") then
				for host, m in pairs(moving) do if m.el == el and m.outline then release(host) end end
			end -- release synchronously, before Stroke's deferred attach snapshots its rest pose
			queueSync(el)
		end)
		hooks[#hooks + 1] = el:GetAttributeChangedSignal("FigmaFlow"):Connect(function()
			if not active(el, "FigmaFlow") then
				for host, m in pairs(moving) do if m.el == el then release(host) end end
			end
			queueSync(el)
		end)
		for _, key in ipairs({ "FlowOn", "FigmaFlowOn" }) do
			hooks[#hooks + 1] = el:GetAttributeChangedSignal(key):Connect(function() queueSync(el) end)
		end
		hooks[#hooks + 1] = el.Destroying:Connect(function()
			for host, m in pairs(moving) do if m.el == el then release(host) end end
			for _, hook in ipairs(hooks) do hook:Disconnect() end
			watched[el] = nil
		end)
	end
	if active(el, "FigmaFlow") then el:SetAttribute("FW_Flow", true) end
	sync(el)
end
local function added(d)
	if stopped then return end
	if d:IsA("GuiObject") then
		wire(d)
		if active(d, "FigmaFlowOverlay") then local owner = templateOwner(d); if owner then queueSync(owner) end end
	elseif d:IsA("UIStroke") and d.Parent then queueSync(d.Parent)
	elseif d:IsA("UIGradient") and d.Parent then
		local host = d.Parent
		local m = moving[host]
		if m and m.made and m.grad and m.grad ~= d then
			release(host) -- a supplied gradient replaces our temporary fallback
			queueSync(m.el)
		end
	end
end
for _, r in ipairs(roots) do
	for _, d in ipairs(r:GetDescendants()) do wire(d) end
	connections[#connections + 1] = r.DescendantAdded:Connect(added)
	connections[#connections + 1] = r.DescendantRemoving:Connect(function(d)
		if stopped then return end
		if d:IsA("GuiObject") then
			local surface = surfaceHooks[d]
			if surface then
				for _, owners in ipairs(ownerTables) do
					local state = surface.el and owners[surface.el]
					if state and state.paintParent == d and state.host then release(state.host, d) end
				end
				for _, hook in ipairs(surface) do hook:Disconnect() end
				surfaceHooks[d] = nil
				if surface.el then queueSync(surface.el) end
			end
			local hooks = templateHooks[d]
			if hooks then
				for _, owners in ipairs(ownerTables) do
					local state = owners[hooks.el]
					if state and state.template == d then
						state.template = nil
						if state.host then release(state.host) end
					end
				end
				for _, hook in ipairs(hooks) do hook:Disconnect() end
				templateHooks[d] = nil
				queueSync(hooks.el)
			end
			if moving[d] and moving[d].overlay then
				local el = moving[d].el
				release(d, d)
				queueSync(el)
			end
			for host, m in pairs(moving) do
				if m.el == d or m.el:IsDescendantOf(d) then release(host) end
			end
			for el, hooks in pairs(watched) do
				if el == d or el:IsDescendantOf(d) then
					for _, hook in ipairs(hooks) do hook:Disconnect() end
					watched[el] = nil
					overlayOwners[el], outlineOwners[el] = nil, nil
				end
			end
		elseif d:IsA("UIStroke") then release(d)
		elseif d:IsA("UIGradient") and d.Parent then
			local host = d.Parent
			local hooks = templateHooks[host]
			if hooks then hooks.refresh() end
			local m = moving[host]
			if m and m.grad == d then
				release(host, d) -- never destroy a gradient from inside its own Removing event
				queueSync(m.el)
			end
		end
	end)
end
local count = 0
for _ in pairs(moving) do count = count + 1 end
print(("[Framewisp] _flow: %d gradient(s) moving"):format(count))
connections[#connections + 1] = RunService.RenderStepped:Connect(function(dt)
	if stopped then return end
	for _, owners in ipairs(ownerTables) do
		for el, state in pairs(owners) do
			if not el.Parent or not inside(el) then
				if state.host then release(state.host) end
				owners[el] = nil
			else
				local on = math.floor(number(el, "FlowOn", 0, 0, 2) + 0.5)
				local parent = state.template and paintParent(el, state.template)
				local strokeOwn = state.outline and state.template ~= nil and active(state.template, "FigmaFlowStrokeOwn") and active(el, "FigmaStroke")
				local channel = state.outline and (strokeOwn or (on >= 1 and not active(el, "FigmaStroke"))) or (not state.outline and on ~= 1)
				local allowed = active(el, "FigmaFlow") and channel and parent ~= nil and visible(el) and visible(parent) and not reduced(el) and not reduced(parent)
				if state.allowed ~= allowed or state.paintParent ~= parent or state.strokeOwn ~= strokeOwn
					or (state.template and not active(state.template, "FigmaFlowOverlay")) then sync(el) end
			end
		end
	end
	for host, m in pairs(moving) do
		if not host.Parent or not inside(m.el) or not active(m.el, "FigmaFlow")
			or (m.nativeOutline and (host.Parent ~= m.el or active(m.el, "FigmaStroke")))
			or (m.overlay and m.outline and not m.strokeOwn and active(m.el, "FigmaStroke"))
			or (m.overlay and (host.Parent ~= m.paintParent or (host.Parent ~= m.el and surfaceOwner(host.Parent) ~= m.el))) then
			release(host)
			queueSync(m.el)
		elseif m.grad.Parent ~= host then
			release(host)
			queueSync(m.el)
		elseif visible(m.el) then
			paint(host, m, math.max(0, dt))
		end
	end
end)
script.Destroying:Connect(function()
	stopped = true
	for _, connection in ipairs(connections) do connection:Disconnect() end
	for host in pairs(moving) do release(host) end
	for _, hooks in pairs(watched) do for _, hook in ipairs(hooks) do hook:Disconnect() end end
	table.clear(watched)
	for _, hooks in pairs(templateHooks) do for _, hook in ipairs(hooks) do hook:Disconnect() end end
	for _, hooks in pairs(surfaceHooks) do for _, hook in ipairs(hooks) do hook:Disconnect() end end
	table.clear(templateHooks)
	table.clear(surfaceHooks)
	table.clear(overlayOwners)
	table.clear(outlineOwners)
end)
