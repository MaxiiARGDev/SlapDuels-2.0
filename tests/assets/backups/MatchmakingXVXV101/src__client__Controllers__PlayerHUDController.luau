--!strict
-- PlayerHUDController
-- Controlador del HUD global del jugador (Avatar, Nombre, Coins, Wins, Losses).
-- Se enlaza con StarterGui.PlayerHUD (replicado a PlayerGui.PlayerHUD)
-- y escucha las actualizaciones autoritativas emitidas por PlayerService.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Types = require(ReplicatedStorage.Shared.Types)

type PlayerData = Types.PlayerData

local localPlayer = Players.LocalPlayer

local PlayerHUDController = {}
PlayerHUDController.Name = "PlayerHUDController"

-- Referencias a instancias de PlayerGui.PlayerHUD
PlayerHUDController._hud = nil :: ScreenGui?
PlayerHUDController._profileCard = nil :: Frame?
PlayerHUDController._avatar = nil :: ImageLabel?
PlayerHUDController._playerName = nil :: TextLabel?
PlayerHUDController._winsLabel = nil :: TextLabel?
PlayerHUDController._lossesLabel = nil :: TextLabel?
PlayerHUDController._killsLabel = nil :: TextLabel?
PlayerHUDController._coinsContainer = nil :: Frame?
PlayerHUDController._coinsLabel = nil :: TextLabel?

-- Estado interno
PlayerHUDController._currentCoins = 0
PlayerHUDController._currentWins = 0
PlayerHUDController._currentLosses = 0
PlayerHUDController._currentKills = 0
PlayerHUDController._coinTween = nil :: Tween?
PlayerHUDController._coinAnimValue = nil :: NumberValue?
PlayerHUDController._origCoinsContainerSize = nil :: UDim2?

function PlayerHUDController:Init(context: any)
	self:_bindHUD()
end

function PlayerHUDController:Start(context: any)
	self:_setupIdentity()
	self:_connectRemotes()
	print("[PlayerHUDController] HUD global iniciado y enlazado a PlayerGui.PlayerHUD")
end

function PlayerHUDController:_bindHUD()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("PlayerHUD", 15) :: ScreenGui?
	if not hud then
		warn("[PlayerHUDController] No se encontro PlayerHUD en PlayerGui")
		return
	end
	self._hud = hud

	local profileCard = hud:WaitForChild("ProfileCard", 10) :: Frame?
	if not profileCard then
		warn("[PlayerHUDController] No se encontro ProfileCard en PlayerHUD")
		return
	end
	self._profileCard = profileCard

	self._avatar = profileCard:FindFirstChild("Avatar") :: ImageLabel?
	self._playerName = profileCard:FindFirstChild("PlayerName") :: TextLabel?
	self._winsLabel = profileCard:FindFirstChild("WinsLabel") :: TextLabel?
	self._lossesLabel = profileCard:FindFirstChild("LossesLabel") :: TextLabel?
	self._killsLabel = profileCard:FindFirstChild("KillsLabel") :: TextLabel?

	local coinsContainer = profileCard:FindFirstChild("CoinsContainer") :: Frame?
	if coinsContainer then
		self._coinsContainer = coinsContainer
		self._origCoinsContainerSize = coinsContainer.Size
		self._coinsLabel = coinsContainer:FindFirstChild("CoinsLabel") :: TextLabel?
	end

	-- NumberValue auxiliar para interpolación suave de Coins
	local animVal = Instance.new("NumberValue")
	animVal.Value = 0
	animVal.Changed:Connect(function(val: number)
		if self._coinsLabel then
			self._coinsLabel.Text = string.format("%d", math.floor(val + 0.5))
		end
	end)
	self._coinAnimValue = animVal
end

function PlayerHUDController:_setupIdentity()
	-- Nombre del jugador
	if self._playerName then
		self._playerName.Text = localPlayer.DisplayName or localPlayer.Name
	end

	-- Avatar circular del jugador usando thumbnail oficial de Roblox
	if self._avatar then
		local thumbType = Enum.ThumbnailType.HeadShot
		local thumbSize = Enum.ThumbnailSize.Size150x150
		task.spawn(function()
			local content, isReady = Players:GetUserThumbnailAsync(localPlayer.UserId, thumbType, thumbSize)
			if self._avatar then
				self._avatar.Image = content
			end
		end)
	end

	-- Estado inicial por defecto en UI
	self:_renderData({
		Coins = self._currentCoins,
		Wins = self._currentWins,
		Losses = self._currentLosses,
	}, false)
end

function PlayerHUDController:_connectRemotes()
	local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 10)
	if not remotesFolder then
		warn("[PlayerHUDController] Carpeta Remotes no encontrada en ReplicatedStorage")
		return
	end

	local playerRemotes = remotesFolder:WaitForChild("Player", 10)
	if not playerRemotes then
		warn("[PlayerHUDController] Carpeta Remotes.Player no encontrada")
		return
	end

	local dataUpdated = playerRemotes:WaitForChild("DataUpdated", 10) :: RemoteEvent?
	if not dataUpdated then
		warn("[PlayerHUDController] RemoteEvent DataUpdated no encontrado")
		return
	end

	dataUpdated.OnClientEvent:Connect(function(data: PlayerData)
		if type(data) ~= "table" then
			return
		end
		self:_renderData(data, true)
	end)
end

function PlayerHUDController:_renderData(data: PlayerData, animateChanges: boolean)
	local newCoins = if typeof(data.Coins) == "number" then data.Coins else self._currentCoins
	local newWins = if typeof(data.Wins) == "number" then data.Wins else self._currentWins
	local newLosses = if typeof(data.Losses) == "number" then data.Losses else self._currentLosses
	local newKills = if typeof(data.Kills) == "number" then data.Kills else self._currentKills

	-- Actualizar Wins
	if self._winsLabel then
		self._winsLabel.Text = string.format("Wins: %d", newWins)
	end
	self._currentWins = newWins

	-- Actualizar Losses
	if self._lossesLabel then
		self._lossesLabel.Text = string.format("Losses: %d", newLosses)
	end
	self._currentLosses = newLosses

	-- Actualizar Kills (si KillsLabel existe en la UI)
	if self._killsLabel then
		self._killsLabel.Text = string.format("Kills: %d", newKills)
	end
	self._currentKills = newKills

	-- Actualizar Coins con animación si aumenta
	local oldCoins = self._currentCoins
	self._currentCoins = newCoins

	if animateChanges and newCoins > oldCoins and self._coinAnimValue and self._coinsLabel then
		self:_animateCoinsIncrease(oldCoins, newCoins)
	else
		if self._coinAnimValue then
			self._coinAnimValue.Value = newCoins
		end
		if self._coinsLabel then
			self._coinsLabel.Text = string.format("%d", newCoins)
		end
	end
end

function PlayerHUDController:_animateCoinsIncrease(fromVal: number, toVal: number)
	if not self._coinAnimValue then
		return
	end

	if self._coinTween then
		self._coinTween:Cancel()
		self._coinTween = nil
	end

	self._coinAnimValue.Value = fromVal

	-- Interpolación de número durante 0.25 segundos
	local tweenInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tween = TweenService:Create(self._coinAnimValue, tweenInfo, { Value = toVal })
	self._coinTween = tween
	tween:Play()

	-- Feedback visual sutil (pulse) en CoinsContainer
	if self._coinsContainer and self._origCoinsContainerSize then
		local origSize = self._origCoinsContainerSize
		local popSize = UDim2.new(
			origSize.X.Scale,
			origSize.X.Offset + 8,
			origSize.Y.Scale,
			origSize.Y.Offset + 4
		)

		local popTween = TweenService:Create(
			self._coinsContainer,
			TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Size = popSize }
		)
		local returnTween = TweenService:Create(
			self._coinsContainer,
			TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Size = origSize }
		)

		popTween.Completed:Connect(function()
			returnTween:Play()
		end)
		popTween:Play()
	end
end

return PlayerHUDController
