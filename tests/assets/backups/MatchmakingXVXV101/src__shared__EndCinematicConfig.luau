--!strict
return {
	Transition = { CloseDuration = 0.65, ClosedHoldDuration = 0.35, OpenDuration = 0.65, Color = Color3.fromRGB(5, 5, 8), Angle = 12 },
	Camera = {
		StartPart = "CameraCheck-v1",
		Destinations = { ["1v1"] = "CameraCheck-Only1V1", ["2v2"] = "CameraCheck-v2", ["3v3"] = "CameraCheck-v2", Default = "CameraCheck-v2" },
		TravelDuration = 3.5, HorizontalRotationEnabled = true, HorizontalRotationDegrees = 5,
		ArrivalBounceEnabled = true, ArrivalBounceStrength = 0.08, ArrivalBounceDuration = 0.35,
	},
	Winners = { MaxVisible = 5, WalkAnimationId = "", WalkStartDelay = 0.45, WalkDistance = 2.5, WalkDuration = 2.2, EntryStagger = 0.12, PlatformMargin = 0.3, CameraClearance = 3 },
	Effects = { ConfettiEnabled = true, SoundsEnabled = true, BurstCount = 30, DisabledSounds = {} },
	HUD = { ShowDelay = 0.3, FadeDuration = 0.45 },
	Preview = { Enabled = true },
	Ranking = { Criteria = { "Goals", "Kills", "Deaths" }, Ascending = { Deaths = true }, MaxVisible = 5 },
	Billboards = {
		Enabled = true, ShowIn1v1 = false, ShowMVP = true, ShowUsername = false,
		ShowGoals = true, ShowKills = true, ShowDeaths = true, ShowPoints = true,
		-- Position, size, distance and visual style are authored on physical BillboardAnchors.
		DynamicColors = true, FadeDuration = 0.35, ShowDelay = 0.1,
		RankColors = { Color3.fromRGB(255,210,80), Color3.fromRGB(201,220,241), Color3.fromRGB(223,160,107) },
		TeamColors = { Red = Color3.fromRGB(255,105,117), Blue = Color3.fromRGB(101,176,255) },
	},
	FloatingFollow = {
		Enabled = true, StartAfterArrival = true, LateralAmplitude = 0.12, VerticalAmplitude = 0.08,
		LateralFrequency = 0.45, VerticalFrequency = 0.65, -- radians/second; amplitudes in studs
		FollowEnabled = true, FollowResponsiveness = 3.5, MaxYawDegrees = 1.5, MaxPitchDegrees = 1,
		PreserveBaseDistance = true, DistanceTolerance = 0.15, FieldOfViewLocked = true,
		FadeInDuration = 1.2, FocusHeight = 1.4, MaxTargetStep = 1.5,
	},
	FinalGoal = { CelebrationEnabled = true, CelebrationDuration = 2.5, WaitForFeedback = true, MaxFeedbackWait = 4 },
	TransitionAudio = {
		Enabled = true, CloseSoundId = "126941244422484", OpenSoundId = "123796710194563",
		CloseSoundName = "", OpenSoundName = "", -- optional Sound names inside ScenarioFinal
		CloseVolume = 0.65, OpenVolume = 0.65, ClosePlaybackSpeed = 1, OpenPlaybackSpeed = 1,
		CloseStartOffset = 0, OpenStartOffset = 0,
	},
	Results = { PreparationTimeout = 25, StartLeadTime = 0.5, ViewDuration = 20, SceneWaitTimeout = 12 },
	Music = {
		SuspendDuringCinematic = true,
		FadeOutDuration = 0.4,
		FadeInDuration = 0.6,
	},
}
