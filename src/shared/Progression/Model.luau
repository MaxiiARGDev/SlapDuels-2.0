--!nonstrict
local Config=require(script.Parent.Config)
local Model={}
function Model.Copy(v)if type(v)~='table'then return v end;local n={};for k,x in pairs(v)do n[k]=Model.Copy(x)end;return n end
function Model.Integer(v)return type(v)=='number'and v==v and v>=0 and v<9007199254740991 and v%1==0 end
function Model.Normalize(raw)
 raw=if type(raw)=='table'then raw else {}
 local p={Schema=1,TotalXP=if Model.Integer(raw.TotalXP)then raw.TotalXP else 0,Receipts={},ReceiptOrder={},Watermark=if Model.Integer(raw.Watermark)then raw.Watermark else 0}
 if type(raw.ReceiptOrder)=='table'and type(raw.Receipts)=='table'then
  for _,id in ipairs(raw.ReceiptOrder)do local r=raw.Receipts[id];if type(id)=='string'and type(r)=='table'and Model.Integer(r.StartedAt)and not p.Receipts[id]then p.Receipts[id]=Model.Copy(r);table.insert(p.ReceiptOrder,id)end end
 end
 while #p.ReceiptOrder>128 do local id=table.remove(p.ReceiptOrder,1);p.Watermark=math.max(p.Watermark,p.Receipts[id].StartedAt);p.Receipts[id]=nil end
 local e=raw.Edition
 if type(e)=='table'and type(e.Id)=='string'and Model.Integer(e.XP)then
  p.Edition={Id=e.Id,XP=e.XP,Claimed={},Premium=false,PremiumSince=nil,FullUnlock=false}
  for i=1,30 do if type(e.Claimed)=='table'and e.Claimed[tostring(i)]==true then p.Edition.Claimed[tostring(i)]=true end end
  -- Future paid entitlements must be confirmed by the durable receipt integration, not profile flags.
 end
 return p
end
function Model.Level(total)
 total=if Model.Integer(total)then total else 0
 local level=0;local remaining=total
 while level<36 do local cost=Config.FirstLevelXP+Config.LevelIncrement*level;if remaining<cost then return level,remaining,cost end;remaining-=cost;level+=1 end
 local extra=math.floor(remaining/Config.MaximumLevelXP);return level+extra,remaining%Config.MaximumLevelXP,Config.MaximumLevelXP
end
function Model.Active(season,now)return type(season)=='table'and type(season.Id)=='string'and type(season.StartsAt)=='number'and type(season.EndsAt)=='number'and season.StartsAt<=now and now<season.EndsAt end
function Model.Edition(p,season)
 if not p.Edition or p.Edition.Id~=season.Id then p.Edition={Id=season.Id,XP=0,Claimed={},Premium=false,FullUnlock=false}end
 return p.Edition
end
function Model.Stage(p,season)
 local e=p.Edition
 return if e and e.Id==season.Id then math.min(season.Stages,math.floor(e.XP/season.StageXP))else 0
end
function Model.Eligible(m)
 return m.Playing>=Config.MinimumPlaying and(m.Goals>0 or m.Kills>0 or(m.FirstAttack and m.LastAttack and m.LastAttack-m.FirstAttack>=Config.AttackSeparation))==true
end
function Model.Award(raw,match,season,now)
 local p=Model.Normalize(raw)
 if p.Receipts[match.Id]then return p,p.Receipts[match.Id],false end
 if not Model.Integer(match.StartedAt)or match.StartedAt<=p.Watermark or now-match.StartedAt>7200 or match.StartedAt>now then return p,{Code='StaleMatch'},false end
 if not match.Connected or match.Left or match.Cancelled or not Model.Eligible(match)then
  local reason=if not match.Connected or match.Left then 'Left'elseif match.Cancelled then 'Cancelled'elseif match.Playing<Config.MinimumPlaying then 'MinimumPlaying'else 'Participation'
  return p,{Code='Ineligible',Reason=reason,XP=0,PassXP=0,Base=0,Victory=0,Goals=0,Kills=0},false
 end
 local base=Config.CompleteXP+(match.Won and Config.WinXP or 0)+match.Goals*Config.GoalXP+match.Kills*Config.KillXP
 local xp=base -- Premium deliberately disabled until durable commerce is implemented.
 if not Model.Integer(base)or base>100000 or p.TotalXP+xp>=9007199254740991 then return p,{Code='InvalidXP'},false end
 local passXP=0
 if Model.Active(season,now)and match.EditionId==season.Id then local e=Model.Edition(p,season);passXP=xp;e.XP+=passXP end
 p.TotalXP+=xp
 local receipt={StartedAt=match.StartedAt,XP=xp,PassXP=passXP,Base=Config.CompleteXP,Victory=match.Won and Config.WinXP or 0,Goals=match.Goals*Config.GoalXP,Kills=match.Kills*Config.KillXP,Code='Awarded'}
 p.Receipts[match.Id]=receipt;table.insert(p.ReceiptOrder,match.Id)
 while #p.ReceiptOrder>128 do local id=table.remove(p.ReceiptOrder,1);p.Watermark=math.max(p.Watermark,p.Receipts[id].StartedAt);p.Receipts[id]=nil end
 return p,receipt,true
end
function Model.Claim(data,season,now,stage,uid,catalog)
 if not Model.Active(season,now)then return nil,'SeasonExpired'end
 if not Model.Integer(stage)or stage<1 or stage>season.Stages then return nil,'InvalidStage'end
 local nextData=Model.Copy(data);nextData.Progression=Model.Normalize(data.Progression)
 local e=Model.Edition(nextData.Progression,season);local key=tostring(stage)
 if e.Claimed[key]then return nil,'AlreadyClaimed'end
 if Model.Stage(nextData.Progression,season)<stage then return nil,'StageLocked'end
 local reward=season.Rewards[stage];if not reward then return nil,'RewardMissing'end
 local inv=nextData.Inventory
 if not inv or type(inv.Owned)~='table'then return nil,'InvalidInventory'end
 local delivered=Model.Copy(reward)
 if reward.Kind=='Coins'then nextData.Coins+=reward.Amount
 elseif reward.Kind=='Effect'then
  inv.Owned[reward.Category]=inv.Owned[reward.Category]or {}
  if inv.Owned[reward.Category][reward.Id]then nextData.Coins+=reward.Compensation;delivered={Kind='Coins',Amount=reward.Compensation,Compensation=true}
  else inv.Owned[reward.Category][reward.Id]=true end
 elseif reward.Kind=='Slap'then
  local definition=catalog.Rewards[reward.Id];if not definition then return nil,'RewardMissing'end
  inv.Owned.Slaps=inv.Owned.Slaps or {};inv.Owned.Slaps[reward.Id]=true;inv.SlapUnits=inv.SlapUnits or {}
  local id='Pass:'..season.Id..':'..uid..':'..stage
  if inv.SlapUnits[id]then return nil,'UnitConflict'end
  inv.SlapUnits[id]={UnitId=id,RewardId=reward.Id,SlapId=definition.SlapId,VariationId=definition.VariationId,OwnerUserId=uid,Origin='BattlePass',OperationId=id}
 else return nil,'RewardInvalid'end
 e.Claimed[key]=true
 return nextData,delivered
end
return Model
