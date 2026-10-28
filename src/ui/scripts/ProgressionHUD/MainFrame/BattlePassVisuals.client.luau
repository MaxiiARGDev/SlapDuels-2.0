local RS = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local main = script.Parent
local hud = main:FindFirstAncestorOfClass("ScreenGui")
local winScale = main:WaitForChild("WindowScale")
local closeBtn = main:WaitForChild("Close")
local heroShowcase = main:WaitForChild("HeroShowcase")
local heroVp = heroShowcase:WaitForChild("HeroViewport")
local heroCoinImg = heroShowcase:WaitForChild("HeroCoinImage")
local heroEffectImg = heroShowcase:WaitForChild("HeroEffectPlaceholder")
local heroTag = heroShowcase:WaitForChild("HeroTag")
local heroLabel = heroTag:WaitForChild("HeroLabel")
local heroCost = heroTag:WaitForChild("HeroCost")
local heroRays = heroShowcase:WaitForChild("Rays")
local rewardsScroll = main:WaitForChild("Rewards")
local sounds = hud and hud:WaitForChild("Sounds", 10)

local sHover = sounds and sounds:FindFirstChild("Hover")
local sClick = sounds and sounds:FindFirstChild("Click")
local sOpen = sounds and sounds:FindFirstChild("Open")
local sClaim = sounds and sounds:FindFirstChild("Claim")

local heroCamera = heroVp:FindFirstChildOfClass("Camera")
if not heroCamera then
    heroCamera = Instance.new("Camera")
    heroCamera.Parent = heroVp
end
heroVp.CurrentCamera = heroCamera

local previews = RS:WaitForChild("CrateRewardPreviews", 10)
local currentHeroModel = nil

-- Thoroughly purges any existing models or parts from HeroViewport
local function cleanupHero3D()
    for _, child in ipairs(heroVp:GetChildren()) do
        if child:IsA("Model") or child:IsA("BasePart") then
            child:Destroy()
        end
    end
    currentHeroModel = nil
end

local function play(snd, pitch)
    if not snd then return end
    local c = snd:Clone()
    if pitch then c.PlaybackSpeed = snd.PlaybackSpeed + (math.random() - 0.5) * pitch end
    c.Parent = snd.Parent
    c:Play()
    c.Ended:Once(function() c:Destroy() end)
end

-- Displays an item (Coins: 2D texture, Effects: placeholder texture, Slaps: static 3D model)
local function showItem(itemText, costText, stageText)
    heroLabel.Text = itemText or "Recompensa"
    local costInfo = ""
    if stageText and stageText ~= "" then
        costInfo = stageText .. "  ·  "
    end
    costInfo = costInfo .. (costText or "")
    heroCost.Text = costInfo
    
    local lower = string.lower(itemText or "")
    
    -- 1. Coins -> 2D Coin Texture
    if string.find(lower, "coin") then
        cleanupHero3D()
        heroVp.Visible = false
        heroEffectImg.Visible = false
        heroCoinImg.Visible = true
        return
    end
    
    -- 2. Point Effects -> Placeholder Texture
    if string.find(lower, "punto") then
        cleanupHero3D()
        heroVp.Visible = false
        heroCoinImg.Visible = false
        heroEffectImg.Image = "rbxassetid://123068502871010"
        heroEffectImg.Visible = true
        return
    end
    
    -- 3. Death / Kill Effects -> Placeholder Texture
    if string.find(lower, "muerte") or string.find(lower, "kill") or string.find(lower, "death") then
        cleanupHero3D()
        heroVp.Visible = false
        heroCoinImg.Visible = false
        heroEffectImg.Image = "rbxassetid://84058950298471"
        heroEffectImg.Visible = true
        return
    end
    
    -- 4. 3D Slap / Weapon Models (STATIC, NO ROTATION, CENTERED & FITTED)
    heroCoinImg.Visible = false
    heroEffectImg.Visible = false
    cleanupHero3D()
    
    local modelName = nil
    if string.find(lower, "chancla") then
        modelName = "Chancla"
    elseif string.find(lower, "classic") then
        modelName = "Classic"
    elseif string.find(lower, "pingpong") then
        modelName = "PingPong"
    end
    
    local source = previews and modelName and previews:FindFirstChild(modelName)
    if source then
        heroVp.Visible = true
        currentHeroModel = source:Clone()
        currentHeroModel.Parent = heroVp
        
        -- Geometric origin centering
        local origCf = currentHeroModel:GetBoundingBox()
        currentHeroModel:PivotTo(CFrame.new(-origCf.Position) * currentHeroModel:GetPivot())
        
        -- Static 3D orientation
        local rot = CFrame.Angles(math.rad(10), math.rad(28), 0)
        currentHeroModel:PivotTo(rot * currentHeroModel:GetPivot())
        
        -- Frustum calculation for perfect framing without clipping
        local finalCf, finalSize = currentHeroModel:GetBoundingBox()
        local fov = 40
        heroCamera.FieldOfView = fov
        local halfFovRad = math.rad(fov / 2)
        local tanHalfFov = math.tan(halfFovRad)
        
        local vpSize = heroVp.AbsoluteSize
        local aspect = (vpSize.X > 0 and vpSize.Y > 0) and (vpSize.X / vpSize.Y) or 1
        
        local distY = (finalSize.Y / 2) / tanHalfFov
        local distX = (finalSize.X / 2) / (tanHalfFov * math.min(aspect, 1.5))
        local distZ = (finalSize.Z / 2) / tanHalfFov
        local reqDist = math.max(distY, distX, distZ) * 1.35 -- 35% safe margin
        
        heroCamera.CFrame = CFrame.new(finalCf.Position + Vector3.new(0, 0, reqDist), finalCf.Position)
    else
        heroVp.Visible = false
        heroEffectImg.Image = "rbxassetid://123068502871010"
        heroEffectImg.Visible = true
    end
end

-- Default showcase item
task.defer(function()
    showItem("Chancla:Common", "300 EXP", "ETAPA 3")
end)

-- Window Open Animation
main:GetPropertyChangedSignal("Visible"):Connect(function()
    if main.Visible then
        play(sOpen)
        winScale.Scale = 0.75
        TweenService:Create(winScale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1.0}):Play()
    end
end)

closeBtn.MouseEnter:Connect(function() play(sHover, 0.1) end)
closeBtn.MouseButton1Down:Connect(function() play(sClick) end)

local claimAllBtn = main:WaitForChild("ClaimAll")
claimAllBtn.MouseEnter:Connect(function() play(sHover, 0.1) end)
claimAllBtn.MouseButton1Down:Connect(function()
    play(sClick)
    play(sClaim)
end)

-- Bind hover & selection on reward cards
local function bindCard(card)
    if card:IsA("Frame") and card:FindFirstChild("Reward") then
        local rw = card:WaitForChild("Reward")
        local cost = card:WaitForChild("Cost")
        local stage = card:WaitForChild("Stage")
        
        card.MouseEnter:Connect(function()
            showItem(rw.Text, cost.Text, stage.Text)
        end)
        
        card.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                showItem(rw.Text, cost.Text, stage.Text)
            end
        end)
    end
end

for _, c in ipairs(rewardsScroll:GetChildren()) do
    bindCard(c)
end
rewardsScroll.ChildAdded:Connect(bindCard)
