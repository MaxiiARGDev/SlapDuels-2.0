"""Prepare cosmetic resources from the audited Classic. --apply only after confirming Studio Edit."""
import argparse
import json
from pathlib import Path
root=Path(__file__).resolve().parents[2]
stage=root/'tests/staging/SlapVariationsV1'
parser=argparse.ArgumentParser();parser.add_argument('--apply',action='store_true');args=parser.parse_args()
audit=json.loads((root/'tests/SlapVariationsV1.classic-audit.json').read_text(encoding='utf-8-sig'))
assert audit['IsStudio'] and not audit['IsRunning'],'Edit audit required'
hand=next(x for x in audit['Classic'] if x['Path']=='ServerStorage.Slaps.Classic.Hand')
assert hand['Class']=='MeshPart','Re-audit geometry adapter for changed Classic'
original=hand['Color'];size=hand['Size'];mesh_size=hand['MeshSize']
palette=[
 ('Basic',[round(x*255)for x in original],'SmoothPlastic',0,'Original sin efectos extraordinarios'),
 ('Common',[202,209,218],'SmoothPlastic',0,'Plateado discreto'),
 ('Uncommon',[65,190,100],'SmoothPlastic',5,'Energía verde suave'),
 ('Rare',[69,138,255],'SmoothPlastic',7,'Energía azul y brillo tenue'),
 ('Gold',[239,187,62],'Metal',6,'Metal dorado y destellos moderados'),
 ('Arcoiris',[245,245,245],'SmoothPlastic',9,'Partículas multicolores sin bucles de servidor'),
 ('Emote',[220,93,180],'SmoothPlastic',4,'Símbolo expresivo rosa; sin sistema de emotes'),
 ('Wings',[151,218,255],'Glass',6,'Dos plumas de energía celeste; sin vuelo'),
 ('Epic',[145,58,225],'Neon',11,'Energía violeta intensa'),
 ('Legendary',[255,156,37],'Neon',16,'Aura dorada anaranjada moderada'),
 ('Blood',[125,24,45],'SmoothPlastic',8,'Energía roja y negra, sin gore'),
 ('Galaxy',[38,31,83],'Neon',12,'Estrellas azules, violetas y blancas'),
]
def n(cls,props=None,**kids):return {'$className':cls,'$properties':props or {},**kids}
def color(rgb):return {'Color3':[x/255 for x in rgb]}
def vec(v):return {'Vector3':v}
def attrs(**values):return {k:({'Bool':v}if type(v)is bool else {'String':v}if isinstance(v,str)else {'Float64':v}if isinstance(v,(int,float))else v)for k,v in values.items()}
def colorseq(points):return {'ColorSequence':{'keypoints':[{'time':t,'color':[x/255 for x in rgb]}for t,rgb in points]}}
def numberseq(points):return {'NumberSequence':{'keypoints':[{'time':t,'value':v,'envelope':0}for t,v in points]}}
profiles=n('Folder');previews=n('Folder',None,Classic=n('Folder'))
metadata=[]
for index,(id,rgb,material,rate,description)in enumerate(palette):
 tint=original if id=='Basic'else [x/255 for x in rgb]
 profile=n('Folder',{'Attributes':attrs(Tint={'Color3':tint},ApplyTint=id!='Basic',Material=material,
  ApplyMaterial=id!='Basic',Intensity=1,DesignPending=True,ProfileVersion=1,Description=description)})
 colors=[(0,rgb),(1,[255,255,255])]
 if id=='Arcoiris':colors=[(0,[255,65,65]),(.17,[255,185,45]),(.34,[65,230,85]),(.5,[75,225,255]),(.67,[95,100,255]),(.84,[220,75,245]),(1,[255,65,65])]
 if id=='Blood':colors=[(0,[165,24,52]),(1,[18,12,24])]
 if id=='Galaxy':colors=[(0,[85,135,255]),(.45,[173,87,245]),(.8,[255,255,255]),(1,[95,80,200])]
 positions=[('CosmeticOrigin',[0,0,0])]
 if id=='Wings':positions=[('WingLeft',[-.48,.10,0]),('WingRight',[.48,.10,0])]
 for name,normalized in positions:
  emitter=n('ParticleEmitter',{'Texture':'rbxasset://textures/particles/'+('smoke_main.dds'if id=='Blood'else 'sparkles_main.dds'),
   'Enabled':rate>0,'Rate':rate/len(positions),'Lifetime':{'NumberRange':[.35,.8]},'Speed':{'NumberRange':[.15,.7]},
   'SpreadAngle':{'Vector2':[30,30]},'LightEmission':.65 if id not in ('Blood','Common','Basic')else .1,
   'LightInfluence':.25,'Drag':1,'LockedToPart':False,'Color':colorseq(colors),
   'Size':numberseq([(0,.055),(.35,.12),(1,0)]),'Transparency':numberseq([(0,.25),(.6,.5),(1,1)]),
   'Rotation':{'NumberRange':[0,360]},'RotSpeed':{'NumberRange':[-35,35]},
   'Attributes':attrs(SlapVariationEmitter=True,RevealBurstCount=0 if rate==0 else 3)})
  attachment=n('Attachment',{'Position':vec([size[i]*normalized[i]for i in range(3)]),
   'Attributes':attrs(ScaleToHand=True,NormalizedPosition=vec(normalized))},Energy=emitter)
  if id in ('Rare','Epic','Legendary','Galaxy'):
   attachment['Glow']=n('PointLight',{'Color':color(rgb),'Range':4 if id=='Legendary'else 3,'Brightness':.4 if id=='Legendary'else .18,'Shadows':False,'Enabled':True})
  if id=='Emote':
   attachment['Symbol']=n('BillboardGui',{'Size':{'UDim2':[[0,22],[0,22]]},'StudsOffset':vec([0,.3,0]),'AlwaysOnTop':False,'MaxDistance':30,'LightInfluence':0},
    Label=n('TextLabel',{'Size':{'UDim2':[[1,0],[1,0]]},'BackgroundTransparency':1,'Text':'✦','TextColor3':color(rgb),'TextScaled':True,'TextStrokeTransparency':.7}))
  profile[name]=attachment
 # Original audio preserved. Empty Sounds are explicit future authoring slots only.
 profile['Hit']=n('Sound',{'Volume':.4});profile['Reveal']=n('Sound',{'Volume':.4})
 profiles[id]=profile
 visual=n('Model',{'Attributes':attrs(SlapId='Classic',VariationId=id,PreviewOfRewardId='Classic:'+id)})
 visual_hand=n('Part',{'Anchored':True,'CanCollide':False,'CanTouch':False,'CanQuery':False,'CastShadow':False,
  'Size':vec(size),'Color':{'Color3':original if id=='Basic'else tint},'Material':hand['MaterialName']if id=='Basic'else material,
  'Attributes':attrs(SlapVariationOriginalColor={'Color3':original},SlapVariationOriginalMaterial=hand['MaterialName'])},
  Mesh=n('SpecialMesh',{'MeshType':'FileMesh','MeshId':hand['MeshId'],'TextureId':hand['TextureID'],
   'Scale':vec([size[i]/mesh_size[i]for i in range(3)])}))
 for name,item in profile.items():
  if name.startswith('$')or item['$className']=='Sound':continue
  copy=json.loads(json.dumps(item));copy['$properties'].setdefault('Attributes',{})['SlapVariationManaged']={'Bool':True};visual_hand[name]=copy
 visual['Hand']=visual_hand;previews['Classic'][id]=visual
 metadata.append({'Id':id,'DisplayName':id,'RGB':rgb,'Material':material,'Rate':rate,'Description':description})
def write(file,name,tree):
 p=stage/file;p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps({'name':name,'tree':tree},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
write('SlapVariationEffects.project.json','SlapVariationEffects',profiles)
write('SlapVariationPreviews.project.json','SlapVariationPreviews',previews)
lines=['--!nonstrict','-- Generated cosmetic manifest. Commercial settings remain unchanged.','return {']
for i,m in enumerate(metadata):
 lines.append(' {Id="%s",DisplayName="%s",Description=%s,SortOrder=%d,Color=Color3.fromRGB(%s),Icon="",VisualProfile="%s",VFX="%s",SFX="Reveal",AnnounceInChat=false,LimitedStock=false,DefaultStock=nil,AdditionalConfig={DesignPending=true}},'%(
 m['Id'],m['DisplayName'],json.dumps(m['Description'],ensure_ascii=False),i+1,','.join(str(x)for x in m['RGB']),m['Id'],m['Id']))
lines.append('}')
(stage/'VariationDefinitions.luau').write_text('\n'.join(lines)+'\n',encoding='utf-8')
(root/'tests/SlapVariationsV1.palette.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2),encoding='utf-8')
if args.apply:
 for file,dest in [('SlapVariationEffects.project.json','src/assets'),('SlapVariationPreviews.project.json','src/assets'),('VariationDefinitions.luau','src/shared/SlapCrates'),('Appearance.luau','src/shared/SlapCrates')]:
  (root/dest/file).write_bytes((stage/file).read_bytes())
 project=root/'default.project.json';data=json.loads(project.read_text(encoding='utf-8'))
 data['tree']['ReplicatedStorage']['SlapVariationPreviews']={'$path':'src/assets/SlapVariationPreviews.project.json'}
 data['tree']['ServerStorage']['$ignoreUnknownInstances']=True
 project.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Applied'if args.apply else 'Staged',len(metadata),'cosmetic profiles and safe previews')
