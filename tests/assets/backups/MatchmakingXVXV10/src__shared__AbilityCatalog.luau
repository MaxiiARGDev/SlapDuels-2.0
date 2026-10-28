--!nonstrict
-- Client cache of plain, server-derived metadata. Never requires server modules.
local Catalog={}
local current=table.freeze({Version=0,Order=table.freeze({}),Items=table.freeze({})})
local function plain(value,depth)
 if depth>12 then return false end
 local kind=type(value)
 if kind=="number" then return value==value and math.abs(value)<math.huge end
 if kind=="string" or kind=="boolean" or kind=="nil" then return true end
 if kind~="table" or getmetatable(value)~=nil then return false end
 for k,v in pairs(value) do if (type(k)~="string" and type(k)~="number") or not plain(v,depth+1) then return false end end
 return true
end
local function freeze(value)
 if type(value)=="table" then for _,v in pairs(value) do freeze(v) end;if not table.isfrozen(value) then table.freeze(value) end end
 return value
end
function Catalog.Apply(snapshot)
 if type(snapshot)~="table" or not plain(snapshot,0) or type(snapshot.Version)~="number"
  or snapshot.Version<=current.Version or type(snapshot.Order)~="table" or #snapshot.Order>100
  or type(snapshot.Items)~="table" or type(snapshot.DefaultId)~="string" then return false end
 local seen={}
 for _,id in ipairs(snapshot.Order) do
  local d=snapshot.Items[id]
  if type(id)~="string" or seen[id] or type(d)~="table" or d.Id~=id or d.Enabled~=true
   or type(d.DisplayName)~="string" or type(d.Description)~="string" or type(d.Icon)~="string"
   or type(d.Duration)~="number" or d.Duration<0 or type(d.Cooldown)~="number" or d.Cooldown<=0
   or type(d.ActiveLabel)~="string" or type(d.Input)~="table" or type(d.Assets)~="table"
   or type(d.Assets.Cues)~="table" or (d.Input.Primary~="None" and d.Input.Primary~="Direction") then return false end
  seen[id]=true
 end
 current=freeze(snapshot);return true
end
function Catalog.Get()return current end
function Catalog.GetItem(id)return current.Items[id]end
return table.freeze(Catalog)
