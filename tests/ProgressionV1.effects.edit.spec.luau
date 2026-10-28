assert(not game:GetService('RunService'):IsRunning(),'Edit only')
local registry=game.ServerScriptService.PointEffectControllers.PointEffectRegistry:Clone();registry.Name='__ProgressionRegistry';registry.Parent=game.ServerScriptService.PointEffectControllers
local count=0
local function check(v,m)assert(v,m);count+=1 end
local ok,result=xpcall(function()
 local r=require(registry)
 for _,id in ipairs({'Frost','Void'})do
  local template=game.ServerStorage.PointEffects[id]
  check(template:IsA('Model')and template.PrimaryPart==template.Origin,'Model pivot contract')
  check(r.Has(id)and type(r.GetController(id).Play)=='function','Explicit attribute controller registered')
  local emitters=0
  for _,o in ipairs(template:GetDescendants())do
   check(not o:IsA('LuaSourceContainer'),'No embedded scripts')
   if o:IsA('BasePart')then check(o.Anchored and not o.CanCollide and not o.CanTouch and not o.CanQuery,'Safe visual-only geometry')
   elseif o:IsA('ParticleEmitter')then
    emitters+=1;check(not o.Enabled and o.Rate==0,'No spontaneous particles')
    check(o:GetAttribute('EmitCount')>0 and o:GetAttribute('EmitCount')<=60,'Bounded bursts')
    check(o.Lifetime.Max+o:GetAttribute('EmitDelay')<template:GetAttribute('Duration'),'Particles end before cleanup')
   elseif o:IsA('Beam')then check(o.Attachment0:IsDescendantOf(template)and o.Attachment1:IsDescendantOf(template),'Beam references stay internal')end
  end
  check(emitters==5,'Five authored emitters')
 end
 return {Assertions=count,Scope='Physical templates and controller registration; no Play(context), particle emission or audio playback'}
end,debug.traceback)
registry:Destroy();if not ok then error(result)end;return result
