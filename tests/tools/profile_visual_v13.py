"""Profile-only art pass. Native editable shapes; no external image/audio assets."""
from pathlib import Path
import copy,json
r=Path(__file__).resolve().parents[2]
def u(x=0,y=0,dx=0,dy=0):return {'UDim2':[[x,dx],[y,dy]]}
def c(rgb):return {'Color3':[x/255 for x in rgb]}
def seq(points):return {'ColorSequence':{'keypoints':[{'time':t,'color':[v/255 for v in rgb]}for t,rgb in points]}}
def node(cls,**p):return {'$className':cls,'$properties':p}
def corner(v,radius=10):v['Corner']=node('UICorner',CornerRadius={'UDim':[0,radius]});return v
def frame(pos,size,color,alpha=0,radius=0,z=1):
 v=node('Frame',Position=pos,Size=size,BackgroundColor3=c(color),BackgroundTransparency=alpha,BorderSizePixel=0,ZIndex=z,Active=False)
 if radius:corner(v,radius)
 return v
def stroke(v,color,width=1,alpha=0):v['Stroke']=node('UIStroke',Color=c(color),Thickness=width,Transparency=alpha,ApplyStrokeMode='Border');return v
def gradient(v,top,bottom,rotation=90):v['Gradient']=node('UIGradient',Color=seq([(0,top),(1,bottom)]),Rotation=rotation);return v
def text(txt,pos,size,maximum=18,color=(235,243,255),align='Center',font='GothamBold'):
 v=node('TextLabel',Text=txt,Position=pos,Size=size,BackgroundTransparency=1,BorderSizePixel=0,TextColor3=c(color),Font=font,TextSize=maximum,TextScaled=True,TextWrapped=True,TextXAlignment=align,TextStrokeTransparency=.8,TextStrokeColor3=c((0,0,0)),ZIndex=3)
 v['TextBounds']=node('UITextSizeConstraint',MinTextSize=8,MaxTextSize=maximum)
 return v
def icon(kind,color=(255,255,255)):
 v=frame(u(),u(1,1),color,1)
 v['Aspect']=node('UIAspectRatioConstraint',AspectRatio=1)
 def shape(name,x,y,w,h,rot=0,col=color,rad=0):
  q=frame(u(x,y),u(w,h),col,radius=rad,z=2);q['$properties']['Rotation']=rot;v[name]=q;return q
 if kind=='flame':
  shape('Outer',.22,.17,.58,.66,35,rad=12);shape('Tip',.5,.025,.25,.45,25,rad=6)
  shape('Heart',.38,.5,.29,.38,35,(255,221,95),8)
 elif kind=='cup':
  shape('Bowl',.24,.16,.52,.47,rad=10);shape('Stem',.45,.59,.10,.18);shape('Base',.28,.77,.44,.09,rad=3)
  for name,x in [('Left',.05),('Right',.68)]:
   q=shape(name,x,.22,.27,.29,rad=8);q['$properties']['BackgroundTransparency']=1;stroke(q,color,3)
 elif kind=='skull':
  shape('Head',.18,.10,.64,.57,rad=16);shape('Jaw',.32,.58,.36,.21,rad=4)
  for name,x in [('LeftEye',.29),('RightEye',.56)]:shape(name,x,.33,.15,.17,col=(23,30,44),rad=6)
  shape('Nose',.465,.52,.07,.11,col=(23,30,44),rad=2)
  for i in range(2):shape('Tooth'+str(i),.43+i*.11,.69,.035,.10,col=(23,30,44))
  shape('Bone1',.12,.84,.76,.075,24,rad=3);shape('Bone2',.12,.84,.76,.075,-24,rad=3)
 elif kind=='grid':
  for y in range(2):
   for x in range(2):shape('Tile'+str(x)+str(y),.1+x*.45,.1+y*.45,.34,.34,rad=3)
 elif kind=='duel':
  shape('BladeA',.45,.03,.12,.83,42,rad=2);shape('BladeB',.45,.03,.12,.83,-42,rad=2)
  shape('GuardA',.07,.68,.35,.08,42,rad=2);shape('GuardB',.58,.68,.35,.08,-42,rad=2)
 elif kind=='party':
  for i,(x,y,scale)in enumerate([(.03,.21,.32),(.65,.21,.32),(.28,.03,.44)]):
   shape('Head'+str(i),x,y,scale,scale,rad=50);shape('Body'+str(i),x-.01,y+scale+.06,scale+.02,.25,rad=8)
 elif kind=='arrows':
  shape('Top',.15,.25,.68,.11,rad=3);shape('TipTop',.70,.17,.23,.23,45)
  shape('Bottom',.15,.65,.68,.11,rad=3);shape('TipBottom',.07,.58,.23,.23,45)
 return v
def add_icon(parent,name,kind,pos,size,color):
 v=icon(kind,color);v['$properties'].update(Position=pos,Size=size);parent[name]=v;return v

p=r/'src/ui/PlayerProfileHUD.project.json';root=json.loads(p.read_text(encoding='utf-8'));m=root['tree']['MainFrame']
m['$properties'].update(Size=u(.94,.82),BackgroundColor3=c((17,23,35)),GroupColor3=c((255,255,255)),GroupTransparency=0)
m['Bounds']['$properties'].update(MaxSize={'Vector2':[1000,620]},MinSize={'Vector2':[300,320]})
corner(m,18);m['Stroke']['$properties'].update(Color=c((104,127,163)),Thickness=2,Transparency=.12)
# CanvasGroup modifiers tint EVERY descendant. All art gradients live on ordinary Frames.
m['BackgroundGradient']={'$className':'UIGradient','$properties':{'Enabled':False}}
surface=corner(frame(u(),u(1,1),(255,255,255),z=0),18)
gradient(surface,(38,49,68),(12,18,28),115);surface['$properties']['ClipsDescendants']=True
for i in range(5):
 bar=frame(u(.72+i*.065,-.4),u(.035,2),(85,122,172),.94,z=0);bar['$properties']['Rotation']=27;surface['Slash'+str(i)]=bar
surface['TopLine']=gradient(frame(u(.02,0),u(.96,0,dy=3),(255,255,255)),(82,217,255),(255,199,89),0)
m['Surface']=surface
m['Eyebrow']=text('SLAPDUELS  /  PERFIL DEL JUGADOR',u(.035,.035),u(.70,.035),12,(147,175,212),'Left')
m['Identity']['$properties'].update(Position=u(.195,.12),Size=u(.66,.075),TextColor3=c((255,255,255)),TextStrokeTransparency=.45,TextXAlignment='Left',TextScaled=True)
m['Identity']['TextBounds']=node('UITextSizeConstraint',MinTextSize=14,MaxTextSize=34)
m['Username']=text('@jugador',u(.195,.21),u(.62,.045),19,(157,179,209),'Left')
m['Progression']['$properties'].update(Position=u(.195,.277),Size=u(.74,.035),TextColor3=c((148,161,184)),TextScaled=True)
m['Progression']['TextBounds']=node('UITextSizeConstraint',MinTextSize=8,MaxTextSize=12)
m['ProfileBadge']=stroke(corner(frame(u(.73,.035),u(.17,.045),(36,64,85),.15),6),(83,159,191),1,.3)
m['ProfileBadge']['Label']=text('TU PERFIL',u(.07,.12),u(.86,.76),10,(136,226,255))
m['Avatar']['$properties'].update(Position=u(.035,.095),Size=u(.135,.225),BackgroundColor3=c((21,33,50)),BackgroundTransparency=0,Ambient=c((235,238,255)),LightColor=c((255,255,255)),LightDirection={'Vector3':[-1,-.5,-2]})
m['Avatar']['Border']['$properties'].update(Color=c((94,203,239)),Thickness=2,Transparency=.1)
corner(m['Avatar'],12)
m['AvatarRibbon']=text('JUGADOR',u(.035,.30),u(.135,.025),9,(137,220,255))
m['HeaderDivider']=frame(u(.035,.335),u(.93,0,dy=1),(100,127,162),.65)
m['Summary']['$properties'].update(Position=u(.035,.37),Size=u(.93,.335),BackgroundTransparency=1)
m['Summary']['Stroke']['$properties']['Enabled']=False
themes=[('Streak','RACHAS','flame',(255,155,47),'3 VICTORIAS = 1 RACHA'),('Wins','VICTORIAS','cup',(255,214,78),'PARTIDAS GANADAS'),('Kills','KILLS','skull',(255,105,119),'ELIMINACIONES')]
for i,(name,title,kind,color,sub)in enumerate(themes):
 q=m['Summary'][name];q['$properties'].update(Position=u(i*.213,0),Size=u(.198,1),BackgroundColor3=c((255,255,255)),BackgroundTransparency=0)
 q['Stroke']['$properties'].update(Color=c(color),Thickness=1.5,Transparency=.35)
 gradient(q,tuple(int(v*.19+12)for v in color),(21,28,42))
 q['TopAccent']=frame(u(.13,0),u(.74,0,dy=3),color,0,radius=2)
 q['Value']['$properties'].update(Position=u(.06,.36),Size=u(.88,.28),TextColor3=c((255,255,255)),Font='GothamBlack',TextStrokeTransparency=.6)
 q['Value']['TextBounds']=node('UITextSizeConstraint',MinTextSize=18,MaxTextSize=48)
 q['Caption']['$properties'].update(Position=u(.04,.69),Size=u(.92,.12),TextColor3=c(color),TextScaled=True)
 q['Caption']['TextBounds']=node('UITextSizeConstraint',MinTextSize=8,MaxTextSize=15)
 q['Subcaption']=text(sub,u(.06,.855),u(.88,.065),8,(154,168,191))
 add_icon(q,'StatIcon',kind,u(.37,.075),u(.26,.26),color)
eq=m['Summary']['Equipped'];eq['$properties'].update(Position=u(.657,0),Size=u(.343,1),BackgroundColor3=c((255,255,255)))
gradient(eq,(41,50,68),(20,28,43));eq['Stroke']['$properties'].update(Color=c((105,125,162)),Transparency=.3,Thickness=1.5)
eq['Eyebrow']=text('TU SLAP EQUIPADO',u(.06,.055),u(.88,.08),10,(178,196,225),'Left')
eq['Preview']['$properties'].update(Position=u(.10,.16),Size=u(.80,.53),BackgroundTransparency=1,Ambient=c((240,240,255)),LightColor=c((255,255,255)),LightDirection={'Vector3':[-1,-.5,-2]})
eq['Preview']['Border']['$properties']['Enabled']=False
eq['Caption']['$properties'].update(Position=u(.06,.75),Size=u(.88,.15),TextColor3=c((238,244,255)))
eq['Caption']['TextBounds']=node('UITextSizeConstraint',MinTextSize=8,MaxTextSize=14)
eq['EquippedTag']=text('EQUIPAMIENTO ACTUAL',u(.06,.92),u(.88,.045),8,(106,184,222))
m['Collection']['$properties'].update(Position=u(.035,.37),Size=u(.93,.335),ScrollBarThickness=5,ScrollBarImageColor3=c((102,195,242)))
m['CollectionTitle']=text('COLECCIÓN  /  SLAPS Y VARIACIONES',u(.035,.743),u(.93,.03),11,(135,190,229),'Left')
m['CollectionHint']=text('Tu colección. Tus variaciones. Tu estilo.',u(.035,.784),u(.93,.025),11,(139,155,180),'Left')
m['Status']['$properties'].update(Position=u(.035,.815),Size=u(.93,.027),TextColor3=c((255,206,122)),TextScaled=True)
m['Status']['TextBounds']=node('UITextSizeConstraint',MinTextSize=8,MaxTextSize=12)
for name,x in [('Previous',.035),('Page',.185),('Next',.85)]:
 m[name]['$properties'].update(Position=u(x,.715),Size=u(.12 if name!='Page'else .63,.05))
 m[name]['TextBounds']=node('UITextSizeConstraint',MinTextSize=8,MaxTextSize=12)
colors={'Articles':((47,166,239),(18,99,181),'grid'),'Challenge':((247,92,106),(164,39,59),'duel'),'Invite':((104,205,83),(34,128,63),'party'),'Trade':((251,201,73),(183,123,25),'arrows')}
for name,(top,bottom,kind)in colors.items():
 b=m[name];b['$properties'].update(BackgroundTransparency=1,TextColor3=c((255,255,255)),TextStrokeTransparency=1,TextScaled=True,TextTransparency=1)
 b['TextBounds']=node('UITextSizeConstraint',MinTextSize=9,MaxTextSize=22)
 b['Gradient']['$properties']['Enabled']=False
 b['Stroke']['$properties'].update(Color=c(top),Transparency=.15,Thickness=1.5)
 b['Surface']=gradient(corner(frame(u(),u(1,1),(255,255,255),z=0),8),top,bottom)
 b['Surface']['Shine']=frame(u(.04,.05),u(.92,0,dy=1),(255,255,255),.55)
 b['ActionLabel']=text(b['$properties']['Text'],u(.18,.1),u(.76,.8),20,(255,255,255))
 add_icon(b,'ActionIcon',kind,u(.045,.24),u(.12,.52),(255,255,255))
close=m['Close'];close['$properties'].update(Position=u(1,0,dx=-60,dy=18),Size=u(dx=42,dy=42),TextColor3=c((255,255,255)),TextSize=24,TextScaled=False,BackgroundColor3=c((196,53,73)))
close['Gradient']['$properties']['Enabled']=False;close['Stroke']['$properties'].update(Color=c((255,143,153)),Transparency=.3)
close['TextBounds']=node('UITextSizeConstraint',MinTextSize=16,MaxTextSize=24)
# Collection cards keep the exact contract while adopting the same material palette.
card=root['tree']['CardTemplate'];card['$properties']['BackgroundColor3']=c((24,34,52))
card['Accent']['$properties'].update(Thickness=1.5,Transparency=.15)
for key,cap in [('ItemName',15),('Variation',12),('State',10),('UnitId',9)]:card[key]['TextBounds']=node('UITextSizeConstraint',MinTextSize=8,MaxTextSize=cap)
card['UnitId']['$properties']['Visible']=False
card['Preview']['$properties'].update(Position=u(.04,.035),Size=u(.92,.46))
card['Aura']['$properties']['Size']=u(.96,.50)
for key,y,height in [('ItemName',.55,.13),('Variation',.71,.09),('State',.84,.09)]:
 card[key]['$properties'].update(Position=u(.04,y),Size=u(.92,height),TextScaled=True)
p.write_text(json.dumps(root,indent=2,ensure_ascii=True)+'\n',encoding='utf-8')
print('Profile art pass generated; CanvasGroup tint disabled; functional paths preserved')
