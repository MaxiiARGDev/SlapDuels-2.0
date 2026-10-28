"""Generate only new editable social HUD projects; never rewrite existing HUDs."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[2]
def u(xs=0,x=0,ys=0,y=0):return {'UDim2':[[xs,x],[ys,y]]}
def color(r,g,b):return {'Color3':[r/255,g/255,b/255]}
def obj(cls,props=None,**children):return {'$className':cls,'$properties':props or {},**children}
def label(text,pos,size,button=False):
 p=dict(Text=text,Position=pos,Size=size,TextColor3=color(224,239,249),BackgroundTransparency=0 if button else 1,BackgroundColor3=color(25,65,85),BorderSizePixel=0,TextSize=15,Font='GothamBold',TextWrapped=True)
 n=obj('TextButton'if button else'TextLabel',p)
 if button:n['Corner']=obj('UICorner',{'CornerRadius':{'UDim':[0,8]}})
 return n
def viewport(pos,size):return obj('ViewportFrame',dict(Position=pos,Size=size,BackgroundColor3=color(12,20,32),BorderSizePixel=0,Ambient=color(170,178,194),LightColor=color(230,235,245),LightDirection={'Vector3':[-1,-1,-1]}))
def scroller(pos,size):return obj('ScrollingFrame',dict(Position=pos,Size=size,BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=5,AutomaticCanvasSize='Y',CanvasSize=u()),Grid=obj('UIGridLayout',dict(CellSize=u(0.48,0,0,150),CellPadding=u(0.02,0,0,12),SortOrder='LayoutOrder')))
def root(name):
 main=obj('CanvasGroup',dict(AnchorPoint={'Vector2':[.5,.5]},Position=u(.5,0,.5,0),Size=u(.94,0,.90,0),BackgroundColor3=color(10,16,27),BorderSizePixel=0,GroupTransparency=0),
  Corner=obj('UICorner',{'CornerRadius':{'UDim':[0,14]}}),Stroke=obj('UIStroke',{'Color':color(35,146,182),'Thickness':1.5}),
  Bounds=obj('UISizeConstraint',{'MaxSize':{'Vector2':[1060,780]},'MinSize':{'Vector2':[280,250]}}),
  Title=label(name,u(0,16,0,8),u(1,-80,0,32)),Close=label('X',u(1,-52,0,10),u(0,36,0,32),True),
  Status=label('',u(0,12,1,-60),u(1,-24,0,24)))
 audio=obj('Folder')
 for sound in ['Open','Close','Click','Hover','Accept','Confirm','Cancel','Error','TradeCompleted']:audio[sound]=obj('Sound',{'SoundId':'','Volume':.25,'PlaybackSpeed':1})
 return obj('ScreenGui',dict(ResetOnSpawn=False,IgnoreGuiInset=False,DisplayOrder=90,Enabled=False,ZIndexBehavior='Sibling'),MainFrame=main,Audio=audio)
def card():
 return obj('TextButton',dict(Visible=False,Size=u(0,130,0,180),BackgroundColor3=color(18,28,44),BorderSizePixel=0,Text='',AutoButtonColor=False),
  Corner=obj('UICorner',{'CornerRadius':{'UDim':[0,9]}}),Accent=obj('UIStroke',{'Color':color(73,181,217),'Thickness':1.5}),
  Aura=obj('Frame',dict(Position=u(.02,0,.01,0),Size=u(.96,0,.44,0),BackgroundColor3=color(50,140,180),BackgroundTransparency=.82,BorderSizePixel=0),Corner=obj('UICorner',{'CornerRadius':{'UDim':[0,12]}}),Gradient=obj('UIGradient',{'Rotation':45})),
  Preview=viewport(u(.04,0,.03,0),u(.92,0,.41,0)),ItemName=label('',u(.03,0,.46,0),u(.94,0,.14,0)),
  Variation=label('',u(.03,0,.60,0),u(.94,0,.10,0)),State=label('',u(.03,0,.70,0),u(.94,0,.10,0)),UnitId=label('',u(.03,0,.80,0),u(.94,0,.20,0)))
profile=root('PERFIL DEL JUGADOR');m=profile['MainFrame']
m.update(Avatar=viewport(u(.025,0,.09,0),u(.28,0,.48,0)),Identity=label('',u(.025,0,.59,0),u(.28,0,.11,0)),
 Stats=label('',u(.025,0,.71,0),u(.28,0,.12,0)),Progression=label('Nivel y EXP pendientes',u(.025,0,.84,0),u(.28,0,.06,0)),
 Collection=scroller(u(.34,0,.09,0),u(.635,0,.72,0)),Page=label('',u(.49,0,.83,0),u(.30,0,0,28)),
 Previous=label('<',u(.34,0,.83,0),u(.12,0,0,28),True),Next=label('>',u(.84,0,.83,0),u(.135,0,0,28),True),
 Trade=label('SOLICITAR TRADE',u(.34,0,1,-35),u(.635,0,0,30),True))
profile['CardTemplate']=card()
request=root('SOLICITUD DE TRADE');m=request['MainFrame'];m['$properties']['Size']=u(.88,0,.40,0)
m.update(Avatar=viewport(u(.04,0,.2,0),u(.23,0,.45,0)),Requester=label('',u(.30,0,.2,0),u(.65,0,.28,0)),
 Countdown=label('',u(.30,0,.5,0),u(.65,0,.1,0)),Accept=label('ACEPTAR',u(.06,0,1,-40),u(.42,0,0,32),True),Decline=label('RECHAZAR',u(.52,0,1,-40),u(.42,0,0,32),True))
trade=root('INTERCAMBIO DE SLAPS');m=trade['MainFrame']
for name,x,text in [('Mine',.025,'MIS OFERTAS'),('Theirs',.515,'OFERTA DEL OTRO JUGADOR')]:
 column=obj('Frame',dict(Position=u(x,0,.08,0),Size=u(.46,0,.72,0),BackgroundTransparency=1),
  Name=label(text,u(),u(1,0,0,28)),Avatar=viewport(u(.03,0,.07,0),u(.28,0,.17,0)),
  Identity=label('',u(.34,0,.07,0),u(.64,0,.17,0)),Offers=scroller(u(0,0,.26,0),u(1,0,.36,0)),Accepted=label('',u(0,0,.63,0),u(1,0,.08,0)))
 if name=='Mine':column['Inventory']=scroller(u(0,0,.73,0),u(1,0,.27,0))
 else:column['Summary']=label('Revisá artículos, variaciones e identidad antes de confirmar.',u(0,0,.74,0),u(1,0,.25,0))
 m[name]=column
m.update(Accept=label('ACEPTAR OFERTA',u(.025,0,1,-38),u(.29,0,0,30),True),
 Confirm=label('CONFIRMAR INTERCAMBIO',u(.335,0,1,-38),u(.40,0,0,30),True),Cancel=label('CANCELAR',u(.755,0,1,-38),u(.22,0,0,30),True),
 Page=label('',u(.15,0,.81,0),u(.22,0,0,24)),Previous=label('<',u(.025,0,.81,0),u(.10,0,0,24),True),Next=label('>',u(.39,0,.81,0),u(.10,0,0,24),True))
trade['CardTemplate']=card()
for name,tree in [('PlayerProfileHUD',profile),('TradeRequestHUD',request),('TradeHUD',trade)]:
 (ROOT/'src/ui'/f'{name}.project.json').write_text(json.dumps({'name':name,'tree':tree},ensure_ascii=False,indent=2),encoding='utf-8')
for project in ['default.project.json','studio-safe.project.json']:
 p=ROOT/project;d=json.loads(p.read_text(encoding='utf-8'));gui=d['tree'].setdefault('StarterGui',{'$className':'StarterGui','$ignoreUnknownInstances':True})
 for name in ['PlayerProfileHUD','TradeRequestHUD','TradeHUD']:
  mapping={'$path':f'src/ui/{name}.project.json','$ignoreUnknownInstances':True}
  assert name not in gui or gui[name]==mapping,'Refusing to replace existing social HUD mapping'
  gui[name]=mapping
 remotes=d['tree']['ReplicatedStorage'].setdefault('Remotes',{'$className':'Folder','$ignoreUnknownInstances':True})
 mapping={'$className':'Folder','$ignoreUnknownInstances':True,'Inspect':{'$className':'RemoteFunction'},'Action':{'$className':'RemoteFunction'},'Updated':{'$className':'RemoteEvent'}}
 assert 'Social'not in remotes or remotes['Social']==mapping,'Refusing to replace existing social remotes'
 remotes['Social']=mapping
 p.write_text(json.dumps(d,ensure_ascii=False,indent=2),encoding='utf-8')
print('Generated three new HUD projects and additive mappings only.')
