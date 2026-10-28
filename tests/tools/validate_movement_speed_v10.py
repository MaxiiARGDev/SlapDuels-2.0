"""Compile source, build both projects and validate this change's integrity."""
import pathlib, subprocess, hashlib, json
root=pathlib.Path(__file__).resolve().parents[2]
compiler=r'C:\Users\rataatrevida\AppData\Local\Temp\SlapDuels-AbilityV1-Luau\luau-compile.exe'
rojo=r'C:\Users\rataatrevida\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe'
def run(args,log):
    result=subprocess.run(args,cwd=root,capture_output=True,text=True,encoding='utf-8',errors='replace')
    (root/'tests'/log).write_text(result.stdout+result.stderr,encoding='utf-8')
    assert result.returncode==0,log+': '+result.stdout+result.stderr
    print('PASS '+log)
scripts=list((root/'src').rglob('*.luau'))
for path in scripts:
    result=subprocess.run([compiler,'--null',str(path)],capture_output=True,text=True)
    assert result.returncode==0,str(path)+result.stdout+result.stderr
(root/'tests/MovementSpeedV10.compile.txt').write_text(f'PASS {len(scripts)} source scripts compiled\n',encoding='utf-8')
print(f'PASS {len(scripts)} source scripts compiled')
for project,label in [('default.project.json','default'),('studio-safe.project.json','safe')]:
    run([rojo,'build',project,'-o',f'tests/MovementSpeedV10.{label}.rbxlx'],f'MovementSpeedV10.{label}.build.txt')
run(['git','-c','core.safecrlf=false','diff','--check'],'MovementSpeedV10.diff.txt')
mapping={'Config':'src/shared/Config.luau','SpawnService':'src/server/Services/SpawnService.luau','RoundService':'src/server/Services/RoundService.luau','DevilSpeedAbility':'src/server/Abilities/DevilSpeedAbility.luau','MovementSpeed':'src/server/Services/Respawn/MovementSpeed.luau'}
def digest(path):return hashlib.sha256(path.read_text(encoding='utf-8').rstrip().encode('utf-8')).hexdigest()
manifest=[]
for name,relative in mapping.items():
    before=root/'tests/assets/backups/MovementSpeedV10'/pathlib.Path(relative).name
    manifest.append({'Name':name,'Path':relative,'BeforeHash':digest(before) if before.exists()else None,'Hash':digest(root/relative)})
(root/'tests/MovementSpeedV10.source-hashes.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print('PASS source hash manifest')
