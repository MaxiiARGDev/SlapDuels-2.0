"""Bundle social regression and loadout tests; no Roblox, cloud or gameplay."""
from pathlib import Path
import json,subprocess,tempfile,sys
r=Path(__file__).resolve().parents[2]
files={p.stem:p for p in (r/'src/shared/SlapCrates').glob('*.luau')}
files.update({p.stem:p for p in (r/'src/server/Services/Trading').glob('*.luau')})
files.update({name:r/path for name,path in {'SocialConfig':'src/shared/SocialConfig.luau','Targeting':'src/client/Social/Targeting.luau','ViewportPool':'src/client/Social/ViewportPool.luau','SocialService':'src/server/Services/SocialService.luau','SocialController':'src/client/Controllers/SocialController.luau'}.items()})
parts=['local Sources={}']+[f'Sources[{json.dumps(k)}]=[====[{p.read_text(encoding="utf-8")}]====]'for k,p in files.items()]
parts += [(r/'tests'/name).read_text(encoding='utf-8')for name in ['PlayerInventoryTradingV10.spec.luau','PlayerInventoryV11.spec.luau','InventoryLoadoutV12.spec.luau']]
with tempfile.TemporaryDirectory(prefix='InventoryLoadoutV12-')as directory:
 p=Path(directory)/'tests.luau';p.write_text('\n'.join(parts),encoding='utf-8')
 result=subprocess.run([r'C:\Users\rataatrevida\AppData\Local\Temp\SlapDuels-AbilityV1-Luau\luau.exe',str(p)],capture_output=True,text=True)
 output=result.stdout+result.stderr;(r/'tests/InventoryLoadoutV12.results.txt').write_text(output,encoding='utf-8');print(output);sys.exit(result.returncode)
