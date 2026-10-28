assert(game:GetService('RunService'):IsStudio() and not game:GetService('RunService'):IsRunning(),'Edit required')
assert(not workspace:FindFirstChild('TrainingZone'),'TrainingZone exists; preserve it')
local origin=Vector3.new(-55.22151184082031,16.579307556152344,237.5)
local zone=Instance.new('Model');zone.Name='TrainingZone';zone:SetAttribute('AuthoredVersion','AdminTrainingV1')
local function part(parent,name,size,offset,color,collide)
 local p=Instance.new('Part');p.Name=name;p.Size=size;p.CFrame=CFrame.new(origin+offset);p.Color=Color3.fromRGB(unpack(color));p.Anchored=true;p.CanCollide=collide~=false;p.CanTouch=false;p.TopSurface=Enum.SurfaceType.Smooth;p.BottomSurface=Enum.SurfaceType.Smooth;p.Material=Enum.Material.SmoothPlastic;p.Parent=parent;return p
end
local floor=part(zone,'Floor',Vector3.new(56,1,56),Vector3.zero,{25,35,51});zone.PrimaryPart=floor
part(zone,'LobbyBridge',Vector3.new(10,1,30),Vector3.new(0,0,-31),{32,48,65})
for _,x in ipairs({-27.5,27.5})do
 part(zone,'SideRail'..tostring(x),Vector3.new(1,5,56),Vector3.new(x,3,0),{37,77,103})
 local light=part(zone,'RailLight'..tostring(x),Vector3.new(.2,.2,55),Vector3.new(x,5.6,0),{80,206,255},false);light.Material=Enum.Material.Neon
end
part(zone,'BackRail',Vector3.new(56,5,1),Vector3.new(0,3,27.5),{37,77,103})
for _,x in ipairs({-17,17})do part(zone,'FrontRail'..x,Vector3.new(21,3,1),Vector3.new(x,2,-27.5),{37,77,103})end
local bounds=part(zone,'Bounds',Vector3.new(55,25,55),Vector3.new(0,13,0),{0,0,0},false);bounds.Transparency=1;bounds.CanQuery=false
local home=part(zone,'DummyHome',Vector3.new(2,.2,2),Vector3.new(0,3.5,3),{255,255,255},false);home.Transparency=1;home.CanQuery=false
local marker=part(zone,'PracticeCircle',Vector3.new(.12,12,12),Vector3.new(0,.59,3),{48,173,222},false);marker.Shape=Enum.PartType.Cylinder;marker.CFrame=CFrame.new(origin+Vector3.new(0,.59,3))*CFrame.Angles(0,0,math.pi/2);marker.Material=Enum.Material.Neon;marker.Transparency=.55
local entry=part(zone,'EntryPad',Vector3.new(8,.2,6),Vector3.new(0,.62,-20),{48,173,222},false);entry.Material=Enum.Material.Neon
local prompt=Instance.new('ProximityPrompt');prompt.Name='TrainPrompt';prompt.ActionText='Entrenar / salir';prompt.ObjectText='Maniquí de práctica';prompt.HoldDuration=.2;prompt.MaxActivationDistance=10;prompt.RequiresLineOfSight=false;prompt.Parent=entry
local board=part(zone,'InstructionBoard',Vector3.new(24,6,.5),Vector3.new(0,8,-23),{14,23,36},false)
for _,x in ipairs({-10,10})do part(zone,'SignSupport'..x,Vector3.new(.4,8,.4),Vector3.new(x,4,-23),{53,88,110},false)end
local gui=Instance.new('SurfaceGui');gui.Name='Instructions';gui.Face=Enum.NormalId.Front;gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud;gui.PixelsPerStud=32;gui.Parent=board
local label=Instance.new('TextLabel');label.Name='Label';label.Size=UDim2.fromScale(1,1);label.BackgroundTransparency=1;label.Text='PRÁCTICA DE SLAPS\nUsá el pad para tomar tu Slap y golpeá al maniquí.\nRagdoll de 3 s · Vuelve a su base · Sin Kills ni Coins';label.TextColor3=Color3.fromRGB(218,242,255);label.TextScaled=true;label.Font=Enum.Font.GothamBold;label.Parent=gui
local dummy=Instance.new('Model');dummy.Name='TrainingDummy';dummy:SetAttribute('TrainingDummy',true)
local root=part(dummy,'HumanoidRootPart',Vector3.new(2,2,1),Vector3.new(0,3.5,3),{0,0,0},false);root.Transparency=1;root.CanQuery=false
local torso=part(dummy,'Torso',Vector3.new(2,2,1),Vector3.new(0,3.5,3),{30,133,176})
local head=part(dummy,'Head',Vector3.new(2,1,1),Vector3.new(0,5,3),{218,180,115})
local mesh=Instance.new('SpecialMesh');mesh.MeshType=Enum.MeshType.Head;mesh.Scale=Vector3.new(1.2,1.2,1.2);mesh.Parent=head
local face=Instance.new('Decal');face.Name='Face';face.Texture='rbxasset://textures/face.png';face.Face=Enum.NormalId.Front;face.Parent=head
local leftArm=part(dummy,'Left Arm',Vector3.new(1,2,1),Vector3.new(-1.5,3.5,3),{218,180,115})
local rightArm=part(dummy,'Right Arm',Vector3.new(1,2,1),Vector3.new(1.5,3.5,3),{218,180,115})
local leftLeg=part(dummy,'Left Leg',Vector3.new(1,2,1),Vector3.new(-.5,1.5,3),{36,47,64})
local rightLeg=part(dummy,'Right Leg',Vector3.new(1,2,1),Vector3.new(.5,1.5,3),{36,47,64})
for _,p in ipairs({torso,head,leftArm,rightArm,leftLeg,rightLeg})do p.Anchored=false end
local function motor(parent,name,a,b,c0,c1)local j=Instance.new('Motor6D');j.Name=name;j.Part0=a;j.Part1=b;j.C0=c0;j.C1=c1;j.Parent=parent end
motor(root,'RootJoint',root,torso,CFrame.identity,CFrame.identity)
motor(torso,'Neck',torso,head,CFrame.new(0,1,0),CFrame.new(0,-.5,0))
motor(torso,'Left Shoulder',torso,leftArm,CFrame.new(-1,.5,0),CFrame.new(.5,.5,0))
motor(torso,'Right Shoulder',torso,rightArm,CFrame.new(1,.5,0),CFrame.new(-.5,.5,0))
motor(torso,'Left Hip',torso,leftLeg,CFrame.new(-.5,-1,0),CFrame.new(0,1,0))
motor(torso,'Right Hip',torso,rightLeg,CFrame.new(.5,-1,0),CFrame.new(0,1,0))
local humanoid=Instance.new('Humanoid');humanoid.Name='Humanoid';humanoid.RequiresNeck=false;humanoid.BreakJointsOnDeath=false;humanoid.WalkSpeed=0;humanoid.JumpPower=0;humanoid.MaxHealth=1000;humanoid.Health=1000;humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None;humanoid.Parent=dummy
dummy.PrimaryPart=root;dummy.Parent=zone;dummy:PivotTo(home.CFrame)
local tag=Instance.new('BillboardGui');tag.Name='DummyLabel';tag.Size=UDim2.fromOffset(240,60);tag.StudsOffsetWorldSpace=Vector3.new(0,2,0);tag.AlwaysOnTop=true;tag.MaxDistance=65;tag.Parent=head
local title=Instance.new('TextLabel');title.Name='Label';title.Size=UDim2.fromScale(1,1);title.BackgroundTransparency=1;title.Text='MANIQUÍ DE PRÁCTICA\nProtegido durante el ragdoll';title.TextColor3=Color3.fromRGB(127,226,255);title.TextStrokeTransparency=.4;title.TextScaled=true;title.Font=Enum.Font.GothamBold;title.Parent=tag
zone.Parent=workspace
return game.HttpService:JSONEncode({Path=zone:GetFullName(),Position=tostring(floor.Position),Parts=#zone:GetDescendants(),DummyRootAnchored=root.Anchored,Motors=6,RequiresNeck=humanoid.RequiresNeck})
