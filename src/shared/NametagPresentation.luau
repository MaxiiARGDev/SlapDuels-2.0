--!strict
-- Cosmetic metadata only. Platform is client-reported and never authorizes gameplay.
local Presentation={}
function Presentation.Platform(value: any): string?
 return if value=='PC'or value=='Mobile'or value=='Console'then value else nil
end
function Presentation.FromInput(name: string): string
 return if name=='Touch'then 'Mobile'elseif name=='Gamepad'then 'Console'else 'PC'
end
function Presentation.Wins(value: any): number
 if type(value)~='number'or value~=value or value==math.huge or value==-math.huge then return 0 end
 return math.max(0,math.floor(value))
end
function Presentation.Paint(tag: any,displayName: string,username: string,wins: any,platform: any,level: any?)
 tag.Level.Text=tostring(Presentation.Wins(level))
 tag.Identity.DisplayName.Text=displayName
 tag.Identity.Username.Text='@'..username
 tag.Trophy.Wins.Text=tostring(Presentation.Wins(wins))
 local kind=Presentation.Platform(platform)
 for _,name in ipairs({'PC','Mobile','Console'})do tag.Platform[name].Visible=name==kind end
end
return Presentation
