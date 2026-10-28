"""Author editable stand/overlay resources; no runtime economy or Studio execution."""
import json,copy,re
from pathlib import Path
root=Path(__file__).resolve().parents[2]
if (root/'src/assets/CrateVisualsV21/manifest.json').exists():
 raise SystemExit('Legacy generator disabled: preserve native CrateVisualsV21 snapshots; export current Studio visuals before any asset change.')
def obj(cls,props=None,**children):return {'$className':cls,'$properties':props or {},**children}
def vec(*v):return {'Vector3':list(v)}
def cf(x=0,y=0,z=0):return {'CFrame':[x,y,z,1,0,0,0,1,0,0,0,1]}
def color(*v):return {'Color3':list(v)}
def ud(x,y):return {'UDim2':[[x,0],[y,0]]}
def part(x,y,z,size=(1,1,1),visible=False):
 return obj('Part',dict(CFrame=cf(x,y,z),Size=vec(*size),Anchored=True,CanCollide=False,CanTouch=False,CanQuery=False,Transparency=0 if visible else 1,CastShadow=False))
def text(t,y,h=.25):return obj('TextLabel',{'Text':t,'Position':ud(0,y),'Size':ud(1,h),'BackgroundTransparency':1,'TextColor3':color(1,1,1),'TextScaled':True,'Font':'GothamBold'})
def billboard(title,price='',status=''):
 return obj('BillboardGui',{'Size':{'UDim2':[[0,220],[0,95]]},'StudsOffsetWorldSpace':vec(0,2,0),'AlwaysOnTop':False,'MaxDistance':65},Title=text(title,0,.35),Price=text(price,.38,.25),Status=text(status,.68,.25))
stand=obj('Model',{'Attributes':{'StandId':{'String':'Main'},'Enabled':{'Bool':True},'OpeningState':{'String':'Idle'}}})
stand['Base']=part(0,0,0,(12,1,10),True);stand['Base']['$properties']['Color']=color(.08,.1,.18)
stand['Base']['$properties']['CanCollide']=True
stand['Pedestal']=part(0,1,0,(5,1,4),True);stand['Pedestal']['$properties']['Color']=color(.18,.24,.4)
stand['InteractionPart']=part(0,1,4,(4,4,1));stand['InteractionPart']['ProximityPrompt']=obj('ProximityPrompt',{'ObjectText':'CAJAS','ActionText':'Abrir tienda','HoldDuration':0,'MaxActivationDistance':10,'RequiresLineOfSight':False})
stand['SpawnPoint']=part(0,2,0)
stand['RewardPoint']=part(0,5,0)
stand['CameraPoint']=part(0,6,12)
stand['BillboardAnchor']=part(0,5,-3);stand['BillboardAnchor']['BillboardGui']=billboard('SLAP CRATES','', 'CAJAS · INTERACTUÁ PARA VER')
effects=obj('Model')
fx=part(0,2,0)
fx['EnergyFrom']=obj('Attachment',{'Position':vec(-1,0,0)})
fx['EnergyTo']=obj('Attachment',{'Position':vec(1,2,0)})
fx['Particles']=obj('Attachment',{},Soft=obj('ParticleEmitter',{'Enabled':False,'Rate':0,'Lifetime':{'NumberRange':[.4,.8]},'Speed':{'NumberRange':[1,3]},'SpreadAngle':{'Vector2':[180,180]}}))
fx['Light']=obj('PointLight',{'Brightness':0,'Range':10,'Color':color(.6,.8,1)})
fx['EnergyBeam']=obj('Beam',{'Enabled':False,'Width0':.08,'Width1':.02,'FaceCamera':True})
for name in ['Start','Appear','Rise','Growth','Shake','Flash','Reward','Special','Outro']:
 fx[name]=obj('Sound',{'SoundId':'','Volume':.45,'RollOffMaxDistance':65})
effects['FXAnchor']=fx
stand['Effects']=obj('Folder')
scene=obj('Model',{},Effects=effects,RewardAnchor=part(0,5,0))
scene['RewardBillboard']=obj('BillboardGui',{'Enabled':False,'Size':{'UDim2':[[0,280],[0,125]]},'StudsOffsetWorldSpace':vec(0,2,0),'MaxDistance':80},Title=text('¡RECOMPENSA OBTENIDA!',0,.25),Slap=text('SLAP',.3,.25),Variation=text('VARIACIÓN',.6,.35))
stand['PresentationTemplate']=scene
stand['PreviewAnchors']=obj('Folder')
assets=json.loads((root/'src/assets/CrateEffects.project.json').read_text(encoding='utf-8'))['tree']
approved=dict(re.findall(r'Id="([^"]+)",SortOrder=\d+,PriceCoins=(\d+)',(root/'src/shared/SlapCrates/CrateDefinitions.luau').read_text(encoding='utf-8')))
for i,crate in enumerate(['Basic','Common','Uncommon'],1):
 price=approved[crate]
 anchor=part((i-2)*3.5,2,-2)
 anchor['$properties']['Attributes']={'CrateId':{'String':crate}}
 decor=copy.deepcopy(assets[crate]);anchor['Decoration']=decor
 # Translate authored geometry without mutating the original assets.
 def shift(node):
  props=node.get('$properties',{})
  if node.get('$className')=='Part':
   position=props.pop('Position',{}).get('Vector3',[0,0,0])
   old=props.get('CFrame',{}).get('CFrame',[*position,1,0,0,0,1,0,0,0,1])
   old=old.copy();old[0]+=(i-2)*3.5;old[1]+=2;old[2]-=2;props['CFrame']={'CFrame':old}
  for k,v in node.items():
   if not k.startswith('$') and isinstance(v,dict):shift(v)
 shift(decor)
 anchor['BillboardGui']=billboard('Caja '+crate,str(price)+' Coins','Probabilidades pendientes')
 stand['PreviewAnchors']['Preview_'+str(i)]=anchor
# Initial placement adjoining the observed lobby SpawnLocation. Animation never uses these coordinates.
origin=(-46.56125557,16.07930756,197.2275994)
rot=(.50000006,0,-.866025627,0,1,0,.866025805,0,.50000006)
def place(node):
 props=node.get('$properties',{})
 if node.get('$className')=='Part':
  v=props['CFrame']['CFrame'];x,y,z=v[:3]
  props.pop('CFrame')
  props['Position']=vec(origin[0]+rot[0]*x+rot[2]*z,origin[1]+y,origin[2]+rot[6]*x+rot[8]*z)
  props['Orientation']=vec(0,-60,0)
 for k,v in node.items():
  if not k.startswith('$') and isinstance(v,dict):place(v)
place(stand)
folder=obj('Folder',{},MainCrateStand=stand)
(root/'src/assets/CrateStands.project.json').write_text(json.dumps({'name':'CrateStands','tree':folder},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
hud=obj('ScreenGui',{'Enabled':False,'ResetOnSpawn':False,'IgnoreGuiInset':True,'DisplayOrder':90,'ZIndexBehavior':'Sibling'})
for name,c,z in [('Transition',(0,0,0),100),('Flash',(1,1,1),99)]:
 hud[name]=obj('Frame',{'Size':ud(1,1),'BackgroundColor3':color(*c),'BackgroundTransparency':1,'BorderSizePixel':0,'ZIndex':z,'Active':False})
(root/'src/ui/CrateOpeningHUD.project.json').write_text(json.dumps({'name':'CrateOpeningHUD','tree':hud},indent=2)+'\n',encoding='utf-8')
project=root/'default.project.json';p=json.loads(project.read_text(encoding='utf-8'))
p['tree'].setdefault('Workspace',{'$className':'Workspace','$ignoreUnknownInstances':True})['CrateStands']={'$path':'src/assets/CrateStands.project.json'}
p['tree']['StarterGui']['CrateOpeningHUD']={'$path':'src/ui/CrateOpeningHUD.project.json'}
p['tree']['ReplicatedStorage']['Remotes']['Crates']['StandPresentation']={'$className':'RemoteEvent'}
project.write_text(json.dumps(p,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Authored stand + overlay templates. Existing UI/model geometry untouched.')
