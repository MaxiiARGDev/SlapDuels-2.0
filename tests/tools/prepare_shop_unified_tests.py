from pathlib import Path
p=Path("tests/CrateGalleryV4.spec.luau")
s=p.read_text(encoding="utf-8")
s=s.replace("CrateRewardGallery={}}","CrateRewardGallery={},ShopLayout={}}")
s=s.replace("Parent={Parent={CrateOpening=", "Parent={Parent={UI={ShopLayout='ShopLayout'},CrateOpening=")
s=s.replace("PASS CrateGalleryV4:", "PASS ShopUnifiedV1:")
s+="""
-- Re-rendering snapshots must not clear the current quote or issue another request.
C._panel.Visible=true;C._request={};C._quote={Token='keep'};C._quoteCache.Gold=C._quote
local version=C._selectionVersion
C:ShowCrate('Gold',true)
check(C._selectionVersion==version and C._quote.Token=='keep','same embedded selection preserves quote')
C._products.Basic={Id='Basic'};C._pendingAction={CrateId='Gold'}
C:ShowCrate('Basic',true)
check(C._crateId=='Gold','pending transaction prevents crate substitution')
C._pendingAction=nil;C._busy=true;C:ShowCrate('Basic',true)
check(C._crateId=='Gold','busy transaction prevents crate substitution')
print('PASS ShopUnifiedV1 total: '..count..' assertions')
"""
Path("tests/ShopUnifiedV1.spec.luau").write_text(s,encoding="utf-8")
