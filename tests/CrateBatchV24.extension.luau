-- Current defaults, actual service/engine/stock. All profiles and Players are offline fixtures.
local actual=load("OpeningConfig")
check(actual.Stand.ExclusiveOpening==false and actual.Stand.ReopenCooldown==0,"Private default and zero cooldown")
local actualPlan=assert(timeline.Build(actual,10));check(actualPlan.Duration==12.5 and actualPlan.Duration<actual.Stand.MaxSequenceDuration,"Batch duration within safety cap")
local rules=loaded.BatchOpening
for _,q in ipairs({1,5,10})do check(rules.Quantity(q)==q,"Allowed quantity "..q)end
for _,q in ipairs({0,-1,2,4,7,11,math.huge,0/0,"5",false,{}})do check(not rules.Quantity(q),"Invalid quantity rejected")end
local ledger=Ledger.new(actual,actualPlan,function()return 500 end)
local la=assert(ledger:Acquire(-1,"Main","a",actualPlan));local lb=assert(ledger:Acquire(-2,"Main","b",actualPlan))
check(la~=lb and next(ledger.Stands)==nil,"Two buyers no global stand lease")
check(not ledger:Acquire(-1,"Main","incompatible"),"Same buyer cannot overlap operations")
ledger:Commit(la,"-1:a");ledger:Release(-1);check(ledger:Acquire(-1,"Main","immediate")~=nil,"Immediate reopen after completion")
service:Init(ctx);service._resource=function()return true end
service._stands=load("StandOpeningService").new(service)
service._stands.Remote=node("RemoteEvent","StandPresentation")
local calls=0;service._rng={NextNumber=function()calls+=1;return if calls%2==0 then .99 else .1 end}
pdata[a]=data(100);pdata[b]=data(100)
pdata[a].Inventory.Crates.StudioTest=40;pdata[b].Inventory.Crates.StudioTest=30
local function openBatch(player,quantity,id,token)
 local quote=if token then {Token=token}else service:Quote(player,"StudioTest")
 local args={CrateId="StudioTest",Quantity=quantity,OperationId=id,StandId="Main",QuoteToken=quote.Token}
 return service._stands:Open(player,args,function()return service:_transact(player,"Open",args)end),args
end
local messages=#objects
local first,args=openBatch(a,10,"tenA")
local second=openBatch(b,10,"tenB")
check(first.Ok and second.Ok,"Two players x10 simultaneously active")
check(pdata[a].Inventory.Crates.StudioTest==30 and pdata[b].Inventory.Crates.StudioTest==20,"Exact10 consumption each")
check(#first.Operation.Rewards==10 and #second.Operation.Rewards==10,"Exact10 rewards each")
check(first.Operation.BatchId~=second.Operation.BatchId and calls==20,"Independent opening identity and independent draws")
check(first.Operation.Rewards[1].RewardId~=first.Operation.Rewards[2].RewardId,"Batch does not copy a single random result")
for _,unit in ipairs(first.Operation.Rewards)do
 check(unit.EffectivePercent==(if unit.VariationId=="Basic"then 75 else 25),"Receipt carries exact draw-time effective percent")
end
check(#first.Operation.PreviewRewardIds==2,"Receipt eligible previews snapshot")
check(pdata[a].Coins==100 and pdata[b].Coins==100,"Open never buys or charges Coins")
check(next(service._stands.Ledger.Stands)==nil,"No global busy flag")
local packets=0
for i=messages+1,#objects do local event=objects[i]
 if event.Name=="StandPresentation"and event.Packet.Kind=="Opening"then
  packets+=1;check(event.Player.UserId==event.Packet.BuyerUserId and not event.Packet.Exclusive,"Private packet only to buyer")
  check(#event.Packet.Operation.Rewards==10 and event.Packet.Duration==12.5,"Exact batch packet and authoritative duration")
 end
end
check(packets==2,"No observer opening packets")
local replay=openBatch(a,10,"tenA","expired-token")
check(replay.Ok and replay.Replay and pdata[a].Inventory.Crates.StudioTest==30 and calls==20,"Retry is exact receipt, no reroll/consume")
local conflict=openBatch(a,5,"newWhileActive")
check(not conflict.Ok and conflict.Code=="OpeningInProgress","Different request blocked during cinematic")
service._stands:Release(a.UserId,"Completed");service._stands:Release(b.UserId,"Disconnected")
local five=openBatch(a,5,"fiveA");check(five.Ok and #five.Operation.Rewards==5 and pdata[a].Inventory.Crates.StudioTest==25,"Exact5 immediately after prior batch")
service._stands:Release(a.UserId,"Completed")
local one=openBatch(a,1,"oneA");check(one.Ok and not one.Operation.Rewards and pdata[a].Inventory.Crates.StudioTest==24,"x1 retains original operation contract")
check(one.Operation.EffectivePercent==(if one.Operation.VariationId=="Basic"then 75 else 25)and #one.Operation.PreviewRewardIds==2,"x1 metadata survives staging and authoritative commit")
service._stands:Release(a.UserId,"Completed")
local before=pdata[a]
local poor=I.Copy(before);poor.Inventory.Crates.StudioTest=4;pdata[a]=poor
local insufficient=openBatch(a,5,"short")
check(not insufficient.Ok and insufficient.Code=="InsufficientCrates"and pdata[a]==poor and poor.Inventory.Crates.StudioTest==4,"Insufficient inventory consumes nothing")
pdata[a]=before
local changed=openBatch(a,5,"tenA","ignored")
check(not changed.Ok and changed.Code=="OperationConflict","Same ID cannot change quantity")
-- Profile failure releases every pre-grant reservation and leaves original profile untouched.
ps.Fail=true;local pre=pdata[a];local failed=openBatch(a,5,"profileFail");ps.Fail=false
check(not failed.Ok and pdata[a]==pre,"Profile failure leaves all boxes and rewards untouched")
for index=1,5 do check(service._stock.State.Operations["-1:profileFail:"..index].State=="Released","All failed profile reservations released")end
-- A stock confirmation failure after the single profile commit retains ALL grants and reservations.
local realCommit=service._stock.Commit;local once=true
service._stock.Commit=function(self,id)if once then once=false;return false,"Injected"end;return realCommit(self,id)end
local oldCount=pdata[a].Inventory.Crates.StudioTest;local previousCalls=calls
local pending=openBatch(a,5,"recover")
check(not pending.Ok and pending.Code=="StockCommitPending","Ambiguous stock confirmation is recoverable, not a new transaction")
check(pdata[a].Inventory.Crates.StudioTest==oldCount-5 and #pending.Operation.Rewards==5,"All5 grants committed together before stock retry")
service._stock.Commit=realCommit
local recovered=openBatch(a,5,"recover","old-token")
check(recovered.Ok and recovered.Replay and recovered.Operation.State=="Completed","Retry completes original batch")
check(calls==previousCalls+5 and pdata[a].Inventory.Crates.StudioTest==oldCount-5,"Recovery never rerolls or consumes twice")
service._stands:Release(a.UserId,"Completed")
local sent=#objects;local again=openBatch(a,5,"recover","irrelevant")
check(again.Ok and again.Replay and #objects==sent,"Recovered receipt cannot replay presentation again")
-- Commit throws after writing profile: treat confirmed identity as committed, never release awarded stock.
local originalCommit=ps.CommitCrateState
ps.CommitCrateState=function(self,p,expected,nextData)local ok,why=originalCommit(self,p,expected,nextData);if ok then error("Injected after profile write")end;return ok,why end
local afterWrite=openBatch(a,5,"afterWrite");ps.CommitCrateState=originalCommit
check(afterWrite.Ok and #afterWrite.Operation.Rewards==5,"Ambiguous profile success recovered by authoritative identity")
for _,unit in ipairs(afterWrite.Operation.Rewards)do check(service._stock.State.Operations[unit.UnitId].State=="Issued","Awarded stock never released after profile success")end
service._stands:Release(a.UserId,"Completed")
for _,q in ipairs({0,2,7,"10",math.huge})do
 service._rate[a]=nil
 local invalid=service:Request(a,"Open",{CrateId="StudioTest",Quantity=q,OperationId="invalidQuantity",StandId="Main"})
 check(not invalid.Ok and invalid.Code=="InvalidQuantity","Actual remote rejects forged quantity")
end
local rate=service:Request(a,"OpeningContext",{})
check(not rate.Ok and rate.Code=="RateLimited","Anti-spam rate protection survives cooldown removal")
local cancelResult=openBatch(a,1,"cancelOwn")
local current=pdata[a];local cancel=service:Request(a,"CancelOpening",{OpeningId=cancelResult.Operation.UnitId})
check(cancel.Ok and not service._stands.Active[a.UserId]and pdata[a]==current,"Cancel releases own visual lease without undoing grant")
local following=openBatch(a,1,"afterCancel")
service._cancelRate[a]=nil
local late=service:Request(a,"CancelOpening",{OpeningId=cancelResult.Operation.UnitId})
check(not late.Ok and service._stands.Active[a.UserId].Packet.OpeningId==following.Operation.UnitId,"Late cancel cannot close newer opening")
service._cancelRate[b]=nil
service:Request(b,"CancelOpening",{OpeningId=following.Operation.UnitId})
check(service._stands.Active[a.UserId]~=nil,"Other player cannot cancel buyer opening")
service._stands:Release(a.UserId,"Completed")
-- Unique policy recomputes eligibility within one batch, without altering real definitions.
local unique=I.Copy(crate);unique.DuplicatePolicy="UniquePerPlayer";unique.Weights={}
for _,id in ipairs(C.Variations.Order)do unique.Weights[id]=1 end
local ud=data(10);ud.Inventory.Crates.StudioTest=16;local us=S.new()
local granted,why,operation=E.Stage(ud,unique,"Open","unique10",-50,C,us,function()return 0 end,nil,10)
check(granted and #operation.Rewards==10 and ud.Inventory.Crates.StudioTest==16,"Unique10 staged without mutating original")
local seen={};for _,unit in ipairs(operation.Rewards)do check(not seen[unit.RewardId],"No duplicate within unique batch");seen[unit.RewardId]=true end
for i,unit in ipairs(operation.Rewards)do check(math.abs(unit.EffectivePercent-100/(12-i))<1e-7,"Batch metadata captures conditional odds before each unique draw")end
E.Reconcile(granted,us)
local impossible,reason=E.Stage(granted,unique,"Open","notEnoughEligible",-50,C,us,function()return 0 end,nil,5)
check(not impossible and reason=="NoEligibleResults"and granted.Inventory.Crates.StudioTest==6,"Whole batch rejected when only one result remains")
for id,allocation in pairs(us.State.Operations)do if id:find("notEnoughEligible",1,true)then check(allocation.State=="Released","Failed unique batch releases staged last prize")end end
local last=assert(E.Stage(granted,unique,"Open","last",-50,C,us,0,nil,1))
check(not E.Stage(last,unique,"Open","empty",-50,C,us,0,nil,1),"Last eligible prize cannot be duplicated")
-- Exhausted limited stock halfway through a batch: zero profile mutation and no negative stock.
local limited=I.Copy(C);local reward=limited.Rewards["Classic:Common"]
reward.LimitedStock=true;reward.TotalSupply=3;reward.EditionId="batch-offline-only"
local limitedCrate=I.Copy(crate);limitedCrate.Weights={Common=1}
local ld=data(10);ld.Inventory.Crates.StudioTest=10;local ls=S.new()
local aborted,code=E.Stage(ld,limitedCrate,"Open","limited",-60,limited,ls,function()return .5 end,nil,5)
check(not aborted and code=="NoEligibleResults"and ld.Inventory.Crates.StudioTest==10,"Limited3 cannot partially satisfy x5")
local view=assert(ls:View(reward,limited.Variations.ById.Common))
check(view.RemainingStock==3 and view.IssuedCount==0,"All limited reservations rolled back")
reward.TotalSupply=15;local sharedStock={Buckets={},Operations={}};local sa,sb=S.new(sharedStock),S.new(sharedStock)
local da,db=data(10),data(10);da.Inventory.Crates.StudioTest=10;db.Inventory.Crates.StudioTest=10
local wa=assert(E.Stage(da,limitedCrate,"Open","competingA",-71,limited,sa,function()return .5 end,nil,10))
local wb=E.Stage(db,limitedCrate,"Open","competingB10",-72,limited,sb,function()return .5 end,nil,10)
check(not wb and db.Inventory.Crates.StudioTest==10,"Competing x10 sees reservations and cannot oversell remaining5")
E.Reconcile(wa,sa)
wb=assert(E.Stage(db,limitedCrate,"Open","competingB5",-72,limited,sb,function()return .5 end,nil,5));E.Reconcile(wb,sb)
check(sa:View(reward,limited.Variations.ById.Common).RemainingStock==0 and wb.Inventory.Crates.StudioTest==5,"Shared final stock issued exactly15 without negatives")
-- Inject a failure after Reserve allocated a unit; rollback still finds that identity.
local fs=S.new();local reserve=fs.Reserve;local attempts=0
fs.Reserve=function(self,...)attempts+=1;local ok,why=reserve(self,...);if attempts==3 then error("Injected reserve fault")end;return ok,why end
local broken=E.Stage(ld,crate,"Open","reserveCrash",-60,C,fs,function()return .5 end,nil,5)
check(not broken and ld.Inventory.Crates.StudioTest==10,"Staging error before consume is safe")
for _,allocation in pairs(fs.State.Operations)do check(allocation.State=="Released","Thrown reserve rolls back allocated units")end
-- Actual quantity selection state; request carries immutable quantity and operation id on retries.
flow._context={GetController=function()return nil end};flow._busy=false;flow._quoting=false;flow._pendingAction=nil
flow._data={Coins=100,Inventory={Crates={StudioTest=5}}};flow._openQuantity=10
local product=service:GetCatalog()[13]
for _,p in ipairs(service:GetCatalog())do if p.Id=="StudioTest"then product=p end end
flow._quoteCache.StudioTest=service:Quote(a,"StudioTest")
check(not flow:GetView(product).OpenEnabled,"Client cannot open10 with only5")
flow._openQuantity=5;check(flow:GetView(product).OpenEnabled,"Client permits exact owned5")
-- Pure layout/frustum bounds at portrait, landscape and ultrawide.
local layout=loaded.RewardGalleryLayout;local gc=loaded.CinematicConfig.Gallery
for _,q in ipairs({5,10})do for _,aspect in ipairs({.45,.5625,1,16/9,2.4})do
 local result=layout.Build(q,aspect,35,gc);check(#result.Positions==q,"Exact gallery slots")
 local width=result.Distance*math.tan(math.rad(35)/2)*aspect;local height=result.Distance*math.tan(math.rad(35)/2)
 for _,point in ipairs(result.Positions)do check(math.abs(point.X)+gc.Spacing/2<=width and math.abs(point.Y)+gc.RowSpacing/2<=height,"Reward fits conservative frustum")end
end end
check(C.Crates.ById.StudioTest.PriceCoins==1 and not E.Approved(C.Crates.ById.Basic),"Studio price and commercial gates preserved")
print("PASS CrateBatchV24: "..assertions.." combined isolated assertions; real multiplayer/visual NOT RUN")
