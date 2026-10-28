--!nonstrict
-- Authorised manifest. Colours are editable presentation placeholders, not commercial values.
local definitions={}
for i,id in ipairs({"Basic","Common","Uncommon","Rare","Gold","Arcoiris","Emote","Wings","Epic","Legendary","Blood","Galaxy"}) do
 table.insert(definitions,{Id=id,DisplayName=id,Description="Variación cosmética "..id,
  SortOrder=i,Color=Color3.fromHSV((i-1)/12,.45,.95),Icon="",VisualProfile=id,
  VFX=id,SFX="Reveal",AnnounceInChat=false,LimitedStock=false,DefaultStock=nil,
  AdditionalConfig={DesignPending=true}})
end
return definitions
