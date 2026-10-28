-- Run manually in Studio Command Bar, EDIT ONLY. Never run automatically.
-- Additive: existing positions, art and properties are preserved. Save the place afterward.
local RunService = game:GetService("RunService")
assert(RunService:IsStudio() and not RunService:IsRunning(), "V1.4.1 installation requires Studio Edit")
local function unique(parent, name)
 local result
 for _, item in ipairs(parent:GetChildren()) do
  if item.Name == name then
   assert(not result, "Duplicate name: " .. parent:GetFullName() .. "/" .. name)
   result = item
  end
 end
 return result
end
local storage = game:GetService("ServerStorage")
local folder = assert(unique(storage, "EndGames-Scenario"), "EndGames-Scenario missing")
local scene = assert(unique(folder, "ScenarioFinal"), "ScenarioFinal missing")
assert(scene:IsA("Model"), "ScenarioFinal must be Model")
local slots = assert(unique(scene, "Players"), "ScenarioFinal/Players missing")
-- Rojo names the mapped root EndCinematicBillboardAnchor; direct XML import keeps
-- its serialized name BillboardAnchor. Support both explicit installation workflows.
local selection = game:GetService("Selection"):Get()
local assets = game:GetService("ReplicatedStorage"):FindFirstChild("UIAssets")
local source
if #selection == 1 and selection[1]:IsA("Part")
 and (selection[1].Name == "BillboardAnchor" or selection[1].Name == "EndCinematicBillboardAnchor")
 and not selection[1]:IsDescendantOf(scene) then
 source = selection[1]
elseif assets then
 source = unique(assets, "EndCinematicBillboardAnchor")
end
assert(source, "Template missing. In EDIT import src/ui/EndCinematicBillboardAnchor.rbxmx, "
 .. "select its root Part BillboardAnchor, then rerun this entire installer; "
 .. "or sync ReplicatedStorage/UIAssets/EndCinematicBillboardAnchor with Rojo.")
assert(not source:IsDescendantOf(scene), "Source must be the imported asset, not an installed scene anchor")
assert(source:IsA("Part") and source.Archivable, "Source must be archivable Part")
for _, item in ipairs(source:GetDescendants()) do
 assert(not item:IsA("LuaSourceContainer"), "Source must not contain scripts")
 assert(item.Archivable, "Non-archivable source child: " .. item:GetFullName())
end
local gui = assert(unique(source, "BillboardGui"), "Source BillboardGui missing")
assert(gui:IsA("BillboardGui") and gui.Adornee == nil and not gui.Enabled, "Invalid source GUI")
local function required(parent, name, class)
 local item = assert(unique(parent, name), "Incomplete source: " .. parent:GetFullName() .. "/" .. name)
 assert(item:IsA(class), "Wrong source class: " .. item:GetFullName() .. " expected " .. class)
 return item
end
local frame = required(gui, "MainFrame", "CanvasGroup")
for _, name in ipairs({"RankLabel", "PlayerName", "MVPLabel", "Username", "TeamLabel", "PreviewLabel"}) do
 required(frame, name, "TextLabel")
end
local stats = required(frame, "StatsFrame", "Frame")
for _, name in ipairs({"GoalsLabel", "KillsLabel", "DeathsLabel", "MatchPointsLabel"}) do
 required(stats, name, "TextLabel")
end
required(frame, "UICorner", "UICorner")
required(frame, "UIStroke", "UIStroke")
required(frame, "UIScale", "UIScale")
required(stats, "UIGridLayout", "UIGridLayout")
print("[EndCinematic V1.4.1] Template source:", source:GetFullName(),
 "; cloning its existing BillboardGui design, not generating UI.")
assert(source.Anchored and source.Transparency == 1 and not source.CanCollide and not source.CanTouch
 and not source.CanQuery and not source.CastShadow, "Invalid source anchor properties")
local pending = {}
local function plan(sourceItem, parent, initialCFrame, targetName)
 local name = targetName or sourceItem.Name
 local existing = unique(parent, name)
 if existing then
  assert(existing.ClassName == sourceItem.ClassName, "Wrong class: " .. existing:GetFullName()
   .. "; correct manually; nothing has been installed")
  for _, item in ipairs(sourceItem:GetChildren()) do plan(item, existing) end
 else
  table.insert(pending, {Source=sourceItem, Parent=parent, InitialCFrame=initialCFrame, Name=name})
 end
end
-- Complete conflict preflight before adding anything.
for index = 1, 5 do
 local slot = assert(unique(slots, "SlotPlayer_" .. index), "Missing SlotPlayer_" .. index)
 assert(slot:IsA("BasePart"), "SlotPlayer must be BasePart")
 local anchor = unique(slot, "BillboardAnchor")
 if anchor then
  assert(anchor:IsA("Part") and anchor.Anchored and anchor.Transparency == 1
   and not anchor.CanCollide and not anchor.CanTouch and not anchor.CanQuery and not anchor.CastShadow,
   "Correct existing anchor properties manually: " .. anchor:GetFullName())
  local existingGui = unique(anchor, "BillboardGui")
  assert(not existingGui or (existingGui:IsA("BillboardGui")
   and (existingGui.Adornee == nil or existingGui.Adornee == anchor)), "Invalid existing Adornee")
 end
 -- Authoring seed for NEW anchors only. Independently editable afterward, never recentered.
 plan(source, slot, slot.CFrame + Vector3.new(0, 7.1, 0), "BillboardAnchor")
end
local created = {}
local ok, failure = pcall(function()
 for _, operation in ipairs(pending) do
  local copy = assert(operation.Source:Clone(), "Clone failed")
  table.insert(created, copy)
  copy.Name = operation.Name
  if operation.InitialCFrame then copy.CFrame = operation.InitialCFrame end
  copy.Parent = operation.Parent
 end
end)
if not ok then
 for _, item in ipairs(created) do item:Destroy() end -- Only this invocation's additions.
 error("V1.4.1 additions rolled back: " .. tostring(failure))
end
for index = 1, 5 do
 local slot = unique(slots, "SlotPlayer_" .. index)
 local anchor = required(slot, "BillboardAnchor", "Part")
 required(anchor, "BillboardGui", "BillboardGui")
 print("[EndCinematic V1.4.1] Review in Explorer:", anchor:GetFullName())
end
print("[EndCinematic V1.4.1] Additions applied; added subtrees:", #created,
 "; awaiting developer confirmation of all FIVE anchors in Explorer. SAVE the place locally.")
