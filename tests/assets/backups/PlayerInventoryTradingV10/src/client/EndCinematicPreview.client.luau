--!nonstrict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Config = require(game.ReplicatedStorage.Shared.EndCinematicConfig)
if not RunService:IsStudio() or not Config.Preview.Enabled then return end
local player = Players.LocalPlayer
local controller = require(script.Parent.Controllers.EndCinematicController)
controller:Initialize()
local gui = Instance.new("ScreenGui")
gui.Name = "EndCinematicPreview"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10001
gui.Parent = player:WaitForChild("PlayerGui")
local frame = Instance.new("Frame")
frame.Position = UDim2.new(0, 12, 0.28, 0)
frame.Size = UDim2.fromOffset(210, 344)
frame.BackgroundColor3 = Color3.fromRGB(15, 18, 30)
frame.Parent = gui
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = frame
local nextButtonOrder=0
local function button(text, callback)
	local b = Instance.new("TextButton")
	b.Name = text:gsub("[^%w]+", "_")
	nextButtonOrder+=1
	b.LayoutOrder=nextButtonOrder
	b.Size = UDim2.new(1, 0, 0, 34)
	b.Text = text
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.TextColor3 = Color3.new(1, 1, 1)
	b.BackgroundColor3 = Color3.fromRGB(37, 42, 65)
	b.Parent = frame
	b.Activated:Connect(callback)
	return b
end
local team = "Red"
local count = 1
local mode = "1v1"
local floatingEnabled,billboardsEnabled=true,true
local previewSerial = 0
local function cancel()
	previewSerial += 1
	controller:Stop()
end
local function play(n, selectedMode)
	mode = selectedMode or mode
	count = n
	cancel()
	local serial = previewSerial
	local remote = game.ReplicatedStorage.Remotes.Match:WaitForChild("EndCinematicPreview", 5)
	if not remote then warn("[EndCinematicPreview] Studio preview remote missing"); return end
	local success, descriptor = pcall(function() return remote:InvokeServer("Prepare") end)
	if not success or type(descriptor) ~= "table" then warn("[EndCinematicPreview] Scene denied or unavailable"); return end
	local released = false
	local function release()
		if released then return end
		released = true
		task.spawn(function() pcall(function() remote:InvokeServer("Release", descriptor.Name) end) end)
	end
	local deadline = os.clock() + Config.Results.SceneWaitTimeout
	task.spawn(function() pcall(function() player:RequestStreamAroundAsync(descriptor.Origin, Config.Results.SceneWaitTimeout) end) end)
	local scene
	repeat
		local folder = workspace:FindFirstChild("EndCinematicPreviews")
		scene = folder and folder:FindFirstChild(descriptor.Name)
		local cameras = scene and scene:FindFirstChild("TransCamera")
		local slots = scene and scene:FindFirstChild("Players")
		local complete = scene ~= nil and cameras ~= nil and slots ~= nil and scene:GetAttribute("PreviewOwnerUserId") == player.UserId
		for _, name in { "CameraCheck-v1", "CameraCheck-v2", "CameraCheck-Only1V1" } do
			complete = complete and cameras:FindFirstChild(name) ~= nil
		end
		for index = 1, 5 do complete = complete and slots:FindFirstChild("SlotPlayer_" .. index) ~= nil end
		if complete then break end
		scene = nil
		task.wait(.05)
	until serial ~= previewSerial or os.clock() >= deadline
	if serial ~= previewSerial or not scene or player:GetAttribute("MatchId") ~= nil then release(); return end
	local winners = {}
	local participants = {}
	local available = Players:GetPlayers()
	table.sort(available, function(a, b) return a.UserId < b.UserId end)
	for i = 1, n*2 do
		local candidate = available[i] or player
		-- Repeated local appearance is intentional demonstration data, not match results.
		local competitiveSlot=(i-1)%n+1
		local row={ UserId = i<=#available and candidate.UserId or -100000-i,
			AppearanceUserId=candidate.UserId,DisplayName=candidate.DisplayName..(i>#available and " · Demo "..i or ""),
			Username=candidate.Name,Team=i<=n and "Red" or "Blue",Slot=competitiveSlot,CompetitiveSlot=competitiveSlot,
			Goals=competitiveSlot==1 and (i<=n and 3 or 2) or (competitiveSlot==2 and (i<=n and 2 or 1) or 0),
			Kills=i%4,Deaths=i%3,Preview=true }
		table.insert(participants,row)
		if i<=n then table.insert(winners,row) end
	end
	local ok, reason = controller:Play({ MatchId = "PREVIEW_" .. tostring(os.clock()), Mode = mode, TeamSize = n, WinningTeam = "Red", Winners = winners, Participants=participants, LocalTeam = team, Score = { Red = 5, Blue = 3 }, EligibleParticipantCount = n * 2 }, { Scene = scene, OnStopped = release, FloatingEnabled=floatingEnabled, BillboardsEnabled=billboardsEnabled })
	if not ok then release(); warn("[EndCinematicPreview] " .. tostring(reason)) end
end
button("PREVIEW · 1v1", function() play(1, "1v1") end)
button("PREVIEW · 2v2", function() play(2, "2v2") end)
button("PREVIEW · 3v3", function() play(3, "3v3") end)
button("PREVIEW · 4v4", function() play(4, "4v4") end)
local toggle
toggle = button("VISTA: VICTORIA", function()
	team = team == "Red" and "Blue" or "Red"
	toggle.Text = team == "Red" and "VISTA: VICTORIA" or "VISTA: DERROTA"
end)
button("REINICIAR", function() play(count) end)
button("DETENER", cancel)
local floatingToggle
floatingToggle=button("FLOTACIÓN: ON",function()
	floatingEnabled=not floatingEnabled
	floatingToggle.Text="FLOTACIÓN: "..(floatingEnabled and "ON" or "OFF")
	controller:SetPreviewOptions(floatingEnabled,billboardsEnabled)
end)
local billboardToggle
billboardToggle=button("BILLBOARDS: ON",function()
	billboardsEnabled=not billboardsEnabled
	billboardToggle.Text="BILLBOARDS: "..(billboardsEnabled and "ON" or "OFF")
	controller:SetPreviewOptions(floatingEnabled,billboardsEnabled)
end)
