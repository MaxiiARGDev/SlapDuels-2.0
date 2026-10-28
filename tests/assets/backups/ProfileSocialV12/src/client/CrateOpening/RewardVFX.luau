--!nonstrict
local RS=game:GetService("ReplicatedStorage")
local Config=require(script.Parent.RewardRevealConfig)
local Profiles=require(script.Parent.RewardRevealProfile)
local VFX={}
local function templates()return assert(RS.UIAssets:FindFirstChild("CrateRevealV25"),"Missing Edit reward effects")end
function VFX.Budget(mobile,quantity)
 local total=if mobile then Config.MaxMobileParticles else Config.MaxParticles
 return {Remaining=total,PerReward=math.max(1,math.floor(total/(quantity or 1))),Mobile=mobile,Beams=0}
end
function VFX.Attach(run,model,variation,percent,primary)
 local profile=Profiles.For(percent,variation);local source=templates()
 local highlight=source.RewardHighlight:Clone();highlight.Adornee=model;highlight.Enabled=false;highlight.Parent=model
 local fx=source.RewardEffects:Clone();fx:PivotTo(model:GetPivot());fx.Parent=model
 local budget=run.VisualBudget;local limit=if budget.Mobile then 1 else 2
 local beamAllowed=profile.Rank>=4 and budget.Beams<limit-(if primary then 0 else 1)
 if beamAllowed then budget.Beams+=1 end
 local record={Highlight=highlight,FX=fx,Profile=profile,Emitters={},Beams={},Lights={},Started=nil,Primary=primary}
 for _,obj in ipairs(fx:GetDescendants())do
  if obj:IsA("ParticleEmitter")then
   obj.Enabled=false;obj.Rate=0;obj.Color=ColorSequence.new(variation.Color);table.insert(record.Emitters,obj)
  elseif obj:IsA("Beam")then
   if beamAllowed then obj.Enabled=false;obj.Color=ColorSequence.new(variation.Color);table.insert(record.Beams,obj)else obj:Destroy()end
  elseif obj:IsA("PointLight")then obj.Color=variation.Color;obj.Enabled=false;table.insert(record.Lights,obj)end
 end
 highlight.FillColor=variation.Color;highlight.OutlineColor=variation.Color
 highlight.FillTransparency=profile.Fill;highlight.OutlineTransparency=profile.Outline
 return record
end
function VFX.Reveal(run,record,now)
 if record.Started then return false end;record.Started=now;record.Highlight.Enabled=true
 local eligible={}
 for _,emitter in ipairs(record.Emitters)do
  local rank=emitter:GetAttribute("MinimumVisualRank")or 1
  if record.Profile.Rank>=rank then table.insert(eligible,emitter)end
 end
 local total=math.min(run.VisualBudget.Remaining,run.VisualBudget.PerReward,math.floor(record.Profile.Burst*(if run.VisualBudget.Mobile then Config.MobileParticleScale else 1)))
 for i,emitter in ipairs(eligible)do
  local count=math.ceil(total/(#eligible-i+1));if count>0 then emitter:Emit(count);total-=count;run.VisualBudget.Remaining-=count end
 end
 local sound=record.FX:FindFirstChild("JackpotReveal",true)
 if record.Profile.Rank==5 and sound and sound.SoundId~=""then sound:Play()end
 return true
end
function VFX.Update(record,now)
 if not record.Started then return end
 local age=math.max(0,now-record.Started);local p=record.Profile
 record.Highlight.FillTransparency=math.clamp(p.Fill+math.sin(age*3)*.015,0,1)
 record.Highlight.OutlineTransparency=math.clamp(p.Outline+math.sin(age*4)*Config.HighlightPulse*p.Rank/5,0,1)
 for _,beam in ipairs(record.Beams)do
  beam.Enabled=age<p.Duration and (beam:GetAttribute("IsHalo")==true or p.Rank==5)
  if beam.Enabled then beam.Transparency=NumberSequence.new(math.clamp(.25+age/p.Duration*.75,0,1))end
 end
 for _,light in ipairs(record.Lights)do
  light.Enabled=age<p.Duration;light.Brightness=(.2+p.Rank*.12)*math.max(0,1-age/p.Duration)
 end
end
function VFX.Label(record,label,now)
 if not record.Started or record.Profile.Rank<4 or not label.Size then return end
 record.LabelSize=record.LabelSize or label.Size
 local s=record.LabelSize;local pulse=1+.025*math.sin((now-record.Started)*3)^2
 label.Size=UDim2.new(s.X.Scale*pulse,s.X.Offset*pulse,s.Y.Scale*pulse,s.Y.Offset*pulse)
end
function VFX.Chest(run,model,palette,variation)
 local highlight=templates().ChestHighlight:Clone();highlight.Adornee=model;highlight.Enabled=false;highlight.Parent=model
 return {Highlight=highlight,Palette=palette,Variation=variation,LastColor=variation.Color}
end
function VFX.UpdateChest(record,stage,p,elapsed)
 local h=record.Highlight;h.Enabled=stage=="Appear"or stage=="Rise"or stage=="Growth"or stage=="Shake"or stage=="Flash"
 if not h.Enabled then return end
 local color=record.Variation.Color;local palette=record.Palette
 if stage=="Shake"or stage=="Flash"then
  record.LockFrom=record.LockFrom or record.LastColor
  local t=if stage=="Flash"then 1 else math.clamp(p/Config.Chest.LockFraction,0,1)
  color=record.LockFrom:Lerp(color,t*t*(3-2*t))
 elseif #palette>0 then
  local phase=elapsed*Config.Chest.ColorSpeed;local index=math.floor(phase)
  color=palette[index%#palette+1]:Lerp(palette[(index+1)%#palette+1],phase-index)
 end
 record.LastColor=color;h.FillColor=color;h.OutlineColor=color
 h.FillTransparency=Config.Chest.Fill;h.OutlineTransparency=if stage=="Shake"or stage=="Flash"then .12 else Config.Chest.Outline
end
function VFX.Reaction(profile,age,mobile)
 if not profile or age<0 or age>Config.ReactionDuration then return 0,0,0 end
 local strength=profile.Reaction*(1-age/Config.ReactionDuration)^3*(if mobile then .5 else 1)
 return math.sin(age*29)*strength,math.sin(age*23)*strength*.6,
  math.rad(math.sin(age*19)*Config.MaxReactionDegrees*(strength/.1))
end
return VFX
