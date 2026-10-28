--!strict
-- PlayerService
-- Ciclo de vida de jugadores: registro/desregistro, estado económico y datos runtime (Coins, Wins, Losses).
-- Servidor autoritativo. Integrado con PlayerDataService para persistencia segura vía DataStoreService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WinStreak = require(script.Parent.Gameplay.WinStreak)
local Progression = require(game.ReplicatedStorage.Shared.Progression.Model)
local Players = game:GetService("Players")

local PointEffectDefinitions = require(ReplicatedStorage.Shared.PointEffectDefinitions)
local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local ProfilePurchase = require(script.Parent.Parent.Shop.ProfilePurchase)
local Constants = require(ReplicatedStorage.Shared.Constants)
local DeathSettings = require(ReplicatedStorage.Shared.DeathFeedbackConfig).DeathEffects

type PlayerData = Types.PlayerData

local PlayerService = {}
PlayerService.Name = "PlayerService"

PlayerService._context = nil :: any
PlayerService._registered = {}
PlayerService._connections = {} :: { RBXScriptConnection }
PlayerService._data = {} :: { [any]: PlayerData }
PlayerService._coins = {} :: { [any]: number } -- Retrocompatibilidad
PlayerService._kills = {} :: { [any]: number }
PlayerService._coinTransactions = {} :: { [any]: { [string]: boolean } }
PlayerService._ownedPointEffects = {} :: { [any]: { [string]: boolean } }
PlayerService._equippedPointEffects = {} :: { [any]: string }
PlayerService._dataUpdatedRemote = nil :: RemoteEvent?
PlayerService._playerDataService = nil :: any
PlayerService._shopClosing = {} :: { [any]: boolean }
PlayerService._shopShutdown = false

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
	self._shopClosing = {}
	self._shopShutdown = false
	self._connections = {}
	self._data = {}
	self._coins = {}
	self._kills = {}
	self._coinTransactions = {}
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

-- Sincroniza las estadísticas del jugador con el folder nativo leaderstats de Roblox
function PlayerService:_syncLeaderstats(player: any, data: PlayerData)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		local folder = Instance.new("Folder")
		folder.Name = "leaderstats"

		local coinsVal = Instance.new("IntValue")
		coinsVal.Name = "Coins"
		coinsVal.Value = data.Coins
		coinsVal.Parent = folder

		local winsVal = Instance.new("IntValue")
		winsVal.Name = "Wins"
		winsVal.Value = data.Wins
		winsVal.Parent = folder

		local killsVal = Instance.new("IntValue")
		killsVal.Name = "Kills"
		killsVal.Value = data.Kills or 0
		killsVal.Parent = folder

		folder.Parent = player
	else
		local coinsVal = leaderstats:FindFirstChild("Coins") :: IntValue?
		if not coinsVal then
			coinsVal = Instance.new("IntValue")
			coinsVal.Name = "Coins"
			coinsVal.Value = data.Coins
			coinsVal.Parent = leaderstats
		else
			coinsVal.Value = data.Coins
		end

		local winsVal = leaderstats:FindFirstChild("Wins") :: IntValue?
		if not winsVal then
			winsVal = Instance.new("IntValue")
			winsVal.Name = "Wins"
			winsVal.Value = data.Wins
			winsVal.Parent = leaderstats
		else
			winsVal.Value = data.Wins
		end

		local killsVal = leaderstats:FindFirstChild("Kills") :: IntValue?
		if not killsVal then
			killsVal = Instance.new("IntValue")
			killsVal.Name = "Kills"
			killsVal.Value = data.Kills or 0
			killsVal.Parent = leaderstats
		else
			killsVal.Value = data.Kills or 0
		end
	end
end

-- Envía actualización autoritativa de datos al cliente correspondiente y sincroniza leaderstats
function PlayerService:_sendDataUpdate(player: any, rewardReceipt: any?)
	local backSlap = self._context and self._context:GetService("BackSlapService")
	if backSlap then
		local ok, failure = pcall(backSlap.Refresh, backSlap, player)
		if not ok then warn("[PlayerService] Back Slap cosmetic refresh failed: " .. tostring(failure)) end
	end
	if typeof(player) == "Instance" and player:IsA("Player") then
		local data = self:GetPlayerData(player)
		local progress = Progression.Normalize(data.Progression)
		local level = Progression.Level(progress.TotalXP)
		player:SetAttribute("Level", level)
		player:SetAttribute("TotalXP", progress.TotalXP)
		self:_syncLeaderstats(player, data)

		local remote = self:_getDataUpdatedRemote()
		if remote then
			remote:FireClient(player, data, rewardReceipt)
		end
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
		WinStreak = WinStreak.Normalize(nil),
		Progression = Progression.Normalize(nil),
		Inventory = {
			Owned = {
				["PointEffects"] = { [PointEffectDefinitions.DefaultEffectId] = true },
				["DeathEffects"] = { [DeathSettings.DefaultKillEffectId] = true },
				["Abilities"] = { Dash = true },
			},
			Equipped = {
				["PointEffects"] = PointEffectDefinitions.DefaultEffectId,
				["DeathEffects"] = DeathSettings.DefaultKillEffectId,
				["Abilities"] = "Dash",
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
				initialData.WinStreak = WinStreak.Normalize(record.WinStreak)
					initialData.Progression = Progression.Normalize(record.Progression)
				if record.Inventory then
					initialData.Inventory = record.Inventory
				end
			else
				warn(string.format("[PlayerService] No se pudo cargar PlayerData de '%s' (err: %s). Usando valores seguros no persistibles.", player.Name, tostring(err)))
			end
		end
	end

		local crates = self._context and self._context:GetService("CrateService")
		if crates then initialData.Inventory = crates:ExtendInventory(initialData.Inventory) end
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
	self._shopClosing[player] = true -- Before the first save/yield; never accept another Shop mutation.
	if typeof(player) == "Instance" and player:IsA("Player") then
		local pds = self:_getPlayerDataService()
		if pds and type(pds.SavePlayer) == "function" then
			local currentData = self._data[player]
			local saved, saveError = pds:SavePlayer(player, currentData)
			if not saved then warn("[PlayerService] Final save failed; no durability guarantee: " .. tostring(saveError)) end
			if type(pds.Cleanup) == "function" then
				pds:Cleanup(player)
			end
		end
	end

	self._registered[player] = nil
	self._data[player] = nil
	self._shopClosing[player] = nil
	self._coins[player] = nil
	self._kills[player] = nil
	self._coinTransactions[player] = nil
	self._ownedPointEffects[player] = nil
	self._equippedPointEffects[player] = nil

	local pName = if type(player) == "table" and player.Name then player.Name elseif typeof(player) == "Instance" then player.Name else tostring(player)
	print(string.format("[PlayerService] Desregistrado: %s", pName))
end

-- ==================================================
-- INTERFAZ AUTORITATIVA DE ECONOMÍA Y ESTADÍSTICAS
-- ==================================================

function PlayerService:AddCoins(player: any, amount: number, reason: string, transactionId: string?): (number, number)
	if not player or amount ~= amount or amount <= 0 or amount == math.huge then
		return self:GetCoins(player), 0
	end

	local data = self._data[player]
	if transactionId then
		-- Transactional awards never reload/recreate a disconnected or missing profile.
		if transactionId == "" or not data then return self:GetCoins(player), 0 end
		local transactions = self._coinTransactions[player]
		if not transactions then transactions = {}; self._coinTransactions[player] = transactions end
		if transactions[transactionId] then return self:GetCoins(player), 0 end
		-- No yields between reserving the key and committing the in-memory balance.
		transactions[transactionId] = true
	end
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

	if transactionId then
		-- Failure to notify cannot roll back a committed award or allow a second credit.
		local receipt = if reason == "MatchPoint" and string.sub(transactionId, 1, 5) == "Goal:" then {
			Kind = "CreditedGoal", RecipientUserId = player.UserId,
			SessionId = player:GetAttribute("MatchId"), EventId = transactionId, RewardCoins = amount,
		} else nil
		local ok, failure = pcall(self._sendDataUpdate, self, player, receipt)
		if not ok then warn("[PlayerService] Committed Coins; data notification failed: " .. tostring(failure)) end
	else
		self:_sendDataUpdate(player)
	end
	return newBalance, amount
end

-- Called only by the elimination authority after its final credited-kill decision.
-- Separate from AddKill so generic stat corrections never create money.
function PlayerService:AwardConfirmedKill(player: Player, victim: Player, sessionId: string, eliminationId: string): (number, number)
	if not player or not victim or player == victim or player.Parent ~= Players or victim.Parent ~= Players then
		return 0, self:GetCoins(player)
	end
	local rounds = self._context and self._context:GetService("RoundService")
	local session = rounds and rounds:GetSessionById(sessionId)
	if not session or not rounds:IsSessionActive(sessionId) or session.GameplayFrozen
		or session.Closing or session.Cancelled or session.Closed
		or (session.State ~= Constants.RoundState.Playing and session.State ~= Constants.RoundState.PointRestartCountdown) then
		return 0, self:GetCoins(player)
	end
	local attacker = rounds:GetSessionParticipant(sessionId, player)
	local target = rounds:GetSessionParticipant(sessionId, victim)
	local prefix = sessionId .. "_" .. tostring(victim.UserId) .. "_"
	if not attacker or not target or attacker.Team == target.Team
		or player:GetAttribute("MatchId") ~= sessionId or victim:GetAttribute("MatchId") ~= sessionId
		or type(eliminationId) ~= "string" or string.sub(eliminationId, 1, #prefix) ~= prefix then
		return 0, self:GetCoins(player)
	end
	local amount = Config.Economy.KillRewardCoins
	if type(amount) ~= "number" or amount ~= amount or amount < 0 or amount % 1 ~= 0 or amount == math.huge then
		warn("[PlayerService] Invalid Economy.KillRewardCoins")
		return 0, self:GetCoins(player)
	end
	local balance, credited = self:AddCoins(player, amount, "SlapElimination", "Kill:" .. eliminationId)
	return credited, balance
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

function PlayerService:RecordStreakResult(player: any, matchId: string, outcome: string): boolean
 local data=self._data[player]
 if not data then return false end
 local applied=WinStreak.Apply(data,matchId,outcome)
 if applied then
  local ok,why=pcall(self._sendDataUpdate,self,player)
  if not ok then warn('[PlayerService] Streak notification failed: '..tostring(why))end
 end
 return applied
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

-- Stats-only API. Kill money requires AwardConfirmedKill and its elimination transaction key.
function PlayerService:AddKill(player: any, amount: number?, reason: string?): (number, number)
	if not player then return 0, 0 end
	local addAmt = amount or 1
	if addAmt <= 0 then
		return self:GetKills(player), 0
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

	local ok, failure = pcall(self._sendDataUpdate, self, player)
	if not ok then warn("[PlayerService] Kill registered; data notification failed: " .. tostring(failure)) end
	return data.Kills, 0
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
			WinStreak = WinStreak.Normalize(data.WinStreak),
			Progression = Progression.Normalize(data.Progression),
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
				["DeathEffects"] = { [DeathSettings.DefaultKillEffectId] = true },
			},
			Equipped = {
				["PointEffects"] = PointEffectDefinitions.DefaultEffectId,
				["DeathEffects"] = DeathSettings.DefaultKillEffectId,
			},
		},
	}
end

-- ==================================================
-- INTERFAZ AUTORITATIVA GENÉRICA DE INVENTORY
-- ==================================================

-- Obtiene el inventario completo del jugador
function PlayerService:IsShopDataReady(player: any): boolean
	if self._shopShutdown or self._shopClosing[player] then return false end
	if typeof(player) ~= "Instance" or not player:IsA("Player") or player.Parent ~= Players or not self._data[player] then return false end
	local pds = self:_getPlayerDataService()
	return pds ~= nil and pds:GetLoadState(player) == "Loaded"
end

-- Stops Shop mutations before shutdown snapshots. Does not change reward rules.
function PlayerService:BeginShopShutdown()
 self._shopShutdown = true
end

function PlayerService:CommitShopPurchase(player: any, product: any): (boolean, string?)
 if not self:IsShopDataReady(player) then return false,"DataNotLoaded" end
 local current = self._data[player]
 local nextData, reason = ProfilePurchase.Stage(current, product)
 if not nextData then return false,reason end
 -- Stage is pure/non-yielding; recheck identity/readiness immediately before commit.
 if self._data[player] ~= current or not self:IsShopDataReady(player) then return false,"DataNotLoaded" end
 self._data[player] = nextData
 self._coins[player] = nextData.Coins
 self._ownedPointEffects[player] = nextData.Inventory.Owned.PointEffects
 -- A notification failure never undoes payment/ownership or reports a failed commit.
 self:NotifyShopUpdate(player)
 return true,nil
end

function PlayerService:NotifyShopUpdate(player: any)
 local ok, err = pcall(function() self:_sendDataUpdate(player) end)
 if not ok then warn("[PlayerService] Shop committed; snapshot delivery failed: " .. tostring(err)) end
end

-- Server-only no-yield commit. Uses the same profile/Coins caches and Shop lock.
-- One non-yielding runtime commit: XP/claim marker and inventory/Coins move together.
-- Production progression remains gated until this lifecycle has durable transaction ownership.
function PlayerService:CommitProgression(player: any, expected: any, nextData: any): boolean
 if not self:IsShopDataReady(player) or self._data[player] ~= expected then return false end
 self._data[player] = nextData
 self._coins[player] = nextData.Coins
 self._ownedPointEffects[player] = nextData.Inventory.Owned.PointEffects
 self:NotifyShopUpdate(player)
 return true
end

function PlayerService:CommitCrateState(player: any, expectedInventory: any, nextData: any): (boolean, string?)
 if not self:IsShopDataReady(player) then return false,"DataNotLoaded" end
 local current=self._data[player]
 if current.Inventory~=expectedInventory then return false,"ProfileChanged" end
 self._data[player]=nextData
 self._coins[player]=nextData.Coins
 self._ownedPointEffects[player]=nextData.Inventory.Owned.PointEffects
 self:NotifyShopUpdate(player)
 return true
end

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
	-- Initial entitlement, never a purchase/grant event or Coins transaction.
	if category == "DeathEffects" and productId == DeathSettings.DefaultKillEffectId then return true end
	if category == "Abilities" and productId == "Dash" then return true end

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
	if category == "DeathEffects" then
		local shop = self._context and self._context:GetService("ShopService")
		local provider = shop and shop:GetProvider(category)
		return if provider then provider:GetEquippedEffectId(player) else DeathSettings.DefaultKillEffectId
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
		local models = game:GetService("ServerStorage"):FindFirstChild("PointEffects")
		local model = equipped and models and models:FindFirstChild(equipped)
		if not equipped or not PointEffectDefinitions.IsValid(equipped) or not self:HasItem(player, category, equipped)
			or not model or not model:IsA("Model") then
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
	if not self:IsShopDataReady(player) then return false, "DataNotLoaded" end
	if not player then
		return false, "PlayerNotFound"
	end
	if type(category) ~= "string" or category == "" then
		return false, "InvalidCategory"
	end
	if category == "DeathEffects" then
		if not self:IsShopDataReady(player) then return false, "DataNotLoaded" end
		local shop = self._context and self._context:GetService("ShopService")
		local provider = shop and shop:GetProvider(category)
		local actualId = if productId and productId ~= "" then productId else DeathSettings.DefaultKillEffectId
		local product = provider and provider:GetProduct(actualId)
		if not product then return false, "ProductNotFound" end
		if not provider:GetResource(actualId) then return false, "ProductUnavailable" end
	end
	if category == "PointEffects" and productId and productId ~= "" then
		if not PointEffectDefinitions.IsValid(productId) then return false, "ProductNotFound" end
		local models = game:GetService("ServerStorage"):FindFirstChild("PointEffects")
		local model = models and models:FindFirstChild(productId)
		if not model or not model:IsA("Model") then return false, "ProductUnavailable" end
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

	self:NotifyShopUpdate(player)
	return true, nil
end

-- Desequipa el ítem de una categoría (restituye default seguro si aplica)
function PlayerService:UnequipItem(player: any, category: string): (boolean, string?)
	if not self:IsShopDataReady(player) then return false, "DataNotLoaded" end
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
	elseif category == "DeathEffects" then
		return self:SetEquippedItem(player, category, DeathSettings.DefaultKillEffectId)
	else
		data.Inventory.Equipped[category] = nil
	end

	local pName = if type(player) == "table" and player.Name then player.Name elseif typeof(player) == "Instance" then player.Name else tostring(player)
	print(string.format("[PlayerService] Jugador '%s' desequipó categoría: [%s]", pName, category))

	self:NotifyShopUpdate(player)
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
