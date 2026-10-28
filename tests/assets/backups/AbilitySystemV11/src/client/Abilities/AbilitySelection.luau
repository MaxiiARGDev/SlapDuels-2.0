--!nonstrict
local Definitions=require(game.ReplicatedStorage.Shared.AbilityDefinitions)
local Selection={}
Selection.__index=Selection
function Selection.new(frame,request)
 local self=setmetatable({Frame=frame,Cards={},Connections={}},Selection)
 local template=frame.Cards.AbilityCardTemplate
 for index,id in ipairs(Definitions.Order) do
  local d=Definitions.Items[id]
  local card=template:Clone();card.Name=id;card.LayoutOrder=index;card.Visible=true
  card.AbilityName.Text=d.DisplayName
  card.Description.Text=d.Description
  card.Cooldown.Text=string.format("CD %ds · duración %ss",d.Cooldown,if id=="Dash" then "instantánea" else tostring(d.Duration))
  card.Icon.Image=d.Icon;card.Icon.Visible=d.Icon~=""
  card.Parent=frame.Cards;self.Cards[id]=card
  table.insert(self.Connections,card.Activated:Connect(function()
   if self.Payload and self.Payload.Selecting and self.Payload.Owned[id] then request(id,self.Payload) end
  end))
 end
 return self
end
function Selection:Render(payload)
 self.Payload=payload;self.Frame.Visible=payload.Selecting==true
 for id,card in pairs(self.Cards) do
  local owned=payload.Owned[id]==true
  card.Active=owned and payload.Selecting
  card.Status.Text=if not owned then "BLOQUEADA · SHOP" elseif payload.AbilityId==id then "CONFIRMADA" else "SELECCIONAR"
  card.BackgroundTransparency=if owned then 0.05 else 0.45
 end
end
function Selection:Tick()
 if self.Payload and self.Payload.Selecting then
  self.Frame.Title.Text=string.format("ELEGÍ TU HABILIDAD · %ds",math.max(0,math.ceil(self.Payload.SelectionUntil-workspace:GetServerTimeNow())))
 end
end
function Selection:Destroy()
 for _,c in ipairs(self.Connections) do c:Disconnect() end
 for _,c in pairs(self.Cards) do c:Destroy() end
end
return Selection
