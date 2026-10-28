"""Build and compile without Studio/gameplay; preserve server authority."""
import pathlib,subprocess,hashlib,json,sys
r=pathlib.Path(__file__).resolve().parents[2];prefix=sys.argv[1] if len(sys.argv)>1 else 'SocialProfilePromptFixV1'
def run(args,label):
    result=subprocess.run(args,cwd=r,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=60)
    (r/'tests'/f'{prefix}.{label}.txt').write_text(result.stdout+result.stderr,encoding='utf-8')
    assert result.returncode==0,result.stdout+result.stderr;print('PASS '+label)
files=list((r/'src').rglob('*.luau'))
for p in files:
    result=subprocess.run([r'C:\Users\rataatrevida\AppData\Local\Temp\SlapDuels-AbilityV1-Luau\luau-compile.exe','--null',str(p)],capture_output=True,text=True,timeout=15)
    assert result.returncode==0,str(p)+result.stdout+result.stderr
(r/'tests'/f'{prefix}.compile.txt').write_text(f'PASS {len(files)} scripts compiled\n',encoding='utf-8');print(f'PASS {len(files)} scripts compiled')
for project,label in [('default.project.json','default'),('studio-safe.project.json','safe')]:
    run([r'C:\Users\rataatrevida\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe','build',project,'-o',f'tests/{prefix}.{label}.rbxlx'],label+'.build')
run(['git','-c','core.safecrlf=false','diff','--check'],'diff')
def sha(p):return hashlib.sha256(p.read_text(encoding='utf-8').rstrip().encode()).hexdigest()
manifest=[]
for name,p in {'SocialController':'src/client/Controllers/SocialController.luau','Targeting':'src/client/Social/Targeting.luau'}.items():
    if not (r/'tests/assets/backups'/prefix/pathlib.Path(p).name).exists():continue
    manifest.append({'Name':name,'Path':p,'BeforeHash':sha(r/'tests/assets/backups'/prefix/pathlib.Path(p).name),'Hash':sha(r/p)})
(r/'tests'/f'{prefix}.source-hashes.json').write_text(json.dumps(manifest,indent=2),encoding='utf-8')
for path,expected in {'src/server/Services/SocialService.luau':'d70f950434439e42c97cd018d325ede781a7d5e1d35b09b899f668cb6591672b','src/shared/SocialConfig.luau':'9f3816bf3671334c35cd524c840b591670ec14bc351101d7149f51677d148fd1'}.items():
    assert sha(r/path)==expected,'Protected source changed: '+path
print('PASS server SocialService and SocialConfig unchanged')
