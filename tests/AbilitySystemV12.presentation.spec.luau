--!nonstrict
-- Local property mocks validate restoration; visual/gameplay validation is manual.
local passed=0
local function check(v,label)assert(v,label);passed+=1 end
local function load(name,env)
 local f=assert(loadstring(Sources[name],name));setfenv(f,setmetatable(env or {},{__index=getfenv()}));return f()
end
local effects={FindFirstChild=function()return nil end}
local RS={Shared={AbilityCatalog="Catalog"},FindFirstChild=function()return effects end}
local gameMock={GetService=function(_,name)return if name=="ReplicatedStorage" then RS else {}end}
local Profiles=load("Profiles",{game=gameMock,Enum={HumanoidDisplayDistanceType={None="None"}}})
local function object(class,properties)
 local o=properties or {};o.Parent=o.Parent or {GetAttribute=function()return nil end}
 function o:IsA(c)return c==class end
 function o:GetAttribute()return nil end
 return o
end
local part=object("BasePart",{LocalTransparencyModifier=.2})
local toolPart=object("BasePart",{LocalTransparencyModifier=0})
local decal=object("Decal",{Transparency=.3})
local emitter=object("ParticleEmitter",{Enabled=true})
local billboard=object("BillboardGui",{Enabled=true})
local hum=object("Humanoid",{DisplayDistanceType="Viewer"})
local descendants={part,toolPart,decal,emitter,billboard,hum}
local added,disconnected
local char={GetDescendants=function()return descendants end,
 DescendantAdded={Connect=function(_,cb)added=cb;return {Disconnect=function()disconnected=true end}end}}
local record={Saved={},Assets={},Character=char}
Profiles.Start({Profile="InvisibleAvatar",Key="Invisible"},record,char,{})
check(part.LocalTransparencyModifier==1 and toolPart.LocalTransparencyModifier==1,"Invisibility hides avatar and equipped tool locally")
check(decal.Transparency==1 and not emitter.Enabled and not billboard.Enabled and hum.DisplayDistanceType=="None","Associated presentation is hidden")
local newPart=object("BasePart",{LocalTransparencyModifier=.4});added(newPart)
check(newPart.LocalTransparencyModifier==1,"Late accessory receives local invisibility")
added(newPart)
check(record.Saved[newPart].LocalTransparencyModifier.Original==.4,"Repeated descendant notification cannot overwrite original state")
part.LocalTransparencyModifier=.7 -- New local visual owner wins.
local Presentation=load("Presentation",{game=gameMock,script={Parent={AbilityPresentationProfiles="Profiles"}},
 require=function(key)return if key=="Profiles" then Profiles else {}end})
local presentation=Presentation.new();presentation.Active.test=record
presentation:_remove("test")
check(disconnected and presentation.Active.test==nil,"Cleanup detaches descendant connection and active record")
check(part.LocalTransparencyModifier==.7,"Restoration preserves a later local owner")
check(toolPart.LocalTransparencyModifier==0 and decal.Transparency==.3 and emitter.Enabled and billboard.Enabled,"Original avatar/tool presentation restored")
check(hum.DisplayDistanceType=="Viewer" and newPart.LocalTransparencyModifier==.4,"Humanoid and late accessory restored")
presentation:_remove("test")
check(toolPart.LocalTransparencyModifier==0,"Repeated presentation removal is idempotent")
check(part.CanCollide==nil and hum.Health==nil,"Presentation writes no collision or health values")

local Validator=load("AssetValidator")
local root={FindFirstChild=function()return nil end}
check(not Validator.Validate({Profile="AttachmentEffect",Key="Missing"},root),"Missing physical folder rejected")
local origin=object("Attachment")
local particle=object("ParticleEmitter")
local list={origin,particle}
local template={FindFirstChild=function(_,name)return if name=="Origin" then origin else nil end,GetDescendants=function()return list end}
root.FindFirstChild=function()return template end
check(Validator.Validate({Profile="AttachmentEffect",Key="Test"},root),"Authored attachment and visual trace accepted")
list={origin}
check(not Validator.Validate({Profile="AttachmentEffect",Key="Test"},root),"Empty visual template rejected")
list={origin,particle,object("LuaSourceContainer")}
check(not Validator.Validate({Profile="AttachmentEffect",Key="Test"},root),"Executable physical asset rejected")
list={origin,particle,object("BasePart",{Anchored=true,CanCollide=true,CanTouch=false,CanQuery=false})}
check(not Validator.Validate({Profile="AttachmentEffect",Key="Test"},root),"Colliding visual prop rejected")
list={origin,particle,object("Trail")}
check(not Validator.Validate({Profile="AttachmentEffect",Key="Test"},root),"Dangling trail attachments rejected")
list={origin,particle}
check(not Validator.Validate({Profile="AttachmentEffect",Key="Test",Cues={Impact={Resource="Missing"}}},root),"Missing impact prop rejected")
check(Validator.Validate({Profile="None"},nil),"Explicit asset-free profile needs no physical resource")
print(string.format("PASS: %d isolated presentation/resource assertions; no Studio/gameplay/cloud execution.",passed))
