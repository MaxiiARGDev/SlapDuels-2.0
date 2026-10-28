-- Shop Integration V2 authoring only; execute in Edit, never during Play.
assert(game:GetService("RunService"):IsStudio() and not game:GetService("RunService"):IsRunning(),"Edit only")
local folder=game.ServerStorage:WaitForChild("DeathEffects")
assert(not folder:FindFirstChild("Frost") and not folder:FindFirstChild("Void"),"Preserve existing models; inspect before replacing")
local function part(name,parent,position)
 local p=Instance.new("Part");p.Name=name;p.Size=Vector3.new(1,1,1);p.CFrame=CFrame.new(position or Vector3.zero)
 p.Anchored=true;p.Transparency=1;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Parent=parent;return p
end
local function emitter(parent,name,color,count,delay,life,speed,size,texture)
 local e=Instance.new("ParticleEmitter");e.Name=name;e.Texture=texture or "rbxasset://textures/particles/sparkles_main.dds"
 e.Color=ColorSequence.new(color);e.Rate=0;e.Enabled=false;e.Lifetime=NumberRange.new(life*.8,life);e.Speed=NumberRange.new(speed*.7,speed)
 e.EmissionDirection=Enum.NormalId.Top;e.SpreadAngle=Vector2.new(15,15)
 e.LightEmission=.85;e.LightInfluence=0;e.Drag=2
 e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,size*.35),NumberSequenceKeypoint.new(.18,size),NumberSequenceKeypoint.new(1,0)})
 e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.12),NumberSequenceKeypoint.new(.6,.5),NumberSequenceKeypoint.new(1,1)})
 e.Rotation=NumberRange.new(-180,180);e.RotSpeed=NumberRange.new(-80,80)
 e:SetAttribute("EmitCount",count);e:SetAttribute("EmitDelay",delay);e.Parent=parent;return e
end
local function create(id,duration,cold)
 local m=Instance.new("Model");m.Name=id;m:SetAttribute("Duration",duration);m:SetAttribute("AudioStatus","PendingAuthorizedAsset")
 local origin=part("Origin",m);m.PrimaryPart=origin
 local vfx=Instance.new("Folder");vfx.Name="VFX";vfx.Parent=m
 local sfx=Instance.new("Folder");sfx.Name="SFX";sfx.Parent=m
 local impact=part("Impact",sfx)
 local sound=Instance.new("Sound");sound.Name=id.."Impact";sound.SoundId="";sound.Volume=.65
 sound.RollOffMode=Enum.RollOffMode.InverseTapered;sound.RollOffMinDistance=12;sound.RollOffMaxDistance=110
 sound.Looped=false;sound.PlayOnRemove=false;sound:SetAttribute("PlayDelay",0);sound:SetAttribute("MissingAsset","Authorized "..id.." impact SFX required");sound.Parent=impact
 local primary=if cold then Color3.fromRGB(92,210,255) else Color3.fromRGB(150,50,255)
 local secondary=if cold then Color3.fromRGB(235,253,255) else Color3.fromRGB(42,8,65)
 local flash=part("Flash",vfx)
 local f=emitter(flash,"FlashBurst",primary,2,0,.22,0,9);f.LightEmission=1
 local l=Instance.new("PointLight");l.Name="ImpactLight";l.Color=primary;l.Range=24;l.Brightness=0;l:SetAttribute("LightPeak",4);l.Parent=flash
 local jet=part(if cold then "VerticalJet" else "VioletJet",vfx)
 jet.Size=Vector3.new(5,1,5)
 local e=emitter(jet,"UpwardColumn",primary,34,.025,1.2,27,2.8)
 e.SpreadAngle=Vector2.new(9,9);e.Acceleration=Vector3.new(0,5,0);e.VelocityInheritance=0
 local shards=part(if cold then "IceShards" else "VoidParticles",vfx)
 local q=emitter(shards,if cold then "Crystals" else "DarkFragments",secondary,28,.07,1.65,22,1)
 q.SpreadAngle=Vector2.new(85,85);q.Acceleration=Vector3.new(0,-22,0)
 q.Squash=NumberSequence.new(if cold then -1.3 else .4)
 local mist=part(if cold then "FrostMist" else "DarkCore",vfx)
 mist.Size=Vector3.new(5,1,5)
 local haze=emitter(mist,"Dispersal",if cold then primary else Color3.fromRGB(16,6,25),10,.1,1.7,4,7,"rbxasset://textures/particles/smoke_main.dds")
 haze.LightEmission=if cold then .25 else 0
 haze.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.6),NumberSequenceKeypoint.new(.45,.78),NumberSequenceKeypoint.new(1,1)})
 local rain=part(if cold then "FallingParticles" else "RisingEnergy",vfx,Vector3.new(0,if cold then 8 else 1,0))
 rain.Size=Vector3.new(9,1,9)
 local r=emitter(rain,"SecondaryParticles",primary,22,.35,2,if cold then 2 else 7,.45)
 r.EmissionDirection=if cold then Enum.NormalId.Bottom else Enum.NormalId.Top;r.Acceleration=Vector3.new(0,if cold then -9 else 4,0)
 local rings=part(if cold then "Shockwave" else "EnergyRings",vfx,Vector3.new(0,.25,0))
 -- Precisely oriented emitters form actual expanding circular particle waves.
 for wave=1,(if cold then 1 else 2) do
  for i=1,20 do
   local angle=2*math.pi*i/20;local radial=Vector3.new(math.cos(angle),0,math.sin(angle))
   local a=Instance.new("Attachment");a.Name="Wave"..wave.."_"..i;a.CFrame=CFrame.lookAt(radial*1.2,radial*2.2);a.Parent=rings
   local ring=emitter(a,"RingParticle",primary,1,.04+(wave-1)*.18,.8,16-(wave-1)*3,1.5)
   ring.EmissionDirection=Enum.NormalId.Front;ring.SpreadAngle=Vector2.zero;ring.Rotation=NumberRange.new(0);ring.RotSpeed=NumberRange.new(0)
  end
 end
 m.Parent=folder
 return {Path=m:GetFullName(),Descendants=#m:GetDescendants(),Duration=duration}
end
local results={create("Frost",3.2,true),create("Void",3.6,false)}
return game:GetService("HttpService"):JSONEncode(results)
