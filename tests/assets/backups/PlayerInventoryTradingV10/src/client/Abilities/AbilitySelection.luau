--!nonstrict
local Catalog=require(game.ReplicatedStorage.Shared.AbilityCatalog)
local HttpService=game:GetService("HttpService")
local Selection={}
Selection.__index=Selection
function Selection.new(frame,request,isCurrentSession)
 local self=setmetatable({Frame=frame,Cards={},Connections={},Request=request,IsCurrentSession=isCurrentSession},Selection)
 frame.Visible=false
 return self
end
function Selection:_buildCards()
 local catalog=Catalog.Get()
 if self.CatalogVersion==catalog.Version then return end
 self.CatalogVersion=catalog.Version
 for _,connection in ipairs(self.Connections) do connection:Disconnect() end
 for _,card in pairs(self.Cards) do card:Destroy() end
 self.Connections={};self.Cards={}
 local template=self.Frame.Cards.AbilityCardTemplate
 for index,id in ipairs(catalog.Order) do
  local d=catalog.Items[id]
  local card=template:Clone();card.Name=id;card.LayoutOrder=index;card.Visible=true
  card.AbilityName.Text=d.DisplayName
  card.Description.Text=d.Description
  card.Cooldown.Text=string.format("CD %ds · duración %ss",d.Cooldown,if d.DurationKind=="Instant" then "instantánea" else tostring(d.Duration))
  card.Icon.Image=d.Icon;card.Icon.Visible=d.Icon~=""
  card.Parent=self.Frame.Cards;self.Cards[id]=card
  table.insert(self.Connections,card.Activated:Connect(function()
   if self.IsOpen and self:CanOpen() and self.Payload.Owned[id] and not self.Pending then
    local requestId=HttpService:GenerateGUID(false)
    self.Pending={RequestId=requestId,WindowId=self.Payload.WindowId,PreparationId=self.Payload.PreparationId}
    self.Request(id,self.Payload,requestId)
   end
  end))
 end
end
function Selection:Render(payload)
 self:_buildCards()
 local key=payload.SessionId and payload.PreparationId and payload.WindowId
  and (payload.SessionId.."/"..payload.PreparationId.."/"..payload.WindowId)
 if key~=self.WindowKey then self:Close();self.WindowKey=key end
 self.Payload=payload
 if not self:CanOpen() then self:Close() end
 local receipt=payload.SelectionReceipt
 if self.Pending and receipt and receipt.RequestId==self.Pending.RequestId
  and receipt.WindowId==self.Pending.WindowId and receipt.PreparationId==self.Pending.PreparationId then
  self.Pending=nil
  if receipt.Accepted and receipt.AbilityId==payload.AbilityId then self:Close() end
 end
 for id,card in pairs(self.Cards) do
  local owned=payload.Owned[id]==true
  card.Active=owned and self:CanOpen() and self.Pending==nil
  card.Status.Text=if not owned then "BLOQUEADA · SHOP" elseif payload.AbilityId==id then "CONFIRMADA" else "SELECCIONAR"
  card.BackgroundTransparency=if owned then 0.05 else 0.45
 end
end
function Selection:CanOpen()
 local p=self.Payload
 return p~=nil and p.Selecting==true and not p.Playing and type(p.SelectionUntil)=="number"
  and p.SelectionUntil>workspace:GetServerTimeNow() and p.PreparationId~=nil and p.WindowId~=nil
  and (p.PreparationState=="StartCountdown" or p.PreparationState=="PointRestartCountdown")
  and (not self.IsCurrentSession or self.IsCurrentSession(p))
end
function Selection:Open()
 if not self:CanOpen() then self:Close();return false end
 self.IsOpen=true;self.Frame.Visible=true;return true
end
function Selection:Close()
 self.IsOpen=false;self.Pending=nil;self.Frame.Visible=false
end
function Selection:Tick()
 if not self:CanOpen() then self:Close() end
 if self.Payload and self:CanOpen() then
  self.Frame.Title.Text=string.format("ELEGÍ TU HABILIDAD · %ds",math.max(0,math.ceil(self.Payload.SelectionUntil-workspace:GetServerTimeNow())))
 end
end
function Selection:Destroy()
 self:Close()
 for _,c in ipairs(self.Connections) do c:Disconnect() end
 for _,c in pairs(self.Cards) do c:Destroy() end
end
return Selection
