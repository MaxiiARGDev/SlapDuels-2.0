assert(not game:GetService('RunService'):IsRunning(),'Edit only')
local module=game.ServerScriptService.Services.PlayerDataService:Clone();module.Name='__ProgressionPersistence';module.Parent=game.ServerScriptService.Services
local checks=0
local function check(v,m)assert(v,m);checks+=1 end
local ok,result=xpcall(function()
 local PDS=require(module)
 local M=require(game.ReplicatedStorage.Shared.Progression.Model)
 local store=require(game.ServerScriptService.Services.Persistence.InMemoryDataStore).new()
 local fake={Name='ProgressionUnit',UserId=-9191,IsA=function(_,class)return class=='Player'end}
 PDS._store=store;PDS._loadStates={[fake]='Loaded'};PDS._saving={};PDS._persistenceInfo={Environment='Studio',ProviderName='InMemory',WritesToCloud=false}
 local raw={Version=2,Coins=83,Wins=4,Losses=2,Kills=9,WinStreak={Total=1,Progress=1},Inventory={Owned={PointEffects={Basic=true},DeathEffects={BasicKill=true},Slaps={['Classic:Basic']=true}},Equipped={Slaps='Classic:Basic'},SlapUnits={}}}
 local valid,old=PDS:ValidatePlayerData(raw)
 check(valid and old.Progression.TotalXP==0,'Old profile migrates additively')
 check(old.Coins==83 and old.Wins==4 and old.Kills==9 and old.Inventory.Owned.Slaps['Classic:Basic'],'Migration preserves economy/inventory')
 local data=M.Copy(old);data.Progression={Schema=1,TotalXP=2450,Receipts={M1={StartedAt=100,XP=100,PassXP=100}},ReceiptOrder={'M1'},Watermark=0,Edition={Id='FrozenEdition',XP=1600,Claimed={['1']=true}}}
 check(PDS:SavePlayer(fake,data),'Actual SavePlayer using independent InMemory adapter')
 local persisted=store:GetAsync('Player_-9191')
 check(persisted.Progression.TotalXP==2450 and persisted.Progression.Edition.XP==1600,'Both XP persisted')
 check(persisted.Progression.Edition.Claimed['1']==true,'Claim marker persisted')
 check(persisted.Progression.Receipts.M1~=nil,'Idempotence receipt persisted')
 local loaded,recovered=PDS:ValidatePlayerData(persisted)
 check(loaded and recovered.Progression.TotalXP==2450,'Reload retains permanent progression')
 check(recovered.Progression.Edition.Id=='FrozenEdition'and recovered.Progression.Edition.Claimed['1'],'Reload retains edition/claim')
 check(recovered.Inventory.Equipped.Slaps=='Classic:Basic'and recovered.Coins==83,'Reload retains existing loadout/economy')
 PDS._loadStates[fake]='Failed'
 local saved,reason=PDS:SavePlayer(fake,data);check(not saved and reason=='DataNotLoaded','Failed profile cannot save progression')
 check(store:GetDiagnostics().WritesToCloud==false and store:GetDiagnostics().CommittedWrites==1,'Exactly one isolated save; no cloud')
 return {Assertions=checks,Scope='Actual PlayerDataService validation/save/reload with fake identity and separate InMemory adapter; no Init/Start/BindToClose'}
end,debug.traceback)
module:Destroy();if not ok then error(result)end;return result
