assert(not game:GetService('RunService'):IsRunning(),'Edit required')
local root=game.ServerStorage.PointEffects
local function part(parent,name)
 local p=Instance.new('Part');p.Name=name;p.Size=Vector3.new(.2,.2,.2);p.Anchored=true;p.Transparency=1;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Parent=parent;return p
end
local function emitter(parent,name,tint,count,delay,speed,size,life,texture)
 local e=Instance.new('ParticleEmitter');e.Name=name;e.Enabled=false;e.Rate=0;e.Texture=texture or 'rbxasset://textures/particles/sparkles_main.dds';e.Color=ColorSequence.new(tint,Color3.new(1,1,1));e.LightEmission=.75;e.Lifetime=NumberRange.new(life*.65,life);e.Speed=NumberRange.new(speed*.5,speed);e.SpreadAngle=Vector2.new(170,170);e.Drag=3;e.Rotation=NumberRange.new(0,360);e.RotSpeed=NumberRange.new(-50,50);e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,size),NumberSequenceKeypoint.new(.35,size*.65),NumberSequenceKeypoint.new(1,0)});e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.1),NumberSequenceKeypoint.new(.65,.35),NumberSequenceKeypoint.new(1,1)});e:SetAttribute('EmitCount',count);e:SetAttribute('EmitDelay',delay);e.Parent=parent;return e
end
local created={}
for _,id in ipairs({'Frost','Void'})do
 assert(not root:FindFirstChild(id),'Existing effect must be preserved: '..id)
 local model=Instance.new('Model');model.Name=id;model:SetAttribute('Duration',3.5);model:SetAttribute('FinalMultiplier',1.4);model:SetAttribute('EffectId',id)
 local origin=part(model,'Origin');model.PrimaryPart=origin
 local vfx=Instance.new('Folder');vfx.Name='VFX';vfx.Parent=model
 local flash=part(vfx,'Flash');local burst=part(vfx,'Burst');local wave=part(vfx,'Shockwave')
 local tint=id=='Frost'and Color3.fromRGB(125,225,255)or Color3.fromRGB(138,70,225)
 emitter(flash,'Glints',tint,24,0,8,.35,1.1)
 emitter(flash,'Halo',tint,2,0,.5,5,.8,'rbxasset://textures/particles/smoke_main.dds')
 local main=emitter(burst,id=='Frost'and 'IceShards'or 'Starfield',tint,42,.08,12,.22,1.5)
 main.Acceleration=id=='Frost'and Vector3.new(0,-12,0)or Vector3.new(0,3,0)
 emitter(wave,id=='Frost'and 'ColdMist'or 'VoidMist',tint,18,.18,6,1.3,1.6,'rbxasset://textures/particles/smoke_main.dds')
 emitter(wave,'SecondWave',tint,16,.55,10,.18,1)
 local light=Instance.new('PointLight');light.Name='FlashLight';light.Color=tint;light.Range=15;light.Brightness=0;light:SetAttribute('LightPeak',2);light:SetAttribute('LightIn',.06);light:SetAttribute('LightFade',.6);light.Parent=flash
 local pillar=part(vfx,'Pillar');local low=Instance.new('Attachment');low.Name='Base';low.Parent=pillar;local high=Instance.new('Attachment');high.Name='Top';high.Position=Vector3.new(0,7,0);high.Parent=pillar
 local beam=Instance.new('Beam');beam.Name='Pulse';beam.Attachment0=low;beam.Attachment1=high;beam.Color=ColorSequence.new(tint);beam.FaceCamera=true;beam.Width0=0;beam.Width1=0;beam.LightEmission=1;beam.Transparency=NumberSequence.new(.25);beam:SetAttribute('PulsePeak',id=='Frost'and 2.8 or 3.4);beam:SetAttribute('PulseTopRatio',.2);beam:SetAttribute('PulseIn',.1);beam:SetAttribute('PulseOut',.8);beam.Parent=pillar
 local sfx=Instance.new('Folder');sfx.Name='SFX';sfx.Parent=model;local impact=part(sfx,'PointImpact')
 local existing=root.Inferno.SFX.PointImpact:FindFirstChild(id=='Frost'and 'Ping'or 'Glint')
 if existing and existing:IsA('Sound')then local sound=existing:Clone();sound.Name=id..'Impact';sound.Volume=math.min(sound.Volume,.45);sound.PlaybackSpeed=id=='Frost'and 1.2 or .75;sound.Looped=false;sound:SetAttribute('PlayDelay',.08);sound.Parent=impact end
 model.Parent=root;table.insert(created,model:GetFullName())
end
return created
