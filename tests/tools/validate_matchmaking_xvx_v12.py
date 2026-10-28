"""Local validation only: no Studio session, gameplay, network or persistence access."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
LUAU = Path(r'C:\Users\rataatrevida\AppData\Local\Temp\SlapDuels-AbilityV1-Luau\luau.exe')
COMPILER = LUAU.with_name('luau-compile.exe')
ROJO = Path(r'C:\Users\rataatrevida\.aftman\tool-storage\rojo-rbx\rojo\7.7.0\rojo.exe')
PREFIX = ROOT / 'tests/MatchmakingXVXV12'
checks = {}

def run(name, args):
    result = subprocess.run([str(x) for x in args], cwd=ROOT, capture_output=True, text=True, encoding='utf-8', errors='replace')
    Path(str(PREFIX) + '.' + name + '.log').write_text(result.stdout + result.stderr, encoding='utf-8')
    checks[name] = {'ExitCode': result.returncode}
    print(name, result.returncode, flush=True)
    return result.returncode

sources = sorted((ROOT / 'src').rglob('*.luau'))
specs = [ROOT / ('tests/MatchmakingXVXV12' + suffix) for suffix in ('.spec.luau', '.prematch.luau', '.integration.luau')]
failures = []
for file in sources + specs:
    result = subprocess.run([str(COMPILER), '--null', str(file)], capture_output=True, text=True)
    if result.returncode:
        failures.append({'File': str(file.relative_to(ROOT)), 'Output': result.stdout + result.stderr})
checks['Compile'] = {'Sources': len(sources), 'Specs': len(specs), 'Failures': failures}
Path(str(PREFIX) + '.compile.log').write_text(json.dumps(checks['Compile'], indent=2), encoding='utf-8')
print('Compile', len(sources), 'sources;', len(failures), 'failures', flush=True)
run('matchmaking', [sys.executable, 'tests/tools/run_matchmaking_xvx_v10.py', '--base-spec', 'tests/MatchmakingXVXV12.spec.luau', '--extension', 'tests/MatchmakingXVXV12.prematch.luau', '--extension', 'tests/MatchmakingXVXV12.integration.luau', '--output', 'tests/MatchmakingXVXV12.results.txt'])
for spec in ('SlapVictimProtection', 'AbilityMultiplayerFixV1.regression', 'EconomyBalanceV1', 'EconomyBalanceV1.shop', 'PremiumShopV11'):
    run(spec, [sys.executable, 'tests/tools/run_ability_unit_tests.py', '--luau', LUAU, '--spec', 'tests/' + spec + '.spec.luau', '--output', 'tests/MatchmakingXVXV12.' + spec + '.txt'])
for project in ('default.project.json', 'studio-safe.project.json'):
    run(project, [ROJO, 'build', project, '-o', str(PREFIX) + '.' + project + '.rbxlx'])
run('diff', ['git', 'diff', '--check'])

before = json.loads((ROOT / 'tests/assets/backups/MatchmakingXVXV12/hashes.before.json').read_text(encoding='utf-8'))
changed = [name for name, digest in before.items() if hashlib.sha256((ROOT / name).read_bytes()).hexdigest() != digest]
expected = {'src/shared/Config.luau', 'src/shared/EndCinematicRanking.luau', 'src/server/Services/SpawnService.luau', 'src/server/Services/MatchmakingService.luau', 'src/client/Controllers/MatchmakingController.luau', 'src/client/EndCinematicPreview.client.luau'}
checks['Scope'] = {'Changed': changed, 'Unexpected': sorted(set(changed) - expected), 'Unchanged': len(before) - len(changed)}
Path(str(PREFIX) + '.checks.json').write_text(json.dumps(checks, indent=2), encoding='utf-8')
print('Changed production files:', changed, flush=True)
sys.exit(bool(failures or checks['Scope']['Unexpected'] or any(v.get('ExitCode', 0) for v in checks.values())))
