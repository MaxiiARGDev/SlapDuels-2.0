--!strict
-- PersistenceEnvironment
-- Selecciona una vez el proveedor de persistencia antes de inicializar servicios.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local InMemoryDataStore = require(script.Parent.InMemoryDataStore)
local RobloxDataStoreAdapter = require(script.Parent.RobloxDataStoreAdapter)

local PersistenceEnvironment = {}

-- Bloqueado intencionalmente hasta que el propietario apruebe un Universe ID.
-- No inferir este valor a partir de PlaceId.
local APPROVED_PRODUCTION_UNIVERSE_ID: number? = 10769217377

export type Selection = {
	Environment: string,
	ProviderName: string,
	WritesToCloud: boolean,
	GameId: number,
	PlaceId: number,
	StoreName: string?,
	BlockedReason: string?,
	Provider: any?,
}

export type ResolveOptions = {
	IsStudio: boolean,
	GameId: number,
	PlaceId: number,
	ApprovedProductionUniverseId: number?,
	ProductionStoreName: string,
	CreateInMemory: () -> any,
	CreateProduction: (string) -> any,
}

function PersistenceEnvironment.ResolveWithOptions(options: ResolveOptions): Selection
	if options.IsStudio then
		return {
			Environment = "Studio",
			ProviderName = "InMemory",
			WritesToCloud = false,
			GameId = options.GameId,
			PlaceId = options.PlaceId,
			StoreName = nil,
			BlockedReason = nil,
			Provider = options.CreateInMemory(),
		}
	end

	local approvedId = options.ApprovedProductionUniverseId
	if type(approvedId) ~= "number" or approvedId <= 0 then
		return {
			Environment = "Blocked",
			ProviderName = "Unavailable",
			WritesToCloud = false,
			GameId = options.GameId,
			PlaceId = options.PlaceId,
			StoreName = nil,
			BlockedReason = "ProductionUniverseIdNotApproved",
			Provider = nil,
		}
	end

	if options.GameId ~= approvedId then
		return {
			Environment = "Blocked",
			ProviderName = "Unavailable",
			WritesToCloud = false,
			GameId = options.GameId,
			PlaceId = options.PlaceId,
			StoreName = nil,
			BlockedReason = "UnknownUniverse",
			Provider = nil,
		}
	end

	local ok, providerOrError = pcall(options.CreateProduction, options.ProductionStoreName)
	if not ok or providerOrError == nil then
		return {
			Environment = "Blocked",
			ProviderName = "Unavailable",
			WritesToCloud = false,
			GameId = options.GameId,
			PlaceId = options.PlaceId,
			StoreName = nil,
			BlockedReason = "ProductionProviderInitializationFailed",
			Provider = nil,
		}
	end

	return {
		Environment = "Production",
		ProviderName = "RobloxDataStore",
		WritesToCloud = true,
		GameId = options.GameId,
		PlaceId = options.PlaceId,
		StoreName = options.ProductionStoreName,
		BlockedReason = nil,
		Provider = providerOrError,
	}
end

function PersistenceEnvironment.Resolve(): Selection
	local storeName = (Config.DataStore and Config.DataStore.Name) or "SlapDuels_PlayerData_v1"
	return PersistenceEnvironment.ResolveWithOptions({
		IsStudio = RunService:IsStudio(),
		GameId = game.GameId,
		PlaceId = game.PlaceId,
		ApprovedProductionUniverseId = APPROVED_PRODUCTION_UNIVERSE_ID,
		ProductionStoreName = storeName,
		CreateInMemory = function()
			return InMemoryDataStore.new()
		end,
		CreateProduction = function(name: string)
			return RobloxDataStoreAdapter.new(name)
		end,
	})
end

return PersistenceEnvironment
