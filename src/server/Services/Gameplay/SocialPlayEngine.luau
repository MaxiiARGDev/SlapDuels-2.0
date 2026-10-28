--!nonstrict
-- Disposable server state. No remotes, persistence or client-supplied rosters.
local Engine={};Engine.__index=Engine
function Engine.new(config,deps)
 return setmetatable({C=config,D=deps,Groups={},Membership={},Pending={},Busy={},LastInvite={},Grants={}},Engine)
end
function Engine:Group(id)return self.Groups[self.Membership[id]]end
function Engine:GroupView(id)
 local g=self:Group(id);if not g then return nil end
 local members={};for _,v in ipairs(g.Members)do table.insert(members,{UserId=v,DisplayName=self.D.Name(v)})end
 return {Id=g.Id,Leader=g.Leader,Members=members,Revision=g.Revision}
end
function Engine:_publish(g)
 for _,id in ipairs(g.Members)do self.Membership[id]=g.Id;self.D.GroupChanged(id,g.Id);self.D.Emit(id,'Group',self:GroupView(id))end
end
function Engine:_finish(request,reason)
 if self.Pending[request.Id]~=request then return end
 self.Pending[request.Id]=nil
 for _,id in ipairs({request.From,request.To})do
  if self.Busy[id]==request.Id then self.Busy[id]=nil end
  self.D.Emit(id,'RequestClosed',{Id=request.Id,Reason=reason})
 end
end
function Engine:_available(id)
 return self.D.Eligible(id) and not self.Busy[id]
end
function Engine:_groupFree(g)
 for _,id in ipairs(g.Members)do if not self.D.Eligible(id)then return false end end
 return true
end
function Engine:CanChallenge(a,b)
 return a~=b and not self:Group(a)and not self:Group(b)and self:_available(a)and self:_available(b)
end
function Engine:Invite(from,to,kind)
 if kind~='Duel'and kind~='Group'then return false,'InvalidKind'end
 if from==to or not self:_available(from)or not self:_available(to)then return false,'PlayerUnavailable'end
 if kind=='Duel'and not self.D.Near(from,to)then return false,'OutOfRange'end
 local group=self:Group(from)
 if kind=='Duel'then
  if group or self:Group(to)then return false,'InGroup'end
 else
  if self:Group(to)then return false,'AlreadyGrouped'end
  if group and (group.Leader~=from or #group.Members>=self.C.MaxGroupSize or not self:_groupFree(group))then return false,'GroupUnavailable'end
 end
 local now=self.D.Clock()
 if now-(self.LastInvite[from]or -math.huge)<self.C.InviteCooldown then return false,'InviteCooldown'end
 local req={Id=self.D.Id(),Kind=kind,From=from,To=to,ExpiresAt=now+self.C.RequestLifetime,GroupId=group and group.Id,Revision=group and group.Revision}
 self.LastInvite[from]=now;self.Pending[req.Id]=req;self.Busy[from]=req.Id;self.Busy[to]=req.Id
 for _,id in ipairs({from,to})do self.D.Emit(id,'Request',{Id=req.Id,Kind=kind,From=from,To=to,FromName=self.D.Name(from),ToName=self.D.Name(to),ExpiresAt=req.ExpiresAt})end
 return true,req.Id
end
function Engine:Respond(id,key,accept)
 local req=self.Pending[key]
 if not req or req.To~=id or type(accept)~='boolean'then return false,'InvalidRequest'end
 if self.D.Clock()>=req.ExpiresAt then self:_finish(req,'Expired');return false,'Expired'end
 if not accept then self:_finish(req,'Declined');return true end
 if not self.D.Eligible(req.From)or not self.D.Eligible(req.To)then self:_finish(req,'PlayerUnavailable');return false,'PlayerUnavailable'end
 if req.Kind=='Duel'then
  if self:Group(req.From)or self:Group(req.To)then self:_finish(req,'InGroup');return false,'InGroup'end
  local grant={ZoneId='Duel:'..req.Id,Token=self.D.Id(),A=req.From,B=req.To,ExpiresAt=self.D.Clock()+self.C.DuelReservationLifetime,Consumed=false}
  self:_finish(req,'Accepted');self.Grants[grant.ZoneId]=grant
  local ok,started,why=pcall(self.D.StartDuel,grant)
  if not ok or not started then
   self.Grants[grant.ZoneId]=nil
   for _,uid in ipairs({grant.A,grant.B})do self.D.Emit(uid,'Notice',{Reason=ok and why or 'DuelStartFailed'})end
   return false,ok and why or 'DuelStartFailed'
  end
 else
  local group=self:Group(req.From)
  if self:Group(req.To)or (group and (group.Leader~=req.From or group.Id~=req.GroupId or group.Revision~=req.Revision or #group.Members>=self.C.MaxGroupSize or not self:_groupFree(group)))or (not group and req.GroupId)then
   self:_finish(req,'GroupChanged');return false,'GroupChanged'
  end
  if not group then group={Id=self.D.Id(),Leader=req.From,Members={req.From},Revision=0};self.Groups[group.Id]=group end
  self:_finish(req,'Accepted');table.insert(group.Members,req.To);group.Revision+=1;self:_publish(group)
 end
 return true
end
function Engine:Leave(id,disband,force)
 local group=self:Group(id);if not group then return false,'NotGrouped'end
 if not force and not self:_groupFree(group)then return false,'GroupBusy'end
 if disband and group.Leader~=id then return false,'NotLeader'end
 local old=table.clone(group.Members)
 if disband then table.clear(group.Members)else table.remove(group.Members,table.find(group.Members,id))end
 self.Membership[id]=nil;self.D.GroupChanged(id,nil);self.D.Emit(id,'Group',nil)
 if #group.Members<2 then
  self.Groups[group.Id]=nil
  for _,member in ipairs(old)do self.Membership[member]=nil;self.D.GroupChanged(member,nil);self.D.Emit(member,'Group',nil)end
 else
  if group.Leader==id then group.Leader=group.Members[1]end
  group.Revision+=1;self:_publish(group)
 end
 return true
end
function Engine:CanQueueTeam(players,teamSize)
 local present={};for _,p in ipairs(players)do present[p.UserId]=true end
 for _,p in ipairs(players)do local g=self:Group(p.UserId)
  if g then
   if #g.Members>teamSize then return false,'GroupTooLarge'end
   for _,id in ipairs(g.Members)do if not present[id]then return false,'IncompleteGroup'end end
  end
 end
 return true
end
function Engine:Tick()
 for _,req in pairs(self.Pending)do
  if self.D.Clock()>=req.ExpiresAt or not self.D.Eligible(req.From)or not self.D.Eligible(req.To)then self:_finish(req,'ExpiredOrUnavailable')end
 end
 for zone,g in pairs(self.Grants)do if self.D.Clock()>=g.ExpiresAt then self.Grants[zone]=nil end end
end
function Engine:Disconnect(id)
 local req=self.Pending[self.Busy[id]];if req then self:_finish(req,'Disconnected')end
 self:Leave(id,false,true);self.LastInvite[id]=nil
 for zone,g in pairs(self.Grants)do if g.A==id or g.B==id then self.Grants[zone]=nil end end
end
return Engine
