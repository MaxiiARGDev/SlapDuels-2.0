from pathlib import Path
import subprocess,sys
root=Path(__file__).resolve().parents[2]
subprocess.run([sys.executable,str(root/'tests/tools/crate_visual_v21_spec.py')],check=True)
base=(root/'tests/CrateVisualV21.spec.luau').read_text(encoding='utf-8')
base=base[:base.rfind('print(')]
(root/'tests/CrateBatchV24.spec.luau').write_text(base+(root/'tests/CrateBatchV24.extension.luau').read_text(encoding='utf-8'),encoding='utf-8')
