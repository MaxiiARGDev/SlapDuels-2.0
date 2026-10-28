--!strict
-- Charge consumption occurs only after CombatService confirms the hit.
local Strong = {}
function Strong.Start(record: any): boolean record.State="Armed";return true end
function Strong.Step(_record: any,_dt: number): boolean return true end
function Strong.Cancel(_record: any) end
return Strong
