--!strict
-- Catalog only; no purchases, grants or persistence are performed here.
local Existing = require(script.Parent.PointEffectDefinitions)
local frost = assert(Existing.Get("Frost"))
local void = assert(Existing.Get("Void"))
return {
 DefaultFall = {
  DeathEffectId="DefaultFall", DisplayName="Caída", ModelName="DefaultFall",
  Duration=1.5, EmitCount=18, EmitDelay=0, PlayDelay=0, RequiredOwnership=false, IsDefault=true,
  IsShopProduct=false,
 },
 BasicKill = {
  DeathEffectId="BasicKill", DisplayName="Propulsión", ModelName="BasicKill",
  Duration=2.2, EmitCount=32, EmitDelay=0, PlayDelay=0, RequiredOwnership=false, IsDefault=true,
  IsShopProduct=true, Price=0, Rarity="Common", Description="Efecto inicial gratuito de Kill. Se reproduce cuando sos la víctima de una Kill acreditada.",
 },
 Frost = {
  DeathEffectId=frost.Id, DisplayName=frost.DisplayName, ModelName="Frost",
  Duration=3.2, EmitCount=24, EmitDelay=0, PlayDelay=0, RequiredOwnership=true, IsDefault=false,
  IsShopProduct=true, Price=frost.Price, Rarity=frost.Rarity,
  Description="Explosión glacial vertical, cristales y onda helada al recibir una Kill.",
 },
 Void = {
  DeathEffectId=void.Id, DisplayName=void.DisplayName, ModelName="Void",
  Duration=3.6, EmitCount=24, EmitDelay=0, PlayDelay=0, RequiredOwnership=true, IsDefault=false,
  IsShopProduct=true, Price=void.Price, Rarity=void.Rarity,
  Description="Ruptura oscura con energía púrpura y anillos del vacío al recibir una Kill.",
 },
}
