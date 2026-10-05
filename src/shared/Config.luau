--!strict
-- Config
-- Configuracion general del juego. Los valores son PLACEHOLDER y se ajustaran en fases posteriores.

local Config = {}

Config.Round = {
	MatchCountdownTime = 5,
	MapSelectionTime = 5,
	RoundDuration = 300,
	EndingDisplayTime = 4,
	ReturnToLobbyTime = 2,
}

Config.Match = {
	WinningScore = 5,
	PointReward = 50,
	PointResetDelay = 1.5,
	StartCountdownTime = 5,
	PointRestartCountdownTime = 3,
}

Config.PointRestartCountdownEffects = {
	["3"] = {
		ShakeStuds = 0.25,
		ShakeRotationDeg = 1.0,
		ShakeDuration = 0.30,
		FlashTransparency = 0.80,
		FlashFadeDuration = 0.20,
		BlurSize = 3.5,
		BlurDuration = 0.25,
		PulseScale = 1.8,
		PulseDuration = 0.25,
		NumberScale = 1.30,
		SoundName = "CountdownTick",
		SoundVolume = 0.75,
		SoundPlaybackSpeed = 1.05,
	},
	["2"] = {
		ShakeStuds = 0.40,
		ShakeRotationDeg = 1.5,
		ShakeDuration = 0.35,
		FlashTransparency = 0.65,
		FlashFadeDuration = 0.25,
		BlurSize = 5.0,
		BlurDuration = 0.30,
		PulseScale = 2.2,
		PulseDuration = 0.30,
		NumberScale = 1.38,
		SoundName = "CountdownHeavy",
		SoundVolume = 0.90,
		SoundPlaybackSpeed = 1.05,
	},
	["1"] = {
		ShakeStuds = 0.55,
		ShakeRotationDeg = 2.0,
		ShakeDuration = 0.40,
		FlashTransparency = 0.50,
		FlashFadeDuration = 0.30,
		BlurSize = 7.0,
		BlurDuration = 0.35,
		PulseScale = 2.5,
		PulseDuration = 0.35,
		NumberScale = 1.45,
		SoundName = "CountdownFinal",
		SoundVolume = 1.05,
		SoundPlaybackSpeed = 1.10,
	},
	["GO"] = {
		ShakeStuds = 0.85,
		ShakeRotationDeg = 2.8,
		ShakeDuration = 0.55,
		FlashTransparency = 0.20,
		FlashFadeDuration = 0.45,
		BlurSize = 9.0,
		BlurDuration = 0.50,
		PulseScale = 2.6,
		PulseDuration = 0.45,
		ShockwaveScale = 3.2,
		ShockwaveDuration = 0.50,
		NumberScale = 1.40,
		WhooshSoundName = "StartWhoosh",
		ImpactSoundName = "StartImpact",
		SoundVolume = 1.20,
		SequenceTotalDuration = 0.55,
	},
}

Config.StartCountdownEffects = {
	["5"] = {
		ShakeStuds = 0.12,
		ShakeRotationDeg = 0.5,
		ShakeDuration = 0.35,
		FlashTransparency = 0.90,
		FlashFadeDuration = 0.25,
		BlurSize = 2,
		BlurDuration = 0.30,
		PulseScale = 1.5,
		PulseDuration = 0.30,
		NumberScale = 1.25,
		SoundName = "CountdownTick",
		SoundVolume = 0.60,
		SoundPlaybackSpeed = 1.0,
	},
	["4"] = {
		ShakeStuds = 0.18,
		ShakeRotationDeg = 0.7,
		ShakeDuration = 0.35,
		FlashTransparency = 0.88,
		FlashFadeDuration = 0.25,
		BlurSize = 2.5,
		BlurDuration = 0.30,
		PulseScale = 1.6,
		PulseDuration = 0.30,
		NumberScale = 1.28,
		SoundName = "CountdownTick",
		SoundVolume = 0.65,
		SoundPlaybackSpeed = 1.05,
	},
	["3"] = {
		ShakeStuds = 0.25,
		ShakeRotationDeg = 1.0,
		ShakeDuration = 0.40,
		FlashTransparency = 0.82,
		FlashFadeDuration = 0.30,
		BlurSize = 3.5,
		BlurDuration = 0.35,
		PulseScale = 1.8,
		PulseDuration = 0.35,
		NumberScale = 1.32,
		SoundName = "CountdownTick",
		SoundVolume = 0.70,
		SoundPlaybackSpeed = 1.10,
	},
	["2"] = {
		ShakeStuds = 0.38,
		ShakeRotationDeg = 1.5,
		ShakeDuration = 0.45,
		FlashTransparency = 0.70,
		FlashFadeDuration = 0.35,
		BlurSize = 5.0,
		BlurDuration = 0.40,
		PulseScale = 2.0,
		PulseDuration = 0.40,
		NumberScale = 1.38,
		SoundName = "CountdownHeavy",
		SoundVolume = 0.85,
		SoundPlaybackSpeed = 1.0,
	},
	["1"] = {
		ShakeStuds = 0.55,
		ShakeRotationDeg = 2.0,
		ShakeDuration = 0.50,
		FlashTransparency = 0.55,
		FlashFadeDuration = 0.40,
		BlurSize = 7.0,
		BlurDuration = 0.45,
		PulseScale = 2.3,
		PulseDuration = 0.45,
		NumberScale = 1.45,
		SoundName = "CountdownFinal",
		SoundVolume = 1.0,
		SoundPlaybackSpeed = 1.0,
	},
	["GO"] = {
		ShakeStuds = 0.90,
		ShakeRotationDeg = 3.0,
		ShakeDuration = 0.70,
		FlashTransparency = 0.18,
		FlashFadeDuration = 0.50,
		BlurSize = 10.0,
		BlurDuration = 0.60,
		PulseScale = 2.8,
		PulseDuration = 0.50,
		ShockwaveScale = 3.5,
		ShockwaveDuration = 0.55,
		NumberScale = 1.40,
		WhooshSoundName = "StartWhoosh",
		ImpactSoundName = "StartImpact",
		SoundVolume = 1.25,
		SequenceTotalDuration = 0.70,
	},
}

Config.Economy = {
	StartingCoins = 0,
	StartingWins = 0,
	StartingLosses = 0,
	StartingKills = 0,
}

Config.DataStore = {
	Name = "SlapDuels_PlayerData_v1",
	CurrentVersion = 1,
	MaxRetries = 3,
	InitialRetryDelay = 1.0,
	RetryBackoffMultiplier = 2.0,
}

Config.Combat = {
	SlapCooldown = 0.6,
	KnockbackForce = 45,
	LastHitLifetime = 10, -- Segundos de validez para otorgar la Kill al último atacante
}

Config.Ragdoll = {
	BlastRadius = 100,      -- Radio en studs alcanzado por la onda de choque del punto
	BlastForce = 110,      -- Magnitud del impulso de despegue
	UpwardRatio = 1,    -- 100% componente vertical prioritaria (fuerte impulso hacia arriba por los aires)
	DefaultDuration = 5.0, -- Segundos en estado muñeco de trapo antes de reincorporarse
}

Config.Arena = {
	BaseOrigin = Vector3.new(10000, 500, 0),
	Spacing = Vector3.new(10000, 0, 0),
	MaxSlots = 100,
	VoidBoundarySize = Vector3.new(500, 4, 500),
	VoidBoundaryOffset = Vector3.new(0, -50, 0),
	VoidBoundaryPollInterval = 0.2, -- Intervalo de chequeo fail-safe para caídas al vacío (segundos)
}

Config.Matchmaking = {
	DefaultMode = "1v1",
	Modes = {
		["1v1"] = {
			Mode = "1v1",
			TeamSize = 1,
			MaxPlayersPerTeam = 1,
			TotalPlayers = 2,
		},
		["2v2"] = {
			Mode = "2v2",
			TeamSize = 2,
			MaxPlayersPerTeam = 2,
			TotalPlayers = 4,
		},
		["3v3"] = {
			Mode = "3v3",
			TeamSize = 3,
			MaxPlayersPerTeam = 3,
			TotalPlayers = 6,
		},
	},
}

return Config
