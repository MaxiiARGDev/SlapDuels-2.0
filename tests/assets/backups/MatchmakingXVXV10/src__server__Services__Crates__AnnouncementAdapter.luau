--!nonstrict
-- Local TextChat bridge only. Optional global transport contract is inert until a later authorised phase.
local Adapter={};Adapter.__index=Adapter
function Adapter.new(sendLocal,globalProvider)
 return setmetatable({SendLocal=sendLocal,GlobalProvider=globalProvider,GlobalEnabled=false,Seen={}},Adapter)
end
function Adapter:AnnounceOnce(id,packet)
 if self.Seen[id]then return false,"AlreadyAnnounced"end
 self.Seen[id]=true
 local ok=pcall(self.SendLocal,packet)
 return ok,if ok then nil else "DeliveryUnknown"
end
function Adapter:PublishGlobal(_id,_packet)
 -- No MessagingService lookup, no cross-server writes or hidden activation switch in V1.
 return false,"GlobalAnnouncementsRequireAuthorisedBackend"
end
return Adapter
