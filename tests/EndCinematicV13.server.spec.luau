-- Isolated presentation tests; no Bootstrap, profiles, real players or cloud calls.
return function(services)
 local passed={}
 local function check(name, value) assert(value,name); table.insert(passed,name) end
 local zone=Instance.new("Part")
 local template=Instance.new("Model")
 local part=Instance.new("Part"); part.Parent=template
 local sound=Instance.new("Sound"); sound.Name="ExistingGoalSound"; sound.Parent=part
 local particles=Instance.new("ParticleEmitter"); particles.Parent=part
 local session={Id="V13_FINAL",State="Ending",StateVersion=15,GameplayFrozen=true,Closing=true,Result="Red",
  Results={Token="server-only",Celebrating=true}}
 local authority={GetSessionById=function() return session end,IsSessionActive=function() return false end}
 local physics,plays,destroyed=0,0,0
 local f=setmetatable({_processedPoints={},_activeMatchEffects={},_activeMatchHandles={}}, {__index=services.PointFeedbackService})
 f._getRoundService=function() return authority end
 f._validateScoringZone=function() return true end
 f._resolvePlayerEffectId=function() return "Basic" end
 f._getEffectTemplate=function() return template end
 f._getRagdollService=function() return {BlastZone=function() physics+=1 end} end
 f._getControllerRegistry=function() return {GetController=function() return {Play=function(context)
  plays+=1
  check("existing final controller receives final flag",context.IsFinalPoint)
  local copy=context.EffectModel:FindFirstChildOfClass("Part")
  check("existing sound and particles retained",copy:FindFirstChild("ExistingGoalSound") and copy:FindFirstChildOfClass("ParticleEmitter"))
  check("final cosmetic parts have no physics",copy.Anchored and not copy.CanCollide and not copy.CanTouch)
  return {IsActive=function() return true end,Destroy=function() destroyed+=1; context.EffectModel:Destroy() end}
 end} end} end
 local payload={PointId="V13_FINAL_Red_5_0",MatchId=session.Id,ScoringTeam="Red",ScoringZone=zone,IsFinalPoint=true,RedScore=5,BlueScore=0}
 check("ordinary feedback cannot bypass Ending",not f:PlayPoint(session,payload))
 check("incorrect final authorization rejected",not f:PlayPoint(session,payload,"wrong"))
 check("authorized final feedback runs",f:PlayPoint(session,payload,"server-only"))
 check("no final BlastZone",physics==0)
 check("duplicate final effect rejected",not f:PlayPoint(session,payload,"server-only") and plays==1)
 check("active feedback detected",f:HasActiveFeedback(session.Id))
 f:CleanupMatch(session.Id)
 check("final feedback cleaned",destroyed==1 and not f:HasActiveFeedback(session.Id) and #zone:GetChildren()==0)
 session.Results.Celebrating=false
 payload.PointId="late"
 check("expired final authorization rejected",not f:PlayPoint(session,payload,"server-only"))
 zone:Destroy(); template:Destroy()
 return {Passed=#passed,Assertions=passed,CloudAccess=false}
end
