--!nonstrict
-- Actual client controller methods over table-based UI/event/task mocks.
local count=0
local function check(v,label)assert(v,label);count+=1 end
local function load(name,env)
 local f=assert(loadstring(Sources[name],name));setfenv(f,setmetatable(env or {},{__index=getfenv()}));return f()
end
local F=load("ShopFixture",{Sources=Sources});local s=F.New()
local thread,listener
local tasks={spawn=function(fn)thread=coroutine.create(fn);assert(coroutine.resume(thread))end,delay=function()end}
local color={fromRGB=function(...)return {...}end}
local gameMock={GetService=function(_,name)return if name=="Players" then {LocalPlayer={}} else {}end}
local C=load("ShopController",{game=gameMock,task=tasks,Color3=color,typeof=type,warn=function()end})
local function gui()
 return {GetAttribute=function()return nil end,BackgroundColor3="base",TextColor3="text"}
end
local d={Frame=gui(),NameLabel=gui(),RarityLabel=gui(),DescriptionLabel=gui(),PriceRow=gui(),PriceLabel=gui(),
 StatusLabel=gui(),ActionButton=gui(),SecondaryButton=gui(),PreviewIcon=gui(),PreviewLabel=gui()}
local ui={Main=gui(),Detail=d,CoinsLabel=gui(),MessageLabel=gui()}
local c=setmetatable({_ui=ui,_category="Abilities",_catalog=s.Provider:GetProducts(),_selectedId="AirJumps",
 _cards={},_cardConnections={},_busy=false,_isOpen=true,_messageToken=0,_remotes={}}, {__index=C})
local function data(coins,owned,preferred)
 return {Coins=coins,Inventory={Owned={Abilities=owned or {Dash=true}},Equipped={Abilities=preferred or "Dash"}}}
end
c._playerData=data(10000)
c:_renderDetail()
check(d.PriceLabel.Text=="750 Coins" and d.ActionButton.Text=="COMPRAR" and d.ActionButton.Active,"Approved price and enabled Buy rendered")
c._selectedId="DevilSpeed";c:_renderDetail()
check(d.PriceLabel.Text=="1.500 Coins" and d.ActionButton.Text=="COMPRAR","Thousands formatting uses approved catalog value")
c._playerData.Coins=1499;c:_renderDetail()
check(not d.ActionButton.Active and d.StatusLabel.Text=="Coins insuficientes","Insufficient funds disables buying and explains state")
local sent={}
c._request=function(_,...)table.insert(sent,table.pack(...))end
c:_onActionPressed()
check(#sent==0,"Direct repeated handler invocation cannot send unaffordable purchase")
c._playerData.Coins=1500;c:_onActionPressed()
check(#sent==1 and sent[1][1]=="PurchaseProduct" and sent[1][2]=="DevilSpeed" and sent[1][4]=="Abilities","Client requests ID/category without a price")
c._playerData=data(0,{Dash=true,DevilSpeed=true});c:_renderDetail()
check(d.ActionButton.Text=="EQUIPAR" and d.ActionButton.Active and not d.PriceRow.Visible,"Owned ability exposes Equip without price")
c:_onActionPressed()
check(sent[2][1]=="EquipProduct" and sent[2][2]=="DevilSpeed","Owned action uses existing Equip remote")
c._playerData.Inventory.Equipped.Abilities="DevilSpeed";c:_renderDetail()
check(d.ActionButton.Text=="PREFERIDA" and not d.ActionButton.Active,"Preferred ability has disabled preferred indicator")
c:_onActionPressed();check(#sent==2,"Preferred ability cannot repeatedly request mutations")
c._selectedId="Dash";c:_renderDetail()
check(d.NameLabel.Text=="Impulso" and d.ActionButton.Text=="EQUIPAR" and not d.PriceRow.Visible,"Dash remains owned/free with approved name")
c._playerData.Inventory.Equipped.Abilities="Dash";c:_renderDetail()
check(d.ActionButton.Text=="PREFERIDA" and not d.SecondaryButton.Visible,"Free Dash has no repurchase or unequip action")
local locked={Id="FixtureDisabled",Category="Abilities",ProductType="Ability",DisplayName="Fixture",Price=1,Currency="Coins",IsAvailable=true,
 Metadata={PurchaseEnabled=true,PriceApproved=false}}
table.insert(c._catalog,locked);c._selectedId=locked.Id;c:_renderDetail()
check(d.ActionButton.Text=="PRÓXIMAMENTE" and not d.ActionButton.Active,"Unapproved future product fails closed")
c:_onActionPressed();check(#sent==2,"Unapproved product cannot submit a purchase")

-- Real _request, delayed response, DataUpdated, duplicate clicks, Close while pending.
c._request=nil;c._selectedId="AirJumps";c._playerData=data(10000)
local calls=0;local args
c._remotes.PurchaseProduct={InvokeServer=function(_,...)
 calls+=1;args=table.pack(...);coroutine.yield("network-paused");return true
end}
c._dataUpdated={OnClientEvent={Connect=function(_,callback)listener=callback;return {}end}}
c:_ensureDataListener();c:_onActionPressed()
check(c._busy and calls==1 and d.ActionButton.Text=="PROCESANDO…" and not d.ActionButton.Active,"In-flight purchase locks client action")
check(args.n==2 and args[1]=="AirJumps" and args[2]=="Abilities","Actual RemoteFunction gets only product identity")
c:_onActionPressed();check(calls==1,"Double click cannot start second network call")
c:Close();check(not c._isOpen and not ui.Main.Visible and c._busy,"Closing Shop does not cancel or repeat pending purchase")
listener(data(9250,{Dash=true,AirJumps=true}))
check(c._playerData.Coins==9250 and c:_isOwned(s.Provider:GetProduct("AirJumps")),"Server snapshot supplies ownership/balance after closed Shop purchase")
check(coroutine.resume(thread) and coroutine.status(thread)=="dead" and not c._busy,"Delayed successful response releases client lock")
check(not c._isOpen and not ui.Main.Visible and calls==1,"Response cannot reopen Shop or resubmit purchase")
check(d.ActionButton.Text=="EQUIPAR" and ui.CoinsLabel.Text=="9.250","Committed ownership and balance render after response")
listener(data(9250,{Dash=true,AirJumps=true}));listener(data(9250,{Dash=true,AirJumps=true}))
check(c._playerData.Coins==9250 and calls==1,"Duplicate server snapshots are not transactions")
check(c._playerData.Inventory.Equipped.Abilities=="Dash","Client response never auto-equips bought skill")
print(string.format("PASS: %d isolated Shop UI assertions; no Studio/gameplay/cloud execution.",count))
