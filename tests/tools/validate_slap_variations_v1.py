"""Offline validation; never starts Studio or accesses cloud."""
import json
import subprocess
import sys
from pathlib import Path
root=Path(__file__).resolve().parents[2]
luau=Path(r'C:\Users\rataatrevida\AppData\Local\Temp\SlapDuels-AbilityV1-Luau\luau.exe')
rojo=Path(r'C:\Users\rataatrevida\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe')
checks={}
def run(name,args):
 p=subprocess.run([str(x)for x in args],cwd=root,capture_output=True,text=True,encoding='utf-8',errors='replace')
 log=f'tests/SlapVariationsV1.{name}.log';(root/log).write_text(p.stdout+p.stderr,encoding='utf-8')
 checks[name]={'ExitCode':p.returncode,'Log':log};print(name,p.returncode,p.stdout.strip()[:170])
 assert p.returncode==0,log
run('appearance',[sys.executable,'tests/tools/run_slap_variations_v1_tests.py'])
for name,spec in [('crates','SlapCratesV1'),('combat','SlapVictimProtection'),('ability','AbilityMultiplayerFixV1.regression'),('registry','AbilityShopV13.registry'),('shop','AbilityShopV13.shop')]:
 run(name,[sys.executable,'tests/tools/run_ability_unit_tests.py','--luau',luau,'--spec',f'tests/{spec}.spec.luau','--output',f'tests/SlapVariationsV1.{name}-results.txt'])
sources=sorted((root/'src').rglob('*.luau'))
run('compile',[luau.with_name('luau-compile.exe'),'--null',*sources,root/'tests/SlapVariationsV1.appearance.spec.luau',root/'tests/SlapCratesV1.spec.luau'])
run('build',[rojo,'build','default.project.json','-o','tests/SlapVariationsV1.build.rbxlx'])
run('safe-build',[rojo,'build','studio-safe.project.json','-o','tests/SlapVariationsV1.safe.build.rbxlx'])
run('diff-check',['git','diff','--check'])
run('integrity',[sys.executable,'tests/tools/slap_variations_v1_payload.py'])
(root/'tests/SlapVariationsV1.checks.json').write_text(json.dumps({'RuntimeCompiled':len(sources),'Gameplay':'NOT RUN','Checks':checks},indent=2),encoding='utf-8')
