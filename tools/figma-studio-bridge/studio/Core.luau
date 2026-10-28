--!nonstrict
-- Data-only converter. No require(assetId), loadstring, HTTP, or runtime game scripts.
local Core={}
local allowed={Frame=true,TextLabel=true,TextButton=true,ImageLabel=true,ImageButton=true,ScrollingFrame=true}
local function finite(v,lo,hi)return type(v)=='number'and v==v and v>=lo and v<=hi end
local function str(v,max)return type(v)=='string'and #v<=max end
local function color(v)return type(v)=='table'and #v==3 and finite(v[1],0,1)and finite(v[2],0,1)and finite(v[3],0,1)end
function Core.Validate(p)
 assert(type(p)=='table'and p.schema==1,'Schema incompatible')
 assert(str(p.sourceId,200)and #p.sourceId>0 and str(p.name,200),'Identidad inválida')
 assert(finite(p.width,1,16000)and finite(p.height,1,16000),'Tamaño inválido')
 assert(type(p.nodes)=='table'and #p.nodes>0 and #p.nodes<=1500,'Cantidad inválida')
 local ids,depths={},{};local roots=0;local count=0
 for k in pairs(p.nodes)do count+=1;assert(type(k)=='number'and k%1==0 and k>=1 and k<=#p.nodes,'Array inválido')end
 assert(count==#p.nodes,'Array disperso')
 for _,n in ipairs(p.nodes)do
  assert(type(n)=='table'and str(n.id,200)and #n.id>0 and not ids[n.id],'ID inválido o duplicado')
  assert(allowed[n.class]and str(n.name,200),'Clase/nombre no permitido')
  if n.parent==nil then roots+=1;depths[n.id]=0 else assert(ids[n.parent],'Padre ausente o desordenado');depths[n.id]=depths[n.parent]+1 end
  assert(depths[n.id]<=40,'Demasiada profundidad')
  for _,k in ipairs({'x','y'})do assert(finite(n[k],-100,100),'Posición inválida')end
  for _,k in ipairs({'w','h'})do assert(finite(n[k],0,100),'Tamaño relativo inválido')end
  assert(finite(n.rotation,-360,360)and finite(n.opacity,0,1)and finite(n.fillOpacity,0,1)and finite(n.radius,0,16000)and color(n.color),'Estilo inválido')
  if n.text~=nil then assert(str(n.text,40000)and finite(n.textSize,1,1000)and color(n.textColor)and finite(n.textOpacity,0,1)and({Left=true,Center=true,Right=true})[n.align]and str(n.font,50),'Texto inválido')end
  if n.stroke then assert(color(n.stroke.color)and finite(n.stroke.width,0,100)and finite(n.stroke.opacity,0,1),'Borde inválido')end
  if n.assetId then assert(type(n.assetId)=='string'and n.assetId:match('^%d+$')and #n.assetId<=20,'AssetId inválido')end
  if n.asset then assert(str(n.asset,200),'Asset inválido')end
  assert(n.class~='TextLabel'or n.text~=nil,'TextLabel sin texto')
  ids[n.id]=n
 end
 assert(roots==1 and p.nodes[1].parent==nil,'Se requiere una única raíz')
 return true
end
local function rgb(c)return Color3.new(c[1],c[2],c[3])end
local function properties(n,index)
 local props={Name=n.name,Position=UDim2.fromScale(n.x,n.y),Size=UDim2.fromScale(n.w,n.h),Rotation=n.rotation,
  BackgroundColor3=rgb(n.color),BackgroundTransparency=1-n.fillOpacity*n.opacity,BorderSizePixel=0,Visible=true,ZIndex=index,ClipsDescendants=n.clip==true}
 if n.class=='TextLabel'or n.class=='TextButton'then
  local font=Enum.Font.Gotham;pcall(function()font=Enum.Font[n.font or 'Gotham']end)
  props.Font=font;props.Text=n.text or '';props.TextColor3=rgb(n.textColor or {1,1,1});props.TextTransparency=1-(n.textOpacity or n.opacity)
  props.TextScaled=true;props.TextWrapped=true;props.RichText=false;props.TextXAlignment=Enum.TextXAlignment[n.align or 'Left'];props.TextYAlignment=Enum.TextYAlignment.Center
  if n.class=='TextButton'then props.AutoButtonColor=true end
 elseif n.class=='ImageLabel'or n.class=='ImageButton'then
  props.Image=n.assetId and('rbxassetid://'..n.assetId)or '';props.ImageTransparency=1-n.opacity;props.ScaleType=Enum.ScaleType.Fit
  if n.class=='ImageButton'then props.AutoButtonColor=true end
 elseif n.class=='ScrollingFrame'then
  props.CanvasSize=UDim2.new();props.AutomaticCanvasSize=Enum.AutomaticSize.XY;props.ScrollBarThickness=6;props.ClipsDescendants=true
 end
 return props
end
local function indexTarget(target,source)
 if not target then return {}end
 assert(target:IsA('ScreenGui')and target:GetAttribute('UIBridgeSource')==source,'Solo se actualizan ScreenGui creados por este puente para el mismo diseño')
 local ids={}
 for _,o in ipairs(target:GetDescendants())do
  if o:GetAttribute('UIBridgeSource')==source and o:GetAttribute('UIBridgeId')then
   local id=o:GetAttribute('UIBridgeId');assert(not ids[id],'IDs duplicados en Studio');ids[id]=o
  end
 end
 return ids
end
function Core.Plan(p,target)
 Core.Validate(p);local old=indexTarget(target,p.sourceId);local seen={};local report={New=0,Updated=0,Stale=0,MissingImages=0,Lines={}}
 for _,n in ipairs(p.nodes)do
  local o=old[n.id];seen[n.id]=true
  if o then assert(o.ClassName==n.class,'Cambio de clase en '..n.name..': importar como otro diseño o corregir la etiqueta');report.Updated+=1 else report.New+=1 end
  if n.asset and not n.assetId then report.MissingImages+=1;table.insert(report.Lines,'PNG pendiente: '..n.name..' ['..n.asset..']')end
 end
 for id,o in pairs(old)do if not seen[id]and o:IsA('GuiObject')then report.Stale+=1;table.insert(report.Lines,'Se ocultará (no borra scripts): '..o.Name)end end
 return report
end
local function decorate(o,n,set,make,ratio)
 local function part(class,tag)
  for _,c in ipairs(o:GetChildren())do if c:GetAttribute('UIBridgeDecoration')==tag then assert(c:IsA(class),'Decoración conflictiva');return c end end
  local c=make(class);set(c,'Name','Bridge'..tag);c:SetAttribute('UIBridgeDecoration',tag);set(c,'Parent',o);return c
 end
 if ratio then set(part('UIAspectRatioConstraint','RootAspect'),'AspectRatio',ratio)end
 if n.radius>0 then set(part('UICorner','Corner'),'CornerRadius',UDim.new(0,n.radius))else for _,c in ipairs(o:GetChildren())do if c:GetAttribute('UIBridgeDecoration')=='Corner'then set(c,'CornerRadius',UDim.new())end end end
 if n.stroke then
  local s=part('UIStroke','Stroke');set(s,'Enabled',true);set(s,'Color',rgb(n.stroke.color));set(s,'Thickness',n.stroke.width);set(s,'Transparency',1-n.stroke.opacity)
 else for _,c in ipairs(o:GetChildren())do if c:GetAttribute('UIBridgeDecoration')=='Stroke'then set(c,'Enabled',false)end end end
 if o:IsA('TextLabel')or o:IsA('TextButton')then
  local c=part('UITextSizeConstraint','TextBounds');set(c,'MinTextSize',1);set(c,'MaxTextSize',math.max(1,math.floor(n.textSize or 100)))
 end
end
function Core.Apply(p,target,parent)
 assert(not game:GetService('RunService'):IsRunning(),'Solo Studio Edit')
 local report=Core.Plan(p,target);local old=indexTarget(target,p.sourceId)
 local created,changes,parents,attrs={},{},{},{}
 local function make(class)local o=Instance.new(class);table.insert(created,o);return o end
 local function set(o,k,v)table.insert(changes,{o,k,o[k]});o[k]=v end
 local function attribute(o,k,v)table.insert(attrs,{o,k,o:GetAttribute(k)});o:SetAttribute(k,v)end
 local result
 local ok,err=pcall(function()
  result=target or make('ScreenGui')
  if not target then result.Name='Bridge_'..p.name;result.ResetOnSpawn=false;result.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;result:SetAttribute('UIBridgeSource',p.sourceId)end
  -- Detach managed GUI nodes first, permitting safe parent inversions between imports.
  for _,o in pairs(old)do if o:IsA('GuiObject')then table.insert(parents,{o,o.Parent});o.Parent=nil end end
  local current={};local present={}
  for i,n in ipairs(p.nodes)do
   local o=old[n.id]or make(n.class);present[n.id]=true;current[n.id]=o
   for k,v in pairs(properties(n,i))do set(o,k,v)end
   attribute(o,'UIBridgeId',n.id);attribute(o,'UIBridgeSource',p.sourceId);attribute(o,'UIBridgeStale',nil)
   decorate(o,n,set,make,n.parent==nil and p.width/p.height or nil)
   if n.parent==nil then set(o,'AnchorPoint',Vector2.new(.5,.5));set(o,'Position',UDim2.fromScale(.5,.5))end
   set(o,'Parent',n.parent and current[n.parent]or result)
  end
  for id,o in pairs(old)do if not present[id]and o:IsA('GuiObject')then
   local original;for _,entry in ipairs(parents)do if entry[1]==o then original=entry[2];break end end
   -- Keep stale nodes at the root if their former parent became a descendant.
   set(o,'Parent',original and not original:IsDescendantOf(o)and original or result);set(o,'Visible',false);attribute(o,'UIBridgeStale',true)
  end end
  if not target then result.Parent=parent end
 end)
 if not ok then
  for _,entry in ipairs(parents)do pcall(function()entry[1].Parent=nil end)end
  for i=#changes,1,-1 do local e=changes[i];if e[2]~='Parent'then pcall(function()e[1][e[2]]=e[3]end)end end
  for i=#attrs,1,-1 do local e=attrs[i];pcall(function()e[1]:SetAttribute(e[2],e[3])end)end
  for _,e in ipairs(parents)do pcall(function()e[1].Parent=e[2]end)end
  for _,o in ipairs(created)do o:Destroy()end
  error('Importación cancelada y revertida: '..tostring(err))
 end
 return result,report
end
function Core.Preview(p,parent)
 Core.Validate(p);local root=Instance.new('Frame');root.Name='BridgePreview';root.Size=UDim2.fromScale(1,1);root.BackgroundTransparency=1
 local ok,err=pcall(function()
  local ids={};for i,n in ipairs(p.nodes)do local o=Instance.new(n.class);for k,v in pairs(properties(n,i))do o[k]=v end
   decorate(o,n,function(a,k,v)a[k]=v end,Instance.new);o.Parent=n.parent and ids[n.parent]or root;ids[n.id]=o
  end
  local aspect=Instance.new('UIAspectRatioConstraint');aspect.AspectRatio=p.width/p.height;aspect.Parent=root;root.Parent=parent
 end)
 if not ok then root:Destroy();error(err)end
 return root
end
return Core
