--!strict
-- LeaderboardScrollController
-- Controlador de cliente para hacer que el scroll en las 3 pantallas de TOPS-SCREENS
-- sea interactivo, fluido y responda a la rueda del ratón (MouseWheel), botones táctiles y cercanía.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local LeaderboardScrollController = {}
LeaderboardScrollController.Name = "LeaderboardScrollController"

local localPlayer = Players.LocalPlayer
local MAX_INTERACTION_DISTANCE = 35 -- Distancia máxima en studs para interactuar con la pantalla
local SCROLL_STEP = 180 -- Cantidad de píxeles a scrollear por paso (aprox. 3 filas)

local targetScreens: { { ModelName: string, PartName: string, GuiName: string } } = {
	{ ModelName = "TopWins", PartName = "Screen_TopWins", GuiName = "SurfaceGui_TopWins" },
	{ ModelName = "TopKills", PartName = "Screen_TopKills", GuiName = "SurfaceGui_TopKills" },
	{ ModelName = "TopRachas", PartName = "Screen_TopRachas", GuiName = "SurfaceGui_TopRachas" },
}

function LeaderboardScrollController:Init(_context: any)
	-- Inicialización del controlador de scroll de leaderboards
end

function LeaderboardScrollController:Start(_context: any)
	local function getClosestScreenScroll(): ScrollingFrame?
		local character = localPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then return nil end

		local stands = Workspace:FindFirstChild("stands") and Workspace.stands:FindFirstChild("TOPS-SCREENS")
		if not stands then return nil end

		local closestScroll: ScrollingFrame? = nil
		local closestDist = MAX_INTERACTION_DISTANCE

		for _, cfg in ipairs(targetScreens) do
			local model = stands:FindFirstChild(cfg.ModelName)
			local part = model and model:FindFirstChild(cfg.PartName) :: BasePart?
			if part then
				local dist = (root.Position - part.Position).Magnitude
				if dist < closestDist then
					closestDist = dist
					local gui = part:FindFirstChild(cfg.GuiName)
					local main = gui and gui:FindFirstChild("MainFrame")
					local scroll = main and main:FindFirstChild("ScrollList") :: ScrollingFrame?
					if scroll then
						closestScroll = scroll
					end
				end
			end
		end

		return closestScroll
	end

	-- 1. Soporte para rueda de ratón (MouseWheel) cuando el jugador está frente a la pantalla
	UserInputService.InputChanged:Connect(function(input: InputObject, gameProcessed: boolean)
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			local activeScroll = getClosestScreenScroll()
			if activeScroll then
				local delta = -input.Position.Z * SCROLL_STEP
				local maxCanvas = math.max(0, activeScroll.AbsoluteCanvasSize.Y - activeScroll.AbsoluteWindowSize.Y)
				local targetY = math.clamp(activeScroll.CanvasPosition.Y + delta, 0, maxCanvas)
				activeScroll.CanvasPosition = Vector2.new(0, targetY)
			end
		end
	end)

	-- 2. Conectar botones de navegación táctil/click (si existen en el GUI)
	task.spawn(function()
		local stands = Workspace:WaitForChild("stands", 15)
		local topScreens = stands and stands:WaitForChild("TOPS-SCREENS", 15)
		if not topScreens then return end

		for _, cfg in ipairs(targetScreens) do
			local model = topScreens:WaitForChild(cfg.ModelName, 10)
			local part = model and model:WaitForChild(cfg.PartName, 10)
			local gui = part and part:WaitForChild(cfg.GuiName, 10)
			local main = gui and gui:WaitForChild("MainFrame", 10)
			local scroll = main and main:WaitForChild("ScrollList", 10) :: ScrollingFrame?

			if scroll and main then
				-- Asegurar propiedades nativas de interactividad en el SurfaceGui y ScrollingFrame
				if gui:IsA("SurfaceGui") then
					gui.AlwaysOnTop = false
					gui.MaxDistance = 50
					gui.Active = true
				end

				scroll.Active = true
				scroll.Selectable = true
				scroll.ScrollingEnabled = true
				scroll.ScrollBarThickness = 10

				-- Conectar botón de subir
				local btnUp = main:FindFirstChild("ScrollUpBtn", true) :: TextButton?
				if btnUp then
					btnUp.Activated:Connect(function()
						local targetY = math.max(0, scroll.CanvasPosition.Y - (SCROLL_STEP * 2))
						scroll.CanvasPosition = Vector2.new(0, targetY)
					end)
				end

				-- Conectar botón de bajar
				local btnDown = main:FindFirstChild("ScrollDownBtn", true) :: TextButton?
				if btnDown then
					btnDown.Activated:Connect(function()
						local maxCanvas = math.max(0, scroll.AbsoluteCanvasSize.Y - scroll.AbsoluteWindowSize.Y)
						local targetY = math.min(maxCanvas, scroll.CanvasPosition.Y + (SCROLL_STEP * 2))
						scroll.CanvasPosition = Vector2.new(0, targetY)
					end)
				end
			end
		end
	end)

	print("[LeaderboardScrollController] Controlador de scroll físico en cliente activo.")
end

return LeaderboardScrollController
