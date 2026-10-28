--!nonstrict
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
