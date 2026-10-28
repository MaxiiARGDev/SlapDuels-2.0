--!strict
local Labels={}
function Labels.Percent(value: number): string
 if math.abs(value-math.round(value))<1e-7 then return string.format('%d %%',math.round(value))end
 if value<1 then return '<1 %'end
 return string.format('≈ %d %%',math.round(value))
end
function Labels.Chance(value: number): string
 return if value>=15 then 'Probabilidad alta'elseif value>=5 then 'Probabilidad media'elseif value>=1 then 'Probabilidad baja'else 'Probabilidad muy baja'
end
return Labels
