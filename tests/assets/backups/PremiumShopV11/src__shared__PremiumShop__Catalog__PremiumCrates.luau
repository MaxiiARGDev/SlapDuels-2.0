local definitions=require(script.Parent.Parent.Parent.SlapCrates.PremiumCrateDefinitions)
local products={}
for _,c in ipairs(definitions)do
 table.insert(products,{Id=c.CrateId,Category="PremiumCrates",DisplayName=c.DisplayName,Description=c.Description,
  DeveloperProductId=nil,CrateId=c.CrateId,Rewards={Coins=0,Crates={{CrateId=c.CrateId,Quantity=1}},Slaps={},KillEffects={}},
  Icon=c.Icon,PreviewModel=c.Model,SortOrder=c.SortOrder,Enabled=false,PurchaseApproved=false,ContentsApproved=false,
  DuplicatePolicy="RepeatableNoCompensation",ContractVersion="DraftV1"})
end
return products
