--!nonstrict
-- Public presentation only. Every mutation is still independently authorised by the server.
local View={}
View.Errors={CommercialApprovalPending="Precio o probabilidades pendientes de aprobación.",ProductionBackendBlocked="Ventas productivas bloqueadas.",
 PaidRandomItemsRestricted="Compra aleatoria restringida o elegibilidad no verificable.",OddsChanged="Probabilidades modificadas: consultalas otra vez.",
 ViewOddsFirst="Consultá las probabilidades vigentes.",LobbyOnly="Solo disponible en el lobby.",InsufficientFunds="Coins insuficientes.",
 NoCrate="No tenés cajas cerradas.",NoEligibleResults="No hay resultados elegibles.",SoldOut="Stock agotado.",StockUnknown="Stock no verificable.",
 RateLimited="Esperá un momento y reintentá.",DataNotLoaded="Esperá a que cargue tu perfil.",CrateUnavailable="Caja no disponible.",
 NoResponse="Sin confirmación: reintentá la misma operación.",InternalError="No se pudo confirmar la operación; reintentá.",
 TransactionInProgress="Hay una operación en curso.",JournalCapacityReached="Inventario de operaciones completo.",ProfileChanged="Tu perfil cambió; volvé a consultar."}
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
 local data=snapshot or {};local count=data.Inventory and data.Inventory.Crates and data.Inventory.Crates[product.Id]or 0
 local coins=data.Coins
 local state={Quantity=if finite(count)and count>=0 then count else 0,Price=price,
  PriceText=if priceApproved then string.format("%d Coins",price)else "Precio pendiente",
  CoinsText=if finite(coins)then tostring(coins).." Coins"else "—",BuyText="COMPRAR",OpenText="ABRIR",
  BuyEnabled=false,OpenEnabled=false,StockText="Stock: consultar",Status="Consultá probabilidades",Badge="CONSULTAR",NeedQuote=true}
 if m.PricePending==true or not priceApproved then state.Status="Precio pendiente";state.Badge="PENDIENTE"
 elseif m.OddsApproved~=true then state.Status="Probabilidades pendientes";state.Badge="PENDIENTE"
 elseif product.IsAvailable==false or m.Enabled~=true or m.PurchaseEnabled~=true then state.Status="Caja no disponible";state.Badge="BLOQUEADA"
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
  state.BuyEnabled=coins>=price;state.OpenEnabled=state.Quantity>0
  state.Status=if state.BuyEnabled then "Disponible"else "Coins insuficientes"
  state.Badge=if state.Quantity>0 then tostring(state.Quantity).." cajas"elseif state.BuyEnabled then "DISPONIBLE"else "SIN SALDO"
  local unlimited=true
  for _,row in ipairs(quote.Outcomes or {})do if not row.Stock.UnlimitedStock then unlimited=false end end
  state.StockText=if unlimited then "Stock: Ilimitado"else "Stock: ver probabilidades"
 end
 if busy then state.BuyEnabled=false;state.OpenEnabled=false;state.Status="Procesando…"end
 return state
end
return View
