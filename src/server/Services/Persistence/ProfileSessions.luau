--!nonstrict
-- One fenced writer per profile. Injected provider only; no DataStoreService lookup.
local Http=game:GetService('HttpService')
local Profiles={};Profiles.__index=Profiles
function Profiles.Copy(value,seen,depth)
 if type(value)~='table'then
  assert(type(value)=='nil'or type(value)=='string'or type(value)=='boolean'or(type(value)=='number'and value==value and math.abs(value)<math.huge),'Non-serializable profile value')
  return value
 end
 seen=seen or {};depth=depth or 0;assert(depth<40 and not seen[value],'Invalid profile graph');seen[value]=true
 local result={};for k,v in pairs(value)do assert(type(k)=='string'or(type(k)=='number'and k%1==0),'Invalid profile key');result[k]=Profiles.Copy(v,seen,depth+1)end
 seen[value]=nil;return result
end
function Profiles.Acquire(old,id,now,ttl,normalize)
 if old~=nil and type(old)~='table'then return nil,'CorruptedProfile'end
 if old and old._PremiumProfile~=nil then return nil,'FencedProfileLifecycleRequired'end
 local lease=old and old._Session
 if lease~=nil and(type(lease)~='table'or type(lease.Id)~='string'or type(lease.Until)~='number'or lease.Until~=lease.Until)then return nil,'InvalidSessionLease'end
 if lease and lease.Id~=id and lease.Until>now then return nil,'ProfileInUse'end
 local valid,data,reason=normalize(old);if not valid then return nil,reason or 'InvalidProfile'end
 local row=Profiles.Copy(old or {})
 for k,v in pairs(data)do row[k]=Profiles.Copy(v)end
 row._Session={Id=id,Until=now+ttl};return row
end
function Profiles.Write(old,request,id,now,ttl)
 if type(old)~='table'then return nil,'ProfileMissing'end
 if old._PremiumProfile~=nil then return nil,'FencedProfileLifecycleRequired'end
 if old._LastProfileWrite and old._LastProfileWrite.Id==request.Id then return Profiles.Copy(old),'Replay'end
 local lease=old._Session
 if not lease or lease.Id~=id or lease.Until<=now then return nil,'SessionLost'end
 if type(old.Version)=='number'and old.Version>(request.Data.Version or 0)then return nil,'IncompatibleVersion'end
 local row=Profiles.Copy(old)
 for k,v in pairs(request.Data)do row[k]=Profiles.Copy(v)end
 row._LastProfileWrite={Id=request.Id,Session=id}
 row._Session=not request.Release and {Id=id,Until=now+ttl}or nil
 row.LastSaved=now;return row
end
function Profiles.new(store,normalize,latest,options)
 options=options or {}
 return setmetatable({Store=store,Normalize=normalize,Latest=latest,Handles={},TTL=options.TTL or 180,Clock=options.Clock or os.time,Wait=options.Wait or task.wait,Retries=options.Retries or 3,NewId=options.NewId or function()return Http:GenerateGUID(false)end},Profiles)
end
function Profiles:Load(player)
 if self.Handles[player]then return false,nil,'AlreadyLoaded'end
 local id=self.NewId();local key='Player_'..tostring(player.UserId);local last
 for attempt=1,self.Retries do
  local reason;local now=self.Clock()
  local ok,row=pcall(self.Store.UpdateAsync,self.Store,key,function(old)local nextData,why=Profiles.Acquire(old,id,now,self.TTL,self.Normalize);reason=why;return nextData end)
  if ok and row and row._Session and row._Session.Id==id then
   local valid,data,why=self.Normalize(row);if not valid then return false,nil,why end
   self.Handles[player]={Id=id,Key=key,Until=row._Session.Until,Data=data};return true,data
  end
  last=ok and reason or tostring(row)
  if reason and reason~='ProfileInUse'then break end
  if attempt<self.Retries then self.Wait(attempt*2)end
 end
 return false,nil,last or 'LoadUnconfirmed'
end
function Profiles:Owns(player)
 local h=self.Handles[player];return h~=nil and not h.Released and not h.Lost and h.Until>self.Clock()
end
function Profiles:_write(player,h)
 local request=h.Pending;local last
 for attempt=1,self.Retries do
  local reason;local now=self.Clock()
  local ok,row=pcall(self.Store.UpdateAsync,self.Store,h.Key,function(old)local nextData,why=Profiles.Write(old,request,h.Id,now,self.TTL);reason=why;return nextData end)
  if ok and row and row._LastProfileWrite and row._LastProfileWrite.Id==request.Id then
   if not request.Release and(not row._Session or row._Session.Id~=h.Id)then h.Lost=true;h.Pending=nil;return false,'SessionLost'end
   h.Pending=nil;h.Released=request.Release;h.Until=row._Session and row._Session.Until or 0;return true
  end
  last=ok and reason or tostring(row)
  if reason=='SessionLost'or reason=='IncompatibleVersion'or reason=='FencedProfileLifecycleRequired'then h.Lost=true;return false,reason end
  if attempt<self.Retries then self.Wait(attempt)end
 end
 return false,last or 'WriteUnconfirmed'
end
function Profiles:Save(player,fallback,release)
 local h=self.Handles[player];if not h then return false,'ProfileNotOwned'end
 local waited=0;while h.Busy and waited<20 do self.Wait(.05);waited+=.05 end
 if h.Busy then return false,'SaveBusy'end
 if h.Released then return release==true,release and nil or 'ProfileReleased'end
 h.Busy=true
 local ok,saved,reason=pcall(function()
  if h.Pending then local done,why=self:_write(player,h);if not done then return false,why end;if h.Released then return release==true,'ProfileReleased'end end
  if not self:Owns(player)then h.Lost=true;return false,'SessionLost'end
  -- Capture AFTER acquiring the write queue, never before a previous yielding save.
  local data=self.Latest(player)or fallback or h.Data
  local valid,payload,why=self.Normalize(data);if not valid then return false,why end
  h.Data=Profiles.Copy(payload)
  assert(#Http:JSONEncode(h.Data)<3500000,'ProfileTooLarge')
  h.Pending={Id=self.NewId(),Data=h.Data,Release=release==true}
  return self:_write(player,h)
 end)
 h.Busy=false
 if not ok then return false,tostring(saved)end
 return saved,reason
end
function Profiles:Cleanup(player)
 local h=self.Handles[player];if not h then return end
 if h.Released then self.Handles[player]=nil;return end
 -- Keep uncertain final writes and their exact operation IDs alive after disconnect.
 task.spawn(function()
  for _=1,3 do local done=self:Save(player,h.Data,true);if done or h.Lost then break end;self.Wait(2)end
  if h.Released or h.Lost then self.Handles[player]=nil end
 end)
end
return Profiles
