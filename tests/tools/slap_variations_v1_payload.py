"""Guarded source payloads and scope verification; no Studio execution."""
import hashlib
import json
from pathlib import Path
root=Path(__file__).resolve().parents[2]
backup=root/'tests/assets/backups/SlapVariationsV1'
out=root/'tests/SlapVariationsV1.payloads';out.mkdir(exist_ok=True)
def h(s):return hashlib.sha256(s.replace('\r\n','\n').rstrip().encode('utf-8')).hexdigest()
files={'src/shared/SlapCrates/Appearance.luau':['ReplicatedStorage','Shared','SlapCrates','Appearance'],
 'src/shared/SlapCrates/VariationDefinitions.luau':['ReplicatedStorage','Shared','SlapCrates','VariationDefinitions'],
 'src/server/Services/CrateService.luau':['ServerScriptService','Services','CrateService'],
 'src/client/Controllers/CrateController.luau':['StarterPlayer','StarterPlayerScripts','Controllers','CrateController']}
manifest=[]
for i,(file,path)in enumerate(files.items()):
 source=(root/file).read_text(encoding='utf-8');old=backup/file.replace('/','__')
 row={'Path':path,'File':file,'Source':source,'Before':h(old.read_text(encoding='utf-8'))if old.exists()else None,'After':h(source)}
 (out/f'{i}.json').write_text(json.dumps(row),encoding='utf-8');manifest.append({k:v for k,v in row.items()if k!='Source'})
(out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
hashes=json.loads((backup/'src-hashes.json').read_text(encoding='utf-8-sig'))
changed=[]
for item in hashes:
 p=Path(item['Path'])
 if hashlib.sha256(p.read_bytes()).hexdigest().upper()!=item['Hash']:changed.append(str(p.relative_to(root)).replace('\\','/'))
allowed=set(files)|{'src/assets/SlapVariationEffects.project.json'}
assert set(changed)<=allowed,changed
for project in ['studio-safe.project.json']:
 assert (root/project).read_bytes()==(backup/project).read_bytes(),project
evidence={'ChangedExistingSrc':changed,'UnchangedOriginalSrc':len(hashes)-len(changed),'Sources':manifest,'SafeProjectUnchanged':True}
(root/'tests/SlapVariationsV1.integrity.json').write_text(json.dumps(evidence,indent=2),encoding='utf-8')
print(json.dumps({'Sources':len(manifest),'ExistingSrcChanges':changed,'UnchangedOriginalSrc':evidence['UnchangedOriginalSrc']}))
