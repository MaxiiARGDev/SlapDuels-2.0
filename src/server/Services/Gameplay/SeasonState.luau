--!nonstrict
-- Pure compare-and-swap transform; no side effects inside UpdateAsync callbacks.
local M=require(game.ReplicatedStorage.Shared.Progression.Model)
local State={}
function State.Valid(row)
 if type(row)~='table'or not M.Integer(row.Revision)then return false end
 local s=row.Active;if s==nil then return true end
 if type(s)~='table'or type(s.Id)~='string'or #s.Id==0 or type(s.DisplayName)~='string'or not M.Integer(s.StartsAt)or not M.Integer(s.EndsAt)or s.EndsAt<s.StartsAt or not M.Integer(s.StageXP)or s.StageXP<1 or s.Stages~=30 or type(s.Rewards)~='table'then return false end
 for i=1,30 do local reward=s.Rewards[i];if type(reward)~='table'or type(reward.Label)~='string'or(reward.Kind~='Coins'and reward.Kind~='Slap'and reward.Kind~='Effect')then return false end end
 return true
end
function State.Apply(old,expected,command,definition,days,id,operation,now,actor)
 old=old or {Revision=0}
 if not State.Valid(old)then return nil,'SeasonCorrupted'end
 if old.LastOperation==operation then return old,'Replay'end
 if old.Revision~=expected then return nil,'SeasonChanged'end
 if command=='Start'and M.Active(old.Active,now)then return nil,'SeasonAlreadyActive'end
 if command~='Start'and command~='Restart'and command~='End'then return nil,'InvalidCommand'end
 local nextState=M.Copy(old);nextState.Revision+=1;nextState.LastOperation=operation;nextState.ActorUserId=actor;nextState.ChangedAt=now
 if command=='End'then
  if not M.Active(old.Active,now)then return nil,'NoActiveSeason'end
  nextState.Active.EndsAt=now
 else
  if not definition or not M.Integer(days)or days<1 or days>365 then return nil,'InvalidDuration'end
  nextState.Active={Id=id,PresetId=definition.Id,Version=definition.Version,DisplayName=definition.DisplayName,StartsAt=now,EndsAt=now+days*86400,StageXP=definition.StageXP,Stages=definition.Stages,Rewards=M.Copy(definition.Rewards),StudioOnly=definition.StudioOnly==true}
 end
 return nextState,'Applied'
end
return State
