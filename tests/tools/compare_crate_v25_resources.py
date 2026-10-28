"""Read captured native Edit resources offline, preserving originals."""
import base64,json,subprocess,xml.etree.ElementTree as ET
from pathlib import Path
root=Path(__file__).resolve().parents[2];folder=root/'tests/assets/backups/CrateRevealV25'
rojo=r'C:\Users\rataatrevida\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe'
native=base64.b64decode((folder/'ShopHUD.after.base64').read_text().strip())
(folder/'ShopHUD.after.rbxm').write_bytes(native)
project={'name':'V25SnapshotComparison','tree':{'$className':'DataModel','ReplicatedStorage':{'$className':'ReplicatedStorage','Before':{'$path':'ShopHUD.before.rbxm'},'After':{'$path':'ShopHUD.after.rbxm'}}}}
(folder/'compare.project.json').write_text(json.dumps(project,indent=2))
subprocess.run([rojo,'build',str(folder/'compare.project.json'),'-o',str(folder/'compare.rbxlx')],check=True,cwd=root)
tree=ET.parse(folder/'compare.rbxlx').getroot()
def name(n):return n.findtext('./Properties/string[@name="Name"]')
rs=tree.find('Item');roots={name(n):n for n in rs.findall('Item')}
def walk(node,path=''):
 yield path,node
 for c in node.findall('Item'):yield from walk(c,path+'/'+name(c))
def snapshot(node):
 pairs=list(walk(node));refs={n.get('referent'):p for p,n in pairs};out={}
 for p,n in pairs:
  props={}
  for prop in n.find('Properties'):
   key=prop.get('name')
   if key in ['UniqueId','HistoryId']or not p and key=='Name':continue
   if prop.tag=='Ref':value=refs.get(prop.text,prop.text)
   else:value=ET.tostring(prop,encoding='unicode')
   props[key]=value
  out[p]={'Class':n.get('class'),'Properties':props}
 return out
a,b=snapshot(roots['Before']),snapshot(roots['After'])
added=sorted(b.keys()-a.keys());removed=sorted(a.keys()-b.keys());changed={}
for p in a.keys()&b.keys():
 if a[p]!=b[p]:changed[p]={k:{'Before':a[p]['Properties'].get(k),'After':b[p]['Properties'].get(k)}for k in a[p]['Properties'].keys()|b[p]['Properties'].keys()if a[p]['Properties'].get(k)!=b[p]['Properties'].get(k)}
result={'Added':added,'Removed':removed,'ChangedProperties':changed}
(folder/'ShopHUD.delta.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print(json.dumps(result,indent=2))
