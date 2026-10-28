--!nonstrict
local definitions={}
for _,entry in ipairs({{Id="Basic",SortOrder=10},{Id="Common",SortOrder=20},{Id="Uncommon",SortOrder=30},
 {Id="Rare",SortOrder=40},{Id="Gold",SortOrder=50},{Id="Arcoiris",SortOrder=60},{Id="Emote",SortOrder=70},
 {Id="Wings",SortOrder=80},{Id="Epic",SortOrder=90},{Id="Legendary",SortOrder=100},{Id="Blood",SortOrder=110},{Id="Galaxy",SortOrder=120}}) do
 local id=entry.Id
 table.insert(definitions,{CrateId=id,SortOrder=entry.SortOrder,DisplayName="Caja "..id,Description="Precios y probabilidades pendientes de aprobación.",
  Icon="",Model=id,PriceCoins=nil,PriceApproved=false,OddsApproved=false,ApprovalStatus="Pending",
  Enabled=false,RollDuration=5,AnimationProfile="Horizontal",VFX=id,SFX="Reveal",Weights={},
  DuplicatePolicy="UniquePerPlayer",SoldOutPolicy="ExcludeAndRenormalize",StockRules={}})
end
-- Isolated fixture only. Never in production catalog and disabled unless a server Edit flag is enabled.
table.insert(definitions,{CrateId="StudioTest",SortOrder=1000,DisplayName="PRUEBA LOCAL — Caja",Description="Solo InMemory. 1 Coin y pesos 3:1 ilustrativos; sin valor comercial.",
 Icon="",Model="Basic",PriceCoins=1,PriceApproved=true,OddsApproved=true,ApprovalStatus="IsolatedFixture",
 Enabled=true,StudioOnly=true,RollDuration=4,AnimationProfile="Horizontal",VFX="Basic",SFX="Reveal",
 Weights={Basic=3,Common=1},DuplicatePolicy="AllowDuplicates",SoldOutPolicy="ExcludeAndRenormalize",StockRules={}})
return definitions
