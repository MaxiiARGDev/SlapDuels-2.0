--!nonstrict
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Tween=game:GetService("TweenService")
local CAS=game:GetService("ContextActionService")
local Config=require(RS.Shared.SlapCrates.OpeningConfig)
local Timeline=require(RS.Shared.SlapCrates.OpeningTimeline)
local Catalog=require(RS.Shared.SlapCrates.Catalog)
local Appearance=require(RS.Shared.SlapCrates.Appearance)
local CameraLease=require(script.Parent.Parent.CrateOpening.CameraLease)
local CharacterVisibility=require(script.Parent.Parent.CrateOpening.CharacterVisibility)
local CinematicConfig=require(script.Parent.Parent.CrateOpening.CinematicConfig)
local CinematicMotion=require(script.Parent.Parent.CrateOpening.CinematicMotion)
local CinematicTransition=require(script.Parent.Parent.CrateOpening.CinematicTransition)
local StandPromptVisibility=require(script.Parent.Parent.CrateOpening.StandPromptVisibility)
local VisualProfile=require(script.Parent.Parent.CrateOpening.VisualProfile)
local OverlayPresenter=require(script.Parent.Parent.CrateOpening.RewardOverlayPresenter)
local Controller={Name="CrateStandCinematicController"}
local player=Players.LocalPlayer
local function safeVisual(model)
 for _,obj in ipairs(model:GetDescendants())do
  if obj:IsA("LuaSourceContainer")then obj:Destroy()
  elseif obj:IsA("BasePart")then obj.Anchored=true;obj.CanCollide=false;obj.CanTouch=false;obj.CanQuery=false
  elseif obj:IsA("ParticleEmitter")then obj.Enabled=false;obj.Rate=math.min(obj.Rate,8)end
 end
end
local function standById(id)
 local folder=workspace:FindFirstChild("CrateStands");local result
 for _,stand in ipairs(folder and folder:GetChildren()or {})do if stand:GetAttribute("StandId")==id then if result then return nil end;result=stand end end
 return result
end
function Controller:Init(context)
 self._context=context;self._runs={};self._seen={};self._idle={};self._connections={};self._cooldowns={}
 self._plan=Timeline.Build(Config)
end
function Controller:IsPlaying()return self._private~=nil end
function Controller:_priority()
 local ending=self._context:GetController("EndCinematicController")
 return player:GetAttribute("MatchId")~=nil or player:GetAttribute("ResultsSessionId")~=nil or(ending and ending:IsPlaying())
end
function Controller:_restore(run)
 if run.Restored then return end;run.Restored=true
 if run.Action then CAS:UnbindAction(run.Action)end
 local character=player.Character;local humanoid=character and character:FindFirstChildOfClass("Humanoid")
 if humanoid and humanoid.Health<=0 then character=nil end
 if run.Lease then CameraLease.Restore(run.Lease,character,self:_priority()or workspace.CurrentCamera~=run.Lease.Camera)end
 CharacterVisibility.Release(run.Visibility);run.Visibility=nil
 if run.MusicToken then
  local music=self._context:GetController("MusicController")
  if music then music:Resume("CrateStand:"..run.Id,run.MusicToken,.3)end
 end
end
function Controller:_stop(id,reason)
 local run=self._runs[id];if not run then return end
 self._runs[id]=nil
 local restored,failure=pcall(self._restore,self,run)
 if not restored then warn("[CrateStand] Restore failure: "..tostring(failure))end
 CharacterVisibility.Release(run.Visibility);run.Visibility=nil
 StandPromptVisibility.Release(run.PromptVisibility);run.PromptVisibility=nil
 if self._private==run then self._private=nil end
 for _,t in ipairs(run.Tweens)do pcall(function()t:Cancel();t:Destroy()end)end
 for _,obj in ipairs(run.Objects)do pcall(function()obj:Destroy()end)end
 if run.Private and self._overlay then self._overlay:Reset(run.Id)end
 if run.Private and self._hud then
  CinematicTransition.Reset(self._hud)
  self._hud.Enabled=false;self._hud.Transition.BackgroundTransparency=1;self._hud.Flash.BackgroundTransparency=1
  self._hud.Transition.Visible=false;self._hud.Flash.Visible=false
 end
end
function Controller:_sound(run,name)
 local sound=run.Effects:FindFirstChild(name,true)
 if sound and sound:IsA("Sound")and sound.SoundId~=""then sound:Play()end
end
function Controller:_whoosh(run,name)
 if not run.Private then return end
 local source=run.Effects:FindFirstChild(name,true)
 if source and source:IsA("Sound")and source.SoundId~=""then
  local sound=source:Clone();sound.Volume=CinematicConfig.Audio.Volume
  sound.Parent=game:GetService("SoundService");table.insert(run.Objects,sound);sound:Play()
 end
end
function Controller:_phase(run,stage)
 if stage==run.Stage then return end;run.Stage=stage
 self:_sound(run,stage)
 VisualProfile.Emit(run.Effects,stage,run.Profile)
 if stage=="Intro"then self:_whoosh(run,CinematicConfig.Audio.Close)
 elseif stage=="CameraReveal"and run.Private then
  run.Visibility=CharacterVisibility.Acquire(Players,run.Id)
  run.Lease.Camera.CameraType=Enum.CameraType.Scriptable
  self:_whoosh(run,CinematicConfig.Audio.Open)
 elseif stage=="Outro"then
  self:_whoosh(run,CinematicConfig.Audio.Close)
 end
 if stage=="Flash"then
  if run.Private then
   self._hud.Flash.BackgroundTransparency=.25
   local t=Tween:Create(self._hud.Flash,TweenInfo.new(Config.Cinematic.FlashDuration),{BackgroundTransparency=1})
   table.insert(run.Tweens,t);t:Play()
  end
 elseif stage=="Reward"then
  run.Reward.Parent=run.Scene;run.Label.Enabled=true
  self:_showReward(run)
  if run.RewardSound and run.RewardSound.SoundId~=""then run.RewardSound:Play()end
  for _,item in ipairs(run.Reward:GetDescendants())do if item:IsA("ParticleEmitter")then item:Emit(math.min(item:GetAttribute("RevealBurstCount")or 6,12))end end
 end
end
function Controller:_showReward(run)
 if not run.RewardDefinition then return end
 if run.Private and self._overlay and CinematicConfig.RewardOverlayByMode.StandCinematic then
  self._overlay:Show(run,Catalog.Slaps.ById[run.RewardDefinition.SlapId],run.RewardVariation)
 end
 if run.Profile and run.Profile.Special and not run.SpecialPlayed then run.SpecialPlayed=true;self:_sound(run,"Special")end
end
function Controller:Play(packet)
 if not self._plan or packet.Mode~="StandCinematic"or type(packet.OpeningId)~="string"or self._seen[packet.OpeningId]
  or type(packet.StartedAt)~="number"or packet.StartedAt~=packet.StartedAt or type(packet.Operation)~="table"then return end
 local age=workspace:GetServerTimeNow()-packet.StartedAt
 if age< -1 or age>=self._plan.Duration or self:_priority()then return end
 local stand=standById(packet.StandId);local reward=Catalog.Rewards[packet.Operation.RewardId]
 local crate=Catalog.Crates.ById[packet.Operation.CrateId]
 if not stand or not reward or not crate then return end
 local private=packet.BuyerUserId==player.UserId
 if not private and packet.Exclusive~=true then return end
 if private and self._private then return end
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local radius=if private then Config.Stand.MaxActivationDistance else Config.Stand.SpectatorRadius
 if not root or(root.Position-stand.InteractionPart.Position).Magnitude>radius then return end
 local count=0;for _ in pairs(self._runs)do count+=1 end;if count>=6 then return end
 local run={Id=packet.OpeningId,Packet=packet,Stand=stand,Private=private,Objects={},Tweens={},Character=player.Character}
 self._seen[run.Id]=packet.StartedAt;self._runs[run.Id]=run
 local ok,err=pcall(function()
  if private then
   run.Lease=CameraLease.Acquire(workspace.CurrentCamera,run.Id,player.Character);assert(run.Lease,"CameraBusy")
   self._private=run
   if CinematicConfig.HideStandPrompt then run.PromptVisibility=StandPromptVisibility.Acquire(stand,run.Id)end
   local shop=self._context:GetController("ShopController");if shop then shop:Close()end
   local crates=self._context:GetController("CrateController");if crates and crates._panel then crates._panel.Visible=false end
   self._hud.Enabled=true;self._hud.Transition.BackgroundTransparency=1;self._hud.Flash.BackgroundTransparency=1
   self._hud.Transition.Visible=true;self._hud.Flash.Visible=true
   if self._overlay then self._overlay:Reset()end
   local overlay=self._hud:FindFirstChild("RewardOverlay");if overlay then overlay.Visible=false end
   CinematicTransition.Reset(self._hud)
   run.Action="CrateStand:"..run.Id
   CAS:BindActionAtPriority(run.Action,function()return Enum.ContextActionResult.Sink end,false,3000,table.unpack(Enum.PlayerActions:GetEnumItems()))
   local music=self._context:GetController("MusicController");if music then run.MusicToken=music:Suspend("CrateStand:"..run.Id,.3)end
  end
  local scene=stand.PresentationTemplate:Clone();scene.Name="CratePresentation_"..run.Id;scene.Parent=workspace
  table.insert(run.Objects,scene);run.Scene=scene;run.Effects=scene.Effects
  run.Effects:PivotTo(stand.SpawnPoint.CFrame);safeVisual(scene)
  local fx=run.Effects.FXAnchor;fx.EnergyBeam.Attachment0=fx.EnergyFrom;fx.EnergyBeam.Attachment1=fx.EnergyTo
  run.Chest=assert(RS.CrateEffects:FindFirstChild(crate.Model)):Clone();safeVisual(run.Chest)
  run.Chest.Parent=scene;table.insert(run.Objects,run.Chest);run.BaseScale=run.Chest:GetScale()
  local previews=RS:FindFirstChild("SlapVariationPreviews");local slap=previews and previews:FindFirstChild(reward.SlapId)
  local source=slap and slap:FindFirstChild(reward.VariationId)
  source=source or RS.CrateRewardPreviews:FindFirstChild(reward.SlapId);assert(source,"RewardPreviewMissing")
  run.Reward=source:Clone();table.insert(run.Objects,run.Reward);safeVisual(run.Reward)
  local variation=Catalog.Variations.ById[reward.VariationId]
  run.Profile=VisualProfile.For(variation);run.RewardDefinition=reward
  local part=run.Reward:FindFirstChildWhichIsA("BasePart",true)
  if part then
   local profile=RS.SlapVariationEffects:FindFirstChild(variation.VisualProfile)
   Appearance.Apply(part,profile)
   local sound=profile and profile:FindFirstChild(variation.SFX,true)
   if sound and sound:IsA("Sound")then run.RewardSound=sound:Clone();run.RewardSound.Parent=part end
  end
  run.Label=scene.RewardBillboard;run.Label.Adornee=scene.RewardAnchor
  run.Label.Title.Text="¡RECOMPENSA OBTENIDA!";run.Label.Slap.Text=Catalog.Slaps.ById[reward.SlapId].DisplayName
  run.Label.Variation.Text=variation.DisplayName;run.Label.Variation.TextColor3=variation.Color
  run.RewardVariation=variation
  local beam=fx.EnergyBeam;run.BeamWidth=beam.Width0;beam.Color=ColorSequence.new(variation.Color)
  for _,item in ipairs(run.Effects:GetDescendants())do if item:IsA("PointLight")then item.Color=variation.Color end end
  if age>=self._plan.Stages[8].Start then run.Reward.Parent=scene;run.Label.Enabled=true;self:_showReward(run)end
  self:_sound(run,"Start")
 end)
 if not ok then warn("[CrateStand] Presentation failed; reward retained: "..tostring(err));self:_stop(run.Id,"Error")end
end
function Controller:_update(run,now)
 if not run.Stand.Parent or player.Character~=run.Character or self:_priority()then self:_stop(run.Id,"ContextChanged");return end
 local hum=run.Character and run.Character:FindFirstChildOfClass("Humanoid")
 if not hum or hum.Health<=0 then self:_stop(run.Id,"CharacterLost");return end
 if run.Private and not run.Restored and(not CameraLease.Owns(run.Lease)or workspace.CurrentCamera~=run.Lease.Camera)then self:_stop(run.Id,"CameraLost");return end
 local elapsed=now-run.Packet.StartedAt;local stage,p=Timeline.At(self._plan,elapsed)
 if stage=="Done"then self:_stop(run.Id,"Completed");return end
 self:_phase(run,stage)
 if run.Private then CinematicTransition.Update(self._hud,CinematicMotion.Cover(stage,p,CinematicConfig.Transition))end
 local profile=run.Profile or {Light=1,Bob=.15,Spin=.65,Zoom=4}
 local height,scale=VisualProfile.Pose(stage,p)
 local pose=run.Stand.SpawnPoint.CFrame*CFrame.new(0,height,0)*CFrame.Angles(0,VisualProfile.Rotation(self._plan,elapsed),0)
 if stage=="Shake"then local strength=.025+.065*p;pose*=CFrame.new(math.sin(elapsed*55)*strength,math.cos(elapsed*47)*strength*.7,0)end
 if stage~="Reward"and stage~="Outro"and(stage~="Flash"or p<.25)then
  run.Chest:PivotTo(pose);run.Chest:ScaleTo(run.BaseScale*scale)
 else run.Chest.Parent=nil end
 run.Scene.RewardAnchor.CFrame=run.Stand.RewardPoint.CFrame
 if run.Reward.Parent then run.Reward:PivotTo(run.Stand.RewardPoint.CFrame*CFrame.new(0,math.sin(elapsed*2)*profile.Bob,0)*CFrame.Angles(0,elapsed*profile.Spin,0))end
 local light=run.Effects:FindFirstChildWhichIsA("PointLight",true)
 if light then light.Brightness=(if stage=="Flash"then (1-p)*3 elseif stage=="Growth"or stage=="Shake"then .8+p else .3)*profile.Light end
 run.Effects.FXAnchor.EnergyBeam.Enabled=stage=="Growth"or stage=="Shake"
 if run.BeamWidth then run.Effects.FXAnchor.EnergyBeam.Width0=run.BeamWidth*(.92+.08*math.sin(elapsed*4))end
 if run.Private then
  if stage=="Outro"and p>=CinematicConfig.Transition.OutroHandoff then
   if not run.Restored then
    CinematicTransition.Update(self._hud,.5)
    self:_restore(run);self:_whoosh(run,CinematicConfig.Audio.Open)
   end
  elseif stage~="Intro"and not run.Restored then
   local camera=run.Lease.Camera;local cameraPoint=run.Stand.CameraPoint
   -- Late packets can skip CameraReveal; acquire before the first camera write.
   if not run.Visibility then run.Visibility=CharacterVisibility.Acquire(Players,run.Id)end
   camera.CameraType=Enum.CameraType.Scriptable
   local focus=if stage=="Reward"or stage=="Outro"then run.Stand.RewardPoint.Position else pose.Position
   local dt=math.clamp(now-(run.LastCameraAt or now),0,.1);run.LastCameraAt=now
   local c=CinematicConfig.Camera
   run.CameraFocus=if run.CameraFocus then run.CameraFocus:Lerp(focus,1-math.exp(-c.FocusResponse*dt))else focus
   local motion=CinematicMotion.Sample(self._plan,elapsed,stage,p,c)
   local position=cameraPoint.Position:Lerp(focus,c.PushIn*math.sin(math.min(elapsed,8)*.2))
    +cameraPoint.CFrame.UpVector*c.IntroHeight*motion.Drop
    -cameraPoint.CFrame.LookVector*c.IntroBack*motion.Drop
   local target=run.CameraFocus+cameraPoint.CFrame.UpVector*c.IntroLookHeight*motion.Drop
   camera.CFrame=CFrame.lookAt(position,target,cameraPoint.CFrame.UpVector)
    *CFrame.new(motion.X,motion.Y,0)*CFrame.Angles(motion.Pitch,0,motion.Roll)
   camera.FieldOfView=math.clamp(run.Lease.FieldOfView-profile.Zoom*math.clamp(elapsed/self._plan.Duration,0,1)+motion.Fov,35,100)
  end
 end
end
function Controller:_idleUpdate(now)
 if now-(self._idleAt or -math.huge)<1/30 then return end;self._idleAt=now
 local updateLabels=now>=(self._labelsAt or 0);if updateLabels then self._labelsAt=now+.25 end
 local folder=workspace:FindFirstChild("CrateStands")
 for _,stand in ipairs(folder and folder:GetChildren()or {})do
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  local base=stand:FindFirstChild("Base")
  if root and base and(root.Position-base.Position).Magnitude>math.max(60,Config.Stand.SpectatorRadius*2)then continue end
  local cache=self._idle[stand]
  if not cache then
   cache={Parts={},Lights={}};self._idle[stand]=cache
   local decor=stand:FindFirstChild("VisualDecor")
   for _,item in ipairs(decor and decor:GetDescendants()or {})do
    if item:IsA("BasePart")and(item:GetAttribute("IdleMotion")or item.Parent.Name=="Shards"or item.Name=="Ring")then
     table.insert(cache.Parts,{Object=item,Pose=stand:GetPivot():ToObjectSpace(item.CFrame),Kind=item:GetAttribute("IdleMotion")or(if item.Name=="Ring"then "Rotate"else "Float")})
    elseif item:IsA("PointLight")then table.insert(cache.Lights,{Object=item,Brightness=item.Brightness})end
   end
  end
  for i,row in ipairs(cache.Parts)do if row.Object.Parent then
   local offset=if row.Kind=="Rotate"then CFrame.Angles(0,now*.16,0)else CFrame.new(0,math.sin(now*.9+i)*.12,0)*CFrame.Angles(0,math.sin(now*.5+i)*.06,0)
   row.Object.CFrame=stand:GetPivot()*row.Pose*offset
  end end
  for i,row in ipairs(cache.Lights)do if row.Object.Parent then row.Object.Brightness=row.Brightness*(.9+.1*math.sin(now*1.1+i))end end
  local anchors=stand:FindFirstChild("PreviewAnchors");local index=0
  for _,anchor in ipairs(anchors and anchors:GetChildren()or {})do
   if not anchor:IsA("BasePart")then continue end;index+=1
   local model=anchor:FindFirstChild("Decoration");local gui=anchor:FindFirstChildWhichIsA("BillboardGui")
   local visible=index<=Config.Stand.MaxIdleCrates and stand:GetAttribute("OpeningState")=="Idle"
   if model then
    for _,part in ipairs(model:GetDescendants())do if part:IsA("BasePart")then part.LocalTransparencyModifier=if visible then 0 else 1 end end
    if visible then model:PivotTo(anchor.CFrame*CFrame.new(0,math.sin(now*1.2+index)*.15,0)*CFrame.Angles(0,now*.2,0))end
   end
   if gui then
    gui.Enabled=visible
    local crate=Catalog.Crates.ById[anchor:GetAttribute("CrateId")]
    if crate and updateLabels then
     gui.Title.Text=crate.DisplayName
     gui.Price.Text=if crate.PriceApproved then tostring(crate.PriceCoins).." Coins"else "Precio pendiente"
     gui.Status.Text=if not crate.OddsApproved then "Probabilidades pendientes"elseif not crate.Enabled then "No disponible"else "Ver probabilidades"
     local variation=Catalog.Variations.ById[crate.CrateId];if variation then gui.Title.TextColor3=variation.Color end
    end
   end
  end
 end
 for stand in pairs(self._idle)do if not stand.Parent then self._idle[stand]=nil end end
end
function Controller:_cooldownUpdate(now)
 local label=self._hud and self._hud:FindFirstChild("CooldownLabel");if not label then return end
 for id,at in pairs(self._cooldowns)do if at<=now then self._cooldowns[id]=nil end end
 local crates=self._context:GetController("CrateController");local standId=crates and crates._standId
 local deadline=standId and self._cooldowns[standId]or 0
 local show=deadline>now and not self._private and not self:_priority()
 label.Visible=show
 if show then label.Text="ESPERA PERSONAL · "..tostring(standId).." · "..string.format("%.1f",deadline-now).." s";self._hud.Enabled=true
 elseif not self._private then self._hud.Enabled=false end
end
function Controller:Start()
 task.spawn(function()
  self._hud=player:WaitForChild("PlayerGui"):WaitForChild("CrateOpeningHUD",15)
  local remotes=RS:WaitForChild("Remotes"):WaitForChild("Crates",15)
  if not self._hud or not remotes then warn("[CrateStand] Missing Edit resources");return end
  self._hud.Enabled=false
  self._overlay=OverlayPresenter.new(self._hud:FindFirstChild("RewardOverlay"))
  table.insert(self._connections,remotes:WaitForChild("StandPresentation").OnClientEvent:Connect(function(packet)
   if type(packet)~="table"then return end
   if packet.Kind=="Access"then
    local crates=self._context:GetController("CrateController");if crates then crates._standId=packet.StandId end
    local shop=self._context:GetController("ShopController");if shop and not self:_priority()and not self:IsPlaying()then shop:OpenCategory("Crates")end
   elseif packet.Kind=="Cancel"then
    self:_stop(packet.OpeningId,"ServerRelease")
    if type(packet.StandId)=="string"and type(packet.CooldownUntil)=="number"and packet.CooldownUntil<workspace:GetServerTimeNow()+60 then self._cooldowns[packet.StandId]=packet.CooldownUntil end
   elseif packet.Kind=="Opening"then self:Play(packet)end
  end))
  table.insert(self._connections,Run.RenderStepped:Connect(function()
   local now=workspace:GetServerTimeNow()
   self:_cooldownUpdate(now)
   for id,at in pairs(self._seen)do if now-at>60 then self._seen[id]=nil end end
   for id,run in pairs(self._runs)do
    local ok,err=pcall(self._update,self,run,now)
    if not ok then warn("[CrateStand] "..tostring(err));self:_stop(id,"Error")end
   end
   if self._plan and Config.Mode=="StandCinematic"and Config.Stand.Enabled then self:_idleUpdate(now)end
  end))
 end)
end
function Controller:Destroy()
 for id in pairs(self._runs)do self:_stop(id,"Destroy")end
 for _,connection in ipairs(self._connections)do connection:Disconnect()end
 self._cooldowns={}
 for stand,cache in pairs(self._idle)do if stand.Parent then
  for _,row in ipairs(cache.Parts)do if row.Object.Parent then row.Object.CFrame=stand:GetPivot()*row.Pose end end
  for _,row in ipairs(cache.Lights)do if row.Object.Parent then row.Object.Brightness=row.Brightness end end
 end end
 self._idle={}
 if self._hud then self._hud.Enabled=false end
end
return Controller
