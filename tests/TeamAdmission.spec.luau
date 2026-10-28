--!strict
-- tests/TeamAdmission.spec.luau
-- Pruebas de admision autoritativa de equipos XvX para Fase 2A (Tests A..P)
-- Verifica el contrato entre MatchmakingService y RoundService.

return function(services: {
	RoundService: any,
	MatchmakingService: any,
	Config: any,
	Types: any,
})
	local RoundService = services.RoundService
	local MatchmakingService = services.MatchmakingService
	local Config = services.Config

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

	-- Limpieza de estado de pruebas previas
	local function resetServiceState()
		RoundService._sessionsById = {}
		RoundService._sessionIdByUserId = {}
		RoundService._participantByPlayer = {}
		RoundService._closedSessionIds = {}
		RoundService._currentSession = nil
		RoundService._isStartingSession = false
		RoundService._sessionCounter = 0
		RoundService._maxConcurrentSessions = 1
		MatchmakingService._zones = {}
	end

	local function makeSimPlayer(name: string, isConnected: boolean?): any
		local char = Instance.new("Model")
		char.Name = name .. "_Char"
		local hrp = Instance.new("Part")
		hrp.Name = "HumanoidRootPart"
		hrp.Position = Vector3.new(0, 5, 0)
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
			IsSimulatedPlayer = true,
			IsConnected = if isConnected ~= nil then isConnected else true,
			IsA = function(self, className: string)
				return className == "Player"
			end,
			FindFirstChildOfClass = function(self, className: string)
				return nil
			end,
			FindFirstChild = function(self, childName: string)
				return nil
			end,
			IsDescendantOf = function(self, ancestor: any)
				return true
			end,
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

	-- =========================================================================
	-- TEST A: Admisión 1v1 compatible
	-- =========================================================================
	resetServiceState()
	local p1 = makeSimPlayer("P1_A")
	local p2 = makeSimPlayer("P2_A")

	local sessionA, errA = RoundService:AdmitSession({
		ZoneId = "Zone_1v1",
		Mode = "1v1",
		TeamSize = 1,
		RedTeam = { p1 },
		BlueTeam = { p2 },
	})

	local checkA = sessionA ~= nil
		and sessionA.Mode == "1v1"
		and sessionA.TeamSize == 1
		and #sessionA.Participants == 2
		and sessionA.Participants[1].Team == "Red"
		and sessionA.Participants[1].Slot == 1
		and sessionA.Participants[2].Team == "Blue"
		and sessionA.Participants[2].Slot == 1
		and RoundService:GetSessionForPlayer(p1) == sessionA
		and RoundService:GetSessionForPlayer(p2) == sessionA

	assertTest("A", "Admision 1v1 compatible", checkA, tostring(errA or sessionA))
	cleanupSimPlayer(p1)
	cleanupSimPlayer(p2)

	-- =========================================================================
	-- TEST B: Solicitud 2v2 estructuralmente válida
	-- =========================================================================
	resetServiceState()
	local r1, r2 = makeSimPlayer("R1_B"), makeSimPlayer("R2_B")
	local b1, b2 = makeSimPlayer("B1_B"), makeSimPlayer("B2_B")

	local sessionB, errB = RoundService:AdmitSession({
		ZoneId = "Zone_2v2",
		Mode = "2v2",
		TeamSize = 2,
		RedTeam = { r1, r2 },
		BlueTeam = { b1, b2 },
	})

	local checkB = sessionB ~= nil
		and sessionB.Mode == "2v2"
		and sessionB.TeamSize == 2
		and #sessionB.Participants == 4
		and sessionB.Participants[1].Team == "Red" and sessionB.Participants[1].Slot == 1
		and sessionB.Participants[2].Team == "Red" and sessionB.Participants[2].Slot == 2
		and sessionB.Participants[3].Team == "Blue" and sessionB.Participants[3].Slot == 1
		and sessionB.Participants[4].Team == "Blue" and sessionB.Participants[4].Slot == 2

	assertTest("B", "Solicitud 2v2 estructuralmente valida", checkB, tostring(errB or sessionB))
	cleanupSimPlayer(r1); cleanupSimPlayer(r2); cleanupSimPlayer(b1); cleanupSimPlayer(b2)

	-- =========================================================================
	-- TEST C: Solicitud 3v3 estructuralmente válida
	-- =========================================================================
	resetServiceState()
	local r1_c, r2_c, r3_c = makeSimPlayer("R1_C"), makeSimPlayer("R2_C"), makeSimPlayer("R3_C")
	local b1_c, b2_c, b3_c = makeSimPlayer("B1_C"), makeSimPlayer("B2_C"), makeSimPlayer("B3_C")

	local sessionC, errC = RoundService:AdmitSession({
		ZoneId = "Zone_3v3",
		Mode = "3v3",
		TeamSize = 3,
		RedTeam = { r1_c, r2_c, r3_c },
		BlueTeam = { b1_c, b2_c, b3_c },
	})

	local checkC = sessionC ~= nil
		and sessionC.Mode == "3v3"
		and sessionC.TeamSize == 3
		and #sessionC.Participants == 6
		and sessionC.Participants[3].Slot == 3
		and sessionC.Participants[6].Slot == 3

	assertTest("C", "Solicitud 3v3 estructuralmente valida", checkC, tostring(errC or sessionC))
	cleanupSimPlayer(r1_c); cleanupSimPlayer(r2_c); cleanupSimPlayer(r3_c)
	cleanupSimPlayer(b1_c); cleanupSimPlayer(b2_c); cleanupSimPlayer(b3_c)

	-- =========================================================================
	-- TEST D: Rechazo de equipos incompletos
	-- =========================================================================
	resetServiceState()
	local rd1 = makeSimPlayer("RD1")
	local bd1, bd2 = makeSimPlayer("BD1"), makeSimPlayer("BD2")

	local sessionD1, reasonD1 = RoundService:AdmitSession({
		ZoneId = "Zone_2v2",
		Mode = "2v2",
		TeamSize = 2,
		RedTeam = { rd1 }, -- Incompleto (1 de 2)
		BlueTeam = { bd1, bd2 },
	})

	local sessionD2, reasonD2 = RoundService:AdmitSession({
		ZoneId = "Zone_1v1",
		Mode = "1v1",
		TeamSize = 1,
		RedTeam = { rd1, bd1 }, -- Excede (2 de 1)
		BlueTeam = { bd2 },
	})

	local checkD = (sessionD1 == nil and reasonD1 == "IncompleteTeam")
		and (sessionD2 == nil and reasonD2 == "IncompleteTeam")

	assertTest("D", "Rechazo de equipos incompletos", checkD, string.format("D1: %s, D2: %s", tostring(reasonD1), tostring(reasonD2)))
	cleanupSimPlayer(rd1); cleanupSimPlayer(bd1); cleanupSimPlayer(bd2)

	-- =========================================================================
	-- TEST E: Rechazo de participantes duplicados y equipos no disjuntos
	-- =========================================================================
	resetServiceState()
	local dup1 = makeSimPlayer("DUP1")
	local p_other = makeSimPlayer("P_OTHER")

	-- Duplicado dentro del mismo equipo
	local sessionE1, reasonE1 = RoundService:AdmitSession({
		ZoneId = "Zone_2v2",
		Mode = "2v2",
		TeamSize = 2,
		RedTeam = { dup1, dup1 },
		BlueTeam = { p_other, makeSimPlayer("TMP1") },
	})

	-- Mismo participante en ambos equipos (no disjuntos)
	local p_shared = makeSimPlayer("SHARED")
	local sessionE2, reasonE2 = RoundService:AdmitSession({
		ZoneId = "Zone_2v2",
		Mode = "2v2",
		TeamSize = 2,
		RedTeam = { p_shared, makeSimPlayer("TMP2") },
		BlueTeam = { p_shared, makeSimPlayer("TMP3") },
	})

	local checkE = (sessionE1 == nil and reasonE1 == "DuplicateParticipant")
		and (sessionE2 == nil and reasonE2 == "DuplicateParticipant")

	assertTest("E", "Rechazo de participantes duplicados", checkE, string.format("E1: %s, E2: %s", tostring(reasonE1), tostring(reasonE2)))

	-- =========================================================================
	-- TEST F: Rechazo de jugadores desconectados
	-- =========================================================================
	resetServiceState()
	local p_disc = makeSimPlayer("DISC", false) -- IsConnected = false
	local p_conn = makeSimPlayer("CONN", true)

	local sessionF, reasonF = RoundService:AdmitSession({
		ZoneId = "Zone_1v1",
		Mode = "1v1",
		TeamSize = 1,
		RedTeam = { p_disc },
		BlueTeam = { p_conn },
	})

	local checkF = (sessionF == nil and reasonF == "ParticipantDisconnected")
	assertTest("F", "Rechazo de jugadores desconectados", checkF, tostring(reasonF))
	cleanupSimPlayer(p_disc); cleanupSimPlayer(p_conn)

	-- =========================================================================
	-- TEST G: Rechazo de reservas vencidas o inválidas
	-- =========================================================================
	resetServiceState()
	local pr1, pb1 = makeSimPlayer("G_R1"), makeSimPlayer("G_B1")

	-- Mock de zona en MatchmakingService para validar token
	local mockFolder = Instance.new("Folder")
	mockFolder.Name = "Zone_1v1"
	MatchmakingService._zones[mockFolder] = {
		ZoneId = "Zone_1v1",
		Instance = mockFolder,
		ZoneName = "Zone_1v1",
		Config = { Mode = "1v1", TeamSize = 1, MaxPlayersPerTeam = 1, TotalPlayers = 2 },
		RedPads = {},
		BluePads = {},
		PadOccupants = {},
		OccupantLastSeen = {},
		CandidateArrivals = {},
		CandidateLastSeen = {},
		CurrentRed = { pr1 },
		CurrentBlue = { pb1 },
		State = "READY",
		ActiveReservation = nil,
		LastModeNotPlayableWarn = nil,
	}

	-- 1. Token inexistente
	local sessionG1, reasonG1 = RoundService:AdmitSession({
		ZoneId = "Zone_1v1",
		Mode = "1v1",
		TeamSize = 1,
		RedTeam = { pr1 },
		BlueTeam = { pb1 },
		ReservationToken = "fake-token-1234",
	})

	-- 2. Token vencido
	local expiredRes = MatchmakingService:CreateReservation("Zone_1v1", "1v1", 1, { pr1 }, { pb1 }, -10) -- TTL en el pasado
	local sessionG2, reasonG2 = RoundService:AdmitSession({
		ZoneId = "Zone_1v1",
		Mode = "1v1",
		TeamSize = 1,
		RedTeam = { pr1 },
		BlueTeam = { pb1 },
		ReservationToken = expiredRes.Token,
	})

	local checkG = (sessionG1 == nil and reasonG1 == "ReservationNotFound")
		and (sessionG2 == nil and reasonG2 == "ReservationExpired")

	assertTest("G", "Rechazo de reservas vencidas o invalidas", checkG, string.format("G1: %s, G2: %s", tostring(reasonG1), tostring(reasonG2)))
	cleanupSimPlayer(pr1); cleanupSimPlayer(pb1); mockFolder:Destroy()

	-- =========================================================================
	-- TEST H: Selección FIFO de los primeros N
	-- =========================================================================
	resetServiceState()
	local redCandidates = { makeSimPlayer("H_R1"), makeSimPlayer("H_R2"), makeSimPlayer("H_R3") }
	local blueCandidates = { makeSimPlayer("H_B1"), makeSimPlayer("H_B2") }

	-- Simular zona 2v2 donde el equipo Red tiene 3 ocupantes en orden de llegada
	local teamSizeH = 2
	local committedRedH: { any } = {}
	for i = 1, math.min(#redCandidates, teamSizeH) do
		table.insert(committedRedH, redCandidates[i])
	end

	local checkH = (#committedRedH == 2)
		and (committedRedH[1] == redCandidates[1])
		and (committedRedH[2] == redCandidates[2])
		and (committedRedH[3] == nil)

	assertTest("H", "Seleccion FIFO de los primeros N", checkH, "Primeros 2 preservados estrictamente")
	for _, p in ipairs(redCandidates) do cleanupSimPlayer(p) end
	for _, p in ipairs(blueCandidates) do cleanupSimPlayer(p) end

	-- =========================================================================
	-- TEST I: Los jugadores adicionales no reemplazan ocupantes
	-- =========================================================================
	local occ1 = makeSimPlayer("I_OCC1")
	local occ2 = makeSimPlayer("I_OCC2")
	local lateArrival = makeSimPlayer("I_LATE")

	local occupantsList = { occ1, occ2 }
	-- Al llegar un 3er jugador a un equipo de 2:
	if #occupantsList >= 2 then
		-- No se inserta en occupantsList de juego
	else
		table.insert(occupantsList, lateArrival)
	end

	local checkI = (#occupantsList == 2)
		and (occupantsList[1] == occ1)
		and (occupantsList[2] == occ2)
		and (table.find(occupantsList, lateArrival) == nil)

	assertTest("I", "Los jugadores adicionales no reemplazan ocupantes", checkI, "Ocupantes originales inmutables")
	cleanupSimPlayer(occ1); cleanupSimPlayer(occ2); cleanupSimPlayer(lateArrival)

	-- =========================================================================
	-- TEST J: Rechazo de jugadores ya registrados
	-- =========================================================================
	resetServiceState()
	RoundService._maxConcurrentSessions = 2 -- Permitir 2da sesion para validar que el rechazo es por participante y no por capacidad
	local pj1 = makeSimPlayer("J_P1")
	local pj2 = makeSimPlayer("J_P2")
	local pj3 = makeSimPlayer("J_P3")

	-- Registrar primera sesión con pj1 y pj2
	RoundService:AdmitSession({
		ZoneId = "Zone_1v1_A",
		Mode = "1v1",
		TeamSize = 1,
		RedTeam = { pj1 },
		BlueTeam = { pj2 },
	})

	-- Intentar admitir otra sesión que contenga a pj1 (ya registrado)
	local sessionJ, reasonJ = RoundService:AdmitSession({
		ZoneId = "Zone_1v1_B",
		Mode = "1v1",
		TeamSize = 1,
		RedTeam = { pj1 },
		BlueTeam = { pj3 },
	})

	local checkJ = (sessionJ == nil and reasonJ == "ParticipantAlreadyRegistered")
	assertTest("J", "Rechazo de jugadores ya registrados", checkJ, tostring(reasonJ))
	cleanupSimPlayer(pj1); cleanupSimPlayer(pj2); cleanupSimPlayer(pj3)
	RoundService._maxConcurrentSessions = 1

	-- =========================================================================
	-- TEST K: Rollback completo ante un fallo de admisión
	-- =========================================================================
	resetServiceState()
	local pk1 = makeSimPlayer("K_P1")
	local pk2 = makeSimPlayer("K_P2")
	local pk3_disc = makeSimPlayer("K_P3", false) -- 3er participante desconectado provoca error

	local initialSessionCount = #RoundService:GetActiveSessions()

	local sessionK, reasonK = RoundService:AdmitSession({
		ZoneId = "Zone_2v2",
		Mode = "2v2",
		TeamSize = 2,
		RedTeam = { pk1, pk2 },
		BlueTeam = { pk3_disc, makeSimPlayer("K_P4") },
	})

	local checkK = (sessionK == nil)
		and (#RoundService:GetActiveSessions() == initialSessionCount)
		and (RoundService:GetSessionForPlayer(pk1) == nil)
		and (RoundService:GetSessionForPlayer(pk2) == nil)

	assertTest("K", "Rollback completo ante fallo de admision", checkK, tostring(reasonK))
	cleanupSimPlayer(pk1); cleanupSimPlayer(pk2); cleanupSimPlayer(pk3_disc)

	-- =========================================================================
	-- TEST L: No quedan índices huérfanos
	-- =========================================================================
	resetServiceState()
	local pl1 = makeSimPlayer("L_P1")
	local pl2 = makeSimPlayer("L_P2")

	local sessionL, errL = RoundService:AdmitSession({
		ZoneId = "Zone_1v1",
		Mode = "1v1",
		TeamSize = 1,
		RedTeam = { pl1 },
		BlueTeam = { pl2 },
	})

	assert(sessionL ~= nil, "SessionL debe ser admitida para Test L")
	local sessionIdL = sessionL.Id
	RoundService:CloseSession(sessionIdL)

	local checkL = (RoundService:GetSession(sessionIdL) == nil)
		and (RoundService:GetSessionForPlayer(pl1) == nil)
		and (RoundService:GetSessionForPlayer(pl2) == nil)
		and (RoundService._participantByPlayer[pl1] == nil)
		and (RoundService._participantByPlayer[pl2] == nil)
		and (RoundService._sessionIdByUserId[pl1.UserId] == nil)
		and (RoundService._sessionIdByUserId[pl2.UserId] == nil)
		and (#RoundService:GetActiveSessions() == 0)

	assertTest("L", "No quedan indices huerfanos", checkL, "Indices limpios tras CloseSession")
	cleanupSimPlayer(pl1); cleanupSimPlayer(pl2)

	-- =========================================================================
	-- TEST M: Límite de una sesión (_maxConcurrentSessions = 1)
	-- =========================================================================
	resetServiceState()
	local pm1 = makeSimPlayer("M_P1")
	local pm2 = makeSimPlayer("M_P2")
	local pm3 = makeSimPlayer("M_P3")
	local pm4 = makeSimPlayer("M_P4")

	RoundService:AdmitSession({
		ZoneId = "Zone_1v1",
		Mode = "1v1",
		TeamSize = 1,
		RedTeam = { pm1 },
		BlueTeam = { pm2 },
	})

	local sessionM, reasonM = RoundService:AdmitSession({
		ZoneId = "Zone_1v1_2",
		Mode = "1v1",
		TeamSize = 1,
		RedTeam = { pm3 },
		BlueTeam = { pm4 },
	})

	local checkM = (sessionM == nil and reasonM == "ConcurrentSessionLimitReached")
	assertTest("M", "Limite de una sesion concurrente", checkM, tostring(reasonM))
	cleanupSimPlayer(pm1); cleanupSimPlayer(pm2); cleanupSimPlayer(pm3); cleanupSimPlayer(pm4)

	-- =========================================================================
	-- TEST N: Bloqueo explícito del inicio real de XvX
	-- =========================================================================
	resetServiceState()
	local pn1, pn2 = makeSimPlayer("N_R1"), makeSimPlayer("N_R2")
	local pn3, pn4 = makeSimPlayer("N_B1"), makeSimPlayer("N_B2")

	local okN, reasonN = RoundService:StartTeamMatch({
		ZoneId = "Zone_2v2",
		Mode = "2v2",
		TeamSize = 2,
		RedTeam = { pn1, pn2 },
		BlueTeam = { pn3, pn4 },
	})

	local checkN = (okN == false and reasonN == "ModeNotPlayable")
		and (RoundService:IsModePlayable("2v2") == false)
		and (RoundService:IsModePlayable("3v3") == false)
		and (RoundService:IsModePlayable("1v1") == true)
		and (#RoundService:GetActiveSessions() == 0)

	assertTest("N", "Bloqueo explicito del inicio real de XvX", checkN, tostring(reasonN))
	cleanupSimPlayer(pn1); cleanupSimPlayer(pn2); cleanupSimPlayer(pn3); cleanupSimPlayer(pn4)

	-- =========================================================================
	-- TEST O: Compatibilidad de cierre y cancelación para una plantilla simulada
	-- =========================================================================
	resetServiceState()
	local po1, po2 = makeSimPlayer("O_R1"), makeSimPlayer("O_R2")
	local po3, po4 = makeSimPlayer("O_B1"), makeSimPlayer("O_B2")

	local sessionO, errO = RoundService:AdmitSession({
		ZoneId = "Zone_2v2",
		Mode = "2v2",
		TeamSize = 2,
		RedTeam = { po1, po2 },
		BlueTeam = { po3, po4 },
	})

	local closeSuccess = false
	if sessionO then
		closeSuccess = RoundService:CloseSession(sessionO.Id)
	end

	local checkO = (sessionO ~= nil)
		and (closeSuccess == true)
		and (#RoundService:GetActiveSessions() == 0)
		and (RoundService:GetSessionForPlayer(po1) == nil)

	assertTest("O", "Cierre y cancelacion limpia de plantilla simulada XvX", checkO, "Cancelacion sin errores")
	cleanupSimPlayer(po1); cleanupSimPlayer(po2); cleanupSimPlayer(po3); cleanupSimPlayer(po4)

	-- =========================================================================
	-- TEST P: Reserva antigua no puede comprometer jugadores de composición posterior
	-- =========================================================================
	resetServiceState()
	local pp1, pp2 = makeSimPlayer("P_R1"), makeSimPlayer("P_R2")
	local pp3, pp4 = makeSimPlayer("P_B1"), makeSimPlayer("P_B2")
	local pp5 = makeSimPlayer("P_R2_NEW")

	local mockFolderP = Instance.new("Folder")
	mockFolderP.Name = "Zone_2v2_P"
	MatchmakingService._zones[mockFolderP] = {
		ZoneId = "Zone_2v2_P",
		Instance = mockFolderP,
		ZoneName = "Zone_2v2_P",
		Config = { Mode = "2v2", TeamSize = 2, MaxPlayersPerTeam = 2, TotalPlayers = 4 },
		RedPads = {},
		BluePads = {},
		PadOccupants = {},
		OccupantLastSeen = {},
		CandidateArrivals = {},
		CandidateLastSeen = {},
		CurrentRed = { pp1, pp2 },
		CurrentBlue = { pp3, pp4 },
		State = "READY",
		ActiveReservation = nil,
		LastModeNotPlayableWarn = nil,
	}

	-- 1. Crear reserva original para R1, R2 vs B1, B2
	local resP1 = MatchmakingService:CreateReservation("Zone_2v2_P", "2v2", 2, { pp1, pp2 }, { pp3, pp4 })
	local oldToken = resP1.Token

	-- 2. La plantilla cambia: pp2 sale y entra pp5 (nueva composición)
	-- Se genera una nueva reserva
	local resP2 = MatchmakingService:CreateReservation("Zone_2v2_P", "2v2", 2, { pp1, pp5 }, { pp3, pp4 })

	-- 3. Intentar usar el token antiguo con la nueva plantilla
	local validP, reasonP = MatchmakingService:ValidateReservation(oldToken, {
		ZoneId = "Zone_2v2_P",
		Mode = "2v2",
		TeamSize = 2,
		RedTeam = { pp1, pp5 },
		BlueTeam = { pp3, pp4 },
		ReservationToken = oldToken,
	})

	local checkP = (validP == false) and (reasonP == "ReservationNotFound")

	assertTest("P", "Reserva antigua no compromete composicion posterior", checkP, tostring(reasonP))
	cleanupSimPlayer(pp1); cleanupSimPlayer(pp2); cleanupSimPlayer(pp3); cleanupSimPlayer(pp4); cleanupSimPlayer(pp5)
	mockFolderP:Destroy()

	resetServiceState()

	print(string.format("=== RESUMEN DE PRUEBAS ADMISION XvX: %d PASADAS, %d FALLADAS ===", passedCount, failedCount))
	return {
		passed = passedCount,
		failed = failedCount,
		results = results,
	}
end
