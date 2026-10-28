--!nonstrict
-- Real local Workspace rendering: particles and Highlights are not emulated in ViewportFrames.
local RS=game:GetService('ReplicatedStorage')
local Labels=require(script.Parent.CrateOddsLabels)
local Gallery={};Gallery.__index=Gallery
function Gallery.new(panel)return setmetatable({Panel=panel,Rows={},Angle=0},Gallery)end
function Gallery:Release(row)
 if row.Model then for _,o in ipairs(row.Model:GetDescendants())do if o:IsA('ParticleEmitter')then o:Clear()end end;row.Model:Destroy();row.Model=nil end
 if row.Back then row.Back:Destroy();row.Back=nil end
end
function Gallery:Clear()
 for _,r in ipairs(self.Rows)do self:Release(r);r.Card:Destroy()end
 table.clear(self.Rows)
end
function Gallery:Set(result)
 self:Clear();self.Panel.RewardScroll.CanvasPosition=Vector2.zero
 if not result.Ok then return end
 for i,outcome in ipairs(result.Outcomes or {})do
  local card=self.Panel.RewardCard:Clone();card.Name='Reward_'..i;card.LayoutOrder=i;card.Visible=true
  card.ItemName.Text=outcome.SlapName or outcome.DisplayName;card.Rarity.Text=outcome.VariationName
  card.Rarity.TextColor3=outcome.Color;card.Stroke.Color=outcome.Color
  card.Chance.Text=Labels.Percent(outcome.Percent)..' · '..Labels.Chance(outcome.Percent)
  card.Detail.Text=Labels.Percent(outcome.Percent)..' · '..Labels.Chance(outcome.Percent)
  card.Detail.Visible=false
  card.MouseEnter:Connect(function()card.Detail.Visible=true end)
  card.MouseLeave:Connect(function()card.Detail.Visible=false end)
  card.InputBegan:Connect(function(input)if input.UserInputType==Enum.UserInputType.Touch then card.Detail.Visible=true end end)
  card.InputEnded:Connect(function(input)if input.UserInputType==Enum.UserInputType.Touch then card.Detail.Visible=false end end)
  card.Parent=self.Panel.RewardScroll
  table.insert(self.Rows,{Card=card,Outcome=outcome})
 end
end
function Gallery:HideModels()
 for _,r in ipairs(self.Rows)do self:Release(r)end
end
function Gallery:Create(row)
 local previews=RS:FindFirstChild('SlapVariationPreviews');local base=previews and previews:FindFirstChild(row.Outcome.SlapId)
 local source=base and base:FindFirstChild(row.Outcome.VariationId);if not source then return end
 local model=source:Clone();model.Name='LocalCratePreview';row.Bursts={};row.LastBurst=-math.huge
 for _,o in ipairs(model:GetDescendants())do
  if o:IsA('LuaSourceContainer')then o:Destroy()
  elseif o:IsA('BasePart')then o.Anchored=true;o.CanCollide=false;o.CanTouch=false;o.CanQuery=false;o.CastShadow=false
  elseif o:IsA('Sound')then o:Stop() -- No overlapping audio from nine previews.
  elseif o:IsA('ParticleEmitter')then
   o.Rate=math.min(o.Rate,12)
   if o:GetAttribute('PreviewEnabled')~=false then
    o.Enabled=o.Rate>0
    if o.Rate==0 and #row.Bursts<4 then table.insert(row.Bursts,{Emitter=o,Count=math.clamp(tonumber(o:GetAttribute('PreviewEmitCount')or o:GetAttribute('EmitCount')or o:GetAttribute('RevealBurstCount'))or 4,1,8)})end
   end
  end
 end
 row.Model=model;row.BaseScale=model:GetScale();row.Extent=model:GetExtentsSize().Magnitude;row.Rotation=model:GetPivot().Rotation
 local back=Instance.new('Part');back.Name='LocalCrateRarityBackdrop';back.Anchored=true;back.CanCollide=false;back.CanTouch=false;back.CanQuery=false
 back.CastShadow=false;back.Material=Enum.Material.Neon;back.Color=row.Outcome.Color:Lerp(Color3.fromRGB(8,12,23),.82);row.Back=back
end
function Gallery:Step(dt)
 if not self.Panel.Visible or not self.Panel.Parent.Enabled then self:HideModels();return end
 local camera=workspace.CurrentCamera;if not camera then return end
 self.Angle+=dt*.55;self.Time=(self.Time or 0)+dt
 local scroll=self.Panel.RewardScroll;local pos,size=scroll.AbsolutePosition,scroll.AbsoluteSize;local active=0
 for _,row in ipairs(self.Rows)do
  local a,b=row.Card.AbsolutePosition,row.Card.AbsoluteSize
  local visible=a.X>=pos.X and a.X+b.X<=pos.X+size.X and active<6
  if visible then
   active+=1;if not row.Model then self:Create(row)end
   if row.Model then
    local center=a+Vector2.new(b.X/2,b.Y*.33)
    local ray=camera:ScreenPointToRay(center.X,center.Y)
    local distance=1.5;local worldHeight=2*distance*math.tan(math.rad(camera.FieldOfView/2))*b.Y*.51/math.max(1,camera.ViewportSize.Y)
    row.Model:ScaleTo(row.BaseScale*worldHeight/math.max(row.Extent,.01)*.77)
    row.Model:PivotTo(CFrame.new(ray.Origin+ray.Direction*distance)*camera.CFrame.Rotation*CFrame.Angles(0,self.Angle,0)*row.Rotation)
    local plateRay=camera:ScreenPointToRay(center.X,center.Y)
    row.Back.Size=Vector3.new(worldHeight*b.X/(b.Y*.51),worldHeight*.66/.51,.01)
    row.Back.CFrame=CFrame.new(plateRay.Origin+plateRay.Direction*(distance+.12))*camera.CFrame.Rotation
    row.Back.Parent=workspace;row.Model.Parent=workspace;row.Card.BackgroundTransparency=1
    if self.Time-row.LastBurst>=2.5 then
     local budget=8;for _,burst in ipairs(row.Bursts)do local amount=math.min(budget,burst.Count);if amount>0 then burst.Emitter:Emit(amount);budget-=amount end end
     row.LastBurst=self.Time
    end
   end
  else
   row.Card.BackgroundTransparency=0;row.Card.BackgroundColor3=row.Outcome.Color:Lerp(Color3.fromRGB(8,12,23),.85)
   self:Release(row)
  end
 end
end
function Gallery:Destroy()self:Clear()end
return Gallery
