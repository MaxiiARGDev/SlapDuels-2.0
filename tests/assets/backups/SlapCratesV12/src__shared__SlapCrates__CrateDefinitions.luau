--!nonstrict
local definitions={}
for _,id in ipairs({"Basic","Common","Uncommon","Rare","Gold","Arcoiris","Emote","Wings","Epic","Legendary","Blood","Galaxy"}) do
 table.insert(definitions,{CrateId=id,DisplayName="Caja "..id,Description="Precios y probabilidades pendientes de aprobación.",
  Icon="",Model=id,PriceCoins=nil,PriceApproved=false,OddsApproved=false,ApprovalStatus="Pending",
  Enabled=false,RollDuration=5,AnimationProfile="Horizontal",VFX=id,SFX="Reveal",Weights={},
  DuplicatePolicy="UniquePerPlayer",SoldOutPolicy="ExcludeAndRenormalize",StockRules={}})
end
-- Isolated fixture only. Never in production catalog and disabled unless a server Edit flag is enabled.
table.insert(definitions,{CrateId="StudioTest",DisplayName="PRUEBA LOCAL — Caja",Description="Solo InMemory. 1 Coin y pesos 3:1 ilustrativos; sin valor comercial.",
 Icon="",Model="Basic",PriceCoins=1,PriceApproved=true,OddsApproved=true,ApprovalStatus="IsolatedFixture",
 Enabled=true,StudioOnly=true,RollDuration=4,AnimationProfile="Horizontal",VFX="Basic",SFX="Reveal",
 Weights={Basic=3,Common=1},DuplicatePolicy="AllowDuplicates",SoldOutPolicy="ExcludeAndRenormalize",StockRules={}})
return definitions
