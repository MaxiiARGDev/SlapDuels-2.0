"""Editable profile redesign and additive social request/group HUD; no Studio calls."""
from pathlib import Path
import copy,json
r=Path(__file__).resolve().parents[2]
def ud(x,y):return {'UDim2':[[x,0],[y,0]]}
def col(rgb):return {'Color3':[n/255 for n in rgb]}
def seq(points):return {'ColorSequence':{'keypoints':[{'time':t,'color':c}for t,c in points]}}
def node(cls,**props):return {'$className':cls,'$properties':props}
def label(text,pos,size,color=(255,255,255),font='GothamBold'):
 return node('TextLabel',Text=text,Position=ud(*pos),Size=ud(*size),BackgroundTransparency=1,TextColor3=col(color),Font=font,TextSize=20,TextScaled=True,TextWrapped=True,TextStrokeTransparency=.25,TextStrokeColor3=col((0,0,0)),BorderSizePixel=0)
def panel(pos,size,color):
 v=node('Frame',Position=ud(*pos),Size=ud(*size),BackgroundColor3=col(color),BorderSizePixel=0)
 v['Corner']=node('UICorner',CornerRadius={'UDim':[0,10]})
 v['Stroke']=node('UIStroke',Color=col((96,89,78)),Thickness=2)
 return v
def button(text,pos,size,color):
 v=label(text,pos,size);v['$className']='TextButton';v['$properties'].update(BackgroundTransparency=0,BackgroundColor3=col(color),AutoButtonColor=False,Active=True,Selectable=True)
 v['Corner']=node('UICorner',CornerRadius={'UDim':[0,7]});v['Stroke']=node('UIStroke',Color=col((210,210,205)),Thickness=1.5,ApplyStrokeMode='Border')
 v['Gradient']=node('UIGradient',Color=seq([[0,[1,1,1]],[1,[.48,.48,.48]]]),Rotation=90)
 return v
path=r/'src/ui/PlayerProfileHUD.project.json';v=json.loads(path.read_text(encoding='utf-8'));m=v['tree']['MainFrame'];p=m['$properties']
p.update(Size=ud(.94,.82),BackgroundColor3=col((29,24,20)))
m['Bounds']['$properties'].update(MaxSize={'Vector2':[1000,620]},MinSize={'Vector2':[300,300]})
m['Stroke']['$properties'].update(Color=col((126,113,91)),Thickness=3)
m['BackgroundGradient']=node('UIGradient',Color=seq([[0,[.23,.21,.18]],[.5,[.06,.04,.025]],[1,[.16,.11,.07]]]),Rotation=25)
m['Title']['$properties'].update(Visible=False)
m['Avatar']['$properties'].update(Position=ud(.02,.035),Size=ud(.135,.235),BackgroundColor3=col((11,11,10)))
m['Avatar']['Border']=node('UIStroke',Color=col((150,145,130)),Thickness=2)
m['Identity']['$properties'].update(Position=ud(.17,.045),Size=ud(.69,.17),TextScaled=True,TextXAlignment='Left',TextStrokeTransparency=0,TextColor3=col((255,255,255)),Font='GothamBlack')
m['Progression']['$properties'].update(Position=ud(.17,.225),Size=ud(.69,.045),TextScaled=True,TextXAlignment='Left',TextColor3=col((165,160,150)))
m['Close']=button('X',(.91,.035),(.065,.115),(230,48,45))
m['Stats']['$properties'].update(Visible=False)
m['Summary']=panel((.02,.31),(.96,.40),(13,10,8))
for i,(name,title,color)in enumerate([('Streak','RACHAS',(255,140,20)),('Wins','VICTORIAS',(244,218,45)),('Kills','KILLS',(245,45,40))]):
 card=panel((.015+i*.205,.06),(.19,.88),tuple(int(c*.16)for c in color));card['Stroke']['$properties']['Color']=col(color)
 card['Value']=label('0',(.05,.14),(.9,.43),color);card['Caption']=label(title,(.04,.65),(.92,.22))
 m['Summary'][name]=card
m['Summary']['Equipped']=panel((.645,.06),(.34,.88),(35,35,33))
m['Summary']['Equipped']['Preview']=copy.deepcopy(m['Avatar']);m['Summary']['Equipped']['Preview']['$properties'].update(Position=ud(.04,.05),Size=ud(.92,.66),BackgroundTransparency=1)
m['Summary']['Equipped']['Caption']=label('SLAP EQUIPADO',(.03,.75),(.94,.19))
m['Collection']['$properties'].update(Position=ud(.02,.31),Size=ud(.96,.40),Visible=False)
for name,pos,size in [('Previous',(.02,.735),(.12,.06)),('Page',(.17,.735),(.66,.06)),('Next',(.86,.735),(.12,.06))]:m[name]['$properties'].update(Position=ud(*pos),Size=ud(*size),Visible=False,TextScaled=True)
m['Status']['$properties'].update(Position=ud(.02,.795),Size=ud(.96,.045),TextScaled=True)
for i,(name,text,color)in enumerate([('Articles','Ver artículos',(38,165,245)),('Challenge','Desafío',(235,55,65)),('Invite','Invitar',(104,220,15)),('Trade','Intercambio',(245,204,30))]):
 m[name]=button(text,(.02+i*.245,.87),(.225,.095),color)
path.write_text(json.dumps(v,indent=2,ensure_ascii=True)+'\n',encoding='utf-8')
root={'name':'SocialPlayHUD','tree':node('ScreenGui',Enabled=True,ResetOnSpawn=False,DisplayOrder=95,IgnoreGuiInset=False,ZIndexBehavior='Sibling')};t=root['tree']
t['RequestPanel']=panel((.25,.32),(.5,.34),(29,24,20));t['RequestPanel']['$properties']['Visible']=False
t['RequestPanel']['Bounds']=node('UISizeConstraint',MinSize={'Vector2':[240,160]},MaxSize={'Vector2':[650,320]})
t['RequestPanel']['Message']=label('',(.05,.07),(.9,.36));t['RequestPanel']['Countdown']=label('',(.3,.47),(.4,.15))
t['RequestPanel']['Accept']=button('Aceptar',(.05,.72),(.42,.2),(75,200,20));t['RequestPanel']['Decline']=button('Rechazar',(.53,.72),(.42,.2),(225,55,50))
t['GroupPanel']=panel((.01,.57),(.3,.25),(24,24,22));t['GroupPanel']['$properties']['Visible']=False
t['GroupPanel']['Bounds']=node('UISizeConstraint',MinSize={'Vector2':[220,115]},MaxSize={'Vector2':[400,190]})
t['GroupPanel']['Members']=label('',(.03,.04),(.94,.56));t['GroupPanel']['Leave']=button('Salir',(.03,.69),(.43,.25),(220,80,45));t['GroupPanel']['Disband']=button('Disolver',(.52,.69),(.45,.25),(170,80,45))
t['Notice']=label('',(.17,.24),(.66,.07),(255,222,110));t['Notice']['$properties']['Visible']=False
(r/'src/ui/SocialPlayHUD.project.json').write_text(json.dumps(root,indent=2)+'\n',encoding='utf-8')
for file in ['default.project.json','studio-safe.project.json']:
 p=r/file;j=json.loads(p.read_text(encoding='utf-8'));j['tree']['StarterGui']['SocialPlayHUD']={'$path':'src/ui/SocialPlayHUD.project.json','$ignoreUnknownInstances':True}
 j['tree']['ReplicatedStorage']['Remotes']['SocialPlay']={'$className':'Folder','$ignoreUnknownInstances':True,'Request':{'$className':'RemoteFunction'},'Updated':{'$className':'RemoteEvent'}}
 p.write_text(json.dumps(j,indent=2)+'\n',encoding='utf-8')
print('Editable profile redesign and SocialPlayHUD generated')
