--!nonstrict
local Registry={}
local function integer(n,minimum)return type(n)=="number"and n==n and n<math.huge and n%1==0 and n>=minimum end
local categories={Coins=true,Combos=true,PremiumCrates=true}
local policies={OncePerPlayer=true,RestrictOwned=true,RepeatableNoCompensation=true}
function Registry.Build(groups,crates,deaths)
 local result={ById={},ByProductId={},Order={}}
 for _,group in ipairs(groups)do for _,raw in ipairs(group)do
  local p=table.clone(raw);assert(type(p.Id)=="string"and #p.Id>0 and #p.Id<=64 and not result.ById[p.Id],"DuplicateOrInvalidPremiumId")
  assert(categories[p.Category]and type(p.DisplayName)=="string"and type(p.Description)=="string","InvalidPremiumMetadata")
  assert(type(p.Enabled)=="boolean"and type(p.PurchaseApproved)=="boolean"and type(p.ContentsApproved)=="boolean","InvalidPremiumApproval")
  assert(type(p.ContractVersion)=="string"and #p.ContractVersion>0,"MissingContractVersion")
  assert(p.DeveloperProductId==nil or integer(p.DeveloperProductId,1),"InvalidDeveloperProductId")
  assert(p.DeveloperProductId==nil or not result.ByProductId[p.DeveloperProductId],"DuplicateDeveloperProductId")
  local r=p.Rewards;assert(type(r)=="table"and integer(r.Coins,0),"InvalidCoinQuantity")
  if p.Category=="Coins"and p.Coins~=nil then assert(integer(p.Coins,1)and p.Coins==r.Coins,"CoinPackageAmountMismatch")end
  assert(p.SuggestedRobux==nil or integer(p.SuggestedRobux,1),"InvalidSuggestedPrice")
  for key in pairs(r)do assert(key=="Coins"or key=="Crates"or key=="Slaps"or key=="KillEffects","UnsupportedPremiumReward")end
  local content=r.Coins>0;local permanent=false;local random=false;local limited=false;local cratesReady=true
  assert(type(r.Crates)=="table"and type(r.Slaps)=="table"and type(r.KillEffects)=="table","InvalidPremiumContents")
  local seen={}
  for _,item in ipairs(r.Crates)do
   assert(crates.Crates.ById[item.CrateId]and integer(item.Quantity,1)and item.Quantity<=100 and not seen[item.CrateId],"InvalidPremiumCrate")
   seen[item.CrateId]=true;content=true;random=true
   local c=crates.Crates.ById[item.CrateId]
   cratesReady=cratesReady and not c.StudioOnly and c.Enabled==true and c.OddsApproved==true and next(c.Weights)~=nil
    and(if c.PremiumOnly then c.OpeningApproved==true else c.PriceApproved==true)
  end
  seen={}
  for _,item in ipairs(r.Slaps)do
   local id=tostring(item.SlapId)..":"..tostring(item.VariationId);local reward=crates.Rewards[id]
   assert(reward and not seen[id],"InvalidPremiumSlap");seen[id]=true;permanent=true;content=true
   local v=crates.Variations.ById[reward.VariationId];limited=limited or reward.LimitedStock==true or v.LimitedStock==true
  end
  seen={}
  for _,id in ipairs(r.KillEffects)do assert(deaths[id]and deaths[id].IsShopProduct==true and not seen[id],"InvalidPremiumKillEffect");seen[id]=true;content=true;permanent=true end
  if p.Category=="Coins"then assert(#r.Crates==0 and #r.Slaps==0 and #r.KillEffects==0,"CoinPackageHasOtherRewards")end
  if p.Category=="PremiumCrates"then assert(p.CrateId and crates.Crates.ById[p.CrateId]and crates.Crates.ById[p.CrateId].PremiumOnly,"InvalidPremiumBoxProduct")end
  p.HasRandomContents=random;p.HasPermanentContents=permanent
  p.IsPlaceholder=p.IsPlaceholder~=false
  p.BlockedReason=if p.IsPlaceholder then "PlaceholderProduct"elseif not content or not p.ContentsApproved then "ContentsPending"elseif not policies[p.DuplicatePolicy]then "DuplicatePolicyPending"
   elseif limited then "LimitedGuaranteeBackendPending"elseif not cratesReady then "CrateApprovalPending"elseif not p.DeveloperProductId then "ProductIdPending"elseif not p.PurchaseApproved then "ApprovalPending"
   elseif not p.Enabled then "ProductDisabled"else nil
  result.ById[p.Id]=p;table.insert(result.Order,p.Id)
  if p.DeveloperProductId then result.ByProductId[p.DeveloperProductId]=p end
 end end
 table.sort(result.Order,function(a,b)local x,y=result.ById[a],result.ById[b];return if x.SortOrder==y.SortOrder then a<b else(x.SortOrder or 0)<(y.SortOrder or 0)end)
 return result
end
function Registry.Load(shared)
 -- Explicit authorized modules only. Never require arbitrary descendants.
 return Registry.Build({require(shared.PremiumShop.Catalog.CoinPackages),require(shared.PremiumShop.Catalog.PremiumCombos),require(shared.PremiumShop.Catalog.PremiumCrates)},
  require(shared.SlapCrates.Catalog),require(shared.DeathEffectDefinitions))
end
return Registry
