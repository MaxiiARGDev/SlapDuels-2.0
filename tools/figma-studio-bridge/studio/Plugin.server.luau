--!nonstrict
local Core=require(script.Core)
local Http=game:GetService('HttpService')
local Run=game:GetService('RunService')
local History=game:GetService('ChangeHistoryService')
local Selection=game:GetService('Selection')
local toolbar=plugin:CreateToolbar('UI Bridge')
local toggle=toolbar:CreateButton('Figma → Studio','Importar diseño local sin generar scripts','')
local info=DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float,false,false,480,740,360,550)
local widget=plugin:CreateDockWidgetPluginGui('SlapDuelsUIBridgeV1',info);widget.Title='Figma → Studio · local'
local root=Instance.new('Frame');root.Size=UDim2.fromScale(1,1);root.BackgroundColor3=Color3.fromRGB(16,26,43);root.Parent=widget
local function ui(class,text,y,h)
 local o=Instance.new(class);o.Name=text;o.Size=UDim2.new(1,-24,0,h);o.Position=UDim2.fromOffset(12,y);o.BackgroundColor3=Color3.fromRGB(28,48,73);o.BorderSizePixel=0;o.TextColor3=Color3.fromRGB(234,247,255);o.Font=Enum.Font.Gotham;o.TextSize=13;o.Text=text;o.TextWrapped=true;o.Parent=root
 if o:IsA('TextBox')then o.ClearTextOnFocus=false end;return o
end
ui('TextLabel','Solo Edit · no cloud · no scripts generados',8,30)
local token=ui('TextBox','',44,32);token.PlaceholderText='Token del puente (no se guarda)'
local fetch=ui('TextButton','1. Obtener diseño del puente local',82,32)
local json=ui('TextBox','',120,70);json.PlaceholderText='Alternativa: pegar JSON exportado aquí';json.MultiLine=true;json.TextSize=10;json.TextXAlignment=Enum.TextXAlignment.Left;json.TextYAlignment=Enum.TextYAlignment.Top
local previewButton=ui('TextButton','2. Preview y revisar cambios',196,32)
local apply=ui('TextButton','3. APLICAR a StarterGui (requiere preview)',234,32)
local status=ui('TextLabel','Importa en un ScreenGui propio; no reemplaza los HUD de tu juego.',272,116);status.TextSize=11;status.TextYAlignment=Enum.TextYAlignment.Top
local preview=Instance.new('Frame');preview.Name='Preview';preview.Position=UDim2.fromOffset(12,400);preview.Size=UDim2.new(1,-24,1,-412);preview.BackgroundColor3=Color3.fromRGB(8,14,24);preview.ClipsDescendants=true;preview.Parent=root
local packet,target,planned,revision,previewObject
local busy=false
local function safe(fn)
 if busy then return end;busy=true
 local ok,err=pcall(function()assert(not Run:IsRunning(),'Detené tu prueba antes de importar; el plugin no detiene Play');fn()end)
 busy=false;if not ok then planned=false;status.Text=tostring(err)end
end
local function existing(p)
 local found;for _,o in ipairs(game.StarterGui:GetChildren())do if o:IsA('ScreenGui')and o:GetAttribute('UIBridgeSource')==p.sourceId then assert(not found,'Dos importaciones del mismo diseño; resolver duplicado primero');found=o end end;return found
end
local function request()
 local response=Http:RequestAsync({Url='http://127.0.0.1:38474/design',Method='GET',Headers={Authorization='Bearer '..token.Text}})
 assert(response.Success,'Puente: '..response.StatusCode..' (verificá token/puerto)')
 local row=Http:JSONDecode(response.Body);return row.packet,row.revision
end
fetch.Activated:Connect(function()safe(function()
 packet,revision=request();Core.Validate(packet);json.Text='';planned=false
 status.Text='Recibido: '..packet.name..' · '..#packet.nodes..' capas · revisión '..revision..'\nAhora revisá la preview.'
end)end)
json:GetPropertyChangedSignal('Text'):Connect(function()if json.Text~=''then planned=false end end)
previewButton.Activated:Connect(function()safe(function()
 if json.Text~=''then packet=Http:JSONDecode(json.Text);revision=nil end
 assert(packet,'Primero obtené o pegá un diseño');Core.Validate(packet);target=existing(packet)
 local report=Core.Plan(packet,target)
 if previewObject then previewObject:Destroy()end;previewObject=Core.Preview(packet,preview)
 planned=true
 status.Text=string.format('%s · Nuevas %d / actualizar %d / ocultar %d\nPNG sin ID: %d\n',packet.name,report.New,report.Updated,report.Stale,report.MissingImages)..table.concat(report.Lines,'\n'):sub(1,450)
 if packet.warnings and #packet.warnings>0 then status.Text..='\nAvisos de conversión: '..#packet.warnings..' (detalle en JSON de Figma)'end
end)end)
apply.Activated:Connect(function()safe(function()
 assert(planned and packet,'Revisá la preview primero');assert(target==existing(packet),'Cambió el destino; repetí preview')
 if revision then local _,latest=request();assert(latest==revision,'Llegó otra revisión: obtener y previsualizar otra vez')end
 local recording=History:TryBeginRecording('UIBridgeImport','Importar diseño Figma')
 assert(recording,'No se pudo iniciar Undo; cerrá otras operaciones de edición')
 local ok,result=pcall(Core.Apply,packet,target,game.StarterGui)
 History:FinishRecording(recording,ok and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel)
 assert(ok,result);Selection:Set({result});planned=false
 status.Text='Importado: '..result:GetFullName()..'\nScripts existentes preservados. Ctrl+Z permite deshacer. Vinculá tus controladores a estos objetos.'
end)end)
toggle.Click:Connect(function()widget.Enabled=not widget.Enabled end)
plugin.Unloading:Connect(function()token.Text='';if previewObject then previewObject:Destroy()end;widget:Destroy()end)
