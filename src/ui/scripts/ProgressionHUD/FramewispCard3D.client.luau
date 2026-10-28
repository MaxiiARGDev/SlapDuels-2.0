-- Framewisp: _3D / _tilt cards — real perspective, not a fake skew.
-- _tilt is the POSE the card stands in: turn left/right, look up/down.
-- _3D adds the tilt toward the cursor.
-- On the same layer the cursor tilt swings AROUND the pose instead of around zero.
-- The card is re-hosted on an invisible part in front of the camera with a
-- SurfaceGui (AlwaysOnTop), so it renders with real 3D perspective while every
-- button, state and _smooth effect inside keeps working. Play-mode only; the
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")

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
local player = Players.LocalPlayer
if not player then return end
local playerGui = player:FindFirstChildOfClass("PlayerGui")
if not playerGui then return end

-- ========================== tune the feel here ==========================
-- MAX_TILT — how far the card leans toward the cursor, in degrees.
--   3 = subtle, premium   ·   8 = default, lively   ·   15 = showy
--   25+ = motion-sickness territory, you were warned
-- SMOOTH — how fast the tilt follows the cursor (per-second rate).
--   4 = floaty, trails behind   ·   10 = default   ·   20 = near-instant
-- DIST — camera-to-card distance in studs; closer = stronger perspective
--   at the same tilt.   1 = dramatic   ·   2 = default   ·   4 = flat-ish
-- SWAY — idle sway on touch devices (no cursor there), in degrees.
--   0 = off   ·   2 = default breathing   ·   5 = noticeable rocking
-- ========================================================================
local MAX_TILT = 8
local SMOOTH = 10
local DIST = 2
local SWAY = 2

local rig = workspace:FindFirstChild("FramewispCards3D")
if not rig then
	rig = Instance.new("Folder")
	rig.Name = "FramewispCards3D"
	rig.Parent = workspace
end

local cards = {}
local function paints(e) -- does this layer put pixels on screen by itself?
	if not e:IsA("GuiObject") or not e.Visible then return false end
	if e.BackgroundTransparency < 0.99 then return true end
	if (e:IsA("ImageLabel") or e:IsA("ImageButton")) and e.Image ~= "" and e.ImageTransparency < 0.99 then return true end
	if (e:IsA("TextLabel") or e:IsA("TextButton") or e:IsA("TextBox")) and e.Text ~= "" and e.TextTransparency < 0.99 then return true end
	local st = e:FindFirstChildOfClass("UIStroke")
	return st ~= nil and st.Transparency < 0.99
end
local function overlaps(a, b)
	local ap, as, bp, bs = a.AbsolutePosition, a.AbsoluteSize, b.AbsolutePosition, b.AbsoluteSize
	return ap.X < bp.X + bs.X and ap.X + as.X > bp.X and ap.Y < bp.Y + bs.Y and ap.Y + as.Y > bp.Y
end
local function branchUnder(a, n) -- the child of a on the way down to n; nil when n is a itself
	while n and n.Parent ~= a do n = n.Parent end
	return n
end
local function beneath(e, card, a) -- e is drawn before the card, seen from their common ancestor a
	local eb, cb = branchUnder(a, e), branchUnder(a, card)
	if eb == nil then return true end -- e IS the ancestor: its own paint lies under everything in it
	if eb == cb then return false end -- inside the card's own branch: not a cover
	if eb.ZIndex ~= cb.ZIndex then return eb.ZIndex < cb.ZIndex end
	for _, k in ipairs(a:GetChildren()) do
		if k == eb then return true end
		if k == cb then return false end
	end
	return false
end
local function commonAncestor(e, card)
	local seen = {}
	local n = card.Parent
	while n do seen[n] = true; n = n.Parent end
	n = e
	while n and not seen[n] do n = n.Parent end
	return n
end
local function firstHost(card) -- the smallest ancestor holding every painted layer under the card
	local host, covers, name = nil, 0, ""
	for _, r in ipairs(fwRoots()) do
		for _, e in ipairs(r:GetDescendants()) do
			if e ~= card and paints(e) and not e:IsDescendantOf(card) and overlaps(e, card) then
				local a = commonAncestor(e, card)
				if a and a:IsA("GuiObject") and beneath(e, card, a) then
					covers, name = covers + 1, e.Name
					if not host or host:IsDescendantOf(a) then host = a end
				end
			end
		end
	end
	return host, covers, name
end
local function hostFor(card) -- climb: whatever covers the host is covered by ITS container, up to the design root
	local host, covers, name = firstHost(card)
	local h = host
	while h do
		local up = firstHost(h)
		if not up or up == h then break end
		h = up
	end
	return h, covers, name
end
local attach
attach = function(card, asHost)
	if card:GetAttribute("FW_3DHosted") then return true end
	for _, d in ipairs(card:GetDescendants()) do
		if d:IsA("CanvasGroup") then
			if not asHost then warn("[Framewisp] _3D: '" .. card.Name .. "' contains a CanvasGroup, which SurfaceGuis render unreliably — the card stays flat.") end
			return true
		end
	end
	local px = card.AbsoluteSize
	if px.X < 1 or px.Y < 1 then return false end -- not laid out yet: the caller retries
	if not asHost then
		local host, covers, name = hostFor(card) -- a ScreenGui draws over the world: what lies UNDER the card would cover it
		if host then -- so the container holding the card and those layers leaves the screen too: flat, zero tilt, one surface behind the card
			if not attach(host, true) then return false end -- the host is not laid out yet either
			if not host:GetAttribute("FW_3DHosted") and not card:GetAttribute("FW_3DLayerSaid") then
				card:SetAttribute("FW_3DLayerSaid", true)
				warn(("[Framewisp] _3d: %q renders in the world so it can have real perspective, and a ScreenGui always draws over that. %d layer(s) behind it (%s) will cover it in game. Framewisp would draw %q as a flat surface behind the card, but it holds a CanvasGroup, which a surface cannot render — move the tag onto the group that holds the card and its backdrop, or take the CanvasGroup out.")
					:format(card.Name, covers, name, host.Name))
			end
		end
	end

	local slot = Instance.new("Frame")
	slot.Name = card.Name .. "_3DSlot"
	slot.BackgroundTransparency = 1
	local restSize = card:GetAttribute("FW_EntrSize0") -- resting geometry, without scale, pitch or bob
	local restPos = card:GetAttribute("FW_EntrPos0")
	local ek = card:GetAttribute("FW_EntrK") -- an entrance mid-flight has the card scaled DOWN; the slot must hold the full size
	if typeof(restSize) == "UDim2" then
		slot.Size = restSize
	elseif type(ek) == "number" and ek > 0.05 and ek < 1 then
		slot.Size = UDim2.new(card.Size.X.Scale / ek, card.Size.X.Offset / ek, card.Size.Y.Scale / ek, card.Size.Y.Offset / ek)
	else
		slot.Size = card.Size
	end
	slot.Position = typeof(restPos) == "UDim2" and restPos or card.Position
	slot.AnchorPoint = card.AnchorPoint
	slot.LayoutOrder = card.LayoutOrder
	slot.ZIndex = card.ZIndex -- holds the card's place in the sibling order
	slot.Parent = card.Parent

	local part = Instance.new("Part")
	part.Name = "Card_" .. card.Name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	part.CanQuery = true -- SurfaceGui button input rides on this
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 0.001)
	part.Parent = rig

	local sg = Instance.new("SurfaceGui")
	sg.Name = "FramewispCard3D_" .. card.Name
	sg.ResetOnSpawn = false
	sg.AlwaysOnTop = true -- over world geometry, ScreenGui-exact colours, sharp text
	sg.Face = Enum.NormalId.Back -- the face that looks at the camera
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	local SS = 1 -- 1:1 with the screen: the size must be right first, smoothness second
	sg.CanvasSize = Vector2.new(px.X * SS, px.Y * SS)
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.ZOffset = #cards -- stack multiple cards without z-fighting
	sg.Adornee = part
	sg.Parent = playerGui -- input only works for PlayerGui descendants

	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromScale(1, 1)
	card:SetAttribute("FW_EntrK", nil) -- the normalisation above already removed the entrance scale
	card:SetAttribute("FW_EntrSize0", nil)
	card:SetAttribute("FW_EntrPos0", nil)
	card.Parent = sg
	local ov = Instance.new("ObjectValue") -- the card left the screen: every other runtime scans fwRoots(), so it must find it here
	ov.Name = "FW_ExtraRoot"
	ov.Value = sg
	ov.Parent = gui

	local tiltMax = card:GetAttribute("TiltMax") or card:GetAttribute("FigmaTiltMax")
	local persp = card:GetAttribute("TiltPersp") or card:GetAttribute("FigmaTiltPersp") -- camera distance: closer = stronger
	card:SetAttribute("FW_3DHosted", true) -- the juice runtime rocks THIS card in real 3D
	local host = nil -- the slot sits inside a hosted container's surface: its pixels are canvas pixels
	local n = slot.Parent
	while n and n ~= playerGui and n ~= gui do
		if n:IsA("SurfaceGui") then
			for _, h in ipairs(cards) do if h.sg == n then host = h end end
			break
		end
		n = n.Parent
	end
	local scroller = nil -- the list it scrolls in: a world surface is not clipped by it
	if not asHost then
		local m = slot.Parent
		while m and m ~= gui and not m:IsA("LayerCollector") do
			if m:IsA("ScrollingFrame") then scroller = m break end
			m = m.Parent
		end
	end
	cards[#cards + 1] = {
		slot = slot, part = part, sg = sg, card = card, host = host, flat = asHost == true, tiltX = 0, tiltY = 0, tiltMax = tiltMax,
		scroller = scroller, inWorld = true,
		live = card:GetAttribute("Figma3D") ~= nil, -- only _3D reacts to the cursor
		baseX = card:GetAttribute("TiltX") or card:GetAttribute("FigmaTiltX") or 0,
		baseY = card:GetAttribute("TiltY") or card:GetAttribute("FigmaTiltY") or 0,
		dist = persp and math.clamp(8 / math.max(persp, 0.5), 0.3, 20) or DIST,
	}
	return true
end
local function tagged(d)
	return (d:GetAttribute("Figma3D") or d:GetAttribute("FigmaTilt") or d:GetAttribute("FigmaSwing")) and d:IsA("GuiObject") and not d:IsA("ScrollingFrame") -- only layers that MEANT to leave the plane
end
local function tryAttach(d, tries)
	if not d.Parent or attach(d) then return end
	if tries > 0 then task.delay(0.5, function() tryAttach(d, tries - 1) end) end -- a zero-size card is one still being laid out
end

task.wait(0.1)
for _, d in ipairs(fwAll()) do
	if tagged(d) then tryAttach(d, 4) end
end
for _, r in ipairs(fwRoots()) do -- a card that arrives later still gets its depth
	r.DescendantAdded:Connect(function(d) if tagged(d) then task.defer(tryAttach, d, 4) end end)
end
local function shown(slot) -- the slot holds the card's place in the screen; its visibility chain is the card's
	if not gui.Enabled then return false end
	local n = slot
	while n do
		if n == gui then return true end
		if n:IsA("GuiObject") and not n.Visible then return false end
		if n:IsA("SurfaceGui") then -- inside a hosted container: its chain continues from THAT slot
			local h = nil
			for _, c in ipairs(cards) do if c.sg == n then h = c end end
			if not h then return false end
			n = h.slot
		else
			n = n.Parent
		end
	end
	return false
end

local touchOnly = UserInputService.TouchEnabled and not UserInputService.MouseEnabled

local function windowFit(c, sp, rs) -- 1 = well inside the list, fading to 0 at its edge; -1 = over it; nil = no list
	local w = c.scroller
	if not w or not w.Parent then return nil end
	local wp = w.AbsolutePosition
	local ok, ws = pcall(function() return w.AbsoluteWindowSize end) -- the visible part, scrollbars excluded
	if not ok or ws == nil or type(ws.Y) ~= "number" then ws = w.AbsoluteSize end
	local dir = w.ScrollingDirection -- only the edges it scrolls across: cards touch a list's sides by design
	local okC, canvas = pcall(function() return w.AbsoluteCanvasSize end)
	local known = okC and canvas ~= nil and type(canvas.Y) == "number"
	local useY = dir ~= Enum.ScrollingDirection.X and (not known or canvas.Y > ws.Y + 1)
	local useX = dir ~= Enum.ScrollingDirection.Y and (not known or canvas.X > ws.X + 1)
	if not useX and not useY then return nil end -- nothing scrolls: nothing can cross an edge
	local d, span = math.huge, math.huge
	if useY then d = math.min(d, sp.Y - wp.Y, wp.Y + ws.Y - (sp.Y + rs.Y)); span = math.min(span, rs.Y) end
	if useX then d = math.min(d, sp.X - wp.X, wp.X + ws.X - (sp.X + rs.X)); span = math.min(span, rs.X) end
	if d < -0.5 then return -1 end
	local margin = math.max(12, 0.35 * span)
	return math.clamp(d / margin, 0, 1)
end
local function toWorld(c, yes) -- the card's AnchorPoint/Position/Size fill either parent the same way
	if c.inWorld == yes then return end
	c.inWorld = yes
	c.card.Parent = yes and c.sg or c.slot
	if not yes then c.tiltX, c.tiltY = 0, 0 end
end

local function step(dt)
	local cam = workspace.CurrentCamera -- re-grabbed: CurrentCamera can be replaced
	if not cam then return end
	local inset = GuiService:GetGuiInset()
	local vp = cam.ViewportSize
	if vp.Y <= 0 then return end
	local tanHalf = math.tan(math.rad(cam.FieldOfView) / 2)
	local mouse = UserInputService:GetMouseLocation() -- viewport space, like ViewportPointToRay
	local alpha = 1 - math.exp(-dt * SMOOTH)
	for i, c in ipairs(cards) do
		c.rp = nil
		if c.slot.Parent and (not c.host or c.host.rp) then -- a host is always earlier in the list: its rect is fresh
			local spp = (2 * c.dist * tanHalf) / vp.Y
			local rp = c.host and (c.host.rp + c.slot.AbsolutePosition) or (c.slot.AbsolutePosition + inset)
			c.rp = rp
			local rs = c.slot.AbsoluteSize
			c.sg:SetAttribute("FW_RectX", rp.X)
			c.sg:SetAttribute("FW_RectY", rp.Y)
			c.sg:SetAttribute("FW_RectW", rs.X)
			c.sg:SetAttribute("FW_RectH", rs.Y)
			local wantW = math.floor(rs.X + 0.5)
			local wantH = math.floor(rs.Y + 0.5)
			local cs = c.sg.CanvasSize
			if math.abs(cs.X - wantW) > 2 or math.abs(cs.Y - wantH) > 2 then
				c.sg.CanvasSize = Vector2.new(math.max(wantW, 8), math.max(wantH, 8))
			end
			local cx = rp.X + rs.X / 2
			local cy = rp.Y + rs.Y / 2
			local fit = windowFit(c, c.slot.AbsolutePosition, rs)
			if fit ~= nil then c.sg:SetAttribute("FW_TiltK", math.max(fit, 0)) end
			if fit == -1 then
				toWorld(c, false) -- over the edge: flat in its slot, clipped by the list
				if c.sg.Enabled ~= false then c.sg.Enabled = false end
				continue
			end
			toWorld(c, true)
			local k = fit or 1
			if c.live then -- a pose-only card just holds its angle: no cursor, no sway
				local tx, ty = 0, 0
				if touchOnly then
					local t = time()
					tx = math.sin(t * 0.9 + i) * SWAY
					ty = math.cos(t * 0.7 + i) * SWAY
				else
					local nx = (mouse.X - cx) / math.max(rs.X / 2, 1)
					local ny = (mouse.Y - cy) / math.max(rs.Y / 2, 1)
					if math.abs(nx) <= 1 and math.abs(ny) <= 1 then
						local mt = c.tiltMax or MAX_TILT
						tx = -ny * mt
						ty = nx * mt
					end
				end
				c.tiltX = c.tiltX + (tx - c.tiltX) * alpha
				c.tiltY = c.tiltY + (ty - c.tiltY) * alpha
			end
			local hs = (c.card and c.card:GetAttribute("FW_HostScale")) or 1 -- a 3D quad has no pixel grid
			local sz = Vector3.new(math.max(rs.X * spp * hs, 0.001), math.max(rs.Y * spp * hs, 0.001), 0.001)
			local offX = (cx - vp.X / 2) * spp
			local offY = -(cy - vp.Y / 2) * spp -- screen Y is down, camera Y is up
			c.part.Size = sz
			c.part.CFrame = cam.CFrame
				* CFrame.new(offX, offY, -(c.dist + sz.Z / 2))
				* CFrame.Angles(math.rad(-(c.baseX + c.tiltX + (c.card and c.card:GetAttribute("FW_SwingPitch") or 0)) * k),
					math.rad((c.baseY + c.tiltY) * k), 0) -- -X: CSS and Roblox pitch opposite ways; k fades it at a list's edge
			local faces = (-c.part.CFrame.LookVector):Dot(cam.CFrame.Position - c.part.Position) > 0
			local on = faces and shown(c.slot) -- a closed panel or a disabled screen hides its world cards too
			if c.sg.Enabled ~= on then c.sg.Enabled = on end
		end
	end
end
RunService:BindToRenderStep("FramewispCard3D", Enum.RenderPriority.Camera.Value + 1, step)
