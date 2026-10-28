--!strict
-- Presentation values are replicated; every permission is checked again on the server.
return table.freeze({
 ProfileInspectionEnabled=true, TradeInvitationsEnabled=true, TradeCommitEnabled=false,
 InspectDistance=10, PromptHoldSeconds=0.5, MaxSlapsPerSide=6,
 InviteTimeoutSeconds=15, SafetyCountdownSeconds=5, MaxTradeSeconds=180,
 InviteCooldownSeconds=15, RequestIntervalSeconds=0.25, InventoryPageSize=24,
 MaxActivePreviews=12, AimPollSeconds=0.12, TerminalRetentionSeconds=30,
})
