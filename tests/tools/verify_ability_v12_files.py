"""Verify the pre-refactor backup and protected files without touching source."""
import hashlib,json,pathlib
root=pathlib.Path(__file__).resolve().parents[2]
backup=root/'tests/assets/backups/AbilitySystemV12'
digest=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
protected=json.loads((root/'tests/AbilitySystemV12.protected-before.json').read_text())
baseline=json.loads((backup/'manifest.json').read_text())
changed=[r['File'] for r in protected if not (root/r['File']).is_file() or digest(root/r['File'])!=r['SHA256']]
bad_backup=[r['File'] for r in baseline if not (backup/r['File']).is_file() or digest(backup/r['File'])!=r['SHA256']]
modified=[r['File'] for r in baseline if digest(root/r['File'])!=r['SHA256']]
output={'ProtectedFiles':len(protected),'ProtectedUnchanged':len(protected)-len(changed),
 'ProtectedDifferences':changed,'BackupFiles':len(baseline),'BackupHashMismatches':bad_backup,
 'ChangedFromTaskBaseline':modified}
(root/'tests/AbilitySystemV12.file-integrity.json').write_text(json.dumps(output,indent=2),encoding='utf-8')
print(json.dumps(output))
raise SystemExit(1 if changed or bad_backup else 0)
