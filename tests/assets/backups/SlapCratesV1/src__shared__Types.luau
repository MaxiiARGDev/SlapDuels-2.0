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

export type SessionId = string

export type MatchMode = string

export type MatchTeamName = "Red" | "Blue"

export type SessionParticipantState = "Reserved" | "Active" | "Left" | "Released"

export type SessionParticipant = {
	Player: Player,
	UserId: number,
	Team: MatchTeamName,
	Slot: number,
	State: SessionParticipantState,
	MatchStats: { Goals: number, Kills: number, Deaths: number }?,
}

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

export type TeamMatchAdmissionRequest = {
	ZoneId: string,
	Mode: string,
	TeamSize: number,
	RedTeam: { Player },
	BlueTeam: { Player },
	ReservationToken: string?,
}

export type TeamMatchReservation = {
	Token: string,
	ZoneId: string,
	Mode: string,
	TeamSize: number,
	RedTeam: { Player },
	BlueTeam: { Player },
	CreatedAt: number,
	ExpiresAt: number,
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
	TeamSpawns: {
		Red: { BasePart },
		Blue: { BasePart },
	},
	TeamCapacity: number,
	ZoneWin: Instance?,
	RedWin: BasePart?,
	BlueWin: BasePart?,
	KillParts: { BasePart }?,
	VoidBoundaryPart: BasePart?,
	EndCinematic: Model?,
	ArenaTransform: CFrame?,
}

export type SpawnFailure = {
	Player: Player?,
	UserId: number?,
	Team: MatchTeamName?,
	Slot: number?,
	Reason: string,
}

export type SpawnBatchResult = {
	Success: boolean,
	SessionId: SessionId,
	Required: number,
	Placed: number,
	PlacedPlayers: { Player },
	Failures: { SpawnFailure },
}

export type PlayerVotes = {
	[Player]: string,
}

export type MatchSession = {
	Id: SessionId,
	Mode: MatchMode,
	TeamSize: number,
	ZoneId: string?,
	ReservationToken: string?,
	Participants: { SessionParticipant },
	-- Compatibilidad 1v1 temporal. Participants es el registro autoritativo;
	-- estos arrays y referencias se derivan una sola vez durante la admisión.
	RedPlayer: Player,
	BluePlayer: Player,
	RedTeam: { Player },
	BlueTeam: { Player },
	SelectedMap: string?,
	Result: MatchResultName?,
	StartTime: number?,
	State: RoundStateName,
	StateVersion: number,
	Votes: PlayerVotes,
	SessionThread: thread?,
	PointRestartThread: thread?,
	RemainingTime: number?,
	GameplayRound: any?, -- Server-owned per-round deadline/identity/outcome; no second global timer.
	Closing: boolean,
	Cancelled: boolean,
	Closed: boolean,
	CloseStarted: boolean?,
	CloseSteps: { [string]: boolean }?,
	CloseErrors: { [string]: string }?,
	InstanceInfo: MatchInstanceInfo?,
	Score: MatchScore?,
	-- Alias temporal de ZoneId para los consumidores 1v1 existentes.
	MatchmakingZoneId: string?,
	PointInProgress: boolean?,
	PointScorer: Player?,
	PointScorerTeam: ("Red" | "Blue")?,
	PointScoreTimestamp: number?,
	PointNumber: number?,
	GameplayFrozen: boolean?,
	Results: any?,
	ResultsThread: thread?,
	MatchStatEvents: { [string]: boolean }?,
	EndingCharacters: { [Player]: any }?,
}

export type MatchRewardPayload = {
	MatchId: string,
	WinningTeam: MatchResultName,
	Result: MatchResultName,
	Players: { Player },
}

export type PlayerStats = {
	wins: number,
	losses: number,
	eliminations: number,
}

export type PlayerInventory = {
	Owned: {
		[string]: { [string]: boolean },
	},
	Equipped: {
		[string]: string?,
	},
}

export type PlayerData = {
	Coins: number,
	Wins: number,
	Losses: number,
	Kills: number,
	Inventory: PlayerInventory,
}

export type PlayerDataRecord = {
	Version: number,
	Coins: number,
	Wins: number,
	Losses: number,
	Kills: number,
	Inventory: PlayerInventory,
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
	ImpactCFrame: CFrame?,
	RewardCoins: number?,
	StateVersion: number?,
	ConfirmedAt: number?,
	FeedbackSnapshot: { [string]: any }?,
}

export type DataLoadState = "Loading" | "Loaded" | "Failed" | "Corrupted" | "IncompatibleVersion"

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
	SessionId: string?,
	StateVersion: number?,
	VisualOnly: boolean?,
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

-- ==================================================
-- SHOP FRAMEWORK TYPES
-- ==================================================

export type CurrencyType = "Coins" | "Robux"

export type ProductType = "Cosmetic" | "Consumable" | "Ability"

export type ProductDefinition = {
	-- Campos Obligatorios
	Id: string,
	Category: string,
	ProductType: ProductType,
	DisplayName: string,
	Price: number,
	Currency: CurrencyType,
	IsAvailable: boolean,

	-- Requerido según Currency (Robux)
	RobloxProductId: number?,

	-- Campos Opcionales / Metadata
	Description: string?,
	Rarity: string?,
	AssetId: string?,
	Icon: string?,
	Metadata: { [string]: any }?,
}

export type ProductProvider = {
	GetCategory: (self: ProductProvider) -> string,
	GetProducts: (self: ProductProvider) -> { ProductDefinition },
	GetProduct: (self: ProductProvider, productId: string) -> ProductDefinition?,
	CanPurchase: (self: ProductProvider, player: Player, product: ProductDefinition) -> (boolean, string?),
	CanEquip: (self: ProductProvider, player: Player, product: ProductDefinition) -> (boolean, string?),
	OnPurchased: (self: ProductProvider, player: Player, product: ProductDefinition) -> (boolean, string?),
	OnEquipped: (self: ProductProvider, player: Player, product: ProductDefinition) -> (boolean, string?),
	OnUnequipped: (self: ProductProvider, player: Player, product: ProductDefinition) -> (boolean, string?),
}

return {}

