"""Static validation/builds and preservation checks; never runs gameplay."""
import pathlib, subprocess, json, hashlib
root=pathlib.Path(__file__).resolve().parents[2]
prefix='DisappearingPlatformsV10'
compiler=r'C:\Users\rataatrevida\AppData\Local\Temp\SlapDuels-AbilityV1-Luau\luau-compile.exe'
rojo=r'C:\Users\rataatrevida\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe'
def run(args,label):
    result=subprocess.run(args,cwd=root,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=60)
    (root/'tests'/f'{prefix}.{label}.txt').write_text(result.stdout+result.stderr,encoding='utf-8')
    assert result.returncode==0,label+': '+result.stdout+result.stderr
    print('PASS '+label)
scripts=list((root/'src').rglob('*.luau'))
for file in scripts:
    result=subprocess.run([compiler,'--null',str(file)],capture_output=True,text=True,timeout=15)
    assert result.returncode==0,str(file)+result.stdout+result.stderr
(root/'tests'/f'{prefix}.compile.txt').write_text(f'PASS {len(scripts)} source scripts compiled\n',encoding='utf-8')
print(f'PASS {len(scripts)} scripts compiled')
for project,name in [('default.project.json','default'),('studio-safe.project.json','safe')]:
    run([rojo,'build',project,'-o',f'tests/{prefix}.{name}.rbxlx'],name+'.build')
run(['git','-c','core.safecrlf=false','diff','--check'],'diff')
before=json.loads((root/'tests'/f'{prefix}.before-files.json').read_text(encoding='utf-8'))
changed=[]
for path,digest in before.items():
    assert (root/path).is_file(),'Deleted source/asset '+path
    if hashlib.sha256((root/path).read_bytes()).hexdigest()!=digest:changed.append(path)
assert set(changed)=={'src/server/Bootstrap.server.luau','src/server/Services/MatchInstanceService.luau'},changed
protected={'ComparedFiles':len(before),'Changed':changed,'OthersIdentical':True}
(root/'tests'/f'{prefix}.protected.json').write_text(json.dumps(protected,indent=2),encoding='utf-8')
print(f'PASS {len(before)-len(changed)} previous source/asset files unchanged')
paths={'Bootstrap':'src/server/Bootstrap.server.luau','MatchInstanceService':'src/server/Services/MatchInstanceService.luau',
       'DisappearingPlatformsService':'src/server/Services/DisappearingPlatformsService.luau',
       'PlatformPolicy':'src/server/Services/Platforms/PlatformPolicy.luau','DisappearingPlatformsConfig':'src/shared/DisappearingPlatformsConfig.luau'}
manifest=[]
def sha(file):return hashlib.sha256(file.read_text(encoding='utf-8').rstrip().encode('utf-8')).hexdigest()
for name,path in paths.items():
    backup=root/'tests/assets/backups'/prefix/pathlib.Path(path).name
    manifest.append({'Name':name,'Path':path,'Hash':sha(root/path),'BeforeHash':sha(backup)if backup.exists()else None})
(root/'tests'/f'{prefix}.source-hashes.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
print('PASS source manifests')
