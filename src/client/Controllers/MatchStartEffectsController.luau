--!strict
-- MatchStartEffectsController
-- Controlador cliente dedicado a la presentación y Game Feel del StartCountdown.
-- Responsabilidad exclusiva de PRESENTACIÓN:
-- - Camera Shake local acumulativo y seguro (RenderPriority.Camera + 1) sin alterar la base de la cámara.
-- - Destellos de pantalla (FlashOverlay) con intensidad creciente 5..1 y clímax en ¡COMIENZA!.
-- - Blur dinámico y efímero (Lighting.MatchStartBlur).
-- - Expansión de ondas (PulseFrame y ShockwaveFrame).
-- - Audio direccional/SFX (SoundService.MatchStartSFX).
-- - Aislamiento estricto por MatchId para partidas simultáneas.
-- - Cleanup defensivo ante desconexiones, cancelaciones o transición a Playing.
-- NO altera lógica de gameplay, scoring ni la autoridad del servidor.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Constants = require(ReplicatedStorage.Shared.Constants)

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera :: Camera

local MatchStartEffectsController = {}
MatchStartEffectsController.Name = "MatchStartEffectsController"

-- Referencias internas
MatchStartEffectsController._context = nil :: any
MatchStartEffectsController._activeMatchId = nil :: string?
MatchStartEffectsController._activeConnections = {} :: { RBXScriptConnection }
MatchStartEffectsController._activeTweens = {} :: { Tween }
MatchStartEffectsController._activeThreads = {} :: { thread }

-- Instancias de presentación en Lighting, UI y Audio
MatchStartEffectsController._blurEffect = nil :: BlurEffect?
MatchStartEffectsController._flashOverlay = nil :: Frame?
MatchStartEffectsController._pulseFrame = nil :: Frame?
MatchStartEffectsController._shockwaveFrame = nil :: Frame?
MatchStartEffectsController._pulseScale = nil :: UIScale?
MatchStartEffectsController._shockwaveScale = nil :: UIScale?
MatchStartEffectsController._effectsScale = nil :: UIScale?
MatchStartEffectsController._sfxFolder = nil :: Folder?

-- Estado de Camera Shake
MatchStartEffectsController._shakeTrauma = 0
MatchStartEffectsController._shakeDecay = 2.0
MatchStartEffectsController._shakeMoveStuds = 0.5
MatchStartEffectsController._shakeRollDeg = 1.5
MatchStartEffectsController._shakeSeed = math.random() * 1000

local RENDER_STEP_NAME = "MatchStartCameraShake"

-- Accesibilidad: reduce intensidad si el jugador tiene el atributo activado
local function getAccessibilityScale(): number
	if localPlayer and localPlayer:GetAttribute("ReduceScreenEffects") == true then
		return 0.3
	end
	return 1.0
end

function MatchStartEffectsController:Init(context)
	self._context = context
	self._activeConnections = {}
	self._activeTweens = {}
	self._activeThreads = {}

	self:_bindInstances()
	self:_setupCameraShake()
end

function MatchStartEffectsController:Start(context)
	self._context = context
	self:_connectRemotes()
	print("[MatchStartEffectsController] Controlador de Game Feel de inicio de partida iniciado y listo")
end

-- Localiza las instancias visuales y auditivas en Lighting, PlayerGui y SoundService
function MatchStartEffectsController:_bindInstances()
	-- 1. Lighting.MatchStartBlur
	local blur = Lighting:FindFirstChild("MatchStartBlur") :: BlurEffect?
	if not blur then
		blur = Instance.new("BlurEffect")
		blur.Name = "MatchStartBlur"
		blur.Enabled = false
		blur.Size = 0
		blur.Parent = Lighting
	end
	self._blurEffect = blur
	blur.Enabled = false
	blur.Size = 0

	-- 2. StarterGui / PlayerGui.MatchHUD.StartEffects
	task.spawn(function()
		local playerGui = localPlayer:WaitForChild("PlayerGui", 10)
		if not playerGui then return end

		local hud = playerGui:WaitForChild("MatchHUD", 15)
		if not hud then return end

		local effects = hud:WaitForChild("StartEffects", 10)
		if not effects then return end

		self._effectsScale = effects:FindFirstChild("UIScale") :: UIScale?
		self._flashOverlay = effects:FindFirstChild("FlashOverlay") :: Frame?
		self._pulseFrame = effects:FindFirstChild("PulseFrame") :: Frame?
		self._shockwaveFrame = effects:FindFirstChild("ShockwaveFrame") :: Frame?

		if self._pulseFrame then
			self._pulseScale = self._pulseFrame:FindFirstChild("UIScale") :: UIScale?
		end
		if self._shockwaveFrame then
			self._shockwaveScale = self._shockwaveFrame:FindFirstChild("UIScale") :: UIScale?
		end

		if self._flashOverlay then self._flashOverlay.BackgroundTransparency = 1 end
		if self._pulseFrame then self._pulseFrame.Visible = false end
		if self._shockwaveFrame then self._shockwaveFrame.Visible = false end
	end)

	-- 3. SoundService.MatchStartSFX
	self._sfxFolder = SoundService:FindFirstChild("MatchStartSFX") :: Folder?
end

-- Configura el enlace de RunService para la sacudida de cámara local sin modificar CFrame de forma permanente
function MatchStartEffectsController:_setupCameraShake()
	RunService:UnbindFromRenderStep(RENDER_STEP_NAME)

	RunService:BindToRenderStep(RENDER_STEP_NAME, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		if self._shakeTrauma <= 0 then return end

		self._shakeTrauma = math.max(0, self._shakeTrauma - dt * self._shakeDecay)
		local traumaSq = self._shakeTrauma * self._shakeTrauma
		local scale = getAccessibilityScale()

		local t = os.clock() * 32
		local nx = math.noise(self._shakeSeed, t, 0) * 2
		local ny = math.noise(self._shakeSeed, t, 15) * 2
		local nr = math.noise(self._shakeSeed, t, 30) * 2

		local cam = workspace.CurrentCamera
		if cam then
			local move = (self._shakeMoveStuds * traumaSq) * scale
			local roll = math.rad(self._shakeRollDeg * traumaSq) * scale
			cam.CFrame = cam.CFrame * CFrame.new(nx * move, ny * move, 0) * CFrame.Angles(0, 0, nr * roll)
		end
	end)
end

-- Conexión reactiva a los RemoteEvents existentes
function MatchStartEffectsController:_connectRemotes()
	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
	if not remotesFolder then return end

	local matchFolder = remotesFolder:WaitForChild("Match", 10)
	if not matchFolder then return end

	local stateChanged = matchFolder:WaitForChild("StateChanged", 10) :: RemoteEvent?
	local countdown = matchFolder:WaitForChild("Countdown", 10) :: RemoteEvent?

	if stateChanged then
		table.insert(self._activeConnections, stateChanged.OnClientEvent:Connect(function(newState: string, extraData: any)
			self:_handleStateChanged(newState, extraData)
		end))
	end

	if countdown then
		table.insert(self._activeConnections, countdown.OnClientEvent:Connect(function(remaining: number, label: string, extraData: any?)
			self:_handleCountdown(remaining, label, extraData)
		end))
	end
end

-- Determina si el jugador local pertenece al match según los datos del servidor
local function isLocalPlayerInMatch(extraData: any): boolean
	if not extraData then return true end
	local myName = localPlayer.Name

	if extraData.Red == myName or extraData.Blue == myName then
		return true
	end

	if type(extraData.RedTeam) == "table" then
		for _, p in ipairs(extraData.RedTeam) do
			if (type(p) == "table" and p.Name == myName) or (typeof(p) == "Instance" and p.Name == myName) then
				return true
			end
		end
	end

	if type(extraData.BlueTeam) == "table" then
		for _, p in ipairs(extraData.BlueTeam) do
			if (type(p) == "table" and p.Name == myName) or (typeof(p) == "Instance" and p.Name == myName) then
				return true
			end
		end
	end

	return false
end

function MatchStartEffectsController:_handleStateChanged(newState: string, extraData: any)
	if newState == Constants.RoundState.StartCountdown
		or newState == Constants.RoundState.PointRestartCountdown
		or newState == Constants.RoundState.MatchReady then
		if isLocalPlayerInMatch(extraData) then
			if extraData and extraData.MatchId then
				self._activeMatchId = extraData.MatchId
			end
		else
			self._activeMatchId = nil
		end
	elseif newState == Constants.RoundState.Playing then
		-- Al entrar a Playing, programar cleanup tras un breve respiro para que concluya la secuencia de ¡COMIENZA!
		task.delay(0.75, function()
			self:Cleanup()
		end)
	elseif newState == Constants.RoundState.Ending
		or newState == Constants.RoundState.ReturningToLobby
		or newState == Constants.RoundState.Waiting then
		self._activeMatchId = nil
		self:Cleanup()
	end
end

function MatchStartEffectsController:_handleCountdown(remaining: number, label: string, extraData: any?)
	-- Solo procesar conteos correspondientes a START_COUNTDOWN
	if label ~= "START_COUNTDOWN" and (extraData == nil or extraData.Started == nil) then
		return
	end

	-- Validación estricta de MatchId para aislar múltiples partidas simultáneas
	if extraData and extraData.MatchId then
		if self._activeMatchId and self._activeMatchId ~= extraData.MatchId then
			return -- Ignorar evento de otra partida concurrente
		end
		self._activeMatchId = extraData.MatchId
	end

	if remaining > 0 then
		self:PlayCountdown(remaining, extraData)
	elseif remaining == 0 or (extraData and extraData.Started == true) then
		self:PlayStart(extraData)
	end
end

-- ==================================================
-- EJECUCIÓN MODULAR DE EFECTOS
-- ==================================================

-- Impacto audiovisual correspondiente a un número (5..1 o 3..1)
function MatchStartEffectsController:PlayCountdown(value: number, extraData: any?)
	local isPointRestart = (extraData and extraData.Phase == "PointRestart")
	local key = tostring(value)
	local cfgTable = if isPointRestart
		then (Config.PointRestartCountdownEffects or Config.StartCountdownEffects)
		else Config.StartCountdownEffects

	local cfg = (cfgTable and cfgTable[key]) or {
		ShakeStuds = 0.20,
		ShakeRotationDeg = 1.0,
		ShakeDuration = 0.35,
		FlashTransparency = 0.85,
		FlashFadeDuration = 0.25,
		BlurSize = 3,
		BlurDuration = 0.30,
		PulseScale = 1.6,
		PulseDuration = 0.30,
		SoundName = "CountdownTick",
		SoundVolume = 0.70,
		SoundPlaybackSpeed = 1.0,
	}

	-- 1. Camera Shake
	self:Shake(cfg.ShakeStuds, cfg.ShakeRotationDeg, cfg.ShakeDuration)

	-- 2. Screen Flash
	self:Flash(cfg.FlashTransparency, cfg.FlashFadeDuration)

	-- 3. Blur
	self:Blur(cfg.BlurSize, cfg.BlurDuration)

	-- 4. Pulse de expansión (manteniendo color editable en Studio)
	self:Pulse(cfg.PulseScale, cfg.PulseDuration)

	-- 5. Audio
	if cfg.SoundName then
		self:PlaySound(cfg.SoundName, cfg.SoundVolume, cfg.SoundPlaybackSpeed)
	end
end

-- Clímax cinematográfico correspondiente a ¡COMIENZA!
function MatchStartEffectsController:PlayStart(extraData: any?)
	local isPointRestart = (extraData and extraData.Phase == "PointRestart")
	local cfgTable = if isPointRestart
		then (Config.PointRestartCountdownEffects or Config.StartCountdownEffects)
		else Config.StartCountdownEffects

	local cfg = (cfgTable and cfgTable["GO"]) or {
		ShakeStuds = 0.90,
		ShakeRotationDeg = 3.0,
		ShakeDuration = 0.70,
		FlashTransparency = 0.18,
		FlashFadeDuration = 0.50,
		BlurSize = 10.0,
		BlurDuration = 0.60,
		PulseScale = 2.8,
		PulseDuration = 0.50,
		ShockwaveScale = 3.5,
		ShockwaveDuration = 0.55,
		WhooshSoundName = "StartWhoosh",
		ImpactSoundName = "StartImpact",
		SoundVolume = 1.25,
	}

	-- T+0.00: Gran flash, fuerte sacudida, blur y sonido whoosh
	self:Flash(cfg.FlashTransparency, cfg.FlashFadeDuration)
	self:Shake(cfg.ShakeStuds * 0.7, cfg.ShakeRotationDeg * 0.7, 0.35)
	self:Blur(cfg.BlurSize, cfg.BlurDuration)
	if cfg.WhooshSoundName then
		self:PlaySound(cfg.WhooshSoundName, 0.9, 1.0)
	end

	-- T+0.12 (o T+0.08 en PointRestart más rápido): Shockwave grande, impacto de cámara máximo y sonido explosivo
	local delayTime = if isPointRestart then 0.08 else 0.12
	local th = task.delay(delayTime, function()
		self:Shake(cfg.ShakeStuds, cfg.ShakeRotationDeg, cfg.ShakeDuration)
		self:Shockwave(cfg.ShockwaveScale or 3.5, cfg.ShockwaveDuration or 0.55)
		if cfg.ImpactSoundName then
			self:PlaySound(cfg.ImpactSoundName, cfg.SoundVolume or 1.25, 1.0)
		end
	end)
	table.insert(self._activeThreads, th)
end

-- Aplica impulso de sacudida a la cámara con trauma decreciente
function MatchStartEffectsController:Shake(studs: number, rotDeg: number, duration: number)
	self._shakeMoveStuds = studs
	self._shakeRollDeg = rotDeg
	self._shakeDecay = 1.0 / math.max(0.1, duration)
	self._shakeTrauma = 1.0
end

-- Destello de pantalla (FlashOverlay)
function MatchStartEffectsController:Flash(peakTransparency: number, fadeTime: number)
	local overlay = self._flashOverlay
	if not overlay then return end

	local accScale = getAccessibilityScale()
	local effectiveTransparency = 1 - ((1 - peakTransparency) * accScale)

	overlay.BackgroundTransparency = effectiveTransparency
	overlay.Visible = true

	local tw = TweenService:Create(overlay, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	})
	table.insert(self._activeTweens, tw)
	tw.Completed:Once(function()
		if overlay.BackgroundTransparency >= 0.99 then
			overlay.BackgroundTransparency = 1
		end
	end)
	tw:Play()
end

-- Blur efímero en Lighting
function MatchStartEffectsController:Blur(targetSize: number, duration: number)
	local blur = self._blurEffect
	if not blur then return end

	local accScale = getAccessibilityScale()
	local effectiveSize = targetSize * accScale

	blur.Enabled = true
	blur.Size = effectiveSize

	local holdTime = duration * 0.25
	local fadeTime = duration * 0.75

	local th = task.delay(holdTime, function()
		if not blur or not blur.Parent then return end
		local tw = TweenService:Create(blur, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = 0,
		})
		table.insert(self._activeTweens, tw)
		tw.Completed:Once(function()
			if blur and blur.Size <= 0.2 then
				blur.Size = 0
				blur.Enabled = false
			end
		end)
		tw:Play()
	end)
	table.insert(self._activeThreads, th)
end

-- Onda expansiva sutil (PulseFrame) alrededor del centro del HUD
function MatchStartEffectsController:Pulse(targetScale: number, duration: number, strokeColor: Color3?)
	local frame = self._pulseFrame
	if not frame then return end

	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if not stroke then return end

	local uiScale = self._pulseScale or frame:FindFirstChildOfClass("UIScale")

	frame.Visible = true
	if strokeColor then
		stroke.Color = strokeColor
	end
	stroke.Transparency = 0.1

	if uiScale then
		uiScale.Scale = 0.3
		local twScale = TweenService:Create(uiScale, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = targetScale,
		})
		local twStroke = TweenService:Create(stroke, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1,
		})

		table.insert(self._activeTweens, twScale)
		table.insert(self._activeTweens, twStroke)

		twScale.Completed:Once(function()
			frame.Visible = false
			uiScale.Scale = 1.0
		end)

		twScale:Play()
		twStroke:Play()
	else
		local baseSize = UDim2.fromOffset(120, 120)
		frame.Size = baseSize
		local targetSize = UDim2.fromOffset(120 * targetScale, 120 * targetScale)

		local twSize = TweenService:Create(frame, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = targetSize,
		})
		local twStroke = TweenService:Create(stroke, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Transparency = 1,
		})

		table.insert(self._activeTweens, twSize)
		table.insert(self._activeTweens, twStroke)

		twSize.Completed:Once(function()
			frame.Visible = false
		end)

		twSize:Play()
		twStroke:Play()
	end
end

-- Onda expansiva prominente (ShockwaveFrame) para ¡COMIENZA!
function MatchStartEffectsController:Shockwave(targetScale: number, duration: number)
	local frame = self._shockwaveFrame
	if not frame then return end

	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if not stroke then return end

	local uiScale = self._shockwaveScale or frame:FindFirstChildOfClass("UIScale")

	frame.Visible = true
	stroke.Transparency = 0

	if uiScale then
		uiScale.Scale = 0.2
		local twScale = TweenService:Create(uiScale, TweenInfo.new(duration, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
			Scale = targetScale,
		})
		local twStroke = TweenService:Create(stroke, TweenInfo.new(duration, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
			Transparency = 1,
		})

		table.insert(self._activeTweens, twScale)
		table.insert(self._activeTweens, twStroke)

		twScale.Completed:Once(function()
			frame.Visible = false
			uiScale.Scale = 1.0
		end)

		twScale:Play()
		twStroke:Play()
	else
		local baseSize = UDim2.fromOffset(140, 140)
		frame.Size = baseSize
		local targetSize = UDim2.fromOffset(140 * targetScale, 140 * targetScale)

		local twSize = TweenService:Create(frame, TweenInfo.new(duration, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
			Size = targetSize,
		})
		local twStroke = TweenService:Create(stroke, TweenInfo.new(duration, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
			Transparency = 1,
		})

		table.insert(self._activeTweens, twSize)
		table.insert(self._activeTweens, twStroke)

		twSize.Completed:Once(function()
			frame.Visible = false
		end)

		twSize:Play()
		twStroke:Play()
	end
end

-- Reproduce un sonido localizado en SoundService.MatchStartSFX
function MatchStartEffectsController:PlaySound(soundName: string, volume: number?, speed: number?)
	local folder = self._sfxFolder or SoundService:FindFirstChild("MatchStartSFX")
	if not folder then return end

	local sfx = folder:FindFirstChild(soundName) :: Sound?
	if sfx and sfx:IsA("Sound") then
		local clone = sfx:Clone()
		if volume then clone.Volume = volume end
		if speed then clone.PlaybackSpeed = speed end
		clone.Parent = SoundService
		clone.Ended:Once(function()
			clone:Destroy()
		end)
		clone:Play()
		-- Limpieza de seguridad por si el audio se interrumpe
		task.delay(3, function()
			if clone and clone.Parent then
				clone:Destroy()
			end
		end)
	end
end

-- Limpieza exhaustiva de todos los efectos visuales y auditivos
function MatchStartEffectsController:Cleanup()
	-- 1. Reset Camera Shake
	self._shakeTrauma = 0

	-- 2. Cancelar tweens activos
	for _, tw in ipairs(self._activeTweens) do
		pcall(function()
			tw:Cancel()
		end)
	end
	self._activeTweens = {}

	-- 3. Cancelar hilos activos
	for _, th in ipairs(self._activeThreads) do
		pcall(task.cancel, th)
	end
	self._activeThreads = {}

	-- 4. Reset Blur
	if self._blurEffect then
		self._blurEffect.Size = 0
		self._blurEffect.Enabled = false
	end

	-- 5. Reset Overlays y Frames
	if self._flashOverlay then
		self._flashOverlay.BackgroundTransparency = 1
	end
	if self._pulseFrame then
		self._pulseFrame.Visible = false
		local s = self._pulseFrame:FindFirstChildOfClass("UIStroke")
		if s then s.Transparency = 1 end
		local sc = self._pulseScale or self._pulseFrame:FindFirstChildOfClass("UIScale")
		if sc then sc.Scale = 1.0 end
	end
	if self._shockwaveFrame then
		self._shockwaveFrame.Visible = false
		local s = self._shockwaveFrame:FindFirstChildOfClass("UIStroke")
		if s then s.Transparency = 1 end
		local sc = self._shockwaveScale or self._shockwaveFrame:FindFirstChildOfClass("UIScale")
		if sc then sc.Scale = 1.0 end
	end
end

return MatchStartEffectsController
