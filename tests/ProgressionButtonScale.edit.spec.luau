-- Exercises the native script against real UI classes in Edit, no clicks/Play.
assert(not game:GetService('RunService'):IsRunning(),'Edit required')
local module=Instance.new('ModuleScript')
module.Source='return function(script)\n'..game.StarterGui.ProgressionHUD.OpenButton.UIScale.LocalScript.Source..'\nreturn "Bound" end'
local instances={module}
local ok,result=pcall(function()
 local run=require(module)
 for _,class in ipairs({'TextLabel','ImageLabel','TextButton','ImageButton'})do
  local target=Instance.new(class);table.insert(instances,target)
  local scale=Instance.new('UIScale');scale.Parent=target
  local scriptObject=Instance.new('LocalScript');scriptObject.Parent=scale
  if target:IsA('GuiButton')then for _,name in ipairs({'Click','Hover'})do local sound=Instance.new('Sound');sound.Name=name;sound.Parent=scale end end
  local value=run(scriptObject)
  assert(value==(target:IsA('GuiButton')and 'Bound'or nil),'Unexpected input binding for '..class)
 end
 return 'PASS: 4 UI type assertions; decorative labels skipped; buttons bind successfully; no Play'
end)
for _,o in ipairs(instances)do o:Destroy()end
assert(ok,result);return result
