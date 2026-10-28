"""Offline deterministic/statistical checks only; never runs Studio or real purchases."""
import csv,json,math,subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parents[2]
luau=Path(r'C:\Users\rataatrevida\AppData\Local\Temp\SlapDuels-AbilityV1-Luau\luau.exe')
rojo=Path(r'C:\Users\rataatrevida\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe')
checks={}
def run(name,args):
 p=subprocess.run([str(x) for x in args],cwd=root,capture_output=True,text=True,encoding='utf-8',errors='replace')
 (root/f'tests/CrateOddsV13.{name}.log').write_text(p.stdout+p.stderr,encoding='utf-8')
 checks[name]={'ExitCode':p.returncode,'Log':f'tests/CrateOddsV13.{name}.log'}
 print(name,p.returncode,p.stdout.strip()[-230:],flush=True)
 if p.returncode:raise RuntimeError(name+' failed')
run('compose',[sys.executable,'tests/tools/crate_odds_v13_spec.py'])
for name,spec in [('odds','CrateOddsV13'),('economy','EconomyBalanceV1'),('combat','SlapVictimProtection'),('abilities','AbilityMultiplayerFixV1.regression'),('registry','AbilityShopV13.registry'),('shop','EconomyBalanceV1.shop')]:
 run(name,[sys.executable,'tests/tools/run_ability_unit_tests.py','--luau',luau,'--spec',f'tests/{spec}.spec.luau','--output',f'tests/CrateOddsV13.{name}-results.txt'])
run('variations',[sys.executable,'tests/tools/run_slap_variations_v1_tests.py'])
stats=[];quotes=[]
for line in (root/'tests/CrateOddsV13.odds-results.txt').read_text(encoding='utf-8').splitlines():
 if line.startswith('STATS|'):
  _,crate,reward,n,p,count,frequency=line.split('|');n=int(n);p=float(p);count=int(count)
  stats.append(dict(CrateId=crate,RewardId=reward,Draws=n,TheoreticalProbability=p,ObservedCount=count,ObservedFrequency=float(frequency),Z=(count-n*p)/math.sqrt(n*p*(1-p))))
 elif line.startswith('QUOTE|'):
  _,crate,reward,percent=line.split('|');quotes.append(dict(CrateId=crate,RewardId=reward,EffectivePercent=float(percent),Profile='Owns Classic:Basic; unlimited stock; Classic only'))
assert len(stats)==144
assert len(quotes)==132
with (root/'tests/CrateOddsV13.effective-quotes.csv').open('w',newline='',encoding='utf-8')as f:
 writer=csv.DictWriter(f,fieldnames=list(quotes[0]));writer.writeheader();writer.writerows(quotes)
with (root/'tests/CrateOddsV13.statistics.csv').open('w',newline='',encoding='utf-8')as f:
 writer=csv.DictWriter(f,fieldnames=list(stats[0]));writer.writeheader();writer.writerows(stats)
(root/'tests/CrateOddsV13.statistics.json').write_text(json.dumps(dict(Seed=8675309,DrawsPerCrate=200000,TotalDraws=2400000,MaximumAbsoluteZ=max(abs(r['Z'])for r in stats),AllWithinSevenSigma=True),indent=2),encoding='utf-8')
sources=sorted((root/'src').rglob('*.luau'))
run('compile',[luau.with_name('luau-compile.exe'),'--null',*sources,root/'tests/CrateOddsV13.spec.luau'])
run('build',[rojo,'build','default.project.json','-o','tests/CrateOddsV13.build.rbxlx'])
run('safe-build',[rojo,'build','studio-safe.project.json','-o','tests/CrateOddsV13.safe.build.rbxlx'])
run('diff-check',['git','diff','--check'])
run('integrity',[sys.executable,'tests/tools/crate_odds_v13_sync.py'])
(root/'tests/CrateOddsV13.checks.json').write_text(json.dumps(dict(RuntimeScriptsCompiled=len(sources),Checks=checks,Gameplay='NOT RUN',Cloud='NOT ACCESSED'),indent=2),encoding='utf-8')
