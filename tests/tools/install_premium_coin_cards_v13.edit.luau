-- Edit-only physical UI installation. No services, purchases or gameplay are started.
assert(not game:GetService('RunService'):IsRunning(),'Studio Edit required')
local hud=game.StarterGui.PremiumShopHUD
local main=hud.MainFrame
local catalog=main.Catalog
local template=catalog.ProductCardTemplate
local data=game.ReplicatedStorage.Shared.PremiumShop.Catalog.CoinPackages:Clone()
local ok,products=pcall(require,data)
data:Destroy()
assert(ok,products)
local function numberText(n)return(tostring(n):reverse():gsub('(%d%d%d)','%1,'):reverse():gsub('^,',''))end
local results={}
for _,product in ipairs(products)do
 local name='Product_'..product.Id
 local matches={}
 for _,child in catalog:GetChildren()do if child.Name==name then table.insert(matches,child)end end
 assert(#matches<=1,'Duplicate existing card '..name)
 local card=matches[1]
 assert(not card or card:GetAttribute('PremiumPersistentCard')==true,'Existing card is not owned by this installer: '..name)
 local created=not card
 if not card then
  card=template:Clone();card.Name=name
  card:SetAttribute('PremiumPersistentCard',true)
  card:SetAttribute('PremiumProductId',product.Id)
  card.BackgroundColor3=Color3.fromRGB(13,19,26)
  card.Title.TextColor3=Color3.fromRGB(255,255,255)
  card.Price.TextColor3=Color3.fromRGB(255,213,77)
  card.Buy.BackgroundColor3=Color3.fromRGB(19,199,63)
  card.Buy.BackgroundTransparency=.15
  local stroke=card:FindFirstChildWhichIsA('UIStroke');if stroke then stroke.Color=Color3.fromRGB(205,166,46)end
  local viewport=card.Preview
  local world=viewport:FindFirstChildWhichIsA('WorldModel')or Instance.new('WorldModel')
  world.Name='World';world.Parent=viewport
  local camera=viewport:FindFirstChildWhichIsA('Camera')or Instance.new('Camera')
  camera.Name='PreviewCamera';camera.Parent=viewport
  local model=game.ReplicatedStorage.PremiumShopPreviews.CoinsDisplay:Clone()
  for _,obj in model:GetDescendants()do
   if obj:IsA('BasePart')then obj.Anchored=true;obj.CanCollide=false;obj.CanTouch=false;obj.CanQuery=false
   elseif obj:IsA('LuaSourceContainer')then obj:Destroy()end
  end
  model.Name='CoinsDisplay';model:PivotTo(CFrame.new());model.Parent=world
  local bounds,size=model:GetBoundingBox()
  local extent=math.max(size.X,size.Y,size.Z)
  camera.FieldOfView=35
  camera.CFrame=CFrame.lookAt(bounds.Position+Vector3.new(extent*.8,extent*.55,extent*2.4),bounds.Position)
  viewport.CurrentCamera=camera
  viewport.Ambient=Color3.fromRGB(210,210,210)
  card.Parent=catalog
 end
 card:SetAttribute('CoinAmount',product.Rewards.Coins)
 card:SetAttribute('SuggestedRobux',product.SuggestedRobux)
 card.Visible=true;card.LayoutOrder=product.SortOrder
 card.Title.Text=numberText(product.Rewards.Coins)
 card.Description.Text=product.Description
 card.Content.Text='COINS GARANTIZADAS'
 card.Price.Text=numberText(product.SuggestedRobux)..' ROBUX · PRECIO PROVISIONAL'
 card.Buy.Text=numberText(product.SuggestedRobux)..' ROBUX'
 card.Buy.Active=false;card.Buy.AutoButtonColor=false
 card.Status.Text='VISTA PREVIA'
 local world=card.Preview:FindFirstChildWhichIsA('WorldModel')
 assert(world and world:FindFirstChild('CoinsDisplay')and card.Preview.CurrentCamera,'Incomplete preview: '..name)
 table.insert(results,{Path=card:GetFullName(),Created=created,Visible=card.Visible,Amount=card.Title.Text,Price=card.Buy.Text,
  PreviewParts=#world:GetDescendants(),ProductId=card:GetAttribute('PremiumProductId')})
end
template.Visible=false
catalog.AutomaticCanvasSize=Enum.AutomaticSize.Y
catalog.CanvasSize=UDim2.fromOffset(0,0)
catalog.ScrollingDirection=Enum.ScrollingDirection.Y
catalog.ScrollBarThickness=6
catalog.UIGridLayout.CellSize=UDim2.new(.49,-6,0,224)
main.Empty.Visible=false
hud.Enabled=true;main.Visible=true
return results
