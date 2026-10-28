--!nonstrict
-- Same free rewards/balance already exercised privately; no Premium purchase enabled.
local M=require(script.Parent.Parent.Model)
local pass=M.Copy(require(script.Parent.TestSeason))
pass.Id='LaunchSeason';pass.DisplayName='SlapDuels · Temporada inaugural';pass.StudioOnly=false
return pass
