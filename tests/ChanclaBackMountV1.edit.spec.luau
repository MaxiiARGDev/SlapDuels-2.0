assert(not game:GetService('RunService'):IsRunning(),'Edit only')
local module=game.ServerScriptService.Services.BackSlapService:Clone();module.Name='__ChanclaMountAudit';module.Parent=game.ServerScriptService
local rig=Instance.new('Model');local torso=Instance.new('Part');torso.Name='Torso';torso.CFrame=CFrame.new(0,5,0);torso.Parent=rig
local anchor=game.StarterPlayer.StarterCharacter.Torso.slap_here:Clone();anchor.Parent=torso
local assertions=0
local function check(v,m)assert(v,m);assertions+=1 end
local ok,result=xpcall(function()
 local service=require(module)
 local tools={game.ServerStorage.Slaps.Slap_Chancla}
 for _,tool in ipairs(game.ServerStorage.SlapVariations.Chancla:GetChildren())do if tool:IsA('Tool')then table.insert(tools,tool)end end
 check(#tools==13,'Base and all twelve variations')
 for _,tool in ipairs(tools)do
  local hand=tool.Hand;local mounts=0
  for _,o in ipairs(hand:GetChildren())do if o.Name=='SlapBackAttachment'then mounts+=1 end end
  check(mounts==1,'Exactly one back attachment')
  check(hand.SlapBackAttachment.CFrame==CFrame.Angles(math.pi/2,0,0),'Consistent mount')
  local cf=hand.CFrame;local grip=tool.Grip;local size=hand.Size
  local clone=service.Build(tool,anchor,{RewardId='Chancla:'..tool.Name,SlapId='Chancla',VariationId=tool.Name})
  check(clone~=nil,'Full clone created')
  local displayed=clone.Hand
  check(displayed.CFrame.ZVector:Dot(anchor.WorldCFrame.UpVector)>.999,'Long axis follows back vertical')
  check(math.abs(displayed.CFrame.UpVector:Dot(anchor.WorldCFrame.LookVector))>.999,'Flat face follows back plane')
  check((displayed.SlapBackAttachment.WorldPosition-anchor.WorldPosition).Magnitude<.001,'Mount position aligns')
  check(hand.CFrame==cf and hand.Size==size and tool.Grip==grip,'Original geometry and grip unchanged')
  clone:Destroy()
 end
 check(not game.ServerStorage.Slaps.Classic.Hand:FindFirstChild('SlapBackAttachment'),'Classic untouched')
 check(not game.ServerStorage.Slaps.Slap_PingPong.Hand:FindFirstChild('SlapBackAttachment'),'PingPong untouched')
 return {Assertions=assertions,Tools=#tools,Mode='Edit isolated'}
end,debug.traceback)
rig:Destroy();module:Destroy();if not ok then error(result)end;return result
