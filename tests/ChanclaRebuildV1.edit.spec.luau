assert(not game:GetService('RunService'):IsRunning(),'Edit only')
local base=game.ServerStorage.Slaps.Slap_Chancla
local folder=game.ServerStorage.SlapVariations.Chancla
local defs=require(game.ReplicatedStorage.Shared.SlapCrates.VariationDefinitions)
local count=0
local function check(v,m)assert(v,m);count+=1 end
local function path(root,o)
 if not o then return nil end
 local names={};while o~=root do table.insert(names,1,o.Name);o=o.Parent;if not o then return nil end end
 return table.concat(names,'/')
end
local function validate(tool)
 local parts={};local links={}
 for _,o in ipairs(tool:GetDescendants())do
  if o:IsA('BasePart')then parts[o]=true;links[o]={};check(not o.Anchored,'No anchored parts')end
 end
 for _,o in ipairs(tool:GetDescendants())do
  if o:IsA('JointInstance')or o:IsA('WeldConstraint')then
   check(parts[o.Part0]and parts[o.Part1],'All welds stay inside own Tool')
   table.insert(links[o.Part0],o.Part1);table.insert(links[o.Part1],o.Part0)
  end
 end
 local seen={};local function visit(p)if seen[p]then return end;seen[p]=true;for _,other in ipairs(links[p])do visit(other)end end
 visit(tool.Handle);for part in pairs(parts)do check(seen[part],'Every part connected to Handle')end
end
check(#folder:GetChildren()==12,'Exactly twelve variations')
validate(base)
for _,v in ipairs(defs)do
 local tool=folder:FindFirstChild(v.Id);check(tool and tool:IsA('Tool'),'Variant exists')
 validate(tool)
 check(tool.Grip:FuzzyEq(base.Grip,1e-5) and tool.RequiresHandle==base.RequiresHandle,'Original grip contract')
 check(tool.Configuration.Power.Value==base.Configuration.Power.Value and tool.Configuration.SlapCooldown.Value==base.Configuration.SlapCooldown.Value,'Original balance')
 check(tool.Hand.SlapBackAttachment.CFrame:FuzzyEq(base.Hand.SlapBackAttachment.CFrame,1e-5),'Authored back mount preserved')
 check(tool.Hand.Color==v.Color,'Variation color')
 check(tool:GetAttribute('RewardId')=='Chancla:'..v.Id,'Variant identity')
 check(tool.Hand.RarityHighlight.Adornee==tool.Hand and tool.Hand.RarityHighlight.FillColor==v.Color,'Highlight bound to own Hand')
 for _,part in ipairs(base:GetDescendants())do if part:IsA('BasePart')then
  local copy=tool;for component in string.gmatch(path(base,part),'[^/]+')do copy=copy:FindFirstChild(component)end
  check(copy and copy.Size==part.Size and copy.CFrame:FuzzyEq(part.CFrame,1e-5),'Full geometry preserves authored placement')
 end end
end
return {Assertions=count,Tools=13,Variants=12,Mode='Edit isolated; no equip/Play'}
