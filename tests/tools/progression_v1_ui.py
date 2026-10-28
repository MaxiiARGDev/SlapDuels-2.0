"""Native editable UI for Studio-only progression and existing admin panel."""
import json
from pathlib import Path
r=Path(__file__).resolve().parents[2]
def c(rgb):return {'Color3':[v/255 for v in rgb]}
def rect(x,y,w,h):return {'Position':{'UDim2':[[x,0],[y,0]]},'Size':{'UDim2':[[w,0],[h,0]]}}
def n(kind,p=None,**children):return {'$className':kind,'$properties':p or {},**children}
def frame(p=None,**children):return n('Frame',{'BackgroundColor3':c([13,19,46]),'BorderSizePixel':0,'ZIndex':81}|(p or {}),**children)
def corner():return n('UICorner',{'CornerRadius':{'UDim':[0,10]}})
def stroke():return n('UIStroke',{'Color':c([45,205,240]),'Thickness':2})
def label(text,p=None):return n('TextLabel',{'Text':text,'Font':'GothamBold','TextColor3':c([235,245,255]),'TextScaled':True,'TextWrapped':True,'BackgroundTransparency':1,'ZIndex':84}|(p or {}),TextBounds=n('UITextSizeConstraint',{'MinTextSize':10,'MaxTextSize':22}))
def button(text,p=None):return n('TextButton',{'Text':text,'Font':'Bangers','TextColor3':c([255,255,255]),'TextSize':23,'TextScaled':True,'TextWrapped':True,'BackgroundColor3':c([33,116,172]),'BorderSizePixel':0,'ZIndex':85}|(p or {}),Corner=corner(),Bounds=n('UITextSizeConstraint',{'MinTextSize':10,'MaxTextSize':26}))
tree=n('ScreenGui',{'ResetOnSpawn':False,'DisplayOrder':65,'ZIndexBehavior':'Sibling'},OpenButton=button('PASE',rect(.015,.82,.12,.055)),Bar=frame(rect(.015,.885,.23,.085),Corner=corner(),Level=label('NIVEL 0',rect(.04,.05,.4,.36)),XP=label('0 / 100 EXP',rect(.44,.05,.52,.36)),Track=frame({'BackgroundColor3':c([32,43,73]),**rect(.05,.65,.9,.17)},Fill=frame({'BackgroundColor3':c([60,215,240]),**rect(0,0,0,1)}))))
main=frame({'Visible':False,'AnchorPoint':{'Vector2':[.5,.5]},'Position':{'UDim2':[[.5,0],[.5,0]]},'Size':{'UDim2':[[.87,0],[.78,0]]}},Corner=corner(),Stroke=stroke(),Bounds=n('UISizeConstraint',{'MinSize':{'Vector2':[320,300]},'MaxSize':{'Vector2':[1100,680]}}),Title=label('PASE DE BATALLA',{'Font':'Bangers',**rect(.035,.025,.79,.09)}),Close=button('X',{'BackgroundColor3':c([200,45,75]),**rect(.90,.025,.065,.085)}),Remaining=label('Próximamente',{'TextColor3':c([255,208,85]),**rect(.04,.13,.92,.05)}),Progress=label('Sin temporada activa',rect(.04,.20,.92,.045)),Status=label('',rect(.04,.78,.92,.065)),ClaimAll=button('RECLAMAR TODO',{'BackgroundColor3':c([26,162,96]),**rect(.30,.885,.4,.075)}))
main['Rewards']=n('ScrollingFrame',{'BackgroundTransparency':1,'BorderSizePixel':0,'ZIndex':82,'ScrollingDirection':'X','AutomaticCanvasSize':'X','CanvasSize':{'UDim2':[[0,0],[0,0]]},'ScrollBarThickness':6,**rect(.03,.285,.94,.46)},Layout=n('UIListLayout',{'FillDirection':'Horizontal','Padding':{'UDim':[0,12]},'SortOrder':'LayoutOrder'}))
tree['MainFrame']=main
tree['Notice']=label('',{'Visible':False,**rect(.015,.765,.40,.045)})
tree['RewardTemplate']=frame({'Visible':False,'Size':{'UDim2':[[0,170],[1,-12]]}},Corner=corner(),Stroke=stroke(),Stage=label('ETAPA 1',{'TextColor3':c([107,222,255]),**rect(.06,.04,.88,.12)}),Reward=label('150 Coins',rect(.06,.23,.88,.32)),Cost=label('800 EXP',{'TextColor3':c([255,211,85]),**rect(.06,.60,.88,.10)}),Claim=button('BLOQUEADO',rect(.06,.78,.88,.17)))
(r/'src/ui/ProgressionHUD.project.json').write_text(json.dumps({'name':'ProgressionHUD','tree':tree},ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
panel=frame({'Visible':False,**rect(.02,.16,.96,.82),'ZIndex':90},Corner=corner(),Stroke=stroke(),Title=label('ADMINISTRAR TEMPORADAS',{'ZIndex':94,**rect(.04,.025,.80,.08)}),Close=button('VOLVER',{'ZIndex':95,**rect(.79,.025,.17,.08)}),Current=label('Sin pase activo',{'ZIndex':94,**rect(.04,.135,.92,.08)}),Preset=button('SELECCIONAR PASE',{'ZIndex':95,**rect(.04,.26,.60,.10)}),Days=n('TextBox',{'Text':'60','PlaceholderText':'Duración: 1–365 días','ClearTextOnFocus':False,'Font':'GothamBold','TextSize':22,'TextColor3':c([255,255,255]),'BackgroundColor3':c([27,38,70]),'ZIndex':95,**rect(.69,.26,.27,.10)}),Start=button('INICIAR',{'ZIndex':95,**rect(.04,.43,.28,.10)}),Restart=button('REINICIAR',{'ZIndex':95,**rect(.36,.43,.28,.10)}),Finish=button('FINALIZAR',{'ZIndex':95,'BackgroundColor3':c([168,53,74]),**rect(.68,.43,.28,.10)}),Status=label('Los cambios afectan a todos los jugadores del entorno de prueba.',{'ZIndex':94,**rect(.04,.60,.92,.16)}),Confirm=button('CONFIRMAR',{'Visible':False,'ZIndex':95,'BackgroundColor3':c([197,122,30]),**rect(.22,.82,.56,.10)}))
admin_path=r/'src/ui/AdminHUD.project.json';admin=json.loads(admin_path.read_text(encoding='utf-8'));m=admin['tree']['MainFrame']
panel['DaysLabel']=label('DURACIÓN EN DÍAS',{'ZIndex':94,**rect(.69,.215,.27,.035)})
m['SeasonPanel']=panel;m['SeasonsButton']=button('TEMPORADAS',{'ZIndex':88,**rect(.53,.025,.22,.075)})
admin_path.write_text(json.dumps(admin,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
for name in ['default.project.json','studio-safe.project.json']:
 p=r/name;d=json.loads(p.read_text(encoding='utf-8'));d['tree']['StarterGui']['ProgressionHUD']={'$path':'src/ui/ProgressionHUD.project.json'}
 if name=='studio-safe.project.json':
  d['tree']['ServerScriptService']['Services']['ProgressionService']={'$path':'src/server/Services/ProgressionService.luau'}
  d['tree']['ServerScriptService']['Services']['Gameplay']['SeasonState']={'$path':'src/server/Services/Gameplay/SeasonState.luau'}
  d['tree']['ReplicatedStorage']['Shared']['Progression']={'$path':'src/shared/Progression'}
  d['tree']['StarterPlayer']['StarterPlayerScripts']['Controllers']['BattlePassController']={'$path':'src/client/Controllers/BattlePassController.luau'}
 p.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Progression UI/project resources prepared')
