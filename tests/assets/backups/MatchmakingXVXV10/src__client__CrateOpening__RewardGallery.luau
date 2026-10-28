--!nonstrict
local RS=game:GetService("ReplicatedStorage")
local Catalog=require(RS.Shared.SlapCrates.Catalog)
local Appearance=require(RS.Shared.SlapCrates.Appearance)
local Config=require(script.Parent.CinematicConfig)
local Layout=require(script.Parent.RewardGalleryLayout)
local RewardVFX=require(script.Parent.RewardVFX)
local Gallery={}
function Gallery.Create(run,rewards,safeVisual)
 local template=assert(RS.UIAssets:FindFirstChild("CrateBatchRewardSlot"),"Missing editable batch slot")
 local gallery={Rows={},Count=#rewards,Emitted=0}
 for _,unit in ipairs(rewards)do
  local reward=assert(Catalog.Rewards[unit.RewardId],"Unknown batch reward")
  local variation=Catalog.Variations.ById[reward.VariationId]
  local slot=template:Clone();slot.Name="RewardSlot_"..(#gallery.Rows+1);slot.Parent=run.Scene
  table.insert(run.Objects,slot)
  local label=slot.Anchor.BillboardGui;label.Enabled=false
  label.Slap.Text=Catalog.Slaps.ById[reward.SlapId].DisplayName
  label.Variation.Text=variation.DisplayName;label.Variation.TextColor3=variation.Color
  local previews=RS:FindFirstChild("SlapVariationPreviews")
  local slap=previews and previews:FindFirstChild(reward.SlapId)
  local source=(slap and slap:FindFirstChild(reward.VariationId))or RS.CrateRewardPreviews:FindFirstChild(reward.SlapId)
  local model=assert(source,"Missing batch reward preview"):Clone();table.insert(run.Objects,model);safeVisual(model)
  local part=model:FindFirstChildWhichIsA("BasePart",true)
  local profile=RS.SlapVariationEffects:FindFirstChild(variation.VisualProfile)
  if part then Appearance.Apply(part,profile)end
  safeVisual(model) -- Applied profiles must obey the same local presentation bounds.
  local size=model:GetExtentsSize();local extent=math.max(size.X,size.Y,size.Z)
  local primary=run.GlobalFX and run.GlobalFX.Index==#gallery.Rows+1
  local visual=RewardVFX.Attach(run,model,variation,unit.EffectivePercent,primary)
  table.insert(gallery.Rows,{Slot=slot,Model=model,Label=label,Variation=variation,
   VFX=visual,Primary=primary,Scale=model:GetScale()*math.min(1,Config.Gallery.MaxModelExtent/math.max(extent,.01))})
 end
 return gallery
end
function Gallery.Update(run,elapsed,camera)
 local gallery=run.Gallery
 local aspect=camera.ViewportSize.X/math.max(1,camera.ViewportSize.Y)
 local layout=Layout.Build(gallery.Count,aspect,math.clamp(camera.FieldOfView or 70,35,100),Config.Gallery)
 gallery.Layout=layout
 local since=elapsed-run.Plan.Stages[8].Start
 for index,row in ipairs(gallery.Rows)do
  local age=since-(index-1)*Config.Gallery.Stagger
  if age<0 then continue end
  local p=math.clamp(age/Config.Gallery.EnterDuration,0,1);local eased=1-(1-p)^3
  local point=layout.Positions[index];local cameraPoint=run.Stand.CameraPoint
  local position=run.Stand.RewardPoint.Position+cameraPoint.CFrame.RightVector*point.X
   +cameraPoint.CFrame.UpVector*(point.Y-(1-eased)*.6)
  row.Slot.Anchor.CFrame=CFrame.new(position)
  row.Label.Adornee=row.Slot.Anchor;row.Label.Enabled=true
  row.Model.Parent=row.Slot;row.Model:ScaleTo(row.Scale*math.max(.01,eased))
  row.Model:PivotTo(CFrame.new(position+Vector3.new(0,math.sin(elapsed*2+index)*.07,0))
   *run.Stand.RewardPoint.CFrame.Rotation*CFrame.Angles(0,elapsed*.5,0))
  if not row.Revealed then
   row.Revealed=true
   RewardVFX.Reveal(run,row.VFX,elapsed)
   if row.Primary then run.PrimaryRewardRevealed=true end
   local rowBudget=if row.Variation.SortOrder>=5 then 4 else 2
   local mobile=run.VisualBudget and run.VisualBudget.Mobile
   if mobile then rowBudget=math.max(1,math.floor(rowBudget*.5))end
   for _,effect in ipairs(row.Model:GetDescendants())do
    local maximum=if mobile then math.min(12,Config.Gallery.MaxRevealParticles)else Config.Gallery.MaxRevealParticles
    if effect:IsA("ParticleEmitter")and(not row.VFX.FX or not effect:IsDescendantOf(row.VFX.FX))and rowBudget>0 and gallery.Emitted<maximum then
     local n=math.min(rowBudget,maximum-gallery.Emitted)
     effect:Emit(n);gallery.Emitted+=n;rowBudget-=n
    end
   end
  end
  RewardVFX.Update(row.VFX,elapsed)
  RewardVFX.Label(row.VFX,row.Label,elapsed)
 end
end
function Gallery.CameraPosition(run,position)
 if not run.Gallery.Layout then return position end
 local focus=run.Stand.RewardPoint.Position;local direction=position-focus
 if direction.Magnitude<.01 then return position end
 return focus+direction.Unit*math.max(direction.Magnitude,run.Gallery.Layout.Distance)
end
return Gallery
