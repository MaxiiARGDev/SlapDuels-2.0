--!nonstrict
local Layout={}
function Layout.Build(count,aspect,fov,config)
 assert(count==5 or count==10,"Gallery requires five or ten rewards")
 aspect=math.clamp(aspect,.4,3)
 local columns=if aspect<.9 then config.PortraitColumns else config.Columns
 local rows=math.ceil(count/columns);local positions={}
 for index=1,count do
  local row=math.floor((index-1)/columns);local inRow=math.min(columns,count-row*columns)
  positions[index]={X=((index-1)%columns-(inRow-1)/2)*config.Spacing,Y=((rows-1)/2-row)*config.RowSpacing}
 end
 local width=math.min(columns,count)*config.Spacing
 local height=rows*config.RowSpacing
 local tangent=math.tan(math.rad(fov)/2)
 return {Positions=positions,Width=width,Height=height,
  Distance=math.max(width/(2*tangent*aspect),height/(2*tangent))*config.FrameMargin}
end
return Layout
