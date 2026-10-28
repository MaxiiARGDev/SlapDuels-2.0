-- UIEffects: feedback de sonido y animacion para ShopHUD.
-- Solo agrega efectos (hover/press/sounds). No altera la logica del ShopController ni del CrateController.
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local gui = script.Parent
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Esperar a que el HUD se copie a PlayerGui (StarterGui tarda un frame)
local hud = playerGui:WaitForChild("ShopHUD", 15)
if not hud then return end

-- === Sonidos ===
local function makeSound(id, vol, pitch, parent)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = vol
	s.PlaybackSpeed = pitch or 1
	s.Parent = parent or hud
	return s
end

local SND_HOVER = makeSound("rbxassetid://124917708988713", 0.35, 1.2)   -- Glint (hover)
local SND_CLICK = makeSound("rbxassetid://87437544236708", 0.5, 1.0)    -- Ping (click)
local SND_OPEN  = makeSound("rbxassetid://138924280439393", 0.6, 0.85)   -- Ping grave (open)
local SND_CLOSE = makeSound("rbxassetid://131923350029101", 0.45, 0.75)  -- Glint grave (close)

local lastHover = 0
local function play(snd)
	if not snd then return end
	snd.TimePosition = 0
	snd:Play()
end
local function playHover()
	-- throttle para evitar spam
	if os.clock() - lastHover < 0.05 then return end
	lastHover = os.clock()
	play(SND_HOVER)
end

-- === Hover / Press ===
local TWEEN_HOVER = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function attachButton(btn, opts)
	opts = opts or {}
	if not btn or not btn:IsA("GuiButton") or btn:GetAttribute("UIEffectsBound") then return end
	btn:SetAttribute("UIEffectsBound", true)

	local baseSize = btn.Size
	local baseBgTransparency = btn.BackgroundTransparency
	local baseStrokeColor = nil
	local baseStrokeTransparency = nil
	local stroke = btn:FindFirstChildOfClass("UIStroke")
	if stroke then baseStrokeColor = stroke.Color; baseStrokeTransparency = stroke.Transparency end

	local hoverScale = opts.hoverScale or 1.03
	local hoverColor = opts.hoverColor

	btn.MouseEnter:Connect(function()
		if not btn.Active then return end
		playHover()
		local tw = { Size = UDim2.new(baseSize.X.Scale * hoverScale, baseSize.X.Offset * hoverScale,
		                            baseSize.Y.Scale * hoverScale, baseSize.Y.Offset * hoverScale) }
		TweenService:Create(btn, TWEEN_HOVER, { BackgroundTransparency = math.max(0, baseBgTransparency - 0.08) }):Play()
		if stroke and baseStrokeColor then
			TweenService:Create(stroke, TWEEN_HOVER, { Color = Color3.fromRGB(0, 194, 255), Transparency = 0 }):Play()
		end
	end)

	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TWEEN_HOVER, { BackgroundTransparency = baseBgTransparency }):Play()
		if stroke and baseStrokeColor then
			TweenService:Create(stroke, TWEEN_HOVER, { Color = baseStrokeColor, Transparency = baseStrokeTransparency or 0 }):Play()
		end
	end)

	btn.Activated:Connect(function()
		play(opts.sound or SND_CLICK)
		-- micro-press feedback
		local pressed = UDim2.new(baseSize.X.Scale * 0.96, baseSize.X.Offset * 0.96,
		                          baseSize.Y.Scale * 0.96, baseSize.Y.Offset * 0.96)
		btn.Size = pressed
		TweenService:Create(btn, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = baseSize }):Play()
	end)
end

-- === Boton de tienda (open sound) ===
local shopBtn = hud:FindFirstChild("ShopButton")
if shopBtn then attachButton(shopBtn, { sound = SND_OPEN, hoverScale = 1.04 }) end

-- === Cerrar tienda (header) ===
local mainFrame = hud:WaitForChild("MainFrame", 10)
if mainFrame then
	local closeBtn = mainFrame:FindFirstChild("Header") and mainFrame.Header:FindFirstChild("CloseButton")
	if closeBtn then attachButton(closeBtn, { sound = SND_CLOSE, hoverScale = 1.08 }) end

	-- Tabs
	local tabs = mainFrame:FindFirstChild("Tabs")
	if tabs then
		for _,tab in ipairs(tabs:GetChildren()) do
			if tab:IsA("GuiButton") then attachButton(tab, { hoverScale = 1.05 }) end
		end
	end

	-- DetailPanel
	local dp = mainFrame:FindFirstChild("Body") and mainFrame.Body:FindFirstChild("DetailPanel")
	if dp then
		local ab = dp:FindFirstChild("ActionButton")
		if ab then attachButton(ab, { hoverScale = 1.02 }) end
		local sb = dp:FindFirstChild("SecondaryButton")
		if sb then attachButton(sb, { hoverScale = 1.02 }) end
	end
end

-- === CratePanel ===
local cratePanel = hud:WaitForChild("CratePanel", 10)
if cratePanel then
	for _,name in ipairs({ "Buy", "Open", "ViewOdds", "Receipt" }) do
		local b = cratePanel:FindFirstChild(name)
		if b then attachButton(b, { hoverScale = 1.03 }) end
	end
	local c = cratePanel:FindFirstChild("Close")
	if c then attachButton(c, { sound = SND_CLOSE, hoverScale = 1.1 }) end
	-- X1 / X5 / X10
	local sel = cratePanel:FindFirstChild("OpenQuantities")
	if sel then
		for _,btn in ipairs(sel:GetChildren()) do
			if btn:IsA("TextButton") then attachButton(btn, { hoverScale = 1.06 }) end
		end
	end
end

-- === CrateSpinPanel ===
local spinPanel = hud:WaitForChild("CrateSpinPanel", 10)
if spinPanel then
	local c = spinPanel:FindFirstChild("Close")
	if c then attachButton(c, { sound = SND_CLOSE, hoverScale = 1.05 }) end
end

-- === Product cards (dinamicas) ===
local catalog = mainFrame and mainFrame:FindFirstChild("Body") and mainFrame.Body:FindFirstChild("Catalog")
if catalog then
	local function bindCard(card)
		if card.Name == "ProductCardTemplate" then return end
		if card:IsA("TextButton") then attachButton(card, { hoverScale = 1.025 }) end
	end
	for _,child in ipairs(catalog:GetChildren()) do bindCard(child) end
	catalog.ChildAdded:Connect(bindCard)
end

-- === CardAccent sigue el color de rareza (basado en el stroke del preview) ===
local function syncAccent(card)
	local accent = card:FindFirstChild("CardAccent")
	local preview = card:FindFirstChild("Preview")
	if not accent or not preview then return end
	local st = preview:FindFirstChildOfClass("UIStroke")
	if st then
		accent.BackgroundColor3 = st.Color
	end
end

if catalog then
	local function hookCard(card)
		if not card:IsA("TextButton") or card.Name == "ProductCardTemplate" then return end
		syncAccent(card)
		local preview = card:FindFirstChild("Preview")
		if preview then
			local st = preview:FindFirstChildOfClass("UIStroke")
			if st then
				st:GetPropertyChangedSignal("Color"):Connect(function() syncAccent(card) end)
			end
		end
	end
	for _, child in ipairs(catalog:GetChildren()) do hookCard(child) end
	catalog.ChildAdded:Connect(function(c) task.wait(0.05); hookCard(c) end)
end

-- === Glow en la tab activa (detecta el cambio de BackgroundColor a ActiveColor) ===
local tabsFrame = mainFrame and mainFrame:FindFirstChild("Tabs")
if tabsFrame then
	local activeColor = tabsFrame:GetAttribute("ActiveColor")
	for _, tab in ipairs(tabsFrame:GetChildren()) do
		if tab:IsA("GuiButton") then
			local s = tab:FindFirstChild("TabStroke")
			tab:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
				if not s then return end
				local isActive = activeColor and tab.BackgroundColor3 == activeColor
				TweenService:Create(s, TweenInfo.new(0.15), {
					Color = isActive and Color3.fromRGB(34, 211, 238) or Color3.fromRGB(44, 62, 99),
					Thickness = isActive and 2.2 or 1.5,
					Transparency = isActive and 0 or 0.4,
				}):Play()
			end)
		end
	end
end

-- === Overlay de atenuacion detras del panel (no bloquea input) ===
local dim = hud:FindFirstChild("DimBackground")
if dim and mainFrame then
	local TWEEN_DIM = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local function applyDim(visible)
		if visible then
			dim.Visible = true
			TweenService:Create(dim, TWEEN_DIM, { BackgroundTransparency = 0.4 }):Play()
		else
			local tw = TweenService:Create(dim, TWEEN_DIM, { BackgroundTransparency = 1 })
			tw.Completed:Once(function() if mainFrame.Visible == false then dim.Visible = false end end)
			tw:Play()
		end
	end
	applyDim(mainFrame.Visible)
	mainFrame:GetPropertyChangedSignal("Visible"):Connect(function() applyDim(mainFrame.Visible) end)
end

print("[UIEffects] HUD de tienda con efectos listo")