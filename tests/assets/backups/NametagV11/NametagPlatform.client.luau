--!strict
local UIS=game:GetService('UserInputService')
local RS=game:GetService('ReplicatedStorage')
local Presentation=require(RS:WaitForChild('Shared'):WaitForChild('NametagPresentation'))
local report=RS:WaitForChild('Remotes'):WaitForChild('Nametag'):WaitForChild('ReportPlatform') :: RemoteEvent
local version=0
local function send()
 version+=1;local current=version
 -- Coalesce fast input changes and remain below the cosmetic server rate limit.
 task.delay(2.1,function()
  if current==version then report:FireServer(Presentation.FromInput(UIS.PreferredInput.Name))end
 end)
end
UIS:GetPropertyChangedSignal('PreferredInput'):Connect(send)
send()
