-- Real controller presentation + native GUI clones, no Play or persistence.
assert(not game:GetService('RunService'):IsRunning(),'Edit required')
local module=game.StarterPlayer.StarterPlayerScripts.Controllers.BattlePassController:Clone()
module.Source=module.Source:gsub('local player=Players.LocalPlayer','local player={UserId=123}')
local clone=game.StarterGui.ProgressionHUD:Clone()
local profile=game.StarterGui.PlayerProfileHUD:Clone()
local ok,result=pcall(function()
 local c=require(module);local now=workspace:GetServerTimeNow()
 local s={Level=5,LevelXP=250,LevelCost=300,PassXP=3000,Stage=3,Active=true,Claimed={['1']=true},Season={EndsAt=now+600,Stages=30,StageXP=800,Rewards={}}}
 for i=1,30 do s.Season.Rewards[i]={Label='Premio '..i}end
 local v=c:ProgressView(s,now)
 assert(v.PlayerRatio==250/300 and v.PlayerXP=='250 / 300 EXP','Permanent level uses its own cost')
 assert(v.PassRatio==.75 and v.PassXP=='600 / 800 EXP DEL PASE','Pass uses XP within current stage')
 assert(v.Reward=='Próximo: Premio 4'and v.Pending==2,'Next prize and unclaimed rewards')
 c:PaintProgress(clone.ProgressCards,s)
 assert(math.abs(clone.ProgressCards.Pass.Track.Fill.Size.X.Scale-.75)<.0001,'Actual gold fill')
 assert(clone.ProgressCards.Pass.Open.Text=='VER PASE · 2 POR RECLAMAR','Claim shortcut')
 s.PassXP=3200;s.Stage=4;v=c:ProgressView(s,now)
 assert(v.PassRatio==0 and v.Reward=='Próximo: Premio 5','Exact boundary advances to next prize')
 s.Stage=30;s.PassXP=30000;v=c:ProgressView(s,now)
 assert(v.PassRatio==1 and v.PassTitle=='PASE · COMPLETADO','Completion caps visual progress')
 s.Active=false;v=c:ProgressView(s,now)
 assert(v.Pending==0 and v.PassRatio==0 and v.PassXP=='Temporada finalizada','Expired rewards not advertised')
 s.Season=nil;v=c:ProgressView(s,now)
 assert(v.PassXP=='Sin temporada activa'and v.PlayerRatio==250/300,'No-season leaves player progression intact')
 s.Season={EndsAt=now-1};s.Active=true;v=c:ProgressView(s,now)
 assert(v.PassXP=='Temporada finalizada','Local expiry handled before next server snapshot')
 local social={Profile=profile,ProfileTarget=123,ArticlesVisible=false}
 c.Context={GetController=function()return social end};c.Data=s;c.Hud=clone
 c:RenderProfile()
 assert(profile.MainFrame.ProgressCards.Pass.Visible,'Own profile shows pass progression')
 social.ProfileTarget=456;c:RenderProfile()
 assert(not profile.MainFrame.ProgressCards.Pass.Visible,'Other player pass stays private')
 social.ArticlesVisible=true;c:RenderProfile()
 assert(not profile.MainFrame.ProgressCards.Visible,'Inventory keeps its layout')
 c:OpenPass();assert(clone.MainFrame.Visible and not clone.ProgressCards.Visible,'Pass shortcut avoids compact overlay')
 s.Season={EndsAt=now+600,Stages=30,StageXP=800,Rewards={}}
 for i=1,30 do s.Season.Rewards[i]={Label='Premio '..i}end
 s.Active=true;s.Stage=2;s.PassXP=1600;s.Claimed={};social.ProfileTarget=123;social.ArticlesVisible=false
 c:Tick()
 assert(not clone.ProgressCards.Visible and not clone.Bar.Visible and not clone.Notice.Visible,'No EXP on main screen')
 assert(not clone.MainFrame.ProgressCards.Player.Visible,'Pass menu only shows pass EXP')
 assert(clone.OpenButton.ClaimDot.Visible and profile.MainFrame.ProgressCards.Pass.Open.ClaimDot.Visible,'Both pass shortcuts signal claimable rewards')
 s.Claimed={['1']=true,['2']=true};c:Tick()
 assert(not clone.OpenButton.ClaimDot.Visible,'Dot clears once all unlocked rewards claimed')
 s.Claimed={};s.Season.EndsAt=now-1;c:Tick()
 assert(not clone.OpenButton.ClaimDot.Visible,'Expired rewards never display red dot')
 return 'PASS: 19 presentation assertions with real GUI clones; no Play'
end)
clone:Destroy();profile:Destroy();module:Destroy();assert(ok,result);return result
