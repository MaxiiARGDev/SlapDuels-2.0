-- Real discovery, catalog, odds, stock and transaction staging, without Studio/cloud.
local count=0;local function check(v,label)assert(v,label);count+=1 end
local function load(name,env)local f=assert(loadstring(Sources[name],name));setfenv(f,setmetatable(env or {},{__index=getfenv()}));return f()end
local function obj(kind,name,children,attrs)
 local o={ClassName=kind,Name=name,Children=children or {},Attributes=attrs or {}}
 function o:GetChildren()return self.Children end
 function o:FindFirstChild(key)for _,v in ipairs(self.Children)do if v.Name==key then return v end end end
 function o:GetAttribute(key)return self.Attributes[key]end
 function o:IsA(class)return self.ClassName==class or class=='BasePart'and(self.ClassName=='MeshPart'or self.ClassName=='UnionOperation')end
 return o
end
local function tool(name,union)
 local power=obj('NumberValue','Power');power.Value=20
 local cd=obj('NumberValue','SlapCooldown');cd.Value=.6
 return obj('Tool',name,{obj(union and 'UnionOperation'or 'MeshPart','Hand'),obj('Configuration','Configuration',{power,cd})})
end
local variations=load('Crates/VariationDefinitions',{Color3={fromRGB=function(...)return {...}end}})
local discovery=load('SlapResourceRegistry')
local bases=obj('Folder','Slaps',{tool('Classic'),tool('Slap_Chancla'),tool('Slap_PingPong',true),obj('ModuleScript','NeverExecute')})
local folders={}
for _,id in ipairs({'Classic','Chancla','PingPong'})do local children={};for _,v in ipairs(variations)do table.insert(children,tool(v.Id,id=='PingPong'))end;table.insert(folders,obj('Folder',id,children))end
local variants=obj('Folder','SlapVariations',folders)
local models,diagnostics=discovery.Discover(bases,variants,variations)
check(#models==3 and #diagnostics==1,'three valid models, no execution of unknown source containers')
for _,m in ipairs(models)do check(#m.VariationIds==12,'all physical variants discovered');check(m.Templates.Gold~=nil,'physical Gold mapped')end
local duplicate=obj('Folder','Slaps',{tool('Classic'),tool('Slap_Classic')})
check(not pcall(discovery.Discover,duplicate,variants,variations),'canonical ID collisions rejected')
local dupVariant=obj('Folder','SlapVariations',{obj('Folder','Classic',{tool('Gold'),tool('Gold')})})
check(not pcall(discovery.Discover,bases,dupVariant,variations),'duplicate physical variants rejected')
local additional=obj('Folder','SlapVariations',{obj('Folder','Classic',{tool('Gold')}),obj('Folder','Hammer',{tool('Gold')})})
local extra=discovery.Discover(bases,additional,variations)
check(#extra==4,'variant-only model discovered without invented base')
local metadataChildren={}
for _,m in ipairs(models)do local markers={};for _,id in ipairs(m.VariationIds)do table.insert(markers,obj('Folder',id))end
 table.insert(metadataChildren,obj('Folder',m.SlapId,{obj('Folder','Variations',markers)},{Model=m.Model,DisplayName=m.DisplayName,VariantsFolder=m.VariantsFolder}))end
local metadata=obj('Folder','SlapCatalog',metadataChildren)
local rs=obj('ReplicatedStorage','ReplicatedStorage',{metadata})
local parent=setmetatable({},{__index=function(_,key)return 'Crates/'..key end})
rs.Shared={SlapCrates=parent}
local loaded={}
local function requireModule(key)
 if loaded[key]then return loaded[key]end
 local result=load(key,{script={Parent=parent},game={GetService=function(_,name)return name=='ReplicatedStorage'and rs or {IsRunning=function()return false end}end},Color3={fromRGB=function(...)return {...}end},require=requireModule})
 loaded[key]=result;return result
end
local catalog=requireModule('Crates/Catalog');local odds=requireModule('Crates/Odds');local invModule=requireModule('Crates/Inventory')
local stockClass=requireModule('Crates/InMemoryStock');local engine=requireModule('Crates/CrateEngine')
local rewards=0;for _ in pairs(catalog.Rewards)do rewards+=1 end
check(rewards==36 and #catalog.Slaps.Order==3,'shared catalog consumes physical metadata')
local inventory=invModule.Extend({});local allOwned=invModule.Copy(inventory)
for id in pairs(catalog.Rewards)do allOwned.Owned.Slaps[id]=true end
local order=requireModule('Crates/InitialOdds').VariationOrder
for index,id in ipairs(order)do
 local crate=catalog.Crates.ById[id]
 check(engine.Approved(crate)and crate.DuplicatePolicy=='AllowDuplicates','normal crate approved with duplicate units')
 local rows,why=odds.Resolve(crate,catalog,inventory,stockClass.new(),function()return true end)
 check(rows~=nil,'complete pool: '..tostring(why))
 local grouped={};local total=0
 for _,row in ipairs(rows)do grouped[row.Reward.VariationId]=(grouped[row.Reward.VariationId]or 0)+row.Percent;total+=row.Percent end
 check(math.abs(total-100)<1e-8,'normalized total')
 for j,vid in ipairs(order)do
  local expected=j==index and((index==1 or index==#order)and 80 or 60)or math.abs(j-index)==1 and 20 or 0
  check(math.abs((grouped[vid]or 0)-expected)<1e-8,'approved neighbour-only weight '..id..'/'..vid)
 end
 for _,row in ipairs(rows)do check(math.abs(row.Percent-grouped[row.Reward.VariationId]/3)<1e-8,'equal model odds within each tier')end
 local ownedRows=assert(odds.Resolve(crate,catalog,allOwned,stockClass.new(),function()return true end))
 check(#rows==#ownedRows,'ownership never removes duplicate outcomes')
 for j,row in ipairs(rows)do check(row.Percent==ownedRows[j].Percent,'ownership never changes percentages')end
 for _,roll in ipairs({0,.1,.5,.9,.999999})do local r=odds.Roll(rows,roll);check(r.VariationId==id or r.VariationId==order[index-1]or r.VariationId==order[index+1],'draw stays within approved tiers')end
end
local gold=catalog.Crates.ById.Gold
local missing,why=odds.Resolve(gold,catalog,inventory,stockClass.new(),function(r)return r.VariationId~='Gold'end)
check(missing==nil and why=='RequiredVariationUnavailable','missing target pool blocks without changing approved odds')
local reduced=assert(odds.Resolve(gold,catalog,inventory,stockClass.new(),function(r)return r.SlapId~='Chancla'end))
for _,row in ipairs(reduced)do check(math.abs(row.Percent-(row.Reward.VariationId=='Gold'and 30 or 10))<1e-8,'remaining models share unchanged tier weight')end
local data={Coins=100000,Inventory=invModule.Extend({})};local stock=stockClass.new()
for i=1,7 do data=assert(engine.Stage(data,gold,'Purchase','buy'..i,42,catalog,stock,.5,function()return true end,1))end
check(data.Coins==100000-7*4500 and data.Inventory.Crates.Gold==7,'purchase uses existing price and closed crate count')
local paid=data.Coins
data=assert(engine.Stage(data,gold,'Open','open1',42,catalog,stock,.5,function()return true end,1));check(engine.Reconcile(data,stock),'first reconcile')
data=assert(engine.Stage(data,gold,'Open','open2',42,catalog,stock,.5,function()return true end,1));check(engine.Reconcile(data,stock),'duplicate reconcile')
check(data.Inventory.SlapUnits['42:open1'].RewardId==data.Inventory.SlapUnits['42:open2'].RewardId,'same reward may be obtained twice')
check(data.Inventory.SlapUnits['42:open1'].UnitId~=data.Inventory.SlapUnits['42:open2'].UnitId,'duplicate prizes have independent identities')
check(data.Inventory.SlapUnits['42:open1'].VariationId=='Gold','deterministic target tier award')
local replay,err,op,replayed=engine.Stage(data,gold,'Open','open2',42,catalog,stock,.1,function()return true end,1)
check(replay==data and replayed and replay.Inventory.Crates.Gold==5,'replayed request never rerolls or consumes another crate')
data=assert(engine.Stage(data,gold,'Open','batch',42,catalog,stock,function()return .5 end,function()return true end,5))
check(engine.Reconcile(data,stock),'batch stock reconciliation')
local batch=data.Inventory.CrateOperations.batch
check(#batch.Rewards==5 and data.Inventory.Crates.Gold==0,'x5 grants five individual prizes')
local keys={};for _,r in ipairs(batch.Rewards)do check(not keys[r.UnitId]and r.VariationId=='Gold','batch duplicates remain unique units');keys[r.UnitId]=true end
check(data.Coins==paid,'opening never charges a second purchase')
check(not catalog.ProductionCommerceEnabled,'durable production gate unchanged')
for _,id in ipairs({'PremiumI','PremiumII','PremiumIII'})do check(not engine.Approved(catalog.Crates.ById[id]),'premium remains disabled')end
local inStudio=false;local lookups={}
local serverGame={GetService=function(_,name)
 lookups[name]=true
 if name=='ReplicatedStorage'then return rs elseif name=='RunService'then return {IsStudio=function()return inStudio end}
 elseif name=='HttpService'then return {}elseif name=='Players'or name=='ServerStorage'or name=='PolicyService'then return {}end
 error('Unexpected external dependency: '..name)
end}
local runtime=load('CrateService',{game=serverGame,script={Parent={Crates=parent}},require=requireModule,Random={new=function()return {NextNumber=function()return .5 end}end}})
local context={PersistenceInfo={Environment='Studio',ProviderName='InMemory',WritesToCloud=false}}
runtime:Init(context);check(runtime._stock==nil,'production never selects the Studio in-memory commerce backend')
local allowed,reason=runtime:_eligible({},gold);check(not allowed and reason=='ProductionBackendBlocked','production requests remain blocked before policy or mutation')
inStudio=true;runtime:Init(context);check(runtime._stock and runtime._stock.WritesToCloud==false,'Studio selects isolated stock only')
context.PersistenceInfo.WritesToCloud=true;runtime:Init(context);check(runtime._stock==nil,'Studio rejects cloud-writing persistence selection')
check(not lookups.DataStoreService,'no real DataStore dependency accessed')
print('PASS CrateTiersV3: '..count..' isolated assertions; gameplay/cloud NOT RUN')
