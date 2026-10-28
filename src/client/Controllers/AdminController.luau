--!nonstrict
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local Http=game:GetService('HttpService')
local player=Players.LocalPlayer
local Controller={Name='AdminController'}
local messages={Forbidden='No tenés permisos de administrador.',RateLimited='Esperá un momento.',DataNotLoaded='El perfil todavía no está disponible. No se aplicó el comando.',PlayerNotConnected='El jugador ya no está conectado.',InvalidTarget='Elegí un UserId válido.',InvalidAmount='Cantidad inválida o fuera del límite.',InvalidSlap='Slap inexistente, limitado o no permitido.',CoinsGranted='Coins acreditados.',SlapGranted='Slap agregado al inventario.',AlreadyOwned='El jugador ya posee ese Slap.',RequestIdConflict='La solicitud no coincide con su operación original.',SessionRequestLimit='Se alcanzó el límite de operaciones de esta sesión.',ExecutionFailedNoAutoRetry='No se pudo confirmar la operación. Revisá el inventario/Output antes de crear otra.'}
function Controller:Message(response)
 self.Hud.MainFrame.Status.Text=messages[response.Reason]or tostring(response.Reason or(response.Ok and 'Operación completada.'or 'Error'))
end
function Controller:ClearForm()
 for _,c in ipairs(self.FormConnections)do c:Disconnect()end;self.FormConnections={}
 for _,o in ipairs(self.Hud.MainFrame.Form:GetChildren())do if o:IsA('Frame')then o:Destroy()end end
 self.Inputs={}
end
function Controller:SelectCommand(command)
 if self.Pending or self.Retry then return end
 self:ClearForm();self.Command=command
 local m=self.Hud.MainFrame;m.Description.Text=command.Description
 for index,field in ipairs(command.Fields)do
  local row=self.Hud.FieldTemplate:Clone();row.Name=field.Name;row.Visible=true;row.LayoutOrder=index;row.Label.Text=field.Label
  row.Size=UDim2.new(1,-12,0,field.Type=='Integer'and 86 or 202)
  row.Input.Text='';row.Input.PlaceholderText=field.Type=='Integer'and(string.format('%d — %d',field.Min,field.Max))or(field.Type=='Player'and 'UserId del jugador o elegir abajo'or 'Id de Slap: Classic:Basic')
  self.Inputs[field.Name]={Input=row.Input,Type=field.Type}
  row.Choices.Visible=field.Type~='Integer'
  local choices=field.Type=='Player'and self.Info.Players or field.Type=='Slap'and self.Info.Slaps or {}
  for order,option in ipairs(choices)do
   local button=self.Hud.ChoiceTemplate:Clone();button.Visible=true;button.LayoutOrder=order
   button.Text=field.Type=='Player'and(option.DisplayName..' (@'..option.Username..') · '..option.UserId)or(option.Label..' · '..option.Id)
   button.Parent=row.Choices
   table.insert(self.FormConnections,button.Activated:Connect(function()if not self.Pending and not self.Retry then row.Input.Text=tostring(option.UserId or option.Id)end end))
  end
  row.Parent=m.Form
 end
end
function Controller:LoadInfo()
 if self.Pending or self.Retry then return end;self.Pending=true
 task.spawn(function()
  local ok,result=pcall(self.Remote.InvokeServer,self.Remote,'Info');self.Pending=false
  if not ok or type(result)~='table'then self.Hud.MainFrame.Status.Text='No se pudo cargar el panel.';return end
  if not result.Ok then self:Message(result);return end
  self.Info=result
  for _,c in ipairs(self.CommandConnections)do c:Disconnect()end;self.CommandConnections={}
  for _,o in ipairs(self.Hud.MainFrame.Commands:GetChildren())do if o:IsA('TextButton')then o:Destroy()end end
  for i,command in ipairs(result.Commands)do
   local b=self.Hud.CommandTemplate:Clone();b.Visible=true;b.LayoutOrder=i;b.Text=command.DisplayName;b.Parent=self.Hud.MainFrame.Commands
   table.insert(self.CommandConnections,b.Activated:Connect(function()self:SelectCommand(command)end))
  end
  if result.Commands[1]then self:SelectCommand(result.Commands[1])end
 end)
end
function Controller:Execute()
 if self.Pending or not self.Command then return end
 local packet=self.Retry
 if not packet then
  local args={};for name,row in pairs(self.Inputs)do args[name]=row.Type=='Slap'and row.Input.Text or tonumber(row.Input.Text)end
  packet={Id=Http:GenerateGUID(false),CommandId=self.Command.Id,Args=args};self.Retry=packet
 end
 self.Pending=true;self.Hud.MainFrame.Confirm.Text='PROCESANDO…'
 task.spawn(function()
  local ok,response=pcall(self.Remote.InvokeServer,self.Remote,'Execute',packet.Id,packet.CommandId,packet.Args)
  self.Pending=false
  if not ok or type(response)~='table'then
   self.Hud.MainFrame.Status.Text='Sin respuesta. Reintentá la MISMA solicitud; no se generará otro ID.'
   self.Hud.MainFrame.Confirm.Text='REINTENTAR MISMA SOLICITUD';return
  end
  if response.Reason=='RateLimited'or response.Reason=='OperationPending'then
   self:Message(response);self.Hud.MainFrame.Confirm.Text='REINTENTAR MISMA SOLICITUD';return
  end
  self.Retry=nil;self:Message(response);self.Hud.MainFrame.Confirm.Text='APLICAR AL JUGADOR'
 end)
end
function Controller:RefreshAccess()
 local allowed=player:GetAttribute('AdminPanelAllowed')==true
 self.Hud.OpenButton.Visible=allowed;self.Hud.OpenButton.Active=allowed
 if not allowed then self.Hud.MainFrame.Visible=false end
end
function Controller:Init()
 self.Connections={};self.FormConnections={};self.CommandConnections={};self.Inputs={}
 self.Hud=player:WaitForChild('PlayerGui'):WaitForChild('AdminHUD',15);assert(self.Hud,'AdminHUD missing in Edit')
 self.Remote=RS:WaitForChild('Remotes'):WaitForChild('Admin'):WaitForChild('Request')
 self.Hud.MainFrame.Visible=false;self.Hud.OpenButton.Visible=false
 local function bind(button,fn)table.insert(self.Connections,button.Activated:Connect(fn))end
 bind(self.Hud.OpenButton,function()if player:GetAttribute('AdminPanelAllowed')==true then self.Hud.MainFrame.Visible=not self.Hud.MainFrame.Visible;if self.Hud.MainFrame.Visible then self:LoadInfo()end end end)
 bind(self.Hud.MainFrame.Close,function()self.Hud.MainFrame.Visible=false end)
 bind(self.Hud.MainFrame.Refresh,function()self:LoadInfo()end)
 bind(self.Hud.MainFrame.Confirm,function()self:Execute()end)
 bind(self.Hud.MainFrame.NewOperation,function()
  if self.Pending then return end
  self.Retry=nil;self.Hud.MainFrame.Confirm.Text='APLICAR AL JUGADOR';self.Hud.MainFrame.Status.Text='Nueva operación. Si la anterior no respondió, revisá antes el saldo/inventario y Output.'
 end)
end
function Controller:Start()
 if not self.Hud then return end
 self:RefreshAccess();table.insert(self.Connections,player:GetAttributeChangedSignal('AdminPanelAllowed'):Connect(function()self:RefreshAccess()end))
end
function Controller:Destroy()
 self:ClearForm();for _,list in ipairs({self.Connections,self.CommandConnections})do for _,c in ipairs(list or {})do c:Disconnect()end end
 if self.Hud then self.Hud.Enabled=false end
end
return Controller
