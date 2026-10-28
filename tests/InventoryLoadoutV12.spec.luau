-- Appended to established social fixtures. Real projection/handlers/controller; no Roblox execution.
do
 local startCount=n
 Service.Engine.Busy[aa.UserId]=nil;active[aa]=nil;ready=true
 local effects={PointEffects={{Id='Basic',Category='PointEffects',DisplayName='Punto básico',Rarity='Basic',IsAvailable=true},{Id='Fire',Category='PointEffects',DisplayName='Fuego',Rarity='Rare',IsAvailable=true},{Id='Missing',Category='PointEffects',DisplayName='Ausente',IsAvailable=false}},DeathEffects={{Id='BasicKill',Category='DeathEffects',DisplayName='Muerte básica',IsAvailable=true},{Id='Frost',Category='DeathEffects',DisplayName='Hielo',IsAvailable=true},{Id='Void',Category='DeathEffects',DisplayName='Vacío',IsAvailable=true}}}
 ownData.Inventory.Owned.PointEffects={Basic=true,Fire=true,Missing=true}
 ownData.Inventory.Owned.DeathEffects={BasicKill=true,Frost=true}
 ownData.Inventory.Equipped.PointEffects='Basic';ownData.Inventory.Equipped.DeathEffects='BasicKill'
 local shopCalls=0;local shop={}
 function shop:GetCatalog(category)return effects[category]or {}end
 function shop:EquipProduct(p,id,category)
  shopCalls+=1;check(p==aa,'authenticated caller is the only equip target')
  if id=='Missing'then return false,'ProductUnavailable'end
  ownData.Inventory.Equipped[category]=id;return true
 end
 Service.Context={GetService=function(_,name)return name=='ShopService'and shop or nil end}
 Service.Profiles.GetInventory=function(_,p)return p==aa and ownData.Inventory or data.Inventory end
 local function read(category,page)clock+=.3;return Service:SelfProfile(aa,page or 1,category)end
 local function equip(category,id,page)clock+=.3;return Service:Equip(aa,category,id,page)end
 local before=copy(ownData)
 local projected=read('PointEffects').Profile
 check(projected.Category=='PointEffects'and #projected.Inventory==3,'owned point effects in separate category')
 for _,item in ipairs(projected.Inventory)do check(not item.Tradable and item.UnitId==nil and item.Category=='PointEffects','effects never become trade units')end
 check(projected.EquippedLoadout.PointEffects.ProductId=='Basic'and projected.EquippedLoadout.DeathEffects.ProductId=='BasicKill','complete loadout independent of current category')
 check(projected.EquippedSlap.RewardId==ownData.Inventory.Equipped.Slaps,'slap summary stays global on effect tab')
 check(projected.Coins==nil and projected.Inventory.CrateOperations==nil,'public DTO remains private-data free')
 check(same(before,ownData),'projection does not mutate profile')
 check(#read('DeathEffects').Profile.Inventory==2,'unowned death effect omitted')
 check(read('PointEffects',999).Profile.Page==1,'effect category pages clamp against its own size')
 check(not read('Abilities').Ok and not read(false).Ok,'only three explicit inventory categories')
 local pointResult=equip('PointEffects','Fire');check(pointResult.Ok and ownData.Inventory.Equipped.PointEffects=='Fire','point equipped through Shop: '..tostring(pointResult.Reason))
 check(equip('DeathEffects','Frost').Profile.EquippedLoadout.DeathEffects.ProductId=='Frost','kill effect equipped and authoritative projection returned')
 check(equip('Slaps','Classic:Rare').Ok and ownData.Inventory.Equipped.Slaps=='Classic:Rare','slap preferred for gameplay')
 local beforeCalls=shopCalls
 check(not equip('DeathEffects','Void').Ok,'unowned rejected before Shop')
 check(not equip('Slaps','Frost').Ok,'cross-category ID rejected')
 check(not equip('Abilities','Dash').Ok,'other categories rejected')
 check(not equip('PointEffects',{}).Ok,'invalid identifier rejected')
 check(not equip('PointEffects','Fire',0).Ok,'invalid page rejected')
 check(shopCalls==beforeCalls,'invalid requests cannot reach mutator')
 check(not equip('PointEffects','Missing').Ok and ownData.Inventory.Equipped.PointEffects=='Fire','provider availability failure leaves selection')
 active[aa]={Id='match'};check(not equip('PointEffects','Basic').Ok,'server session blocks even without client attr');active[aa]=nil
 aa.Attributes.ResultsSessionId='result';check(not equip('PointEffects','Basic').Ok,'results blocked');aa.Attributes.ResultsSessionId=nil
 Service.Engine.Busy[aa.UserId]='trade';check(not equip('PointEffects','Basic').Ok,'trade locks equipment');Service.Engine.Busy[aa.UserId]=nil
 ready=false;check(not equip('PointEffects','Basic').Ok,'unloaded profile blocked');ready=true
 local originalParent=aa.Parent;aa.Parent=nil;check(not equip('PointEffects','Basic').Ok,'disconnected blocked');aa.Parent=originalParent
 clock+=.3;check(not Service:Equip(table.clone(aa),'PointEffects','Basic',1).Ok,'forged Player identity blocked')
 read('PointEffects');check(not Service:Equip(aa,'PointEffects','Basic',1).Ok,'rate limiting shared with reads')
 check(ownData.Coins==before.Coins and same(ownData.Inventory.Owned,before.Inventory.Owned)and same(ownData.Inventory.SlapUnits,before.Inventory.SlapUnits),'no spending, ownership or trade identity mutation')
 check(#Public.Build(ownData,aa.UserId,catalog)==7,'trade projection remains slap-only')
 local other=inspect(bb.UserId);check(other.Ok and other.Profile.ProfileMode=='OtherPlayerProfile','other profile stays inspect-only route')
 C.Generation+=1;profile.Enabled=true;C.ProfileMode='OtherPlayerProfile';C.ProfileTarget=bb.UserId;C.PendingProfile=false;C.PendingEquip=false
 local calls=0;C.Equip={InvokeServer=function(_,category,id,page)calls+=1;return equip(category,id,page)end}
 C:EquipItem({Category='PointEffects',ProductId='Basic'})
 check(calls==0,'foreign profile has no equip action')
 C.ProfileMode='SelfProfile';C.ProfileTarget=aa.UserId;C.ProfilePage=1
 C:EquipItem({Category='PointEffects',ProductId='Basic'})
 check(calls==1 and ownData.Inventory.Equipped.PointEffects=='Basic'and C.ProfileCategory=='PointEffects','client equips and refreshes same category from confirmed response')
 C:EquipItem({Category='PointEffects',ProductId='Basic',Equipped=true});check(calls==1,'equipped card no duplicate request')
 deferred=true;C:EquipItem({Category='DeathEffects',ProductId='BasicKill'})
 check(C.PendingEquip,'one pending equip')
 C:EquipItem({Category='PointEffects',ProductId='Fire'});check(#spawned==1,'click spam cannot create extra pending requests')
 local generation=C.Generation;C:Close(profile);deferred=false;table.remove(spawned,1)()
 check(C.Generation>generation and C.ProfileTarget==nil,'late confirmation cannot reopen closed profile')
 check(cfg.TradeCommitEnabled==false,'no enablement of real trade transfers')
 print('PASS InventoryLoadoutV12: '..(n-startCount)..' new assertions; gameplay NOT RUN')
end
