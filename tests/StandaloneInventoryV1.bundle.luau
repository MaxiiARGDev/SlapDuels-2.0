local Sources={}
Sources["Appearance"]=[====[--!nonstrict
-- Cosmetic-only: no Parts, joints, scripts, Configuration, animation or combat state.
local Appearance={}
local allowed={Attachment=true,ParticleEmitter=true,PointLight=true,BillboardGui=true,Frame=true,TextLabel=true,UICorner=true,UIStroke=true}
local function material(name)
 if type(name)~="string"then return nil end
 local ok,result=pcall(function()return Enum.Material[name]end)
 return if ok then result else nil
end
local function finite(n)return type(n)=="number" and n==n and n>-math.huge and n<math.huge end
local function safe(root)
 if not allowed[root.ClassName]then return false end
 for _,desc in ipairs(root:GetDescendants())do if not allowed[desc.ClassName]then return false end end
 return true
end
function Appearance.Apply(hand,profile)
 if not hand or not hand:IsA("BasePart")or not profile then return false end
 -- Full authored templates already contain their appearance, sounds and future effects.
 -- Never overlay legacy generated profiles or remove artist-authored components.
 if hand:GetAttribute("SlapVariationAuthored")==true then return true end
 local original=hand:GetAttribute("SlapVariationOriginalColor")
 if typeof(original)~="Color3"then original=hand.Color;hand:SetAttribute("SlapVariationOriginalColor",original)end
 local originalMaterial=hand:GetAttribute("SlapVariationOriginalMaterial")
 if not material(originalMaterial)then originalMaterial=hand.Material.Name;hand:SetAttribute("SlapVariationOriginalMaterial",originalMaterial)end
 hand.Color=original;hand.Material=material(originalMaterial)
 for _,child in ipairs(hand:GetChildren())do
  if child:GetAttribute("SlapVariationManaged")==true then child:Destroy()end
 end
 local tint=profile:GetAttribute("Tint")
 if profile:GetAttribute("ApplyTint")~=false and typeof(tint)=="Color3"then hand.Color=tint end
 if profile:GetAttribute("ApplyMaterial")==true then
  local m=material(profile:GetAttribute("Material"));if m then hand.Material=m end
 end
 local intensity=profile:GetAttribute("Intensity")
 intensity=if finite(intensity)then math.clamp(intensity,0,2)else 1
 for _,resource in ipairs(profile:GetChildren())do
  if not safe(resource)then continue end
  local copy=resource:Clone();copy:SetAttribute("SlapVariationManaged",true)
  local all=copy:GetDescendants();table.insert(all,copy)
  for _,desc in ipairs(all)do
   if desc:IsA("Attachment")and desc:GetAttribute("ScaleToHand")==true then
    local position=desc:GetAttribute("NormalizedPosition")
    if typeof(position)=="Vector3"then desc.Position=hand.Size*position end
   elseif desc:IsA("ParticleEmitter")then
    desc:SetAttribute("SlapVariationEmitter",true)
    desc.Rate=math.clamp(desc.Rate*intensity,0,24)
    if intensity==0 then desc.Enabled=false end
   elseif desc:IsA("PointLight")then
    desc.Brightness=math.clamp(desc.Brightness*intensity,0,1)
    if intensity==0 then desc.Enabled=false end
   end
  end
  copy.Parent=hand
 end
 return true
end
return Appearance
]====]
Sources["BatchOpening"]=[====[--!nonstrict
local Config=require(script.Parent.OpeningConfig)
local Batch={}
function Batch.Quantity(value)
 if value==nil then return 1 end
 if type(value)~="number"then return nil end
 for _,allowed in ipairs(Config.AllowedOpenQuantities)do if value==allowed then return value end end
 return nil
end
function Batch.Count(operation)return operation.Quantity or 1 end
function Batch.Rewards(operation)return operation.Rewards or {operation}end
return Batch
]====]
Sources["Catalog"]=[====[--!nonstrict
local Registry=require(script.Parent.Registry)
local Catalog={}
Catalog.Variations=Registry.Build(require(script.Parent.VariationDefinitions),"Id")
Catalog.Slaps=Registry.Build(require(script.Parent.SlapDefinitions),"SlapId",function(d)
 assert(type(d.Model)=="string" and type(d.VariationIds)=="table","InvalidSlap")
 local seen={} for _,id in ipairs(d.VariationIds)do assert(Catalog.Variations.ById[id] and not seen[id],"InvalidVariation");seen[id]=true end
end)
Catalog.Crates=Registry.Build(require(script.Parent.CrateDefinitions),"CrateId",function(d)
 assert(type(d.SortOrder)=="number" and d.SortOrder==d.SortOrder and math.abs(d.SortOrder)<math.huge,"InvalidCrateSortOrder")
 assert(d.AnimationProfile=="Horizontal","UnsupportedAnimationProfile")
 assert(type(d.Model)=="string" and type(d.Icon)=="string" and type(d.Weights)=="table","InvalidCrateDefinition")
 local sum,count=0,0
 for id,weight in pairs(d.Weights)do
  assert(Catalog.Variations.ById[id]and type(weight)=="number"and weight==weight and weight>=0 and weight<math.huge,"InvalidCrateWeight")
  sum+=weight;count+=1
 end
 if d.MatrixVersion=="InitialV13Review"then assert(count==12 and math.abs(sum-100)<1e-9,"InvalidInitialMatrixSum")end
 if d.MatrixVersion=='TierAdjacentV3'then assert(count==12 and math.abs(sum-100)<1e-9 and d.DuplicatePolicy=='AllowDuplicates'and d.RequireAllWeightedVariations==true,'InvalidTierAdjacentMatrix')end
 assert(d.SoldOutPolicy=="ExcludeAndRenormalize","UnknownSoldOutPolicy")
 assert(d.DuplicatePolicy=="UniquePerPlayer" or d.DuplicatePolicy=="AllowDuplicates","UnapprovedDuplicatePolicy")
 assert(type(d.RollDuration)=="number" and d.RollDuration>=1 and d.RollDuration<=30,"InvalidDuration")
end)
Catalog.Rewards={}
for _,sid in ipairs(Catalog.Slaps.Order)do
 for _,vid in ipairs(Catalog.Slaps.ById[sid].VariationIds)do
  local v=Catalog.Variations.ById[vid];local id=sid..":"..vid
  Catalog.Rewards[id]={RewardId=id,SlapId=sid,VariationId=vid,DisplayName=Catalog.Slaps.ById[sid].DisplayName.." ["..v.DisplayName.."]",
   LimitedStock=false,TotalSupply=nil,EditionId=nil}
 end
end
local stock=require(script.Parent.StockDefinitions)
for id,definition in pairs(stock.Rewards)do
 local reward=assert(Catalog.Rewards[id],"UnknownStockReward:"..id)
 reward.LimitedStock=definition.LimitedStock;reward.TotalSupply=definition.TotalSupply;reward.EditionId=definition.EditionId
end
for id,definition in pairs(stock.Variations)do
 local variation=assert(Catalog.Variations.ById[id],"UnknownStockVariation:"..id)
 variation.LimitedStock=definition.LimitedStock;variation.DefaultStock=definition.DefaultStock;variation.EditionId=definition.EditionId
end
-- Production hard gate: requires a reviewed durable profile journal/session owner backend.
Catalog.ProductionCommerceEnabled=false
Catalog.DefaultRewardId="Classic:Basic"
return Catalog
]====]
Sources["CrateDefinitions"]=[====[--!nonstrict
local Matrix=require(script.Parent.InitialOdds)
local definitions={}
for _,entry in ipairs({{Id="Basic",SortOrder=10,PriceCoins=500},{Id="Common",SortOrder=20,PriceCoins=1000},{Id="Uncommon",SortOrder=30,PriceCoins=1750},
 {Id="Rare",SortOrder=40,PriceCoins=3000},{Id="Gold",SortOrder=50,PriceCoins=4500},{Id="Arcoiris",SortOrder=60,PriceCoins=7000},{Id="Emote",SortOrder=70,PriceCoins=10000},
 {Id="Wings",SortOrder=80,PriceCoins=13500},{Id="Epic",SortOrder=90,PriceCoins=19000},{Id="Legendary",SortOrder=100,PriceCoins=27500},{Id="Blood",SortOrder=110,PriceCoins=37500},{Id="Galaxy",SortOrder=120,PriceCoins=50000}}) do
 local id=entry.Id
  table.insert(definitions,{CrateId=id,SortOrder=entry.SortOrder,DisplayName="Caja "..id,Description="Variación de la caja: 60%; vecinas: 20% cada una. Extremos: 80% propia y 20% vecina. Modelo aleatorio; admite duplicados.",
  Icon="",Model=id,PriceCoins=entry.PriceCoins,PriceApproved=true,OddsApproved=true,ApprovalStatus="TierAdjacentV3Approved",
  Enabled=true,MatrixVersion="TierAdjacentV3",RollDuration=5,AnimationProfile="Horizontal",VFX=id,SFX="Reveal",Weights=Matrix.WeightsFor(id),
  DuplicatePolicy="AllowDuplicates",RequireAllWeightedVariations=true,SoldOutPolicy="ExcludeAndRenormalize",StockRules={}})
end
-- Isolated fixture only. Never in production catalog and disabled unless a server Edit flag is enabled.
table.insert(definitions,{CrateId="StudioTest",SortOrder=1000,DisplayName="PRUEBA LOCAL — Caja",Description="Solo InMemory. 1 Coin y pesos 3:1 ilustrativos; sin valor comercial.",
 Icon="",Model="Basic",PriceCoins=1,PriceApproved=true,OddsApproved=true,ApprovalStatus="IsolatedFixture",
 Enabled=true,StudioOnly=true,RollDuration=4,AnimationProfile="Horizontal",VFX="Basic",SFX="Reveal",
 Weights={Basic=3,Common=1},DuplicatePolicy="AllowDuplicates",SoldOutPolicy="ExcludeAndRenormalize",StockRules={}})
for _,premium in ipairs(require(script.Parent.PremiumCrateDefinitions))do table.insert(definitions,premium)end
return definitions
]====]
Sources["CrateShopView"]=[====[--!nonstrict
-- Public presentation only. Every mutation is still independently authorised by the server.
local View={}
-- Keep configured tier percentages intact when a required model/variation pool is missing.
View.Errors={CommercialApprovalPending="Precio o probabilidades pendientes de aprobación.",ProductionBackendBlocked="Ventas productivas bloqueadas.",
 RequiredVariationUnavailable="Faltan recursos de una variación necesaria. La caja no puede abrirse con sus probabilidades aprobadas.",
 PaidRandomItemsRestricted="Compra aleatoria restringida o elegibilidad no verificable.",OddsChanged="Probabilidades modificadas: consultalas otra vez.",
 ViewOddsFirst="Consultá las probabilidades vigentes.",LobbyOnly="Solo disponible en el lobby.",InsufficientFunds="Coins insuficientes.",
 NoCrate="No tenés cajas cerradas.",NoEligibleResults="No hay resultados elegibles.",SoldOut="Stock agotado.",StockUnknown="Stock no verificable.",
 RateLimited="Esperá un momento y reintentá.",DataNotLoaded="Esperá a que cargue tu perfil.",CrateUnavailable="Caja no disponible.",
 NoResponse="Sin confirmación: reintentá la misma operación.",InternalError="No se pudo confirmar la operación; reintentá.",
 TransactionInProgress="Hay una operación en curso.",JournalCapacityReached="Inventario de operaciones completo.",ProfileChanged="Tu perfil cambió; volvé a consultar.",
 InvalidStandId="Acercate al stand e interactuá para abrir.",StandTooFar="Estás demasiado lejos del stand.",
 StandBusy="Stand en uso. Esperá tu turno.",StandCooldown="Esperá a que termine tu espera personal del stand.",OpeningInProgress="Ya tenés una apertura en curso.",
 StandDisabled="Stand deshabilitado.",StandLeaseExpired="La reserva del stand venció. Volvé a interactuar.",
 InvalidOpeningConfig="Configuración de apertura no válida.",CharacterUnavailable="Esperá a que tu personaje esté disponible.",
 InvalidQuantity="Seleccioná x1, x5 o x10.",InsufficientCrates="No tenés suficientes cajas para el lote completo.",
 MultiOpenStandOnly="La apertura múltiple requiere el stand.",
 StockCommitPending="Premios conservados: reintentá la misma operación para confirmar el stock.",
 ProfileCommitFailed="No se consumieron cajas. Reintentá la operación."}
local function finite(n)return type(n)=="number"and n==n and math.abs(n)<math.huge end
function View.SortProducts(list,category)
 table.sort(list,function(a,b)
  if category=="Crates"then
   local x=if finite(a.SortOrder)then a.SortOrder else math.huge
   local y=if finite(b.SortOrder)then b.SortOrder else math.huge
   return if x==y then tostring(a.Id)<tostring(b.Id)else x<y
  end
  if a.Price==b.Price then return tostring(a.Id)<tostring(b.Id)end
  return(a.Price or 0)<(b.Price or 0)
 end)
 return list
end
function View.State(product,snapshot,quote,now,busy)
 local m=product.Metadata or {};local price=product.Price
 if quote and quote.Ok and finite(quote.PriceCoins)then price=quote.PriceCoins end
 local priceApproved=m.PriceApproved==true and finite(price)and price>0 and price%1==0
 if m.PremiumOnly then priceApproved=true end -- Opening a previously owned Premium box never charges Coins.
 local data=snapshot or {};local count=data.Inventory and data.Inventory.Crates and data.Inventory.Crates[product.Id]or 0
 local coins=data.Coins
 local state={Quantity=if finite(count)and count>=0 then count else 0,Price=price,
  PriceText=if m.PremiumOnly then "Solo Tienda Premium"elseif priceApproved then string.format("%d Coins",price)else "Precio pendiente",
  CoinsText=if finite(coins)then tostring(coins).." Coins"else "—",BuyText="COMPRAR",OpenText="ABRIR",
  BuyEnabled=false,OpenEnabled=false,StockText="Stock: consultar",Status="Consultá probabilidades",Badge="CONSULTAR",NeedQuote=true}
 if (m.PricePending==true and not m.PremiumOnly)or not priceApproved then state.Status="Precio pendiente";state.Badge="PENDIENTE"
 elseif m.OddsApproved~=true then state.Status="Probabilidades pendientes";state.Badge="PENDIENTE"
 elseif product.IsAvailable==false or m.Enabled~=true or (if m.PremiumOnly then m.OpeningEnabled~=true else m.PurchaseEnabled~=true)then state.Status="Caja no disponible";state.Badge="BLOQUEADA"
 elseif quote and not quote.Ok then
  state.Status=View.Errors[quote.Code]or tostring(quote.Code);state.Badge="NO DISP."
  if quote.Code=="NoEligibleResults"or quote.Code=="SoldOut"then state.StockText="Sin resultados disponibles"end
 elseif not quote or not finite(quote.ExpiresAt)or now>=quote.ExpiresAt then
  state.Status=if quote then "Quote vencido: consultá probabilidades"else "Consultá probabilidades para comprar"
 elseif not finite(coins)then state.Status="Esperá a que cargue tu saldo"
 else
  local total=0;local seen={};local valid=type(quote.Outcomes)=="table"and #quote.Outcomes>0
  for _,row in ipairs(quote.Outcomes or {})do
   if type(row.RewardId)~="string"or seen[row.RewardId]or not finite(row.Percent)or row.Percent<0 or type(row.Stock)~="table"then valid=false
   else total+=row.Percent;seen[row.RewardId]=true end
  end
  if not valid or math.abs(total-100)>.000001 then state.Status="Probabilidades no verificables";state.Badge="NO DISP.";return state end
  state.NeedQuote=false
  state.BuyEnabled=not m.PremiumOnly and coins>=price;state.OpenEnabled=state.Quantity>0
  state.Status=if m.PremiumOnly then "Apertura desde el stand; compra solo en Premium"elseif state.BuyEnabled then "Disponible"else "Coins insuficientes"
  state.Badge=if state.Quantity>0 then tostring(state.Quantity).." cajas"elseif state.BuyEnabled then "DISPONIBLE"else "SIN SALDO"
  local unlimited=true
  for _,row in ipairs(quote.Outcomes or {})do if not row.Stock.UnlimitedStock then unlimited=false end end
  state.StockText=if unlimited then "Stock: Ilimitado"else "Stock: ver probabilidades"
 end
 if busy then state.BuyEnabled=false;state.OpenEnabled=false;state.Status="Procesando…"end
 return state
end
return View
]====]
Sources["InitialOdds"]=[====[--!nonstrict
-- Approved tier-relative balance: own 60%, immediate neighbours 20% each.
-- At either boundary the missing neighbour's weight goes to the crate's own tier (80/20).
local Matrix={VariationOrder={"Basic","Common","Uncommon","Rare","Gold","Arcoiris","Emote","Wings","Epic","Legendary","Blood","Galaxy"},Rows={
}}
for index,id in ipairs(Matrix.VariationOrder)do
 local row=table.create(#Matrix.VariationOrder,0)
 row[index]=60
 if index>1 then row[index-1]=20 else row[index]+=20 end
 if index<#Matrix.VariationOrder then row[index+1]=20 else row[index]+=20 end
 Matrix.Rows[id]=row
end
function Matrix.WeightsFor(id)
 local row=assert(Matrix.Rows[id],"UnknownMatrixCrate:"..tostring(id))
 local weights={} for i,vid in ipairs(Matrix.VariationOrder)do weights[vid]=row[i]end
 return weights
end
return Matrix
]====]
Sources["Inventory"]=[====[--!nonstrict
local Inventory={}
function Inventory.Copy(value)
 if type(value)~="table" then return value end
 local result={} for k,v in pairs(value)do result[k]=Inventory.Copy(v)end return result
end
function Inventory.Extend(raw)
 local inv=Inventory.Copy(raw or {Owned={},Equipped={}})
 inv.Owned=inv.Owned or {};inv.Equipped=inv.Equipped or {}
 inv.Owned.Slaps=inv.Owned.Slaps or {};inv.Owned.Slaps["Classic:Basic"]=true
 -- Legacy base ownership preserved and represented only as its Basic cosmetic.
 for id,owned in pairs(inv.Owned.Slaps)do if owned==true and not id:find(":",1,true)then inv.Owned.Slaps[id..":Basic"]=true end end
 inv.Equipped.Slaps=inv.Equipped.Slaps or "Classic:Basic"
 inv.Crates=inv.Crates or {};inv.SlapUnits=inv.SlapUnits or {};inv.CrateOperations=inv.CrateOperations or {}
 return inv
end
-- Preserve rich fields, including unknown future units, without a destructive migration.
function Inventory.Preserve(raw, sanitized)
 for _,key in ipairs({"Crates","SlapUnits","CrateOperations","PremiumReceipts","PremiumPurchases"})do
  if raw and raw[key]~=nil then sanitized[key]=Inventory.Copy(raw[key]) end
 end
 return Inventory.Extend(sanitized)
end
function Inventory.Validate(inv)
 for _,key in ipairs({"Crates","SlapUnits","CrateOperations"})do if type(inv[key])~="table" then return false,"InvalidCrateInventory" end end
 for id,n in pairs(inv.Crates)do if type(id)~="string" or type(n)~="number" or n<0 or n%1~=0 or n==math.huge then return false,"InvalidCrateInventory" end end
 local count=0 for _,op in pairs(inv.CrateOperations)do
  if type(op)~="table" then return false,"InvalidCrateInventory" end;count+=1
 end
 if count>=256 then return false,"JournalCapacityReached" end
 return true
end
return Inventory
]====]
Sources["Odds"]=[====[--!nonstrict
-- Weight of a variation is divided equally among its currently eligible base Slaps.
local Odds={}
function Odds.Resolve(crate,catalog,inventory,stock,resourcesAvailable)
 local results={};local excluded={};local total=0;local hasWeights=false
 for vid,weight in pairs(crate.Weights)do
  hasWeights=true
  if not catalog.Variations.ById[vid] or type(weight)~="number" or weight~=weight or weight<0 or weight==math.huge then return nil,"InvalidWeights" end
  if weight==0 then continue end
  local candidates={}
  for id,reward in pairs(catalog.Rewards)do
   if reward.VariationId~=vid then continue end
   if crate.DuplicatePolicy=="UniquePerPlayer" and inventory.Owned.Slaps[id] then table.insert(excluded,{Reward=reward,Reason="AlreadyOwned"});continue end
   if resourcesAvailable and not resourcesAvailable(reward)then table.insert(excluded,{Reward=reward,Reason="ResourceUnavailable"});continue end
   local view,reason=stock:View(reward,catalog.Variations.ById[vid])
   if not view then return nil,reason or "StockUnknown" end
   if not view.SoldOut then table.insert(candidates,{Reward=reward,Stock=view})else table.insert(excluded,{Reward=reward,Stock=view,Reason="SoldOut"})end
  end
  if #candidates==0 and crate.RequireAllWeightedVariations then return nil,'RequiredVariationUnavailable',excluded end
  for _,row in ipairs(candidates)do row.Weight=weight/#candidates;total+=row.Weight;table.insert(results,row)end
 end
 if not hasWeights or total<=0 or total==math.huge then return nil,"NoEligibleResults",excluded end
 table.sort(results,function(a,b)return a.Reward.RewardId<b.Reward.RewardId end)
 for _,row in ipairs(results)do row.Probability=row.Weight/total;row.Percent=row.Probability*100 end
 return results,nil,excluded
end
function Odds.Roll(results,unit)
 assert(type(unit)=="number" and unit>=0 and unit<1,"InvalidRandom")
 local sum=0 for _,row in ipairs(results)do sum+=row.Probability;if unit<sum then return row.Reward end end
 return results[#results].Reward
end
return Odds
]====]
Sources["OddsPresentation"]=[====[--!nonstrict
-- Formats the authoritative Quote only; never estimates, samples or grants rewards.
local Presentation={}
local reasons={SoldOut="AGOTADO",AlreadyOwned="YA ADQUIRIDO",ResourceUnavailable="RECURSO NO DISPONIBLE"}
function Presentation.Rows(quote)
 local entries={}
 for _,row in ipairs(quote.Outcomes or {})do table.insert(entries,{Row=row,Excluded=false})end
 for _,row in ipairs(quote.ExcludedOutcomes or {})do table.insert(entries,{Row=row,Excluded=true})end
 table.sort(entries,function(a,b)
  local x,y=a.Row.SortOrder or math.huge,b.Row.SortOrder or math.huge
  return if x==y then tostring(a.Row.RewardId)<tostring(b.Row.RewardId)else x<y
 end)
 local result={}
 for _,entry in ipairs(entries)do
  local row=entry.Row;local stock=row.Stock
  local status=if entry.Excluded then reasons[row.Reason]or tostring(row.Reason)
   elseif stock and stock.UnlimitedStock then "Ilimitado"else tostring(stock and stock.RemainingStock or "?").." disponibles"
  local amount=if entry.Excluded then "0"else string.format("%.10g",row.Percent)
  table.insert(result,{Text=(row.SlapName or row.SlapId or row.DisplayName).." · "..(row.VariationName or row.VariationId or "").." — "..amount.." %\n"..status,
   Color=row.Color,RewardId=row.RewardId,Excluded=entry.Excluded})
 end
 return result
end
return Presentation
]====]
Sources["OpeningConfig"]=[====[--!nonstrict
-- Server selects the mode. No client request can override it.
return {
 Mode="StandCinematic",
 AllowedOpenQuantities={1,5,10},
 BatchRevealDurations={[5]=4,[10]=5},
 RewardSpin={SpinDuration=3.6,InitialSpeed=16,DecelerationDuration=2.6,VisiblePreviewCount=5,
  ItemSpacing=2.5,WinningItemScale=1.1,FinalPauseDuration=2.4,MaxPreviewExtent=1.8},
 Stand={Enabled=true,ExclusiveOpening=false,ReopenCooldown=0,SpectatorRadius=80,
  MaxSequenceDuration=25,MaxActivationDistance=10,MaxIdleCrates=3},
 Cinematic={IntroTransitionDuration=.7,CameraRevealDuration=.6,ChestAppearDuration=1,
  ChestRiseDuration=2,ChestGrowthDuration=1,ChestShakeDuration=1,FlashDuration=.5,
  RewardRevealDuration=3,OutroTransitionDuration=.7},
}
]====]
Sources["OpeningTimeline"]=[====[--!nonstrict
local Timeline={}
local stages={{"Intro","IntroTransitionDuration"},{"CameraReveal","CameraRevealDuration"},
 {"Appear","ChestAppearDuration"},{"Rise","ChestRiseDuration"},{"Growth","ChestGrowthDuration"},
 {"Shake","ChestShakeDuration"},{"Flash","FlashDuration"},{"Reward","RewardRevealDuration"},
 {"Outro","OutroTransitionDuration"}}
function Timeline.Build(config,quantity)
 if type(config)~="table"or(config.Mode~="Spin"and config.Mode~="StandCinematic")then return nil,"InvalidOpeningConfig"end
 local stand,c=config.Stand,config.Cinematic
 if type(stand)~="table"or type(c)~="table"or type(stand.Enabled)~="boolean"or type(stand.ExclusiveOpening)~="boolean"then return nil,"InvalidOpeningConfig"end
 for _,key in ipairs({"ReopenCooldown","SpectatorRadius","MaxSequenceDuration","MaxActivationDistance","MaxIdleCrates"})do
  local v=stand[key];if type(v)~="number"or v~=v or v<0 or v==math.huge then return nil,"InvalidOpeningConfig"end
 end
 if stand.MaxActivationDistance<=0 or stand.MaxActivationDistance>20 or stand.SpectatorRadius>150
  or stand.MaxIdleCrates%1~=0 or stand.MaxIdleCrates>6 or stand.MaxSequenceDuration>60 then return nil,"InvalidOpeningConfig"end
 local plan={Stages={},Duration=0}
 for _,row in ipairs(stages)do
  local d=if row[1]=="Reward"and (quantity or 1)>1 and config.BatchRevealDurations then config.BatchRevealDurations[quantity]else c[row[2]]
  if row[1]=="Reward"and config.Mode=="StandCinematic"and(quantity or 1)==1 and config.RewardSpin then
   local spin=config.RewardSpin
   for _,key in ipairs({"SpinDuration","FinalPauseDuration","DecelerationDuration","InitialSpeed","VisiblePreviewCount","ItemSpacing","WinningItemScale","MaxPreviewExtent"})do
    local n=spin[key];if type(n)~="number"or n~=n or n<=0 or n==math.huge then return nil,"InvalidOpeningConfig"end
   end
   if spin.DecelerationDuration>spin.SpinDuration then return nil,"InvalidOpeningConfig"end
   d=math.max(d,spin.SpinDuration+spin.FinalPauseDuration)
  end
  if type(d)~="number"or d~=d or d<=0 or d>10 then return nil,"InvalidOpeningConfig"end
  table.insert(plan.Stages,{Name=row[1],Start=plan.Duration,Duration=d});plan.Duration+=d
 end
 if plan.Duration>stand.MaxSequenceDuration then return nil,"InvalidOpeningConfig"end
 return plan
end
function Timeline.At(plan,elapsed)
 for _,stage in ipairs(plan.Stages)do if elapsed<stage.Start+stage.Duration then
  return stage.Name,math.clamp((elapsed-stage.Start)/stage.Duration,0,1)
 end end
 return "Done",1
end
return Timeline
]====]
Sources["PremiumCrateDefinitions"]=[====[-- Exactly three draft tiers. Empty weights mean NOT CONFIGURED, not zero-percent commercial odds.
local definitions={}
for i,id in ipairs({"PremiumI","PremiumII","PremiumIII"})do
 table.insert(definitions,{CrateId=id,SortOrder=2000+i*10,DisplayName="Premium "..({"I","II","III"})[i],
  Description="Caja Premium provisional. Contenidos, probabilidades, precio y venta pendientes.",Icon="",Model=id,
  PremiumOnly=true,PriceCoins=nil,PriceApproved=false,OddsApproved=false,OpeningApproved=false,Enabled=false,
  ApprovalStatus="PremiumApprovalPending",RollDuration=5,AnimationProfile="Horizontal",VFX=id,SFX="Reveal",Weights={},
  DuplicatePolicy="UniquePerPlayer",SoldOutPolicy="ExcludeAndRenormalize",StockRules={}})
end
return definitions
]====]
Sources["Registry"]=[====[--!nonstrict
-- Only modules explicitly required by Catalog are trusted; never require descendants dynamically.
local Registry = {}
function Registry.Build(definitions, key, validate)
 local result = {Order={}, ById={}}
 for _,definition in ipairs(definitions) do
  local id=definition[key]
  assert(type(id)=="string" and id:match("^[%w_%-]+$"),"InvalidId")
  assert(not result.ById[id],"DuplicateId:"..id)
  assert(type(definition.DisplayName)=="string" and definition.DisplayName~="","InvalidName")
  if validate then validate(definition) end
  result.ById[id]=definition;table.insert(result.Order,id)
 end
 return result
end
return Registry
]====]
Sources["SlapDefinitions"]=[====[--!nonstrict
-- Runtime metadata is produced by the server from validated physical Tools, never client claims.
local rs=game and game:GetService('ReplicatedStorage');local run=game and game:GetService('RunService')
if run and type(run.IsClient)=='function'and run:IsClient()and run:IsRunning()then
 local deadline=os.clock()+20
 while rs:GetAttribute('SlapCatalogReady')~=true do assert(os.clock()<deadline,'SlapCatalogNotReady');task.wait()end
end
local root=rs and type(rs.FindFirstChild)=='function'and rs:FindFirstChild('SlapCatalog')
if root then
 local definitions={}
 for _,entry in ipairs(root:GetChildren())do
  if entry:IsA('Folder')then
   local variants={};local folder=entry:FindFirstChild('Variations')
   if folder then for _,v in ipairs(folder:GetChildren())do if v:IsA('Folder')then table.insert(variants,v.Name)end end end
   table.sort(variants)
   table.insert(definitions,{SlapId=entry.Name,DisplayName=entry:GetAttribute('DisplayName'),Model=entry:GetAttribute('Model'),VariantsFolder=entry:GetAttribute('VariantsFolder'),VariationIds=variants})
  end
 end
 table.sort(definitions,function(a,b)return a.SlapId<b.SlapId end)
 return definitions
end
if run and type(run.IsRunning)=='function'and run:IsRunning()then error('PhysicalSlapCatalogMissing')end
-- Offline fixture/Edit fallback only. Production/clients never silently use it at runtime.
return {{SlapId="Classic",DisplayName="Clásico",Model="Classic",VariationIds={
 "Basic","Common","Uncommon","Rare","Gold","Arcoiris","Emote","Wings","Epic","Legendary","Blood","Galaxy"}}}
]====]
Sources["StockDefinitions"]=[====[--!nonstrict
-- No approved limited editions yet. Never change an existing edition supply to restock it.
-- Rewards[RewardId] = {LimitedStock=true, TotalSupply=<approved>, EditionId=<immutable id>}
-- Variations[VariationId] = {LimitedStock=true, DefaultStock=<approved>, EditionId=<immutable id>}
return {Rewards={},Variations={}}
]====]
Sources["VariationDefinitions"]=[====[--!nonstrict
-- Generated cosmetic manifest. Commercial settings remain unchanged.
return {
 {Id="Basic",DisplayName="Basic",Description="Original sin efectos extraordinarios",SortOrder=1,Color=Color3.fromRGB(248,248,248),Icon="",VisualProfile="Basic",VFX="Basic",SFX="Reveal",AnnounceInChat=false,LimitedStock=false,DefaultStock=nil,AdditionalConfig={DesignPending=true}},
 {Id="Common",DisplayName="Common",Description="Plateado discreto",SortOrder=2,Color=Color3.fromRGB(202,209,218),Icon="",VisualProfile="Common",VFX="Common",SFX="Reveal",AnnounceInChat=false,LimitedStock=false,DefaultStock=nil,AdditionalConfig={DesignPending=true}},
 {Id="Uncommon",DisplayName="Uncommon",Description="Energía verde suave",SortOrder=3,Color=Color3.fromRGB(65,190,100),Icon="",VisualProfile="Uncommon",VFX="Uncommon",SFX="Reveal",AnnounceInChat=false,LimitedStock=false,DefaultStock=nil,AdditionalConfig={DesignPending=true}},
 {Id="Rare",DisplayName="Rare",Description="Energía azul y brillo tenue",SortOrder=4,Color=Color3.fromRGB(69,138,255),Icon="",VisualProfile="Rare",VFX="Rare",SFX="Reveal",AnnounceInChat=false,LimitedStock=false,DefaultStock=nil,AdditionalConfig={DesignPending=true}},
 {Id="Gold",DisplayName="Gold",Description="Metal dorado y destellos moderados",SortOrder=5,Color=Color3.fromRGB(239,187,62),Icon="",VisualProfile="Gold",VFX="Gold",SFX="Reveal",AnnounceInChat=false,LimitedStock=false,DefaultStock=nil,AdditionalConfig={DesignPending=true}},
 {Id="Arcoiris",DisplayName="Arcoiris",Description="Partículas multicolores sin bucles de servidor",SortOrder=6,Color=Color3.fromRGB(245,245,245),Icon="",VisualProfile="Arcoiris",VFX="Arcoiris",SFX="Reveal",AnnounceInChat=false,LimitedStock=false,DefaultStock=nil,AdditionalConfig={DesignPending=true}},
 {Id="Emote",DisplayName="Emote",Description="Símbolo expresivo rosa; sin sistema de emotes",SortOrder=7,Color=Color3.fromRGB(220,93,180),Icon="",VisualProfile="Emote",VFX="Emote",SFX="Reveal",AnnounceInChat=false,LimitedStock=false,DefaultStock=nil,AdditionalConfig={DesignPending=true}},
 {Id="Wings",DisplayName="Wings",Description="Dos plumas de energía celeste; sin vuelo",SortOrder=8,Color=Color3.fromRGB(151,218,255),Icon="",VisualProfile="Wings",VFX="Wings",SFX="Reveal",AnnounceInChat=false,LimitedStock=false,DefaultStock=nil,AdditionalConfig={DesignPending=true}},
 {Id="Epic",DisplayName="Epic",Description="Energía violeta intensa",SortOrder=9,Color=Color3.fromRGB(145,58,225),Icon="",VisualProfile="Epic",VFX="Epic",SFX="Reveal",AnnounceInChat=false,LimitedStock=false,DefaultStock=nil,AdditionalConfig={DesignPending=true}},
 {Id="Legendary",DisplayName="Legendary",Description="Aura dorada anaranjada moderada",SortOrder=10,Color=Color3.fromRGB(255,156,37),Icon="",VisualProfile="Legendary",VFX="Legendary",SFX="Reveal",AnnounceInChat=false,LimitedStock=false,DefaultStock=nil,AdditionalConfig={DesignPending=true}},
 {Id="Blood",DisplayName="Blood",Description="Energía roja y negra, sin gore",SortOrder=11,Color=Color3.fromRGB(125,24,45),Icon="",VisualProfile="Blood",VFX="Blood",SFX="Reveal",AnnounceInChat=false,LimitedStock=false,DefaultStock=nil,AdditionalConfig={DesignPending=true}},
 {Id="Galaxy",DisplayName="Galaxy",Description="Estrellas azules, violetas y blancas",SortOrder=12,Color=Color3.fromRGB(38,31,83),Icon="",VisualProfile="Galaxy",VFX="Galaxy",SFX="Reveal",AnnounceInChat=false,LimitedStock=false,DefaultStock=nil,AdditionalConfig={DesignPending=true}},
}
]====]
Sources["PersonalInventory"]=[====[--!nonstrict
-- Own-only projection. No balances, trade journals or other players' inventories.
local Public=require(script.Parent.PublicInventory)
local View={Categories={Slaps=true,DeathEffects=true,PointEffects=true,Crates=true}}
function View.Valid(category,page,query)
 return type(category)=='string' and View.Categories[category]==true
  and type(page)=='number' and page==page and page%1==0 and page>=1 and page<=10000
  and type(query)=='string' and #query<=80
end
function View.Build(data,userId,catalog,category,products,crateProducts,page,query,pageSize)
 local rows={}
 if category=='Slaps' then
  local grouped={}
  for _,item in ipairs(Public.Build(data,userId,catalog))do
   local prior=grouped[item.ProductId]
   if prior then prior.Quantity+=1 else
    local row=table.clone(item);row.UnitId=nil;row.EntryId=row.ProductId;row.Quantity=1
    grouped[row.ProductId]=row;table.insert(rows,row)
   end
  end
 elseif category=='Crates' then
  local counts=data.Inventory and data.Inventory.Crates or {}
  for _,product in ipairs(crateProducts or {})do
   local n=counts[product.Id]
   if type(n)=='number' and n==n and n>0 and n<math.huge then
    table.insert(rows,{Category='Crates',ProductId=product.Id,EntryId=product.Id,DisplayName=product.DisplayName,
     Rarity=product.Rarity,Icon=product.Icon,Quantity=math.floor(n),Owned=true,Available=product.IsAvailable,
     Description=product.Description,Product=product})
   end
  end
 else rows=Public.Effects(data,category,products)end
 local total=#rows;local filtered={};query=string.lower(query)
 for _,row in ipairs(rows)do
  if query=='' or string.find(string.lower(row.DisplayName or ''),query,1,true) or string.find(string.lower(row.VariationName or ''),query,1,true)then table.insert(filtered,row)end
 end
 table.sort(filtered,function(a,b)
  if a.Equipped~=b.Equipped then return a.Equipped==true end
  return a.DisplayName==b.DisplayName and a.ProductId<b.ProductId or a.DisplayName<b.DisplayName
 end)
 local pages=math.max(1,math.ceil(#filtered/pageSize));page=math.min(page,pages);local items={}
 for i=(page-1)*pageSize+1,math.min(#filtered,page*pageSize)do table.insert(items,filtered[i])end
 return {UserId=userId,Category=category,Items=items,Total=total,FilteredTotal=#filtered,Page=page,Pages=pages,HasNext=page<pages}
end
return View
]====]
Sources["PublicInventory"]=[====[--!nonstrict
local Policy=require(script.Parent.TradePolicy)
local View={}
function View.Build(data,uid,catalog)
 local inventory=data.Inventory or {};local equipped=inventory.Equipped and inventory.Equipped.Slaps
 local rows,represented={},{}
 local function row(reward,unit,key)
  local v=catalog.Variations.ById[reward.VariationId]
  local allowed,reason=false,'LegacyEntitlement'
  if unit then allowed,reason=Policy.Check(unit,inventory,uid,catalog)end
  return {Category='Slaps',ProductId=reward.RewardId,EntryId=key,UnitId=unit and unit.UnitId,RewardId=reward.RewardId,SlapId=reward.SlapId,VariationId=reward.VariationId,
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
function View.Effects(data,category,products)
 local inventory=data.Inventory or {};local owned=inventory.Owned and inventory.Owned[category]or {}
 local selected=inventory.Equipped and inventory.Equipped[category];local rows={}
 for _,product in ipairs(products or {})do
  if product.Category==category and owned[product.Id]==true then
   table.insert(rows,{Category=category,ProductId=product.Id,EntryId=category..':'..product.Id,
    DisplayName=product.DisplayName,VariationName=category=='PointEffects'and 'EFECTO DE PUNTO'or 'EFECTO DE MUERTE',
    Rarity=product.Rarity,Icon=product.Icon,Owned=true,Equipped=selected==product.Id,
    Available=product.IsAvailable==true,Tradable=false,Restriction='NonTradableCategory'})
  end
 end
 table.sort(rows,function(a,b)return a.ProductId<b.ProductId end);return rows
end
function View.Profile(player,data,catalog,config,page,category,products)
 category=category or 'Slaps';products=products or {}
 local slaps=View.Build(data,player.UserId,catalog)
 local point=View.Effects(data,'PointEffects',products.PointEffects)
 local death=View.Effects(data,'DeathEffects',products.DeathEffects)
 local all=category=='Slaps'and slaps or category=='PointEffects'and point or death
 page=math.min(page,math.max(1,math.ceil(#all/config.InventoryPageSize)))
 local start=(page-1)*config.InventoryPageSize+1;local entries={}
 for i=start,math.min(#all,start+config.InventoryPageSize-1)do table.insert(entries,all[i])end
 local equipped;for _,row in ipairs(slaps)do if row.Equipped then equipped=row;break end end
 local loadout={Slaps=equipped}
 for _,rows in ipairs({point,death})do for _,row in ipairs(rows)do if row.Equipped then loadout[row.Category]=row;break end end end
 local function stat(n)return type(n)=='number' and n==n and n>=0 and n<math.huge and math.floor(n)or 0 end
 return {UserId=player.UserId,DisplayName=player.DisplayName,Username=player.Name,
  Stats={Wins=stat(data.Wins),Losses=stat(data.Losses),TotalKills=stat(data.Kills),Streaks=stat(type(data.WinStreak)=='table'and data.WinStreak.Total)},
  EquippedSlap=equipped,EquippedLoadout=loadout,Category=category,CategoryCounts={Slaps=#slaps,PointEffects=#point,DeathEffects=#death},Progression={Available=false,Status='Nivel y EXP pendientes'},Inventory=entries,Page=page,TotalItems=#all,
  HasNext=start+#entries<=#all,TradeCommitEnabled=false}
end
return View
]====]
Sources["TradeEngine"]=[====[--!nonstrict
-- No yielding or inventory writes. Transport/clock/player state are injected for deterministic tests.
local Engine={};Engine.__index=Engine
local function copy(x)if type(x)~='table'then return x end;local y={};for k,v in pairs(x)do y[k]=copy(v)end;return y end
function Engine.new(config,deps)return setmetatable({C=config,D=deps,Trades={},Busy={},Reserved={},Cooldown={}},Engine)end
function Engine:_pair(a,b,near)
 if a==b then return false,'SelfTarget' end
 if not self.D.Eligible(a)or not self.D.Eligible(b)then return false,'PlayerUnavailable' end
 if near then local distance=self.D.Distance(a,b);if type(distance)~='number'or not(distance<=self.C.InspectDistance)or distance<0 then return false,'OutOfRange'end end
 return true
end
function Engine:_publish(t)
 t.Sequence=(t.Sequence or 0)+1
 local function keys(values)local out={};for k,v in pairs(values)do out[tostring(k)]=copy(v)end;return out end
 local packet={TradeId=t.Id,State=t.State,Revision=t.Revision,A=t.A,B=t.B,
  Sequence=t.Sequence,Names={[tostring(t.A)]=self.D.Name(t.A),[tostring(t.B)]=self.D.Name(t.B)},Offers=keys(t.Offers),Accepted=keys(t.Accepted),Confirmed=keys(t.Confirmed),
  Deadline=t.Deadline,ExpiresAt=t.ExpiresAt,Reason=t.Reason,TradeCommitEnabled=false}
 self.D.Emit(t.A,'Trade',packet);self.D.Emit(t.B,'Trade',packet)
end
function Engine:_release(t)
 for _,uid in ipairs({t.A,t.B})do
  if self.Busy[uid]==t.Id then self.Busy[uid]=nil end
  for key,owner in pairs(self.Reserved)do if owner==t.Id then self.Reserved[key]=nil end end
 end
end
function Engine:_cancel(t,why)
 if t.Terminal or t.State=='Committing'then return false,'CannotCancel' end
 t.State='Cancelled';t.Reason=why;t.Terminal=true;t.FinishedAt=self.D.Clock();self:_release(t);self:_publish(t);return true
end
function Engine:Invite(a,b)
 local ok,why=self:_pair(a,b,true);if not ok then return false,why end
 if self.C.TradeInvitationsEnabled~=true then return false,'InvitationsDisabled' end
 if self.Busy[a]or self.Busy[b]then return false,'PlayerBusy' end
 local now=self.D.Clock();if (self.Cooldown[a]or 0)>now then return false,'InviteCooldown' end
 local id=self.D.Id();local t={Id=id,A=a,B=b,State='Requested',Revision=0,Offers={[a]={},[b]={}},Accepted={},Confirmed={},
  CreatedAt=now,ExpiresAt=now+self.C.InviteTimeoutSeconds,MaxUntil=now+self.C.MaxTradeSeconds}
 self.Cooldown[a]=now+self.C.InviteCooldownSeconds;self.Trades[id]=t;self.Busy[a]=id;self.Busy[b]=id
 self:_publish(t);return true,id
end
function Engine:_validateOffers(t)
 for _,uid in ipairs({t.A,t.B})do for _,row in ipairs(t.Offers[uid])do
  local current=self.D.Unit(uid,row.UnitId)
  if not current or not current.Tradable or current.RewardId~=row.RewardId or current.VariationId~=row.VariationId
   or self.Reserved[tostring(uid)..':'..row.UnitId]~=t.Id then return false,'OfferChangedOrUnavailable' end
 end end
 return true
end
function Engine:Act(uid,action,id,revision,item)
 local t=self.Trades[id]
 if not t or uid~=t.A and uid~=t.B then return false,'NotParticipant' end
 if t.Terminal then return false,'TradeClosed' end
 local valid,why=self:_pair(t.A,t.B,false);if not valid then self:_cancel(t,why);return false,why end
 local now=self.D.Clock()
 if now>=t.MaxUntil or t.State=='Requested'and now>=t.ExpiresAt then self:_cancel(t,'Expired');return false,'Expired' end
 if revision~=t.Revision then return false,'StaleRevision' end
 if action=='Cancel'then return self:_cancel(t,'CancelledByPlayer')end
 if action=='Respond'then
  if t.State~='Requested'or uid~=t.B then return false,'InvalidAcceptance' end
  if item~=true then return self:_cancel(t,'InvitationDeclined')end
  local near,err=self:_pair(t.A,t.B,true);if not near then self:_cancel(t,err);return false,err end
  t.State='Negotiating';self:_publish(t);return true
 end
 if action=='Add'or action=='Remove'then
  if t.State~='Negotiating'then return false,'OffersLocked' end
  if type(item)~='string'or #item>256 then return false,'InvalidUnitId' end
  local rows=t.Offers[uid];local at
  for i,row in ipairs(rows)do if row.UnitId==item then at=i end end
  local key=tostring(uid)..':'..item
  if action=='Add'then
   if at then return false,'DuplicateUnit' end
   if #rows>=self.C.MaxSlapsPerSide then return false,'OfferFull' end
   local row=self.D.Unit(uid,item)
   if not row or not row.Tradable then return false,'ItemNotTradable' end
   if self.Reserved[key]and self.Reserved[key]~=id then return false,'UnitReserved' end
   self.Reserved[key]=id;table.insert(rows,copy(row))
  else
   if not at then return false,'NotOffered' end
   table.remove(rows,at);self.Reserved[key]=nil
  end
  t.Revision+=1;t.Accepted={};t.Confirmed={};t.Deadline=nil
 elseif action=='Accept'then
  if t.State~='Negotiating'then return false,'InvalidState' end
  local ok,err=self:_validateOffers(t);if not ok then self:_cancel(t,err);return false,err end
  if #t.Offers[t.A]+#t.Offers[t.B]==0 then return false,'EmptyTrade' end
  t.Accepted[uid]=true
  if t.Accepted[t.A]and t.Accepted[t.B]then t.State='SafetyCountdown';t.Deadline=now+self.C.SafetyCountdownSeconds end
 elseif action=='Confirm'then
  if t.State~='FinalConfirmation'or not t.Deadline or now<t.Deadline then return false,'FinalConfirmationNotReady' end
  local ok,err=self:_validateOffers(t);if not ok then self:_cancel(t,err);return false,err end
  t.Confirmed[uid]=true
  if t.Confirmed[t.A]and t.Confirmed[t.B]then
   -- Never display Completed for a simulation and never manufacture a durable journal.
   t.BothConfirmations=true
   local committed,reason=self.D.Commit({TradeId=t.Id,Revision=t.Revision,A=t.A,B=t.B,Offers=copy(t.Offers)})
   assert(not committed,'Real transfers are not installed in V1.0')
   return self:_cancel(t,reason or 'TradeCommitDisabled')
  end
 else return false,'UnknownAction' end
 self:_publish(t);return true
end
function Engine:Tick()
 local now=self.D.Clock()
 for id,t in pairs(self.Trades)do
  if t.Terminal then if now-t.FinishedAt>=self.C.TerminalRetentionSeconds then self.Trades[id]=nil end
  elseif not self.D.Eligible(t.A)or not self.D.Eligible(t.B)then self:_cancel(t,'PlayerUnavailable')
  elseif now>=t.MaxUntil or t.State=='Requested'and now>=t.ExpiresAt then self:_cancel(t,'Expired')
  elseif t.State=='SafetyCountdown'and now>=t.Deadline then
   local ok,why=self:_validateOffers(t);if not ok then self:_cancel(t,why)else t.State='FinalConfirmation';self:_publish(t)end
  end
 end
end
function Engine:CancelForPlayer(uid)
 local t=self.Trades[self.Busy[uid]];if t then self:_cancel(t,'PlayerUnavailable')end
end
function Engine:Disconnect(uid)
 self:CancelForPlayer(uid);self.Cooldown[uid]=nil
end
return Engine
]====]
Sources["TradePolicy"]=[====[--!nonstrict
-- Explicit ordinary crate provenance only. Legacy entitlements are never tradable units.
local Policy={}
Policy.AllowedSlapIds={Classic=true}
Policy.NonTradableSlapIds={}
Policy.AllowedVariationIds={Common=true,Uncommon=true,Rare=true,Gold=true,Arcoiris=true,Emote=true,Wings=true,Epic=true,Legendary=true,Blood=true,Galaxy=true}
Policy.NonTradableRewardIds={['Classic:Basic']=true}
Policy.NonTradableSourceTypes={Premium=true,Temporary=true,Test=true,Reward=true}
function Policy.Check(unit,inventory,uid,catalog)
 if type(unit)~='table' or type(unit.UnitId)~='string' or unit.OwnerUserId~=uid then return false,'OwnershipMismatch' end
 local reward=catalog.Rewards[unit.RewardId]
 if not reward or reward.SlapId~=unit.SlapId or reward.VariationId~=unit.VariationId then return false,'InvalidVariation' end
 if type(inventory.Owned)~='table' or type(inventory.Owned.Slaps)~='table' or inventory.Owned.Slaps[unit.RewardId]~=true then return false,'NotOwned' end
 local variation=catalog.Variations.ById[unit.VariationId]
 if not Policy.AllowedSlapIds[unit.SlapId]or Policy.NonTradableSlapIds[unit.SlapId]then return false,'RestrictedSlap'end
 if not Policy.AllowedVariationIds[unit.VariationId] or Policy.NonTradableRewardIds[unit.RewardId] then return false,'RestrictedItem' end
 if unit.Locked or unit.TradeLocked or unit.NonTradable or unit.PremiumOnly or unit.Temporary or unit.TestOnly or reward.LimitedStock or variation.LimitedStock then return false,'RestrictedItem' end
 if unit.Origin~='Crate' or Policy.NonTradableSourceTypes[unit.Origin] then return false,'RestrictedSource' end
 local op=type(inventory.CrateOperations)=='table' and inventory.CrateOperations[unit.OperationId]
 if type(op)~='table'then return false,'UnverifiedProvenance'end
 local crate=op and catalog.Crates.ById[op.CrateId]
 if not crate or crate.PremiumOnly or op.OwnerUserId~=uid or op.State~='Completed' then return false,'UnverifiedProvenance' end
 -- The immutable opening journal must really contain this unit, including batch rewards.
 local found=op.UnitId==unit.UnitId and op.RewardId==unit.RewardId
 if op.Rewards~=nil and type(op.Rewards)~='table'then return false,'UnverifiedProvenance'end
 for _,row in ipairs(op.Rewards or {})do if type(row)=='table'and row.UnitId==unit.UnitId and row.RewardId==unit.RewardId then found=true end end
 if not found then return false,'UnverifiedProvenance' end
 return true
end
return Policy
]====]
Sources["TradeRecoveryService"]=[====[--!strict
-- Deliberately has no adapter/DataStore access. No durable trade can start in V1.0.
local Recovery={}
function Recovery.Status()
 return {DurableRecoveryAvailable=false,Reason='ProfileLifecycleIntegrationPending',RequiresFencedProfileBridge=true}
end
function Recovery.Reconcile(_tradeId: string): (boolean,string)
 return false,'DurableRecoveryUnavailable'
end
return Recovery
]====]
Sources["TradeTransactionService"]=[====[--!nonstrict
-- No inventory mutation path is installed until ALL profile saves/mutators are fenced.
local Transaction={}
function Transaction.Availability(config,info,isStudio)
 if isStudio or not info or info.ProviderName=='InMemory' or info.Environment~='Production' or info.WritesToCloud~=true then return false,'InMemoryCommitForbidden' end
 if config.TradeCommitEnabled~=true then return false,'TradeCommitDisabled' end
 return false,'ProfileLifecycleIntegrationPending'
end
function Transaction.Commit(_intent,_backend)
 -- A boolean, fake backend, client confirmation or two UpdateAsync calls cannot bypass this gate.
 return false,'TradeCommitDisabled'
end
return Transaction
]====]
Sources["SocialConfig"]=[====[--!strict
-- Presentation values are replicated; every permission is checked again on the server.
return table.freeze({
 ProfileInspectionEnabled=true, TradeInvitationsEnabled=true, TradeCommitEnabled=false,
 InspectDistance=10, PromptHoldSeconds=0.5, MaxSlapsPerSide=6,
 InviteTimeoutSeconds=15, SafetyCountdownSeconds=5, MaxTradeSeconds=180,
 InviteCooldownSeconds=15, RequestIntervalSeconds=0.25, InventoryPageSize=24,
 MaxActivePreviews=12, AimPollSeconds=0.12, TerminalRetentionSeconds=30, SelfProfileRefreshSeconds=2,
})
]====]
Sources["Targeting"]=[====[--!nonstrict
local Targeting={}
function Targeting.Valid(localPlayer,target,maxDistance)
 if not target or target==localPlayer or not target.Parent or localPlayer:GetAttribute('MatchId')or target:GetAttribute('MatchId')then return false end
 local a=localPlayer.Character;local b=target.Character
 local x=a and a:FindFirstChild('HumanoidRootPart');local y=b and b:FindFirstChild('HumanoidRootPart')
 local h=b and b:FindFirstChildOfClass('Humanoid')
 return x~=nil and y~=nil and h~=nil and h.Health>0 and (x.Position-y.Position).Magnitude<=maxDistance
end
function Targeting.FromHit(players,hit)
 local current=hit
 while current and current~=workspace do
  if current:IsA('Model')then local player=players:GetPlayerFromCharacter(current);if player then return player end end
  current=current.Parent
 end
 return nil
end
return Targeting
]====]
Sources["ViewportPool"]=[====[--!nonstrict
-- Bounded visual clones exclusively inside ViewportFrames; no workspace or input ownership.
local RS=game:GetService('ReplicatedStorage')
local Players=game:GetService('Players')
local Appearance=require(RS.Shared.SlapCrates.Appearance)
local Pool={};Pool.__index=Pool
function Pool.new(maximum)return setmetatable({Rows={},Count=0,Maximum=maximum},Pool)end
function Pool:Remove(view)
 local row=self.Rows[view];if not row then return end
 self.Rows[view]=nil;self.Count-=1
 for _,connection in ipairs(row.Connections)do connection:Disconnect()end
 view.CurrentCamera=nil;row.World:Destroy();row.Camera:Destroy()
end
function Pool:Clear()local keys={};for view in pairs(self.Rows)do table.insert(keys,view)end;for _,view in ipairs(keys)do self:Remove(view)end end
local function clean(model)
 for _,p in ipairs(model:GetDescendants())do
  if p:IsA('LuaSourceContainer')or p:IsA('Tool')or p:IsA('Sound')then p:Destroy()
  elseif p:IsA('BasePart')then p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
  elseif p:IsA('ParticleEmitter')then p.Enabled=false -- Viewport preview uses authored tint plus UI aura; no workspace emitters.
  end
 end
end
function Pool:Add(view,source,avatar)
 if self.Rows[view]then return true end
 if self.Count>=self.Maximum or not source or not view.Parent then return false end
 local model
 if avatar then
  local char=source.Character;if not char then return false end
  local humanoid=char:FindFirstChildOfClass('Humanoid');if not humanoid then return false end
  -- Clone the existing visual character; no web lookup, no temporary models in Workspace.
  local original=char.Archivable;char.Archivable=true
  local ok,result=pcall(char.Clone,char);char.Archivable=original
  if not ok or not result then return false end;model=result
 else model=source:Clone()end
 if not model:IsA('Model')then model:Destroy();return false end
 clean(model)
 local world=Instance.new('WorldModel');world.Name='SocialPreviewWorld';world.Parent=view
 local camera=Instance.new('Camera');camera.Name='SocialPreviewCamera';camera.FieldOfView=35;camera.Parent=view
 model.Parent=world
 if avatar then model:PivotTo(CFrame.new())end -- Neutral forward orientation; camera looks at the avatar's front.
 local box,size=model:GetBoundingBox();model:PivotTo(CFrame.new(-box.Position)*model:GetPivot())
 local row={World=world,Camera=camera,Model=model,Avatar=avatar,Base=model:GetPivot(),Size=size,Angle=0,Connections={}}
 local function fit()
  if not view.Parent then return end
  local aspect=math.max(0.2,view.AbsoluteSize.X/math.max(1,view.AbsoluteSize.Y))
  local radius=math.max(0.5,size.Magnitude/2)
  local half=math.atan(math.tan(math.rad(camera.FieldOfView/2))*math.min(1,aspect))
  local distance=radius/math.sin(half)*1.12
  camera.CFrame=CFrame.lookAt(Vector3.new(0,0,avatar and -distance or distance),Vector3.zero)
 end
 table.insert(row.Connections,view:GetPropertyChangedSignal('AbsoluteSize'):Connect(fit))
 table.insert(row.Connections,view.Destroying:Connect(function()self:Remove(view)end))
 self.Rows[view]=row;self.Count+=1;view.CurrentCamera=camera;fit();return true
end
function Pool:Slap(view,item)
 local roots=RS:FindFirstChild('SlapVariationPreviews');local base=roots and roots:FindFirstChild(item.SlapId)
 local source=base and base:FindFirstChild(item.VariationId)
 if not source then local fallback=RS:FindFirstChild('CrateRewardPreviews');source=fallback and fallback:FindFirstChild(item.SlapId)end
 if not self:Add(view,source,false)then return false end
 local row=self.Rows[view];local part=row.Model:FindFirstChildWhichIsA('BasePart',true)
 local effects=RS:FindFirstChild('SlapVariationEffects');local profile=effects and effects:FindFirstChild(item.VariationId)
 if part then Appearance.Apply(part,profile);clean(row.Model)end
 return true
end
function Pool:Step(dt)
 for view,row in pairs(self.Rows)do
  if view.Parent then
   row.Angle+=dt*(row.Avatar and 0.08 or 0.45)
   row.Model:PivotTo(CFrame.Angles(0,row.Angle,0)*row.Base)
  end
 end
end
return Pool
]====]
Sources["SocialService"]=[====[--!nonstrict
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local Http=game:GetService('HttpService')
local Config=require(RS.Shared.SocialConfig)
local Catalog=require(RS.Shared.SlapCrates.Catalog)
local Public=require(script.Parent.Trading.PublicInventory)
local Personal=require(script.Parent.Trading.PersonalInventory)
local Engine=require(script.Parent.Trading.TradeEngine)
local Transaction=require(script.Parent.Trading.TradeTransactionService)
local Service={Name='SocialService'}
local function uid(n)return type(n)=='number'and n==n and n~=0 and math.abs(n)<9007199254740992 and n%1==0 end
local categories={Slaps=true,PointEffects=true,DeathEffects=true}
function Service:Project(p,page,category)
 local shop=self.Context and self.Context:GetService('ShopService');local products={}
 if shop then products.PointEffects=shop:GetCatalog('PointEffects');products.DeathEffects=shop:GetCatalog('DeathEffects')end
 return Public.Profile(p,self.Profiles:GetPlayerData(p),Catalog,Config,page,category,products)
end
function Service:Equip(p,category,productId,page)
 if not self:AllowRequest(p)then return {Ok=false,Reason='RateLimited'}end
 if type(category)~='string'or not categories[category]or type(productId)~='string'or #productId==0 or #productId>128 then return {Ok=false,Reason='InvalidRequest'}end
 if page==nil then page=1 end
 if type(page)~='number'or page~=page or page%1~=0 or page<1 or page>10000 then return {Ok=false,Reason='InvalidRequest'}end
 if Players:GetPlayerByUserId(p.UserId)~=p or not self:Eligible(p.UserId)or p:GetAttribute('ResultsSessionId')~=nil then return {Ok=false,Reason='PlayerUnavailable'}end
 if self.Engine.Busy[p.UserId]then return {Ok=false,Reason='PlayerBusy'}end
 local inv=self.Profiles:GetInventory(p);local owned=inv and inv.Owned and inv.Owned[category]
 if not owned or owned[productId]~=true then return {Ok=false,Reason='NotOwned'}end
 local shop=self.Context and self.Context:GetService('ShopService')
 if not shop then return {Ok=false,Reason='ShopUnavailable'}end
 -- The caller is the only target. Share Shop's provider validation and transaction lock.
 local ok,reason=shop:EquipProduct(p,productId,category)
 if not ok then return {Ok=false,Reason=reason}end
 local result=self:Project(p,page,category);result.ProfileMode='SelfProfile'
 return {Ok=true,Profile=result}
end
function Service:Eligible(id)
 local p=uid(id)and Players:GetPlayerByUserId(id)
 if not p or p.Parent~=Players or not self.Profiles:IsShopDataReady(p)then return false end
 if self.Rounds:GetSessionForPlayer(p)then return false end
 local c=p.Character;local h=c and c:FindFirstChildOfClass('Humanoid');local root=c and c:FindFirstChild('HumanoidRootPart')
 return c~=nil and c:IsDescendantOf(workspace)and h~=nil and h.Health>0 and root~=nil and root:IsA('BasePart')
end
function Service:Distance(a,b)
 local x=Players:GetPlayerByUserId(a);local y=Players:GetPlayerByUserId(b)
 local r=x and x.Character and x.Character:FindFirstChild('HumanoidRootPart');local s=y and y.Character and y.Character:FindFirstChild('HumanoidRootPart')
 return r and s and (r.Position-s.Position).Magnitude or math.huge
end
function Service:Unit(id,key)
 local p=Players:GetPlayerByUserId(id)
 if not p or not self.Profiles:IsShopDataReady(p)then return nil end
 for _,row in ipairs(Public.Build(self.Profiles:GetPlayerData(p),id,Catalog))do if row.UnitId==key then return row end end
end
function Service:AllowRequest(p)
 local now=workspace:GetServerTimeNow();local last=self.LastRequest[p]or -math.huge
 if now-last<Config.RequestIntervalSeconds then return false end
 self.LastRequest[p]=now;return true
end
function Service:Inspect(p,targetId,page,category)
 if not self:AllowRequest(p)then return {Ok=false,Reason='RateLimited'}end
 page=page or 1
 if category==nil then category='Slaps'end
 if not categories[category]or not Config.ProfileInspectionEnabled or not uid(targetId)or type(page)~='number'or page~=page or page%1~=0 or page<1 or page>10000 then return {Ok=false,Reason='InvalidRequest'}end
 local ok,why=self.Engine:_pair(p.UserId,targetId,true)
 if not ok then return {Ok=false,Reason=why}end
 local target=Players:GetPlayerByUserId(targetId)
 local result=self:Project(target,page,category)
 result.ProfileMode='OtherPlayerProfile'
 local play=self.Context and self.Context:GetService('SocialPlayService');if play then play:Decorate(p,result)end
 self.Viewers[p]=targetId;return {Ok=true,Profile=result}
end
-- No target or client mode argument: the authenticated caller owns this read-only view.
function Service:SelfProfile(p,page,category)
 if not self:AllowRequest(p)then return {Ok=false,Reason='RateLimited'}end
 if page==nil then page=1 end
 if category==nil then category='Slaps'end
 if not categories[category]or not Config.ProfileInspectionEnabled or type(page)~='number'or page~=page or page%1~=0 or page<1 or page>10000 then return {Ok=false,Reason='InvalidRequest'}end
 if not uid(p.UserId)or Players:GetPlayerByUserId(p.UserId)~=p or not self:Eligible(p.UserId)then return {Ok=false,Reason='PlayerUnavailable'}end
 local result=self:Project(p,page,category)
 result.ProfileMode='SelfProfile'
 local play=self.Context and self.Context:GetService('SocialPlayService');if play then play:Decorate(p,result)end
 self.Viewers[p]=p.UserId
 return {Ok=true,Profile=result}
end
function Service:Inventory(p,category,page,query)
 if not self:AllowRequest(p)then return {Ok=false,Reason='RateLimited'}end
 if not Personal.Valid(category,page,query)then return {Ok=false,Reason='InvalidRequest'}end
 if Players:GetPlayerByUserId(p.UserId)~=p or not self:Eligible(p.UserId)or p:GetAttribute('ResultsSessionId')~=nil then return {Ok=false,Reason='PlayerUnavailable'}end
 local shop=self.Context:GetService('ShopService');local crates=self.Context:GetService('CrateService')
 local products=category~='Crates' and category~='Slaps' and shop and shop:GetCatalog(category)or {}
 local crateProducts=category=='Crates' and crates and crates:GetCatalog()or {}
 return {Ok=true,Inventory=Personal.Build(self.Profiles:GetPlayerData(p),p.UserId,Catalog,category,products,crateProducts,page,query,Config.InventoryPageSize)}
end
function Service:Action(p,action,id,revision,value)
 if not self:AllowRequest(p)then return {Ok=false,Reason='RateLimited'}end
 if action=='Invite'then
  if not uid(id)then return {Ok=false,Reason='InvalidTarget'}end
  local target=Players:GetPlayerByUserId(id)
  if target and target:GetAttribute('TradeInvitationsDisabled')==true then return {Ok=false,Reason='InvitationsDisabled'}end
  local ok,why=self.Engine:Invite(p.UserId,id);return {Ok=ok,Reason=ok and nil or why,TradeId=ok and why or nil}
 end
 if type(action)~='string'or #action>16 or type(id)~='string'or #id>128 or type(revision)~='number'or revision~=revision or revision<0 or revision%1~=0 then return {Ok=false,Reason='InvalidRequest'}end
 if action=='Inventory'then
  local t=self.Engine.Trades[id]
  if not t or t.Terminal or (p.UserId~=t.A and p.UserId~=t.B)or t.Revision~=revision or not self:Eligible(p.UserId)then return {Ok=false,Reason='NotParticipant'}end
  local page=value or 1
  if type(page)~='number'or page~=page or page%1~=0 or page<1 or page>10000 then return {Ok=false,Reason='InvalidPage'}end
  return {Ok=true,Profile=Public.Profile(p,self.Profiles:GetPlayerData(p),Catalog,Config,page)}
 end
 local ok,why=self.Engine:Act(p.UserId,action,id,revision,value);return {Ok=ok,Reason=why}
end
function Service:Init(context)
 self.Context=context;self.Profiles=context:GetService('PlayerService');self.Rounds=context:GetService('RoundService')
 assert(self.Profiles and self.Rounds,'Social dependencies unavailable')
 self.LastRequest={};self.Viewers={};self.Connections={};self.CharacterConnections={}
 local remotes=RS:WaitForChild('Remotes');local folder=remotes:FindFirstChild('Social')
 local function ensure(parent,name,class)local p=parent:FindFirstChild(name);if p then assert(p:IsA(class),'Social remote class mismatch');return p end;local n=Instance.new(class);n.Name=name;n.Parent=parent;return n end
 folder=folder or ensure(remotes,'Social','Folder')
 self.Update=ensure(folder,'Updated','RemoteEvent')
 self.SelfProfileRemote=ensure(folder,'SelfProfile','RemoteFunction')
 self.EquipRemote=ensure(folder,'Equip','RemoteFunction')
 self.InventoryRemote=ensure(folder,'Inventory','RemoteFunction')
 self.InspectRemote=ensure(folder,'Inspect','RemoteFunction');self.ActionRemote=ensure(folder,'Action','RemoteFunction')
 self.Engine=Engine.new(Config,{
  Clock=function()return workspace:GetServerTimeNow()end,Id=function()return Http:GenerateGUID(false)end,
  Eligible=function(id)return self:Eligible(id)end,Distance=function(a,b)return self:Distance(a,b)end,
  Name=function(id)local p=Players:GetPlayerByUserId(id);return p and p.DisplayName or 'Desconectado'end,
  Unit=function(id,key)return self:Unit(id,key)end,Commit=Transaction.Commit,
  Emit=function(id,kind,payload)local p=Players:GetPlayerByUserId(id);if p then self.Update:FireClient(p,kind,payload)end end,
 })
 self.CommitAvailable,self.CommitReason=Transaction.Availability(Config,context.PersistenceInfo,RunService:IsStudio())
 assert(not self.CommitAvailable,'Real trade commit must remain disabled')
end
function Service:ValidateViewers()
  for p,target in pairs(self.Viewers)do
   if not self:Eligible(p.UserId)or not self:Eligible(target)or (p.UserId~=target and not(self:Distance(p.UserId,target)<=Config.InspectDistance))then
    self.Viewers[p]=nil;if p.Parent==Players then self.Update:FireClient(p,'ProfileUnavailable',{UserId=target})end
   end
  end
end
function Service:Start()
 self.InventoryRemote.OnServerInvoke=function(p,category,page,query)return self:Inventory(p,category,page,query)end
 self.SelfProfileRemote.OnServerInvoke=function(p,page,category)return self:SelfProfile(p,page,category)end
 self.EquipRemote.OnServerInvoke=function(p,...)return self:Equip(p,...)end
 self.InspectRemote.OnServerInvoke=function(p,...)return self:Inspect(p,...)end
 self.ActionRemote.OnServerInvoke=function(p,...)return self:Action(p,...)end
 local function bind(p)
  if self.CharacterConnections[p]then self.CharacterConnections[p]:Disconnect()end
  self.CharacterConnections[p]=p.CharacterRemoving:Connect(function()self.Engine:CancelForPlayer(p.UserId)end)
 end
 for _,p in ipairs(Players:GetPlayers())do bind(p)end
 table.insert(self.Connections,Players.PlayerAdded:Connect(bind))
 table.insert(self.Connections,Players.PlayerRemoving:Connect(function(p)
  self.Engine:Disconnect(p.UserId);self.Viewers[p]=nil;self.LastRequest[p]=nil
  if self.CharacterConnections[p]then self.CharacterConnections[p]:Disconnect();self.CharacterConnections[p]=nil end
 end))
 local elapsed=0
 table.insert(self.Connections,RunService.Heartbeat:Connect(function(dt)
  elapsed+=dt;if elapsed<0.25 then return end;elapsed=0;self.Engine:Tick()
  self:ValidateViewers()
 end))
 print('[SocialService] Inspection/invitations ready; TradeCommitEnabled=false; '..self.CommitReason)
end
return Service
]====]
Sources["SocialController"]=[====[--!nonstrict
local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local UIS=game:GetService('UserInputService')
local Tween=game:GetService('TweenService')
local Config=require(RS.Shared.SocialConfig)
local Catalog=require(RS.Shared.SlapCrates.Catalog)
local Targeting=require(script.Parent.Parent.Social.Targeting)
local Viewports=require(script.Parent.Parent.Social.ViewportPool)
local player=Players.LocalPlayer
local Controller={Name='SocialController'}
local terminal={Cancelled=true,Completed=true,FailedRecoverable=true}
local reasons={TradeCommitDisabled='PRUEBA FINALIZADA: no se transfirió ningún Slap.',RateLimited='Esperá un momento antes de volver a intentar.',
 OutOfRange='El jugador está fuera del alcance.',PlayerUnavailable='Jugador no disponible o en partida.',PlayerBusy='Uno de los jugadores ya tiene una solicitud o trade.',
 InviteCooldown='Esperá antes de enviar otra invitación.',ItemNotTradable='Este artículo no es comerciable.',StaleRevision='La oferta cambió. Revisala nuevamente.',
 OffersLocked='La oferta está bloqueada durante la confirmación.',InvitationDeclined='Solicitud rechazada.',Expired='La solicitud o el trade expiró.',InvitationsDisabled='El jugador no recibe solicitudes.'}
local function text(reason)return reasons[reason]or tostring(reason or '')end
local categoryNames={Slaps='SLAPS',PointEffects='EFECTOS DE PUNTO',DeathEffects='EFECTOS DE MUERTE'}
local rarityColors={Basic=Color3.fromRGB(220,225,235),Common=Color3.fromRGB(190,205,220),Rare=Color3.fromRGB(69,138,255),Epic=Color3.fromRGB(145,58,225),Legendary=Color3.fromRGB(255,156,37)}
function Controller:EquipItem(item)
 if self.PendingEquip or self.PendingProfile or self.ProfileMode~='SelfProfile'or self.ProfileTarget~=player.UserId or not self.Profile.Enabled or item.Equipped then return end
 if item.Available==false then self:Message('Este recurso no está disponible.');return end
 local category=item.Category or 'Slaps';if not categoryNames[category]then return end
 self.PendingEquip=true;local generation=self.Generation;local page=self.ProfilePage
 self:Message('Guardando selección…')
 task.spawn(function()
  local ok,response=pcall(self.Equip.InvokeServer,self.Equip,category,item.ProductId or item.RewardId,page)
  self.PendingEquip=false
  if generation~=self.Generation or self.ProfileMode~='SelfProfile'or self.ProfileTarget~=player.UserId then return end
  if not ok or type(response)~='table'then self:Message('No se pudo confirmar. Actualizá el inventario para revisar tu selección.');return end
  if not response.Ok then self:Message(text(response.Reason));return end
  if response.Profile and response.Profile.UserId==player.UserId then self:ApplyProfile(response.Profile,true);self:Message('Selección equipada para tus partidas.')end
 end)
end
function Controller:Sound(gui,name)
 local folder=gui and gui:FindFirstChild('Audio');local sound=folder and folder:FindFirstChild(name)
 if self.LastSound and self.LastSound.IsPlaying then self.LastSound:Stop()end
 if sound and sound.SoundId~=''then sound:Play();self.LastSound=sound end
end
function Controller:Message(message)
 for _,gui in ipairs({self.Profile,self.Request,self.Trade})do if gui.Enabled then gui.MainFrame.Status.Text=message end end
end
function Controller:RequestAction(action,id,revision,value,callback)
 if self.PendingAction then return end
 self.PendingAction=true
 task.spawn(function()
  local ok,response=pcall(self.Action.InvokeServer,self.Action,action,id,revision,value)
  self.PendingAction=false
  if not ok or type(response)~='table'then self:Message('No se pudo contactar al servidor.');return end
  if not response.Ok then self:Sound(self.Trade.Enabled and self.Trade or self.Profile,'Error');self:Message(text(response.Reason))end
  if callback then callback(response)end
  if self.PendingInventoryPage then local page=self.PendingInventoryPage;self.PendingInventoryPage=nil;task.delay(.3,function()self:OwnPage(page)end)end
 end)
end
function Controller:ClearCards(container)
 for i=#self.Cards,1,-1 do local record=self.Cards[i]
  if record.Container==container then
   self.Pool:Remove(record.View)
   if record.Connection then record.Connection:Disconnect()end
   record.Card:Destroy();table.remove(self.Cards,i)
  end
 end
end
function Controller:RefreshPreviews()
 local live=0
 for _,entry in ipairs(self.Cards)do
  local s=entry.Container;local visible=entry.Gui.Enabled and s.Visible
  local pos,size=entry.Card.AbsolutePosition,entry.Card.AbsoluteSize;local p,z=s.AbsolutePosition,s.AbsoluteSize
  visible=visible and pos.Y+size.Y>p.Y and pos.Y<p.Y+z.Y and pos.X+size.X>p.X and pos.X<p.X+z.X
  if visible and live<Config.MaxActivePreviews-2 then
   if (entry.Item.Category==nil or entry.Item.Category=='Slaps')and self.Pool:Slap(entry.View,entry.Item)then live+=1 end
  else self.Pool:Remove(entry.View)end
 end
end
function Controller:CardsFor(gui,container,items,mode)
 self:ClearCards(container)
 local template=gui.CardTemplate
 for index,item in ipairs(items)do
  local card=template:Clone();card.Name='Item_'..index;card.LayoutOrder=index;card.Visible=true
  card:FindFirstChild('ItemName').Text=item.DisplayName;card.Variation.Text=item.VariationName
  local variation=Catalog.Variations.ById[item.VariationId];local color=variation and variation.Color or rarityColors[item.Rarity]or Color3.fromRGB(90,205,220)
  card.Accent.Color=color;card.Variation.TextColor3=color
  card.Aura.BackgroundColor3=color;card.Preview.BackgroundTransparency=1
  card.Aura.Gradient.Color=ColorSequence.new(color,Color3.fromRGB(12,20,32))
  local ownProfile=gui==self.Profile and self.ProfileMode=='SelfProfile'and self.ProfileTarget==player.UserId
  card.State.Text=ownProfile and(item.Equipped and 'EQUIPADO'or item.Available==false and 'NO DISPONIBLE'or 'EQUIPAR')or ((item.Equipped and 'EQUIPADO · 'or '')..(item.Tradable and(mode=='Add'and '+ OFRECER'or mode=='Remove'and 'RETIRAR'or 'COMERCIABLE')or 'NO COMERCIABLE'))
  card.UnitId.Text=item.Category and item.Category~='Slaps'and 'PERSONAL · NO INTERCAMBIABLE'or(item.Tradable and 'SLAP INTERCAMBIABLE'or 'SLAP NO INTERCAMBIABLE');card.UnitId.TextSize=10
  local effect=card:FindFirstChild('EffectBadge')
  if effect then effect.Visible=item.Category~=nil and item.Category~='Slaps';effect.Text=item.Category=='PointEffects'and 'PUNTO'or 'MUERTE';effect.TextColor3=color;card.Preview.Visible=not effect.Visible end
  card.Parent=container
  local connection=card.Activated:Connect(function()
   if ownProfile then self:EquipItem(item)
   elseif mode and item.UnitId and self.CurrentTrade and (mode=='Remove'or item.Tradable)then
    local t=self.CurrentTrade;self:RequestAction(mode,t.TradeId,t.Revision,item.UnitId)
   end
   self:Sound(gui,'Click')
   Tween:Create(card.Accent,TweenInfo.new(.15),{Thickness=3}):Play()
  end)
  table.insert(self.Cards,{Card=card,View=card.Preview,Item=item,Container=container,Gui=gui,Connection=connection})
 end
 local grid=container:FindFirstChildOfClass('UIGridLayout')
 if grid then
  local columns=container.AbsoluteSize.X>=300 and 3 or container.AbsoluteSize.X>=185 and 2 or 1
  grid.CellSize=UDim2.new(1/columns,-8,0,180)
 end
end
function Controller:Show(gui)
 self.DisplayTokens[gui]=(self.DisplayTokens[gui]or 0)+1
 if self.Fades[gui]then self.Fades[gui]:Cancel();self.Fades[gui]:Destroy()end
 gui.Enabled=true;gui.MainFrame.GroupTransparency=1
 local fade=Tween:Create(gui.MainFrame,TweenInfo.new(.2),{GroupTransparency=0});self.Fades[gui]=fade;fade:Play();self:Sound(gui,'Open')
end
function Controller:Close(gui)
 local navigation=self.Context and self.Context:GetController('WindowNavigationController');if navigation then navigation:Forget(gui.Name)end
 self.DisplayTokens[gui]=(self.DisplayTokens[gui]or 0)+1;local token=self.DisplayTokens[gui]
 if self.Fades[gui]then self.Fades[gui]:Cancel();self.Fades[gui]:Destroy();self.Fades[gui]=nil end
 if gui.Enabled then
  self:Sound(gui,'Close')
  local fade=Tween:Create(gui.MainFrame,TweenInfo.new(.15),{GroupTransparency=1});self.Fades[gui]=fade;fade:Play()
  task.delay(.16,function()if self.DisplayTokens[gui]==token then gui.Enabled=false end end)
 end
 self.Generation+=1
 for _,entry in ipairs(self.Cards)do if entry.Gui==gui then self.Pool:Remove(entry.View)end end
 if gui==self.Profile then local summary=gui.MainFrame:FindFirstChild('Summary');if summary then self.Pool:Remove(summary.Equipped.Preview)end;self.ProfileData=nil;self.Pool:Remove(gui.MainFrame.Avatar);self.ProfileTarget=nil;self.ProfileMode=nil;self.NextSelfRefresh=nil end
 if gui==self.Request then self.Pool:Remove(gui.MainFrame.Avatar)end
 if gui==self.Trade then self.Pool:Remove(gui.MainFrame.Mine.Avatar);self.Pool:Remove(gui.MainFrame.Theirs.Avatar)end
 local containers={};for _,entry in ipairs(self.Cards)do if entry.Gui==gui then containers[entry.Container]=true end end
 for container in pairs(containers)do self:ClearCards(container)end
end
-- These existing windows own their own lifecycle; this controller never changes them.
function Controller:WindowBusy()
 local gui=player:FindFirstChild('PlayerGui')
 if not gui then return true end
 for _,name in ipairs({'ShopHUD','PremiumShopHUD','SettingsGUI','CrateOpeningHUD'})do
  local hud=gui:FindFirstChild(name)
  local main=hud and hud:FindFirstChild('MainFrame')
  local navigation=self.Context and self.Context:GetController('WindowNavigationController')
  if hud and hud.Enabled and (name=='CrateOpeningHUD'or not navigation and main and main.Visible)then return true end
 end
 return self.Request.Enabled or self.Trade.Enabled
end
function Controller:SetArticlesMode(show)
 if show and self.ProfileMode=='SelfProfile' and self.ProfileTarget==player.UserId then
  local inventory=self.Context and self.Context:GetController('InventoryController')
  if inventory then inventory:Open();return end
 end
 local m=self.Profile.MainFrame;local summary=m:FindFirstChild('Summary')
 if not summary then return end
 self.ArticlesVisible=show;summary.Visible=not show;m.Collection.Visible=show
 for _,name in ipairs({'InventoryTabs','CollectionTitle','CollectionHint'})do local o=m:FindFirstChild(name);if o then o.Visible=show end end
 local loadout=m:FindFirstChild('SelectedEffects');if loadout then loadout.Visible=not show end
 for _,name in ipairs({'Previous','Page','Next'})do m[name].Visible=show end
 m.Articles.Text=show and 'Volver al perfil'or 'Ver inventario'
 local cards=m:FindFirstChild('ProgressCards');if cards then cards.Visible=not show end
 local label=m.Articles:FindFirstChild('ActionLabel');if label then label.Text=m.Articles.Text end
 if not show then for _,entry in ipairs(self.Cards)do if entry.Gui==self.Profile then self.Pool:Remove(entry.View)end end end
end
function Controller:ProfileActions(data)
 local m=self.Profile.MainFrame;local own=data.UserId==player.UserId
 local target=Players:GetPlayerByUserId(data.UserId)
 local solo=not player:GetAttribute('SocialGroupId')and target and not target:GetAttribute('SocialGroupId')
 for _,entry in ipairs({{'Challenge',not own and solo and data.Actions and data.Actions.Challenge},{'Invite',not own and data.Actions and data.Actions.Invite}})do
  local button=m:FindFirstChild(entry[1]);if button then local enabled=entry[2]==true;button.Visible=enabled;button.Active=enabled;button.Selectable=enabled end
 end
 local articles=m:FindFirstChild('Articles')
 local badge=m:FindFirstChild('ProfileBadge');if badge and m.AbsoluteSize then badge.Visible=m.AbsoluteSize.X>=560 end
 if articles then articles.Position=UDim2.new(.02,0,.87,0);articles.Size=UDim2.new(own and .96 or .225,0,.095,0)end
end
function Controller:ApplyProfile(data,refresh)
 if type(data)~='table'or player:GetAttribute('MatchId')or self:WindowBusy()then return false end
 local owner=Players:GetPlayerByUserId(data.UserId)
 local own=data.UserId==player.UserId
 if not owner or data.ProfileMode~=(own and 'SelfProfile'or 'OtherPlayerProfile')then return false end
 self.ProfileTarget=data.UserId;self.ProfileMode=data.ProfileMode
 self.ProfilePage=data.Page;self.ProfileHasNext=data.HasNext
 self.NextSelfRefresh=workspace:GetServerTimeNow()+Config.SelfProfileRefreshSeconds
 if not refresh then self:Show(self.Profile)end
 local m=self.Profile.MainFrame
 m.Trade.Visible=not own;m.Trade.Active=not own;m.Trade.Selectable=not own
 m.Trade.AutoButtonColor=not own
 self.ProfileData=data;self:ProfileActions(data)
 if not refresh then self:SetArticlesMode(false)end
 local summary=m:FindFirstChild('Summary')
 if summary then
  summary.Streak.Value.Text=tostring(data.Stats.Streaks or 0);summary.Wins.Value.Text=tostring(data.Stats.Wins);summary.Kills.Value.Text=tostring(data.Stats.TotalKills)
 end
 local username=m:FindFirstChild('Username')
 if username then m.Identity.Text=data.DisplayName;username.Text='@'..data.Username
 else m.Identity.Text=data.DisplayName..'\n@'..data.Username end
 local badge=m:FindFirstChild('ProfileBadge');if badge then badge.Label.Text=own and 'TU PERFIL'or 'JUGADOR'end
 local collectionTitle=m:FindFirstChild('CollectionTitle');if collectionTitle then collectionTitle.Text='COLECCIÓN  /  '..tostring(data.TotalItems)..' ARTÍCULOS'end
 local hint=m:FindFirstChild('CollectionHint');if hint then hint.Text=own and 'Tocá un artículo para equiparlo. Solo los Slaps admiten intercambio.'or 'Colección de consulta. Solo los Slaps admiten intercambio.'end
 if summary then local tile=summary:FindFirstChild('Equipped');local heading=tile and tile:FindFirstChild('Eyebrow');if heading then heading.Text=own and 'TU SLAP EQUIPADO'or 'SLAP EQUIPADO'end end
 m.Stats.Text=string.format('VICTORIAS %d\nDERROTAS %d\nKILLS %d',data.Stats.Wins,data.Stats.Losses,data.Stats.TotalKills)
 m.Progression.Text='NIVEL '..tostring(owner:GetAttribute('Level')or 0)..' · Derrotas '..tostring(data.Stats.Losses);m.Page.Text=string.format('%d · %d artículos',data.Page,data.TotalItems)
 local progression=self.Context and self.Context:GetController('BattlePassController');if progression then progression:RenderProfile()end
 m.Status.Text=''
 -- Keep the same avatar and card pool on unchanged refreshes (no rotation reset).
 if not refresh then self.Pool:Remove(m.Avatar);self.Pool:Add(m.Avatar,owner,true)end
 local category=data.Category or 'Slaps';self.ProfileCategory=category
 local tabs=m:FindFirstChild('InventoryTabs');if tabs then for key in pairs(categoryNames)do tabs[key].BackgroundColor3=key==category and Color3.fromRGB(29,105,145)or Color3.fromRGB(20,30,45)end end
 local selected=m:FindFirstChild('SelectedEffects')
 if selected then for _,key in ipairs({'PointEffects','DeathEffects'})do local item=data.EquippedLoadout and data.EquippedLoadout[key];selected[key].Text=(key=='PointEffects'and 'PUNTO: 'or 'MUERTE: ')..(item and item.DisplayName or 'Sin selección disponible')end end
 local fingerprint=game:GetService('HttpService'):JSONEncode({Inventory=data.Inventory,Loadout=data.EquippedLoadout,Category=category})..':'..tostring(data.EquippedSlap and data.EquippedSlap.RewardId)
 if not refresh or self.ProfileInventoryFingerprint~=fingerprint then
  self.ProfileInventoryFingerprint=fingerprint
  self:CardsFor(self.Profile,m.Collection,data.Inventory,nil)
  if summary then
   local equipped=data.EquippedSlap
   self.Pool:Remove(summary.Equipped.Preview)
   if equipped then self.Pool:Slap(summary.Equipped.Preview,equipped);summary.Equipped.Caption.Text=string.find(string.lower(equipped.DisplayName),string.lower(equipped.VariationName),1,true)and equipped.DisplayName or equipped.DisplayName..' · '..equipped.VariationName
   else summary.Equipped.Caption.Text='Consultá Ver artículos para ver el Slap equipado'end
  end
 end
 return true
end
function Controller:OpenProfile(id,page,refresh,category)
 if self.PendingProfile or self.PendingEquip or player:GetAttribute('MatchId')or self:WindowBusy()then return end
 category=category or(refresh and self.ProfileCategory)or 'Slaps'
 local own=id==player.UserId
 self.PendingProfile=true;local generation=self.Generation
 task.spawn(function()
  local remote=own and self.SelfInspect or self.Inspect
  local ok,response
  if own then ok,response=pcall(remote.InvokeServer,remote,page,category)
  else ok,response=pcall(remote.InvokeServer,remote,id,page,category)end
  self.PendingProfile=false
  if generation~=self.Generation then return end
  if not ok or type(response)~='table'or not response.Ok then
   if refresh then
    self.NextSelfRefresh=workspace:GetServerTimeNow()+Config.RequestIntervalSeconds
    if type(response)=='table'and response.Reason~='RateLimited'then self:Close(self.Profile)end
   else self:Message(text(type(response)=='table'and response.Reason or 'Error de red'))end
   return
  end
  if response.Profile.UserId~=id then return end
  self:ApplyProfile(response.Profile,refresh)
 end)
end
function Controller:OpenSelfProfile()
 if self.Profile.Enabled and self.ProfileMode=='SelfProfile'then self:Close(self.Profile);return end
 self:OpenProfile(player.UserId,1)
end
function Controller:BindProfileButton(button)
 local base=button.BackgroundColor3
 table.insert(self.Connections,button.Activated:Connect(function()self:Sound(self.Profile,'Click');self:OpenSelfProfile()end))
 table.insert(self.Connections,button.MouseEnter:Connect(function()
  self:Sound(self.Profile,'Hover');Tween:Create(button,TweenInfo.new(.12),{BackgroundColor3=base:Lerp(Color3.fromRGB(70,160,195),.25)}):Play()
 end))
 table.insert(self.Connections,button.MouseLeave:Connect(function()Tween:Create(button,TweenInfo.new(.12),{BackgroundColor3=base}):Play()end))
end
function Controller:OwnPage(page)
 local t=self.CurrentTrade;if not t or terminal[t.State]then return end
 if self.PendingAction then self.PendingInventoryPage=page;return end
 self:RequestAction('Inventory',t.TradeId,t.Revision,page,function(response)
  if not response.Ok or not self.CurrentTrade or self.CurrentTrade.TradeId~=t.TradeId or terminal[self.CurrentTrade.State]then return end
  self.OwnPageNumber=response.Profile.Page;self.OwnHasNext=response.Profile.HasNext
  self.Trade.MainFrame.Page.Text='PÁGINA '..response.Profile.Page
  self:CardsFor(self.Trade,self.Trade.MainFrame.Mine.Inventory,response.Profile.Inventory,'Add')
 end)
end
function Controller:TradePacket(t)
 local previous=self.CurrentTrade
 if previous and previous.TradeId==t.TradeId and (t.Sequence or 0)<=(previous.Sequence or 0)then return end
 self.CurrentTrade=t
 if terminal[t.State]then
  self.Request.MainFrame.Requester.Text=text(t.Reason);self:Close(self.Request)
  if self.Trade.Enabled then self.Trade.MainFrame.Status.Text=text(t.Reason);self.Trade.MainFrame.Accept.Active=false;self.Trade.MainFrame.Confirm.Active=false;self:Sound(self.Trade,'Cancel')end
  self:Message(text(t.Reason));return
 end
 local uid=player.UserId;local mine=tostring(uid);local other=tostring(t.A==uid and t.B or t.A)
 if t.State=='Requested'then
  if t.B==uid then
   self:Show(self.Request);self.Request.MainFrame.Requester.Text=t.Names[tostring(t.A)]..' quiere intercambiar Slaps.'
   self.Request.MainFrame.Status.Text='Solo negociación: transferencias reales desactivadas.'
   self.Pool:Add(self.Request.MainFrame.Avatar,Players:GetPlayerByUserId(t.A),true)
  else self:Message('Solicitud enviada. Esperando respuesta.')end
  return
 end
 if not(self.Context and self.Context:GetController('WindowNavigationController'))then self:Close(self.Profile)end;self:Close(self.Request)
 local navigation=self.Context and self.Context:GetController('WindowNavigationController')
 if not self.Trade.Enabled and not(navigation and navigation:Contains('TradeHUD'))then self:Show(self.Trade)end
 local m=self.Trade.MainFrame
 m.Mine.Identity.Text=t.Names[mine];m.Theirs.Identity.Text=t.Names[other]
 m.Mine.Accepted.Text=t.Accepted[mine]and 'OFERTA ACEPTADA'or 'REVISANDO'
 m.Theirs.Accepted.Text=t.Accepted[other]and 'OFERTA ACEPTADA'or 'REVISANDO'
 for _,entry in ipairs({{Label=m.Mine.Accepted,Accepted=t.Accepted[mine]},{Label=m.Theirs.Accepted,Accepted=t.Accepted[other]}})do
  Tween:Create(entry.Label,TweenInfo.new(.18),{TextColor3=entry.Accepted and Color3.fromRGB(110,235,160)or Color3.fromRGB(180,205,225)}):Play()
 end
 self:CardsFor(self.Trade,m.Mine.Offers,t.Offers[mine]or {},'Remove')
 self:CardsFor(self.Trade,m.Theirs.Offers,t.Offers[other]or {},nil)
 self.Pool:Add(m.Mine.Avatar,player,true);self.Pool:Add(m.Theirs.Avatar,Players:GetPlayerByUserId(tonumber(other)),true)
 m.Accept.Active=t.State=='Negotiating';m.Confirm.Active=t.State=='FinalConfirmation'
 m.Accept.AutoButtonColor=m.Accept.Active;m.Confirm.AutoButtonColor=m.Confirm.Active
 m.Status.Text=t.State=='FinalConfirmation'and 'REVISÁ LO QUE ENTREGÁS Y RECIBÍS. Confirmación individual obligatoria.'or 'NEGOCIACIÓN DE PRUEBA · NO TRANSFIERE OBJETOS'
 if not previous or previous.TradeId~=t.TradeId or previous.State=='Requested'then task.delay(.3,function()self:OwnPage(1)end)end
end
function Controller:SetTarget(target)
 if self.Target==target and (not target or self.Prompt and self.Prompt.Parent==target.Character:FindFirstChild('HumanoidRootPart'))then return end
 if self.PromptConnection then self.PromptConnection:Disconnect();self.PromptConnection=nil end
 if self.Prompt then self.Prompt:Destroy();self.Prompt=nil end
 if self.Highlight then self.Highlight:Destroy();self.Highlight=nil end
 self.Target=target
 if not target then return end
 local root=target.Character:FindFirstChild('HumanoidRootPart')
 local prompt=Instance.new('ProximityPrompt');prompt.Name='SocialProfilePrompt';prompt.ActionText='Ver perfil';prompt.ObjectText=target.DisplayName
 prompt.HoldDuration=Config.PromptHoldSeconds;prompt.MaxActivationDistance=Config.InspectDistance;prompt.RequiresLineOfSight=true
 prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.GamepadKeyCode=Enum.KeyCode.ButtonX;prompt.ClickablePrompt=true;prompt.Parent=root
 local highlight=Instance.new('Highlight');highlight.Name='SocialTargetHighlight';highlight.Adornee=target.Character
 highlight.FillTransparency=.85;highlight.OutlineColor=Color3.fromRGB(74,210,240);highlight.FillColor=highlight.OutlineColor
 highlight.DepthMode=Enum.HighlightDepthMode.Occluded;highlight.Parent=target.Character
 self.Prompt=prompt;self.Highlight=highlight
 self.PromptConnection=prompt.Triggered:Connect(function()self:OpenProfile(target.UserId)end)
end
function Controller:PollTarget()
 local inventory=self.Context and self.Context:GetController('InventoryController')
 if inventory and inventory.Hud and inventory.Hud.Enabled then self:SetTarget(nil);return end
 if self.Profile.Enabled or self.Request.Enabled or self.Trade.Enabled or player:GetAttribute('MatchId')then self:SetTarget(nil);return end
 local camera=workspace.CurrentCamera;if not camera then self:SetTarget(nil);return end
 local point=UIS:GetMouseLocation();local ray
 if UIS.TouchEnabled or UIS.GamepadEnabled then ray=camera:ViewportPointToRay(camera.ViewportSize.X/2,camera.ViewportSize.Y/2)
 else ray=camera:ScreenPointToRay(point.X,point.Y)end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances=player.Character and {player.Character}or {}
 local hit=workspace:Raycast(ray.Origin,ray.Direction*200,params)
 local target=hit and Targeting.FromHit(Players,hit.Instance)
 self:SetTarget(Targeting.Valid(player,target,Config.InspectDistance)and target or nil)
end
function Controller:Init(context)
 if self.Initialized then return end
 self.Initialized=true;self.Context=context
 self.Generation=0;self.Cards={};self.Connections={};self.DisplayTokens={};self.Fades={};self.Pool=Viewports.new(Config.MaxActivePreviews)
 local gui=player:WaitForChild('PlayerGui')
 self.Profile=gui:WaitForChild('PlayerProfileHUD',15);self.Request=gui:WaitForChild('TradeRequestHUD',15);self.Trade=gui:WaitForChild('TradeHUD',15)
 assert(self.Profile and self.Request and self.Trade,'Social HUDs missing in Edit')
 local remotes=RS:WaitForChild('Remotes'):WaitForChild('Social');self.SelfInspect=remotes:WaitForChild('SelfProfile');self.Inspect=remotes:WaitForChild('Inspect');self.Action=remotes:WaitForChild('Action');self.Update=remotes:WaitForChild('Updated')
 self.Equip=remotes:WaitForChild('Equip')
 for _,hud in ipairs({self.Profile,self.Request,self.Trade})do
  hud.Enabled=false
  for _,button in ipairs(hud:GetDescendants())do if button:IsA('TextButton')then
   local surface=hud==self.Profile and button:FindFirstChild('Surface')
   local visual=surface or button;local base=visual.BackgroundColor3
   local border=surface and button:FindFirstChild('Stroke');local thickness=border and border.Thickness
   table.insert(self.Connections,button.MouseEnter:Connect(function()
    self:Sound(hud,'Hover');Tween:Create(visual,TweenInfo.new(.12),{BackgroundColor3=base:Lerp(Color3.fromRGB(135,210,255),surface and .15 or .25)}):Play()
    if border then Tween:Create(border,TweenInfo.new(.12),{Thickness=thickness+1}):Play()end
   end))
   table.insert(self.Connections,button.MouseLeave:Connect(function()
    Tween:Create(visual,TweenInfo.new(.12),{BackgroundColor3=base}):Play()
    if border then Tween:Create(border,TweenInfo.new(.12),{Thickness=thickness}):Play()end
   end))
  end end
 end
 self:BindProfileButton(gui:WaitForChild('PlayerHUD'):WaitForChild('ProfileButton',15))
 local function connect(button,fn)table.insert(self.Connections,button.Activated:Connect(fn))end
 local articles=self.Profile.MainFrame:FindFirstChild('Articles')
 if articles then connect(articles,function()self:Sound(self.Profile,'Click');self:SetArticlesMode(not self.ArticlesVisible)end)end
 for _,entry in ipairs({{'Challenge','Duel'},{'Invite','Group'}})do
  local button=self.Profile.MainFrame:FindFirstChild(entry[1])
  if button then connect(button,function()
   if button.Active and self.ProfileMode=='OtherPlayerProfile'and self.ProfileTarget~=player.UserId then
    local play=self.Context and self.Context:GetController('SocialPlayController')
    if play then self:Sound(self.Profile,'Click');play:Invite(entry[2],self.ProfileTarget)end
   end
  end)end
 end
 connect(self.Profile.MainFrame.Close,function()self:Close(self.Profile)end)
 connect(self.Profile.MainFrame.Previous,function()if (self.ProfilePage or 1)>1 then self:OpenProfile(self.ProfileTarget,self.ProfilePage-1,true,self.ProfileCategory)end end)
 connect(self.Profile.MainFrame.Next,function()if self.ProfileHasNext then self:OpenProfile(self.ProfileTarget,self.ProfilePage+1,true,self.ProfileCategory)end end)
 local tabs=self.Profile.MainFrame:FindFirstChild('InventoryTabs')
 if tabs then for category in pairs(categoryNames)do connect(tabs[category],function()if self.ProfileTarget then self:OpenProfile(self.ProfileTarget,1,true,category)end end)end end
 connect(self.Profile.MainFrame.Trade,function()if self.ProfileMode=='OtherPlayerProfile'and self.ProfileTarget and self.ProfileTarget~=player.UserId and self.Profile.MainFrame.Trade.Active then self:RequestAction('Invite',self.ProfileTarget)end end)
 local function act(name,value)local t=self.CurrentTrade;if t then self:RequestAction(name,t.TradeId,t.Revision,value)end end
 connect(self.Request.MainFrame.Accept,function()self:Sound(self.Request,'Accept');act('Respond',true)end)
 connect(self.Request.MainFrame.Decline,function()act('Respond',false)end)
 connect(self.Request.MainFrame.Close,function()act('Respond',false)end)
 connect(self.Trade.MainFrame.Close,function()if self.CurrentTrade and terminal[self.CurrentTrade.State]then self:Close(self.Trade)else act('Cancel')end end)
 connect(self.Trade.MainFrame.Cancel,function()if self.CurrentTrade and terminal[self.CurrentTrade.State]then self:Close(self.Trade)else act('Cancel')end end)
 connect(self.Trade.MainFrame.Accept,function()self:Sound(self.Trade,'Accept');act('Accept')end)
 connect(self.Trade.MainFrame.Confirm,function()self:Sound(self.Trade,'Confirm');act('Confirm')end)
 connect(self.Trade.MainFrame.Previous,function()if (self.OwnPageNumber or 1)>1 then self:OwnPage(self.OwnPageNumber-1)end end)
 connect(self.Trade.MainFrame.Next,function()if self.OwnHasNext then self:OwnPage(self.OwnPageNumber+1)end end)
end
function Controller:Start()
 if self.Started then return end
 self.Started=true
 if not self.Update or not self.Profile or not self.Request or not self.Trade then warn('[Social] Init incomplete; controller disabled');return end
 table.insert(self.Connections,self.Update.OnClientEvent:Connect(function(kind,payload)
  if kind=='Trade'then self:TradePacket(payload)
  elseif kind=='ProfileUnavailable'and self.ProfileTarget==payload.UserId then self:Close(self.Profile)end
 end))
 local function closeAll()self:SetTarget(nil);for _,hud in ipairs({self.Profile,self.Request,self.Trade})do self:Close(hud)end;self.Pool:Clear()end
 table.insert(self.Connections,player:GetAttributeChangedSignal('MatchId'):Connect(function()if player:GetAttribute('MatchId')then closeAll()end end))
 table.insert(self.Connections,player.CharacterRemoving:Connect(closeAll))
 table.insert(self.Connections,Players.PlayerRemoving:Connect(function(p)if self.ProfileTarget==p.UserId then self:Close(self.Profile)end;if self.Target==p then self:SetTarget(nil)end end))
 local dataUpdated=RS:WaitForChild('Remotes'):WaitForChild('Player'):WaitForChild('DataUpdated')
 table.insert(self.Connections,dataUpdated.OnClientEvent:Connect(function()
  -- Invalidation only; never render the client's private cached inventory.
  if self.ProfileMode=='SelfProfile'then self.NextSelfRefresh=workspace:GetServerTimeNow()+Config.RequestIntervalSeconds end
 end))
 local gui=player:WaitForChild('PlayerGui')
 for _,name in ipairs({'ShopHUD','PremiumShopHUD','SettingsGUI','CrateOpeningHUD'})do
  local hud=gui:FindFirstChild(name);local main=hud and hud:FindFirstChild('MainFrame')
  if main then
   local function changed()if self.ProfileTarget and self:WindowBusy()and not(self.Context and self.Context:GetController('WindowNavigationController'))then self:Close(self.Profile)end end
   table.insert(self.Connections,main:GetPropertyChangedSignal('Visible'):Connect(changed))
   table.insert(self.Connections,hud:GetPropertyChangedSignal('Enabled'):Connect(changed))
  end
 end
 local elapsed=0
 table.insert(self.Connections,RunService.RenderStepped:Connect(function(dt)
  self.Pool:Step(dt);elapsed+=dt
  if elapsed<Config.AimPollSeconds then return end;elapsed=0
  self:PollTarget();self:RefreshPreviews();if self.ProfileData then self:ProfileActions(self.ProfileData)end
  if self.ProfileTarget and self:WindowBusy()and not(self.Context and self.Context:GetController('WindowNavigationController'))then self:Close(self.Profile)end
  if self.ProfileTarget and self.Profile.Enabled and workspace:GetServerTimeNow()>=(self.NextSelfRefresh or math.huge)then
   self:OpenProfile(self.ProfileTarget,self.ProfilePage,true)
  end
  local t=self.CurrentTrade
  if t and not terminal[t.State]then
   local now=workspace:GetServerTimeNow()
   if t.State=='Requested'then self.Request.MainFrame.Countdown.Text='Expira en '..math.max(0,math.ceil(t.ExpiresAt-now))..' s'
   elseif t.State=='SafetyCountdown'then self.Trade.MainFrame.Status.Text='SEGURIDAD: '..math.max(0,math.ceil(t.Deadline-now))..' s · NO TRANSFIERE OBJETOS'end
  end
 end))
end
function Controller:Destroy()
 self.Initialized=false;self.Started=false;self.Generation+=1;self:SetTarget(nil);self.Pool:Clear()
 for _,c in ipairs(self.Connections or {})do c:Disconnect()end;self.Connections={}
 for _,hud in ipairs({self.Profile,self.Request,self.Trade})do self:Close(hud)end
end
return Controller
]====]
-- Actual policy/public projection/negotiation modules over disposable tables.
local n=0;local function check(v,m)n+=1;assert(v,m)end
local loaded={};local parent=setmetatable({},{__index=function(_,key)return key end})
parent.Trading=parent
local shared={SlapCrates=parent,SocialConfig='SocialConfig'};local fakeServices={ReplicatedStorage={Shared=shared},Players={}}
local world={};local clock=500;world.GetServerTimeNow=function()return clock end
local function load(name)
 if loaded[name]then return loaded[name]end
 local f=assert(loadstring(Sources[name],name))
 setfenv(f,setmetatable({script={Parent=parent},game={GetService=function(_,key)return fakeServices[key]or {}end},
  workspace=world,Color3={fromRGB=function(...)return {...}end},require=load},{__index=getfenv()}))
 local result=f();loaded[name]=result;return result
end
local cfg=load('SocialConfig');local catalog=load('Catalog');local Policy=load('TradePolicy');local Public=load('PublicInventory')
local Engine=load('TradeEngine');local Tx=load('TradeTransactionService');local Recovery=load('TradeRecoveryService')
local function copy(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t end
local function same(a,b)if type(a)~=type(b)then return false end;if type(a)~='table'then return a==b end;for k,v in pairs(a)do if not same(v,b[k])then return false end end;for k in pairs(b)do if a[k]==nil then return false end end;return true end
local function inventory(uid)
 local inv={Owned={Slaps={['Classic:Basic']=true}},Equipped={Slaps='Classic:Common'},SlapUnits={},CrateOperations={},Crates={}}
 local crate=catalog.Crates.Order[1]
 for i,id in ipairs({'Common','Uncommon','Rare','Gold','Arcoiris','Emote','Wings'})do
  local key=tostring(uid)..':operation-'..i;local reward='Classic:'..id
  inv.SlapUnits[key]={UnitId=key,RewardId=reward,SlapId='Classic',VariationId=id,OperationId='operation-'..i,OwnerUserId=uid,Origin='Crate'}
  inv.CrateOperations['operation-'..i]={CrateId=crate,OwnerUserId=uid,State='Completed',Kind='Open',UnitId=key,RewardId=reward}
  inv.Owned.Slaps[reward]=true
 end
 return inv
end
local inv=inventory(-1);local original=copy(inv);local unit=inv.SlapUnits['-1:operation-1']
check(Policy.Check(unit,inv,-1,catalog),'ordinary unit explicitly eligible')
check(not Policy.Check(unit,inv,-2,catalog),'different owner rejected')
for _,field in ipairs({'SlapId','VariationId','RewardId','Origin','OperationId','OwnerUserId'})do
 local bad=copy(unit);bad[field]='invented';check(not Policy.Check(bad,inv,-1,catalog),'invalid identity/provenance '..field)
end
for _,flag in ipairs({'Locked','TradeLocked','NonTradable','PremiumOnly','Temporary','TestOnly'})do local bad=copy(unit);bad[flag]=true;check(not Policy.Check(bad,inv,-1,catalog),'locked unit rejected')end
local badInv=copy(inv);badInv.CrateOperations[unit.OperationId].State='GrantCommitted';check(not Policy.Check(unit,badInv,-1,catalog),'pending stock reconciliation cannot trade')
badInv=copy(inv);badInv.CrateOperations[unit.OperationId].CrateId='PremiumOnlyUnknown';check(not Policy.Check(unit,badInv,-1,catalog),'unknown/premium source cannot be inferred from Origin=Crate')
badInv=copy(inv);badInv.CrateOperations[unit.OperationId].UnitId='another-unit';check(not Policy.Check(unit,badInv,-1,catalog),'journal must contain exact unit')
badInv=copy(inv);badInv.CrateOperations[unit.OperationId].Rewards='malformed';check(not Policy.Check(unit,badInv,-1,catalog),'malformed rich journal fails closed')
local data={Wins=12,Losses=4,Kills=17,Coins=9999,Token='private',Inventory=inv,_PremiumProfile={Token='secret'}}
local public=Public.Profile({UserId=-1,DisplayName='Visible',Name='Username'},data,catalog,cfg,1)
check(public.Stats.Wins==12 and public.Stats.Losses==4 and public.Stats.TotalKills==17,'reuse persisted stats')
check(public.Coins==nil and public.Token==nil and public._PremiumProfile==nil and public.Inventory.CrateOperations==nil,'specific public response excludes private fields')
check(public.Progression.Available==false and public.Progression.Level==nil and public.Progression.Experience==nil,'no fabricated level or EXP')
local default;for _,row in ipairs(public.Inventory)do if row.RewardId=='Classic:Basic'then default=row end end
check(#public.Inventory==8 and default and default.UnitId==nil and not default.Tradable,'default entitlement visible but no fabricated transferable identity')
check(same(original,inv),'public projection never mutates inventory')
local rows=Public.Build(data,-1,catalog);local keys={};for _,row in ipairs(rows)do if row.UnitId then keys[row.UnitId]=row end end
check(keys[unit.UnitId].Tradable and keys[unit.UnitId].Equipped,'equipped cosmetic shown without unequipping or fabricating ownership')
local pageConfig=table.clone(cfg);pageConfig.InventoryPageSize=3
check(#Public.Profile({UserId=-1},data,catalog,pageConfig,1).Inventory==3 and Public.Profile({UserId=-1},data,catalog,pageConfig,1).HasNext,'bounded pagination')
check(#Public.Profile({UserId=-1},data,catalog,pageConfig,3).Inventory==2,'last inventory page')
local dup=copy(data);local clone=copy(unit);clone.UnitId='-1:duplicate';dup.Inventory.SlapUnits[clone.UnitId]=clone
check(#Public.Build(dup,-1,catalog)==9,'existing duplicate units stay separately visible')

local function fixture()
 local f={Now=100,Eligible={[-1]=true,[-2]=true,[-3]=true},Distance=3,Emitted={},Inventories={[-1]=inventory(-1),[-2]=inventory(-2),[-3]=inventory(-3)},Commits=0}
 local serial=0
 f.Engine=Engine.new(cfg,{
  Clock=function()return f.Now end,Id=function()serial+=1;return 'trade-'..serial end,
  Eligible=function(uid)return f.Eligible[uid]==true end,Distance=function()return f.Distance end,Name=function(uid)return 'Player'..uid end,
  Unit=function(uid,id)for _,row in ipairs(Public.Build({Inventory=f.Inventories[uid]},uid,catalog))do if row.UnitId==id then return row end end end,
  Emit=function(uid,kind,packet)table.insert(f.Emitted,{UserId=uid,Kind=kind,Packet=packet})end,
  Commit=function(intent)f.Commits+=1;return Tx.Commit(intent,{PretendDurable=true})end,
 })
 function f:Invite()local ok,id=self.Engine:Invite(-1,-2);assert(ok,id);self.Id=id;return self.Engine.Trades[id]end
 function f:Act(uid,action,revision,item)return self.Engine:Act(uid,action,self.Id,revision,item)end
 function f:Negotiate()local t=self:Invite();assert(self:Act(-2,'Respond',0,true));return t end
 return f
end
local f=fixture();check(not f.Engine:Invite(-1,-1),'self invitation rejected')
f.Distance=11;check(not f.Engine:Invite(-1,-2),'distance limit');f.Distance=3
f.Distance=0/0;check(not f.Engine:Invite(-1,-2),'non-finite distance fails closed');f.Distance=3
f.Eligible[-1]=false;check(not f.Engine:Invite(-1,-2),'match/unavailable cannot invite');f.Eligible[-1]=true
local t=f:Invite();check(t.State=='Requested' and t.ExpiresAt==115,'valid invitation with fifteen-second deadline')
check(not f.Engine:Invite(-1,-2)and not f.Engine:Invite(-3,-2),'duplicate and busy target rejected')
check(not f:Act(-3,'Respond',0,true)and not f:Act(-1,'Respond',0,true),'third party and requester cannot accept for target')
check(not f:Act(-2,'Respond',1,true),'stale invitation revision rejected')
check(f:Act(-2,'Respond',0,false)and t.State=='Cancelled'and f.Engine.Busy[-1]==nil,'decline releases state')
check(not f.Engine:Invite(-1,-2),'invitation cooldown preserved after decline')
f.Engine:CancelForPlayer(-1);check(not f.Engine:Invite(-1,-2),'respawn cancellation cannot reset invite cooldown')
f=fixture();t=f:Invite();f.Now=115;f.Engine:Tick();check(t.Terminal and t.Reason=='Expired','invitation expiration')
check(not f:Act(-2,'Respond',0,true),'late acceptance rejected')
f=fixture();t=f:Negotiate();local before=copy(f.Inventories)
check(f:Act(-1,'Add',0,'-1:operation-1')and t.Revision==1,'valid unit offer')
check(not f:Act(-1,'Add',1,'-1:operation-1'),'duplicate offer rejected')
check(not f:Act(-1,'Add',1,'does-not-exist')and not f:Act(-1,'Add',1,'-2:operation-1'),'nonexistent and foreign units rejected')
check(not f:Act(-1,'Add',0,'-1:operation-2'),'stale offer revision rejected')
check(f:Act(-1,'Accept',1),'first acceptance')
check(f:Act(-2,'Add',1,'-2:operation-1')and not t.Accepted[-1]and not t.Accepted[-2]and next(t.Confirmed)==nil,'any edit invalidates both acceptances and final confirmations')
check(not f:Act(-1,'Confirm',2),'premature final confirmation rejected')
check(f:Act(-1,'Accept',2)and f:Act(-2,'Accept',2)and t.State=='SafetyCountdown'and t.Deadline==105,'two acceptances start five-second safety step')
check(not f:Act(-1,'Remove',2,'-1:operation-1'),'offers locked during safety countdown')
f.Now=104.999;f.Engine:Tick();check(t.State=='SafetyCountdown'and not f:Act(-1,'Confirm',2),'exact deadline enforced')
f.Now=105;f.Engine:Tick();check(t.State=='FinalConfirmation'and not next(t.Confirmed),'countdown never auto-confirms')
check(not f:Act(-1,'Confirm',1),'old final confirmation rejected')
check(f:Act(-1,'Confirm',2)and f.Commits==0,'one confirmation is insufficient')
check(f:Act(-2,'Confirm',2)and f.Commits==1 and t.State=='Cancelled'and t.Reason=='TradeCommitDisabled','both confirmations stop at disabled commit')
check(same(before,f.Inventories),'no transfer of equipped or unequipped objects and no duplicate ownership')
check(next(f.Engine.Reserved)==nil and not f.Engine.Busy[-1]and not f.Engine.Busy[-2],'disabled commit releases draft reservations')
check(not f:Act(-2,'Confirm',2)and f.Commits==1,'confirmation replay never calls commit twice')
local packet=f.Emitted[#f.Emitted].Packet
check(packet.TradeCommitEnabled==false and packet.Names['-1']=='Player-1'and packet.Offers['-1'][1].UnitId=='-1:operation-1','wire DTO preserves signed IDs as string keys')
for _,event in ipairs(f.Emitted)do check(event.UserId==-1 or event.UserId==-2,'no unrelated lobby player receives trade state')end
for _,kind in ipairs({'Disconnect','Match','Expired','ChangeInventory'})do
 f=fixture();t=f:Negotiate();f:Act(-1,'Add',0,'-1:operation-1')
 if kind=='Disconnect'then f.Engine:Disconnect(-2)
 elseif kind=='Match'then f.Eligible[-2]=false;f.Engine:Tick()
 elseif kind=='Expired'then f.Now=281;f.Engine:Tick()
 else f.Inventories[-1].SlapUnits['-1:operation-1']=nil;check(not f:Act(-1,'Accept',1),'removed unit cannot be accepted')end
 check(t.Terminal and next(f.Engine.Reserved)==nil and f.Commits==0,'safe cancellation '..kind)
end
f=fixture();t=f:Negotiate()
for i=1,6 do check(f:Act(-1,'Add',i-1,'-1:operation-'..i),'each of six offers accepted')end
check(not f:Act(-1,'Add',6,'-1:operation-7'),'seventh unit rejected')
check(f:Act(-1,'Remove',6,'-1:operation-1')and t.Revision==7 and #t.Offers[-1]==5,'remove updates revision')
check(f:Act(-1,'Cancel',7)and not f:Act(-1,'Cancel',7),'cancellation idempotent and no re-entry')
f.Now=131;f.Engine:Tick();check(next(f.Engine.Trades)==nil,'terminal records are bounded and reclaimed')
f=fixture();t=f:Negotiate();f.Engine.Reserved['-1:-1:operation-1']='other-trade'
check(not f:Act(-1,'Add',0,'-1:operation-1'),'reservation conflict rejected')
check(not Tx.Availability(cfg,{Environment='Studio',ProviderName='InMemory',WritesToCloud=false},true),'InMemory commit hard-disabled')
local force=table.clone(cfg);force.TradeCommitEnabled=true
check(not Tx.Availability(force,{Environment='Production',ProviderName='RobloxDataStore',WritesToCloud=true},false),'flag alone cannot enable unsupported durable bridge')
check(not Tx.Commit({}, {UpdateAsync=function()error('must never write')end}),'no backend writes even with fake adapter')
check(not Recovery.Status().DurableRecoveryAvailable and not Recovery.Reconcile('missing'),'durable recovery explicitly unavailable; never reports simulated recovery as durable')

-- Actual local targeting helper with distance witness.
local target=load('Targeting')
local function position(x)return setmetatable({X=x},{__sub=function(a,b)return {Magnitude=math.abs(a.X-b.X)}end})end
local function p(id,x)
 local v={UserId=id,Parent=true,Attributes={},Character={}}
 function v:GetAttribute(k)return self.Attributes[k]end
 function v.Character:FindFirstChild()return {Position=position(x)}end
 function v.Character:FindFirstChildOfClass()return {Health=100}end
 return v
end
local a,b=p(-1,0),p(-2,10)
check(target.Valid(a,b,10),'local valid target at exact maximum distance')
check(not target.Valid(a,a,10),'self targeting rejected')
b=p(-2,10.01);check(not target.Valid(a,b,10),'local range check beyond maximum')
b=p(-2,3);b.Attributes.MatchId='active';check(not target.Valid(a,b,10),'local presentation hides active target')
b.Attributes.MatchId=nil;a.Attributes.MatchId='active';check(not target.Valid(a,b,10),'active requester has no profile prompt')
a.Attributes.MatchId=nil;b.Parent=nil;check(not target.Valid(a,b,10),'disconnected target removed')
local pool=load('ViewportPool').new(12);local destroyed,disconnected=0,0
local view={CurrentCamera=true}
pool.Rows[view]={World={Destroy=function()destroyed+=1 end},Camera={Destroy=function()destroyed+=1 end},Connections={{Disconnect=function()disconnected+=1 end}}};pool.Count=1
pool:Remove(view);pool:Remove(view)
check(pool.Count==0 and next(pool.Rows)==nil and view.CurrentCamera==nil and destroyed==2 and disconnected==1,'viewport cleanup idempotently destroys WorldModel/camera and disconnects resize')
check(cfg.MaxActivePreviews==12 and cfg.TradeCommitEnabled==false,'render budget and commit flag')

-- Real remote handler/service methods: distance, session authority, rate limiting and public DTO.
local Service=load('SocialService');local ps=fakeServices.Players
local aa,bb=p(-1,0),p(-2,3);aa.Parent=ps;bb.Parent=ps
for _,who in ipairs({aa,bb})do
 who.Name='RealName'..who.UserId;who.DisplayName='Visible'..who.UserId
 function who.Character:IsDescendantOf(w)return w==world end
 local get=who.Character.FindFirstChild
 who.Character.FindFirstChild=function(self,k)local root=get(self,k);root.IsA=function(_,class)return class=='BasePart'end;return root end
end
local users={[-1]=aa,[-2]=bb};ps.GetPlayerByUserId=function(_,id)return users[id]end
local active={};local ready=true
Service.Profiles={IsShopDataReady=function()return ready end,GetPlayerData=function(_,who)return{Wins=5,Losses=6,Kills=7,Inventory=inventory(who.UserId),Coins=1000,_PremiumProfile={Token='never-public'}}end}
Service.Rounds={GetSessionForPlayer=function(_,who)return active[who]end};Service.LastRequest={};Service.Viewers={}
Service.Engine=Engine.new(cfg,{Clock=function()return clock end,Id=function()return 'remote-trade'end,Name=function(id)return users[id].DisplayName end,
 Eligible=function(id)return Service:Eligible(id)end,Distance=function(a,b)return Service:Distance(a,b)end,
 Unit=function(id,key)return Service:Unit(id,key)end,Emit=function()end,Commit=Tx.Commit})
local function inspect(id,page)clock+=.3;return Service:Inspect(aa,id,page)end
check(Service:Eligible(-1)and Service:Eligible(-2),'real service accepts two loaded lobby players')
local inspected=inspect(-2);check(inspected.Ok and inspected.Profile.Stats.TotalKills==7 and inspected.Profile.Coins==nil and inspected.Profile._PremiumProfile==nil,'real handler exports only public projection')
check(not Service:Inspect(aa,-2).Ok,'real handler rate limit')
check(not inspect(-1).Ok,'real handler rejects self inspection')
check(not inspect(0).Ok and not inspect('remote-id').Ok and not inspect(0/0).Ok,'invalid target identity rejected')
check(not inspect(-2,0).Ok and not inspect(-2,math.huge).Ok,'page bounds validated')
active[aa]={Id='authoritative-session'};check(not inspect(-2).Ok,'server session blocks requester even with no local MatchId attribute')
active[aa]=nil;active[bb]={Id='target-session'};check(not inspect(-2).Ok,'server session blocks active target')
active[bb]=nil;ready=false;check(not inspect(-2).Ok,'unloaded profiles blocked');ready=true
users[-2]=nil;check(not inspect(-2).Ok,'disconnected target blocked');users[-2]=bb
local rootFunction=bb.Character.FindFirstChild;bb.Character.FindFirstChild=function()return {Position=position(11),IsA=function()return true end}end
check(not inspect(-2).Ok,'server distance beyond ten studs rejected');bb.Character.FindFirstChild=rootFunction
clock+=.3;local invitation=Service:Action(aa,'Invite',-2)
check(invitation.Ok and invitation.TradeId=='remote-trade','real invitation handler')
clock+=.3;check(not Service:Action(aa,'Inventory','foreign-trade',0,1).Ok,'own inventory cannot be requested without trade membership')
clock+=.3;local owned=Service:Action(aa,'Inventory','remote-trade',0,1)
check(owned.Ok and owned.Profile.UserId==-1 and owned.Profile.Coins==nil,'own inventory during negotiation uses same public mapper')
clock+=.3;check(not Service:Action(aa,'Confirm','remote-trade',-1).Ok,'invalid remote revision rejected')
print('PASS PlayerInventoryTradingV10: '..n..' isolated assertions; durable protocol NOT IMPLEMENTED; no Studio/transfer/cloud execution')

-- Appended to V1.0 fixtures: actual server handlers and client controller, no Studio execution.
local baseCount=n
local function own(page)clock+=.3;return Service:SelfProfile(aa,page)end
local ownData={Wins=18,Losses=4,Kills=31,Inventory=inventory(-1),Coins=1234,_PremiumProfile={Private=true}}
Service.Profiles.GetPlayerData=function(_,who)return who==aa and ownData or data end
local snapshot=copy(ownData)
local selfResult=own()
check(selfResult.Ok and selfResult.Profile.UserId==aa.UserId,'authenticated caller is self profile owner')
check(selfResult.Profile.ProfileMode=='SelfProfile','server assigns self mode')
check(selfResult.Profile.Username==aa.Name and selfResult.Profile.DisplayName==aa.DisplayName,'own identity')
check(selfResult.Profile.Stats.Wins==18 and selfResult.Profile.Stats.Losses==4 and selfResult.Profile.Stats.TotalKills==31,'own statistics')
check(#selfResult.Profile.Inventory==8,'same complete public inventory mapper')
check(selfResult.Profile.Coins==nil and selfResult.Profile._PremiumProfile==nil,'private persistence not exposed')
check(same(snapshot,ownData),'self inspection does not mutate inventory or data')
check(not Service:SelfProfile(aa).Ok,'self shares server rate limit')
for _,page in ipairs({0,-1,1.5,math.huge,0/0,'-2',false})do check(not own(page).Ok,'invalid self page rejected '..tostring(page))end
check(own(10000).Profile.Page==1,'removed/shrunk pages clamp to last existing page')
clock+=.3;check(not Service:SelfProfile(bb,-1,true).Ok,'foreign id/mode cannot masquerade as self arguments')
active[aa]={Id='match'};check(not own().Ok,'authoritative session blocks even if client MatchId absent')
active[aa]=nil;aa.Attributes.Queue='waiting';check(own().Ok,'waiting outside an admitted session remains eligible');aa.Attributes.Queue=nil
ready=false;check(not own().Ok,'unloaded self profile blocked');ready=true
local realParent=aa.Parent;aa.Parent=nil;check(not own().Ok,'disconnected self blocked');aa.Parent=realParent
local fake=copy(aa);clock+=.3;check(not Service:SelfProfile(fake).Ok,'forged player identity rejected')
clock+=.3;check(not Service:Action(aa,'Invite',aa.UserId).Ok,'actual server rejects self trade')
local other=inspect(-2);check(other.Ok and other.Profile.ProfileMode=='OtherPlayerProfile','other inspection retained with server mode')
ownData.Inventory.Equipped.Slaps='Classic:Rare'
local updated=own().Profile;local equipped
for _,row in ipairs(updated.Inventory)do if row.Equipped then equipped=row end end
check(equipped and equipped.VariationId=='Rare','equipment refresh reads authoritative current data')
ownData.Inventory.SlapUnits['-1:operation-1']=nil;ownData.Inventory.Owned.Slaps['Classic:Common']=nil
check(#own().Profile.Inventory==7,'ownership change reflected on next read')
local events={};Service.Update={FireClient=function(_,who,kind,payload)table.insert(events,{who,kind,payload})end}
Service.Viewers={[aa]=aa.UserId};active[aa]={Id='began'};Service:ValidateViewers()
check(Service.Viewers[aa]==nil and #events==1 and events[1][2]=='ProfileUnavailable','server invalidates open own view when session starts')
Service:ValidateViewers();check(#events==1,'invalidation emitted once');active[aa]=nil
Service.Viewers={[aa]=aa.UserId};Service:ValidateViewers();check(Service.Viewers[aa]==aa.UserId,'self watcher never requires proximity to another player')

-- Disposable client GUI/signal scheduler fixtures execute real controller methods.
local function signal()
 local out={Listeners={}}
 function out:Connect(fn)local c={Connected=true};function c:Disconnect()self.Connected=false end;table.insert(self.Listeners,{fn,c});return c end
 function out:Fire(...)for _,v in ipairs(self.Listeners)do if v[2].Connected then v[1](...)end end end
 return out
end
local later={};local deferred=false;local spawned={}
local scheduler={spawn=function(fn)if deferred then table.insert(spawned,fn)else fn()end end,delay=function(_,fn)table.insert(later,fn)end}
local function gui(name)
 local g={Name=name,Enabled=false,MainFrame={GroupTransparency=0,Avatar={},Collection={},Trade={},Identity={},Stats={},Progression={},Page={},Status={}}}
 function g:FindFirstChild(key)return rawget(self,key)end
 function g.MainFrame:FindFirstChild(key)return rawget(self,key)end
 return g
end
local profile,request,trade=gui('PlayerProfileHUD'),gui('TradeRequestHUD'),gui('TradeHUD')
trade.MainFrame.Mine={Avatar={}};trade.MainFrame.Theirs={Avatar={}}
local screens={PlayerProfileHUD=profile,TradeRequestHUD=request,TradeHUD=trade,ShopHUD=gui('ShopHUD'),PremiumShopHUD=gui('PremiumShopHUD'),SettingsGUI=gui('SettingsGUI'),CrateOpeningHUD=gui('CrateOpeningHUD')}
for _,name in ipairs({'ShopHUD','PremiumShopHUD','SettingsGUI'})do screens[name].MainFrame.Visible=false end
local playerGui={};function playerGui:FindFirstChild(key)return screens[key]end
aa.FindFirstChild=function(_,key)if key=='PlayerGui'then return playerGui end end
fakeServices.Players.LocalPlayer=aa
local function stableRows(rows)if rows.Inventory then return tostring(rows.Category)..':'..stableRows(rows.Inventory)end;local out={};for _,row in ipairs(rows)do table.insert(out,row.EntryId..':'..tostring(row.Equipped))end;return table.concat(out,',')end
fakeServices.HttpService={JSONEncode=function(_,rows)return stableRows(rows)end}
fakeServices.TweenService={Create=function()return{Play=function()end,Cancel=function()end,Destroy=function()end}end}
fakeServices.RunService={RenderStepped=signal()}
parent.Parent=parent;parent.Social=parent
local chunk=assert(loadstring(Sources.SocialController,'SocialController'))
setfenv(chunk,setmetatable({script={Parent=parent},game={GetService=function(_,key)return fakeServices[key]or {}end},workspace=world,require=load,
 task=scheduler,TweenInfo={new=function()return{}end},Color3={fromRGB=function()return{}end}},{__index=getfenv()}))
local C=chunk();C.Profile=profile;C.Request=request;C.Trade=trade;C.Generation=0;C.Connections={};C.Cards={};C.DisplayTokens={};C.Fades={}
local renders,avatars,removes=0,0,0
C.Pool={Remove=function()removes+=1 end,Add=function(_,view,owner,isAvatar)avatars+=1;check(owner==aa or owner==bb,'same pool receives actual player');check(isAvatar,'avatar route uses existing WorldModel renderer')end,Clear=function()end}
C.CardsFor=function(_,hud,collection,rows,mode)renders+=1;check(hud==profile and collection==profile.MainFrame.Collection and mode==nil,'same inventory renderer in read-only mode');check(#rows>0,'owned variations delivered to renderer')end
local sounds={};C.Sound=function(_,_,key)table.insert(sounds,key)end
local readCalls,foreignCalls=0,0
C.SelfInspect={InvokeServer=function(_,page,category)readCalls+=1;check(category=='Slaps','self wire has page/category only, never target or arbitrary mode');return own(page)end}
C.Inspect={InvokeServer=function(_,id,page)foreignCalls+=1;return inspect(id,page)end}
local button={Activated=signal(),MouseEnter=signal(),MouseLeave=signal(),BackgroundColor3={Lerp=function(self)return self end}}
C:BindProfileButton(button);check(#C.Connections==3,'one button binding with tracked cleanup connections')
button.Activated:Fire()
check(profile.Enabled and C.ProfileTarget==aa.UserId and C.ProfileMode=='SelfProfile','button opens local player through actual self remote flow')
check(readCalls==1 and foreignCalls==0,'self uses dedicated authenticated route')
check(profile.MainFrame.Identity.Text==aa.DisplayName..'\n@'..aa.Name,'own display and username presented')
check(string.find(profile.MainFrame.Stats.Text,'VICTORIAS 18',1,true)~=nil,'real statistics presented')
check(profile.MainFrame.Trade.Visible==false and profile.MainFrame.Trade.Active==false and profile.MainFrame.Trade.Selectable==false,'trade hidden and non-activable in own profile')
check(avatars==1 and renders==1,'same avatar and owned inventory renders')
local beforeRenders=renders;C:OpenProfile(aa.UserId,1,true)
check(renders==beforeRenders and avatars==1,'unchanged refresh preserves rotating previews and avatar')
ownData.Inventory.Equipped.Slaps='Classic:Gold';C:OpenProfile(aa.UserId,1,true)
check(renders==beforeRenders+1 and avatars==1,'equipment changes refresh cards without resetting avatar')
C:Close(profile);check(C.ProfileTarget==nil and C.ProfileMode==nil and C.NextSelfRefresh==nil and removes>0,'close releases profile target and avatar')
button.Activated:Fire();check(C.ProfileTarget==aa.UserId,'reopen through same button')
for _,fn in ipairs(later)do fn()end;later={}
check(profile.Enabled,'stale close fade cannot hide reopened profile')
check(#C.Connections==3,'reopening adds no button events')
C:Close(profile);for _,fn in ipairs(later)do fn()end;later={}
C:OpenProfile(bb.UserId,1)
check(C.ProfileTarget==bb.UserId and profile.MainFrame.Trade.Visible and profile.MainFrame.Trade.Active and profile.MainFrame.Trade.Selectable,'other profile preserves trade UI')
check(foreignCalls==1,'other uses original inspect remote')
check(not C:ApplyProfile({UserId=aa.UserId,ProfileMode='OtherPlayerProfile'}),'mismatched server identity/mode ignored before render')
check(not C:ApplyProfile({UserId=bb.UserId,ProfileMode='SelfProfile'}),'foreign self mode ignored')
C:Close(profile);for _,fn in ipairs(later)do fn()end;later={}
aa.Attributes.MatchId='session';local beforeCalls=readCalls;button.Activated:Fire();check(readCalls==beforeCalls and C.ProfileTarget==nil,'local authoritative MatchId blocks opening');aa.Attributes.MatchId=nil
screens.ShopHUD.Enabled=true;screens.ShopHUD.MainFrame.Visible=true
button.Activated:Fire();check(readCalls==beforeCalls,'existing ordinary shop prevents overlapping own profile')
screens.ShopHUD.MainFrame.Visible=false;screens.PremiumShopHUD.Enabled=true;screens.PremiumShopHUD.MainFrame.Visible=true
check(C:WindowBusy(),'premium prevents overlapping profile');screens.PremiumShopHUD.Enabled=false
screens.SettingsGUI.Enabled=true;screens.SettingsGUI.MainFrame.Visible=true
check(C:WindowBusy(),'settings prevents overlapping profile');screens.SettingsGUI.MainFrame.Visible=false
screens.CrateOpeningHUD.Enabled=true;check(C:WindowBusy(),'crate opening blocks profile without a MainFrame');screens.CrateOpeningHUD.Enabled=false
request.Enabled=true;check(C:WindowBusy(),'trade request prevents overlapping profile');request.Enabled=false
deferred=true;C:OpenProfile(aa.UserId,1);C:Close(profile);local count=avatars;deferred=false;table.remove(spawned,1)()
check(C.ProfileTarget==nil and avatars==count,'late server response cannot reopen closed window')
C.Initialized=true;C:Init({});check(#C.Connections==3,'Init is idempotent and does not duplicate bindings')
-- Real Start listeners: session auto-close, data invalidation, window changes and cleanup.
local attributeChanged,characterRemoving=signal(),signal()
aa.GetAttributeChangedSignal=function()return attributeChanged end;aa.CharacterRemoving=characterRemoving
aa.WaitForChild=function(_,key)assert(key=='PlayerGui');return playerGui end
ps.PlayerRemoving=signal()
local dataSignal=signal();local remoteTree={Player={DataUpdated={OnClientEvent=dataSignal}}}
function remoteTree:WaitForChild(key)return self[key]end
function remoteTree.Player:WaitForChild(key)return self[key]end
fakeServices.ReplicatedStorage.WaitForChild=function(_,key)assert(key=='Remotes');return remoteTree end
for _,name in ipairs({'ShopHUD','PremiumShopHUD','SettingsGUI','CrateOpeningHUD'})do
 local hud=screens[name];hud.Changed=signal();hud.MainFrame.Changed=signal()
 function hud:GetPropertyChangedSignal()return self.Changed end
 function hud.MainFrame:GetPropertyChangedSignal()return self.Changed end
end
playerGui.WaitForChild=playerGui.FindFirstChild
C.Update={OnClientEvent=signal()};C.Pool.Step=function()end
C.PollTarget=function()end;C.RefreshPreviews=function()end;C.SetTarget=function()end
C:Start();local bound=#C.Connections;C:Start();check(#C.Connections==bound,'Start adds no duplicate listeners')
C:OpenProfile(aa.UserId,1);aa.Attributes.MatchId='admitted';attributeChanged:Fire()
check(C.ProfileTarget==nil and C.ProfileMode==nil,'authoritative MatchId event closes existing own profile')
aa.Attributes.MatchId=nil;C:OpenProfile(aa.UserId,1)
local due=C.NextSelfRefresh;dataSignal:Fire({Inventory={Fake=true}})
check(C.NextSelfRefresh<due,'DataUpdated invalidates rather than trusting client payload')
clock+=.3;local reads=readCalls;fakeServices.RunService.RenderStepped:Fire(.2)
check(readCalls==reads+1 and C.ProfileTarget==aa.UserId,'visible own profile refetches current server data')
screens.ShopHUD.MainFrame.Visible=true;screens.ShopHUD.MainFrame.Changed:Fire()
check(C.ProfileTarget==nil,'shop opening closes profile without modifying shop state')
check(screens.ShopHUD.MainFrame.Visible,'existing shop remains open');screens.ShopHUD.MainFrame.Visible=false
C:OpenProfile(aa.UserId,1);C.Update.OnClientEvent:Fire('ProfileUnavailable',{UserId=aa.UserId})
check(C.ProfileTarget==nil,'server invalidation closes own view independently of attributes')
C:OpenProfile(aa.UserId,1);characterRemoving:Fire();check(C.ProfileTarget==nil,'respawn removes own profile and preview target')
check(cfg.TradeCommitEnabled==false,'real transfers remain disabled after own reads')
for _,c in ipairs(C.Connections)do c:Disconnect()end
local calls=readCalls;button.Activated:Fire();check(readCalls==calls,'tracked button connection disconnects cleanly')
print('PASS PlayerInventoryV11: '..(n-baseCount)..' additional isolated assertions; visual/mobile/multiplayer validation remains manual')

-- Appended to established social fixtures. Real projection/handlers/controller; no Roblox execution.
do
 local startCount=n
 Service.Engine.Busy[aa.UserId]=nil;active[aa]=nil;ready=true
 local effects={PointEffects={{Id='Basic',Category='PointEffects',DisplayName='Punto básico',Rarity='Basic',IsAvailable=true},{Id='Fire',Category='PointEffects',DisplayName='Fuego',Rarity='Rare',IsAvailable=true},{Id='Missing',Category='PointEffects',DisplayName='Ausente',IsAvailable=false}},DeathEffects={{Id='BasicKill',Category='DeathEffects',DisplayName='Muerte básica',IsAvailable=true},{Id='Frost',Category='DeathEffects',DisplayName='Hielo',IsAvailable=true},{Id='Void',Category='DeathEffects',DisplayName='Vacío',IsAvailable=true}}}
 ownData.Inventory.Owned.PointEffects={Basic=true,Fire=true,Missing=true}
 ownData.Inventory.Owned.DeathEffects={BasicKill=true,Frost=true}
 ownData.Inventory.Equipped.PointEffects='Basic';ownData.Inventory.Equipped.DeathEffects='BasicKill'
 local shopCalls=0;local shop={}
 function shop:GetCatalog(category)return effects[category]or {}end
 function shop:EquipProduct(p,id,category)
  shopCalls+=1;check(p==aa,'authenticated caller is the only equip target')
  if id=='Missing'then return false,'ProductUnavailable'end
  ownData.Inventory.Equipped[category]=id;return true
 end
 Service.Context={GetService=function(_,name)return name=='ShopService'and shop or nil end}
 Service.Profiles.GetInventory=function(_,p)return p==aa and ownData.Inventory or data.Inventory end
 local function read(category,page)clock+=.3;return Service:SelfProfile(aa,page or 1,category)end
 local function equip(category,id,page)clock+=.3;return Service:Equip(aa,category,id,page)end
 local before=copy(ownData)
 local projected=read('PointEffects').Profile
 check(projected.Category=='PointEffects'and #projected.Inventory==3,'owned point effects in separate category')
 for _,item in ipairs(projected.Inventory)do check(not item.Tradable and item.UnitId==nil and item.Category=='PointEffects','effects never become trade units')end
 check(projected.EquippedLoadout.PointEffects.ProductId=='Basic'and projected.EquippedLoadout.DeathEffects.ProductId=='BasicKill','complete loadout independent of current category')
 check(projected.EquippedSlap.RewardId==ownData.Inventory.Equipped.Slaps,'slap summary stays global on effect tab')
 check(projected.Coins==nil and projected.Inventory.CrateOperations==nil,'public DTO remains private-data free')
 check(same(before,ownData),'projection does not mutate profile')
 check(#read('DeathEffects').Profile.Inventory==2,'unowned death effect omitted')
 check(read('PointEffects',999).Profile.Page==1,'effect category pages clamp against its own size')
 check(not read('Abilities').Ok and not read(false).Ok,'only three explicit inventory categories')
 local pointResult=equip('PointEffects','Fire');check(pointResult.Ok and ownData.Inventory.Equipped.PointEffects=='Fire','point equipped through Shop: '..tostring(pointResult.Reason))
 check(equip('DeathEffects','Frost').Profile.EquippedLoadout.DeathEffects.ProductId=='Frost','kill effect equipped and authoritative projection returned')
 check(equip('Slaps','Classic:Rare').Ok and ownData.Inventory.Equipped.Slaps=='Classic:Rare','slap preferred for gameplay')
 local beforeCalls=shopCalls
 check(not equip('DeathEffects','Void').Ok,'unowned rejected before Shop')
 check(not equip('Slaps','Frost').Ok,'cross-category ID rejected')
 check(not equip('Abilities','Dash').Ok,'other categories rejected')
 check(not equip('PointEffects',{}).Ok,'invalid identifier rejected')
 check(not equip('PointEffects','Fire',0).Ok,'invalid page rejected')
 check(shopCalls==beforeCalls,'invalid requests cannot reach mutator')
 check(not equip('PointEffects','Missing').Ok and ownData.Inventory.Equipped.PointEffects=='Fire','provider availability failure leaves selection')
 active[aa]={Id='match'};check(not equip('PointEffects','Basic').Ok,'server session blocks even without client attr');active[aa]=nil
 aa.Attributes.ResultsSessionId='result';check(not equip('PointEffects','Basic').Ok,'results blocked');aa.Attributes.ResultsSessionId=nil
 Service.Engine.Busy[aa.UserId]='trade';check(not equip('PointEffects','Basic').Ok,'trade locks equipment');Service.Engine.Busy[aa.UserId]=nil
 ready=false;check(not equip('PointEffects','Basic').Ok,'unloaded profile blocked');ready=true
 local originalParent=aa.Parent;aa.Parent=nil;check(not equip('PointEffects','Basic').Ok,'disconnected blocked');aa.Parent=originalParent
 clock+=.3;check(not Service:Equip(table.clone(aa),'PointEffects','Basic',1).Ok,'forged Player identity blocked')
 read('PointEffects');check(not Service:Equip(aa,'PointEffects','Basic',1).Ok,'rate limiting shared with reads')
 check(ownData.Coins==before.Coins and same(ownData.Inventory.Owned,before.Inventory.Owned)and same(ownData.Inventory.SlapUnits,before.Inventory.SlapUnits),'no spending, ownership or trade identity mutation')
 check(#Public.Build(ownData,aa.UserId,catalog)==7,'trade projection remains slap-only')
 local other=inspect(bb.UserId);check(other.Ok and other.Profile.ProfileMode=='OtherPlayerProfile','other profile stays inspect-only route')
 C.Generation+=1;profile.Enabled=true;C.ProfileMode='OtherPlayerProfile';C.ProfileTarget=bb.UserId;C.PendingProfile=false;C.PendingEquip=false
 local calls=0;C.Equip={InvokeServer=function(_,category,id,page)calls+=1;return equip(category,id,page)end}
 C:EquipItem({Category='PointEffects',ProductId='Basic'})
 check(calls==0,'foreign profile has no equip action')
 C.ProfileMode='SelfProfile';C.ProfileTarget=aa.UserId;C.ProfilePage=1
 C:EquipItem({Category='PointEffects',ProductId='Basic'})
 check(calls==1 and ownData.Inventory.Equipped.PointEffects=='Basic'and C.ProfileCategory=='PointEffects','client equips and refreshes same category from confirmed response')
 C:EquipItem({Category='PointEffects',ProductId='Basic',Equipped=true});check(calls==1,'equipped card no duplicate request')
 deferred=true;C:EquipItem({Category='DeathEffects',ProductId='BasicKill'})
 check(C.PendingEquip,'one pending equip')
 C:EquipItem({Category='PointEffects',ProductId='Fire'});check(#spawned==1,'click spam cannot create extra pending requests')
 local generation=C.Generation;C:Close(profile);deferred=false;table.remove(spawned,1)()
 check(C.Generation>generation and C.ProfileTarget==nil,'late confirmation cannot reopen closed profile')
 check(cfg.TradeCommitEnabled==false,'no enablement of real trade transfers')
 print('PASS InventoryLoadoutV12: '..(n-startCount)..' new assertions; gameplay NOT RUN')
end

do
 local start=n;local Personal=load('PersonalInventory')
 local products={{Id='Basic',Category='Crates',DisplayName='Caja básica',Rarity='Basic'}, {Id='Rare',Category='Crates',DisplayName='Caja rara',Rarity='Rare'}, {Id='PremiumI',Category='Crates',DisplayName='Caja premium',Rarity='PremiumI'}}
 local saved=copy(ownData);ownData.Inventory.Crates={Basic=3,Rare=0,PremiumI=2,Unknown=99}
 local shop={GetCatalog=function(_,category)return category=='PointEffects'and {{Id='Basic',Category=category,DisplayName='Básico',IsAvailable=true},{Id='NotOwned',Category=category,DisplayName='No poseído',IsAvailable=true}}or {}end}
 Service.Context={GetService=function(_,name)return name=='ShopService'and shop or name=='CrateService'and {GetCatalog=function()return products end}or nil end}
 Service.Engine.Busy[aa.UserId]=nil;active[aa]=nil;ready=true;aa.Attributes.ResultsSessionId=nil
 local function fetch(category,page,query)clock+=.3;return Service:Inventory(aa,category,page or 1,query or '')end
 local r=fetch('Crates');check(r.Ok and r.Inventory.UserId==aa.UserId,'private inventory bound to authenticated caller')
 check(#r.Inventory.Items==2,'only positive owned counts from real catalog, including premium')
 check(r.Inventory.Items[1].Quantity==3 and r.Inventory.Items[2].Quantity==2,'exact owned crate amounts')
 check(r.Inventory.Coins==nil and r.Inventory.CrateOperations==nil and r.Inventory.SlapUnits==nil,'no persistence journal or balances in DTO')
 check(fetch('Crates',1,'PREMIUM').Inventory.FilteredTotal==1,'case insensitive inventory search')
 check(fetch('Crates',1,'%').Inventory.FilteredTotal==0,'search is literal, never a Lua pattern')
 check(fetch('Crates',10000,'').Inventory.Page==1,'page clamped after inventory changes')
 check(fetch('PointEffects').Inventory.Total==1,'effects restricted to owned catalog entries')
 local snapshot=copy(ownData);fetch('Slaps');check(same(snapshot,ownData),'reads cannot mutate ownership/equipment')
 for _,category in ipairs({'Titles','Abilities',tostring(bb.UserId),false})do check(not fetch(category).Ok,'reject unrecognized category/foreign user ID')end
 for _,page in ipairs({0,-1,.5,math.huge,0/0,'Slaps'})do clock+=.3;check(not Service:Inventory(aa,'Slaps',page,'').Ok,'invalid page rejected')end
 clock+=.3;check(not Service:Inventory(aa,'Slaps',1,string.rep('x',81)).Ok,'query length bounded')
 clock+=.3;check(not Service:Inventory(aa,'Slaps',1,{}).Ok,'query type bounded')
 fetch('Slaps');check(not Service:Inventory(aa,'Slaps',1,'').Ok,'reads share rate limit')
 clock+=.3;check(not Service:Inventory(table.clone(aa),'Slaps',1,'').Ok,'forged player rejected')
 active[aa]={Id='active'};check(not fetch('Slaps').Ok,'authoritative match state blocks reads');active[aa]=nil
 aa.Attributes.ResultsSessionId='results';check(not fetch('Slaps').Ok,'results state blocked');aa.Attributes.ResultsSessionId=nil
 ready=false;check(not fetch('Slaps').Ok,'unloaded profile blocked');ready=true
 local d={Inventory=inventory(aa.UserId)};local unit=copy(d.Inventory.SlapUnits[aa.UserId..':operation-1']);unit.UnitId='duplicate';d.Inventory.SlapUnits.duplicate=unit
 local grouped=Personal.Build(d,aa.UserId,catalog,'Slaps',{},products,1,'',100)
 local common;for _,row in grouped.Items do if row.ProductId=='Classic:Common'then common=row end end
 check(common and common.Quantity==2 and common.UnitId==nil,'duplicate units grouped for equip without exposing trade identity')
 check(#Public.Build(d,aa.UserId,catalog)==9,'trade projection still preserves all individual units')
 local page=Personal.Build(d,aa.UserId,catalog,'Slaps',{},products,1,'',2);check(#page.Items==2 and page.HasNext and page.Pages==4,'bounded inventory pagination')
 d.Inventory.Crates={};local empty=Personal.Build(d,aa.UserId,catalog,'Crates',{},products,1,'',24)
 check(empty.Total==0 and empty.Page==1 and not empty.HasNext,'empty crate inventory has stable metadata')
 -- Own profile routes to the separate controller; foreign collections retain read-only navigation.
 local opens=0;C.Context={GetController=function(_,name)if name=='InventoryController'then return {Open=function()opens+=1 end}end end}
 C.ProfileMode='SelfProfile';C.ProfileTarget=aa.UserId;C:SetArticlesMode(true);check(opens==1,'own profile links to independent inventory')
 C.ProfileMode='OtherPlayerProfile';C.ProfileTarget=bb.UserId;C:SetArticlesMode(true);check(opens==1,'foreign profile cannot invoke own equip inventory through its collection button')
 ownData=saved
 print('PASS StandaloneInventoryV1: '..(n-start)..' new assertions; total '..n)
end
