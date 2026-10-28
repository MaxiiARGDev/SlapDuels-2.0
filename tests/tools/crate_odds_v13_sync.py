import json,hashlib
from pathlib import Path
root=Path(__file__).resolve().parents[2];backup=root/'tests/assets/backups/CrateOddsV13'
out=root/'tests/CrateOddsV13.payloads';out.mkdir(exist_ok=True)
targets=['src/shared/SlapCrates/InitialOdds.luau','src/shared/SlapCrates/CrateDefinitions.luau','src/shared/SlapCrates/Catalog.luau','src/shared/SlapCrates/Odds.luau','src/shared/SlapCrates/OddsPresentation.luau','src/server/Services/CrateService.luau','src/client/Controllers/CrateController.luau']
def h(s):return hashlib.sha256(s.replace('\r\n','\n').rstrip().encode()).hexdigest()
manifest=[]
for i,f in enumerate(targets):
 source=(root/f).read_text(encoding='utf-8');old=backup/f.replace('/','__')
 path=f.removesuffix('.luau').replace('src/shared/','ReplicatedStorage/Shared/').replace('src/server/','ServerScriptService/').replace('src/client/','StarterPlayer/StarterPlayerScripts/')
 row=dict(File=f,Path=path.split('/'),Source=source,Before=h(old.read_text(encoding='utf-8')) if old.exists() else None,After=h(source))
 (out/f'{i}.json').write_text(json.dumps(row),encoding='utf-8');manifest.append({k:v for k,v in row.items() if k!='Source'})
original=json.loads((backup/'src-hashes.json').read_text(encoding='utf-8-sig'));changed=[]
for row in original:
 p=Path(row['Path'])
 if hashlib.sha256(p.read_bytes()).hexdigest().upper()!=row['Hash']:changed.append(p.relative_to(root).as_posix())
assert set(changed)<=set(targets),changed
f='src/client/Controllers/CrateController.luau';old=(backup/f.replace('/','__')).read_text(encoding='utf-8');new=(root/f).read_text(encoding='utf-8')
for method in ['_spin','_world']:
 def section(s):
  start=s.index('function Controller:'+method+'(');end=s.find('\nfunction ',start+1)
  return s[start:end if end>=0 else len(s)].strip()
 assert section(old)==section(new)
evidence=dict(Sources=manifest,ChangedOriginalSources=changed,UnchangedOriginalFiles=len(original)-len(changed),SpinAndWorldUnchanged=True)
(root/'tests/CrateOddsV13.integrity.json').write_text(json.dumps(evidence,indent=2),encoding='utf-8')
print(json.dumps(dict(Scripts=len(targets),Changed=changed,Unchanged=len(original)-len(changed))))
