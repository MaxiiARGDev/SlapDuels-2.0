assert(not game:GetService('RunService'):IsRunning(),'Edit only')
local temp=game.ReplicatedStorage.Shared.NametagPresentation:Clone();temp.Name='__NametagAudit';temp.Parent=game.ReplicatedStorage
local tag=workspace.NametagService.Nametag:Clone();local count=0
local function check(v,m)assert(v,m);count+=1 end
local ok,result=xpcall(function()
 local P=require(temp)
 for _,name in ipairs({'PC','Mobile','Console'})do check(P.Platform(name)==name,'Allowed platform')end
 for _,value in ipairs({'Xbox','',false,123,{Platform='PC'}})do check(P.Platform(value)==nil,'Reject arbitrary client metadata')end
 check(P.FromInput('KeyboardAndMouse')=='PC','PC input')
 check(P.FromInput('Touch')=='Mobile','Touch input')
 check(P.FromInput('Gamepad')=='Console','Gamepad input')
 check(P.Wins(-5)==0,'No negative wins');check(P.Wins(3.9)==3,'Integer wins')
 check(P.Wins(0/0)==0,'NaN');check(P.Wins(math.huge)==0,'Infinity');check(P.Wins('5')==0,'No numeric strings')
 for _,name in ipairs({'PC','Mobile','Console'})do
  P.Paint(tag,'Nombre Largo Áéñ','MaxiiDJ4K',5,name)
  check(tag.Level.Text=='0','Level placeholder')
  check(tag.Identity.DisplayName.Text=='Nombre Largo Áéñ','DisplayName preserved')
  check(tag.Identity.Username.Text=='@MaxiiDJ4K','Username preserved')
  check(tag.Trophy.Wins.Text=='5','Authoritative wins displayed')
  local visible=0;for _,icon in ipairs(tag.Platform:GetChildren())do if icon:IsA('Frame')and icon.Visible then visible+=1;check(icon.Name==name,'Selected icon')end end
  check(visible==1,'Exactly one platform')
 end
 P.Paint(tag,'Otro','user',6,nil)
 check(tag.Trophy.Wins.Text=='6','Wins update')
 check(not tag.Platform.PC.Visible and not tag.Platform.Mobile.Visible and not tag.Platform.Console.Visible,'Unknown platform hidden')
 check(not tag.AlwaysOnTop,'No labels through walls')
 check(tag.MaxDistance==75,'Bounded visibility')
 check(tag.Identity.DisplayName.RichText==false,'No name markup')
 check(tag.Level.TextScaled and tag.Identity.DisplayName.TextScaled,'Readable scaled labels')
 check(workspace.NametagService.Nametag.Trophy.Wins.Text=='0','Original editable template unchanged')
 return {Assertions=count,Mode='Edit isolated; no players or Play'}
end,debug.traceback)
tag:Destroy();temp:Destroy();if not ok then error(result)end;return result
