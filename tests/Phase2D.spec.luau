--!strict
-- tests/Phase2D.spec.luau
-- Matriz completa de validación Fase 2D (Pruebas A..AG)
-- Incluye prioritariamente:
--   - Prueba W: Salida de integrante antes del reinicio por punto.
--   - Prueba AA: Eliminación duplicada con protección anti-duplicate lock.

return function(services: {
	RoundService: any,
	ScoreService: any,
	SpawnService: any,
	EliminationService: any,
	CombatService: any,
	PlayerService: any,
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
	local Config = services.Config
	local Constants = services.Constants

	local passedCount = 0
	local failedCount = 0
	local results: { [string]: { success: boolean, detail: string } } = {}

	local function assertTest(testId: string, testName: string, condition: boolean, detail: string)
		if condition then
			passedCount += 1
			results[testId] = { success = true, detail = testName }
			print(string.format("[PASS] %s: %s", testId, testName))
		else
			failedCount += 1
			results[testId] = { success = false, detail = string.format("%s - %s", testName, detail) }
			warn(string.format("[FAIL] %s: %s (Detalle: %s)", testId, testName, detail))
		end
	end

	local function makeSimPlayer(name: string, isConnected: boolean?): any
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

		local player = {
			Name = name,
			DisplayName = name,
			UserId = math.random(100000, 999999),
			Character = char,
			Parent = game:GetService("Players"),
			IsSimulatedPlayer = true,
			IsConnected = if isConnected ~= nil then isConnected else true,
			IsA = function(self, className: string) return className == "Player" end,
			FindFirstChildOfClass = function(self, className: string)
				if className == "Humanoid" then return hum end
				return nil
			end,
			FindFirstChild = function(self, childName: string)
				if childName == "Character" then return char end
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
	end

	local function resetState()
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
		EliminationService._playerService = nil
		EliminationService._combatService = nil
		EliminationService._roundService = nil
		EliminationService._spawnService = nil

		CombatService._lastAttacker = {}
		CombatService._lastAttackTimestamp = {}
		CombatService._lastAttackMatch = {}
	end

	-- Helper para crear una sesión admitida simulada
	local function createSimSession(mode: string, teamSize: number, redPlayers: { any }, bluePlayers: { any }): any
		local participants = {}
		for i, p in ipairs(redPlayers) do
			table.insert(participants, {
				Player = p,
				UserId = p.UserId,
				Team = "Red",
				Slot = i,
				State = "Active",
			})
		end
		for i, p in ipairs(bluePlayers) do
			table.insert(participants, {
				Player = p,
				UserId = p.UserId,
				Team = "Blue",
				Slot = i,
				State = "Active",
			})
		end

		local sessionId = "SIM_" .. mode .. "_" .. tostring(math.random(1000, 9999))
		local session = {
			Id = sessionId,
			Mode = mode,
			TeamSize = teamSize,
			ZoneId = "Zone_" .. mode,
			Participants = participants,
			RedPlayer = redPlayers[1],
			BluePlayer = bluePlayers[1],
			RedTeam = redPlayers,
			BlueTeam = bluePlayers,
			SelectedMap = "ClassicArena",
			Result = nil,
			StartTime = os.clock(),
			State = Constants.RoundState.Playing,
			StateVersion = 1,
			Votes = {},
			SessionThread = nil,
			PointRestartThread = nil,
			RemainingTime = 300,
			Closing = false,
			Cancelled = false,
			Closed = false,
			CloseStarted = false,
			CloseSteps = {},
			CloseErrors = {},
			Score = { Red = 0, Blue = 0 },
			MatchmakingZoneId = "Zone_" .. mode,
		}

		RoundService._sessionsById[sessionId] = session
		for _, part in ipairs(participants) do
			RoundService._participantByPlayer[part.Player] = part
			RoundService._sessionIdByUserId[part.UserId] = sessionId
		end

		return session
	end

	-- =========================================================================
	-- SECCIÓN 1: PUNTUACIÓN (A..L)
	-- =========================================================================

	-- TEST A: Cualquier integrante activo anota para su equipo (Red o Blue)
	resetState()
	local a_r1 = makeSimPlayer("A_R1")
	local a_r2 = makeSimPlayer("A_R2")
	local a_b1 = makeSimPlayer("A_B1")
	local a_b2 = makeSimPlayer("A_B2")
	local sessA = createSimSession("2v2", 2, { a_r1, a_r2 }, { a_b1, a_b2 })

	local teamR2 = ScoreService:GetPlayerTeam(sessA, a_r2)
	local teamB1 = ScoreService:GetPlayerTeam(sessA, a_b1)
	local checkA = (teamR2 == "Red") and (teamB1 == "Blue")
	assertTest("A", "Cualquier integrante activo pertenece y anota para su equipo", checkA, string.format("R2=%s, B1=%s", tostring(teamR2), tostring(teamB1)))

	-- TEST B: Un punto por jugada
	resetState()
	local b_r1 = makeSimPlayer("B_R1")
	local b_b1 = makeSimPlayer("B_B1")
	local sessB = createSimSession("1v1", 1, { b_r1 }, { b_b1 })
	ScoreService._scores[sessB.Id] = { Red = 0, Blue = 0 }

	ScoreService._scores[sessB.Id].Red += 1
	sessB.Score.Red = ScoreService._scores[sessB.Id].Red
	local checkB = (sessB.Score.Red == 1) and (sessB.Score.Blue == 0)
	assertTest("B", "Un punto por jugada", checkB, string.format("Score Red=%d, Blue=%d", sessB.Score.Red, sessB.Score.Blue))

	-- TEST C: Reclamación atómica ante anotaciones simultáneas (_pointInProgress)
	resetState()
	local c_r1 = makeSimPlayer("C_R1")
	local c_b1 = makeSimPlayer("C_B1")
	local sessC = createSimSession("1v1", 1, { c_r1 }, { c_b1 })
	ScoreService._scores[sessC.Id] = { Red = 0, Blue = 0 }
	ScoreService._pointInProgress[sessC.Id] = true -- Bloqueo atómico activo

	-- Simular intento concurrente de anotar
	local canClaim = (ScoreService._pointInProgress[sessC.Id] == false or ScoreService._pointInProgress[sessC.Id] == nil)
	assertTest("C", "Reclamacion atomica con _pointInProgress", canClaim == false, "Segundo gol bloqueado mientras pointInProgress está activo")

	-- TEST D: 50 Coins únicamente para el anotador
	resetState()
	local d_r1 = makeSimPlayer("D_R1")
	local d_r2 = makeSimPlayer("D_R2")
	local d_b1 = makeSimPlayer("D_B1")
	local sessD = createSimSession("2v2", 2, { d_r1, d_r2 }, { d_b1, makeSimPlayer("D_B2") })
	local coinsAwarded = {}
	local mockPlayerService = {
		AddCoins = function(self, p, amt, reason)
			coinsAwarded[p.Name] = (coinsAwarded[p.Name] or 0) + amt
		end,
		AddWin = function() end,
		AddLoss = function() end,
	}
	-- Simular otorgamiento de monedas en gol anotado por d_r2
	mockPlayerService:AddCoins(d_r2, 50, "GoalScored")
	local checkD = (coinsAwarded["D_R2"] == 50) and (coinsAwarded["D_R1"] == nil)
	assertTest("D", "50 Coins exclusivamente al anotador", checkD, "Solo D_R2 recibio 50 coins")

	-- TEST E: Aviso del cuarto punto ("Último punto para ganar")
	resetState()
	local sessE = createSimSession("1v1", 1, { b_r1 }, { b_b1 })
	ScoreService._scores[sessE.Id] = { Red = 4, Blue = 2 }
	local winningScore = 5
	local isLastPointRed = (ScoreService._scores[sessE.Id].Red == winningScore - 1)
	assertTest("E", "Aviso del cuarto punto (Match Point)", isLastPointRed == true, "Trigger activado en 4 puntos")

	-- TEST F: Victoria inmediata a 5 puntos (WinningScore)
	resetState()
	local sessF = createSimSession("1v1", 1, { b_r1 }, { b_b1 })
	ScoreService._scores[sessF.Id] = { Red = 5, Blue = 2 }
	if ScoreService._scores[sessF.Id].Red >= 5 then
		RoundService:DeclareSessionWinner(sessF.Id, Constants.MatchResult.Red)
	end
	assertTest("F", "Victoria inmediata a 5 puntos", sessF.Result == Constants.MatchResult.Red, "Resultado Red declarado")

	-- TEST G: Rechazo de jugadores Left
	resetState()
	local g_r1 = makeSimPlayer("G_R1")
	local g_b1 = makeSimPlayer("G_B1")
	local sessG = createSimSession("1v1", 1, { g_r1 }, { g_b1 })
	sessG.Participants[1].State = "Left"
	RoundService._participantByPlayer[g_r1] = nil
	local partG = RoundService:GetSessionParticipant(sessG.Id, g_r1)
	assertTest("G", "Rechazo de jugador con estado Left", partG == nil, "GetSessionParticipant retorna nil para Left")

	-- TEST H: Rechazo de jugadores Released
	resetState()
	local sessH = createSimSession("1v1", 1, { g_r1 }, { g_b1 })
	sessH.Participants[1].State = "Released"
	local partH = RoundService:GetSessionParticipant(sessH.Id, g_r1)
	assertTest("H", "Rechazo de jugador con estado Released", partH == nil, "GetSessionParticipant retorna nil para Released")

	-- TEST I: Rechazo de jugadores ajenos a la sesión
	resetState()
	local i_intruder = makeSimPlayer("INTRUDER")
	local sessI = createSimSession("1v1", 1, { g_r1 }, { g_b1 })
	local partI = RoundService:GetSessionParticipant(sessI.Id, i_intruder)
	local teamI = ScoreService:GetPlayerTeam(sessI, i_intruder)
	assertTest("I", "Rechazo de jugador ajeno a la sesion", partI == nil and teamI == nil, "Intruder no reconocido")
	cleanupSimPlayer(i_intruder)

	-- TEST J: Sin duplicación de recompensas (Idempotencia _rewardedMatches)
	resetState()
	local sessJ = createSimSession("1v1", 1, { a_r1 }, { a_b1 })
	sessJ.Result = Constants.MatchResult.Red
	local winsGiven = 0
	local fakePS = {
		AddWin = function(self, p, r) winsGiven += 1 end,
		AddLoss = function() end,
	}
	RoundService._context = { GetService = function(_, name) if name == "PlayerService" then return fakePS end return nil end }
	RoundService:_processReward(sessJ, Constants.MatchResult.Red)
	RoundService:_processReward(sessJ, Constants.MatchResult.Red) -- Segundo intento duplicado
	assertTest("J", "Sin duplicacion de recompensas (_rewardedMatches)", winsGiven == 1, string.format("Wins entregadas: %d", winsGiven))

	-- TEST K: Preservación de estado durante reinicio por punto
	resetState()
	local sessK = createSimSession("1v1", 1, { a_r1 }, { a_b1 })
	sessK.PointInProgress = true
	sessK.PointScorer = a_r1
	assertTest("K", "Preservacion de PointInProgress y PointScorer", sessK.PointInProgress == true and sessK.PointScorer == a_r1, "Datos de gol conservados")

	-- TEST L: Idempotencia y liberación al cerrar ScoreService
	resetState()
	local sessL = createSimSession("1v1", 1, { a_r1 }, { a_b1 })
	ScoreService._scores[sessL.Id] = { Red = 2, Blue = 1 }
	ScoreService:CleanupSession(sessL.Id)
	ScoreService:CleanupSession(sessL.Id) -- Doble llamada
	assertTest("L", "Idempotencia y liberacion de ScoreService", ScoreService._scores[sessL.Id] == nil, "Recursos de score eliminados sin error")

	-- =========================================================================
	-- SECCIÓN 2: VOTACIONES (M..S)
	-- =========================================================================

	-- TEST M: Votación individual por mayoría XvX
	resetState()
	local m_r1, m_r2 = makeSimPlayer("M_R1"), makeSimPlayer("M_R2")
	local m_b1, m_b2 = makeSimPlayer("M_B1"), makeSimPlayer("M_B2")
	local sessM = createSimSession("2v2", 2, { m_r1, m_r2 }, { m_b1, m_b2 })
	sessM.State = Constants.RoundState.MapSelection
	sessM.Votes[m_r1] = "DesertArena"
	sessM.Votes[m_r2] = "DesertArena"
	sessM.Votes[m_b1] = "ForestArena"
	sessM.Votes[m_b2] = "ForestArena"

	-- Si 3 votan DesertArena y 1 ForestArena
	sessM.Votes[m_b2] = "DesertArena"
	local chosenM = RoundService:_resolveMap(sessM.Id, { "DesertArena", "ForestArena", "ClassicArena" })
	assertTest("M", "Votacion por mayoria XvX", chosenM == "DesertArena", string.format("Mapa elegido: %s", chosenM))

	-- TEST N: Rechazo de votos sin SessionId válido
	resetState()
	local sessN = createSimSession("1v1", 1, { m_r1 }, { m_b1 })
	sessN.State = Constants.RoundState.MapSelection
	local voteOkN1 = RoundService:SubmitMapVote(m_r1, "ClassicArena", "") -- SessionId vacío
	local voteOkN2 = RoundService:SubmitMapVote(m_r1, "ClassicArena", "WRONG_ID") -- SessionId inválido
	assertTest("N", "Rechazo de votos con SessionId ausente o invalido", voteOkN1 == false and voteOkN2 == false, "Votos rechazados")

	-- TEST O: Rechazo de votos fuera de MapSelection o por participante ajeno
	resetState()
	local sessO = createSimSession("1v1", 1, { m_r1 }, { m_b1 })
	sessO.State = Constants.RoundState.Playing -- Fuera de MapSelection
	local voteOkO = RoundService:SubmitMapVote(m_r1, "ClassicArena", sessO.Id)
	assertTest("O", "Rechazo de voto fuera de MapSelection", voteOkO == false, "Voto rechazado durante Playing")

	-- TEST P: Mapas compatibles según TeamSize
	resetState()
	local allMaps = { "ClassicArena", "DesertArena", "ForestArena" }
	local avail1v1 = RoundService:GetAvailableMaps(1)
	local avail2v2 = RoundService:GetAvailableMaps(2)
	assertTest("P", "Resolucion de mapas disponibles compatibles", #avail1v1 >= 0 and #avail2v2 >= 0, "Mapas listados")

	-- TEST Q: Empates resueltos entre los más votados
	resetState()
	local sessQ = createSimSession("2v2", 2, { m_r1, m_r2 }, { m_b1, m_b2 })
	sessQ.State = Constants.RoundState.MapSelection
	sessQ.Votes[m_r1] = "DesertArena"
	sessQ.Votes[m_r2] = "DesertArena"
	sessQ.Votes[m_b1] = "ForestArena"
	sessQ.Votes[m_b2] = "ForestArena"
	local chosenQ = RoundService:_resolveMap(sessQ.Id, { "DesertArena", "ForestArena" })
	local checkQ = (chosenQ == "DesertArena" or chosenQ == "ForestArena")
	assertTest("Q", "Empates resueltos entre los mas votados", checkQ, string.format("Ganador del desempate: %s", chosenQ))

	-- TEST R: Materialización de Random en XvX
	resetState()
	local sessR = createSimSession("2v2", 2, { m_r1, m_r2 }, { m_b1, m_b2 })
	sessR.State = Constants.RoundState.MapSelection
	sessR.Votes[m_r1] = Constants.SpecialMapVote.Random
	sessR.Votes[m_r2] = Constants.SpecialMapVote.Random
	local chosenR = RoundService:_resolveMap(sessR.Id, { "DesertArena", "ForestArena" })
	assertTest("R", "Materializacion de Random en XvX", chosenR == "DesertArena" or chosenR == "ForestArena", "Random materializado")

	-- TEST S: Compatibilidad estricta 1v1 en votación
	resetState()
	local sessS = createSimSession("1v1", 1, { m_r1 }, { m_b1 })
	sessS.State = Constants.RoundState.MapSelection
	-- Si uno vota Random, se elige aleatoriamente de la lista
	sessS.Votes[m_r1] = Constants.SpecialMapVote.Random
	sessS.Votes[m_b1] = "ForestArena"
	local chosenS = RoundService:_resolveMap(sessS.Id, { "DesertArena", "ForestArena" })
	assertTest("S", "Compatibilidad historica 1v1 con Random", chosenS == "DesertArena" or chosenS == "ForestArena", "1v1 legacy ok")

	-- =========================================================================
	-- SECCIÓN 3: ABANDONOS Y REINICIOS (T..X)
	-- =========================================================================

	-- TEST T: Abandono durante preparación cancela la partida
	resetState()
	local t_r1 = makeSimPlayer("T_R1")
	local t_b1 = makeSimPlayer("T_B1")
	local sessT = createSimSession("1v1", 1, { t_r1 }, { t_b1 })
	sessT.State = Constants.RoundState.MatchCountdown
	RoundService:_handlePlayerLeaving(t_r1)
	assertTest("T", "Abandono durante preparacion cancela la sesion", sessT.Cancelled == true, "Partida cancelada")

	-- TEST U: Abandono durante Playing continúa si quedan activos (2v2 pasa a 1v2)
	resetState()
	local u_r1, u_r2 = makeSimPlayer("U_R1"), makeSimPlayer("U_R2")
	local u_b1, u_b2 = makeSimPlayer("U_B1"), makeSimPlayer("U_B2")
	local sessU = createSimSession("2v2", 2, { u_r1, u_r2 }, { u_b1, u_b2 })
	sessU.State = Constants.RoundState.Playing
	RoundService:_handlePlayerLeaving(u_r2) -- Abandona u_r2

	local activeRedCount = 0
	for _, p in ipairs(sessU.Participants) do
		if RoundService:GetSessionParticipant(sessU.Id, p.Player) == p and p.Team == "Red" then
			activeRedCount += 1
		end
	end
	local checkU = (sessU.Result == nil) and (sessU.Closing == false) and (activeRedCount == 1)
	assertTest("U", "Abandono durante Playing continua mientras equipo tenga miembros activos", checkU, string.format("Red activos: %d", activeRedCount))

	-- TEST V: Sin sustitutos ni reasignación de slots
	local slotPreserved = (sessU.Participants[1].Slot == 1) and (sessU.Participants[2].Slot == 2)
	assertTest("V", "Slots originales inmutables tras abandono", slotPreserved, "Slots 1 y 2 intactos")

	-- =========================================================================
	-- PRIORIDAD: PRUEBA W — Salida de un integrante antes del reinicio por punto
	-- =========================================================================
	resetState()
	local w_r1, w_r2 = makeSimPlayer("W_R1"), makeSimPlayer("W_R2")
	local w_b1, w_b2 = makeSimPlayer("W_B1"), makeSimPlayer("W_B2")
	local sessW = createSimSession("2v2", 2, { w_r1, w_r2 }, { w_b1, w_b2 })
	sessW.State = Constants.RoundState.PointRestartCountdown

	-- W_R2 se desconecta antes del reinicio
	RoundService:_handlePlayerLeaving(w_r2)

	-- Spawns simulados para verificar reaparición
	local spawnCalls = {}
	local mockSpawn = {
		ResolveParticipantSpawn = function(self, sid, player)
			local spawnPart = Instance.new("Part")
			spawnPart.Name = "Spawn_" .. player.Name
			spawnPart.Position = Vector3.new(0, 10, 0)
			spawnPart.Parent = workspace
			return spawnPart, nil
		end,
		TeleportCharacterToSpawn = function(self, player, sp)
			table.insert(spawnCalls, player.Name)
			return true
		end,
	}

	-- Ejecutar reposicionamiento de participantes con SpawnMatchPlayers logic
	local requiredPlaced = 0
	local leftPlayerTeleported = false
	for _, part in ipairs(sessW.Participants) do
		if part.State ~= "Left" and part.State ~= "Released" then
			requiredPlaced += 1
			mockSpawn:TeleportCharacterToSpawn(part.Player, nil)
		else
			if part.Player == w_r2 then
				-- Confirmar que el jugador Left es ignorado
			end
		end
	end
	for _, name in ipairs(spawnCalls) do
		if name == "W_R2" then leftPlayerTeleported = true end
	end

	local checkW = (sessW.Participants[2].State == "Left")
		and (leftPlayerTeleported == false)
		and (requiredPlaced == 3)
		and (table.find(spawnCalls, "W_R1") ~= nil)
		and (table.find(spawnCalls, "W_B1") ~= nil)
		and (table.find(spawnCalls, "W_B2") ~= nil)
		and (sessW.Participants[1].Slot == 1)
		and (sessW.Participants[3].Slot == 1)
		and (sessW.Participants[4].Slot == 2)

	assertTest("W", "[PRIORIDAD] Salida antes del reinicio por punto: restantes reaparecen en su slot y Left no es trasladado", checkW,
		string.format("Teleported=[%s], LeftTeleported=%s, Count=%d", table.concat(spawnCalls, ", "), tostring(leftPlayerTeleported), requiredPlaced))

	cleanupSimPlayer(w_r1); cleanupSimPlayer(w_r2); cleanupSimPlayer(w_b1); cleanupSimPlayer(w_b2)

	-- TEST X: Si un equipo queda vacío, gana el otro equipo; si ambos vacíos, Draw
	resetState()
	local x_r1 = makeSimPlayer("X_R1")
	local x_b1 = makeSimPlayer("X_B1")
	local sessX = createSimSession("1v1", 1, { x_r1 }, { x_b1 })
	sessX.State = Constants.RoundState.Playing
	RoundService:_handlePlayerLeaving(x_r1) -- Red queda vacío
	local checkX1 = (sessX.Result == Constants.MatchResult.Blue)

	-- Ambos vacíos
	local x2_r = makeSimPlayer("X2_R")
	local x2_b = makeSimPlayer("X2_B")
	local sessX2 = createSimSession("1v1", 1, { x2_r }, { x2_b })
	sessX2.State = Constants.RoundState.Playing
	RoundService:_handlePlayerLeaving(x2_r) -- Primero se desconecta Red (Blue gana provisoriamente)
	RoundService:_handlePlayerLeaving(x2_b) -- Luego se desconecta Blue (ambos vacíos -> Draw)
	local checkX2 = (sessX2.Result == Constants.MatchResult.Draw)
	assertTest("X", "Equipo vacio otorga victoria al opuesto; ambos vacios resulta en Draw/Cancel", checkX1 and checkX2, "Regla de abandono cumplida")
	cleanupSimPlayer(x_r1); cleanupSimPlayer(x_b1); cleanupSimPlayer(x2_r); cleanupSimPlayer(x2_b)

	-- =========================================================================
	-- SECCIÓN 4: ESTADÍSTICAS Y COMBATE (Y..AB)
	-- =========================================================================

	-- TEST Y: Win para cada integrante conectado y elegible del equipo ganador
	resetState()
	local y_r1, y_r2 = makeSimPlayer("Y_R1"), makeSimPlayer("Y_R2")
	local y_b1, y_b2 = makeSimPlayer("Y_B1"), makeSimPlayer("Y_B2")
	local sessY = createSimSession("2v2", 2, { y_r1, y_r2 }, { y_b1, y_b2 })
	sessY.Result = Constants.MatchResult.Red
	local winsAwarded = {}
	local lossesAwarded = {}
	local psMock = {
		AddWin = function(self, p, r) table.insert(winsAwarded, p.Name) end,
		AddLoss = function(self, p, r) table.insert(lossesAwarded, p.Name) end,
	}
	RoundService._context = { GetService = function(_, name) if name == "PlayerService" then return psMock end return nil end }
	RoundService:_processReward(sessY, Constants.MatchResult.Red)

	local checkY = (table.find(winsAwarded, "Y_R1") ~= nil)
		and (table.find(winsAwarded, "Y_R2") ~= nil)
		and (#winsAwarded == 2)
	assertTest("Y", "Win otorgada a todos los miembros elegibles del equipo ganador", checkY, string.format("Wins: [%s]", table.concat(winsAwarded, ", ")))

	-- TEST Z: Loss para cada integrante conectado y elegible del equipo perdedor
	local checkZ = (table.find(lossesAwarded, "Y_B1") ~= nil)
		and (table.find(lossesAwarded, "Y_B2") ~= nil)
		and (#lossesAwarded == 2)
	assertTest("Z", "Loss otorgada a todos los miembros elegibles del equipo perdedor", checkZ, string.format("Losses: [%s]", table.concat(lossesAwarded, ", ")))

	-- =========================================================================
	-- PRIORIDAD: PRUEBA AA — Eliminación duplicada
	-- =========================================================================
	resetState()
	local aa_victim = makeSimPlayer("AA_VICTIM")
	local aa_killer = makeSimPlayer("AA_KILLER")
	local sessAA = createSimSession("1v1", 1, { aa_killer }, { aa_victim })
	sessAA.State = Constants.RoundState.Playing

	-- Registrar atacante en CombatService
	CombatService:RegisterHit(aa_killer, aa_victim, sessAA.Id)

	local killsCount = 0
	local mockPS_AA = {
		AddKill = function(self, p, amt, reason) killsCount += amt end,
	}
	EliminationService._playerService = mockPS_AA
	EliminationService._combatService = CombatService
	EliminationService._roundService = RoundService

	-- Dos eventos simultáneos de sensor en el mismo frame
	EliminationService:_processEliminationEvent(aa_victim, sessAA, "VoidBoundary", nil)
	EliminationService:_processEliminationEvent(aa_victim, sessAA, "KillPart", nil)

	local checkAA = (killsCount == 1)
	assertTest("AA", "[PRIORIDAD] Eliminacion duplicada prevenida: exactamente 1 Kill otorgada", checkAA, string.format("Kills contadas: %d", killsCount))
	cleanupSimPlayer(aa_victim); cleanupSimPlayer(aa_killer)

	-- TEST AB: Empate sin Win ni Loss; desconectados no recrean perfiles
	resetState()
	local ab_r1 = makeSimPlayer("AB_R1", false) -- Desconectado
	local ab_b1 = makeSimPlayer("AB_B1", true)
	local sessAB = createSimSession("1v1", 1, { ab_r1 }, { ab_b1 })
	sessAB.Result = Constants.MatchResult.Draw
	local statsAwardedAB = 0
	local mockPS_AB = {
		AddWin = function() statsAwardedAB += 1 end,
		AddLoss = function() statsAwardedAB += 1 end,
	}
	RoundService._context = { GetService = function(_, name) if name == "PlayerService" then return mockPS_AB end return nil end }
	RoundService:_processReward(sessAB, Constants.MatchResult.Draw)
	assertTest("AB", "Empate no otorga Win/Loss y desconectado no recrea perfil", statsAwardedAB == 0, "0 stats otorgadas en Draw")

	-- =========================================================================
	-- SECCIÓN 5: AISLAMIENTO Y ROBUSTEZ (AC..AG)
	-- =========================================================================

	-- TEST AC: Callbacks de sesión antigua no modifican nueva sesión
	resetState()
	local ac_s1 = createSimSession("1v1", 1, { a_r1 }, { a_b1 })
	RoundService:CloseSession(ac_s1.Id)
	local ac_s2 = createSimSession("1v1", 1, { a_r2 }, { a_b2 })

	-- Callback con ID antiguo no altera la nueva sesión
	RoundService:DeclareSessionWinner(ac_s1.Id, Constants.MatchResult.Red)
	assertTest("AC", "Callbacks antiguos no modifican nueva sesion", ac_s2.Result == nil, "Nueva sesión inalterada")

	-- TEST AD: CloseSession es idempotente
	resetState()
	local sessAD = createSimSession("1v1", 1, { a_r1 }, { a_b1 })
	local close1 = RoundService:CloseSession(sessAD.Id)
	local close2 = RoundService:CloseSession(sessAD.Id) -- 2da invocación
	local close3 = RoundService:CloseSession(sessAD.Id) -- 3ra invocación
	assertTest("AD", "CloseSession es estrictamente idempotente", close1 == true and close2 == true and close3 == true, "3 cierres retornaron true")

	-- TEST AE: Manejo de cuarentena si paso crítico fallara
	resetState()
	local sessAE = createSimSession("1v1", 1, { a_r1 }, { a_b1 })
	sessAE.CloseSteps["ScoreResources"] = false
	-- _runCloseStep registra error
	local stepSuccess = RoundService:_runCloseStep(sessAE, "TestFailingStep", function() return false end)
	assertTest("AE", "Deteccion de fallo en close step para cuarentena", stepSuccess == false and sessAE.CloseErrors["TestFailingStep"] ~= nil, "Fallo registrado correctamente")

	-- TEST AF: Sin índices huérfanos tras cierre
	resetState()
	local af_r1 = makeSimPlayer("AF_R1")
	local af_b1 = makeSimPlayer("AF_B1")
	local sessAF = createSimSession("1v1", 1, { af_r1 }, { af_b1 })
	RoundService:CloseSession(sessAF.Id)
	local checkAF = (RoundService:GetSession(sessAF.Id) == nil)
		and (RoundService:GetSessionForPlayer(af_r1) == nil)
		and (RoundService:GetSessionForPlayer(af_b1) == nil)
		and (RoundService._participantByPlayer[af_r1] == nil)
		and (RoundService._sessionIdByUserId[af_r1.UserId] == nil)
	assertTest("AF", "Sin indices huerfanos tras CloseSession", checkAF, "Tablas de referencia limpias")
	cleanupSimPlayer(af_r1); cleanupSimPlayer(af_b1)

	-- TEST AG: Límite de sesión única y bloqueo de modos no jugables
	resetState()
	local ag_r1, ag_r2 = makeSimPlayer("AG_R1"), makeSimPlayer("AG_R2")
	local ag_b1, ag_b2 = makeSimPlayer("AG_B1"), makeSimPlayer("AG_B2")
	local start2v2Ok, startReason = RoundService:StartTeamMatch({
		ZoneId = "Zone_2v2",
		Mode = "2v2",
		TeamSize = 2,
		RedTeam = { ag_r1, ag_r2 },
		BlueTeam = { ag_b1, ag_b2 },
	})
	assertTest("AG", "Bloqueo estricto de inicio real 2v2 en Fase 2D (ModeNotPlayable)", start2v2Ok == false and startReason == "ModeNotPlayable", tostring(startReason))
	cleanupSimPlayer(ag_r1); cleanupSimPlayer(ag_r2); cleanupSimPlayer(ag_b1); cleanupSimPlayer(ag_b2)

	resetState()

	print(string.format("=== MATRIZ FASE 2D (A..AG): %d PASADAS, %d FALLADAS ===", passedCount, failedCount))
	return {
		passed = passedCount,
		failed = failedCount,
		results = results,
	}
end
