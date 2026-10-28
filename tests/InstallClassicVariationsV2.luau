-- Edit only. Run once against the audited original; refuses to overwrite authored Tools.
assert(game:GetService('RunService'):IsStudio()and not game:GetService('RunService'):IsRunning(),'Edit required')
local ss=game:GetService('ServerStorage');local rs=game:GetService('ReplicatedStorage')
assert(not ss:FindFirstChild('SlapVariations'),'Templates already exist; inspect instead of overwriting')
local original=ss.Slaps.Classic
assert(original:IsA('Tool')and original.Hand:IsA('MeshPart'))
local definitions=require(rs.Shared.SlapCrates.VariationDefinitions)
assert(#definitions==12)
local templates=Instance.new('Folder');templates.Name='SlapVariations'
local classic=Instance.new('Folder');classic.Name='Classic';classic.Parent=templates
local previews=Instance.new('Folder');previews.Name='Classic'
for _,definition in ipairs(definitions)do
 local tool=original:Clone();tool.Name=definition.Id
 tool:SetAttribute('SlapId','Classic');tool:SetAttribute('VariationId',definition.Id)
 tool:SetAttribute('RewardId','Classic:'..definition.Id)
 tool.Hand.Color=definition.Color
 tool.Hand:SetAttribute('SlapVariationAuthored',true)
 local highlight=Instance.new('Highlight');highlight.Name='RarityHighlight'
 highlight.Adornee=tool.Hand;highlight.DepthMode=Enum.HighlightDepthMode.Occluded
 highlight.FillColor=definition.Color;highlight.OutlineColor=definition.Color
 highlight.FillTransparency=.88;highlight.OutlineTransparency=.2;highlight.Enabled=true
 highlight.Parent=tool.Hand;tool.Parent=classic
 -- Full visual copy: preserve all geometry, welds, animation, configuration and audio.
 local copy=tool:Clone();local model=Instance.new('Model');model.Name=definition.Id
 for _,child in ipairs(copy:GetChildren())do child.Parent=model end
 copy:Destroy();model.PrimaryPart=model.Hand
 model:SetAttribute('SlapId','Classic');model:SetAttribute('VariationId',definition.Id)
 model:SetAttribute('PreviewOfRewardId','Classic:'..definition.Id)
 for _,o in ipairs(model:GetDescendants())do
  if o:IsA('LuaSourceContainer')then o:Destroy()
  elseif o:IsA('BasePart')then o.Anchored=true;o.CanCollide=false;o.CanTouch=false;o.CanQuery=false
  end
 end
 model.Parent=previews
end
templates.Parent=ss
local old=rs.SlapVariationPreviews:FindFirstChild('Classic');assert(old)
old.Parent=nil;previews.Parent=rs.SlapVariationPreviews;old:Destroy()
local basic=previews.Basic:Clone();basic.Name='Classic'
local legacy=rs.CrateRewardPreviews.Classic;legacy.Parent=nil;basic.Parent=rs.CrateRewardPreviews;legacy:Destroy()
return 'Installed 12 full Tools + 12 full preview Models in Edit; original Classic untouched'
