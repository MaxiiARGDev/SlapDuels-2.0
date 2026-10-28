-- Actual pure engine, PlayerService and schema modules. No Studio/cloud.
local n=0;local function check(v,m)n+=1;assert(v,m)end
local function load(key,env)local f=assert(loadstring(Sources[key],key));setfenv(f,setmetatable(env or {},{__index=getfenv()}));return f()end
local config=load('SocialPlayConfig')
local streak=load('WinStreak',{game={GetService=function()return {Shared={SocialPlayConfig='cfg'}}end},require=function()return config end})
local data={Coins=123,WinStreak=nil};local unchanged=data.Coins
for i=1,9 do
 check(streak.Apply(data,'match'..i,'Win'),'each win recorded')
 check(data.WinStreak.Total==math.floor(i/3)and data.WinStreak.Progress==i%3,'exact blocks of three '..i)
 check(not streak.Apply(data,'match'..i,'Win'),'duplicate result cannot award another block')
end
check(streak.Apply(data,'loss','Loss')and data.WinStreak.Total==3 and data.WinStreak.Progress==0,'loss preserves permanent total')
streak.Apply(data,'one','Win');streak.Apply(data,'two','Win');streak.Apply(data,'draw','Draw')
check(data.WinStreak.Total==3 and data.WinStreak.Progress==0,'draw resets unfinished block only')
check(not streak.Apply(data,'cancel','Cancelled')and data.WinStreak.LastMatchId=='draw','cancelled game does not affect counters')
check(data.Coins==unchanged,'streak never touches economy')
for _,v in ipairs({false,0,'bad',{Total=-1,Progress=0/0},{Total=math.huge,Progress=-1}})do local row=streak.Normalize(v);check(row.Total==0 and row.Progress==0,'invalid saved stats sanitize')end
local F=load('ShopFixture',{Sources=Sources});local fixture=F.New();local ps,a=fixture.PS,fixture.A
for i=1,6 do check(ps:RecordStreakResult(a,'ps'..i,'Win'),'real PlayerService integration')end
check(ps:GetPlayerData(a).WinStreak.Total==2,'public runtime snapshot carries accumulated blocks')
local schema=load('DataService',fixture.Env);local ok,record=schema:ValidatePlayerData(ps._data[a])
check(ok and record.WinStreak.Total==2 and record.WinStreak.Progress==0,'schema preserves streak record')
local _,legacy=schema:ValidatePlayerData(F.Profile(100))
check(legacy.WinStreak.Total==0 and legacy.WinStreak.Progress==0,'legacy profile does not fabricate streaks from lifetime wins')
local persisted
schema._loadStates={[a]='Loaded'};schema._saving={}
schema.GetStore=function()return {UpdateAsync=function(_,key,transform)check(key=='Player_'..a.UserId,'existing profile key is preserved');persisted=transform({Version=2,External='preserved'})end}end
check(schema:SavePlayer(a,ps:GetPlayerData(a)),'real save method with isolated table adapter')
check(persisted.WinStreak.Total==2 and persisted.WinStreak.Progress==0 and persisted.External=='preserved','save carries new counters without removing unrelated fields')
local _,reloaded=schema:ValidatePlayerData(persisted)
check(reloaded.WinStreak.Total==2,'save/load normalization preserves permanent earned total')

local Engine=load('SocialPlayEngine')
local function fixtureEngine()
 local f={Now=1,Valid={},Events={},Attributes={},Started={},Serial=0,Start=true}
 for i=1,8 do f.Valid[i]=true end
 f.Engine=Engine.new(config,{Clock=function()return f.Now end,Id=function()f.Serial+=1;return 'id-'..f.Serial end,
  Eligible=function(id)return f.Valid[id]==true end,Near=function()return f.Distance~=false end,Name=function(id)return 'P'..id end,
  Emit=function(id,kind,payload)table.insert(f.Events,{Id=id,Kind=kind,Data=payload})end,
  GroupChanged=function(id,group)f.Attributes[id]=group end,
  StartDuel=function(g)table.insert(f.Started,g);return f.Start,'RoundUnavailable'end})
 return f
end
local function invite(f,a,b,kind)f.Now+=16;local ok,key=f.Engine:Invite(a,b,kind);check(ok,'valid invitation '..kind);return key end
local f=fixtureEngine();local e=f.Engine
check(not e:Invite(1,1,'Duel'),'self challenge rejected')
check(not e:Invite(1,0,'Duel'),'invalid/disconnected target rejected')
f.Distance=false;check(not e:Invite(1,2,'Duel'),'range checked at send');f.Distance=true
local key=invite(f,1,2,'Duel')
check(not e:Invite(3,2,'Duel'),'one outstanding request per recipient')
check(not e:Respond(3,key,true),'outsider cannot accept')
check(not e:Respond(2,key,'true'),'boolean acceptance required')
check(e:Respond(2,key,true)and #f.Started==1,'acceptance starts exactly one server 1v1')
check(not e:Respond(2,key,true)and #f.Started==1,'replayed acceptance cannot start another match')
local grant=f.Started[1];check(grant.A==1 and grant.B==2 and grant.ZoneId:sub(1,5)=='Duel:'and grant.Token~=key,'server-owned reservation exact roster and independent token')
f.Now=grant.ExpiresAt;e:Tick();check(next(e.Grants)==nil,'stale duel grants reclaimed')
f=fixtureEngine();e=f.Engine;f.Start=false;key=invite(f,1,2,'Duel');check(not e:Respond(2,key,true)and next(e.Grants)==nil,'failed admission releases grant')
f=fixtureEngine();e=f.Engine;key=invite(f,1,2,'Duel');f.Valid[1]=false;check(not e:Respond(2,key,true)and #f.Started==0,'disconnect/busy rechecked at acceptance')
f=fixtureEngine();e=f.Engine;key=invite(f,1,2,'Duel');f.Now+=15;check(not e:Respond(2,key,true),'exact expiration rejects acceptance')
f=fixtureEngine();e=f.Engine;key=invite(f,1,2,'Group');check(e:Respond(2,key,true),'group created only upon consent')
local group=e:Group(1)
check(group and #group.Members==2 and group==e:Group(2)and group.Leader==1,'same authoritative group for both players')
check(not e:CanChallenge(1,3)and not e:CanChallenge(3,1),'either player grouped hides challenge')
check(not e:Invite(1,3,'Duel')and not e:Invite(3,1,'Duel'),'server blocks grouped challenger and target')
check(not e:Invite(2,3,'Group'),'nonleader cannot invite')
key=invite(f,1,3,'Group');check(e:Respond(3,key,true),'third member joins')
key=invite(f,1,4,'Group');check(e:Respond(4,key,true),'fourth member joins')
f.Now+=16;check(not e:Invite(1,5,'Group')and #group.Members==4,'fifth member rejected')
local roster={{UserId=1},{UserId=2},{UserId=3},{UserId=4}}
check(e:CanQueueTeam(roster,4),'whole group can queue as same team')
check(not e:CanQueueTeam({roster[1],roster[2]},2),'group cannot be split into smaller mode')
check(not e:CanQueueTeam({roster[1],roster[2],roster[3]},4),'missing member prevents partial admission')
check(not e:CanQueueTeam({roster[4]},4),'cannot move last group member to opposing team')
check(e:CanQueueTeam({{UserId=5},{UserId=6}},2),'solo queues unchanged')
f.Valid[3]=false;check(not e:Leave(1,false),'cannot alter group during queue/match');f.Valid[3]=true
check(not e:Leave(2,true),'nonleader cannot disband')
check(e:Leave(1,false)and e:Group(2).Leader==2,'leader leaving migrates leadership')
e:Disconnect(3);check(e:Group(3)==nil and #e:Group(2).Members==2,'disconnect removes member')
e:Disconnect(4);check(next(e.Groups)==nil and next(e.Membership)==nil,'one remaining player dissolves group')
f=fixtureEngine();e=f.Engine;key=invite(f,1,2,'Group');e:Respond(2,key,true)
key=invite(f,1,3,'Group');e:Leave(1,true);check(not e:Respond(3,key,true),'invite cannot recreate a dissolved group')
f=fixtureEngine();e=f.Engine;key=invite(f,1,2,'Group');check(e:Respond(2,key,false)and next(e.Groups)==nil,'decline does not create a group')
check(not e:Invite(1,3,'Group'),'invite spam cooldown retained after decline')
f.Now+=16;key=invite(f,1,2,'Duel');e:Disconnect(2);check(next(e.Pending)==nil and next(e.Busy)==nil,'disconnect cancels both sides of pending request')
f=fixtureEngine();e=f.Engine;key=invite(f,1,2,'Group');f.Now+=15;e:Tick();check(next(e.Pending)==nil and next(e.Busy)==nil,'timeout releases pending locks')
local gui={Screens={}};function gui:FindFirstChild(name)return self.Screens[name]end
local localUser={UserId=-1,Attributes={}};function localUser:GetAttribute(name)return self.Attributes[name]end
function localUser:FindFirstChild(name)if name=='PlayerGui'then return gui end end
local target={Attributes={}};function target:GetAttribute(name)return self.Attributes[name]end
local client=load('SocialPlayController',{game={GetService=function(_,name)if name=='Players'then return {LocalPlayer=localUser,GetPlayerByUserId=function()return target end}else return {}end end}})
client.Hud={RequestPanel={Visible=false}}
check(client:GroupPanelAllowed(),'group panel available in unobstructed lobby')
for _,name in ipairs({'PlayerProfileHUD','TradeHUD','TradeRequestHUD','ShopHUD','PremiumShopHUD','SettingsGUI','CrateOpeningHUD'})do
 local screen={Enabled=true,MainFrame={Visible=true}};function screen:FindFirstChild(key)return self[key]end
 gui.Screens[name]=screen;check(not client:GroupPanelAllowed(),'group panel never covers '..name);gui.Screens[name]=nil
end
client.Hud.RequestPanel.Visible=true;check(not client:GroupPanelAllowed(),'group panel hidden for invitation');client.Hud.RequestPanel.Visible=false
localUser.Attributes.MatchId='match';check(not client:GroupPanelAllowed(),'group panel hidden during match');localUser.Attributes.MatchId=nil
local sent={};client.Send=function(_,...)table.insert(sent,{...})end
client:Invite('Duel',localUser.UserId);check(#sent==0,'client never sends self challenge')
localUser.Attributes.SocialGroupId='group';client:Invite('Duel',2);check(#sent==0,'grouped caller cannot send challenge');localUser.Attributes.SocialGroupId=nil
target.Attributes.SocialGroupId='group';client:Invite('Duel',2);check(#sent==0,'grouped target cannot receive client challenge');target.Attributes.SocialGroupId=nil
client:Invite('Duel',2);check(#sent==1 and sent[1][1]=='Duel'and sent[1][2]==2,'available peer sends only requested target, never roster/token')
print('PASS ProfileSocialV12: '..n..' isolated assertions; real gameplay and visual acceptance NOT RUN')
