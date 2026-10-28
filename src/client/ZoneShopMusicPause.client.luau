-- ZoneShopMusicPause (LocalScript, StarterPlayer.StarterPlayerScripts)
-- Pausa la musica del lobby usando la API publica de MusicController
-- (Suspend / Resume) cuando el jugador entra en
-- Workspace.ZoneShopMusic.DetectPauseMusicLobby, y la reanuda al salir.
-- No modifica el volumen de ningun Sound directamente: MusicController
-- es el dueno del mixer y aplica el fade a 0 por su cuenta.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- MusicController es un ModuleScript singleton: ClientBootstrap ya lo requiere,
-- asi que este require devuelve la MISMA tabla con el estado compartido.
local controllersFolder = script.Parent:WaitForChild("Controllers", 20)
local musicModule = controllersFolder and controllersFolder:WaitForChild("MusicController", 15)
local MusicController = musicModule and require(musicModule)

-- Zona de deteccion (puede tardar en cargar si el juego usa StreamingEnabled).
local zoneModel = workspace:WaitForChild("ZoneShopMusic", 60)
local zonePart = zoneModel and zoneModel:WaitForChild("DetectPauseMusicLobby", 60)

local SUSPEND_REASON = "ZoneShopMusic"
local ENTER_FADE = 0.8
local EXIT_FADE = 0.8
local CHECK_INTERVAL = 0.1

local suspensionToken = nil

local function getRootPart()
	local character = player.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function isInsideZone()
	local part = zonePart
	if not part or not part.Parent then
		return false
	end
	local root = getRootPart()
	if not root then
		return false
	end

	local localPos = part.CFrame:PointToObjectSpace(root.Position)
	local half = part.Size * 0.5
	return math.abs(localPos.X) <= half.X
		and math.abs(localPos.Y) <= half.Y
		and math.abs(localPos.Z) <= half.Z
end

local function suspendLobbyMusic()
	if suspensionToken ~= nil then
		return
	end
	suspensionToken = MusicController:Suspend(SUSPEND_REASON, ENTER_FADE)
end

local function resumeLobbyMusic()
	if suspensionToken == nil then
		return
	end
	MusicController:Resume(SUSPEND_REASON, suspensionToken, EXIT_FADE)
	suspensionToken = nil
end

-- Chequeo periodico por bounds: cubre entrar, salir, morir y respawnear sin
-- depender de Touched/TouchEnded (poco fiables con partes no colisionables).
local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < CHECK_INTERVAL then
		return
	end
	accumulator = 0

	if isInsideZone() then
		suspendLobbyMusic()
	else
		resumeLobbyMusic()
	end
end)
