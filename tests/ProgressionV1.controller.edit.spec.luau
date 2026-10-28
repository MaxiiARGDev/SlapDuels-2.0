-- Isolated Init/button regression; no Play, real players, or persistence.
assert(not game:GetService('RunService'):IsRunning(), 'Edit required')
local scope=Instance.new('Folder')
scope.Name='__ProgressionControllerRegression'
local ok,result=pcall(function()
 local fixture=Instance.new('ModuleScript');fixture.Name='Fixture'
 fixture.Source=[[
local f={Events={},Allowed=true}
local function button()
 local e=Instance.new('BindableEvent');table.insert(f.Events,e)
 return {Activated=e.Event,Fire=function()e:Fire()end}
end
local panel={Visible=false,Close=button(),Preset=button(),Start=button(),Restart=button(),Finish=button(),Confirm=button()}
local admin={MainFrame={SeasonPanel=panel,SeasonsButton=button()}}
function admin.MainFrame:WaitForChild(n)return self[n]end
local hud={MainFrame={Close=button(),ClaimAll=button(),ProgressCards={Pass={Open=button()}}},OpenButton=button(),Bar={},ProgressCards={Pass={Open=button()}}}
local gui={ProgressionHUD=hud,AdminHUD=admin,PlayerProfileHUD={MainFrame={ProgressCards={Pass={Open=button()}}}}}
function gui:WaitForChild(n)return self[n]end
local attr=Instance.new('BindableEvent');table.insert(f.Events,attr)
f.Player={PlayerGui=gui}
function f.Player:WaitForChild(n)return self[n]end
function f.Player:GetAttribute()return f.Allowed end
function f.Player:GetAttributeChangedSignal()return attr.Event end
f.RS=Instance.new('Folder');f.RS.Name='ReplicatedStorage'
local remotes=Instance.new('Folder');remotes.Name='Remotes';remotes.Parent=f.RS
local progression=Instance.new('Folder');progression.Name='Progression';progression.Parent=remotes
local request=Instance.new('RemoteFunction');request.Name='Request';request.Parent=progression
local changed=Instance.new('RemoteEvent');changed.Name='Changed';changed.Parent=progression
f.Panel=panel;f.Button=admin.MainFrame.SeasonsButton
return f
]]
 fixture.Parent=scope
 local module=game.StarterPlayer.StarterPlayerScripts.Controllers.BattlePassController:Clone()
 module.Source=module.Source:gsub("local RS=game:GetService%('ReplicatedStorage'%)","local RS=require(script.Parent.Fixture).RS"):gsub('local player=Players.LocalPlayer','local player=require(script.Parent.Fixture).Player')
 module.Parent=scope
 local f=require(fixture);local controller=require(module)
 local calls=0;controller.AdminInfo=function()calls+=1 end
 controller:Init()
 assert(#controller.Connections==15,'Init must bind all controls and notifications')
 f.Button.Fire();task.wait()
 assert(f.Panel.Visible and calls==1,'Admin button must open season panel')
 f.Panel.Close.Fire();task.wait()
 assert(not f.Panel.Visible,'Return must close panel')
 f.Allowed=false;f.Button.Fire();task.wait()
 assert(not f.Panel.Visible and calls==1,'Non-admin must not open panel')
 controller:Destroy();f.Allowed=true;f.Button.Fire();task.wait()
 assert(not f.Panel.Visible and calls==1,'Destroy must disconnect button')
 for _,e in ipairs(f.Events)do e:Destroy()end
 f.RS:Destroy()
 return 'PASS: 5 controller assertions; real Folder.Changed collision covered; no Play or remote calls'
end)
scope:Destroy()
assert(ok,result)
return result
