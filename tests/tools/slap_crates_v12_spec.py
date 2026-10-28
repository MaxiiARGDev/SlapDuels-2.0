"""Compose new coverage with the existing real-module crate fixture."""
from pathlib import Path
root=Path(__file__).resolve().parents[2]
base=(root/'tests/SlapCratesV1.spec.luau').read_text(encoding='utf-8')
base=base[:base.rfind('print("PASS SlapCratesV1:')]
extra=(root/'tests/SlapCratesV12.extension.luau').read_text(encoding='utf-8')
(root/'tests/SlapCratesV12.spec.luau').write_text(base+'\n'+extra,encoding='utf-8')
