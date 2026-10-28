"""Prepare guarded source payloads and verify protected systems. No Studio execution."""
import json,hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[2];backup=root/'tests/assets/backups/SlapCratesV2'
out=root/'tests/SlapCratesV2.payloads';out.mkdir(exist_ok=True)
targets=['src/shared/SlapCrates/OpeningConfig.luau','src/shared/SlapCrates/OpeningTimeline.luau',
 'src/shared/SlapCrates/CrateShopView.luau','src/server/Services/Crates/StandOpeningLedger.luau',
 'src/server/Services/Crates/StandOpeningService.luau','src/server/Services/CrateService.luau',
 'src/client/CrateOpening/CameraLease.luau','src/client/Controllers/CrateStandCinematicController.luau',
 'src/client/Controllers/CrateController.luau','src/client/Controllers/ShopController.luau']
original=json.loads((backup/'src-hashes.json').read_text(encoding='utf-8-sig'))
# Recover the one presentation-error table's before-image, verifying against the pre-edit manifest.
f='src/shared/SlapCrates/CrateShopView.luau';old=backup/f.replace('/','__')
if not old.exists():
 s=(root/f).read_text(encoding='utf-8');start=s.index(' TransactionInProgress=');end=s.index('\nlocal function finite',start)
 prior=s[:start]+' TransactionInProgress="Hay una operación en curso.",JournalCapacityReached="Inventario de operaciones completo.",ProfileChanged="Tu perfil cambió; volvé a consultar."}\n'+s[end+1:]
 expected=next(r['Hash'] for r in original if Path(r['Path'])==root/f)
 assert hashlib.sha256(prior.encode()).hexdigest().upper()==expected,'Before-image mismatch'
 old.write_text(prior,encoding='utf-8')
def h(s):return hashlib.sha256(s.replace('\r\n','\n').rstrip().encode()).hexdigest()
manifest=[]
for i,f in enumerate(targets):
 source=(root/f).read_text(encoding='utf-8');prior=backup/f.replace('/','__')
 path=f.removesuffix('.luau').replace('src/shared/','ReplicatedStorage/Shared/').replace('src/server/','ServerScriptService/').replace('src/client/','StarterPlayer/StarterPlayerScripts/')
 row=dict(File=f,Path=path.split('/'),Source=source,Before=h(prior.read_text(encoding='utf-8')) if prior.exists() else None,After=h(source))
 (out/f'{i}.json').write_text(json.dumps(row),encoding='utf-8');manifest.append({k:v for k,v in row.items() if k!='Source'})
changed=[]
for r in original:
 p=Path(r['Path'])
 if hashlib.sha256(p.read_bytes()).hexdigest().upper()!=r['Hash']:changed.append(p.relative_to(root).as_posix())
assert set(changed)<=set(targets),changed
f='src/client/Controllers/CrateController.luau'
before=(backup/f.replace('/','__')).read_text(encoding='utf-8');after=(root/f).read_text(encoding='utf-8')
for method in ['_spin','_world']:
 def section(s):
  start=s.index('function Controller:'+method+'(');end=s.find('\nfunction ',start+1)
  return s[start:end if end>=0 else len(s)].strip()
 assert section(before)==section(after),method+' modified'
data=dict(Sources=manifest,ChangedOriginalSources=changed,UnchangedOriginalSourceFiles=len(original)-len(changed),SpinAndWorldUnchanged=True)
(root/'tests/SlapCratesV2.integrity.json').write_text(json.dumps(data,indent=2),encoding='utf-8')
print(json.dumps(dict(Scripts=len(targets),Changed=changed,Unchanged=len(original)-len(changed))))
