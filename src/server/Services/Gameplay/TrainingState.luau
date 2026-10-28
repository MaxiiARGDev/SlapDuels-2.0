--!strict
local State={}
function State.Begin(record: any,sequence: any,now: number): (boolean,string?)
 if type(sequence)~='number' or sequence~=sequence or sequence%1~=0 or sequence<1 or sequence>1000000 then return false,'InvalidSequence' end
 if sequence<=(record.LastSequence or 0)then return false,'Replayed' end
 record.LastSequence=sequence
 if record.Pending or now<(record.ReadyAt or 0)then return false,'Recovery' end
 record.Pending=sequence
 return true
end
function State.Finish(record: any,sequence: number,now: number,hit: boolean,combo: any,cooldown: number): boolean
 if record.Pending~=sequence then return false end
 record.Pending=nil
 record.ReadyAt=now+(if combo.Enabled then (if hit then combo.SuccessfulHitRecovery else combo.MissRecovery)else cooldown)
 return true
end
return State
