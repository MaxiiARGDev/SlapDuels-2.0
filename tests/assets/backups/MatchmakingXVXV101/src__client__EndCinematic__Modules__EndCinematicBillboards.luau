--!nonstrict
-- Controls authored UI in the authorized scene; never creates UI or follows rigs.
local Config = require(game.ReplicatedStorage.Shared.EndCinematicConfig)
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Billboards = {}
local owners = setmetatable({}, { __mode = "k" })
local stats = {
 {"Goals", "GoalsLabel", "GOLES", "ShowGoals"},
 {"Kills", "KillsLabel", "KILLS", "ShowKills"},
 {"Deaths", "DeathsLabel", "BAJAS", "ShowDeaths"},
 {"MatchPoints", "MatchPointsLabel", "PUNTOS", "ShowPoints"},
}
local function child(parent, name, class)
 local object = parent:FindFirstChild(name)
 assert(object and object:IsA(class), "[EndCinematicBillboards] PhysicalResourceMissingOrInvalid: "
  .. parent:GetFullName() .. "/" .. name .. " expected " .. class .. "; install V1.4.1 in Edit")
 return object
end
local function ordinal(rank)
 local tail = rank % 100
 if tail >= 11 and tail <= 13 then return rank .. "th" end
 return rank .. (({[1]="st", [2]="nd", [3]="rd"})[rank % 10] or "th")
end
local function enabled(run)
 return Config.Billboards.Enabled and run.BillboardsEnabled ~= false
  and (run.Mode ~= "1v1" or Config.Billboards.ShowIn1v1)
end
local function reset(record)
 record.Gui.Enabled = false
 record.Frame.GroupTransparency = record.Transparency
 for label, original in pairs(record.Labels) do
  label.Text = original.Static and original.Text or ""
  label.Visible = false
  label.TextColor3 = original.Color
 end
 if record.Stroke then record.Stroke.Color = record.StrokeColor end
end
function Billboards.Cleanup(run)
 run.BillboardsGeneration = (run.BillboardsGeneration or 0) + 1
 for _, connection in ipairs(run.BillboardConnections or {}) do connection:Disconnect() end
 for _, tween in ipairs(run.BillboardTweens or {}) do tween:Cancel(); tween:Destroy() end
 for _, record in ipairs(run.Billboards or {}) do
  if owners[record.Gui] == run then
   if record.Gui.Parent then
    reset(record)
    if record.Scale then record.Scale.Scale = record.OriginalScale end
   end
   owners[record.Gui] = nil
  end
 end
 run.Billboards = {}
 run.BillboardConnections = {}
 run.BillboardTweens = {}
end
function Billboards.Prepare(run)
 Billboards.Cleanup(run)
 local scene = run.Scene
 assert(scene and scene:IsA("Model") and scene:IsDescendantOf(workspace), "BillboardsSceneCloneRequired")
 assert(run.Context and run.Context.Scene == scene, "BillboardsSceneContextMismatch")
 if run.Context.IsMatch then
  assert(run.Context.Payload and scene:GetAttribute("SessionId") == run.Context.Payload.SessionId,
   "BillboardsSessionMismatch")
 else
  assert(RunService:IsStudio() and scene:GetAttribute("PreviewOwnerUserId") == Players.LocalPlayer.UserId,
   "BillboardsPreviewOwnerMismatch")
 end
 local slots = child(scene, "Players", "Instance")
 local resolved = {}
 -- Validate all five slots before changing any GUI, including unused slots.
 for index = 1, 5 do
  local slot = child(slots, "SlotPlayer_" .. index, "BasePart")
  local anchor = child(slot, "BillboardAnchor", "Part")
  assert(anchor.Anchored and anchor.Transparency == 1 and not anchor.CanCollide
   and not anchor.CanTouch and not anchor.CanQuery and not anchor.CastShadow,
   "[EndCinematicBillboards] UnsafeAnchor: " .. anchor:GetFullName())
  local gui = child(anchor, "BillboardGui", "BillboardGui")
  assert(gui.Adornee == nil or gui.Adornee == anchor, "BillboardAdorneeMustBePhysicalAnchor")
  assert(not owners[gui] or owners[gui] == run, "BillboardPlaybackAlreadyOwned")
  local frame = child(gui, "MainFrame", "CanvasGroup")
  local labels = {}
  for _, name in ipairs({"RankLabel", "PlayerName", "MVPLabel", "Username", "TeamLabel", "PreviewLabel"}) do
   local label = child(frame, name, "TextLabel")
   labels[label] = {Text=label.Text, Color=label.TextColor3,
    Static=name == "MVPLabel" or name == "PreviewLabel"}
  end
  local statsFrame = child(frame, "StatsFrame", "Frame")
  for _, stat in ipairs(stats) do
   local label = child(statsFrame, stat[2], "TextLabel")
   labels[label] = {Color=label.TextColor3}
  end
  local stroke = frame:FindFirstChildOfClass("UIStroke")
  local scale = frame:FindFirstChildOfClass("UIScale")
  resolved[index] = {Gui=gui, Frame=frame, Labels=labels, Stroke=stroke,
   StrokeColor=stroke and stroke.Color, Transparency=frame.GroupTransparency,
   Scale=scale, OriginalScale=scale and scale.Scale}
 end
 run.Billboards = resolved
 for _, record in ipairs(resolved) do owners[record.Gui] = run; reset(record) end
 local occupied = {}
 for _, entry in ipairs(run.Rigs) do
  local data = entry.Participant
  if not data then continue end -- Never inherit another participant's row.
  local index = data.CinematicSlot
  assert(type(index) == "number" and index % 1 == 0 and resolved[index] and not occupied[index],
   "BillboardsInvalidOrDuplicateCinematicSlot")
  occupied[index] = true
  local record = resolved[index]
  record.Occupied = true
  local frame = record.Frame
  frame.RankLabel.Text = ordinal(data.Rank); frame.RankLabel.Visible = true
  frame.PlayerName.Text = data.DisplayName or tostring(data.UserId); frame.PlayerName.Visible = true
  frame.Username.Text = data.Username and ("@" .. data.Username) or ""
  frame.Username.Visible = Config.Billboards.ShowUsername and data.Username ~= nil
  frame.TeamLabel.Text = data.Team == run.WinningTeam and "EQUIPO GANADOR" or "EQUIPO RIVAL"
  frame.TeamLabel.Visible = true
  frame.MVPLabel.Visible = Config.Billboards.ShowMVP and data.IsMVP == true
  frame.PreviewLabel.Visible = run.Ranking.Preview == true
  for _, stat in ipairs(stats) do
   local value = data[stat[1]]
   local label = frame.StatsFrame[stat[2]]
   label.Visible = Config.Billboards[stat[4]] and value ~= nil
   label.Text = value ~= nil and (stat[3] .. " " .. value) or ""
  end
  if Config.Billboards.DynamicColors ~= false then
   local medal = Config.Billboards.RankColors[data.Rank] or record.Labels[frame.RankLabel].Color
   frame.RankLabel.TextColor3 = medal
   frame.TeamLabel.TextColor3 = Config.Billboards.TeamColors[data.Team] or medal
   if record.Stroke then record.Stroke.Color = medal end
  end
  -- Scale the existing authored pixel canvas, without changing layout or world size.
  if record.Scale and frame.Size.X.Scale == 0 and frame.Size.X.Offset > 0 then
   local function fit()
    if owners[record.Gui] == run then
     record.Scale.Scale = math.max(.01, record.Gui.AbsoluteSize.X / frame.Size.X.Offset)
    end
   end
   fit()
   table.insert(run.BillboardConnections, record.Gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit))
   table.insert(run.BillboardConnections, frame:GetPropertyChangedSignal("Size"):Connect(fit))
  end
 end
end
function Billboards.Play(run)
 if not enabled(run) then return end
 if not run.Billboards or #run.Billboards == 0 then Billboards.Prepare(run) end
 local generation = run.BillboardsGeneration
 task.wait(Config.Billboards.ShowDelay)
 if not run:IsAlive() or not enabled(run) or generation ~= run.BillboardsGeneration then return end
 for _, record in ipairs(run.Billboards) do
  if record.Occupied and record.Gui.Parent and owners[record.Gui] == run then
   record.Frame.GroupTransparency = 1
   record.Gui.Enabled = true
   local tween = TweenService:Create(record.Frame, TweenInfo.new(Config.Billboards.FadeDuration),
    {GroupTransparency=record.Transparency})
   table.insert(run.BillboardTweens, tween)
   tween:Play()
  end
 end
end
return Billboards
