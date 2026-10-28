--!nonstrict
local TweenService=game:GetService("TweenService")
local Scope={}
Scope.__index=Scope
function Scope.new() return setmetatable({Dead=false,Objects={},Threads={},Tweens={}},Scope) end
function Scope:Add(object) table.insert(self.Objects,object);return object end
function Scope:Delay(seconds,callback)
 local thread
 thread=task.delay(math.max(0,seconds),function()
  self.Threads[thread]=nil
  if not self.Dead then
   local ok,failure=pcall(callback)
   if not ok then warn("[DeathFeedback] "..tostring(failure));self:Destroy() end
  end
 end)
 self.Threads[thread]=true
 return thread
end
function Scope:Tween(object,duration,properties)
 if self.Dead then return end
 local tween=TweenService:Create(object,TweenInfo.new(math.max(.001,duration),Enum.EasingStyle.Sine),properties)
 table.insert(self.Tweens,tween);tween:Play()
 return tween
end
function Scope:Destroy()
 if self.Dead then return end
 self.Dead=true
 for thread in pairs(self.Threads) do pcall(task.cancel,thread) end
 for _,tween in ipairs(self.Tweens) do tween:Cancel();tween:Destroy() end
 for _,object in ipairs(self.Objects) do object:Destroy() end
 table.clear(self.Threads);table.clear(self.Objects);table.clear(self.Tweens)
end
return Scope
