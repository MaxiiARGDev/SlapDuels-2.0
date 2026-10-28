--!nonstrict
local Players = game:GetService("Players")
local Config = require(game.ReplicatedStorage.Shared.EndCinematicConfig)
local Module = {}

function Module.Resolve()
 local gui = Players.LocalPlayer.PlayerGui:FindFirstChild("EndCinematicHUD")
 local panel = gui and gui:FindFirstChild("MainFrame")
 if not gui or not gui:IsA("ScreenGui") or not panel or not panel:IsA("CanvasGroup") then return nil, "PhysicalHUDMissing" end
 for _, name in ipairs({ "Title", "Subtitle", "WinnerNames", "WinningTeam", "Score", "ReturnButton", "RematchButton", "RematchCounter" }) do
  if not panel:FindFirstChild(name, true) then return nil, "HUDChildMissing:" .. name end
 end
 return gui
end

function Module.Prepare(run, gui, stop)
 run.HUD = gui
 run.HUDPanel = gui.MainFrame
 run.HUDEnabled = gui.Enabled
 run.HUDTransparency = gui.MainFrame.GroupTransparency
 run.HiddenHUDs = {}
 for _, object in ipairs(Players.LocalPlayer.PlayerGui:GetChildren()) do
  if object:IsA("ScreenGui") and object ~= gui and object.Name ~= "EndCinematicPreview" then
   run.HiddenHUDs[object] = object.Enabled; object.Enabled = false
  end
 end
 gui.Enabled = false
 gui.MainFrame.GroupTransparency = 1
 table.insert(run.Connections, gui.MainFrame.ReturnButton.Activated:Connect(function()
  if run:IsAlive() then stop() end
 end))
 table.insert(run.Connections, gui.Destroying:Connect(function() if run:IsAlive() then stop() end end))
end

function Module.Play(run, data, winners)
 if not run:IsAlive() then return end
 local panel = run.HUDPanel
 panel.ReturnButton.Active = true
 local won = data.LocalTeam == data.WinningTeam
 local draw = data.WinningTeam == "Draw"
 panel.Title.Text = draw and "EMPATE" or (won and "VICTORIA" or "DERROTA")
 panel.Title.TextColor3 = won and Color3.fromRGB(255, 207, 74) or Color3.fromRGB(255, 104, 115)
 panel.Subtitle.Text = draw and "EL DUELO TERMINÓ EN EMPATE" or (won and "GANASTE EL DUELO" or "PERDISTE EL DUELO")
 local names = {}
 for _, winner in ipairs(winners) do table.insert(names, winner.DisplayName) end
 -- Kept on one visual line, as in V1, but separately editable in Explorer.
 local line = panel.WinnerLine
 line.WinningTeam.Text = draw and "SIN GANADOR" or ("EQUIPO " .. data.WinningTeam .. "  ·  ")
 line.WinnerNames.Text = table.concat(names, ", ")
 local function fitNames()
  if not run:IsAlive() then return end
  local text = line.WinningTeam.Text .. line.WinnerNames.Text
  local width = game:GetService("TextService"):GetTextSize(text, 17, Enum.Font.GothamBold, Vector2.new(10000, 42)).X
  local size = math.min(17, math.max(8, 17 * line.AbsoluteSize.X / math.max(width, 1)))
  line.WinningTeam.TextSize = size
  line.WinnerNames.TextSize = size
 end
 fitNames()
 table.insert(run.Connections, line:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitNames))
 panel.Score.Text = string.format("%d  —  %d", data.Score.Red, data.Score.Blue)
 local eligible = data.EligibleParticipantCount or (#winners * 2)
 panel.RematchButton.Text = string.format("REVANCHA (0/%d)", eligible)
 panel.RematchButton.Active = false
 panel.RematchButton.AutoButtonColor = false
 panel.RematchCounter.Text = "REVANCHA · PRÓXIMAMENTE"
 run.HUD.Enabled = true
 run:Tween(panel, Config.HUD.FadeDuration, { GroupTransparency = 0 })
end

function Module.Cleanup(run)
 if run.HUD and run.HUD.Parent then
  run.HUD.Enabled = false
  run.HUDPanel.GroupTransparency = run.HUDTransparency
 end
 for gui, enabled in pairs(run.HiddenHUDs or {}) do if gui.Parent then gui.Enabled = enabled end end
end
return Module
