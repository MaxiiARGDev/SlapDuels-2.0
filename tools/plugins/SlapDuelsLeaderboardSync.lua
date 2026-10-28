-- SlapDuels Leaderboard Sync Studio Plugin
-- Sincroniza automáticamente StarterGui.LeaderboardScreen_Template con las 3 pantallas físicas 3D en Workspace.stands["TOPS-SCREENS"]:
-- 1. Screen_TopWins (🏆 TOP VICTORIAS)
-- 2. Screen_TopKills (💀 TOP ELIMINACIONES)
-- 3. Screen_TopRachas (🔥 TOP RACHAS)

local StarterGui = game:GetService("StarterGui")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local toolbar = plugin:CreateToolbar("SlapDuels Leaderboard")
local syncButton = toolbar:CreateButton(
    "Sync Leaderboards",
    "Sincroniza el diseño 2D de StarterGui con las 3 pantallas físicas 3D de TOPS-SCREENS",
    "rbxassetid://74257339735840"
)
syncButton.ClickableWhenViewportHidden = true

local isSyncing = false
local pendingSync = false

local SCREENS = {
    {
        ModelName = "TopWins",
        PartName = "Screen_TopWins",
        GuiName = "SurfaceGui_TopWins",
        Title = "🏆 TOP VICTORIAS",
        Subtitle = "TOP 50 GLOBAL - WINS",
        StatCol = "VICTORIAS",
        IconAll = "Top_All_Wins",
        DefaultStat = "2,500",
    },
    {
        ModelName = "TopKills",
        PartName = "Screen_TopKills",
        GuiName = "SurfaceGui_TopKills",
        Title = "💀 TOP ELIMINACIONES",
        Subtitle = "TOP 50 GLOBAL - KILLS",
        StatCol = "ELIMINACIONES",
        IconAll = "Top_All_Kills",
        DefaultStat = "8,400",
    },
    {
        ModelName = "TopRachas",
        PartName = "Screen_TopRachas",
        GuiName = "SurfaceGui_TopRachas",
        Title = "🔥 TOP RACHAS",
        Subtitle = "3 VICTORIAS = 1 RACHA",
        StatCol = "RACHAS",
        IconAll = "Top_All_Streak",
        DefaultStat = "450",
    },
}

local function syncAllLeaderboards()
    if isSyncing then
        pendingSync = true
        return
    end
    isSyncing = true

    local success, err = pcall(function()
        local sourceGui = StarterGui:FindFirstChild("LeaderboardScreen_Template")
        if not sourceGui then return end
        local sourceMainFrame = sourceGui:FindFirstChild("MainFrame")
        if not sourceMainFrame then return end

        local stands = Workspace:FindFirstChild("stands") and Workspace.stands:FindFirstChild("TOPS-SCREENS")
        if not stands then return end

        local iconsFolder = ServerStorage:FindFirstChild("Assets") and ServerStorage.Assets:FindFirstChild("Icons")
        local iconTop1 = iconsFolder and iconsFolder:FindFirstChild("Top_1")
        local iconTop2 = iconsFolder and iconsFolder:FindFirstChild("Top_2")
        local iconTop3 = iconsFolder and iconsFolder:FindFirstChild("Top_3")

        for _, cfg in ipairs(SCREENS) do
            local model = stands:FindFirstChild(cfg.ModelName)
            local part = model and model:FindFirstChild(cfg.PartName)
            local surfaceGui = part and part:FindFirstChild(cfg.GuiName)

            if surfaceGui then
                local iconTopAll = iconsFolder and iconsFolder:FindFirstChild(cfg.IconAll)
                local newFrame = sourceMainFrame:Clone()
                newFrame.Size = UDim2.new(1, 0, 1, 0)
                newFrame.Position = UDim2.new(0, 0, 0, 0)
                newFrame.AnchorPoint = Vector2.new(0, 0)

                -- 1. Actualizar Encabezado
                local header = newFrame:FindFirstChild("Header")
                if header then
                    local titleLbl = header:FindFirstChild("Title")
                    if titleLbl and titleLbl:IsA("TextLabel") then
                        titleLbl.Text = cfg.Title
                    end
                    local subLbl = header:FindFirstChild("Subtitle")
                    if subLbl and subLbl:IsA("TextLabel") then
                        subLbl.Text = cfg.Subtitle
                    end
                end

                -- 2. Actualizar Leyenda de columna
                local legend = newFrame:FindFirstChild("Legend")
                if legend then
                    local statColLbl = legend:FindFirstChild("StatColumn")
                    if statColLbl and statColLbl:IsA("TextLabel") then
                        statColLbl.Text = cfg.StatCol
                    end
                end

                -- 3. Actualizar Íconos del ScrollingFrame
                local scroll = newFrame:FindFirstChild("ScrollList")
                if scroll then
                    for _, child in ipairs(scroll:GetChildren()) do
                        if child:IsA("Frame") and child:FindFirstChild("IconTop") then
                            local s2 = child:FindFirstChild("Separator2")
                            if s2 then s2:Destroy() end
                            local rank = child.LayoutOrder
                            local targetIcon = iconTopAll
                            if rank == 1 and iconTop1 then targetIcon = iconTop1
                            elseif rank == 2 and iconTop2 then targetIcon = iconTop2
                            elseif rank == 3 and iconTop3 then targetIcon = iconTop3
                            end

                            if targetIcon and targetIcon:IsA("ImageLabel") then
                                local iconTop = child.IconTop
                                iconTop.Image = targetIcon.Image
                                iconTop.ImageColor3 = targetIcon.ImageColor3
                                iconTop.ImageRectOffset = targetIcon.ImageRectOffset
                                iconTop.ImageRectSize = targetIcon.ImageRectSize
                            end
                        end
                    end
                end

                -- 4. Reemplazar MainFrame viejo por el nuevo
                local oldFrame = surfaceGui:FindFirstChild("MainFrame")
                if oldFrame then
                    oldFrame:Destroy()
                end
                newFrame.Parent = surfaceGui
            end
        end
    end)

    if not success then
        warn("[SlapDuelsLeaderboardSync] Error sincronizando:", err)
    end

    isSyncing = false
    if pendingSync then
        pendingSync = false
        task.defer(syncAllLeaderboards)
    end
end

syncButton.Click:Connect(function()
    syncAllLeaderboards()
    print("[SlapDuels] Las 3 pantallas de Tops fueron sincronizadas exitosamente.")
end)

-- Auto-Watcher en tiempo de edición
local debounceTimer = nil
local function requestSync()
    if debounceTimer then return end
    debounceTimer = task.delay(0.3, function()
        debounceTimer = nil
        syncAllLeaderboards()
    end)
end

local function hookGui()
    local targetGui = StarterGui:FindFirstChild("LeaderboardScreen_Template")
    if not targetGui then return end
    targetGui.DescendantAdded:Connect(requestSync)
    targetGui.DescendantRemoving:Connect(requestSync)
    for _, desc in ipairs(targetGui:GetDescendants()) do
        if desc:IsA("GuiObject") or desc:IsA("UIComponent") then
            desc.Changed:Connect(function(prop)
                if prop ~= "AbsoluteSize" and prop ~= "AbsolutePosition" then
                    requestSync()
                end
            end)
        end
    end
end

local function hookIcons()
    local iconsFolder = ServerStorage:FindFirstChild("Assets") and ServerStorage.Assets:FindFirstChild("Icons")
    if not iconsFolder then return end
    iconsFolder.DescendantAdded:Connect(requestSync)
    iconsFolder.DescendantRemoving:Connect(requestSync)
    for _, icon in ipairs(iconsFolder:GetChildren()) do
        if icon:IsA("ImageLabel") then
            icon.Changed:Connect(requestSync)
        end
    end
end

hookGui()
hookIcons()
StarterGui.ChildAdded:Connect(function(ch)
    if ch.Name == "LeaderboardScreen_Template" then
        hookGui()
        requestSync()
    end
end)

print("[SlapDuels] Plugin de sincronización de Leaderboard activo para Wins, Kills y Rachas.")
