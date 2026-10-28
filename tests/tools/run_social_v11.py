"""Isolated Luau social tests; no Studio, cloud, purchases or transfers."""
from pathlib import Path
import json,subprocess,tempfile,sys
r=Path(__file__).resolve().parents[2]
files={p.stem:p.relative_to(r).as_posix()for p in (r/'src/shared/SlapCrates').glob('*.luau')}
files.update({p.stem:p.relative_to(r).as_posix()for p in (r/'src/server/Services/Trading').glob('*.luau')})
files.update({'SocialConfig':'src/shared/SocialConfig.luau','Targeting':'src/client/Social/Targeting.luau','ViewportPool':'src/client/Social/ViewportPool.luau'})
files['SocialService']='src/server/Services/SocialService.luau'
files['SocialController']='src/client/Controllers/SocialController.luau'
parts=['local Sources={}']
for key,path in files.items():parts.append('Sources['+json.dumps(key)+']=[====[\n'+(r/path).read_text(encoding='utf-8')+'\n]====]')
parts.append((r/'tests/PlayerInventoryTradingV10.spec.luau').read_text(encoding='utf-8'))
parts.append((r/'tests/PlayerInventoryV11.spec.luau').read_text(encoding='utf-8'))
with tempfile.TemporaryDirectory(prefix='SlapDuels-social-')as directory:
 p=Path(directory)/'tests.luau';p.write_text('\n'.join(parts),encoding='utf-8')
 result=subprocess.run([r'C:\Users\rataatrevida\AppData\Local\Temp\SlapDuels-AbilityV1-Luau\luau.exe',str(p)],capture_output=True,text=True)
 (r/'tests/PlayerInventoryV11.results.txt').write_text(result.stdout+result.stderr,encoding='utf-8')
 print(result.stdout+result.stderr);sys.exit(result.returncode)
