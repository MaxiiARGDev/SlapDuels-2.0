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
local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

type MatchSession = Types.MatchSession

local SlapService = {}
SlapService.Name = "SlapService"

-- Constantes de validacion de combate
local MAX_SLAP_REACH = 9.0 -- Studs maximos de distancia entre agresor y objetivo
local MIN_FACING_DOT = -0.2 -- Producto punto minimo (cono frontal de impacto de ~200 grados)
-- Knockdown duration is centralized in Config.Combat.DefaultSlapKnockdownDuration.

SlapService._context = nil :: any
SlapService._swingSequence = {} :: { [Player]: number }
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
	self._slapFeedbackRemote = ensureRemoteEvent(combatFolder, "SlapFeedback")
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

-- Identifica de forma autoritativa si una herramienta es un Slap administrado por SlapService
function SlapService:IsSlapTool(tool: any): boolean
	if not tool or typeof(tool) ~= "Instance" or not tool:IsA("Tool") then
		return false
	end

	-- 1. Identificación autoritativa explícita: debe haber sido creada y sellada por GiveSlap
	if tool:GetAttribute("IsSlapWeapon") ~= true then
		return false
	end

	-- 2. Validación estructural complementaria del contenedor de combate
	local config = tool:FindFirstChild("Configuration")
	if not config or not config:FindFirstChild("Power") then
		return false
	end

	return true
end

export type PlayerLockData = {
	slapName: string,
	playerConnections: { RBXScriptConnection },
	charConnections: { RBXScriptConnection },
	isEnforcing: boolean,
	currentTool: Tool?,
}

SlapService._playerLocks = {} :: { [Player]: PlayerLockData }

-- Clona un Slap desde ServerStorage.Slaps, lo entrega al jugador y lo equipa automáticamente
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
	clone.CanBeDropped = false
	clone:SetAttribute("IsSlapWeapon", true)
	clone:SetAttribute("SlapName", template.Name)

	local backpack = player:FindFirstChildOfClass("Backpack")
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")

	if backpack then
		clone.Parent = backpack
		if humanoid and humanoid.Health > 0 and char and char:IsDescendantOf(workspace) then
			pcall(function()
				humanoid:EquipTool(clone)
			end)
		end
	elseif char then
		clone.Parent = char
		if humanoid and humanoid.Health > 0 and char:IsDescendantOf(workspace) then
			pcall(function()
				humanoid:EquipTool(clone)
			end)
		end
	else
		clone:Destroy()
		return nil
	end

	-- Si el jugador tiene un lock activo, actualizar la referencia a la nueva herramienta
	local lock = self._playerLocks[player]
	if lock then
		lock.currentTool = clone
	end

	return clone
end

-- Remueve todos los Slap tools del Backpack y Character del jugador
function SlapService:RemoveSlaps(player: Player)
	if not player then return end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if self:IsSlapTool(child) then
				child:Destroy()
			end
		end
	end

	local char = player.Character
	if char then
		for _, child in ipairs(char:GetChildren()) do
			if self:IsSlapTool(child) then
				child:Destroy()
			end
		end
	end

	-- Restaurar cualquier herramienta ajena preservada en Player hacia Backpack
	if backpack then
		for _, child in ipairs(player:GetChildren()) do
			if child:IsA("Tool") then
				if self:IsSlapTool(child) then
					child:Destroy()
				else
					child.Parent = backpack
				end
			end
		end
	end
end

-- Bloquea autoritativamente el equipamiento del jugador para que no pueda desequipar ni cambiar de herramienta
function SlapService:LockAndEquipPlayer(player: Player, slapName: string?)
	if not player or not player:IsA("Player") or not player:IsDescendantOf(Players) then
		return
	end

	self:UnlockPlayer(player)

	local lockData: PlayerLockData = {
		slapName = slapName or "Classic",
		playerConnections = {},
		charConnections = {},
		isEnforcing = false,
		currentTool = nil,
	}
	self._playerLocks[player] = lockData

	local function enforceEquipped()
		if self._playerLocks[player] ~= lockData then return end
		if lockData.isEnforcing then return end

		local char = player.Character
		if not char or not char.Parent or not char:IsDescendantOf(workspace) then return end
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then return end

		local tool = lockData.currentTool

		-- Detectar si hay alguna herramienta no autorizada en Character
		local hasForeignTool = false
		for _, item in ipairs(char:GetChildren()) do
			if item:IsA("Tool") and item ~= tool then
				hasForeignTool = true
				break
			end
		end

		if tool and tool.Parent == char and not hasForeignTool then
			return
		end

		lockData.isEnforcing = true
			local generation = char:GetAttribute("ArenaPhysicsGeneration") or 0
			local matchId = player:GetAttribute("MatchId")
			local rounds = self:_getRoundService()
			local session = rounds and rounds:GetSessionForPlayer(player)
			local version = session and session.StateVersion
			local function currentCharacter(): boolean
				return player.Parent == Players and player.Character == char and char.Parent ~= nil
					and (char:GetAttribute("ArenaPhysicsGeneration") or 0) == generation
					and not char:GetAttribute("ArenaRespawnPending")
					and player:GetAttribute("MatchId") == matchId
					and player:GetAttribute("ResultsSessionId") == nil
					and (session == nil or (rounds:GetSessionForPlayer(player) == session
						and session.StateVersion == version and rounds:IsSessionActive(session.Id)
						and not session.Closing and not session.Closed and not session.Cancelled and not session.GameplayFrozen))
			end
		task.defer(function()
			-- Verificación estricta de identidad de bloqueo
				if self._playerLocks[player] ~= lockData or not currentCharacter() then
				lockData.isEnforcing = false
				return
			end

			local success, err = pcall(function()
					local c = char
				local h = c and c:FindFirstChildOfClass("Humanoid")
				if c and c.Parent and c:IsDescendantOf(workspace) and h and h.Health > 0 then
					local backpack = player:FindFirstChildOfClass("Backpack")
					if not backpack then
						backpack = player:WaitForChild("Backpack", 0.5) :: Backpack?
						-- Validación estricta post-yield si WaitForChild cedió el hilo
							if self._playerLocks[player] ~= lockData or not currentCharacter() or not c:IsDescendantOf(workspace) then
							return
						end
					end

					local t = lockData.currentTool

					-- Si backpack está disponible, devolver herramientas ajenas preservadas en Player
					if backpack then
						for _, child in ipairs(player:GetChildren()) do
							if child:IsA("Tool") and child ~= t then
								if not self:IsSlapTool(child) then
									child.Parent = backpack
								else
									child:Destroy()
								end
							end
						end
					end

					-- 1. Desalojar cualquier herramienta ajena del Character hacia el Backpack
					for _, item in ipairs(c:GetChildren()) do
						if item:IsA("Tool") and item ~= t then
							if backpack then
								item.Parent = backpack
							else
								-- Conservar la herramienta ajena sin destruirla; alojarla en Player temporalmente
								if self:IsSlapTool(item) then
									item:Destroy()
								else
									pcall(function()
										item.Parent = player
									end)
								end
							end
						end
					end

					-- 2. Asegurar que el Slap esté equipado en la mano
					if t and t.Parent == backpack then
						pcall(function()
							h:EquipTool(t)
						end)
					elseif not t or not t:IsDescendantOf(player) or not self:IsSlapTool(t) then
						-- Si el Slap no existe o fue destruido, regenerar y equipar
						local newTool = self:GiveSlap(player, lockData.slapName)
						lockData.currentTool = newTool
						if newTool then
							pcall(function()
								h:EquipTool(newTool)
							end)
						end
					elseif t.Parent ~= c then
						pcall(function()
							h:EquipTool(t)
						end)
					end
				end
			end)

			-- Garantizar que isEnforcing se restablezca siempre
			lockData.isEnforcing = false

			if not success and err then
				warn(string.format("[SlapService] Error durante enforceEquipped para '%s': %s", player.Name, tostring(err)))
			end
		end)
	end

	local function bindCharacter(char: Model)
		for _, c in ipairs(lockData.charConnections) do
			if c.Connected then c:Disconnect() end
		end
		table.clear(lockData.charConnections)

		local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
		-- Validación estricta post-yield: si la partida terminó o el personaje/jugador ya no es válido, salir sin entregar Slap
		if not hum or self._playerLocks[player] ~= lockData or not char.Parent or not char:IsDescendantOf(workspace) or not player:IsDescendantOf(Players) then
			return
		end

		-- Entregar y equipar Slap en este character
		local tool = self:GiveSlap(player, lockData.slapName)
		lockData.currentTool = tool
		if tool and hum.Health > 0 and char:IsDescendantOf(workspace) then
			pcall(function()
				hum:EquipTool(tool)
			end)
		end

		-- Escuchar cuando el Slap u otra cosa sale del Character (e.g. unequip)
		local charRemovedConn = char.ChildRemoved:Connect(function(child: Instance)
			if child:IsA("Tool") and self._playerLocks[player] == lockData then
				enforceEquipped()
			end
		end)
		table.insert(lockData.charConnections, charRemovedConn)

		-- Escuchar cuando otra herramienta es equipada en el Character
		local charAddedConn = char.ChildAdded:Connect(function(child: Instance)
			if child:IsA("Tool") and child ~= lockData.currentTool and self._playerLocks[player] == lockData then
				enforceEquipped()
			end
		end)
		table.insert(lockData.charConnections, charAddedConn)

		-- Escuchar cuando una herramienta entra al Backpack (cuando el cliente la desequipa)
		local backpack = player:FindFirstChildOfClass("Backpack")
		if backpack then
			local bpConn = backpack.ChildAdded:Connect(function(child: Instance)
				if child:IsA("Tool") and self._playerLocks[player] == lockData then
					enforceEquipped()
				end
			end)
			table.insert(lockData.charConnections, bpConn)
		end
	end

	-- Escuchar si el personaje muere y reaparece (respawn durante partida)
	local charAddedConn = player.CharacterAdded:Connect(function(newChar: Model)
		if self._playerLocks[player] == lockData then
			bindCharacter(newChar)
		end
	end)
	table.insert(lockData.playerConnections, charAddedConn)

	-- Si el personaje ya existe actualmente en Workspace
	if player.Character and player.Character.Parent and player.Character:IsDescendantOf(workspace) then
		bindCharacter(player.Character)
	end
end

-- Desbloquea el equipamiento del jugador y limpia todas las conexiones
function SlapService:UnlockPlayer(player: Player)
	local lockData = self._playerLocks[player]
	if lockData then
		for _, c in ipairs(lockData.playerConnections) do
			if c.Connected then c:Disconnect() end
		end
		for _, c in ipairs(lockData.charConnections) do
			if c.Connected then c:Disconnect() end
		end
		self._playerLocks[player] = nil
	end
end

function SlapService:IsPlayerLocked(player: Player): boolean
	return self._playerLocks[player] ~= nil
end

-- Entrega y bloquea los Slaps a todos los contendientes de una partida
function SlapService:EquipMatchPlayers(session: MatchSession, slapName: string?)
	if not session then return end

	local participants: { Player } = {}
	if session.RedTeam and #session.RedTeam > 0 then
		for _, p in ipairs(session.RedTeam) do table.insert(participants, p) end
	elseif session.RedPlayer then
		table.insert(participants, session.RedPlayer)
	end
	if session.BlueTeam and #session.BlueTeam > 0 then
		for _, p in ipairs(session.BlueTeam) do table.insert(participants, p) end
	elseif session.BluePlayer then
		table.insert(participants, session.BluePlayer)
	end

	for _, player in ipairs(participants) do
		self:LockAndEquipPlayer(player, slapName)
	end
end

-- Retira el bloqueo y los Slaps de todos los contendientes de una partida
function SlapService:RemoveMatchPlayers(session: MatchSession)
	if not session then return end

	local participants: { Player } = {}
	if session.RedTeam and #session.RedTeam > 0 then
		for _, p in ipairs(session.RedTeam) do table.insert(participants, p) end
	elseif session.RedPlayer then
		table.insert(participants, session.RedPlayer)
	end
	if session.BlueTeam and #session.BlueTeam > 0 then
		for _, p in ipairs(session.BlueTeam) do table.insert(participants, p) end
	elseif session.BluePlayer then
		table.insert(participants, session.BluePlayer)
	end

	for _, player in ipairs(participants) do
		self:UnlockPlayer(player)
		self:RemoveSlaps(player)
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

	-- Debe ser un Slap legítimo administrado por SlapService
	if not self:IsSlapTool(tool) then
		return false, 0, 0, "NotAuthorizedSlap"
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
	if not powerVal or not powerVal:IsA("NumberValue") or powerVal.Value <= 0 or powerVal.Value~=powerVal.Value or powerVal.Value==math.huge then
		return false, 0, 0, "InvalidPowerValue"
	end

	local cooldownVal = config:FindFirstChild("SlapCooldown")
	if not cooldownVal or not cooldownVal:IsA("NumberValue") or cooldownVal.Value < 0 or cooldownVal.Value~=cooldownVal.Value or cooldownVal.Value==math.huge then
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

-- Selecciona como máximo un oponente usando exclusivamente el registro
-- autoritativo de la sesión. Prioridad: menor distancia, luego Slot y UserId.
function SlapService:_selectOpponent(
	attacker: Player,
	session: MatchSession,
	attackerRoot: BasePart
): (Player?, BasePart?, Vector3?, string?)
	local roundService = self:_getRoundService()
	if not roundService
		or type(roundService.GetSessionParticipant) ~= "function"
		or type(roundService.GetSessionForPlayer) ~= "function"
		or type(roundService.GetSessionById) ~= "function"
		or type(roundService.IsSessionActive) ~= "function"
		or roundService:GetSessionById(session.Id) ~= session
		or not roundService:IsSessionActive(session.Id)
		or session.State ~= Constants.RoundState.Playing
		or session.Closing or session.Cancelled or session.Closed then
		return nil, nil, nil, "SessionNotCombatReady"
	end

	local attackerParticipant = roundService:GetSessionParticipant(session.Id, attacker)
	if not attackerParticipant then return nil, nil, nil, "AttackerNotParticipant" end

	local selected: Player? = nil
	local selectedRoot: BasePart? = nil
	local selectedDiff: Vector3? = nil
	local selectedDistance = math.huge
	local selectedSlot = math.huge
	local selectedUserId = math.huge
	local firstRejection: string? = nil
	local forwardDir = attackerRoot.CFrame.LookVector

	for _, rosterParticipant in ipairs(session.Participants) do
		if rosterParticipant.Team == attackerParticipant.Team
			or rosterParticipant.State == "Left"
			or rosterParticipant.State == "Released" then
			continue
		end

		local candidate = rosterParticipant.Player
		if not isPlayer(candidate) or candidate == attacker or candidate.Parent ~= Players then
			firstRejection = firstRejection or "InvalidOpponent"
			continue
		end
		if roundService:GetSessionForPlayer(candidate) ~= session
			or roundService:GetSessionParticipant(session.Id, candidate) ~= rosterParticipant then
			firstRejection = firstRejection or "DifferentMatch"
			continue
		end

		local character = candidate.Character
			if character and character:GetAttribute("ArenaRespawnPending") then
				firstRejection = firstRejection or "VictimRespawning"
				continue
			end
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not character or not character:IsDescendantOf(workspace) or not root then
			firstRejection = firstRejection or "VictimNotSpawned"
			continue
		end
		if not humanoid or humanoid.Health <= 0 then
			firstRejection = firstRejection or "VictimNotAlive"
			continue
		end

		local diff = root.Position - attackerRoot.Position
		local distance = diff.Magnitude
		if distance > MAX_SLAP_REACH then
			firstRejection = firstRejection or "OutOfReach"
			continue
		end
		local direction = if distance > 0.05 then diff.Unit else forwardDir
		if forwardDir:Dot(direction) < MIN_FACING_DOT then
			firstRejection = firstRejection or "TargetBehindAttacker"
			continue
		end

		local slot = rosterParticipant.Slot
		local userId = rosterParticipant.UserId
		if distance < selectedDistance
			or (distance == selectedDistance and slot < selectedSlot)
			or (distance == selectedDistance and slot == selectedSlot and userId < selectedUserId) then
			selected = candidate
			selectedRoot = root
			selectedDiff = diff
			selectedDistance = distance
			selectedSlot = slot
			selectedUserId = userId
		end
	end

	return selected, selectedRoot, selectedDiff, if selected then nil else (firstRejection or "NoValidOpponent")
end

-- Ejecuta la resolucion autoritativa del golpe
function SlapService:ProcessSlap(attacker: Player, tool: Tool): (boolean, string?)
	-- 1. Validar que el atacante sea un Player valido
	if not isPlayer(attacker) or not attacker.Parent then
		return false, "InvalidAttacker"
	end

	local attackerChar = attacker.Character
	if attackerChar and attackerChar:GetAttribute("ArenaRespawnPending") then return false, "AttackerRespawning" end
	if not attackerChar or not attackerChar:IsDescendantOf(workspace) then
		return false, "AttackerCharNotSpawned"
	end

	local attackerHumanoid = attackerChar:FindFirstChildOfClass("Humanoid")
	local attackerRoot = attackerChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not attackerHumanoid or attackerHumanoid.Health <= 0 or not attackerRoot then
		return false, "AttackerNotAlive"
	end

	if attackerHumanoid.PlatformStand then return false,"AttackerKnockedDown" end

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

	if session.State ~= Constants.RoundState.Playing or not roundService:IsGameplayRoundOpen(session) then
		return false, "MatchNotPlaying"
	end

	-- 4. Validar cooldown del servidor
	local now = os.clock()
	local nextAllowed = self._cooldowns[attacker] or 0
	if now < nextAllowed then
		return false, "OnCooldown"
	end
	self._cooldowns[attacker] = math.huge -- In-flight swing; no new activation can overlap its window.

	local combo=Config.Combat.SlapCombo
 local roundId=session.GameplayRound.Id
 local generation=attackerChar:GetAttribute("ArenaPhysicsGeneration") or 0
 local swingDeadline=now+(if combo.Enabled then combo.SwingWindow else 0)
 local opponent: Player?=nil
 local victimRoot: BasePart?=nil
 local diff: Vector3?=nil
 local targetReason: string?=nil
 repeat
  if attacker.Character~=attackerChar or attacker.Parent~=Players or tool.Parent~=attackerChar
   or (attackerChar:GetAttribute("ArenaPhysicsGeneration") or 0)~=generation
   or not roundService:IsGameplayRoundOpen(session) or session.GameplayRound.Id~=roundId then
   self._cooldowns[attacker]=nil;return false,"SwingInvalidated"
  end
  opponent,victimRoot,diff,targetReason=self:_selectOpponent(attacker,session,attackerRoot)
  if opponent then break end
  if os.clock()>=swingDeadline then break end
  task.wait(math.min(combo.SampleInterval,math.max(0,swingDeadline-os.clock())))
 until false
 if not opponent or not victimRoot or not diff then
  self._cooldowns[attacker]=os.clock()+(if combo.Enabled then combo.MissRecovery else cooldown)
  return false,targetReason or "NoValidOpponent"
 end
	self._cooldowns[attacker]=os.clock()+(if combo.Enabled then combo.MissRecovery else cooldown)
	local victimChar = opponent.Character :: Model
	local forwardDir = attackerRoot.CFrame.LookVector

	-- 7. Registrar impacto autoritativo en CombatService
	local combatService = self:_getCombatService()
	if not combatService then
		return false, "CombatServiceUnavailable"
	end

	local hitSuccess, hitReason, receivedHits = combatService:RegisterHit(attacker, opponent, session.Id)
	if not hitSuccess then
		return false, hitReason or "CombatServiceRejected"
	end

	self._cooldowns[attacker]=os.clock()+(if Config.Combat.SlapCombo.Enabled then Config.Combat.SlapCombo.SuccessfulHitRecovery else cooldown)

	-- 8. Reproducir feedback sonoro de impacto
	local hand = tool:FindFirstChild("Hand")
	local hitSound = hand and hand:FindFirstChild("Hit") :: Sound?
	if hitSound and hitSound:IsA("Sound") then
		pcall(function()
			hitSound:Play()
		end)
	end

	if (receivedHits or 0)>=Config.Combat.SlapElimination.HitsToEliminate then
  local elimination=self._context and self._context:GetService("EliminationService")
  if elimination then elimination:HandleSlapThreshold(opponent,session,attacker) end
  return true,nil
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

		ragdollService:ApplyRagdoll(victimChar, Config.Combat.DefaultSlapKnockdownDuration, launchVelocity)
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
	self._swingSequence = {}
	self:_ensureRemotes()
end

function SlapService:Start(context: any)
	self._context = context

	-- Escuchar activacion remota desde el cliente
	if self._performSlapRemote then
		local conn = self._performSlapRemote.OnServerEvent:Connect(function(player: Player, tool: any)
			local requestCharacter=player.Character
   local requestGeneration=requestCharacter and requestCharacter:GetAttribute("ArenaPhysicsGeneration") or 0
   self._swingSequence[player]=(self._swingSequence[player] or 0)+1
   local sequence=self._swingSequence[player]
   local ok,hit,reason=pcall(self.ProcessSlap,self,player,tool)
   if not ok then self._cooldowns[player]=nil;warn("[SlapService] Swing error: "..tostring(hit));reason="InternalError" end
   local ready=self._cooldowns[player] or os.clock()
   if ready==math.huge then ready=os.clock()+0.05 end
   local rounds=self:_getRoundService()
   local session=rounds and rounds:GetSessionForPlayer(player)
   if player.Parent==Players and self._slapFeedbackRemote then
    self._slapFeedbackRemote:FireClient(player,{Sequence=sequence,Character=requestCharacter,Generation=requestGeneration,
     SessionId=session and session.Id,RoundId=session and session.GameplayRound and session.GameplayRound.Id,
     Hit=ok and hit==true,Reason=reason,ReadyAt=workspace:GetServerTimeNow()+math.max(0,ready-os.clock())})
   end
		end)
		table.insert(self._connections, conn)
	end

	-- Limpieza de cooldowns y bloqueos cuando un jugador se desconecta
	local leaveConn = Players.PlayerRemoving:Connect(function(player: Player)
		self._cooldowns[player] = nil
		self._swingSequence[player] = nil
		self:UnlockPlayer(player)
	end)
	table.insert(self._connections, leaveConn)

	print("[SlapService] Servicio centralizado de Slaps iniciado y listo")
end

return SlapService
