--!nonstrict
-- Only physical Tools in two server-owned folders are inspected. Never require asset scripts.
local Registry={}
local function id(value)
 return type(value)=='string'and #value>0 and #value<=64 and value:match('^[%w_%-]+$')~=nil
end
local function canonical(name)return name:gsub('^Slap_','')end
local function unique(parent)
 local seen={};if parent then for _,o in ipairs(parent:GetChildren())do assert(not seen[o.Name],'DuplicateSlapResource:'..o.Name);seen[o.Name]=o end end;return seen
end
local function valid(tool)
 if not tool or not tool:IsA('Tool')then return false end
 local hand=tool:FindFirstChild('Hand');local c=tool:FindFirstChild('Configuration')
 local p=c and c:FindFirstChild('Power');local cd=c and c:FindFirstChild('SlapCooldown')
 return hand and hand:IsA('BasePart')and p and p:IsA('NumberValue')and p.Value==p.Value and p.Value>0 and p.Value<math.huge
  and cd and cd:IsA('NumberValue')and cd.Value==cd.Value and cd.Value>=0 and cd.Value<math.huge
end
function Registry.Discover(slaps,variants,variations)
 local known={};for _,v in ipairs(variations)do known[v.Id]=v end
 local models={};local diagnostics={}
 for _,tool in pairs(unique(slaps))do
  if valid(tool)then
   local key=tool:GetAttribute('SlapId')or canonical(tool.Name);assert(id(key),'InvalidSlapId')
   assert(not models[key],'DuplicateSlapId:'..key)
   models[key]={SlapId=key,Model=tool.Name,DisplayName=tool:GetAttribute('DisplayName')or(key=='Classic'and 'Clásico'or key),Base=tool,Templates={Basic=tool}}
  else table.insert(diagnostics,'Invalid base: '..tool.Name)end
 end
 for _,folder in pairs(unique(variants))do
  if folder:IsA('Folder')then
   local key=folder:GetAttribute('SlapId')or canonical(folder.Name);assert(id(key),'InvalidSlapFolder')
   local model=models[key]
   if not model then model={SlapId=key,Model=folder:GetAttribute('BaseModel')or key,DisplayName=folder:GetAttribute('DisplayName')or key,Templates={}};models[key]=model end
   assert(not model.VariantsFolder,'AmbiguousSlapVariants:'..key);model.VariantsFolder=folder.Name
   for name,tool in pairs(unique(folder))do
    if known[name]and valid(tool)then model.Templates[name]=tool
    else table.insert(diagnostics,'Invalid/unknown variant: '..folder.Name..'/'..name)end
   end
  end
 end
 local result={}
 for _,model in pairs(models)do
  model.VariationIds={}
  for _,v in ipairs(variations)do if model.Templates[v.Id]then table.insert(model.VariationIds,v.Id)end end
  if #model.VariationIds>0 then table.insert(result,model)end
 end
 table.sort(result,function(a,b)return a.SlapId<b.SlapId end)
 local default=false;for _,m in ipairs(result)do if m.SlapId=='Classic'and m.Templates.Basic then default=true end end
 assert(default,'DefaultClassicBasicRequired')
 return result,diagnostics
end
function Registry.Preview(tool,name)
 local copy=tool:Clone();local model=Instance.new('Model');model.Name=name
 for _,child in ipairs(copy:GetChildren())do child.Parent=model end;copy:Destroy()
 model.PrimaryPart=model:FindFirstChild('Hand')
 if model.PrimaryPart then model.PrimaryPart:SetAttribute('SlapVariationAuthored',true)end
 for _,o in ipairs(model:GetDescendants())do
  if o:IsA('LuaSourceContainer')then o:Destroy()
  elseif o:IsA('BasePart')then o.Anchored=true;o.CanCollide=false;o.CanTouch=false;o.CanQuery=false end
 end
 return model
end
function Registry.Publish()
 local rs=game:GetService('ReplicatedStorage');local ss=game:GetService('ServerStorage')
 local variations=require(rs.Shared.SlapCrates.VariationDefinitions)
 local models,diagnostics=Registry.Discover(ss:FindFirstChild('Slaps'),ss:FindFirstChild('SlapVariations'),variations)
 local metadata=Instance.new('Folder');metadata.Name='SlapCatalog';metadata:SetAttribute('SchemaVersion',1)
 local previews=Instance.new('Folder');previews.Name='SlapVariationPreviews'
 local bases=Instance.new('Folder');bases.Name='CrateRewardPreviews'
 for _,model in ipairs(models)do
  local entry=Instance.new('Folder');entry.Name=model.SlapId
  entry:SetAttribute('Model',model.Model);entry:SetAttribute('DisplayName',model.DisplayName)
  entry:SetAttribute('VariantsFolder',model.VariantsFolder or model.SlapId)
  local names=Instance.new('Folder');names.Name='Variations';names.Parent=entry
  local visuals=Instance.new('Folder');visuals.Name=model.SlapId
  for _,variation in ipairs(model.VariationIds)do
   local marker=Instance.new('Folder');marker.Name=variation;marker.Parent=names
   local preview=Registry.Preview(model.Templates[variation],variation)
   preview:SetAttribute('SlapId',model.SlapId);preview:SetAttribute('VariationId',variation)
   preview:SetAttribute('PreviewOfRewardId',model.SlapId..':'..variation);preview.Parent=visuals
  end
  local base=Registry.Preview(model.Templates.Basic or model.Templates[model.VariationIds[1]],model.SlapId);base.Parent=bases
  entry.Parent=metadata;visuals.Parent=previews
 end
 -- Build first, then publish. Clients wait for the runtime-ready marker before requiring Catalog.
 rs:SetAttribute('SlapCatalogReady',false)
 for _,new in ipairs({metadata,previews,bases})do local old=rs:FindFirstChild(new.Name);if old then old:Destroy()end;new.Parent=rs end
 rs:SetAttribute('SlapCatalogReady',true)
 for _,message in ipairs(diagnostics)do warn('[SlapCatalog] '..message)end
 print('[SlapCatalog] Registered '..#models..' physical Slap models')
 return models,diagnostics
end
return Registry
