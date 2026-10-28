--!nonstrict
-- Real UpdateAsync profile transactions on the EXISTING Player_<id> key, never a second wallet/store.
-- Integration with the legacy runtime lifecycle is separately gated by DurableReceiptBackend.
local Grant=require(script.Parent.PremiumGrantPlan)
local Store={};Store.__index=Store
local function copy(v)if type(v)~="table"then return v end;local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t end
local function integer(n)return type(n)=="number"and n==n and n>=0 and n<9007199254740992 and n%1==0 end
function Store.new(adapter,options)
 options=options or {}
 assert(adapter and type(adapter.UpdateAsync)=="function","Profile adapter required")
 return setmetatable({Adapter=adapter,Clock=options.Clock or os.time,Lease=options.LeaseSeconds or 120,Version=options.ProfileVersion or 2},Store)
end
function Store:_update(uid,transform)
 if not integer(uid)or uid==0 then return nil,"InvalidPlayerId"end
 local reason
 local ok,value=pcall(self.Adapter.UpdateAsync,self.Adapter,"Player_"..uid,function(old)
  if type(old)=="table"and ((old.Version or 0)>self.Version or old._PremiumProfile and old._PremiumProfile.Schema~=1)then reason="UnsupportedProfileVersion";return nil end
  local nextValue,why=transform(old);reason=why;return nextValue
 end)
 if not ok then return nil,"PersistenceTemporaryError"end
 if reason then return nil,reason end
 if type(value)~="table"then return nil,"TransactionNotConfirmed"end
 return value
end
function Store:Acquire(uid,token,defaultRecord)
 if type(token)~="string"or #token==0 then return nil,"InvalidSessionToken"end
 local record,why=self:_update(uid,function(old)
  local data=copy(old or defaultRecord);if type(data)~="table"then return nil,"ProfileMissing"end
  local meta=data._PremiumProfile or {Schema=1,Revision=0}
  local owner=meta.Session
  if owner and owner.Token~=token and owner.Until>self.Clock()then return nil,"ProfileOwnedElsewhere"end
  if not owner or owner.Token~=token then meta.Revision+=1 end
  meta.Session={Token=token,Until=self.Clock()+self.Lease};data._PremiumProfile=meta;return data
 end)
 if not record then return nil,why end
 return {UserId=uid,Token=token,Revision=record._PremiumProfile.Revision,Record=copy(record)}
end
local function owned(self,data,handle)
 local meta=data and data._PremiumProfile;local s=meta and meta.Session
 if not s or s.Token~=handle.Token or s.Until<=self.Clock()then return false,"ProfileLeaseLost"end
 if meta.Revision~=handle.Revision then return false,"StaleProfileRevision"end
 return true
end
local function adopt(handle,record)handle.Revision=record._PremiumProfile.Revision;handle.Record=copy(record)end
function Store:Save(handle,snapshot,commitId,release)
 if type(commitId)~="string"or commitId==""or not integer(snapshot.Coins)then return nil,"InvalidSave"end
 local record,why=self:_update(handle.UserId,function(old)
  if old and old._PremiumProfile and old._PremiumProfile.LastCommitId==commitId and old._PremiumProfile.LastCommitToken==handle.Token then return old end
  local ok,err=owned(self,old,handle);if not ok then return nil,err end
  local prior=old.Inventory and old.Inventory.PremiumReceipts or {}
  local nextReceipts=snapshot.Inventory and snapshot.Inventory.PremiumReceipts or {}
  for id,r in pairs(prior)do
   local n=nextReceipts[id]
   if not n or n.PlayerId~=r.PlayerId or n.ProductId~=r.ProductId or n.State~=r.State or n.ContractVersion~=r.ContractVersion then return nil,"ReceiptJournalWouldRegress"end
  end
  local nextData=copy(old)
  for _,k in ipairs({"Coins","Wins","Losses","Kills","Inventory"})do nextData[k]=copy(snapshot[k])end
  local meta=nextData._PremiumProfile;meta.Revision+=1;meta.LastCommitId=commitId;meta.LastCommitToken=handle.Token
  meta.Session=if release then nil else {Token=handle.Token,Until=self.Clock()+self.Lease}
  nextData.LastSaved=self.Clock();return nextData
 end)
 if record then adopt(handle,record)end;return record,why
end
function Store:ApplyReceipt(handle,receipt,product)
 local replay=false
 local record,why=self:_update(receipt.PlayerId,function(old)
  replay=false
  local prior=old and old.Inventory and old.Inventory.PremiumReceipts and old.Inventory.PremiumReceipts[receipt.PurchaseId]
  if prior then
   if prior.PlayerId~=receipt.PlayerId or prior.ProductId~=receipt.ProductId or prior.State~="Applied"then return nil,"ReceiptIdentityConflict"end
   replay=true;return old
  end
  if not handle or handle.UserId~=receipt.PlayerId then return nil,"ProfileSessionRequired"end
  local ok,err=owned(self,old,handle);if not ok then return nil,err end
  local nextData,reason=Grant.Stage(old,product,receipt,true);if not nextData then return nil,reason end
  local entry=nextData.Inventory.PremiumReceipts[receipt.PurchaseId]
  entry.State="Applied";entry.ProductKey=product.Id;entry.Rewards=copy(product.Rewards);entry.AppliedAt=self.Clock()
  nextData._PremiumProfile=copy(old._PremiumProfile);local meta=nextData._PremiumProfile
  meta.Revision+=1;meta.LastCommitId="Receipt:"..receipt.PurchaseId;meta.Session.Until=self.Clock()+self.Lease
  return nextData
 end)
 if not record then return nil,why end
 local entry=record.Inventory and record.Inventory.PremiumReceipts and record.Inventory.PremiumReceipts[receipt.PurchaseId]
 if not entry or entry.State~="Applied"or entry.PlayerId~=receipt.PlayerId or entry.ProductId~=receipt.ProductId then return nil,"ReceiptNotConfirmed"end
 if handle and record._PremiumProfile.Session and record._PremiumProfile.Session.Token==handle.Token then adopt(handle,record)end
 return {Durable=true,Replay=replay,PurchaseId=receipt.PurchaseId,PlayerId=receipt.PlayerId,ProductId=receipt.ProductId,ProductKey=entry.ProductKey,Record=record}
end
return Store
