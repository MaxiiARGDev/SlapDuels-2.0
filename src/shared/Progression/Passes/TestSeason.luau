--!nonstrict
-- Editions freeze a copy of these definitions. Add future themes here, never client rewards.
local rewards={}
local coins={[1]=150,[2]=200,[4]=250,[6]=300,[7]=350,[9]=400,[11]=450,[12]=500,[14]=550,[16]=600,[17]=650,[19]=700,[21]=750,[22]=800,[24]=850,[26]=900,[27]=950,[29]=1000}
for stage,n in pairs(coins)do rewards[stage]={Kind='Coins',Amount=n,Label=n..' Coins'}end
for stage,id in pairs({[3]='Chancla:Common',[8]='Classic:Uncommon',[13]='PingPong:Rare',[18]='Chancla:Gold',[23]='Classic:Arcoiris',[30]='PingPong:Epic'})do rewards[stage]={Kind='Slap',Id=id,Label=id}end
for stage,row in pairs({[5]={'PointEffects','Inferno',500},[10]={'PointEffects','Frost',750},[15]={'DeathEffects','Frost',750},[20]={'PointEffects','Thunder',1500},[25]={'PointEffects','Void',3000},[28]={'DeathEffects','Void',3000}})do
 rewards[stage]={Kind='Effect',Category=row[1],Id=row[2],Compensation=row[3],Label=(row[1]=='PointEffects'and 'Punto: 'or 'Muerte: ')..row[2]}
end
return {Id='TestSeason',Version=1,DisplayName='SlapDuels · Pase de prueba',StudioOnly=true,StageXP=800,Stages=30,Rewards=rewards}
