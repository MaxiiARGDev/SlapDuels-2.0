--!strict
-- Pruebas unitarias puras para los adaptadores y el selector.
-- Este archivo no forma parte del DataModel de producción.

return function(
	InMemoryDataStore: any,
	PersistenceEnvironment: any,
	RobloxDataStoreAdapter: any,
	PlayerDataService: any
)
	local passed = 0

	local function check(condition: boolean, message: string)
		assert(condition, message)
		passed += 1
	end

	local store = InMemoryDataStore.new()
	check(store:GetAsync("Player_1") == nil, "new profile must be nil")

	store:UpdateAsync("Player_1", function()
		return {
			Version = 2,
			Coins = 50,
			Wins = 1,
			Losses = 2,
			Kills = 3,
			Inventory = { Owned = { PointEffects = { Basic = true } }, Equipped = { PointEffects = "Basic" } },
		}
	end)

	local firstRead = store:GetAsync("Player_1")
	firstRead.Coins = 999
	firstRead.Inventory.Owned.PointEffects.Basic = false
	local secondRead = store:GetAsync("Player_1")
	check(secondRead.Coins == 50, "reads must be deep copies")
	check(secondRead.Inventory.Owned.PointEffects.Basic == true, "nested data must be deep copied")

	secondRead.Coins = 75
	secondRead.Wins = 4
	secondRead.Losses = 5
	secondRead.Kills = 6
	secondRead.Inventory.Owned.PointEffects.Inferno = true
	store:UpdateAsync("Player_1", function()
		return secondRead
	end)
	local persistedStats = store:GetAsync("Player_1")
	check(persistedStats.Coins == 75, "Coins must persist in the same server")
	check(persistedStats.Wins == 4, "Wins must persist in the same server")
	check(persistedStats.Losses == 5, "Losses must persist in the same server")
	check(persistedStats.Kills == 6, "Kills must persist in the same server")
	check(persistedStats.Inventory.Owned.PointEffects.Inferno == true, "Inventory must persist in the same server")

	store:UpdateAsync("Player_2", function()
		return { Version = 2, Coins = 10, Wins = 0, Losses = 0, Kills = 0, Inventory = { Owned = {}, Equipped = {} } }
	end)
	check(store:GetAsync("Player_1").Coins == 75, "player profiles must be independent")
	check(store:GetAsync("Player_2").Coins == 10, "second profile must retain its own data")

	local productionFactoryCalls = 0
	local studioSelection = PersistenceEnvironment.ResolveWithOptions({
		IsStudio = true,
		GameId = 100,
		PlaceId = 200,
		ApprovedProductionUniverseId = 100,
		ProductionStoreName = "SlapDuels_PlayerData_v1",
		CreateInMemory = function() return InMemoryDataStore.new() end,
		CreateProduction = function()
			productionFactoryCalls += 1
			return {}
		end,
	})
	check(studioSelection.ProviderName == "InMemory", "Studio must always select memory")
	check(studioSelection.WritesToCloud == false, "Studio must never write to cloud")
	check(productionFactoryCalls == 0, "Studio must not initialize the production provider")

	local unknownSelection = PersistenceEnvironment.ResolveWithOptions({
		IsStudio = false,
		GameId = 999,
		PlaceId = 200,
		ApprovedProductionUniverseId = 100,
		ProductionStoreName = "SlapDuels_PlayerData_v1",
		CreateInMemory = function() return InMemoryDataStore.new() end,
		CreateProduction = function()
			productionFactoryCalls += 1
			return {}
		end,
	})
	check(unknownSelection.Provider == nil, "unknown universes must be blocked")
	check(unknownSelection.WritesToCloud == false, "unknown universes must not write to cloud")
	check(productionFactoryCalls == 0, "unknown universes must not initialize production")

	local missingIdSelection = PersistenceEnvironment.ResolveWithOptions({
		IsStudio = false,
		GameId = 100,
		PlaceId = 200,
		ApprovedProductionUniverseId = nil,
		ProductionStoreName = "SlapDuels_PlayerData_v1",
		CreateInMemory = function() return InMemoryDataStore.new() end,
		CreateProduction = function()
			productionFactoryCalls += 1
			return {}
		end,
	})
	check(missingIdSelection.BlockedReason == "ProductionUniverseIdNotApproved", "missing production ID must fail closed")
	check(productionFactoryCalls == 0, "missing production ID must not initialize production")

	local productionSelection = PersistenceEnvironment.ResolveWithOptions({
		IsStudio = false,
		GameId = 100,
		PlaceId = 200,
		ApprovedProductionUniverseId = 100,
		ProductionStoreName = "SlapDuels_PlayerData_v1",
		CreateInMemory = function() return InMemoryDataStore.new() end,
		CreateProduction = function(name: string)
			productionFactoryCalls += 1
			return { Name = name }
		end,
	})
	check(productionSelection.ProviderName == "RobloxDataStore", "approved production must select the remote adapter")
	check(productionSelection.WritesToCloud == true, "approved production must allow cloud writes")
	check(productionFactoryCalls == 1, "approved production must initialize exactly once")

	local remoteValues = {}
	local remoteGetCalls = 0
	local remoteUpdateCalls = 0
	local requestedStoreName = nil
	local mockDataStoreService = {
		GetDataStore = function(_self: any, name: string)
			requestedStoreName = name
			return {
				GetAsync = function(_store: any, key: string)
					remoteGetCalls += 1
					return remoteValues[key]
				end,
				UpdateAsync = function(_store: any, key: string, transform: (any) -> any)
					remoteUpdateCalls += 1
					local nextValue = transform(remoteValues[key])
					if nextValue ~= nil then
						remoteValues[key] = nextValue
					end
					return nextValue
				end,
			}
		end,
	}
	local remoteAdapter = RobloxDataStoreAdapter.new("SlapDuels_PlayerData_v1", mockDataStoreService)
	remoteAdapter:UpdateAsync("Player_9", function()
		return { Coins = 90 }
	end)
	check(remoteAdapter:GetAsync("Player_9").Coins == 90, "remote adapter must preserve UpdateAsync/GetAsync semantics")
	check(requestedStoreName == "SlapDuels_PlayerData_v1", "remote adapter must preserve the production store name")
	check(remoteGetCalls == 1 and remoteUpdateCalls == 1, "remote adapter must forward one operation each")

	local migratedOk, migrated, migrationWarning = PlayerDataService:ValidatePlayerData({
		Version = 1,
		Coins = 12.9,
		Wins = 2,
		Losses = 3,
		Inventory = { Owned = {}, Equipped = {} },
	})
	check(migratedOk == true and migrated.Version == 2, "older profiles must migrate to the current schema")
	check(migrated.Kills == 0 and migrationWarning ~= nil, "missing Kills must be sanitized with a warning")
	check(migrated.Inventory.Owned.PointEffects.Basic == true, "migration must restore the required inventory default")
	check(migrated.Inventory.Equipped.PointEffects == "Basic", "migration must restore the required equipped default")

	local invalidOk = PlayerDataService:ValidatePlayerData("corrupted")
	check(invalidOk == false, "non-table profiles must be rejected")
	local futureOk, _, futureError = PlayerDataService:ValidatePlayerData({ Version = 999 })
	check(futureOk == false and string.find(futureError or "", "IncompatibleVersion", 1, true) ~= nil, "future schema versions must be rejected")

	check(type(PlayerDataService.LoadPlayer) == "function", "LoadPlayer contract must remain available")
	check(type(PlayerDataService.SavePlayer) == "function", "SavePlayer contract must remain available")
	check(type(PlayerDataService.SaveAllPlayers) == "function", "SaveAllPlayers contract must remain available")
	check(type(PlayerDataService.Cleanup) == "function", "Cleanup contract must remain available")

	local diagnostics = store:GetDiagnostics()
	check(diagnostics.GetAsyncCalls >= 5, "load diagnostics must be counted")
	check(diagnostics.UpdateAsyncCalls == 3, "update diagnostics must be counted")
	check(diagnostics.CommittedWrites == 3, "committed writes must be counted")

	return passed
end
