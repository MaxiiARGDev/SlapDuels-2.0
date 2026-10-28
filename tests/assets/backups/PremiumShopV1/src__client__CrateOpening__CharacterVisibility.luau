--!nonstrict
-- Client-only lease. Only descendants of Players' Characters are eligible.
local Visibility={}
local active
local function disconnect(list)
 for _,connection in ipairs(list)do connection:Disconnect()end
 table.clear(list)
end
local function propertyFor(object)
 if object:IsA("BasePart")then return "LocalTransparencyModifier",1 end
 if object:IsA("Decal")then return "Transparency",1 end
 if object:IsA("ForceField")then return "Visible",false end
 if object:IsA("ParticleEmitter")or object:IsA("Trail")or object:IsA("Beam")
  or object:IsA("BillboardGui")or object:IsA("SurfaceGui")or object:IsA("Highlight")
  or object:IsA("Light")or object:IsA("Fire")or object:IsA("Smoke")or object:IsA("Sparkles")then return "Enabled",false end
 if object:IsA("Humanoid")then return "DisplayDistanceType",Enum.HumanoidDisplayDistanceType.None end
end
local function restore(lease,object)
 local row=lease.Saved[object];if not row then return end
 lease.Saved[object]=nil;row.Connection:Disconnect()
 -- Don't overwrite a newer value if a deferred external write already won.
 pcall(function()if object[row.Property]==row.Applied then object[row.Property]=row.Previous end end)
end
local function hide(lease,character,object)
 if lease.Released or lease.Saved[object]or not object:IsDescendantOf(character)then return end
 local property,value=propertyFor(object);if not property then return end
 local row={Property=property,Applied=value,Previous=object[property],Writing=false,Character=character}
 lease.Saved[object]=row
 row.Connection=object:GetPropertyChangedSignal(property):Connect(function()
  if lease.Released or row.Writing or lease.Saved[object]~=row then return end
  local current=object[property]
  if current~=value then
   row.Previous=current -- Latest observable external intent, including camera transparency.
   row.Writing=true;object[property]=value;row.Writing=false
  end
 end)
 row.Writing=true;object[property]=value;row.Writing=false
 -- Stop already-emitted geometry too; never touch emitters outside Characters.
 if object:IsA("ParticleEmitter")or object:IsA("Trail")then object:Clear()end
end
local function unwatchCharacter(lease,character)
 local connections=lease.Characters[character];if not connections then return end
 lease.Characters[character]=nil;disconnect(connections)
 local objects={};for object,row in pairs(lease.Saved)do if row.Character==character then table.insert(objects,object)end end
 for _,object in ipairs(objects)do restore(lease,object)end
end
local function watchCharacter(lease,character)
 if lease.Released or lease.Characters[character]then return end
 local connections={};lease.Characters[character]=connections
 table.insert(connections,character.DescendantAdded:Connect(function(object)hide(lease,character,object)end))
 table.insert(connections,character.DescendantRemoving:Connect(function(object)restore(lease,object)end))
 for _,object in ipairs(character:GetDescendants())do hide(lease,character,object)end
end
local function unwatchPlayer(lease,player)
 local connections=lease.Players[player];if not connections then return end
 lease.Players[player]=nil;disconnect(connections)
 local characters={};for character,owner in pairs(lease.Owners)do if owner==player then table.insert(characters,character)end end
 for _,character in ipairs(characters)do lease.Owners[character]=nil;unwatchCharacter(lease,character)end
end
local function watchPlayer(lease,player)
 if lease.Released or lease.Players[player]then return end
 local function added(character)
  if lease.Released then return end
  lease.Owners[character]=player;watchCharacter(lease,character)
 end
 lease.Players[player]={player.CharacterAdded:Connect(added),player.CharacterRemoving:Connect(function(character)
  lease.Owners[character]=nil;unwatchCharacter(lease,character)
 end)}
 if player.Character then added(player.Character)end
end
function Visibility.Release(lease)
 if not lease or lease.Released then return end
 lease.Released=true;disconnect(lease.Connections)
 for _,connections in pairs(lease.Players)do disconnect(connections)end
 for _,connections in pairs(lease.Characters)do disconnect(connections)end
 local objects={};for object in pairs(lease.Saved)do table.insert(objects,object)end
 for _,object in ipairs(objects)do restore(lease,object)end
 table.clear(lease.Players);table.clear(lease.Characters);table.clear(lease.Owners)
 if active==lease then active=nil end
end
function Visibility.Acquire(players,id)
 assert(type(id)=="string","OpeningId required")
 if active and active.Id==id then return active end
 Visibility.Release(active)
 local lease={Id=id,Saved={},Players={},Characters={},Owners={},Connections={},Released=false}
 active=lease
 local ok,failure=pcall(function()
  table.insert(lease.Connections,players.PlayerAdded:Connect(function(player)watchPlayer(lease,player)end))
  table.insert(lease.Connections,players.PlayerRemoving:Connect(function(player)unwatchPlayer(lease,player)end))
  for _,player in ipairs(players:GetPlayers())do watchPlayer(lease,player)end
 end)
 if not ok then Visibility.Release(lease);error(failure)end
 return lease
end
return Visibility
