assert(game:GetService('RunService'):IsStudio()and not game:GetService('RunService'):IsRunning(),'Edit required')
local ss=game:GetService('ServerStorage');local rs=game:GetService('ReplicatedStorage')
local count=0;local function check(v,label)assert(v,label);count+=1 end
local original=ss.Slaps.Classic
local function compare(a,b)
 check(a.ClassName==b.ClassName,'class '..a.Name)
 if a:IsA('BasePart')then
  check(a.Size==b.Size and a.CFrame==b.CFrame and a.Material==b.Material and a.Transparency==b.Transparency,'geometry/material '..a.Name)
 elseif a:IsA('ValueBase')then check(a.Value==b.Value,'configuration')
 elseif a:IsA('Animation')then check(a.AnimationId==b.AnimationId,'animation')
 elseif a:IsA('Sound')then check(a.SoundId==b.SoundId and a.Volume==b.Volume and a.PlaybackSpeed==b.PlaybackSpeed,'audio')end
 if a:IsA('MeshPart')then check(a.MeshId==b.MeshId and a.TextureID==b.TextureID,'original mesh and texture')end
 for _,child in ipairs(a:GetChildren())do local other=b:FindFirstChild(child.Name);check(other~=nil,'preserved child '..child.Name);compare(child,other)end
end
local rows={}
for _,v in ipairs(require(rs.Shared.SlapCrates.VariationDefinitions))do
 local tool=ss.SlapVariations.Classic:FindFirstChild(v.Id)
 check(tool and tool:IsA('Tool'),'full tool')
 compare(original,tool)
 check(tool.Hand.Color==v.Color,'rarity color')
 local h=tool.Hand.RarityHighlight
 check(h:IsA('Highlight')and h.Enabled and h.Adornee==tool.Hand and h.FillColor==v.Color and h.OutlineColor==v.Color,'highlight')
 check(h.DepthMode==Enum.HighlightDepthMode.Occluded,'no through-wall outline')
 local preview=rs.SlapVariationPreviews.Classic[v.Id]
 check(preview:IsA('Model')and preview.PrimaryPart==preview.Hand,'full preview')
 check(preview.Hand:IsA('MeshPart')and preview.Hand.MeshId==original.Hand.MeshId and preview.Hand.TextureID==original.Hand.TextureID,'exact preview mesh')
 check(preview:FindFirstChild('Handle')and preview:FindFirstChild('Swing')and preview:FindFirstChild('Configuration')and preview.Hand:FindFirstChild('Hit'),'complete components in preview')
 check(preview.Hand.RarityHighlight.Adornee==preview.Hand,'preview highlight reference internal')
 local highlights=0;for _,o in ipairs(tool:GetDescendants())do if o:IsA('Highlight')then highlights+=1 end end
 check(highlights==1,'no duplicate highlights')
 table.insert(rows,{Id=v.Id,Path=tool:GetFullName(),RGB={math.round(v.Color.R*255),math.round(v.Color.G*255),math.round(v.Color.B*255)}})
end
check(#ss.SlapVariations.Classic:GetChildren()==12,'exactly twelve tools')
check(#rs.SlapVariationPreviews.Classic:GetChildren()==12,'exactly twelve previews')
local source=rs.Shared.SlapCrates.Appearance:Clone();source.Name='__ClassicAppearanceAudit';source.Parent=rs.Shared.SlapCrates
local copy=ss.SlapVariations.Classic.Galaxy:Clone()
local ok,err=pcall(function()
 local appearance=require(source)
 local future=Instance.new('ParticleEmitter');future.Name='FutureAuthoredParticle';future.Enabled=false;future.Parent=copy.Hand
 local color=copy.Hand.Color;local sound=copy.Hand.Hit.SoundId
 appearance.Apply(copy.Hand,rs.SlapVariationEffects.Basic)
 check(copy.Hand.Color==color and copy.Hand.RarityHighlight and future.Parent==copy.Hand and copy.Hand.Hit.SoundId==sound,'authored effects not overwritten')
end)
copy:Destroy();source:Destroy();assert(ok,err)
local enc=game:GetService('EncodingService');local serial=game:GetService('SerializationService')
local binary=enc:ComputeStringHash(buffer.tostring(serial:SerializeInstancesAsync({original})),Enum.HashAlgorithm.Sha256)
local hash=binary:gsub('.',function(c)return string.format('%02x',string.byte(c))end)
check(hash=='16f7ac4d86c65b8e3666f7e5e155857d79aec59d8fe01b5b03ef0c2a7e5ebe8d','original Classic byte-identical')
return game:GetService('HttpService'):JSONEncode({Mode='Edit',Assertions=count,OriginalClassicHash=hash,Variants=rows,Gameplay='NOT RUN'})
