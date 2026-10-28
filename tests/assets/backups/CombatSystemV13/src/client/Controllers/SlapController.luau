--!strict
-- SlapController
-- Controlador cliente de Slaps.
-- Responsabilidad exclusiva:
-- 1. Detectar cuando el jugador equipa un Slap (Tool con Configuration.Power).
-- 2. Conectar al evento Tool.Activated.
-- 3. Reproducir localmente la animacion de golpe (Swing) para retroalimentacion visual instantanea.
-- 4. Solicitar la ejecucion autoritativa al servidor via ReplicatedStorage.Remotes.Combat.PerformSlap.
-- 5. Manejar un debounce local liviano para evitar saturar la red con clics repetidos.
-- NO calcula daño, distancia autoritativa, knockback ni fisica.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer

local SlapController = {}
SlapController.Name = "SlapController"

SlapController._context = nil :: any
SlapController._performSlapRemote = nil :: RemoteEvent?
SlapController._equippedTool = nil :: Tool?
SlapController._activatedConn = nil :: RBXScriptConnection?
SlapController._swingTrack = nil :: AnimationTrack?
SlapController._localNextSlapTime = 0
SlapController._awaitingUntil = 0
SlapController._lastSequence = 0

--------------------------------------------------------------------------------
-- Remotes
--------------------------------------------------------------------------------

function SlapController:_getPerformRemote(): RemoteEvent?
	if self._performSlapRemote then return self._performSlapRemote end

	local remotes = ReplicatedStorage:WaitForChild("Remotes", 5) :: Folder?
	local combat = remotes and remotes:WaitForChild("Combat", 5) :: Folder?
	local remote = combat and combat:WaitForChild("PerformSlap", 5) :: RemoteEvent?
	if remote and remote:IsA("RemoteEvent") then
		self._performSlapRemote = remote
		return remote
	end
	return nil
end

--------------------------------------------------------------------------------
-- Animaciones y Ciclo del Tool
--------------------------------------------------------------------------------

local function isSlapTool(tool: Instance): boolean
	if not tool:IsA("Tool") then return false end
	local config = tool:FindFirstChild("Configuration")
	if config and config:FindFirstChild("Power") then
		return true
	end
	return false
end

function SlapController:_onToolEquipped(tool: Tool)
	if not isSlapTool(tool) then return end

	self:_onToolUnequipped()
	self._equippedTool = tool

	-- Preparar animacion de swing si existe
	local swingAnim = tool:FindFirstChild("Swing") :: Animation?
	local char = localPlayer.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")

	if swingAnim and swingAnim:IsA("Animation") and animator then
		local ok, track = pcall(function()
			return animator:LoadAnimation(swingAnim)
		end)
		if ok and track then
			track.Priority = Enum.AnimationPriority.Action
			self._swingTrack = track
		end
	end

	-- Conectar activacion del Tool
	self._activatedConn = tool.Activated:Connect(function()
		self:_onToolActivated(tool)
	end)
end

function SlapController:_onToolUnequipped()
	if self._activatedConn then
		self._activatedConn:Disconnect()
		self._activatedConn = nil
	end

	if self._swingTrack then
		pcall(function()
			self._swingTrack:Stop(0.1)
		end)
		self._swingTrack = nil
	end

	self._equippedTool = nil
	self._localNextSlapTime=0;self._awaitingUntil=0
end

function SlapController:_onToolActivated(tool: Tool)
	local now = workspace:GetServerTimeNow()
	if now < self._localNextSlapTime or now < self._awaitingUntil then
		return
	end

	-- Await authoritative hit/miss recovery; timeout only permits a retry, never authorizes a hit.
	self._awaitingUntil=now+2

	-- 1. Feedback visual instantaneo: Reproducir animacion de swing
	if self._swingTrack then
		pcall(function()
			self._swingTrack:Play(0.05, 1, 1.2)
		end)
	end

	-- 2. Solicitar al servidor la validacion y ejecucion del golpe
	local remote = self:_getPerformRemote()
	if remote then
		remote:FireServer(tool)
	end
end

--------------------------------------------------------------------------------
-- Enlace de Personaje
--------------------------------------------------------------------------------

function SlapController:_bindCharacter(character: Model)
	self:_onToolUnequipped()

	-- Detectar herramientas equipadas
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			self:_onToolEquipped(child)
		end
	end)

	character.ChildRemoved:Connect(function(child)
		if child == self._equippedTool then
			self:_onToolUnequipped()
		end
	end)

	-- Si ya tenia una herramienta equipada al iniciar
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			self:_onToolEquipped(child)
			break
		end
	end
end

--------------------------------------------------------------------------------
-- Ciclo de Vida Bootstrap
--------------------------------------------------------------------------------

function SlapController:Init(context: any)
	self._context = context
	self:_getPerformRemote()
 local combat=ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Combat")
 local feedback=combat:WaitForChild("SlapFeedback",10)
 if feedback and feedback:IsA("RemoteEvent") then
  feedback.OnClientEvent:Connect(function(data)
   local character=localPlayer.Character
   if type(data)~="table" or data.Character~=character or not character
    or data.SessionId~=localPlayer:GetAttribute("MatchId")
    or data.Generation~=(character:GetAttribute("ArenaPhysicsGeneration") or 0)
    or type(data.Sequence)~="number" or data.Sequence<=self._lastSequence
    or type(data.ReadyAt)~="number" then return end
   self._lastSequence=data.Sequence;self._awaitingUntil=0;self._localNextSlapTime=data.ReadyAt
  end)
 end
end

function SlapController:Start(context: any)
	self._context = context

	if localPlayer.Character then
		self:_bindCharacter(localPlayer.Character)
	end

	localPlayer.CharacterAdded:Connect(function(char)
		self:_bindCharacter(char)
	end)

	print("[SlapController] Controlador de Slaps iniciado y listo")
end

return SlapController
