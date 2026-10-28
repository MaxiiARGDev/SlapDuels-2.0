--!nonstrict
local RS=game:GetService("ReplicatedStorage")
local Config=require(RS.Shared.SlapCrates.OpeningConfig).RewardSpin
local Catalog=require(RS.Shared.SlapCrates.Catalog)
local Appearance=require(RS.Shared.SlapCrates.Appearance)
local Motion=require(script.Parent.RewardSpinMotion)
local Spin={}
local function sourceFor(reward)
 local previews=RS:FindFirstChild("SlapVariationPreviews");local slap=previews and previews:FindFirstChild(reward.SlapId)
 return(slap and slap:FindFirstChild(reward.VariationId))or RS.CrateRewardPreviews:FindFirstChild(reward.SlapId)
end
function Spin.Create(run,eligibleIds,safeVisual)
 local eligible={};local seen={}
 for _,id in ipairs(eligibleIds or {})do
  local reward=Catalog.Rewards[id]
  if reward and not seen[id]and sourceFor(reward)then seen[id]=true;table.insert(eligible,reward)end
 end
 if #eligible==0 then return nil end -- Legacy receipt: never invent an eligible pool.
 local count=math.clamp(math.floor(Config.VisiblePreviewCount),3,7);if count%2==0 then count-=1 end
 local record={Pool={},Count=count,WinnerScale=run.Reward:GetScale(),Finished=false,Fit=0}
 for index=1,count do
  local reward=eligible[(index-1)%#eligible+1];local model=sourceFor(reward):Clone();table.insert(run.Objects,model);safeVisual(model)
  local variation=Catalog.Variations.ById[reward.VariationId]
  local part=model:FindFirstChildWhichIsA("BasePart",true)
  if part then Appearance.Apply(part,RS.SlapVariationEffects:FindFirstChild(variation.VisualProfile))end
  safeVisual(model)
  local extent=model:GetExtentsSize();local size=math.max(extent.X,extent.Y,extent.Z,.01)
  record.Pool[index]={Model=model,Scale=model:GetScale()*math.min(1,Config.MaxPreviewExtent/size),RewardId=reward.RewardId}
 end
 local t=RS.UIAssets:FindFirstChild("CrateRevealV25");local sound=t and t:FindFirstChild("SpinTick")
 if sound then record.Tick=sound:Clone();record.Tick.Parent=run.Scene;table.insert(run.Objects,record.Tick)end
 return record
end
function Spin.Update(run,elapsed,camera)
 local spin=run.Spin3D;local age=elapsed-run.Plan.Stages[8].Start
 local aspect=camera.ViewportSize.X/math.max(1,camera.ViewportSize.Y)
 local count=if aspect<.9 then 3 else spin.Count
 spin.Fit=count*Config.ItemSpacing/(2*math.tan(math.rad(math.clamp(camera.FieldOfView,35,100))/2)*math.max(.4,aspect))*1.12
 spin.Age=age;if age<0 then return false end
 local remaining=Motion.Remaining(age,Config);local used={};local winner=false
 if age<Config.SpinDuration then
  for _,slot in ipairs(Motion.Slots(remaining,count))do
   local row=spin.Pool[slot.Pool];local model=if slot.Winner then run.Reward else row.Model
   if not slot.Winner then used[slot.Pool]=true else winner=true end
   local fade=if slot.Winner then 1 else math.clamp(remaining/.8,0,1)
   model.Parent=run.Scene
   model:ScaleTo(if slot.Winner then spin.WinnerScale*Config.WinningItemScale else row.Scale*math.max(.01,fade))
   local center=run.Stand.RewardPoint.Position+run.Stand.CameraPoint.CFrame.RightVector*(slot.X*Config.ItemSpacing)
   model:PivotTo(CFrame.new(center)*run.Stand.RewardPoint.CFrame.Rotation*CFrame.Angles(0,elapsed*.35,0))
  end
  local center=math.floor(remaining+.5)
  if spin.Tick and spin.Tick.SoundId~=""and spin.LastIndex~=center and elapsed-(spin.LastTick or -100)>.045 then spin.Tick:Play();spin.LastTick=elapsed end
  spin.LastIndex=center
 end
 for index,row in ipairs(spin.Pool)do if not used[index]then row.Model.Parent=nil end end
 if age>=Config.SpinDuration then
  run.Reward.Parent=run.Scene;run.Reward:ScaleTo(spin.WinnerScale*Config.WinningItemScale)
  local bob=math.sin(age*2)*.1*math.clamp((age-Config.SpinDuration)/.35,0,1)
  run.Reward:PivotTo(run.Stand.RewardPoint.CFrame*CFrame.new(0,bob,0)*CFrame.Angles(0,elapsed*.35,0))
  spin.Finished=true;return true
 end
 if not winner then run.Reward.Parent=nil end
 return false
end
function Spin.CameraPosition(run,position)
 local spin=run.Spin3D;local focus=run.Stand.RewardPoint.Position;local direction=position-focus
 if direction.Magnitude<.01 then return position end
 local settle=math.clamp(((spin.Age or 0)-Config.SpinDuration)/.6,0,1)
 local extra=1.2*math.clamp(1-(spin.Age or 0)/Config.SpinDuration,0,1)
 local distance=math.max(direction.Magnitude,spin.Fit+extra)
 return focus+direction.Unit*(distance+(direction.Magnitude-distance)*(settle*settle*(3-2*settle)))
end
return Spin
