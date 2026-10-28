--!nonstrict
-- Personal price is queried on the client, never SuggestedRobux or a shared server cache.
local Flow={};Flow.__index=Flow
function Flow.new(marketplace,player,request,changed,clock,reserved)
 return setmetatable({Marketplace=marketplace,Player=player,Request=request,Changed=changed,Clock=clock or os.clock,State="Unavailable",Seen={},Sequence=0,Reserved=reserved or {}},Flow)
end
function Flow:Set(state,extra)self.State=state;self.Changed(state,extra)end
function Flow:Price(product)
 if product.IsPlaceholder~=false or not product.ProductId or self.Reserved[product.ProductId]or not product.CommercialVerified then return nil,"PlaceholderProduct"end
 local ok,info=pcall(self.Marketplace.GetProductInfoAsync,self.Marketplace,product.ProductId,Enum.InfoType.Product)
 local price=ok and type(info)=="table"and info.PriceInRobux
 if type(price)~="number"or price~=price or price<1 or price==math.huge or info.IsForSale~=true then return nil,"PriceUnavailable"end
 return price
end
function Flow:Begin(product)
 if self.Pending or self.Busy then return false,"PurchaseInProgress"end
 self.Sequence+=1;local seq=self.Sequence;self.Busy=true;self:Set("Processing")
 local function fail(state,why)if seq==self.Sequence then self.Busy=false;self:Set(state,why)end;return false,why end
 local price,why=self:Price(product)
 if seq~=self.Sequence then return false,"Cancelled"end
 if not price then return fail("TemporaryError",why)end
 if product.PriceRobux~=nil and product.PriceRobux~=price then product.PriceRobux=price;return fail("TemporaryError","PriceChanged")end
 local requested,result=pcall(self.Request,"Purchase",{Id=product.Id,QuoteTokens=product.QuoteTokens})
 if seq~=self.Sequence then return false,"Cancelled"end
 if not requested or type(result)~="table"then return fail("TemporaryError","RequestUnavailable")end
 if not result.Ok or result.ProductId~=product.ProductId or result.PromptAllowed~=true then return fail("Restricted",result.Code)end
 -- Requery immediately before the prompt. No price supplied by the client controls fulfillment.
 local latest=self:Price(product);if seq~=self.Sequence then return false,"Cancelled"end
 if latest~=price then return fail("TemporaryError","PriceChanged")end
 self.Pending={ProductKey=product.Id,ProductId=result.ProductId,Since=self.Clock(),Known=result.KnownReceipts or {}};self:Set("Purchasing",price)
 local ok=pcall(self.Marketplace.PromptProductPurchase,self.Marketplace,self.Player,result.ProductId)
 self.Busy=false
 if not ok then self.Pending=nil;return fail("TemporaryError","PromptUnavailable")end
 return true
end
function Flow:PromptClosed(userId,productId,purchased)
 if userId~=self.Player.UserId or not self.Pending or self.Pending.ProductId~=productId then return end
 -- Never grant/announce success here. Status endpoint/receipt event is authoritative.
 if purchased then self:Set("AwaitingConfirmation")else self.Pending=nil;self:Set("Available")end
end
function Flow:Delivery(receipt)
 if type(receipt)~="table"or receipt.State~="Applied"or type(receipt.PurchaseId)~="string"or self.Seen[receipt.PurchaseId]then return false end
 self.Seen[receipt.PurchaseId]=true
 if self.Pending and self.Pending.ProductId==receipt.ProductId then self.Pending=nil end
 self:Set("Credited",receipt.ProductKey);return true
end
function Flow:CancelAuthorization()if not self.Pending then self.Sequence+=1;self.Busy=false end end
function Flow:Status(receipts)
 for _,r in ipairs(receipts)do
  if self.Pending and self.Pending.ProductId==r.ProductId and not self.Pending.Known[r.PurchaseId]then self:Delivery(r)
  elseif not self.Pending then self.Seen[r.PurchaseId]=true end
 end
end
return Flow
