local Profiles=loaded.VisualProfile
local Presenter=loaded.OverlayPresenter
for _,id in ipairs(C.Variations.Order)do
 local variation=C.Variations.ById[id];local profile=Profiles.For(variation)
 check(profile.Color==variation.Color and profile.Tier>=1 and profile.Tier<=6,"Registered variation color and bounded profile "..id)
 local emitter={Name="FlashSparks",GetAttribute=function(_,key)return if key=="BurstCount"then 24 else nil end}
 check(Profiles.Count(emitter,"Flash",profile)<=32 and Profiles.Count(emitter,"Rise",profile)==0,"Stage-specific bounded flash "..id)
 local streak={Name="RiseStreaks",GetAttribute=function(_,key)return if key=="BurstCount"then 6 else nil end}
 check(Profiles.Count(streak,"Rise",profile)>0 and Profiles.Count(streak,"Flash",profile)==0,"Authored RiseStreaks reused "..id)
end
local galaxy=Profiles.For(C.Variations.ById.Galaxy);local basic=Profiles.For(C.Variations.ById.Basic)
check(galaxy.Special and not basic.Special and galaxy.Light>basic.Light,"Rare treatment differs without economics changes")
local emitted=0;local list={}
for i=1,20 do table.insert(list,{Name="FlashSparks",IsA=function(_,kind)return kind=="ParticleEmitter"end,GetAttribute=function(_,key)return if key=="BurstCount"then 200 else nil end,Emit=function(_,n)emitted+=n end})end
Profiles.Emit({GetDescendants=function()return list end},"Flash",galaxy)
check(emitted==64,"Whole stage has a64particle cap")
for i=2,#plan.Stages do local at=plan.Stages[i].Start
 check(math.abs(Profiles.Rotation(plan,at-1e-7)-Profiles.Rotation(plan,at+1e-7))<1e-5,"Rotation continuous across stage "..plan.Stages[i].Name)
end
check(Profiles.Pose("Rise",0)==.5 and Profiles.Pose("Rise",1)==2.5,"Rise authored endpoints retained")
-- Actual overlay helper, engine tween targets applied immediately by the isolated fixture.
local oldUDim=extraEnv.UDim2
local udmeta={__add=function(x,y)return setmetatable({X=x.X+y.X,Y=x.Y+y.Y},getmetatable(x))end}
local function ud(x,y)return setmetatable({X=x,Y=y},udmeta)end
extraEnv.UDim2={fromScale=ud}
local function ui(class,name)
 local obj=node(class,name);obj.BackgroundTransparency=1;obj.TextTransparency=0;obj.Transparency=.2
 function obj:IsA(kind)return kind==class or kind=="GuiObject"and(class=="Frame"or class=="TextLabel")end
 return obj
end
local root=ui("Frame","RewardOverlay");root.Position=ud(.5,.75);root.BackgroundTransparency=.15;root.Visible=false
for _,name in ipairs({"Title","SlapName","VariationName"})do root.Children[name]=ui("TextLabel",name)end
root.Children.AccentStroke=ui("UIStroke","AccentStroke");root.Children.RevealScale={Scale=1}
function root:GetDescendants()return {self.Title,self.SlapName,self.VariationName,self.AccentStroke}end
local overlay=assert(Presenter.new(root))
local run={Private=true,Id="overlay-one",Tweens={}}
overlay:Show(run,C.Slaps.ById.Classic,C.Variations.ById.Galaxy)
check(root.Visible and root.SlapName.Text==C.Slaps.ById.Classic.DisplayName and root.VariationName.Text==C.Variations.ById.Galaxy.DisplayName,"Overlay uses actual registered reward names")
check(root.VariationName.TextColor3==C.Variations.ById.Galaxy.Color and root.AccentStroke.Color==C.Variations.ById.Galaxy.Color,"Overlay color comes from variation")
local tweens=#run.Tweens;overlay:Show(run,C.Slaps.ById.Classic,C.Variations.ById.Galaxy)
check(#run.Tweens==tweens,"Repeated reward phase does not duplicate overlay tweens")
overlay:Exit(run);check(root.SlapName.TextTransparency==1,"Outro fades overlay")
overlay:Reset("late-other");check(root.Visible,"Late cleanup cannot hide another opening")
overlay:Reset(run.Id);check(not root.Visible and root.Position==overlay.Position and root.SlapName.TextTransparency==0,"Cancel resets visibility authored geometry and alpha")
overlay:Show({Private=false,Id="spectator",Tweens={}},C.Slaps.ById.Classic,C.Variations.ById.Galaxy)
check(not root.Visible,"Spectator never receives private reward overlay")
extraEnv.UDim2=oldUDim
print("PASS CrateVisualV21: "..assertions.." combined isolated assertions; visual/gameplay NOT RUN")
