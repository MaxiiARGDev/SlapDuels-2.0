--!nonstrict
-- DOCUMENTATION ONLY. Not in AbilityManifest; rejected even if added by mistake.
-- Copy to the direct Abilities folder, rename, review, then remove IsTemplate.
local Ability={
 IsTemplate=true,Enabled=false,
 Descriptor={Id="ReplaceWithUniqueId",DisplayName="Nombre",Description="Descripción de la habilidad.",
  Type="Utilidad",Duration=1,Cooldown=10,Icon="",SortOrder=60},
 Config={},ConfigSchema={},Dependencies={},
 Assets={Profile="None"}, -- Or AttachmentEffect / InvisibleAvatar, Key="YourAssetFolder".
 Shop={Price=0,PriceApproved=false,PurchaseEnabled=false},
 Input={Primary="None"}, -- Direction is validated by the server input adapter.
}
function Ability.ValidateActivation(_runtime,_input) return true end
function Ability.Start(runtime,_input)
 -- No waits, tasks, connections or delayed work. Store only activation-local state.
 runtime.Started=true
 return true -- false rejects activation without spending the cooldown.
end
function Ability.Step(_runtime,_dt)
 return true -- optional; false ends the active window, preserving cooldown.
end
function Ability.Cancel(runtime)
 -- Safe after partial Start and safe to call repeatedly. Restore only values owned
 -- by this activation; never overwrite a later movement/visual owner.
 runtime.Started=false
end
return Ability
