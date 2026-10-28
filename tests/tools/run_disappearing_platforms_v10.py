"""Deterministic Luau mocks only. Never starts Studio or a gameplay session."""
import pathlib, subprocess, tempfile, json
root=pathlib.Path(__file__).resolve().parents[2]
files={'Config':'src/shared/DisappearingPlatformsConfig.luau',
       'Policy':'src/server/Services/Platforms/PlatformPolicy.luau',
       'Service':'src/server/Services/DisappearingPlatformsService.luau',
       'Instances':'src/server/Services/MatchInstanceService.luau',
       'Elimination':'src/server/Services/EliminationService.luau',
       'Transit':'src/server/Services/Respawn/CompetitiveTransit.luau',
       'ArenaPolicy':'src/shared/ArenaRespawnPolicy.luau'}
parts=['local Sources={}']
for name,path in files.items():
    parts.append('Sources['+json.dumps(name)+']=[====[\n'+(root/path).read_text(encoding='utf-8')+'\n]====]')
parts.append((root/'tests/DisappearingPlatformsV10.spec.luau').read_text(encoding='utf-8'))
with tempfile.TemporaryDirectory(prefix='SlapDuels-Platforms-') as directory:
    file=pathlib.Path(directory)/'isolated.luau';file.write_text('\n'.join(parts),encoding='utf-8')
    result=subprocess.run([r'C:\Users\rataatrevida\AppData\Local\Temp\SlapDuels-AbilityV1-Luau\luau.exe',str(file)],capture_output=True,text=True,timeout=30)
    output=result.stdout+result.stderr
    (root/'tests/DisappearingPlatformsV10.results.txt').write_text(output,encoding='utf-8')
    print(output,end='');raise SystemExit(result.returncode)
