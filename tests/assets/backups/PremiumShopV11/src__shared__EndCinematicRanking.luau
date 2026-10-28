--!nonstrict
-- Pure, shared algorithm. Live results are built once by RoundService, never from client stats.
local Config = require(script.Parent.EndCinematicConfig)
local Ranking = {}
local function finite(value) return type(value)=="number" and value==value and math.abs(value)<math.huge end
local function metric(value) return finite(value) and value>=0 and value%1==0 end

function Ranking.Build(participants, winningTeam, mode, identity)
 local entries, seen = {}, {}
 for _, source in ipairs(participants) do
  assert(finite(source.UserId) and source.UserId~=0 and not seen[source.UserId], "InvalidRankingParticipant")
  seen[source.UserId]=true
  local row={UserId=source.UserId,DisplayName=source.DisplayName,Username=source.Username,
   Team=source.Team,CompetitiveSlot=source.CompetitiveSlot or source.Slot,
   DescriptionKey=source.DescriptionKey,Preview=source.Preview==true}
  if identity.Preview and source.Preview then row.AppearanceUserId=source.AppearanceUserId end
  for _, key in ipairs({"Goals","Kills","Deaths","MatchPoints"}) do
   if metric(source[key]) then row[key]=source[key] end -- absent stays absent, never fabricated zero
  end
  table.insert(entries,row)
 end
 table.sort(entries,function(a,b)
  for _, key in ipairs(Config.Ranking.Criteria) do
   local x,y=a[key],b[key]
   if x~=y then
    if x==nil then return false end
    if y==nil then return true end
    return Config.Ranking.Ascending[key] and x<y or (not Config.Ranking.Ascending[key] and x>y)
   end
  end
  return a.UserId<b.UserId -- original IDs, including Studio negatives
 end)
 local mvp
 for rank,row in ipairs(entries) do
  row.Rank=rank
  if rank==1 then
   for _,key in ipairs(Config.Ranking.Criteria) do if row[key]~=nil then mvp=row.UserId; break end end
  end
  row.IsMVP=row.UserId==mvp
 end
 local visible={}
 local capacity=math.min(5,Config.Winners.MaxVisible,Config.Ranking.MaxVisible)
 -- Team priority is a selection policy, not a claim that these are the global top five.
 for _, winnersFirst in ipairs({true,false}) do
  for _,row in ipairs(entries) do
   local winner=row.Team==winningTeam
   if winner==winnersFirst and #visible<capacity and (mode~="1v1" or winner) then
    local copy=table.clone(row); copy.CinematicSlot=#visible+1
    table.insert(visible,copy)
   end
  end
 end
 local snapshot={SessionId=identity.SessionId,StateVersion=identity.StateVersion,
  WinningTeam=winningTeam,Entries=entries,VisibleParticipants=visible,MVPUserId=mvp,
  SelectionPolicy="WinningTeamThenIndividualRank",Preview=identity.Preview==true}
 for _,row in ipairs(entries) do table.freeze(row) end
 for _,row in ipairs(visible) do table.freeze(row) end
 table.freeze(entries); table.freeze(visible)
 return table.freeze(snapshot)
end

function Ranking.Validate(snapshot, sessionId, version)
 if type(snapshot)~="table" or snapshot.SessionId~=sessionId or snapshot.StateVersion~=version
  or type(snapshot.Entries)~="table" or type(snapshot.VisibleParticipants)~="table"
  or #snapshot.VisibleParticipants>5 then return false end
 local seen={}
 for i,row in ipairs(snapshot.Entries) do
  if type(row)~="table" or not finite(row.UserId) or row.UserId==0 or seen[row.UserId]
   or row.Rank~=i or type(row.DisplayName)~="string" then return false end
  for _,key in ipairs({"Goals","Kills","Deaths","MatchPoints"}) do
   if row[key]~=nil and not metric(row[key]) then return false end
  end
  seen[row.UserId]=row
 end
 local visible={}
 for i,row in ipairs(snapshot.VisibleParticipants) do
  if type(row)~="table" then return false end
  local original=seen[row.UserId]
  if not original or visible[row.UserId] or row.CinematicSlot~=i or row.Rank~=original.Rank then return false end
  visible[row.UserId]=true
 end
 return true
end

function Ranking.Resolve(data, isMatch)
 if data.ResultSnapshot then
  if type(data.ResultSnapshot)=="table" and data.ResultSnapshot.WinningTeam==data.WinningTeam and Ranking.Validate(data.ResultSnapshot,data.MatchId,data.StateVersion) then return data.ResultSnapshot end
  return nil,"InvalidResultSnapshot"
 end
 if isMatch then return nil,"ResultSnapshotMissing" end
 return Ranking.Build(data.Participants or data.Winners,data.WinningTeam,data.Mode or "1v1",
  {SessionId=data.MatchId,StateVersion=data.StateVersion,Preview=true})
end
return Ranking
