--!nonstrict
-- EXAMPLE IDs ONLY. Replace each ID in Creator Hub and clear IsPlaceholder individually.
local products={}
for i,row in ipairs({{1000,19},{2500,39},{6000,79},{15000,149},{40000,299}})do
 local id="Coins_"..row[1]
 table.insert(products,{Id=id,PackageId=id,Category="Coins",DisplayName=tostring(row[1]).." Coins",
  Description="Paquete garantizado de "..row[1].." Coins. Precio sugerido, no precio final de Roblox.",
  DeveloperProductId=123456000+i,IsPlaceholder=true,SuggestedRobux=row[2],Coins=row[1],
  Rewards={Coins=row[1],Crates={},Slaps={},KillEffects={}},Icon="",SortOrder=i*10,
  Enabled=true,PurchaseApproved=false,ContentsApproved=true,DuplicatePolicy="RepeatableNoCompensation",ContractVersion="CoinsV11"})
end
return products
