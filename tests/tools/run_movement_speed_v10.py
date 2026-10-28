"""Run actual movement modules with disposable mocks; no Studio/players/cloud."""
import pathlib, subprocess, tempfile, json
root = pathlib.Path(__file__).resolve().parents[2]
files = {
    'Config':'src/shared/Config.luau',
    'Constants':'src/shared/Constants.luau',
    'Movement':'src/server/Services/Respawn/MovementSpeed.luau',
    'Speed':'src/server/Abilities/DevilSpeedAbility.luau',
    'Spawn':'src/server/Services/SpawnService.luau',
    'Round':'src/server/Services/RoundService.luau',
    'ArenaRespawn':'src/server/Services/Respawn/ArenaRespawn.luau',
    'PlayerService':'src/server/Services/PlayerService.luau',
    'ConfigBefore':'tests/assets/backups/MovementSpeedV10/Config.luau',
}
parts=['local Sources={}']
for key, path in files.items():
    parts.append('Sources['+json.dumps(key)+']=[====[\n'+(root/path).read_text(encoding='utf-8')+'\n]====]')
parts.append((root/'tests/MovementSpeedV10.spec.luau').read_text(encoding='utf-8'))
with tempfile.TemporaryDirectory(prefix='SlapDuels-Movement-') as directory:
    script=pathlib.Path(directory)/'isolated.luau'
    script.write_text('\n'.join(parts),encoding='utf-8')
    result=subprocess.run([r'C:\Users\rataatrevida\AppData\Local\Temp\SlapDuels-AbilityV1-Luau\luau.exe',str(script)],capture_output=True,text=True)
    output=result.stdout+result.stderr
    (root/'tests/MovementSpeedV10.results.txt').write_text(output,encoding='utf-8')
    print(output,end='')
    raise SystemExit(result.returncode)
