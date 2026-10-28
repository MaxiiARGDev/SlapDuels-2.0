"""Compile/test/build only. Does not start Studio, touch cloud or transfer items."""
from pathlib import Path
import subprocess,json,hashlib,sys
r=Path(__file__).resolve().parents[2];prefix=r/'tests/ProfileSocialV12'
luau=Path(r'C:\Users\rataatrevida\AppData\Local\Temp\SlapDuels-AbilityV1-Luau\luau.exe')
rojo=Path(r'C:\Users\rataatrevida\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe')
checks={}
def run(name,args):
 result=subprocess.run([str(v)for v in args],cwd=r,capture_output=True,text=True,encoding='utf-8',errors='replace')
 Path(str(prefix)+'.'+name+'.log').write_text(result.stdout+result.stderr,encoding='utf-8')
 checks[name]={'ExitCode':result.returncode};print(name,result.returncode,flush=True)
files=list((r/'src').rglob('*.luau'))+[r/'tests/ProfileSocialV12.spec.luau',r/'tests/ProfileSocialV12.integration.luau'];failures=[]
for p in files:
 result=subprocess.run([str(luau.with_name('luau-compile.exe')),'--null',str(p)],capture_output=True,text=True)
 if result.returncode:failures.append({'File':p.relative_to(r).as_posix(),'Output':result.stdout+result.stderr})
checks['Compile']={'Sources':len(files)-2,'Specs':2,'Failures':failures};print('Compile',len(files),len(failures),flush=True)
run('social',[sys.executable,'tests/tools/run_social_v11.py'])
run('features',[sys.executable,'tests/tools/run_ability_unit_tests.py','--luau',luau,'--spec','tests/ProfileSocialV12.spec.luau','--output','tests/ProfileSocialV12.results.txt'])
run('matchmaking',[sys.executable,'tests/tools/run_matchmaking_xvx_v10.py','--base-spec','tests/MatchmakingXVXV12.spec.luau','--extension','tests/MatchmakingXVXV12.prematch.luau','--extension','tests/MatchmakingXVXV12.integration.luau','--extension','tests/ProfileSocialV12.integration.luau','--output','tests/ProfileSocialV12.integration.txt'])
for spec in ['SlapVictimProtection','AbilityMultiplayerFixV1.regression','EconomyBalanceV1','EconomyBalanceV1.shop','PremiumShopV11','CrateBatchV24']:
 run(spec,[sys.executable,'tests/tools/run_ability_unit_tests.py','--luau',luau,'--spec','tests/'+spec+'.spec.luau','--output','tests/ProfileSocialV12.'+spec+'.txt'])
for project in ['default.project.json','studio-safe.project.json']:run(project,[rojo,'build',project,'-o',str(prefix)+'.'+project+'.rbxlx'])
run('diff',['git','diff','--check'])
b=r/'tests/assets/backups/ProfileSocialV12';before=json.loads((b/'hashes.json').read_text(encoding='utf-8'))
changed=[name for name,h in before.items()if hashlib.sha256((r/name).read_bytes()).hexdigest()!=h]
checks['Integrity']={'ChangedExistingFiles':changed,'Unexpected':[p for p in changed if p not in ['src/server/Services/SocialService.luau','src/client/Controllers/SocialController.luau','src/server/Services/PlayerService.luau','src/server/Services/PlayerDataService.luau','src/server/Services/MatchmakingService.luau','src/server/Services/RoundService.luau','src/server/Bootstrap.server.luau','src/server/Services/Trading/PublicInventory.luau','src/shared/Types.luau','src/ui/PlayerProfileHUD.project.json','default.project.json','studio-safe.project.json']]}
# Previously authored project entries must be semantically identical, despite JSON formatting.
def preserved(old,new,path=''):
 if isinstance(old,dict):
  return all(k in new and preserved(v,new[k],path+'/'+k)for k,v in old.items())
 return old==new
checks['OldRojoEntriesPreserved']=all(preserved(json.loads((b/name).read_text(encoding='utf-8')),json.loads((r/name).read_text(encoding='utf-8')))for name in ['default.project.json','studio-safe.project.json'])
Path(str(prefix)+'.checks.json').write_text(json.dumps(checks,indent=2),encoding='utf-8')
print('Existing files changed:',changed,'Prior mappings preserved:',checks['OldRojoEntriesPreserved'],flush=True)
sys.exit(bool(failures or checks['Integrity']['Unexpected']or not checks['OldRojoEntriesPreserved']or any(v.get('ExitCode',0)for v in checks.values()if isinstance(v,dict))))
