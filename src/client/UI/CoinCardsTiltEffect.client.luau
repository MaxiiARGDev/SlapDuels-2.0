--!strict
-- CoinCardsTiltEffect
-- Efecto 3D de inclinación interactiva al pasar el ratón (Smooth 3D Tilt & Parallax)
-- para las tarjetas de la Tienda Premium. 100% nativo y compatible con CanvasGroup.

local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local container = script.Parent :: GuiObject
if not container then return end

local MAX_TILT_DEG = 3.5 -- Grados máximos de rotación
local PARALLAX_OFFSET = 6 -- Píxeles de desplazamiento hacia el cursor (sensación de elevación)
local HOVER_SCALE = 1.04 -- Escala al pasar el ratón por encima
local LERP_SPEED = 14 -- Velocidad de suavizado

type CardState = {
	card: GuiObject,
	origPos: UDim2,
	origZIndex: number,
	scaleObj: UIScale,
	isHovered: boolean,
	currentRot: number,
	currentX: number,
	currentY: number,
	currentScale: number,
	targetRot: number,
	targetX: number,
	targetY: number,
	targetScale: number,
	reflejo: ImageLabel?,
	origReflejoPos: UDim2?,
}

local cardStates: { CardState } = {}

for _, child in ipairs(container:GetChildren()) do
	if child.Name == "Paquete de monedas" and child:IsA("GuiObject") then
		local origPos = child.Position
		local origZIndex = child.ZIndex

		-- Asegurar UIScale para elevación limpia
		local scaleObj = child:FindFirstChild("TiltScale") :: UIScale?
		if not scaleObj then
			scaleObj = Instance.new("UIScale")
			scaleObj.Name = "TiltScale"
			scaleObj.Scale = 1
			scaleObj.Parent = child
		end

		local reflejo = child:FindFirstChild("Reflejo angular", true) :: ImageLabel?
		local origReflejoPos = reflejo and reflejo.Position or nil

		local state: CardState = {
			card = child,
			origPos = origPos,
			origZIndex = origZIndex,
			scaleObj = scaleObj,
			isHovered = false,
			currentRot = 0,
			currentX = 0,
			currentY = 0,
			currentScale = 1,
			targetRot = 0,
			targetX = 0,
			targetY = 0,
			targetScale = 1,
			reflejo = reflejo,
			origReflejoPos = origReflejoPos,
		}

		child.MouseEnter:Connect(function()
			state.isHovered = true
			state.targetScale = HOVER_SCALE
			child.ZIndex = origZIndex + 20
		end)

		child.MouseLeave:Connect(function()
			state.isHovered = false
			state.targetRot = 0
			state.targetX = 0
			state.targetY = 0
			state.targetScale = 1
			child.ZIndex = origZIndex
		end)

		table.insert(cardStates, state)
	end
end

-- Bucle de interpolación suave (RenderStepped)
RunService.RenderStepped:Connect(function(dt: number)
	local mousePos = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
	local factor = math.clamp(dt * LERP_SPEED, 0, 1)

	for _, state in ipairs(cardStates) do
		local card = state.card
		if not card.Parent then continue end

		if state.isHovered then
			local absPos = card.AbsolutePosition
			local absSize = card.AbsoluteSize
			if absSize.X > 0 and absSize.Y > 0 then
				local center = absPos + (absSize * 0.5)
				local nx = math.clamp((mousePos.X - center.X) / (absSize.X * 0.5), -1, 1)
				local ny = math.clamp((mousePos.Y - center.Y) / (absSize.Y * 0.5), -1, 1)

				state.targetRot = nx * MAX_TILT_DEG
				state.targetX = nx * PARALLAX_OFFSET
				state.targetY = ny * PARALLAX_OFFSET
			end
		end

		-- Suavizado lerp
		state.currentRot += (state.targetRot - state.currentRot) * factor
		state.currentX += (state.targetX - state.currentX) * factor
		state.currentY += (state.targetY - state.currentY) * factor
		state.currentScale += (state.targetScale - state.currentScale) * factor

		-- Aplicar transformaciones
		card.Rotation = state.currentRot
		card.Position = UDim2.new(
			state.origPos.X.Scale,
			state.origPos.X.Offset + state.currentX,
			state.origPos.Y.Scale,
			state.origPos.Y.Offset + state.currentY
		)
		state.scaleObj.Scale = state.currentScale

		-- Efecto de reflejo de luz (brillo que acompaña el ángulo de inclinación)
		if state.reflejo and state.origReflejoPos then
			state.reflejo.Position = UDim2.new(
				state.origReflejoPos.X.Scale,
				state.origReflejoPos.X.Offset - (state.currentX * 1.5),
				state.origReflejoPos.Y.Scale,
				state.origReflejoPos.Y.Offset - (state.currentY * 1.5)
			)
		end
	end
end)
