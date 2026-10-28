--!nonstrict
local Registry={}
local types={Player=true,Integer=true,Slap=true}
function Registry.Build(manifest,loadApproved)
 local out={ById={},Order={}}
 for _,name in ipairs(manifest)do
  assert(type(name)=='string'and name:match('^%w+$'),'Invalid admin manifest entry')
  local command=loadApproved(name)
  assert(type(command)=='table'and command.Id==name and not out.ById[name],'Invalid/duplicate admin command')
  assert(type(command.DisplayName)=='string'and type(command.Description)=='string'and type(command.Execute)=='function'and type(command.Fields)=='table','Invalid admin contract')
  local names={};local target=false
  for _,field in ipairs(command.Fields)do
   assert(type(field.Name)=='string'and not names[field.Name]and types[field.Type]and type(field.Label)=='string','Invalid/duplicate admin field')
   if field.Type=='Integer'then assert(type(field.Min)=='number'and type(field.Max)=='number'and field.Min>=0 and field.Max>=field.Min and field.Max<9007199254740992,'Invalid integer bounds')end
   if field.Name=='TargetUserId'and field.Type=='Player'then target=true end
   names[field.Name]=true
  end
  assert(target,'Admin command requires an explicit target player')
  out.ById[name]=command;table.insert(out.Order,name)
 end
 return out
end
function Registry.Public(registry)
 local result={}
 for _,id in ipairs(registry.Order)do local c=registry.ById[id];local fields={}
  for _,f in ipairs(c.Fields)do table.insert(fields,{Name=f.Name,Label=f.Label,Type=f.Type,Min=f.Min,Max=f.Max})end
  table.insert(result,{Id=c.Id,DisplayName=c.DisplayName,Description=c.Description,Fields=fields})
 end
 return result
end
function Registry.Validate(command,args,deps)
 if type(args)~='table'then return false,'InvalidArguments'end
 local expected={};local clean={}
 for _,field in ipairs(command.Fields)do
  expected[field.Name]=true;local value=args[field.Name]
  if field.Type=='Player'then
   if type(value)~='number'or value~=value or value%1~=0 or value==0 or math.abs(value)>=9007199254740992 or (not deps.IsStudio and value<0)then return false,'InvalidTarget'end
   if not deps.Player(value)then return false,'PlayerNotConnected'end
  elseif field.Type=='Integer'then
   if type(value)~='number'or value~=value or value%1~=0 or value<field.Min or value>field.Max then return false,'InvalidAmount'end
  elseif field.Type=='Slap'then
   if type(value)~='string'or #value>96 or not deps.Slap(value)then return false,'InvalidSlap'end
  end
  clean[field.Name]=value
 end
 for name in pairs(args)do if not expected[name]then return false,'UnexpectedArgument'end end
 return true,clean
end
return Registry
