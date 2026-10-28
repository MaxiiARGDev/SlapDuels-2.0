-- Actual catalog, provider factory, registry, Shop and PlayerService. No Roblox/cloud.
local function load(name,env)local f=assert(loadstring(Sources[name],name));setfenv(f,setmetatable(env or {},{__index=getfenv()}));return f()end
local loaded={};local parent=setmetatable({},{__index=function(_,key)return 'Crates/'..key end})
local function catalogLoad(key)
 if loaded[key]then return loaded[key]end
 local value=load(key,{script={Parent=parent},require=catalogLoad,Color3={fromRGB=function(...)return {...}end}})
 loaded[key]=value;return value
end
local catalog=catalogLoad('Crates/Catalog');local inventory=catalogLoad('Crates/Inventory')
local fixture=load('ShopFixture',{Sources=Sources}).New();local ps=fixture.PS;local actor=fixture.A
local rawCatalog={}
for _,id in ipairs(catalog.Crates.Order)do
 local c=catalog.Crates.ById[id]
 if not c.StudioOnly then table.insert(rawCatalog,{Id=id,Category='Crates',ProductType='Consumable',DisplayName=c.DisplayName,Price=c.PriceCoins or 0,Currency=c.PremiumOnly and 'Robux'or 'Coins',IsAvailable=true,Metadata={PremiumOnly=c.PremiumOnly==true}})end
end
local service={GetCatalog=function()return rawCatalog end,_resource=function()return true end,_lobby=function()return true end,_players=function()return ps end}
local factory=load('CrateProviders',{game={GetService=function()return {Shared={SlapCrates={Catalog='Catalog',Inventory='Inventory'}}}end},require=function(key)return key=='Catalog'and catalog or inventory end})
local providers=factory.Create(service)
local registry=fixture.Registry
local count=0;local function check(v,message)assert(v,message);count+=1 end
check(#rawCatalog==15,'reproduction includes 12 normal crates plus 3 drafts without Robux IDs')
local reproduction=load('ShopFixture',{Sources=Sources}).New().Registry
local legacy=table.clone(providers[1]);legacy.GetProducts=function()return rawCatalog end
local registered,registrationError=pcall(reproduction.Register,reproduction,legacy)
check(not registered and tostring(registrationError):find('RobloxProductId',1,true)~=nil,'old mixed provider reproduces the exact registration error')
check(reproduction:GetProvider('Slaps')==nil,'failed registration never reaches the next Slaps provider')
check(#providers[1]:GetProducts()==12,'Coins provider excludes Premium drafts')
registry:Register(providers[1]);registry:Register(providers[2])
check(registry:GetProvider('Slaps')~=nil,'real registry reaches Slaps registration')
check(registry:GetProduct('Classic:Blood','Slaps')~=nil,'Blood resolves by real category/id')
check(registry:GetProduct('PremiumI','Crates')==nil,'no Robux placeholder registered into Coins')
ps:AddItem(actor,'Slaps','Classic:Blood')
local owned=ps:HasItem(actor,'Slaps','Classic:Blood');check(owned,'same admin entitlement path')
local coins=ps:GetCoins(actor)
local ok,why=fixture.Shop:EquipProduct(actor,'Classic:Blood','Slaps')
check(ok,'actual Shop equip succeeds: '..tostring(why))
check(ps:GetInventory(actor).Equipped.Slaps=='Classic:Blood','confirmed authoritative equipped selection')
check(ps:GetCoins(actor)==coins,'equip spends no Coins')
check(not fixture.Shop:EquipProduct(actor,'Classic:Blood','PointEffects'),'wrong category still rejected')
check(not providers[1]:CanPurchase(),'crate purchase cannot bypass reviewed opening flow')
check(catalog.ProductionCommerceEnabled==false,'production commerce remains disabled')
for _,id in ipairs({'PremiumI','PremiumII','PremiumIII'})do local c=catalog.Crates.ById[id];check(not c.Enabled and not c.OddsApproved and not c.OpeningApproved,'premium sales remain disabled')end
print('PASS InventoryEquipFixV121: '..count..' assertions with real provider/registry/Shop/PlayerService; gameplay NOT RUN')
