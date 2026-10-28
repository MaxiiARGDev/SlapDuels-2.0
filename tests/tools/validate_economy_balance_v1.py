"""Offline tests/builds only; never initiates Studio or cloud."""
import json,subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parents[2]
luau=Path(r'C:\Users\rataatrevida\AppData\Local\Temp\SlapDuels-AbilityV1-Luau\luau.exe')
rojo=Path(r'C:\Users\rataatrevida\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe')
checks={}
def run(name,args):
 p=subprocess.run([str(x) for x in args],cwd=root,capture_output=True,text=True,encoding='utf-8',errors='replace')
 (root/f'tests/EconomyBalanceV1.{name}.log').write_text(p.stdout+p.stderr,encoding='utf-8')
 checks[name]={'ExitCode':p.returncode,'Log':f'tests/EconomyBalanceV1.{name}.log'}
 print(name,p.returncode,p.stdout.strip()[-220:],flush=True)
 if p.returncode:raise RuntimeError(name+' failed')
run('compose',[sys.executable,'tests/tools/economy_balance_v1_specs.py'])
for name,spec in [('economy','EconomyBalanceV1'),('crates','SlapCratesV13'),('combat','SlapVictimProtection'),('abilities','AbilityMultiplayerFixV1.regression'),('registry','AbilityShopV13.registry'),('shop','EconomyBalanceV1.shop')]:
 run(name,[sys.executable,'tests/tools/run_ability_unit_tests.py','--luau',luau,'--spec',f'tests/{spec}.spec.luau','--output',f'tests/EconomyBalanceV1.{name}-results.txt'])
run('variations',[sys.executable,'tests/tools/run_slap_variations_v1_tests.py'])
sources=sorted((root/'src').rglob('*.luau'))
run('compile',[luau.with_name('luau-compile.exe'),'--null',*sources,root/'tests/EconomyBalanceV1.spec.luau',root/'tests/SlapCratesV13.spec.luau'])
run('build',[rojo,'build','default.project.json','-o','tests/EconomyBalanceV1.build.rbxlx'])
run('safe-build',[rojo,'build','studio-safe.project.json','-o','tests/EconomyBalanceV1.safe.build.rbxlx'])
run('diff-check',['git','diff','--check'])
run('integrity',[sys.executable,'tests/tools/economy_balance_v1_sync.py'])
(root/'tests/EconomyBalanceV1.checks.json').write_text(json.dumps(dict(RuntimeScriptsCompiled=len(sources),Checks=checks,Gameplay='NOT RUN',Cloud='NOT ACCESSED'),indent=2),encoding='utf-8')
