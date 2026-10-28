-- Exactly three draft tiers. Empty weights mean NOT CONFIGURED, not zero-percent commercial odds.
local definitions={}
for i,id in ipairs({"PremiumI","PremiumII","PremiumIII"})do
 table.insert(definitions,{CrateId=id,SortOrder=2000+i*10,DisplayName="Premium "..({"I","II","III"})[i],
  Description="Caja Premium provisional. Contenidos, probabilidades, precio y venta pendientes.",Icon="",Model=id,
  PremiumOnly=true,PriceCoins=nil,PriceApproved=false,OddsApproved=false,OpeningApproved=false,Enabled=false,
  ApprovalStatus="PremiumApprovalPending",RollDuration=5,AnimationProfile="Horizontal",VFX=id,SFX="Reveal",Weights={},
  DuplicatePolicy="UniquePerPlayer",SoldOutPolicy="ExcludeAndRenormalize",StockRules={}})
end
return definitions
