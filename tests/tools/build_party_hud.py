"""Build editable Rojo UI; no network, gameplay or generated runtime artwork."""
import json
from pathlib import Path

def u(x,y,xo=0,yo=0):return {'UDim2':[[x,xo],[y,yo]]}
def color(r,g,b):return {'Color3':[r/255,g/255,b/255]}
def obj(cls,props=None,**children):return {'$className':cls,'$properties':props or {},**children}
def corner(n=12):return obj('UICorner',{'CornerRadius':{'UDim':[0,n]}})
def stroke(c=(64,116,143)):return obj('UIStroke',{'Color':color(*c),'Thickness':1.5,'Transparency':.15})
def label(text,pos,size,ts=20):return obj('TextLabel',{'Text':text,'Position':pos,'Size':size,'BackgroundTransparency':1,'TextColor3':color(242,248,255),'Font':'GothamBold','TextSize':ts,'TextWrapped':True,'ZIndex':3})
def button(text,pos,size,c=(24,181,211)):
 return obj('TextButton',{'Text':text,'Position':pos,'Size':size,'BackgroundColor3':color(*c),'BorderSizePixel':0,'TextColor3':color(255,255,255),'Font':'GothamBold','TextSize':23,'TextWrapped':True,'ZIndex':3},Corner=corner(),Outline=stroke())
def panel(title,w,h):
 return obj('Frame',{'AnchorPoint':{'Vector2':[.5,.5]},'Position':u(.5,.48),'Size':u(.88,.72),'BackgroundColor3':color(14,26,39),'BackgroundTransparency':.08,'Visible':False,'BorderSizePixel':0,'ZIndex':2},Corner=corner(20),Outline=stroke(),Limit=obj('UISizeConstraint',{'MaxSize':{'Vector2':[w,h]},'MinSize':{'Vector2':[260,240]}}),Title=label(title,u(0,0,22,10),u(1,0,-85,48),26),Close=button('×',u(1,0,-56,10),u(0,0,42,42),(223,45,67)))

root=obj('ScreenGui',{'Enabled':True,'ResetOnSpawn':False,'DisplayOrder':96,'IgnoreGuiInset':False,'ZIndexBehavior':'Sibling'})
dock=obj('Frame',{'AnchorPoint':{'Vector2':[0,1]},'Position':u(0,1,18,-32),'Size':u(0,0,330,158),'BackgroundTransparency':1},
 Count=label('1 / 4',u(1,0,-66,0),u(0,0,66,22),14),Members=obj('Frame',{'Position':u(0,0,0,20),'Size':u(1,0,0,70),'BackgroundTransparency':1},Layout=obj('UIListLayout',{'FillDirection':'Horizontal','HorizontalAlignment':'Center','SortOrder':'LayoutOrder','Padding':{'UDim':[0,8]}})),Play=button('Jugar',u(0,0,0,100),u(1,0,0,52),(22,199,58)),Leave=button('Salir del grupo',u(0,0,0,-6),u(0,0,145,24),(48,61,76)))
dock['Leave']['$properties'].update({'Visible':False,'TextSize':13})
for i in range(1,5):
 slot=obj('Frame',{'Size':u(0,0,60,72),'LayoutOrder':i,'BackgroundTransparency':1,'Visible':i==1},Avatar=obj('ImageLabel',{'Size':u(0,0,56,56),'BackgroundColor3':color(20,52,68),'Image':'','BorderSizePixel':0},Corner=corner(40),Outline=stroke()),Caption=label('TÚ' if i==1 else 'Jugador',u(0,0,0,55),u(1,0,0,18),12),Leader=label('★',u(0,0,-3,-7),u(0,0,20,20),19))
 dock['Members']['Slot'+str(i)]=slot
dock['Members']['Add']=button('+',u(0,0),u(0,0,56,56),(75,91,105));dock['Members']['Add']['$properties'].update({'LayoutOrder':5,'TextSize':42})
root['Dock']=dock
root['InvitePanel']=panel('Invitar jugadores',580,620)
root['InvitePanel']['List']=obj('ScrollingFrame',{'Position':u(0,0,16,70),'Size':u(1,1,-32,-86),'BackgroundTransparency':1,'BorderSizePixel':0,'AutomaticCanvasSize':'Y','CanvasSize':u(0,0),'ScrollBarThickness':5,'ScrollingDirection':'Y'},Layout=obj('UIListLayout',{'SortOrder':'LayoutOrder','Padding':{'UDim':[0,8]}}))
root['InvitePanel']['Empty']=label('No hay otros jugadores en este servidor.',u(.1,.35),u(.8,.3),20)
root['InviteTemplate']=obj('Frame',{'Size':u(1,0,-8,90),'BackgroundColor3':color(27,44,61),'BorderSizePixel':0,'Visible':False},Corner=corner(),Outline=stroke(),Avatar=obj('ImageLabel',{'Position':u(0,0,9,9),'Size':u(0,0,64,64),'BackgroundTransparency':1,'Image':''}),Username=label('Nombre (@usuario)',u(0,0,83,8),u(1,0,-94,32),16),Invite=button('Invitar',u(1,0,-130,47),u(0,0,118,34)))
root['InviteTemplate']['Invite']['$properties']['TextSize']=17
root['ModePanel']=panel('Elegí tu modalidad',800,540)
root['ModePanel']['Modes']=obj('Frame',{'Position':u(0,0,20,72),'Size':u(1,1,-40,-92),'BackgroundTransparency':1},Layout=obj('UIGridLayout',{'CellSize':u(.5,.5,-8,-8),'CellPadding':u(0,0,12,12),'SortOrder':'LayoutOrder'}))
for i,mode in enumerate(['1v1','2v2','3v3','4v4']):
 b=button('',u(0,0),u(.5,.5),(22+12*i,62,95+20*i));b['$properties']['LayoutOrder']=i
 b['Mode']=label(mode,u(0,.15),u(1,.4),46)
 b['Hint']=label('Buscar partida',u(.05,.65),u(.9,.2),17)
 root['ModePanel']['Modes'][mode]=b
root['Search']=obj('Frame',{'AnchorPoint':{'Vector2':[.5,0]},'Position':u(.5,0,0,18),'Size':u(.8,0,0,92),'BackgroundColor3':color(13,39,52),'BorderSizePixel':0,'Visible':False},Corner=corner(20),Outline=stroke(),Limit=obj('UISizeConstraint',{'MaxSize':{'Vector2':[610,92]}}),Title=label('Buscando jugadores…',u(0,0,18,8),u(.7,0,-20,32),21),Mode=label('1v1',u(0,0,18,44),u(.45,0,0,32),20),Timer=label('0:00',u(.7,0,0,32),u(.25,0,0,40),28),Cancel=button('×',u(1,0,-32,-12),u(0,0,42,42),(223,45,67)))
root['Telemetry']=label('FPS · ms · Servidor',u(0,1,14,-25),u(0,0,580,20),12)
root['Telemetry']['$properties']['TextXAlignment']='Left'
root['Status']=label('',u(.2,.78),u(.6,0,0,46),16)
root['Return']=button('Volver al lobby',u(.5,.8,-100,0),u(0,0,200,48));root['Return']['$properties']['Visible']=False
Path('src/ui/PartyMatchHUD.project.json').write_text(json.dumps({'name':'PartyMatchHUD','tree':root},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
