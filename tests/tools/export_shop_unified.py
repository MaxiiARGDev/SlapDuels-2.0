from pathlib import Path
import base64,json
root=Path(__file__).resolve().parents[2]
(root/"src/ui/ShopHUD.UnifiedV1.rbxm").write_bytes(base64.b64decode((root/"tests/ShopUnifiedV1.HUD.base64").read_text()))
(root/"tests/assets/backups/ShopUnifiedV1/ShopHUD.rbxm").write_bytes(base64.b64decode((root/"tests/assets/backups/ShopUnifiedV1/ShopHUD.base64").read_text()))
p=root/"default.project.json"
s=p.read_text(encoding="utf-8").replace('"src/ui/ShopHUD.CrateGalleryV4.rbxm"','"src/ui/ShopHUD.UnifiedV1.rbxm"')
p.write_text(s,encoding="utf-8")
p=root/"studio-safe.project.json"
d=json.loads(p.read_text(encoding="utf-8"))
d["tree"].setdefault("StarterGui",{"$className":"StarterGui","$ignoreUnknownInstances":True})["ShopHUD"]={
 "$className":"ScreenGui","$ignoreUnknownInstances":True,
 "UIEffects":{"$path":"src/ui/scripts/ShopUIEffects.client.luau","$ignoreUnknownInstances":True},
 "MainFrame":{"$className":"Frame","$ignoreUnknownInstances":True,
  "NeonShopMotion":{"$path":"src/ui/scripts/ShopNeonShopMotion.client.luau","$ignoreUnknownInstances":True}}}
# Preserve existing whitespace for the large generated map, insert only StarterGui.
original=p.read_text(encoding="utf-8")
if '"StarterGui"' not in original:
 pos=original.index('"tree"')
 brace=original.index('{',pos)
 inserted='\n        "StarterGui": '+json.dumps(d["tree"]["StarterGui"],ensure_ascii=False)+','
 original=original[:brace+1]+inserted+original[brace+1:]
 p.write_text(original,encoding="utf-8")
else:
 raise RuntimeError("Review existing StarterGui map before changing it")
print("Exported current Edit HUD; safe map synchronizes only its two scripts.")
