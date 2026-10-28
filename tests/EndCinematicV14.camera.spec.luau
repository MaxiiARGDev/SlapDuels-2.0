-- Mathematical camera tests; these do not claim human visual approval at each FPS.
return function(Camera,config)
 local anchor=CFrame.new(5,4,8)*CFrame.Angles(0,.4,0)
 local focus=anchor.Position+anchor.LookVector*10
 local passed={}
 local function check(n,v) assert(v,n);table.insert(passed,n) end
 check("floating starts exactly at anchor",Camera.ComputeFloatingFrame(anchor,focus,focus,0,1/60,{},config)==anchor)
 local frames,maxOffset,maxRadius,maxDepth={},0,0,0
 for _,fps in ipairs({30,60,144}) do
  local state={}
  for i=1,fps*20 do
   local frame=Camera.ComputeFloatingFrame(anchor,focus,focus,i/fps,1/fps,state,config)
   maxOffset=math.max(maxOffset,(frame.Position-anchor.Position).Magnitude)
   maxRadius=math.max(maxRadius,math.abs((frame.Position-focus).Magnitude-(anchor.Position-focus).Magnitude))
   maxDepth=math.max(maxDepth,math.abs(anchor:PointToObjectSpace(frame.Position).Z))
   assert(math.abs(state.Yaw)<=math.rad(config.MaxYawDegrees)+1e-6)
   assert(math.abs(state.Pitch)<=math.rad(config.MaxPitchDegrees)+1e-6)
   frames[fps]=frame
  end
 end
 check("bounded offset",maxOffset<=config.DistanceTolerance+1e-4)
 check("bounded radial distance",maxRadius<=config.DistanceTolerance+1e-4)
 check("no depth component",maxDepth<1e-5)
 check("frame-rate independent position",(frames[30].Position-frames[144].Position).Magnitude<1e-5)
 local late=Camera.ComputeFloatingFrame(anchor,focus,focus,100000,1/60,{},config)
 check("no accumulated drift",(late.Position-anchor.Position).Magnitude<=config.DistanceTolerance+1e-4)
 local state={}
 for i=1,100 do Camera.ComputeFloatingFrame(anchor,focus,focus+Vector3.new(100,100,100),i/60,1/60,state,config) end
 check("orientation correction clamped",math.abs(state.Yaw)<=math.rad(config.MaxYawDegrees)+1e-6 and math.abs(state.Pitch)<=math.rad(config.MaxPitchDegrees)+1e-6)
 -- Exercise arrival ownership/cleanup without touching the actual workspace camera.
 local folder=Instance.new("Folder")
 local fakeCamera={CFrame=anchor}
 local calls=0
 local run={Container=folder,Camera=fakeCamera,Destination=anchor,Rigs={},Connections={},FloatingEnabled=true,
  IsAlive=function() return true end,Tween=function(self,object,_,properties)
   assert(self.FloatingConnection==nil,"Floating began before travel/bounce ended")
   calls+=1;object.Value=properties.Value;return true
  end}
 Camera.Play(run,anchor*CFrame.new(0,0,4),anchor)
 local connection=run.FloatingConnection
 check("floating starts after both travel and bounce",calls==2 and run.CameraDone and connection and connection.Connected)
 check("arrival anchor preserved",fakeCamera.CFrame==anchor)
 Camera.Cleanup(run)
 check("cleanup disconnects floating render",not connection.Connected and run.FloatingConnection==nil)
 folder:Destroy()
 return {Passed=#passed,Assertions=passed,MaxOffset=maxOffset,MaxRadialChange=maxRadius,MaxLocalDepth=maxDepth}
end
