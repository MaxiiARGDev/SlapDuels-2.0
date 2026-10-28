"""Offline Premium Shop audit/build + guarded Edit payloads; no Studio execution."""
import base64,hashlib,json,subprocess,sys,xml.etree.ElementTree as ET
from pathlib import Path
root=Path(__file__).resolve().parents[2];backup=root/'tests/assets/backups/PremiumShopV1'
luau=Path(r'C:\Users\rataatrevida\AppData\Local\Temp\SlapDuels-AbilityV1-Luau\luau.exe')
rojo=Path(r'C:\Users\rataatrevida\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe')
checks={}
def run(name,args):
 p=subprocess.run([str(x)for x in args],cwd=root,capture_output=True,text=True,encoding='utf-8',errors='replace')
 (root/f'tests/PremiumShopV1.{name}.log').write_text(p.stdout+p.stderr,encoding='utf-8');checks[name]=p.returncode
 print(name,p.returncode,p.stdout.strip()[-180:],flush=True);assert p.returncode==0,name
assets=root/'src/assets/PremiumShopV1';assets.mkdir(exist_ok=True)
rows=json.loads((root/'tests/PremiumShopV1.asset-index.json').read_text());manifest=[]
for row in rows:
 raw=base64.b64decode((backup/(row['Name']+'.final.base64')).read_text().strip());(assets/(row['Name']+'.rbxm')).write_bytes(raw)
 manifest.append(dict(Name=row['Name'],Descendants=row['Descendants'],Path=row['TreePath'],Hash=hashlib.sha256(raw).hexdigest()))
for n in ['ShopHUD','PlayerHUD','MainCrateStand']:(backup/(n+'.before.rbxm')).write_bytes(base64.b64decode((backup/(n+'.before.base64')).read_text().strip()))
(assets/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
p=root/'default.project.json';project=json.loads(p.read_text(encoding='utf-8-sig'));tree=project['tree']
for row in rows:
 node=tree
 for key in row['TreePath'][:-1]:node=node.setdefault(key,{'$className':'Folder','$ignoreUnknownInstances':True})
 node[row['TreePath'][-1]]={'$path':'src/assets/PremiumShopV1/'+row['Name']+'.rbxm','$ignoreUnknownInstances':True}
p.write_text(json.dumps(project,indent=2)+'\n',encoding='utf-8')
run('compose',[sys.executable,'tests/tools/premium_shop_v1_spec.py'])
run('compose-cinematic',[sys.executable,'tests/tools/crate_cinematic_v23_spec.py'])
for name,spec in [('unit','PremiumShopV1'),('reveal','CrateRevealV25'),('gallery','CrateBatchV24.gallery'),('cinematic','CrateCinematicV23'),('economy','EconomyBalanceV1'),('combat','SlapVictimProtection'),('abilities','AbilityMultiplayerFixV1.regression'),('registry','AbilityShopV13.registry'),('shop','EconomyBalanceV1.shop')]:
 run(name,[sys.executable,'tests/tools/run_ability_unit_tests.py','--luau',luau,'--spec',f'tests/{spec}.spec.luau','--output',f'tests/PremiumShopV1.{name}-results.txt'])
sources=sorted((root/'src').rglob('*.luau'))
run('compile',[luau.with_name('luau-compile.exe'),'--null',*sources,root/'tests/PremiumShopV1.spec.luau'])
run('safe-map',['powershell','-NoProfile','-File','Start-StudioSafeRojo.ps1','-GenerateOnly'])
for name,project in [('build','default.project.json'),('safe-build','studio-safe.project.json')]:run(name,[rojo,'build',project,'-o',f'tests/PremiumShopV1.{name}.rbxlx'])
built=ET.parse(root/'tests/PremiumShopV1.build.rbxlx').getroot()
def name(n):return n.findtext('./Properties/string[@name="Name"]')
def get(path,tree=built):
 for segment in path:
  found=[n for n in tree.findall('Item')if name(n)==segment];assert len(found)==1,(path,segment);tree=found[0]
 return tree
for row in rows:
 node=get(row['TreePath']);assert len(list(node.iter('Item')))-1==row['Descendants']
 for parent in node.iter('Item'):
  names=[name(n)for n in parent.findall('Item')]
  if row['Name']not in ['ShopHUD','PlayerHUD']:assert len(names)==len(set(names)),(row['Name'],names)
get(['StarterGui','PremiumShopHUD','MainFrame','Catalog','ProductCardTemplate','Preview','WorldModel'])
get(['StarterGui','PlayerHUD','PremiumShopButton'])
get(['Workspace','Shops','CoinShop','InteractionPart','ProximityPrompt'])
# Compare complete native GUI backups semantically, allowing ONLY hidden old button and new Premium entry.
compare={'name':'BeforeGUI','tree':{'$className':'DataModel','StarterGui':{'$className':'StarterGui','ShopHUD':{'$path':'ShopHUD.before.rbxm'},'PlayerHUD':{'$path':'PlayerHUD.before.rbxm'}}}}
(backup/'compare.project.json').write_text(json.dumps(compare))
run('backup-build',[rojo,'build',backup/'compare.project.json','-o',backup/'compare.rbxlx'])
previous=ET.parse(backup/'compare.rbxlx').getroot()
def walk(node,path=''):
 yield path,node
 seen={}
 for c in node.findall('Item'):
  key=name(c);seen[key]=seen.get(key,0)+1
  yield from walk(c,path+'/'+key+(''if seen[key]==1 else '#'+str(seen[key])))
def snapshot(node):
 pairs=list(walk(node));refs={n.get('referent'):p for p,n in pairs};out={}
 for path,n in pairs:
  properties={}
  for prop in n.find('Properties'):
   key=prop.get('name')
   if key in ('UniqueId','HistoryId'):continue
   properties[key]=refs.get(prop.text,prop.text)if prop.tag=='Ref'else ET.tostring(prop,encoding='unicode').strip()
  out[path]=(n.get('class'),properties)
 return out
guiChanges={}
for gui in ['ShopHUD','PlayerHUD']:
 before=snapshot(get(['StarterGui',gui],previous));after=snapshot(get(['StarterGui',gui]));changes=[]
 for path,(kind,props)in before.items():
  assert path in after and after[path][0]==kind,(gui,path,'deleted/class change')
  for key,value in props.items():
   if value!=after[path][1].get(key):changes.append((path,key))
 added=set(after)-set(before)
 if gui=='ShopHUD':assert changes==[('/ShopButton','Visible')]and not added,changes
 else:assert not changes and len(added)==4 and all(p.startswith('/PremiumShopButton')for p in added),(changes,added)
 guiChanges[gui]={'PropertiesChanged':changes,'ObjectsAdded':sorted(added)}
safe=json.loads((root/'studio-safe.project.json').read_text())
def verify_safe(n):
 assert n.get('$ignoreUnknownInstances')is True
 if '$path'in n:assert n['$path'].endswith(('.luau','.lua'))
 for k,v in n.items():
  if not k.startswith('$')and isinstance(v,dict):verify_safe(v)
verify_safe(safe['tree'])
old=json.loads((backup/'src-hashes.before.json').read_text());changed=[]
for row in old:
 p=Path(row['Path'])
 if hashlib.sha256(p.read_bytes()).hexdigest()!=row['Hash']:changed.append(p.relative_to(root).as_posix())
allowed={'src/server/Bootstrap.server.luau','src/client/Controllers/ShopController.luau','src/client/Controllers/CrateStandCinematicController.luau','src/shared/SlapCrates/CrateDefinitions.luau','src/shared/SlapCrates/Inventory.luau','src/server/Services/Crates/CrateEngine.luau','src/server/Services/CrateService.luau','src/shared/SlapCrates/CrateShopView.luau'}
assert set(changed)==allowed,changed
allCode='\n'.join(p.read_text(encoding='utf-8')for p in sources)
assert allCode.count('Marketplace.ProcessReceipt=')==1
run('diff-check',['git','diff','--check'])
report=dict(Checks=checks,RuntimeScriptsCompiled=len(sources),ChangedOriginalSources=changed,OtherOriginalFilesUnchanged=len(old)-len(changed),GUIChanges=guiChanges,PurchasesEnabled=False,DurableBackend='NOT IMPLEMENTED / BLOCKED',Gameplay='NOT RUN',BuiltResourcesMatched=True,SafeScriptsOnly=True)
(root/'tests/PremiumShopV1.checks.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
oldPaths={Path(r['Path']).relative_to(root).as_posix()for r in old}
targets=[p.relative_to(root).as_posix()for p in sources if p.relative_to(root).as_posix()not in oldPaths]+changed
out=root/'tests/PremiumShopV1.payloads';out.mkdir(exist_ok=True)
def h(s):return hashlib.sha256(s.replace('\r\n','\n').rstrip().encode()).hexdigest()
for i,f in enumerate(targets):
 source=(root/f).read_text(encoding='utf-8');prior=backup/f.replace('/','__');stem=f.removesuffix('.luau')
 cls='ModuleScript'
 if stem.endswith('.server'):stem=stem.removesuffix('.server');cls='Script'
 elif stem.endswith('.client'):stem=stem.removesuffix('.client');cls='LocalScript'
 path=stem.replace('src/client/','StarterPlayer/StarterPlayerScripts/').replace('src/server/','ServerScriptService/').replace('src/shared/','ReplicatedStorage/Shared/')
 (out/f'{i:02d}.json').write_text(json.dumps(dict(File=f,Path=path.split('/'),Class=cls,Source=source,Before=h(prior.read_text(encoding='utf-8'))if prior.exists()else None,After=h(source))),encoding='utf-8')
