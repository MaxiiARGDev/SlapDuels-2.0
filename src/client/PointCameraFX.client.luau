--!strict
-- PointCameraFX (LocalScript, solo cliente)
-- Feedback de camara local cuando se anota un punto: sacudida, destellos de pantalla, bloom y golpe de FOV.
-- Escucha el RemoteEvent existente ReplicatedStorage.Remotes.Match.PointFeedback (no altera la logica de gameplay).
-- La intensidad cae con la distancia entre la camara y la ScoringZone, asi que solo se nota en quien esta en la partida.
-- Accesibilidad: si el jugador tiene el atributo "ReduceScreenEffects" = true, los efectos se atenuan mucho.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")

local CONFIG = {
	FullPowerDistance = 40,   -- studs: a esta distancia o menos, intensidad completa
	MaxDistance = 260,        -- studs: mas lejos que esto no se aplica nada
	ShakeTrauma = 0.9,        -- 0..1 por punto normal
	ShakeTraumaFinal = 1.0,
	ShakeDecay = 1.6,         -- trauma perdido por segundo
	ShakeMoveStuds = 1.1,
	ShakeRollDegrees = 4,
	FlashStrength = 0.6,      -- opacidad maxima del destello blanco (0..1)
	FlashFinalBoost = 1.15,
	FovKick = 12,             -- grados extra de FOV
	BloomPeak = 1.6,
	ReducedScale = 0.25,
}

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera :: Camera

local function effectScale(): number
	if player:GetAttribute("ReduceScreenEffects") == true then
		return CONFIG.ReducedScale
	end
	return 1
end

-- UI de destello
local gui = Instance.new("ScreenGui")
gui.Name = "PointCameraFX"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.Parent = player:WaitForChild("PlayerGui")

local flashFrame = Instance.new("Frame")
flashFrame.Name = "Flash"
flashFrame.Size = UDim2.fromScale(1, 1)
flashFrame.BackgroundColor3 = Color3.new(1, 1, 1)
flashFrame.BackgroundTransparency = 1
flashFrame.BorderSizePixel = 0
flashFrame.Active = false
flashFrame.Parent = gui

-- Efectos de iluminacion locales (no se replican)
local bloom = Instance.new("BloomEffect")
bloom.Name = "PointFX_Bloom"
bloom.Intensity = 0
bloom.Size = 36
bloom.Threshold = 1.2
bloom.Parent = Lighting

local color = Instance.new("ColorCorrectionEffect")
color.Name = "PointFX_Color"
color.Brightness = 0
color.Contrast = 0
color.Parent = Lighting

local flashTween: Tween? = nil
local function pulse(tint: Color3, strength: number, fadeTime: number)
	if flashTween then flashTween:Cancel() end
	flashFrame.BackgroundColor3 = tint
	flashFrame.BackgroundTransparency = 1 - math.clamp(strength, 0, 1)
	local tw = TweenService:Create(flashFrame, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
	flashTween = tw
	tw:Play()
end

-- Sacudida de camara (modelo de "trauma")
local trauma = 0
local seed = math.random() * 100
RunService:BindToRenderStep("PointCameraFX", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	if trauma <= 0 then return end
	trauma = math.max(0, trauma - dt * CONFIG.ShakeDecay)
	local shake = trauma * trauma
	local t = os.clock() * 28
	local nx = math.noise(seed, t, 0) * 2
	local ny = math.noise(seed, t, 10) * 2
	local nr = math.noise(seed, t, 20) * 2
	local cam = workspace.CurrentCamera
	if cam then
		local move = CONFIG.ShakeMoveStuds * shake
		local roll = math.rad(CONFIG.ShakeRollDegrees) * shake
		cam.CFrame = cam.CFrame * CFrame.new(nx * move, ny * move, 0) * CFrame.Angles(0, 0, nr * roll)
	end
end)

-- Golpe de FOV
local fovBase: number? = nil
local function fovKick(amount: number)
	local cam = workspace.CurrentCamera
	if not cam then return end
	if fovBase == nil then fovBase = cam.FieldOfView end
	local base = fovBase :: number
	TweenService:Create(cam, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = base + amount }):Play()
	task.delay(0.07, function()
		local c = workspace.CurrentCamera
		if not c then return end
		local back = TweenService:Create(c, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { FieldOfView = base })
		back.Completed:Once(function() fovBase = nil end)
		back:Play()
	end)
end

local function distanceFactor(pos: Vector3): number
	local cam = workspace.CurrentCamera
	if not cam then return 0 end
	local d = (cam.CFrame.Position - pos).Magnitude
	if d <= CONFIG.FullPowerDistance then return 1 end
	return math.clamp(1 - (d - CONFIG.FullPowerDistance) / (CONFIG.MaxDistance - CONFIG.FullPowerDistance), 0, 1)
end

local function onPoint(data: any)
	if typeof(data) ~= "table" then return end
	local pos = data.ScoringZonePosition
	if typeof(pos) ~= "Vector3" then return end

	local factor = distanceFactor(pos) * effectScale()
	if factor < 0.04 then return end
	local isFinal = data.IsFinalPoint == true

	-- Sacudida
	trauma = math.min(1, trauma + (if isFinal then CONFIG.ShakeTraumaFinal else CONFIG.ShakeTrauma) * factor)

	-- Destello 1 (blanco, fuerte) y destello 2 (calido, mas suave): solo 2 pulsos de pantalla completa
	local strength = CONFIG.FlashStrength * factor * (if isFinal then CONFIG.FlashFinalBoost else 1)
	pulse(Color3.new(1, 1, 1), strength, 0.34)
	task.delay(0.2, function()
		pulse(Color3.fromRGB(255, 232, 160), strength * 0.55, 0.45)
	end)

	-- Bloom + contraste
	bloom.Intensity = CONFIG.BloomPeak * factor
	color.Brightness = 0.16 * factor
	color.Contrast = 0.35 * factor
	local info = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(bloom, info, { Intensity = 0 }):Play()
	TweenService:Create(color, info, { Brightness = 0, Contrast = 0 }):Play()

	-- FOV
	fovKick(CONFIG.FovKick * factor)
end

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local matchFolder = remotes:WaitForChild("Match")
local pointFeedback = matchFolder:WaitForChild("PointFeedback") :: RemoteEvent
pointFeedback.OnClientEvent:Connect(onPoint)
