"""Integrity and guarded Edit deployment payload; never starts Studio or gameplay."""
import hashlib
import json
import pathlib
import sys

root = pathlib.Path(__file__).resolve().parents[2]
backup = root / "tests/assets/backups/CombatSystemV132"
targets = {
    "src/server/Services/SlapService.luau": "ServerScriptService.Services.SlapService",
    "src/client/Controllers/SlapController.luau": "StarterPlayer.StarterPlayerScripts.Controllers.SlapController",
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest().upper()


def normalized(path):
    return path.read_text(encoding="utf-8").replace("\r\n", "\n").rstrip()


def text_hash(text):
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


if sys.argv[1] == "payload":
    print(json.dumps([
        {"Path": target, "Source": normalized(root / file),
         "BeforeSHA256": text_hash(normalized(backup / file)),
         "SHA256": text_hash(normalized(root / file))}
        for file, target in targets.items()
    ]))
elif sys.argv[1] == "verify":
    protected = json.loads((backup / "protected.json").read_text(encoding="utf-8-sig"))
    manifest = json.loads((backup / "manifest.json").read_text(encoding="utf-8-sig"))
    changed = [r["Path"] for r in protected if digest(root / r["Path"]) != r["SHA256"]]
    damaged = [r["Path"] for r in manifest if digest(backup / r["Path"]) != r["SHA256"]]
    files = [root / file for file in targets] + [root / "src/ui/CombatSlots.project.json", root / "default.project.json"] + [
        p for p in (root / "tests").glob("CombatSystemV132*")
        if p.suffix in (".md", ".json", ".luau")
    ]
    whitespace = [
        f"{p.relative_to(root)}:{i}"
        for p in files for i, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1)
        if line != line.rstrip()
    ]
    result = {"ProtectedFiles": len(protected), "ProtectedDifferences": changed,
              "BackupFiles": len(manifest), "BackupHashMismatches": damaged,
              "WhitespaceIssues": whitespace}
    (root / "tests/CombatSystemV132.integrity.json").write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(result))
    raise SystemExit(bool(changed or damaged or whitespace))
else:
    raise SystemExit("Expected payload or verify")
