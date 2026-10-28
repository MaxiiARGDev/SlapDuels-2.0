--!nonstrict
-- Opt-in Studio-only observations. Never participates in ability authorization.
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local HttpService=game:GetService("HttpService")
local Diagnostics={Build="AbilityMultiplayerFixV1",Attribute="AbilityDiagnosticsEnabled"}
local budgets={}
local fields={"TraceId","ActivationId","SessionId","RoundId","UserId","AbilityId","SelectedAbilityId","RoundState",
 "Action","Result","Reason","Generation","ExpectedGeneration","CooldownRemaining","LifeId","ExpectedLifeId",
 "Playing","Preparing","RegistryCount","CatalogVersion","Environment","Provider","WritesToCloud","RemotesReady",
 "Elapsed","StepDt","MoveDistance","SpeedBefore","SpeedAfter","VelocityY","OwnerUserId","OwnerAutomatic",
 "RootAnchored","HumanoidState","MovementApplied","RemainingDuration","Source"}
function Diagnostics.Enabled()
 return RunService:IsStudio() and RS:GetAttribute(Diagnostics.Attribute)==true
end
function Diagnostics.NewTrace()
 return if Diagnostics.Enabled() then HttpService:GenerateGUID(false) else nil
end
function Diagnostics.TraceId(value)
 return if type(value)=="string" and #value<=80 and value:match("^[%x%-]+$") then value else nil
end
function Diagnostics.Forget(side,userId) budgets[side..":"..tostring(userId)]=nil end
function Diagnostics.Emit(side,phase,values)
 if not Diagnostics.Enabled() then return false end
 local key=side..":"..tostring(values.UserId or 0)
 local t=os.clock();local budget=budgets[key]
 if not budget or t-budget.Start>=1 then budget={Start=t,Count=0};budgets[key]=budget end
 if budget.Count>=30 then return false end -- bounded even if an input/remote is spammed
 budget.Count+=1
 local row={Build=Diagnostics.Build,Side=side,Phase=phase,IsStudio=true,
  PlaceId=game.PlaceId,GameId=game.GameId,PlaceVersion=game.PlaceVersion}
 for _,field in ipairs(fields)do
  local value=values[field]
  if type(value)=="string" then row[field]=value:gsub("[%c]"," "):sub(1,120)
  elseif type(value)=="boolean" or (type(value)=="number" and value==value and math.abs(value)<math.huge) then row[field]=value end
 end
 -- A diagnostic serialization/output failure must never interrupt gameplay.
 local ok=pcall(function()print("[AbilityTrace] "..HttpService:JSONEncode(row))end)
 return ok
end
return table.freeze(Diagnostics)
