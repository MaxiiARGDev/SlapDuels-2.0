--!nonstrict
-- Server-only sealed registry. Build is dependency-injected for isolated tests.
-- Nothing is required by discovery; only explicit manifest entries are loaded.
local Registry={}
local singleton
local function finite(v) return type(v)=="number" and v==v and math.abs(v)<math.huge end
local function text(v,max) return type(v)=="string" and #v>0 and #v<=max end
local function identifier(v) return text(v,48) and v:match("^[A-Za-z][A-Za-z0-9_]*$")~=nil end
local function copy(value)
 if type(value)~="table" then return value end
 local result={} for key,v in pairs(value) do result[key]=copy(v) end return result
end
local function freeze(value)
 if type(value)=="table" and not table.isfrozen(value) then
  for _,v in pairs(value) do freeze(v) end;table.freeze(value)
 end
 return value
end
local function validate(module,options)
 if type(module)~="table" or module.IsTemplate then return nil,"InvalidAbilityOrTemplate" end
 local d=module.Descriptor
 if type(d)~="table" or not identifier(d.Id) then return nil,"InvalidDescriptorId" end
 if not text(d.DisplayName,80) or not text(d.Description,400) or not text(d.Type,48)
  or not finite(d.Duration) or d.Duration<0 or d.Duration>600
  or not finite(d.Cooldown) or d.Cooldown<=0 or d.Cooldown>3600
  or not finite(d.SortOrder) or d.SortOrder%1~=0
  or type(d.Icon)~="string" or #d.Icon>256 or (d.Icon~="" and not d.Icon:match("^rbxassetid://%d+$")) then return nil,"InvalidDescriptor" end
 if type(module.Enabled)~="boolean" then return nil,"InvalidAvailability" end
 if type(module.Start)~="function" or type(module.Cancel)~="function" then return nil,"MissingStartOrCancel" end
 for _,name in {"Step","ValidateActivation","OnAction"} do
  if module[name]~=nil and type(module[name])~="function" then return nil,"InvalidCallback:"..name end
 end
 local config,schema=module.Config,module.ConfigSchema
 if type(config)~="table" or type(schema)~="table" then return nil,"InvalidConfigSchema" end
 for key,value in pairs(config) do
  local rule=schema[key]
  if not identifier(key) or type(rule)~="table" then return nil,"UndeclaredConfig:"..tostring(key) end
  if rule.Type=="number" then
   if not finite(value) or not finite(rule.Min) or not finite(rule.Max) or rule.Min>rule.Max
    or value<rule.Min or value>rule.Max or (rule.Integer and value%1~=0) then return nil,"InvalidConfig:"..key end
  elseif rule.Type=="boolean" then
   if type(value)~="boolean" then return nil,"InvalidConfig:"..key end
  elseif rule.Type=="string" then
   if not text(value,128) then return nil,"InvalidConfig:"..key end
  else return nil,"UnsupportedConfigType:"..key end
 end
 for key in pairs(schema) do if config[key]==nil then return nil,"MissingConfig:"..tostring(key) end end
 if module.Dependencies~=nil and type(module.Dependencies)~="table" then return nil,"InvalidDependencies" end
 for _,dependency in ipairs(module.Dependencies or {}) do
  if not identifier(dependency) or not options.HasDependency(dependency) then return nil,"MissingDependency:"..tostring(dependency) end
 end
 local input=module.Input or {Primary="None"}
 if type(input)~="table" or (input.Primary~="None" and input.Primary~="Direction") then return nil,"InvalidInputProfile" end
 local actions=module.Actions or {}
 if type(actions)~="table" then return nil,"InvalidActions" end
 local checkedActions={}
 for name,action in pairs(actions) do
  if not identifier(name) or name=="Activate" or name=="Sync" or name=="Select" or type(action)~="table"
   or (action.Input~="None" and action.Input~="Direction") or type(module.OnAction)~="function" then return nil,"InvalidAction" end
  checkedActions[name]={Input=action.Input}
 end
 for _,field in {"ActivePrimaryAction","JumpAction"} do
  if input[field]~=nil and not actions[input[field]] then return nil,"UnknownInputAction:"..field end
 end
 local assets=module.Assets
 if type(assets)~="table" or (assets.Profile~="None" and assets.Profile~="AttachmentEffect" and assets.Profile~="InvisibleAvatar")
  or (assets.Profile~="None" and not identifier(assets.Key))
  or (assets.Key~=nil and not identifier(assets.Key)) then return nil,"InvalidAssets" end
 local cues={}
 for name,cue in pairs(assets.Cues or {}) do
  if not identifier(name) or type(cue)~="table" or cue.Profile~="VerticalLaunch" or not identifier(cue.Resource)
   or not finite(cue.Lift) or cue.Lift<0 or cue.Lift>100 or not finite(cue.Duration) or cue.Duration<=0 or cue.Duration>5 then return nil,"InvalidCue" end
  cues[name]={Profile=cue.Profile,Resource=cue.Resource,Lift=cue.Lift,Duration=cue.Duration}
 end
 if assets.Profile=="None" and next(cues)~=nil then return nil,"CueWithoutVisualProfile" end
 local checkedAssets={Key=assets.Key,Profile=assets.Profile,Cues=cues}
 local assetOk,assetReason=options.CheckAssets(checkedAssets)
 if not assetOk then return nil,assetReason or "InvalidPhysicalResources" end
 local hooks=module.Hooks
 if hooks~=nil then
  if type(hooks)~="table" or hooks.Profile~="ImmediateElimination" or type(hooks.BeforeHit)~="function" or type(hooks.Consume)~="function"
   or (hooks.Reason~="StrongSlap" and hooks.Reason~="AbilityImpact") or not cues[hooks.Cue] then return nil,"InvalidImpactHook" end
  hooks={Profile=hooks.Profile,BeforeHit=hooks.BeforeHit,Consume=hooks.Consume,Reason=hooks.Reason,Cue=hooks.Cue}
 end
 local shop=module.Shop
 if type(shop)~="table" or type(shop.PurchaseEnabled)~="boolean" or type(shop.PriceApproved)~="boolean"
  or not finite(shop.Price) or shop.Price<0 or shop.Price%1~=0 then return nil,"InvalidShopMetadata" end
 if shop.PurchaseEnabled and (not shop.PriceApproved or shop.Price<=0) then return nil,"UnapprovedPurchase" end
 local activeLabel=d.ActiveLabel or "ACTIVA"
 if not text(activeLabel,40) or (d.DurationKind~=nil and d.DurationKind~="Instant") then return nil,"InvalidDisplayMetadata" end
 -- Explicit public projection: never replicate Config, schema, functions, Instance
 -- references, dependencies, service references or arbitrary extra descriptor keys.
 local public={Id=d.Id,DisplayName=d.DisplayName,Description=d.Description,Type=d.Type,Duration=d.Duration,Cooldown=d.Cooldown,
  Icon=d.Icon,SortOrder=d.SortOrder,Enabled=module.Enabled,ActiveLabel=activeLabel,DurationKind=d.DurationKind,
  Input={Primary=input.Primary,ActivePrimaryAction=input.ActivePrimaryAction,JumpAction=input.JumpAction},Assets=checkedAssets}
 local definition=copy(config)
 for key,value in pairs(public) do definition[key]=copy(value) end
 return {Id=d.Id,Enabled=module.Enabled,Public=public,Definition=definition,Config=copy(config),
  Shop={Price=shop.Price,PriceApproved=shop.PriceApproved,PurchaseEnabled=shop.PurchaseEnabled},
  Input=copy(public.Input),Actions=checkedActions,Assets=checkedAssets,Hooks=hooks,
  Module={Start=module.Start,Step=module.Step,Cancel=module.Cancel,ValidateActivation=module.ValidateActivation,OnAction=module.OnAction}}
end
function Registry.Build(options)
 local errors,entries,order,candidates,counts={},{},{},{},{}
 local function diagnostic(name,reason)
  local row={Module=tostring(name),Reason=tostring(reason):sub(1,500)};table.insert(errors,row)
  if options.Warn then options.Warn("[AbilityRegistry] "..row.Module..": "..row.Reason) end
 end
 local names={}
 if type(options.Manifest)~="table" then diagnostic("Manifest","InvalidManifest") else
  for _,name in ipairs(options.Manifest) do
   if not identifier(name) then diagnostic(name,"InvalidModuleName")
   elseif names[name] then diagnostic(name,"RepeatedManifestEntry")
   else
    names[name]=true
    local ok,module=pcall(function()
     local instance=options.Resolve(name)
     if not instance or not options.IsModule(instance) then error("MissingOrUnauthorizedModule") end
     -- Authorization occurs BEFORE require; returned-table validation is not a sandbox.
     return options.Load(instance)
    end)
    if not ok then diagnostic(name,"RequireFailed:"..tostring(module)) else
     local valid,entry,reason=pcall(validate,module,options)
     if not valid then diagnostic(name,"ContractError:"..tostring(entry))
     elseif not entry then diagnostic(name,reason) else
      counts[entry.Id]=(counts[entry.Id] or 0)+1;table.insert(candidates,{Name=name,Entry=entry})
     end
    end
   end
  end
 end
 for _,candidate in ipairs(candidates) do
  local entry=candidate.Entry
  if counts[entry.Id]>1 then diagnostic(candidate.Name,"DuplicateId:"..entry.Id)
  else entries[entry.Id]=freeze(entry);if entry.Enabled then table.insert(order,entry.Id) end end
 end
 table.sort(order,function(a,b)
  local x,y=entries[a].Public.SortOrder,entries[b].Public.SortOrder
  return if x==y then a<b else x<y
 end)
 local items={} for _,id in ipairs(order) do items[id]=entries[id].Public end
 if not items[options.DefaultId] then diagnostic("Default","DefaultAbilityUnavailable") end
 local catalog=freeze({Version=1,DefaultId=options.DefaultId,Order=order,Items=items})
 freeze(errors)
 return table.freeze({
  Get=function(_,id)return entries[id]end,
  GetPublicCatalog=function()return catalog end,
  GetDiagnostics=function()return errors end,
  IsSealed=function()return true end,
 })
end
function Registry.Initialize(options)
 if singleton then return false,"RegistryAlreadySealed" end
 singleton=Registry.Build(options);return true
end
function Registry.Get(_self,id) return singleton and singleton:Get(id) end
function Registry.GetPublicCatalog() return singleton and singleton:GetPublicCatalog() end
function Registry.GetDiagnostics() return singleton and singleton:GetDiagnostics() or {} end
return table.freeze(Registry)
