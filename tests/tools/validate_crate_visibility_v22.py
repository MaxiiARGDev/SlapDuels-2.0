"""Offline only. No Roblox execution or cloud writes."""
import hashlib,json,subprocess,sys,xml.etree.ElementTree as ET
from pathlib import Path
root=Path(__file__).resolve().parents[2]
luau=Path(r'C:\Users\rataatrevida\AppData\Local\Temp\SlapDuels-AbilityV1-Luau\luau.exe')
rojo=Path(r'C:\Users\rataatrevida\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe')
checks={}
def run(name,args):
 p=subprocess.run([str(x)for x in args],cwd=root,capture_output=True,text=True,encoding='utf-8',errors='replace')
 (root/f'tests/CrateVisibilityV22.{name}.log').write_text(p.stdout+p.stderr,encoding='utf-8')
 checks[name]={'ExitCode':p.returncode};print(name,p.returncode,p.stdout.strip()[-200:],flush=True)
 assert p.returncode==0,name
run('compose',[sys.executable,'tests/tools/crate_visual_v21_spec.py'])
for name,spec in [('visibility','CrateVisibilityV22'),('crates','CrateVisualV21'),('economy','EconomyBalanceV1'),('combat','SlapVictimProtection'),('abilities','AbilityMultiplayerFixV1.regression'),('registry','AbilityShopV13.registry'),('shop','EconomyBalanceV1.shop')]:
 run(name,[sys.executable,'tests/tools/run_ability_unit_tests.py','--luau',luau,'--spec',f'tests/{spec}.spec.luau','--output',f'tests/CrateVisibilityV22.{name}-results.txt'])
sources=sorted((root/'src').rglob('*.luau'))
run('compile',[luau.with_name('luau-compile.exe'),'--null',*sources,root/'tests/CrateVisibilityV22.spec.luau'])
run('safe-map',['powershell','-NoProfile','-File','Start-StudioSafeRojo.ps1','-GenerateOnly'])
for name,project in [('build','default.project.json'),('safe-build','studio-safe.project.json')]:
 run(name,[rojo,'build',project,'-o',f'tests/CrateVisibilityV22.{name}.rbxlx'])
 tree=ET.parse(root/f'tests/CrateVisibilityV22.{name}.rbxlx').getroot()
 modules=[n for n in tree.iter('Item')if n.findtext('./Properties/string[@name="Name"]')=='CharacterVisibility']
 assert len(modules)==1 and modules[0].attrib['class']=='ModuleScript'
 assert 'Client-only lease' in modules[0].findtext('./Properties/*[@name="Source"]')
manifest=json.loads((root/'src/assets/CrateVisualsV21/manifest.json').read_text())
for row in manifest:
 p=root/'src/assets/CrateVisualsV21'/(row['Name']+'.rbxm')
 assert hashlib.sha256(p.read_bytes()).hexdigest()==row['Hash']
before=json.loads((root/'tests/assets/backups/CrateVisibilityV22/current-hashes.json').read_text(encoding='utf-8-sig'))
for row in before:
 assert hashlib.sha256(Path(row['Path']).read_bytes()).hexdigest().upper()==row['Hash'],row['Path']
run('diff-check',['git','diff','--check'])
(root/'tests/CrateVisibilityV22.checks.json').write_text(json.dumps({'Checks':checks,'CompiledRuntimeScripts':len(sources),'V21AssetsUnchanged':True,'SourceBaselineUnchangedSinceImplementation':True,'Gameplay':'NOT RUN'},indent=2),encoding='utf-8')
