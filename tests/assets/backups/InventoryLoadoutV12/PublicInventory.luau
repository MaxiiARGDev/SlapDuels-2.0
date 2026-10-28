--!nonstrict
local Policy=require(script.Parent.TradePolicy)
local View={}
function View.Build(data,uid,catalog)
 local inventory=data.Inventory or {};local equipped=inventory.Equipped and inventory.Equipped.Slaps
 local rows,represented={},{}
 local function row(reward,unit,key)
  local v=catalog.Variations.ById[reward.VariationId]
  local allowed,reason=false,'LegacyEntitlement'
  if unit then allowed,reason=Policy.Check(unit,inventory,uid,catalog)end
  return {EntryId=key,UnitId=unit and unit.UnitId,RewardId=reward.RewardId,SlapId=reward.SlapId,VariationId=reward.VariationId,
   DisplayName=reward.DisplayName,VariationName=v.DisplayName,Rarity=v.Id,Owned=true,Equipped=equipped==reward.RewardId,
   Tradable=allowed,Restriction=reason}
 end
 for key,unit in pairs(type(inventory.SlapUnits)=='table'and inventory.SlapUnits or {})do
  if type(key)=='string' and type(unit)=='table' and unit.UnitId==key and unit.OwnerUserId==uid then
   local reward=catalog.Rewards[unit.RewardId]
   if reward and reward.SlapId==unit.SlapId and reward.VariationId==unit.VariationId then
    table.insert(rows,row(reward,unit,key));represented[unit.RewardId]=true
   end
  end
 end
 for id,owned in pairs(inventory.Owned and inventory.Owned.Slaps or {})do
  local reward=catalog.Rewards[id]
  if owned==true and reward and not represented[id] then table.insert(rows,row(reward,nil,'Legacy:'..id));represented[id]=true end
 end
 -- The existing default entitlement is universal, even before crates extend the schema.
 if not represented[catalog.DefaultRewardId]then table.insert(rows,row(catalog.Rewards[catalog.DefaultRewardId],nil,'Legacy:'..catalog.DefaultRewardId))end
 table.sort(rows,function(a,b)return a.RewardId==b.RewardId and a.EntryId<b.EntryId or a.RewardId<b.RewardId end)
 return rows
end
function View.Profile(player,data,catalog,config,page)
 local all=View.Build(data,player.UserId,catalog);local start=(page-1)*config.InventoryPageSize+1;local entries={}
 for i=start,math.min(#all,start+config.InventoryPageSize-1)do table.insert(entries,all[i])end
 local equipped;for _,row in ipairs(all)do if row.Equipped then equipped=row;break end end
 local function stat(n)return type(n)=='number' and n==n and n>=0 and n<math.huge and math.floor(n)or 0 end
 return {UserId=player.UserId,DisplayName=player.DisplayName,Username=player.Name,
  Stats={Wins=stat(data.Wins),Losses=stat(data.Losses),TotalKills=stat(data.Kills),Streaks=stat(type(data.WinStreak)=='table'and data.WinStreak.Total)},
  EquippedSlap=equipped,Progression={Available=false,Status='Nivel y EXP pendientes'},Inventory=entries,Page=page,TotalItems=#all,
  HasNext=start+#entries<=#all,TradeCommitEnabled=false}
end
return View
