"""Prepare guarded Edit payloads; does not launch or control Studio."""
import hashlib,json
from pathlib import Path
root=Path(__file__).resolve().parents[2]
out=root/'tests/CrateVisibilityV22.payloads';out.mkdir(exist_ok=True)
def h(s):return hashlib.sha256(s.replace('\r\n','\n').rstrip().encode()).hexdigest()
for i,f in enumerate(['src/client/CrateOpening/CharacterVisibility.luau','src/client/Controllers/CrateStandCinematicController.luau']):
 source=(root/f).read_text(encoding='utf-8')
 before=(root/'tests/assets/backups/CrateVisibilityV22/CrateStandCinematicController.before.luau').read_text(encoding='utf-8')if i==1 else None
 path=f.removesuffix('.luau').replace('src/client/','StarterPlayer/StarterPlayerScripts/')
 (out/f'{i}.json').write_text(json.dumps(dict(Path=path.split('/'),Source=source,Before=h(before)if before else None,After=h(source))),encoding='utf-8')
