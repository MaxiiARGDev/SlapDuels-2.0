"""Static/offline validation only. Does not invoke Studio, cloud, publishing or Git mutations."""
import json
import subprocess
import sys
from pathlib import Path
root=Path(__file__).resolve().parents[2]
luau=Path(r'C:\Users\rataatrevida\AppData\Local\Temp\SlapDuels-AbilityV1-Luau\luau.exe')
compiler=luau.with_name('luau-compile.exe')
rojo=Path(r'C:\Users\rataatrevida\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe')
checks={}
def run(name,args):
 p=subprocess.run([str(x) for x in args],cwd=root,capture_output=True,text=True,encoding='utf-8',errors='replace')
 (root/f'tests/SlapCratesV1.{name}.log').write_text(p.stdout+p.stderr,encoding='utf-8')
 checks[name]={'ExitCode':p.returncode,'Log':f'tests/SlapCratesV1.{name}.log'}
 print(name,p.returncode,p.stdout.strip()[:200])
 if p.returncode:raise RuntimeError(f'{name} failed; inspect log')
for name,spec in [('crates','SlapCratesV1'),('combat','SlapVictimProtection'),('ability','AbilityMultiplayerFixV1.regression'),('registry','AbilityShopV13.registry'),('shop','AbilityShopV13.shop')]:
 run(name,[sys.executable,'tests/tools/run_ability_unit_tests.py','--luau',luau,'--spec',f'tests/{spec}.spec.luau','--output',f'tests/SlapCratesV1.{name}-results.txt'])
sources=sorted((root/'src').rglob('*.luau'))
run('compile',[compiler,'--null',*sources,root/'tests/SlapCratesV1.spec.luau'])
run('build',[rojo,'build','default.project.json','-o','tests/SlapCratesV1.build.rbxlx'])
run('safe-build',[rojo,'build','studio-safe.project.json','-o','tests/SlapCratesV1.safe.build.rbxlx'])
run('diff-check',['git','diff','--check'])
run('integrity',[sys.executable,'tests/tools/slap_crates_v1_sync.py'])
(root/'tests/SlapCratesV1.checks.json').write_text(json.dumps({'RuntimeScriptsCompiled':len(sources),'Gameplay':'NOT RUN','Cloud':'NOT ACCESSED','Checks':checks},indent=2),encoding='utf-8')
