--!strict
-- Authored reference markers; never moves them or requires collidable surfaces.
local Resolver = {}
local function positiveInteger(value: any): boolean
 return type(value)=="number" and value>0 and value<math.huge and value%1==0
end
function Resolver.Resolve(map: Instance, required: number?): (any?, number, string?)
 local count=required or 1
 if not positiveInteger(count) then return nil,0,"InvalidRequiredTeamSize" end
 local result={Red={},Blue={}}
 local capacity=math.huge
 for _,team in ipairs({"Red","Blue"}) do
  local folder=map:FindFirstChild(team.."Team")
  if not folder or not folder:IsA("Folder") then return nil,0,"MissingTeamFolder:"..team.."Team" end
  local slots={};local highest=0
  for _,part in ipairs(folder:GetChildren()) do
   local raw=part.Name:match("^Spawn([1-9]%d*)$")
   if raw then
    local slot=tonumber(raw)
    if not slot or not positiveInteger(slot) or slot>1024 then return nil,0,"InvalidSpawnIndex:"..part.Name end
    if slots[slot] then return nil,0,"DuplicateSpawn:"..team.."Team/"..part.Name end
    if not part:IsA("BasePart") then return nil,0,"InvalidSpawnPart:"..team.."Team/"..part.Name end
    slots[slot]=part;highest=math.max(highest,slot)
   end
  end
  for slot=1,math.max(count,highest) do
   local part=slots[slot]
   if not part then return nil,0,"MissingSpawn:"..team.."Team/Spawn"..slot end
   table.insert(result[team],part)
  end
  capacity=math.min(capacity,#result[team])
 end
 return result,capacity,nil
end
return Resolver
