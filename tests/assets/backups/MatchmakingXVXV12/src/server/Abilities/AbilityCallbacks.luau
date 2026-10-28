--!nonstrict
-- Ability lifecycle callbacks must not yield. A suspended callback is cancelled
-- before it can resume against a different Character/round.
local Callbacks={}
function Callbacks.Call(callback,...)
 if type(callback)~="function" then return false,"MissingCallback" end
 local thread=coroutine.create(callback)
 local result=table.pack(coroutine.resume(thread,...))
 if coroutine.status(thread)~="dead" then
  if task and task.cancel then pcall(task.cancel,thread) end
  pcall(coroutine.close,thread)
  return false,"CallbackYielded"
 end
 if not result[1] then return false,tostring(result[2]) end
 return true,table.unpack(result,2,result.n)
end
function Callbacks.Runtime(core)
 return setmetatable({State="Active"},{
  __index=core,
  __newindex=function(t,key,value)
   assert(core[key]==nil,"ReadOnlyAbilityContext: "..tostring(key));rawset(t,key,value)
  end,
  __metatable="AbilityRuntime",
 })
end
return table.freeze(Callbacks)
