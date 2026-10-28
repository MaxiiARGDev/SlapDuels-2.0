--!nonstrict
local Config = require(game.ReplicatedStorage.Shared.EndCinematicConfig)
local Module = {}

function Module.Prepare(run, stage)
 local original = stage:FindFirstChild("Confeti")
 local effects = original and original:Clone() or Instance.new("Folder")
 effects.Name = "Particles"
 for _, object in ipairs(effects:GetDescendants()) do
  if object:IsA("LuaSourceContainer") or object:IsA("Sound") then object:Destroy()
  elseif object:IsA("ParticleEmitter") then object.Enabled = false; object:Clear()
  elseif object:IsA("BasePart") then
   object.Anchored = true; object.CanCollide = false; object.CanTouch = false; object.Transparency = 1
  end
 end
 effects.Parent = run.Container
 run.Effects = effects
 if original then
  for _, object in ipairs(original:GetDescendants()) do
   if object:IsA("ParticleEmitter") and object.Enabled then
    warn("[EndCinematic] Original emitter active outside preview: " .. object:GetFullName())
   end
  end
 end
end

function Module.Play(run)
 if not run:IsAlive() or not Config.Effects.ConfettiEnabled then return end
 for _, object in ipairs(run.Effects:GetDescendants()) do
  if object:IsA("ParticleEmitter") then
   object.Enabled = object.Rate > 0
   if object.Rate == 0 then object:Emit(object:GetAttribute("EmitCount") or Config.Effects.BurstCount) end
  end
 end
end

function Module.Stop(run)
 if not run.Effects then return end
 for _, object in ipairs(run.Effects:GetDescendants()) do
  if object:IsA("ParticleEmitter") then object.Enabled = false end
 end
end

function Module.Cleanup(run)
 Module.Stop(run)
 if run.Effects then run.Effects:Destroy(); run.Effects = nil end
end
return Module
