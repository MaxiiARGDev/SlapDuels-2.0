from pathlib import Path
import subprocess,sys
root=Path(__file__).resolve().parents[2]
subprocess.run([sys.executable,str(root/'tests/tools/economy_balance_v1_specs.py')],check=True)
base=(root/'tests/SlapCratesV13.spec.luau').read_text(encoding='utf-8');base=base[:base.rfind('print(')]
(root/'tests/SlapCratesV2.spec.luau').write_text(base+(root/'tests/SlapCratesV2.extension.luau').read_text(encoding='utf-8'),encoding='utf-8')
