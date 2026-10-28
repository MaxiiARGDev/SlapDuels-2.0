-- INPUT_ROWS is generated independently from the user's CSV by the spec composer.
local Matrix=loaded.InitialOdds;local Presentation=loaded.OddsPresentation
local mathCat={Variations={ById={}},Slaps={ById={Classic={DisplayName="Classic"}}},Rewards={}}
for _,vid in ipairs(Matrix.VariationOrder)do
 local variation=I.Copy(C.Variations.ById[vid]);variation.LimitedStock=false
 mathCat.Variations.ById[vid]=variation
 mathCat.Rewards["Classic:"..vid]={RewardId="Classic:"..vid,SlapId="Classic",VariationId=vid,DisplayName="Classic ["..vid.."]",LimitedStock=false}
end
local empty={Owned={Slaps={}}};local rng=8675309
local function randomUnit()rng=(1664525*rng+1013904223)%4294967296;return rng/4294967296 end
local allStats={};local draws=200000
for _,input in ipairs(INPUT_ROWS)do
 local crate=C.Crates.ById[input.Id];local sum=0
 check(crate.DuplicatePolicy=="UniquePerPlayer"and not crate.OddsApproved and not crate.Enabled and crate.PriceApproved,"Approvals and duplicate policy preserved "..input.Id)
 for i,vid in ipairs(Matrix.VariationOrder)do
  check(crate.Weights[vid]==input.Values[i]and crate.Weights[vid]>0,"Exact CSV weight "..input.Id..":"..vid)
  sum+=crate.Weights[vid]
 end
 check(math.abs(sum-100)<1e-10,"Original row sums100 "..input.Id)
 local rows=assert(O.Resolve(crate,mathCat,empty,S.new()))
 check(#rows==12,"Single Slap has12 eligible variations "..input.Id)
 local total=0;local seen={};local counts={}
 for _,row in ipairs(rows)do
  check(math.abs(row.Percent-crate.Weights[row.Reward.VariationId])<1e-10,"Reported probability matches original full catalog "..row.Reward.RewardId)
  local middle=total+row.Probability*.5
  check(O.Roll(rows,middle).RewardId==row.Reward.RewardId,"Tiny bucket selectable without rounding "..input.Id..":"..row.Reward.VariationId)
  total+=row.Probability;seen[row.Reward.RewardId]=row.Probability;counts[row.Reward.RewardId]=0
 end
 check(math.abs(total-1)<1e-12,"Resolved row normalized "..input.Id)
 for i=1,draws do local id=O.Roll(rows,randomUnit()).RewardId;counts[id]+=1 end
 for _,row in ipairs(rows)do
  local id=row.Reward.RewardId;local p=row.Probability;local expected=draws*p;local observed=counts[id]
  check(math.abs(observed-expected)<=7*math.sqrt(draws*p*(1-p))+2,"Seeded frequency within7sigma "..input.Id..":"..id)
  print(string.format("STATS|%s|%s|%d|%.12g|%d|%.12g",input.Id,id,draws,p,observed,observed/draws))
 end
end
check(C.Crates.ById.StudioTest.PriceCoins==1 and C.Crates.ById.StudioTest.Weights.Basic==3 and C.Crates.ById.StudioTest.Weights.Common==1,"StudioTest unchanged")
local basic=C.Crates.ById.Basic
local multi=I.Copy(mathCat);multi.Rewards["Future:Galaxy"]={RewardId="Future:Galaxy",SlapId="Future",VariationId="Galaxy",LimitedStock=false}
local rows=assert(O.Resolve(basic,multi,empty,S.new()));local galaxy=0
for _,row in ipairs(rows)do if row.Reward.VariationId=="Galaxy"then galaxy+=row.Percent;check(math.abs(row.Percent-.005)<1e-12,"Galaxy weight split across eligible Slaps")end end
check(math.abs(galaxy-.01)<1e-12,"Variation total preserved across multiple Slaps")
local owned={Owned={Slaps={["Classic:Galaxy"]=true}}}
rows=assert(O.Resolve(basic,multi,owned,S.new()))
for _,row in ipairs(rows)do if row.Reward.VariationId=="Galaxy"then check(row.Reward.SlapId=="Future"and math.abs(row.Percent-.01)<1e-12,"Owned reward excluded before candidate weight split")end end
local stock=S.new();local originalView=stock.View
function stock:View(reward,variation)
 if reward.VariationId=="Galaxy"then return {SoldOut=true,UnlimitedStock=false,RemainingStock=0}end
 return originalView(self,reward,variation)
end
local _,_,excluded
rows,_,excluded=O.Resolve(basic,mathCat,empty,stock)
check(#rows==11 and #excluded==1 and excluded[1].Reason=="SoldOut","Sold-out reward excluded and disclosed")
local normalized=0
for _,row in ipairs(rows)do normalized+=row.Percent;check(row.Reward.VariationId~="Galaxy"and math.abs(row.Percent-basic.Weights[row.Reward.VariationId]/99.99*100)<1e-10,"Sold-out distribution renormalized")end
check(math.abs(normalized-100)<1e-10,"Filtered sum100")
rows=assert(O.Resolve(basic,mathCat,empty,S.new(),function(reward)return reward.VariationId~="Galaxy"end))
check(#rows==11,"Variation with no eligible Slap is removed")
local allOwned={Owned={Slaps={}}};for id in pairs(mathCat.Rewards)do allOwned.Owned.Slaps[id]=true end
local none,reason=O.Resolve(basic,mathCat,allOwned,S.new())
check(not none and reason=="NoEligibleResults","No eligible results block resolution")
for _,bad in ipairs({-1,math.huge,0/0})do
 local invalid=I.Copy(basic);invalid.Weights.Galaxy=bad
 check(select(2,O.Resolve(invalid,mathCat,empty,S.new()))=="InvalidWeights","Invalid numeric weight rejected")
end
local invalid=I.Copy(basic);invalid.Weights.Unknown=1
check(select(2,O.Resolve(invalid,mathCat,empty,S.new()))=="InvalidWeights","Unknown variation rejected")
local approved=I.Copy(basic);approved.OddsApproved=true;approved.Enabled=true -- disposable mathematical fixture only
local profile=data(1000);profile.Inventory.Owned.Slaps={};profile.Inventory.Crates.Basic=1
local beforeCount=profile.Inventory.Crates.Basic
local noGrant,err=E.Stage(profile,approved,"Open","none",-99,mathCat,S.new(),.5,function()return false end)
check(not noGrant and err=="NoEligibleResults"and profile.Inventory.Crates.Basic==beforeCount,"Empty distribution never consumes crate")
local full=assert(O.Resolve(approved,mathCat,I.Extend(profile.Inventory),S.new()))
local unit=0;for _,row in ipairs(full)do
 local nextData,why,op=E.Stage(profile,approved,"Open","bucket-"..row.Reward.VariationId,-99,mathCat,S.new(),unit+row.Probability*.5)
 check(nextData and op.RewardId==row.Reward.RewardId,"Stage uses exact quoted distribution bucket "..row.Reward.VariationId)
 unit+=row.Probability
end
-- Actual review Quote exposes computed values but never enables payment or bypasses PolicyService.
service:Init(ctx);service._resource=function()return true end
pdata[a]=data(100000);pdata[a].Inventory.Owned.Slaps={}
policy.ArePaidRandomItemsRestricted=false
for _,id in ipairs(Matrix.VariationOrder)do
 local quote=service:Quote(a,id)
 check(quote.Ok and quote.ReviewOnly and not quote.PurchaseAllowed and #quote.Outcomes==11,"Read-only Studio review quote excludes owned default "..id)
 local sum=0;for _,row in ipairs(quote.Outcomes)do
  sum+=row.Percent;check(row.SlapName and row.VariationName and row.Color and row.Percent>0,"Authoritative presentation metadata")
  print(string.format("QUOTE|%s|%s|%.12g",id,row.RewardId,row.Percent))
 end
 check(math.abs(sum-100)<1e-10,"Quote effective sum100")
 local rejected=service:_transact(a,"Purchase",{CrateId=id,OperationId="blocked-"..id,QuoteToken=quote.Token,OddsApproved=true})
 check(not rejected.Ok and rejected.Code=="CommercialApprovalPending"and pdata[a].Coins==100000,"Review token cannot authorize commerce "..id)
end
policy.ArePaidRandomItemsRestricted=true
check(service:Quote(a,"Basic").Code=="PaidRandomItemsRestricted","Review does not bypass restricted policy")
policy.ArePaidRandomItemsRestricted=false;policyFailure=true
check(not service:Quote(a,"Basic").Ok,"Policy failure blocks review and purchase safely")
policyFailure=false
local quote=service:Quote(a,"Basic");local formatted=Presentation.Rows(quote)
check(#formatted==12 and formatted[1].RewardId=="Classic:Basic"and formatted[12].RewardId=="Classic:Galaxy"and formatted[1].Excluded,"Odds UI sorts by variation then reward, showing owned exclusion")
check(formatted[12].Text:find("0.025 %%")~=nil,"Small effective probability remains visible after owned-default renormalization")
check(Presentation.Rows({Outcomes={{RewardId="Classic:Galaxy",SlapId="Classic",VariationId="Galaxy",Percent=.01,Stock={UnlimitedStock=true}}}})[1].Text:find("0.01 %%")~=nil,"Original 0.01percent is never rounded away")
local list=node("ScrollingFrame","OddsList");local labels={};local template=node("TextLabel","RowTemplate")
function template:Clone()local l=node("TextLabel","Row");table.insert(labels,l);return l end
list.Children.RowTemplate=template;panel.Children.OddsList=list
extraEnv.Vector2={zero={}}
extraEnv.Enum.AutomaticSize={Y="Y"}
flow:_renderOdds(quote)
check(list.Visible and not panel.Outcomes.Visible and #labels==14,"Actual controller uses header + batch notice + 12 rows")
check(labels[1].Text:find("REVISIÓN",1,true)and labels[14].Text:find("0.025 %%")~=nil,"Review banner and tiny effective odds rendered without invented estimates")
panel.Children.OddsList=nil
print("PASS CrateOddsV13: "..assertions.." deterministic assertions; 2400000 isolated draws; gameplay/cloud NOT RUN")
