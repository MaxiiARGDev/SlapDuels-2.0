"""Validate presentation changes without Play, cloud or mutations of authority."""
from pathlib import Path
import subprocess,json,hashlib,sys
r=Path(__file__).resolve().parents[2];prefix=r/'tests/ProfileVisualV13';checks={}
py=sys.executable;luau=Path(r'C:\Users\rataatrevida\AppData\Local\Temp\SlapDuels-AbilityV1-Luau\luau.exe');rojo=Path(r'C:\Users\rataatrevida\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe')
def run(name,args):
 p=subprocess.run([str(a)for a in args],cwd=r,capture_output=True,text=True,encoding='utf-8',errors='replace')
 Path(str(prefix)+'.'+name+'.log').write_text(p.stdout+p.stderr,encoding='utf-8');checks[name]={'ExitCode':p.returncode};print(name,p.returncode,flush=True)
run('compile',[luau.with_name('luau-compile.exe'),'--null','src/client/Controllers/SocialController.luau'])
run('social',[py,'tests/tools/run_social_v11.py'])
run('features',[py,'tests/tools/run_ability_unit_tests.py','--luau',luau,'--spec','tests/ProfileSocialV12.spec.luau','--output','tests/ProfileVisualV13.features.txt'])
for name in ['default.project.json','studio-safe.project.json']:run(name,[rojo,'build',name,'-o',str(prefix)+'.'+name+'.rbxlx'])
run('diff',['git','diff','--check'])
ui=json.loads((r/'src/ui/PlayerProfileHUD.project.json').read_text(encoding='utf-8'))['tree'];main=ui['MainFrame']
checks['Contrast']={'NoEnabledGradientOnCanvasGroup':all(not n.get('$properties',{}).get('Enabled',True)for n in main.values()if isinstance(n,dict)and n.get('$className')=='UIGradient'),
 'WhiteGroupTint':main['$properties']['GroupColor3']=={'Color3':[1,1,1]},'SeparateBackgroundFrame':main['Surface']['$className']=='Frame'}
checks['NativeShapes']={'StatIcons':all('StatIcon'in main['Summary'][k]for k in ['Streak','Wins','Kills']),
 'ActionIcons':all('ActionIcon'in main[k]and 'ActionLabel'in main[k]for k in ['Articles','Challenge','Invite','Trade'])}
baseline=json.loads((r/'tests/assets/backups/ProfileVisualV13/hashes.before.json').read_text(encoding='utf-8'))
changed=[name for name,h in baseline.items()if hashlib.sha256((r/name).read_bytes()).hexdigest()!=h]
checks['Scope']={'Changed':changed,'Unexpected':[name for name in changed if name not in ['src/ui/PlayerProfileHUD.project.json','src/client/Controllers/SocialController.luau']]}
Path(str(prefix)+'.checks.json').write_text(json.dumps(checks,indent=2),encoding='utf-8')
print('Contrast',checks['Contrast'],'Scope',checks['Scope'],flush=True)
sys.exit(any(v.get('ExitCode',0)for v in checks.values())or bool(checks['Scope']['Unexpected'])or not all(checks['Contrast'].values())or not all(checks['NativeShapes'].values()))
