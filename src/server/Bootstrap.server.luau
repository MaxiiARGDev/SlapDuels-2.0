--!strict
-- Bootstrap
-- Punto de entrada del servidor. Requiere los servicios, ejecuta Init() y Start()
-- en orden controlado, y maneja errores de inicializacion de forma clara.

local ServerScriptService = game:GetService("ServerScriptService")

local ServicesFolder = ServerScriptService:WaitForChild("Services", 10)
assert(ServicesFolder, "[Bootstrap] No se encontro ServerScriptService.Services")

-- Orden de carga controlado. Cada servicio expone Name, Init(context) y Start(context).
local SERVICE_ORDER = {
	"PlayerDataService",
	"PlayerService",
	"RagdollService",
	"MatchInstanceService",
	"SpawnService",
	"PointFeedbackService",
	"PointEffectTestService",
	"ScoreService",
	"RoundService",
	"MatchmakingFeedbackService",
	"MatchmakingService",
	"CombatService",
	"KnockbackService",
	"EliminationService",
	"SlapService",
}

local loadedServices: { [string]: any } = {}
local initializedServices = {}

-- Carga de modulos
for _, name in ipairs(SERVICE_ORDER) do
	local moduleScript = ServicesFolder:FindFirstChild(name)
	if not moduleScript or not moduleScript:IsA("ModuleScript") then
		warn(string.format("[Bootstrap] Servicio no encontrado o invalido: %s", name))
		continue
	end

	local ok, result = pcall(require, moduleScript)
	if not ok then
		warn(string.format("[Bootstrap] Error al requerir %s: %s", name, tostring(result)))
		continue
	end

	loadedServices[name] = result
end

-- Contexto compartido: permite referencias controladas sin dependencias circulares.
local context = {
	Services = loadedServices,
	GetService = function(_self, name: string)
		return loadedServices[name]
	end,
}

-- Init() en todos
for _, name in ipairs(SERVICE_ORDER) do
	local service = loadedServices[name]
	if not service then
		continue
	end

	if type(service.Init) == "function" then
		local ok, err = pcall(function()
			service:Init(context)
		end)
		if ok then
			table.insert(initializedServices, name)
		else
			warn(string.format("[Bootstrap] Error en Init() de %s: %s", name, tostring(err)))
		end
	else
		warn(string.format("[Bootstrap] %s no implementa Init()", name))
	end
end

-- Start() en todos
for _, name in ipairs(SERVICE_ORDER) do
	local service = loadedServices[name]
	if not service then
		continue
	end

	if type(service.Start) == "function" then
		local ok, err = pcall(function()
			service:Start(context)
		end)
		if not ok then
			warn(string.format("[Bootstrap] Error en Start() de %s: %s", name, tostring(err)))
		end
	else
		warn(string.format("[Bootstrap] %s no implementa Start()", name))
	end
end

print(string.format("[Bootstrap] Servicios inicializados: %s", table.concat(initializedServices, ", ")))
print("[Bootstrap] Arranque completado")
