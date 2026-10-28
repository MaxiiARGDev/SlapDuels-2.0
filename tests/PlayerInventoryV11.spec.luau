-- Appended to V1.0 fixtures: actual server handlers and client controller, no Studio execution.
local baseCount=n
local function own(page)clock+=.3;return Service:SelfProfile(aa,page)end
local ownData={Wins=18,Losses=4,Kills=31,Inventory=inventory(-1),Coins=1234,_PremiumProfile={Private=true}}
Service.Profiles.GetPlayerData=function(_,who)return who==aa and ownData or data end
local snapshot=copy(ownData)
local selfResult=own()
check(selfResult.Ok and selfResult.Profile.UserId==aa.UserId,'authenticated caller is self profile owner')
check(selfResult.Profile.ProfileMode=='SelfProfile','server assigns self mode')
check(selfResult.Profile.Username==aa.Name and selfResult.Profile.DisplayName==aa.DisplayName,'own identity')
check(selfResult.Profile.Stats.Wins==18 and selfResult.Profile.Stats.Losses==4 and selfResult.Profile.Stats.TotalKills==31,'own statistics')
check(#selfResult.Profile.Inventory==8,'same complete public inventory mapper')
check(selfResult.Profile.Coins==nil and selfResult.Profile._PremiumProfile==nil,'private persistence not exposed')
check(same(snapshot,ownData),'self inspection does not mutate inventory or data')
check(not Service:SelfProfile(aa).Ok,'self shares server rate limit')
for _,page in ipairs({0,-1,1.5,math.huge,0/0,'-2',false})do check(not own(page).Ok,'invalid self page rejected '..tostring(page))end
check(own(10000).Profile.Page==1,'removed/shrunk pages clamp to last existing page')
clock+=.3;check(not Service:SelfProfile(bb,-1,true).Ok,'foreign id/mode cannot masquerade as self arguments')
active[aa]={Id='match'};check(not own().Ok,'authoritative session blocks even if client MatchId absent')
active[aa]=nil;aa.Attributes.Queue='waiting';check(own().Ok,'waiting outside an admitted session remains eligible');aa.Attributes.Queue=nil
ready=false;check(not own().Ok,'unloaded self profile blocked');ready=true
local realParent=aa.Parent;aa.Parent=nil;check(not own().Ok,'disconnected self blocked');aa.Parent=realParent
local fake=copy(aa);clock+=.3;check(not Service:SelfProfile(fake).Ok,'forged player identity rejected')
clock+=.3;check(not Service:Action(aa,'Invite',aa.UserId).Ok,'actual server rejects self trade')
local other=inspect(-2);check(other.Ok and other.Profile.ProfileMode=='OtherPlayerProfile','other inspection retained with server mode')
ownData.Inventory.Equipped.Slaps='Classic:Rare'
local updated=own().Profile;local equipped
for _,row in ipairs(updated.Inventory)do if row.Equipped then equipped=row end end
check(equipped and equipped.VariationId=='Rare','equipment refresh reads authoritative current data')
ownData.Inventory.SlapUnits['-1:operation-1']=nil;ownData.Inventory.Owned.Slaps['Classic:Common']=nil
check(#own().Profile.Inventory==7,'ownership change reflected on next read')
local events={};Service.Update={FireClient=function(_,who,kind,payload)table.insert(events,{who,kind,payload})end}
Service.Viewers={[aa]=aa.UserId};active[aa]={Id='began'};Service:ValidateViewers()
check(Service.Viewers[aa]==nil and #events==1 and events[1][2]=='ProfileUnavailable','server invalidates open own view when session starts')
Service:ValidateViewers();check(#events==1,'invalidation emitted once');active[aa]=nil
Service.Viewers={[aa]=aa.UserId};Service:ValidateViewers();check(Service.Viewers[aa]==aa.UserId,'self watcher never requires proximity to another player')

-- Disposable client GUI/signal scheduler fixtures execute real controller methods.
local function signal()
 local out={Listeners={}}
 function out:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(self.Listeners,{fn,c});return c end
 function out:Fire(...)for _,v in ipairs(self.Listeners)do if v[2].Connected then v[1](...)end end end
 return out
end
local later={};local deferred=false;local spawned={}
local scheduler={spawn=function(fn)if deferred then table.insert(spawned,fn)else fn()end end,delay=function(_,fn)table.insert(later,fn)end}
local function gui(name)
 local g={Name=name,Enabled=false,MainFrame={GroupTransparency=0,Avatar={},Collection={},Trade={},Identity={},Stats={},Progression={},Page={},Status={}}}
 function g:FindFirstChild(key)return rawget(self,key)end
 function g.MainFrame:FindFirstChild(key)return rawget(self,key)end
 return g
end
local profile,request,trade=gui('PlayerProfileHUD'),gui('TradeRequestHUD'),gui('TradeHUD')
trade.MainFrame.Mine={Avatar={}};trade.MainFrame.Theirs={Avatar={}}
local screens={PlayerProfileHUD=profile,TradeRequestHUD=request,TradeHUD=trade,ShopHUD=gui('ShopHUD'),PremiumShopHUD=gui('PremiumShopHUD'),SettingsGUI=gui('SettingsGUI'),CrateOpeningHUD=gui('CrateOpeningHUD')}
for _,name in ipairs({'ShopHUD','PremiumShopHUD','SettingsGUI'})do screens[name].MainFrame.Visible=false end
local playerGui={};function playerGui:FindFirstChild(key)return screens[key]end
aa.FindFirstChild=function(_,key)if key=='PlayerGui'then return playerGui end end
fakeServices.Players.LocalPlayer=aa
local function stableRows(rows)if rows.Inventory then return tostring(rows.Category)..':'..stableRows(rows.Inventory)end;local out={};for _,row in ipairs(rows)do table.insert(out,row.EntryId..':'..tostring(row.Equipped))end;return table.concat(out,',')end
fakeServices.HttpService={JSONEncode=function(_,rows)return stableRows(rows)end}
fakeServices.TweenService={Create=function()return{Play=function()end,Cancel=function()end,Destroy=function()end}end}
fakeServices.RunService={RenderStepped=signal()}
parent.Parent=parent;parent.Social=parent
local chunk=assert(loadstring(Sources.SocialController,'SocialController'))
setfenv(chunk,setmetatable({script={Parent=parent},game={GetService=function(_,key)return fakeServices[key]or {}end},workspace=world,require=load,
 task=scheduler,TweenInfo={new=function()return{}end},Color3={fromRGB=function()return{}end}},{__index=getfenv()}))
local C=chunk();C.Profile=profile;C.Request=request;C.Trade=trade;C.Generation=0;C.Connections={};C.Cards={};C.DisplayTokens={};C.Fades={}
local renders,avatars,removes=0,0,0
C.Pool={Remove=function()removes+=1 end,Add=function(_,view,owner,isAvatar)avatars+=1;check(owner==aa or owner==bb,'same pool receives actual player');check(isAvatar,'avatar route uses existing WorldModel renderer')end,Clear=function()end}
C.CardsFor=function(_,hud,collection,rows,mode)renders+=1;check(hud==profile and collection==profile.MainFrame.Collection and mode==nil,'same inventory renderer in read-only mode');check(#rows>0,'owned variations delivered to renderer')end
local sounds={};C.Sound=function(_,_,key)table.insert(sounds,key)end
local readCalls,foreignCalls=0,0
C.SelfInspect={InvokeServer=function(_,page,category)readCalls+=1;check(category=='Slaps','self wire has page/category only, never target or arbitrary mode');return own(page)end}
C.Inspect={InvokeServer=function(_,id,page)foreignCalls+=1;return inspect(id,page)end}
local button={Activated=signal(),MouseEnter=signal(),MouseLeave=signal(),BackgroundColor3={Lerp=function(self)return self end}}
C:BindProfileButton(button);check(#C.Connections==3,'one button binding with tracked cleanup connections')
button.Activated:Fire()
check(profile.Enabled and C.ProfileTarget==aa.UserId and C.ProfileMode=='SelfProfile','button opens local player through actual self remote flow')
check(readCalls==1 and foreignCalls==0,'self uses dedicated authenticated route')
check(profile.MainFrame.Identity.Text==aa.DisplayName..'\n@'..aa.Name,'own display and username presented')
check(string.find(profile.MainFrame.Stats.Text,'VICTORIAS 18',1,true)~=nil,'real statistics presented')
check(profile.MainFrame.Trade.Visible==false and profile.MainFrame.Trade.Active==false and profile.MainFrame.Trade.Selectable==false,'trade hidden and non-activable in own profile')
check(avatars==1 and renders==1,'same avatar and owned inventory renders')
local beforeRenders=renders;C:OpenProfile(aa.UserId,1,true)
check(renders==beforeRenders and avatars==1,'unchanged refresh preserves rotating previews and avatar')
ownData.Inventory.Equipped.Slaps='Classic:Gold';C:OpenProfile(aa.UserId,1,true)
check(renders==beforeRenders+1 and avatars==1,'equipment changes refresh cards without resetting avatar')
C:Close(profile);check(C.ProfileTarget==nil and C.ProfileMode==nil and C.NextSelfRefresh==nil and removes>0,'close releases profile target and avatar')
button.Activated:Fire();check(C.ProfileTarget==aa.UserId,'reopen through same button')
for _,fn in ipairs(later)do fn()end;later={}
check(profile.Enabled,'stale close fade cannot hide reopened profile')
check(#C.Connections==3,'reopening adds no button events')
C:Close(profile);for _,fn in ipairs(later)do fn()end;later={}
C:OpenProfile(bb.UserId,1)
check(C.ProfileTarget==bb.UserId and profile.MainFrame.Trade.Visible and profile.MainFrame.Trade.Active and profile.MainFrame.Trade.Selectable,'other profile preserves trade UI')
check(foreignCalls==1,'other uses original inspect remote')
check(not C:ApplyProfile({UserId=aa.UserId,ProfileMode='OtherPlayerProfile'}),'mismatched server identity/mode ignored before render')
check(not C:ApplyProfile({UserId=bb.UserId,ProfileMode='SelfProfile'}),'foreign self mode ignored')
C:Close(profile);for _,fn in ipairs(later)do fn()end;later={}
aa.Attributes.MatchId='session';local beforeCalls=readCalls;button.Activated:Fire();check(readCalls==beforeCalls and C.ProfileTarget==nil,'local authoritative MatchId blocks opening');aa.Attributes.MatchId=nil
screens.ShopHUD.Enabled=true;screens.ShopHUD.MainFrame.Visible=true
button.Activated:Fire();check(readCalls==beforeCalls,'existing ordinary shop prevents overlapping own profile')
screens.ShopHUD.MainFrame.Visible=false;screens.PremiumShopHUD.Enabled=true;screens.PremiumShopHUD.MainFrame.Visible=true
check(C:WindowBusy(),'premium prevents overlapping profile');screens.PremiumShopHUD.Enabled=false
screens.SettingsGUI.Enabled=true;screens.SettingsGUI.MainFrame.Visible=true
check(C:WindowBusy(),'settings prevents overlapping profile');screens.SettingsGUI.MainFrame.Visible=false
screens.CrateOpeningHUD.Enabled=true;check(C:WindowBusy(),'crate opening blocks profile without a MainFrame');screens.CrateOpeningHUD.Enabled=false
request.Enabled=true;check(C:WindowBusy(),'trade request prevents overlapping profile');request.Enabled=false
deferred=true;C:OpenProfile(aa.UserId,1);C:Close(profile);local count=avatars;deferred=false;table.remove(spawned,1)()
check(C.ProfileTarget==nil and avatars==count,'late server response cannot reopen closed window')
C.Initialized=true;C:Init({});check(#C.Connections==3,'Init is idempotent and does not duplicate bindings')
-- Real Start listeners: session auto-close, data invalidation, window changes and cleanup.
local attributeChanged,characterRemoving=signal(),signal()
aa.GetAttributeChangedSignal=function()return attributeChanged end;aa.CharacterRemoving=characterRemoving
aa.WaitForChild=function(_,key)assert(key=='PlayerGui');return playerGui end
ps.PlayerRemoving=signal()
local dataSignal=signal();local remoteTree={Player={DataUpdated={OnClientEvent=dataSignal}}}
function remoteTree:WaitForChild(key)return self[key]end
function remoteTree.Player:WaitForChild(key)return self[key]end
fakeServices.ReplicatedStorage.WaitForChild=function(_,key)assert(key=='Remotes');return remoteTree end
for _,name in ipairs({'ShopHUD','PremiumShopHUD','SettingsGUI','CrateOpeningHUD'})do
 local hud=screens[name];hud.Changed=signal();hud.MainFrame.Changed=signal()
 function hud:GetPropertyChangedSignal()return self.Changed end
 function hud.MainFrame:GetPropertyChangedSignal()return self.Changed end
end
playerGui.WaitForChild=playerGui.FindFirstChild
C.Update={OnClientEvent=signal()};C.Pool.Step=function()end
C.PollTarget=function()end;C.RefreshPreviews=function()end;C.SetTarget=function()end
C:Start();local bound=#C.Connections;C:Start();check(#C.Connections==bound,'Start adds no duplicate listeners')
C:OpenProfile(aa.UserId,1);aa.Attributes.MatchId='admitted';attributeChanged:Fire()
check(C.ProfileTarget==nil and C.ProfileMode==nil,'authoritative MatchId event closes existing own profile')
aa.Attributes.MatchId=nil;C:OpenProfile(aa.UserId,1)
local due=C.NextSelfRefresh;dataSignal:Fire({Inventory={Fake=true}})
check(C.NextSelfRefresh<due,'DataUpdated invalidates rather than trusting client payload')
clock+=.3;local reads=readCalls;fakeServices.RunService.RenderStepped:Fire(.2)
check(readCalls==reads+1 and C.ProfileTarget==aa.UserId,'visible own profile refetches current server data')
screens.ShopHUD.MainFrame.Visible=true;screens.ShopHUD.MainFrame.Changed:Fire()
check(C.ProfileTarget==nil,'shop opening closes profile without modifying shop state')
check(screens.ShopHUD.MainFrame.Visible,'existing shop remains open');screens.ShopHUD.MainFrame.Visible=false
C:OpenProfile(aa.UserId,1);C.Update.OnClientEvent:Fire('ProfileUnavailable',{UserId=aa.UserId})
check(C.ProfileTarget==nil,'server invalidation closes own view independently of attributes')
C:OpenProfile(aa.UserId,1);characterRemoving:Fire();check(C.ProfileTarget==nil,'respawn removes own profile and preview target')
check(cfg.TradeCommitEnabled==false,'real transfers remain disabled after own reads')
for _,c in ipairs(C.Connections)do c:Disconnect()end
local calls=readCalls;button.Activated:Fire();check(readCalls==calls,'tracked button connection disconnects cleanly')
print('PASS PlayerInventoryV11: '..(n-baseCount)..' additional isolated assertions; visual/mobile/multiplayer validation remains manual')
