--!strict
-- SERVER ONLY. Add positive production UserIds here; never trust a client attribute.
return table.freeze({
 UserIds=table.freeze({[1522376993]=true}),
 StudioUserIds=table.freeze({}), -- Explicit negative local-test IDs only, if later authorized.
 RequestInterval=0.3,MaxRequestsPerAdminSession=1000,MaxAuditEntries=256,MaxCoinsPerGrant=1000000,
})
