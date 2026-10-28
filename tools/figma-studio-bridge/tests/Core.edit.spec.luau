-- Provided Core module in script.Core; detached objects only, no game HUD changes.
assert(not game:GetService('RunService'):IsRunning(),'Edit required')
local Core=require(script.Core)
local function row(id,parent,class)
 return {id=id,parent=parent,name=id,class=class or 'Frame',x=0,y=0,w=1,h=1,rotation=0,opacity=1,fillOpacity=1,color={.1,.2,.3},radius=8}
end
local p={schema=1,sourceId='test',name='Test',width=400,height=300,nodes={row('root'),row('a','root'),row('b','a')},assets={}}
local holder=Instance.new('Folder');local count=0
local function check(v,m)assert(v,m);count+=1 end
local ok,result=pcall(function()
 local gui,report=Core.Apply(p,nil,holder);check(report.New==3,'New nodes');check(#holder:GetChildren()==1,'One ScreenGui')
 local function find(id)for _,o in ipairs(gui:GetDescendants())do if o:GetAttribute('UIBridgeId')==id then return o end end end
 local a,b=find('a'),find('b');local custom=Instance.new('ModuleScript');custom.Name='KeepMe';custom.Source='return 1';custom.Parent=a
 p.nodes={row('root'),row('b','root'),row('a','b')};p.nodes[3].color={1,0,0}
 local same,r=Core.Apply(p,gui,holder);check(same==gui and r.Updated==3,'In-place update');check(a.Parent==b,'Parent inversion');check(custom.Parent==a and custom.Source=='return 1','Script preserved');check(a.BackgroundColor3==Color3.new(1,0,0),'Property updated')
 p.nodes={row('root'),row('a','root')};Core.Apply(p,gui,holder);check(b.Parent~=nil and b.Visible==false and b:GetAttribute('UIBridgeStale'),'Removed layer hidden, not deleted');check(custom.Parent==a,'Custom content survives removal')
 local bad={schema=1,sourceId='other',name='Other',width=400,height=300,nodes={row('root')}}
 check(not pcall(Core.Apply,bad,gui,holder),'Other design rejected')
 bad.sourceId='test';bad.nodes[1].class='Script';check(not pcall(Core.Validate,bad),'Script injection rejected')
 bad.nodes={row('x','missing')};check(not pcall(Core.Validate,bad),'Invalid parent rejected')
 -- Force a decoration conflict after property mutation; original properties/parents must recover.
 local corner=a:FindFirstChild('BridgeCorner');corner:Destroy();local conflict=Instance.new('Folder');conflict:SetAttribute('UIBridgeDecoration','Corner');conflict.Parent=a
 local before=a.BackgroundColor3;p.nodes[2].color={0,1,0}
 check(not pcall(Core.Apply,p,gui,holder),'Conflict rejected');check(a.BackgroundColor3==before and a.Parent==find('root'),'Rollback preserves properties/parents');check(custom.Parent==a,'Rollback preserves scripts');conflict:Destroy()
 local preview=Core.Preview(p,holder);check(preview:IsA('Frame'),'Preview renders detached UI');preview:Destroy()
 local countScripts=0;for _,o in ipairs(gui:GetDescendants())do if o:IsA('LuaSourceContainer')then countScripts+=1 end end;check(countScripts==1,'No scripts generated')
 return 'PASS: '..count..' importer assertions; no Play, cloud or production GUI changes'
end)
holder:Destroy();assert(ok,result);return result
