"""Offline validation only; never starts Studio or contacts persistence."""
import json,subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parents[2]
luau=Path(r'C:\Users\rataatrevida\AppData\Local\Temp\SlapDuels-AbilityV1-Luau\luau.exe')
rojo=Path(r'C:\Users\rataatrevida\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe')
checks={}
def run(name,args):
 p=subprocess.run([str(x) for x in args],cwd=root,capture_output=True,text=True,encoding='utf-8',errors='replace')
 (root/f'tests/SlapCratesV12.{name}.log').write_text(p.stdout+p.stderr,encoding='utf-8')
 checks[name]={'ExitCode':p.returncode,'Log':f'tests/SlapCratesV12.{name}.log'}
 print(name,p.returncode,p.stdout.strip()[-250:],flush=True)
 if p.returncode:raise RuntimeError(name+' failed')
run('compose',[sys.executable,'tests/tools/slap_crates_v12_spec.py'])
for name,spec in [('crates','SlapCratesV12'),('combat','SlapVictimProtection'),('ability','AbilityMultiplayerFixV1.regression'),('registry','AbilityShopV13.registry'),('shop','AbilityShopV13.shop')]:
 run(name,[sys.executable,'tests/tools/run_ability_unit_tests.py','--luau',luau,'--spec',f'tests/{spec}.spec.luau','--output',f'tests/SlapCratesV12.{name}-results.txt'])
run('variations',[sys.executable,'tests/tools/run_slap_variations_v1_tests.py'])
sources=sorted((root/'src').rglob('*.luau'))
run('compile',[luau.with_name('luau-compile.exe'),'--null',*sources,root/'tests/SlapCratesV12.spec.luau'])
run('build',[rojo,'build','default.project.json','-o','tests/SlapCratesV12.build.rbxlx'])
run('safe-build',[rojo,'build','studio-safe.project.json','-o','tests/SlapCratesV12.safe.build.rbxlx'])
run('diff-check',['git','diff','--check'])
run('integrity',[sys.executable,'tests/tools/slap_crates_v12_sync.py'])
(root/'tests/SlapCratesV12.checks.json').write_text(json.dumps(dict(RuntimeScriptsCompiled=len(sources),Gameplay='NOT RUN',Cloud='NOT ACCESSED',Checks=checks),indent=2),encoding='utf-8')
