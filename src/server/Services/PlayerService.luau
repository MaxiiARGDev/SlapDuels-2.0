--!strict
-- PlayerService
-- Ciclo de vida de jugadores: registro/desregistro, estado económico y datos runtime (Coins, Wins, Losses).
-- Servidor autoritativo. Integrado con PlayerDataService para persistencia segura vía DataStoreService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PointEffectDefinitions = require(ReplicatedStorage.Shared.PointEffectDefinitions)
local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

type PlayerData = Types.PlayerData

local PlayerService = {}
PlayerService.Name = "PlayerService"

PlayerService._context = nil :: any
PlayerService._registered = {}
PlayerService._connections = {} :: { RBXScriptConnection }
PlayerService._data = {} :: { [any]: PlayerData }
PlayerService._coins = {} :: { [any]: number } -- Retrocompatibilidad
PlayerService._kills = {} :: { [any]: number }
PlayerService._ownedPointEffects = {} :: { [any]: { [string]: boolean } }
PlayerService._equippedPointEffects = {} :: { [any]: string }
PlayerService._dataUpdatedRemote = nil :: RemoteEvent?
PlayerService._playerDataService = nil :: any

-- Utilidad para garantizar la existencia de RemoteEvents
local function ensureRemote(parent: Instance, name: string): RemoteEvent
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = parent
	return remote
end

local function ensureFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function PlayerService:Init(context)
	self._context = context
	self._registered = {}
	self._connections = {}
	self._data = {}
	self._coins = {}
	self._kills = {}
	self._ownedPointEffects = {}
	self._equippedPointEffects = {}

	self:_getDataUpdatedRemote()
end

function PlayerService:_getDataUpdatedRemote(): RemoteEvent?
	if self._dataUpdatedRemote and self._dataUpdatedRemote.Parent then
		return self._dataUpdatedRemote
	end
	local remotesFolder = ensureFolder(ReplicatedStorage, "Remotes")
	local playerFolder = ensureFolder(remotesFolder, "Player")
	local remote = ensureRemote(playerFolder, "DataUpdated")
	self._dataUpdatedRemote = remote
	return remote
end

-- Envía actualización autoritativa de datos al cliente correspondiente
function PlayerService:_sendDataUpdate(player: any)
	local remote = self:_getDataUpdatedRemote()
	if not remote then return end
	if typeof(player) == "Instance" and player:IsA("Player") then
		local data = self:GetPlayerData(player)
		remote:FireClient(player, data)
	end
end

function PlayerService:_getPlayerDataService(): any
	if self._playerDataService then
		return self._playerDataService
	end
	if self._context and type(self._context.GetService) == "function" then
		local s = self._context:GetService("PlayerDataService")
		if s then
			self._playerDataService = s
			return s
		end
	end
	local ok, mod = pcall(require, script.Parent.PlayerDataService)
	if ok and mod then
		self._playerDataService = mod
		return mod
	end
	return nil
end

function PlayerService:_register(player: any)
	self._registered[player] = {}
	self._ownedPointEffects[player] = {
		[PointEffectDefinitions.DefaultEffectId] = true,
	}
	self._equippedPointEffects[player] = PointEffectDefinitions.DefaultEffectId

	local initialData: PlayerData = {
		Coins = (Config.Economy and Config.Economy.StartingCoins) or 0,
		Wins = (Config.Economy and Config.Economy.StartingWins) or 0,
		Losses = (Config.Economy and Config.Economy.StartingLosses) or 0,
		Kills = (Config.Economy and Config.Economy.StartingKills) or 0,
	}

	if typeof(player) == "Instance" and player:IsA("Player") then
		local pds = self:_getPlayerDataService()
		if pds and type(pds.LoadPlayer) == "function" then
			local ok, record, err = pds:LoadPlayer(player)
			if ok and record then
				initialData.Coins = record.Coins
				initialData.Wins = record.Wins
				initialData.Losses = record.Losses
				initialData.Kills = record.Kills or 0
			else
				warn(string.format("[PlayerService] No se pudo cargar PlayerData de '%s' (err: %s). Usando valores seguros no persistibles.", player.Name, tostring(err)))
			end
		end
	end

	self._data[player] = initialData
	self._coins[player] = initialData.Coins
	self._kills[player] = initialData.Kills

	local pName = if type(player) == "table" and player.Name then player.Name elseif typeof(player) == "Instance" then player.Name else tostring(player)
	print(string.format("[PlayerService] Registrado: %s (Coins=%d, Wins=%d, Losses=%d, Kills=%d, PointEffect: %s)",
		pName, initialData.Coins, initialData.Wins, initialData.Losses, initialData.Kills, PointEffectDefinitions.DefaultEffectId))

	-- Enviar estado inicial cargado al jugador (el HUD muestra inmediatamente datos reales sin parpadeo de 0)
	self:_sendDataUpdate(player)
end

function PlayerService:_unregister(player: any)
	if typeof(player) == "Instance" and player:IsA("Player") then
		local pds = self:_getPlayerDataService()
		if pds and type(pds.SavePlayer) == "function" then
			local currentData = self._data[player]
			pds:SavePlayer(player, currentData)
			if type(pds.Cleanup) == "function" then
				pds:Cleanup(player)
			end
		end
	end

	self._registered[player] = nil
	self._data[player] = nil
	self._coins[player] = nil
	self._kills[player] = nil
	self._ownedPointEffects[player] = nil
	self._equippedPointEffects[player] = nil

	local pName = if type(player) == "table" and player.Name then player.Name elseif typeof(player) == "Instance" then player.Name else tostring(player)
	print(string.format("[PlayerService] Desregistrado: %s", pName))
end

-- ==================================================
-- INTERFAZ AUTORITATIVA DE ECONOMÍA Y ESTADÍSTICAS
-- ==================================================

function PlayerService:AddCoins(player: any, amount: number, reason: string): number
	if not player or amount <= 0 then
		return self:GetCoins(player)
	end

	local data = self._data[player]
	if not data then
		self:_register(player)
		data = self._data[player]
	end

	local newBalance = data.Coins + amount
	data.Coins = newBalance
	self._coins[player] = newBalance

	local pName = if type(player) == "table" and player.Name then player.Name elseif typeof(player) == "Instance" then player.Name else tostring(player)
	print(string.format("[PlayerService] +%d Coins otorgados a '%s' (Razón: %s). Saldo: %d",
		amount, pName, reason or "Unspecified", newBalance))

	self:_sendDataUpdate(player)
	return newBalance
end

function PlayerService:GetCoins(player: any): number
	local data = self._data[player]
	return (data and data.Coins) or self._coins[player] or 0
end

function PlayerService:AddWin(player: any, reason: string?): number
	if not player then return 0 end

	local data = self._data[player]
	if not data then
		self:_register(player)
		data = self._data[player]
	end

	data.Wins += 1
	local pName = if type(player) == "table" and player.Name then player.Name elseif typeof(player) == "Instance" then player.Name else tostring(player)
	print(string.format("[PlayerService] +1 Win otorgado a '%s' (Razón: %s). Total Wins: %d",
		pName, reason or "MatchWin", data.Wins))

	self:_sendDataUpdate(player)
	return data.Wins
end

function PlayerService:GetWins(player: any): number
	local data = self._data[player]
	return (data and data.Wins) or 0
end

function PlayerService:AddLoss(player: any, reason: string?): number
	if not player then return 0 end

	local data = self._data[player]
	if not data then
		self:_register(player)
		data = self._data[player]
	end

	data.Losses += 1
	local pName = if type(player) == "table" and player.Name then player.Name elseif typeof(player) == "Instance" then player.Name else tostring(player)
	print(string.format("[PlayerService] +1 Loss registrado a '%s' (Razón: %s). Total Losses: %d",
		pName, reason or "MatchLoss", data.Losses))

	self:_sendDataUpdate(player)
	return data.Losses
end

function PlayerService:GetLosses(player: any): number
	local data = self._data[player]
	return (data and data.Losses) or 0
end

function PlayerService:AddKill(player: any, amount: number?, reason: string?): number
	if not player then return 0 end
	local addAmt = amount or 1
	if addAmt <= 0 then
		return self:GetKills(player)
	end

	local data = self._data[player]
	if not data then
		self:_register(player)
		data = self._data[player]
	end

	data.Kills = (data.Kills or 0) + addAmt
	self._kills[player] = data.Kills

	local pName = if type(player) == "table" and player.Name then player.Name elseif typeof(player) == "Instance" then player.Name else tostring(player)
	print(string.format("[PlayerService] +%d Kill(s) registrado a '%s' (Razón: %s). Total Kills: %d",
		addAmt, pName, reason or "Elimination", data.Kills))

	self:_sendDataUpdate(player)
	return data.Kills
end

function PlayerService:GetKills(player: any): number
	local data = self._data[player]
	return (data and data.Kills) or self._kills[player] or 0
end

function PlayerService:GetPlayerData(player: any): PlayerData
	local data = self._data[player]
	if data then
		return {
			Coins = data.Coins,
			Wins = data.Wins,
			Losses = data.Losses,
			Kills = data.Kills or 0,
		}
	end
	return {
		Coins = self:GetCoins(player),
		Wins = 0,
		Losses = 0,
		Kills = 0,
	}
end

-- ==================================================
-- INTERFAZ AUTORITATIVA DE POINT EFFECTS (COSMÉTICOS)
-- ==================================================

-- Verifica si el jugador posee un PointEffect específico
function PlayerService:HasPointEffect(player: any, effectId: string): boolean
	if effectId == PointEffectDefinitions.DefaultEffectId then
		return true -- Basic está disponible para todos los jugadores de forma universal
	end
	if not player then return false end
	local owned = self._ownedPointEffects[player]
	return (owned ~= nil and owned[effectId] == true)
end

-- Retorna el diccionario de efectos que posee el jugador
function PlayerService:GetOwnedPointEffects(player: any): { [string]: boolean }
	if not player then
		return { [PointEffectDefinitions.DefaultEffectId] = true }
	end
	local owned = self._ownedPointEffects[player]
	if not owned then
		return { [PointEffectDefinitions.DefaultEffectId] = true }
	end

	local copy = {}
	for k, v in pairs(owned) do
		copy[k] = v
	end
	return copy
end

-- Agrega un efecto a la lista de efectos poseídos (preparado para compras de tienda / desbloqueos)
function PlayerService:AddOwnedPointEffect(player: any, effectId: string): (boolean, string?)
	if not player then
		return false, "PlayerNotFound"
	end
	if not PointEffectDefinitions.IsValid(effectId) then
		return false, "InvalidEffectId"
	end

	local owned = self._ownedPointEffects[player]
	if not owned then
		owned = { [PointEffectDefinitions.DefaultEffectId] = true }
		self._ownedPointEffects[player] = owned
	end

	owned[effectId] = true
	local pName = if type(player) == "table" and player.Name then player.Name elseif typeof(player) == "Instance" then player.Name else tostring(player)
	print(string.format("[PlayerService] Jugador '%s' desbloqueó PointEffect: '%s'", pName, effectId))
	return true, nil
end

-- Retorna el PointEffect equipado por el jugador (con fallback seguro obligatorio a Basic)
function PlayerService:GetEquippedPointEffect(player: any): string
	if not player then
		return PointEffectDefinitions.DefaultEffectId
	end

	local equipped = self._equippedPointEffects[player]
	if not equipped or not PointEffectDefinitions.IsValid(equipped) then
		return PointEffectDefinitions.DefaultEffectId
	end

	-- Validar defensivamente que realmente lo posea
	if not self:HasPointEffect(player, equipped) then
		return PointEffectDefinitions.DefaultEffectId
	end

	return equipped
end

-- Equipa autoritativamente un PointEffect para el jugador
function PlayerService:SetEquippedPointEffect(player: any, effectId: string): (boolean, string?)
	if not player then
		return false, "PlayerNotFound"
	end

	if not PointEffectDefinitions.IsValid(effectId) then
		warn(string.format("[PlayerService] Intento de equipar effectId inexistente: '%s'", tostring(effectId)))
		return false, "InvalidEffectId"
	end

	if not self:HasPointEffect(player, effectId) then
		warn(string.format("[PlayerService] Jugador no posee el efecto '%s'", effectId))
		return false, "NotOwned"
	end

	self._equippedPointEffects[player] = effectId
	local pName = if type(player) == "table" and player.Name then player.Name elseif typeof(player) == "Instance" then player.Name else tostring(player)
	print(string.format("[PlayerService] Jugador '%s' equipó PointEffect: '%s'", pName, effectId))
	return true, nil
end

function PlayerService:Start(context)
	self._context = context
	table.insert(self._connections, Players.PlayerAdded:Connect(function(player)
		self:_register(player)
	end))
	table.insert(self._connections, Players.PlayerRemoving:Connect(function(player)
		self:_unregister(player)
	end))

	for _, player in ipairs(Players:GetPlayers()) do
		self:_register(player)
	end
end

return PlayerService
