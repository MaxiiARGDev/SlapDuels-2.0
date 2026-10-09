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

	local initialData: PlayerData = {
		Coins = (Config.Economy and Config.Economy.StartingCoins) or 0,
		Wins = (Config.Economy and Config.Economy.StartingWins) or 0,
		Losses = (Config.Economy and Config.Economy.StartingLosses) or 0,
		Kills = (Config.Economy and Config.Economy.StartingKills) or 0,
		Inventory = {
			Owned = {
				["PointEffects"] = { [PointEffectDefinitions.DefaultEffectId] = true },
			},
			Equipped = {
				["PointEffects"] = PointEffectDefinitions.DefaultEffectId,
			},
		},
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
				if record.Inventory then
					initialData.Inventory = record.Inventory
				end
			else
				warn(string.format("[PlayerService] No se pudo cargar PlayerData de '%s' (err: %s). Usando valores seguros no persistibles.", player.Name, tostring(err)))
			end
		end
	end

	self._data[player] = initialData
	self._coins[player] = initialData.Coins
	self._kills[player] = initialData.Kills
	self._ownedPointEffects[player] = initialData.Inventory.Owned["PointEffects"]
	self._equippedPointEffects[player] = initialData.Inventory.Equipped["PointEffects"] or PointEffectDefinitions.DefaultEffectId

	local pName = if type(player) == "table" and player.Name then player.Name elseif typeof(player) == "Instance" then player.Name else tostring(player)
	print(string.format("[PlayerService] Registrado: %s (Coins=%d, Wins=%d, Losses=%d, Kills=%d, PointEffect: %s)",
		pName, initialData.Coins, initialData.Wins, initialData.Losses, initialData.Kills, tostring(self._equippedPointEffects[player])))

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

-- Deduce monedas del jugador de forma server-authoritative (retorna éxito y nuevo balance)
function PlayerService:DeductCoins(player: any, amount: number, reason: string?): (boolean, number)
	if not player or amount <= 0 then
		return false, self:GetCoins(player)
	end

	local data = self._data[player]
	if not data then
		self:_register(player)
		data = self._data[player]
	end

	if data.Coins < amount then
		return false, data.Coins
	end

	local newBalance = data.Coins - amount
	data.Coins = newBalance
	self._coins[player] = newBalance

	local pName = if type(player) == "table" and player.Name then player.Name elseif typeof(player) == "Instance" then player.Name else tostring(player)
	print(string.format("[PlayerService] -%d Coins deducidos de '%s' (Razón: %s). Saldo restante: %d",
		amount, pName, reason or "ShopPurchase", newBalance))

	self:_sendDataUpdate(player)
	return true, newBalance
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
			Inventory = data.Inventory,
		}
	end
	return {
		Coins = self:GetCoins(player),
		Wins = 0,
		Losses = 0,
		Kills = 0,
		Inventory = {
			Owned = {
				["PointEffects"] = { [PointEffectDefinitions.DefaultEffectId] = true },
			},
			Equipped = {
				["PointEffects"] = PointEffectDefinitions.DefaultEffectId,
			},
		},
	}
end

-- ==================================================
-- INTERFAZ AUTORITATIVA GENÉRICA DE INVENTORY
-- ==================================================

-- Obtiene el inventario completo del jugador
function PlayerService:GetInventory(player: any): Types.PlayerInventory?
	local data = self._data[player]
	if not data then return nil end
	return data.Inventory
end

-- Verifica si el jugador posee un ítem en una categoría específica
function PlayerService:HasItem(player: any, category: string, productId: string): boolean
	if not player or type(category) ~= "string" or type(productId) ~= "string" then
		return false
	end

	-- Regla especial universal: PointEffects.Basic siempre es poseído
	if category == "PointEffects" and productId == PointEffectDefinitions.DefaultEffectId then
		return true
	end

	local data = self._data[player]
	if not data or not data.Inventory or not data.Inventory.Owned then
		return false
	end

	local catOwned = data.Inventory.Owned[category]
	return catOwned ~= nil and catOwned[productId] == true
end

-- Otorga propiedad de un ítem en una categoría genérica (server-authoritative)
function PlayerService:AddItem(player: any, category: string, productId: string): (boolean, string?)
	if not player then
		return false, "PlayerNotFound"
	end
	if type(category) ~= "string" or category == "" then
		return false, "InvalidCategory"
	end
	if type(productId) ~= "string" or productId == "" then
		return false, "InvalidProductId"
	end

	local data = self._data[player]
	if not data then
		self:_register(player)
		data = self._data[player]
	end

	if not data.Inventory then
		data.Inventory = { Owned = {}, Equipped = {} }
	end
	if not data.Inventory.Owned then
		data.Inventory.Owned = {}
	end
	if not data.Inventory.Owned[category] then
		data.Inventory.Owned[category] = {}
	end

	data.Inventory.Owned[category][productId] = true

	-- Mantener referencias auxiliares de PointEffects sincronizadas
	if category == "PointEffects" then
		self._ownedPointEffects[player] = data.Inventory.Owned[category]
	end

	local pName = if type(player) == "table" and player.Name then player.Name elseif typeof(player) == "Instance" then player.Name else tostring(player)
	print(string.format("[PlayerService] Jugador '%s' adquirió ítem: [%s] '%s'", pName, category, productId))

	self:_sendDataUpdate(player)
	return true, nil
end

-- Retorna el ítem equipado actualmente en una categoría
function PlayerService:GetEquippedItem(player: any, category: string): string?
	if not player or type(category) ~= "string" then
		return nil
	end

	local data = self._data[player]
	if not data or not data.Inventory or not data.Inventory.Equipped then
		if category == "PointEffects" then
			return PointEffectDefinitions.DefaultEffectId
		end
		return nil
	end

	local equipped = data.Inventory.Equipped[category]

	if category == "PointEffects" then
		if not equipped or not PointEffectDefinitions.IsValid(equipped) or not self:HasItem(player, category, equipped) then
			return PointEffectDefinitions.DefaultEffectId
		end
		return equipped
	end

	if equipped and not self:HasItem(player, category, equipped) then
		return nil
	end

	return equipped
end

-- Equipa un ítem en una categoría (valida propiedad y disponibilidad)
function PlayerService:SetEquippedItem(player: any, category: string, productId: string?): (boolean, string?)
	if not player then
		return false, "PlayerNotFound"
	end
	if type(category) ~= "string" or category == "" then
		return false, "InvalidCategory"
	end

	local data = self._data[player]
	if not data then
		self:_register(player)
		data = self._data[player]
	end

	if not data.Inventory then
		data.Inventory = { Owned = {}, Equipped = {} }
	end
	if not data.Inventory.Equipped then
		data.Inventory.Equipped = {}
	end

	if productId == nil or productId == "" then
		return self:UnequipItem(player, category)
	end

	if not self:HasItem(player, category, productId) then
		warn(string.format("[PlayerService] Jugador no posee el ítem: [%s] '%s'", category, productId))
		return false, "NotOwned"
	end

	data.Inventory.Equipped[category] = productId

	if category == "PointEffects" then
		self._equippedPointEffects[player] = productId
	end

	local pName = if type(player) == "table" and player.Name then player.Name elseif typeof(player) == "Instance" then player.Name else tostring(player)
	print(string.format("[PlayerService] Jugador '%s' equipó ítem: [%s] '%s'", pName, category, productId))

	self:_sendDataUpdate(player)
	return true, nil
end

-- Desequipa el ítem de una categoría (restituye default seguro si aplica)
function PlayerService:UnequipItem(player: any, category: string): (boolean, string?)
	if not player then
		return false, "PlayerNotFound"
	end
	if type(category) ~= "string" or category == "" then
		return false, "InvalidCategory"
	end

	local data = self._data[player]
	if not data or not data.Inventory then
		return false, "NoInventory"
	end
	if not data.Inventory.Equipped then
		data.Inventory.Equipped = {}
	end

	if category == "PointEffects" then
		data.Inventory.Equipped["PointEffects"] = PointEffectDefinitions.DefaultEffectId
		self._equippedPointEffects[player] = PointEffectDefinitions.DefaultEffectId
	else
		data.Inventory.Equipped[category] = nil
	end

	local pName = if type(player) == "table" and player.Name then player.Name elseif typeof(player) == "Instance" then player.Name else tostring(player)
	print(string.format("[PlayerService] Jugador '%s' desequipó categoría: [%s]", pName, category))

	self:_sendDataUpdate(player)
	return true, nil
end

-- ==================================================
-- INTERFAZ ESPECÍFICA DE POINT EFFECTS (WRAPPERS SOBRE INVENTORY)
-- ==================================================

-- Verifica si el jugador posee un PointEffect específico
function PlayerService:HasPointEffect(player: any, effectId: string): boolean
	return self:HasItem(player, "PointEffects", effectId)
end

-- Retorna el diccionario de efectos que posee el jugador
function PlayerService:GetOwnedPointEffects(player: any): { [string]: boolean }
	local inv = self:GetInventory(player)
	local owned = (inv and inv.Owned and inv.Owned["PointEffects"]) or {}
	local copy = { [PointEffectDefinitions.DefaultEffectId] = true }
	for k, v in pairs(owned) do
		copy[k] = v
	end
	return copy
end

-- Agrega un efecto a la lista de efectos poseídos (wrapper compatible)
function PlayerService:AddOwnedPointEffect(player: any, effectId: string): (boolean, string?)
	if not PointEffectDefinitions.IsValid(effectId) then
		return false, "InvalidEffectId"
	end
	return self:AddItem(player, "PointEffects", effectId)
end

-- Retorna el PointEffect equipado por el jugador (con fallback seguro obligatorio a Basic)
function PlayerService:GetEquippedPointEffect(player: any): string
	return self:GetEquippedItem(player, "PointEffects") or PointEffectDefinitions.DefaultEffectId
end

-- Equipa autoritativamente un PointEffect para el jugador (wrapper compatible)
function PlayerService:SetEquippedPointEffect(player: any, effectId: string): (boolean, string?)
	if not PointEffectDefinitions.IsValid(effectId) then
		warn(string.format("[PlayerService] Intento de equipar effectId inexistente: '%s'", tostring(effectId)))
		return false, "InvalidEffectId"
	end
	return self:SetEquippedItem(player, "PointEffects", effectId)
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
