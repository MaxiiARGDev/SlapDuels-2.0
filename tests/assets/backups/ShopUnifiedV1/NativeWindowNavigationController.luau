--!nonstrict
local Players=game:GetService('Players')
local Stack=require(script.Parent.Parent.UI.WindowStack)
local Controller={Name='WindowNavigationController'}
function Controller:Init(context)
 self.Context=context;self.Entries={};self.Connections={};self.Expected={};self.Muting=false
 self.Stack=Stack.new(function(top)
  local function valid(id)
   if id=='SocialRequest'and self.Context then local c=self.Context:GetController('SocialPlayController');return c and c.Request and workspace:GetServerTimeNow()<c.Request.ExpiresAt end
   if id=='Admin'and Players.LocalPlayer then return Players.LocalPlayer:GetAttribute('AdminPanelAllowed')==true end
   return true
  end
  while top and not valid(top)do table.remove(self.Stack.Order);top=self.Stack.Order[#self.Stack.Order]end
  self.Muting=true
  for id,entry in pairs(self.Entries)do if entry.Object.Parent then
   self.Expected[id]=id==top;entry.Object[entry.Property]=id==top
   if entry.Dim then entry.Dim.Visible=id==top end
  end end
  self.Muting=false
 end)
end
function Controller:Forget(id)if self.Stack then self.Stack:Remove(id)end end
function Controller:Contains(id)for _,key in ipairs(self.Stack and self.Stack.Order or {})do if key==id then return true end end;return false end
function Controller:Watch(id,object,property)
 if self.Entries[id]then return end
 self.Entries[id]={Object=object,Property=property,Dim=id=='Shop'and object.Parent:FindFirstChild('DimBackground')or id=='Premium'and object.Parent:FindFirstChild('Dim')or nil}
 table.insert(self.Connections,object:GetPropertyChangedSignal(property):Connect(function()
  if self.Muting then return end
  -- Property signals may be deferred by Roblox; a synchronous mute alone is insufficient.
  if self.Expected[id]~=nil and object[property]==self.Expected[id]then return end
  self.Expected[id]=nil
  if object[property]then self.Stack:Push(id)else self.Stack:Remove(id)end
 end))
 if object[property]then self.Stack:Push(id)end
end
function Controller:Start()
 local player=Players.LocalPlayer;local gui=player:WaitForChild('PlayerGui')
 local definitions={{'ShopHUD','MainFrame','Shop'},{'ShopHUD','CrateSpinPanel','CrateSpin'},{'PremiumShopHUD','MainFrame','Premium'},{'SettingsGUI','MainFrame','Settings'},{'AdminHUD','MainFrame','Admin'},{'SocialPlayHUD','RequestPanel','SocialRequest'},{'ProgressionHUD','MainFrame','BattlePass'}}
 for _,d in ipairs(definitions)do task.spawn(function()
  local hud=gui:WaitForChild(d[1],20);local main=hud and hud:WaitForChild(d[2],20)
  if main then self:Watch(d[3],main,'Visible')end
 end)end
 for _,name in ipairs({'InvitePanel','ModePanel'})do task.spawn(function()
  local hud=gui:WaitForChild('PartyMatchHUD',20);local panel=hud and hud:WaitForChild(name,20)
  if panel then self:Watch('Party'..name,panel,'Visible')end
 end)end
 for _,name in ipairs({'PlayerProfileHUD','TradeRequestHUD','TradeHUD','CrateOpeningHUD'})do task.spawn(function()
  local hud=gui:WaitForChild(name,20);if hud then self:Watch(name,hud,'Enabled')end
 end)end
 local function clear()
  self.Stack:Clear()
  for _,name in ipairs({'ShopController','PremiumShopController','SettingsController'})do
   local c=self.Context and self.Context:GetController(name);if c and type(c.Close)=='function'then c:Close()end
  end
 end
 local function reset()if player:GetAttribute('MatchId')or player:GetAttribute('ResultsSessionId')then clear()end end
 for _,key in ipairs({'MatchId','ResultsSessionId'})do table.insert(self.Connections,player:GetAttributeChangedSignal(key):Connect(reset))end
 table.insert(self.Connections,player.CharacterRemoving:Connect(clear))
 reset()
end
function Controller:Destroy()self.Stack:Clear();for _,c in ipairs(self.Connections)do c:Disconnect()end end
return Controller

