--!nonstrict
local Config = require(game.ReplicatedStorage.Shared.EndCinematicConfig)
local Module = {}

local function normalizeSoundId(id)
    if type(id) ~= "string" or id == "" then
        return nil
    end

    if id:match("^%d+$") then
        return "rbxassetid://" .. id
    end

    return id
end

function Module.PlayTransition(run, closed)
 local config = Config.TransitionAudio
 if not run:IsAlive() or not config.Enabled then return false end
 local phase = closed and "Close" or "Open"
 run.TransitionStarted = run.TransitionStarted or {}
 if run.TransitionStarted[phase] then return false end
 run.TransitionStarted[phase] = true
 local name = config[phase .. "SoundName"]
 local source = name and name ~= "" and run.Scene:FindFirstChild(name, true)
 local id = config[phase .. "SoundId"]
 if not (source and source:IsA("Sound")) and (type(id) ~= "string" or id == "") then return false end
 local sound = source and source:IsA("Sound") and source:Clone() or Instance.new("Sound")
 if not source or not source:IsA("Sound") then
    sound.SoundId = normalizeSoundId(id) or ""
 end
 if sound.SoundId == "" then sound:Destroy(); return false end
 sound.Name = "EndCinematic" .. phase .. "Whoosh"
 sound.Looped = false
 sound.Volume = math.clamp(config[phase .. "Volume"], 0, 10)
 sound.PlaybackSpeed = math.max(.01, config[phase .. "PlaybackSpeed"])
 sound.TimePosition = math.max(0, config[phase .. "StartOffset"])
 if not run.TransitionAudioFolder then
  run.TransitionAudioFolder = Instance.new("Folder")
  run.TransitionAudioFolder.Name = "EndCinematicTransitionAudio_" .. run.Id
  run.TransitionAudioFolder.Parent = game:GetService("SoundService")
  table.insert(run.Resources, run.TransitionAudioFolder)
 end
 sound.Parent = run.TransitionAudioFolder
 run.TransitionSounds = run.TransitionSounds or {}
 table.insert(run.TransitionSounds, sound)
 sound:Play()
 return true
end

function Module.Prepare(run, stage)
 run.AudioCopies = {}
 run.AudioStarted = {}
 local confetti = stage:FindFirstChild("Confeti")
 if not confetti then return end
 for _, dropName in ipairs({ "DropT1", "DropT2" }) do
  local drop = confetti:FindFirstChild(dropName)
  local folder = drop and drop:FindFirstChild("AllSoundsPlay")
  local localDrop = run.Effects:FindFirstChild(dropName)
  if folder and localDrop then
   for _, object in ipairs(folder:GetDescendants()) do
    if object:IsA("Sound") then
     local sound = object:Clone()
     sound:Stop()
     sound.Parent = localDrop
     table.insert(run.AudioCopies, sound)
    end
   end
  end
 end
end

function Module.Play(run)
 if not run:IsAlive() or not Config.Effects.SoundsEnabled then return end
 for _, sound in ipairs(run.AudioCopies or {}) do
  if sound.SoundId ~= "" and not Config.Effects.DisabledSounds[sound.Name] and not run.AudioStarted[sound] then
   run.AudioStarted[sound] = true
   sound:Play()
  end
 end
end

function Module.Stop(run)
 for _, sound in ipairs(run.AudioCopies or {}) do
  if run.AudioStarted[sound] then sound:Stop() end
 end
end

function Module.Cleanup(run)
 Module.Stop(run)
 for _, sound in ipairs(run.TransitionSounds or {}) do sound:Stop(); sound:Destroy() end
 run.TransitionSounds = {}
 run.TransitionStarted = {}
 for _, sound in ipairs(run.AudioCopies or {}) do sound:Destroy() end
 run.AudioCopies = {}
 run.AudioStarted = {}
end
return Module
