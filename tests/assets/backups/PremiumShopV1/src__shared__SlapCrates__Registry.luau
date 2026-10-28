--!nonstrict
-- Only modules explicitly required by Catalog are trusted; never require descendants dynamically.
local Registry = {}
function Registry.Build(definitions, key, validate)
 local result = {Order={}, ById={}}
 for _,definition in ipairs(definitions) do
  local id=definition[key]
  assert(type(id)=="string" and id:match("^[%w_%-]+$"),"InvalidId")
  assert(not result.ById[id],"DuplicateId:"..id)
  assert(type(definition.DisplayName)=="string" and definition.DisplayName~="","InvalidName")
  if validate then validate(definition) end
  result.ById[id]=definition;table.insert(result.Order,id)
 end
 return result
end
return Registry
