--!nonstrict
local Access=require(script.Parent.Parent.Access)
return {
 Id='GrantCoins',DisplayName='Dar Coins',Description='Acredita Coins al jugador conectado. No concede premios de combate.',
 Fields={{Name='TargetUserId',Label='Jugador',Type='Player'},{Name='Amount',Label='Cantidad de Coins',Type='Integer',Min=1,Max=Access.MaxCoinsPerGrant}},
 Execute=function(context,args)
  local ps=context.PlayerService;local target=context.Target
  if not ps:IsShopDataReady(target)then return {Ok=false,Reason='DataNotLoaded'}end
  local current=ps:GetCoins(target)
  if current>9007199254740991-args.Amount then return {Ok=false,Reason='BalanceOverflow'}end
  local balance,credited=ps:AddCoins(target,args.Amount,'AdminGrant',context.OperationId)
  return {Ok=credited==args.Amount,Reason=credited==args.Amount and 'CoinsGranted'or 'NotCredited',Balance=balance,Granted=credited}
 end,
}
