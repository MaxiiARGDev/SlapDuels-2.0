"""Studio-server guarantees tested offline; this script never starts Roblox."""
import hashlib,json,subprocess,sys,xml.etree.ElementTree as ET
from pathlib import Path
root=Path(__file__).resolve().parents[2]
luau=Path(r'C:\Users\rataatrevida\AppData\Local\Temp\SlapDuels-AbilityV1-Luau\luau.exe')
rojo=Path(r'C:\Users\rataatrevida\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe')
checks={}
def run(name,args):
 p=subprocess.run([str(x)for x in args],cwd=root,capture_output=True,text=True,encoding='utf-8',errors='replace')
 (root/f'tests/CrateBatchV24.{name}.log').write_text(p.stdout+p.stderr,encoding='utf-8')
 checks[name]=p.returncode;print(name,p.returncode,p.stdout.strip()[-170:],flush=True)
 assert p.returncode==0,name
run('compose-batch',[sys.executable,'tests/tools/crate_batch_v24_spec.py'])
run('compose-cinematic',[sys.executable,'tests/tools/crate_cinematic_v23_spec.py'])
for name,spec in [('batch','CrateBatchV24'),('gallery','CrateBatchV24.gallery'),('cinematic','CrateCinematicV23'),('economy','EconomyBalanceV1'),('combat','SlapVictimProtection'),('abilities','AbilityMultiplayerFixV1.regression'),('registry','AbilityShopV13.registry'),('shop','EconomyBalanceV1.shop')]:
 run(name,[sys.executable,'tests/tools/run_ability_unit_tests.py','--luau',luau,'--spec',f'tests/{spec}.spec.luau','--output',f'tests/CrateBatchV24.{name}-results.txt'])
sources=sorted((root/'src').rglob('*.luau'))
run('compile',[luau.with_name('luau-compile.exe'),'--null',*sources,root/'tests/CrateBatchV24.spec.luau',root/'tests/CrateBatchV24.gallery.spec.luau'])
run('safe-map',['powershell','-NoProfile','-File','Start-StudioSafeRojo.ps1','-GenerateOnly'])
for name,project in [('build','default.project.json'),('safe-build','studio-safe.project.json')]:
 run(name,[rojo,'build',project,'-o',f'tests/CrateBatchV24.{name}.rbxlx'])
tree=ET.parse(root/'tests/CrateBatchV24.build.rbxlx').getroot()
def name(n):return n.findtext('./Properties/string[@name="Name"]')
def get(path):
 parent=tree
 for segment in path.split('/'):
  found=[n for n in parent.findall('Item')if name(n)==segment];assert len(found)==1,(path,segment);parent=found[0]
 return parent
manifest=json.loads((root/'src/assets/CrateBatchV24/manifest.json').read_text())
for row in manifest:
 p=root/'src/assets/CrateBatchV24'/(row['Name']+'.rbxm');assert hashlib.sha256(p.read_bytes()).hexdigest()==row['Hash']
 path={'MainCrateStand':'Workspace/CrateStands/MainCrateStand','ShopHUD':'StarterGui/ShopHUD','CrateBatchRewardSlot':'ReplicatedStorage/UIAssets/CrateBatchRewardSlot'}[row['Name']]
 node=get(path);assert len(list(node.iter('Item')))-1==row['Descendants']
 for parent in node.iter('Item'):
  names=[name(n)for n in parent.findall('Item')];assert len(names)==len(set(names)),names
for quantity in [1,5,10]:get(f'StarterGui/ShopHUD/CratePanel/OpenQuantities/X{quantity}')
get('ReplicatedStorage/UIAssets/CrateBatchRewardSlot/Anchor/BillboardGui/Slap')
get('ReplicatedStorage/UIAssets/CrateBatchRewardSlot/Anchor/BillboardGui/Variation')
safe=json.loads((root/'studio-safe.project.json').read_text())
def verify_safe(node):
 assert node.get('$ignoreUnknownInstances')is True
 if '$path'in node:assert node['$path'].endswith(('.lua','.luau'))
 for k,v in node.items():
  if not k.startswith('$')and isinstance(v,dict):verify_safe(v)
verify_safe(safe['tree'])
backup=root/'tests/assets/backups/CrateBatchV24'
assert (backup/'MainCrateStand.before.rbxm').read_bytes()==(root/'src/assets/CrateBatchV24/MainCrateStand.rbxm').read_bytes()
assert (backup/'CrateOpeningHUD.before.rbxm').read_bytes()==(root/'src/assets/CrateCinematicV23/CrateOpeningHUD.rbxm').read_bytes()
old=json.loads((backup/'src-hashes.before.json').read_text(encoding='utf-8-sig'));changed=[]
allowed={'src/shared/SlapCrates/OpeningConfig.luau','src/shared/SlapCrates/OpeningTimeline.luau','src/shared/SlapCrates/CrateShopView.luau','src/server/Services/CrateService.luau','src/server/Services/Crates/CrateEngine.luau','src/server/Services/Crates/StandOpeningLedger.luau','src/server/Services/Crates/StandOpeningService.luau','src/client/Controllers/CrateController.luau','src/client/Controllers/CrateStandCinematicController.luau','src/client/CrateOpening/CinematicConfig.luau'}
for row in old:
 p=Path(row['Path'])
 if hashlib.sha256(p.read_bytes()).hexdigest().upper()!=row['Hash']:changed.append(p.relative_to(root).as_posix())
assert set(changed)==allowed,changed
run('diff-check',['git','diff','--check'])
report=dict(Checks=checks,RuntimeScriptsCompiled=len(sources),ChangedOriginalSources=changed,OtherOriginalFilesUnchanged=len(old)-len(changed),BuiltResourcesMatched=True,SafeScriptsOnly=True,Gameplay='NOT RUN',ProductionCommerce='BLOCKED')
(root/'tests/CrateBatchV24.checks.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
targets=['src/shared/SlapCrates/BatchOpening.luau','src/server/Services/Crates/CrateBatchEngine.luau','src/client/CrateOpening/RewardGalleryLayout.luau','src/client/CrateOpening/RewardGallery.luau']+changed
out=root/'tests/CrateBatchV24.payloads';out.mkdir(exist_ok=True)
def h(s):return hashlib.sha256(s.replace('\r\n','\n').rstrip().encode()).hexdigest()
for i,f in enumerate(targets):
 source=(root/f).read_text(encoding='utf-8');prior=backup/f.replace('/','__')
 if f.endswith('/CinematicConfig.luau'):prior=backup/'CinematicConfig.native-before.luau'
 if f.endswith('/CrateShopView.luau'):prior=backup/'CrateShopView.native-before.luau'
 path=f.removesuffix('.luau').replace('src/client/','StarterPlayer/StarterPlayerScripts/').replace('src/server/','ServerScriptService/').replace('src/shared/','ReplicatedStorage/Shared/')
 (out/f'{i:02d}.json').write_text(json.dumps(dict(File=f,Path=path.split('/'),Source=source,Before=h(prior.read_text(encoding='utf-8'))if prior.exists()else None,After=h(source))),encoding='utf-8')
