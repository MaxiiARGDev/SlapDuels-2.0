assert(game:GetService('RunService'):IsStudio()and not game:GetService('RunService'):IsRunning(),'Edit required')
local ss=game.ServerStorage;local variations=require(game.ReplicatedStorage.Shared.SlapCrates.VariationDefinitions)
local count=0
for _,name in ipairs({'Slap_Chancla','Slap_PingPong'})do
 local original=ss.Slaps:FindFirstChild(name);assert(original and original:IsA('Tool')and original.Hand:IsA('BasePart'))
 local key=name:gsub('^Slap_','');local folder=ss.SlapVariations:FindFirstChild(key)
 if not folder then folder=Instance.new('Folder');folder.Name=key;folder.Parent=ss.SlapVariations end
 folder:SetAttribute('DisplayName',key)
 for _,v in ipairs(variations)do
  -- Never overwrite existing artist-authored variants.
  if not folder:FindFirstChild(v.Id)then
   local tool=original:Clone();tool.Name=v.Id;tool:SetAttribute('SlapId',key);tool:SetAttribute('VariationId',v.Id);tool:SetAttribute('RewardId',key..':'..v.Id)
   tool.Hand.Color=v.Color;tool.Hand:SetAttribute('SlapVariationAuthored',true)
   local h=Instance.new('Highlight');h.Name='RarityHighlight';h.Adornee=tool.Hand;h.FillColor=v.Color;h.OutlineColor=v.Color
   h.FillTransparency=.88;h.OutlineTransparency=.2;h.DepthMode=Enum.HighlightDepthMode.Occluded;h.Parent=tool.Hand
   tool.Parent=folder;count+=1
  end
 end
 task.wait()
end
return 'Created '..count..' missing complete variants; original bases and existing variants preserved'
