local count=0;local function check(v,m)assert(v,m);count+=1 end
local function load(name,env)local f=assert(loadstring(Sources[name],name));setfenv(f,setmetatable(env or {},{__index=getfenv()}));return f()end
local stackClass=load('WindowStack');local top
local s=stackClass.new(function(id)top=id end)
s:Push('Shop');s:Push('Crate');s:Push('Admin');check(top=='Admin'and #s.Order==3,'push covers existing windows')
s:Remove('Admin');check(top=='Crate','back to direct parent')
s:Remove('Crate');check(top=='Shop','back to original window')
s:Push('Shop');check(#s.Order==1,'no duplicate stack entries')
s:Push('Crate');s:Remove('Shop');s:Remove('Crate');check(top==nil,'closed covered windows never resurrect')
s:Push('Profile');s:Clear();check(top==nil and #s.Order==0,'gameplay reset clears history')
local deferred={}
local function signal()local x={Listeners={}};function x:Connect(fn)table.insert(self.Listeners,fn);return {Disconnect=function()end}end;return x end
local function object()
 local values={Visible=false};local changed=signal()
 local methods={Parent={FindFirstChild=function()return nil end},GetPropertyChangedSignal=function()return changed end}
 return setmetatable({}, {__index=function(_,k)return methods[k]or values[k]end,__newindex=function(_,k,v)if values[k]~=v then values[k]=v;table.insert(deferred,function()for _,fn in ipairs(changed.Listeners)do fn()end end)end end})
end
local function flush()local n=0;while #deferred>0 do n+=1;assert(n<100,'property feedback loop');table.remove(deferred,1)()end end
local allowedAdmin=true;local navClock=0
local localPlayer={GetAttribute=function()return allowedAdmin end}
local nav=load('WindowNavigation',{game={GetService=function()return {LocalPlayer=localPlayer}end},workspace={GetServerTimeNow=function()return navClock end},script={Parent={Parent={UI={WindowStack='Stack'}}}},require=function()return stackClass end})
nav:Init();local shop,crate,profile=object(),object(),object()
nav:Watch('Shop',shop,'Visible');nav:Watch('Crate',crate,'Visible');nav:Watch('Profile',profile,'Visible')
shop.Visible=true;flush();check(shop.Visible and not crate.Visible,'one top window')
crate.Visible=true;flush();check(crate.Visible and not shop.Visible and #nav.Stack.Order==2,'deferred internal hide retains previous page')
profile.Visible=true;flush();check(profile.Visible and not crate.Visible and #nav.Stack.Order==3,'three levels with deferred signals')
profile.Visible=false;flush();check(crate.Visible and not profile.Visible,'external close restores covered page')
crate.Visible=false;flush();check(shop.Visible and #nav.Stack.Order==1,'multiple back transitions')
crate.Visible=true;flush();nav:Forget('Shop');crate.Visible=false;flush();check(#nav.Stack.Order==0 and not shop.Visible,'explicit forget handles covered logical closes')
shop.Visible=true;flush();crate.Visible=true;flush();nav.Stack:Clear();flush();check(not shop.Visible and not crate.Visible and #nav.Stack.Order==0,'deferred reset cannot reopen windows')
local admin=object();nav:Watch('Admin',admin,'Visible');admin.Visible=true;flush();crate.Visible=true;flush();allowedAdmin=false;crate.Visible=false;flush()
check(not admin.Visible and #nav.Stack.Order==0,'covered admin panel is not restored after permission revocation')
local social=object();local request={ExpiresAt=1};nav.Context={GetController=function()return {Request=request}end};nav:Watch('SocialRequest',social,'Visible')
social.Visible=true;flush();crate.Visible=true;flush();request=nil;navClock=2;crate.Visible=false;flush()
check(not social.Visible and #nav.Stack.Order==0,'expired covered invitation does not reappear')
local labels=load('CrateOddsLabels')
check(labels.Percent(20)=='20 %','integer odds')
check(labels.Percent(6.6666666667)=='≈ 7 %','rounding explicitly approximate')
check(labels.Percent(.01)=='<1 %','tiny probabilities not falsely shown as zero')
check(labels.Chance(20)=='Probabilidad alta'and labels.Chance(6.67)=='Probabilidad media','plain chance labels')
check(labels.Chance(1)=='Probabilidad baja'and labels.Chance(.1)=='Probabilidad muy baja','low chance labels')
local visual=load('CrateRewardGallery',{game={GetService=function()return {}end},script={Parent={CrateOddsLabels='Labels'}},require=function()return labels end})
local released=0;local row={Model={GetDescendants=function()return {{IsA=function(_,name)return name=='ParticleEmitter'end,Clear=function()released+=1 end}}end,Destroy=function()released+=1 end},Back={Destroy=function()released+=1 end}}
visual.Release({},row);check(released==3 and row.Model==nil and row.Back==nil,'hiding previews clears particles and destroys model/backdrop')
visual.Release({},row);check(released==3,'visual cleanup idempotent')
local state={Quantity=7,CoinsText='10000',PriceText='4500 Coins',BuyEnabled=true,OpenEnabled=true,NeedQuote=false}
local keys=setmetatable({},{__index=function(_,k)return k end});local calls,queue,delayed={},{},{}
local currentCatalog={Crates={ById={Gold={RollDuration=5}}},Rewards={}}
local dependencies={Catalog=currentCatalog,Appearance={},CrateShopView={State=function()return table.clone(state)end,Errors={NoResponse='Sin respuesta'}},OddsPresentation={},OpeningConfig={AllowedOpenQuantities={1,5,10},Mode='StandCinematic'},BatchOpening={},CrateRewardGallery={},ShopLayout={}}
local C=load('CrateController',{game={GetService=function(_,name)return name=='ReplicatedStorage'and {Shared={SlapCrates=keys}}or name=='HttpService'and {GenerateGUID=function()return 'one-operation-id'end}or {}end},script={Parent={Parent={UI={ShopLayout='ShopLayout'},CrateOpening={CrateRewardGallery='CrateRewardGallery'}}}},require=function(name)return assert(dependencies[name],name)end,workspace={GetServerTimeNow=function()return 0 end},task={spawn=function(fn)fn()end,delay=function(_,fn)table.insert(delayed,fn)end}})
C:Init({GetController=function()return nil end});C._products.Gold={Id='Gold'};C._crateId='Gold'
local p={Count={},Status={},Buy={},Open={Visible=true},ViewOdds={Visible=true},Receipt={Visible=true},Price={},Outcomes={},OpenActions={X1={},X5={},X10={}}}
function p:FindFirstChild()return nil end
C._panel=p;C._quote={Token='approved'};C._quoteCache.Gold=C._quote
C._request={InvokeServer=function(_,action,args)table.insert(calls,{Action=action,Args=table.clone(args)});return table.remove(queue,1)end}
C:_renderPanel()
check(p.Buy.Text=='COMPRAR'and p.OpenActions.X1.Text=='ABRIR x1'and p.OpenActions.X5.Text=='ABRIR x5'and p.OpenActions.X10.Text=='ABRIR x10','four primary labels')
check(not p.Open.Visible and not p.ViewOdds.Visible and not p.Receipt.Visible,'obsolete controls hidden')
check(p.OpenActions.X1.Active and p.OpenActions.X5.Active and not p.OpenActions.X10.Active,'quantities independently validated against owned crates')
table.insert(queue,{Ok=false,Code='NoResponse'});C._openQuantity=5;C:_mutate('Open')
check(#calls==1 and calls[1].Args.Quantity==5,'one click sends requested quantity')
check(C._pendingAction~=nil and p.OpenActions.X5.Active and not p.OpenActions.X1.Active and not p.Buy.Active,'unknown outcome allows same-quantity retry only')
C:_mutate('Purchase');check(#calls==1,'unconfirmed operation blocks a new purchase')
table.insert(queue,{Ok=true,Operation={UnitId='unit'},Presentation={Mode='StandCinematic'}});C:_mutate('Open')
check(#calls==2 and calls[2].Args.OperationId==calls[1].Args.OperationId and calls[2].Args.Quantity==5,'retry preserves operation ID and original quantity')
check(C._pendingAction==nil and C._quote==nil,'confirmed opening clears pending operation and refreshes quote')
check(#delayed>0,'automatic refresh scheduled without a View Odds button')
print('PASS ShopUnifiedV1: '..count..' isolated assertions; visual/render/gameplay NOT RUN')

-- Re-rendering snapshots must not clear the current quote or issue another request.
C._panel.Visible=true;C._request={};C._quote={Token='keep'};C._quoteCache.Gold=C._quote
local version=C._selectionVersion
C:ShowCrate('Gold',true)
check(C._selectionVersion==version and C._quote.Token=='keep','same embedded selection preserves quote')
C._products.Basic={Id='Basic'};C._pendingAction={CrateId='Gold'}
C:ShowCrate('Basic',true)
check(C._crateId=='Gold','pending transaction prevents crate substitution')
C._pendingAction=nil;C._busy=true;C:ShowCrate('Basic',true)
check(C._crateId=='Gold','busy transaction prevents crate substitution')
print('PASS ShopUnifiedV1 total: '..count..' assertions')
