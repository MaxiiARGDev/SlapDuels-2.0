--!strict
-- Presentation is coordinated only to session recipients. No server transparency,
-- collision, hitbox, health, Tool or sensor changes.
local Invisible = {}
function Invisible.Start(_record: any): boolean return true end
function Invisible.Step(_record: any,_dt: number): boolean return true end
function Invisible.Cancel(_record: any) end
Invisible.Descriptor={Id="Invisible",DisplayName="Invisible",Description="Oculta avatar y Slap durante 5 s; deja un rastro tenue.",Type="Sigilo",
 Duration=5,Cooldown=35,Icon="",SortOrder=50}
Invisible.Enabled=true
Invisible.Config={}
Invisible.ConfigSchema={}
Invisible.Shop={Price=2250,PriceApproved=true,PurchaseEnabled=true}
Invisible.Dependencies={}
Invisible.Input={Primary="None"}
Invisible.Assets={Key="Invisible",Profile="InvisibleAvatar"}
return Invisible
