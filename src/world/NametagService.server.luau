--!nonstrict
-- Replaces the original Workspace name-only script; no persistence or gameplay authority.
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Presentation=require(RS.Shared.NametagPresentation)
local template=script:WaitForChild('Nametag')
local states={}
local function ensure(parent,name,class)
 local o=parent:FindFirstChild(name);if o then assert(o:IsA(class),'Nametag resource conflict: '..name);return o end
 o=Instance.new(class);o.Name=name;o.Parent=parent;return o
end
local remote=ensure(ensure(ensure(RS,'Remotes','Folder'),'Nametag','Folder'),'ReportPlatform','RemoteEvent')
local function disconnect(list)for _,c in ipairs(list)do c:Disconnect()end;table.clear(list)end
local function clear(state)if state.Tag then state.Tag:Destroy();state.Tag=nil end end
local function paint(player)
 local state=states[player];if not state or not state.Tag then return end
 local stats=player:FindFirstChild('leaderstats');local wins=stats and stats:FindFirstChild('Wins')
 Presentation.Paint(state.Tag,player.DisplayName,player.Name,if wins and wins:IsA('IntValue')then wins.Value else 0,state.Platform,player:GetAttribute('Level'))
end
local function mount(player)
 local state=states[player];if not state then return end
 local char=player.Character;local head=char and char:FindFirstChild('Head')
 if not head or not head:IsA('BasePart')then clear(state);return end
 local hum=char:FindFirstChildOfClass('Humanoid')
 if hum then hum.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.Subject;hum.NameDisplayDistance=0 end
 if state.Tag and state.Tag.Parent==head then paint(player);return end
 clear(state)
 local tag=template:Clone();tag.Enabled=true;tag.Adornee=head;tag.Parent=head;state.Tag=tag
 paint(player)
end
local function watchStats(player)
 local state=states[player];if not state then return end
 disconnect(state.StatsConnections)
 local stats=player:FindFirstChild('leaderstats')
 if stats then
  table.insert(state.StatsConnections,stats.ChildAdded:Connect(function()watchStats(player)end))
  table.insert(state.StatsConnections,stats.ChildRemoved:Connect(function()watchStats(player)end))
  local wins=stats:FindFirstChild('Wins')
  if wins and wins:IsA('IntValue')then table.insert(state.StatsConnections,wins.Changed:Connect(function()paint(player)end))end
 end
 paint(player)
end
local function character(player,char)
 local state=states[player];if not state then return end
 disconnect(state.CharacterConnections);clear(state)
 table.insert(state.CharacterConnections,char.ChildAdded:Connect(function(o)if o.Name=='Head'or o:IsA('Humanoid')then mount(player)end end))
 table.insert(state.CharacterConnections,char.ChildRemoved:Connect(function(o)if o.Name=='Head'then mount(player)end end))
 mount(player)
end
local function bind(player)
 if states[player]then return end
 local state={Connections={},CharacterConnections={},StatsConnections={}};states[player]=state
 table.insert(state.Connections,player.CharacterAdded:Connect(function(c)character(player,c)end))
 table.insert(state.Connections,player.CharacterRemoving:Connect(function()disconnect(state.CharacterConnections);clear(state)end))
 table.insert(state.Connections,player.CharacterAppearanceLoaded:Connect(function()mount(player)end))
 table.insert(state.Connections,player:GetPropertyChangedSignal('DisplayName'):Connect(function()paint(player)end))
 table.insert(state.Connections,player:GetAttributeChangedSignal('Level'):Connect(function()paint(player)end))
 table.insert(state.Connections,player.ChildAdded:Connect(function(o)if o.Name=='leaderstats'then watchStats(player)end end))
 table.insert(state.Connections,player.ChildRemoved:Connect(function(o)if o.Name=='leaderstats'then watchStats(player)end end))
 watchStats(player);if player.Character then character(player,player.Character)end
end
remote.OnServerEvent:Connect(function(player,value)
 local state=states[player];local platform=Presentation.Platform(value)
 if not state or not platform then return end
 local now=os.clock();if state.LastReport and now-state.LastReport<2 then return end
 state.LastReport=now;state.Platform=platform;paint(player)
end)
Players.PlayerAdded:Connect(bind)
Players.PlayerRemoving:Connect(function(player)
 local state=states[player];if not state then return end
 states[player]=nil;disconnect(state.Connections);disconnect(state.CharacterConnections);disconnect(state.StatsConnections);clear(state)
end)
for _,player in ipairs(Players:GetPlayers())do bind(player)end
print('[NametagService] Ready: ReportPlatform y nametags inicializados')
