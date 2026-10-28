-- Data and actual card rendering with disposable GUI mocks; no purchases/Studio.
local count=0;local function check(v,m)assert(v,m);count+=1 end
local function load(key,env)local f=assert(loadstring(Sources[key],key));setfenv(f,setmetatable(env or {},{__index=getfenv()}));return f()end
local coins=load('Premium/CoinPackages')
local config=load('Premium/PremiumShopConfig')
check(#coins==5,'Exactly five approved coin packs')
check(not config.PurchasesEnabled and not config.DurableCommerceValidated,'Commerce remains disabled')
local C=load('Premium/Controller',{game={GetService=function(_,k)return k=='Players'and{LocalPlayer={}}or k=='ReplicatedStorage'and{Shared={PremiumShop={PlaceholderProductIds=true}}}or{}end},
 script={Parent={Parent={PremiumShop={PremiumPurchaseFlow=true}}}},require=function()return{}end,
 warn=function()end,Color3={fromRGB=function(r,g,b)return{R=r,G=g,B=b}end}})
local expected={{1000,50,'1,000','50'},{10000,450,'10,000','450'},{35000,1250,'35,000','1,250'},{100000,3000,'100,000','3,000'},{400000,10000,'400,000','10,000'}}
for i,row in ipairs(expected)do
 local p=coins[i];check(p.Coins==row[1]and p.Rewards.Coins==row[1]and p.SuggestedRobux==row[2],'Approved amount/price '..i)
 check(p.Id=='Coins_'..row[1]and p.IsPlaceholder and not p.PurchaseApproved,'Unique safe placeholder '..i)
 local view=C:CoinPresentation(p)
 check(view.Title==row[3]and view.Buy==row[4]..' ROBUX','Readable amount and button price '..i)
 check(view.Provisional and view.Price==row[4]..' ROBUX · PRECIO PROVISIONAL'and view.Status=='VISTA PREVIA','Clear draft pricing '..i)
 check(p.PriceRobux==nil and not p.PurchaseAllowed,'Suggested price grants no purchase authorization '..i)
end
local actual=table.clone(coins[1]);actual.IsPlaceholder=false;actual.PriceRobux=55
local realView=C:CoinPresentation(actual)
check(realView.Price=='55 ROBUX'and not realView.Provisional,'Real Roblox price wins over suggested draft')
local function event()return{Connect=function()return{Disconnect=function()end}end}end
local function card()
 local c={Activated=event(),Preview={},Stroke={},Attrs={PremiumPersistentCard=true}}
 for _,k in {'Title','Description','Content','Price','Status','Buy'}do c[k]={Activated=event()}end
 function c:FindFirstChildWhichIsA()return self.Stroke end
 function c:GetAttribute(k)return self.Attrs[k]end
 function c:IsA(k)return k=='GuiObject'or k=='GuiButton'end
 function c:Destroy()self.Destroyed=true end
 return c
end
local template={Clone=card};local tabs={};for _,name in {'Coins','Combos','PremiumCrates'}do tabs[name]={}end
local catalog={ProductCardTemplate=template,Children={}}
function catalog:FindFirstChild(k)return self.Children[k]end
function catalog:GetChildren()local a={};for _,c in pairs(self.Children)do table.insert(a,c)end;return a end
for _,p in ipairs(coins)do local c=card();c.Attrs.PremiumProductId=p.Id;c.Title.TextColor3='ArtistColor';catalog.Children['Product_'..p.Id]=c end
local ctl=setmetatable({Category='Coins',Products=coins,Cards={},CardConnections={},Main={Catalog=catalog,Empty={},Tabs=tabs},
 _preview=function()error('Persistent preview must not be rebuilt')end,_layout=function()end},{__index=C})
ctl:_render();check(#ctl.Cards==5,'Actual renderer creates all five cards')
for i,c in ipairs(ctl.Cards)do
 check(c.Title.Text==expected[i][3]and c.Buy.Text==expected[i][4]..' ROBUX','Rendered package matches approved presentation '..i)
 check(not c.Buy.Active and not c.Buy.AutoButtonColor and c.Status.Text=='VISTA PREVIA','Rendered placeholder cannot purchase '..i)
end
check(not ctl.Main.Empty.Visible,'Catalog is not empty')
local original=table.clone(ctl.Cards);ctl:_render()
check(#ctl.Cards==5,'Repeated render has exactly five reused cards')
for i,c in ipairs(ctl.Cards)do check(c==original[i]and c.Title.TextColor3=='ArtistColor','Physical card identity and artist color preserved '..i)end
ctl:_clear();check(#ctl.Cards==0 and not original[1].Destroyed and original[1].Visible,'Close clears listeners without destroying/hiding physical cards')
catalog.Children.Product_Coins_1000=nil
check(ctl:_cardFor(coins[1])==nil,'Missing physical card does not silently create a runtime clone')
print('PremiumCoinsV12 PASS '..count..' isolated assertions; purchases/gameplay NOT RUN')
