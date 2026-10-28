--!nonstrict
local Matrix=require(script.Parent.InitialOdds)
local definitions={}
for _,entry in ipairs({{Id="Basic",SortOrder=10,PriceCoins=500},{Id="Common",SortOrder=20,PriceCoins=1000},{Id="Uncommon",SortOrder=30,PriceCoins=1750},
 {Id="Rare",SortOrder=40,PriceCoins=3000},{Id="Gold",SortOrder=50,PriceCoins=4500},{Id="Arcoiris",SortOrder=60,PriceCoins=7000},{Id="Emote",SortOrder=70,PriceCoins=10000},
 {Id="Wings",SortOrder=80,PriceCoins=13500},{Id="Epic",SortOrder=90,PriceCoins=19000},{Id="Legendary",SortOrder=100,PriceCoins=27500},{Id="Blood",SortOrder=110,PriceCoins=37500},{Id="Galaxy",SortOrder=120,PriceCoins=50000}}) do
 local id=entry.Id
 table.insert(definitions,{CrateId=id,SortOrder=entry.SortOrder,DisplayName="Caja "..id,Description="Matriz inicial en revisión. Compra comercial bloqueada.",
  Icon="",Model=id,PriceCoins=entry.PriceCoins,PriceApproved=true,OddsApproved=false,ApprovalStatus="OddsPending",
  Enabled=false,MatrixVersion="InitialV13Review",RollDuration=5,AnimationProfile="Horizontal",VFX=id,SFX="Reveal",Weights=Matrix.WeightsFor(id),
  DuplicatePolicy="UniquePerPlayer",SoldOutPolicy="ExcludeAndRenormalize",StockRules={}})
end
-- Isolated fixture only. Never in production catalog and disabled unless a server Edit flag is enabled.
table.insert(definitions,{CrateId="StudioTest",SortOrder=1000,DisplayName="PRUEBA LOCAL — Caja",Description="Solo InMemory. 1 Coin y pesos 3:1 ilustrativos; sin valor comercial.",
 Icon="",Model="Basic",PriceCoins=1,PriceApproved=true,OddsApproved=true,ApprovalStatus="IsolatedFixture",
 Enabled=true,StudioOnly=true,RollDuration=4,AnimationProfile="Horizontal",VFX="Basic",SFX="Reveal",
 Weights={Basic=3,Common=1},DuplicatePolicy="AllowDuplicates",SoldOutPolicy="ExcludeAndRenormalize",StockRules={}})
for _,premium in ipairs(require(script.Parent.PremiumCrateDefinitions))do table.insert(definitions,premium)end
return definitions
