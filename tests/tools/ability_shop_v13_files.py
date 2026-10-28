"""Task-scoped backup, integrity verification and guarded source transport."""
import argparse,hashlib,json,pathlib,re,subprocess
root=pathlib.Path(__file__).resolve().parents[2]
backup=root/'tests/assets/backups/AbilityShopV13'
files=[f'src/server/Abilities/{name}Ability.luau' for name in ['Dash','AirJumps','DevilSpeed','Invisibility','StrongSlap']]+[
 'src/server/Shop/Providers/AbilityProvider.luau','src/server/Shop/ShopRemotes.luau',
 'src/server/Shop/ProfilePurchase.luau','src/client/Controllers/ShopController.luau']
digest=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
norm=lambda p:p.read_text(encoding='utf-8-sig').replace('\r\n','\n').rstrip()
sha=lambda s:hashlib.sha256(s.encode()).hexdigest()
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('mode',choices=['backup','verify','payload']);args=parser.parse_args()
if args.mode=='backup':
    if backup.exists():raise SystemExit('Backup already exists; refusing to overwrite')
    backup.mkdir(parents=True)
    manifest=[]
    for f in files:
        target=backup/f;target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes((root/f).read_bytes());manifest.append({'File':f,'SHA256':digest(root/f)})
    protected=[{'File':p.relative_to(root).as_posix(),'SHA256':digest(p)} for p in sorted((root/'src').rglob('*')) if p.is_file() and p.relative_to(root).as_posix() not in files]
    (backup/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
    (backup/'protected.json').write_text(json.dumps(protected,indent=2),encoding='utf-8')
    state={}
    for key,command in [('HEAD',['git','rev-parse','HEAD']),('Branch',['git','branch','--show-current']),('Status',['git','status','--porcelain=v1','-uall'])]:
        state[key]=subprocess.run(command,cwd=root,capture_output=True,text=True,check=True).stdout
    (backup/'git-state.json').write_text(json.dumps(state,indent=2),encoding='utf-8')
    print(json.dumps({'BackupFiles':len(manifest),'ProtectedFiles':len(protected),'Path':str(backup)}))
elif args.mode=='verify':
    baseline=json.loads((backup/'manifest.json').read_text())
    protected=json.loads((backup/'protected.json').read_text())
    bad_backup=[r['File'] for r in baseline if digest(backup/r['File'])!=r['SHA256']]
    bad_protected=[r['File'] for r in protected if not (root/r['File']).exists() or digest(root/r['File'])!=r['SHA256']]
    changed=[r['File'] for r in baseline if digest(root/r['File'])!=r['SHA256']]
    mechanics=[]
    def without_commercial_metadata(path):
        text=norm(path)
        text=re.sub(r'^\w+\.Shop=.*\n?','',text,flags=re.MULTILINE)
        return re.sub(r'DisplayName="[^"]*"','DisplayName="<catalog-name>"',text)
    for f in files[:5]:
        if without_commercial_metadata(root/f)!=without_commercial_metadata(backup/f):mechanics.append(f)
    text_files={root/f for f in files}
    text_files.update(p for p in (root/'tests').glob('AbilityShopV13*') if p.suffix in ('.luau','.md','.json'))
    text_files.update([root/'tests/tools/run_ability_unit_tests.py',pathlib.Path(__file__).resolve()])
    whitespace=[]
    for path in sorted(text_files):
        for number,line in enumerate(path.read_text(encoding='utf-8-sig').splitlines(),1):
            if line.rstrip(' \t')!=line:whitespace.append({'File':path.relative_to(root).as_posix(),'Line':number})
    out={'ProtectedFiles':len(protected),'ProtectedUnchanged':len(protected)-len(bad_protected),
         'ProtectedDifferences':bad_protected,'BackupFiles':len(baseline),'BackupHashMismatches':bad_backup,'ChangedFiles':changed,
         'AbilityMechanicsCompared':5,'AbilityMechanicsDifferences':mechanics,
         'WhitespaceFiles':len(text_files),'WhitespaceIssues':whitespace}
    (root/'tests/AbilityShopV13.file-integrity.json').write_text(json.dumps(out,indent=2),encoding='utf-8')
    print(json.dumps(out));raise SystemExit(1 if bad_backup or bad_protected or mechanics or whitespace else 0)
else:
    rows=[]
    for f in files:
        target=f
        for prefix,mapped in [('src/server/','ServerScriptService/'),('src/client/','StarterPlayer/StarterPlayerScripts/')]:
            if target.startswith(prefix):target=mapped+target[len(prefix):];break
        target=target.removesuffix('.luau')
        rows.append({'File':f,'Path':target,'Source':norm(root/f),'SHA256':sha(norm(root/f)),
                     'BeforeSHA256':sha(norm(backup/f))})
    print(json.dumps(rows,ensure_ascii=True))
