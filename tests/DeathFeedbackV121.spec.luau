--!nonstrict
-- PREPARED, NOT RUN by the agent. Isolated developer harness only, never live servers.
-- Creates a temporary R6 fixture, calls a separate service instance, always destroys it.
return function()
 assert(game:GetService("RunService"):IsStudio(), "Studio harness only")
 local Service=require(game.ServerScriptService.Services.RagdollService)
 local Config=require(game.ReplicatedStorage.Shared.Config)
 local service=setmetatable({
  _activeTimers={},_r6Instances={},_rootCollisions={},
  _getStateEvent=function()return nil end,
 },{__index=Service})
 local rig=Instance.new("Model")
 rig.Name="DeathFeedbackV121_IsolatedFixture"
 local assertions=0
 local function expect(value,message)assertions+=1;assert(value,message)end
 local function part(name,position)
  local p=Instance.new("Part");p.Name=name;p.Size=Vector3.new(2,2,1)
  p.CFrame=CFrame.new(position);p.Parent=rig;return p
 end
 local root=part("HumanoidRootPart",Vector3.new(0,50000,0))
 root.Anchored=true;root.CanCollide=false
 local torso=part("Torso",root.Position)
 local arm=part("Right Arm",root.Position+Vector3.new(2,0,0))
 local hum=Instance.new("Humanoid");hum.Parent=rig
 local function motor(name,a,b,c0)
  local m=Instance.new("Motor6D");m.Name=name;m.Part0=a;m.Part1=b
  m.C0=c0;m.Parent=a;return m
 end
 motor("RootJoint",root,torso,CFrame.identity)
 local shoulder=motor("Right Shoulder",torso,arm,CFrame.new(2,0,0))
 rig:SetAttribute("ArenaPhysicsGeneration",10)
 rig.Parent=workspace
 local ok,failure=xpcall(function()
  expect(Config.Respawn.KillPartDelayMs==500,"500ms unchanged")
  expect(Config.Respawn.Debug==false,"Diagnostics off by default")
  expect(service:ApplyRagdoll(rig,20,Vector3.new(30,40,0)),"First hit")
  local tracked=service._r6Instances[rig]
  local descendantCount=#rig:GetDescendants()
  expect(service:ApplyRagdoll(rig,20,Vector3.new(60,40,0)),"Second valid hit")
  expect(service._r6Instances[rig]==tracked,"Same cleanup list retained")
  expect(#rig:GetDescendants()==descendantCount,"No duplicate constraints/colliders")
  -- Same lifecycle token as production; no second generation system.
  rig:SetAttribute("ArenaPhysicsGeneration",11)
  rig:SetAttribute("ArenaRespawnPending",true)
  arm.CFrame=CFrame.new(root.Position+Vector3.new(0,-5,3))
  expect(service:ResetRagdollImmediate(rig,true),"Quiet retirement")
  expect(service._activeTimers[rig]==nil,"Old recovery cancelled")
  expect(service._r6Instances[rig]==nil,"Tracked rig cleared")
  expect(shoulder.Enabled,"Motor restored")
  local expected=torso.CFrame*shoulder.C0*shoulder.C1:Inverse()
  expect((arm.Position-expected.Position).Magnitude<0.001,"Limb reassembled before physics")
  expect(not root.CanCollide,"Original root collision retained")
  for _,object in ipairs(rig:GetDescendants()) do
   expect(object.Name~="Collider" and object.Name~="RagdollConstraint" and object.Name~="TorsoWeld","Owned ragdoll resources removed")
   if object:IsA("BasePart") then
    expect(object.AssemblyLinearVelocity.Magnitude<0.001,"Linear velocity cleared")
    expect(object.AssemblyAngularVelocity.Magnitude<0.001,"Angular velocity cleared")
   end
  end
  expect(not hum.Jump,"No automatic Jump")
 end,debug.traceback)
 for _,thread in pairs(service._activeTimers) do pcall(task.cancel,thread) end
 rig:Destroy()
 assert(ok,failure)
 return assertions
end
