--!nonstrict
local Strong={}
function Strong.Start(record) record.State="Armed";return true end
function Strong.Step(_record,_dt) return true end
function Strong.Cancel(_record) end
Strong.Descriptor={Id="StrongSlap",DisplayName="Golpe Fuerte",Description="Prepara el próximo impacto válido durante 15 s. Eliminación inmediata.",Type="Ofensiva",
 Duration=15,Cooldown=25,Icon="",SortOrder=20,ActiveLabel="PREPARADA"}
Strong.Enabled=true
Strong.Config={PresentationLift=25}
Strong.ConfigSchema={PresentationLift={Type="number",Min=0,Max=100}}
Strong.Shop={Price=3000,PriceApproved=true,PurchaseEnabled=true}
Strong.Dependencies={}
Strong.Input={Primary="None"}
Strong.Assets={Key="StrongSlap",Profile="AttachmentEffect",Cues={Impact={Profile="VerticalLaunch",Resource="LaunchSpectacle",Lift=Strong.Config.PresentationLift,Duration=0.65}}}
Strong.Hooks={Profile="ImmediateElimination",Reason="StrongSlap",Cue="Impact",
 BeforeHit=function(record) return record.State=="Armed" end,
 Consume=function(record)
  if record.State~="Armed" then return false end
  record.State="Consumed";return true
 end}
return Strong
