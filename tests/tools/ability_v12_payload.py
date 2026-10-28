"""Prepare guarded Edit-only source transport; never connects to Studio itself."""
import hashlib,json,pathlib
root=pathlib.Path(__file__).resolve().parents[2]
backup=root/'tests/assets/backups/AbilitySystemV12'
files=[r['File'] for r in json.loads((backup/'manifest.json').read_text()) if r['File'].endswith('.luau')]
files += ['src/server/Services/AbilityRegistry.luau','src/shared/AbilityCatalog.luau',
 'src/server/Abilities/AbilityManifest.luau','src/server/Abilities/AbilityCallbacks.luau',
 'src/server/Abilities/AbilityInputAdapter.luau','src/server/Abilities/AbilityAssetValidator.luau',
 'src/server/Abilities/Templates/AbilityTemplate.luau','src/client/Abilities/AbilityPresentationProfiles.luau']
def norm(path):return path.read_text(encoding='utf-8-sig').replace('\r\n','\n').rstrip()
sha=lambda s:hashlib.sha256(s.encode()).hexdigest()
rows=[]
for file in files:
    target=file
    for prefix,mapped in [('src/server/','ServerScriptService/'),('src/client/','StarterPlayer/StarterPlayerScripts/'),('src/shared/','ReplicatedStorage/Shared/')]:
        if target.startswith(prefix):target=mapped+target[len(prefix):];break
    target=target.removesuffix('.server.luau').removesuffix('.luau')
    source=norm(root/file)
    rows.append({'File':file,'Path':target,'Source':source,'SHA256':sha(source),
                 'BeforeSHA256':sha(norm(backup/file)) if (backup/file).exists() else None})
print(json.dumps(rows,ensure_ascii=True))
