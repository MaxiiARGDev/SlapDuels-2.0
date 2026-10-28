-- Framewisp: keeps text and stroke sizes accurate at any screen resolution.
-- Safe to delete only if your UI never changes resolution (text will stop scaling).
local TextService = game:GetService("TextService")
local gui = script.Parent
function fwGradientAnchor(d)
	local grads = {}
	for _, c in ipairs(d:GetChildren()) do
		if c:IsA("UIGradient") and d:GetAttribute("FigmaFlow") == nil then grads[#grads + 1] = c
		elseif c:IsA("UIStroke") and d:GetAttribute("FigmaStroke") == nil and d:GetAttribute("FigmaFlow") == nil then
			for _, g in ipairs(c:GetChildren()) do if g:IsA("UIGradient") then grads[#grads + 1] = g end end
		end
	end
	if #grads == 0 then return end
	fwGradientData = fwGradientData or setmetatable({}, { __mode = "k" })
	local host = d:FindFirstChild("FW_Scale")
	local ch = host and host:FindFirstChild("k_text")
	local spill = ch and ch.Value or 1
	local shift = d:GetAttribute("FW_GradientShiftY") or 0
	local anchor = d.AnchorPoint
	for _, grad in ipairs(grads) do
		local raw = grad:GetAttribute("FigmaGradient")
		if type(raw) ~= "string" then continue end
		local entry = fwGradientData[grad]
		if not entry or entry.raw ~= raw then
			local ok, paint = pcall(function() return game:GetService("HttpService"):JSONDecode(raw) end)
			if not ok or type(paint) ~= "table" or type(paint.geometry) ~= "table" or type(paint.stops) ~= "table" then continue end
			entry = { raw = raw, paint = paint }
			fwGradientData[grad] = entry
		end
		local key = tostring(spill) .. ":" .. tostring(shift) .. ":" .. tostring(anchor.X) .. ":" .. tostring(anchor.Y)
		if entry.key == key then continue end
		if entry.color and (grad.Color ~= entry.color or grad.Transparency ~= entry.alpha
			or grad.Rotation ~= entry.rotation or grad.Offset ~= entry.offset) then
			entry.own = true -- a developer edited the sequence: retain their paint
		end
		if entry.own then continue end
		local g, stops = entry.paint.geometry, entry.paint.stops
		if #stops < 1 or not (g.w > 0 and g.h > 0 and g.bw > 0 and g.bh > 0) then continue end
		local w, h = g.bw * spill, g.bh * spill
		local x = g.x - (spill - 1) * g.bw * anchor.X
		local y = g.y + shift - (spill - 1) * g.bh * anchor.Y
		local qx, qy = g.a / g.w, g.b / g.h
		local q = math.sqrt(qx * qx + qy * qy)
		local center = qx * (x + w / 2) + qy * (y + h / 2) + g.c
		local function sample(t)
			if t <= stops[1].p then return stops[1] end
			for i = 2, #stops do
				local l, r = stops[i - 1], stops[i]
				if t <= r.p then
					local u = r.p - l.p > 1e-10 and (t - l.p) / (r.p - l.p) or 1
					return { r = l.r + (r.r - l.r) * u, g = l.g + (r.g - l.g) * u,
						b = l.b + (r.b - l.b) * u, a = l.a + (r.a - l.a) * u }
				end
			end
			return stops[#stops]
		end
		local first, last = 1, #stops
		local function same(l, r)
			return math.abs(l.r - r.r) <= 1e-10 and math.abs(l.g - r.g) <= 1e-10
				and math.abs(l.b - r.b) <= 1e-10 and math.abs(l.a - r.a) <= 1e-10
		end
		while first < last and same(stops[first], stops[first + 1]) do first += 1 end
		while last > first and same(stops[last], stops[last - 1]) do last -= 1 end
		local span, start, nx, ny = 1, center, 1, 0
		if q >= 1e-10 then
			nx, ny = qx / q, qy / q
			local length = math.min(math.abs(nx) > 1e-10 and w / math.abs(nx) or math.huge,
				math.abs(ny) > 1e-10 and h / math.abs(ny) or math.huge)
			span = q * length
			local extent = (math.abs(qx) * w + math.abs(qy) * h) / 2
			local lo, hi = math.max(center - extent, stops[first].p), math.min(center + extent, stops[last].p)
			start = center - span / 2
			if hi > lo and hi - lo <= span + 1e-8 then start = math.max(hi - span, math.min(lo, start)) end
		end
		local times = { 0 }
		local values = { sample(q < 1e-10 and center or start) }
		if q >= 1e-10 then
			for i = first, last do
				local stop = stops[i]
				local t = (stop.p - start) / span
				if t > 1e-8 and t < 1 - 1e-8 then times[#times + 1] = t; values[#values + 1] = stop end
			end
		end
		times[#times + 1] = 1
		values[#values + 1] = sample(q < 1e-10 and center or start + span)
		if #times > 20 then
			times, values = {}, {}
			for i = 0, 19 do
				times[#times + 1] = i / 19; values[#values + 1] = sample(start + span * i / 19)
			end
			grad:SetAttribute("FW_GradientApprox", true)
		end
		for i = #times - 1, 2, -1 do if times[i] >= times[i + 1] then times[i] = times[i + 1] - 1e-6 end end
		local colors, alpha = {}, {}
		for i, t in ipairs(times) do
			local c = values[i]
			colors[#colors + 1] = ColorSequenceKeypoint.new(t, Color3.new(c.r, c.g, c.b))
			alpha[#alpha + 1] = NumberSequenceKeypoint.new(t, 1 - c.a)
		end
		grad.Color, grad.Transparency = ColorSequence.new(colors), NumberSequence.new(alpha)
		grad.Rotation = q < 1e-10 and 0 or math.deg(math.atan2(qy, qx))
		local delta = q < 1e-10 and 0 or (start + span / 2 - center) / q
		grad.Offset = Vector2.new(delta * nx / w, delta * ny / h)
		entry.key, entry.color, entry.alpha = key, grad.Color, grad.Transparency
		entry.rotation, entry.offset = grad.Rotation, grad.Offset
	end
end

do
	local okv, v = pcall(function() return script:GetAttribute("FWv") end)
	print("[Framewisp] TextScaler v" .. tostring(okv and v or "?") .. " in " .. gui.Name .. " — baselines are static, Play moves nothing")
end
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
	local dw, dh = gui:GetAttribute("BB_DesignW"), gui:GetAttribute("BB_DesignH")
	for _, d in ipairs(fwAll()) do -- slots transport the design; only stampDesign marks its actual bounds
		if d:IsA("GuiObject") and d:GetAttribute("FW_Owned") == true then
			local w, h = d:GetAttribute("BB_DesignW"), d:GetAttribute("BB_DesignH")
			if type(w) == "number" and w > 0 and type(h) == "number" and h > 0
				and (dw == nil or w == dw) and (dh == nil or h == dh) then
				return d -- retain this object when Card3D reparents it into a SurfaceGui
			end
		end
	end
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
local designH = gui:GetAttribute("BB_DesignH") or 1080
local designW = gui:GetAttribute("BB_DesignW")
local factor = gui:GetAttribute("BB_TextFactor") or 1.16
local byKey, facesReady = {}, {}
local reverified = false
local EM = { -- TextSize per design em of each bundled face: a label not sized by its width uses its em
	["rbxasset://fonts/families/AccanthisADFStd.json"] = 1.168,
	["rbxasset://fonts/families/AmaticSC.json"] = 1.261,
	["rbxasset://fonts/families/Arimo.json"] = 1.1172,
	["rbxasset://fonts/families/Balthazar.json"] = 1.018,
	["rbxasset://fonts/families/Bangers.json"] = 1.064,
	["rbxasset://fonts/families/BuilderExtended.json"] = 1.26,
	["rbxasset://fonts/families/BuilderMono.json"] = 1.26,
	["rbxasset://fonts/families/BuilderSans.json"] = 1.26,
	["rbxasset://fonts/families/ComicNeueAngular.json"] = 1.209,
	["rbxasset://fonts/families/Creepster.json"] = 1.1689,
	["rbxasset://fonts/families/DenkOne.json"] = 1.25,
	["rbxasset://fonts/families/Fondamento.json"] = 1.3838,
	["rbxasset://fonts/families/FredokaOne.json"] = 1.21,
	["rbxasset://fonts/families/GrenzeGotisch.json"] = 1.48,
	["rbxasset://fonts/families/Guru.json"] = 1.1846,
	["rbxasset://fonts/families/HighwayGothic.json"] = 1.107,
	["rbxasset://fonts/families/Inconsolata.json"] = 1.049,
	["rbxasset://fonts/families/IndieFlower.json"] = 1.459,
	["rbxasset://fonts/families/JosefinSans.json"] = 1.0,
	["rbxasset://fonts/families/Jura.json"] = 1.183,
	["rbxasset://fonts/families/Kalam.json"] = 1.594,
	["rbxasset://fonts/families/LegacyArial.json"] = 1.1172,
	["rbxasset://fonts/families/LegacyArimo.json"] = 1.1172,
	["rbxasset://fonts/families/LuckiestGuy.json"] = 1.0,
	["rbxasset://fonts/families/Merriweather.json"] = 1.257,
	["rbxasset://fonts/families/Michroma.json"] = 1.4219,
	["rbxasset://fonts/families/Montserrat.json"] = 1.219,
	["rbxasset://fonts/families/Nunito.json"] = 1.364,
	["rbxasset://fonts/families/Oswald.json"] = 1.482,
	["rbxasset://fonts/families/PatrickHand.json"] = 1.354,
	["rbxasset://fonts/families/PermanentMarker.json"] = 1.4268,
	["rbxasset://fonts/families/PressStart2P.json"] = 1.834, -- Figma's face is 1.790x wider than this file: 1.0244 x 1.790
	["rbxasset://fonts/families/Roboto.json"] = 1.1719,
	["rbxasset://fonts/families/RobotoCondensed.json"] = 1.1719,
	["rbxasset://fonts/families/RobotoMono.json"] = 1.3188,
	["rbxasset://fonts/families/RomanAntique.json"] = 1.049,
	["rbxasset://fonts/families/Sarpanch.json"] = 1.4,
	["rbxasset://fonts/families/SourceSansPro.json"] = 1.257,
	["rbxasset://fonts/families/SpecialElite.json"] = 1.0,
	["rbxasset://fonts/families/TitilliumWeb.json"] = 1.521,
	["rbxasset://fonts/families/Ubuntu.json"] = 1.121,
	["rbxasset://fonts/families/Zekton.json"] = 1.2,
}
local ContentProvider = game:GetService("ContentProvider")
local function faceOf(d)
	local f = d.FontFace
	if not f then return "?" end
	return tostring(f.Family) .. "|" .. tostring(f.Weight) .. "|" .. tostring(f.Style)
end
local function textKey(d)
	return faceOf(d) .. "|" .. (d.ContentText:gsub("^%s+", ""):gsub("%s+$", ""))
end
local gridInfo = setmetatable({}, { __mode = "k" })
local function fwRenders()
	local cam = workspace.CurrentCamera
	return cam ~= nil and cam.ViewportSize.X >= 2 and cam.ViewportSize.Y >= 2
end

local function fwHoverRoom(cells, cellW, cellH)
	local hs = 1
	if cells then
		for _, c in ipairs(cells:GetChildren()) do
			if c:IsA("GuiObject") and c:GetAttribute("FigmaSmooth") then
				local v = c:GetAttribute("SmoothHover") or c:GetAttribute("FigmaSmoothHover") or 1.08
				if type(v) == "number" and v > hs then hs = v end
			end
		end
	end
	if hs <= 1 then return 0, 0 end
	return cellW * (hs - 1) / 2, cellH * (hs - 1) / 2
end

local gridGeometry, gridScroll -- mutually recursive: a re-fit updates the canvas

local function gridRatio(cells, fallback, smScale)
	local grid = cells and cells:FindFirstChildWhichIsA("UIGridLayout")
	if not grid then return fallback end
	local winW = grid:GetAttribute("FigmaWinW") or 0
	if winW <= 0 then return fallback end
	local host = cells.Parent
	local live = ((host and host:IsA("ScrollingFrame")) and host.AbsoluteSize.X or cells.AbsoluteSize.X) / smScale
	if live <= 1 then return fallback end
	return live / winW
end

function gridGeometry(d, k, kx, smScale)
	if d:IsA("UIPadding") and d:GetAttribute("FigmaPadL") ~= nil then
		local gs = gridRatio(d.Parent, kx, smScale)
		d.PaddingLeft = UDim.new(0, (d:GetAttribute("FigmaPadL") or 0) * gs)
		d.PaddingTop = UDim.new(0, (d:GetAttribute("FigmaPadT") or 0) * gs)
		d.PaddingBottom = UDim.new(0, (d:GetAttribute("FigmaPadB") or 0) * gs)
		return
	end
	if not (d:IsA("UIGridLayout") and d:GetAttribute("FigmaCellW") ~= nil) then return end
	local cells = d.Parent
	local cols = math.max(1, d.FillDirectionMaxCells)
	local gs = gridRatio(cells, kx, smScale)
	local cellWD = d:GetAttribute("FigmaCellW") or 0
	local cellHD = d:GetAttribute("FigmaCellH") or 0
	local gapXD = d:GetAttribute("FigmaGapX") or 0
	local gapYD = d:GetAttribute("FigmaGapY") or 0
	local pad = cells and cells:FindFirstChildWhichIsA("UIPadding")
	local padLD = (pad and pad:GetAttribute("FigmaPadL")) or 0

	local sf = cells and cells.Parent
	local barD = 0
	if sf and sf:IsA("ScrollingFrame") then
		barD = sf:GetAttribute("FigmaBar") or sf.ScrollBarThickness
		local mineBar = sf:GetAttribute("FW_BarPx")
		if type(mineBar) == "number" and math.abs(sf.ScrollBarThickness - mineBar) > 0.5 then
			barD = sf.ScrollBarThickness / (gs > 0.001 and gs or 1)
			sf:SetAttribute("FigmaBar", barD)
		end
		local wantBar = math.max(2, barD * gs)
		sf.ScrollBarThickness = wantBar
		sf:SetAttribute("FW_BarPx", wantBar)
	end

	local roomD = d:GetAttribute("FigmaHoverRoom")
	if roomD == nil then roomD = select(1, fwHoverRoom(cells, cellWD, cellHD)) end
	local hostW = ((sf and sf:IsA("ScrollingFrame")) and sf.AbsoluteSize.X) or (cells and cells.AbsoluteSize.X) or 0
	local availD = (hostW / smScale) / math.max(gs, 1e-6)
	local cellW = cellWD
	if availD > 1 then
		local maxD = (availD - padLD - (cols - 1) * gapXD - barD - roomD) / cols
		if maxD > 0 and maxD < cellW then cellW = maxD end
	end
	local cellH = cellHD * (cellW / math.max(cellWD, 1e-6)) -- keep the card's shape

	d.CellSize = UDim2.fromOffset(math.max(1, cellW * gs), math.max(1, cellH * gs))
	d.CellPadding = UDim2.fromOffset(gapXD * gs, gapYD * gs)

	local info = gridInfo[d]
	if not info then
		info = {}
		gridInfo[d] = info
	end
	if cells and not info.sizeWired then
		info.sizeWired = true
		cells:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			if info.refit and not info.busy and fwRenders() then
				info.busy = true
				info.refit()
				info.busy = false
			end
		end)
	end
	info.refit = function()
		gridGeometry(d, k, kx, smScale)
		if pad then gridGeometry(pad, k, kx, smScale) end -- the origin rides along
		if sf then gridScroll(sf) end
	end
end

function gridScroll(sf)
	if not (sf:IsA("ScrollingFrame") and sf:GetAttribute("FWGridScroll")) then return end
	local cells, grid
	for _, c in ipairs(sf:GetAttribute("FWNestedGridScroll") and sf:GetDescendants() or sf:GetChildren()) do
		if c.Name == "Cells" and c:GetAttribute("FW_Owned") and c:FindFirstAncestorWhichIsA("ScrollingFrame") == sf then
			local g = c:FindFirstChildWhichIsA("UIGridLayout")
			if g then cells, grid = c, g break end
		end
	end
	if not grid then return end
	local pad = cells:FindFirstChildWhichIsA("UIPadding")
	local info = gridInfo[grid]
	if not info then
		info = {}
		gridInfo[grid] = info
	end
	if not info.canvasWired then
		info.canvasWired = true
		grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
			if info.set and fwRenders() then info.set() end
		end)
		cells.ChildAdded:Connect(function() if info.set and fwRenders() then info.set() end end)
		cells.ChildRemoved:Connect(function() if info.set and fwRenders() then info.set() end end)
	end
	info.set = function()
		local cellH = grid.CellSize.Y.Offset
		local gapY = grid.CellPadding.Y.Offset
		local pt = pad and pad.PaddingTop.Offset or 0
		local pb = pad and pad.PaddingBottom.Offset or 0
		local step = cellH + gapY
		local rows = 0
		if step > 0 then
			rows = math.max(0, math.floor((grid.AbsoluteContentSize.Y + gapY) / step + 0.5))
		end
		if rows == 0 then
			local n = 0
			for _, c in ipairs(cells:GetChildren()) do
				if c:IsA("GuiObject") and c.Visible then n = n + 1 end
			end
			rows = math.ceil(n / math.max(1, grid.FillDirectionMaxCells))
		end
		local h = rows > 0 and (pt + rows * cellH + (rows - 1) * gapY + pb) or 0
		if sf:GetAttribute("FWNestedGridScroll") then
			h += math.max(0, cells.AbsolutePosition.Y - sf.AbsolutePosition.Y + sf.CanvasPosition.Y)
		end
		if h <= sf.AbsoluteWindowSize.Y + 1 then h = 0 end
		sf.CanvasSize = UDim2.fromOffset(0, h)
	end
	info.set()
end

local function measure(d) -- per face + text, after the face is downloaded
	local key = textKey(d)
	local cached = byKey[key]
	if cached ~= nil then return cached or nil end
	local face = faceOf(d)
	if not facesReady[face] then
		facesReady[face] = true
		pcall(function() ContentProvider:PreloadAsync({ d }) end)
	end
	local ok, b = pcall(function()
		local prm = Instance.new("GetTextBoundsParams")
		prm.Text = (d.ContentText:gsub("^%s+", ""):gsub("%s+$", ""))
		prm.Font = d.FontFace
		prm.Size = 100
		prm.Width = 1e6
		return TextService:GetTextBoundsAsync(prm)
	end)
	if ok and b and b.X > 0 then
		byKey[key] = b.X
		return b.X
	end
	if ok then
		byKey[key] = false
	end
	return nil
end
local function stampVote() -- twins agree: the stamp most labels of one face + text carry
	local votes, best = {}, {}
	for _, d in ipairs(root:GetDescendants()) do
		local st = d:GetAttribute("FW_M100")
		if type(st) == "number" and st > 0 and d:GetAttribute("FigmaTextW") then
			local key = textKey(d)
			local r = math.floor(st * 10 + 0.5) / 10
			votes[key] = votes[key] or {}
			votes[key][r] = (votes[key][r] or 0) + 1
		end
	end
	for key, tally in pairs(votes) do
		local top, n = nil, 0
		for v, c in pairs(tally) do
			if c > n or (c == n and top and v > top) then top, n = v, c end
		end
		best[key] = top
	end
	return best
end
local padWired = setmetatable({}, { __mode = "k" })
local function textPad(d, s) -- the spill grows the box about its AnchorPoint: inset the text back to the design box
	local pad = d:FindFirstChild("FW_TextPad")
	if s <= 1.0001 then
		if pad then pad:Destroy() end
		return
	end
	if not pad then
		if d:FindFirstChildWhichIsA("UIPadding") then return end -- the developer's padding owns the text area
		pad = Instance.new("UIPadding")
		pad.Name = "FW_TextPad"
		pad:SetAttribute("FW_Owned", true)
		pad.Parent = d
	end
	local a, g = d.AnchorPoint, 1 - 1 / s
	pad.PaddingLeft = UDim.new(a.X * g, 0)
	pad.PaddingRight = UDim.new((1 - a.X) * g, 0)
	pad.PaddingTop = UDim.new(a.Y * g, 0)
	pad.PaddingBottom = UDim.new((1 - a.Y) * g, 0)
	if not padWired[d] then
		padWired[d] = true
		d:GetPropertyChangedSignal("AnchorPoint"):Connect(function() -- a layout slot re-anchors it later
			local h = d:FindFirstChild("FW_Scale")
			local c = h and h:FindFirstChild("k_text")
			textPad(d, c and c.Value or 1)
		end)
	end
end
local function spillOver(x) -- a stroke or a gleam copy is drawn inside its label's spill
	local sp, n = 1, x.Parent
	while n and n ~= root do
		local h = n:FindFirstChild("FW_Scale")
		local c = h and h:FindFirstChild("k_text")
		if c and c.Value > 0 then sp = sp * c.Value end
		n = n.Parent
	end
	return sp
end
local function setTextPx(d, t, exact)
	if d:FindFirstAncestorWhichIsA("BillboardGui") then return end -- billboards size their own text
	local mine = d:GetAttribute("FW_TextMine")
	if type(mine) == "number" and (math.abs(d.TextSize - mine) > 0.5
		or d.TextScaled ~= (d:GetAttribute("FW_TextScaledMine") == true)) then
		d:SetAttribute("FW_TextOwn", true)
	end
	if d:GetAttribute("FW_TextOwn") then return end
	local sc = fwChannel(d, "k_text")
	local con = d:FindFirstChild("FWTextBig")
	if con then con:Destroy() end -- TextScaled + Min==Max stops at 100 too: the spill is the only way past it
	d.TextScaled = false
	if t > 100 then
		sc.Value = t / 100
		d.TextSize = 100
	else
		sc.Value = 1
		local px = exact and math.floor(t) or math.floor(t + 0.5)
		d.TextSize = math.max(1, px)
	end
	textPad(d, sc.Value)
	d:SetAttribute("FW_TextMine", d.TextSize)
	d:SetAttribute("FW_TextScaledMine", d.TextScaled)
end
local gen = 0
local coldTries = 0
local printedPass = false
local smHooked, smPend = nil, false
local apply
local function smRerun()
	if smPend then return end
	smPend = true
	task.delay(0.2, function()
		smPend = false
		apply()
	end)
end
function apply()
	gen = gen + 1
	local myGen = gen
	local sm = root:FindFirstChild("FW_Scale") or root:FindFirstChild("FramewispSmooth") or root:FindFirstChild("FWActScale")
	local smScale = (sm and sm:IsA("UIScale") and sm.Scale > 0) and sm.Scale or 1
	if sm and sm ~= smHooked and sm:IsA("UIScale") then
		smHooked = sm
		sm:GetPropertyChangedSignal("Scale"):Connect(smRerun) -- solved mid-tween = a size compensating a scale that finished at 1
	end
	local k = root.AbsoluteSize.Y / designH / smScale
	if k <= 0 then return end
	if not fwRenders() then return end
	if root.AbsoluteSize.X < 2 or root.AbsoluteSize.Y < 2 then return end
	local kx = (type(designW) == "number" and designW > 0) and root.AbsoluteSize.X / designW / smScale or k
	local transient = false
	local nExact, nFallback = 0, 0
	local measured = false
	local agreed = stampVote()
	for _, d in ipairs(root:GetDescendants()) do
		if myGen ~= gen then return end
		local fs = d:GetAttribute("FigmaFontSize")
		if fs and d.Name ~= "FW_GleamShine" then -- a gleam copy inherits its label's spill: solving it again doubled it
			local m = nil
			local tw = d:GetAttribute("FigmaTextW")
			if type(tw) == "number" and tw > 0 then
				local t0 = d:GetAttribute("FW_Text0")
				if t0 == nil then
					t0 = d.ContentText
					d:SetAttribute("FW_Text0", t0)
				end
				if d.ContentText == t0 then
					m = agreed[textKey(d)] or d:GetAttribute("FW_M100")
					if m == nil then m = measure(d); measured = true end -- stamped at import; twins vote; else measured here
					if m == nil and byKey[textKey(d)] == nil then transient = true end
				end
				if myGen ~= gen then return end
			end
			if m then
				setTextPx(d, 100 * (tw * kx) / m, true)
				nExact = nExact + 1
			else
				local f = d.FontFace
				setTextPx(d, fs * k * ((f and EM[tostring(f.Family)]) or factor))
				nFallback = nFallback + 1
			end
			fwGradientAnchor(d)
		end
		local swMine = d:GetAttribute("FW_StrokeMine")
		if type(swMine) == "number" and math.abs(d.Thickness - swMine) > 0.01 then
			d:SetAttribute("FW_StrokeOwn", true)
		end
		local okMode, isFrac = pcall(function() return d.StrokeSizingMode == Enum.StrokeSizingMode.ScaledSize end)
		if d:GetAttribute("FW_StrokeScaled") or (okMode and isFrac) then -- a fraction, not pixels
			d:SetAttribute("FW_StrokeScaled", true)
			local host = d.Parent
			if d.Thickness > 0.5 and (d:GetAttribute("FigmaStrokeW") or d:GetAttribute("FigmaTextStrokeW"))
				and host and host:IsA("GuiObject") and math.min(host.AbsoluteSize.X, host.AbsoluteSize.Y) > 1 then
				d.Thickness = d.Thickness / math.min(host.AbsoluteSize.X, host.AbsoluteSize.Y)
			end
		elseif not d:GetAttribute("FW_StrokeOwn") then
			local sw = d:GetAttribute("FigmaStrokeW")
			if sw then d.Thickness = math.max(0.35, sw * k) end
			local tsw = d:GetAttribute("FigmaTextStrokeW")
			if tsw then
				d.Thickness = math.max(0.35, (tsw * k + (d:GetAttribute("FW_StrokeExtra") or 0)) / spillOver(d)) -- geometry, not font compensation; a gleam halo keeps its extra
			end
			if sw or tsw then d:SetAttribute("FW_StrokeMine", d.Thickness) end
		end
		local ss = d:GetAttribute("FigmaSliceScale")
		if type(ss) == "number" and ss > 0 then pcall(function() d.SliceScale = ss * k end) end -- 9-slice corners keep the design's size
		gridGeometry(d, k, kx, smScale)
		gridScroll(d)
	end
	gridScroll(root) -- the root can BE the scrolling grid
	if not printedPass and (nExact + nFallback) > 0 then
		printedPass = true
		print(("[Framewisp] TextScaler: %d width-exact, %d fallback"):format(nExact, nFallback))
		local rootH = root.AbsoluteSize.Y
		local worst, shown = {}, 0
		if rootH > 1 then
			for _, d in ipairs(root:GetDescendants()) do
				local tag = d:GetAttribute("FW_EDbg")
				if type(tag) == "string" and d:IsA("TextLabel") and d.AbsoluteSize.Y > 0 then
					local eL, eC = tag:match("([%d.]+)|([%d.]+)")
					eL, eC = tonumber(eL), tonumber(eC)
					if eL and eC then
						local pL = d.TextSize / rootH
						local pC = (d.AbsolutePosition.Y - root.AbsolutePosition.Y + d.AbsoluteSize.Y / 2) / rootH
						local dl, dc = pL - eL, pC - eC
						if math.abs(dl) > 0.002 or math.abs(dc) > 0.002 then
							worst[#worst + 1] = { n = d.Name, dl = dl * rootH, dc = dc * rootH }
						end
					end
				end
			end
		end
		table.sort(worst, function(a, b) return math.abs(a.dc) + math.abs(a.dl) > math.abs(b.dc) + math.abs(b.dl) end)
		for i = 1, math.min(3, #worst) do
			local x = worst[i]
			print(("[Framewisp] play vs edit %q: size %+.1f px, centre %+.1f px"):format(x.n, x.dl, x.dc))
		end
		if #worst == 0 then
			print("[Framewisp] play matches the editor within 0.2% — any remaining shift is pure rendering")
		end
	end
	if transient and coldTries < 6 then
		coldTries = coldTries + 1
		task.delay(0.5, function()
			if myGen == gen then apply() end
		end)
	elseif measured and not reverified then
		reverified = true
		task.delay(2, function() table.clear(byKey); apply() end) -- once more with every face surely downloaded
	end
end
local pending = false
root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
	if pending then return end
	pending = true
	task.spawn(function()
		task.wait()
		pending = false
		apply()
	end)
end)
apply()
