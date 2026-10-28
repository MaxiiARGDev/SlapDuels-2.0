--!nonstrict
local Config=require(game.ReplicatedStorage.Shared.DeathFeedbackConfig)
local Catalog=require(game.ReplicatedStorage.Shared.DeathEffectDefinitions)
local Scope=require(script.Parent.Scope)
local Player={}
local function number(object,key,fallback,max)
 local value=object:GetAttribute(key)
 if type(value)~="number" or value~=value then value=fallback end
 return math.clamp(value,0,max)
end
function Player.Play(payload)
 local scope=Scope.new()
 if not Config.DeathEffects.Enabled then scope:Destroy();return scope end
 local definition=Catalog[payload.EffectId]
 local assets=game.ReplicatedStorage:FindFirstChild("DeathEffectAssets")
 local source=definition and assets and assets:FindFirstChild(definition.ModelName)
 if not source or not source:IsA("Model") then
  warn("[DeathFeedback] Physical effect missing: "..tostring(payload.EffectId));scope:Destroy();return scope
 end
 local model=scope:Add(source:Clone())
 model.Name="DeathFeedback_"..payload.EliminationId
 local origin=model:FindFirstChild("Origin")
 if not origin or not origin:IsA("BasePart") then scope:Destroy();return scope end
 -- Origin is the editable physical origin, independently of the template's artistic pivot.
 model:PivotTo(payload.ImpactCFrame*origin.CFrame:Inverse()*model:GetPivot())
 local duration=number(model,"Duration",definition.Duration,Config.DeathEffects.MaxDuration)
 for _,object in ipairs(model:GetDescendants()) do
  if object:IsA("ParticleEmitter") then object.Enabled=false
  elseif object:IsA("Sound") then object.Looped=false;object:Stop()
  elseif object:IsA("PointLight") then object.Brightness=0 end
 end
 model.Parent=workspace -- LOCAL clone only, never replicated from the server into Workspace.
 for _,object in ipairs(model:GetDescendants()) do
  if object:IsA("ParticleEmitter") and Config.DeathEffects.ParticlesEnabled then
   scope:Delay(number(object,"EmitDelay",definition.EmitDelay,duration),function()
    if object.Parent then object:Emit(math.floor(number(object,"EmitCount",definition.EmitCount,80))) end
   end)
  elseif object:IsA("Sound") and Config.DeathEffects.SoundsEnabled and object.SoundId~="" then
   scope:Delay(number(object,"PlayDelay",definition.PlayDelay,duration),function()if object.Parent then object:Play() end end)
  elseif object:IsA("PointLight") and Config.DeathEffects.ParticlesEnabled then
   object.Brightness=number(object,"LightPeak",3,8)
   scope:Tween(object,.25,{Brightness=0})
  end
 end
 scope:Delay(duration,function() scope:Destroy() end)
 return scope
end
return Player
