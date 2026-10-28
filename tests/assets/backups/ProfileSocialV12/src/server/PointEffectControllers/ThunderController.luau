--!strict
-- ThunderController
-- Coreografía exclusiva y data-driven del Point Effect "Thunder" para Slap Duels 2.0.
-- Soporta tanto los componentes base por convención de nombres (BURSTS, SUSTAIN, SOUND_PHASES)
-- como nuevos componentes agregados desde Roblox Studio (ParticleEmitter, Part, MeshPart, Attachment, Beam, Explosion)
-- mediante atributos de configuración o fallback inteligente basado en el estado inicial del template.
--
-- Contrato PointEffectRegistry: Play(context: PlayContext) -> EffectHandle { Stop, Destroy, IsActive }
-- Fases (5):
--   1. InitialDischarge (0.0s - 0.3s): Descarga inicial, destello de luz, chispas primarias.
--   2. LightningStrike  (0.3s - 1.0s): Rayo principal, erupción de partículas, columna sostenida.
--   3. Overcharge       (1.0s - 2.2s): Ondas de sobrecarga, pulsos de beam, oleadas secundarias.
--   4. FinalDischarge   (2.2s - 3.2s): Descarga conclusiva de alta energía.
--   5. Dissipation      (3.2s - 4.0s): Disipación gradual, decaimiento de tasas a cero.
--   Fin                 (4.0s):        Apagado de emisores y cierre seguro antes de cleanup.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local PointEffectRegistry = require(script.Parent.PointEffectRegistry)

type PlayContext = PointEffectRegistry.PlayContext
type EffectHandle = PointEffectRegistry.EffectHandle

type Burst = { phase: string, offset: number?, fraction: number, finalOnly: boolean? }
type Event = { time: number, order: number, run: () -> () }

local ThunderController = {}

-- Configuración de depuración global o por modelo (model:GetAttribute("Debug") == true)
ThunderController.Debug = false
-- Hook opcional para testing automatizado: (nombreDeFase, segundosTranscurridos) -> ()
ThunderController.DebugHook = nil :: ((phase: string, elapsed: number) -> ())?

local DEFAULT_DURATION = 8
local BASE_LENGTH = 4.0 -- Duración de la cinemática a escala 1 (segundos)
local TAIL_MARGIN = 1.6 -- Vida máxima de partículas + margen de seguridad
local MIN_SCALE = 0.25
local MAX_SCALE = 3.0

-- Inicio de cada fase (segundos a escala 1)
local PHASES: { [string]: number } = {
	InitialDischarge = 0.0,
	LightningStrike = 0.3,
	Overcharge = 1.0,
	FinalDischarge = 2.2,
	Dissipation = 3.2,
	End = BASE_LENGTH,
}
local PHASE_ORDER = { "InitialDischarge", "LightningStrike", "Overcharge", "FinalDischarge", "Dissipation" }
local WAVE_OFFSETS = { 0, 0.4, 0.8 }

-- Ráfagas heredadas por nombre (compatibilidad total con template Thunder original)
local BURSTS: { [string]: { Burst } } = {
	Glow = { { phase = "InitialDischarge", fraction = 1 }, { phase = "FinalDischarge", fraction = 1 } },
	Core = { { phase = "InitialDischarge", fraction = 1 } },
	Halo = { { phase = "InitialDischarge", fraction = 1 } },
	Glints = { { phase = "InitialDischarge", fraction = 1 }, { phase = "FinalDischarge", fraction = 0.6 } },
	GlintsLate = { { phase = "LightningStrike", fraction = 1 }, { phase = "FinalDischarge", fraction = 1 } },
	Sparks = {
		{ phase = "InitialDischarge", fraction = 0.3 },
		{ phase = "LightningStrike", fraction = 0.7 },
		{ phase = "FinalDischarge", fraction = 0.8 },
	},
	Embers = { { phase = "LightningStrike", fraction = 1 }, { phase = "FinalDischarge", fraction = 0.6 } },
	Puff = { { phase = "LightningStrike", fraction = 1 }, { phase = "FinalDischarge", fraction = 0.5 } },
	Disc = {
		{ phase = "Overcharge", offset = WAVE_OFFSETS[1], fraction = 1 },
		{ phase = "Overcharge", offset = WAVE_OFFSETS[2], fraction = 1 },
		{ phase = "Overcharge", offset = WAVE_OFFSETS[3], fraction = 1, finalOnly = true },
	},
	DiscGlow = {
		{ phase = "Overcharge", offset = WAVE_OFFSETS[1], fraction = 1 },
		{ phase = "Overcharge", offset = WAVE_OFFSETS[2], fraction = 1 },
		{ phase = "Overcharge", offset = WAVE_OFFSETS[3], fraction = 1, finalOnly = true },
	},
	Streaks = {
		{ phase = "Overcharge", offset = WAVE_OFFSETS[1], fraction = 0.6 },
		{ phase = "Overcharge", offset = WAVE_OFFSETS[2], fraction = 0.8 },
		{ phase = "Overcharge", offset = WAVE_OFFSETS[3], fraction = 0.5, finalOnly = true },
	},
	Dust = {
		{ phase = "Overcharge", offset = WAVE_OFFSETS[1], fraction = 0.6 },
		{ phase = "Overcharge", offset = WAVE_OFFSETS[2], fraction = 0.6 },
	},
}

-- Emisión continua sostenida heredada por nombre (partículas/seg a escala 1)
local SUSTAIN: { [string]: number } = { Embers = 24, Sparks = 10, Puff = 4 }

-- Fases de disparo de sonidos heredados
local SOUND_PHASES: { [string]: string } = {
	Thump = "InitialDischarge",
	Snap = "InitialDischarge",
	Boom = "LightningStrike",
	Crack = "FinalDischarge",
	Ping = "Overcharge",
	Glint = "FinalDischarge",
}

-- Instancias activas por modelo para evitar ejecuciones duplicadas simultáneas
local activeHandles: { [Instance]: EffectHandle } = {}

--------------------------------------------------------------------------------
-- Helpers de lectura defensiva de atributos
--------------------------------------------------------------------------------

local function num(inst: Instance, attr: string, default: number): number
	local v = inst:GetAttribute(attr)
	if typeof(v) == "number" then
		return v
	end
	return default
end

local function str(inst: Instance, attr: string, default: string?): string?
	local v = inst:GetAttribute(attr)
	if typeof(v) == "string" and v ~= "" then
		return v
	end
	return default
end

local function bool(inst: Instance, attr: string, default: boolean): boolean
	local v = inst:GetAttribute(attr)
	if typeof(v) == "boolean" then
		return v
	end
	return default
end

local function vec3(inst: Instance, attr: string, default: Vector3?): Vector3?
	local v = inst:GetAttribute(attr)
	if typeof(v) == "Vector3" then
		return v
	elseif typeof(v) == "string" then
		local parts = string.split(v, ",")
		if #parts == 3 then
			local x = tonumber(string.match(parts[1], "[%d%.%-]+"))
			local y = tonumber(string.match(parts[2], "[%d%.%-]+"))
			local z = tonumber(string.match(parts[3], "[%d%.%-]+"))
			if x and y and z then
				return Vector3.new(x, y, z)
			end
		end
	end
	return default
end

local function getEasingStyle(inst: Instance, attr: string, default: Enum.EasingStyle): Enum.EasingStyle
	local s = inst:GetAttribute(attr)
	if typeof(s) == "string" then
		local ok, val = pcall(function() return (Enum.EasingStyle :: any)[s] end)
		if ok and val then return val end
	end
	return default
end

local function getEasingDirection(inst: Instance, attr: string, default: Enum.EasingDirection): Enum.EasingDirection
	local s = inst:GetAttribute(attr)
	if typeof(s) == "string" then
		local ok, val = pcall(function() return (Enum.EasingDirection :: any)[s] end)
		if ok and val then return val end
	end
	return default
end

--------------------------------------------------------------------------------
-- Diagnóstico estático de componentes de un modelo
--------------------------------------------------------------------------------

export type DiagnosticResult = {
	modelName: string,
	totalCounts: { [string]: number },
	emitters: { { name: string, path: string, role: string, reason: string } },
	parts: { { name: string, path: string, role: string, reason: string, animType: string?, distFromPivot: number?, anchored: boolean?, canCollide: boolean? } },
	attachments: { { name: string, path: string, role: string, animType: string?, distFromPivot: number? } },
	beams: { { name: string, path: string, valid: boolean, att0: string?, att1: string? } },
	sounds: { { name: string, path: string, phase: string } },
	explosions: { { name: string, path: string, safe: boolean, phase: string } },
}

function ThunderController.Diagnose(model: Model): DiagnosticResult
	local emitters = {}
	local parts = {}
	local attachments = {}
	local beams = {}
	local lights = {}
	local sounds = {}
	local explosions = {}
	local pivotPos = model:GetPivot().Position

	for _, desc in ipairs(model:GetDescendants()) do
		local rel = desc:GetFullName()
		if desc:IsA("ParticleEmitter") then
			local customPhase = str(desc, "Phase", nil)
			local customCount = num(desc, "EmitCount", -1)
			local customSustain = num(desc, "SustainRate", -1)
			local hasBurstPlan = BURSTS[desc.Name] ~= nil
			local hasSustainPlan = SUSTAIN[desc.Name] ~= nil

			local role = "Desconocido"
			local reason = "Sin plan BURSTS ni atributos específicos"
			if customPhase or customCount > 0 or customSustain > 0 then
				role = "Atributos personalizados"
				reason = string.format("Phase=%s, EmitCount=%d, SustainRate=%.1f", tostring(customPhase), customCount, customSustain)
			elseif hasBurstPlan or hasSustainPlan then
				role = "Plan base heredado (BURSTS/SUSTAIN)"
				reason = string.format("BURSTS=%s, SUSTAIN=%s", tostring(hasBurstPlan), tostring(hasSustainPlan))
			elseif desc.Rate > 0 or desc.Enabled then
				role = "Sustain automático detectado"
				reason = string.format("Template original tenía Rate=%.1f y Enabled=%s", desc.Rate, tostring(desc.Enabled))
			else
				role = "Emisión puntual simple por defecto"
				reason = "EmitCount=1, EmitDelay=0"
			end

			table.insert(emitters, {
				name = desc.Name,
				path = rel,
				role = role,
				reason = reason,
			})
		elseif desc:IsA("BasePart") then
			local animType = str(desc, "AnimationType", nil)
			local role = if animType then ("Animada: " .. animType) else "Estática / Anclaje"
			local reason = if animType then "Tiene atributo AnimationType" else "Sin AnimationType (preservada estática)"
			local dist = (desc.Position - pivotPos).Magnitude
			table.insert(parts, {
				name = desc.Name,
				path = rel,
				role = role,
				reason = reason,
				animType = animType,
				distFromPivot = dist,
				anchored = desc.Anchored,
				canCollide = desc.CanCollide,
			})
		elseif desc:IsA("Attachment") then
			local animType = str(desc, "AnimationType", nil)
			local role = if animType then ("Animado: " .. animType) else "Estático"
			local dist = (desc.WorldPosition - pivotPos).Magnitude
			table.insert(attachments, {
				name = desc.Name,
				path = rel,
				role = role,
				animType = animType,
				distFromPivot = dist,
			})
		elseif desc:IsA("PointLight") then
			table.insert(lights, desc)
		elseif desc:IsA("Beam") then
			local hasAtt0 = desc.Attachment0 ~= nil and desc.Attachment0:IsDescendantOf(model)
			local hasAtt1 = desc.Attachment1 ~= nil and desc.Attachment1:IsDescendantOf(model)
			table.insert(beams, {
				name = desc.Name,
				path = rel,
				valid = hasAtt0 and hasAtt1,
				att0 = if desc.Attachment0 then desc.Attachment0.Name else nil,
				att1 = if desc.Attachment1 then desc.Attachment1.Name else nil,
			})
		elseif desc:IsA("Sound") then
			table.insert(sounds, {
				name = desc.Name,
				path = rel,
				phase = SOUND_PHASES[desc.Name] or "t=0",
			})
		elseif desc:IsA("Explosion") then
			table.insert(explosions, {
				name = desc.Name,
				path = rel,
				safe = true,
				phase = str(desc, "Phase", "LightningStrike") or "LightningStrike",
			})
		end
	end

	return {
		modelName = model.Name,
		totalCounts = {
			Emitters = #emitters,
			Parts = #parts,
			Attachments = #attachments,
			Beams = #beams,
			Lights = #lights,
			Sounds = #sounds,
			Explosions = #explosions,
		},
		emitters = emitters,
		parts = parts,
		attachments = attachments,
		beams = beams,
		sounds = sounds,
		explosions = explosions,
	}
end

--------------------------------------------------------------------------------
-- Función principal Play(context)
--------------------------------------------------------------------------------

function ThunderController.Play(context: PlayContext): EffectHandle
	local model = context.EffectModel
	local isFinalPoint = context.IsFinalPoint
	local scoringZone = context.ScoringZone

	-- Protección contra ejecuciones duplicadas sobre la misma instancia
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

	local isDebug = ThunderController.Debug or bool(model, "Debug", false)

	-- Referencia espacial canónica: ScoringZone o Pivot del modelo clonado
	local originPosition = if scoringZone and scoringZone:IsA("BasePart")
		then scoringZone.Position
		else model:GetPivot().Position
	local originCFrame = if scoringZone and scoringZone:IsA("BasePart")
		then CFrame.new(scoringZone.Position)
		else model:GetPivot()

	local duration = num(model, "Duration", DEFAULT_DURATION)
	if duration <= 0 then
		duration = DEFAULT_DURATION
	end
	local multiplier = if isFinalPoint then num(model, "FinalMultiplier", 1.4) else 1
	local rateMul = math.min(multiplier, 3)

	-- Escala temporal configurable (CinematicDuration / BASE_LENGTH)
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
			return
		end
		order += 1
		table.insert(events, { time = math.max(time, 0), order = order, run = run })
	end

	local function mark(name: string)
		local hook = ThunderController.DebugHook
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

	-- Limpieza segura garantizada
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

	----------------------------------------------------------------------------
	-- Fase 1.5: Normalización espacial defensiva del modelo clonado
	----------------------------------------------------------------------------

	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("BasePart") then
			-- Asegurar invariantes físicas: las partes visuales deben estar ancladas
			-- y sin colisión para evitar desplazamientos por física, gravedad o contacto
			desc.Anchored = true
			desc.CanCollide = false
			desc.Massless = true

			-- Si alguna pieza importada de un pack externo se encontraba a coordenadas
			-- arbitrarias del mundo (> 60 studs del origen), normalizarla al origen del gol
			local dist = (desc.Position - originPosition).Magnitude
			if dist > 60 then
				if isDebug then
					warn(string.format("[ThunderController] Normalización defensiva: Part '%s' a %.1f studs del origen. Reubicada a CFrame del ScoringZone.", desc.Name, dist))
				end
				desc.CFrame = originCFrame
			end
		elseif desc:IsA("Explosion") then
			-- Normalizar posición inicial de Explosion: no heredan PivotTo de modelos
			local parent = desc.Parent
			if parent and parent:IsA("BasePart") then
				desc.Position = parent.Position
			elseif parent and parent:IsA("Attachment") then
				desc.Position = parent.WorldPosition
			else
				desc.Position = originPosition
			end
			desc.BlastPressure = 0
			desc.BlastRadius = 0
			desc.DestroyJointRadiusPercent = 0
		end
	end

	----------------------------------------------------------------------------
	-- Fase 2: Recolección y diagnóstico de componentes
	----------------------------------------------------------------------------

	type EmitterRecord = {
		emitter: ParticleEmitter,
		origRate: number,
		origEnabled: boolean,
		path: string,
	}

	type PartRecord = {
		part: BasePart,
		origSize: Vector3,
		origTransparency: number,
		origCFrame: CFrame,
		path: string,
	}

	type AttachmentRecord = {
		attachment: Attachment,
		origPosition: Vector3,
		path: string,
	}

	local emitterRecords: { EmitterRecord } = {}
	local partRecords: { PartRecord } = {}
	local attachmentRecords: { AttachmentRecord } = {}
	local lights: { PointLight } = {}
	local beams: { Beam } = {}
	local sounds: { Sound } = {}
	local explosions: { Explosion } = {}

	for _, desc in ipairs(model:GetDescendants()) do
		local relPath = desc:GetFullName()
		if desc:IsA("ParticleEmitter") then
			table.insert(emitterRecords, {
				emitter = desc,
				origRate = desc.Rate,
				origEnabled = desc.Enabled,
				path = relPath,
			})
			-- Estado inicial seguro: desactivar hasta su programación
			desc.Enabled = false
			desc.Rate = 0
		elseif desc:IsA("BasePart") then
			table.insert(partRecords, {
				part = desc,
				origSize = desc.Size,
				origTransparency = desc.Transparency,
				origCFrame = desc.CFrame,
				path = relPath,
			})
		elseif desc:IsA("Attachment") then
			table.insert(attachmentRecords, {
				attachment = desc,
				origPosition = desc.Position,
				path = relPath,
			})
		elseif desc:IsA("PointLight") then
			table.insert(lights, desc)
		elseif desc:IsA("Beam") then
			table.insert(beams, desc)
		elseif desc:IsA("Sound") then
			desc.Looped = false
			table.insert(sounds, desc)
		elseif desc:IsA("Explosion") then
			-- Seguridad física absoluta: cero daño, presión ni destrucción
			desc.BlastPressure = 0
			desc.BlastRadius = 0
			desc.DestroyJointRadiusPercent = 0
			table.insert(explosions, desc)
		end
	end

	-- Diagnóstico controlado si Debug está activo
	if isDebug then
		print(string.format("[ThunderController:DEBUG] --- Diagnóstico de '%s' (IsFinalPoint=%s, Scale=%.2f, Origin=%s) ---",
			model.Name, tostring(isFinalPoint), scale, tostring(originPosition)))
		print(string.format("[ThunderController:DEBUG] Total componentes: %d Emisores, %d Parts, %d Attachments, %d Beams, %d Luces, %d Sonidos, %d Explosiones",
			#emitterRecords, #partRecords, #attachmentRecords, #beams, #lights, #sounds, #explosions))

		for _, er in ipairs(emitterRecords) do
			local e = er.emitter
			local customPhase = str(e, "Phase", nil)
			local customCount = num(e, "EmitCount", -1)
			local customSustain = num(e, "SustainRate", -1)
			local hasBurstPlan = BURSTS[e.Name] ~= nil
			local hasSustainPlan = SUSTAIN[e.Name] ~= nil

			local descRole = "Desconocido"
			if customPhase or customCount > 0 or customSustain > 0 then
				descRole = string.format("Atributos personalizados (Phase=%s, EmitCount=%d, SustainRate=%.1f)",
					tostring(customPhase), customCount, customSustain)
			elseif hasBurstPlan or hasSustainPlan then
				descRole = string.format("Plan base heredado (Bursts=%s, Sustain=%s)",
					tostring(hasBurstPlan), tostring(hasSustainPlan))
			elseif er.origRate > 0 or er.origEnabled then
				descRole = string.format("Fallback visual Studio (Sustain detectado: Rate=%.1f)", er.origRate)
			else
				descRole = "Emisión puntual simple por defecto"
			end
			print(string.format("  • [Emitter] %s -> %s", e.Name, descRole))
		end

		for _, pr in ipairs(partRecords) do
			local animType = str(pr.part, "AnimationType", nil)
			local dist = (pr.part.Position - originPosition).Magnitude
			if animType then
				print(string.format("  • [Part/MeshPart] %s -> Animación configurada (%s, Dist=%.1f)", pr.part.Name, animType, dist))
			else
				print(string.format("  • [Part/MeshPart] %s -> Estático/Anclaje (Dist=%.1f)", pr.part.Name, dist))
			end
		end

		for _, b in ipairs(beams) do
			local hasAtt0 = b.Attachment0 ~= nil and b.Attachment0:IsDescendantOf(model)
			local hasAtt1 = b.Attachment1 ~= nil and b.Attachment1:IsDescendantOf(model)
			print(string.format("  • [Beam] %s -> Attachments válidos: %s (Att0=%s, Att1=%s)",
				b.Name, tostring(hasAtt0 and hasAtt1), tostring(b.Attachment0), tostring(b.Attachment1)))
		end

		for _, exp in ipairs(explosions) do
			print(string.format("  • [Explosion] %s -> Cosmética segura en Pos=%s", exp.Name, tostring(exp.Position)))
		end
		print("[ThunderController:DEBUG] ----------------------------------------------------")
	end

	----------------------------------------------------------------------------
	-- Fase 3: Programación de marcadores de fase
	----------------------------------------------------------------------------

	for _, phase in ipairs(PHASE_ORDER) do
		local name = phase
		add(at(name), function()
			mark(name)
		end)
	end

	----------------------------------------------------------------------------
	-- Fase 3: Programación de ParticleEmitters
	----------------------------------------------------------------------------

	local dissipationLength = (PHASES.End - PHASES.Dissipation) * scale

	for _, er in ipairs(emitterRecords) do
		local emitter = er.emitter
		local isFinalOnly = bool(emitter, "FinalOnly", false)
		if isFinalOnly and not isFinalPoint then
			continue
		end

		local attrPhase = str(emitter, "Phase", nil)
		local attrEmitCount = emitter:GetAttribute("EmitCount")
		local attrEmitDelay = num(emitter, "EmitDelay", 0)
		local attrSustainRate = emitter:GetAttribute("SustainRate")
		local burstPlan = BURSTS[emitter.Name]
		local sustainPlan = SUSTAIN[emitter.Name]

		-- 1. Ráfagas programadas por atributos explícitos
		if attrPhase or (typeof(attrEmitCount) == "number" and attrEmitCount > 0 and not burstPlan) then
			local targetPhase = attrPhase or "LightningStrike"
			local baseCount = if typeof(attrEmitCount) == "number" and attrEmitCount > 0 then attrEmitCount else 1
			local count = math.max(1, math.floor(baseCount * multiplier + 0.5))
			local repeatCount = math.max(1, math.floor(num(emitter, "BurstCount", 1)))
			local burstInterval = math.max(num(emitter, "BurstInterval", 0.2), 0.05)

			for i = 1, repeatCount do
				local offset = attrEmitDelay + (i - 1) * burstInterval
				add(at(targetPhase, offset), function()
					if emitter.Parent then
						emitter:Emit(count)
					end
				end)
			end

		-- 2. Ráfagas heredadas por nombre (BURSTS)
		elseif burstPlan then
			local base = num(emitter, "EmitCount", 1)
			local emitOffset = math.max(attrEmitDelay, 0)
			for _, burst in ipairs(burstPlan) do
				if not burst.finalOnly or isFinalPoint then
					local count = math.max(1, math.floor(base * multiplier * burst.fraction + 0.5))
					add(at(burst.phase, burst.offset) + emitOffset, function()
						if emitter.Parent then
							emitter:Emit(count)
						end
					end)
				end
			end

		-- 3. Emisor sin plan pero con Rate > 0 original en Studio: se maneja en la sección de sustain abajo
		-- 4. Emisor totalmente sin configuración: ráfaga genérica segura
		elseif er.origRate <= 0 and not er.origEnabled then
			local base = num(emitter, "EmitCount", 1)
			local count = math.max(1, math.floor(base * multiplier + 0.5))
			add(attrEmitDelay, function()
				if emitter.Parent then
					emitter:Emit(count)
				end
			end)
		end

		-- 5. Emisión continua sostenida (Sustain)
		-- Prioridad: Atributo SustainRate > Plan SUSTAIN heredado > Tasa original de Studio si estaba habilitada
		local sustainTarget: number? = nil
		if typeof(attrSustainRate) == "number" and attrSustainRate > 0 then
			sustainTarget = attrSustainRate * rateMul
		elseif sustainPlan then
			sustainTarget = sustainPlan * rateMul
		elseif er.origRate > 0 or er.origEnabled then
			-- Reconocimiento automático de componentes agregados desde Studio con Rate pre-configurado
			local effectiveRate = if er.origRate > 0 then er.origRate else 20
			sustainTarget = effectiveRate * rateMul
		end

		if sustainTarget and sustainTarget > 0 then
			local targetRate = sustainTarget :: number
			local startPhase = str(emitter, "SustainPhase", "LightningStrike") :: string
			local endPhase = str(emitter, "SustainEndPhase", "Dissipation") :: string

			add(at(startPhase), function()
				if emitter.Parent then
					emitter.Enabled = true
					tween(emitter, TweenInfo.new(0.4 * scale, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Rate = targetRate })
				end
			end)

			add(at(endPhase), function()
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

	----------------------------------------------------------------------------
	-- Fase 3: Animación configurable de Part y MeshPart
	----------------------------------------------------------------------------

	for _, pr in ipairs(partRecords) do
		local part = pr.part
		local animType = str(part, "AnimationType", nil)
		if not animType then
			continue -- Partes de anclaje/colisión no configuradas se preservan estáticas
		end

		local phase = str(part, "Phase", "LightningStrike") :: string
		local delaySec = num(part, "AnimationDelay", 0)
		local durSec = math.max(num(part, "AnimationDuration", 0.5 * scale), 0.05)
		local style = getEasingStyle(part, "EasingStyle", Enum.EasingStyle.Quad)
		local dir = getEasingDirection(part, "EasingDirection", Enum.EasingDirection.Out)
		local scaleWithFinal = bool(part, "ScaleWithFinal", false)
		local partMul = if scaleWithFinal and isFinalPoint then multiplier else 1

		local startSize = vec3(part, "StartSize", nil)
		local endSize = vec3(part, "EndSize", nil)
		local startTrans = part:GetAttribute("StartTransparency")
		local endTrans = part:GetAttribute("EndTransparency")
		local rotateAngles = vec3(part, "RotateAngles", nil)
		local startOffset = vec3(part, "StartOffset", nil) or vec3(part, "StartPosition", nil)
		local endOffset = vec3(part, "EndOffset", nil) or vec3(part, "EndPosition", nil)

		local animTypes = string.split(string.lower(animType), ",")

		-- Configuración del estado inicial de la animación (relativo al clon)
		if table.find(animTypes, "expand") then
			if startSize then
				part.Size = startSize
			end
		end
		if table.find(animTypes, "fade") and typeof(startTrans) == "number" then
			part.Transparency = startTrans
		end
		if startOffset then
			part.CFrame = pr.origCFrame * CFrame.new(startOffset)
		end

		local targetTime = at(phase, delaySec)

		add(targetTime, function()
			if not part.Parent then return end

			local goals: { [string]: any } = {}

			for _, t in ipairs(animTypes) do
				local cleanT = string.gsub(t, "%s+", "")
				if cleanT == "expand" then
					local targetSize = if endSize then (endSize * partMul) else (pr.origSize * partMul)
					goals.Size = targetSize
				elseif cleanT == "fade" then
					local targetTrans = if typeof(endTrans) == "number" then endTrans else 1
					goals.Transparency = targetTrans
				elseif cleanT == "pulse" then
					-- Pulso: crece y retorna
					local pulseSize = (endSize or pr.origSize * 1.3) * partMul
					local halfDur = durSec * 0.5
					tween(part, TweenInfo.new(halfDur, style, Enum.EasingDirection.Out), { Size = pulseSize })
					task.delay(halfDur, function()
						if part.Parent and isActive then
							tween(part, TweenInfo.new(halfDur, style, Enum.EasingDirection.In), { Size = pr.origSize })
						end
					end)
				elseif cleanT == "rotate" and rotateAngles then
					local radAngles = Vector3.new(math.rad(rotateAngles.X), math.rad(rotateAngles.Y), math.rad(rotateAngles.Z))
					local baseCF = if endOffset then (pr.origCFrame * CFrame.new(endOffset * partMul)) else pr.origCFrame
					goals.CFrame = baseCF * CFrame.Angles(radAngles.X * partMul, radAngles.Y * partMul, radAngles.Z * partMul)
				end
			end

			if endOffset and not (table.find(animTypes, "rotate") and rotateAngles) then
				goals.CFrame = pr.origCFrame * CFrame.new(endOffset * partMul)
			end

			if next(goals) ~= nil then
				tween(part, TweenInfo.new(durSec, style, dir), goals)
			end
		end)

		-- Limpieza o desvanecimiento hacia el final si la parte debe desaparecer
		local autoFadeAtEnd = bool(part, "AutoFadeAtEnd", false)
		if autoFadeAtEnd then
			add(at("Dissipation"), function()
				if part.Parent then
					tween(part, TweenInfo.new(dissipationLength * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 })
				end
			end)
		end
	end

	----------------------------------------------------------------------------
	-- Fase 3: Animación opcional de Attachments (sin alterar Beams)
	----------------------------------------------------------------------------

	-- Determinar qué attachments son requeridos por Beams para proteger su geometría
	local protectedAttachments: { [Attachment]: boolean } = {}
	for _, beam in ipairs(beams) do
		if beam.Attachment0 then protectedAttachments[beam.Attachment0] = true end
		if beam.Attachment1 then protectedAttachments[beam.Attachment1] = true end
	end

	for _, ar in ipairs(attachmentRecords) do
		local att = ar.attachment
		local animType = str(att, "AnimationType", nil)
		if not animType then
			continue
		end

		-- Si el attachment forma parte de un Beam y no se declaró explícitamente OverrideBeam
		if protectedAttachments[att] and not bool(att, "OverrideBeam", false) then
			if isDebug then
				warn(string.format("[ThunderController:DEBUG] Attachment '%s' protege geometría de Beam; animación omitida.", att.Name))
			end
			continue
		end

		local phase = str(att, "Phase", "LightningStrike") :: string
		local delaySec = num(att, "AnimationDelay", 0)
		local durSec = math.max(num(att, "AnimationDuration", 0.5 * scale), 0.05)
		local startPos = vec3(att, "StartPosition", nil)
		local endPos = vec3(att, "EndPosition", nil)
		local style = getEasingStyle(att, "EasingStyle", Enum.EasingStyle.Quad)
		local dir = getEasingDirection(att, "EasingDirection", Enum.EasingDirection.Out)

		if startPos then
			att.Position = startPos
		end

		if endPos then
			add(at(phase, delaySec), function()
				if att.Parent then
					tween(att, TweenInfo.new(durSec, style, dir), { Position = endPos })
				end
			end)
		end
	end

	----------------------------------------------------------------------------
	-- Fase 3: Detección y ejecución segura de Explosions (cosméticas)
	----------------------------------------------------------------------------

	for _, exp in ipairs(explosions) do
		local phase = str(exp, "Phase", "LightningStrike") :: string
		local delaySec = num(exp, "Delay", 0)
		local isVisible = bool(exp, "Visible", true)

		add(at(phase, delaySec), function()
			if exp.Parent then
				-- Asegurar invariante: posición en el padre o ScoringZone, cero daño físico
				local parent = exp.Parent
				if parent:IsA("BasePart") then
					exp.Position = parent.Position
				elseif parent:IsA("Attachment") then
					exp.Position = parent.WorldPosition
				else
					exp.Position = originPosition
				end
				exp.BlastPressure = 0
				exp.BlastRadius = 0
				exp.DestroyJointRadiusPercent = 0
				exp.Visible = isVisible
			end
		end)
	end

	----------------------------------------------------------------------------
	-- Iluminación (PointLight)
	----------------------------------------------------------------------------

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

			lightTo(at("InitialDischarge"), peak, lightIn, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			lightTo(at("InitialDischarge") + lightIn, peak * 0.45, 0.25 * scale, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

			local flickerStep = math.max(0.15 * scale, 0.05)
			local t = at("LightningStrike")
			local flickerEnd = at("FinalDischarge") - flickerStep
			local guard = 0
			while t < flickerEnd and guard < 24 do
				lightTo(t, peak * (0.3 + 0.2 * rng:NextNumber()), flickerStep * 0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				t += flickerStep
				guard += 1
			end

			lightTo(at("FinalDischarge"), peak * 0.8, 0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			lightTo(at("FinalDischarge") + 0.05, peak * 0.3, lightFade * scale, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			lightTo(at("Dissipation"), 0, dissipationLength * 0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			add(at("End"), function()
				if light.Parent then
					light.Brightness = 0
				end
			end)
		end
	end

	----------------------------------------------------------------------------
	-- Columna eléctrica (Beam)
	----------------------------------------------------------------------------

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

			beamTo(at("LightningStrike"), 0.5, 0.3 * scale, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			beamTo(at("LightningStrike", 0.3), 1, 0.4 * scale, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			beamTo(at("Overcharge", WAVE_OFFSETS[2]), 0.88, 0.3 * scale, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			beamTo(at("Overcharge", WAVE_OFFSETS[3]), 1, 0.3 * scale, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			beamTo(at("FinalDischarge"), 1.3, surgeIn, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			beamTo(at("FinalDischarge") + surgeIn, 0.6, 0.25 * scale, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			beamTo(at("Dissipation"), 0, dissipationLength * 0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			add(at("End"), function()
				if beam.Parent then
					beam.Width0 = 0
					beam.Width1 = 0
				end
			end)
		end
	end

	----------------------------------------------------------------------------
	-- Sonidos existentes
	----------------------------------------------------------------------------

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

	----------------------------------------------------------------------------
	-- Ciclo de vida y orquestador temporal
	----------------------------------------------------------------------------

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

	destroyingConn = model.Destroying:Connect(function()
		cleanup()
	end)

	table.sort(events, function(a, b)
		if a.time ~= b.time then
			return a.time < b.time
		end
		return a.order < b.order
	end)

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
				warn(string.format("[ThunderController] Error en evento de la cinemática: %s", tostring(err)))
			end
		end
	end)

	return handle
end

PointEffectRegistry.Register("Thunder", ThunderController)

return ThunderController
