
-- Cosmetic behavior only: purchasing remains owned by ShopController.
local Tween=game:GetService("TweenService")
local main=script.Parent
local catalog=main.Body.Catalog
local connections={}
local bound=setmetatable({},{__mode="k"})
local function connect(signal,fn) local c=signal:Connect(fn);table.insert(connections,c);return c end
local function tween(x,time,properties)
 local t=Tween:Create(x,TweenInfo.new(time,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),properties);t:Play();return t
end
local function bind(button)
 if not button:IsA("GuiButton") or bound[button] then return end
 if button.Name~="ActionButton" and button.Name~="Action" and button.Name~="Buy" then return end
 bound[button]=true
 local owned={}
 local function connect(signal,fn) local c=signal:Connect(fn);table.insert(owned,c);return c end
 button.Destroying:Once(function() for _,c in owned do c:Disconnect() end end)
 local shine=Instance.new("Frame");shine.Name="V2Shine";shine.Size=UDim2.fromScale(1,1);shine.BackgroundColor3=Color3.new(1,1,1);shine.BackgroundTransparency=.67;shine.BorderSizePixel=0;shine.ZIndex=button.ZIndex+1;shine.Active=false
 local c=Instance.new("UICorner",shine);c.CornerRadius=UDim.new(0,10)
 local g=Instance.new("UIGradient",shine);g.Rotation=25;g.Offset=Vector2.new(-1.5,0);g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.38,1),NumberSequenceKeypoint.new(.5,.15),NumberSequenceKeypoint.new(.62,1),NumberSequenceKeypoint.new(1,1)})
 shine.Parent=button
 local stroke=button:FindFirstChildOfClass("UIStroke")
 local base=stroke and stroke.Thickness or 1.5
 local sweep
 local function glint()
  if not button.Active or not main.Visible then return end
  if sweep then sweep:Cancel() end
  g.Offset=Vector2.new(-1.5,0)
  sweep=tween(g,.65,{Offset=Vector2.new(1.5,0)})
 end
 connect(button.MouseEnter,function() glint();if stroke and button.Active then tween(stroke,.15,{Thickness=base+1}) end end)
 connect(button.MouseLeave,function() if stroke then tween(stroke,.15,{Thickness=base}) end end)
 local scale=Instance.new("UIScale");scale.Name="V2PressScale";scale.Parent=button
 local motion
 local function press(value) if motion then motion:Cancel() end;motion=tween(scale,.1,{Scale=value}) end
 connect(button.InputBegan,function(input) if button.Active and (input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch or input.KeyCode==Enum.KeyCode.ButtonA) then press(.975) end end)
 connect(button.InputEnded,function(input) if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch or input.KeyCode==Enum.KeyCode.ButtonA then press(1) end end)
 connect(button.MouseLeave,function() press(1) end)
 connect(button:GetPropertyChangedSignal("Active"),function() if not button.Active then press(1);if stroke then stroke.Thickness=base end end end)
 connect(button.Activated,glint)
end
for _,v in main:GetDescendants() do bind(v) end
connect(main.DescendantAdded,bind)
local function layout()
 local narrow=main.AbsoluteSize.X<760
 local side=narrow and 82 or 112
 main.Tabs.Size=UDim2.new(0,side,1,-130)
 main.Body.Position=UDim2.fromOffset(side+30,110)
 main.Body.Size=UDim2.new(1,-side-48,1,-148)
 main.V2CollectionTitle.Position=UDim2.fromOffset(side+34,87)
 local grid=catalog.UIGridLayout
 grid.CellSize=UDim2.new(narrow and 1 or .5,narrow and -12 or -10,0,214)
 main.Header.TitlePlate.Size=UDim2.fromOffset(narrow and 180 or 260,58)
 main.Header.TitlePlate.TitleLabel.TextSize=narrow and 24 or 30
 main.Header.TitlePlate.V2Subtitle.Visible=not narrow
 main.Header.CoinsContainer.Size=UDim2.fromOffset(narrow and 112 or 158,38)
end
connect(main:GetPropertyChangedSignal("AbsoluteSize"),layout);layout()
connect(script.Destroying,function() for _,c in connections do c:Disconnect() end end)

-- A category illustration is shown only when the catalog has no product artwork.
local function decoratePreview(preview)
 if not preview:IsA("Frame") or preview.Name~="Preview" or preview:FindFirstChild("V2CategoryArt") then return end
 if preview.Parent.Name=="ProductCardTemplate" then return end
 local label=preview:FindFirstChild("PreviewLabel")
 local original=preview:FindFirstChild("PreviewIcon")
 if not label or not original then return end
 local art=Instance.new("ImageLabel");art.Name="V2CategoryArt";art.BackgroundTransparency=1;art.AnchorPoint=Vector2.new(.5,.5);art.Position=UDim2.fromScale(.5,.5);art.Size=UDim2.fromScale(.68,.68);art.ScaleType=Enum.ScaleType.Fit;art.ZIndex=preview.ZIndex+1;art.Parent=preview
 local function refresh()
  art.Visible=not(original.Visible and original.Image~="") and not(label.Visible and label.Text~="")
  for _,v in preview:GetChildren() do if v:IsA("ViewportFrame") and v.Visible then art.Visible=false end end
  for _,tab in main.Tabs:GetChildren() do
   if tab:IsA("GuiButton") and tab.BackgroundColor3==main.Tabs:GetAttribute("ActiveColor") then
    local icon=tab:FindFirstChild("IconImage");if icon then art.Image=icon.Image end
   end
  end
 end
 local owned={}
 table.insert(owned,preview.ChildAdded:Connect(refresh))
 table.insert(owned,preview.ChildRemoved:Connect(refresh))
 for _,sig in {original:GetPropertyChangedSignal("Visible"),original:GetPropertyChangedSignal("Image"),label:GetPropertyChangedSignal("Visible"),label:GetPropertyChangedSignal("Text")} do table.insert(owned,sig:Connect(refresh)) end
 for _,tab in main.Tabs:GetChildren() do if tab:IsA("GuiButton") then table.insert(owned,tab:GetPropertyChangedSignal("BackgroundColor3"):Connect(refresh)) end end
 preview.Destroying:Once(function() for _,c in owned do c:Disconnect() end end)
 refresh()
end
for _,v in main:GetDescendants() do decoratePreview(v) end
connect(main.DescendantAdded,decoratePreview)
