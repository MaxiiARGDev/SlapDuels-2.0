-- Framewisp: juice — idle motion (_pulse/_wiggle/_shake/_jelly/_glow/_rays/_pixels)
-- and entrances (_pop/_cascade/_reveal/_swing/_drop). Every number comes from the
-- plugin; a Studio attribute without the Figma prefix wins (DropHeight, DropTime,
-- DropBounce, DropSquash, DropFade, DropDelay, DropKids, DropStep, DropSound).
-- Safe to delete: everything just holds still.
local RunService = game:GetService("RunService")
do
	local okv, v = pcall(function() return script:GetAttribute("FWv") end)
	print("[Framewisp] Juice v" .. tostring(okv and v or "?") .. " in " .. script.Parent.Name)
end
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
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

local function attr(el, name, def)
	local v = el:GetAttribute(name)
	if v == nil then v = el:GetAttribute("Figma" .. name) end
	if type(v) ~= "number" then return def end
	return v
end
local function pxScale() -- design px -> rendered px, the same factor _float and _up use
	local root = gui:FindFirstChildWhichIsA("GuiObject")
	if not root then -- a billboard design lives one level deeper, or hangs off FW_ExtraRoot
		for _, v in ipairs(gui:GetChildren()) do
			if v:IsA("BillboardGui") then -- clickable _billboard: kept inside this ScreenGui
				root = v:FindFirstChildWhichIsA("GuiObject")
				break
			end
			if v:IsA("ObjectValue") and v.Name == "FW_ExtraRoot" and v.Value then
				root = v.Value:FindFirstChildWhichIsA("GuiObject")
				break
			end
		end
	end
	local designH = gui:GetAttribute("BB_DesignH")
	if root and type(designH) == "number" and designH > 0 and root.AbsoluteSize.Y > 1 then
		return root.AbsoluteSize.Y / designH
	end
	return 1
end
local function slotFor(el, force) -- also the host for juice scaling: Roblox honours one UIScale per object
	local p = el.Parent
	if not p then return end
	local laid = p:FindFirstChildWhichIsA("UIGridLayout") or p:FindFirstChildWhichIsA("UIListLayout")
		or p:FindFirstChildWhichIsA("UITableLayout") or p:FindFirstChildWhichIsA("UIPageLayout")
	if not laid and not force then return end
	if p:GetAttribute("FW_JuiceSlot") then return end
	local slot = Instance.new("Frame")
	slot.Name = el.Name .. "_JSlot"
	slot.BackgroundTransparency = 1
	slot.Size = el.Size
	slot.Position = el.Position -- the wrapper must stand exactly where the layer stood
	slot.AnchorPoint = el.AnchorPoint
	slot.ZIndex = el.ZIndex
	slot.LayoutOrder = el.LayoutOrder
	slot:SetAttribute("FW_Owned", true)
	slot:SetAttribute("FW_JuiceSlot", true)
	slot.Parent = p
	el.Size = UDim2.fromScale(1, 1)
	el.Position = UDim2.fromScale(0.5, 0.5)
	el.AnchorPoint = Vector2.new(0.5, 0.5)
	el.Parent = slot
	return slot
end

local function scaleOf(el)
	return fwChannel(el, "k_juice") -- a channel, never the UIScale itself
end

local function shown(el) -- visible TO THE PLAYER: every ancestor counts, not just this layer
	local n = el
	while n and not n:IsA("LayerCollector") do
		if n:IsA("GuiObject") and not n.Visible then return false end
		n = n.Parent
	end
	return n ~= nil
end
local function onShown(el, fn)
	local was = shown(el)
	if was then fn() end
	local n = el
	while n and not n:IsA("LayerCollector") do
		if n:IsA("GuiObject") then
			n:GetPropertyChangedSignal("Visible"):Connect(function()
				local now = shown(el)
				if now and not was then fn() end
				was = now
			end)
		end
		n = n.Parent
	end
end

local idle = {}
local function popIn(el)
	local sc = fwChannel(el, "k_pop") -- its own channel: the idle tick owns k_juice
	local from = attr(el, "PopFrom", 0.8)
	sc.Value = from
	TweenService:Create(sc, TweenInfo.new(attr(el, "PopTime", 0.3), Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 1 }):Play()
end
local function wirePop(el)
	if el:GetAttribute("FW_Pop") then return end
	el:SetAttribute("FW_Pop", true)
	onShown(el, function() popIn(el) end)
end
local function cascadeIn(el)
	local gap = attr(el, "CascadeGap", 70) / 1000
	local i = 0
	local function cardish(c) -- a card is something you CLICK, not decoration that animates
		return c:IsA("GuiButton") or c:GetAttribute("FigmaAction") ~= nil
	end
	local kids, actors = {}, {}
	local function sweep(host, depth)
		for _, c in ipairs(host:GetChildren()) do
			if c:IsA("GuiObject") and c:GetAttribute("FW_Owned") ~= false then
				if depth == 0 then kids[#kids + 1] = c end
				if cardish(c) then
					actors[#actors + 1] = c
				elseif depth < 3 then
					sweep(c, depth + 1) -- a plain container is not a card: look inside it
				end
			end
		end
	end
	sweep(el, 0)
	if #actors > 1 then kids = actors end -- the preview staggers the CARDS, not the plate
	if #kids == 0 then -- fully baked: nothing to stagger, so at least make it arrive
		popIn(el)
		return
	end
	if #kids == 1 and #kids[1]:GetChildren() > 1 then
		local n = kids[1].Name
		if n:sub(-7) == "Content" or n:sub(-4) == "Mask" or n:sub(-6) == "Masked" then
			return cascadeIn(kids[1])
		end
	end
	local laid = false -- design order, like the preview; a layout's own order still wins
	for _, c in ipairs(kids) do
		if c.LayoutOrder ~= 0 then laid = true break end
	end
	if laid then
		table.sort(kids, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	end
	for _, c in ipairs(kids) do
		local sc = fwChannel(c, "k_pop")
		sc.Value = 0.001
		task.delay(i * gap, function()
			if c.Parent then
				TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Value = 1 }):Play()
			end
		end)
		i += 1
	end
end
local function wireCascade(el)
	if el:GetAttribute("FW_Cascade") then return end
	el:SetAttribute("FW_Cascade", true)
	onShown(el, function() cascadeIn(el) end)
end
local function wireGlow(el)
	if el:GetAttribute("FW_Glow") then return end
	el:SetAttribute("FW_Glow", true)
	local host = el
	local sw = attr(el, "GlowSW", 1)
	local sh = attr(el, "GlowSH", 1)
	local rot = attr(el, "GlowRot", 0)
	if sw < 0.999 or sw > 1.001 or sh < 0.999 or sh > 1.001 or math.abs(rot) > 0.05 then
		local ring = Instance.new("Frame")
		ring.Name = "FW_GlowRing"
		ring.BackgroundTransparency = 1
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.Size = UDim2.fromScale(sw, sh)
		ring.Rotation = rot
		ring:SetAttribute("FW_Owned", true)
		local rad = attr(el, "GlowRad", 0)
		if rad > 0 then
			local uc = Instance.new("UICorner")
			uc.CornerRadius = UDim.new(rad, 0)
			uc.Parent = ring
		end
		ring.Parent = el
		host = ring
	end
	local stroke = host:FindFirstChildWhichIsA("UIStroke")
	if stroke and stroke:GetAttribute("FW_Owned") ~= true then stroke = nil end -- the DESIGNED border is sacred
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border -- on text, Contextual outlines the GLYPHS
		stroke:SetAttribute("FW_Owned", true)
		local c = attr(el, "GlowColor", 16777215)
		stroke.Color = Color3.fromRGB(math.floor(c / 65536) % 256, math.floor(c / 256) % 256, c % 256)
		stroke.Thickness = 0
		stroke.Parent = host
	end
	idle[#idle + 1] = { kind = "glow", el = el, stroke = stroke, base = stroke.Thickness,
		frac = stroke:GetAttribute("FW_StrokeScaled") == true, t = math.random() * 7 }
end
local function wirePixels(el)
	if el:GetAttribute("FW_Pixels") then return end
	el:SetAttribute("FW_Pixels", true)
	local wrap = Instance.new("Frame")
	wrap.Name = "FW_PixelHost"
	wrap.BackgroundTransparency = 1
	wrap.Size = UDim2.fromScale(1, 1)
	wrap.ClipsDescendants = true
	wrap:SetAttribute("FW_Owned", true)
	local corner = el:FindFirstChildWhichIsA("UICorner")
	if corner then corner:Clone().Parent = wrap end
	local top = el.ZIndex
	for _, d in ipairs(el:GetChildren()) do
		if d:IsA("GuiObject") and d.ZIndex > top then top = d.ZIndex end
	end
	wrap.ZIndex = top + 1 -- the preview draws the mosaic OVER the layer's contents
	wrap.Parent = el
	local c = attr(el, "PixColor", 16777215)
	local col = Color3.fromRGB(math.floor(c / 65536) % 256, math.floor(c / 256) % 256, c % 256)
	local alpha = attr(el, "PixAlpha", 0.35)
	for _ = 1, 240 do -- a grid cut before the layout exists collapses to one cell
		if el.AbsoluteSize.X > 2 and el.AbsoluteSize.Y > 2 then break end
		task.wait()
		if not el.Parent then return end
	end
	local w, h = el.AbsoluteSize.X, el.AbsoluteSize.Y
	local cellPx = math.max(1, attr(el, "PixCell", 14)) * pxScale() -- a DESIGN size, like every other
	local k = math.max(1, math.ceil(math.sqrt((math.ceil(w / cellPx) * math.ceil(h / cellPx)) / 1600))) -- same cap as the preview
	local cw = cellPx * k
	local cells = {}
	local sx, sy = cw / math.max(1, w), cw / math.max(1, h) -- square in RENDERED px, and scales with the box
	local y = 0
	while y < h do
		local x = 0
		while x < w do
			local f = Instance.new("Frame")
			f.BorderSizePixel = 0
			f.BackgroundColor3 = col
			f.BackgroundTransparency = 1
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Size = UDim2.fromScale(sx, sy)
			f.Position = UDim2.fromScale((x + cw / 2) / w, (y + cw / 2) / h)
			f.ZIndex = wrap.ZIndex
			f.Parent = wrap
			cells[#cells + 1] = f
			x = x + cw
		end
		y = y + cw
	end
	idle[#idle + 1] = { kind = "pixels", el = el, t = 0, cells = cells, acc = 0, rate = attr(el, "PixRate", 8), alpha = alpha,
		vary = attr(el, "PixVary", 0) >= 0.5, cw = sx, ch = sy }
end

local function wireReveal(el)
	if el:GetAttribute("FW_Reveal") then return end
	el:SetAttribute("FW_Reveal", true)
	slotFor(el, true)
	local size0, pos0 = el.Size, el.Position -- restore THESE, never an assumed 1x1 at centre
	local function play()
		idle[#idle + 1] = {
			kind = "reveal", el = el, t = 0, size0 = size0, pos0 = pos0,
			T = math.max(0.02, attr(el, "RevealTime", 0.7)),
			A = math.rad(attr(el, "RevealAngle", 35)),
			dir = math.rad(attr(el, "RevealDir", 0)),
			from = attr(el, "RevealFrom", 0.55),
		}
	end
	onShown(el, play)
end

local function gleamSeq(w, peak) -- the preview's core: shoulders at 30/70% of the band
	local h = math.clamp(w * 0.5, 0.04, 0.46) -- w is the FULL band, as in the preview
	if peak then
		return NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5 - h, 1),
			NumberSequenceKeypoint.new(0.5, peak),
			NumberSequenceKeypoint.new(0.5 + h, 1),
			NumberSequenceKeypoint.new(1, 1),
		})
	end
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5 - h, 1),
		NumberSequenceKeypoint.new(0.5 - h * 0.4, 0.45),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(0.5 + h * 0.4, 0.45),
		NumberSequenceKeypoint.new(0.5 + h, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
end
local GLEAM_TILT = -14 -- the preview skews the beam by the same angle
local function textSpill(x) -- the text scaler's k_text on x and every layer above it
	local sp = 1
	while x and x ~= gui do
		local h = x:FindFirstChild("FW_Scale")
		local c = h and h:FindFirstChild("k_text")
		if c and c.Value > 0 then sp = sp * c.Value end
		x = x.Parent
	end
	return sp
end
local GLEAM_TAN = 0.25 -- tan(14 deg): below this aspect the tilt eats the sweep
local function gleamShine(el, w)
	local grads = {}
	local box = el.AbsoluteSize -- a tilt on a wide, short layer collapses the sweep axis
	local tilt = (box.Y >= box.X * GLEAM_TAN) and GLEAM_TILT or 0
	local function band(host, width, peak)
		local g = Instance.new("UIGradient")
		g.Transparency = gleamSeq(width, peak)
		g.Rotation = tilt
		g.Offset = Vector2.new(-2, 0)
		g:SetAttribute("FW_Owned", true)
		g.Parent = host
		grads[#grads + 1] = g
	end
	local function whiteCopy(z)
		local ov
		if el:IsA("TextLabel") or el:IsA("TextButton") then
			ov = Instance.new("TextLabel")
			ov.Text = el.Text
			ov.RichText = el.RichText
			ov.FontFace = el.FontFace
			ov.TextScaled = el.TextScaled
			ov.TextSize = el.TextSize
			ov.TextWrapped = el.TextWrapped
			ov.LineHeight = el.LineHeight
			ov.TextXAlignment = el.TextXAlignment
			ov.TextYAlignment = el.TextYAlignment
			ov.TextColor3 = Color3.new(1, 1, 1)
			ov.TextStrokeTransparency = 1
		elseif el:IsA("ImageLabel") or el:IsA("ImageButton") then
			ov = Instance.new("ImageLabel")
			local sheen = el:FindFirstChild(el.Name .. "_Sheen") -- the white silhouette the plugin exported for this picture
			if sheen and sheen:IsA("ImageLabel") and sheen.Image ~= "" then
				ov.Image = sheen.Image
			else
				ov.Image = el.Image -- tinted white this IS the picture again: the sweep cannot show (older export)
				if not el:GetAttribute("FW_GleamNoSheen") then
					el:SetAttribute("FW_GleamNoSheen", true)
					warn("[Framewisp] _gleam: '" .. el.Name .. "' is a picture without its white silhouette, so the sweep has nothing to paint. Re-export with the current Framewisp plugin.")
				end
			end
			ov.ImageColor3 = Color3.new(1, 1, 1)
			ov.ScaleType = el.ScaleType
			ov.SliceCenter = el.SliceCenter
			ov.SliceScale = el.SliceScale
			ov.TileSize = el.TileSize
			ov.ImageRectOffset = el.ImageRectOffset
			ov.ImageRectSize = el.ImageRectSize
		else
			ov = Instance.new("Frame") -- a layer kept native is a plain Frame: it gets a sheen too
			ov.BackgroundColor3 = Color3.new(1, 1, 1)
		end
		ov.Name = "FW_GleamShine"
		ov.Visible = false -- shown ONLY while the light travels: no ghost copy at rest
		if not ov:IsA("Frame") then ov.BackgroundTransparency = 1 end
		ov.Size = UDim2.fromScale(1, 1)
		ov.Position = UDim2.fromScale(0.5, 0.5)
		ov.AnchorPoint = Vector2.new(0.5, 0.5)
		ov.ZIndex = el.ZIndex + z
		ov:SetAttribute("FW_Owned", true)
		local corner = el:FindFirstChildWhichIsA("UICorner")
		if corner then corner:Clone().Parent = ov end
		local bb = el:FindFirstChild("FW_BBText") -- a billboard's constraint rides along, or the copy fits differently
		if bb then bb:Clone().Parent = ov end -- no FigmaFontSize: the copy sits inside its label's spill and follows its TextSize
		ov.Parent = el
		return ov
	end
	local st = el:FindFirstChildWhichIsA("UIStroke")
	local function whiteStroke(host, extra)
		local c = st and st:Clone() or Instance.new("UIStroke")
		for _, k in ipairs(c:GetChildren()) do k:Destroy() end -- a stroke gradient measures in STROKE space, so it desyncs
		c.Color = Color3.new(1, 1, 1)
		pcall(function() c.BorderStrokePosition = Enum.BorderStrokePosition.Outer end)
		if host:IsA("TextLabel") or host:IsA("TextButton") then
			c.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual -- a cloned Border-mode stroke drew a white BOX around each letter
		end
		if st and st:GetAttribute("FW_StrokeScaled") then
			c.Thickness = st.Thickness * (extra > 0 and 1.7 or 1) -- a fraction, so widen by ratio
		else
			c.Thickness = (st and st.Thickness or 0) + extra / textSpill(el) -- the copy draws inside the label's text spill: the extra stays screen px
			if extra > 0 then c:SetAttribute("FW_StrokeExtra", extra) end -- the text scaler keeps the halo this much wider on every resize
			c:SetAttribute("FW_StrokeMine", c.Thickness) -- written by us, not a hand edit the scaler must leave alone
		end
		c:SetAttribute("FW_Owned", true)
		c.Parent = host
	end
	local isText = el:IsA("TextLabel") or el:IsA("TextButton") -- a stroke on an image outlines its rectangle, not glyphs
	local halo = whiteCopy(1) -- wide and soft: Roblox has no blur, a fatter outline stands in
	if halo then
		if isText then whiteStroke(halo, 3) end
		band(halo, w * 1.6, 0.4)
	end
	local core = whiteCopy(2)
	if not core then return grads end
	if st and isText then whiteStroke(core, 0) end -- the layer's gradient already covers its stroke
	band(core, w)
	return grads
end
local function wireGleam(el)
	if el:GetAttribute("FW_Gleam") then return end
	el:SetAttribute("FW_Gleam", true)
	local w = attr(el, "GleamWidth", 0.22)
	if not (el:IsA("TextLabel") or el:IsA("TextButton") or el:IsA("ImageLabel") or el:IsA("ImageButton")) then
		idle[#idle + 1] = { kind = "gleamG", el = el, t = 0, parts = nil, waited = 0 } -- collected on first tick: a group wires before its letters exist
		return
	end
	idle[#idle + 1] = { kind = "gleam", el = el, t = 0, w = w, grads = gleamShine(el, w) }
end
local function wireSwing(el)
	if el:GetAttribute("FW_Swing") then return end
	el:SetAttribute("FW_Swing", true)
	slotFor(el, true)
	local size0, pos0 = el.Size, el.Position -- restore THESE, never an assumed 1x1 at centre
	local parent0 = el.Parent
	local function playSwing()
		if parent0 ~= el.Parent then -- replay after the 3D host changed coordinate spaces
			parent0, size0, pos0 = el.Parent, el.Size, el.Position
		end
		if not el:GetAttribute("FW_3DHosted") then
			el:SetAttribute("FW_EntrSize0", size0)
			el:SetAttribute("FW_EntrPos0", pos0)
		end
		idle[#idle + 1] = {
			kind = "swing", el = el, t = 0, size0 = size0, pos0 = pos0, par = el.Parent,
			T = math.max(0.02, attr(el, "SwingTime", 1.2)),
			A = attr(el, "SwingAngle", 20),
			n = attr(el, "SwingCount", 4),
			from = attr(el, "SwingFrom", 0.5),
		}
	end
	onShown(el, playSwing)
end

local SoundService = game:GetService("SoundService")
local DROP_FADE = {
	ImageLabel = { "ImageTransparency", "BackgroundTransparency" },
	ImageButton = { "ImageTransparency", "BackgroundTransparency" },
	TextLabel = { "TextTransparency", "BackgroundTransparency", "TextStrokeTransparency" },
	TextButton = { "TextTransparency", "BackgroundTransparency", "TextStrokeTransparency" },
	TextBox = { "TextTransparency", "BackgroundTransparency" },
	Frame = { "BackgroundTransparency" },
	ScrollingFrame = { "BackgroundTransparency" },
	CanvasGroup = { "GroupTransparency" },
	UIStroke = { "Transparency" },
}
local function dropParts(root) -- read ONCE: a replay mid-fade must not take a faded value for the rest
	local parts = {}
	local function add(inst)
		for _, prop in ipairs(DROP_FADE[inst.ClassName] or {}) do
			local ok, rest = pcall(function() return inst[prop] end)
			if ok and type(rest) == "number" then parts[#parts + 1] = { inst = inst, prop = prop, rest = rest } end
		end
	end
	add(root)
	local function under(inst) -- an arrow or a card shows and hides itself: never faded from here
		for _, c in ipairs(inst:GetChildren()) do
			if not (c:GetAttribute("FigmaPointer") or c:GetAttribute("FigmaCard")) then add(c); under(c) end
		end
	end
	under(root)
	return parts
end
local function dropAlpha(parts, a)
	for _, part in ipairs(parts) do
		if part.inst.Parent then pcall(function() part.inst[part.prop] = part.rest + (1 - part.rest) * (1 - a) end) end
	end
end
local function dropPose(e, kx, ky, dy) -- the layer's own box in its slot, scaled, lifted by dy slot heights
	local sz, po = e.size0, e.pos0
	e.el.Size = UDim2.new(sz.X.Scale * kx, sz.X.Offset * kx, sz.Y.Scale * ky, sz.Y.Offset * ky)
	e.el.Position = UDim2.new(po.X.Scale, po.X.Offset, po.Y.Scale + dy, po.Y.Offset)
end
local function dropAt(t, H, T, b, s, fade) -- the preview's dropAt, number for number: y px (up is negative), sx, sy, alpha
	local Tf = 0.55 * T
	local Tb = math.max(0.1, T - Tf - 0.08)
	if t < 0 then return -H, 1, 1, fade and 0 or 1 end
	local y, q = 0, 0
	if t < Tf then
		local p = t / Tf
		y = -H * (1 - p * p) -- speeds up like a weight
	elseif t < Tf + 0.08 then
		q = math.sin((t - Tf) / 0.08 * math.pi / 2) -- squashes where it lands
	else
		local r = t - Tf - 0.08
		y = -H * b * math.sin(math.pi * math.min(1, r / Tb)) -- one soft bounce
		local x = math.min(1, r / 0.2)
		q = 1 - (1 + 3.2 * (x - 1) ^ 3 + 2.2 * (x - 1) ^ 2) -- back out: a small stretch, then rest
	end
	return y, 1 + 0.6 * s * q, 1 - s * q, fade and math.min(1, t / (0.3 * Tf)) or 1
end
local function dropLen(T)
	local Tf = 0.55 * T
	return Tf + 0.08 + math.max(math.max(0.1, T - Tf - 0.08), 0.2)
end
local function dropTargets(el) -- the layer itself, or its children in reading order (their shadows ride along)
	if attr(el, "DropKids", 0) < 0.5 then return { { el } } end
	local kids, byName = {}, {}
	for _, c in ipairs(el:GetChildren()) do
		if c:IsA("GuiObject") and c.Visible and c.Name ~= "Background" and c.Name ~= "TextureClip" then
			kids[#kids + 1] = c
			byName[c.Name] = c
		end
	end
	local laid = el:FindFirstChildWhichIsA("UIListLayout") or el:FindFirstChildWhichIsA("UIGridLayout")
	local main, shadows = {}, {}
	for i, c in ipairs(kids) do
		local base = c.Name:sub(-6) == "Shadow" and byName[c.Name:sub(1, -7)] or nil
		if base and base ~= c then
			shadows[base] = shadows[base] or {}
			table.insert(shadows[base], c)
		else
			main[#main + 1] = { c = c, i = i }
		end
	end
	local measured = el.AbsoluteSize.Y > 1
	local function at(c, axis)
		if measured then return c.AbsolutePosition[axis] end
		return c.Position[axis].Scale * 1e4 + c.Position[axis].Offset
	end
	table.sort(main, function(a, b)
		if laid then
			if a.c.LayoutOrder ~= b.c.LayoutOrder then return a.c.LayoutOrder < b.c.LayoutOrder end
			return a.i < b.i
		end
		local ay, by = at(a.c, "Y"), at(b.c, "Y")
		if math.abs(ay - by) > 1 then return ay < by end -- reading order: top to bottom, then left to right
		local ax, bx = at(a.c, "X"), at(b.c, "X")
		if ax ~= bx then return ax < bx end
		return a.i < b.i
	end)
	local out = {}
	for _, m in ipairs(main) do
		local group = { m.c }
		for _, sh in ipairs(shadows[m.c] or {}) do group[#group + 1] = sh end
		out[#out + 1] = group
	end
	if #out == 0 then return { { el } } end -- baked flat: nothing inside to stagger, so the layer falls whole
	return out
end
local function wireDrop(el)
	if el:GetAttribute("FW_Drop") then return end
	el:SetAttribute("FW_Drop", true)
	local groups = nil
	local live = {}
	local function dropPlay()
		groups = groups or dropTargets(el)
		local step = attr(el, "DropKids", 0) >= 0.5 and attr(el, "DropStep", 0.06) or 0
		local delay = attr(el, "DropDelay", 0)
		for i, group in ipairs(groups) do
			for gi, target in ipairs(group) do
				local e = live[target]
				if not e then
					slotFor(target, true)
					e = { kind = "drop", el = target, src = el, size0 = target.Size, pos0 = target.Position, par = target.Parent,
						parts = dropParts(target), voice = (i == 1 and gi == 1) }
					live[target] = e
				end
				e.t = -(delay + (i - 1) * step)
				e.landed = false
				if not e.on then
					e.on = true
					idle[#idle + 1] = e
				end
				local slotH = target.Parent and target.Parent:IsA("GuiObject") and target.Parent.AbsoluteSize.Y or 0
				if slotH >= 1 and not target:GetAttribute("FW_3DHosted") then -- the first pose now: no frame shows it at rest
					dropPose(e, 1, 1, -attr(el, "DropHeight", 160) * pxScale() / slotH)
				end
				if attr(el, "DropFade", 1) >= 0.5 then dropAlpha(e.parts, 0) end
			end
		end
	end
	onShown(el, dropPlay)
end

local function wire(el)
	if not el:IsA("GuiObject") then return end
	if el:GetAttribute("FigmaTimeline") ~= nil then return end -- the timeline owns this layer
	local function try(fn, ...) -- one tag must never take the rest of the UI down
		local ok, err = pcall(fn, ...)
		if not ok then warn("[Framewisp] " .. el:GetFullName() .. ": " .. tostring(err)) end
	end
	if el:GetAttribute("FigmaGleam") then try(wireGleam, el) end
	if el:GetAttribute("FigmaSwing") then try(wireSwing, el) end
	if el:GetAttribute("FigmaReveal") then try(wireReveal, el) end
	if el:GetAttribute("FigmaDrop") then try(wireDrop, el) -- _drop plays the entrance: a _pop beside it would fight it
	elseif el:GetAttribute("FigmaPop") then try(wirePop, el) end
	if el:GetAttribute("FigmaCascade") then try(wireCascade, el) end
	if el:GetAttribute("FigmaGlow") then try(wireGlow, el) end
	if el:GetAttribute("FigmaPixels") then task.spawn(try, wirePixels, el) end -- waits for a real box
	local function once(name) -- reparenting into a slot re-fires DescendantAdded
		if el:GetAttribute(name) then return false end
		el:SetAttribute(name, true)
		return true
	end
	if el:GetAttribute("FigmaPulse") and once("FW_Pulse") then
		idle[#idle + 1] = { kind = "pulse", el = el, sc = scaleOf(el), t = math.random() * 7 }
	end
	if el:GetAttribute("FigmaJelly") and once("FW_Jelly") then
		idle[#idle + 1] = { kind = "jelly", el = el, sc = scaleOf(el), base = el.Rotation, t = math.random() * 7 }
	end
	if el:GetAttribute("FigmaWiggle") and once("FW_Wiggle") then
		idle[#idle + 1] = { kind = "wiggle", el = el, base = el.Rotation, t = 0 }
	end
	if el:GetAttribute("FigmaRays") and once("FW_Rays") then
		idle[#idle + 1] = { kind = "rays", el = el, sc = scaleOf(el), base = el.Rotation, t = math.random() * 7 }
	end
	if el:GetAttribute("FigmaShake") and once("FW_Shake") then
		slotFor(el)
		idle[#idle + 1] = { kind = "shake", el = el, base = nil, t = 0 }
	end
end
for _, d in ipairs(fwAll()) do wire(d) end
for _, r in ipairs(fwRoots()) do r.DescendantAdded:Connect(wire) end

local function posed(e, kx, ky, dx, dy) -- the layer's own box, scaled and nudged
	local sz, po = e.size0, e.pos0
	e.el.Size = UDim2.new(sz.X.Scale * kx, sz.X.Offset * kx, sz.Y.Scale * ky, sz.Y.Offset * ky)
	e.el.Position = UDim2.new(po.X.Scale + dx, po.X.Offset, po.Y.Scale + dy, po.Y.Offset)
end
local scaleAcc, rotAcc, rotBase = {}, {}, {}
local function tickIdle(dt)
	local dead = nil
	table.clear(scaleAcc)
	table.clear(rotAcc)
	table.clear(rotBase)
	for i, e in ipairs(idle) do
		if e.el.Parent then
			e.t = e.t + dt
			if e.size0 and e.par ~= e.el.Parent then
				e.par = e.el.Parent -- a slot re-hosted it with canonical FULL-size coords; dividing the entrance out again doubled the card
				e.size0 = e.el.Size
				e.pos0 = e.el.Position
			end
			if e.kind == "swing" then
				local p = math.min(1, e.t / e.T)
				if p >= 1 then
					posed(e, 1, 1, 0, 0)
					if e.el:GetAttribute("FW_SwingPitch") then e.el:SetAttribute("FW_SwingPitch", 0) end
					e.el:SetAttribute("FW_HostScale", nil)
					e.el:SetAttribute("FW_EntrK", nil)
					e.el:SetAttribute("FW_EntrSize0", nil)
					e.el:SetAttribute("FW_EntrPos0", nil)
					dead = dead or {}
					dead[#dead + 1] = i
				else
					local deg = e.A * math.exp(-4 * p) * math.cos(p * math.pi * 2 * e.n)
					local th = math.rad(deg)
					local rise = math.min(1, e.t / (e.T * 0.3))
					local c = 2.2
					local sc = e.from + (1 - e.from) * (1 + (c + 1) * (rise - 1) ^ 3 + c * (rise - 1) ^ 2)
					if e.el:GetAttribute("FW_3DHosted") then -- real depth: scale the WORLD QUAD, never the card's box
						e.el:SetAttribute("FW_SwingPitch", deg)
						e.el:SetAttribute("FW_HostScale", sc)
						posed(e, 1, 1, 0, 0) -- the flat frames before hosting left the box shrunken; hold it at full or the finish SNAPS
					else
						e.el:SetAttribute("FW_EntrSize0", e.size0)
						e.el:SetAttribute("FW_EntrPos0", e.pos0)
						e.el:SetAttribute("FW_EntrK", sc) -- the 3D slot reads this if it adopts the card mid-entrance
						posed(e, sc, sc * math.abs(math.cos(th)), 0, -math.sin(th) * 0.09)
					end
				end
			elseif e.kind == "drop" then
				local src = e.src
				local T = math.max(0.1, attr(src, "DropTime", 0.6))
				local y, sx, sy, o = dropAt(e.t, attr(src, "DropHeight", 160) * pxScale(), T,
					attr(src, "DropBounce", 12) / 100, attr(src, "DropSquash", 10) / 100, attr(src, "DropFade", 1) >= 0.5)
				local slot = e.el.Parent
				local slotH = slot and slot:IsA("GuiObject") and slot.AbsoluteSize.Y or 0
				if e.el:GetAttribute("FW_3DHosted") or slotH < 1 then
					dropPose(e, 1, 1, 0) -- a card in the world only fades: its quad follows the slot, not this box
				else
					dropPose(e, sx, sy, y / slotH + (1 - sy) / 2) -- the bottom edge stays put while it squashes
				end
				dropAlpha(e.parts, o)
				if not e.landed and e.t >= 0.55 * T then
					e.landed = true
					local id = attr(src, "DropSound", 0)
					if id > 0 and e.voice then -- one landing sound per drop, not one per child
						local snd = src:FindFirstChild("FW_DropSound")
						if not snd then
							snd = Instance.new("Sound")
							snd.Name = "FW_DropSound"
							snd:SetAttribute("FW_Owned", true)
							snd.Parent = src
						end
						snd.SoundId = "rbxassetid://" .. string.format("%d", id)
						pcall(function() SoundService:PlayLocalSound(snd) end)
					end
				end
				if e.t >= dropLen(T) then
					dropPose(e, 1, 1, 0)
					dropAlpha(e.parts, 1)
					e.on = false
					dead = dead or {}
					dead[#dead + 1] = i
				end
			elseif e.kind == "reveal" then
				local p = math.min(1, e.t / e.T)
				if p >= 1 then
					posed(e, 1, 1, 0, 0)
					dead = dead or {}
					dead[#dead + 1] = i
				else
					local th = e.A * math.exp(-5 * p) * math.cos(p * math.pi * 5)
					local rise = math.min(1, e.t / (e.T * 0.45))
					local c = 2.2
					local sc = e.from + (1 - e.from) * (1 + (c + 1) * (rise - 1) ^ 3 + c * (rise - 1) ^ 2)
					local fore = 1 - math.cos(th)
					local drift = math.sin(th) * 0.07
					posed(e, sc * (1 - fore * math.abs(math.sin(e.dir))), sc * (1 - fore * math.abs(math.cos(e.dir))),
						math.sin(e.dir) * drift, -math.cos(e.dir) * drift)
				end
			elseif e.kind == "pulse" then
				local sp = attr(e.el, "PulseSpeed", 1)
				local w = (1 - math.cos(e.t * math.pi * 2 * sp)) * 0.5 -- even speed: a flattened peak held its last pixel step
				local amp = attr(e.el, "PulseAmp", 5) / 100
				if e.el:GetAttribute("FW_3DHosted") then
					e.el:SetAttribute("FW_HostScale", 1 + amp * w) -- scaled as a 3D quad: no pixel grid
				else
					local px = math.min(e.el.AbsoluteSize.X, e.el.AbsoluteSize.Y) -- UI lays out on WHOLE pixels
					if px > 1 and amp * px < 10 then amp = math.min(amp * 4, 10 / px) end -- more travel = more steps
					scaleAcc[e.sc] = (scaleAcc[e.sc] or 1) * (1 + amp * w)
				end
			elseif e.kind == "jelly" then
				local sp = attr(e.el, "JellySpeed", 1.2)
				rotBase[e.el] = e.base
				rotAcc[e.el] = (rotAcc[e.el] or 0) + math.sin(e.t * math.pi * 2 * sp) * attr(e.el, "JellyAmp", 3)
				scaleAcc[e.sc] = (scaleAcc[e.sc] or 1) * (1 + 0.01 * math.sin(e.t * math.pi * 4 * sp + 1))
			elseif e.kind == "wiggle" then
				local every = attr(e.el, "WiggleEvery", 4)
				local tt = e.t % (every + 0.7)
				rotBase[e.el] = e.base
				rotAcc[e.el] = rotAcc[e.el] or 0
				if tt < 0.7 then
					local p = tt / 0.7
					rotAcc[e.el] = rotAcc[e.el] + math.sin(p * math.pi * 6) * attr(e.el, "WiggleAngle", 12) * (1 - p)
				end
			elseif e.kind == "rays" then
				e.ang = (e.ang or 0) + attr(e.el, "RaysSpeed", 25) * dt
				rotBase[e.el] = e.base or 0
				rotAcc[e.el] = (rotAcc[e.el] or 0) + e.ang
				scaleAcc[e.sc] = (scaleAcc[e.sc] or 1) * (1 + attr(e.el, "RaysPulse", 6) / 100 * (0.5 + 0.5 * math.sin(e.t * 2)))
			elseif e.kind == "shake" then
				local every = attr(e.el, "ShakeEvery", 3)
				local dur = attr(e.el, "ShakeTime", 0.5)
				local tt = e.t % (every + dur)
				if e.base == nil then e.base = e.el.Position end
				if tt < dur then
					local p = tt / dur
					local amp = attr(e.el, "ShakeAmp", 6) * (1 - p)
					e.el.Position = e.base + UDim2.fromOffset(math.sin(e.t * 53) * amp, math.cos(e.t * 47) * amp)
				else
					e.el.Position = e.base
				end
			elseif e.kind == "glow" then
				local sp = attr(e.el, "GlowSpeed", 0.8)
				local size = attr(e.el, "GlowSize", 12)
				local breathe = 0.5 + 0.5 * math.sin(e.t * math.pi * 2 * sp)
				if e.frac then -- a ScaledSize stroke is a FRACTION: pixels here meant 150-600%
					local short = math.max(1, math.min(e.el.AbsoluteSize.X, e.el.AbsoluteSize.Y))
					e.stroke.Thickness = e.base + (size * 0.5 * breathe) / short
				else
					e.stroke.Thickness = math.max(e.base + size * 0.5 * breathe, 1.5) -- same 0.5 factor as the demo ring
				end
				e.stroke.Transparency = 0.15 -- the preview's ring holds its density; only SIZE breathes
			elseif e.kind == "gleam" then
				local dur = attr(e.el, "GleamSpeed", 0.8)
				local cool = attr(e.el, "GleamCooldown", 2)
				local w = attr(e.el, "GleamWidth", 0.22)
				local tt = e.t % (dur + cool)
				if e.grads then
					local live = tt < dur
					local off = -2
					if live then
						local span = 0.5 + w
						off = -span + (tt / dur) * span * 2
					end
					for gi = 1, #e.grads do
						e.grads[gi].Offset = Vector2.new(off, 0)
						local host = e.grads[gi].Parent
						if host and host:IsA("GuiObject") then
							if host.Visible ~= live then host.Visible = live end
							if live and host:IsA("TextLabel") and (e.el:IsA("TextLabel") or e.el:IsA("TextButton")) then -- both text classes share the original's spill
								if host.TextSize ~= e.el.TextSize then host.TextSize = e.el.TextSize end
								if host.TextScaled ~= e.el.TextScaled then host.TextScaled = e.el.TextScaled end
							end
						end
					end
				end
			elseif e.kind == "gleamG" then
				if e.parts == nil then
					local w0 = attr(e.el, "GleamWidth", 0.22)
					local gw0 = math.max(1, e.el.AbsoluteSize.X)
					local found = {}
					if gw0 > 1 then
						for _, d in ipairs(e.el:GetDescendants()) do
							local isText = d:IsA("TextLabel") or d:IsA("TextButton")
							if (isText or d:IsA("ImageLabel") or d:IsA("ImageButton")) -- overlays excluded by NAME: FW_Owned marks every imported instance, letters included
								and d.Name ~= "FW_GleamShine" and d.Name ~= "Background" then
								local dw = d.AbsoluteSize.X
								local pad = d:FindFirstChild("FW_TextPad")
								if pad and pad:IsA("UIPadding") then
									dw = dw * math.max(0, 1 - pad.PaddingLeft.Scale - pad.PaddingRight.Scale) -- the glyph copy lives inside the text spill's inset
								end
								if dw > 0 and (isText or dw < gw0 * 0.95) then -- only a group-sized IMAGE is a backdrop; a full-width title is still text
									local wl = math.clamp(w0 * gw0 / math.max(1, dw), 0.05, 0.6) -- capped: an uncapped band lit each letter WHOLE, a square flash instead of a sheen
									found[#found + 1] = { el = d, grads = gleamShine(d, wl) }
								end
							end
						end
					end
					if #found > 0 then
						e.parts = found
					else
						e.waited = e.waited + dt
						if e.waited > 2 then -- a group with genuinely nothing inside: the single sheen
							e.kind = "gleam"
							e.w = w0
							e.grads = gleamShine(e.el, w0)
						end
						continue
					end
				end
				local dur = math.max(0.02, attr(e.el, "GleamSpeed", 0.8))
				local cool = attr(e.el, "GleamCooldown", 2)
				local w = attr(e.el, "GleamWidth", 0.22)
				local tt = e.t % (dur + cool)
				local live = tt < dur
				local gp = e.el.AbsolutePosition.X
				local gw = math.max(1, e.el.AbsoluteSize.X)
				local m = 0.5 + w
				local c = -m + (tt / dur) * (1 + 2 * m) -- the band's centre, in GROUP fractions
				for pi = 1, #e.parts do
					local p = e.parts[pi]
					if p.el.Parent then
						for gi = 1, #p.grads do
							local host = p.grads[gi].Parent
							if host and host:IsA("GuiObject") then
								local px = (host.AbsolutePosition.X - gp) / gw
								local pw = math.max(0.001, host.AbsoluteSize.X / gw) -- use the rendered copy, not its parent's expanded text-spill box
								local off = live and ((c - px) / pw - 0.5) or -10 -- the ONE light, in this letter's own fractions
								p.grads[gi].Offset = Vector2.new(off, 0)
								if host.Visible ~= live then host.Visible = live end
								if live and host:IsA("TextLabel") and (p.el:IsA("TextLabel") or p.el:IsA("TextButton")) then
									if host.TextSize ~= p.el.TextSize then host.TextSize = p.el.TextSize end
									if host.TextScaled ~= p.el.TextScaled then host.TextScaled = p.el.TextScaled end
								end
							end
						end
					end
				end
			elseif e.kind == "pixels" then
				e.acc = e.acc + dt * e.rate
				while e.acc >= 1 do
					e.acc = e.acc - 1
					local f = e.cells[math.random(#e.cells)]
					if f then
						if e.vary then
							local kk = 0.3 + math.random() * 1.4
							f.Size = UDim2.fromScale(e.cw * kk, e.ch * kk)
						else
							f.Size = UDim2.fromScale(e.cw, e.ch)
						end
						local lit = 1 - e.alpha * (0.55 + 0.45 * math.random()) -- each twinkle its own brightness
						TweenService:Create(f, TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
							{ BackgroundTransparency = lit }):Play() -- the preview's envelope: fast lift, hold, slow fall
						local hold = 0.16 + math.random() * 0.48
						local fall = 0.35 + math.random() * 0.45
						task.delay(hold, function()
							if f.Parent then
								TweenService:Create(f, TweenInfo.new(fall, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
									{ BackgroundTransparency = 1 }):Play()
							end
						end)
					end
				end
			end
		end
	end
	for sc, v in pairs(scaleAcc) do -- one write per property: effects multiply, never overwrite
		sc.Value = v
	end
	for el, d in pairs(rotAcc) do
		fwRotSet(el, "r_juice", d)
	end
	if dead then
		for i = #dead, 1, -1 do
			table.remove(idle, dead[i])
		end
	end
end
task.delay(0.4, function() -- after the 3D host has had its turn
	local flat, deep = 0, 0
	for _, e in ipairs(idle) do
		if e.kind == "pulse" then
			if e.el:GetAttribute("FW_3DHosted") then deep = deep + 1 else flat = flat + 1 end
		end
	end
	print(("[Framewisp] juice: %d effect(s) on %s | pulse: %d smooth (3D host), %d on the pixel grid")
		:format(#idle, gui:GetFullName(), deep, flat))
end)
local told = false
RunService.RenderStepped:Connect(function(dt) -- one bad frame must not stop every effect
	local ok, err = pcall(tickIdle, dt)
	if not ok and not told then
		told = true
		warn("[Framewisp] effects: " .. tostring(err))
	end
end)
