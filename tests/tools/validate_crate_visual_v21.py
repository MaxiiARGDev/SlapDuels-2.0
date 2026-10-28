"""Offline validation, including built hierarchies and synchronization boundaries."""
import json,subprocess,sys,xml.etree.ElementTree as ET
from pathlib import Path
root=Path(__file__).resolve().parents[2]
luau=Path(r'C:\Users\rataatrevida\AppData\Local\Temp\SlapDuels-AbilityV1-Luau\luau.exe')
rojo=Path(r'C:\Users\rataatrevida\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe')
checks={}
def run(name,args):
 p=subprocess.run([str(x)for x in args],cwd=root,capture_output=True,text=True,encoding='utf-8',errors='replace')
 (root/f'tests/CrateVisualV21.{name}.log').write_text(p.stdout+p.stderr,encoding='utf-8')
 checks[name]={'ExitCode':p.returncode,'Log':f'tests/CrateVisualV21.{name}.log'}
 print(name,p.returncode,p.stdout.strip()[-240:],flush=True)
 if p.returncode:raise RuntimeError(name+' failed')
run('compose',[sys.executable,'tests/tools/crate_visual_v21_spec.py'])
for name,spec in [('visual','CrateVisualV21'),('economy','EconomyBalanceV1'),('combat','SlapVictimProtection'),('abilities','AbilityMultiplayerFixV1.regression'),('registry','AbilityShopV13.registry'),('shop','EconomyBalanceV1.shop')]:
 run(name,[sys.executable,'tests/tools/run_ability_unit_tests.py','--luau',luau,'--spec',f'tests/{spec}.spec.luau','--output',f'tests/CrateVisualV21.{name}-results.txt'])
run('variations',[sys.executable,'tests/tools/run_slap_variations_v1_tests.py'])
sources=sorted((root/'src').rglob('*.luau'))
run('compile',[luau.with_name('luau-compile.exe'),'--null',*sources,root/'tests/CrateVisualV21.spec.luau'])
run('build',[rojo,'build','default.project.json','-o','tests/CrateVisualV21.build.rbxlx'])
run('safe-build',[rojo,'build','studio-safe.project.json','-o','tests/CrateVisualV21.safe.build.rbxlx'])
tree=ET.parse(root/'tests/CrateVisualV21.build.rbxlx').getroot()
def name(node):return node.findtext('./Properties/string[@name="Name"]')
def get(parent,path):
 for segment in path.split('/'):
  matches=[n for n in parent.findall('Item')if name(n)==segment]
  assert len(matches)==1,(path,segment,len(matches));parent=matches[0]
 return parent
snapshots=json.loads((root/'src/assets/CrateVisualsV21/manifest.json').read_text())
for row in snapshots:
 path='Workspace/CrateStands/MainCrateStand'if row['Name']=='MainCrateStand'else'StarterGui/'+row['Name']
 node=get(tree,path);assert len(list(node.iter('Item')))-1==row['Descendants'],path
 for parent in node.iter('Item'):
  names=[name(n)for n in parent.findall('Item')];assert len(names)==len(set(names)),(path,names)
get(tree,'Workspace/CrateStands/MainCrateStand/VisualDecor/Backdrop')
get(tree,'StarterGui/CrateOpeningHUD/RewardOverlay/RevealScale')
get(tree,'StarterGui/ShopHUD/CratePanel/OddsList/RowTemplate')
safe=json.loads((root/'studio-safe.project.json').read_text())
def verify_safe(node):
 assert node.get('$ignoreUnknownInstances')is True
 if '$path'in node:assert node['$path'].endswith(('.lua','.luau')),node['$path']
 for k,v in node.items():
  if not k.startswith('$')and isinstance(v,dict):verify_safe(v)
verify_safe(safe['tree'])
project=json.loads((root/'default.project.json').read_text())
for key in ['ShopHUD','CrateOpeningHUD']:
 node=project['tree']['StarterGui'][key];assert node['$path'].startswith('src/assets/CrateVisualsV21/')and all(k.startswith('$')for k in node)
run('diff-check',['git','diff','--check'])
run('integrity',[sys.executable,'tests/tools/crate_visual_v21_sync.py'])
(root/'tests/CrateVisualV21.checks.json').write_text(json.dumps(dict(RuntimeScriptsCompiled=len(sources),Checks=checks,BuiltSnapshotHierarchiesMatched=True,SafeScriptOnlyBoundariesVerified=True,Gameplay='NOT RUN'),indent=2),encoding='utf-8')
