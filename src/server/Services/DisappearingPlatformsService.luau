--!nonstrict
-- Authoritative, instance-scoped platforms. One detector while registered maps exist.
local Config=require(game.ReplicatedStorage.Shared.DisappearingPlatformsConfig)
local Policy=require(script.Parent.Platforms.PlatformPolicy)
local Controller={}
Controller.__index=Controller
function Controller.new(raw,deps)
 local config,reason=Policy.Validate(raw)
 assert(config,reason)
 return setmetatable({Config=config,Deps=deps,Maps={},Heartbeat=nil,Elapsed=0},Controller)
end
function Controller:_current(record)
 if self.Maps[record.Id]~=record then return false end
 local session,info=record.Session,record.Info
 return not session.Closing and not session.Closed and not session.Cancelled and not session.Result
  and self.Deps.GetSession(record.Id)==session and session.InstanceInfo==info
  and self.Deps.GetInstance(record.Id)==info and info.InstanceModel==record.Map
  and record.Map.Parent==info.Container and record.Map:IsDescendantOf(self.Deps.World)
  and record.Geometry:IsDescendantOf(record.Map)
end
function Controller:_partCurrent(record,part,entry)
 return self:_current(record) and record.Parts[part]==entry and part:IsDescendantOf(record.Geometry)
end
local function release(entry)
 if entry.Timer then pcall(task.cancel,entry.Timer);entry.Timer=nil end
 if entry.Connection then entry.Connection:Disconnect();entry.Connection=nil end
 if entry.Tween then entry.Tween:Cancel();entry.Tween:Destroy();entry.Tween=nil end
end
function Controller:UnbindMap(id,expectedInfo)
 local record=self.Maps[id]
 if not record or (expectedInfo and record.Info~=expectedInfo) then return end
 self.Maps[id]=nil -- invalidate callbacks BEFORE cancellation can dispatch Completed.
 for _,connection in ipairs(record.Connections) do connection:Disconnect() end
 for _,entry in pairs(record.Parts) do release(entry) end
 table.clear(record.Parts);table.clear(record.Connections)
 record.Session=nil;record.Info=nil;record.Map=nil;record.Geometry=nil
 if next(self.Maps)==nil and self.Heartbeat then
  self.Heartbeat:Disconnect();self.Heartbeat=nil;self.Elapsed=0
 end
end
function Controller:BindMap(session,info)
 if not self.Config.Enabled then return true end
 if not session or not info or session.Id~=info.MatchId or self.Deps.GetSession(session.Id)~=session
  or self.Deps.GetInstance(session.Id)~=info then return false,"UnauthorizedMap" end
 local current=self.Maps[session.Id]
 if current then return current.Info==info,"AlreadyBound" end
 local map=info.InstanceModel
 if not map or not map:IsA("Model") or map.Parent~=info.Container or not map:IsDescendantOf(self.Deps.World)
  or map:IsDescendantOf(self.Deps.Templates) then return false,"ExpectedActiveClone" end
 local geometry=map:FindFirstChild(self.Config.GeometryFolderName)
 if not geometry or (not geometry:IsA("Folder") and not geometry:IsA("Model")) then return false,"GeometryMissing" end
 local record={Id=session.Id,Session=session,Info=info,Map=map,Geometry=geometry,Parts={},Connections={}}
 for _,part in ipairs(geometry:GetDescendants()) do
  if part:IsA("BasePart") and part.Name==self.Config.TargetPartName then
   record.Parts[part]={State="Idle"}
  end
 end
 if next(record.Parts)==nil then return true end
 self.Maps[record.Id]=record
 table.insert(record.Connections,map.Destroying:Connect(function()self:UnbindMap(record.Id,info)end))
 table.insert(record.Connections,map.AncestryChanged:Connect(function()
  if map.Parent~=info.Container or not map:IsDescendantOf(self.Deps.World) then self:UnbindMap(record.Id,info) end
 end))
 if not self.Heartbeat then
  self.Heartbeat=self.Deps.Heartbeat:Connect(function(dt)self:Step(dt)end)
 end
 local count=0
 for _ in pairs(record.Parts) do count+=1 end
 print(string.format("[DisappearingPlatforms] Bound Match=%s Map=%s Platforms=%d",record.Id,tostring(info.MapName),count))
 return true
end
function Controller:_fade(record,part,entry)
 if not self:_partCurrent(record,part,entry) or entry.State~="Triggered" then return end
 entry.State="Fading"
 local tween=self.Deps.TweenService:Create(part,TweenInfo.new(self.Config.FadeDuration,Enum.EasingStyle.Linear),{Transparency=1})
 entry.Tween=tween
 entry.Connection=tween.Completed:Connect(function(state)
  if state~=Enum.PlaybackState.Completed then
   if self:_partCurrent(record,part,entry) then entry.State="Cancelled";release(entry) end
   return
  end
  if not self:_partCurrent(record,part,entry) or entry.State~="Fading" then return end
  part.Transparency=1 -- Collision is removed ONLY after completed, never on Cancel.
  part.CanCollide=false
  entry.State="Disappeared"
  release(entry)
 end)
 tween:Play()
end
function Controller:_trigger(record,part)
 local entry=record.Parts[part]
 if not entry or entry.State~="Idle" or not part.CanCollide or part.Transparency>=1
  or not self:_partCurrent(record,part,entry) then return false end
 entry.State="Triggered" -- reserve synchronously: two players cannot create two tweens.
 if self.Config.FadeDelay>0 then
  entry.Timer=task.delay(self.Config.FadeDelay,function()
   entry.Timer=nil
   self:_fade(record,part,entry)
  end)
 else self:_fade(record,part,entry) end
 return true
end
function Controller:_detect(record,player)
 if typeof(player)~="Instance" or not player:IsA("Player") or player.Parent~=self.Deps.Players
  or player:GetAttribute("MatchId")~=record.Id or self.Deps.GetPlayerSession(player)~=record.Session
  or not self.Deps.GetParticipant(record.Id,player) then return end
 local character=player.Character
 if not character or not character:IsDescendantOf(self.Deps.World) then return end
 local humanoid=character:FindFirstChildOfClass("Humanoid")
 local root=character:FindFirstChild("HumanoidRootPart")
 if not humanoid or not root or not root:IsA("BasePart") or not Policy.CanStand(character,humanoid,root,self.Config) then return end
 local height=Policy.ExpectedHeight(character,humanoid,root)
 if not height then return end
 local params=RaycastParams.new()
 params.FilterType=Enum.RaycastFilterType.Exclude
 params.FilterDescendantsInstances={character}
 params.RespectCanCollide=true
 -- Use a body's collision group, not the noncolliding arena root group.
 local foot=character:FindFirstChild(if humanoid.RigType==Enum.HumanoidRigType.R6 then "Left Leg" else "LeftFoot")
 if foot and foot:IsA("BasePart") then params.CollisionGroup=foot.CollisionGroup end
 local hit=self.Deps.World:Raycast(root.Position,Vector3.new(0,-(height+self.Config.SupportTolerance),0),params)
 if not hit then return end
 local entry=record.Parts[hit.Instance]
 if entry and Policy.IsTopSupport(hit.Instance,root,hit,height,self.Config) then self:_trigger(record,hit.Instance) end
end
function Controller:Step(dt)
 self.Elapsed+=dt
 if self.Elapsed<self.Config.DetectionInterval then return end
 self.Elapsed%=self.Config.DetectionInterval -- no burst of catch-up queries after a stalled frame.
 for id,record in pairs(self.Maps) do
  if not self:_current(record) then self:UnbindMap(id,record.Info)
  else
   local session=record.Session
   if session.State=="Playing" and not session.GameplayFrozen and not session.PointInProgress
    and session.GameplayRound and not session.GameplayRound.Resolved then
    for _,participant in ipairs(session.Participants or {}) do
     if participant.State~="Left" and participant.State~="Released" then self:_detect(record,participant.Player) end
    end
   end
  end
 end
end
function Controller:Destroy()
 while next(self.Maps) do
  local id=next(self.Maps)
  self:UnbindMap(id)
 end
end
local Service={Name="DisappearingPlatformsService",new=Controller.new}
function Service:Init(context)
 self._context=context
 if self._controller then self._controller:Destroy() end
 local rounds=context:GetService("RoundService")
 local instances=context:GetService("MatchInstanceService")
 local ok,result=pcall(Controller.new,Config,{
  World=game:GetService("Workspace"),Templates=game:GetService("ServerStorage"),Players=game:GetService("Players"),
  TweenService=game:GetService("TweenService"),Heartbeat=game:GetService("RunService").Heartbeat,
  GetSession=function(id)return rounds:GetSessionById(id)end,
  GetInstance=function(id)return instances:GetInstance(id)end,
  GetPlayerSession=function(player)return rounds:GetSessionForPlayer(player)end,
  GetParticipant=function(id,player)return rounds:GetSessionParticipant(id,player)end,
 })
 if ok then self._controller=result
 else self._controller=nil;warn("[DisappearingPlatforms] Disabled: "..tostring(result)) end
end
function Service:Start(_context) end -- detection starts only when an authorized map is bound.
function Service:BindMap(session,info)
 if not self._controller then return true end -- invalid configuration disables this feature, not the match.
 return self._controller:BindMap(session,info)
end
function Service:UnbindMap(id,info)
 if self._controller then self._controller:UnbindMap(id,info) end
end
return Service
