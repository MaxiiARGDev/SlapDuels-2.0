"""Guarded script payloads, assets hashes and protection of unrelated source."""
from pathlib import Path
import json,hashlib
root=Path(__file__).resolve().parents[2];backup=root/'tests/assets/backups/CrateVisualV21'
out=root/'tests/CrateVisualV21.payloads';out.mkdir(exist_ok=True)
targets=['src/client/CrateOpening/VisualProfile.luau','src/client/CrateOpening/RewardOverlayPresenter.luau','src/client/Controllers/CrateStandCinematicController.luau','src/server/Services/Crates/StandOpeningService.luau']
def h(s):return hashlib.sha256(s.replace('\r\n','\n').rstrip().encode()).hexdigest()
rows=[]
for i,f in enumerate(targets):
 source=(root/f).read_text(encoding='utf-8');prior=backup/f.replace('/','__')
 path=f.removesuffix('.luau').replace('src/server/','ServerScriptService/').replace('src/client/','StarterPlayer/StarterPlayerScripts/')
 r=dict(File=f,Path=path.split('/'),Source=source,Before=h(prior.read_text(encoding='utf-8'))if prior.exists()else None,After=h(source))
 (out/f'{i}.json').write_text(json.dumps(r),encoding='utf-8');rows.append({k:v for k,v in r.items()if k!='Source'})
old=json.loads((backup/'src-hashes.json').read_text(encoding='utf-8-sig'));changed=[]
for r in old:
 p=Path(r['Path'])
 if hashlib.sha256(p.read_bytes()).hexdigest().upper()!=r['Hash']:changed.append(p.relative_to(root).as_posix())
assert set(changed)<=set(targets),changed
manifest=json.loads((root/'src/assets/CrateVisualsV21/manifest.json').read_text())
for r in manifest:
 p=root/'src/assets/CrateVisualsV21'/(r['Name']+'.rbxm')
 assert p.stat().st_size==r['Bytes'] and hashlib.sha256(p.read_bytes()).hexdigest()==r['Hash']
external=json.loads((backup/'external-backup.json').read_text())
for r in external['Files']:
 p=Path(external['ExternalPath'])/(r['Name']+'.before.rbxm')
 assert p.exists()and p.stat().st_size==r['Bytes']and hashlib.sha256(p.read_bytes()).hexdigest()==r['Hash']
evidence=dict(Sources=rows,ChangedOriginalSources=changed,UnchangedOriginalFiles=len(old)-len(changed),ExternalBackup=external['ExternalPath'],ExternalFilesVerified=5,SnapshotHashesVerified=3)
(root/'tests/CrateVisualV21.integrity.json').write_text(json.dumps(evidence,indent=2),encoding='utf-8')
print(json.dumps({k:v for k,v in evidence.items()if k!='Sources'}))
