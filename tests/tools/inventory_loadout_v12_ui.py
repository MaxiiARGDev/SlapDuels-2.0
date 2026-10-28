"""Add inventory category tabs and equipped effect labels to the existing profile."""
import json
from pathlib import Path
r=Path(__file__).resolve().parents[2]
p=r/'src/ui/PlayerProfileHUD.project.json'
d=json.loads(p.read_text(encoding='utf-8'));m=d['tree']['MainFrame']
def color(rgb):return {'Color3':[x/255 for x in rgb]}
def u(x,y,w,h):return {'Position':{'UDim2':[[x,0],[y,0]]},'Size':{'UDim2':[[w,0],[h,0]]}}
def node(c,props,**children):return {'$className':c,'$properties':props,**children}
def label(text,props):return node('TextLabel',dict(Text=text,BackgroundTransparency=1,BorderSizePixel=0,TextColor3=color([210,225,245]),Font='GothamBold',TextScaled=True,TextWrapped=True,ZIndex=4)|props)
tabs=node('Frame',dict(BackgroundTransparency=1,Visible=False,ZIndex=4,**u(.035,.353,.93,.055)))
for i,(key,text)in enumerate([('Slaps','SLAPS'),('PointEffects','EFECTOS DE PUNTO'),('DeathEffects','EFECTOS DE MUERTE')]):
 tabs[key]=node('TextButton',dict(Text=text,BackgroundColor3=color([20,30,45]),TextColor3=color([225,240,255]),Font='GothamBold',TextScaled=True,TextWrapped=True,BorderSizePixel=0,AutoButtonColor=True,ZIndex=5,**u(i/3,0,.325,1)),Corner=node('UICorner',{'CornerRadius':{'UDim':[0,8]}}),Stroke=node('UIStroke',{'Color':color([65,105,135]),'Thickness':1,'Transparency':.3}))
effects=node('Frame',dict(BackgroundColor3=color([14,24,38]),BackgroundTransparency=.1,BorderSizePixel=0,ZIndex=3,**u(.035,.735,.93,.07)),Corner=node('UICorner',{'CornerRadius':{'UDim':[0,8]}}))
for i,(key,text)in enumerate([('PointEffects','PUNTO: —'),('DeathEffects','MUERTE: —')]):effects[key]=label(text,dict(TextXAlignment='Left',**u(.025+i*.5,.1,.455,.8)))
badge=label('EFECTO',dict(Visible=False,TextColor3=color([90,205,220]),**u(.07,.08,.86,.51)))
# TextColor3 is intentionally set after label's common properties.
adds={'MainFrame':{'InventoryTabs':tabs,'SelectedEffects':effects},'CardTemplate':{'EffectBadge':badge}}
updates={
 'MainFrame.Collection':u(.035,.425,.93,.27),
 'MainFrame.CollectionTitle':dict(Visible=False,**u(.035,.775,.93,.025)),
 'MainFrame.CollectionHint':dict(Visible=False,**u(.035,.805,.93,.025)),
 'MainFrame.Status':u(.035,.837,.93,.025),
}
for parent,children in adds.items():d['tree'][parent].update(children)
for path,props in updates.items():
 o=d['tree']
 for name in path.split('.'):o=o[name]
 o['$properties'].update(props)
p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(r/'tests/InventoryLoadoutV12.ui.json').write_text(json.dumps({'Adds':adds,'Updates':updates}),encoding='utf-8')
print('Profile tabs, effect labels and effect card badge prepared')
