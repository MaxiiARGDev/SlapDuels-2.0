from pathlib import Path
import subprocess,sys
root=Path(__file__).resolve().parents[2]
subprocess.run([sys.executable,str(root/'tests/tools/crate_batch_v24_spec.py')],check=True)
base=(root/'tests/CrateBatchV24.spec.luau').read_text(encoding='utf-8');base=base[:base.rfind('print(')]
(root/'tests/PremiumShopV1.spec.luau').write_text(base+(root/'tests/PremiumShopV1.extension.luau').read_text(encoding='utf-8'),encoding='utf-8')
