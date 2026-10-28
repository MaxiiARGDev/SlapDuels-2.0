"""Create only AdminHUD/TrainingHUD editable projects and additive mappings."""
from pathlib import Path
import json
r=Path(__file__).resolve().parents[2]
def u(x=0,y=0,dx=0,dy=0):return {'UDim2':[[x,dx],[y,dy]]}
def c(rgb):return {'Color3':[v/255 for v in rgb]}
def n(cls,**props):return {'$className':cls,'$properties':props}
def panel(pos,size):
 v=n('Frame',Position=pos,Size=size,BackgroundColor3=c((19,29,45)),BorderSizePixel=0)
 v['Corner']=n('UICorner',CornerRadius={'UDim':[0,12]});v['Stroke']=n('UIStroke',Color=c((77,142,181)),Thickness=1.5)
 return v
def label(text,pos,size,cap=16):
 v=n('TextLabel',Text=text,Position=pos,Size=size,BackgroundTransparency=1,TextColor3=c((232,241,255)),Font='GothamBold',TextSize=cap,TextScaled=True,TextWrapped=True)
 v['Bounds']=n('UITextSizeConstraint',MinTextSize=8,MaxTextSize=cap)
 return v
def button(text,pos,size,color=(31,116,166)):
 v=label(text,pos,size);v['$className']='TextButton';v['$properties'].update(BackgroundTransparency=0,BackgroundColor3=c(color),AutoButtonColor=True,BorderSizePixel=0)
 v['Corner']=n('UICorner',CornerRadius={'UDim':[0,7]});return v
def scroll(pos,size):
 v=n('ScrollingFrame',Position=pos,Size=size,BackgroundTransparency=1,BorderSizePixel=0,AutomaticCanvasSize='Y',CanvasSize=u(),ScrollBarThickness=4,ScrollBarImageColor3=c((109,197,242)))
 v['Layout']=n('UIListLayout',Padding={'UDim':[0,8]},SortOrder='LayoutOrder');return v
admin={'name':'AdminHUD','tree':n('ScreenGui',Enabled=True,ResetOnSpawn=False,DisplayOrder=110,IgnoreGuiInset=False,ZIndexBehavior='Sibling')};a=admin['tree']
a['OpenButton']=button('ADMIN',u(.007,.18,dy=48),u(dx=142,dy=40),(140,92,21));a['OpenButton']['$properties'].update(Visible=False,Active=False)
m=panel(u(.5,.5),u(.9,.84));m['$properties'].update(AnchorPoint={'Vector2':[.5,.5]},Visible=False);m['Bounds']=n('UISizeConstraint',MinSize={'Vector2':[310,360]},MaxSize={'Vector2':[980,650]})
m['Title']=label('ADMINISTRACIÓN  /  SLAPDUELS',u(.03,.035),u(.83,.07),22)
m['Close']=button('X',u(1,0,-54,14),u(dx=38,dy=36),(182,47,65))
m['Commands']=scroll(u(.03,.16),u(.25,.64));m['Description']=label('Seleccioná un comando.',u(.32,.15),u(.65,.08),14)
m['Form']=scroll(u(.32,.26),u(.65,.51));m['Status']=label('',u(.03,.79),u(.94,.055),13)
m['Confirm']=button('APLICAR AL JUGADOR',u(.32,.875),u(.4,.075),(28,137,91));m['Refresh']=button('ACTUALIZAR',u(.03,.875),u(.25,.075));m['NewOperation']=button('NUEVA OPERACIÓN',u(.75,.875),u(.22,.075),(131,89,27))
a['MainFrame']=m
field=panel(u(),u(1,0,dy=202));field['$properties']['Visible']=False
field['Label']=label('Campo',u(.025,0,dy=6),u(.95,0,dy=24),14)
field['Input']=n('TextBox',Position=u(.025,0,dy=35),Size=u(.95,0,dy=35),BackgroundColor3=c((9,18,30)),TextColor3=c((235,244,255)),PlaceholderColor3=c((125,151,179)),Text='',PlaceholderText='',ClearTextOnFocus=False,Font='Gotham',TextSize=14,TextXAlignment='Left',BorderSizePixel=0)
field['Input']['Padding']=n('UIPadding',PaddingLeft={'UDim':[0,10]},PaddingRight={'UDim':[0,10]})
field['Choices']=scroll(u(.025,0,dy=82),u(.95,0,dy=110));a['FieldTemplate']=field
a['ChoiceTemplate']=button('Opción',u(),u(1,0,dx=-8,dy=28));a['ChoiceTemplate']['$properties']['Visible']=False
a['CommandTemplate']=button('Comando',u(),u(1,0,dx=-8,dy=48));a['CommandTemplate']['$properties']['Visible']=False
training={'name':'TrainingHUD','tree':n('ScreenGui',Enabled=True,ResetOnSpawn=False,DisplayOrder=80,IgnoreGuiInset=False,ZIndexBehavior='Sibling')};t=training['tree']
p=panel(u(.5,1,dy=-18),u(.65,0,dy=125));p['$properties'].update(AnchorPoint={'Vector2':[.5,1]},Visible=False);p['Bounds']=n('UISizeConstraint',MinSize={'Vector2':[285,125]},MaxSize={'Vector2':[690,125]})
p['Title']=label('ZONA DE PRÁCTICA  /  SIN PREMIOS',u(.03,.05),u(.76,.17),14)
p['Status']=label('Golpeá al maniquí. Durante el ragdoll no recibe otro impacto.',u(.03,.28),u(.94,.22),12)
p['Attack']=button('GOLPEAR',u(.03,.62),u(.64,.28));p['Exit']=button('SALIR',u(.71,.62),u(.26,.28),(169,53,68));t['Panel']=p
for name,definition in [('AdminHUD',admin),('TrainingHUD',training)]:
 (r/f'src/ui/{name}.project.json').write_text(json.dumps(definition,indent=2)+'\n',encoding='utf-8')
for name in ['default.project.json','studio-safe.project.json']:
 p=r/name;v=json.loads(p.read_text(encoding='utf-8'));tree=v['tree']
 for hud in ['AdminHUD','TrainingHUD']:tree['StarterGui'][hud]={'$path':f'src/ui/{hud}.project.json','$ignoreUnknownInstances':True}
 tree['ReplicatedStorage']['Remotes']['Admin']={'$className':'Folder','$ignoreUnknownInstances':True,'Request':{'$className':'RemoteFunction'}}
 tree['ReplicatedStorage']['Remotes']['Training']={'$className':'Folder','$ignoreUnknownInstances':True,**{k:{'$className':'RemoteEvent'}for k in ['Activate','Leave','Updated']}}
 p.write_text(json.dumps(v,indent=2)+'\n',encoding='utf-8')
print('AdminHUD, TrainingHUD and additive remote mappings authored')
