local config=refs.CinematicConfig
local motion=refs.CinematicMotion
local function standalone(name,env)
 local f=assert(loadstring(Sources[name]));setfenv(f,setmetatable(env or {},{__index=getfenv()}));return f()
end
local opening=standalone("Crates/OpeningConfig")
local timeline=standalone("Crates/OpeningTimeline")
local plan=assert(timeline.Build(opening))
local expectedDuration=10.5
if opening.RewardSpin then expectedDuration+=opening.RewardSpin.SpinDuration+opening.RewardSpin.FinalPauseDuration-3 end
check(math.abs(plan.Duration-expectedDuration)<1e-6,"Shared timeline covers x1 spin and final pause")
check(config.RewardOverlayByMode.StandCinematic==false and config.RewardOverlayByMode.Spin==true,"Stand-only overlay policy")
local shown=0;controller._overlay={Show=function()shown+=1 end}
controller:_showReward({Private=true,RewardDefinition={},Profile={Special=false}})
check(shown==0,"Actual stand controller does not call overlay presenter")
controller._overlay=nil
check(motion.Cover("Intro",0,config.Transition)==0,"Intro begins open")
check(motion.Cover("Intro",1,config.Transition)==.5,"Intro closes fully")
check(motion.Cover("CameraReveal",0,config.Transition)==.5,"Camera cut concealed")
check(motion.Cover("CameraReveal",1,config.Transition)==config.Transition.Letterbox,"Reveal opens into letterbox")
check(motion.Cover("Outro",config.Transition.OutroHandoff,config.Transition)==.5,"Full blackout at camera handoff")
check(motion.Cover("Outro",1,config.Transition)==0,"Outro ends open")
local high=motion.Sample(plan,plan.Stages[2].Start,"CameraReveal",0,config.Camera)
check(high.Drop==1 and high.Fov==config.Camera.IntroFov,"Elevated wide entry")
local settle=motion.Sample(plan,plan.Stages[2].Start+config.Camera.IntroDuration,"Rise",.5,config.Camera)
check(math.abs(settle.Drop)<1e-10 and settle.Fov==0,"Entry lands at authored camera framing")
local bounce=motion.Sample(plan,plan.Stages[2].Start+config.Camera.IntroDuration*.8,"Appear",.5,config.Camera)
check(bounce.Drop<0 and bounce.Drop>-.05,"Small landing overshoot")
local impact=motion.Sample(plan,plan.Stages[7].Start,"Flash",0,config.Camera)
local calm=motion.Sample(plan,plan.Stages[7].Start+config.Camera.ImpactDuration,"Reward",.5,config.Camera)
check(impact.Impact==1 and calm.Impact<1e-12,"Impact envelope returns to zero")
for i=0,600 do
 local elapsed=plan.Duration*i/600;local stage,p=timeline.At(plan,elapsed)
 local sample=motion.Sample(plan,elapsed,stage,p,config.Camera)
 check(math.abs(sample.X)<=config.Camera.MaxPositionShake and math.abs(sample.Y)<=config.Camera.MaxPositionShake,"Shake positional cap")
 check(math.abs(sample.Pitch)<=math.rad(config.Camera.MaxDegreesShake)and math.abs(sample.Roll)<=math.rad(config.Camera.MaxDegreesShake),"Shake angular cap")
 check(motion.Cover(stage,p,config.Transition)>=0 and motion.Cover(stage,p,config.Transition)<=.5,"Shutters remain within screen")
end
-- Real local prompt lease; independent spectator prompt never enters scope.
local prompts=standalone("StandPromptVisibility")
local stand=object("Model");local prompt=add(stand,object("ProximityPrompt",{Enabled=true}))
local disabled=add(stand,object("ProximityPrompt",{Enabled=false}))
local spectatorPrompt=object("ProximityPrompt",{Enabled=true})
local lease=prompts.Acquire(stand,"buyer")
check(not prompt.Enabled and not disabled.Enabled and spectatorPrompt.Enabled,"Only selected local stand prompts hidden")
prompt.Enabled=true;check(not prompt.Enabled,"Server enable does not expose prompt during opening")
local dynamic=add(stand,object("ProximityPrompt",{Enabled=true}));check(not dynamic.Enabled,"Dynamic prompt hidden")
prompts.Release(lease);prompts.Release(lease)
check(prompt.Enabled and dynamic.Enabled and not disabled.Enabled,"Prompt exact previous state restored")
check(lease.Released and next(lease.Saved)==nil and lease.Connection==nil,"Prompt lease cleaned")
local hud={Top={},Bottom={},Overlay={Visible=false}}
function hud:FindFirstChild(name)return if name=="ShutterTop"then self.Top elseif name=="ShutterBottom"then self.Bottom else self.Overlay end
local transition=standalone("CinematicTransition",{UDim2={fromScale=function(x,y)return {X=x,Y=y}end}})
transition.Update(hud,.5);check(hud.Top.Size.Y==.5 and hud.Bottom.Size.Y==.5 and hud.Top.Visible,"Two shutters cover viewport")
transition.Reset(hud);check(not hud.Top.Visible and not hud.Bottom.Visible and not hud.Overlay.Visible,"Cleanup hides shutters without touching overlay")
print("PASS CrateCinematicV23: "..count.." isolated assertions including V2.2 lifecycle; visual acceptance NOT RUN")
