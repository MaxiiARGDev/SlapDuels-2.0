--!nonstrict
-- No yielding or inventory writes. Transport/clock/player state are injected for deterministic tests.
local Engine={};Engine.__index=Engine
local function copy(x)if type(x)~='table'then return x end;local y={};for k,v in pairs(x)do y[k]=copy(v)end;return y end
function Engine.new(config,deps)return setmetatable({C=config,D=deps,Trades={},Busy={},Reserved={},Cooldown={}},Engine)end
function Engine:_pair(a,b,near)
 if a==b then return false,'SelfTarget' end
 if not self.D.Eligible(a)or not self.D.Eligible(b)then return false,'PlayerUnavailable' end
 if near then local distance=self.D.Distance(a,b);if type(distance)~='number'or not(distance<=self.C.InspectDistance)or distance<0 then return false,'OutOfRange'end end
 return true
end
function Engine:_publish(t)
 t.Sequence=(t.Sequence or 0)+1
 local function keys(values)local out={};for k,v in pairs(values)do out[tostring(k)]=copy(v)end;return out end
 local packet={TradeId=t.Id,State=t.State,Revision=t.Revision,A=t.A,B=t.B,
  Sequence=t.Sequence,Names={[tostring(t.A)]=self.D.Name(t.A),[tostring(t.B)]=self.D.Name(t.B)},Offers=keys(t.Offers),Accepted=keys(t.Accepted),Confirmed=keys(t.Confirmed),
  Deadline=t.Deadline,ExpiresAt=t.ExpiresAt,Reason=t.Reason,TradeCommitEnabled=false}
 self.D.Emit(t.A,'Trade',packet);self.D.Emit(t.B,'Trade',packet)
end
function Engine:_release(t)
 for _,uid in ipairs({t.A,t.B})do
  if self.Busy[uid]==t.Id then self.Busy[uid]=nil end
  for key,owner in pairs(self.Reserved)do if owner==t.Id then self.Reserved[key]=nil end end
 end
end
function Engine:_cancel(t,why)
 if t.Terminal or t.State=='Committing'then return false,'CannotCancel' end
 t.State='Cancelled';t.Reason=why;t.Terminal=true;t.FinishedAt=self.D.Clock();self:_release(t);self:_publish(t);return true
end
function Engine:Invite(a,b)
 local ok,why=self:_pair(a,b,true);if not ok then return false,why end
 if self.C.TradeInvitationsEnabled~=true then return false,'InvitationsDisabled' end
 if self.Busy[a]or self.Busy[b]then return false,'PlayerBusy' end
 local now=self.D.Clock();if (self.Cooldown[a]or 0)>now then return false,'InviteCooldown' end
 local id=self.D.Id();local t={Id=id,A=a,B=b,State='Requested',Revision=0,Offers={[a]={},[b]={}},Accepted={},Confirmed={},
  CreatedAt=now,ExpiresAt=now+self.C.InviteTimeoutSeconds,MaxUntil=now+self.C.MaxTradeSeconds}
 self.Cooldown[a]=now+self.C.InviteCooldownSeconds;self.Trades[id]=t;self.Busy[a]=id;self.Busy[b]=id
 self:_publish(t);return true,id
end
function Engine:_validateOffers(t)
 for _,uid in ipairs({t.A,t.B})do for _,row in ipairs(t.Offers[uid])do
  local current=self.D.Unit(uid,row.UnitId)
  if not current or not current.Tradable or current.RewardId~=row.RewardId or current.VariationId~=row.VariationId
   or self.Reserved[tostring(uid)..':'..row.UnitId]~=t.Id then return false,'OfferChangedOrUnavailable' end
 end end
 return true
end
function Engine:Act(uid,action,id,revision,item)
 local t=self.Trades[id]
 if not t or uid~=t.A and uid~=t.B then return false,'NotParticipant' end
 if t.Terminal then return false,'TradeClosed' end
 local valid,why=self:_pair(t.A,t.B,false);if not valid then self:_cancel(t,why);return false,why end
 local now=self.D.Clock()
 if now>=t.MaxUntil or t.State=='Requested'and now>=t.ExpiresAt then self:_cancel(t,'Expired');return false,'Expired' end
 if revision~=t.Revision then return false,'StaleRevision' end
 if action=='Cancel'then return self:_cancel(t,'CancelledByPlayer')end
 if action=='Respond'then
  if t.State~='Requested'or uid~=t.B then return false,'InvalidAcceptance' end
  if item~=true then return self:_cancel(t,'InvitationDeclined')end
  local near,err=self:_pair(t.A,t.B,true);if not near then self:_cancel(t,err);return false,err end
  t.State='Negotiating';self:_publish(t);return true
 end
 if action=='Add'or action=='Remove'then
  if t.State~='Negotiating'then return false,'OffersLocked' end
  if type(item)~='string'or #item>256 then return false,'InvalidUnitId' end
  local rows=t.Offers[uid];local at
  for i,row in ipairs(rows)do if row.UnitId==item then at=i end end
  local key=tostring(uid)..':'..item
  if action=='Add'then
   if at then return false,'DuplicateUnit' end
   if #rows>=self.C.MaxSlapsPerSide then return false,'OfferFull' end
   local row=self.D.Unit(uid,item)
   if not row or not row.Tradable then return false,'ItemNotTradable' end
   if self.Reserved[key]and self.Reserved[key]~=id then return false,'UnitReserved' end
   self.Reserved[key]=id;table.insert(rows,copy(row))
  else
   if not at then return false,'NotOffered' end
   table.remove(rows,at);self.Reserved[key]=nil
  end
  t.Revision+=1;t.Accepted={};t.Confirmed={};t.Deadline=nil
 elseif action=='Accept'then
  if t.State~='Negotiating'then return false,'InvalidState' end
  local ok,err=self:_validateOffers(t);if not ok then self:_cancel(t,err);return false,err end
  if #t.Offers[t.A]+#t.Offers[t.B]==0 then return false,'EmptyTrade' end
  t.Accepted[uid]=true
  if t.Accepted[t.A]and t.Accepted[t.B]then t.State='SafetyCountdown';t.Deadline=now+self.C.SafetyCountdownSeconds end
 elseif action=='Confirm'then
  if t.State~='FinalConfirmation'or not t.Deadline or now<t.Deadline then return false,'FinalConfirmationNotReady' end
  local ok,err=self:_validateOffers(t);if not ok then self:_cancel(t,err);return false,err end
  t.Confirmed[uid]=true
  if t.Confirmed[t.A]and t.Confirmed[t.B]then
   -- Never display Completed for a simulation and never manufacture a durable journal.
   t.BothConfirmations=true
   local committed,reason=self.D.Commit({TradeId=t.Id,Revision=t.Revision,A=t.A,B=t.B,Offers=copy(t.Offers)})
   assert(not committed,'Real transfers are not installed in V1.0')
   return self:_cancel(t,reason or 'TradeCommitDisabled')
  end
 else return false,'UnknownAction' end
 self:_publish(t);return true
end
function Engine:Tick()
 local now=self.D.Clock()
 for id,t in pairs(self.Trades)do
  if t.Terminal then if now-t.FinishedAt>=self.C.TerminalRetentionSeconds then self.Trades[id]=nil end
  elseif not self.D.Eligible(t.A)or not self.D.Eligible(t.B)then self:_cancel(t,'PlayerUnavailable')
  elseif now>=t.MaxUntil or t.State=='Requested'and now>=t.ExpiresAt then self:_cancel(t,'Expired')
  elseif t.State=='SafetyCountdown'and now>=t.Deadline then
   local ok,why=self:_validateOffers(t);if not ok then self:_cancel(t,why)else t.State='FinalConfirmation';self:_publish(t)end
  end
 end
end
function Engine:CancelForPlayer(uid)
 local t=self.Trades[self.Busy[uid]];if t then self:_cancel(t,'PlayerUnavailable')end
end
function Engine:Disconnect(uid)
 self:CancelForPlayer(uid);self.Cooldown[uid]=nil
end
return Engine
