-- Extends the actual-module V1 fixture. No Studio, cloud or gameplay execution.
local View=loaded.CrateShopView
local order={"Basic","Common","Uncommon","Rare","Gold","Arcoiris","Emote","Wings","Epic","Legendary","Blood","Galaxy","StudioTest"}
local list=service:GetCatalog()
for i,id in ipairs(order)do check(list[i].Id==id and list[i].SortOrder==C.Crates.ById[id].SortOrder,"Server explicit order "..id)end
local shopClass=load("ShopControllerActual","ShopController")
local shopUI=setmetatable({_catalog={},_category="Crates",_cards={}},{__index=shopClass})
for i=#list,1,-1 do table.insert(shopUI._catalog,list[i])end
local sorted=shopUI:_getProducts("Crates")
for i,id in ipairs(order)do check(sorted[i].Id==id,"Actual Shop sorting ignores shuffled arrival "..id)end
table.insert(shopUI._catalog,{Id="Future",Category="Crates",SortOrder=35,Price=999})
local future=shopUI:_getProducts("Crates");check(future[4].Id=="Future" and future[5].Id=="Rare","Future crate inserted by configured position")
local ties=View.SortProducts({{Id="Z",SortOrder=1},{Id="A",SortOrder=1}},"Crates")
check(ties[1].Id=="A","SortOrder ties use stable CrateId")
local abilities=View.SortProducts({{Id="A",Price=9},{Id="Z",Price=1}},"Abilities")
check(abilities[1].Id=="Z","Other category price order unchanged")
local testProduct=providers[1]:GetProduct("StudioTest")
local snapshot={Coins=1,Inventory=I.Extend({})}
local q={Ok=true,Token="quote",ExpiresAt=130,PriceCoins=1,Outcomes={{RewardId="Classic:Basic",Percent=75,Stock={UnlimitedStock=true}},{RewardId="Classic:Common",Percent=25,Stock={UnlimitedStock=true}}}}
for i=1,12 do local state=View.State(list[i],snapshot,nil,100,false)
 check(state.PriceText=="Precio pendiente"and not state.BuyEnabled,"No false zero price "..list[i].Id)
end
local state=View.State(testProduct,snapshot,q,100,false)
check(state.PriceText=="1 Coins" and state.BuyEnabled and not state.OpenEnabled,"Approved test price from server and no unopened box")
local poor=I.Copy(snapshot);poor.Coins=0;poor.Inventory.Crates.StudioTest=1
state=View.State(testProduct,poor,q,100,false)
check(not state.BuyEnabled and state.OpenEnabled and state.Status=="Coins insuficientes","No balance prevents buy but not opening owned box")
local pendingOdds=I.Copy(testProduct);pendingOdds.Metadata.OddsApproved=false
check(View.State(pendingOdds,snapshot,q,100,false).Status=="Probabilidades pendientes","Odds approval distinct from price approval")
check(not View.State(testProduct,snapshot,q,130,false).BuyEnabled,"Quote expires at exact deadline")
local invalid=I.Copy(q);invalid.Outcomes[1].Percent=70
check(not View.State(testProduct,snapshot,invalid,100,false).BuyEnabled,"Undisclosable distribution blocked in UI")
local unknown=I.Copy(q);unknown.Outcomes={}
check(not View.State(testProduct,snapshot,unknown,100,false).BuyEnabled,"No final outcomes cannot enable purchase")
state=View.State(testProduct,snapshot,{Ok=false,Code="NoEligibleResults"},100,false)
check(not state.BuyEnabled and not state.OpenEnabled and state.StockText=="Sin resultados disponibles","Sold out/no eligible results cannot enable action")
-- Use actual client methods against actual service/engine/profile fixture.
extraEnv.task.spawn=function(fn)fn()end;extraEnv.task.wait=function()end;extraEnv.task.defer=function()end
service:Init(ctx);service._resource=function()return true end;pdata[a]=data(2)
local flow=load("CrateFlowActual","CrateController")
local refreshes=0
function shopUI:_refreshStates()refreshes+=1 end
local flowContext={GetController=function(_,name)return if name=="ShopController"then shopUI else flow end}
flow:Init(flowContext);flow._spinPanel=spin
local panel=visual("Frame","Panel")
for _,name in ipairs({"Title","Count","Status","Outcomes","Buy","Open","ViewOdds"})do panel.Children[name]=visual("TextLabel",name)end
flow._panel=panel;flow._request={};flow:SetCatalog(service:GetCatalog())
local calls,ids={},{}
local loseReply=true;local reentry=false
function flow:_call(action,args)
 table.insert(calls,action)
 if action=="Inventory"then return {Ok=true,Inventory=pdata[a].Inventory,Snapshot={Coins=pdata[a].Coins,Inventory=I.Copy(pdata[a].Inventory)}}end
 if action=="Quote"then return service:Quote(a,args.CrateId)end
 table.insert(ids,args.OperationId)
 if action=="Purchase"and not reentry then reentry=true;self:_mutate("Purchase")end
 local result=service:_transact(a,action,args)
 if action=="Purchase"and loseReply then loseReply=false;return {Ok=false,Code="NoResponse"}end
 return result
end
flow:ShowCrate("StudioTest")
check(panel.Buy.Active and not panel.Open.Active and panel.Outcomes.Text:find("75",1,true),"Actual panel shows numeric odds before enabling purchase")
flow:_mutate("Purchase")
check(pdata[a].Coins==1 and pdata[a].Inventory.Crates.StudioTest==1,"Purchase commits right Coins and one closed box")
check(flow._pendingAction and panel.Buy.Text=="REINTENTAR","Lost response retains unresolved operation")
flow:_mutate("Purchase")
check(ids[1]==ids[2] and #ids==2,"Retry preserves OperationId; reentrant click creates no extra request")
check(pdata[a].Coins==1 and pdata[a].Inventory.Crates.StudioTest==1,"Same operation cannot double-charge or duplicate crate")
check(not flow._pendingAction and shopUI._playerData.Coins==1 and shopUI._playerData.Inventory.Crates.StudioTest==1,"Balance/inventory snapshot refreshed in Shop")
check(panel.Count.Text:find("Cajas: 1",1,true)and panel.Open.Active,"Owned crate quantity and Open refreshed")
pdata[a].Coins=0;flow:_quoteCurrent("StudioTest")
local beforeCalls=#calls;flow:_mutate("Purchase")
check(not panel.Buy.Active and #calls==beforeCalls,"Insufficient balance disables client request")
local forged=service:_transact(a,"Purchase",{CrateId="StudioTest",OperationId="forgedPrice",QuoteToken=flow._quote.Token,PriceCoins=0})
check(not forged.Ok and forged.Code=="InsufficientFunds"and pdata[a].Coins==0,"Server ignores Remote price and rejects insufficient funds")
local messagesBefore=#objects;local observed
local originalSpin=flow._spin
flow._spin=function(self,packet)observed=packet;return originalSpin(self,packet)end
flow:_mutate("Open")
check(pdata[a].Inventory.Crates.StudioTest==0 and pdata[a].Coins==0,"Opening consumes once with no additional Coin cost")
check(observed and pdata[a].Inventory.Owned.Slaps[observed.Operation.RewardId],"Spin uses actually granted Slap+variation")
for i=messagesBefore+1,#objects do local message=objects[i]
 if message.Name=="World"or message.Name=="Reveal"then check(message.Packet.Operation.RewardId==observed.Operation.RewardId,"World/HUD use same assigned reward")end
end
check(not panel.Open.Active and flow._quote==nil,"Empty inventory and stale post-open quote cannot reopen")
local v=providers[2]:GetProduct(observed.Operation.RewardId)
check(providers[2]:OnEquipped(a,v),"Awarded exact reward remains equippable")
flow:_quoteCurrent("StudioTest")
service._quotes[a].Until=-1
local expired=service:_transact(a,"Purchase",{CrateId="StudioTest",OperationId="expiredV12",QuoteToken=flow._quote.Token})
check(not expired.Ok and expired.Code=="ViewOddsFirst","Server rejects expired quote without debit")
local savedResource=service._resource;service._resource=function()return false end
flow:_quoteCurrent("StudioTest")
check(not panel.Buy.Active and not panel.Open.Active and panel.Status.Text:find("elegibles",1,true),"Actual no-results response disables both buttons")
service._resource=savedResource;policy.ArePaidRandomItemsRestricted=true
flow:_quoteCurrent("StudioTest")
check(not panel.Buy.Active and not panel.Open.Active,"Restricted policy never enables client purchase")
policy.ArePaidRandomItemsRestricted=false
-- Public projection preserves ordering, prices and approval flags.
local public=rs.Remotes.Shop.GetCatalog.OnServerInvoke(a)
check(public[1].SortOrder==10 and public[1].Metadata.PricePending and not public[1].Metadata.OddsApproved,"Public Shop contract retains order and approvals")
-- Late Quote for a prior selection must not replace the current selection state.
shopUI._context=flowContext;shopUI._selectedId="Basic"
local detail={}
for _,name in ipairs({"NameLabel","DescriptionLabel","PriceRow","PriceLabel","StatusLabel","ActionButton","SecondaryButton"})do detail[name]=visual("TextLabel",name)end
shopUI._ui={Detail=detail}
shopUI:_renderDetail()
check(detail.PriceLabel.Text=="Precio pendiente"and detail.ActionButton.Text=="VER CAJA","Actual Shop detail shows pending price without crashing")
local card=visual("Frame","Card")
for _,name in ipairs({"PriceLabel","StateBadge","CoinIcon"})do card.Children[name]=visual("TextLabel",name)end
card.Children.CrateActions=visual("Frame","CrateActions")
for _,name in ipairs({"Action","StockLabel"})do card.CrateActions.Children[name]=visual("TextLabel",name)end
shopUI:_applyCardState(card,providers[1]:GetProduct("Basic"))
check(card.PriceLabel.Text=="Precio pendiente"and not card.CrateActions.Action.Active,"Actual card blocks pending commerce and hides zero")
flow._quoteCache.StudioTest=service:Quote(a,"StudioTest")
shopUI._playerData={Coins=0,Inventory=I.Extend({})};shopUI._playerData.Inventory.Crates.StudioTest=2
shopUI:_applyCardState(card,testProduct)
check(card.StateBadge.Text=="2 cajas"and card.CrateActions.Action.Active and card.CrateActions.Action.Text=="ABRIR","Actual acquired-card state uses quantity and offers opening with no balance")
local normalCall=flow._call
flow._call=function(self,action,args)
 if action=="Quote"then self._selectionVersion+=1;self._crateId="Basic";return q end
 return normalCall(self,action,args)
end
flow._crateId="StudioTest";flow._quote=nil
flow:_quoteCurrent("StudioTest")
check(flow._quote==nil and flow._crateId=="Basic","Late quote cannot apply to another crate")
flow._crateId="StudioTest";flow._quote=nil
flow._call=function(self,action,args)
 if action=="Quote"then
  local old=normalCall(self,action,args)
  self:SetSnapshot({Coins=99,Inventory=I.Extend({})},true)
  old.Snapshot={Coins=1,Inventory=I.Extend({})};return old
 end
 return normalCall(self,action,args)
end
flow:_quoteCurrent("StudioTest")
check(flow._data.Coins==99,"Late quote snapshot cannot overwrite newer authoritative DataUpdated")
-- Reproduce the client template missing Camera, exercising the actual preview method.
local previousInstance,previousLookAt=extraEnv.Instance,extraEnv.CFrame.lookAt
local previousVectorNew=extraEnv.Vector3.new
extraEnv.Vector3.new=function(x)return vec(x or 0)end
local created=0
extraEnv.Instance={new=function(class)check(class=="Camera","Preview creates only a local camera");created+=1;return {ClassName=class}end}
extraEnv.CFrame.lookAt=function()return {PreviewPose=true}end
local previewModel={PivotTo=function()end,GetExtentsSize=function()return {Magnitude=4}end}
local effects=node("Folder","CrateEffects");effects.Children.Basic={Clone=function()return previewModel end};rs.Children.CrateEffects=effects
local suppliedCamera=nil;local lastViewport
local template={Clone=function()
 lastViewport={WorldModel={}}
 function lastViewport:FindFirstChildWhichIsA(class)return suppliedCamera end
 return lastViewport
end}
local previewHud=node("ScreenGui","ShopHUD");previewHud.Children.CratePreviewTemplate=template
local previewUI=setmetatable({_ui={Hud=previewHud}},{__index=shopClass})
local preview=node("Frame","Preview");preview.Children.PreviewLabel={Visible=true}
previewUI:_cratePreview(preview,{Icon="",Metadata={Model="Basic"}})
check(created==1 and lastViewport.CurrentCamera.Parent==lastViewport and lastViewport.CurrentCamera.FieldOfView==45,"Missing client camera created locally and bound")
check(lastViewport.CurrentCamera.CFrame.PreviewPose and not preview.PreviewLabel.Visible,"Missing-camera preview completes without aborting catalog")
suppliedCamera={FieldOfView=45}
previewUI:_cratePreview(preview,{Icon="",Metadata={Model="Basic"}})
check(created==1 and lastViewport.CurrentCamera==suppliedCamera,"Existing camera reused without duplicates")
extraEnv.Instance=previousInstance;extraEnv.CFrame.lookAt=previousLookAt
extraEnv.Vector3.new=previousVectorNew
print("PASS SlapCratesV12: "..assertions.." isolated assertions including base crates regression; gameplay/cloud NOT RUN")
