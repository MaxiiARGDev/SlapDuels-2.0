--!strict
-- BasicController
-- Coreografia del Point Effect "Basic". Es data-driven: lee atributos del template (editables en Studio).
--   ParticleEmitter: EmitCount, EmitDelay
--   Sound:           PlayDelay
--   PointLight:      LightPeak, LightIn, LightFade   (destello de luz)
--   Beam:            PulsePeak, PulseTopRatio, PulseIn, PulseOut (pulso de la columna de luz)
--   Model:           Duration, FinalMultiplier
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local PointEffectRegistry = require(script.Parent.PointEffectRegistry)

type PlayContext = PointEffectRegistry.PlayContext
type EffectHandle = PointEffectRegistry.EffectHandle

local BasicController = {}

local function num(inst: Instance, attr: string, default: number): number
	local v = inst:GetAttribute(attr)
	if typeof(v) == "number" then
		return v
	end
	return default
end

function BasicController.Play(context: PlayContext): EffectHandle
	local model = context.EffectModel
	local isFinalPoint = context.IsFinalPoint

	local isActive = true
	local scheduledThreads: { thread } = {}
	local activeTweens: { Tween } = {}

	local function schedule(delaySeconds: number, fn: () -> ())
		if not isActive then return end
		local t: thread
		t = task.delay(delaySeconds, function()
			if not isActive then return end
			local idx = table.find(scheduledThreads, t)
			if idx then
				table.remove(scheduledThreads, idx)
			end
			fn()
		end)
		table.insert(scheduledThreads, t)
	end

	local function tween(inst: Instance, info: TweenInfo, goal: { [string]: any })
		local tw = TweenService:Create(inst, info, goal)
		table.insert(activeTweens, tw)
		tw:Play()
	end

	local duration = num(model, "Duration", 1.8)
	if duration <= 0 then duration = 1.8 end
	local multiplier = if isFinalPoint then num(model, "FinalMultiplier", 1.4) else 1

	-- Estado inicial seguro
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("ParticleEmitter") then
			desc.Enabled = false
			desc.Rate = 0
		elseif desc:IsA("Sound") then
			desc.Looped = false
		end
	end

	-- Programar todo segun atributos
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("ParticleEmitter") then
			local emitter = desc
			local count = math.max(1, math.floor(num(emitter, "EmitCount", 1) * multiplier + 0.5))
			local delay = num(emitter, "EmitDelay", 0)
			if delay <= 0 then
				emitter:Emit(count)
			else
				schedule(delay, function()
					if emitter.Parent then emitter:Emit(count) end
				end)
			end

		elseif desc:IsA("Sound") then
			local sound = desc
			if isFinalPoint then
				sound.Volume = math.min(sound.Volume * 1.15, 10)
			end
			local delay = num(sound, "PlayDelay", 0)
			if delay <= 0 then
				sound:Play()
			else
				schedule(delay, function()
					if sound.Parent then sound:Play() end
				end)
			end

		elseif desc:IsA("PointLight") then
			local light = desc
			local peak = num(light, "LightPeak", 0) * (if isFinalPoint then 1.2 else 1)
			if peak > 0 then
				light.Brightness = 0
				tween(light, TweenInfo.new(num(light, "LightIn", 0.04), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = peak })
				schedule(num(light, "LightIn", 0.04), function()
					if light.Parent then
						tween(light, TweenInfo.new(num(light, "LightFade", 0.5), Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Brightness = 0 })
					end
				end)
			end

		elseif desc:IsA("Beam") then
			local beam = desc
			local peak = num(beam, "PulsePeak", 0) * (if isFinalPoint then 1.25 else 1)
			if peak > 0 then
				local topRatio = num(beam, "PulseTopRatio", 0.35)
				local pulseIn = num(beam, "PulseIn", 0.07)
				local pulseOut = num(beam, "PulseOut", 0.45)
				beam.Width0 = 0
				beam.Width1 = 0
				tween(beam, TweenInfo.new(pulseIn, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Width0 = peak, Width1 = peak * topRatio })
				schedule(pulseIn, function()
					if beam.Parent then
						tween(beam, TweenInfo.new(pulseOut, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Width0 = 0, Width1 = 0 })
					end
				end)
			end
		end
	end

	local function cleanup()
		if not isActive then return end
		isActive = false

		for _, th in ipairs(scheduledThreads) do
			pcall(task.cancel, th)
		end
		table.clear(scheduledThreads)

		for _, tw in ipairs(activeTweens) do
			pcall(function() tw:Cancel() end)
		end
		table.clear(activeTweens)

		if model and model.Parent then
			for _, desc in ipairs(model:GetDescendants()) do
				if desc:IsA("Sound") and desc.IsPlaying then
					pcall(function() desc:Stop() end)
				elseif desc:IsA("ParticleEmitter") then
					desc.Enabled = false
				end
			end
			model:Destroy()
		end
	end

	schedule(duration, cleanup)
	Debris:AddItem(model, duration + 1.0)

	local handle: EffectHandle = {
		Stop = function(_self) cleanup() end,
		Destroy = function(_self) cleanup() end,
		IsActive = function(_self) return isActive end,
	}

	return handle
end

PointEffectRegistry.Register("Basic", BasicController)

return BasicController
