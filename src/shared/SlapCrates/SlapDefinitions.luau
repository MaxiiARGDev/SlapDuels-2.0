--!nonstrict
-- Runtime metadata is produced by the server from validated physical Tools, never client claims.
local rs=game and game:GetService('ReplicatedStorage');local run=game and game:GetService('RunService')
if run and type(run.IsClient)=='function'and run:IsClient()and run:IsRunning()then
 local deadline=os.clock()+20
 while rs:GetAttribute('SlapCatalogReady')~=true do assert(os.clock()<deadline,'SlapCatalogNotReady');task.wait()end
end
local root=rs and type(rs.FindFirstChild)=='function'and rs:FindFirstChild('SlapCatalog')
if root then
 local definitions={}
 for _,entry in ipairs(root:GetChildren())do
  if entry:IsA('Folder')then
   local variants={};local folder=entry:FindFirstChild('Variations')
   if folder then for _,v in ipairs(folder:GetChildren())do if v:IsA('Folder')then table.insert(variants,v.Name)end end end
   table.sort(variants)
   table.insert(definitions,{SlapId=entry.Name,DisplayName=entry:GetAttribute('DisplayName'),Model=entry:GetAttribute('Model'),VariantsFolder=entry:GetAttribute('VariantsFolder'),VariationIds=variants})
  end
 end
 table.sort(definitions,function(a,b)return a.SlapId<b.SlapId end)
 return definitions
end
if run and type(run.IsRunning)=='function'and run:IsRunning()then error('PhysicalSlapCatalogMissing')end
-- Offline fixture/Edit fallback only. Production/clients never silently use it at runtime.
return {{SlapId="Classic",DisplayName="Clásico",Model="Classic",VariationIds={
 "Basic","Common","Uncommon","Rare","Gold","Arcoiris","Emote","Wings","Epic","Legendary","Blood","Galaxy"}}}
