--!strict
-- InMemoryDataStore
-- Implementa el subconjunto de GlobalDataStore usado por PlayerDataService.
-- Vive solamente durante el servidor actual y nunca accede a servicios cloud.

local InMemoryDataStore = {}
InMemoryDataStore.__index = InMemoryDataStore

export type Diagnostics = {
	ProviderName: string,
	WritesToCloud: boolean,
	GetAsyncCalls: number,
	UpdateAsyncCalls: number,
	CommittedWrites: number,
	StoredKeys: number,
}

export type Store = typeof(setmetatable({} :: {
	_records: { [string]: any },
	_getAsyncCalls: number,
	_updateAsyncCalls: number,
	_committedWrites: number,
}, InMemoryDataStore))

local function deepCopy(value: any, seen: { [any]: any }?): any
	if type(value) ~= "table" then
		return value
	end

	local visited = seen or {}
	if visited[value] ~= nil then
		return visited[value]
	end

	local copy = {}
	visited[value] = copy
	for key, child in pairs(value) do
		copy[deepCopy(key, visited)] = deepCopy(child, visited)
	end
	return copy
end

function InMemoryDataStore.new(): Store
	return setmetatable({
		_records = {},
		_getAsyncCalls = 0,
		_updateAsyncCalls = 0,
		_committedWrites = 0,
	}, InMemoryDataStore) :: any
end

function InMemoryDataStore:GetAsync(key: string): any
	assert(type(key) == "string" and key ~= "", "InMemoryDataStore:GetAsync requires a non-empty string key")
	self._getAsyncCalls += 1
	return deepCopy(self._records[key])
end

function InMemoryDataStore:UpdateAsync(key: string, transform: (any) -> any): any
	assert(type(key) == "string" and key ~= "", "InMemoryDataStore:UpdateAsync requires a non-empty string key")
	assert(type(transform) == "function", "InMemoryDataStore:UpdateAsync requires a transform callback")
	self._updateAsyncCalls += 1

	local previousValue = deepCopy(self._records[key])
	local nextValue = transform(previousValue)
	if nextValue == nil then
		return nil
	end

	local storedValue = deepCopy(nextValue)
	self._records[key] = storedValue
	self._committedWrites += 1
	return deepCopy(storedValue)
end

function InMemoryDataStore:GetDiagnostics(): Diagnostics
	local storedKeys = 0
	for _ in pairs(self._records) do
		storedKeys += 1
	end

	return {
		ProviderName = "InMemory",
		WritesToCloud = false,
		GetAsyncCalls = self._getAsyncCalls,
		UpdateAsyncCalls = self._updateAsyncCalls,
		CommittedWrites = self._committedWrites,
		StoredKeys = storedKeys,
	}
end

-- Hooks deliberadamente acotados para pruebas unitarias aisladas.
function InMemoryDataStore:_seedForTests(key: string, value: any)
	self._records[key] = deepCopy(value)
end

function InMemoryDataStore:_readForTests(key: string): any
	return deepCopy(self._records[key])
end

return InMemoryDataStore
