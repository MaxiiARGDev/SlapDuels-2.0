--!nonstrict
local Catalog={ById={},Order={}}
local seenModules={}
for _,name in ipairs(require(script.Parent.PassManifest))do
 assert(type(name)=='string'and name:match('^[%w_]+$')and not seenModules[name],'InvalidPassManifest')
 seenModules[name]=true
 local found
 for _,child in ipairs(script.Parent.Passes:GetChildren())do if child.Name==name then assert(not found,'DuplicatePassModule');found=child end end
 assert(found and found:IsA('ModuleScript'),'MissingPassModule: '..name)
 local pass=require(found)
 assert(type(pass)=='table'and type(pass.Id)=='string'and pass.Id:match('^[%w_%-]+$')and not Catalog.ById[pass.Id],'InvalidPassId')
 assert(pass.Version==1 and pass.Stages==30 and type(pass.StageXP)=='number'and pass.StageXP>0 and pass.StageXP%1==0,'InvalidPassProgression')
 for i=1,pass.Stages do
  local r=pass.Rewards[i]
  assert(type(r)=='table'and type(r.Label)=='string','MissingPassReward')
  assert(r.Kind=='Coins'or r.Kind=='Slap'or r.Kind=='Effect','InvalidPassReward')
  if r.Kind=='Coins'then assert(type(r.Amount)=='number'and r.Amount>0 and r.Amount%1==0,'InvalidPassCoins')
  elseif r.Kind=='Slap'then assert(type(r.Id)=='string','InvalidPassSlap')
  else assert((r.Category=='PointEffects'or r.Category=='DeathEffects')and type(r.Id)=='string'and type(r.Compensation)=='number'and r.Compensation>=0 and r.Compensation%1==0,'InvalidPassEffect')end
 end
 Catalog.ById[pass.Id]=pass;table.insert(Catalog.Order,pass.Id)
end
return Catalog
