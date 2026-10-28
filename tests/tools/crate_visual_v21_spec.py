from pathlib import Path
import subprocess,sys
root=Path(__file__).resolve().parents[2]
subprocess.run([sys.executable,str(root/'tests/tools/crate_odds_v13_spec.py')],check=True)
s=(root/'tests/CrateOddsV13.spec.luau').read_text(encoding='utf-8');s=s[:s.rfind('print(')]
(root/'tests/CrateVisualV21.spec.luau').write_text(s+(root/'tests/CrateVisualV21.extension.luau').read_text(encoding='utf-8'),encoding='utf-8')
