-- Execute only in Studio Edit, using a disposable clone. No gameplay/services started.
assert(not game:GetService("RunService"):IsRunning(),"Edit only")
local module=game.StarterPlayer.StarterPlayerScripts.UI.ShopLayout:Clone()
module.Parent=game.StarterPlayer.StarterPlayerScripts.UI
local Layout=require(module);module:Destroy()
local hud=game.StarterGui.ShopHUD:Clone();hud.Name="ShopUnifiedLayoutTest";hud.Enabled=false
for _,v in hud:GetDescendants()do if v:IsA("BaseScript")then v.Disabled=true end end
hud.Parent=game.StarterGui
local checks=0;local sizes={}
local function check(value,message)checks+=1;assert(value,message)end
local ok,err=xpcall(function()
 local main=hud.MainFrame
 for _,c in main:GetChildren()do if c:IsA("UISizeConstraint")or c:IsA("UIAspectRatioConstraint")then c:Destroy()end end
 local host,detail,panel,back=Layout.Prepare(hud)
 main.Body.Catalog:SetAttribute("HasProducts",true)
 for _,size in {Vector2.new(320,568),Vector2.new(390,844),Vector2.new(768,1024),Vector2.new(844,390),Vector2.new(1024,600),Vector2.new(1366,768)}do
  main.Size=UDim2.fromOffset(size.X,size.Y);task.wait()
  local compact=Layout.Apply(hud,false);task.wait()
  check(main.Body.Catalog.Visible,"Collection visible")
  check(host.Visible==not compact,"Wide detail / narrow collection")
  check(main.Header.CoinsContainer.Position.X.Offset+main.Header.CoinsContainer.Size.X.Offset<=main.Header.CloseButton.Position.X.Offset,"Header collision")
  Layout.Apply(hud,true);task.wait()
  check(host.Visible,"Selected detail visible")
  check(back.Visible==compact,"Back only on compact screens")
  check(main.Body.Catalog.Visible==not compact,"Collection hidden on compact detail")
  check(panel.Buy.Size.Y.Offset>=44 and panel.OpenActions.X1.Size.Y.Offset>=44,"Touch target")
  check(panel.Buy.Position.Y.Offset+panel.Buy.Size.Y.Offset<=panel.Size.Y.Offset,"Buy within canvas")
  check(panel.OpenActions.Position.Y.Offset+panel.OpenActions.X10.Position.Y.Offset+panel.OpenActions.X10.Size.Y.Offset<=host.CanvasSize.Y.Offset,"Open reachable")
  check(panel.RewardScroll.Position.Y.Offset+panel.RewardScroll.Size.Y.Offset<=panel.Status.Position.Y.Offset,"Gallery / status separation")
  check(panel.Parent==host and detail.Parent==host,"Single detail host")
  table.insert(sizes,tostring(size))
 end
 local card=main.Body.Catalog.ProductCardTemplate
 Layout.Card(card)
 check(card.Text=="","No root title duplicate")
 check(card.NameLabel.Position.Y.Offset>=card.Preview.Position.Y.Offset+card.Preview.Size.Y.Offset,"Title below preview")
 check(card.RarityLabel.Position.Y.Offset>=card.NameLabel.Position.Y.Offset+card.NameLabel.Size.Y.Offset,"Rarity below title")
 main.Body.Catalog:SetAttribute("HasProducts",false);Layout.Apply(hud,true)
 check(not host.Visible and not main.Body.Catalog.Visible,"No stale detail for empty categories")
end,debug.traceback)
hud:Destroy()
assert(ok,err)
return {Assertions=checks,Sizes=sizes,Mode="Edit",Gameplay=false}
