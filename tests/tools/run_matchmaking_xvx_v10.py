"""Actual modules under isolated table-based Roblox fixtures; never starts Studio."""
import pathlib,subprocess,tempfile,json,argparse
parser=argparse.ArgumentParser();parser.add_argument('--extension',action='append',default=[]);parser.add_argument('--base-spec',default='tests/MatchmakingXVXV10.spec.luau');parser.add_argument('--output');args=parser.parse_args()
root=pathlib.Path(__file__).resolve().parents[2]
files={'Resolver':'src/server/Services/TeamSpawnResolver.luau','Round':'src/server/Services/RoundService.luau','Spawn':'src/server/Services/SpawnService.luau','Arena':'src/server/Services/MatchInstanceService.luau','Config':'src/shared/Config.luau','Constants':'src/shared/Constants.luau','Ranking':'src/shared/EndCinematicRanking.luau','CinematicConfig':'src/shared/EndCinematicConfig.luau','Clock':'src/server/Services/Gameplay/RoundClock.luau','Score':'src/server/Services/ScoreService.luau','Policy':'src/shared/ArenaRespawnPolicy.luau','Matchmaking':'src/server/Services/MatchmakingService.luau'}
files['Client']='src/client/Controllers/MatchController.luau'
files['MovementSpeed']='src/server/Services/Respawn/MovementSpeed.luau'
files['QueueClient']='src/client/Controllers/MatchmakingController.luau'
files['SocialPlayConfig']='src/shared/SocialPlayConfig.luau'
files['SocialPlayEngine']='src/server/Services/Gameplay/SocialPlayEngine.luau'
files['SocialPlayService']='src/server/Services/SocialPlayService.luau'
pieces=['local Sources={}']
for name,path in files.items():pieces.append('Sources['+json.dumps(name)+']=[====[\n'+(root/path).read_text(encoding='utf-8')+'\n]====]')
pieces.append((root/args.base_spec).read_text(encoding='utf-8'))
for extension in args.extension:pieces.append((root/extension).read_text(encoding='utf-8'))
with tempfile.TemporaryDirectory(prefix='SlapDuels-XvX-unit-')as directory:
 p=pathlib.Path(directory)/'isolated.luau';p.write_text('\n'.join(pieces),encoding='utf-8')
 result=subprocess.run([r'C:\Users\rataatrevida\AppData\Local\Temp\SlapDuels-AbilityV1-Luau\luau.exe',str(p)],capture_output=True,text=True)
 (root/(args.output or ('tests/MatchmakingXVXV101.results.txt'if args.extension else'tests/MatchmakingXVXV10.results.txt'))).write_text(result.stdout+result.stderr,encoding='utf-8')
 print(result.stdout+result.stderr);raise SystemExit(result.returncode)
