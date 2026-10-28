import csv,io,json,subprocess,sys
from pathlib import Path
root=Path(__file__).resolve().parents[2]
subprocess.run([sys.executable,str(root/'tests/tools/slap_crates_v2_spec.py')],check=True)
base=(root/'tests/SlapCratesV2.spec.luau').read_text(encoding='utf-8');base=base[:base.rfind('print(')]
rows=list(csv.reader(io.StringIO((root/'tests/CrateOddsV13.matrix.csv').read_text(encoding='utf-8'))))
fixture='local INPUT_ROWS={\n'+'\n'.join('{Id="'+r[0]+'",Values={'+','.join(r[1:])+'}},'for r in rows[1:])+'\n}\n'
(root/'tests/CrateOddsV13.spec.luau').write_text(base+fixture+(root/'tests/CrateOddsV13.extension.luau').read_text(encoding='utf-8'),encoding='utf-8')
