--!nonstrict
-- Remote handlers run against plain tables; IsRunning is only a fixture boolean.
local count=0
local function check(v,label)assert(v,label);count+=1 end
local function load(name,env)
 local f=assert(loadstring(Sources[name],name));setfenv(f,setmetatable(env or {},{__index=getfenv()}));return f()
end
local F=load("ShopFixture",{Sources=Sources});local s=F.New();local a=s.A
local function node(class,children)
 local n={ClassName=class,Children=children or {}}
 function n:FindFirstChild(name)return self.Children[name]end
 function n:IsA(name)return name==self.ClassName end
 return n
end
local remotes=node("Folder",{GetCatalog=node("RemoteFunction"),PurchaseProduct=node("RemoteFunction"),
 EquipProduct=node("RemoteFunction"),UnequipProduct=node("RemoteFunction")})
local snapshots={};local event=node("RemoteEvent")
event.FireClient=function(_,p,data)table.insert(snapshots,{Player=p,Data=data})end
local rs=node("ReplicatedStorage",{Remotes=node("Folder",{Shop=remotes,Player=node("Folder",{DataUpdated=event})})})
local removing
s.Players.PlayerRemoving={Connect=function(_,fn)removing=fn;return {Disconnect=function()end}end}
local clock=1;local deferred={}
local run={IsRunning=function()return true end} -- No Roblox process is started.
local gameMock={GetService=function(_,name)return ({Players=s.Players,ReplicatedStorage=rs,RunService=run,ServerScriptService={}})[name]end}
local api=load("ShopRemotes",{game=gameMock,os={clock=function()return clock end},warn=function()end,print=function()end,
 task={defer=function(fn,...)table.insert(deferred,{fn,table.pack(...)})end},
 Instance={new=function()error("Expected remotes must be reused")end}})
api:Init(s.Shop)
local exposed=remotes.Children.GetCatalog.OnServerInvoke(a,"Abilities")
check(#exposed==5,"Remote exposes five registered products")
for _,p in ipairs(exposed)do
 check(type(p.Metadata)=="table" and p.Metadata.PriceApproved==true,"Approved metadata survives public projection: "..p.Id)
 check(p.Metadata.PurchaseEnabled==(p.Id~="Dash") and not p.Metadata.PricePending,"Correct public buying state: "..p.Id)
 check(p.Start==nil and p.Config==nil and p.Shop==nil,"No server execution/configuration exposed: "..p.Id)
end
for _,job in ipairs(deferred)do job[1](table.unpack(job[2],1,job[2].n))end
check(#snapshots==1 and snapshots[1].Player==a and snapshots[1].Data.Coins==10000,"Existing DataUpdated contract supplies authoritative balance/inventory")
local catalog=s.Shop.GetCatalog
s.Shop.GetCatalog=function(self,...)
 local result=catalog(self,...)
 result[1].Metadata.ServerOnly=function()error("Must not replicate")end
 result[1].Metadata.PrivateContext={Secret="fixture"}
 return result
end
local projected=remotes.Children.GetCatalog.OnServerInvoke(a,"Abilities")
check(projected[1].Metadata.ServerOnly==nil and projected[1].Metadata.PrivateContext==nil,"Metadata whitelist excludes arbitrary server values")
s.Shop.GetCatalog=catalog
local purchase=remotes.Children.PurchaseProduct.OnServerInvoke
local before=s.PS:GetCoins(a)
local ok,reason=purchase(a,{Id="StrongSlap",Price=0},"Abilities")
check(not ok and reason=="InvalidProductId" and s.PS:GetCoins(a)==before,"Client product/price object rejected")
ok,reason=purchase(a,"StrongSlap",{Price=1})
check(not ok and reason=="InvalidCategory" and s.PS:GetCoins(a)==before,"Forged price in category rejected")
check(purchase(a,"StrongSlap","Abilities",1),"Valid ID resolves authoritative product despite ignored extra client price")
check(s.PS:GetCoins(a)==before-3000 and s.PS:HasItem(a,"Abilities","StrongSlap"),"Client cannot choose charge amount")
ok,reason=purchase(a,"StrongSlap","Abilities")
check(not ok and reason=="RateLimited","Immediate button spam rejected")
clock+=.31;ok,reason=purchase(a,"StrongSlap","Abilities")
check(not ok and reason=="AlreadyOwned" and s.PS:GetCoins(a)==7000,"Network retry cannot debit again")
clock+=.31
check(remotes.Children.EquipProduct.OnServerInvoke(a,"StrongSlap","Abilities"),"Equip remote stores acquired preference")
check(s.PS:GetEquippedItem(a,"Abilities")=="StrongSlap" and s.PS:GetCoins(a)==7000,"Preference update never charges Coins")
local updates=#s.PS._snapshots;clock+=.31
check(remotes.Children.EquipProduct.OnServerInvoke(a,"StrongSlap","Abilities") and #s.PS._snapshots==updates,"Repeated equip remote does not mutate or notify again")
clock+=.31
check(not remotes.Children.EquipProduct.OnServerInvoke(a,"Invisible","Abilities"),"Remote cannot equip unowned ability")
clock+=.31
check(not purchase(a,"UnauthorizedModule","Abilities") and s.PS:GetCoins(a)==7000,"Remote rejects unregistered ability without balance mutation")
removing(a);check(purchase(a,"Dash","Abilities")==false,"Disconnect cleanup cannot enable free-item repurchase")
local handlers=remotes.Children.PurchaseProduct.OnServerInvoke
api:Init(s.Shop)
check(remotes.Children.PurchaseProduct.OnServerInvoke==handlers,"Repeated API initialization reuses handler/remotes")
print(string.format("PASS: %d isolated remote/catalog assertions; no Studio/gameplay/cloud execution.",count))
