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
 self._context=context;self._runs={};self._seen={};self._idle={};self._connections={}
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
 if self._private==run then self._private=nil end
 for _,t in ipairs(run.Tweens)do pcall(function()t:Cancel();t:Destroy()end)end
 for _,obj in ipairs(run.Objects)do pcall(function()obj:Destroy()end)end
 if run.Private and self._hud then self._hud.Enabled=false end
end
function Controller:_fade(run,transparency,duration)
 if not run.Private then return end
 local tween=Tween:Create(self._hud.Transition,TweenInfo.new(duration),{BackgroundTransparency=transparency})
 table.insert(run.Tweens,tween);tween:Play()
end
function Controller:_sound(run,name)
 local sound=run.Effects:FindFirstChild(name,true)
 if sound and sound:IsA("Sound")and sound.SoundId~=""then sound:Play()end
end
function Controller:_phase(run,stage)
 if stage==run.Stage then return end;run.Stage=stage
 self:_sound(run,stage)
 if stage=="Appear"or stage=="Rise"or stage=="Growth"then
  for _,obj in ipairs(run.Effects:GetDescendants())do if obj:IsA("ParticleEmitter")then obj:Emit(5)end end
 end
 if stage=="Intro"then self:_fade(run,0,Config.Cinematic.IntroTransitionDuration)
 elseif stage=="CameraReveal"and run.Private then
  run.Lease.Camera.CameraType=Enum.CameraType.Scriptable
  self:_fade(run,1,Config.Cinematic.CameraRevealDuration)
 elseif stage=="Outro"then self:_fade(run,0,Config.Cinematic.OutroTransitionDuration*.5)end
 if stage=="Flash"then
  for _,obj in ipairs(run.Effects:GetDescendants())do if obj:IsA("ParticleEmitter")then obj:Emit(math.min(obj:GetAttribute("BurstCount")or 10,24))end end
  if run.Private then
   self._hud.Flash.BackgroundTransparency=.25
   local t=Tween:Create(self._hud.Flash,TweenInfo.new(Config.Cinematic.FlashDuration),{BackgroundTransparency=1})
   table.insert(run.Tweens,t);t:Play()
  end
 elseif stage=="Reward"then
  run.Reward.Parent=run.Scene;run.Label.Enabled=true
  if run.RewardSound and run.RewardSound.SoundId~=""then run.RewardSound:Play()end
  for _,item in ipairs(run.Reward:GetDescendants())do if item:IsA("ParticleEmitter")then item:Emit(math.min(item:GetAttribute("RevealBurstCount")or 6,12))end end
 end
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
   local shop=self._context:GetController("ShopController");if shop then shop:Close()end
   local crates=self._context:GetController("CrateController");if crates and crates._panel then crates._panel.Visible=false end
   self._hud.Enabled=true;self._hud.Transition.BackgroundTransparency=1;self._hud.Flash.BackgroundTransparency=1
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
  if age>=self._plan.Stages[8].Start then run.Reward.Parent=scene;run.Label.Enabled=true end
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
 local height,scale=0,.15
 if stage=="Appear"then height=p*.5;scale=.15+p*.65
 elseif stage=="Rise"then height=.5+p*2;scale=.8
 elseif stage=="Growth"then height=2.5;scale=.8+p*.45
 elseif stage=="Shake"or stage=="Flash"then height=2.5;scale=1.25 end
 local pose=run.Stand.SpawnPoint.CFrame*CFrame.new(0,height,0)*CFrame.Angles(0,elapsed*(if stage=="Growth"then 2 else .6),0)
 if stage=="Shake"then pose*=CFrame.new(math.sin(elapsed*55)*.09,math.cos(elapsed*47)*.07,0)end
 if stage~="Reward"and stage~="Outro"then
  run.Chest:PivotTo(pose);run.Chest:ScaleTo(run.BaseScale*scale)
 else run.Chest.Parent=nil end
 run.Scene.RewardAnchor.CFrame=run.Stand.RewardPoint.CFrame
 if run.Reward.Parent then run.Reward:PivotTo(run.Stand.RewardPoint.CFrame*CFrame.new(0,math.sin(elapsed*2)*.15,0)*CFrame.Angles(0,elapsed*.65,0))end
 local light=run.Effects:FindFirstChildWhichIsA("PointLight",true)
 if light then light.Brightness=if stage=="Flash"then (1-p)*5 elseif stage=="Growth"or stage=="Shake"then 1+p else .4 end
 run.Effects.FXAnchor.EnergyBeam.Enabled=stage=="Growth"or stage=="Shake"
 if run.Private then
  if stage=="Outro"and p>=.5 then
   if not run.Restored then self:_restore(run);self:_fade(run,1,Config.Cinematic.OutroTransitionDuration*.5)end
  elseif stage~="Intro"and not run.Restored then
   local camera=run.Lease.Camera;local cameraPoint=run.Stand.CameraPoint
   camera.CameraType=Enum.CameraType.Scriptable
   local focus=if stage=="Reward"then run.Stand.RewardPoint.Position else pose.Position
   local position=cameraPoint.Position:Lerp(focus,.035*math.sin(math.min(elapsed,8)*.2))
   camera.CFrame=CFrame.lookAt(position,focus,cameraPoint.CFrame.UpVector)
   camera.FieldOfView=run.Lease.FieldOfView-4*math.clamp(elapsed/self._plan.Duration,0,1)
  end
 end
end
function Controller:_idleUpdate(now)
 local folder=workspace:FindFirstChild("CrateStands")
 for _,stand in ipairs(folder and folder:GetChildren()or {})do
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
    if crate then
     gui.Title.Text=crate.DisplayName
     gui.Price.Text=if crate.PriceApproved then tostring(crate.PriceCoins).." Coins"else "Precio pendiente"
     gui.Status.Text=if not crate.OddsApproved then "Probabilidades pendientes"elseif not crate.Enabled then "No disponible"else "Ver probabilidades"
     local variation=Catalog.Variations.ById[crate.CrateId];if variation then gui.Title.TextColor3=variation.Color end
    end
   end
  end
 end
end
function Controller:Start()
 task.spawn(function()
  self._hud=player:WaitForChild("PlayerGui"):WaitForChild("CrateOpeningHUD",15)
  local remotes=RS:WaitForChild("Remotes"):WaitForChild("Crates",15)
  if not self._hud or not remotes then warn("[CrateStand] Missing Edit resources");return end
  self._hud.Enabled=false
  table.insert(self._connections,remotes:WaitForChild("StandPresentation").OnClientEvent:Connect(function(packet)
   if type(packet)~="table"then return end
   if packet.Kind=="Access"then
    local crates=self._context:GetController("CrateController");if crates then crates._standId=packet.StandId end
    local shop=self._context:GetController("ShopController");if shop and not self:_priority()and not self:IsPlaying()then shop:OpenCategory("Crates")end
   elseif packet.Kind=="Cancel"then self:_stop(packet.OpeningId,"ServerRelease")
   elseif packet.Kind=="Opening"then self:Play(packet)end
  end))
  table.insert(self._connections,Run.RenderStepped:Connect(function()
   local now=workspace:GetServerTimeNow()
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
end
return Controller
