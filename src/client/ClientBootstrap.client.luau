--!strict
local StarterPlayerScripts = script.Parent
local ControllersFolder = StarterPlayerScripts:WaitForChild("Controllers", 10)
assert(ControllersFolder, "[ClientBootstrap] No se encontro StarterPlayerScripts.Controllers")

local loadedControllers: { [string]: any } = {}
local initializedControllers = {}

for _, child in ipairs(ControllersFolder:GetChildren()) do
	if child:IsA("ModuleScript") then
		local ok, result = pcall(require, child)
		if ok then
			loadedControllers[child.Name] = result
		else
			warn(string.format("[ClientBootstrap] Error al requerir %s: %s", child.Name, tostring(result)))
		end
	end
end

local context = {
	Controllers = loadedControllers,
	GetController = function(_self, name: string)
		return loadedControllers[name]
	end,
}

for name, controller in pairs(loadedControllers) do
	if type(controller.Init) == "function" then
		local ok, err = pcall(function()
			controller:Init(context)
		end)
		if ok then
			table.insert(initializedControllers, name)
		else
			warn(string.format("[ClientBootstrap] Error en Init() de %s: %s", name, tostring(err)))
		end
	end
end

for name, controller in pairs(loadedControllers) do
	if type(controller.Start) == "function" then
		local ok, err = pcall(function()
			controller:Start(context)
		end)
		if not ok then
			warn(string.format("[ClientBootstrap] Error en Start() de %s: %s", name, tostring(err)))
		end
	end
end

print(string.format("[ClientBootstrap] Controladores inicializados: %s", table.concat(initializedControllers, ", ")))
