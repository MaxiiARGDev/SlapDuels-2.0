--!strict
-- SlapService
-- Servicio autoritativo centralizado del sistema de Slaps (bofetadas/armas de combate).
--
-- Principios arquitectonicos:
-- 1. Separacion total entre ASSET (modelo/configuracion en ServerStorage.Slaps) y LOGICA DE COMBATE (este servicio).
-- 2. Servidor autoritativo: El cliente solo solicita activar el Slap; el servidor valida que el jugador
--    tenga la herramienta equipada, pertenezca a una partida activa en estado Playing, respete el cooldown,
--    y valida el alcance/angulo fisico del impacto.
-- 3. Lectura data-driven: Power y SlapCooldown se leen directamente de Tool.Configuration (editables en Studio),
--    sin hardcodear valores ni bifurcar logica por nombre de Slap.
-- 4. Integracion estricta con la cadena existente:
--    Slap -> SlapService -> CombatService:RegisterHit() -> CombatTag -> RagdollService:ApplyRagdoll() -> KillPart -> EliminationService -> +1 Kill.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Constants = require(ReplicatedStorage.Shared.Constants)
local Types = require(ReplicatedStorage.Shared.Types)

type MatchSession = Types.MatchSession

local SlapService = {}
SlapService.Name = "SlapService"

-- Constantes de validacion de combate
local MAX_SLAP_REACH = 9.0 -- Studs maximos de distancia entre agresor y objetivo
local MIN_FACING_DOT = -0.2 -- Producto punto minimo (cono frontal de impacto de ~200 grados)
local DEFAULT_RAGDOLL_DURATION = 1.5 -- Duracion de ragdoll tras bofetada antes de reincorporarse

SlapService._context = nil :: any
SlapService._cooldowns = {} :: { [Player]: number }
SlapService._combatService = nil :: any
SlapService._ragdollService = nil :: any
SlapService._roundService = nil :: any
SlapService._performSlapRemote = nil :: RemoteEvent?
SlapService._connections = {} :: { RBXScriptConnection }

--------------------------------------------------------------------------------
-- Resolucion de Servicios Dependientes
--------------------------------------------------------------------------------

function SlapService:_getCombatService(): any
	if self._combatService then return self._combatService end
	if self._context and type(self._context.GetService) == "function" then
		local s = self._context:GetService("CombatService")
		if s then self._combatService = s; return s end
	end
	local mod = ServerScriptService.Services:FindFirstChild("CombatService")
	if mod and mod:IsA("ModuleScript") then
		local ok, res = pcall(require, mod)
		if ok and res then self._combatService = res; return res end
	end
	return nil
end

function SlapService:_getRagdollService(): any
	if self._ragdollService then return self._ragdollService end
	if self._context and type(self._context.GetService) == "function" then
		local s = self._context:GetService("RagdollService")
		if s then self._ragdollService = s; return s end
	end
	local mod = ServerScriptService.Services:FindFirstChild("RagdollService")
	if mod and mod:IsA("ModuleScript") then
		local ok, res = pcall(require, mod)
		if ok and res then self._ragdollService = res; return res end
	end
	return nil
end

function SlapService:_getRoundService(): any
	if self._roundService then return self._roundService end
	if self._context and type(self._context.GetService) == "function" then
		local s = self._context:GetService("RoundService")
		if s then self._roundService = s; return s end
	end
	local mod = ServerScriptService.Services:FindFirstChild("RoundService")
	if mod and mod:IsA("ModuleScript") then
		local ok, res = pcall(require, mod)
		if ok and res then self._roundService = res; return res end
	end
	return nil
end

--------------------------------------------------------------------------------
-- Remotes y Rutas
--------------------------------------------------------------------------------

local function ensureFolder(parent: Instance, name: string): Folder
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
	end
	return f :: Folder
end

local function ensureRemoteEvent(parent: Instance, name: string): RemoteEvent
	local ev = parent:FindFirstChild(name)
	if not ev then
		ev = Instance.new("RemoteEvent")
		ev.Name = name
		ev.Parent = parent
	end
	return ev :: RemoteEvent
end

function SlapService:_ensureRemotes()
	local remotesFolder = ensureFolder(ReplicatedStorage, "Remotes")
	local combatFolder = ensureFolder(remotesFolder, "Combat")
	self._performSlapRemote = ensureRemoteEvent(combatFolder, "PerformSlap")
end

--------------------------------------------------------------------------------
-- Catalogo y Clonado de Slaps
--------------------------------------------------------------------------------

function SlapService:GetSlapsFolder(): Folder?
	local slaps = ServerStorage:FindFirstChild("Slaps")
	if slaps and slaps:IsA("Folder") then
		return slaps
	end
	return nil
end

function SlapService:GetSlapTemplate(slapName: string): Tool?
	local slapsFolder = self:GetSlapsFolder()
	if not slapsFolder then return nil end
	local template = slapsFolder:FindFirstChild(slapName)
	if template and template:IsA("Tool") then
		return template
	end
	return nil
end

-- Clona un Slap desde ServerStorage.Slaps y lo entrega al jugador
function SlapService:GiveSlap(player: Player, slapName: string?): Tool?
	local targetName = slapName or "Classic"
	local template = self:GetSlapTemplate(targetName)
	if not template then
		-- Fallback a Classic si el solicitado no existe
		template = self:GetSlapTemplate("Classic")
	end
	if not template then
		warn(string.format("[SlapService] No se encontro plantilla de Slap para '%s'", tostring(targetName)))
		return nil
	end

	-- Limpiar cualquier Slap previo para evitar acumulacion
	self:RemoveSlaps(player)

	local clone = template:Clone()
	clone.Name = template.Name

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		clone.Parent = backpack
	elseif player.Character then
		clone.Parent = player.Character
	else
		clone:Destroy()
		return nil
	end

	return clone
end

-- Remueve todos los Slap tools del Backpack y Character del jugador
function SlapService:RemoveSlaps(player: Player)
	if not player then return end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") and child:FindFirstChild("Configuration") and child.Configuration:FindFirstChild("Power") then
				child:Destroy()
			end
		end
	end

	local char = player.Character
	if char then
		for _, child in ipairs(char:GetChildren()) do
			if child:IsA("Tool") and child:FindFirstChild("Configuration") and child.Configuration:FindFirstChild("Power") then
				child:Destroy()
			end
		end
	end
end

-- Entrega los Slaps a los contendientes de una partida
function SlapService:EquipMatchPlayers(session: MatchSession, slapName: string?)
	if not session then return end
	if session.RedPlayer then
		self:GiveSlap(session.RedPlayer, slapName)
	end
	if session.BluePlayer then
		self:GiveSlap(session.BluePlayer, slapName)
	end
end

-- Retira los Slaps de los contendientes de una partida
function SlapService:RemoveMatchPlayers(session: MatchSession)
	if not session then return end
	if session.RedPlayer then
		self:RemoveSlaps(session.RedPlayer)
	end
	if session.BluePlayer then
		self:RemoveSlaps(session.BluePlayer)
	end
end

--------------------------------------------------------------------------------
-- Validaciones Autoritativas de Activacion y Combate
--------------------------------------------------------------------------------

-- Valida que la herramienta sea un Slap autorizado con Configuration valida
function SlapService:_validateTool(player: Player, tool: any): (boolean, number, number, string?)
	if not tool or typeof(tool) ~= "Instance" or not tool:IsA("Tool") then
		return false, 0, 0, "InvalidToolInstance"
	end

	-- Debe estar equipada en el Character activo del jugador
	local char = player.Character
	if not char or tool.Parent ~= char then
		return false, 0, 0, "ToolNotEquipped"
	end

	local config = tool:FindFirstChild("Configuration")
	if not config then
		return false, 0, 0, "MissingConfiguration"
	end

	local powerVal = config:FindFirstChild("Power")
	if not powerVal or not powerVal:IsA("NumberValue") or powerVal.Value <= 0 then
		return false, 0, 0, "InvalidPowerValue"
	end

	local cooldownVal = config:FindFirstChild("SlapCooldown")
	if not cooldownVal or not cooldownVal:IsA("NumberValue") or cooldownVal.Value < 0 then
		return false, 0, 0, "InvalidCooldownValue"
	end

	return true, powerVal.Value, cooldownVal.Value, nil
end

local function isPlayer(p: any): boolean
	if not p then return false end
	if typeof(p) == "Instance" then
		return p:IsA("Player")
	end
	if (typeof(p) == "userdata" or typeof(p) == "table") and type(p.IsA) == "function" then
		return p:IsA("Player")
	end
	return false
end

-- Ejecuta la resolucion autoritativa del golpe
function SlapService:ProcessSlap(attacker: Player, tool: Tool): (boolean, string?)
	-- 1. Validar que el atacante sea un Player valido
	if not isPlayer(attacker) or not attacker.Parent then
		return false, "InvalidAttacker"
	end

	local attackerChar = attacker.Character
	if not attackerChar or not attackerChar:IsDescendantOf(workspace) then
		return false, "AttackerCharNotSpawned"
	end

	local attackerHumanoid = attackerChar:FindFirstChildOfClass("Humanoid")
	local attackerRoot = attackerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not attackerHumanoid or attackerHumanoid.Health <= 0 or not attackerRoot then
		return false, "AttackerNotAlive"
	end

	-- 2. Validar que la herramienta sea un Slap valido y este equipada
	local okTool, power, cooldown, toolErr = self:_validateTool(attacker, tool)
	if not okTool then
		return false, toolErr or "ToolValidationFailed"
	end

	-- 3. Validar estado de la partida (solo en estado PLAYING)
	local roundService = self:_getRoundService()
	if not roundService then
		return false, "RoundServiceUnavailable"
	end

	local session = roundService:GetSessionForPlayer(attacker)
	if not session then
		return false, "NotInMatch"
	end

	if session.State ~= Constants.RoundState.Playing then
		return false, "MatchNotPlaying"
	end

	-- 4. Validar cooldown del servidor
	local now = os.clock()
	local nextAllowed = self._cooldowns[attacker] or 0
	if now < nextAllowed then
		return false, "OnCooldown"
	end
	self._cooldowns[attacker] = now + cooldown

	-- 5. Detectar objetivos validos en la partida
	local opponent: Player? = nil
	if session.RedPlayer == attacker then
		opponent = session.BluePlayer
	elseif session.BluePlayer == attacker then
		opponent = session.RedPlayer
	end

	if not isPlayer(opponent) or not opponent.Parent or opponent == attacker then
		return false, "NoValidOpponent"
	end

	local victimChar = opponent.Character
	if not victimChar or not victimChar:IsDescendantOf(workspace) then
		return false, "VictimNotSpawned"
	end

	local victimHumanoid = victimChar:FindFirstChildOfClass("Humanoid")
	local victimRoot = victimChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not victimHumanoid or victimHumanoid.Health <= 0 or not victimRoot then
		return false, "VictimNotAlive"
	end

	-- 6. Validacion espacial (distancia y angulo respecto al atacante)
	local diff = victimRoot.Position - attackerRoot.Position
	local distance = diff.Magnitude
	if distance > MAX_SLAP_REACH then
		return false, "OutOfReach"
	end

	local forwardDir = attackerRoot.CFrame.LookVector
	local toVictimDir = if distance > 0.05 then diff.Unit else forwardDir
	local facingDot = forwardDir:Dot(toVictimDir)
	if facingDot < MIN_FACING_DOT then
		return false, "TargetBehindAttacker"
	end

	-- 7. Registrar impacto autoritativo en CombatService
	local combatService = self:_getCombatService()
	if not combatService then
		return false, "CombatServiceUnavailable"
	end

	local hitSuccess, hitReason = combatService:RegisterHit(attacker, opponent, session.Id)
	if not hitSuccess then
		return false, hitReason or "CombatServiceRejected"
	end

	-- 8. Reproducir feedback sonoro de impacto
	local hand = tool:FindFirstChild("Hand")
	local hitSound = hand and hand:FindFirstChild("Hit") :: Sound?
	if hitSound and hitSound:IsA("Sound") then
		pcall(function()
			hitSound:Play()
		end)
	end

	-- 9. Aplicar knockback y ragdoll autoritativo via RagdollService
	local ragdollService = self:_getRagdollService()
	if ragdollService then
		local horizDiff = Vector3.new(diff.X, 0, diff.Z)
		local horizDir = if horizDiff.Magnitude > 0.1 then horizDiff.Unit else forwardDir

		local upwardRatio = 0.35
		local vertSpeed = math.max(power * upwardRatio * 1.3, 26)
		local horizSpeed = power * (1 - upwardRatio * 0.2)
		local launchVelocity = horizDir * horizSpeed + Vector3.new(0, vertSpeed, 0)

		ragdollService:ApplyRagdoll(victimChar, DEFAULT_RAGDOLL_DURATION, launchVelocity)
	end

	print(string.format("[SlapService] Slap exitoso: '%s' golpeo a '%s' con '%s' (Power=%d, Cooldown=%.2f)",
		attacker.Name, opponent.Name, tool.Name, power, cooldown))

	return true, nil
end

--------------------------------------------------------------------------------
-- Ciclo de Vida Bootstrap
--------------------------------------------------------------------------------

function SlapService:Init(context: any)
	self._context = context
	self._cooldowns = {}
	self:_ensureRemotes()
end

function SlapService:Start(context: any)
	self._context = context

	-- Escuchar activacion remota desde el cliente
	if self._performSlapRemote then
		local conn = self._performSlapRemote.OnServerEvent:Connect(function(player: Player, tool: any)
			self:ProcessSlap(player, tool)
		end)
		table.insert(self._connections, conn)
	end

	-- Limpieza de cooldowns cuando un jugador se desconecta
	local leaveConn = Players.PlayerRemoving:Connect(function(player: Player)
		self._cooldowns[player] = nil
	end)
	table.insert(self._connections, leaveConn)

	print("[SlapService] Servicio centralizado de Slaps iniciado y listo")
end

return SlapService
