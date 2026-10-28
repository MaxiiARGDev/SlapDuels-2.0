local function load(name,env)local f=assert(loadstring(Sources[name],name));setfenv(f,setmetatable(env,{__index=getfenv()}));return f()end
local function folder(children)return {FindFirstChild=function(_,id)return children[id]end}end
local template={IsA=function(_,kind)return kind=='Tool'end}
local base={IsA=template.IsA}
local bad={IsA=function()return false end}
local children={Galaxy=template,Bad=bad}
local ss=folder({SlapVariations=folder({Classic=folder(children)}),Slaps=folder({Classic=base})})
local config={Slaps={ById={Classic={Model='Classic'}}},Variations={ById={Galaxy={VisualProfile='Galaxy'}}}}
local keys=setmetatable({},{__index=function(_,k)return k end})
local service=load('CrateService',{game={GetService=function(_,id)return id=='ServerStorage'and ss or {Shared={SlapCrates=keys},FindFirstChild=function()return nil end}end},script={Parent={Crates=keys}},require=function(id)return id=='Catalog'and config or {}end})
assert(service:GetRewardTemplate({SlapId='Classic',VariationId='Galaxy'})==template)
assert(service:GetRewardTemplate({SlapId='Classic',VariationId='Missing'})==base)
assert(service:GetRewardTemplate({SlapId='Classic',VariationId='Bad'})==base)
assert(service:GetRewardTemplate({SlapId='Unknown',VariationId='Galaxy'})==nil)
local hand={GetAttribute=function()return true end}
local tool={FindFirstChild=function()return hand end,SetAttribute=function()end}
service:ApplyVariation(tool,{SlapId='Classic',VariationId='Galaxy',RewardId='Classic:Galaxy',DisplayName='Test'})
local marked=false
local authoredHand={GetAttribute=function()return false end,SetAttribute=function(_,name,value)assert(name=='SlapVariationAuthored'and value==true);marked=true end}
local authoredTool={FindFirstChild=function()return authoredHand end,SetAttribute=function()end}
service:ApplyVariation(authoredTool,{SlapId='Classic',VariationId='Galaxy',RewardId='Classic:Galaxy',DisplayName='Test'})
assert(marked,'physical templates remain authoritative without requiring a manually authored marker')
print('ClassicVariationsV2 resolver PASS: 6 assertions; gameplay NOT RUN')
