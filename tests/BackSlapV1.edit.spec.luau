assert(not game:GetService('RunService'):IsRunning(),'Edit only')
local temp=game.ServerScriptService.Services.BackSlapService:Clone();temp.Name='__BackSlapAudit';temp.Parent=game.ServerScriptService
local rig=Instance.new('Model');local torso=Instance.new('Part');torso.Name='Torso';torso.CFrame=CFrame.new(10,4,8);torso.Parent=rig
local hum=Instance.new('Humanoid');hum.Parent=rig
local anchor=Instance.new('Attachment');anchor.Name='slap_here';anchor.CFrame=CFrame.new(0,0,.75)*CFrame.Angles(0,.2,-.4);anchor.Parent=torso
local assertions=0
local function check(v,message)assert(v,message);assertions+=1 end
local function count(root,class)local n=0;for _,o in ipairs(root:GetDescendants())do if o:IsA(class)then n+=1 end end;return n end
local ok,result=xpcall(function()
 local service=require(temp)
 local tested=0
 for _,folder in ipairs(game.ServerStorage.SlapVariations:GetChildren())do
  for _,template in ipairs(folder:GetChildren())do if template:IsA('Tool')then
   local hand=template:FindFirstChild('Hand');local originalCF=hand.CFrame;local originalColor=hand.Color
   local reward={RewardId=folder.Name..':'..template.Name,SlapId=folder.Name,VariationId=template.Name}
   local model=service.Build(template,anchor,reward)
   check(model~=nil,'Clone missing')
   check(count(model,'BasePart')==count(template,'BasePart'),'Full geometry must survive')
   check(count(model,'ParticleEmitter')==count(template,'ParticleEmitter'),'Particles preserved')
   check(count(model,'Sound')==count(template,'Sound'),'Sounds preserved')
   check(count(model,'Highlight')==count(template,'Highlight'),'Highlights preserved')
   check(count(model,'LuaSourceContainer')==0 and count(model,'Tool')==0,'No executable weapon')
   check((model.PrimaryPart.Position-anchor.WorldPosition).Magnitude<.001,'Anchor alignment')
   local mount=model.PrimaryPart:FindFirstChild('BackSlapMount')
   check(mount.Part0==torso and mount.Part1==model.PrimaryPart,'Torso welded')
   for _,part in ipairs(model:GetDescendants())do if part:IsA('BasePart')then check(not part.Anchored and part.Massless and not part.CanCollide and not part.CanTouch and not part.CanQuery,'Cosmetic physics')end end
   check(hand.CFrame==originalCF and hand.Color==originalColor,'Template untouched')
   model:Destroy();tested+=1
  end end
 end
 local chosen={RewardId='Classic:Basic',SlapId='Classic',VariationId='Basic'}
 local fake={Character=rig};local ready=true
 local crates={ResolveEquipped=function()return chosen end,GetRewardTemplate=function()return game.ServerStorage.Slaps.Classic end,ApplyVariation=function()end}
 service:Init({GetService=function(_,name)if name=='CrateService'then return crates elseif name=='PlayerService'then return {IsShopDataReady=function()return ready end}end end})
 service._states[fake]={Character=rig,CharacterConnections={},Connections={}}
 service:Refresh(fake);check(rig:FindFirstChild('EquippedBackSlap')~=nil,'Loaded profile displays')
 local first=service._states[fake].Model;service:Refresh(fake);check(service._states[fake].Model==first,'Idempotent refresh')
 chosen={RewardId='Classic:Gold',SlapId='Classic',VariationId='Gold'};service:Refresh(fake)
 check(first.Parent==nil and service._states[fake].Model:GetAttribute('RewardId')=='Classic:Gold','Selection replaces old copy')
 local tool=Instance.new('Tool');tool:SetAttribute('IsSlapWeapon',true);tool.Parent=rig
 service:Refresh(fake);check(not rig:FindFirstChild('EquippedBackSlap'),'In hand hides back copy')
 tool:Destroy();service:Refresh(fake);check(rig:FindFirstChild('EquippedBackSlap')~=nil,'Removing weapon restores back')
 ready=false;service:Refresh(fake);check(not rig:FindFirstChild('EquippedBackSlap'),'Unloaded data hides copy')
 ready=true;service:Refresh(fake);service:_remove(fake);check(not rig:FindFirstChild('EquippedBackSlap')and not service._states[fake],'Leave cleanup')
 return {Assertions=assertions,Variants=tested,Mode='Edit isolated; no Play'}
end,debug.traceback)
rig:Destroy();temp:Destroy();if not ok then error(result)end;return result
