"""Local Luau mocks only; no Studio, live players or cloud."""
import pathlib,subprocess,tempfile,json
r=pathlib.Path(__file__).resolve().parents[2]
files={'Targeting':'src/client/Social/Targeting.luau','Controller':'src/client/Controllers/SocialController.luau'}
parts=['local Sources={}']
for k,p in files.items():parts.append('Sources['+json.dumps(k)+']=[====[\n'+(r/p).read_text(encoding='utf-8')+'\n]====]')
parts.append((r/'tests/SocialProfilePromptFixV1.spec.luau').read_text(encoding='utf-8'))
with tempfile.TemporaryDirectory(prefix='SlapDuels-SocialPrompt-')as directory:
    p=pathlib.Path(directory)/'isolated.luau';p.write_text('\n'.join(parts),encoding='utf-8')
    result=subprocess.run([r'C:\Users\rataatrevida\AppData\Local\Temp\SlapDuels-AbilityV1-Luau\luau.exe',str(p)],capture_output=True,text=True,timeout=30)
    output=result.stdout+result.stderr;(r/'tests/SocialProfilePromptFixV1.results.txt').write_text(output,encoding='utf-8');print(output,end='');raise SystemExit(result.returncode)
