--!strict
return {
 DeathEffects = {
  Enabled = true, DefaultFallEffectId = "DefaultFall", DefaultKillEffectId = "BasicKill",
  MaxDuration = 4, MaxConcurrentEffects = 6, ParticlesEnabled = true, SoundsEnabled = true,
 },
 Notifications = {
  Enabled = true, MaxVisible = 4, DisplayDuration = 2.8, FadeInDuration = .18,
  FadeOutDuration = .3, LocalSoundId = "", LocalSoundVolume = .25, -- empty ID uses the authored HUD Sound
 },
 CoinRewardAnimation = {
  Enabled = true, CoinCount = 7, Stagger = .055, FlightDuration = .65, ArcHeight = 95,
  SoundId = "", SoundVolume = .35, ArrivalPulse = 1.2, -- empty ID uses the authored HUD Sound
 },
 EventLifetime = 5,
}
