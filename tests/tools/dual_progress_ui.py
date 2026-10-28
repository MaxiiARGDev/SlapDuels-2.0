"""Build persistent progress cards and an Edit-only additive Studio patch."""
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
def dim(x,y): return {'UDim2':[[x,0],[y,0]]}
def color(r,g,b): return {'Color3':[r/255,g/255,b/255]}
def node(cls,props=None,**children): return {'$className':cls,'$properties':props or {},**children}
def label(text,x,y,w,h,z,accent=None):
 return node('TextLabel',dict(Text=text,Font='GothamBold',TextColor3=accent or color(234,243,255),BackgroundTransparency=1,TextScaled=True,TextWrapped=True,TextXAlignment='Left',Position=dim(x,y),Size=dim(w,h),ZIndex=z),Bounds=node('UITextSizeConstraint',dict(MinTextSize=7,MaxTextSize=17)))
def card(pas,z):
 accent=color(255,202,72) if pas else color(61,219,249)
 c=node('Frame',dict(BackgroundColor3=color(24,24,39) if pas else color(13,30,47),BorderSizePixel=0,ZIndex=z),Corner=node('UICorner',{'CornerRadius':{'UDim':[0,10]}}),Stroke=node('UIStroke',dict(Color=accent,Transparency=.55,Thickness=1)))
 c['Title']=label('PASE · ETAPA 0 → 1' if pas else 'JUGADOR · NIVEL 0 → 1',.04,.06,.92,.2,z+2,accent)
 c['XP']=label('0 / 800 EXP DEL PASE' if pas else '0 / 100 EXP',.04,.29,.92,.18,z+2)
 c['Track']=node('Frame',dict(Position=dim(.04,.52),Size=dim(.92,.09),BackgroundColor3=color(42,50,68),BorderSizePixel=0,ZIndex=z+1,ClipsDescendants=True),Corner=node('UICorner',{'CornerRadius':{'UDim':[0,6]}}),Fill=node('Frame',dict(Size=dim(0,1),BackgroundColor3=accent,BorderSizePixel=0,ZIndex=z+2),Corner=node('UICorner',{'CornerRadius':{'UDim':[0,6]}})))
 c['Hint']=label('Próximo: premio de temporada' if pas else 'Faltan 100 EXP para subir de nivel',.04,.65,.92,.27 if not pas else .16,z+2)
 if pas:c['Open']=node('TextButton',dict(Text='VER PASE',Font='GothamBold',TextColor3=accent,TextScaled=True,BackgroundTransparency=1,Position=dim(.04,.83),Size=dim(.92,.14),ZIndex=z+3),Bounds=node('UITextSizeConstraint',dict(MinTextSize=7,MaxTextSize=12)))
 return c
def cards(z,vertical=False):
 c=node('Frame',dict(BackgroundTransparency=1,ZIndex=z),Player=card(False,z+1),Pass=card(True,z+1))
 for i,k in enumerate(['Player','Pass']):
  c[k]['$properties'].update(Position=dim(0,i*.52) if vertical else dim(i*.51,0),Size=dim(1,.48) if vertical else dim(.49,1))
 return c

operations=[]
def props(path,values):operations.append({'Path':path,'Props':values})
def install(path,name,tree):operations.append({'Path':path,'Name':name,'Tree':tree})
for filename in ['ProgressionHUD','PlayerProfileHUD']:
 p=ROOT/f'src/ui/{filename}.project.json';doc=json.loads(p.read_text(encoding='utf-8'));tree=doc['tree'];main=tree['MainFrame'];base=f'StarterGui.{filename}'
 if filename=='ProgressionHUD':
  c=cards(81,True);c['$properties'].update(Position=dim(.015,.725),Size=dim(.29,.25),Visible=False)
  c['Bounds']=node('UISizeConstraint',dict(MinSize={'Vector2':[245,0]},MaxSize={'Vector2':[390,1000]}))
  tree['ProgressCards']=c;install(base,'ProgressCards',c)
  tree['Bar']['$properties']['Visible']=False;props(base+'.Bar',{'Visible':False})
  tree['OpenButton']['$properties'].update(Position=dim(.015,.67),Size=dim(.15,.045));props(base+'.OpenButton',{'Position':dim(.015,.67),'Size':dim(.15,.045)})
  c=cards(83);c['$properties'].update(Position=dim(.035,.195),Size=dim(.93,.235));main['ProgressCards']=c;install(base+'.MainFrame','ProgressCards',c)
  main['Progress']['$properties']['Visible']=False;props(base+'.MainFrame.Progress',{'Visible':False})
  main['Rewards']['$properties'].update(Position=dim(.03,.46),Size=dim(.94,.28));props(base+'.MainFrame.Rewards',{'Position':dim(.03,.46),'Size':dim(.94,.28)})
 else:
  c=cards(4);c['$properties'].update(Position=dim(.035,.35),Size=dim(.93,.15));main['ProgressCards']=c;install(base+'.MainFrame','ProgressCards',c)
  main['Summary']['$properties'].update(Position=dim(.035,.52),Size=dim(.93,.19));props(base+'.MainFrame.Summary',{'Position':dim(.035,.52),'Size':dim(.93,.19)})
  main['Progression']['$properties']['Text']='NIVEL DEL JUGADOR';props(base+'.MainFrame.Progression',{'Text':'NIVEL DEL JUGADOR'})
  for stat in ['Streak','Wins','Kills']:
   main['Summary'][stat]['StatIcon']['Aspect']['$properties']['DominantAxis']='Height'
   props(base+'.MainFrame.Summary.'+stat+'.StatIcon.Aspect',{'DominantAxis':'Height'})
 p.write_text(json.dumps(doc,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

payload=json.dumps(operations,ensure_ascii=False,separators=(',',':'))
code="""assert(not game:GetService('RunService'):IsRunning(),'Edit required')
local ops=game:GetService('HttpService'):JSONDecode([==[PAYLOAD]==])
local function value(k,v)
 if type(v)~='table'then return v end
 if v.UDim2 then local a=v.UDim2;return UDim2.new(a[1][1],a[1][2],a[2][1],a[2][2])end
 if v.Color3 then return Color3.new(unpack(v.Color3))end
 if v.UDim then return UDim.new(unpack(v.UDim))end
 if v.Vector2 then return Vector2.new(unpack(v.Vector2))end
 error('Unknown property '..k)
end
local function set(o,p)
 for k,v in pairs(p)do
  if k=='Font'then o[k]=Enum.Font[v]elseif k=='TextXAlignment'then o[k]=Enum.TextXAlignment[v]elseif k=='DominantAxis'then o[k]=Enum.DominantAxis[v]else o[k]=value(k,v)end
 end
end
local function build(name,t)
 local o=Instance.new(t['$className']);o.Name=name;set(o,t['$properties']or {})
 for k,v in pairs(t)do if k:sub(1,1)~='$'then build(k,v).Parent=o end end
 if o:IsA('TextLabel')or o:IsA('TextButton')then o.TextScaled=true end
 return o
end
for _,op in ipairs(ops)do
 local o=game;for part in op.Path:gmatch('[^.]+')do o=assert(o:FindFirstChild(part),'Missing '..op.Path)end
 if op.Tree then assert(not o:FindFirstChild(op.Name),'Existing '..op.Name..'; preserve and inspect');build(op.Name,op.Tree).Parent=o else set(o,op.Props)end
end
-- Preserve optional Studio-authored image icons while fitting the compact stats.
for _,name in ipairs({'Streak','Wins','Kills'})do
 local icon=game.StarterGui.PlayerProfileHUD.MainFrame.Summary[name].StatIcon
 local image=icon:FindFirstChild('IconImage')
 if image and image:IsA('ImageLabel')then image.Size=UDim2.fromScale(1,1);image.Position=UDim2.fromScale(0,0);image.AnchorPoint=Vector2.zero end
end
return 'Installed dual progress cards in Edit'
""".replace('PAYLOAD',payload)
(ROOT/'tests/ProgressionV2.install.edit.luau').write_text(code,encoding='utf-8')
print('Updated 2 UI projects; generated Edit patch')
