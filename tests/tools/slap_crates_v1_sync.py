"""Prepare guarded MCP payloads and integrity evidence, never launches Roblox."""
import hashlib
import json
from pathlib import Path
root=Path(__file__).resolve().parents[2]
out=root/'tests/SlapCratesV1.payloads';out.mkdir(exist_ok=True)
backup=root/'tests/assets/backups/SlapCratesV1'
def h(s):return hashlib.sha256(s.replace('\r\n','\n').rstrip().encode('utf-8')).hexdigest()
targets=['src/server/Bootstrap.server.luau','src/server/Services/PlayerService.luau','src/server/Services/PlayerDataService.luau',
 'src/server/Services/SlapService.luau','src/server/Shop/ShopRemotes.luau','src/client/Controllers/ShopController.luau','src/shared/Types.luau',
 'src/server/Services/CrateService.luau','src/client/Controllers/CrateController.luau','src/server/Shop/Providers/CrateProviders.luau']
for prefix in ['src/shared/SlapCrates','src/server/Services/Crates']:targets += [str(p.relative_to(root)).replace('\\','/') for p in (root/prefix).glob('*.luau')]
manifest=[]
for i,file in enumerate(targets):
 source=(root/file).read_text(encoding='utf-8');old=backup/file.replace('/','__')
 stem=file.removesuffix('.luau').replace('.server','')
 if stem.startswith('src/server/'):
  path='ServerScriptService/'+stem.removeprefix('src/server/')
 elif stem.startswith('src/shared/'):
  path='ReplicatedStorage/Shared/'+stem.removeprefix('src/shared/')
 else:path='StarterPlayer/StarterPlayerScripts/'+stem.removeprefix('src/client/')
 row={'Path':path.split('/'),'Class':'Script' if '.server.' in file else 'ModuleScript','File':file,
  'Source':source,'Before':h(old.read_text(encoding='utf-8')) if old.exists() else None,'After':h(source)}
 (out/f'{i}.json').write_text(json.dumps(row),encoding='utf-8')
 manifest.append({k:v for k,v in row.items() if k!='Source'})
(out/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
assets=[]
for name in ['CrateEffects','SlapVariationEffects','CrateRewardPreviews']:
 assets.append({'Path':['ReplicatedStorage',name],'Definition':json.loads((root/f'src/assets/{name}.project.json').read_text(encoding='utf-8'))['tree']})
for name in ['CratePanel','CrateSpinPanel','CrateActionsTemplate']:
 assets.append({'Path':['StarterGui','ShopHUD',name],'Definition':json.loads((root/f'src/ui/{name}.project.json').read_text(encoding='utf-8'))['tree']})
assets.append({'Path':['StarterGui','ShopHUD','MainFrame','Tabs','CratesTab'],'Definition':json.loads((root/'src/ui/CratesTab.project.json').read_text(encoding='utf-8'))['tree']})
(out/'assets.json').write_text(json.dumps(assets),encoding='utf-8')
original=json.loads((backup/'src-hashes.json').read_text(encoding='utf-8-sig'))
changed=[]
for item in original:
 p=Path(item['Path']);actual=hashlib.sha256(p.read_bytes()).hexdigest().upper()
 if actual!=item['Hash']:changed.append(str(p.relative_to(root)).replace('\\','/'))
allowed=set(targets)
assert all(f in allowed for f in changed),changed
evidence={'ChangedExistingSources':changed,'OtherOriginalSourceHashesPreserved':len(original)-len(changed),'SourceTargets':manifest}
(root/'tests/SlapCratesV1.integrity.json').write_text(json.dumps(evidence,indent=2),encoding='utf-8')
print(json.dumps({'Scripts':len(manifest),'ExistingChanges':changed,'UnchangedOtherSources':evidence['OtherOriginalSourceHashesPreserved']}))
