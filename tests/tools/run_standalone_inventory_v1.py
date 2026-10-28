"""Existing social/equip regressions plus the authenticated personal inventory API."""
from pathlib import Path
import json, subprocess, tempfile, sys
root=Path(__file__).resolve().parents[2]
files={p.stem:p for p in (root/'src/shared/SlapCrates').glob('*.luau')}
files.update({p.stem:p for p in (root/'src/server/Services/Trading').glob('*.luau')})
files.update({name:root/path for name,path in {'SocialConfig':'src/shared/SocialConfig.luau','Targeting':'src/client/Social/Targeting.luau','ViewportPool':'src/client/Social/ViewportPool.luau','SocialService':'src/server/Services/SocialService.luau','SocialController':'src/client/Controllers/SocialController.luau'}.items()})
parts=['local Sources={}']+[f'Sources[{json.dumps(k)}]=[====[{p.read_text(encoding="utf-8")}]====]'for k,p in files.items()]
parts += [(root/'tests'/name).read_text(encoding='utf-8')for name in ['PlayerInventoryTradingV10.spec.luau','PlayerInventoryV11.spec.luau','InventoryLoadoutV12.spec.luau','StandaloneInventoryV1.spec.luau']]
path=root/'tests/StandaloneInventoryV1.bundle.luau';path.write_text('\n'.join(parts),encoding='utf-8')
result=subprocess.run([r'C:\Users\rataatrevida\AppData\Local\Temp\SlapDuels-AbilityV1-Luau\luau.exe',str(path)],capture_output=True,text=True)
output=result.stdout+result.stderr;(root/'tests/StandaloneInventoryV1.results.txt').write_text(output,encoding='utf-8');print(output);sys.exit(result.returncode)
