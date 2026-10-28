"""Minimal physical UI additions. Existing sizes/positions and spin assets stay untouched."""
import json
from pathlib import Path
root=Path(__file__).resolve().parents[2]
panel=root/'src/ui/CratePanel.project.json';data=json.loads(panel.read_text(encoding='utf-8'))
tree=data['tree']
tree['Count']['$properties'].update(Text='Cajas: 0 · Saldo: —',TextXAlignment='Left')
tree['Status']['$properties']['Text']='Seleccioná una caja y consultá sus probabilidades.'
for name,label in [('Buy','COMPRAR'),('Open','ABRIR')]:tree[name]['$properties'].update(Text=label,Active=False,AutoButtonColor=False)
panel.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
actions=root/'src/ui/CrateActionsTemplate.project.json';data=json.loads(actions.read_text(encoding='utf-8'))
data['tree']['Action']['$properties'].update(Text='COMPRAR',Active=False)
data['tree']['StockLabel']={'$className':'TextLabel','$properties':{
 'Position':{'UDim2':[[0,0],[0,-27]]},'Size':{'UDim2':[[1,0],[0,18]]},'BackgroundTransparency':1,
 'Text':'Stock: consultar','TextColor3':{'Color3':[1,1,1]},'TextSize':10,'ZIndex':65}}
actions.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
preview={'name':'CratePreviewTemplate','tree':{'$className':'ViewportFrame','$properties':{
 'Size':{'UDim2':[[1,0],[1,0]]},'BackgroundTransparency':1,'Visible':False,'ZIndex':2,
 'Ambient':{'Color3':[.8,.8,.8]},'LightColor':{'Color3':[1,1,1]}},'WorldModel':{'$className':'WorldModel'},
 'Camera':{'$className':'Camera','$properties':{'FieldOfView':45}}}}
(root/'src/ui/CratePreviewTemplate.project.json').write_text(json.dumps(preview,indent=2)+'\n',encoding='utf-8')
project=root/'default.project.json';data=json.loads(project.read_text(encoding='utf-8'))
data['tree']['StarterGui']['ShopHUD']['CratePreviewTemplate']={'$path':'src/ui/CratePreviewTemplate.project.json'}
data['tree']['ServerStorage'].setdefault('$properties',{}).setdefault('Attributes',{})['CrateStudioTestsEnabled']={'Bool':True}
project.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('Updated texts/states; added StockLabel/Viewport template; only Studio fixture enabled')
