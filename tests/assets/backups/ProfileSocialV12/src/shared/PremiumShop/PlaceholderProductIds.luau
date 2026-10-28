-- Reserved examples: cannot be verified, even if IsPlaceholder is accidentally cleared.
local ids={}
for _,id in ipairs({123456001,123456002,123456003,123456004,123456005,123456101,123456102,123456103,123456201,123456202,123456203})do ids[id]=true end
return ids
