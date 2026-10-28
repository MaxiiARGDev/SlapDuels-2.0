"""Offline V2.5 verification and guarded Edit payloads. Never starts Roblox."""
import base64,hashlib,json,subprocess,sys,xml.etree.ElementTree as ET
from pathlib import Path
root=Path(__file__).resolve().parents[2]
luau=Path(r'C:\Users\rataatrevida\AppData\Local\Temp\SlapDuels-AbilityV1-Luau\luau.exe')
rojo=Path(r'C:\Users\rataatrevida\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe')
checks={}
backup=root/'tests/assets/backups/CrateRevealV25'
assets=root/'src/assets/CrateRevealV25';assets.mkdir(exist_ok=True)
raw=base64.b64decode((backup/'CrateRevealV25.final.base64').read_text().strip())
(assets/'CrateRevealV25.rbxm').write_bytes(raw)
manifest=dict(Name='CrateRevealV25',Descendants=44,Hash=hashlib.sha256(raw).hexdigest())
hud_raw=base64.b64decode((backup/'ShopHUD.after.base64').read_text().strip())
(assets/'ShopHUD.rbxm').write_bytes(hud_raw)
manifest['PreservedShopHUD']=dict(Descendants=200,Hash=hashlib.sha256(hud_raw).hexdigest(),Origin='Captured current Edit design; not overwritten')
(assets/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
project_path=root/'default.project.json';project=json.loads(project_path.read_text(encoding='utf-8-sig'))
project['tree']['ReplicatedStorage']['UIAssets']['CrateRevealV25']={'$path':'src/assets/CrateRevealV25/CrateRevealV25.rbxm','$ignoreUnknownInstances':True}
project['tree']['StarterGui']['ShopHUD']={'$path':'src/assets/CrateRevealV25/ShopHUD.rbxm','$ignoreUnknownInstances':True}
project_path.write_text(json.dumps(project,indent=2)+'\n',encoding='utf-8')
def run(name,args):
 p=subprocess.run([str(x)for x in args],cwd=root,capture_output=True,text=True,encoding='utf-8',errors='replace')
 (root/f'tests/CrateRevealV25.{name}.log').write_text(p.stdout+p.stderr,encoding='utf-8')
 checks[name]=p.returncode;print(name,p.returncode,p.stdout.strip()[-170:],flush=True)
 assert p.returncode==0,name
run('compose-batch',[sys.executable,'tests/tools/crate_batch_v24_spec.py'])
run('compose-cinematic',[sys.executable,'tests/tools/crate_cinematic_v23_spec.py'])
for name,spec in [('visual','CrateRevealV25'),('batch','CrateBatchV24'),('gallery','CrateBatchV24.gallery'),('cinematic','CrateCinematicV23'),('economy','EconomyBalanceV1'),('combat','SlapVictimProtection'),('abilities','AbilityMultiplayerFixV1.regression'),('registry','AbilityShopV13.registry'),('shop','EconomyBalanceV1.shop')]:
 run(name,[sys.executable,'tests/tools/run_ability_unit_tests.py','--luau',luau,'--spec',f'tests/{spec}.spec.luau','--output',f'tests/CrateRevealV25.{name}-results.txt'])
sources=sorted((root/'src').rglob('*.luau'))
run('compile',[luau.with_name('luau-compile.exe'),'--null',*sources,root/'tests/CrateRevealV25.spec.luau',root/'tests/CrateBatchV24.spec.luau',root/'tests/CrateBatchV24.gallery.spec.luau'])
run('safe-map',['powershell','-NoProfile','-File','Start-StudioSafeRojo.ps1','-GenerateOnly'])
for name,project_file in [('build','default.project.json'),('safe-build','studio-safe.project.json')]:
 run(name,[rojo,'build',project_file,'-o',f'tests/CrateRevealV25.{name}.rbxlx'])
tree=ET.parse(root/'tests/CrateRevealV25.build.rbxlx').getroot()
def name(n):return n.findtext('./Properties/string[@name="Name"]')
def get(path):
 parent=tree
 for segment in path.split('/'):
  found=[n for n in parent.findall('Item')if name(n)==segment];assert len(found)==1,(path,segment);parent=found[0]
 return parent
for path,count in [('Workspace/CrateStands/MainCrateStand',154),('StarterGui/ShopHUD',200),('StarterGui/CrateOpeningHUD',26),('ReplicatedStorage/UIAssets/CrateBatchRewardSlot',18),('ReplicatedStorage/UIAssets/CrateRevealV25',44)]:
 node=get(path);assert len(list(node.iter('Item')))-1==count,(path,count)
 for parent in node.iter('Item'):
  names=[name(n)for n in parent.findall('Item')];assert len(names)==len(set(names)),names
for part in ['ChestHighlight','RewardHighlight','RewardEffects/Anchor/JackpotReveal','SpinTick']:
 get('ReplicatedStorage/UIAssets/CrateRevealV25/'+part)
safe=json.loads((root/'studio-safe.project.json').read_text())
def verify_safe(node):
 assert node.get('$ignoreUnknownInstances')is True
 if '$path'in node:assert node['$path'].endswith(('.lua','.luau'))
 for k,v in node.items():
  if not k.startswith('$')and isinstance(v,dict):verify_safe(v)
verify_safe(safe['tree'])
for obj,folder in [('MainCrateStand','CrateBatchV24'),('ShopHUD','CrateBatchV24'),('CrateBatchRewardSlot','CrateBatchV24'),('CrateOpeningHUD','CrateCinematicV23')]:
 assert (backup/(obj+'.before.rbxm')).read_bytes()==(root/f'src/assets/{folder}/{obj}.rbxm').read_bytes(),obj
old=json.loads((backup/'src-hashes.before.json').read_text(encoding='utf-8-sig'));changed=[]
allowed={'src/shared/SlapCrates/OpeningConfig.luau','src/shared/SlapCrates/OpeningTimeline.luau','src/server/Services/Crates/CrateEngine.luau','src/server/Services/Crates/CrateBatchEngine.luau','src/server/Services/Crates/StandOpeningService.luau','src/client/Controllers/CrateStandCinematicController.luau','src/client/CrateOpening/RewardGallery.luau'}
for row in old:
 p=Path(row['Path'])
 if hashlib.sha256(p.read_bytes()).hexdigest().upper()!=row['Hash']:changed.append(p.relative_to(root).as_posix())
assert set(changed)==allowed,changed
run('diff-check',['git','diff','--check'])
report=dict(Checks=checks,RuntimeScriptsCompiled=len(sources),ChangedOriginalSources=changed,OtherOriginalFilesUnchanged=len(old)-len(changed),BuiltResourcesMatched=True,SafeScriptsOnly=True,Gameplay='NOT RUN',ProductionCommerce='BLOCKED')
(root/'tests/CrateRevealV25.checks.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
targets=['src/server/Services/Crates/RewardVisualMetadata.luau']+['src/client/CrateOpening/'+n+'.luau'for n in ['RewardRevealConfig','RewardRevealProfile','RewardVFX','RewardSpinMotion','RewardSpin3D']]+changed
out=root/'tests/CrateRevealV25.payloads';out.mkdir(exist_ok=True)
def h(s):return hashlib.sha256(s.replace('\r\n','\n').rstrip().encode()).hexdigest()
for i,f in enumerate(targets):
 source=(root/f).read_text(encoding='utf-8');prior=backup/f.replace('/','__')
 path=f.removesuffix('.luau').replace('src/client/','StarterPlayer/StarterPlayerScripts/').replace('src/server/','ServerScriptService/').replace('src/shared/','ReplicatedStorage/Shared/')
 (out/f'{i:02d}.json').write_text(json.dumps(dict(File=f,Path=path.split('/'),Source=source,Before=h(prior.read_text(encoding='utf-8'))if prior.exists()else None,After=h(source))),encoding='utf-8')
