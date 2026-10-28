--!strict
-- Deliberately has no adapter/DataStore access. No durable trade can start in V1.0.
local Recovery={}
function Recovery.Status()
 return {DurableRecoveryAvailable=false,Reason='ProfileLifecycleIntegrationPending',RequiresFencedProfileBridge=true}
end
function Recovery.Reconcile(_tradeId: string): (boolean,string)
 return false,'DurableRecoveryUnavailable'
end
return Recovery
