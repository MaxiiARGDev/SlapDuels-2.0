import pathlib,subprocess,tempfile
files={'Config':'src/shared/PartyMatchConfig.luau','Model':'src/server/Services/Gameplay/PartyQueueModel.luau','Store':'src/server/Services/Gameplay/PartyQueueStore.luau','Service':'src/server/Services/PartyMatchService.luau'}
files.update({'SocialConfig':'src/shared/SocialPlayConfig.luau','SocialEngine':'src/server/Services/Gameplay/SocialPlayEngine.luau'})
out='local Sources={}\n'
for key,path in files.items():
 s=pathlib.Path(path).read_text(encoding='utf-8');assert ']====]' not in s
 out+=f'Sources["{key}"]=[====[{s}]====]\n'
out+=pathlib.Path('tests/PartyMatchmakingV1.spec.luau').read_text(encoding='utf-8')
with tempfile.TemporaryDirectory(prefix='PartyMatchTests') as d:
 p=pathlib.Path(d)/'suite.luau';p.write_text(out,encoding='utf-8')
 r=subprocess.run([r'C:\Users\rataatrevida\AppData\Local\Temp\SlapDuels-AbilityV1-Luau\luau.exe',str(p)],capture_output=True,text=True)
 pathlib.Path('tests/PartyMatchmakingV1.results.txt').write_text(r.stdout+r.stderr,encoding='utf-8');print(r.stdout+r.stderr);raise SystemExit(r.returncode)
