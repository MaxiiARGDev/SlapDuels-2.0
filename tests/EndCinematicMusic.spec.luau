--!strict
-- tests/EndCinematicMusic.spec.luau
-- Pruebas de integración y aislamiento para MusicController y EndCinematic V1.3.1.
-- Valida la suspensión temporal por jugador, prioridad de audio cinematográfico,
-- desvanecimiento, protección contra callbacks antiguos y retorno individual al lobby.

return function(services: {
	MusicController: any,
	EndCinematicConfig: any,
})
	local Music = services.MusicController
	local Config = services.EndCinematicConfig

	local passed = {}
	local function check(name: string, condition: boolean)
		assert(condition, name)
		table.insert(passed, name)
	end

	-- Fixture mock de Sound
	local function createMockSound(name: string, baseVolume: number?): any
		local s = Instance.new("Sound")
		s.Name = name
		s.Volume = baseVolume or 0.5
		return s
	end

	local lobbySound = createMockSound("Lobby", 0.5)
	local arenaSound = createMockSound("Default", 0.6)
	local mmSound = createMockSound("Matchmaking", 0.4)

	local controller = setmetatable({
		_musicEnabled = true,
		_userMusicVolume = 1.0,
		_currentState = "None",
		_currentMapName = nil,
		_currentSound = nil,
		_baseVolumes = {
			[lobbySound] = 0.5,
			[arenaSound] = 0.6,
			[mmSound] = 0.4,
		},
		_activeTweens = {},
		_transitionToken = 0,
		_suspensions = {},
		_suspensionTokenCounter = 0,
		_pendingMusicState = nil,
		_context = nil,
	}, { __index = Music })

	-- Mock de búsqueda de sonidos
	controller._getSoundInstance = function(_self, name: string)
		if name == "Lobby" then return lobbySound end
		if name == "Matchmaking" then return mmSound end
		return nil
	end
	controller._getArenaSound = function(_self, _map: string)
		return arenaSound
	end
	controller._getAllManagedSounds = function(_self)
		return { lobbySound, arenaSound, mmSound }
	end

	-- 1. Estado inicial
	check("initial state is not suspended", not controller:IsSuspended())

	-- 2. Reproducir música de Arena (simula partida en curso)
	controller:PlayArena("Default", 0)
	check("arena music is current sound", controller:GetCurrentSound() == arenaSound)
	check("arena state is active", controller:GetCurrentState() == "Arena")

	-- 3. Quinto punto: Suspensión por EndCinematic con FadeOut
	local fadeOut = (Config.Music and Config.Music.FadeOutDuration) or 0.4
	local token1 = controller:Suspend("EndCinematic", fadeOut)
	check("is suspended after EndCinematic call", controller:IsSuspended())
	check("is suspended for EndCinematic reason", controller:IsSuspended("EndCinematic"))
	check("current sound is stopped and cleared", controller:GetCurrentSound() == nil)
	check("current state is None during suspension", controller:GetCurrentState() == "None")

	-- 4. Llamadas tardías de PlayLobby / PlayArena durante suspensión NO deben activar sonido
	controller:PlayLobby(0)
	check("PlayLobby while suspended does not start sound", controller:GetCurrentSound() == nil)
	check("PlayLobby is queued in pending state", controller._pendingMusicState ~= nil and controller._pendingMusicState.State == "Lobby")

	controller:PlayArena("Default", 0)
	check("PlayArena while suspended does not start sound", controller:GetCurrentSound() == nil)
	check("PlayArena is queued in pending state", controller._pendingMusicState ~= nil and controller._pendingMusicState.State == "Arena")

	-- 5. Stale token no libera la suspensión
	local wrongResume = controller:Resume("EndCinematic", token1 + 999)
	check("stale token cannot resume suspension", wrongResume == false and controller:IsSuspended("EndCinematic"))

	-- 6. Re-suspensión consecutiva con la misma razón actualiza token sin acumular
	local token2 = controller:Suspend("EndCinematic", fadeOut)
	check("token incremented on re-suspend", token2 > token1)
	local activeCount = 0
	for _ in pairs(controller._suspensions) do activeCount += 1 end
	check("single suspension entry maintained per reason", activeCount == 1)

	-- 7. Simular llamada a PlayLobby cuando server envía ReturningToLobby
	controller:PlayLobby(0.6)
	check("music stays silent during ReturningToLobby broadcast", controller:GetCurrentSound() == nil)

	-- 8. Retorno confirmado del jugador: Resume con token válido
	local fadeIn = (Config.Music and Config.Music.FadeInDuration) or 0.6
	local resumeOk = controller:Resume("EndCinematic", token2, fadeIn)
	check("valid token successfully resumes", resumeOk == true and not controller:IsSuspended())
	check("lobby music restored after resume", controller:GetCurrentSound() == lobbySound and controller:GetCurrentState() == "Lobby")

	-- 9. Preferencia MusicEnabled = false se respeta estrictamente
	controller:SetMusicEnabled(false, 0)
	check("music disabled preference recorded", not controller:IsMusicEnabled())

	local tokenDisabled = controller:Suspend("EndCinematic", fadeOut)
	controller:PlayLobby(0)
	controller:Resume("EndCinematic", tokenDisabled, fadeIn)
	check("music remains silent when MusicEnabled is false", controller:GetCurrentSound() ~= nil and controller:GetCurrentSound().Volume == 0)
	check("musicEnabled was not forcefully overridden", not controller:IsMusicEnabled())

	-- Restaurar preferencia para siguientes tests
	controller:SetMusicEnabled(true, 0)

	-- 10. Preview en Studio: suspende y restaura contexto previo (Lobby)
	controller:PlayLobby(0)
	check("pre-preview sound is Lobby", controller:GetCurrentSound() == lobbySound)

	local previewToken1 = controller:Suspend("EndCinematicPreview", fadeOut)
	check("preview suspends music", controller:IsSuspended("EndCinematicPreview"))
	check("sound cleared during preview", controller:GetCurrentSound() == nil)

	-- Dos previews consecutivas en Studio
	local previewToken2 = controller:Suspend("EndCinematicPreview", fadeOut)
	check("preview 1 stale token cannot resume preview 2", not controller:Resume("EndCinematicPreview", previewToken1))
	check("preview 2 remains suspended", controller:IsSuspended("EndCinematicPreview"))

	controller:Resume("EndCinematicPreview", previewToken2, fadeIn)
	check("preview 2 resume restores previous Lobby track", controller:GetCurrentSound() == lobbySound and controller:GetCurrentState() == "Lobby")

	-- 11. Limpieza de instancias mock
	lobbySound:Destroy()
	arenaSound:Destroy()
	mmSound:Destroy()

	return {
		Passed = #passed,
		Assertions = passed,
		Success = true,
	}
end
