"""Compose current economy expectations without overwriting historical phase specs."""
from pathlib import Path
root=Path(__file__).resolve().parents[2]
base=(root/'tests/SlapCratesV1.spec.luau').read_text(encoding='utf-8')
base=base[:base.rfind('print(')]
base=base.replace('"CrateDefinitions",','"InitialOdds","CrateDefinitions",').replace('"CrateShopView",','"CrateShopView","OddsPresentation",')
base=base.replace('c.PriceCoins==nil','c.PriceApproved==true and c.PriceCoins>0 and not c.OddsApproved and not c.Enabled')
base=base.replace('next(c.Weights)==nil','next(c.Weights)~=nil')
base=base.replace('not quote.Ok and quote.Code=="CommercialApprovalPending"','quote.Ok and quote.ReviewOnly and not quote.PurchaseAllowed')
base=base.replace('public[1].Metadata.PricePending==true','public[1].Metadata.PricePending==false')
base=base.replace('local service=load("CrateService","CrateService")','parent.StandOpeningService="StandOpeningFixture"\nloaded.StandOpeningFixture={new=function()return {IsStandMode=function()return false end,Context=function()return {Mode="Spin"}end,Open=function(_,_,_,callback)return callback()end}end}\nlocal service=load("CrateService","CrateService")')
ext=(root/'tests/SlapCratesV12.extension.luau').read_text(encoding='utf-8')
ext=ext.replace('state.PriceText=="Precio pendiente"and not state.BuyEnabled','state.PriceText==tostring(list[i].Price).." Coins"and state.Status=="Probabilidades pendientes"and not state.BuyEnabled')
ext=ext.replace('and public[1].Metadata.PricePending and','and not public[1].Metadata.PricePending and')
ext=ext.replace('detail.PriceLabel.Text=="Precio pendiente"','detail.PriceLabel.Text=="500 Coins"')
ext=ext.replace('card.PriceLabel.Text=="Precio pendiente"','card.PriceLabel.Text=="500 Coins"')
ext=ext.replace('PASS SlapCratesV12:','PASS SlapCratesV13:')
prices=[500,1000,1750,3000,4500,7000,10000,13500,19000,27500,37500,50000]
ext=ext.replace('print("PASS SlapCratesV13:',f'local official={{{",".join(map(str,prices))}}}\nfor i=1,12 do check(list[i].Price==official[i],"Exact approved price "..list[i].Id)end\nprint("PASS SlapCratesV13:')
(root/'tests/SlapCratesV13.spec.luau').write_text(base+ext,encoding='utf-8')
shop=(root/'tests/AbilityShopV13.shop.spec.luau').read_text(encoding='utf-8').replace('s.Config.Match.PointReward==50 and s.Config.Economy.KillRewardCoins==50','s.Config.Match.PointReward==150 and s.Config.Economy.KillRewardCoins==30').replace('Goal/Kill rewards untouched','Official Goal/Kill rewards')
(root/'tests/EconomyBalanceV1.shop.spec.luau').write_text(shop,encoding='utf-8')
