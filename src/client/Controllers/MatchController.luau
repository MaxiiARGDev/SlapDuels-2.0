--!strict
-- MatchController
-- Controlador de la interfaz de partida 1v1.
-- NO construye la UI mediante codigo; localiza y controla las instancias reales preexistentes en PlayerGui.MatchHUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Constants = require(ReplicatedStorage.Shared.Constants)

local localPlayer = Players.LocalPlayer

type Palette = { Main: Color3, Shadow: Color3, Deep: Color3, Accent: Color3 }

type Pose = {
	Position: UDim2,
	Rotation: number,
	Scale: number,
	Transparency: number,
	Depth: number,
	ShineY: number,
}

type FxStack = {
	Root: Frame,
	Scale: UIScale,
	Layers: { TextLabel },
	Stroke: UIStroke?,
}

type BurstFx = {
	Container: Frame,
	Rings: { Frame },
	RingStrokes: { UIStroke },
	Sparks: { Frame },
	SparkAngles: { number },
	SparkReach: { number },
}

type CountdownFx = {
	Container: Frame,
	Extrusion: FxStack,
	Ghosts: { FxStack },
	Burst: BurstFx,
}

type CountdownRig = {
	Frame: Frame,
	Label: TextLabel,
	UIScale: UIScale,
	Stroke: UIStroke?,
	Gradient: UIGradient?,
	Fx: CountdownFx,
}

local MatchController = {}
MatchController.Name = "MatchController"

-- Referencias a instancias de PlayerGui.MatchHUD
MatchController._hud = nil :: ScreenGui?

-- StartCountdownFrame
MatchController._startCountdownFrame = nil :: Frame?
MatchController._startCountdownTitle = nil :: TextLabel?
MatchController._startCountdownLabel = nil :: TextLabel?
MatchController._startCountdownScale = nil :: UIScale?
MatchController._countdownAnimToken = 0
MatchController._countdownConn = nil :: RBXScriptConnection?
MatchController._countdownFx = nil :: CountdownFx?
MatchController._currentMatchId = nil :: string?

-- CountdownFrame
MatchController._countdownFrame = nil :: Frame?
MatchController._countdownTitle = nil :: TextLabel?
MatchController._countdownTimer = nil :: TextLabel?

-- MapSelectionFrame
MatchController._mapSelectionFrame = nil :: Frame?
MatchController._mapHeader = nil :: TextLabel?
MatchController._mapTimer = nil :: TextLabel?
MatchController._mapsContainer = nil :: Frame?
MatchController._mapButtonTemplate = nil :: TextButton?
MatchController._randomButton = nil :: TextButton?
MatchController._clonedButtons = {} :: { [string]: TextButton }

-- MatchTimerFrame
MatchController._matchTimerFrame = nil :: Frame?
MatchController._matchTimer = nil :: TextLabel?

-- ResultFrame
MatchController._resultFrame = nil :: Frame?
MatchController._resultTitle = nil :: TextLabel?
MatchController._resultSubtitle = nil :: TextLabel?

-- RedTeamFrame (Scoreboard)
MatchController._redTeamFrame = nil :: Frame?
MatchController._redScoreLabel = nil :: TextLabel?
MatchController._redPlayersContainer = nil :: Frame?

-- BlueTeamFrame (Scoreboard)
MatchController._blueTeamFrame = nil :: Frame?
MatchController._blueScoreLabel = nil :: TextLabel?
MatchController._bluePlayersContainer = nil :: Frame?

-- PlayerSlotTemplate
MatchController._playerSlotTemplate = nil :: Frame?
MatchController._clonedSlots = {} :: { Frame }

-- LastPointFrame
MatchController._lastPointFrame = nil :: Frame?
MatchController._lastPointTitle = nil :: TextLabel?
MatchController._lastPointSubtitle = nil :: TextLabel?
MatchController._lastPointToken = 0

-- Estado local
MatchController._currentState = Constants.RoundState.Waiting
MatchController._selectedMapVote = nil :: string?
MatchController._currentRole = nil :: string? -- "Red" | "Blue" | nil
MatchController._currentSelectedMap = nil :: string?
MatchController._context = nil :: any

local function formatTime(seconds: number): string
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	return string.format("%d:%02d", m, s)
end

function MatchController:Init(context)
	self._context = context
	self:_bindHUD()
end

function MatchController:GetCurrentMatchId(): string?
	return self._currentMatchId
end

function MatchController:GetStartCountdownFrame(): Frame?
	return self._startCountdownFrame
end

function MatchController:GetCurrentState(): string
	return self._currentState
end

function MatchController:IsParticipant(): boolean
	return self._currentRole ~= nil
end

function MatchController:GetCurrentSelectedMap(): string?
	return self._currentSelectedMap
end

function MatchController:Start(context)
	self._context = context
	self:_setupButtonEvents()
	self:_connectRemotes()
	print("[MatchController] Controlador iniciado y enlazado a PlayerGui.MatchHUD")
end

function MatchController:_bindHUD()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("MatchHUD", 15) :: ScreenGui?
	if not hud then
		warn("[MatchController] No se encontro MatchHUD en PlayerGui")
		return
	end
	self._hud = hud

	-- 1. CountdownFrame
	local cdFrame = hud:WaitForChild("CountdownFrame", 10) :: Frame?
	if cdFrame then
		self._countdownFrame = cdFrame
		self._countdownTitle = cdFrame:WaitForChild("Title", 10) :: TextLabel?
		self._countdownTimer = cdFrame:WaitForChild("Timer", 10) :: TextLabel?
		cdFrame.Visible = false
	end

	-- 1.5 StartCountdownFrame
	local scFrame = hud:WaitForChild("StartCountdownFrame", 10) :: Frame?
	if scFrame then
		self._startCountdownFrame = scFrame
		self._startCountdownTitle = scFrame:WaitForChild("Title", 10) :: TextLabel?
		self._startCountdownLabel = scFrame:WaitForChild("CountdownLabel", 10) :: TextLabel?
		self._startCountdownScale = (self._startCountdownLabel and self._startCountdownLabel:FindFirstChildOfClass("UIScale")) :: UIScale?
		scFrame.Visible = false
	end

	-- 2. MapSelectionFrame
	local mapFrame = hud:WaitForChild("MapSelectionFrame", 10) :: Frame?
	if mapFrame then
		self._mapSelectionFrame = mapFrame
		self._mapHeader = mapFrame:WaitForChild("Header", 10) :: TextLabel?
		self._mapTimer = mapFrame:WaitForChild("Timer", 10) :: TextLabel?
		self._randomButton = mapFrame:WaitForChild("RandomButton", 10) :: TextButton?

		local container = mapFrame:WaitForChild("MapsContainer", 10) :: Frame?
		if container then
			self._mapsContainer = container
			self._mapButtonTemplate = container:WaitForChild("MapButtonTemplate", 10) :: TextButton?
			if self._mapButtonTemplate then
				self._mapButtonTemplate.Visible = false
			end
		end
		mapFrame.Visible = false
	end

	-- 3. MatchTimerFrame
	local timerFrame = hud:WaitForChild("MatchTimerFrame", 10) :: Frame?
	if timerFrame then
		self._matchTimerFrame = timerFrame
		self._matchTimer = timerFrame:WaitForChild("Timer", 10) :: TextLabel?
		timerFrame.Visible = false
	end

	-- 4. ResultFrame
	local resFrame = hud:WaitForChild("ResultFrame", 10) :: Frame?
	if resFrame then
		self._resultFrame = resFrame
		self._resultTitle = resFrame:WaitForChild("ResultTitle", 10) :: TextLabel?
		self._resultSubtitle = resFrame:WaitForChild("ResultSubtitle", 10) :: TextLabel?
		resFrame.Visible = false
	end

	-- 5. RedTeamFrame
	local redFrame = hud:WaitForChild("RedTeamFrame", 10) :: Frame?
	if redFrame then
		self._redTeamFrame = redFrame
		self._redScoreLabel = redFrame:WaitForChild("ScoreLabel", 10) :: TextLabel?
		self._redPlayersContainer = redFrame:WaitForChild("PlayersContainer", 10) :: Frame?
		redFrame.Visible = false
	end

	-- 6. BlueTeamFrame
	local blueFrame = hud:WaitForChild("BlueTeamFrame", 10) :: Frame?
	if blueFrame then
		self._blueTeamFrame = blueFrame
		self._blueScoreLabel = blueFrame:WaitForChild("ScoreLabel", 10) :: TextLabel?
		self._bluePlayersContainer = blueFrame:WaitForChild("PlayersContainer", 10) :: Frame?
		blueFrame.Visible = false
	end

	-- 7. PlayerSlotTemplate
	local slotTemplate = hud:WaitForChild("PlayerSlotTemplate", 10) :: Frame?
	if slotTemplate then
		self._playerSlotTemplate = slotTemplate
		slotTemplate.Visible = false
	end

	-- 8. LastPointFrame
	local lpFrame = hud:WaitForChild("LastPointFrame", 10) :: Frame?
	if lpFrame then
		self._lastPointFrame = lpFrame
		self._lastPointTitle = lpFrame:WaitForChild("Title", 10) :: TextLabel?
		self._lastPointSubtitle = lpFrame:WaitForChild("Subtitle", 10) :: TextLabel?
		lpFrame.Visible = false
	end
end

function MatchController:_setupButtonEvents()
	if self._randomButton then
		self._randomButton.MouseButton1Click:Connect(function()
			self:_submitVote(Constants.SpecialMapVote.Random, self._randomButton)
		end)
	end
end

function MatchController:_connectRemotes()
	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
	if not remotesFolder then return end

	local matchFolder = remotesFolder:WaitForChild("Match", 10)
	if not matchFolder then return end

	local stateChanged = matchFolder:WaitForChild("StateChanged", 10) :: RemoteEvent?
	local countdown = matchFolder:WaitForChild("Countdown", 10) :: RemoteEvent?
	local mapSelection = matchFolder:WaitForChild("MapSelection", 10) :: RemoteEvent?
	local matchResult = matchFolder:WaitForChild("MatchResult", 10) :: RemoteEvent?
	local scoreUpdated = matchFolder:WaitForChild("ScoreUpdated", 10) :: RemoteEvent?
	local lastPoint = matchFolder:WaitForChild("LastPoint", 10) :: RemoteEvent?

	if stateChanged then
		stateChanged.OnClientEvent:Connect(function(newState: string, extraData: any)
			self:_handleStateChanged(newState, extraData)
		end)
	end

	if countdown then
		countdown.OnClientEvent:Connect(function(remaining: number, label: string, extraData: any?)
			self:_handleCountdown(remaining, label, extraData)
		end)
	end

	if mapSelection then
		mapSelection.OnClientEvent:Connect(function(data: any)
			if type(data) == "table" and data.Maps then
				self:_populateMapSelection(data.Maps)
			elseif type(data) == "table" and data.Voted then
				self:_highlightSelectedVote(data.Voted)
			end
		end)
	end

	if matchResult then
		matchResult.OnClientEvent:Connect(function(result: string, winnerName: string?)
			self:_handleMatchResult(result, winnerName)
		end)
	end

	if scoreUpdated then
		scoreUpdated.OnClientEvent:Connect(function(data: any)
			self:_handleScoreUpdated(data)
		end)
	end

	if lastPoint then
		lastPoint.OnClientEvent:Connect(function(data: any)
			self:_handleLastPoint(data)
		end)
	end

	local pointFeedback = matchFolder:WaitForChild("PointFeedback", 5) :: RemoteEvent?
	if pointFeedback then
		pointFeedback.OnClientEvent:Connect(function(data: any)
			self:_handlePointFeedback(data)
		end)
	end
end

function MatchController:_handlePointFeedback(data: any)
	-- Hook arquitectónico preparado para Camera Shake y efectos de pantalla
	-- Autoridad exclusiva del servidor: el cliente reacciona pero no decide
	if type(data) ~= "table" then return end
	print(string.format("[MatchController] PointFeedback recibido del servidor: Equipo=%s, Jugador=%s, Efecto=%s, Final=%s",
		tostring(data.ScoringTeam),
		tostring(data.ScoringPlayerName),
		tostring(data.EffectId),
		tostring(data.IsFinalPoint)))
end

function MatchController:_handleStateChanged(newState: string, extraData: any)
	local prevState = self._currentState
	self._currentState = newState
	print(string.format("[MatchController] Estado recibido: %s", newState))

	local isPointRestart = (newState == Constants.RoundState.PointRestartCountdown)

	-- Ocultar frames condicionalmente (durante PointRestartCountdown el HUD y timer permanecen visibles)
	if not isPointRestart then
		if self._startCountdownFrame then self._startCountdownFrame.Visible = false end
		if self._countdownFrame then self._countdownFrame.Visible = false end
		if self._mapSelectionFrame then self._mapSelectionFrame.Visible = false end
		if self._matchTimerFrame and newState ~= Constants.RoundState.Playing then self._matchTimerFrame.Visible = false end
		if self._resultFrame then self._resultFrame.Visible = false end
	end

	if newState == Constants.RoundState.MatchReady then
		if extraData and extraData.MatchId then
			self._currentMatchId = extraData.MatchId
		end
		if extraData and extraData.Red and extraData.Blue then
			if extraData.Red == localPlayer.Name then
				self._currentRole = "Red"
			elseif extraData.Blue == localPlayer.Name then
				self._currentRole = "Blue"
			else
				self._currentRole = nil
			end
		end

	elseif newState == Constants.RoundState.MatchCountdown then
		if self._countdownFrame then
			if self._countdownTitle then
				self._countdownTitle.Text = "LA PARTIDA COMIENZA EN"
			end
			self._countdownFrame.Visible = true
		end

	elseif newState == Constants.RoundState.MapSelection then
		if self._mapSelectionFrame then
			self._selectedMapVote = nil
			self:_resetButtonHighlights()
			self._mapSelectionFrame.Visible = true
		end

	elseif newState == Constants.RoundState.MapLoading then
		self._currentSelectedMap = extraData and extraData.SelectedMap
		if self._countdownFrame and self._countdownTitle and self._countdownTimer then
			self._countdownTitle.Text = "CARGANDO MAPA"
			self._countdownTimer.Text = extraData and extraData.SelectedMap or "..."
			self._countdownFrame.Visible = true
		end
		if self:IsParticipant() then
			local musicController = self._context and self._context:GetController("MusicController")
			if musicController then
				musicController:PlayArena(self._currentSelectedMap or "Default")
			end
		end

	elseif newState == Constants.RoundState.StartCountdown then
		if extraData and extraData.MatchId then
			self._currentMatchId = extraData.MatchId
		end
		if extraData and extraData.SelectedMap and not self._currentSelectedMap then
			self._currentSelectedMap = extraData.SelectedMap
		end
		if self:IsParticipant() then
			local musicController = self._context and self._context:GetController("MusicController")
			if musicController and musicController:GetCurrentState() ~= "Arena" then
				musicController:PlayArena(self._currentSelectedMap or "Default")
			end
		end
		if self._startCountdownFrame then
			if self._startCountdownTitle then
				self._startCountdownTitle.Text = "LA PARTIDA COMIENZA"
			end
			if self._startCountdownLabel then
				local duration = (extraData and extraData.Duration) or 5
				self._startCountdownLabel.Text = tostring(duration)
			end
			self._startCountdownFrame.Visible = true
		end

	elseif newState == Constants.RoundState.PointRestartCountdown then
		if extraData and extraData.MatchId then
			self._currentMatchId = extraData.MatchId
		end
		if self._startCountdownFrame then
			if self._startCountdownTitle then
				self._startCountdownTitle.Text = "SIGUIENTE PUNTO EN"
			end
			if self._startCountdownLabel then
				local duration = (extraData and extraData.Duration) or 3
				self._startCountdownLabel.Text = tostring(duration)
			end
			self._startCountdownFrame.Visible = true
		end
		if self._matchTimerFrame then self._matchTimerFrame.Visible = true end
		if self._redTeamFrame then self._redTeamFrame.Visible = true end
		if self._blueTeamFrame then self._blueTeamFrame.Visible = true end

	elseif newState == Constants.RoundState.Playing then
		if extraData and extraData.MatchId then
			self._currentMatchId = extraData.MatchId
		end
		if self._startCountdownFrame then
			self._startCountdownFrame.Visible = false
		end
		if self._matchTimerFrame then
			self._matchTimerFrame.Visible = true
		end
		if self._redTeamFrame then
			self._redTeamFrame.Visible = true
		end
		if self._blueTeamFrame then
			self._blueTeamFrame.Visible = true
		end

		-- Solo inicializar score a 0 al inicio formal de la partida (no tras un punto anotado)
		if prevState == Constants.RoundState.StartCountdown or prevState == Constants.RoundState.MapLoading then
			if self._redScoreLabel then
				self._redScoreLabel.Text = "0"
			end
			if self._blueScoreLabel then
				self._blueScoreLabel.Text = "0"
			end
		end

		self:_populatePlayers(
			extraData and extraData.RedTeam,
			extraData and extraData.BlueTeam,
			extraData and extraData.Red,
			extraData and extraData.Blue
		)

	elseif newState == Constants.RoundState.Ending then
		if self._resultFrame then
			self._resultFrame.Visible = true
		end
		if self._lastPointFrame then
			self._lastPointFrame.Visible = false
		end

	elseif newState == Constants.RoundState.ReturningToLobby or newState == Constants.RoundState.Waiting then
		local wasParticipant = self:IsParticipant()
		self._currentRole = nil
		self._selectedMapVote = nil
		self._currentMatchId = nil
		self._currentSelectedMap = nil
		if self._startCountdownFrame then self._startCountdownFrame.Visible = false end
		if self._redTeamFrame then self._redTeamFrame.Visible = false end
		if self._blueTeamFrame then self._blueTeamFrame.Visible = false end
		if self._lastPointFrame then self._lastPointFrame.Visible = false end
		self:_clearClonedButtons()
		self:_clearPlayerSlots()

		if wasParticipant or newState == Constants.RoundState.ReturningToLobby then
			local musicController = self._context and self._context:GetController("MusicController")
			if musicController then
				musicController:PlayLobby()
			end
		end
	end
end

function MatchController:_handleScoreUpdated(data: any)
	if type(data) ~= "table" then return end
	if self._redScoreLabel and data.Red ~= nil then
		self._redScoreLabel.Text = tostring(data.Red)
	end
	if self._blueScoreLabel and data.Blue ~= nil then
		self._blueScoreLabel.Text = tostring(data.Blue)
	end
	print(string.format("[MatchController] Score actualizado en HUD: Red=%s, Blue=%s",
		tostring(data.Red), tostring(data.Blue)))
end

function MatchController:_handleLastPoint(data: any)
	if not self._lastPointFrame or not self._lastPointTitle then return end
	local team = data and data.Team
	local message = data and data.Message or "ÚLTIMO PUNTO PARA GANAR LA PARTIDA"

	self._lastPointTitle.Text = message

	if self._lastPointSubtitle then
		if team == "Red" then
			self._lastPointSubtitle.Text = "¡EQUIPO ROJO A 1 PUNTO DE LA VICTORIA!"
			self._lastPointSubtitle.TextColor3 = Color3.fromRGB(255, 120, 120)
		elseif team == "Blue" then
			self._lastPointSubtitle.Text = "¡EQUIPO AZUL A 1 PUNTO DE LA VICTORIA!"
			self._lastPointSubtitle.TextColor3 = Color3.fromRGB(120, 180, 255)
		else
			self._lastPointSubtitle.Text = "¡A 1 punto de la victoria!"
			self._lastPointSubtitle.TextColor3 = Color3.fromRGB(255, 255, 255)
		end
	end

	self._lastPointFrame.Visible = true

	local token = os.clock()
	self._lastPointToken = token
	task.delay(4, function()
		if self._lastPointToken == token and self._lastPointFrame then
			self._lastPointFrame.Visible = false
		end
	end)
end

function MatchController:_clearPlayerSlots()
	for _, slot in ipairs(self._clonedSlots) do
		slot:Destroy()
	end
	self._clonedSlots = {}
end

function MatchController:_populatePlayers(redData: any, blueData: any, redFallback: string?, blueFallback: string?)
	self:_clearPlayerSlots()
	if not self._playerSlotTemplate then return end

	local createSlot = function(playerInfo: any, fallbackName: string?, container: Frame?, teamColor: Color3)
		if not container then return end
		local slot = self._playerSlotTemplate:Clone()
		local name = if type(playerInfo) == "table" and playerInfo.Name then playerInfo.Name else fallbackName or "Jugador"
		local displayName = if type(playerInfo) == "table" and playerInfo.DisplayName then playerInfo.DisplayName else name
		local userId = if type(playerInfo) == "table" and playerInfo.UserId then playerInfo.UserId else 0

		slot.Name = "Slot_" .. name
		local nameLabel = slot:FindFirstChild("DisplayName") :: TextLabel?
		if nameLabel then
			nameLabel.Text = displayName
		end

		local userLabel = slot:FindFirstChild("Username") :: TextLabel?
		if userLabel then
			userLabel.Text = "@" .. name
		end

		local avatarImg = slot:FindFirstChild("Avatar") :: ImageLabel?
		if avatarImg and userId > 0 then
			avatarImg.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=100&h=100", userId)
		end

		local stroke = slot:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = teamColor
		end

		slot.Visible = true
		slot.Parent = container
		table.insert(self._clonedSlots, slot)
	end

	-- Red team
	if type(redData) == "table" and #redData > 0 then
		for _, pInfo in ipairs(redData) do
			createSlot(pInfo, redFallback, self._redPlayersContainer, Color3.fromRGB(150, 40, 40))
		end
	else
		createSlot(nil, redFallback, self._redPlayersContainer, Color3.fromRGB(150, 40, 40))
	end

	-- Blue team
	if type(blueData) == "table" and #blueData > 0 then
		for _, pInfo in ipairs(blueData) do
			createSlot(pInfo, blueFallback, self._bluePlayersContainer, Color3.fromRGB(40, 90, 160))
		end
	else
		createSlot(nil, blueFallback, self._bluePlayersContainer, Color3.fromRGB(40, 90, 160))
	end
end

function MatchController:_handleCountdown(remaining: number, label: string, extraData: any?)
	if extraData and extraData.MatchId and self._currentMatchId and extraData.MatchId ~= self._currentMatchId then
		return -- Ignorar countdown de otra partida concurrente
	end

	if self._currentState == Constants.RoundState.MatchCountdown then
		if self._countdownTimer then
			self._countdownTimer.Text = tostring(remaining)
		end
	elseif self._currentState == Constants.RoundState.MapSelection then
		if self._mapTimer then
			self._mapTimer.Text = tostring(remaining)
		end
	elseif self._currentState == Constants.RoundState.StartCountdown
		or self._currentState == Constants.RoundState.PointRestartCountdown
		or label == "START_COUNTDOWN" then
		self:_updateStartCountdown(remaining, extraData)
	elseif self._currentState == Constants.RoundState.Playing then
		if self._matchTimer then
			self._matchTimer.Text = formatTime(remaining)
		end
	end
end

local COUNTDOWN = {
	-- Cadencia (suma 0.92 s, deja 0.08 s de margen de red dentro del segundo)
	EnterTime = 0.24,
	SettleTime = 0.18,
	HoldTime = 0.35,
	ExitTime = 0.15,

	-- Trayectoria cubica en "C" (coordenadas Scale de pantalla)
	StartPoint = Vector2.new(0.88, 0.05),
	ControlA = Vector2.new(0.14, -0.05),
	ControlB = Vector2.new(0.06, 0.66),
	EndPoint = Vector2.new(0.5, 0.5),
	ExitOffset = Vector2.new(-0.20, 0.22),

	-- Vuelo
	EnterEase = 1.6,          -- >1: acelera hacia el impacto
	FadeInPortion = 0.30,
	FlightStartScale = 0.40,
	FlightTilt = 16,          -- grados de inclinacion segun la velocidad
	StretchDepth = 0.9,       -- extrusion extra durante el vuelo (estiramiento)

	-- Impacto (resorte subamortiguado)
	ImpactScale = 0.25,
	ImpactSink = 0.016,
	SquashDepth = 0.75,       -- cuanto se comprime la extrusion al impactar
	SpringFreq = 24,
	SpringDamping = 0.42,
	ShineTime = 0.35,
	ShineStart = -0.6,

	-- Salida
	ExitRotation = -24,
	ExitScale = 0.5,

	-- Estela
	GhostCount = 3,
	GhostLag = 0.07,
	GhostTransparency = 0.55,

	-- Extrusion 3D
	DepthLayers = 8,
	DepthStep = 0.011,        -- fraccion de la altura del label por capa

	-- Climax
	StartTotal = 0.90,
	StartPunchTime = 0.14,
	StartExitTime = 0.16,
	StartPeakScale = 1.55,
	StartRestScale = 1.18,
	StartPushScale = 1.30,
	SparkCount = 14,
}

local NUMBER_TOTAL = COUNTDOWN.EnterTime + COUNTDOWN.SettleTime + COUNTDOWN.HoldTime + COUNTDOWN.ExitTime

local START_PALETTE: Palette = {
	Main = Color3.fromRGB(60, 235, 130),
	Shadow = Color3.fromRGB(10, 95, 50),
	Deep = Color3.fromRGB(4, 42, 22),
	Accent = Color3.fromRGB(200, 255, 220),
}

-- ===== Utilidades matematicas =====

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

local function easeOutCubic(x: number): number
	return 1 - (1 - x) ^ 3
end

-- Bezier cubica y su derivada (tangente)
local function bezier3(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: number): Vector2
	local u = 1 - t
	return p0 * (u * u * u) + p1 * (3 * u * u * t) + p2 * (3 * u * t * t) + p3 * (t * t * t)
end

local function bezier3Tangent(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: number): Vector2
	local u = 1 - t
	return (p1 - p0) * (3 * u * u) + (p2 - p1) * (6 * u * t) + (p3 - p2) * (3 * t * t)
end

-- Resorte subamortiguado: vale 1 en t = 0 y decae a 0 oscilando (pasa por valores negativos = rebote)
local function springKick(t: number, freq: number, damping: number): number
	if t <= 0 then
		return 1
	end
	local wd = freq * math.sqrt(1 - damping * damping)
	local decay = math.exp(-damping * freq * t)
	return decay * (math.cos(wd * t) + (damping * freq / wd) * math.sin(wd * t))
end

local function flightPoint(s: number): Vector2
	local c = COUNTDOWN
	return bezier3(c.StartPoint, c.ControlA, c.ControlB, c.EndPoint, s)
end

local function flightTilt(s: number): number
	local c = COUNTDOWN
	local tan = bezier3Tangent(c.StartPoint, c.ControlA, c.ControlB, c.EndPoint, s)
	return -tan.Unit.X * c.FlightTilt
end

local END_TILT = flightTilt(1)

-- ===== Poses (funciones puras del tiempo) =====

local function numberPose(t: number): Pose
	local c = COUNTDOWN
	local exitStart = c.EnterTime + c.SettleTime + c.HoldTime

	if t < c.EnterTime then
		local u = t / c.EnterTime
		local s = u ^ c.EnterEase
		local p = flightPoint(s)
		return {
			Position = UDim2.fromScale(p.X, p.Y),
			Rotation = flightTilt(s),
			Scale = lerp(c.FlightStartScale, 1 + c.ImpactScale, 1 - (1 - u) ^ 2),
			Transparency = 1 - clamp01(u / c.FadeInPortion),
			Depth = 1 + c.StretchDepth * u ^ 0.6,
			ShineY = 0,
		}
	end

	local ti = t - c.EnterTime
	local k = springKick(ti, c.SpringFreq, c.SpringDamping)
	local center = c.EndPoint
	local y = center.Y + c.ImpactSink * k
	local rot = END_TILT * k
	local scale = 1 + c.ImpactScale * k
	local depth = 1 - c.SquashDepth * k
	local shine = lerp(c.ShineStart, 0, easeOutCubic(clamp01(ti / c.ShineTime)))

	if t < exitStart then
		return {
			Position = UDim2.fromScale(center.X, y),
			Rotation = rot,
			Scale = scale,
			Transparency = 0,
			Depth = depth,
			ShineY = shine,
		}
	end

	local v = clamp01((t - exitStart) / c.ExitTime)
	local e = v * v
	return {
		Position = UDim2.fromScale(center.X + c.ExitOffset.X * e, y + c.ExitOffset.Y * e),
		Rotation = lerp(rot, c.ExitRotation, e),
		Scale = lerp(scale, c.ExitScale, e),
		Transparency = e,
		Depth = lerp(depth, 1.5, e),
		ShineY = 0,
	}
end

local function startPose(t: number): Pose
	local c = COUNTDOWN
	local center = c.EndPoint

	if t < c.StartPunchTime then
		local u = t / c.StartPunchTime
		local e = easeOutCubic(u)
		return {
			Position = UDim2.fromScale(center.X, center.Y),
			Rotation = -8 * (1 - e),
			Scale = lerp(0.15, c.StartPeakScale, e),
			Transparency = 1 - clamp01(u / 0.4),
			Depth = lerp(2.0, 1.6, u),
			ShineY = c.ShineStart,
		}
	end

	local ti = t - c.StartPunchTime
	local k = springKick(ti, 18, 0.36)
	local push = lerp(c.StartRestScale, c.StartPushScale, clamp01(ti / 0.6))
	local scale = push + (c.StartPeakScale - c.StartRestScale) * k
	local shake = 0.006 * k
	local transparency = 0

	local exitStart = c.StartTotal - c.StartExitTime
	if t >= exitStart then
		local v = clamp01((t - exitStart) / c.StartExitTime)
		local e = v * v
		scale *= lerp(1, 1.4, e)
		transparency = e
	end

	return {
		Position = UDim2.fromScale(center.X + shake * math.sin(ti * 95), center.Y + shake * math.cos(ti * 83)),
		Rotation = 3 * k * math.sin(ti * 60),
		Scale = scale,
		Transparency = transparency,
		Depth = 1.25 - 0.95 * k,
		ShineY = lerp(c.ShineStart, 0, easeOutCubic(clamp01(ti / c.ShineTime))),
	}
end

local function paletteForNumber(remaining: number): Palette
	local main: Color3
	local shadow: Color3
	if remaining <= 2 then
		main = Color3.fromRGB(255, 95, 95)
		shadow = Color3.fromRGB(130, 25, 25)
	else
		main = Color3.fromRGB(255, 215, 60)
		shadow = Color3.fromRGB(130, 65, 10)
	end
	return {
		Main = main,
		Shadow = shadow,
		Deep = shadow:Lerp(Color3.new(0, 0, 0), 0.55),
		Accent = main:Lerp(Color3.new(1, 1, 1), 0.65),
	}
end

-- ===== Construccion de capas (se crean UNA vez y se reutilizan) =====

local function copyTextStyle(target: TextLabel, source: TextLabel)
	target.FontFace = source.FontFace
	target.TextSize = source.TextSize
	target.TextScaled = source.TextScaled
	target.TextWrapped = source.TextWrapped
	target.LineHeight = source.LineHeight
	target.TextXAlignment = source.TextXAlignment
	target.TextYAlignment = source.TextYAlignment
	target.RichText = false
end

local function newStack(name: string, container: Frame, source: TextLabel, layerCount: number, baseZ: number, outlined: boolean): FxStack
	local root = Instance.new("Frame")
	root.Name = name
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.AnchorPoint = source.AnchorPoint
	root.Size = source.Size
	root.Position = source.Position
	root.ZIndex = baseZ
	root.Visible = false

	local scale = Instance.new("UIScale")
	scale.Name = "UIScale"
	scale.Parent = root

	local layers: { TextLabel } = {}
	local stroke: UIStroke? = nil
	for i = 1, layerCount do
		local layer = Instance.new("TextLabel")
		layer.Name = "Layer" .. i
		layer.BackgroundTransparency = 1
		layer.BorderSizePixel = 0
		layer.Size = UDim2.fromScale(1, 1)
		layer.Position = UDim2.fromScale(0, 0)
		layer.ZIndex = baseZ + (layerCount - i) -- la capa 1 (pegada a la cara) queda arriba
		layer.Text = ""
		copyTextStyle(layer, source)
		if outlined and i == layerCount then
			local s = Instance.new("UIStroke")
			s.Name = "DeepStroke"
			s.Thickness = 4
			s.Color = Color3.fromRGB(10, 6, 3)
			s.Parent = layer
			stroke = s
		end
		layer.Parent = root
		table.insert(layers, layer)
	end

	root.Parent = container
	return { Root = root, Scale = scale, Layers = layers, Stroke = stroke }
end

local function newBurst(container: Frame): BurstFx
	local burst = Instance.new("Frame")
	burst.Name = "Burst"
	burst.BackgroundTransparency = 1
	burst.BorderSizePixel = 0
	burst.Size = UDim2.fromScale(1, 1)
	burst.ZIndex = 3
	burst.Visible = false
	burst.Parent = container

	local rings: { Frame } = {}
	local ringStrokes: { UIStroke } = {}
	for i = 1, 2 do
		local ring = Instance.new("Frame")
		ring.Name = "Ring" .. i
		ring.BackgroundTransparency = 1
		ring.BorderSizePixel = 0
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.SizeConstraint = Enum.SizeConstraint.RelativeYY -- circulo perfecto en cualquier resolucion
		ring.Size = UDim2.fromScale(0.1, 0.1)
		ring.ZIndex = 4
		ring.Visible = false

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = ring

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 8
		stroke.Parent = ring

		ring.Parent = burst
		table.insert(rings, ring)
		table.insert(ringStrokes, stroke)
	end

	local rng = Random.new(1337)
	local sparks: { Frame } = {}
	local angles: { number } = {}
	local reach: { number } = {}
	for i = 1, COUNTDOWN.SparkCount do
		local spark = Instance.new("Frame")
		spark.Name = "Spark" .. i
		spark.BorderSizePixel = 0
		spark.AnchorPoint = Vector2.new(0.5, 0.5)
		spark.SizeConstraint = Enum.SizeConstraint.RelativeYY
		spark.Size = UDim2.fromScale(0.06, 0.012)
		spark.ZIndex = 5
		spark.Visible = false

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = spark

		spark.Parent = burst
		table.insert(sparks, spark)
		table.insert(angles, (i - 1) / COUNTDOWN.SparkCount * math.pi * 2 + rng:NextNumber(-0.12, 0.12))
		table.insert(reach, rng:NextNumber(0.26, 0.48))
	end

	return { Container = burst, Rings = rings, RingStrokes = ringStrokes, Sparks = sparks, SparkAngles = angles, SparkReach = reach }
end

local function buildCountdownFx(frame: Frame, label: TextLabel): CountdownFx
	-- Limpieza de restos (evita duplicados si el controlador se reinicia)
	local staleFx = frame:FindFirstChild("CountdownFx")
	if staleFx then
		staleFx:Destroy()
	end
	local staleShadow = label:FindFirstChild("Shadow3D")
	if staleShadow then
		staleShadow:Destroy()
	end

	-- El label siempre por encima de las capas FX (vale para ZIndexBehavior Sibling y Global)
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.ZIndex = math.max(label.ZIndex, 50)

	local container = Instance.new("Frame")
	container.Name = "CountdownFx"
	container.BackgroundTransparency = 1
	container.BorderSizePixel = 0
	container.Size = UDim2.fromScale(1, 1)
	container.Position = UDim2.fromScale(0, 0)
	container.ZIndex = 2
	container.Parent = frame

	local burst = newBurst(container)
	local extrusion = newStack("Extrusion", container, label, COUNTDOWN.DepthLayers, 10, true)
	local ghosts: { FxStack } = {}
	for g = 1, COUNTDOWN.GhostCount do
		table.insert(ghosts, newStack("Ghost" .. g, container, label, 1, 30 + g, false))
	end

	return { Container = container, Extrusion = extrusion, Ghosts = ghosts, Burst = burst }
end

-- ===== Sincronizacion label <-> capas =====

local function paintRig(rig: CountdownRig, text: string, palette: Palette)
	local label = rig.Label
	label.Text = text
	label.TextColor3 = palette.Main

	local layers = rig.Fx.Extrusion.Layers
	local n = #layers
	for i, layer in ipairs(layers) do
		copyTextStyle(layer, label)
		layer.Text = text
		layer.TextColor3 = palette.Shadow:Lerp(palette.Deep, if n > 1 then (i - 1) / (n - 1) else 0)
	end

	for _, ghost in ipairs(rig.Fx.Ghosts) do
		for _, layer in ipairs(ghost.Layers) do
			copyTextStyle(layer, label)
			layer.Text = text
			layer.TextColor3 = palette.Main
		end
	end

	local burst = rig.Fx.Burst
	burst.RingStrokes[1].Color = palette.Accent
	burst.RingStrokes[2].Color = palette.Main
	for i, spark in ipairs(burst.Sparks) do
		spark.BackgroundColor3 = if i % 2 == 0 then palette.Accent else palette.Main
	end
end

local function applyPose(rig: CountdownRig, pose: Pose)
	local label = rig.Label
	label.Position = pose.Position
	label.Rotation = pose.Rotation
	rig.UIScale.Scale = pose.Scale
	label.TextTransparency = pose.Transparency
	if rig.Stroke then
		rig.Stroke.Transparency = pose.Transparency
	end
	if rig.Gradient then
		rig.Gradient.Offset = Vector2.new(0, pose.ShineY)
	end

	local ext = rig.Fx.Extrusion
	ext.Root.Visible = pose.Transparency < 0.999
	ext.Root.Position = pose.Position
	ext.Root.Rotation = pose.Rotation
	ext.Scale.Scale = pose.Scale
	for i, layer in ipairs(ext.Layers) do
		layer.Position = UDim2.fromScale(0, COUNTDOWN.DepthStep * i * pose.Depth)
		layer.TextTransparency = pose.Transparency
	end
	if ext.Stroke then
		ext.Stroke.Transparency = pose.Transparency
	end
end

local function updateGhosts(rig: CountdownRig, t: number)
	local c = COUNTDOWN
	for g, ghost in ipairs(rig.Fx.Ghosts) do
		local u = t / c.EnterTime - c.GhostLag * g
		local visible = t < c.EnterTime and u > 0
		ghost.Root.Visible = visible
		if visible then
			local s = u ^ c.EnterEase
			local p = flightPoint(s)
			ghost.Root.Position = UDim2.fromScale(p.X, p.Y)
			ghost.Root.Rotation = flightTilt(s)
			ghost.Scale.Scale = lerp(c.FlightStartScale, 1 + c.ImpactScale, 1 - (1 - u) ^ 2)
			local transparency = math.max(c.GhostTransparency + (g - 1) * 0.12, 1 - clamp01(u / c.FadeInPortion))
			for _, layer in ipairs(ghost.Layers) do
				layer.TextTransparency = transparency
			end
		end
	end
end

local function hideGhosts(rig: CountdownRig)
	for _, ghost in ipairs(rig.Fx.Ghosts) do
		ghost.Root.Visible = false
	end
end

local RING_TIMING = {
	{ delay = 0, duration = 0.45, size = 2.2 },
	{ delay = 0.07, duration = 0.50, size = 1.5 },
}

local function updateBurst(rig: CountdownRig, t: number)
	local burst = rig.Fx.Burst
	burst.Container.Visible = true

	for i, ring in ipairs(burst.Rings) do
		local timing = RING_TIMING[i]
		local w = clamp01((t - timing.delay) / timing.duration)
		ring.Visible = t >= timing.delay and w < 1
		if ring.Visible then
			local e = easeOutCubic(w)
			local d = lerp(0.18, timing.size, e)
			ring.Size = UDim2.fromScale(d, d)
			burst.RingStrokes[i].Thickness = lerp(14, 1, w)
			burst.RingStrokes[i].Transparency = lerp(0.1, 1, w)
		end
	end

	local abs = rig.Frame.AbsoluteSize
	local aspect = if abs.X > 0 then abs.Y / abs.X else 1
	local w = clamp01((t - 0.02) / 0.5)
	local e = easeOutCubic(w)
	for i, spark in ipairs(burst.Sparks) do
		spark.Visible = t > 0.02 and w < 1
		if spark.Visible then
			local angle = burst.SparkAngles[i]
			local dist = burst.SparkReach[i] * e
			spark.Position = UDim2.fromScale(0.5 + math.cos(angle) * dist * aspect, 0.5 + math.sin(angle) * dist)
			spark.Rotation = math.deg(angle)
			spark.Size = UDim2.fromScale(0.06 * (1 - 0.7 * w), 0.012)
			spark.BackgroundTransparency = w * w
		end
	end
end

local function hideBurst(rig: CountdownRig)
	local burst = rig.Fx.Burst
	burst.Container.Visible = false
	for _, ring in ipairs(burst.Rings) do
		ring.Visible = false
	end
	for _, spark in ipairs(burst.Sparks) do
		spark.Visible = false
	end
end

-- ===== API del controlador =====

function MatchController:_getCountdownRig(): CountdownRig?
	local frame = self._startCountdownFrame
	local label = self._startCountdownLabel
	if not frame or not label then
		return nil
	end

	local fx = self._countdownFx
	if not fx or fx.Container.Parent ~= frame then
		fx = buildCountdownFx(frame, label)
		self._countdownFx = fx
	end

	local uiScale = label:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Parent = label
	end

	return {
		Frame = frame,
		Label = label,
		UIScale = uiScale :: UIScale,
		Stroke = label:FindFirstChildOfClass("UIStroke"),
		Gradient = label:FindFirstChildOfClass("UIGradient"),
		Fx = fx :: CountdownFx,
	}
end

function MatchController:_stopStartCountdownAnimation()
	self._countdownAnimToken += 1
	local conn = self._countdownConn
	if conn then
		conn:Disconnect()
		self._countdownConn = nil
	end
end

function MatchController:_updateStartCountdown(remaining: number, extraData: any?)
	local frame = self._startCountdownFrame
	if not frame or not self._startCountdownLabel then
		return
	end

	local isStarted = (remaining == 0) or (extraData and extraData.Started == true)
	local isPointRestart = (extraData and extraData.Phase == "PointRestart")
		or (self._currentState == Constants.RoundState.PointRestartCountdown)

	frame.Visible = true

	if self._startCountdownTitle then
		self._startCountdownTitle.Text = if isPointRestart then "SIGUIENTE PUNTO EN" else "LA PARTIDA COMIENZA"
	end

	local rig = self:_getCountdownRig()
	if not rig then
		return
	end

	-- Cancela cualquier animacion previa y reclama un token nuevo
	self:_stopStartCountdownAnimation()
	local myToken = self._countdownAnimToken

	local palette = if isStarted then START_PALETTE else paletteForNumber(remaining)
	paintRig(rig, if isStarted then "¡COMIENZA!" else tostring(remaining), palette)
	rig.Fx.Extrusion.Root.Visible = false
	hideGhosts(rig)
	hideBurst(rig)

	local startClock = os.clock()

	-- Un fotograma: devuelve true cuando la animacion termino
	local function step(): boolean
		local t = os.clock() - startClock
		if isStarted then
			applyPose(rig, startPose(t))
			updateBurst(rig, t)
			return t >= COUNTDOWN.StartTotal
		end
		applyPose(rig, numberPose(t))
		updateGhosts(rig, t)
		return t >= NUMBER_TOTAL
	end

	local function finish()
		hideGhosts(rig)
		hideBurst(rig)
		if isStarted
			and (self._currentState == Constants.RoundState.Playing or self._currentState == Constants.RoundState.Waiting)
		then
			frame.Visible = false
			rig.UIScale.Scale = 1
		end
	end

	-- Primer fotograma inmediato: el label nunca se ve un frame en la pose anterior
	if step() then
		finish()
		return
	end

	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		if self._countdownAnimToken ~= myToken then
			if conn then
				conn:Disconnect()
			end
			return
		end
		if step() then
			if conn then
				conn:Disconnect()
			end
			if self._countdownConn == conn then
				self._countdownConn = nil
			end
			finish()
		end
	end)
	self._countdownConn = conn
end

function MatchController:_clearClonedButtons()
	for _, btn in pairs(self._clonedButtons) do
		btn:Destroy()
	end
	self._clonedButtons = {}
end

function MatchController:_populateMapSelection(maps: { string })
	if not self._mapsContainer or not self._mapButtonTemplate then return end

	self:_clearClonedButtons()

	for _, mapName in ipairs(maps) do
		local btn = self._mapButtonTemplate:Clone()
		btn.Name = "Btn_" .. mapName

		local mapNameLabel = btn:FindFirstChild("MapName") :: TextLabel?
		if mapNameLabel then
			mapNameLabel.Text = mapName
		end

		btn.Visible = true
		btn.MouseButton1Click:Connect(function()
			self:_submitVote(mapName, btn)
		end)

		btn.Parent = self._mapsContainer
		self._clonedButtons[mapName] = btn
	end
end

function MatchController:_submitVote(votePayload: string, clickedButton: TextButton?)
	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	local matchFolder = remotesFolder and remotesFolder:FindFirstChild("Match")
	local mapSelection = matchFolder and matchFolder:FindFirstChild("MapSelection") :: RemoteEvent?

	if mapSelection then
		mapSelection:FireServer(votePayload)
	end

	self:_highlightSelectedVote(votePayload)
end

function MatchController:_resetButtonHighlights()
	if self._randomButton then
		local stroke = self._randomButton:FindFirstChildOfClass("UIStroke")
		self._randomButton.BackgroundColor3 = Color3.fromRGB(45, 55, 80)
		if stroke then stroke.Color = Color3.fromRGB(90, 120, 180); stroke.Thickness = 1.5 end
	end

	for _, btn in pairs(self._clonedButtons) do
		local stroke = btn:FindFirstChildOfClass("UIStroke")
		btn.BackgroundColor3 = Color3.fromRGB(30, 38, 55)
		if stroke then stroke.Color = Color3.fromRGB(60, 80, 120); stroke.Thickness = 1 end
	end
end

function MatchController:_highlightSelectedVote(votePayload: string)
	self._selectedMapVote = votePayload
	self:_resetButtonHighlights()

	if votePayload == Constants.SpecialMapVote.Random or votePayload == "Aleatorio" then
		if self._randomButton then
			local stroke = self._randomButton:FindFirstChildOfClass("UIStroke")
			self._randomButton.BackgroundColor3 = Color3.fromRGB(50, 100, 180)
			if stroke then stroke.Color = Color3.fromRGB(120, 200, 255); stroke.Thickness = 2 end
		end
	else
		local btn = self._clonedButtons[votePayload]
		if btn then
			local stroke = btn:FindFirstChildOfClass("UIStroke")
			btn.BackgroundColor3 = Color3.fromRGB(40, 90, 160)
			if stroke then stroke.Color = Color3.fromRGB(100, 180, 255); stroke.Thickness = 2 end
		end
	end
end

function MatchController:_handleMatchResult(result: string, winnerName: string?)
	if not self._resultFrame or not self._resultTitle or not self._resultSubtitle then return end

	local stroke = self._resultFrame:FindFirstChildOfClass("UIStroke")

	if result == Constants.MatchResult.Draw then
		self._resultTitle.Text = "EMPATE"
		self._resultTitle.TextColor3 = Color3.fromRGB(200, 205, 215)
		self._resultSubtitle.Text = "Se agoto el tiempo de la partida"
		if stroke then stroke.Color = Color3.fromRGB(150, 160, 180) end

	elseif result == Constants.MatchResult.Cancelled then
		self._resultTitle.Text = "CANCELADO"
		self._resultTitle.TextColor3 = Color3.fromRGB(230, 100, 100)
		self._resultSubtitle.Text = "Un jugador abandono la partida"
		if stroke then stroke.Color = Color3.fromRGB(200, 60, 60) end

	else
		local myRole = self._currentRole
		local isWinner = false

		if myRole and result == myRole then
			isWinner = true
		end

		if isWinner then
			self._resultTitle.Text = "VICTORIA"
			self._resultTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
			self._resultSubtitle.Text = string.format("¡Has ganado la partida contra %s!", winnerName == localPlayer.Name and "tu oponente" or (winnerName or ""))
			if stroke then stroke.Color = Color3.fromRGB(255, 215, 0) end
		else
			self._resultTitle.Text = "DERROTA"
			self._resultTitle.TextColor3 = Color3.fromRGB(230, 70, 70)
			self._resultSubtitle.Text = string.format("Ganador: %s", winnerName or result)
			if stroke then stroke.Color = Color3.fromRGB(220, 50, 50) end
		end
	end

	self._resultFrame.Visible = true
end

return MatchController
