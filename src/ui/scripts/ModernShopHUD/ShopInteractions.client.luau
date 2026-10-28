--!strict
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local gui = script.Parent :: ScreenGui
local window = gui:WaitForChild("MainWindow") :: Frame
local winScale = window:WaitForChild("WindowScale") :: UIScale
local dim = gui:WaitForChild("DimBackground") :: Frame
local header = window:WaitForChild("Header") :: Frame
local closeBtn = header:WaitForChild("CloseButton") :: ImageButton
local closeFace = closeBtn:WaitForChild("Face") :: Frame
local scroll = window:WaitForChild("ContentScroll") :: ScrollingFrame
local sidebar = window:WaitForChild("Sidebar") :: Frame
local sounds = gui:WaitForChild("Sounds") :: Folder

local sHover = sounds:WaitForChild("Hover") :: Sound
local sClick = sounds:WaitForChild("Click") :: Sound
local sOpen = sounds:WaitForChild("Open") :: Sound
local sBuy = sounds:WaitForChild("Buy") :: Sound
local sClose = sounds:WaitForChild("Close") :: Sound

local function play(snd: Sound, pitchVariation: number?)
    local clone = snd:Clone()
    if pitchVariation then
        clone.PlaybackSpeed = snd.PlaybackSpeed + (math.random() - 0.5) * pitchVariation
    end
    clone.Parent = snd.Parent
    clone:Play()
    clone.Ended:Once(function()
        clone:Destroy()
    end)
end

-- Tween presets
local tSpringFast = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local tSpringSoft = TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local tSmooth = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local tPress = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- 1. Window Open / Close Animations
local function openWindow()
    gui.Enabled = true
    winScale.Scale = 0.75
    dim.BackgroundTransparency = 1
    play(sOpen)
    TweenService:Create(winScale, tSpringSoft, {Scale = 1.0}):Play()
    TweenService:Create(dim, tSmooth, {BackgroundTransparency = 0.45}):Play()
end

local function closeWindow()
    play(sClose)
    local tOut = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
    local twScale = TweenService:Create(winScale, tOut, {Scale = 0.75})
    local twDim = TweenService:Create(dim, tOut, {BackgroundTransparency = 1})
    twScale:Play()
    twDim:Play()
    twScale.Completed:Once(function()
        gui.Enabled = false
        winScale.Scale = 1.0
    end)
end

-- Close button interactions
closeBtn.MouseEnter:Connect(function()
    play(sHover, 0.08)
    TweenService:Create(closeFace, tSmooth, {Position = UDim2.new(0, 0, 0, -2)}):Play()
end)
closeBtn.MouseLeave:Connect(function()
    TweenService:Create(closeFace, tSmooth, {Position = UDim2.new(0, 0, 0, 0)}):Play()
end)
closeBtn.MouseButton1Down:Connect(function()
    play(sClick)
    TweenService:Create(closeFace, tPress, {Position = UDim2.new(0, 0, 0, 4)}):Play()
end)
closeBtn.MouseButton1Up:Connect(function()
    TweenService:Create(closeFace, tSmooth, {Position = UDim2.new(0, 0, 0, -2)}):Play()
end)
closeBtn.Activated:Connect(closeWindow)

-- 2. Sidebar Tab Interactions & Navigation
local tabs = {}
for _, child in ipairs(sidebar:GetChildren()) do
    if child:IsA("ImageButton") then
        table.insert(tabs, child)
    end
end

local function selectTab(activeTab: ImageButton)
    for _, tab in ipairs(tabs) do
        local hScale = tab:FindFirstChild("HoverScale") :: UIScale?
        local stroke = tab:FindFirstChildOfClass("UIStroke")
        local lbl = tab:FindFirstChild("Label") :: TextLabel?
        
        if tab == activeTab then
            tab.BackgroundColor3 = Color3.fromHex("1E2230")
            if not stroke then
                local st = Instance.new("UIStroke")
                st.Thickness = 2
                st.Color = Color3.fromHex("3D455C")
                st.Parent = tab
            else
                stroke.Color = Color3.fromHex("3D455C")
            end
            if lbl then
                lbl.TextColor3 = Color3.fromHex("FFFFFF")
            end
            if hScale then
                TweenService:Create(hScale, tSpringFast, {Scale = 1.05}):Play()
            end
        else
            tab.BackgroundColor3 = Color3.fromHex("13151D")
            if stroke then
                stroke.Color = Color3.fromHex("1B1D25")
            end
            if lbl then
                lbl.TextColor3 = Color3.fromHex("7A8094")
            end
            if hScale then
                TweenService:Create(hScale, tSmooth, {Scale = 1.0}):Play()
            end
        end
    end
end

for _, tab in ipairs(tabs) do
    local hScale = tab:FindFirstChild("HoverScale") :: UIScale?
    
    tab.MouseEnter:Connect(function()
        play(sHover, 0.1)
        if hScale and tab.BackgroundColor3 ~= Color3.fromHex("1E2230") then
            TweenService:Create(hScale, tSmooth, {Scale = 1.03}):Play()
        end
    end)
    tab.MouseLeave:Connect(function()
        if hScale and tab.BackgroundColor3 ~= Color3.fromHex("1E2230") then
            TweenService:Create(hScale, tSmooth, {Scale = 1.0}):Play()
        end
    end)
    tab.Activated:Connect(function()
        play(sClick)
        selectTab(tab)
        
        -- Smooth scroll depending on tab
        if tab.Name == "MonedaTab" then
            local coinsHeader = scroll:FindFirstChild("SectionHeader_Moneda") :: GuiObject?
            if coinsHeader then
                TweenService:Create(scroll, tSmooth, {CanvasPosition = Vector2.new(0, math.max(0, coinsHeader.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y - 8))}):Play()
            end
        else
            TweenService:Create(scroll, tSmooth, {CanvasPosition = Vector2.new(0, 0)}):Play()
        end
    end)
end

-- 3. Cards Hover & Action Animations
local cratesRow = scroll:WaitForChild("CratesRow")
for _, card in ipairs(cratesRow:GetChildren()) do
    if card:IsA("Frame") then
        local hScale = card:FindFirstChild("HoverScale") :: UIScale?
        local stroke = card:FindFirstChildOfClass("UIStroke")
        local baseThickness = stroke and stroke.Thickness or 2.5
        local baseColor = stroke and stroke.Color or Color3.new(1, 1, 1)
        
        local artArea = card:FindFirstChild("ArtArea")
        local crateImg = artArea and artArea:FindFirstChild("CrateImage") :: ImageLabel?
        
        -- Floating / Breathing animation for crate image
        if crateImg then
            local origPos = crateImg.Position
            task.spawn(function()
                local t = math.random() * 10
                while card.Parent do
                    t = t + RunService.RenderStepped:Wait() * 2
                    local offset = math.sin(t) * 3
                    crateImg.Position = UDim2.new(origPos.X.Scale, origPos.X.Offset, origPos.Y.Scale, origPos.Y.Offset + offset)
                end
            end)
        end
        
        card.MouseEnter:Connect(function()
            play(sHover, 0.08)
            if hScale then
                TweenService:Create(hScale, tSpringFast, {Scale = 1.035}):Play()
            end
            if stroke then
                TweenService:Create(stroke, tSmooth, {Thickness = baseThickness + 1.2}):Play()
            end
        end)
        
        card.MouseLeave:Connect(function()
            if hScale then
                TweenService:Create(hScale, tSmooth, {Scale = 1.0}):Play()
            end
            if stroke then
                TweenService:Create(stroke, tSmooth, {Thickness = baseThickness}):Play()
            end
        end)
        
        -- Ver button inside card
        local verBtn = card:FindFirstChild("VerButton") :: ImageButton?
        if verBtn then
            local face = verBtn:FindFirstChild("Face") :: Frame?
            verBtn.MouseEnter:Connect(function()
                play(sHover, 0.12)
                if face then
                    TweenService:Create(face, tSmooth, {Position = UDim2.new(0, 0, 0, -2)}):Play()
                end
            end)
            verBtn.MouseLeave:Connect(function()
                if face then
                    TweenService:Create(face, tSmooth, {Position = UDim2.new(0, 0, 0, 0)}):Play()
                end
            end)
            verBtn.MouseButton1Down:Connect(function()
                play(sClick)
                if face then
                    TweenService:Create(face, tPress, {Position = UDim2.new(0, 0, 0, 4)}):Play()
                end
            end)
            verBtn.MouseButton1Up:Connect(function()
                if face then
                    TweenService:Create(face, tSmooth, {Position = UDim2.new(0, 0, 0, -2)}):Play()
                end
            end)
            verBtn.Activated:Connect(function()
                play(sBuy)
                -- Subtle success pulse on button
                local btnScale = verBtn:FindFirstChild("BtnScale") or Instance.new("UIScale")
                btnScale.Name = "BtnScale"
                btnScale.Parent = verBtn
                btnScale.Scale = 0.92
                TweenService:Create(btnScale, tSpringSoft, {Scale = 1.0}):Play()
            end)
        end
    end
end

-- 4. Offers Banners Hover & Click Animations
local coinsRow = scroll:WaitForChild("CoinsRow")
for _, banner in ipairs(coinsRow:GetChildren()) do
    if banner:IsA("Frame") then
        local hScale = banner:FindFirstChild("HoverScale") :: UIScale?
        banner.MouseEnter:Connect(function()
            play(sHover, 0.08)
            if hScale then
                TweenService:Create(hScale, tSpringFast, {Scale = 1.03}):Play()
            end
        end)
        banner.MouseLeave:Connect(function()
            if hScale then
                TweenService:Create(hScale, tSmooth, {Scale = 1.0}):Play()
            end
        end)
        
        -- Pulse on ¡MEJOR OFERTA! tag
        local tag = banner:FindFirstChild("BestOfferTag") :: Frame?
        if tag then
            local tagScale = Instance.new("UIScale")
            tagScale.Parent = tag
            task.spawn(function()
                while banner.Parent do
                    TweenService:Create(tagScale, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Scale = 1.08}):Play()
                    task.wait(0.6)
                    TweenService:Create(tagScale, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Scale = 0.95}):Play()
                    task.wait(0.6)
                end
            end)
        end
    end
end
