"""Editable crate gallery UI, transparent 3D windows, four primary actions only."""
import json
from pathlib import Path
r=Path(__file__).resolve().parents[2]
def c(rgb):return {'Color3':[x/255 for x in rgb]}
def u(x,y,w,h):return {'Position':{'UDim2':[[x,0],[y,0]]},'Size':{'UDim2':[[w,0],[h,0]]}}
def n(cls,props=None,**kids):return {'$className':cls,'$properties':props or {},**kids}
def frame(props,**kids):return n('Frame',{'BorderSizePixel':0,'ZIndex':61}|props,**kids)
def label(text,props):return n('TextLabel',{'Text':text,'Font':'GothamBold','TextColor3':c([235,243,255]),'TextScaled':True,'TextWrapped':True,'BackgroundTransparency':1,'ZIndex':65}|props)
def button(text,color,props):return n('TextButton',{'Text':text,'Font':'GothamBlack','TextColor3':c([255,255,255]),'TextScaled':True,'TextWrapped':True,'BackgroundColor3':c(color),'BorderSizePixel':0,'ZIndex':66,'Active':False,'AutoButtonColor':False}|props,Corner=n('UICorner',{'CornerRadius':{'UDim':[0,10]}}),Stroke=n('UIStroke',{'Color':c([225,235,255]),'Thickness':1,'Transparency':.6}))
dark=c([8,13,24]);tree=frame({'AnchorPoint':{'Vector2':[.5,.5]},'Position':{'UDim2':[[.5,0],[.5,0]]},'Size':{'UDim2':[[.9,0],[.8,0]]},'Visible':False,'BackgroundTransparency':1,'ZIndex':60},Bounds=n('UISizeConstraint',{'MinSize':{'Vector2':[320,360]},'MaxSize':{'Vector2':[1060,660]}}))
tree['Header']=frame({'BackgroundColor3':dark,**u(0,0,1,.22)})
tree['Footer']=frame({'BackgroundColor3':dark,**u(0,.73,1,.27)})
tree['LeftMask']=frame({'BackgroundColor3':dark,**u(0,.22,.025,.51)})
tree['RightMask']=frame({'BackgroundColor3':dark,**u(.975,.22,.025,.51)})
tree['Title']=label('CAJA GOLD',{'TextColor3':c([255,207,76]),'TextXAlignment':'Left',**u(.03,.025,.81,.08)})
tree['Close']=button('X',[190,45,65],{'Active':True,'AutoButtonColor':True,**u(.91,.025,.06,.08)})
tree['Count']=label('0 cajas · 0 Coins',{'TextColor3':c([105,210,240]),'TextXAlignment':'Left',**u(.03,.12,.65,.04)})
tree['Price']=label('4500 Coins',{'TextColor3':c([255,216,100]),'TextXAlignment':'Right',**u(.68,.12,.29,.04)})
tree['Hint']=label('DESLIZÁ PARA VER LOS PREMIOS',{'TextColor3':c([135,155,180]),'TextXAlignment':'Left',**u(.03,.178,.93,.03)})
tree['RewardScroll']=n('ScrollingFrame',{'BackgroundTransparency':1,'BorderSizePixel':0,'ZIndex':62,'ScrollingDirection':'X','AutomaticCanvasSize':'X','CanvasSize':{'UDim2':[[0,0],[0,0]]},'ScrollBarThickness':5,'ScrollBarImageColor3':c([55,170,215]),'ClipsDescendants':True,**u(.025,.22,.95,.51)},Layout=n('UIListLayout',{'FillDirection':'Horizontal','Padding':{'UDim':[0,12]},'SortOrder':'LayoutOrder'}))
card=frame({'Visible':False,'BackgroundTransparency':1,'Size':{'UDim2':[[0,184],[1,-10]]},'ZIndex':63},Stroke=n('UIStroke',{'Color':c([239,187,62]),'Thickness':2,'Transparency':.15}))
# The top is a transparent window to a real client-only 3D model and rarity backdrop.
card['Info']=frame({'BackgroundColor3':c([13,20,34]),'ZIndex':64,**u(0,.66,1,.34)})
card['ItemName']=label('Clásico',u(.04,.68,.92,.08))
card['Rarity']=label('Gold',{'TextColor3':c([239,187,62]),**u(.04,.78,.92,.055)})
card['Chance']=label('20 % · Probabilidad alta',{'TextColor3':c([200,215,235]),**u(.04,.86,.92,.095)})
card['Detail']=label('Probabilidad exacta: 20 %',{'Visible':False,'BackgroundColor3':c([8,13,24]),'BackgroundTransparency':0,'TextColor3':c([255,255,255]),'ZIndex':70,**u(.02,.03,.96,.14)})
tree['RewardCard']=card
tree['ProbabilityNote']=label('Porcentajes aproximados por Slap · Pasá el cursor o tocá una tarjeta para ver el valor exacto',{'TextColor3':c([140,160,185]),**u(.03,.748,.94,.055)})
tree['Status']=label('Elegí cuántas cajas abrir.',{'TextColor3':c([235,210,155]),**u(.03,.81,.94,.04)})
tree['Buy']=button('COMPRAR',[25,155,85],u(.03,.88,.22,.085))
actions=frame({'BackgroundTransparency':1,'ZIndex':65,**u(.27,.88,.7,.085)})
for i,q in enumerate([1,5,10]):actions['X'+str(q)]=button('ABRIR x'+str(q),[190,135,25],u(i/3,0,.315,1))
tree['OpenActions']=actions
for key in ['Outcomes','ViewOdds','Open','Receipt']:
 tree[key]=n('TextLabel'if key=='Outcomes'else 'TextButton',{'Visible':False,'Active':False,'Text':'','Size':{'UDim2':[[0,0],[0,0]]}})
# V4.1 native Edit design snapshot preserves the ShopHUD MainFrame styling.
design=r/'tests/CrateDesignV41.panel.json'
if design.exists():tree=json.loads(design.read_text(encoding='utf-8'))['tree']
d={'name':'CratePanel','tree':tree};(r/'src/ui/CratePanel.project.json').write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
for name in ['default.project.json','studio-safe.project.json']:
 p=r/name;project=json.loads(p.read_text(encoding='utf-8'));gui=project['tree']['StarterGui'];hud=gui.setdefault('ShopHUD',{'$className':'ScreenGui','$ignoreUnknownInstances':True})
 if name=='studio-safe.project.json':hud['CratePanel']={'$path':'src/ui/CratePanel.project.json'}
 else:
  # Nested overrides do not replace this child inside the binary ShopHUD.
  # Export the native ShopHUD snapshot again after changing the editable panel.
  hud['$path']='src/ui/ShopHUD.CrateGalleryV4.rbxm';hud.pop('CratePanel',None)
 p.write_text(json.dumps(project,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Editable crate gallery prepared: Buy + Open x1/x5/x10')
