--!strict
-- RobloxDataStoreAdapter
-- Encapsula el único punto autorizado para obtener el DataStore de producción.
-- Este constructor no debe invocarse desde Studio ni desde entornos desconocidos.

local RobloxDataStoreAdapter = {}
RobloxDataStoreAdapter.__index = RobloxDataStoreAdapter

export type Store = typeof(setmetatable({} :: {
	_store: any,
	_storeName: string,
	_getAsyncCalls: number,
	_updateAsyncCalls: number,
}, RobloxDataStoreAdapter))

function RobloxDataStoreAdapter.new(storeName: string, dataStoreServiceOverride: any?): Store
	assert(type(storeName) == "string" and storeName ~= "", "Production DataStore name is required")

	-- Requerir el servicio aquí, y no al cargar el módulo, garantiza que la ruta
	-- Studio no realiza ninguna operación sobre DataStoreService. La dependencia
	-- opcional permite verificar el contrato con un mock sin acceso a la nube.
	local dataStoreService = dataStoreServiceOverride or game:GetService("DataStoreService")
	local store = dataStoreService:GetDataStore(storeName)

	return setmetatable({
		_store = store,
		_storeName = storeName,
		_getAsyncCalls = 0,
		_updateAsyncCalls = 0,
	}, RobloxDataStoreAdapter) :: any
end

function RobloxDataStoreAdapter:GetAsync(key: string): any
	self._getAsyncCalls += 1
	return self._store:GetAsync(key)
end

function RobloxDataStoreAdapter:UpdateAsync(key: string, transform: (any) -> any): any
	self._updateAsyncCalls += 1
	return self._store:UpdateAsync(key, transform)
end

function RobloxDataStoreAdapter:GetDiagnostics(): { [string]: any }
	return {
		ProviderName = "RobloxDataStore",
		WritesToCloud = true,
		StoreName = self._storeName,
		GetAsyncCalls = self._getAsyncCalls,
		UpdateAsyncCalls = self._updateAsyncCalls,
	}
end

return RobloxDataStoreAdapter
