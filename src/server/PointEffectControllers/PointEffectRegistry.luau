--!strict
export type EffectHandle = {
	Stop: (self: EffectHandle) -> (),
	Destroy: (self: EffectHandle) -> (),
	IsActive: (self: EffectHandle) -> boolean,
}

export type PlayContext = {
	EffectModel: Model,
	ScoringZone: BasePart,
	ScoringPlayer: Player?,
	MatchId: string,
	PointId: string,
	IsFinalPoint: boolean,
	Score: { Red: number, Blue: number }?,
}

export type EffectController = {
	Play: (context: PlayContext) -> EffectHandle,
}

local PointEffectRegistry = {}

local _controllers: { [string]: EffectController } = {}
local _defaultEffectId = "Basic"

function PointEffectRegistry.Register(effectId: string, controller: EffectController)
	assert(typeof(effectId) == "string" and effectId ~= "", "[PointEffectRegistry] effectId inválido")
	assert(controller and typeof(controller.Play) == "function", "[PointEffectRegistry] controller debe implementar Play(context)")
	_controllers[effectId] = controller
end

-- Controllers exclusivos que se registran explícitamente aquí y se cargan bajo demanda (effectId -> ModuleScript
-- hermano). Los servicios solo precargan BasicController; cada controller exclusivo se auto-registra al cargarse.
-- Si el módulo falla o no existe, se conserva el fallback al controller por defecto.
local _exclusiveControllers: { [string]: string } = {
	Inferno = "InfernoController",
	Thunder = "ThunderController",
		Frost = "BasicController", -- Attribute-driven choreography on the Frost template.
		Void = "BasicController", -- Attribute-driven choreography on the Void template.
}
local _exclusiveAttempted: { [string]: boolean } = {}

local function ensureExclusiveLoaded(effectId: string)
	if _controllers[effectId] then
		return
	end
	local moduleName = _exclusiveControllers[effectId]
	if not moduleName or _exclusiveAttempted[effectId] then
		return
	end
	_exclusiveAttempted[effectId] = true

	local container = script.Parent
	local moduleScript = if container then container:FindFirstChild(moduleName) else nil
	if not moduleScript or not moduleScript:IsA("ModuleScript") then
		warn(string.format("[PointEffectRegistry] Controller exclusivo '%s' no encontrado; se usara el fallback", moduleName))
		return
	end

	local ok, result = pcall(require, moduleScript)
	if not ok then
		warn(string.format("[PointEffectRegistry] Error al cargar '%s': %s; se usara el fallback", moduleName, tostring(result)))
		return
	end

	-- Registro explícito si el módulo no se auto-registró
	if not _controllers[effectId] and typeof(result) == "table" and typeof((result :: any).Play) == "function" then
		PointEffectRegistry.Register(effectId, result :: any)
	end
end

function PointEffectRegistry.GetController(effectId: string?): EffectController?
	if effectId then
		ensureExclusiveLoaded(effectId)
	end
	if effectId and _controllers[effectId] then
		return _controllers[effectId]
	end
	if _controllers[_defaultEffectId] then
		return _controllers[_defaultEffectId]
	end
	return nil
end

function PointEffectRegistry.Has(effectId: string): boolean
	ensureExclusiveLoaded(effectId)
	return _controllers[effectId] ~= nil
end

return PointEffectRegistry
