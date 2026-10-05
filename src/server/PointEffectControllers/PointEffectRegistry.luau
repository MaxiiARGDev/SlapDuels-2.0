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

function PointEffectRegistry.GetController(effectId: string?): EffectController?
	if effectId and _controllers[effectId] then
		return _controllers[effectId]
	end
	if _controllers[_defaultEffectId] then
		return _controllers[_defaultEffectId]
	end
	return nil
end

function PointEffectRegistry.Has(effectId: string): boolean
	return _controllers[effectId] ~= nil
end

return PointEffectRegistry
