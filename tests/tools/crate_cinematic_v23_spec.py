from pathlib import Path
root=Path(__file__).resolve().parents[2]
base=(root/'tests/CrateVisibilityV22.spec.luau').read_text(encoding='utf-8')
base=base[:base.rfind('print(')]
(root/'tests/CrateCinematicV23.spec.luau').write_text(base+(root/'tests/CrateCinematicV23.extension.luau').read_text(encoding='utf-8'),encoding='utf-8')
