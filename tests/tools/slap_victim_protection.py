"""Prepare isolated regression fixture and guarded Edit payload. Never runs Studio."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
backup = root / 'tests/assets/backups/SlapVictimProtection'
def digest(s):
    return hashlib.sha256(s.replace('\r\n', '\n').rstrip().encode('utf-8')).hexdigest()
rows = []
for name in ('CombatService', 'SlapService'):
    path = root / f'src/server/Services/{name}.luau'
    before = (backup / f'{name}.luau').read_text(encoding='utf-8')
    source = path.read_text(encoding='utf-8')
    rows.append(dict(Name=name, Before=digest(before), After=digest(source), Source=source))
(root / 'tests/SlapVictimProtection.payload.json').write_text(json.dumps(rows), encoding='utf-8')
(backup / 'manifest.json').write_text(json.dumps({r['Name']: r['Before'] for r in rows}, indent=2), encoding='utf-8')

s = (root / 'tests/CombatSystemV132.spec.luau').read_text(encoding='utf-8')
s = s.replace('clock=hit.RecoveryUntil;request(a,ta)', 'clock=hit.StartTime+3;request(a,ta)')
s = s.replace('Next valid hit at exact .15 boundary', 'Next valid hit at exact victim protection boundary')
s = s.replace('clock=server._attacks[a].RecoveryUntil;request(a,ta)\ncheck(thirds', 'clock=server._attacks[a].StartTime+3;request(a,ta)\ncheck(thirds')
s = s.replace('clock=server._attacks[a].RecoveryUntil;faultRagdoll=true', 'clock=server._attacks[a].StartTime+3;faultRagdoll=true')
s = s.replace('clock=server._attacks[a].RecoveryUntil;close()\nlocal comboBefore', 'clock=math.max(server._attacks[a].RecoveryUntil,combat._lifeHits[b].ProtectedUntil);close()\nlocal comboBefore')
s = s.replace('clock=server._attacks[a].RecoveryUntil\nlocal realPrepare', 'clock=math.max(server._attacks[a].RecoveryUntil,combat._lifeHits[b].ProtectedUntil)\nlocal realPrepare')
extra = '''
-- Real admission/selection path: victim immunity is distinct from attacker recovery.
combat:ClearCombatTag(b);server._attacks[a]=nil;close();clock+=10
request(a,ta)
local protected=combat._lifeHits[b]
local firstTag=combat:GetCombatTag(b)
local firstRagdolls=ragdolls
local victimDeadline=protected.ProtectedUntil
check(near(victimDeadline,clock+3),"Confirmed hit reserves exactly 3s victim immunity")
clock=server._attacks[a].RecoveryUntil
armed={};Strong.Start(armed)
request(a,ta)
local protectedMiss=server._attacks[a]
check(protectedMiss.Outcome=="Miss" and last(a).Reason=="VictimHitProtected","Slap on protected victim is a confirmed Miss")
check(near(protectedMiss.RecoveryUntil,protectedMiss.StartTime+.1+.45),"Protected Miss pays full window plus .45 recovery")
check(ragdolls==firstRagdolls and protected.Count==1,"Protected contact adds neither launch/ragdoll nor hit count")
check(combat:GetCombatTag(b)==firstTag and #combat:GetHitHistory(b)==1,"Protected contact preserves attribution/history")
check(protected.ProtectedUntil==victimDeadline and armed.State=="Armed","Protected Miss neither refreshes immunity nor consumes StrongSlap")
for _=1,10 do request(a,ta)end
check(server._attacks[a]==protectedMiss and protected.Count==1,"Ten premature requests cannot bypass either recovery")
clock=victimDeadline-.000001
local accepted,reason=combat:RegisterHit(a,b,session.Id,true)
check(not accepted and reason=="VictimHitProtected","Final authoritative guard rejects just before exact deadline, including StrongSlap")
check(protected.ProtectedUntil==victimDeadline and protected.Count==1,"Direct rejected hit has no side effects")
clock=victimDeadline
armed=nil;request(a,ta)
check(last(a).Hit and protected.Count==2,"Exact expiry accepts second hit without waiting for timer/animation")
check(ragdolls==firstRagdolls+1,"Only newly valid hit launches victim again")
local thirdBefore=thirds
clock=protected.ProtectedUntil;request(a,ta)
check(thirds==thirdBefore+1 and protected.Count==3,"Three spaced valid hits still trigger one threshold")
request(a,ta)
check(thirds==thirdBefore+1,"Immediate replay cannot duplicate third-hit elimination")
-- Scope changes invalidate protection; explicit lifecycle clear releases storage.
check(combat:IsHitProtected(b,session),"Current victim scope protected")
check(not combat:IsHitProtected(a,session),"Victim protection does not block independent attacker target")
b.Character:SetAttribute("ArenaPhysicsGeneration",2)
check(not combat:IsHitProtected(b,session),"New physics generation does not inherit immunity")
b.Character:SetAttribute("ArenaPhysicsGeneration",1)
local oldCharacter=b.Character;b.Character=character("replacement")
check(not combat:IsHitProtected(b,session),"Respawn Character does not inherit immunity")
b.Character=oldCharacter
local savedRound=session.GameplayRound.Id;session.GameplayRound.Id="newRound"
check(not combat:IsHitProtected(b,session),"New round does not inherit immunity")
session.GameplayRound.Id=savedRound
local replacementSession=table.clone(session)
check(not combat:IsHitProtected(b,replacementSession),"Replacement session identity cannot inherit immunity")
combat:ClearMatch(session.Id)
check(not combat:IsHitProtected(b,session) and combat._lifeHits[b]==nil,"Match cleanup clears immunity record")
combat:RegisterHit(a,b,session.Id);combat:ClearCombatTag(b)
check(not combat:IsHitProtected(b,session),"Elimination/life cleanup clears immunity")
-- A competing contact between selection and commit must still be rejected.
server._attacks[a]=nil;local raceRagdolls=ragdolls
abilities.PrepareHit=function()
 check(combat:RegisterHit(a,b,session.Id),"Competing contact reserves victim before suspended attempt commits")
 return nil
end
request(a,ta);abilities.PrepareHit=realPrepare
check(not last(a).Hit and last(a).Reason=="VictimHitProtected","Final admission rechecks immunity after ability hook")
check(combat._lifeHits[b].Count==1 and ragdolls==raceRagdolls,"Racing rejected contact cannot add hit or physics")
combat:ClearCombatTag(b)
'''
marker='-- Actual client lifecycle and input/feedback, with reliable fixtures and deliberate reorder.'
assert marker in s
s=s.replace(marker,extra+'\n'+marker)
s=s.replace('PASS CombatSystemV132:', 'PASS SlapVictimProtection:')
(root / 'tests/SlapVictimProtection.spec.luau').write_text(s, encoding='utf-8')
print(json.dumps([{k:v for k,v in r.items() if k!='Source'} for r in rows]))
