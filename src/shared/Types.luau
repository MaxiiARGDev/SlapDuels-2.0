--!strict
-- Types
-- Definiciones de tipos Luau compartidas para tipado progresivo.

export type RoundStateName =
	"Waiting"
	| "MatchReady"
	| "MatchCountdown"
	| "MapSelection"
	| "MapLoading"
	| "StartCountdown"
	| "PointRestartCountdown"
	| "Playing"
	| "Ending"
	| "ReturningToLobby"

export type CountdownPhase = "MatchStart" | "PointRestart"

export type StartCountdownPayload = {
	MatchId: string,
	Value: number,
	Started: boolean?,
	Phase: CountdownPhase?,
}

export type MatchResultName = "Red" | "Blue" | "Draw" | "Cancelled"

export type QueueStateName = "WAITING" | "READY"

export type MatchmakingZoneConfig = {
	Mode: string,
	TeamSize: number,
	MaxPlayersPerTeam: number,
	TotalPlayers: number,
}

export type QueueSnapshot = {
	ZoneId: string,
	ZoneName: string,
	Mode: string,
	TeamSize: number,
	MaxPlayersPerTeam: number,
	TotalPlayers: number,
	Red: { Player },
	Blue: { Player },
	State: QueueStateName,
}

export type MatchScore = {
	Red: number,
	Blue: number,
}

export type MatchInstanceInfo = {
	MatchId: string,
	MapName: string,
	ArenaSlot: number,
	Origin: Vector3,
	InstanceModel: Model,
	Container: Instance,
	Geometry: Instance,
	RedSpawn: BasePart,
	BlueSpawn: BasePart,
	ZoneWin: Instance?,
	RedWin: BasePart?,
	BlueWin: BasePart?,
	KillParts: { BasePart }?,
}

export type MatchSession = {
	Id: string,
	Mode: string,
	RedPlayer: Player,
	BluePlayer: Player,
	RedTeam: { Player }?,
	BlueTeam: { Player }?,
	SelectedMap: string?,
	Result: MatchResultName?,
	StartTime: number?,
	State: RoundStateName,
	InstanceInfo: MatchInstanceInfo?,
	Score: MatchScore?,
	MatchmakingZoneId: string?,
	PointInProgress: boolean?,
	PointScorer: Player?,
	PointScorerTeam: ("Red" | "Blue")?,
	PointScoreTimestamp: number?,
	PointNumber: number?,
}

export type MatchRewardPayload = {
	MatchId: string,
	WinningTeam: MatchResultName,
	Result: MatchResultName,
	Players: { Player },
}

export type PlayerVotes = {
	[Player]: string,
}

export type PlayerStats = {
	wins: number,
	losses: number,
	eliminations: number,
}

export type PlayerData = {
	Coins: number,
	Wins: number,
	Losses: number,
	Kills: number,
}

export type PlayerDataRecord = {
	Version: number,
	Coins: number,
	Wins: number,
	Losses: number,
	Kills: number,
	LastSaved: number?,
}

export type CombatTag = {
	Victim: Player,
	Attacker: Player,
	MatchId: string,
	Timestamp: number,
	HitId: string?,
}

export type CombatHitHistoryItem = {
	Attacker: Player,
	Timestamp: number,
	Damage: number?,
}

export type EliminationRecord = {
	Victim: Player,
	Killer: Player?,
	MatchId: string,
	Timestamp: number,
	Reason: string,
	EliminationId: string,
}

export type DataLoadState = "Loading" | "Loaded" | "Failed"

export type PointEffectRarity = "Common" | "Rare" | "Epic" | "Legendary"

export type PointEffectDefinition = {
	Id: string,
	DisplayName: string,
	Rarity: PointEffectRarity,
	Price: number,
	Description: string?,
}

export type PointFeedbackPayload = {
	PointId: string,
	MatchId: string,
	ScoringTeam: "Red" | "Blue",
	ScoringPlayer: Player?,
	ScoringZone: BasePart,
	IsFinalPoint: boolean,
	RedScore: number,
	BlueScore: number,
}

export type PointFeedbackBroadcast = {
	MatchId: string,
	PointId: string,
	ScoringTeam: "Red" | "Blue",
	ScoringPlayerName: string,
	ScoringZonePosition: Vector3,
	EffectId: string,
	IsFinalPoint: boolean,
	RedScore: number,
	BlueScore: number,
}

export type Service = {
	Name: string?,
	Init: (self: Service, context: { [string]: any }?) -> (),
	Start: (self: Service, context: { [string]: any }?) -> (),
}

return {}

