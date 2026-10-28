--!strict
local Policy = {}
-- Touched may already be queued when a teleport finishes. Reject callbacks far from their sensor.
function Policy.IsContactCurrent(sensorFrame: CFrame, sensorSize: Vector3, partPosition: Vector3, partSize: Vector3): boolean
 local point=sensorFrame:PointToObjectSpace(partPosition)
 local half=sensorSize*.5
 local radius=partSize.Magnitude*.5
 return math.abs(point.X)<=half.X+radius and math.abs(point.Y)<=half.Y+radius and math.abs(point.Z)<=half.Z+radius
end
function Policy.NormalizeDelayMs(value: any, maximum: any): (number, boolean)
 if type(maximum)~="number" or maximum~=maximum or maximum<0 or maximum==math.huge then return 0,false end
 if type(value)~="number" or value~=value or value<0 or value==math.huge then return 0,false end
 local normalized=math.min(math.floor(value),math.floor(maximum))
 return normalized,normalized==value
end
function Policy.IsCurrent(record: any, session: any, character: any, generation: any): boolean
 return record~=nil and session~=nil and session==record.Session and character==record.Character
  and generation==record.Generation and session.StateVersion==record.StateVersion
  and session.State=="Playing" and not session.Closing and not session.Cancelled
  and not session.Closed and not session.GameplayFrozen and not session.PointInProgress
end
return Policy
