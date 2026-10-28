--!nonstrict
local Verifier={};Verifier.__index=Verifier
function Verifier.new(marketplace,reserved,isStudio,gameId)
 return setmetatable({Marketplace=marketplace,Reserved=reserved,Studio=isStudio,GameId=gameId},Verifier)
end
function Verifier:Verify(product)
 if product.IsPlaceholder~=false or self.Reserved[product.DeveloperProductId]then return nil,"PlaceholderProduct"end
 if self.Studio or self.GameId<=0 then return nil,"TestingEnvironment"end
 local ok,result=pcall(function()
  local pages=self.Marketplace:GetDeveloperProductsAsync();local found
  repeat
   for _,item in ipairs(pages:GetCurrentPage())do
    if item.ProductId==product.DeveloperProductId then found=item end
   end
   if pages.IsFinished then break end;pages:AdvanceToNextPageAsync()
  until false
  if not found then return nil end
  local info=self.Marketplace:GetProductInfoAsync(product.DeveloperProductId,Enum.InfoType.Product)
  if type(info)~="table"or info.IsForSale~=true or type(info.PriceInRobux)~="number"or info.PriceInRobux~=info.PriceInRobux or info.PriceInRobux<1 or info.PriceInRobux==math.huge then return nil end
  return {ProductId=product.DeveloperProductId,GameId=self.GameId,Name=info.Name,Verified=true}
 end)
 if not ok or not result then return nil,"ProductOwnershipOrPriceUnverified"end
 return result
end
return Verifier
