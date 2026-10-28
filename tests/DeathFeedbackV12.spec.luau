--!nonstrict
-- PREPARED ONLY. Developer-run isolated policy tests; no characters, remotes, forces or profiles.
return function()
 local Policy=require(game.ReplicatedStorage.Shared.ArenaRespawnPolicy)
 local Lifecycle=require(game.ServerScriptService.Services.Respawn.ArenaRespawn)
 local Config=require(game.ReplicatedStorage.Shared.Config)
 local count=0
 local function expect(value,message)count+=1;assert(value,message)end
 expect(Config.Respawn.KillPartDelayMs==500,"Default KillPart delay is milliseconds")
 expect(Policy.IsContactCurrent(CFrame.new(),Vector3.new(30,5,30),Vector3.new(0,3,0),Vector3.new(2,2,1)),
  "A9 current limb near the sensor accepted")
 expect(not Policy.IsContactCurrent(CFrame.new(),Vector3.new(30,5,30),Vector3.new(0,40,0),Vector3.new(2,2,1)),
  "A9 old queued Touched cannot eliminate an already teleported Character")
 for _,value in ipairs({0,250,500,1000}) do
  local ms,valid=Policy.NormalizeDelayMs(value,Config.Respawn.MaxKillPartDelayMs)
  expect(valid and ms==value,"Allowed delay "..value)
 end
 for _,value in ipairs({false,"500",-1,math.huge}) do
  local ms,valid=Policy.NormalizeDelayMs(value,Config.Respawn.MaxKillPartDelayMs)
  expect(not valid and ms==0,"Explicit invalid-value normalization")
 end
 local nan,valid=Policy.NormalizeDelayMs(0/0,10000)
 expect(nan==0 and not valid,"NaN rejected")
 local capped,unchanged=Policy.NormalizeDelayMs(20000,10000)
 expect(capped==10000 and not unchanged,"Maximum is enforced explicitly")
 local character={}
 local session={State="Playing",StateVersion=7}
 local record={Session=session,Character=character,StateVersion=7,Generation=3}
 expect(Policy.IsCurrent(record,session,character,3),"Valid individual respawn")
 expect(not Policy.IsCurrent(record,session,{},3),"A10 old operation cannot affect new Character")
 expect(not Policy.IsCurrent(record,session,character,4),"A10 generation mismatch rejected")
 expect(not Policy.IsCurrent(record,{},character,3),"Different session object rejected")
 expect(not Policy.IsCurrent(record,nil,character,3),"Missing session rejected")
 for _,state in ipairs({"Ending","ReturningToLobby","StartCountdown","PointRestartCountdown"}) do
  session.State=state
  expect(not Policy.IsCurrent(record,session,character,3),"A11 non-Playing cancels: "..state)
 end
 session.State="Playing"
 for _,flag in ipairs({"Closing","Cancelled","Closed","GameplayFrozen","PointInProgress"}) do
  session[flag]=true
  expect(not Policy.IsCurrent(record,session,character,3),"A11/A12 invalidation: "..flag)
  session[flag]=nil
 end
 session.StateVersion=8
 expect(not Policy.IsCurrent(record,session,character,3),"A12 obsolete point version")
 local owner=Lifecycle.new({})
 local player={}
 local disconnected=0
 owner.Pending[player]={Connection={Disconnect=function()disconnected+=1 end}}
 expect(not owner:Begin(player,session,"duplicate"),"A9 existing pending operation rejects another Begin")
 local taken=owner:Take(player)
 expect(taken~=nil and owner.Pending[player]==nil and disconnected==1,"A9 pending ownership consumed once")
 expect(owner:Take(player)==nil and disconnected==1,"A9 idempotent take")
 -- CharacterRemoving cancellation restores only the captured old object, never the replacement.
 owner.Pending[player]={Character={Parent=nil},Session={Id="old"},EliminationId="old"}
 player.Character={PivotTo=function()error("Must not teleport replacement Character")end}
 owner:Cancel(player,"CharacterReplaced",false)
 expect(owner.Pending[player]==nil,"A10/A13 old Character cleanup cannot touch new Character")
 print("[DeathFeedbackV12.spec] isolated policy assertions:",count)
 return count
end
