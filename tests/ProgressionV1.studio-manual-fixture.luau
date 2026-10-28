-- OPTIONAL: developer runs this in SERVER Command Bar during their own Studio test.
-- Unlocks the test pass to inspect claims/UI. DOES NOT validate earning EXP through gameplay.
local Run=game:GetService('RunService')
assert(Run:IsStudio()and Run:IsRunning(),'Studio test server required')
local progression=require(game.ServerScriptService.Services.ProgressionService)
local info=progression.Context and progression.Context.PersistenceInfo
assert(progression.Enabled and info and info.Environment=='Studio'and info.ProviderName=='InMemory'and info.WritesToCloud==false,'InMemory-only fixture')
local player=game.Players:GetPlayerByUserId(1522376993)
assert(player and progression.Context:GetService('AdminService'):IsAdmin(player),'Approved developer account required')
assert(not player:GetAttribute('MatchId')and not player:GetAttribute('ResultsSessionId'),'Lobby required')
assert(not progression.Context:GetService('ShopService'):IsTransactionInProgress(player),'Wait for pending transactions')
assert(progression:ReadSeason(),'Season unavailable')
local season=progression.Season.Active
local M=require(game.ReplicatedStorage.Shared.Progression.Model)
assert(M.Active(season,os.time())and season.StudioOnly,'Active test edition required')
local profiles=progression.Context:GetService('PlayerService')
assert(profiles:IsShopDataReady(player),'Profile not loaded')
local current=profiles._data[player];local nextData=M.Copy(current)
nextData.Progression=M.Normalize(nextData.Progression)
nextData.Progression.TotalXP=math.max(nextData.Progression.TotalXP,24000)
local edition=M.Edition(nextData.Progression,season);edition.XP=math.max(edition.XP,24000)
assert(profiles:CommitProgression(player,current,nextData),'Profile changed; no fixture applied')
progression:Push(player)
print('[ProgressionFixture] Test profile unlocked to stage 30 in InMemory; no rewards auto-claimed, no cloud access. Restart Play for a clean earning test.')
