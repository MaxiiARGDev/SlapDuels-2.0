--!nonstrict
local Eligibility={}
function Eligibility.Policy(service,player)
 local ok,info=pcall(service.GetPolicyInfoForPlayerAsync,service,player)
 if not ok or type(info)~="table"then return {RandomAllowed=false,TradingAllowed=false,Verified=false}end
 return {RandomAllowed=info.ArePaidRandomItemsRestricted==false,TradingAllowed=info.IsPaidItemTradingAllowed==true,Verified=true}
end
function Eligibility.CanPurchase(config,product,policy,profileReady,isLobby)
 if not config.PremiumShopEnabled or not config.PurchasesEnabled then return false,"PurchasesDisabled"end
 if not config.DurableCommerceValidated then return false,"DurableBackendPending"end
 if not product then return false,"UnknownProduct"end
 if product.BlockedReason then return false,product.BlockedReason end
 local flag=({Coins="CoinPackagesEnabled",Combos="CombosEnabled",PremiumCrates="PremiumCratesEnabled"})[product.Category]
 if not flag or not config[flag]then return false,"CategoryDisabled"end
 if not profileReady then return false,"DataNotLoaded"end
 if not isLobby then return false,"LobbyOnly"end
 if not policy.Verified then return false,"PolicyUnavailable"end
 if product.HasRandomContents and not policy.RandomAllowed then return false,"PaidRandomItemsRestricted"end
 return true
end
return Eligibility
