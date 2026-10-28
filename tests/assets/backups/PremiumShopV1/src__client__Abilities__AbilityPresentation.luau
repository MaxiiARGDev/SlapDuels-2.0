--!nonstrict
-- Only session participants receive these records. Local visual changes never
-- touch collision, hitboxes, health, equipped tools or persistent preferences.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local TweenService=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local Catalog=require(RS.Shared.AbilityCatalog)
local Profiles=require(script.Parent.AbilityPresentationProfiles)
local Presentation={}
Presentation.__index=Presentation
function Presentation.new() return setmetatable({Active={},Impacts={},Transient={}},Presentation) end
function Presentation:_remove(key)
 local record=self.Active[key]
 if not record then return end
 self.Active[key]=nil
 if record.Connection then record.Connection:Disconnect() end
 for object,properties in pairs(record.Saved) do
  if object.Parent then
   for property,values in pairs(properties) do
    -- A later local visual owner wins; restore only values still owned here.
    pcall(function() if object[property]==values.Applied then object[property]=values.Original end end)
   end
  end
 end
 for _,v in ipairs(record.Assets) do v:Destroy() end
end
function Presentation:Reconcile(payload)
 local desired={}
 if payload.Playing and payload.SessionId==Players.LocalPlayer:GetAttribute("MatchId") then
  for _,effect in ipairs(payload.Presentations or {}) do
   local player=Players:GetPlayerByUserId(effect.UserId)
   local char=player and player.Character
   local root=char and char:FindFirstChild("HumanoidRootPart")
   local definition=Catalog.GetItem(effect.AbilityId)
   if definition and char and root and (char:GetAttribute("ArenaPhysicsGeneration") or 0)==effect.CharacterGeneration
    and not char:GetAttribute("ArenaRespawnPending") and effect.ActiveUntil>workspace:GetServerTimeNow() then
    desired[effect.ActivationId]=true
    local record=self.Active[effect.ActivationId]
    if record and record.Character~=char then self:_remove(effect.ActivationId);record=nil end
    if not record then
     record={Saved={},Assets={},Character=char,Until=effect.ActiveUntil,Generation=effect.CharacterGeneration}
     self.Active[effect.ActivationId]=record
     Profiles.Start(definition.Assets,record,char,root)
    end
   end
  end
 end
 local remove={}
 for key in pairs(self.Active) do if not desired[key] then table.insert(remove,key) end end
 for _,key in ipairs(remove) do self:_remove(key) end
end
function Presentation:Tick()
 local remove={}
 for key,r in pairs(self.Active) do
  if not r.Character.Parent or r.Character:GetAttribute("ArenaRespawnPending")
   or (r.Character:GetAttribute("ArenaPhysicsGeneration") or 0)~=r.Generation or workspace:GetServerTimeNow()>=r.Until then table.insert(remove,key) end
 end
 for _,key in ipairs(remove) do self:_remove(key) end
end
function Presentation:Impact(payload)
 if payload.SessionId~=Players.LocalPlayer:GetAttribute("MatchId") or self.Impacts[payload.ActivationId] then return end
 self.Impacts[payload.ActivationId]=true
 local definition=Catalog.GetItem(payload.AbilityId)
 local cue=definition and definition.Assets.Cues[payload.Cue]
 if not cue or cue.Profile~="VerticalLaunch" or typeof(payload.Position)~="Vector3" then return end
 local folder=RS:FindFirstChild("AbilityEffects")
 local assets=folder and folder:FindFirstChild(definition.Assets.Key)
 local template=assets and assets:FindFirstChild(cue.Resource)
 if not template or not template:IsA("BasePart") then return end
 -- Visual prop only: no force is applied to the competitive Character.
 local prop=template:Clone();prop:SetAttribute("AbilityPresentation",true)
 prop.CFrame=CFrame.new(payload.Position);prop.Parent=workspace
 self.Transient[prop]=true
 local tween=TweenService:Create(prop,TweenInfo.new(cue.Duration,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
  {CFrame=prop.CFrame+Vector3.new(0,cue.Lift,0),Transparency=1})
 tween:Play();Debris:AddItem(prop,cue.Duration+0.15)
 task.delay(cue.Duration+0.25,function() self.Transient[prop]=nil end)
end
function Presentation:Clear()
 local keys={} for key in pairs(self.Active) do table.insert(keys,key) end
 for _,key in ipairs(keys) do self:_remove(key) end
 for prop in pairs(self.Transient) do prop:Destroy() end
 self.Transient={};self.Impacts={}
end
return Presentation
