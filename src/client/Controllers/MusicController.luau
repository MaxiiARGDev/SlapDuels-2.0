--!strict
-- MusicController
-- Controlador centralizado y exclusivo de la música de fondo LOCAL del jugador.
-- La música es 100% cliente, no replicada, y completamente independiente de los SFX, UI y Combat Sounds.

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Config = require(game.ReplicatedStorage.Shared.Config)
local Players = game:GetService("Players")

export type MusicState = "None" | "Lobby" | "Matchmaking" | "Arena" | "SuddenDeath" | "Victory" | "Defeat" | "Draw"

local MusicController = {}
MusicController.Name = "MusicController"

-- Configuración de Usuario (Local)
MusicController._musicEnabled = true
MusicController._userMusicVolume = 1.0

-- Estado de Reproducción
MusicController._suddenDeathActive = false
MusicController._currentState = "None" :: MusicState
MusicController._currentMapName = nil :: string?
MusicController._currentSound = nil :: Sound?
MusicController._baseVolumes = {} :: { [Sound]: number }
MusicController._activeTweens = {} :: { [Sound]: Tween }
MusicController._transitionToken = 0
MusicController._context = nil :: any

-- Suspensiones Locales de Música
MusicController._suspensions = {} :: { [string]: { Token: number, PreviousState: MusicState, PreviousMap: string?, PreviousSound: Sound? } }
MusicController._suspensionTokenCounter = 0
MusicController._pendingMusicState = nil :: { State: MusicState, MapName: string?, FadeDuration: number? }?

-- Parámetros de Fade
local DEFAULT_FADE_DURATION = 0.8
local FADE_EASING_STYLE = Enum.EasingStyle.Quad
local FADE_EASING_DIR = Enum.EasingDirection.Out

--------------------------------------------------------------------------------
-- Helpers Internos de Jerarquía en SoundService
--------------------------------------------------------------------------------

function MusicController:_getMusicFolder(): Folder?
	local musicFolder = SoundService:FindFirstChild("Music")
	if musicFolder and musicFolder:IsA("Folder") then
		return musicFolder
	end
	return nil
end

function MusicController:_getArenasFolder(): Folder?
	local musicFolder = self:_getMusicFolder()
	if not musicFolder then return nil end
	local arenasFolder = musicFolder:FindFirstChild("Arenas")
	if arenasFolder and arenasFolder:IsA("Folder") then
		return arenasFolder
	end
	return nil
end

function MusicController:_registerSound(sound: Instance)
	if sound:IsA("Sound") then
		if self._baseVolumes[sound] == nil then
			-- Almacenar el volumen original de Studio como referencia inmutable
			local baseVol = sound.Volume
			if baseVol <= 0 then
				baseVol = 0.35
			end
			self._baseVolumes[sound] = baseVol
		end
	end
end

function MusicController:_cacheAllSounds()
	local musicFolder = self:_getMusicFolder()
	if not musicFolder then return end

	for _, desc in ipairs(musicFolder:GetDescendants()) do
		self:_registerSound(desc)
	end

	musicFolder.DescendantAdded:Connect(function(desc)
		self:_registerSound(desc)
	end)
end

function MusicController:_getSoundInstance(name: string): Sound?
	local musicFolder = self:_getMusicFolder()
	if not musicFolder then return nil end
	local sound = musicFolder:FindFirstChild(name)
	if sound and sound:IsA("Sound") then
		self:_registerSound(sound)
		return sound
	end
	return nil
end

function MusicController:_getArenaSound(mapName: string): Sound?
	local arenasFolder = self:_getArenasFolder()
	if not arenasFolder then return nil end

	-- 1. Coincidencia exacta con el nombre del mapa
	local sound = arenasFolder:FindFirstChild(mapName)
	if sound and sound:IsA("Sound") then
		self:_registerSound(sound)
		return sound
	end

	-- 2. Fallback opcional a "ArenaDefault" o "Default"
	local fallback = arenasFolder:FindFirstChild("ArenaDefault") or arenasFolder:FindFirstChild("Default")
	if fallback and fallback:IsA("Sound") then
		self:_registerSound(fallback)
		return fallback
	end

	return nil
end

--------------------------------------------------------------------------------
-- Cálculo de Volumen
--------------------------------------------------------------------------------

function MusicController:_getTargetVolume(sound: Sound): number
	if not self._musicEnabled then
		return 0
	end

	local baseVolume = self._baseVolumes[sound] or sound.Volume
	local userVol = math.clamp(self._userMusicVolume, 0, 1)
	return baseVolume * userVol
end

--------------------------------------------------------------------------------
-- Transiciones y Cross-Fade
--------------------------------------------------------------------------------

function MusicController:_cancelTweenForSound(sound: Sound)
	local active = self._activeTweens[sound]
	if active then
		active:Cancel()
		active:Destroy()
		self._activeTweens[sound] = nil
	end
end

function MusicController:_getAllManagedSounds(): { Sound }
	local sounds: { Sound } = {}
	local musicFolder = self:_getMusicFolder()
	if musicFolder then
		for _, desc in ipairs(musicFolder:GetDescendants()) do
			if desc:IsA("Sound") then
				table.insert(sounds, desc)
			end
		end
	end
	return sounds
end

function MusicController:_transitionTo(newSound: Sound?, newState: MusicState, fadeDuration: number?)
	local duration = fadeDuration or DEFAULT_FADE_DURATION

	self._transitionToken += 1
	local thisToken = self._transitionToken

	self._currentState = newState
	self._currentSound = newSound

	-- 1. Fade Out de todos los sonidos activos que NO sean el nuevo sonido
	for _, sound in ipairs(self:_getAllManagedSounds()) do
		if sound ~= newSound then
			self:_cancelTweenForSound(sound)

			if sound.IsPlaying or sound.Volume > 0 then
				if duration > 0 then
					local tweenInfo = TweenInfo.new(duration, FADE_EASING_STYLE, FADE_EASING_DIR)
					local fadeOutTween = TweenService:Create(sound, tweenInfo, { Volume = 0 })
					self._activeTweens[sound] = fadeOutTween

					fadeOutTween.Completed:Connect(function()
						if self._activeTweens[sound] == fadeOutTween then
							self._activeTweens[sound] = nil
						end
						if self._transitionToken == thisToken and sound ~= self._currentSound then
							pcall(function()
								sound:Stop()
							end)
						end
						fadeOutTween:Destroy()
					end)

					fadeOutTween:Play()
				else
					sound.Volume = 0
					pcall(function()
						sound:Stop()
					end)
				end
			end
		end
	end

	-- 2. Fade In del nuevo sonido si existe
	if newSound then
		self:_cancelTweenForSound(newSound)

		local targetVol = self:_getTargetVolume(newSound)

		if self._musicEnabled and targetVol > 0 then
			newSound.Looped = true
			if not newSound.IsPlaying then
				newSound.Volume = 0
				pcall(function()
					newSound:Play()
				end)
			end

			if duration > 0 then
				local tweenInfo = TweenInfo.new(duration, FADE_EASING_STYLE, FADE_EASING_DIR)
				local fadeInTween = TweenService:Create(newSound, tweenInfo, { Volume = targetVol })
				self._activeTweens[newSound] = fadeInTween

				fadeInTween.Completed:Connect(function()
					if self._activeTweens[newSound] == fadeInTween then
						self._activeTweens[newSound] = nil
					end
					fadeInTween:Destroy()
				end)

				fadeInTween:Play()
			else
				newSound.Volume = targetVol
			end
		else
			-- Música deshabilitada o target volume = 0
			newSound.Volume = 0
			if newSound.IsPlaying then
				pcall(function()
					newSound:Stop()
				end)
			end
		end
	end
end

--------------------------------------------------------------------------------
-- API Pública
--------------------------------------------------------------------------------
-- API Pública y Gestión de Suspensión
--------------------------------------------------------------------------------

function MusicController:_getMatchController()
	if self._context and typeof(self._context.GetController) == "function" then
		return self._context:GetController("MatchController")
	end
	local controllers = script.Parent
	local matchScript = controllers and controllers:FindFirstChild("MatchController")
	if matchScript and matchScript:IsA("ModuleScript") then
		local ok, mod = pcall(require, matchScript)
		if ok then return mod end
	end
	return nil
end

function MusicController:_getMatchmakingController()
	if self._context and typeof(self._context.GetController) == "function" then
		return self._context:GetController("MatchmakingController")
	end
	local controllers = script.Parent
	local mmScript = controllers and controllers:FindFirstChild("MatchmakingController")
	if mmScript and mmScript:IsA("ModuleScript") then
		local ok, mod = pcall(require, mmScript)
		if ok then return mod end
	end
	return nil
end

function MusicController:IsSuspended(reason: string?): boolean
	if reason then
		return self._suspensions[reason] ~= nil
	end
	for _ in pairs(self._suspensions) do
		return true
	end
	return false
end

function MusicController:Suspend(reason: string?, fadeDuration: number?): number
	local r = reason or "Default"
	self._suspensionTokenCounter += 1
	local token = self._suspensionTokenCounter

	local record = self._suspensions[r]
	if not record then
		self._suspensions[r] = {
			Token = token,
			PreviousState = self._currentState,
			PreviousMap = self._currentMapName,
			PreviousSound = self._currentSound,
		}
	else
		record.Token = token
	end

	local duration = if fadeDuration ~= nil then fadeDuration else 0.4
	self:_transitionTo(nil, "None", duration)
	print(string.format("[MusicController] Música suspendida por '%s' (Token=%d, Fade=%.2fs)", r, token, duration))
	return token
end

function MusicController:Resume(reason: string?, token: number?, restoreFadeDuration: number?): boolean
	local r = reason or "Default"
	local record = self._suspensions[r]
	if not record then
		return false
	end

	if token ~= nil and record.Token ~= token then
		-- Token desactualizado: pertenece a una ejecución anterior ya superada
		return false
	end

	local previousState = record.PreviousState
	local previousMap = record.PreviousMap
	self._suspensions[r] = nil
	print(string.format("[MusicController] Suspensión '%s' liberada", r))

	if self:IsSuspended() then
		return true
	end

	local duration = if restoreFadeDuration ~= nil then restoreFadeDuration else 0.6
	local pending = self._pendingMusicState
	self._pendingMusicState = nil

	if pending and pending.State ~= "None" then
		local pDuration = pending.FadeDuration or duration
		if pending.State == "Lobby" then
			self:PlayLobby(pDuration)
		elseif pending.State == "Matchmaking" then
			self:PlayMatchmaking(pDuration)
		elseif pending.State == "Arena" and pending.MapName then
			self:PlayArena(pending.MapName, pDuration)
		end
	elseif r == "EndCinematicPreview" then
		if previousState == "Lobby" then
			self:PlayLobby(duration)
		elseif previousState == "Matchmaking" then
			self:PlayMatchmaking(duration)
		elseif (previousState == "Arena" or previousState == "SuddenDeath") and previousMap then
			self:PlayArena(previousMap, duration)
		else
			self:Stop(duration)
		end
	else
		local inMatch = false
		local matchController = self:_getMatchController()
		if matchController and typeof(matchController.IsParticipant) == "function" then
			inMatch = matchController:IsParticipant()
		end
		if Players.LocalPlayer and Players.LocalPlayer:GetAttribute("MatchId") ~= nil then
			inMatch = true
		end

		local mmController = self:_getMatchmakingController()
		local inQueue = mmController and typeof(mmController.IsInQueue) == "function" and mmController:IsInQueue()

		if inMatch then
			local selectedMap = matchController and matchController:GetCurrentSelectedMap() or "Default"
			self:PlayArena(selectedMap, duration)
		elseif inQueue then
			self:PlayMatchmaking(duration)
		else
			self:PlayLobby(duration)
		end
	end

	return true
end

-- Shares the existing music mixer, preferences and cinematic suspension priority.
function MusicController:_playSuddenDeath(fadeDuration: number?): boolean
 if self:IsSuspended() then return false end
 local sound=self:_getSoundInstance(Config.SuddenDeathPresentation.MusicSoundName)
 if not sound or sound.SoundId=="" then
  if not self._suddenAudioWarning then warn("[MusicController] Authorized SuddenDeath SoundId missing; arena music retained");self._suddenAudioWarning=true end
  return false
 end
 if self._currentState~="SuddenDeath" or self._currentSound~=sound or not sound.IsPlaying then
  self:_transitionTo(sound,"SuddenDeath",fadeDuration)
 end
 return true
end
function MusicController:SetSuddenDeath(active: boolean,mapName: string?,restoreArena: boolean?)
 self._suddenDeathActive=active
 if mapName then self._currentMapName=mapName end
 if self:IsSuspended() then return end
 if active then
  self:_playSuddenDeath(Config.SuddenDeathPresentation.TransitionDuration)
 elseif restoreArena and self._currentMapName then
  self:PlayArena(self._currentMapName,Config.SuddenDeathPresentation.TransitionDuration)
 end
end

function MusicController:PlayLobby(fadeDuration: number?)
	self._suddenDeathActive=false
	if self:IsSuspended() then
		self._pendingMusicState = { State = "Lobby", MapName = nil, FadeDuration = fadeDuration }
		print("[MusicController] PlayLobby recibido durante suspensión; encolado")
		return
	end

	local lobbySound = self:_getSoundInstance("Lobby")
	if self._currentState == "Lobby" and self._currentSound == lobbySound and lobbySound and lobbySound.IsPlaying then
		return
	end

	self._currentMapName = nil
	self:_transitionTo(lobbySound, "Lobby", fadeDuration)
	print("[MusicController] Reproduciendo música de Lobby")
end

function MusicController:PlayMatchmaking(fadeDuration: number?)
	self._suddenDeathActive=false
	if self:IsSuspended() then
		self._pendingMusicState = { State = "Matchmaking", MapName = nil, FadeDuration = fadeDuration }
		print("[MusicController] PlayMatchmaking recibido durante suspensión; encolado")
		return
	end

	local mmSound = self:_getSoundInstance("Matchmaking")
	if self._currentState == "Matchmaking" and self._currentSound == mmSound and mmSound and mmSound.IsPlaying then
		return
	end

	self._currentMapName = nil
	self:_transitionTo(mmSound, "Matchmaking", fadeDuration)
	print("[MusicController] Reproduciendo música de Matchmaking")
end

function MusicController:PlayArena(mapName: string, fadeDuration: number?)
	if self:IsSuspended() then
		self._pendingMusicState = { State = "Arena", MapName = mapName, FadeDuration = fadeDuration }
		print(string.format("[MusicController] PlayArena(%s) recibido durante suspensión; encolado", mapName))
		return
	end

	self._currentMapName=mapName
	if self._suddenDeathActive and self:_playSuddenDeath(fadeDuration) then return end
	local arenaSound = self:_getArenaSound(mapName)
	if self._currentState == "Arena" and self._currentMapName == mapName and self._currentSound == arenaSound and arenaSound and arenaSound.IsPlaying then
		return
	end

	self._currentMapName = mapName
	if not arenaSound then
		warn(string.format("[MusicController] No se encontro musica para la arena '%s'. Permaneciendo en silencio.", mapName))
		self:_transitionTo(nil, "Arena", fadeDuration)
		return
	end

	self:_transitionTo(arenaSound, "Arena", fadeDuration)
	print(string.format("[MusicController] Reproduciendo música de Arena: %s", mapName))
end

function MusicController:Stop(fadeDuration: number?)
	if self:IsSuspended() then
		self._pendingMusicState = { State = "None", MapName = nil, FadeDuration = fadeDuration }
		return
	end

	self._currentMapName = nil
	self:_transitionTo(nil, "None", fadeDuration)
	print("[MusicController] Música detenida")
end

function MusicController:SetMusicEnabled(enabled: boolean, fadeDuration: number?)
	if self._musicEnabled == enabled then return end
	self._musicEnabled = enabled
	print(string.format("[MusicController] MusicEnabled establecido en %s", tostring(enabled)))

	if self:IsSuspended() then
		return
	end

	local duration = if fadeDuration ~= nil then fadeDuration else 0.4

	if not enabled then
		-- Desvanecer suavemente la pista actual a 0 y pausar
		if self._currentSound and self._currentSound.IsPlaying then
			self:_cancelTweenForSound(self._currentSound)
			if duration > 0 then
				local tweenInfo = TweenInfo.new(duration, FADE_EASING_STYLE, FADE_EASING_DIR)
				local muteTween = TweenService:Create(self._currentSound, tweenInfo, { Volume = 0 })
				self._activeTweens[self._currentSound] = muteTween
				local soundRef = self._currentSound
				muteTween.Completed:Connect(function()
					if self._activeTweens[soundRef] == muteTween then
						self._activeTweens[soundRef] = nil
					end
					if not self._musicEnabled and soundRef then
						soundRef:Stop()
					end
					muteTween:Destroy()
				end)
				muteTween:Play()
			else
				self._currentSound.Volume = 0
				self._currentSound:Stop()
			end
		end
	else
		-- Reanudar o fade in hacia el volumen objetivo
		if self._currentSound then
			local targetVol = self:_getTargetVolume(self._currentSound)
			if targetVol > 0 then
				if not self._currentSound.IsPlaying then
					self._currentSound.Volume = 0
					self._currentSound:Play()
				end
				self:_cancelTweenForSound(self._currentSound)
				if duration > 0 then
					local tweenInfo = TweenInfo.new(duration, FADE_EASING_STYLE, FADE_EASING_DIR)
					local resumeTween = TweenService:Create(self._currentSound, tweenInfo, { Volume = targetVol })
					self._activeTweens[self._currentSound] = resumeTween
					local soundRef = self._currentSound
					resumeTween.Completed:Connect(function()
						if self._activeTweens[soundRef] == resumeTween then
							self._activeTweens[soundRef] = nil
						end
						resumeTween:Destroy()
					end)
					resumeTween:Play()
				else
					self._currentSound.Volume = targetVol
				end
			end
		else
			-- Si no había un track reproduciendo, volver al estado actual
			if self._currentState == "Lobby" then
				self:PlayLobby(duration)
			elseif self._currentState == "Matchmaking" then
				self:PlayMatchmaking(duration)
			elseif self._currentState == "SuddenDeath" then
				self:_playSuddenDeath(duration)
			elseif self._currentState == "Arena" and self._currentMapName then
				self:PlayArena(self._currentMapName, duration)
			end
		end
	end
end

function MusicController:SetMusicVolume(volume: number, fadeDuration: number?)
	local clamped = math.clamp(volume, 0, 1)
	self._userMusicVolume = clamped
	print(string.format("[MusicController] MusicVolume establecido en %.2f", clamped))

	local duration = if fadeDuration ~= nil then fadeDuration else 0.2

	if self._currentSound and self._currentSound.IsPlaying and self._musicEnabled then
		local targetVol = self:_getTargetVolume(self._currentSound)
		self:_cancelTweenForSound(self._currentSound)
		if duration > 0 then
			local tweenInfo = TweenInfo.new(duration, FADE_EASING_STYLE, FADE_EASING_DIR)
			local volTween = TweenService:Create(self._currentSound, tweenInfo, { Volume = targetVol })
			self._activeTweens[self._currentSound] = volTween
			local soundRef = self._currentSound
			volTween.Completed:Connect(function()
				if self._activeTweens[soundRef] == volTween then
					self._activeTweens[soundRef] = nil
				end
				volTween:Destroy()
			end)
			volTween:Play()
		else
			self._currentSound.Volume = targetVol
		end
	end
end

function MusicController:GetCurrentState(): string
	return self._currentState
end

function MusicController:GetCurrentMapName(): string?
	return self._currentMapName
end

function MusicController:IsMusicEnabled(): boolean
	return self._musicEnabled
end

function MusicController:GetMusicVolume(): number
	return self._userMusicVolume
end

function MusicController:GetCurrentSound(): Sound?
	return self._currentSound
end

--------------------------------------------------------------------------------
-- Ciclo de Vida Bootstrap
--------------------------------------------------------------------------------

function MusicController:Init(context: any)
	self._context = context
	self._suspensions = {}
	self._suspensionTokenCounter = 0
	self._pendingMusicState = nil
	self:_cacheAllSounds()
	print("[MusicController] Inicializado exitosamente")
end

function MusicController:Start(context: any)
	self._context = context

	-- Sincronización inicial segura
	local matchController = context and context:GetController("MatchController")
	local mmController = context and context:GetController("MatchmakingController")

	local inMatch = matchController and typeof(matchController.IsParticipant) == "function" and matchController:IsParticipant()
	local inQueue = mmController and typeof(mmController.IsInQueue) == "function" and mmController:IsInQueue()

	if inMatch then
		local selectedMap = matchController:GetCurrentSelectedMap() or "Default"
		self:PlayArena(selectedMap)
	elseif inQueue then
		self:PlayMatchmaking()
	else
		-- Estado predeterminado al entrar al juego
		self:PlayLobby()
	end

	print(string.format("[MusicController] Iniciado en estado: %s", self._currentState))
end

return MusicController
