--!strict
-- ThunderController (Re-export / alias en Services para compatibilidad)
-- La implementación canónica reside en ServerScriptService.PointEffectControllers.ThunderController
local ServerScriptService = game:GetService("ServerScriptService")
local pec = ServerScriptService:WaitForChild("PointEffectControllers", 10)
local thunderMod = pec and pec:WaitForChild("ThunderController", 10)
assert(thunderMod and thunderMod:IsA("ModuleScript"), "[ThunderController] ModuleScript no encontrado en PointEffectControllers")

return require(thunderMod)
