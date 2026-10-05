--!strict
-- SettingsController
-- Controlador cliente de la interfaz de configuración (Settings/Ajustes).
-- Gestiona la interfaz de usuario de forma modular y se comunica exclusivamente
-- con MusicController para aplicar cambios de volumen y estado de la música.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer

local SettingsController = {}
SettingsController.Name = "SettingsController"

-- Referencias a instancias de PlayerGui.SettingsGUI
SettingsController._hud = nil :: ScreenGui?
SettingsController._openButton = nil :: TextButton?
SettingsController._mainFrame = nil :: Frame?
SettingsController._closeButton = nil :: TextButton?

-- AudioSection - Music Toggle
SettingsController._musicToggle = nil :: TextButton?
SettingsController._toggleStatusText = nil :: TextLabel?
SettingsController._toggleStroke = nil :: UIStroke?

-- AudioSection - Music Slider
SettingsController._volumePercent = nil :: TextLabel?
SettingsController._slider = nil :: TextButton?
SettingsController._sliderTrack = nil :: Frame?
SettingsController._sliderFill = nil :: Frame?
SettingsController._sliderKnob = nil :: Frame?

-- Estado interno
SettingsController._context = nil :: any
SettingsController._isDragging = false
SettingsController._dragConnection = nil :: RBXScriptConnection?
SettingsController._endedConnection = nil :: RBXScriptConnection?

--------------------------------------------------------------------------------
-- Enlace a la Interfaz de Usuario
--------------------------------------------------------------------------------

function SettingsController:_bindHUD()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("SettingsGUI", 15) :: ScreenGui?
	if not hud then
		warn("[SettingsController] No se encontro SettingsGUI en PlayerGui")
		return
	end
	self._hud = hud

	-- Botón de apertura global (en esquina de pantalla)
	self._openButton = hud:WaitForChild("SettingsButton", 5) :: TextButton?

	-- Modal principal
	local mainFrame = hud:WaitForChild("MainFrame", 5) :: Frame?
	if not mainFrame then
		warn("[SettingsController] No se encontro MainFrame en SettingsGUI")
		return
	end
	self._mainFrame = mainFrame
	mainFrame.Visible = false

	-- Header y botón de cierre
	local header = mainFrame:FindFirstChild("Header")
	if header then
		self._closeButton = header:FindFirstChild("CloseButton") :: TextButton?
	end

	-- Sección de Audio
	local content = mainFrame:FindFirstChild("Content")
	local audioSection = content and content:FindFirstChild("AudioSection")
	if audioSection then
		-- Toggle de Música
		local toggleRow = audioSection:FindFirstChild("MusicToggleRow")
		if toggleRow then
			local toggle = toggleRow:FindFirstChild("MusicToggle") :: TextButton?
			if toggle then
				self._musicToggle = toggle
				self._toggleStatusText = toggle:FindFirstChild("StatusText") :: TextLabel?
				self._toggleStroke = toggle:FindFirstChildOfClass("UIStroke")
			end
		end

		-- Slider de Volumen
		local volumeRow = audioSection:FindFirstChild("MusicVolumeRow")
		if volumeRow then
			local topRow = volumeRow:FindFirstChild("TopRow")
			if topRow then
				self._volumePercent = topRow:FindFirstChild("MusicVolumePercent") :: TextLabel?
			end

			local slider = volumeRow:FindFirstChild("MusicSlider") :: TextButton?
			if slider then
				self._slider = slider
				self._sliderTrack = slider:FindFirstChild("Track") :: Frame?
				if self._sliderTrack then
					self._sliderFill = self._sliderTrack:FindFirstChild("Fill") :: Frame?
				end
				self._sliderKnob = slider:FindFirstChild("Knob") :: Frame?
			end
		end
	end
end

--------------------------------------------------------------------------------
-- Conexión de Eventos de Interacción (Mouse, Touch, Móvil)
--------------------------------------------------------------------------------

function SettingsController:_connectEvents()
	-- 1. Apertura y Cierre
	if self._openButton then
		self._openButton.Activated:Connect(function()
			self:Toggle()
		end)
	end

	if self._closeButton then
		self._closeButton.Activated:Connect(function()
			self:Close()
		end)
	end

	-- 2. Toggle de Música (ON / OFF)
	if self._musicToggle then
		self._musicToggle.Activated:Connect(function()
			local musicController = self:_getMusicController()
			if not musicController then return end

			local current = musicController:IsMusicEnabled()
			local nextState = not current
			musicController:SetMusicEnabled(nextState)
			self:_updateToggleUI(nextState)
		end)
	end

	-- 3. Slider de Volumen (Soporte Mouse y Touch Drag)
	if self._slider then
		self._slider.InputBegan:Connect(function(input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				self._isDragging = true
				self:_processSliderInput(input.Position.X, false)

				self:_setupGlobalDragListeners()
			end
		end)
	end
end

function SettingsController:_setupGlobalDragListeners()
	self:_cleanupGlobalDragListeners()

	-- Movimiento continuo (arrastre del slider con mouse o dedo en pantalla táctil)
	self._dragConnection = UserInputService.InputChanged:Connect(function(input: InputObject)
		if not self._isDragging then return end

		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			self:_processSliderInput(input.Position.X, true)
		end
	end)

	-- Fin del arrastre
	self._endedConnection = UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			if self._isDragging then
				self._isDragging = false
				self:_processSliderInput(input.Position.X, false)
				self:_cleanupGlobalDragListeners()
			end
		end
	end)
end

function SettingsController:_cleanupGlobalDragListeners()
	if self._dragConnection then
		self._dragConnection:Disconnect()
		self._dragConnection = nil
	end
	if self._endedConnection then
		self._endedConnection:Disconnect()
		self._endedConnection = nil
	end
end

--------------------------------------------------------------------------------
-- Procesamiento Matemático del Slider
--------------------------------------------------------------------------------

function SettingsController:_processSliderInput(inputX: number, isDragging: boolean)
	if not self._slider then return end

	local sliderAbsPos = self._slider.AbsolutePosition
	local sliderAbsSize = self._slider.AbsoluteSize
	if sliderAbsSize.X <= 0 then return end

	local relativeX = inputX - sliderAbsPos.X
	local volumeFraction = math.clamp(relativeX / sliderAbsSize.X, 0, 1)

	-- Actualizar UI visualmente al instante
	self:_updateSliderUI(volumeFraction)

	-- Enviar valor autoritativo al MusicController
	local musicController = self:_getMusicController()
	if musicController then
		-- Si está en arrastre continuo usar fadeDuration 0 para latencia cero
		local fade = if isDragging then 0 else 0.1
		musicController:SetMusicVolume(volumeFraction, fade)
	end
end

--------------------------------------------------------------------------------
-- Actualización Visual de Componentes
--------------------------------------------------------------------------------

function SettingsController:_updateToggleUI(enabled: boolean)
	if self._musicToggle then
		local targetColor = if enabled
			then Color3.fromRGB(40, 140, 75)
			else Color3.fromRGB(45, 55, 75)
		local targetStroke = if enabled
			then Color3.fromRGB(60, 180, 100)
			else Color3.fromRGB(65, 80, 105)

		self._musicToggle.BackgroundColor3 = targetColor
		if self._toggleStroke then
			self._toggleStroke.Color = targetStroke
		end
	end

	if self._toggleStatusText then
		self._toggleStatusText.Text = if enabled then "ON" else "OFF"
		self._toggleStatusText.TextColor3 = if enabled
			then Color3.fromRGB(255, 255, 255)
			else Color3.fromRGB(160, 175, 200)
	end
end

function SettingsController:_updateSliderUI(volume: number)
	local clamped = math.clamp(volume, 0, 1)
	local percentInt = math.floor(clamped * 100 + 0.5)

	-- Porcentaje de texto
	if self._volumePercent then
		self._volumePercent.Text = string.format("%d%%", percentInt)
	end

	-- Barra de relleno (Fill)
	if self._sliderFill then
		self._sliderFill.Size = UDim2.new(clamped, 0, 1, 0)
	end

	-- Perilla de arrastre (Knob)
	if self._sliderKnob then
		self._sliderKnob.Position = UDim2.new(clamped, 0, 0.5, 0)
	end
end

--------------------------------------------------------------------------------
-- Sincronización y Acceso a MusicController
--------------------------------------------------------------------------------

function SettingsController:_getMusicController(): any
	if self._context and typeof(self._context.GetController) == "function" then
		return self._context:GetController("MusicController")
	end
	return nil
end

function SettingsController:SyncWithMusicController()
	local musicController = self:_getMusicController()
	if not musicController then return end

	local enabled = musicController:IsMusicEnabled()
	local volume = musicController:GetMusicVolume()

	self:_updateToggleUI(enabled)
	self:_updateSliderUI(volume)
end

--------------------------------------------------------------------------------
-- API Pública
--------------------------------------------------------------------------------

function SettingsController:Open()
	if self._mainFrame then
		self:SyncWithMusicController()
		self._mainFrame.Visible = true
	end
end

function SettingsController:Close()
	if self._mainFrame then
		self._mainFrame.Visible = false
		self._isDragging = false
		self:_cleanupGlobalDragListeners()
	end
end

function SettingsController:Toggle()
	if self._mainFrame then
		if self._mainFrame.Visible then
			self:Close()
		else
			self:Open()
		end
	end
end

function SettingsController:IsOpen(): boolean
	return self._mainFrame ~= nil and self._mainFrame.Visible == true
end

--------------------------------------------------------------------------------
-- Ciclo de Vida Bootstrap
--------------------------------------------------------------------------------

function SettingsController:Init(context: any)
	self._context = context
	self:_bindHUD()
end

function SettingsController:Start(context: any)
	self._context = context
	self:_connectEvents()
	self:SyncWithMusicController()
	print("[SettingsController] Controlador de ajustes iniciado y enlazado a SettingsGUI")
end

return SettingsController
