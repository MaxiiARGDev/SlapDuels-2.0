local definitions=require(script.Parent.Parent.Parent.SlapCrates.PremiumCrateDefinitions)
local products={}
for i,c in ipairs(definitions)do
 table.insert(products,{Id=c.CrateId,Category="PremiumCrates",DisplayName=c.DisplayName,Description=c.Description,
  DeveloperProductId=123456200+i,IsPlaceholder=true,SuggestedRobux=({49,99,199})[i],CrateId=c.CrateId,Rewards={Coins=0,Crates={{CrateId=c.CrateId,Quantity=1}},Slaps={},KillEffects={}},
  Icon=c.Icon,PreviewModel=c.Model,SortOrder=c.SortOrder,Enabled=true,PurchaseApproved=false,ContentsApproved=false,
  DuplicatePolicy="RepeatableNoCompensation",ContractVersion="DraftV1"})
end
return products
