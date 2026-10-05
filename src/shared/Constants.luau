--!strict
-- Constants
-- Valores semanticos reutilizables. NO implementa logica todavia.

local Constants = {}

Constants.RoundState = {
	Waiting = "Waiting",
	MatchReady = "MatchReady",
	MatchCountdown = "MatchCountdown",
	MapSelection = "MapSelection",
	MapLoading = "MapLoading",
	StartCountdown = "StartCountdown",
	PointRestartCountdown = "PointRestartCountdown",
	Playing = "Playing",
	Ending = "Ending",
	ReturningToLobby = "ReturningToLobby",
}

Constants.CountdownPhase = {
	MatchStart = "MatchStart",
	PointRestart = "PointRestart",
}

Constants.MatchResult = {
	Red = "Red",
	Blue = "Blue",
	Draw = "Draw",
	Cancelled = "Cancelled",
}

Constants.SpecialMapVote = {
	Random = "Random",
}

return Constants
