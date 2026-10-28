--!strict
-- Global protocol settings only. Ability descriptors/configuration live in their
-- approved server modules; public metadata is projected by AbilityRegistry.
return table.freeze({DefaultId="Dash",Category="Abilities",CooldownPolicy="OnActivation",
 RequestInterval=0.12,SnapshotInterval=0.25})
