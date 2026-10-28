--!strict
local Contract = {}
function Contract.IsFeedbackState(state: string): boolean
 return state == "Playing" or state == "PointRestartCountdown"
end
-- Project the actual touching limb onto the closest face of the oriented sensor.
function Contract.ImpactCFrame(sensor: CFrame, size: Vector3, point: Vector3): CFrame
 local p = sensor:PointToObjectSpace(point)
 local h = size * .5
 local q = Vector3.new(math.clamp(p.X,-h.X,h.X), math.clamp(p.Y,-h.Y,h.Y), math.clamp(p.Z,-h.Z,h.Z))
 if math.abs(p.X)<=h.X and math.abs(p.Y)<=h.Y and math.abs(p.Z)<=h.Z then
  local dx,dy,dz = h.X-math.abs(p.X),h.Y-math.abs(p.Y),h.Z-math.abs(p.Z)
  if dy<=dx and dy<=dz then q=Vector3.new(q.X,p.Y>=0 and h.Y or -h.Y,q.Z)
  elseif dx<=dz then q=Vector3.new(p.X>=0 and h.X or -h.X,q.Y,q.Z)
  else q=Vector3.new(q.X,q.Y,p.Z>=0 and h.Z or -h.Z) end
 end
 return CFrame.new(sensor:PointToWorldSpace(q))
end
function Contract.ResolveEffect(playerService: any, victim: any, credited: boolean, catalog: any, settings: any): string
 if not credited then return settings.DefaultFallEffectId end
 local selected = playerService:GetEquippedItem(victim, "DeathEffects")
 local definition = type(selected)=="string" and catalog[selected]
 if definition and selected~=settings.DefaultFallEffectId
  and (not definition.RequiredOwnership or playerService:HasItem(victim,"DeathEffects",selected)) then
  return selected
 end
 return settings.DefaultKillEffectId
end
return Contract
