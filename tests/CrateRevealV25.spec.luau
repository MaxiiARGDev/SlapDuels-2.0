-- Actual visual modules against deterministic engine-independent instance fixtures. No Roblox execution.
local assertions=0
local function check(v,m)assertions+=1;assert(v,m)end
local function near(a,b)return math.abs(a-b)<1e-7 end
local cm={};local function color(n)return setmetatable({N=n},cm)end
function cm.__index(v,k)if k=="Lerp"then return function(a,b,t)return color(a.N+(b.N-a.N)*t)end end end
local vm={};local function vec(x,y,z)return setmetatable({X=x,Y=y,Z=z},vm)end
function vm.__add(a,b)return vec(a.X+b.X,a.Y+b.Y,a.Z+b.Z)end
function vm.__sub(a,b)return vec(a.X-b.X,a.Y-b.Y,a.Z-b.Z)end
function vm.__mul(a,b)return vec(a.X*b,a.Y*b,a.Z*b)end
function vm.__index(v,k)if k=="Magnitude"then return math.sqrt(v.X^2+v.Y^2+v.Z^2)elseif k=="Unit"then return v*(1/v.Magnitude)end end
local fm={};local function frame(p)return setmetatable({Position=p,Rotation=setmetatable({Position=vec(0,0,0)},fm)},fm)end
function fm.__mul(a,b)return frame(a.Position+b.Position)end
local function udim(a,b,c,d)return {X={Scale=a,Offset=b},Y={Scale=c,Offset=d}}end
local modules={};local rs={};local clones=0;local particles=0
local function node(kind,name)
 local n={ClassName=kind,Name=name,Attributes={},Children={}}
 function n:IsA(k)return self.ClassName==k end
 function n:GetAttribute(k)return self.Attributes[k]end
 function n:IsDescendantOf(target)local p=self.Parent;while p do if p==target then return true end;p=p.Parent end;return false end
 function n:GetDescendants()local list={};local function walk(o)for _,c in ipairs(o.Children)do table.insert(list,c);walk(c)end end;walk(self);return list end
 function n:FindFirstChild(k,recursive)for _,c in ipairs(if recursive then self:GetDescendants()else self.Children)do if c.Name==k then return c end end end
 function n:FindFirstChildWhichIsA(k)return if k=="BasePart"then {}else nil end
 function n:GetScale()return self.Scale or 1 end
 function n:ScaleTo(s)self.Scale=s end
 function n:GetExtentsSize()return vec(2,3,1)end
 function n:PivotTo(p)self.Pose=p end
 function n:GetPivot()return self.Pose or frame(vec(0,0,0))end
 function n:Emit(count)particles+=count;self.Emitted=(self.Emitted or 0)+count end
 function n:Play()self.Played=(self.Played or 0)+1 end
 function n:Destroy()self.Destroyed=true;self.Parent=nil;for _,c in ipairs(self.Children)do c:Destroy()end end
 function n:Clone()
  clones+=1;local c=node(self.ClassName,self.Name)
  for k,v in pairs(self)do if type(v)~="function"and k~="Children"and k~="Parent"then c[k]=v end end
  for _,ch in ipairs(self.Children)do local copy=ch:Clone();copy.Parent=c;table.insert(c.Children,copy);c[copy.Name]=copy end
  return c
 end
 return n
end
local templates=node("Folder","CrateRevealV25")
local function child(p,c)table.insert(p.Children,c);p[c.Name]=c;c.Parent=p;return c end
child(templates,node("Highlight","ChestHighlight"));child(templates,node("Highlight","RewardHighlight"))
local effects=child(templates,node("Model","RewardEffects"))
for rank=1,4 do local e=child(effects,node("ParticleEmitter","Emitter"..rank));e.Attributes.MinimumVisualRank=rank end
for i=1,16 do local b=child(effects,node("Beam","Beam"..i));b.Attributes.IsHalo=i<=12 end
child(effects,node("PointLight","Glow"));child(effects,node("Sound","JackpotReveal")).SoundId=""
child(templates,node("Sound","SpinTick")).SoundId=""
rs.UIAssets=node("Folder","UIAssets");child(rs.UIAssets,templates)
rs.CrateRewardPreviews=node("Folder","Previews");child(rs.CrateRewardPreviews,node("Model","Classic"))
rs.SlapVariationEffects=node("Folder","Effects")
function rs:FindFirstChild(k)return self[k]end
local catalog={Rewards={},Variations={ById={}},Slaps={ById={Classic={DisplayName="Clásico"}}}}
for i=1,10 do
 catalog.Rewards["r"..i]={RewardId="r"..i,SlapId="Classic",VariationId="v"..i}
 catalog.Variations.ById["v"..i]={Id="v"..i,Color=color(i),VisualProfile="Basic",DisplayName="Variation "..i,SortOrder=i}
end
rs.Shared={SlapCrates={OpeningConfig="OpeningConfig",Catalog="Catalog",Appearance="Appearance"}}
modules.OpeningConfig=assert(loadstring(Sources["Crates/OpeningConfig"]))();modules.Catalog=catalog;modules.Appearance={Apply=function()end}
modules.VisualProfile=assert(loadstring(Sources.VisualProfile))()
local env={game={GetService=function()return rs end},require=function(k)return assert(modules[k],k)end,
 script={Parent=setmetatable({},{__index=function(_,k)return k end})},Vector3={new=vec},
 CFrame={new=function(x,y,z)return frame(if type(x)=="table"then x else vec(x or 0,y or 0,z or 0))end,Angles=function()return frame(vec(0,0,0))end},
 ColorSequence={new=function(c)return c end},NumberSequence={new=function(n)return n end},UDim2={new=udim}}
setmetatable(env,{__index=getfenv()})
local function loadModule(k)local f=assert(loadstring(Sources[k]));setfenv(f,env);modules[k]=f();return modules[k]end
local config=loadModule("RewardRevealConfig");local profiles=loadModule("RewardRevealProfile")
local motion=loadModule("RewardSpinMotion");local spin=loadModule("RewardSpin3D");local vfx=loadModule("RewardVFX")
local metadata=assert(loadstring(Sources["Crates/RewardVisualMetadata"]))()
local rows={{Reward={RewardId="a"},Probability=.99995,Percent=99.995},{Reward={RewardId="b"},Probability=.00005,Percent=.005},{Reward={RewardId="c"},Probability=0,Percent=0}}
local percent,eligible=metadata.Read(rows,"b")
check(percent==.005 and #eligible==2 and eligible[2]=="b","Snapshot is the effective selected RewardId percentage and eligible set")
check(rows[2].Probability==.00005,"Metadata cannot mutate odds")
for _,row in ipairs({{100,1},{5.00001,1},{5,2},{1,2},{.9999,3},{.1,3},{.09999,4},{.01,4},{.00999,5}})do
 check(profiles.For(row[1],catalog.Variations.ById.v1).Rank==row[2],"Exact configurable percentage boundary")
end
for _,p in ipairs({0,-1,101,math.huge,0/0,".01",false,{}})do check(not profiles.For(p,catalog.Variations.ById.v1).Percent,"Invalid percentage never invented")end
check(profiles.For(nil,{Id="Galaxy",Color=color(1)}).Rank==5,"Actual variation fallback without probability")
check(profiles.For(.005,catalog.Variations.ById.v1).Rank~=profiles.For(50,catalog.Variations.ById.v1).Rank,"Same variation changes visual rank with effective crate odds")
local best,index=profiles.Best({{RewardId="r1",EffectivePercent=.05},{RewardId="r2",EffectivePercent=.005},{RewardId="r3",EffectivePercent=.005}},catalog)
check(index==2 and best.Rank==5,"Only rarest effective result receives global reaction, stable ties")
local cfg=modules.OpeningConfig.RewardSpin;local last=math.huge
for i=0,360 do
 local rem=motion.Remaining(i*.01,cfg);check(rem<=last and rem>=0,"Monotonic deterministic deceleration");last=rem
 local slots=motion.Slots(rem,5);local used={}
 for _,s in ipairs(slots)do check(not used[s.Pool]and math.abs(s.X)<=2.5,"Bounded unique recycled preview slots");used[s.Pool]=true end
end
check(motion.Remaining(cfg.SpinDuration,cfg)==0 and motion.Slots(0,5)[3].Winner,"Winner stops at exact center")
local steady=cfg.SpinDuration-cfg.DecelerationDuration
local velocityA=(motion.Remaining(steady-.001,cfg)-motion.Remaining(steady,cfg))/.001
local velocityB=(motion.Remaining(steady,cfg)-motion.Remaining(steady+.001,cfg))/.001
check(math.abs(velocityA-velocityB)<.02,"No velocity jump at deceleration boundary")
local function runFixture(q,mobile)
 return {Scene={},Objects={},VisualBudget=vfx.Budget(mobile,q),Plan={Stages={[8]={Start=7}}},
 Stand={RewardPoint={Position=vec(0,0,0),CFrame=frame(vec(0,0,0))},CameraPoint={CFrame={RightVector=vec(1,0,0),UpVector=vec(0,1,0)}}},Reward=node("Model","AuthoritativeWinner")}
end
for _,aspect in ipairs({16/9,.46})do
 local r=runFixture(1,false);local before=clones;r.Spin3D=spin.Create(r,{"r1","r2","r1","impossible"},function()end)
 check(#r.Spin3D.Pool==5,"Fixed five real previews")
 for _,p in ipairs(r.Spin3D.Pool)do check(p.RewardId=="r1"or p.RewardId=="r2","Only server eligible previews")end
 local afterCreate=clones
 local camera={ViewportSize={X=720*aspect,Y=720},FieldOfView=60}
 check(not spin.Update(r,6,camera)and r.Reward.Parent==nil,"No premature winner")
 for i=0,420 do spin.Update(r,7+i*.01,camera)end
 check(clones==afterCreate,"No clones allocated per frame")
 check(r.Spin3D.Finished and r.Reward.Parent==r.Scene,"Real winner revealed")
 check(near(r.Reward.Pose.Position.X,0)and near(r.Reward:GetScale(),cfg.WinningItemScale),"Exact centered actual winner scale")
 for _,p in ipairs(r.Spin3D.Pool)do check(p.Model.Parent==nil,"Decorative pool hidden at final reveal")end
 check(spin.CameraPosition(r,vec(0,0,5)).Magnitude>=5,"Camera settles safely")
 for _,o in ipairs(r.Objects)do o:Destroy();check(o.Destroyed,"All spin objects registered for existing cleanup")end
 check(clones>before,"Actual preview cloning exercised")
end
check(spin.Create(runFixture(1,false),{},function()end)==nil,"Legacy missing eligibility falls back safely")
for _,mobile in ipairs({false,true})do for _,count in ipairs({1,5,10})do
 local r=runFixture(count,mobile);local records={};local before=particles
 for i=1,count do
  local model=node("Model","Reward"..i);local record=vfx.Attach(r,model,catalog.Variations.ById["v"..i],.005,i==2 or count==1)
  check(record.Highlight.Adornee==model and not record.Highlight.Enabled,"Independent correct Highlight Adornee")
  check(record.Highlight.FillColor.N==i,"Independent variation color")
  for _,other in ipairs(records)do check(other.Highlight~=record.Highlight,"Never share Highlight instances")end
  table.insert(records,record)
 end
 for _,record in ipairs(records)do
  check(vfx.Reveal(r,record,10)and not vfx.Reveal(r,record,10.1),"One local burst per actual reward")
  vfx.Update(record,10.1);check(record.Highlight.Enabled,"Winner Highlight survives reveal")
  for _,beam in ipairs(record.Beams)do check(beam.Enabled,"Jackpot native rings and rays enabled")end
  local label={Size=udim(0,180,0,60)};vfx.Label(record,label,10.2);check(label.Size.X.Offset>=180 and label.Size.X.Offset<=184.5,"Limited exceptional Billboard emphasis")
  vfx.Update(record,15);for _,beam in ipairs(record.Beams)do check(not beam.Enabled,"Beams finite duration")end
  record.FX:Destroy();record.Highlight:Destroy();check(record.FX.Destroyed and record.Highlight.Destroyed,"Disposable local FX")
 end
 check(particles-before<=(if mobile then 24 else 64)and r.VisualBudget.Remaining>=0,"Bounded PC/mobile batch particles")
 check(r.VisualBudget.Beams<=(if mobile then 1 else 2),"Bounded halo/ray groups per batch")
end end
local r=runFixture(1,false);local chest=node("Model","Chest");local chestFx=vfx.Chest(r,chest,{color(1),color(9)},catalog.Variations.ById.v3)
check(chestFx.Highlight.Adornee==chest,"Chest Highlight uses cloned presentation model")
vfx.UpdateChest(chestFx,"Rise",.5,.1);local first=chestFx.Highlight.FillColor.N
vfx.UpdateChest(chestFx,"Growth",.5,.5);check(chestFx.Highlight.FillColor.N~=first,"Chromatic cycle interpolates")
vfx.UpdateChest(chestFx,"Shake",1,2);check(near(chestFx.Highlight.FillColor.N,3),"Shake locks actual winning variation")
vfx.UpdateChest(chestFx,"Flash",0,3);check(near(chestFx.Highlight.FillColor.N,3),"Final color remains exact through Flash")
vfx.UpdateChest(chestFx,"Reward",0,4);check(not chestFx.Highlight.Enabled,"Chest Highlight disabled after explosion")
for i=0,100 do local x,y,a=vfx.Reaction(best,i*.01,false);check(math.abs(x)<=.1 and math.abs(y)<=.1 and math.abs(a)<=math.rad(.35),"Bounded local camera reaction")end
local x,y,a=vfx.Reaction(best,1,false);check(x==0 and y==0 and a==0,"Reaction ends automatically")
-- Actual gallery + actual VFX integration, rather than only the legacy gallery stub.
local slot=child(rs.UIAssets,node("Model","CrateBatchRewardSlot"))
local anchor=child(slot,node("Part","Anchor"));local billboard=child(anchor,node("BillboardGui","BillboardGui"))
child(billboard,node("TextLabel","Slap"));child(billboard,node("TextLabel","Variation"));billboard.Size=udim(0,180,0,60)
modules.CinematicConfig=assert(loadstring(Sources.CinematicConfig))()
loadModule("RewardGalleryLayout");local gallery=loadModule("RewardGallery")
for _,count in ipairs({5,10})do
 local r=runFixture(count,true);r.GlobalFX={Index=2};local units={}
 for i=1,count do units[i]={RewardId="r"..i,EffectivePercent=if i==2 then .005 else .05}end
 r.Gallery=gallery.Create(r,units,function()end)
 gallery.Update(r,9,{ViewportSize={X=375,Y=812},FieldOfView=60})
 check(#r.Gallery.Rows==count and r.PrimaryRewardRevealed,"Actual batch gallery reveals primary result")
 for i,row in ipairs(r.Gallery.Rows)do
  check(row.VFX.Highlight.Enabled and row.VFX.Highlight.Adornee==row.Model,"Every actual gallery result has own enabled Highlight")
  check(row.VFX.Highlight.FillColor.N==i and row.Label.Enabled,"Actual gallery retains independent metadata and colors")
 end
 local emittedBefore=particles;gallery.Update(r,9.1,{ViewportSize={X=375,Y=812},FieldOfView=60})
 check(particles==emittedBefore,"Actual gallery repeated frames never repeat reveal burst")
end
local timeline=assert(loadstring(Sources["Crates/OpeningTimeline"]))()
check(timeline.Build(modules.OpeningConfig,1).Duration==13.5,"Shared x1 timeline includes spin and final pause")
local ledgerClass=assert(loadstring(Sources["Crates/StandOpeningLedger"]))();local now=100
local plan=timeline.Build(modules.OpeningConfig,1);local ledger=ledgerClass.new(modules.OpeningConfig,plan,function()return now end)
local lease=assert(ledger:Acquire(-1,"Main","spin"));check(ledger:Commit(lease,"winner"),"Actual ledger accepts shared extended plan")
now=110.5;check(#ledger:Step()==0,"Old deadline cannot interrupt the new spin")
now=113.49;check(#ledger:Step()==0,"Final pause and Outro protected until full presentation")
now=113.5;check(#ledger:Step()==1,"Extended deadline releases visual lease exactly once")
check(timeline.Build(modules.OpeningConfig,5).Duration==11.5 and timeline.Build(modules.OpeningConfig,10).Duration==12.5,"Batch duration unchanged")
local classic=table.clone(modules.OpeningConfig);classic.Mode="Spin";check(timeline.Build(classic,1).Duration==10.5,"Classic timeline unchanged")
local invalid=table.clone(modules.OpeningConfig);invalid.RewardSpin=table.clone(cfg);invalid.RewardSpin.InitialSpeed=0
check(not timeline.Build(invalid,1),"Malformed visual config fails closed")
print("PASS CrateRevealV25: "..assertions.." isolated visual/metadata assertions; actual rendering NOT RUN")
