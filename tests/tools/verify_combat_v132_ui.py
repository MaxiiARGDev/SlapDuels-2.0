"""Check authored and built slot hierarchy without running Roblox."""
import json
import pathlib
import xml.etree.ElementTree as ET

root = pathlib.Path(__file__).resolve().parents[2]
data = json.loads((root / "src/ui/CombatSlots.project.json").read_text(encoding="utf-8"))
expected = {}
interactive = []


def visit(node, path):
    expected[path] = node["$className"]
    props = node.get("$properties", {})
    if node["$className"] in ("Frame", "TextLabel", "ImageLabel"):
        if props.get("Active") is not False or props.get("Selectable") is not False:
            interactive.append(path)
    assert node["$className"] not in ("ScreenGui", "TextButton", "ImageButton")
    assert node.get("$ignoreUnknownInstances") is True
    for key, child in node.items():
        if not key.startswith("$"):
            visit(child, path + "." + key)


visit(data["tree"], "CombatSlots")
tree = ET.parse(root / "tests/CombatSystemV132.build.rbxlx")


def name(item):
    node = item.find("./Properties/string[@name='Name']")
    return node.text if node is not None else ""


def collect(item, path, result):
    result[path] = item.attrib["class"]
    for child in item.findall("Item"):
        collect(child, path + "." + name(child), result)


slot_roots = [i for i in tree.iter("Item") if name(i) == "CombatSlots"]
assert len(slot_roots) == 1
actual = {}
collect(slot_roots[0], "CombatSlots", actual)
assert actual == expected, (actual, expected)
assert not interactive, interactive
assert expected["CombatSlots.SlapSlot.CooldownOverlay.CooldownTimeLabel"] == "TextLabel"
assert expected["CombatSlots.SlapSlot.CooldownOverlay.CooldownBarBackground.CooldownBarFill"] == "Frame"
default = json.loads((root / "default.project.json").read_text(encoding="utf-8"))
hud = default["tree"]["StarterGui"]["PlayerHUD"]
assert hud["$ignoreUnknownInstances"] is True
assert "ProfileCard" not in hud  # Existing native profile UI remains outside this change.
safe = json.loads((root / "studio-safe.project.json").read_text(encoding="utf-8"))
assert "StarterGui" not in safe["tree"]  # SAFE still manages only its existing script surfaces.
result = {"BuildHierarchyMatches": True, "Instances": len(actual),
          "NewScreenGuis": 0, "InteractiveObjects": interactive,
          "DefaultPreservesExistingPlayerHUDChildren": True, "SafeUIUnmanaged": True}
(root / "tests/CombatSystemV132.ui-verification.json").write_text(
    json.dumps(result, indent=2) + "\n", encoding="utf-8"
)
print(json.dumps(result))
