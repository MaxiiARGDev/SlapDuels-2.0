--!nonstrict
return {
 Id='GrantSlap',DisplayName='Dar Slap',Description='Otorga propiedad de una variación del catálogo. No equipa ni fabrica unidades comerciables.',
 Fields={{Name='TargetUserId',Label='Jugador',Type='Player'},{Name='RewardId',Label='Slap / variación',Type='Slap'}},
 Execute=function(context,args)
  local ps=context.PlayerService;local target=context.Target
  if not ps:IsShopDataReady(target)then return {Ok=false,Reason='DataNotLoaded'}end
  if ps:HasItem(target,'Slaps',args.RewardId)then return {Ok=true,Reason='AlreadyOwned',RewardId=args.RewardId}end
  local ok,granted,why=pcall(ps.AddItem,ps,target,'Slaps',args.RewardId)
  -- UI notification failure cannot turn an already granted entitlement into an error/retry.
  if ps:HasItem(target,'Slaps',args.RewardId)then return {Ok=true,Reason='SlapGranted',RewardId=args.RewardId}end
  return {Ok=false,Reason=ok and why or 'GrantFailed'}
 end,
}
