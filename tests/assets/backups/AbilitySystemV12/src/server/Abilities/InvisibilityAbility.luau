--!strict
-- Presentation is coordinated only to session recipients. No server transparency,
-- collision, hitbox, health, Tool or sensor changes.
local Invisible = {}
function Invisible.Start(_record: any): boolean return true end
function Invisible.Step(_record: any,_dt: number): boolean return true end
function Invisible.Cancel(_record: any) end
return Invisible
