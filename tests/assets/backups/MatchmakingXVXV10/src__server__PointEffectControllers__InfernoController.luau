--!strict
-- InfernoController
-- Coreografia exclusiva del Point Effect "Inferno". Reutiliza los componentes del template
-- ServerStorage.PointEffects.Inferno (no crea instancias ni modifica SoundIds) y respeta el contrato
-- de PointEffectRegistry: Play(context) -> EffectHandle { Stop, Destroy, IsActive }.
--
-- Atributos existentes que se leen (mismos que BasicController, sin cambiar sus valores):
--   Model:           Duration (ciclo de vida/cleanup), FinalMultiplier
--   ParticleEmitter: EmitCount, EmitDelay (offset dentro de su fase)
--   Sound:           PlayDelay (offset dentro de su fase)
--   PointLight:      LightPeak, LightIn, LightFade
--   Beam:            PulsePeak, PulseTopRatio, PulseIn
-- Atributo OPCIONAL del Model (si no existe se usa el valor por defecto):
--   CinematicDuration: duracion de la cinematica en segundos (default 4.6). Se limita para que la
--   cinematica + la cola de particulas quepan dentro de Duration.
--
-- Fases: Ignition -> Eruption -> Pillar -> Expansion (oleadas) -> Fragmentation -> Dissipation.
-- Toda la secuencia corre en UN solo hilo (task.spawn + task.wait), sin esperas bloqueantes.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local PointEffectRegistry = require(script.Parent.PointEffectRegistry)

type PlayContext = PointEffectRegistry.PlayContext
type EffectHandle = PointEffectRegistry.EffectHandle

type Burst = { phase: string, offset: number?, fraction: number, finalOnly: boolean? }
type Event = { time: number, order: number, run: () -> () }

local InfernoController = {}

-- Hook opcional SOLO para pruebas: recibe (nombreDeFase, segundosTranscurridos). nil en produccion.
InfernoController.DebugHook = nil :: ((phase: string, elapsed: number) -> ())?

local DEFAULT_DURATION = 8
local BASE_LENGTH = 4.6 -- duracion de la cinematica a escala 1 (segundos)
local TAIL_MARGIN = 1.6 -- vida maxima de particulas existentes (~1.3 s) + margen
local MIN_SCALE = 0.25
local MAX_SCALE = 3

-- Inicio de cada fase (segundos a escala 1)
local PHASES: { [string]: number } = {
	Ignition = 0,
	Eruption = 0.12,
	Pillar = 0.38,
	Expansion = 0.85, -- primera oleada; la 2da y 3ra usan offset (ver BURSTS)
	Fragmentation = 2.7,
	Dissipation = 3.3,
	End = BASE_LENGTH,
}
local PHASE_ORDER = { "Ignition", "Eruption", "Pillar", "Expansion", "Fragmentation", "Dissipation" }
local WAVE_OFFSETS = { 0, 0.65, 1.3 }

-- Plan de emisiones puntuales por emisor (nombre -> rafagas). fraction multiplica EmitCount.
local BURSTS: { [string]: { Burst } } = {
	-- Ignicion: destello inicial + primeras chispas
	Glow = { { phase = "Ignition", fraction = 1 }, { phase = "Fragmentation", fraction = 1 } },
	Core = { { phase = "Ignition", fraction = 1 } },
	Halo = { { phase = "Ignition", fraction = 1 } },
	Glints = { { phase = "Ignition", fraction = 1 }, { phase = "Fragmentation", fraction = 0.6 } },
	GlintsLate = { { phase = "Eruption", fraction = 1 }, { phase = "Fragmentation", fraction = 1 } },
	-- Erupcion + fragmentacion
	Sparks = {
		{ phase = "Ignition", fraction = 0.3 },
		{ phase = "Eruption", fraction = 0.7 },
		{ phase = "Fragmentation", fraction = 0.8 },
	},
	Embers = { { phase = "Eruption", fraction = 1 }, { phase = "Fragmentation", fraction = 0.6 } },
	Puff = { { phase = "Eruption", fraction = 1 }, { phase = "Fragmentation", fraction = 0.5 } },
	-- Expansion: oleadas temporizadas (la 3ra solo en punto final)
	Disc = {
		{ phase = "Expansion", offset = WAVE_OFFSETS[1], fraction = 1 },
		{ phase = "Expansion", offset = WAVE_OFFSETS[2], fraction = 1 },
		{ phase = "Expansion", offset = WAVE_OFFSETS[3], fraction = 1, finalOnly = true },
	},
	DiscGlow = {
		{ phase = "Expansion", offset = WAVE_OFFSETS[1], fraction = 1 },
		{ phase = "Expansion", offset = WAVE_OFFSETS[2], fraction = 1 },
		{ phase = "Expansion", offset = WAVE_OFFSETS[3], fraction = 1, finalOnly = true },
	},
	Streaks = {
		{ phase = "Expansion", offset = WAVE_OFFSETS[1], fraction = 0.6 },
		{ phase = "Expansion", offset = WAVE_OFFSETS[2], fraction = 0.8 },
		{ phase = "Expansion", offset = WAVE_OFFSETS[3], fraction = 0.5, finalOnly = true },
	},
	Dust = {
		{ phase = "Expansion", offset = WAVE_OFFSETS[1], fraction = 0.6 },
		{ phase = "Expansion", offset = WAVE_OFFSETS[2], fraction = 0.6 },
	},
}

-- Emision sostenida durante la columna (particulas/seg a escala 1), se reduce en la disipacion
local SUSTAIN: { [string]: number } = { Embers = 26, Sparks = 8, Puff = 4 }

-- Fase en la que arranca cada sonido existente (se suma su PlayDelay). Desconocidos: PlayDelay como en Basic.
local SOUND_PHASES: { [string]: string } = {
	Thump = "Ignition",
	Snap = "Ignition",
	Boom = "Eruption",
	Crack = "Pillar",
	Ping = "Fragmentation",
	Glint = "Fragmentation",
}

-- Instancias activas por modelo: garantiza una sola ejecucion por instancia del efecto
local activeHandles: { [Instance]: EffectHandle } = {}

local function num(inst: Instance, attr: string, default: number): number
	local v = inst:GetAttribute(attr)
	if typeof(v) == "number" then
		return v
	end
	return default
end

function InfernoController.Play(context: PlayContext): EffectHandle
	local model = context.EffectModel
	local isFinalPoint = context.IsFinalPoint

	-- Una sola vez por instancia: si ya hay una secuencia activa sobre este modelo, se reutiliza su handle
	local existing = activeHandles[model]
	if existing and existing:IsActive() then
		return existing
	end

	local isActive = true
	local events: { Event } = {}
	local activeTweens: { Tween } = {}
	local driver: thread? = nil
	local destroyingConn: RBXScriptConnection? = nil
	local order = 0
	local startClock = os.clock()
	local rng = Random.new()

	local duration = num(model, "Duration", DEFAULT_DURATION)
	if duration <= 0 then
		duration = DEFAULT_DURATION
	end
	local multiplier = if isFinalPoint then num(model, "FinalMultiplier", 1.4) else 1
	local rateMul = math.min(multiplier, 3)

	-- Escala temporal configurable, limitada para que cinematica + cola quepan en Duration
	local scale = math.clamp(num(model, "CinematicDuration", BASE_LENGTH) / BASE_LENGTH, MIN_SCALE, MAX_SCALE)
	local maxScale = (duration - TAIL_MARGIN) / BASE_LENGTH
	if scale > maxScale then
		scale = math.max(maxScale, MIN_SCALE)
	end

	local function at(phase: string, offset: number?): number
		return ((PHASES[phase] or 0) + (offset or 0)) * scale
	end

	local function add(time: number, run: () -> ())
		if time >= duration then
			return -- nada se programa mas alla del ciclo de vida del modelo
		end
		order += 1
		table.insert(events, { time = math.max(time, 0), order = order, run = run })
	end

	local function mark(name: string)
		local hook = InfernoController.DebugHook
		if hook then
			pcall(hook, name, os.clock() - startClock)
		end
	end

	local function tween(inst: Instance, info: TweenInfo, goal: { [string]: any })
		if not isActive then
			return
		end
		local tw = TweenService:Create(inst, info, goal)
		table.insert(activeTweens, tw)
		tw:Play()
	end

	-- Cleanup (declarado antes de conectar Destroying)
	local function cleanup()
		if not isActive then
			return
		end
		isActive = false
		mark("Cleanup")
		activeHandles[model] = nil

		if destroyingConn then
			destroyingConn:Disconnect()
			destroyingConn = nil
		end

		if driver and driver ~= coroutine.running() then
			pcall(task.cancel, driver)
		end
		driver = nil

		for _, tw in ipairs(activeTweens) do
			pcall(function()
				tw:Cancel()
			end)
		end
		table.clear(activeTweens)
		table.clear(events)

		if model.Parent then
			for _, desc in ipairs(model:GetDescendants()) do
				if desc:IsA("Sound") and desc.IsPlaying then
					pcall(function()
						desc:Stop()
					end)
				elseif desc:IsA("ParticleEmitter") then
					desc.Enabled = false
					desc.Rate = 0
				end
			end
			model:Destroy()
		end
	end

	-- Recolectar componentes existentes y dejarlos en estado inicial seguro
	local emitters: { ParticleEmitter } = {}
	local sounds: { Sound } = {}
	local lights: { PointLight } = {}
	local beams: { Beam } = {}
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("ParticleEmitter") then
			desc.Enabled = false
			desc.Rate = 0
			table.insert(emitters, desc)
		elseif desc:IsA("Sound") then
			desc.Looped = false
			table.insert(sounds, desc)
		elseif desc:IsA("PointLight") then
			table.insert(lights, desc)
		elseif desc:IsA("Beam") then
			table.insert(beams, desc)
		end
	end

	-- Marcadores de fase (se insertan primero: en un mismo instante van antes que sus componentes)
	for _, phase in ipairs(PHASE_ORDER) do
		local name = phase
		add(at(name), function()
			mark(name)
		end)
	end

	-- Rafagas de particulas
	for _, emitter in ipairs(emitters) do
		local base = num(emitter, "EmitCount", 1)
		local emitOffset = math.max(num(emitter, "EmitDelay", 0), 0)
		local plan = BURSTS[emitter.Name]
		if plan then
			for _, burst in ipairs(plan) do
				if not burst.finalOnly or isFinalPoint then
					local count = math.max(1, math.floor(base * multiplier * burst.fraction + 0.5))
					add(at(burst.phase, burst.offset) + emitOffset, function()
						if emitter.Parent then
							emitter:Emit(count)
						end
					end)
				end
			end
		else
			-- Emisor no previsto: se comporta como en Basic (una emision segun EmitDelay)
			local count = math.max(1, math.floor(base * multiplier + 0.5))
			add(emitOffset, function()
				if emitter.Parent then
					emitter:Emit(count)
				end
			end)
		end
	end

	-- Emision sostenida durante la columna y reduccion en la disipacion
	local dissipationLength = (PHASES.End - PHASES.Dissipation) * scale
	for _, emitter in ipairs(emitters) do
		local sustain = SUSTAIN[emitter.Name]
		if sustain then
			local target = sustain * rateMul
			add(at("Pillar"), function()
				if emitter.Parent then
					emitter.Enabled = true
					tween(emitter, TweenInfo.new(0.5 * scale, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rate = target })
				end
			end)
			add(at("Dissipation"), function()
				if emitter.Parent then
					tween(emitter, TweenInfo.new(dissipationLength * 0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Rate = 0 })
				end
			end)
			add(at("End"), function()
				if emitter.Parent then
					emitter.Rate = 0
					emitter.Enabled = false
				end
			end)
		end
	end

	-- Iluminacion: pico de ignicion -> brasa -> parpadeo de columna -> pico de fragmentacion -> apagado
	for _, light in ipairs(lights) do
		local peak = num(light, "LightPeak", 0) * (if isFinalPoint then 1.2 else 1)
		if peak > 0 then
			local lightIn = math.max(num(light, "LightIn", 0.04), 0.01)
			local lightFade = math.max(num(light, "LightFade", 0.5), 0.1)
			light.Brightness = 0

			local function lightTo(time: number, level: number, dur: number, style: Enum.EasingStyle, dir: Enum.EasingDirection)
				add(time, function()
					if light.Parent then
						tween(light, TweenInfo.new(dur, style, dir), { Brightness = level })
					end
				end)
			end

			lightTo(at("Ignition"), peak, lightIn, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			lightTo(at("Ignition") + lightIn, peak * 0.45, 0.3 * scale, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

			local flickerStep = math.max(0.2 * scale, 0.05)
			local t = at("Pillar")
			local flickerEnd = at("Fragmentation") - flickerStep
			local guard = 0
			while t < flickerEnd and guard < 24 do
				lightTo(t, peak * (0.3 + 0.2 * rng:NextNumber()), flickerStep * 0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				t += flickerStep
				guard += 1
			end

			lightTo(at("Fragmentation"), peak * 0.8, 0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			lightTo(at("Fragmentation") + 0.05, peak * 0.3, lightFade * scale, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			lightTo(at("Dissipation"), 0, dissipationLength * 0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			add(at("End"), function()
				if light.Parent then
					light.Brightness = 0
				end
			end)
		end
	end

	-- Columna infernal: el Beam crece progresivamente, respira durante las oleadas, se sobrecarga y colapsa
	for _, beam in ipairs(beams) do
		local peak = num(beam, "PulsePeak", 0) * (if isFinalPoint then 1.25 else 1)
		if peak > 0 then
			local topRatio = num(beam, "PulseTopRatio", 0.35)
			local surgeIn = math.max(num(beam, "PulseIn", 0.07), 0.02)
			beam.Width0 = 0
			beam.Width1 = 0

			local function beamTo(time: number, factor: number, dur: number, style: Enum.EasingStyle, dir: Enum.EasingDirection)
				add(time, function()
					if beam.Parent then
						tween(beam, TweenInfo.new(dur, style, dir), { Width0 = peak * factor, Width1 = peak * factor * topRatio })
					end
				end)
			end

			beamTo(at("Pillar"), 0.5, 0.45 * scale, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			beamTo(at("Pillar", 0.5), 1, 0.55 * scale, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			beamTo(at("Expansion", WAVE_OFFSETS[2]), 0.88, 0.35 * scale, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			beamTo(at("Expansion", WAVE_OFFSETS[3]), 1, 0.35 * scale, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			beamTo(at("Fragmentation"), 1.3, surgeIn, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			beamTo(at("Fragmentation") + surgeIn, 0.6, 0.3 * scale, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			beamTo(at("Dissipation"), 0, dissipationLength * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			add(at("End"), function()
				if beam.Parent then
					beam.Width0 = 0
					beam.Width1 = 0
				end
			end)
		end
	end

	-- Sonidos existentes (sin SoundIds nuevos ni cambios a los sonidos)
	for _, sound in ipairs(sounds) do
		if isFinalPoint then
			sound.Volume = math.min(sound.Volume * 1.15, 10)
		end
		local phase = SOUND_PHASES[sound.Name]
		local playOffset = math.max(num(sound, "PlayDelay", 0), 0)
		local when = (if phase then at(phase) else 0) + playOffset
		add(when, function()
			if sound.Parent then
				sound:Play()
			end
		end)
	end

	-- Fin del ciclo de vida (cleanup) y red de seguridad igual que Basic
	order += 1
	table.insert(events, { time = duration, order = order, run = cleanup })
	Debris:AddItem(model, duration + 1.0)

	local handle: EffectHandle = {
		Stop = function(_self)
			cleanup()
		end,
		Destroy = function(_self)
			cleanup()
		end,
		IsActive = function(_self)
			return isActive
		end,
	}
	activeHandles[model] = handle

	-- Si el modelo se destruye externamente (limpieza de partida/arena) se corta toda tarea pendiente
	destroyingConn = model.Destroying:Connect(function()
		cleanup()
	end)

	table.sort(events, function(a, b)
		if a.time ~= b.time then
			return a.time < b.time
		end
		return a.order < b.order
	end)

	-- Un unico hilo temporizador: no bloquea al llamador; los eventos de t=0 corren de inmediato
	driver = task.spawn(function()
		for _, ev in ipairs(events) do
			if not isActive then
				return
			end
			local remaining = ev.time - (os.clock() - startClock)
			if remaining > 0 then
				task.wait(remaining)
			end
			if not isActive then
				return
			end
			if not model.Parent then
				cleanup()
				return
			end
			local ok, err = pcall(ev.run)
			if not ok then
				warn(string.format("[InfernoController] Error en evento de la cinematica: %s", tostring(err)))
			end
		end
	end)

	return handle
end

PointEffectRegistry.Register("Inferno", InfernoController)

return InfernoController
