--[[
	====================================================================
	SISTEMA DE SECUENCIA DE ANIMACIONES EN BUCLE CON CROSSFADE (MULTI-ZONA)
	====================================================================

	Recorre TODAS las carpetas dentro de Workspace.ZoneMatchmaking que
	contengan un subfolder "text" y anima sus modelos de letras
	(front / shadow). Cada carpeta puede tener SU PROPIA secuencia.

	CÓMO CONFIGURAR CADA CARPETA (atributos en la propia carpeta,
	por ej. Workspace.ZoneMatchmaking.1v1):
	- "Secuencia" (String): Números separados por coma. Ej: "3, 4, 5"
	- "DuracionFase" (Number): Segundos por animación (por defecto 4.0).
	- "TiempoTransicion" (Number): Segundos de fundido entre fases (0.6).

	Si una carpeta no tiene "Secuencia", usa SECUENCIA_DEFAULT.

	CATÁLOGO DE ANIMACIONES:
		0  = Apagada     |  5 = Glitch       |  9 = Shockwave
		1  = Ola         |  6 = Bamboleo     | 10 = Respiración
		2  = Pulso       |  7 = Latido       | 11 = Twist 3D
		3  = Rebote      |  8 = Péndulo      | 12 = Alerta
		4  = Flotación   |
	====================================================================
]]

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Secuencia por defecto si una carpeta no define el atributo "Secuencia"
local SECUENCIA_DEFAULT = {
	{ id = 1, duracion = 5.0 },
	{ id = 3, duracion = 4.0 },
	{ id = 7, duracion = 4.5 },
}

local DURACION_FASE_DEFAULT = 4.0
local TIEMPO_TRANSICION_DEFAULT = 0.6

-- 1. Carpeta raíz
local raiz = Workspace:WaitForChild("ZoneMatchmaking", 10)
if not raiz then warn("[AnimacionLetras] Falta ZoneMatchmaking") return end

-- Catálogo matemático de animaciones
local animaciones = {
	[0] = function() return 0, 1, 1, 0, 0 end,

	[1] = function(t, i)
		local s = math.sin(t * 2.2 - i * 0.45)
		local u = s * 0.5 + 0.5
		local esc = 1 + 0.15 * u
		return s * 0.8, esc, esc, 0, 0
	end,

	[2] = function(t)
		local u = math.sin(t * 2.5) * 0.5 + 0.5
		local esc = 1 + 0.25 * u
		return u * 0.4, esc, esc, 0, 0
	end,

	[3] = function(t, i, alto)
		local ciclo = (t * 1.2 - i * 0.09) % 1
		local dy, sxz, sy = 0, 1, 1
		if ciclo < 0.6 then
			local h = math.sin(math.pi * ciclo / 0.6)
			dy = h * 1.3
			sy = 1 + 0.12 * h
			sxz = 1 - 0.04 * h
		elseif ciclo < 0.8 then
			local q = math.sin(math.pi * (ciclo - 0.6) / 0.2)
			sy = 1 - 0.2 * q
			sxz = 1 + 0.1 * q
		end
		dy += (sy - 1) * alto * 0.5
		return dy, sxz, sy, 0, 0
	end,

	[4] = function(t, i)
		local dy = math.sin(t * 1.8 + i * 0.35) * 0.35
		local roll = math.sin(t * 1.4 + i * 0.25) * 0.04
		return dy, 1, 1, roll, 0
	end,

	[5] = function(t, i)
		local shake = math.sin(t * 35 + i * 17) * 0.08
		local pulse = 1 + math.abs(math.sin(t * 18 + i)) * 0.08
		return shake, pulse, pulse, shake * 0.4, 0
	end,

	[6] = function(t, i)
		local rot = math.sin(t * 3 - i * 0.5) * 0.12
		local dy = math.abs(math.sin(t * 3 - i * 0.5)) * 0.2
		return dy, 1, 1, rot, 0
	end,

	[7] = function(t, i)
		local ciclo = (t * 1.1 - i * 0.04) % 1
		local esc = 1
		if ciclo < 0.12 then
			esc = 1 + math.sin(ciclo / 0.12 * math.pi) * 0.3
		elseif ciclo > 0.2 and ciclo < 0.32 then
			esc = 1 + math.sin((ciclo - 0.2) / 0.12 * math.pi) * 0.18
		end
		return (esc - 1) * 0.5, esc, esc, 0, 0
	end,

	[8] = function(t, i)
		local rot = math.sin(t * 2.4 - i * 0.3) * 0.18
		local dy = -math.abs(rot) * 0.3
		return dy, 1, 1, rot, 0
	end,

	[9] = function(t, i, alto)
		local ciclo = (t * 0.9 - i * 0.07) % 1
		local dy, sy, sxz = 0, 1, 1
		if ciclo < 0.15 then
			local p = math.sin(ciclo / 0.15 * math.pi)
			sy = 1 - 0.25 * p
			sxz = 1 + 0.2 * p
			dy = -(1 - sy) * alto * 0.5
		elseif ciclo < 0.5 then
			local p = math.sin((ciclo - 0.15) / 0.35 * math.pi)
			dy = p * 1.1
			sy = 1 + 0.15 * p
			sxz = 1 - 0.05 * p
		end
		return dy, sxz, sy, 0, 0
	end,

	[10] = function(t)
		local u = math.sin(t * 1.4) * 0.5 + 0.5
		local esc = 1 + 0.18 * (u ^ 2)
		return (esc - 1) * 0.3, esc, esc, 0, 0
	end,

	[11] = function(t, i)
		local rotZ = math.sin(t * 2.5 - i * 0.4) * 0.1
		local rotX = math.cos(t * 2.5 - i * 0.4) * 0.12
		local dy = math.sin(t * 2.5 - i * 0.4) * 0.25
		return dy, 1, 1, rotZ, rotX
	end,

	[12] = function(t, i)
		local ciclo = (t * 3.5) % 1
		local pulse = (ciclo < 0.4) and (1 + math.sin(ciclo / 0.4 * math.pi) * 0.22) or 1
		local shake = math.sin(t * 40 + i * 5) * 0.05
		return (pulse - 1) * 0.3, pulse, pulse, shake, 0
	end,
}

local function lerp(a, b, w)
	return a + (b - a) * w
end

-- Espera a que un modelo tenga partes cargadas
local function esperarCargaPartes(modelo)
	local partes = {}
	local timeout = os.clock() + 5
	repeat
		partes = {}
		for _, desc in ipairs(modelo:GetDescendants()) do
			if desc:IsA("BasePart") then
				table.insert(partes, desc)
			end
		end
		if #partes == 0 then task.wait(0.2) end
	until #partes > 0 or os.clock() > timeout
	return partes
end

local function reunir(modelo)
	local lista = esperarCargaPartes(modelo)
	table.sort(lista, function(a, b)
		return a.Position.Z < b.Position.Z
	end)
	return lista
end

-- Devuelve true si el nombre parece de letra frontal o sombra
local function esModeloDeLetras(nombre)
	local n = string.lower(nombre)
	return string.find(n, "front", 1, true) ~= nil or string.find(n, "shadow", 1, true) ~= nil
end

-- Lee la secuencia de una carpeta (atributo "Secuencia") o cae a la default
local function obtenerSecuencia(carpeta)
	local attr = carpeta:GetAttribute("Secuencia")
	if type(attr) == "string" and #attr > 0 then
		local lista = {}
		local dur = tonumber(carpeta:GetAttribute("DuracionFase")) or DURACION_FASE_DEFAULT
		for token in string.gmatch(attr, "[^,%s]+") do
			local id = tonumber(token)
			if id then
				table.insert(lista, { id = id, duracion = dur })
			end
		end
		if #lista > 0 then return lista end
	end
	return SECUENCIA_DEFAULT
end

-- Arranca la animación para una zona (carpeta con subfolder "text")
local function animarZona(carpeta)
	local textFolder = carpeta:WaitForChild("text", 10)
	if not textFolder then
		warn("[AnimacionLetras] Falta 'text' en " .. carpeta.Name)
		return
	end

	-- Reunir SOLO los modelos de letras (front / shadow)
	local letras = {}
	for _, hijo in ipairs(textFolder:GetChildren()) do
		if hijo:IsA("Model") and esModeloDeLetras(hijo.Name) then
			local partes = reunir(hijo)
			for i, parte in ipairs(partes) do
				table.insert(letras, {
					parte = parte,
					i = i,
					cf = parte.CFrame,
					size = parte.Size,
				})
			end
		end
	end

	if #letras == 0 then
		warn("[AnimacionLetras] Sin modelos de letras en " .. carpeta.Name)
		return
	end

	local t0 = os.clock()
	local updateSignal = RunService:IsClient() and RunService.RenderStepped or RunService.Heartbeat

	updateSignal:Connect(function()
		local t = os.clock() - t0
		local secuencia = obtenerSecuencia(carpeta)
		local transicion = tonumber(carpeta:GetAttribute("TiempoTransicion")) or TIEMPO_TRANSICION_DEFAULT

		local duracionTotal = 0
		for _, paso in ipairs(secuencia) do
			duracionTotal += paso.duracion
		end
		if duracionTotal <= 0 then return end

		local tCiclo = t % duracionTotal
		local acumulado = 0
		local indiceActual = 1
		local tiempoEnFase = 0

		for idx, paso in ipairs(secuencia) do
			if tCiclo >= acumulado and tCiclo < (acumulado + paso.duracion) then
				indiceActual = idx
				tiempoEnFase = tCiclo - acumulado
				break
			end
			acumulado += paso.duracion
		end

		local pasoActual = secuencia[indiceActual]
		local siguienteIndice = (indiceActual % #secuencia) + 1
		local pasoSiguiente = secuencia[siguienteIndice]

		local fActual = animaciones[pasoActual.id] or animaciones[0]
		local fSiguiente = animaciones[pasoSiguiente.id] or animaciones[0]

		local pesoMezcla = 0
		local tiempoRestante = pasoActual.duracion - tiempoEnFase
		if tiempoRestante < transicion then
			local p = 1 - (tiempoRestante / transicion)
			pesoMezcla = p * p * (3 - 2 * p)
		end

		for _, l in ipairs(letras) do
			local dy1, sxz1, sy1, rz1, rx1 = fActual(t, l.i, l.size.Y)
			local dy, sxz, sy, rz, rx = dy1, sxz1, sy1, rz1 or 0, rx1 or 0

			if pesoMezcla > 0 then
				local dy2, sxz2, sy2, rz2, rx2 = fSiguiente(t, l.i, l.size.Y)
				dy = lerp(dy1, dy2, pesoMezcla)
				sxz = lerp(sxz1, sxz2, pesoMezcla)
				sy = lerp(sy1, sy2, pesoMezcla)
				rz = lerp(rz1 or 0, rz2 or 0, pesoMezcla)
				rx = lerp(rx1 or 0, rx2 or 0, pesoMezcla)
			end

			l.parte.Size = Vector3.new(l.size.X * sxz, l.size.Y * sy, l.size.Z * sxz)
			l.parte.CFrame = (l.cf + Vector3.new(0, dy, 0)) * CFrame.Angles(rx, 0, rz)
		end
	end)
end

-- Arrancar zonas ya presentes
for _, hijo in ipairs(raiz:GetChildren()) do
	if hijo:IsA("Folder") and hijo:FindFirstChild("text") then
		task.spawn(animarZona, hijo)
	end
end

-- Detectar zonas nuevas (clones, carpetas añadidas en runtime)
raiz.ChildAdded:Connect(function(hijo)
	if hijo:IsA("Folder") then
		local textFolder = hijo:WaitForChild("text", 10)
		if textFolder then
			task.spawn(animarZona, hijo)
		end
	end
end)
