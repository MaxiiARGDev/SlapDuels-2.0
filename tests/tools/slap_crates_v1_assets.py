"""Build editable placeholder resources. No production prices/odds/stock or audio IDs."""
import colorsys
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
IDS=['Basic','Common','Uncommon','Rare','Gold','Arcoiris','Emote','Wings','Epic','Legendary','Blood','Galaxy']
def node(cls,props=None,**children):return {'$className':cls,'$properties':props or {},**children}
def ud(x,y,w,z):return {'UDim2':[[x,y],[w,z]]}
def color(i):return {'Color3':list(colorsys.hsv_to_rgb(i/12,.45,.95))}
def box(x,y,w,h):return {'Position':ud(0,x,0,y),'Size':ud(0,w,0,h),'BorderSizePixel':0}
def text(txt,x,y,w,h,cls='TextLabel'):
 return node(cls,{**box(x,y,w,h),'Text':txt,'TextSize':16,'TextColor3':{'Color3':[1,1,1]},'BackgroundColor3':{'Color3':[.08,.10,.15]},'TextWrapped':True,'ZIndex':65})
def write(path,name,tree):
 (ROOT/path).parent.mkdir(parents=True,exist_ok=True)
 (ROOT/path).write_text(json.dumps({'name':name,'tree':tree},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
panel=node('Frame',{'AnchorPoint':{'Vector2':[.5,.5]},'Position':ud(.5,0,.5,0),'Size':ud(.9,0,.8,0),'BackgroundColor3':{'Color3':[.05,.12,.32]},'Visible':False,'ZIndex':60},
 UISizeConstraint=node('UISizeConstraint',{'MaxSize':{'Vector2':[760,550]},'MinSize':{'Vector2':[310,340]}}),
 UICorner=node('UICorner',{'CornerRadius':{'UDim':[0,12]}}),
 Title=text('CAJAS',16,12,520,32),Close=text('X',0,0,40,32,'TextButton'),
 Count=text('Cajas cerradas: 0',16,52,400,26),Status=text('Comercio pendiente de aprobación',16,84,650,42),
 Outcomes=text('Ver probabilidades antes de comprar.',16,132,650,270),
 ViewOdds=text('VER PROBABILIDADES',16,420,210,40,'TextButton'),
 Buy=text('COMPRAR CAJA',236,420,170,40,'TextButton'),Open=text('ABRIR CAJA',416,420,170,40,'TextButton'),
 Receipt=text('VER ÚLTIMO PREMIO',16,470,260,36,'TextButton'))
panel['Close']['$properties']['Position']=ud(1,-48,0,12)
panel['Outcomes']['$properties'].update({'Size':ud(1,-32,1,-245),'TextYAlignment':'Top','TextXAlignment':'Left'})
panel['Status']['$properties']['Size']=ud(1,-32,0,42)
for key,xx,ww in [('ViewOdds',0,.36),('Buy',.37,.3),('Open',.69,.3)]:
 panel[key]['$properties'].update({'Position':ud(xx,8,1,-96),'Size':ud(ww,-12,0,40)})
panel['Receipt']['$properties']['Position']=ud(0,16,1,-48)
write('src/ui/CratePanel.project.json','CratePanel',panel)
card=node('Frame',{**box(0,0,132,140),'Visible':False,'BackgroundColor3':{'Color3':[.12,.15,.24]},'ZIndex':72},Title=text('RECOMPENSA',4,38,124,62),UICorner=node('UICorner'))
card['Title']['$properties']['ZIndex']=73
spin=node('Frame',{'AnchorPoint':{'Vector2':[.5,.5]},'Position':ud(.5,0,.5,0),'Size':ud(.94,0,0,320),'Visible':False,'BackgroundColor3':{'Color3':[.05,.12,.32]},'ZIndex':70},
 UICorner=node('UICorner'),UISizeConstraint=node('UISizeConstraint',{'MaxSize':{'Vector2':[860,320]}}),
 Window=node('Frame',{'Position':ud(0,16,0,48),'Size':ud(1,-32,0,140),'ClipsDescendants':True,'BackgroundColor3':{'Color3':[.08,.10,.15]},'ZIndex':71},
  RollingStrip=node('Frame',{'Size':ud(0,6300,0,140),'BackgroundTransparency':1,'ZIndex':72},RewardTemplate=card)),
 Indicator=node('Frame',{'Position':ud(.5,-2,0,40),'Size':ud(0,4,0,158),'BackgroundColor3':{'Color3':[1,.8,.2]},'BorderSizePixel':0,'ZIndex':76}),
 Result=text('Abriendo…',16,204,800,44),Close=text('CERRAR',16,262,160,40,'TextButton'),
 Tick=node('Sound',{'Volume':.25}),Reveal=node('Sound',{'Volume':.4}))
spin['Result']['$properties'].update({'Size':ud(1,-32,0,44),'ZIndex':75})
spin['Close']['$properties']['ZIndex']=75
write('src/ui/CrateSpinPanel.project.json','CrateSpinPanel',spin)
actions=node('Frame',{'Position':ud(0,8,0,38),'Size':ud(1,-16,0,26),'BackgroundTransparency':1,'Visible':False},
 ViewOdds=text('VER PROB.',0,0,80,26,'TextButton'),Action=text('VER CAJA',82,0,90,26,'TextButton'))
actions['ViewOdds']['$properties'].update({'Size':ud(.49,0,1,0),'TextSize':11})
actions['Action']['$properties'].update({'Position':ud(.51,0,0,0),'Size':ud(.49,0,1,0),'TextSize':11})
write('src/ui/CrateActionsTemplate.project.json','CrateActionsTemplate',actions)
tab=node('TextButton',{'Size':ud(0,120,0,54),'Text':'CAJAS','TextSize':18,'TextColor3':{'Color3':[1,1,1]},
 'BackgroundColor3':{'Color3':[.08,.10,.15]},'LayoutOrder':60,'Attributes':{'Category':{'String':'Crates'}}},UICorner=node('UICorner'))
write('src/ui/CratesTab.project.json','CratesTab',tab)
effects=node('Folder');variations=node('Folder');previews=node('Folder')
for i,id in enumerate(IDS):
 part={'Anchored':True,'CanCollide':False,'CanTouch':False,'CanQuery':False,'CastShadow':False,'Color':color(i)}
 effects[id]=node('Model',None,
  Body=node('Part',{**part,'Size':{'Vector3':[2.6,2,2.2]}}),
  Lid=node('Part',{**part,'Size':{'Vector3':[2.8,.4,2.4]},'Position':{'Vector3':[0,1.2,0]}}),
  Reveal=node('Sound',{'Volume':.4}))
 effects[id]['Body']['Burst']=node('ParticleEmitter',{'Enabled':False,'Rate':0,'Lifetime':{'NumberRange':[.4,.8]},'Speed':{'NumberRange':[2,5]},'SpreadAngle':{'Vector2':[180,180]}})
 variations[id]=node('Folder',{'Attributes':{'Tint':color(i),'DesignPending':{'Bool':True}}},
  Sparkles=node('ParticleEmitter',{'Enabled':False,'Rate':0,'Lifetime':{'NumberRange':[.4,.8]},'Speed':{'NumberRange':[2,5]}}),
  Reveal=node('Sound',{'Volume':.4}))
previews['Classic']=node('Model',None,Hand=node('Part',{'Anchored':True,'CanCollide':False,'CanTouch':False,'CanQuery':False,'Size':{'Vector3':[1.5,.5,1]},'Color':{'Color3':[.9,.9,.9]}}))
previews['Classic']['Hand']['$properties']['Size']={'Vector3':[2.300506353378296,3.1455867290496828,1.088670015335083]}
previews['Classic']['Hand']['Mesh']=node('SpecialMesh',{'MeshType':'FileMesh','MeshId':'http://www.roblox.com/asset/?id=32054761','Scale':{'Vector3':[.5804947018623352,.6936213970184326,.79637610912323]}})
write('src/assets/CrateEffects.project.json','CrateEffects',effects)
write('src/assets/SlapVariationEffects.project.json','SlapVariationEffects',variations)
write('src/assets/CrateRewardPreviews.project.json','CrateRewardPreviews',previews)
project=ROOT/'default.project.json'
data=json.loads(project.read_text(encoding='utf-8'));tree=data['tree']
for name in ('CrateEffects','SlapVariationEffects','CrateRewardPreviews'):tree['ReplicatedStorage'][name]={'$path':f'src/assets/{name}.project.json'}
tree['ReplicatedStorage']['Remotes']['Crates']={'$className':'Folder',**{n:{'$className':c} for n,c in [('Request','RemoteFunction'),('Reveal','RemoteEvent'),('World','RemoteEvent'),('Announce','RemoteEvent')]}}
tree['ReplicatedStorage']['Remotes']['$ignoreUnknownInstances']=True
# Preserve all other ShopHUD resources; only these two new subtrees are managed.
shop=tree['StarterGui'].setdefault('ShopHUD',{'$className':'ScreenGui','$ignoreUnknownInstances':True})
# Existing ShopHUD is a binary asset. Extend that node rather than replacing its path.
for name in ('CratePanel','CrateSpinPanel','CrateActionsTemplate'):shop[name]={'$path':f'src/ui/{name}.project.json'}
shop['$ignoreUnknownInstances']=True
shop['MainFrame']={'$className':'Frame','$ignoreUnknownInstances':True,'Tabs':{'$className':'Frame','$ignoreUnknownInstances':True,'CratesTab':{'$path':'src/ui/CratesTab.project.json'}}}
project.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Generated physical editable resources and default mapping; SAFE unchanged')
