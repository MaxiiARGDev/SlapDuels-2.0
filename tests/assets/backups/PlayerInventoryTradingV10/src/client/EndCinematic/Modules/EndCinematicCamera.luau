--!nonstrict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Config = require(game.ReplicatedStorage.Shared.EndCinematicConfig)
local Module = {}

function Module.ComputeFloatingFrame(anchor, baseFocus, focus, elapsed, dt, state, config)
 local ramp=math.clamp(elapsed/math.max(config.FadeInDuration,.001),0,1)
 ramp=ramp*ramp*(3-2*ramp)
 local offset=Vector3.new(math.sin(elapsed*config.LateralFrequency)*config.LateralAmplitude,
  math.sin(elapsed*config.VerticalFrequency)*config.VerticalAmplitude,0)*ramp
 if config.PreserveBaseDistance and offset.Magnitude>config.DistanceTolerance then
  offset=offset.Unit*math.max(0,config.DistanceTolerance)
 end
 local yaw,pitch=0,0
 if config.FollowEnabled then
  local a,b=anchor:PointToObjectSpace(baseFocus),anchor:PointToObjectSpace(focus)
  local function angles(v) return math.atan2(-v.X,-v.Z),math.atan2(v.Y,Vector2.new(v.X,v.Z).Magnitude) end
  local ya,pa=angles(a); local yb,pb=angles(b)
  yaw=math.atan2(math.sin(yb-ya),math.cos(yb-ya))
  pitch=pb-pa
 end
 local maxYaw,maxPitch=math.rad(config.MaxYawDegrees),math.rad(config.MaxPitchDegrees)
 yaw=math.clamp(yaw+math.rad(.15)*math.sin(elapsed*.32),-maxYaw,maxYaw)*ramp
 pitch=math.clamp(pitch+math.rad(.1)*math.sin(elapsed*.41),-maxPitch,maxPitch)*ramp
 local alpha=1-math.exp(-math.max(0,config.FollowResponsiveness)*math.max(0,dt))
 state.Yaw=(state.Yaw or 0)+(yaw-(state.Yaw or 0))*alpha
 state.Pitch=(state.Pitch or 0)+(pitch-(state.Pitch or 0))*alpha
 return anchor*CFrame.new(offset)*CFrame.Angles(state.Pitch,state.Yaw,0)
end

local function focusOf(run)
 local sum,count=Vector3.zero,0
 for _,entry in ipairs(run.Rigs) do
  if entry.Model.Parent then
   local position=entry.Model:GetPivot().Position
   -- Ignore teleports unrelated to the authored entrance animation.
   if (position-entry.Finish.Position).Magnitude<=Config.FloatingFollow.MaxTargetStep then
    sum+=position+Vector3.new(0,Config.FloatingFollow.FocusHeight,0); count+=1
   end
  end
 end
 return count>0 and sum/count or nil
end

function Module.StartFloating(run, anchor)
 if not Config.FloatingFollow.Enabled or run.FloatingEnabled==false or run.FloatingConnection then return end
 local baseFocus=focusOf(run) or (anchor.Position+anchor.LookVector*10)
 local focus=baseFocus
 local elapsed,state=0,{}
 run.FloatingAnchor=anchor
 run.FloatingConnection=RunService.RenderStepped:Connect(function(dt)
  if not run:IsAlive() or workspace.CurrentCamera~=run.Camera then return end
  elapsed+=dt
  local target=focusOf(run)
  if target and (target-focus).Magnitude<=Config.FloatingFollow.MaxTargetStep then focus=target end
  run.Camera.CFrame=Module.ComputeFloatingFrame(anchor,baseFocus,focus,elapsed,dt,state,Config.FloatingFollow)
  if Config.FloatingFollow.FieldOfViewLocked then run.Camera.FieldOfView=run.FieldOfView end
 end)
 table.insert(run.Connections,run.FloatingConnection)
end

function Module.StopFloating(run)
 local connection=run.FloatingConnection
 if connection then
  connection:Disconnect()
  local index=table.find(run.Connections,connection)
  if index then table.remove(run.Connections,index) end
  run.FloatingConnection=nil
 end
 if run.Camera and run.CameraDone then run.Camera.CFrame=run.Destination end
end
local function make(class, properties, parent)
 local object = Instance.new(class)
 for key, value in pairs(properties) do object[key] = value end
 object.Parent = parent
 return object
end
function Module.Play(run, from, target)
	local alpha = make("NumberValue", { Value = 0 }, run.Container)
	local bounce = false
		local travelConnection = alpha.Changed:Connect(function(value)
		if not run:IsAlive() then return end
		local frame
		if bounce then
			frame = target * CFrame.new(0, 0, -math.sin(value * math.pi) * Config.Camera.ArrivalBounceStrength)
		else
			frame = from:Lerp(target, value)
			if Config.Camera.HorizontalRotationEnabled then frame *= CFrame.Angles(0, math.rad(Config.Camera.HorizontalRotationDegrees) * math.sin(value * math.pi), 0) end
		end
		run.Camera.CFrame = frame
		end)
		table.insert(run.Connections,travelConnection)
	if not run:Tween(alpha, Config.Camera.TravelDuration, { Value = 1 }) then return end
	if Config.Camera.ArrivalBounceEnabled then
		bounce = true; alpha.Value = 0
		if not run:Tween(alpha, Config.Camera.ArrivalBounceDuration, { Value = 1 }) then return end
	end
	run.Camera.CFrame = target
		travelConnection:Disconnect()
	run.CameraDone = true
		Module.StartFloating(run,target)

end


function Module.Resolve(stage, mode)
 local folder = stage:FindFirstChild("TransCamera")
 local startName = Config.Camera.StartPart
 local endName = Config.Camera.Destinations[mode] or Config.Camera.Destinations.Default
 local from = folder and folder:FindFirstChild(startName)
 local target = folder and folder:FindFirstChild(endName)
 if not from or not from:IsA("BasePart") then return nil, nil, "CameraStartMissing:" .. startName end
 if not target or not target:IsA("BasePart") then return nil, nil, "CameraDestinationMissing:" .. endName end
 return from.CFrame, target.CFrame
end

function Module.Prepare(run, from)
 local camera = workspace.CurrentCamera
 assert(camera, "CameraMissing")
 run.Camera = camera
 run.CameraType = camera.CameraType
 run.CameraSubject = camera.CameraSubject
 run.CameraCFrame = camera.CFrame
 run.FieldOfView = camera.FieldOfView
 camera.CameraType = Enum.CameraType.Scriptable
 camera.CFrame = from
end

function Module.Cleanup(run)
 Module.StopFloating(run)
 if not run.Camera then return end
 pcall(function()
  run.Camera.CameraType = run.CameraType
  local subject = run.CameraSubject
  if not subject or not subject.Parent then
   local char = Players.LocalPlayer.Character
   subject = char and char:FindFirstChildOfClass("Humanoid")
  end
  run.Camera.CameraSubject = subject
  run.Camera.CFrame = run.CameraCFrame
  run.Camera.FieldOfView = run.FieldOfView
 end)
end

return Module
