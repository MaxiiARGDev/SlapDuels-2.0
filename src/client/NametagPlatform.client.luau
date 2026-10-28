--!strict
local UIS=game:GetService('UserInputService')
local RS=game:GetService('ReplicatedStorage')
local shared=RS:WaitForChild('Shared',10)
local module=shared and shared:WaitForChild('NametagPresentation',10)
local remotes=RS:WaitForChild('Remotes',10)
local folder=remotes and remotes:WaitForChild('Nametag',10)
local report=folder and folder:WaitForChild('ReportPlatform',10)
if not module or not module:IsA('ModuleScript')or not report or not report:IsA('RemoteEvent')then
 warn('[NametagPlatform] Inicialización incompleta: revisar errores de Workspace.NametagService en el servidor.')
 return
end
local Presentation=require(module)
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
