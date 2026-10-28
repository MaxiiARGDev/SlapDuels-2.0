--!nonstrict
-- Bounded visual clones exclusively inside ViewportFrames; no workspace or input ownership.
local RS=game:GetService('ReplicatedStorage')
local Players=game:GetService('Players')
local Appearance=require(RS.Shared.SlapCrates.Appearance)
local Pool={};Pool.__index=Pool
function Pool.new(maximum)return setmetatable({Rows={},Count=0,Maximum=maximum},Pool)end
function Pool:Remove(view)
 local row=self.Rows[view];if not row then return end
 self.Rows[view]=nil;self.Count-=1
 for _,connection in ipairs(row.Connections)do connection:Disconnect()end
 view.CurrentCamera=nil;row.World:Destroy();row.Camera:Destroy()
end
function Pool:Clear()local keys={};for view in pairs(self.Rows)do table.insert(keys,view)end;for _,view in ipairs(keys)do self:Remove(view)end end
local function clean(model)
 for _,p in ipairs(model:GetDescendants())do
  if p:IsA('LuaSourceContainer')or p:IsA('Tool')or p:IsA('Sound')then p:Destroy()
  elseif p:IsA('BasePart')then p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
  elseif p:IsA('ParticleEmitter')then p.Enabled=false -- Viewport preview uses authored tint plus UI aura; no workspace emitters.
  end
 end
end
function Pool:Add(view,source,avatar)
 if self.Rows[view]then return true end
 if self.Count>=self.Maximum or not source or not view.Parent then return false end
 local model
 if avatar then
  local char=source.Character;if not char then return false end
  local humanoid=char:FindFirstChildOfClass('Humanoid');if not humanoid then return false end
  -- Clone the existing visual character; no web lookup, no temporary models in Workspace.
  local original=char.Archivable;char.Archivable=true
  local ok,result=pcall(char.Clone,char);char.Archivable=original
  if not ok or not result then return false end;model=result
 else model=source:Clone()end
 if not model:IsA('Model')then model:Destroy();return false end
 clean(model)
 local world=Instance.new('WorldModel');world.Name='SocialPreviewWorld';world.Parent=view
 local camera=Instance.new('Camera');camera.Name='SocialPreviewCamera';camera.FieldOfView=35;camera.Parent=view
 model.Parent=world
 if avatar then model:PivotTo(CFrame.new())end -- Neutral forward orientation; camera looks at the avatar's front.
 local box,size=model:GetBoundingBox();model:PivotTo(CFrame.new(-box.Position)*model:GetPivot())
 local row={World=world,Camera=camera,Model=model,Avatar=avatar,Base=model:GetPivot(),Size=size,Angle=0,Connections={}}
 local function fit()
  if not view.Parent then return end
  local aspect=math.max(0.2,view.AbsoluteSize.X/math.max(1,view.AbsoluteSize.Y))
  local radius=math.max(0.5,size.Magnitude/2)
  local half=math.atan(math.tan(math.rad(camera.FieldOfView/2))*math.min(1,aspect))
  local distance=radius/math.sin(half)*1.12
  camera.CFrame=CFrame.lookAt(Vector3.new(0,0,avatar and -distance or distance),Vector3.zero)
 end
 table.insert(row.Connections,view:GetPropertyChangedSignal('AbsoluteSize'):Connect(fit))
 table.insert(row.Connections,view.Destroying:Connect(function()self:Remove(view)end))
 self.Rows[view]=row;self.Count+=1;view.CurrentCamera=camera;fit();return true
end
function Pool:Slap(view,item)
 local roots=RS:FindFirstChild('SlapVariationPreviews');local base=roots and roots:FindFirstChild(item.SlapId)
 local source=base and base:FindFirstChild(item.VariationId)
 if not source then local fallback=RS:FindFirstChild('CrateRewardPreviews');source=fallback and fallback:FindFirstChild(item.SlapId)end
 if not self:Add(view,source,false)then return false end
 local row=self.Rows[view];local part=row.Model:FindFirstChildWhichIsA('BasePart',true)
 local effects=RS:FindFirstChild('SlapVariationEffects');local profile=effects and effects:FindFirstChild(item.VariationId)
 if part then Appearance.Apply(part,profile);clean(row.Model)end
 return true
end
function Pool:Step(dt)
 for view,row in pairs(self.Rows)do
  if view.Parent then
   row.Angle+=dt*(row.Avatar and 0.08 or 0.45)
   row.Model:PivotTo(CFrame.Angles(0,row.Angle,0)*row.Base)
  end
 end
end
return Pool
