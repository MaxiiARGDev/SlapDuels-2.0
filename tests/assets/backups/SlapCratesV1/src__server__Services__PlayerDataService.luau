--!strict
-- PlayerDataService
-- Capa de persistencia autoritativa mediante el proveedor seleccionado al arrancar.
-- Gestiona el ciclo de vida de persistencia (Load, Save, BindToClose, Retries, Validación).
-- No contiene lógica económica de gameplay (responsabilidad de PlayerService).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local DeathSettings = require(ReplicatedStorage.Shared.DeathFeedbackConfig).DeathEffects

type PlayerData = Types.PlayerData
type PlayerDataRecord = Types.PlayerDataRecord
type DataLoadState = Types.DataLoadState

local PlayerDataService = {}
PlayerDataService.Name = "PlayerDataService"

PlayerDataService._context = nil :: any
PlayerDataService._store = nil :: any
PlayerDataService._persistenceInfo = nil :: any
PlayerDataService._loadStates = {} :: { [Player]: DataLoadState }
PlayerDataService._saving = {} :: { [Player]: boolean }
PlayerDataService._bindToCloseConnected = false
PlayerDataService._playerService = nil :: any

-- Función auxiliar para verificar números finitos válidos y no-NaN
local function isValidNumber(val: any): boolean
	return typeof(val) == "number" and val == val and math.abs(val) ~= math.huge
end

-- Función auxiliar para generar Inventory por defecto
local function getDefaultInventory(): Types.PlayerInventory
	return {
		Owned = {
			["PointEffects"] = { ["Basic"] = true },
			["DeathEffects"] = { [DeathSettings.DefaultKillEffectId] = true },
			["Abilities"] = { Dash = true },
		},
		Equipped = {
			["PointEffects"] = "Basic",
			["DeathEffects"] = DeathSettings.DefaultKillEffectId,
			["Abilities"] = "Dash",
		},
	}
end

-- Sanitiza y valida profundamente una estructura de Inventory
local function sanitizeInventory(rawInv: any, warnings: { string }): Types.PlayerInventory
	if type(rawInv) ~= "table" then
		table.insert(warnings, "Inventory is not a table, generated default Inventory")
		return getDefaultInventory()
	end

	local sanitizedOwned: { [string]: { [string]: boolean } } = {}
	local rawOwned = rawInv.Owned
	if type(rawOwned) == "table" then
		for category, items in pairs(rawOwned) do
			if type(category) == "string" and type(items) == "table" then
				local catItems: { [string]: boolean } = {}
				for itemId, isOwned in pairs(items) do
					if type(itemId) == "string" and isOwned == true then
						catItems[itemId] = true
					end
				end
				sanitizedOwned[category] = catItems
			end
		end
	else
		table.insert(warnings, "Inventory.Owned is not a table, initialized empty Owned")
	end

	-- Regla arquitectónica: PointEffects.Basic siempre debe existir
	if not sanitizedOwned["PointEffects"] then
		sanitizedOwned["PointEffects"] = {}
	end
	sanitizedOwned["PointEffects"]["Basic"] = true
	-- Additive initial entitlement within the existing schema; preserve all owned future effects.
	sanitizedOwned["DeathEffects"] = sanitizedOwned["DeathEffects"] or {}
	sanitizedOwned["DeathEffects"][DeathSettings.DefaultKillEffectId] = true
	sanitizedOwned["Abilities"] = sanitizedOwned["Abilities"] or {}
	sanitizedOwned["Abilities"].Dash = true

	local sanitizedEquipped: { [string]: string? } = {}
	local rawEquipped = rawInv.Equipped
	if type(rawEquipped) == "table" then
		for category, equippedId in pairs(rawEquipped) do
			if type(category) == "string" and type(equippedId) == "string" then
				-- Verificar que el ítem realmente se posea en su categoría
				if sanitizedOwned[category] and sanitizedOwned[category][equippedId] == true then
					sanitizedEquipped[category] = equippedId
				else
					table.insert(warnings, string.format("Equipped item '%s' in category '%s' not owned, unequipped", equippedId, category))
				end
			end
		end
	else
		table.insert(warnings, "Inventory.Equipped is not a table, initialized empty Equipped")
	end

	-- Regla arquitectónica: PointEffects.Equipped fallback seguro obligatorio a Basic
	if not sanitizedEquipped["PointEffects"] or not sanitizedOwned["PointEffects"][sanitizedEquipped["PointEffects"]] then
		sanitizedEquipped["PointEffects"] = "Basic"
	end
	if not sanitizedEquipped["DeathEffects"] or sanitizedEquipped["DeathEffects"] == DeathSettings.DefaultFallEffectId then
		sanitizedEquipped["DeathEffects"] = DeathSettings.DefaultKillEffectId
	end
	if not sanitizedEquipped["Abilities"] then sanitizedEquipped["Abilities"] = "Dash" end

	return {
		Owned = sanitizedOwned,
		Equipped = sanitizedEquipped,
	}
end

-- ==================================================
-- VALIDACIÓN CENTRAL DE DATOS
-- ==================================================

function PlayerDataService:ValidatePlayerData(raw: any): (boolean, PlayerDataRecord, string?)
	local defaultInv = getDefaultInventory()
	if type(raw) ~= "table" then
		return false, {
			Version = Config.DataStore.CurrentVersion or 2,
			Coins = Config.Economy.StartingCoins or 0,
			Wins = Config.Economy.StartingWins or 0,
			Losses = Config.Economy.StartingLosses or 0,
			Kills = Config.Economy.StartingKills or 0,
			Inventory = defaultInv,
		}, "Raw data is not a table"
	end

	local warnings: { string } = {}

	local version = raw.Version
	local currentVersion = (Config.DataStore and Config.DataStore.CurrentVersion) or 2
	if not isValidNumber(version) or version < 1 then
		table.insert(warnings, string.format("Invalid or missing Version (%s), migrating to %d", tostring(version), currentVersion))
		version = currentVersion
	elseif version < currentVersion then
		table.insert(warnings, string.format("Migrating PlayerData from version %d to %d", version, currentVersion))
		version = currentVersion
	elseif version > currentVersion then
		local errMsg = string.format("IncompatibleVersion: Data version (%d) is newer than current config (%d)", version, currentVersion)
		warn(string.format("[PlayerData] %s. Normalización y guardado bloqueados para prevenir corrupción de esquema futuro.", errMsg))
		return false, raw, errMsg
	end

	-- Coins
	local coins = raw.Coins
	if not isValidNumber(coins) or coins < 0 then
		table.insert(warnings, string.format("Invalid Coins (%s), fallback to 0", tostring(coins)))
		coins = 0
	else
		coins = math.floor(coins)
	end

	-- Wins
	local wins = raw.Wins
	if not isValidNumber(wins) or wins < 0 then
		table.insert(warnings, string.format("Invalid Wins (%s), fallback to 0", tostring(wins)))
		wins = 0
	else
		wins = math.floor(wins)
	end

	-- Losses
	local losses = raw.Losses
	if not isValidNumber(losses) or losses < 0 then
		table.insert(warnings, string.format("Invalid Losses (%s), fallback to 0", tostring(losses)))
		losses = 0
	else
		losses = math.floor(losses)
	end

	-- Kills (retrocompatible: perfiles anteriores sin Kills reciben fallback a 0)
	local kills = raw.Kills
	if not isValidNumber(kills) or kills < 0 then
		table.insert(warnings, string.format("Invalid or missing Kills (%s), fallback to 0", tostring(kills)))
		kills = 0
	else
		kills = math.floor(kills)
	end

	-- Inventory (Migración y sanitización profunda)
	local inventory = sanitizeInventory(raw.Inventory, warnings)

	local validatedRecord: PlayerDataRecord = {
		Version = Config.DataStore.CurrentVersion or 2,
		Coins = coins,
		Wins = wins,
		Losses = losses,
		Kills = kills,
		Inventory = inventory,
		LastSaved = raw.LastSaved,
	}

	local warningMsg = if #warnings > 0 then table.concat(warnings, "; ") else nil
	return true, validatedRecord, warningMsg
end

-- ==================================================
-- INICIALIZACIÓN Y BINDTOCLOSE
-- ==================================================

function PlayerDataService:Init(context: any)
	self._context = context
	self._loadStates = {}
	self._saving = {}
	self._store = context and context.PersistenceProvider or nil
	self._persistenceInfo = context and context.PersistenceInfo or nil

	if not self._store then
		local reason = self._persistenceInfo and self._persistenceInfo.BlockedReason or "ProviderMissing"
		warn(string.format("[PlayerData] Persistencia no disponible; acceso cloud bloqueado (%s)", tostring(reason)))
	end

	-- BindToClose seguro con espera activa de guardados
	if not self._bindToCloseConnected then
		self._bindToCloseConnected = true
		game:BindToClose(function()
			local ps = self:_getPlayerService()
				if ps then ps:BeginShopShutdown() end
				print("[PlayerData] BindToClose: Guardando datos de todos los jugadores...")
			self:SaveAllPlayers()
			print("[PlayerData] BindToClose: Finalizado.")
		end)
	end
end

function PlayerDataService:Start(context: any)
	print("[PlayerDataService] Servicio de persistencia iniciado y listo")
end

function PlayerDataService:GetStore(): any
	-- La selección es fija durante toda la vida del servidor. Nunca realizar
	-- fallback automático a DataStoreService si el proveedor está ausente o falla.
	return self._store
end

function PlayerDataService:GetPersistenceDiagnostics(): { [string]: any }
	local result = {
		Environment = self._persistenceInfo and self._persistenceInfo.Environment or "Unknown",
		ProviderName = self._persistenceInfo and self._persistenceInfo.ProviderName or "Unavailable",
		WritesToCloud = self._persistenceInfo and self._persistenceInfo.WritesToCloud == true or false,
		GameId = self._persistenceInfo and self._persistenceInfo.GameId or game.GameId,
		PlaceId = self._persistenceInfo and self._persistenceInfo.PlaceId or game.PlaceId,
		BlockedReason = self._persistenceInfo and self._persistenceInfo.BlockedReason or nil,
	}

	if self._store and type(self._store.GetDiagnostics) == "function" then
		for key, value in pairs(self._store:GetDiagnostics()) do
			result[key] = value
		end
	end
	return result
end

function PlayerDataService:GetLoadState(player: Player): DataLoadState?
	return self._loadStates[player]
end

function PlayerDataService:SetLoadState(player: Player, state: DataLoadState)
	self._loadStates[player] = state
end

-- ==================================================
-- CARGA DE DATOS (LOAD)
-- ==================================================

function PlayerDataService:LoadPlayer(player: Player): (boolean, PlayerDataRecord?, string?)
	if not player or not player:IsA("Player") then
		return false, nil, "InvalidPlayerInstance"
	end

	self._loadStates[player] = "Loading"

	local store = self:GetStore()
	if not store then
		self._loadStates[player] = "Failed"
		warn(string.format("[PlayerData] Load failed: DataStore no disponible para '%s'", player.Name))
		return false, nil, "DataStoreNotAvailable"
	end

	local key = string.format("Player_%d", player.UserId)
	local maxRetries = (Config.DataStore and Config.DataStore.MaxRetries) or 3
	local retryDelay = (Config.DataStore and Config.DataStore.InitialRetryDelay) or 1.0
	local backoff = (Config.DataStore and Config.DataStore.RetryBackoffMultiplier) or 2.0

	local lastErr: any = nil
	for attempt = 1, maxRetries do
		local ok, result = pcall(function()
			return store:GetAsync(key)
		end)

		if ok then
			if result == nil then
				-- Jugador nuevo sin datos previos
				local newRecord: PlayerDataRecord = {
					Version = (Config.DataStore and Config.DataStore.CurrentVersion) or 2,
					Coins = (Config.Economy and Config.Economy.StartingCoins) or 0,
					Wins = (Config.Economy and Config.Economy.StartingWins) or 0,
					Losses = (Config.Economy and Config.Economy.StartingLosses) or 0,
					Kills = (Config.Economy and Config.Economy.StartingKills) or 0,
					Inventory = getDefaultInventory(),
				}
				self._loadStates[player] = "Loaded"
				print(string.format("[PlayerData] Load success (Nuevo jugador): '%s' (UserId: %d)", player.Name, player.UserId))
				return true, newRecord, nil
			else
				local valid, validatedRecord, warnMsg = self:ValidatePlayerData(result)
				if not valid then
					if type(result) == "table" and isValidNumber(result.Version) and result.Version > ((Config.DataStore and Config.DataStore.CurrentVersion) or 2) then
						self._loadStates[player] = "IncompatibleVersion"
						warn(string.format("[PlayerData] Load rejected para '%s': Versión de datos incompatible (%d > %d). Guardado bloqueado.",
							player.Name, result.Version, (Config.DataStore and Config.DataStore.CurrentVersion) or 2))
						return false, nil, warnMsg or "IncompatibleVersion"
					else
						self._loadStates[player] = "Corrupted"
						warn(string.format("[PlayerData] Load rejected para '%s': Datos corruptos (%s)", player.Name, tostring(warnMsg)))
						return false, nil, warnMsg or "ValidationFailed"
					end
				end

				if warnMsg then
					warn(string.format("[PlayerData] Advertencia en datos de '%s': %s", player.Name, warnMsg))
				end
				self._loadStates[player] = "Loaded"
				print(string.format("[PlayerData] Load success: '%s' (Coins=%d, Wins=%d, Losses=%d)",
					player.Name, validatedRecord.Coins, validatedRecord.Wins, validatedRecord.Losses))
				return true, validatedRecord, nil
			end
		else
			lastErr = result
			print(string.format("[PlayerData] Load retry %d/%d para '%s': %s", attempt, maxRetries, player.Name, tostring(result)))
			if attempt < maxRetries then
				task.wait(retryDelay)
				retryDelay *= backoff
			end
		end
	end

	self._loadStates[player] = "Failed"
	warn(string.format("[PlayerData] Load failed definitivo para '%s' tras %d intentos: %s", player.Name, maxRetries, tostring(lastErr)))
	return false, nil, tostring(lastErr)
end

-- ==================================================
-- GUARDADO DE DATOS (SAVE)
-- ==================================================

local function snapshotInventory(inventory: any): any
 local result = { Owned = {}, Equipped = {} }
 for category, owned in pairs(inventory.Owned) do result.Owned[category] = table.clone(owned) end
 for category, id in pairs(inventory.Equipped) do result.Equipped[category] = id end
 return result
end

function PlayerDataService:SavePlayer(player: Player, runtimeData: PlayerData?): (boolean, string?)
	if not player or not player:IsA("Player") then
		return false, "InvalidPlayerInstance"
	end

	-- SEGURIDAD CRÍTICA: Si el jugador no cargó correctamente, NUNCA guardar para no corromper ni sobrescribir
	local loadState = self._loadStates[player]
	if loadState == "IncompatibleVersion" then
		warn(string.format("[PlayerData] RECHAZO DE GUARDADO para '%s': Versión de datos en DataStore es incompatible (%s). Guardado bloqueado para proteger datos futuros.",
			player.Name, tostring(loadState)))
		return false, "IncompatibleVersion"
	end

	if loadState ~= "Loaded" then
		warn(string.format("[PlayerData] RECHAZO DE GUARDADO para '%s': Estado no es 'Loaded' (Estado actual: %s). Protección contra pérdida de datos activada.",
			player.Name, tostring(loadState)))
		return false, "DataNotLoaded"
	end

	if not runtimeData then
		warn(string.format("[PlayerData] RECHAZO DE GUARDADO para '%s': runtimeData es nil", player.Name))
		return false, "NilRuntimeData"
	end

	-- Capture the entire purchase state before any yielding wait/retry.
	runtimeData = table.clone(runtimeData)
	runtimeData.Inventory = snapshotInventory(runtimeData.Inventory or getDefaultInventory())

	-- Protección contra guardado simultáneo del mismo jugador
	if self._saving[player] then
		-- Esperar de forma controlada si ya hay un guardado en curso
		local waitAttempts = 0
		while self._saving[player] and waitAttempts < 40 do
			task.wait(0.05)
			waitAttempts += 1
		end
		if self._saving[player] then
			warn(string.format("[PlayerData] Guardado concurrente en curso para '%s', abortando solicitud duplicada", player.Name))
			return false, "AlreadySaving"
		end
	end

	self._saving[player] = true

	local store = self:GetStore()
	if not store then
		self._saving[player] = nil
		warn(string.format("[PlayerData] Save failed: DataStore no disponible para '%s'", player.Name))
		return false, "DataStoreNotAvailable"
	end

	local key = string.format("Player_%d", player.UserId)
	local maxRetries = (Config.DataStore and Config.DataStore.MaxRetries) or 3
	local retryDelay = (Config.DataStore and Config.DataStore.InitialRetryDelay) or 1.0
	local backoff = (Config.DataStore and Config.DataStore.RetryBackoffMultiplier) or 2.0

	local payload: PlayerDataRecord = {
		Version = (Config.DataStore and Config.DataStore.CurrentVersion) or 2,
		Coins = math.max(0, math.floor(runtimeData.Coins or 0)),
		Wins = math.max(0, math.floor(runtimeData.Wins or 0)),
		Losses = math.max(0, math.floor(runtimeData.Losses or 0)),
		Kills = math.max(0, math.floor(runtimeData.Kills or 0)),
		Inventory = runtimeData.Inventory or getDefaultInventory(),
		LastSaved = os.time(),
	}

	local lastErr: any = nil
	local wasVersionAborted = false
	for attempt = 1, maxRetries do
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(oldData: any)
				-- Mantener posibles campos externos futuros si existen
				if type(oldData) == "table" then
					local currentVersion = (Config.DataStore and Config.DataStore.CurrentVersion) or 2
					if isValidNumber(oldData.Version) and oldData.Version > currentVersion then
						wasVersionAborted = true
						return nil -- Cancela la escritura atómica en DataStore sin alterar los datos remotos
					end

					local updated = table.clone(oldData)
					updated.Version = payload.Version
					updated.Coins = payload.Coins
					updated.Wins = payload.Wins
					updated.Losses = payload.Losses
					updated.Kills = payload.Kills
					updated.Inventory = payload.Inventory
					updated.LastSaved = payload.LastSaved
					return updated
				end
				return payload
			end)
		end)

		if wasVersionAborted then
			self._saving[player] = nil
			self._loadStates[player] = "IncompatibleVersion"
			warn(string.format("[PlayerData] Save abortado para '%s': Versión remota en DataStore es superior a la versión soportada (%d).",
				player.Name, (Config.DataStore and Config.DataStore.CurrentVersion) or 2))
			return false, "IncompatibleVersion"
		end

		if ok then
			self._saving[player] = nil
			print(string.format("[PlayerData] Save success: '%s' (Coins=%d, Wins=%d, Losses=%d, Kills=%d)",
				player.Name, payload.Coins, payload.Wins, payload.Losses, payload.Kills))
			return true, nil
		else
			lastErr = err
			print(string.format("[PlayerData] Save retry %d/%d para '%s': %s", attempt, maxRetries, player.Name, tostring(err)))
			if attempt < maxRetries then
				task.wait(retryDelay)
				retryDelay *= backoff
			end
		end
	end

	self._saving[player] = nil
	warn(string.format("[PlayerData] Save failed definitivo para '%s' tras %d intentos: %s", player.Name, maxRetries, tostring(lastErr)))
	return false, tostring(lastErr)
end

function PlayerDataService:_getPlayerService(): any
	if self._playerService then
		return self._playerService
	end
	if self._context and type(self._context.GetService) == "function" then
		local s = self._context:GetService("PlayerService")
		if s then
			self._playerService = s
			return s
		end
	end
	local ok, mod = pcall(require, script.Parent.PlayerService)
	if ok and mod then
		self._playerService = mod
		return mod
	end
	return nil
end

-- ==================================================
-- GUARDADO COLECTIVO (BINDTOCLOSE / SHUTDOWN)
-- ==================================================

function PlayerDataService:SaveAllPlayers(): (number, number)
	local players = Players:GetPlayers()
	if #players == 0 then
		return 0, 0
	end

	local playerService = self:_getPlayerService()
	local remaining = #players
	local savedCount = 0
	local failedCount = 0

	for _, player in ipairs(players) do
		task.spawn(function()
			local runtimeData: PlayerData? = nil
			if playerService and type(playerService.GetPlayerData) == "function" then
				runtimeData = playerService:GetPlayerData(player)
			end

			local success = false
			if runtimeData and self._loadStates[player] == "Loaded" then
				local ok = self:SavePlayer(player, runtimeData)
				success = ok
			else
				print(string.format("[PlayerData] SaveAllPlayers: Omitiendo '%s' (no cargado o sin datos runtime)", player.Name))
			end

			if success then
				savedCount += 1
			else
				failedCount += 1
			end
			remaining -= 1
		end)
	end

	-- Esperar hasta que todos los hilos terminen o timeout de seguridad de 25 segundos
	local timeout = 25
	local elapsed = 0
	while remaining > 0 and elapsed < timeout do
		task.wait(0.1)
		elapsed += 0.1
	end

	print(string.format("[PlayerData] SaveAllPlayers completado: %d guardados, %d omitidos/fallidos", savedCount, failedCount))
	return savedCount, failedCount
end

-- Limpieza de estado auxiliar al salir
function PlayerDataService:Cleanup(player: Player)
	self._loadStates[player] = nil
	self._saving[player] = nil
end

return PlayerDataService
