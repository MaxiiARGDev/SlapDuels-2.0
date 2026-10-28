"""Build, compile and isolated logic checks only; never starts Roblox."""
import hashlib,json,subprocess,sys,xml.etree.ElementTree as ET
from pathlib import Path
root=Path(__file__).resolve().parents[2]
luau=Path(r'C:\Users\rataatrevida\AppData\Local\Temp\SlapDuels-AbilityV1-Luau\luau.exe')
rojo=Path(r'C:\Users\rataatrevida\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe')
checks={}
def run(name,args):
 p=subprocess.run([str(x)for x in args],cwd=root,capture_output=True,text=True,encoding='utf-8',errors='replace')
 (root/f'tests/CrateCinematicV23.{name}.log').write_text(p.stdout+p.stderr,encoding='utf-8')
 checks[name]=p.returncode;print(name,p.returncode,p.stdout.strip()[-200:],flush=True)
 assert p.returncode==0,name
run('compose-cinematic',[sys.executable,'tests/tools/crate_cinematic_v23_spec.py'])
run('compose-crates',[sys.executable,'tests/tools/crate_visual_v21_spec.py'])
for name,spec in [('cinematic','CrateCinematicV23'),('crates','CrateVisualV21'),('economy','EconomyBalanceV1'),('combat','SlapVictimProtection'),('abilities','AbilityMultiplayerFixV1.regression'),('registry','AbilityShopV13.registry'),('shop','EconomyBalanceV1.shop')]:
 run(name,[sys.executable,'tests/tools/run_ability_unit_tests.py','--luau',luau,'--spec',f'tests/{spec}.spec.luau','--output',f'tests/CrateCinematicV23.{name}-results.txt'])
sources=sorted((root/'src').rglob('*.luau'))
run('compile',[luau.with_name('luau-compile.exe'),'--null',*sources,root/'tests/CrateCinematicV23.spec.luau'])
run('safe-map',['powershell','-NoProfile','-File','Start-StudioSafeRojo.ps1','-GenerateOnly'])
for name,project in [('build','default.project.json'),('safe-build','studio-safe.project.json')]:
 run(name,[rojo,'build',project,'-o',f'tests/CrateCinematicV23.{name}.rbxlx'])
tree=ET.parse(root/'tests/CrateCinematicV23.build.rbxlx').getroot()
def name(n):return n.findtext('./Properties/string[@name="Name"]')
def get(path):
 parent=tree
 for segment in path.split('/'):
  found=[n for n in parent.findall('Item')if name(n)==segment];assert len(found)==1,(path,segment);parent=found[0]
 return parent
manifest=json.loads((root/'src/assets/CrateCinematicV23/manifest.json').read_text())
for row in manifest:
 p=root/'src/assets/CrateCinematicV23'/(row['Name']+'.rbxm')
 assert hashlib.sha256(p.read_bytes()).hexdigest()==row['Hash']
 node=get('Workspace/CrateStands/MainCrateStand'if row['Name']=='MainCrateStand'else'StarterGui/CrateOpeningHUD')
 assert len(list(node.iter('Item')))-1==row['Descendants']
 for parent in node.iter('Item'):
  names=[name(n)for n in parent.findall('Item')];assert len(names)==len(set(names)),names
for path in ['StarterGui/CrateOpeningHUD/ShutterTop','StarterGui/CrateOpeningHUD/ShutterBottom','StarterGui/CrateOpeningHUD/RewardOverlay','Workspace/CrateStands/MainCrateStand/PresentationTemplate/Effects/FXAnchor/WhooshClose','Workspace/CrateStands/MainCrateStand/PresentationTemplate/Effects/FXAnchor/WhooshOpen']:
 get(path)
before=json.loads((root/'tests/assets/backups/CrateCinematicV23/src-hashes.before.json').read_text(encoding='utf-8-sig'))
changed=[]
for row in before:
 p=Path(row['Path'])
 if hashlib.sha256(p.read_bytes()).hexdigest().upper()!=row['Hash']:changed.append(p.relative_to(root).as_posix())
assert changed==['src/client/Controllers/CrateStandCinematicController.luau'],changed
run('diff-check',['git','diff','--check'])
report=dict(Checks=checks,RuntimeScriptsCompiled=len(sources),OriginalSourcesChanged=changed,AllOtherOriginalSourceAndAssetHashesPreserved=True,BuiltResourcesMatched=True,Gameplay='NOT RUN')
(root/'tests/CrateCinematicV23.checks.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
out=root/'tests/CrateCinematicV23.payloads';out.mkdir(exist_ok=True)
targets=['src/client/CrateOpening/'+n+'.luau'for n in ['CinematicConfig','CinematicMotion','CinematicTransition','StandPromptVisibility']]+changed
def h(s):return hashlib.sha256(s.replace('\r\n','\n').rstrip().encode()).hexdigest()
for i,f in enumerate(targets):
 source=(root/f).read_text(encoding='utf-8')
 old=(root/'tests/assets/backups/CrateCinematicV23/Controller.before.luau').read_text(encoding='utf-8')if f in changed else None
 path=f.removesuffix('.luau').replace('src/client/','StarterPlayer/StarterPlayerScripts/')
 (out/f'{i}.json').write_text(json.dumps(dict(Path=path.split('/'),Source=source,Before=h(old)if old else None,After=h(source))),encoding='utf-8')
