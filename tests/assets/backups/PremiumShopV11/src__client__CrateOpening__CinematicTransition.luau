--!nonstrict
local Transition={}
function Transition.Update(hud,cover)
 -- Physical editable Frames, never a second ScreenGui.
 local top=hud:FindFirstChild("ShutterTop");local bottom=hud:FindFirstChild("ShutterBottom")
 assert(top and bottom,"Missing V2.3 Edit shutter resources")
 cover=math.clamp(cover,0,.5)
 top.Visible=cover>0;bottom.Visible=cover>0
 top.Size=UDim2.fromScale(1,cover);bottom.Size=UDim2.fromScale(1,cover)
end
function Transition.Reset(hud)
 if not hud then return end
 for _,name in ipairs({"ShutterTop","ShutterBottom"})do
  local frame=hud:FindFirstChild(name);if frame then frame.Visible=false;frame.Size=UDim2.fromScale(1,0)end
 end
end
return Transition
