"""Build guarded Edit payloads and source-integrity evidence."""
import json,hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[2]
backup=root/'tests/assets/backups/EconomyBalanceV1'
out=root/'tests/EconomyBalanceV1.payloads';out.mkdir(exist_ok=True)
targets=['src/shared/Config.luau','src/shared/SlapCrates/CrateDefinitions.luau','src/server/Services/ScoreService.luau','src/server/Services/PlayerService.luau','src/client/Controllers/KillRewardController.luau']
def h(s):return hashlib.sha256(s.replace('\r\n','\n').rstrip().encode()).hexdigest()
manifest=[]
for i,f in enumerate(targets):
 s=(root/f).read_text(encoding='utf-8');old=(backup/f.replace('/','__')).read_text(encoding='utf-8')
 path=f.removesuffix('.luau').replace('src/shared/','ReplicatedStorage/Shared/').replace('src/server/','ServerScriptService/').replace('src/client/','StarterPlayer/StarterPlayerScripts/')
 row=dict(Path=path.split('/'),Source=s,Before=h(old),After=h(s),File=f)
 (out/f'{i}.json').write_text(json.dumps(row),encoding='utf-8');manifest.append({k:v for k,v in row.items() if k!='Source'})
original=json.loads((backup/'src-hashes.json').read_text(encoding='utf-8-sig'));changed=[]
for r in original:
 p=Path(r['Path'])
 if hashlib.sha256(p.read_bytes()).hexdigest().upper()!=r['Hash']:changed.append(p.relative_to(root).as_posix())
assert set(changed)==set(targets),changed
evidence=dict(ChangedSources=changed,UnchangedOriginalSourceFiles=len(original)-len(changed),Sources=manifest,OtherSystemsPreserved=True)
(root/'tests/EconomyBalanceV1.integrity.json').write_text(json.dumps(evidence,indent=2),encoding='utf-8')
print(json.dumps(evidence))
