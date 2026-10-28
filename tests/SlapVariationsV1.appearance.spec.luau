--!nonstrict
local assertions=0
local function check(v,msg)assertions+=1;assert(v,msg)end
local function colour(name)return {Kind="Color3",Name=name}end
local vm={};local function vector(x,y,z)return setmetatable({Kind="Vector3",X=x,Y=y,Z=z},vm)end
function vm.__mul(a,b)return vector(a.X*b.X,a.Y*b.Y,a.Z*b.Z)end
local materials={SmoothPlastic={Name="SmoothPlastic"},Metal={Name="Metal"},Neon={Name="Neon"}}
local function object(class,name)
 local obj={ClassName=class,Name=name,Children={},Attrs={}}
 function obj:IsA(cls)return self.ClassName==cls or cls=="BasePart" and (class=="Part"or class=="MeshPart")end
 function obj:GetAttribute(key)return self.Attrs[key]end
 function obj:SetAttribute(key,value)self.Attrs[key]=value end
 function obj:GetChildren()local children={}for _,c in pairs(self.Children)do table.insert(children,c)end;return children end
 function obj:GetDescendants()local ds={}for _,c in pairs(self.Children)do table.insert(ds,c);for _,d in ipairs(c:GetDescendants())do table.insert(ds,d)end end;return ds end
 function obj:Destroy()if self.Parent then self.Parent.Children[self.Name]=nil end;self.Destroyed=true end
 function obj:Clone()
  local c=object(self.ClassName,self.Name)
  for key,value in pairs(self)do if type(value)~="function"and key~="Children"and key~="Attrs"and key~="_parent"then c[key]=value end end
  for key,value in pairs(self.Attrs)do c.Attrs[key]=value end
  for key,child in pairs(self.Children)do c.Children[key]=child:Clone();c.Children[key].Parent=c end
  return c
 end
 return setmetatable(obj,{__index=function(t,k)if k=="Parent"then return rawget(t,"_parent")end;return t.Children[k]end,
 __newindex=function(t,k,v)if k=="Parent"then rawset(t,"_parent",v);if v then v.Children[t.Name]=t end else rawset(t,k,v)end end})
end
local f=assert(loadstring(AppearanceSource))
setfenv(f,setmetatable({Enum={Material=materials},typeof=function(v)return type(v)=="table"and v.Kind or type(v)end},{__index=getfenv()}))
local appearance=f()
local hand=object("MeshPart","Hand");hand.Color=colour("Original");hand.Material=materials.SmoothPlastic
hand.Size=vector(2,4,6);hand.CanCollide=false;hand.CanTouch=true;hand.CanQuery=true;hand.Transparency=0
local original=hand.Color;local mesh=object("SpecialMesh","OriginalMesh");mesh.Parent=hand
local foreign=object("ParticleEmitter","ForeignEmitter");foreign.Rate=1;foreign.Parent=hand
local hit=object("Sound","Hit");hit.SoundId="approved-original";hit.Parent=hand
local profile=object("Folder","Gold");profile.Attrs={Tint=colour("Gold"),ApplyMaterial=true,Material="Metal",Intensity=1}
local at=object("Attachment","CosmeticOrigin");at.Attrs={ScaleToHand=true,NormalizedPosition=vector(.5,.25,0)}
local emitter=object("ParticleEmitter","Energy");emitter.Rate=10;emitter.Enabled=true;emitter.Parent=at
local light=object("PointLight","Glow");light.Brightness=.3;light.Enabled=true;light.Parent=at;at.Parent=profile
check(appearance.Apply(hand,profile),"Apply valid profile")
check(hand.Color==profile.Attrs.Tint and hand.Material==materials.Metal,"Tint and generic material applied")
check(hand.CosmeticOrigin~=at and hand.CosmeticOrigin.Energy~=emitter,"Independent physical cosmetic clone")
check(hand.CosmeticOrigin.Position.X==1 and hand.CosmeticOrigin.Position.Y==1,"Normalised attachments scale to model Hand size")
check(hand.CosmeticOrigin.Energy.Rate==10 and hand.CosmeticOrigin.Energy:GetAttribute("SlapVariationEmitter"),"Configured intensity and managed emitter marker")
check(hand.Size.X==2 and hand.Size.Y==4 and hand.Size.Z==6 and hand.CanCollide==false and hand.CanTouch==true and hand.CanQuery==true and hand.Transparency==0,"No geometry/hitbox/physics/transparency changes")
check(hand.OriginalMesh==mesh and hand.Hit.SoundId=="approved-original" and hand.ForeignEmitter==foreign,"Original mesh, audio and foreign resources preserved")
local first=hand.CosmeticOrigin
appearance.Apply(hand,profile)
check(first.Destroyed and #hand:GetChildren()==4,"Reapplication cleans only managed roots, no duplicates")
check(hand.CosmeticOrigin.Energy.Rate==10 and emitter.Rate==10,"Reapplication does not multiply template intensity")
profile.Attrs.Intensity=2;appearance.Apply(hand,profile)
check(hand.CosmeticOrigin.Energy.Rate==20,"Intensity configurable")
profile.Attrs.Intensity=100;appearance.Apply(hand,profile)
check(hand.CosmeticOrigin.Energy.Rate==20,"Excessive intensity bounded")
profile.Attrs.Intensity=0;appearance.Apply(hand,profile)
check(not hand.CosmeticOrigin.Energy.Enabled and not hand.CosmeticOrigin.Glow.Enabled,"Zero intensity disables particles/lights")
profile.Attrs.Intensity=0/0;appearance.Apply(hand,profile)
check(hand.CosmeticOrigin.Energy.Rate==10,"Invalid intensity uses safe default")
local bad=object("Attachment","Unsafe");object("LocalScript","Attack").Parent=bad;bad.Parent=profile
object("Part","Hitbox").Parent=profile
appearance.Apply(hand,profile)
check(not hand.Unsafe and not hand.Hitbox,"No scripts or decorative physical parts copied")
local basic=object("Folder","Basic");basic.Attrs={Tint=colour("Ignored"),ApplyTint=false,ApplyMaterial=false}
appearance.Apply(hand,basic)
check(hand.Color==original and hand.Material==materials.SmoothPlastic,"Basic restores original appearance after another skin")
check(hand.CosmeticOrigin==nil and hand.ForeignEmitter==foreign,"Basic has no leftover managed effect")
check(not appearance.Apply(nil,profile)and not appearance.Apply(object("Folder","NoHand"),profile),"Invalid visual target fails without combat effects")
local other=object("Part","HammerHand");other.Size=vector(10,2,2);other.Color=original;other.Material=materials.Neon
profile.Attrs.Intensity=1;appearance.Apply(other,profile)
check(other.CosmeticOrigin.Position.X==5 and other.CosmeticOrigin.Position.Y==.5,"Same profile reusable on different base geometry")
appearance.Apply(other,basic)
check(other.Material==materials.Neon,"Basic preserves a future Slap's own original material")
print("PASS SlapVariationsV1 Appearance: "..assertions.." isolated assertions; Studio/gameplay NOT RUN")
