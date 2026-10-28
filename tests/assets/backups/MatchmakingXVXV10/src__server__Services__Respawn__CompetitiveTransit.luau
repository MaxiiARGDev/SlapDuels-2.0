--!strict
-- One authoritative outcome per exact Character generation, scoped to session and UserId.
-- Pure registry: no timers, rewards, physics, replication or gameplay side effects.
local Transit = {}
Transit.__index = Transit
function Transit.new()
 return setmetatable({_sessions = {} :: {[string]: {[number]: any}}},Transit)
end
function Transit:Get(session: any, player: any, character: any, generation: any): any?
 local entries = self._sessions[session.Id]
 local record = entries and entries[player.UserId]
 if not record then return nil end
 -- The existing point teleport advances the physics generation on the SAME Character.
 -- Keep that goal protected through its countdown; ResumeScoring explicitly releases it.
 local pointHandoff = record.Kind=="Goal" and session.PointInProgress==true
 if record.Session ~= session or record.Player ~= player or record.Character ~= character
  or (record.Generation ~= generation and not pointHandoff) then
  entries[player.UserId] = nil
  if next(entries)==nil then self._sessions[session.Id]=nil end
  return nil
 end
 return record
end
function Transit:Claim(session: any, player: any, character: any, generation: any, kind: string, eventId: string): boolean
 if self:Get(session,player,character,generation) then return false end
 local entries = self._sessions[session.Id]
 if not entries then entries={};self._sessions[session.Id]=entries end
 entries[player.UserId]={Session=session,SessionId=session.Id,Player=player,UserId=player.UserId,
  Character=character,Generation=generation,Kind=kind,EventId=eventId}
 return true
end
function Transit:ForgetPlayer(sessionId: string, player: any)
 local entries=self._sessions[sessionId]
 local record=entries and entries[player.UserId]
 if record and record.Player==player then entries[player.UserId]=nil end
 if entries and next(entries)==nil then self._sessions[sessionId]=nil end
end
function Transit:ReleaseGoals(sessionId: string)
 local entries=self._sessions[sessionId]
 if not entries then return end
 for id,record in pairs(entries) do if record.Kind=="Goal" then entries[id]=nil end end
 if next(entries)==nil then self._sessions[sessionId]=nil end
end
function Transit:ClearSession(sessionId: string)
 self._sessions[sessionId]=nil
end
return Transit
