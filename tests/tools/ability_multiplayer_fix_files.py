"""Backup/integrity/source transport for the Edit-only Dash diagnostic task."""
import argparse,hashlib,json,pathlib
root=pathlib.Path(__file__).resolve().parents[2]
backup=root/'tests/assets/backups/AbilityMultiplayerFixV1'
sources=['src/server/Services/AbilityService.luau','src/client/Controllers/AbilityController.luau',
 'src/server/Abilities/DashAbility.luau','src/server/Abilities/MovementGuard.luau']
added=['src/shared/AbilityDiagnostics.luau']
files=sources+['studio-safe.project.json']
digest=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
norm=lambda p:p.read_text(encoding='utf-8-sig').replace('\r\n','\n').rstrip()
sha=lambda s:hashlib.sha256(s.encode()).hexdigest()
parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('mode',choices=['backup','verify','payload']);args=parser.parse_args()
if args.mode=='backup':
 if backup.exists():raise SystemExit('Refusing to overwrite backup')
 backup.mkdir(parents=True)
 records=[]
 for f in files:
  p=backup/f;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes((root/f).read_bytes());records.append({'File':f,'SHA256':digest(p)})
 protected=[{'File':p.relative_to(root).as_posix(),'SHA256':digest(p)} for p in sorted((root/'src').rglob('*')) if p.is_file() and p.relative_to(root).as_posix() not in sources]
 (backup/'manifest.json').write_text(json.dumps(records,indent=2),encoding='utf-8')
 (backup/'protected.json').write_text(json.dumps(protected,indent=2),encoding='utf-8')
 print(json.dumps({'BackupFiles':len(records),'ProtectedFiles':len(protected),'Path':str(backup)}))
elif args.mode=='verify':
 records=json.loads((backup/'manifest.json').read_text());protected=json.loads((backup/'protected.json').read_text())
 bad=[r['File'] for r in records if digest(backup/r['File'])!=r['SHA256']]
 changed=[r['File'] for r in protected if not (root/r['File']).exists() or digest(root/r['File'])!=r['SHA256']]
 text_files=[root/f for f in sources+added]+[p for p in (root/'tests').glob('AbilityMultiplayerFixV1*') if p.suffix in ('.luau','.md','.json')]
 whitespace=[{'File':p.relative_to(root).as_posix(),'Line':n} for p in text_files for n,line in enumerate(p.read_text(encoding='utf-8').splitlines(),1) if line.rstrip(' \t')!=line]
 out={'ProtectedFiles':len(protected),'ProtectedDifferences':changed,'BackupFiles':len(records),'BackupHashMismatches':bad,'WhitespaceIssues':whitespace}
 (root/'tests/AbilityMultiplayerFixV1.file-integrity.json').write_text(json.dumps(out,indent=2),encoding='utf-8')
 print(json.dumps(out));raise SystemExit(1 if bad or changed or whitespace else 0)
else:
 rows=[]
 for f in sources+added:
  path=f
  for prefix,target in [('src/server/','ServerScriptService/'),('src/client/','StarterPlayer/StarterPlayerScripts/'),('src/shared/','ReplicatedStorage/Shared/')]:
   if path.startswith(prefix):path=target+path[len(prefix):];break
  rows.append({'File':f,'Path':path.removesuffix('.luau'),'Source':norm(root/f),'SHA256':sha(norm(root/f)),
   'BeforeSHA256':sha(norm(backup/f)) if (backup/f).exists() else None})
 print(json.dumps(rows,ensure_ascii=True))
