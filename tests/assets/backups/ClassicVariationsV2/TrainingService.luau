--!nonstrict
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Run=game:GetService('RunService')
local Http=game:GetService('HttpService')
local Config=require(RS.Shared.Config)
local Settings=require(RS.Shared.TrainingConfig)
local State=require(script.Parent.Gameplay.TrainingState)
local Service={Name='TrainingService'}
function Service:IsInside(player)
 local c=player.Character;local root=c and c:FindFirstChild('HumanoidRootPart');local h=c and c:FindFirstChildOfClass('Humanoid')
 if player.Parent~=Players or not root or not h or h.Health<=0 or not self.Bounds or not self.Bounds:IsDescendantOf(workspace)then return false end
 if self.Rounds:GetSessionForPlayer(player)or player:GetAttribute('ResultsSessionId')~=nil then return false end
 local p=self.Bounds.CFrame:PointToObjectSpace(root.Position);local half=self.Bounds.Size/2
 return math.abs(p.X)<=half.X and math.abs(p.Y)<=half.Y and math.abs(p.Z)<=half.Z
end
function Service:IsAuthorizedTool(player,tool)
 local r=self.Sessions and self.Sessions[player]
 return r~=nil and r.Tool==tool and r.Character==player.Character and tool.Parent==player.Character and self:IsInside(player)
end
function Service:Stop(player)
 local r=self.Sessions[player];if not r then return end
 self.Sessions[player]=nil
 if r.Connection then r.Connection:Disconnect()end
 if r.Tool then r.Tool:Destroy()end
 if player.Parent==Players and player:GetAttribute('TrainingSessionId')==r.Id then player:SetAttribute('TrainingSessionId',nil)end
end
function Service:Join(player)
 local now=workspace:GetServerTimeNow()
 if now-(self.LastEntry[player]or -math.huge)<.5 then return end
 self.LastEntry[player]=now
 if self.Sessions[player]then self:Stop(player);return end
 local root=player.Character and player.Character:FindFirstChild('HumanoidRootPart')
 if not self:IsInside(player)or not root or (root.Position-self.Entry.Position).Magnitude>Settings.EntryDistance then return end
 local crates=self.Context:GetService('CrateService');local reward=crates and crates:ResolveEquipped(player)
 local name=reward and crates:GetSlapModel(reward)or 'Classic';local template=self.Slaps:GetSlapTemplate(name)
 if not template then return end
 local tool=template:Clone();tool.Name='Slap de práctica';tool.CanBeDropped=false
 for _,o in ipairs(tool:GetDescendants())do if o:IsA('LuaSourceContainer')then o:Destroy()end end
 tool:SetAttribute('IsSlapWeapon',false);tool:SetAttribute('IsTrainingSlap',true)
 if reward then crates:ApplyVariation(tool,reward)end
 local record={Id=Http:GenerateGUID(false),Character=player.Character,Tool=tool,ReadyAt=0,LastSequence=0}
 self.Sessions[player]=record
 record.Connection=player.CharacterRemoving:Connect(function()if self.Sessions[player]==record then self:Stop(player)end end)
 player:SetAttribute('TrainingSessionId',record.Id)
 local backpack=player:FindFirstChildOfClass('Backpack');local hum=player.Character:FindFirstChildOfClass('Humanoid')
 tool.Parent=backpack or player.Character;if backpack then hum:EquipTool(tool)end
end
function Service:Feedback(player,record,sequence,hit,reason)
 if player.Parent==Players then self.Updated:FireClient(player,{SessionId=record.Id,Sequence=sequence,Hit=hit,Reason=reason,ReadyAt=record.ReadyAt or 0})end
end
function Service:RecoverDummy()
 if self.Recovery then pcall(task.cancel,self.Recovery);self.Recovery=nil end
 local dummy=self.Dummy
 if not dummy or not dummy.Parent then return end
 local root=dummy:FindFirstChild('HumanoidRootPart')
 if not root then return end
 root.Anchored=true;self.Ragdoll:ResetRagdollImmediate(dummy,true)
 dummy:PivotTo(self.Home.CFrame)
 for _,p in ipairs(dummy:GetDescendants())do if p:IsA('BasePart')then p.AssemblyLinearVelocity=Vector3.zero;p.AssemblyAngularVelocity=Vector3.zero end end
 local h=dummy:FindFirstChildOfClass('Humanoid');if h then h.WalkSpeed=0;h.JumpPower=0;h.Jump=false end
 root.Anchored=true;self.DummyDown=false;dummy:SetAttribute('TrainingReadyAt',nil)
end
function Service:HitDummy(attackerRoot,power)
 local dummy=self.Dummy;local root=dummy and dummy:FindFirstChild('HumanoidRootPart');local h=dummy and dummy:FindFirstChildOfClass('Humanoid')
 if self.DummyDown or not root or not h or h.Health<=0 or self.Ragdoll:IsRagdolled(dummy)then return false,'DummyProtected'end
 local reachable=self.Slaps:CheckTargetGeometry(attackerRoot,root)
 if not reachable then return false,'Miss'end
 self.DummyDown=true;root.Anchored=false
 for _,p in ipairs(dummy:GetDescendants())do if p:IsA('BasePart')then pcall(function()p:SetNetworkOwner(nil)end)end end
 local velocity=self.Slaps:ComputeSlapLaunchVelocity(attackerRoot,root,power)
 -- Only this service owns recovery/return for its one explicit NPC. Never tag a Player.
 local ok=self.Ragdoll:ApplyRagdoll(dummy,0,velocity)
 if not ok then self:RecoverDummy();return false,'RagdollUnavailable'end
 local duration=Config.Combat.DefaultSlapKnockdownDuration
 dummy:SetAttribute('TrainingReadyAt',workspace:GetServerTimeNow()+duration)
 self.Recovery=task.delay(duration,function()self.Recovery=nil;if self.Dummy==dummy then self:RecoverDummy()end end)
 return true
end
function Service:Activate(player,tool,sessionId,sequence)
 local record=self.Sessions[player]
 if not record or record.Id~=sessionId or not self:IsAuthorizedTool(player,tool)then return end
 local now=workspace:GetServerTimeNow()
 if now-(record.LastRequest or -math.huge)<Settings.RequestInterval then return end
 record.LastRequest=now
 local started,why=State.Begin(record,sequence,now)
 if not started then if why~='InvalidSequence'then self:Feedback(player,record,sequence,false,why)end;return end
 local config=tool:FindFirstChild('Configuration');local p=config and config:FindFirstChild('Power');local c=config and config:FindFirstChild('SlapCooldown')
 if not p or not c or not p:IsA('NumberValue')or not c:IsA('NumberValue')or p.Value~=p.Value or p.Value<=0 or p.Value==math.huge or c.Value~=c.Value or c.Value<0 or c.Value==math.huge then
  record.Pending=nil;return
 end
 local combo=Config.Combat.SlapCombo;local deadline=now+(combo.Enabled and combo.SwingWindow or 0)
 local hit,reason=false,'Miss'
 local ok=pcall(function()
  repeat
   if self.Sessions[player]~=record or not self:IsAuthorizedTool(player,tool)then reason='PracticeEnded';break end
   local hum=player.Character:FindFirstChildOfClass('Humanoid')
   if hum.PlatformStand or hum:GetAttribute('MovementLocked')or player.Character:GetAttribute('ArenaRespawnPending')then reason='Unavailable';break end
   local root=player.Character:FindFirstChild('HumanoidRootPart')
   hit,reason=self:HitDummy(root,p.Value)
   if hit or workspace:GetServerTimeNow()>=deadline then break end
   task.wait(math.min(combo.SampleInterval,math.max(0,deadline-workspace:GetServerTimeNow())))
  until false
 end)
 if not ok then reason='PracticeError';self:RecoverDummy()end
 if self.Sessions[player]~=record then return end
 State.Finish(record,sequence,workspace:GetServerTimeNow(),hit,combo,c.Value)
 if hit then local hand=tool:FindFirstChild('Hand');local sound=hand and hand:FindFirstChild('Hit');if sound and sound:IsA('Sound')then pcall(sound.Play,sound)end end
 self:Feedback(player,record,sequence,hit,reason)
end
function Service:Init(context)
 self.Context=context;self.Slaps=context:GetService('SlapService');self.Ragdoll=context:GetService('RagdollService');self.Rounds=context:GetService('RoundService')
 assert(self.Slaps and self.Ragdoll and self.Rounds,'Training dependencies missing')
 self.Sessions={};self.LastEntry={};self.Connections={};self.DummyDown=false
 local remotes=RS:WaitForChild('Remotes');local folder=remotes:FindFirstChild('Training')
 if not folder then folder=Instance.new('Folder');folder.Name='Training';folder.Parent=remotes end
 local function event(name)local o=folder:FindFirstChild(name);if o then assert(o:IsA('RemoteEvent'));return o end;o=Instance.new('RemoteEvent');o.Name=name;o.Parent=folder;return o end
 self.ActivateRemote=event('Activate');self.LeaveRemote=event('Leave');self.Updated=event('Updated')
end
function Service:BindDummy()
 if self.DummyConnection then self.DummyConnection:Disconnect()end
 local dummy=self.Dummy
 self.DummyConnection=dummy.Destroying:Connect(function()
  if self.Recovery then pcall(task.cancel,self.Recovery);self.Recovery=nil end
  pcall(self.Ragdoll.ResetRagdollImmediate,self.Ragdoll,dummy,true)
 end)
end
function Service:Start()
 self.Zone=workspace:FindFirstChild(Settings.ZoneName)
 if not self.Zone then warn('[Training] TrainingZone missing in Edit; disabled');return end
 self.Bounds=self.Zone:FindFirstChild('Bounds');self.Home=self.Zone:FindFirstChild('DummyHome');self.Entry=self.Zone:FindFirstChild('EntryPad');self.Dummy=self.Zone:FindFirstChild('TrainingDummy')
 assert(self.Bounds and self.Home and self.Entry and self.Dummy,'Incomplete physical training zone')
 self.Template=self.Dummy:Clone();self:BindDummy();self:RecoverDummy()
 table.insert(self.Connections,self.Entry.TrainPrompt.Triggered:Connect(function(p)self:Join(p)end))
 table.insert(self.Connections,self.ActivateRemote.OnServerEvent:Connect(function(...)self:Activate(...)end))
 table.insert(self.Connections,self.LeaveRemote.OnServerEvent:Connect(function(p)self:Stop(p)end))
 table.insert(self.Connections,Players.PlayerRemoving:Connect(function(p)self:Stop(p);self.LastEntry[p]=nil end))
 local elapsed=0
 table.insert(self.Connections,Run.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<Settings.PollInterval then return end;elapsed=0
  for p in pairs(self.Sessions)do if not self:IsInside(p)then self:Stop(p)end end
  local root=self.Dummy and self.Dummy:FindFirstChild('HumanoidRootPart');local h=self.Dummy and self.Dummy:FindFirstChildOfClass('Humanoid')
  if not self.Dummy or not self.Dummy.Parent or not root or not h or h.Health<=0 then
   if self.Dummy and self.Dummy.Parent then self:RecoverDummy();self.Dummy:Destroy()end
   self.Dummy=self.Template:Clone();self.Dummy.Parent=self.Zone;self:BindDummy();self:RecoverDummy()
  end
 end))
 game:BindToClose(function()for p in pairs(self.Sessions)do self:Stop(p)end;if self.Recovery then pcall(task.cancel,self.Recovery);self.Recovery=nil end;self:RecoverDummy()end)
end
return Service
