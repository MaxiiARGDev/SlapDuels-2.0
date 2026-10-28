do
 local start=n;local Personal=load('PersonalInventory')
 local products={{Id='Basic',Category='Crates',DisplayName='Caja básica',Rarity='Basic'}, {Id='Rare',Category='Crates',DisplayName='Caja rara',Rarity='Rare'}, {Id='PremiumI',Category='Crates',DisplayName='Caja premium',Rarity='PremiumI'}}
 local saved=copy(ownData);ownData.Inventory.Crates={Basic=3,Rare=0,PremiumI=2,Unknown=99}
 local shop={GetCatalog=function(_,category)return category=='PointEffects'and {{Id='Basic',Category=category,DisplayName='Básico',IsAvailable=true},{Id='NotOwned',Category=category,DisplayName='No poseído',IsAvailable=true}}or {}end}
 Service.Context={GetService=function(_,name)return name=='ShopService'and shop or name=='CrateService'and {GetCatalog=function()return products end}or nil end}
 Service.Engine.Busy[aa.UserId]=nil;active[aa]=nil;ready=true;aa.Attributes.ResultsSessionId=nil
 local function fetch(category,page,query)clock+=.3;return Service:Inventory(aa,category,page or 1,query or '')end
 local r=fetch('Crates');check(r.Ok and r.Inventory.UserId==aa.UserId,'private inventory bound to authenticated caller')
 check(#r.Inventory.Items==2,'only positive owned counts from real catalog, including premium')
 check(r.Inventory.Items[1].Quantity==3 and r.Inventory.Items[2].Quantity==2,'exact owned crate amounts')
 check(r.Inventory.Coins==nil and r.Inventory.CrateOperations==nil and r.Inventory.SlapUnits==nil,'no persistence journal or balances in DTO')
 check(fetch('Crates',1,'PREMIUM').Inventory.FilteredTotal==1,'case insensitive inventory search')
 check(fetch('Crates',1,'%').Inventory.FilteredTotal==0,'search is literal, never a Lua pattern')
 check(fetch('Crates',10000,'').Inventory.Page==1,'page clamped after inventory changes')
 check(fetch('PointEffects').Inventory.Total==1,'effects restricted to owned catalog entries')
 local snapshot=copy(ownData);fetch('Slaps');check(same(snapshot,ownData),'reads cannot mutate ownership/equipment')
 for _,category in ipairs({'Titles','Abilities',tostring(bb.UserId),false})do check(not fetch(category).Ok,'reject unrecognized category/foreign user ID')end
 for _,page in ipairs({0,-1,.5,math.huge,0/0,'Slaps'})do clock+=.3;check(not Service:Inventory(aa,'Slaps',page,'').Ok,'invalid page rejected')end
 clock+=.3;check(not Service:Inventory(aa,'Slaps',1,string.rep('x',81)).Ok,'query length bounded')
 clock+=.3;check(not Service:Inventory(aa,'Slaps',1,{}).Ok,'query type bounded')
 fetch('Slaps');check(not Service:Inventory(aa,'Slaps',1,'').Ok,'reads share rate limit')
 clock+=.3;check(not Service:Inventory(table.clone(aa),'Slaps',1,'').Ok,'forged player rejected')
 active[aa]={Id='active'};check(not fetch('Slaps').Ok,'authoritative match state blocks reads');active[aa]=nil
 aa.Attributes.ResultsSessionId='results';check(not fetch('Slaps').Ok,'results state blocked');aa.Attributes.ResultsSessionId=nil
 ready=false;check(not fetch('Slaps').Ok,'unloaded profile blocked');ready=true
 local d={Inventory=inventory(aa.UserId)};local unit=copy(d.Inventory.SlapUnits[aa.UserId..':operation-1']);unit.UnitId='duplicate';d.Inventory.SlapUnits.duplicate=unit
 local grouped=Personal.Build(d,aa.UserId,catalog,'Slaps',{},products,1,'',100)
 local common;for _,row in grouped.Items do if row.ProductId=='Classic:Common'then common=row end end
 check(common and common.Quantity==2 and common.UnitId==nil,'duplicate units grouped for equip without exposing trade identity')
 check(#Public.Build(d,aa.UserId,catalog)==9,'trade projection still preserves all individual units')
 local page=Personal.Build(d,aa.UserId,catalog,'Slaps',{},products,1,'',2);check(#page.Items==2 and page.HasNext and page.Pages==4,'bounded inventory pagination')
 d.Inventory.Crates={};local empty=Personal.Build(d,aa.UserId,catalog,'Crates',{},products,1,'',24)
 check(empty.Total==0 and empty.Page==1 and not empty.HasNext,'empty crate inventory has stable metadata')
 -- Own profile routes to the separate controller; foreign collections retain read-only navigation.
 local opens=0;C.Context={GetController=function(_,name)if name=='InventoryController'then return {Open=function()opens+=1 end}end end}
 C.ProfileMode='SelfProfile';C.ProfileTarget=aa.UserId;C:SetArticlesMode(true);check(opens==1,'own profile links to independent inventory')
 C.ProfileMode='OtherPlayerProfile';C.ProfileTarget=bb.UserId;C:SetArticlesMode(true);check(opens==1,'foreign profile cannot invoke own equip inventory through its collection button')
 ownData=saved
 print('PASS StandaloneInventoryV1: '..(n-start)..' new assertions; total '..n)
end
