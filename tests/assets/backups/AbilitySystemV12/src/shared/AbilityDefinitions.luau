--!strict
-- Commercial prices remain unapproved. Zero in the Shop adapter is a disabled
-- schema placeholder, never an offer. Cooldowns start on accepted activation.
local Definitions = {
 DefaultId = "Dash",
 Category = "Abilities",
 CooldownPolicy = "OnActivation",
 RequestInterval = 0.12,
 SnapshotInterval = 0.25,
 Order = {"Dash", "StrongSlap", "AirJumps", "DevilSpeed", "Invisible"},
 Items = {
  Dash = {Id="Dash", DisplayName="Dash", Type="Movimiento", Description="Impulso horizontal dirigido. E o botón táctil.",
   Cooldown=11, Duration=0.2, DistanceStuds=24, Enabled=true, Price=0, PurchaseEnabled=false, Icon="", Effect="Dash"},
  StrongSlap = {Id="StrongSlap", DisplayName="Golpe Fuerte", Type="Ofensiva", Description="Prepara el próximo impacto válido durante 15 s. Eliminación inmediata.",
   Cooldown=25, Duration=15, Enabled=true, Price=0, PriceApproved=false, PurchaseEnabled=false, Icon="", Effect="StrongSlap", PresentationLift=25},
  AirJumps = {Id="AirJumps", DisplayName="Saltos de Aire", Type="Movilidad", Description="Saltos aéreos moderados durante 15 s; hasta 4 antes de tocar suelo.",
   Cooldown=20, Duration=15, Enabled=true, Price=0, PriceApproved=false, PurchaseEnabled=false, Icon="", Effect="AirJumps",
   AirJumpStrength=32, MinJumpInterval=0.8, MaxConsecutiveAirJumps=4, MaxVerticalVelocity=38, MaxRiseStuds=24},
  DevilSpeed = {Id="DevilSpeed", DisplayName="Velocidad Diabólica", Type="Movilidad", Description="Acelera durante 5 s. El derribo cancela el efecto.",
   Cooldown=14, Duration=5, Enabled=true, Price=0, PriceApproved=false, PurchaseEnabled=false, Icon="", Effect="DevilSpeed",
   SpeedMultiplier=2.4, MaxSpeed=48, Acceleration=100},
  Invisible = {Id="Invisible", DisplayName="Invisible", Type="Sigilo", Description="Oculta avatar y Slap durante 5 s; deja un rastro tenue.",
   Cooldown=35, Duration=5, Enabled=true, Price=0, PriceApproved=false, PurchaseEnabled=false, Icon="", Effect="Invisible"},
 },
}
return Definitions
