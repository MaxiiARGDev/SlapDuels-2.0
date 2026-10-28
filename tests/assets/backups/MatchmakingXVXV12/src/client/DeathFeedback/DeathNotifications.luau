--!nonstrict
local Config=require(game.ReplicatedStorage.Shared.DeathFeedbackConfig).Notifications
local Scope=require(script.Parent.Scope)
local Notifications={Active={},Serial=0}
function Notifications.Clear()
 for _,scope in ipairs(Notifications.Active) do scope:Destroy() end
 table.clear(Notifications.Active)
end
function Notifications.Play(payload)
 if not Config.Enabled then return end
 for i=#Notifications.Active,1,-1 do if Notifications.Active[i].Dead then table.remove(Notifications.Active,i) end end
 while #Notifications.Active>=math.max(1,Config.MaxVisible) do table.remove(Notifications.Active,1):Destroy() end
 local playerGui=game.Players.LocalPlayer:FindFirstChild("PlayerGui")
 local hud=playerGui and playerGui:FindFirstChild("DeathFeedbackHUD")
 local container=hud and hud:FindFirstChild("NotificationContainer")
 local template=container and container:FindFirstChild("NotificationTemplate")
 if not template or not template:IsA("CanvasGroup") then warn("[DeathFeedback] DeathFeedbackHUD template missing");return end
 local scope=Scope.new()
 table.insert(Notifications.Active,scope)
 Notifications.Serial+=1
 local row=scope:Add(template:Clone())
 row.Name="Notification_"..payload.EliminationId
 row.LayoutOrder=Notifications.Serial;row.Visible=true;row.GroupTransparency=1
 local message=row:FindFirstChild("MessageLabel")
 local icon=row:FindFirstChild("Icon")
 if not message or not icon then scope:Destroy();warn("[DeathFeedback] Invalid notification template");return end
 message.RichText=false
 local victim=string.sub(tostring(payload.VictimName),1,64)
 local killer=string.sub(tostring(payload.KillerName or ""),1,64)
 message.Text=payload.Kind=="CreditedKill" and (killer.." tiró a "..victim) or (victim.." se cayó")
 local credited=payload.Kind=="CreditedKill"
 icon.Text=credited and "✦" or "↓"
 icon.TextColor3=credited and (row:GetAttribute("KillColor") or Color3.fromRGB(255,174,64))
  or (row:GetAttribute("FallColor") or Color3.fromRGB(135,179,255))
 row.Parent=container -- UIListLayout stacks clones; authored container Position is untouched.
 local scale=row:FindFirstChildOfClass("UIScale")
 if scale then local original=scale.Scale;scale.Scale=original*.9;scope:Tween(scale,Config.FadeInDuration,{Scale=original}) end
 scope:Tween(row,Config.FadeInDuration,{GroupTransparency=0})
 local sound=row:FindFirstChild("NotificationSound")
 if sound and sound:IsA("Sound") then
  if Config.LocalSoundId~="" then sound.SoundId=Config.LocalSoundId end
  sound.Volume=Config.LocalSoundVolume
  if sound.SoundId~="" then sound:Play() end
 end
 scope:Delay(Config.FadeInDuration+Config.DisplayDuration,function()
  scope:Tween(row,Config.FadeOutDuration,{GroupTransparency=1})
  scope:Delay(Config.FadeOutDuration,function()scope:Destroy()end)
 end)
end
return Notifications
