--!strict
return table.freeze({
 Protocol=1, GlobalEnabled=true, ApprovedUniverseId=10769217377,
 PollSeconds=5, TicketTTL=45, MatchTTL=180, AllocationSeconds=30,
 MaxTickets=32, MaxMatches=8, MaxSearchSeconds=600,
 RegionRelaxSeconds=90, PingSpread=80, ArrivalMaxPingMs=450,
 Modes=table.freeze({'1v1','2v2','3v3','4v4'}),
})
