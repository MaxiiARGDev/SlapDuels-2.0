local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local card = script.Parent
local hud = card:FindFirstAncestorOfClass("ScreenGui")
local vpArea = card:WaitForChild("ViewportArea")
local vp = vpArea:WaitForChild("ItemViewport")
local coinImg = vpArea:WaitForChild("CoinImage")
local effectImg = vpArea:WaitForChild("EffectPlaceholder")
local rewardLbl = card:WaitForChild("Reward")
local claimBtn = card:WaitForChild("Claim")
local hScale = card:WaitForChild("HoverScale")
local stroke = card:FindFirstChildOfClass("UIStroke")
local spotlight = vpArea:WaitForChild("Spotlight")

local camera = vp:FindFirstChildOfClass("Camera")
if not camera then
    camera = Instance.new("Camera")
    camera.Parent = vp
end
vp.CurrentCamera = camera

local previews = RS:WaitForChild("CrateRewardPreviews", 10)
local currentModel = nil

local function cleanup3D()
    if currentModel then
        currentModel:Destroy()
        currentModel = nil
    end
end

local function getModelForLabel(text)
    if not previews then return nil end
    local lower = string.lower(text)
    if string.find(lower, "chancla") then
        return previews:FindFirstChild("Chancla")
    elseif string.find(lower, "classic") then
        return previews:FindFirstChild("Classic")
    elseif string.find(lower, "pingpong") then
        return previews:FindFirstChild("PingPong")
    end
    return nil
end

local function setupStatic3DModel(sourceModel)
    cleanup3D()
    if not sourceModel then return end
    
    currentModel = sourceModel:Clone()
    currentModel.Parent = vp
    
    local cf, size = currentModel:GetBoundingBox()
    local maxDim = math.max(size.X, size.Y, size.Z)
    local dist = maxDim * 1.55
    
    camera.FieldOfView = 50
    camera.CFrame = CFrame.new(cf.Position + Vector3.new(0, maxDim * 0.15, dist), cf.Position)
    
    -- STATIC 3D orientation (NO ROTATION)
    currentModel:PivotTo(cf * CFrame.Angles(math.rad(10), math.rad(30), 0))
end

local function onRewardChanged()
    local text = rewardLbl.Text
    local lower = string.lower(text)
    
    -- 1. Coins -> 2D Coin Texture
    if string.find(lower, "coin") then
        cleanup3D()
        vp.Visible = false
        effectImg.Visible = false
        coinImg.Visible = true
        if stroke then stroke.Color = Color3.fromHex("FFD000") end
        spotlight.ImageColor3 = Color3.fromHex("FFD000")
        return
    end
    
    -- 2. Point Effects -> Placeholder Texture
    if string.find(lower, "punto") then
        cleanup3D()
        vp.Visible = false
        coinImg.Visible = false
        effectImg.Image = "rbxassetid://123068502871010"
        effectImg.Visible = true
        if stroke then stroke.Color = Color3.fromHex("FF8500") end
        spotlight.ImageColor3 = Color3.fromHex("FF8500")
        return
    end
    
    -- 3. Death / Kill Effects -> Placeholder Texture
    if string.find(lower, "muerte") or string.find(lower, "kill") or string.find(lower, "death") then
        cleanup3D()
        vp.Visible = false
        coinImg.Visible = false
        effectImg.Image = "rbxassetid://84058950298471"
        effectImg.Visible = true
        if stroke then stroke.Color = Color3.fromHex("B5179E") end
        spotlight.ImageColor3 = Color3.fromHex("B5179E")
        return
    end
    
    -- 4. 3D Slap / Weapon Models (Static)
    coinImg.Visible = false
    effectImg.Visible = false
    vp.Visible = true
    
    local src = getModelForLabel(text)
    if src then
        setupStatic3DModel(src)
    else
        cleanup3D()
        vp.Visible = false
        effectImg.Image = "rbxassetid://123068502871010"
        effectImg.Visible = true
    end
    
    if string.find(lower, "gold") or string.find(lower, "epic") or string.find(lower, "arcoiris") then
        if stroke then stroke.Color = Color3.fromHex("FFAA00") end
        spotlight.ImageColor3 = Color3.fromHex("FFAA00")
    elseif string.find(lower, "rare") or string.find(lower, "pingpong") then
        if stroke then stroke.Color = Color3.fromHex("00D4FF") end
        spotlight.ImageColor3 = Color3.fromHex("00D4FF")
    else
        if stroke then stroke.Color = Color3.fromHex("303548") end
        spotlight.ImageColor3 = Color3.fromHex("4361EE")
    end
end

rewardLbl:GetPropertyChangedSignal("Text"):Connect(onRewardChanged)
task.defer(onRewardChanged)

local function onClaimStateChanged()
    local t = claimBtn.Text
    local cbGrad = claimBtn:FindFirstChildOfClass("UIGradient")
    local cbStroke = claimBtn:FindFirstChildOfClass("UIStroke")
    
    if t == "RECLAMADO" then
        claimBtn.BackgroundColor3 = Color3.fromHex("1E222D")
        claimBtn.TextColor3 = Color3.fromHex("64748B")
        if cbGrad then
            cbGrad.Color = ColorSequence.new(Color3.fromHex("252A38"), Color3.fromHex("151821"))
        end
        if cbStroke then cbStroke.Color = Color3.fromHex("181C26") end
    elseif t == "BLOQUEADO" or t == "FINALIZADO" then
        claimBtn.BackgroundColor3 = Color3.fromHex("181A22")
        claimBtn.TextColor3 = Color3.fromHex("475569")
        if cbGrad then
            cbGrad.Color = ColorSequence.new(Color3.fromHex("1E212B"), Color3.fromHex("12141A"))
        end
        if cbStroke then cbStroke.Color = Color3.fromHex("101217") end
    else
        claimBtn.BackgroundColor3 = Color3.fromHex("2E7D32")
        claimBtn.TextColor3 = Color3.fromHex("FFFFFF")
        if cbGrad then
            cbGrad.Color = ColorSequence.new(Color3.fromHex("4CAF50"), Color3.fromHex("2E7D32"))
        end
        if cbStroke then cbStroke.Color = Color3.fromHex("123815") end
    end
end

claimBtn:GetPropertyChangedSignal("Text"):Connect(onClaimStateChanged)
task.defer(onClaimStateChanged)

card.MouseEnter:Connect(function()
    local sHover = hud and hud:FindFirstChild("Sounds") and hud.Sounds:FindFirstChild("Hover")
    if sHover then sHover:Play() end
    TweenService:Create(hScale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.05}):Play()
end)

card.MouseLeave:Connect(function()
    TweenService:Create(hScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = 1.0}):Play()
end)
