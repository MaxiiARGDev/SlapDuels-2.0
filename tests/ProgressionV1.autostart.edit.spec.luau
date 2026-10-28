-- Isolated automatic startup; never calls Service.Start or real persistence.
assert(not game:GetService('RunService'):IsRunning(),'Edit required')
local scope=Instance.new('Folder')
local ok,result=pcall(function()
 local fixture=Instance.new('ModuleScript');fixture.Name='Fixture'
 fixture.Source="return {Studio=true,Config={StudioAutoSeason={Enabled=true,PresetId='TestSeason',Days=60}}}"
 fixture.Parent=scope
 local f=require(fixture)
 local module=game.ServerScriptService.Services.ProgressionService:Clone()
 module.Source=module.Source:gsub("local Run=game:GetService%('RunService'%)","local Run={IsStudio=function()return require(script.Parent.Fixture).Studio end}")
  :gsub('local Config=require%(RS.Shared.Progression.Config%)','local Config=require(script.Parent.Fixture).Config')
  :gsub('require%(script.Parent.Gameplay.SeasonState%)','require(game.ServerScriptService.Services.Gameplay.SeasonState)')
 module.Parent=scope
 local service=require(module);local row;local writes=0
 service.Context={PersistenceInfo={Environment='Studio',ProviderName='InMemory',WritesToCloud=false}}
 service.Enabled=true;service.HasReward=function()return true end
 service.Store={GetAsync=function()return row end,UpdateAsync=function(_,_,fn)writes+=1;row=fn(row);return row end}
 local started=service:StartStudioSeason()
 assert(started and writes==1 and row.Active.PresetId=='TestSeason','Fresh store starts configured pass')
 assert(row.Active.EndsAt-row.Active.StartsAt==60*86400,'Configured duration')
 local id=row.Active.Id
 assert(not service:StartStudioSeason()and writes==1 and row.Active.Id==id,'Repeated seed preserves edition')
 row.Active.EndsAt=os.time()-1
 assert(not service:StartStudioSeason()and writes==1,'Admin end is preserved')
 row=nil;f.Studio=false
 assert(not service:StartStudioSeason()and writes==1,'Production never starts pass')
 f.Studio=true;service.Context.PersistenceInfo.WritesToCloud=true
 assert(not service:StartStudioSeason()and writes==1,'Cloud provider blocked')
 service.Context.PersistenceInfo.WritesToCloud=false;f.Config.StudioAutoSeason.Enabled=false
 assert(not service:StartStudioSeason()and writes==1,'Config switch respected')
 f.Config.StudioAutoSeason.Enabled=true;service.HasReward=function()return false end
 assert(not service:StartStudioSeason()and writes==1,'Missing reward blocks startup')
 return 'PASS: 8 automatic season assertions; isolated memory only; no Play'
end)
scope:Destroy();assert(ok,result);return result
