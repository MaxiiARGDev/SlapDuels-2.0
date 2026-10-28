local assertions=0
local function check(v,m)assertions+=1;assert(v,m)end
local config=assert(loadstring(Sources.CinematicConfig))()
local layout=assert(loadstring(Sources.RewardGalleryLayout))()
local vm={}
local function vec(x,y,z)return setmetatable({X=x,Y=y,Z=z},vm)end
function vm.__add(a,b)return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
function vm.__sub(a,b)return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
function vm.__mul(a,b)return vec(a.X*b,a.Y*b,a.Z*b)end
function vm.__index(v,k)if k=="Magnitude"then return math.sqrt(v.X^2+v.Y^2+v.Z^2)elseif k=="Unit"then return v*(1/v.Magnitude)end end
local cf={};local function frame(position)return setmetatable({Position=position},cf)end
function cf.__mul(a,b)return frame(a.Position+b.Position)end
local emitted=0;local clones=0;local slots=0;local cleaned=0
local function effect()return {IsA=function(_,kind)return kind=="ParticleEmitter"end,Emit=function(_,n)emitted+=n end}end
local function preview()
 clones+=1
 local model={Effects={effect()}}
 function model:FindFirstChildWhichIsA()return {}end
 function model:GetExtentsSize()return vec(2,3,1)end
 function model:GetScale()return 1 end
 function model:GetDescendants()return self.Effects end
 function model:ScaleTo(n)self.Scale=n end
 function model:PivotTo(pose)self.Pose=pose end
 function model:Destroy()self.Destroyed=true;self.Parent=nil;cleaned+=1 end
 return model
end
local source={Clone=preview}
local template={Clone=function()
 slots+=1
 local slot={Anchor={BillboardGui={Slap={},Variation={}}}}
 function slot:Destroy()self.Destroyed=true;self.Parent=nil;cleaned+=1 end
 return slot
end}
local catalog={Rewards={},Slaps={ById={Classic={DisplayName="Clásico"}}},Variations={ById={}}}
for index=1,10 do
 catalog.Rewards["prize"..index]={RewardId="prize"..index,SlapId="Classic",VariationId="variation"..index}
 catalog.Variations.ById["variation"..index]={DisplayName="Variación "..index,VisualProfile="profile",Color=index,SortOrder=index}
end
local rs={UIAssets={FindFirstChild=function()return template end},SlapVariationEffects={FindFirstChild=function()return {}end}}
local slap={FindFirstChild=function()return source end}
function rs:FindFirstChild()return {FindFirstChild=function()return slap end}end
local modules={Catalog=catalog,Appearance={Apply=function()end},CinematicConfig=config,RewardGalleryLayout=layout}
modules.RewardVFX={Attach=function()return {}end,Reveal=function()end,Update=function()end,Label=function()end}
rs.Shared={SlapCrates={Catalog="Catalog",Appearance="Appearance"}}
local f=assert(loadstring(Sources.RewardGallery))
setfenv(f,setmetatable({game={GetService=function()return rs end},require=function(k)return assert(modules[k])end,
 script={Parent={CinematicConfig="CinematicConfig",RewardGalleryLayout="RewardGalleryLayout",RewardVFX="RewardVFX"}},
 CFrame={new=function(value)return frame(value)end,Angles=function()return frame(vec(0,0,0))end},Vector3={new=vec}},{__index=getfenv()}))
local gallery=f()
for _,count in ipairs({5,10})do
 local camera={ViewportSize={X=1280,Y=720}}
 local run={Scene={},Objects={},Plan={Stages={[8]={Start=7}}},Stand={CameraPoint={CFrame={RightVector=vec(1,0,0),UpVector=vec(0,1,0)}},RewardPoint={Position=vec(0,0,0),CFrame={Rotation=frame(vec(0,0,0))}}}}
 local rewards={};for index=1,count do rewards[index]={RewardId="prize"..index}end
 run.Gallery=gallery.Create(run,rewards,function()end)
 check(#run.Gallery.Rows==count and #run.Objects==count*2,"One model and one editable slot per actual result")
 gallery.Update(run,6.9,camera)
 for _,row in ipairs(run.Gallery.Rows)do check(not row.Model.Parent and not row.Label.Enabled,"No prize before reveal")end
 gallery.Update(run,7,camera)
 check(run.Gallery.Rows[1].Model.Parent~=nil and not run.Gallery.Rows[2].Model.Parent,"Stagger starts with first reward only")
 gallery.Update(run,8.5,camera)
 for index,row in ipairs(run.Gallery.Rows)do
  check(row.Label.Enabled and row.Model.Parent==row.Slot and row.Model.Scale>0,"All actual prizes visible together")
  check(row.Label.Variation.Text=="Variación "..index and row.Label.Variation.TextColor3==index,"Each result has its own metadata")
 end
 local initialEmitted=emitted;gallery.Update(run,9,camera);check(emitted==initialEmitted,"Repeated frame cannot repeat reveal effects")
 check(run.Gallery.Emitted<=config.Gallery.MaxRevealParticles,"Per-opening particle budget")
 local position=gallery.CameraPosition(run,vec(0,0,5))
 check(position.Magnitude>=run.Gallery.Layout.Distance,"Camera backs up to fit all prizes")
 camera.ViewportSize={X=375,Y=812};gallery.Update(run,9,camera)
 check(#run.Gallery.Layout.Positions==count,"Portrait retains every prize")
 for _,object in ipairs(run.Objects)do object:Destroy()end
 for _,object in ipairs(run.Objects)do check(object.Destroyed,"All batch visuals disposable by existing run cleanup")end
end
check(clones==15 and slots==15 and cleaned==30,"No duplicate prize models or lost preview roots")
print("PASS CrateBatchV24 Gallery: "..assertions.." isolated renderer-contract assertions; actual rendering NOT RUN")
