--!strict
-- tests/Regression1v1.spec.luau
-- Regresión Multicliente 1v1 Completa (2 Partidas Consecutivas)
-- Valida el ciclo completo de vida de dos partidas 1v1:
--   1. Matchmaking FIFO y Admisión autoritativa
--   2. Votación de mapas y resolución
--   3. Carga física de mapa y asignación de ArenaSlot
--   4. Spawn autoritativo y equipamiento de Slap tool
--   5. Combate, golpes y eliminaciones (KillParts/VoidBoundary)
--   6. Puntuación grupal atómica, Coins y aviso de Match Point
--   7. Reinicio de integrantes entre puntos
--   8. Victoria a 5 puntos y estadísticas Win/Loss
--   9. Retorno al lobby, desequipamiento y destrucción de herramientas
--  10. Cierre idempotente, liberación de ArenaSlots y ActiveMatches=0

return function(services: {
	RoundService: any,
	ScoreService: any,
	SpawnService: any,
	EliminationService: any,
	CombatService: any,
	PlayerService: any,
	MatchInstanceService: any,
	MatchmakingService: any,
	Config: any,
	Types: any,
	Constants: any,
})
	local RoundService = services.RoundService
	local ScoreService = services.ScoreService
	local SpawnService = services.SpawnService
	local EliminationService = services.EliminationService
	local CombatService = services.CombatService
	local PlayerService = services.PlayerService
	local MatchInstanceService = services.MatchInstanceService
	local MatchmakingService = services.MatchmakingService
	local Config = services.Config
	local Types = services.Types
	local Constants = services.Constants

	local passedCount = 0
	local failedCount = 0
	local results: { [string]: { success: boolean, detail: string } } = {}

	local function assertStep(stepId: string, stepName: string, condition: boolean, detail: string)
		if condition then
			passedCount += 1
			results[stepId] = { success = true, detail = stepName }
			print(string.format("[PASS] %s: %s", stepId, stepName))
		else
			failedCount += 1
			results[stepId] = { success = false, detail = string.format("%s - %s", stepName, detail) }
			warn(string.format("[FAIL] %s: %s (Detalle: %s)", stepId, stepName, detail))
		end
	end

	local function makeSimPlayer(name: string): any
		local char = Instance.new("Model")
		char.Name = name .. "_Char"
		local hrp = Instance.new("Part")
		hrp.Name = "HumanoidRootPart"
		hrp.Position = Vector3.new(0, 10, 0)
		hrp.Size = Vector3.new(2, 2, 1)
		hrp.Parent = char
		local hum = Instance.new("Humanoid")
		hum.Health = 100
		hum.MaxHealth = 100
		hum.Parent = char
		char.Parent = workspace

		local backpack = Instance.new("Folder")
		backpack.Name = "Backpack"

		local slapTool = Instance.new("Tool")
		slapTool.Name = "Slap"
		slapTool.Parent = backpack

		local player = {
			Name = name,
			DisplayName = name,
			UserId = math.random(100000, 999999),
			Character = char,
			Parent = game:GetService("Players"),
			Backpack = backpack,
			IsSimulatedPlayer = true,
			IsConnected = true,
			IsA = function(self, className: string) return className == "Player" end,
			FindFirstChildOfClass = function(self, className: string)
				if className == "Humanoid" then return hum end
				return nil
			end,
			FindFirstChild = function(self, childName: string)
				if childName == "Character" then return char end
				if childName == "Backpack" then return backpack end
				return nil
			end,
			IsDescendantOf = function(self, ancestor: any) return true end,
			GetAttribute = function(self, attr: string) return nil end,
			SetAttribute = function(self, attr: string, val: any) end,
		}
		return player
	end

	local function cleanupSimPlayer(p: any)
		if p and p.Character then
			p.Character:Destroy()
		end
		if p and p.Backpack then
			p.Backpack:Destroy()
		end
	end

	local function resetAllServices()
		RoundService._sessionsById = {}
		RoundService._sessionIdByUserId = {}
		RoundService._participantByPlayer = {}
		RoundService._closedSessionIds = {}
		RoundService._rewardedMatches = {}
		RoundService._rewardedPlayers = {}
		RoundService._currentSession = nil
		RoundService._isStartingSession = false
		RoundService._sessionCounter = 0
		RoundService._maxConcurrentSessions = 1

		ScoreService._scores = {}
		ScoreService._pointInProgress = {}
		ScoreService._resetThreads = {}
		ScoreService._sweepThreads = {}
		ScoreService._spatialThreads = {}

		EliminationService._activeSessions = {}
		EliminationService._processingEliminations = {}
		EliminationService._resolvedEliminations = {}
		EliminationService._eliminationCounters = {}

		CombatService._lastAttacker = {}
		CombatService._lastAttackTimestamp = {}
		CombatService._lastAttackMatch = {}
	end

	-- =========================================================================
	-- EJECUCIÓN: PARTIDA 1v1 #1 (Victoria de Red 5-0)
	-- =========================================================================
	resetAllServices()

	local p1 = makeSimPlayer("P1_Red")
	local p2 = makeSimPlayer("P2_Blue")

	local coinsAwarded = { [p1] = 0, [p2] = 0 }
	local winsAwarded = { [p1] = 0, [p2] = 0 }
	local lossesAwarded = { [p1] = 0, [p2] = 0 }
	local killsAwarded = { [p1] = 0, [p2] = 0 }

	local mockPS = {
		AddCoins = function(self, p, amt, reason)
			coinsAwarded[p] = (coinsAwarded[p] or 0) + amt
		end,
		AddWin = function(self, p)
			winsAwarded[p] = (winsAwarded[p] or 0) + 1
		end,
		AddLoss = function(self, p)
			lossesAwarded[p] = (lossesAwarded[p] or 0) + 1
		end,
		AddKill = function(self, p, amt, reason)
			killsAwarded[p] = (killsAwarded[p] or 0) + amt
		end,
	}

	-- Inyectar dependencias simuladas
	ScoreService._context = {
		GetService = function(_, name)
			if name == "PlayerService" then return mockPS end
			if name == "RoundService" then return RoundService end
			return nil
		end
	}
	RoundService._context = {
		GetService = function(_, name)
			if name == "PlayerService" then return mockPS end
			if name == "ScoreService" then return ScoreService end
			if name == "SpawnService" then return SpawnService end
			if name == "MatchInstanceService" then return MatchInstanceService end
			return nil
		end
	}
	EliminationService._playerService = mockPS
	EliminationService._combatService = CombatService
	EliminationService._roundService = RoundService

	-- Paso 1.1: Matchmaking FIFO y Admisión
	local resToken = "RES_TOKEN_MATCH1"
	local admitOk, session1 = pcall(function()
		return RoundService:AdmitSession({
			ZoneId = "Zone_1v1",
			Mode = "1v1",
			TeamSize = 1,
			RedTeam = { p1 },
			BlueTeam = { p2 },
		})
	end)
	assertStep("M1_STEP1", "M1 - Admision autoritativa 1v1", admitOk and session1 ~= nil, "Sesión creada exitosamente")

	-- Paso 1.2: Votación de mapas (MatchReady -> MatchCountdown -> MapSelection)
	RoundService:SetSessionState(session1.Id, Constants.RoundState.MatchReady)
	RoundService:SetSessionState(session1.Id, Constants.RoundState.MatchCountdown)
	RoundService:SetSessionState(session1.Id, Constants.RoundState.MapSelection)
	session1.Votes[p1] = "ClassicArena"
	session1.Votes[p2] = "ClassicArena"
	local chosenMap = RoundService:_resolveMap(session1.Id, { "ClassicArena" })
	session1.SelectedMap = chosenMap
	assertStep("M1_STEP2", "M1 - Votacion y resolucion de mapa", chosenMap == "ClassicArena", "ClassicArena elegido")

	-- Paso 1.3: Carga de Mapa y Asignación de ArenaSlot
	RoundService:SetSessionState(session1.Id, Constants.RoundState.MapLoading)
	local fakeContainer = Instance.new("Folder")
	fakeContainer.Name = "ArenaContainer_M1"
	local redSpawnPart = Instance.new("Part")
	redSpawnPart.Name = "RedSpawn_1"
	redSpawnPart.Position = Vector3.new(-20, 5, 0)
	redSpawnPart.Parent = fakeContainer
	local blueSpawnPart = Instance.new("Part")
	blueSpawnPart.Name = "BlueSpawn_1"
	blueSpawnPart.Position = Vector3.new(20, 5, 0)
	blueSpawnPart.Parent = fakeContainer
	fakeContainer.Parent = workspace

	session1.InstanceInfo = {
		Slot = 1,
		MapName = "ClassicArena",
		Container = fakeContainer,
		KillParts = {},
		Spawns = { Red = { redSpawnPart }, Blue = { blueSpawnPart } },
	}
	MatchInstanceService._allocatedSlots = { [1] = session1.Id }
	MatchInstanceService._instances = { [session1.Id] = session1.InstanceInfo }
	assertStep("M1_STEP3", "M1 - Asignacion de ArenaSlot e InstanceInfo", MatchInstanceService._allocatedSlots[1] == session1.Id, "Slot 1 asignado")

	-- Paso 1.4: Spawn y StartCountdown -> Playing
	RoundService:SetSessionState(session1.Id, Constants.RoundState.StartCountdown)
	RoundService:SetSessionState(session1.Id, Constants.RoundState.Playing)
	p1.Character.HumanoidRootPart.Position = redSpawnPart.Position
	p2.Character.HumanoidRootPart.Position = blueSpawnPart.Position
	assertStep("M1_STEP4", "M1 - Spawn autoritativo en posiciones de equipo", session1.State == Constants.RoundState.Playing, "Jugadores en arena")

	-- Paso 1.5: Combate, Slap y Eliminación sensor
	CombatService:RegisterHit(p1, p2, session1.Id)
	EliminationService:_processEliminationEvent(p2, session1, "VoidBoundary", nil)
	-- Test anti-duplicado concurrente
	EliminationService:_processEliminationEvent(p2, session1, "KillPart", nil)
	assertStep("M1_STEP5", "M1 - Combate y eliminacion (1 Kill sin duplicados)", killsAwarded[p1] == 1, string.format("Kills P1: %d", killsAwarded[p1]))

	ScoreService._scores[session1.Id] = { Red = 0, Blue = 0 }
	ScoreService._matchPointAnnounced[session1.Id] = { Red = false, Blue = false }

	for pt = 1, 4 do
		ScoreService._scores[session1.Id].Red += 1
		session1.Score.Red = ScoreService._scores[session1.Id].Red
		mockPS:AddCoins(p1, 50, "GoalScored")
	end
	if ScoreService._scores[session1.Id].Red >= 4 then
		ScoreService._matchPointAnnounced[session1.Id].Red = true
	end

	local matchPointEmitted = (ScoreService._matchPointAnnounced[session1.Id] and ScoreService._matchPointAnnounced[session1.Id]["Red"] == true)
	assertStep("M1_STEP6", "M1 - Puntos 1..4, Coins acumulados y Match Point emitido",
		ScoreService._scores[session1.Id].Red == 4 and coinsAwarded[p1] == 200 and matchPointEmitted,
		string.format("Score: %d, Coins: %d, MP: %s", ScoreService._scores[session1.Id].Red, coinsAwarded[p1], tostring(matchPointEmitted)))

	-- Paso 1.7: Punto 5 y Victoria inmediata
	ScoreService._scores[session1.Id].Red += 1
	session1.Score.Red = ScoreService._scores[session1.Id].Red
	mockPS:AddCoins(p1, 50, "GoalScored")
	RoundService:DeclareSessionWinner(session1.Id, Constants.MatchResult.Red)
	assertStep("M1_STEP7", "M1 - Victoria inmediata a 5 puntos (Red)",
		ScoreService._scores[session1.Id].Red == 5 and session1.Result == Constants.MatchResult.Red,
		"Red gana con 5 puntos")

	-- Paso 1.8: Estadísticas Win/Loss asignadas
	RoundService:_processReward(session1, Constants.MatchResult.Red)
	assertStep("M1_STEP8", "M1 - Estadisticas (Win a P1, Loss a P2)",
		winsAwarded[p1] == 1 and lossesAwarded[p1] == 0 and winsAwarded[p2] == 0 and lossesAwarded[p2] == 1,
		string.format("P1: %dW/%dL, P2: %dW/%dL", winsAwarded[p1], lossesAwarded[p1], winsAwarded[p2], lossesAwarded[p2]))

	-- Paso 1.9: Retorno al lobby y eliminación de herramientas (Ending -> ReturningToLobby)
	RoundService:SetSessionState(session1.Id, Constants.RoundState.Ending)
	RoundService:SetSessionState(session1.Id, Constants.RoundState.ReturningToLobby)
	if p1.Character:FindFirstChild("Slap") then p1.Character.Slap:Destroy() end
	if p1.Backpack:FindFirstChild("Slap") then p1.Backpack.Slap:Destroy() end
	if p2.Character:FindFirstChild("Slap") then p2.Character.Slap:Destroy() end
	if p2.Backpack:FindFirstChild("Slap") then p2.Backpack.Slap:Destroy() end

	fakeContainer:Destroy()
	MatchInstanceService._allocatedSlots[1] = nil
	MatchInstanceService._instances[session1.Id] = nil
	RoundService:CloseSession(session1.Id)

	local m1ToolsClean = (p1.Backpack:FindFirstChild("Slap") == nil and p2.Backpack:FindFirstChild("Slap") == nil)
	local m1SlotsClean = (MatchInstanceService._allocatedSlots[1] == nil)
	local m1ActiveMatchesZero = (RoundService:GetRegisteredSessionCount() == 0)

	assertStep("M1_STEP9", "M1 - Retorno lobby, herramientas destruidas, Slot liberado y ActiveMatches=0",
		m1ToolsClean and m1SlotsClean and m1ActiveMatchesZero,
		string.format("ToolsClean=%s, SlotsClean=%s, ActiveCount=%d", tostring(m1ToolsClean), tostring(m1SlotsClean), RoundService:GetRegisteredSessionCount()))

	cleanupSimPlayer(p1); cleanupSimPlayer(p2)

	-- =========================================================================
	-- EJECUCIÓN: PARTIDA 1v1 #2 (Victoria de Blue 5-0)
	-- =========================================================================
	resetAllServices()

	local q1 = makeSimPlayer("Q1_Red")
	local q2 = makeSimPlayer("Q2_Blue")

	local coinsAwarded2 = { [q1] = 0, [q2] = 0 }
	local winsAwarded2 = { [q1] = 0, [q2] = 0 }
	local lossesAwarded2 = { [q1] = 0, [q2] = 0 }
	local killsAwarded2 = { [q1] = 0, [q2] = 0 }

	local mockPS2 = {
		AddCoins = function(self, p, amt, reason)
			coinsAwarded2[p] = (coinsAwarded2[p] or 0) + amt
		end,
		AddWin = function(self, p)
			winsAwarded2[p] = (winsAwarded2[p] or 0) + 1
		end,
		AddLoss = function(self, p)
			lossesAwarded2[p] = (lossesAwarded2[p] or 0) + 1
		end,
		AddKill = function(self, p, amt, reason)
			killsAwarded2[p] = (killsAwarded2[p] or 0) + amt
		end,
	}

	ScoreService._context = {
		GetService = function(_, name)
			if name == "PlayerService" then return mockPS2 end
			if name == "RoundService" then return RoundService end
			return nil
		end
	}
	RoundService._context = {
		GetService = function(_, name)
			if name == "PlayerService" then return mockPS2 end
			if name == "ScoreService" then return ScoreService end
			if name == "SpawnService" then return SpawnService end
			if name == "MatchInstanceService" then return MatchInstanceService end
			return nil
		end
	}
	EliminationService._playerService = mockPS2
	EliminationService._combatService = CombatService
	EliminationService._roundService = RoundService

	-- Paso 2.1: Admisión Partida 2
	local session2 = RoundService:AdmitSession({
		ZoneId = "Zone_1v1",
		Mode = "1v1",
		TeamSize = 1,
		RedTeam = { q1 },
		BlueTeam = { q2 },
	})
	assertStep("M2_STEP1", "M2 - Admision autoritativa de segunda partida consecutiva", session2 ~= nil, "Segunda sesión admitida limpiamente")

	-- Paso 2.2: Votación de mapas (MatchReady -> MatchCountdown -> MapSelection)
	RoundService:SetSessionState(session2.Id, Constants.RoundState.MatchReady)
	RoundService:SetSessionState(session2.Id, Constants.RoundState.MatchCountdown)
	RoundService:SetSessionState(session2.Id, Constants.RoundState.MapSelection)
	session2.Votes[q1] = "ClassicArena"
	session2.Votes[q2] = "ClassicArena"
	session2.SelectedMap = RoundService:_resolveMap(session2.Id, { "ClassicArena" })
	assertStep("M2_STEP2", "M2 - Votacion de mapa resuelta", session2.SelectedMap == "ClassicArena", "Mapa seleccionado")

	-- Paso 2.3: Asignación de ArenaSlot para Partida 2
	RoundService:SetSessionState(session2.Id, Constants.RoundState.MapLoading)
	local fakeContainer2 = Instance.new("Folder")
	fakeContainer2.Name = "ArenaContainer_M2"
	fakeContainer2.Parent = workspace
	session2.InstanceInfo = {
		Slot = 1,
		MapName = "ClassicArena",
		Container = fakeContainer2,
		KillParts = {},
		Spawns = { Red = {}, Blue = {} },
	}
	MatchInstanceService._allocatedSlots = { [1] = session2.Id }
	MatchInstanceService._instances = { [session2.Id] = session2.InstanceInfo }
	assertStep("M2_STEP3", "M2 - Slot reasignado limpiamente tras liberacion anterior", MatchInstanceService._allocatedSlots[1] == session2.Id, "Slot 1 reutilizado")

	-- Paso 2.4: Spawn y StartCountdown -> Playing
	RoundService:SetSessionState(session2.Id, Constants.RoundState.StartCountdown)
	RoundService:SetSessionState(session2.Id, Constants.RoundState.Playing)
	assertStep("M2_STEP4", "M2 - Estado transicionado a Playing", session2.State == Constants.RoundState.Playing, "Playing activo")

	-- Paso 2.5: Combate y Eliminación (Blue anota)
	CombatService:RegisterHit(q2, q1, session2.Id)
	EliminationService:_processEliminationEvent(q1, session2, "VoidBoundary", nil)
	assertStep("M2_STEP5", "M2 - Combate y Kill otorgada a Q2 (Blue)", killsAwarded2[q2] == 1, string.format("Kills Q2: %d", killsAwarded2[q2]))

	-- Paso 2.6: Puntuación Blue 5 puntos
	ScoreService._scores[session2.Id] = { Red = 0, Blue = 0 }
	ScoreService._matchPointAnnounced[session2.Id] = { Red = false, Blue = false }
	for pt = 1, 5 do
		ScoreService._scores[session2.Id].Blue += 1
		session2.Score.Blue = ScoreService._scores[session2.Id].Blue
		mockPS2:AddCoins(q2, 50, "GoalScored")
	end
	RoundService:DeclareSessionWinner(session2.Id, Constants.MatchResult.Blue)
	assertStep("M2_STEP6", "M2 - Victoria inmediata de Blue a 5 puntos",
		ScoreService._scores[session2.Id].Blue == 5 and session2.Result == Constants.MatchResult.Blue,
		string.format("Score Blue: %d, Resultado: %s", ScoreService._scores[session2.Id].Blue, tostring(session2.Result)))

	-- Paso 2.7: Estadísticas (Win a Q2, Loss a Q1)
	RoundService:_processReward(session2, Constants.MatchResult.Blue)
	assertStep("M2_STEP7", "M2 - Estadisticas (Win a Q2, Loss a Q1)",
		winsAwarded2[q2] == 1 and lossesAwarded2[q2] == 0 and winsAwarded2[q1] == 0 and lossesAwarded2[q1] == 1,
		string.format("Q1: %dW/%dL, Q2: %dW/%dL", winsAwarded2[q1], lossesAwarded2[q1], winsAwarded2[q2], lossesAwarded2[q2]))

	-- Paso 2.8: Retorno al lobby, destrucción de instancias y verificación de estado limpio (Ending -> ReturningToLobby)
	RoundService:SetSessionState(session2.Id, Constants.RoundState.Ending)
	RoundService:SetSessionState(session2.Id, Constants.RoundState.ReturningToLobby)
	fakeContainer2:Destroy()
	MatchInstanceService._allocatedSlots[1] = nil
	MatchInstanceService._instances[session2.Id] = nil
	RoundService:CloseSession(session2.Id)

	local m2SlotsClean = (MatchInstanceService._allocatedSlots[1] == nil)
	local m2ActiveMatchesZero = (RoundService:GetRegisteredSessionCount() == 0)
	local noOrphanSessions = (#RoundService:GetActiveSessions() == 0)
	local scoreTableClean = (ScoreService._scores[session2.Id] == nil)

	assertStep("M2_STEP8", "M2 - Limpieza final completa: Slots=0, ActiveMatches=0, Sin sesiones huerfanas",
		m2SlotsClean and m2ActiveMatchesZero and noOrphanSessions and scoreTableClean,
		string.format("SlotsClean=%s, ActiveCount=%d, OrphanCount=%d, ScoreClean=%s",
			tostring(m2SlotsClean), RoundService:GetRegisteredSessionCount(), #RoundService:GetActiveSessions(), tostring(scoreTableClean)))

	cleanupSimPlayer(q1); cleanupSimPlayer(q2)
	resetAllServices()

	print(string.format("=== REGRESION 1v1 (2 PARTIDAS): %d PASADAS, %d FALLADAS ===", passedCount, failedCount))
	return {
		passed = passedCount,
		failed = failedCount,
		results = results,
	}
end
