"""Prepare guarded Edit payloads; preserve unrelated source and existing geometry."""
import hashlib,json
from pathlib import Path
root=Path(__file__).resolve().parents[2]
out=root/'tests/SlapCratesV12.payloads';out.mkdir(exist_ok=True)
backup=root/'tests/assets/backups/SlapCratesV12'
def h(s):return hashlib.sha256(s.replace('\r\n','\n').rstrip().encode()).hexdigest()
targets=['src/shared/SlapCrates/CrateDefinitions.luau','src/shared/SlapCrates/Catalog.luau','src/shared/SlapCrates/CrateShopView.luau','src/server/Services/CrateService.luau','src/server/Shop/ShopRemotes.luau','src/client/Controllers/ShopController.luau','src/client/Controllers/CrateController.luau']
rows=[]
for i,f in enumerate(targets):
 s=(root/f).read_text(encoding='utf-8');old=backup/f.replace('/','__')
 stem=f.removesuffix('.luau')
 path=stem.replace('src/shared/','ReplicatedStorage/Shared/').replace('src/server/','ServerScriptService/').replace('src/client/','StarterPlayer/StarterPlayerScripts/')
 row=dict(Path=path.split('/'),Source=s,Before=h(old.read_text(encoding='utf-8')) if old.exists() else None,After=h(s))
 (out/f'{i}.json').write_text(json.dumps(row),encoding='utf-8');rows.append({k:v for k,v in row.items() if k!='Source'})
allowed=set(targets+['src/ui/CratePanel.project.json','src/ui/CrateActionsTemplate.project.json'])
original=json.loads((backup/'src-hashes.json').read_text(encoding='utf-8-sig'));changed=[]
for item in original:
 p=Path(item['Path'])
 if hashlib.sha256(p.read_bytes()).hexdigest().upper()!=item['Hash']:changed.append(p.relative_to(root).as_posix())
assert set(changed)<=allowed,changed
f='src/client/Controllers/CrateController.luau'
old=(backup/f.replace('/','__')).read_text(encoding='utf-8');new=(root/f).read_text(encoding='utf-8')
for name in ['_spin','_world']:
 def section(s):
  start=s.index('function Controller:'+name+'(');end=s.find('\nfunction ',start+1)
  return s[start:end if end>=0 else len(s)].strip()
 assert section(old)==section(new),name+' changed'
evidence=dict(Scripts=rows,ChangedExistingSources=changed,OtherOriginalSourceHashesPreserved=len(original)-len(changed),SpinAndWorldUnchanged=True)
(root/'tests/SlapCratesV12.integrity.json').write_text(json.dumps(evidence,indent=2),encoding='utf-8')
print(json.dumps(evidence))
