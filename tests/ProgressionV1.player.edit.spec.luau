assert(not game:GetService('RunService'):IsRunning(),'Edit only')
local module=game.ServerScriptService.Services.PlayerService:Clone();module.Name='__ProgressionPlayerUnit';module.Parent=game.ServerScriptService.Services
local fake={Name='ProgressionUnit',UserId=-9191}
local count=0
local function check(v,m)assert(v,m);count+=1 end
local ok,result=xpcall(function()
 local ps=require(module)
 local M=require(game.ReplicatedStorage.Shared.Progression.Model)
 ps._getDataUpdatedRemote=function()return nil end -- No network dispatch during isolated tests.
 ps.IsShopDataReady=function(_,p)return p==fake end
 local data={Coins=150,Wins=2,Losses=1,Kills=3,Progression={TotalXP=800},Inventory={Owned={PointEffects={Basic=true}},Equipped={}}}
 ps._data[fake]=data
 local dto=ps:GetPlayerData(fake);check(dto.Progression.TotalXP==800,'Actual public snapshot carries XP')
 local nextData=M.Copy(data);nextData.Progression.TotalXP=24000;nextData.Coins=300
 check(ps:CommitProgression(fake,data,nextData),'Actual runtime commit')
 check(ps:GetPlayerData(fake).Progression.TotalXP==24000 and ps:GetCoins(fake)==300,'XP and Coins move together')
 check(M.Level(ps:GetPlayerData(fake).Progression.TotalXP)==40,'Actual snapshot derives expected permanent level')
 check(ps:GetPlayerData(fake).Wins==2 and ps:GetPlayerData(fake).Kills==3,'Existing statistics intact')
 check(not ps:CommitProgression(fake,data,nextData),'Stale snapshot cannot overwrite newer profile')
 check(fake.Parent==nil,'Test identity never joined Players/DataModel')
 return {Assertions=count,Scope='Actual PlayerService commit/snapshot with fake table identity, network disabled; real Player attribute replication NOT RUN'}
end,debug.traceback)
module:Destroy();if not ok then error(result)end;return result
