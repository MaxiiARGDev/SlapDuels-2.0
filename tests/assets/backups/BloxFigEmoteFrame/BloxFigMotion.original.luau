-- Managed by BloxFig. Runs only after the imported ScreenGui enters PlayerGui.
local RunService = game:GetService('RunService')
local UserInputService = game:GetService('UserInputService')
local GuiService = game:GetService('GuiService')
local HttpService = game:GetService('HttpService')
local SoundService = game:GetService('SoundService')
local ContentProvider = game:GetService('ContentProvider')
local TweenService = game:GetService('TweenService')
local gui = script.Parent
local decorationAsset=gui:GetAttribute('BloxFigDecorationAssetId')
if type(decorationAsset)=='string' then task.spawn(function()pcall(function()ContentProvider:PreloadAsync({decorationAsset})end)end)end
-- BEGIN BLOXFIG SCROLL BACKGROUNDS
local installScrollBackgrounds = (function()
-- Fixed artwork follows viewport geometry outside its scrolling canvas and clip.
-- Event driven: no polling or extra GuiObject wrappers.
local CONTROLLER_VERSION=169
return function(root, authoring)
    local states, byItem, connections, textStates, canvasStates = {}, {}, {}, {}, {}
    local detachedStates, viewportById, layoutStates, referencePending, nestedStates = {}, {}, {}, {}, {}
    local restoreLayout, stopped, recovering, historyEpoch = {}, false, false, 0
    local history
    if authoring and game then
        local ok, service=pcall(function() return game:GetService('ChangeHistoryService') end)
        if ok and service.OnUndo and service.OnRedo then history=service end
    end
    -- Coalesce property notifications before reading a complete authoring edit.
    -- Undo restores attributes and properties in multiple steps; none of those
    -- intermediate snapshots may become a new source layout.
    local function watch(callback,settle)
        if not authoring then return callback end
        local pending,serial=false,0
        return function()
            if stopped or recovering or (pending and not settle) then return end
            pending=true;serial+=1
            local request=serial
            local epoch=historyEpoch
            local function flush()
                if settle and request~=serial then return end
                pending=false
                if stopped or recovering or epoch~=historyEpoch then return end
                local recording
                if history and not history:IsRecordingInProgress() then
                    recording=history:TryBeginRecording('BloxFig derived layout')
                    if not recording then return end
                end
                local ok,problem=pcall(callback)
                if recording then history:FinishRecording(recording,ok and Enum.FinishRecordingOperation.Append or Enum.FinishRecordingOperation.Cancel) end
                if not ok then warn('[BloxFig] Layout update failed: '..tostring(problem)) end
            end
            -- Studio may deliver a multi-selection drag in separate notification
            -- batches. Read the settled edit, not a partly moved selection.
            if settle and task.delay then task.delay(.08,flush)else task.defer(flush)end
        end
    end
    local function active(node)
        local current = node
        while current do
            if authoring and current:IsA('ScreenGui')then
                local runtime=current:FindFirstChild('BloxFig Motion')
                local version=runtime and runtime:GetAttribute('BloxFigRuntimeVersion')
                if runtime and runtime:GetAttribute('BloxFigManagedRuntime')==true and type(version)=='number' and version>CONTROLLER_VERSION then return false end
            end
            if current==root then break end
            if current:GetAttribute('BloxFigArchive') == true or current:GetAttribute('BloxFigMissing') == true or current:GetAttribute('BloxFigRetiredDuplicate') == true then return false end
            current = current.Parent
        end
        return true
    end
    local function ownerOf(node)
        while node do
            if node:IsA('ScreenGui') then return node end
            node = node.Parent
        end
        return root
    end
    local function indexViewport(frame)
        local owner = ownerOf(frame)
        viewportById[owner] = viewportById[owner] or {}
        viewportById[owner][frame:GetAttribute('FigmaNodeId') or frame] = frame
    end
    for _, node in ipairs(root:GetDescendants()) do
        if node:IsA('ScrollingFrame') and active(node) then indexViewport(node) end
    end
    local moveFields={'BloxFigDeviceMoveGroup','BloxFigDeviceMovePosition','BloxFigDeviceMovePivot'}
    local function normalized(value,viewport)
        return value.X.Scale+value.X.Offset/viewport.X,value.Y.Scale+value.Y.Offset/viewport.Y
    end
    local function moveGroup(item,gui)
        local id=item:GetAttribute(moveFields[1])
        local position,pivot=item:GetAttribute(moveFields[2]),item:GetAttribute(moveFields[3])
        if type(id)~='number' or typeof(position)~='UDim2' or typeof(pivot)~='Vector2' then return end
        local left,top,right,bottom=math.huge,math.huge,-math.huge,-math.huge
        for _,node in ipairs(gui:GetChildren())do
            if node:IsA('GuiObject') and active(node) and node:GetAttribute(moveFields[1])==id then
                local p,s,a=node:GetAttribute('BloxFigDeviceBasePosition'),node:GetAttribute('BloxFigDeviceBaseSize'),node:GetAttribute('BloxFigDeviceBaseAnchor')
                if typeof(p)=='UDim2' and typeof(s)=='UDim2' and typeof(a)=='Vector2' then
                    local x,y=p.X.Scale-a.X*s.X.Scale,p.Y.Scale-a.Y*s.Y.Scale
                    left,top=math.min(left,x),math.min(top,y)
                    right,bottom=math.max(right,x+s.X.Scale),math.max(bottom,y+s.Y.Scale)
                end
            end
        end
        if left==math.huge then return end
        return {position=position,pivot=pivot,left=left,top=top,right=right,bottom=bottom}
    end
    local function movedTogether(gui,viewportOverride)
        local viewport=viewportOverride or gui.AbsoluteSize
        if not viewport or viewport.X<=0 or viewport.Y<=0 then return false end
        local moved={}
        local left,top,right,bottom=math.huge,math.huge,-math.huge,-math.huge
        local screenLeft,screenTop,screenRight,screenBottom=math.huge,math.huge,-math.huge,-math.huge
        local nextId=1
        for node,record in pairs(layoutStates)do
            if node.Parent==gui and active(node) and node:GetAttribute('BloxFigFixedViewportId')==nil and record.snapshot then
                nextId=math.max(nextId,(tonumber(node:GetAttribute(moveFields[1])) or 0)+1)
                local lastP,lastS=record.snapshot()
                if lastP and lastS then
                    local x,y=normalized(node.Position,viewport)
                    local ox,oy=normalized(lastP,viewport)
                    local w,h=normalized(node.Size,viewport)
                    local ow,oh=normalized(lastS,viewport)
                    if math.abs((x-ox)*viewport.X)>.01 or math.abs((y-oy)*viewport.Y)>.01
                        or math.abs((w-ow)*viewport.X)>.01 or math.abs((h-oh)*viewport.Y)>.01 then
                        local p,size,anchor=node:GetAttribute('BloxFigDeviceBasePosition'),node:GetAttribute('BloxFigDeviceBaseSize'),node:GetAttribute('BloxFigDeviceBaseAnchor')
                        if typeof(p)~='UDim2' or typeof(size)~='UDim2' or typeof(anchor)~='Vector2' or ow<=0 or oh<=0 then return false end
                        local entry={node=node,record=record,x=x,y=y,ox=ox,oy=oy,w=w,h=h,ow=ow,oh=oh,p=p,size=size,anchor=anchor}
                        moved[#moved+1]=entry
                        local bx,by=p.X.Scale-anchor.X*size.X.Scale,p.Y.Scale-anchor.Y*size.Y.Scale
                        left,top=math.min(left,bx),math.min(top,by)
                        right,bottom=math.max(right,bx+size.X.Scale),math.max(bottom,by+size.Y.Scale)
                        local a=node.AnchorPoint
                        screenLeft,screenTop=math.min(screenLeft,x-a.X*w),math.min(screenTop,y-a.Y*h)
                        screenRight,screenBottom=math.max(screenRight,x+(1-a.X)*w),math.max(screenBottom,y+(1-a.Y)*h)
                    end
                end
            end
        end
        if #moved<2 then return false end
        -- Studio truncates Offset components independently. Averaging one
        -- item's width/height ratios lets a 1px height error shift its width by
        -- several pixels, incorrectly splitting a resized selection. Fit one
        -- common transform in physical pixels, bounded by the rounding error
        -- of EVERY item, then verify it before saving any authoring data.
        local numerator,denominator,minimum,maximum=0,0,0,math.huge
        for _,entry in ipairs(moved)do
            for _,axis in ipairs({{entry.ow*viewport.X,entry.w*viewport.X},{entry.oh*viewport.Y,entry.h*viewport.Y}})do
                local before,after=axis[1],axis[2]
                numerator+=before*after;denominator+=before*before
                minimum=math.max(minimum,(after-1.01)/before)
                maximum=math.min(maximum,(after+1.01)/before)
            end
        end
        if minimum>maximum or denominator<=0 then return false end
        local zoom=math.clamp(numerator/denominator,minimum,maximum)
        if zoom<=0 then return false end
        if math.abs(zoom-1)<.000001 then zoom=1 end
        local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
        for _,entry in ipairs(moved)do
            local x,y=entry.x-entry.ox*zoom,entry.y-entry.oy*zoom
            minX,minY=math.min(minX,x),math.min(minY,y)
            maxX,maxY=math.max(maxX,x),math.max(maxY,y)
        end
        local tx,ty=(minX+maxX)/2,(minY+maxY)/2
        for _,entry in ipairs(moved)do
            if math.abs(entry.w-entry.ow*zoom)*viewport.X>1.01 or math.abs(entry.h-entry.oh*zoom)*viewport.Y>1.01
                or math.abs(entry.x-entry.ox*zoom-tx)*viewport.X>1.01 or math.abs(entry.y-entry.oy*zoom-ty)*viewport.Y>1.01 then return false end
        end
        local position=UDim2.fromScale((screenLeft+screenRight)/2,(screenTop+screenBottom)/2)
        local pivot=Vector2.new((left+right)/2,(top+bottom)/2)
        for _,entry in ipairs(moved)do entry.record.writing(true)end
        for _,entry in ipairs(moved)do
            local node=entry.node
            if zoom~=1 then
                node:SetAttribute('BloxFigDeviceBasePosition',UDim2.fromScale(pivot.X+(entry.p.X.Scale-pivot.X)*zoom,pivot.Y+(entry.p.Y.Scale-pivot.Y)*zoom))
                node:SetAttribute('BloxFigDeviceBaseSize',UDim2.fromScale(entry.size.X.Scale*zoom,entry.size.Y.Scale*zoom))
            end
            node:SetAttribute(moveFields[1],nextId);node:SetAttribute(moveFields[2],position);node:SetAttribute(moveFields[3],pivot)
            node:SetAttribute('BloxFigDeviceScreenPosition',nil);node:SetAttribute('BloxFigDeviceScreenAnchor',nil)
            node:SetAttribute('BloxFigDevicePosition',node.Position);node:SetAttribute('BloxFigDeviceSize',node.Size)
            entry.record.adopt()
        end
        for _,entry in ipairs(moved)do entry.record.writing(false)end
        -- Saving the edit never rewrites the properties Studio is manipulating.
        return true
    end
    local function registerLayout(item)
        if layoutStates[item] or not item:IsA('GuiObject') or not active(item) then return end
        -- Detached scroll artwork follows its viewport. Giving it a second,
        -- independent device position reintroduces the pre-drag location when
        -- a later layout notification or animation reads that stale baseline.
        if item:GetAttribute('BloxFigFixedViewportId')~=nil then return end
        local gui = item.Parent
        if not gui or not gui:IsA('ScreenGui') or gui:GetAttribute('BloxFigDeviceScaling')==false or typeof(item:GetAttribute('BloxFigDeviceBasePosition')) ~= 'UDim2' then return end
        local writing, lastPosition, lastSize, lastViewport = false, nil, nil, nil
        local edited
        local function geometry(viewportOverride)
            local width, height, viewport = gui:GetAttribute('ReferenceWidth'), gui:GetAttribute('ReferenceHeight'), viewportOverride or gui.AbsoluteSize
            if type(width) ~= 'number' or type(height) ~= 'number' or width ~= width or height ~= height or width <= 0 or height <= 0
                or not viewport or viewport.X <= 0 or viewport.Y <= 0 then return end
            local fitWidth,fitHeight=width,height
            local group=moveGroup(item,gui)
            if group then fitWidth=math.max(width,(group.right-group.left)*width);fitHeight=math.max(height,(group.bottom-group.top)*height)end
            local base=item:GetAttribute('BloxFigDeviceBaseSize')
            if typeof(base)=='UDim2' and item:GetAttribute('BloxFigDeviceScreenPosition')~=nil then
                fitWidth=math.max(width,width*base.X.Scale+base.X.Offset)
                fitHeight=math.max(height,height*base.Y.Scale+base.Y.Offset)
            end
            local factor = math.min(1,viewport.X*.9/fitWidth,viewport.Y*.9/fitHeight)
            if gui:GetAttribute('BloxFigDeviceScaleMode')=='viewport' then
                local reference=gui:GetAttribute('BloxFigDeviceReferenceViewport')
                local referenceFit=gui:GetAttribute('BloxFigDeviceReferenceFit')
                if gui:GetAttribute('BloxFigDeviceReferenceReady')~=true and authoring and not referencePending[gui] then
                    referencePending[gui]=true
                    local epoch=historyEpoch
                    local function capture()
                        referencePending[gui]=nil
                        if stopped or recovering or not active(item) or epoch~=historyEpoch or (not gui.Parent and gui~=root) then return end
                        if gui:GetAttribute('BloxFigDeviceScaling')==false or gui:GetAttribute('BloxFigDeviceReferenceReady')==true then return end
                        local actual=gui.AbsoluteSize
                        if not actual or actual.X<=0 or actual.Y<=0 then return end
                        referencePending[gui]='writing'
                        gui:SetAttribute('BloxFigDeviceReferenceViewport',Vector2.new(actual.X,actual.Y))
                        gui:SetAttribute('BloxFigDeviceReferenceFit',math.min(1,actual.X*.9/width,actual.Y*.9/height))
                        gui:SetAttribute('BloxFigDeviceReferenceReady',true)
                        referencePending[gui]=nil
                        for node,record in pairs(layoutStates)do if node.Parent==gui then record.resize()end end
                    end
                    if task.delay then task.delay(.05,capture)else task.defer(capture)end
                end
                if gui:GetAttribute('BloxFigDeviceReferenceReady')==true and typeof(reference)=='Vector2' and reference.X>0 and reference.Y>0 and type(referenceFit)=='number' and referenceFit>0 then
                    factor=math.min(referenceFit*math.min(viewport.X/reference.X,viewport.Y/reference.Y),viewport.X*.9/fitWidth,viewport.Y*.9/fitHeight)
                end
            end
            return width*factor/viewport.X,height*factor/viewport.Y,viewport,group
        end
        local function resize()
            if stopped or recovering or not active(item) or writing or referencePending[gui]=='writing' or item.Parent ~= gui or gui:GetAttribute('BloxFigDeviceScaling')==false then return end
            local viewport=gui.AbsoluteSize
            if authoring and edited and lastViewport and viewport and (viewport.X~=lastViewport.X or viewport.Y~=lastViewport.Y) then
                -- Commit a completed authoring edit against its OLD viewport
                -- before a device change can overwrite it with derived geometry.
                edited(lastViewport)
            end
            local sx, sy, _, group = geometry()
            local p, s, anchor = item:GetAttribute('BloxFigDeviceBasePosition'), item:GetAttribute('BloxFigDeviceBaseSize'), item:GetAttribute('BloxFigDeviceBaseAnchor')
            if not sx or typeof(p) ~= 'UDim2' or typeof(s) ~= 'UDim2' or typeof(anchor) ~= 'Vector2' then return end
            local size = UDim2.fromScale(s.X.Scale*sx,s.Y.Scale*sy)
            local position = UDim2.fromScale((1-sx)/2+(p.X.Scale+(item.AnchorPoint.X-anchor.X)*s.X.Scale)*sx,
                (1-sy)/2+(p.Y.Scale+(item.AnchorPoint.Y-anchor.Y)*s.Y.Scale)*sy)
            local screenPosition=item:GetAttribute('BloxFigDeviceScreenPosition')
            local screenAnchor=item:GetAttribute('BloxFigDeviceScreenAnchor')
            if group then
                -- Clamp the whole moved selection once; never clamp each piece.
                local centreX=math.clamp(group.position.X.Scale,(group.pivot.X-group.left)*sx,1-(group.right-group.pivot.X)*sx)
                local centreY=math.clamp(group.position.Y.Scale,(group.pivot.Y-group.top)*sy,1-(group.bottom-group.pivot.Y)*sy)
                position=UDim2.fromScale(centreX+(p.X.Scale+(item.AnchorPoint.X-anchor.X)*s.X.Scale-group.pivot.X)*sx,
                    centreY+(p.Y.Scale+(item.AnchorPoint.Y-anchor.Y)*s.Y.Scale-group.pivot.Y)*sy)
            elseif typeof(screenPosition)=='UDim2' and typeof(screenAnchor)=='Vector2' then
                local x=screenPosition.X.Scale+(item.AnchorPoint.X-screenAnchor.X)*size.X.Scale
                local y=screenPosition.Y.Scale+(item.AnchorPoint.Y-screenAnchor.Y)*size.Y.Scale
                position=UDim2.fromScale(math.clamp(x,item.AnchorPoint.X*size.X.Scale,1-(1-item.AnchorPoint.X)*size.X.Scale),
                    math.clamp(y,item.AnchorPoint.Y*size.Y.Scale,1-(1-item.AnchorPoint.Y)*size.Y.Scale))
            end
            writing = true
            lastPosition, lastSize, lastViewport = position, size, gui.AbsoluteSize
            if item.Size~=size then item.Size = size end
            item:SetAttribute('BloxFigDevicePosition',position)
            item:SetAttribute('BloxFigDeviceSize',size)
            if not group and typeof(screenPosition)=='UDim2' and typeof(screenAnchor)=='Vector2' then
                -- Older installed authoring controllers still consume the
                -- centred-artboard baseline. Publish its current equivalent
                -- so their later callbacks cannot put the button off-screen.
                local compatible=UDim2.fromScale((position.X.Scale-(1-sx)/2)/sx-(item.AnchorPoint.X-anchor.X)*s.X.Scale,
                    (position.Y.Scale-(1-sy)/2)/sy-(item.AnchorPoint.Y-anchor.Y)*s.Y.Scale)
                if item:GetAttribute('BloxFigDeviceBasePosition')~=compatible then item:SetAttribute('BloxFigDeviceBasePosition',compatible) end
            end
            if item.Position~=position then item.Position = position end
            writing = false
        end
        edited=function(viewportOverride)
            if stopped or recovering or not active(item) or writing or item.Parent ~= gui or gui:GetAttribute('BloxFigDeviceScaling')==false or (item.Position == lastPosition and item.Size == lastSize) then return end
            -- Another managed controller can publish the same derived write.
            -- Adopt it without converting it back into fresh authoring data.
            if item.Position==item:GetAttribute('BloxFigDevicePosition') and item.Size==item:GetAttribute('BloxFigDeviceSize') then
                lastPosition,lastSize=item.Position,item.Size
                return
            end
            if movedTogether(gui,viewportOverride) then return end
            local sx, sy, viewport = geometry(viewportOverride)
            if not sx then return end
            local p, s = item.Position, item.Size
            local size = UDim2.fromScale((s.X.Scale+s.X.Offset/viewport.X)/sx,(s.Y.Scale+s.Y.Offset/viewport.Y)/sy)
            local position = UDim2.fromScale((p.X.Scale+p.X.Offset/viewport.X-(1-sx)/2)/sx,
                (p.Y.Scale+p.Y.Offset/viewport.Y-(1-sy)/2)/sy)
            local moved=p~=lastPosition or s~=lastSize
            writing = true
            for _,key in ipairs(moveFields)do item:SetAttribute(key,nil)end
            if moved then
                -- A Studio move is screen-relative, not a displacement from
                -- the centred Figma artboard. The latter goes negative on tablets.
                item:SetAttribute('BloxFigDeviceScreenPosition',UDim2.fromScale(p.X.Scale+p.X.Offset/viewport.X,p.Y.Scale+p.Y.Offset/viewport.Y))
                item:SetAttribute('BloxFigDeviceScreenAnchor',item.AnchorPoint)
            end
            lastPosition, lastSize = p, s
            item:SetAttribute('BloxFigDeviceBasePosition',position)
            item:SetAttribute('BloxFigDeviceBaseSize',size)
            item:SetAttribute('BloxFigDeviceBaseAnchor',item.AnchorPoint)
            item:SetAttribute('BloxFigDevicePosition',p)
            writing = false
        end
        local requestResize,requestEdit=watch(resize),watch(edited,true)
        restoreLayout[item]=function() lastPosition,lastSize,lastViewport=item.Position,item.Size,gui.AbsoluteSize end
        local signals = {gui:GetPropertyChangedSignal('AbsoluteSize'):Connect(requestResize),
            gui:GetAttributeChangedSignal('ReferenceWidth'):Connect(requestResize),
            gui:GetAttributeChangedSignal('ReferenceHeight'):Connect(requestResize),
            gui:GetAttributeChangedSignal('BloxFigLayoutScale'):Connect(requestResize),
            gui:GetAttributeChangedSignal('BloxFigDeviceScaleMode'):Connect(requestResize),
            gui:GetAttributeChangedSignal('BloxFigDeviceReferenceViewport'):Connect(requestResize),
            gui:GetAttributeChangedSignal('BloxFigDeviceReferenceFit'):Connect(requestResize),
            gui:GetAttributeChangedSignal('BloxFigDeviceReferenceReady'):Connect(requestResize),
            item:GetPropertyChangedSignal('AnchorPoint'):Connect(requestResize)}
        for _, name in ipairs({'BloxFigDeviceBasePosition','BloxFigDeviceBaseSize','BloxFigDeviceBaseAnchor','BloxFigDeviceScreenPosition','BloxFigDeviceScreenAnchor','BloxFigDeviceMoveGroup','BloxFigDeviceMovePosition','BloxFigDeviceMovePivot'}) do
            signals[#signals+1] = item:GetAttributeChangedSignal(name):Connect(function() if not writing then requestResize() end end)
        end
        -- Game animation writes must never become authoring geometry. Fixed
        -- artwork is derived from its viewport, not an independent layout edit.
        if authoring and item:GetAttribute('BloxFigFixedViewportId') == nil then
            signals[#signals+1] = item:GetPropertyChangedSignal('Position'):Connect(function() if not writing then requestEdit() end end)
            signals[#signals+1] = item:GetPropertyChangedSignal('Size'):Connect(function() if not writing then requestEdit() end end)
        end
        signals.snapshot=function()return lastPosition,lastSize end
        signals.writing=function(value)writing=value end
        signals.adopt=function()lastPosition,lastSize=item.Position,item.Size end
        signals.resize=resize
        layoutStates[item] = signals
        resize()
    end
    local function registerDetached(item)
        if detachedStates[item] or not item:IsA('GuiObject') or not active(item) then return end
        local scope = viewportById[ownerOf(item)]
        local frame = scope and scope[item:GetAttribute('BloxFigFixedViewportId')]
        local position, size = item:GetAttribute('BloxFigFixedPosition'), item:GetAttribute('BloxFigFixedSize')
        if not frame or typeof(position) ~= 'UDim2' or typeof(size) ~= 'UDim2' then return end
        local function update()
            if stopped or recovering or not active(item) or not frame.Parent or not item.Parent then return end
            local p, s, anchor = frame.Position, frame.Size, frame.AnchorPoint
            local x = position.X.Scale - anchor.X + item.AnchorPoint.X * size.X.Scale
            local y = position.Y.Scale - anchor.Y + item.AnchorPoint.Y * size.Y.Scale
            local wantedPosition=UDim2.new(p.X.Scale+s.X.Scale*x,p.X.Offset+s.X.Offset*x,p.Y.Scale+s.Y.Scale*y,p.Y.Offset+s.Y.Offset*y)
            local wantedSize=UDim2.new(s.X.Scale*size.X.Scale,s.X.Offset*size.X.Scale,s.Y.Scale*size.Y.Scale,s.Y.Offset*size.Y.Scale)
            local owner=ownerOf(item)
            if owner and owner:GetAttribute('BloxFigDeviceScaling')==true then
                item:SetAttribute('BloxFigDevicePosition',wantedPosition)
                item:SetAttribute('BloxFigDeviceSize',wantedSize)
            end
            if item.Position~=wantedPosition then item.Position=wantedPosition end
            if item.Size~=wantedSize then item.Size=wantedSize end
        end
        local requestUpdate=watch(update)
        local signals = {}
        for _, property in ipairs({'Position','Size','AnchorPoint'}) do
            table.insert(signals, frame:GetPropertyChangedSignal(property):Connect(requestUpdate))
        end
        table.insert(signals,item:GetPropertyChangedSignal('AnchorPoint'):Connect(requestUpdate))
        detachedStates[item] = {frame=frame,signals=signals}
        update()
    end
    local scaleOf
    local function stretchOf(node)
        local x,y=1,1
        while node do
            x*=node:GetAttribute('BloxFigMotionStretchX') or 1
            y*=node:GetAttribute('BloxFigMotionStretchY') or 1
            node=node.Parent
        end
        return math.max(x,.001),math.max(y,.001)
    end
    local function registerText(item)
        if textStates[item] or not (item:IsA('TextLabel') or item:IsA('TextBox')) then return end
        local size, width, height = item:GetAttribute('BloxFigResponsiveFont'), item:GetAttribute('BloxFigResponsiveWidth'), item:GetAttribute('BloxFigResponsiveHeight')
        if type(size) ~= 'number' or type(width) ~= 'number' or type(height) ~= 'number' or width <= 0 or height <= 0 then return end
        local lastGeometry, lastRatio
        local function resize()
            if stopped or recovering or not active(item) or not item.Parent or item.AbsoluteSize.X <= 0 or item.AbsoluteSize.Y <= 0 then return end
            -- UIScale already scales rendered glyphs; avoid applying it twice.
            local ratio
            local parent, box = item.Parent, item:GetAttribute('BloxFigMotionBaseSize') or item.Size
            if box and parent and parent.AbsoluteSize then
                local extent = parent:IsA('ScrollingFrame') and parent.AbsoluteCanvasSize or parent.AbsoluteSize
                local ancestorScale = scaleOf(parent)
                local stretchX,stretchY=stretchOf(parent)
                local logicalWidth = extent.X / ancestorScale / stretchX * box.X.Scale + box.X.Offset
                local logicalHeight = extent.Y / ancestorScale / stretchY * box.Y.Scale + box.Y.Offset
                ratio = math.min(logicalWidth/width,logicalHeight/height)
            else
                ratio = math.min(item.AbsoluteSize.X / width, item.AbsoluteSize.Y / height) / scaleOf(item)
            end
            -- AbsoluteSize is rounded, and can notify before an ancestor's
            -- UIScale has settled. Dividing it by an animated scale every
            -- frame refits the font (and shimmer copy) during a button press.
            -- Reuse the logical font size while only managed motion changes.
            -- Real viewport, Size, canvas or constraint edits invalidate it.
            local geometry, node, motion, dynamic = {}, item, false, false
            while node do
                if node:IsA('GuiObject') then
                    local motionSize=node:GetAttribute('BloxFigMotionBaseSize')
                    geometry[#geometry+1]=tostring(typeof(motionSize)=='UDim2' and motionSize or node.Size)
                    geometry[#geometry+1]=tostring(node.SizeConstraint)
                    if node.AutomaticSize and node.AutomaticSize~=Enum.AutomaticSize.None then dynamic=true end
                    local modifier=node:FindFirstChild('BloxFigScale')
                    if modifier and modifier:IsA('UIScale') then motion=true end
                    local aspect=node:FindFirstChildOfClass('UIAspectRatioConstraint')
                    if aspect then geometry[#geometry+1]=tostring(aspect.AspectRatio)..tostring(aspect.DominantAxis)..tostring(aspect.AspectType) end
                    local bounds=node:FindFirstChildOfClass('UISizeConstraint')
                    if bounds then geometry[#geometry+1]=tostring(bounds.MinSize)..tostring(bounds.MaxSize) end
                    if node:IsA('ScrollingFrame') then
                        geometry[#geometry+1]=tostring(node.CanvasSize)
                        if node.AutomaticCanvasSize~=Enum.AutomaticSize.None then dynamic=true end
                    end
                elseif node:IsA('ScreenGui') then
                    geometry[#geometry+1]=tostring(node.AbsoluteSize)
                    break
                end
                node=node.Parent
            end
            local key=table.concat(geometry,'|')
            if motion and not dynamic and key==lastGeometry and lastRatio then ratio=lastRatio end
            lastGeometry,lastRatio=key,ratio
            local wanted = math.max(1,size*ratio)
            if item:GetAttribute('BloxFigResponsiveTextRatio')~=ratio then item:SetAttribute('BloxFigResponsiveTextRatio',ratio)end
            item:SetAttribute('BloxFigManagedTextWrite',true)
            if math.abs(item.TextSize-wanted)>.0001 then item.TextSize = wanted end
            local outline = item:FindFirstChild('BloxFigTextOutline')
            if outline and outline:IsA('UIStroke') then
                local thickness=(item:GetAttribute('BloxFigResponsiveStroke') or 0)*ratio
                if math.abs(outline.Thickness-thickness)>.0001 then outline.Thickness=thickness end
            end
            item:SetAttribute('BloxFigManagedTextWrite',nil)
        end
        local resizeSignal=item:GetPropertyChangedSignal('AbsoluteSize'):Connect(watch(resize))
        textStates[item]=resizeSignal
        resize()
    end
    scaleOf = function(frame)
        local scale, node = 1, frame
        while node do
            local modifier = node:FindFirstChildOfClass('UIScale')
            if modifier then scale *= modifier.Scale end
            node = node.Parent
        end
        return math.max(scale, .001)
    end
    local function registerNested(item)
        if not authoring or nestedStates[item] or not item:IsA('GuiObject') or not active(item) then return end
        local gui,parent=ownerOf(item),item.Parent
        if not gui or not gui:IsA('ScreenGui') or gui:GetAttribute('BloxFigDeviceScaling')==false
            or not parent or not parent:IsA('GuiObject') then return end
        if item:GetAttribute('BloxFigImport')~=true and item:GetAttribute('BloxFigContainer')~=true and item:GetAttribute('BloxFigNativeText')~=true then return end
        if item:GetAttribute('BloxFigScrollFixed')==true or item:GetAttribute('BloxFigFixedViewportId')~=nil then return end
        local writing,pendingParent,pendingExtent=false,nil,nil
        local function extent(node)
            if not node or not node:IsA('GuiObject') then return end
            local size=node:IsA('ScrollingFrame') and node.AbsoluteCanvasSize or node.AbsoluteSize
            if not size or size.X<=0 or size.Y<=0 then return end
            local modifier=scaleOf(node)
            return Vector2.new(size.X/modifier,size.Y/modifier)
        end
        local function normalize()
            if stopped or recovering or not active(item) or item.Parent~=pendingParent or not pendingExtent then return end
            if ownerOf(item):GetAttribute('BloxFigDeviceScaling')==false then return end
            local current=item.Parent
            for _,kind in ipairs({'UIListLayout','UIGridLayout','UITableLayout','UIPageLayout'})do
                if current:FindFirstChildOfClass(kind)then return end
            end
            if Enum.AutomaticSize and item.AutomaticSize and item.AutomaticSize~=Enum.AutomaticSize.None then return end
            local w,h=pendingExtent.X,pendingExtent.Y
            local sw,sh=w,h
            if Enum.SizeConstraint then
                if item.SizeConstraint==Enum.SizeConstraint.RelativeXX then sh=w
                elseif item.SizeConstraint==Enum.SizeConstraint.RelativeYY then sw=h end
            end
            local p,size=item.Position,item.Size
            writing=true
            if p.X.Offset~=0 or p.Y.Offset~=0 then item.Position=UDim2.fromScale(p.X.Scale+p.X.Offset/w,p.Y.Scale+p.Y.Offset/h)end
            if size.X.Offset~=0 or size.Y.Offset~=0 then item.Size=UDim2.fromScale(size.X.Scale+size.X.Offset/sw,size.Y.Scale+size.Y.Offset/sh)end
            writing=false
        end
        local request=watch(normalize,true)
        local function changed()
            if writing or stopped or recovering then return end
            pendingParent=item.Parent;pendingExtent=extent(pendingParent)
            request()
        end
        nestedStates[item]={item:GetPropertyChangedSignal('Position'):Connect(changed),item:GetPropertyChangedSignal('Size'):Connect(changed)}
    end
    local function registerCanvas(frame)
        if canvasStates[frame] or not frame:IsA('ScrollingFrame') then return end
        local width, height = frame:GetAttribute('BloxFigScrollReferenceWidth'), frame:GetAttribute('BloxFigScrollReferenceHeight')
        local canvasWidth, canvasHeight = frame:GetAttribute('BloxFigScrollCanvasWidth'), frame:GetAttribute('BloxFigScrollCanvasHeight')
        if type(width) ~= 'number' or type(height) ~= 'number' or type(canvasWidth) ~= 'number' or type(canvasHeight) ~= 'number' or width <= 0 or height <= 0 then return end
        if not recovering then frame.ElasticBehavior = Enum.ElasticBehavior.Never end
        local clamping = false
        local function stopAtEdge()
            if stopped or recovering or not active(frame) or clamping or not frame.Parent then return end
            local window, canvas = frame.AbsoluteWindowSize, frame.AbsoluteCanvasSize
            if not window or not canvas or window.X <= 0 or window.Y <= 0 then return end
            local position, velocity = frame.CanvasPosition, frame:GetScrollVelocity()
            local maxX = math.max(0, canvas.X-window.X)
            local maxY = math.max(0, canvas.Y-window.Y)
            if frame.ScrollingDirection == Enum.ScrollingDirection.Y then maxX = 0 end
            if frame.ScrollingDirection == Enum.ScrollingDirection.X then maxY = 0 end
            local x, y = math.clamp(position.X,0,maxX), math.clamp(position.Y,0,maxY)
            local outward = (x <= 0 and velocity.X < 0) or (x >= maxX and velocity.X > 0)
                or (y <= 0 and velocity.Y < 0) or (y >= maxY and velocity.Y > 0)
            if x ~= position.X or y ~= position.Y or outward then
                clamping = true
                frame:ResetScrollVelocity()
                if x ~= position.X or y ~= position.Y then frame.CanvasPosition = Vector2.new(x,y) end
                clamping = false
            end
        end
        local function resize()
            if stopped or recovering or not active(frame) or not frame.Parent or frame.AbsoluteSize.X <= 0 or frame.AbsoluteSize.Y <= 0 then return end
            local scale = scaleOf(frame)
            frame.CanvasSize = UDim2.fromOffset(canvasWidth * frame.AbsoluteSize.X / width / scale, canvasHeight * frame.AbsoluteSize.Y / height / scale)
        end
        local requestEdge=watch(stopAtEdge)
        local signals = {frame:GetPropertyChangedSignal('AbsoluteSize'):Connect(watch(resize))}
        for _, property in ipairs({'CanvasPosition','AbsoluteCanvasSize','AbsoluteWindowSize','ScrollingDirection'}) do
            table.insert(signals,frame:GetPropertyChangedSignal(property):Connect(requestEdge))
        end
        canvasStates[frame] = {Disconnect=function() for _, connection in ipairs(signals) do connection:Disconnect() end end}
        resize()
        stopAtEdge()
    end
    local function update(state)
        local frame = state.frame
        if stopped or recovering or not active(frame) or not frame.Parent then return end
        local offset, scale = frame.CanvasPosition, scaleOf(frame)
        for item in pairs(state.items) do
            if item.Parent == frame and item:GetAttribute('BloxFigScrollFixed') == true then
                local base = item:GetAttribute('BloxFigScrollFixedBase')
                if typeof(base) == 'UDim2' then
                    item.Position = UDim2.new(base.X.Scale, base.X.Offset + offset.X / scale,
                        base.Y.Scale, base.Y.Offset + offset.Y / scale)
                end
            end
        end
    end
    local function register(item)
        if not active(item)then return end
        registerLayout(item)
        registerNested(item)
        registerDetached(item)
        registerCanvas(item)
        registerText(item)
        if byItem[item] or not item:IsA('GuiObject') or item:GetAttribute('BloxFigScrollFixed') ~= true then return end
        local frame = item.Parent
        if not frame or not frame:IsA('ScrollingFrame') then return end
        local state = states[frame]
        if not state then
            state = {frame=frame, items={}, connections={}}
            states[frame] = state
            local requestUpdate=watch(function() update(state) end)
            for _, property in ipairs({'CanvasPosition', 'AbsoluteSize'}) do
                table.insert(state.connections, frame:GetPropertyChangedSignal(property):Connect(requestUpdate))
            end
        end
        state.items[item], byItem[item] = true, state
        update(state)
    end
    if history then
        local function restored()
            historyEpoch+=1
            recovering=true
            local epoch=historyEpoch
            for item,adopt in pairs(restoreLayout) do if item.Parent then adopt() end end
            task.defer(function()
                if stopped or historyEpoch~=epoch then return end
                -- Reattach to restored instances without writing to Studio's
                -- newly-restored history or replacing its redo branch.
                for _,item in ipairs(root:GetDescendants()) do register(item) end
                for item,adopt in pairs(restoreLayout) do if item.Parent then adopt() end end
                recovering=false
            end)
        end
        connections[#connections+1]=history.OnUndo:Connect(restored)
        connections[#connections+1]=history.OnRedo:Connect(restored)
    end
    for _, item in ipairs(root:GetDescendants()) do register(item) end
    table.insert(connections, root.DescendantAdded:Connect(function(item)
        local epoch=historyEpoch
        task.defer(function()
            if not stopped and not recovering and epoch==historyEpoch and item:IsDescendantOf(root) then
                if item:IsA('ScrollingFrame') and active(item) then
                    indexViewport(item)
                    for _, artwork in ipairs(root:GetDescendants()) do
                        if ownerOf(artwork) == ownerOf(item) then registerDetached(artwork) end
                    end
                end
                register(item)
            end
        end)
    end))
    table.insert(connections, root.DescendantRemoving:Connect(function(item)
        for artwork, state in pairs(detachedStates) do
            if artwork == item or state.frame == item then
                for _, signal in ipairs(state.signals) do signal:Disconnect() end
                detachedStates[artwork] = nil
            end
        end
        restoreLayout[item]=nil
        if nestedStates[item]then for _,connection in ipairs(nestedStates[item])do connection:Disconnect()end;nestedStates[item]=nil end
        if layoutStates[item] then
            for _, signal in ipairs(layoutStates[item]) do signal:Disconnect() end
            layoutStates[item] = nil
        end
        local key = item:GetAttribute('FigmaNodeId') or item
        local scope = viewportById[ownerOf(item)]
        if scope and scope[key] == item then scope[key] = nil end
        if item:IsA('ScreenGui') then viewportById[item] = nil end
        if canvasStates[item] then canvasStates[item]:Disconnect(); canvasStates[item] = nil end
        if textStates[item] then textStates[item]:Disconnect(); textStates[item] = nil end
        local state = byItem[item]
        if state then state.items[item], byItem[item] = nil, nil end
        local container = states[item]
        if container then
            for _, connection in ipairs(container.connections) do connection:Disconnect() end
            for child in pairs(container.items) do byItem[child] = nil end
            states[item] = nil
        end
    end))
    return function()
        stopped=true;historyEpoch+=1
        table.clear(restoreLayout)
        table.clear(referencePending)
        for _, connection in ipairs(connections) do connection:Disconnect() end
        for _, connection in pairs(textStates) do connection:Disconnect() end
        for _, connection in pairs(canvasStates) do connection:Disconnect() end
        for _, state in pairs(detachedStates) do for _, signal in ipairs(state.signals) do signal:Disconnect() end end
        for _, state in pairs(states) do for _, connection in ipairs(state.connections) do connection:Disconnect() end end
        for _,signals in pairs(nestedStates)do for _,connection in ipairs(signals)do connection:Disconnect()end end
        table.clear(nestedStates)
        for _, signals in pairs(layoutStates) do for _, signal in ipairs(signals) do signal:Disconnect() end end
        table.clear(layoutStates)
        table.clear(states)
        table.clear(byItem)
        table.clear(textStates)
        table.clear(canvasStates)
        table.clear(detachedStates)
        table.clear(viewportById)
    end
end

end)()
local stopScrollBackgrounds = installScrollBackgrounds(gui)
script.Destroying:Connect(stopScrollBackgrounds)
-- END BLOXFIG SCROLL BACKGROUNDS
-- BEGIN BLOXFIG RAINBOW LIGHT
local rainbowLightTags={shiny='rainbowshiny',glint='rainbowglint',textshimmer='rainbowtextshimmer'}
local rainbowLightColors={{255,65,95},{255,155,40},{255,235,70},{70,240,125},{60,215,255},{100,110,255},{220,80,255}}
local rainbowLightPositions={.22,.32,.41,.50,.59,.68,.78}
local rainbowLightAlpha={.44,.64,.82,1,.82,.64,.44}
local function rainbowLightSequence(halfWidth)
    local keys={ColorSequenceKeypoint.new(0,Color3.fromRGB(table.unpack(rainbowLightColors[1])))}
    for i,rgb in ipairs(rainbowLightColors)do
        keys[#keys+1]=ColorSequenceKeypoint.new(.5-halfWidth+2*halfWidth*rainbowLightPositions[i],Color3.fromRGB(table.unpack(rgb)))
    end
    keys[#keys+1]=ColorSequenceKeypoint.new(1,Color3.fromRGB(table.unpack(rainbowLightColors[#rainbowLightColors])))
    return ColorSequence.new(keys)
end
local function rainbowLightTransparency(halfWidth,opacity)
    -- Identical to the original white gleam. Only ColorSequence changes.
    return NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5-halfWidth,1),NumberSequenceKeypoint.new(.5,1-opacity),NumberSequenceKeypoint.new(.5+halfWidth,1),NumberSequenceKeypoint.new(1,1)})
end
local function resolveRainbowLights(effects,speeds,strengths)
    -- Reuse the original timing/hover path and the variant's own saved tuning.
    -- Old exports could save both variants; explicit white keeps its old style.
    if effects.glint and effects.rainbowglint then effects.rainbowglint=nil end
    for base,rainbow in pairs(rainbowLightTags)do
        if effects[rainbow] then effects[base]=true;speeds[base]=speeds[rainbow];strengths[base]=strengths[rainbow] end
    end
end
local rainbowLightRedesigns={glint={tag='glint',halfWidth=.44,angle=28,duration=1.25,cycle=4.6,reverse=false,opacityScale=2/3}}
local function rainbowLightRedesign(fx)
    if fx.shiny or fx.textshimmer then return nil end
    if fx.rainbowglint then return rainbowLightRedesigns.glint end
    return nil
end
local function rainbowRedesignPhase(fx,time,hoverTime,hover)
    local d=rainbowLightRedesign(fx);if not d then return nil end
    if d.tag=='glint' and not hover then return -1 end
    local p=d.tag=='glint' and hoverTime%d.cycle or time%d.cycle
    if p<0 or p>=d.duration then return -1 end
    local phase=.5-.5*math.cos(math.pi*p/d.duration)
    return d.reverse and 1-phase or phase
end
-- END BLOXFIG RAINBOW LIGHT
local supported = {
    hoversmooth=true, smooth=true, gleam=true, shiny=true, glint=true, rainbowshiny=true, rainbowglint=true, pulse=true, spin=true,
    float=true, wiggle=true, shake=true, hoverlift=true, hovertilt=true, tilt=true, bounce=true, breath=true,
    sway=true, jelly=true, flicker=true,
    hoverzoom=true, hoverwobble=true, hoverhop=true, hoverstretch=true, hovershake=true, hovericon=true, hoverspot=true, hoverbloom=true, hoverholo=true,hoverelectric=true,hoverstars=true,hoverfoil=true,hoverglitch=true,hoverprism=true,hovercharge=true,hoverburst=true,hoverglass=true,hoveraurora=true,hovercomet=true,hovercorners=true,hoverdiamonds=true,hoverribbon=true,hoverdraw=true,hovertarget=true,hoverrunners=true,hoversplit=true,hoverlens=true,hoverripple=true,hoverfan=true,
    clicksmooth=true, clickpop=true, clicknudge=true, clicksoft=true, clicksettle=true,
    idleorbit=true, idleheartbeat=true, 
    textfloat=true, textpulse=true, textshimmer=true, rainbowtextshimmer=true,
    hovermagnet=true, clickbounce=true, idlependulum=true, idlefall=true,
}
local states = {}
local usesPointer = false
local tracked = setmetatable({}, { __mode='k' })
local inputsByTarget = {}
local tau = math.pi * 2
local openEffects = {'openzoom','opendrop','openrise','openflip','openbloom','opensettle'}
local zeroPointer = Vector2.zero
local motionTempo = 1.8
local clickCooldown = .08
-- Creator Store audio selected in Figma. Each experience still needs permission to play it.
local clickSounds = {
    keyboard={'127105730240202',1,.5},
    mouse={'139658322785649',1,.5},
    creamy={'113833803825898',1,.5},
    honey={'136892729417641',1,.5},
    pop={'88442833509532',1,.5},
    bubble={'77120543307812',1,.5},
    lightswitch={'9083627113',1,.5},
    water={'139719503904449',1,.5},
    minecraft={'535716488',1,.5},
}
local closing
local function clamp01(x) return math.clamp(x, 0, 1) end
local function easeOutCubic(x) return 1-(1-clamp01(x))^3 end
local function easeOutBack(x)
    local v = x - 1
    return 1 + 2.70158 * v * v * v + 1.70158 * v * v
end
local function visibleInGui(node)
    while node and node ~= gui do
        if node:IsA('GuiObject') and not node.Visible then return false end
        node = node.Parent
    end
    return true
end
local function heartbeatPulse(time,strength)
    local p=time%2.1
    local function g(c)local d=math.abs(p-c);return math.exp(-(math.min(d,2.1-d)/.18)^2)end
    return 1+strength*(.055*g(.24)+.035*g(.62))
end
local idleEffects = {pulse=true,spin=true,float=true,wiggle=true,shake=true,bounce=true,breath=true,sway=true,flicker=true,idleorbit=true,idleheartbeat=true,idlependulum=true,idlefall=true}
local function idleTimeline(state,now)
    if state.idleEpoch ~= state.started then
        state.idleEpoch,state.idleLast,state.idleElapsed,state.idlePaused=state.started,state.started,0,false
    end
    if not state.idlePaused then state.idleElapsed += math.max(0,now-state.idleLast) end
    state.idleLast=now
    state.idlePaused=state.hover and not state.idleOnHover
    return state.idleElapsed
end
-- BEGIN BLOXFIG NEW HOVER
local pressClickPose=(function()
-- Exact press/release spring mechanics, matching figma/press-motion.js.
local tags={}
local function spring(x,v,target,dt,omega,zeta)
 local decay=math.exp(-zeta*omega*dt);local freq=omega*math.sqrt(1-zeta*zeta);local c,s,d,k=math.cos(freq*dt),math.sin(freq*dt),x-target,zeta*omega
 return target+decay*(d*c+(v+k*d)/freq*s),decay*(v*c-(k*v+omega*omega*d)/freq*s)
end
return function(state,fx,down,now,clicked,dt,speeds,strengths,px,py,w,h)
 state.pressFx=state.pressFx or {};local out={x=0,y=0,rotation=0,scale=1,sx=1,sy=1,active=false}
 for _,tag in ipairs(tags)do if not fx[tag] then continue end;local speed,strength=speeds[tag]/1.8,strengths[tag];if speed<=0 or strength<=0 then state.pressFx[tag]=nil;continue end;out.active=true
  local slot=state.pressFx[tag];if not slot then slot={q=0,v=0,r=0,rv=0,click=-1e9,down=false,nx=0,ny=0,untilAt=-1e9};state.pressFx[tag]=slot end
  if clicked>=0 and clicked>slot.click then slot.click=clicked;slot.nx=math.clamp(px/math.max(1,w/2),-.95,.95);slot.ny=math.clamp(py/math.max(1,h/2),-.95,.95);slot.untilAt=now+.065/speed end
  local held=down or now<slot.untilAt;if slot.down and not held and tag=='clickrelease' then slot.rv+=16 end;slot.down=held
  local step=math.max(0,dt)*speed;slot.q,slot.v=spring(slot.q,slot.v,held and 1 or 0,step,held and 26 or 19,held and .9 or .55);slot.r,slot.rv=spring(slot.r,slot.rv,0,step,22,.65)
  if not held and math.abs(slot.q)<.00001 and math.abs(slot.v)<.0001 then slot.q,slot.v=0,0 end;if math.abs(slot.r)<.00001 and math.abs(slot.rv)<.0001 then slot.r,slot.rv=0,0 end
  local q=slot.q*strength;local scale,sx,sy,rotation=1,1,1,0
  if tag=='clickpressure' then scale=1-.085*q
  elseif tag=='clicksquash' then sx=1+.095*q;sy=1-.12*q
  elseif tag=='clickhinge' then rotation=(math.abs(slot.nx)>.12 and slot.nx or .35)*6*q;scale=1-.025*q
  elseif tag=='clickrelease' then scale=1-.035*q+.12*slot.r*strength end
  local a=rotation*math.pi/180;local c,s,cx,cy=math.cos(a),math.sin(a),slot.nx*w/2,slot.ny*h/2
  out.x+=cx-(c*cx*sx-s*cy*sy)*scale;out.y+=cy-(s*cx*sx+c*cy*sy)*scale
  out.scale*=scale;out.sx*=sx;out.sy*=sy;out.rotation+=rotation
 end
 return out
end

end)()
local clickMotionPose=(function()
return function(tag,age,strength)
 local pose={x=0,y=0,rotation=0,scale=1,sx=1,sy=1}
 if tag~='clicksmooth' or age<0 or age>=.54 then return pose end
 local function ease(t)return t*t*(3-2*t)end
 local amount=age<.162 and ease(age/.162) or 1-ease((age-.162)/.378)
 pose.scale=1-.05*strength*amount
 return pose
end

end)()
local newHoverPose=(function()
-- New hover effects use seconds at 1x; existing motion tempo is unchanged.
local function bump(age,duration)
    if age<0 or age>=duration then return 0 end
    return math.sin(math.pi*age/duration)^2
end
return function(tag,age,mix,strength)
    local p={x=0,y=0,sx=1,sy=1,scale=1,spot=0,bloom=0,rotation=0}
    local t=math.max(0,age);local m=mix*strength;local u=1-math.exp(-7*t)*(math.cos(11*t)+7/11*math.sin(11*t))
    if tag=='hoversmooth' then p.scale=1+.035*m
    elseif tag=='hovertilt' then p.rotation=-6*m
    elseif tag=='hoverspring' then p.y=-9*u*m;p.scale=1+.055*u*m
    elseif tag=='hoverswing' then p.rotation=13*math.exp(-2.8*t)*math.sin(t*7)*m;p.y=-4*m;p.scale=1+.035*m
    elseif tag=='hoverroll' then local v=t*1.8;p.x=5*math.sin(v)*m;p.y=-4*(1-math.cos(v))*m;p.rotation=3*math.sin(v)*m;p.scale=1+.035*m
    elseif tag=='hoverlean' then p.rotation=-5*u*m;p.x=3*u*m;p.y=-3*u*m;p.scale=1+.04*u*m
    elseif tag=='hoverdouble' then local function g(c)return math.exp(-((t-c)/.105)^2)end;p.scale=1+(.045+.09*g(.18)+.065*g(.5))*m;p.y=-3*m
    elseif tag=='hoverhop' then p.y=-8*strength*mix*bump(age,.55)
    elseif tag=='hoverstretch' then local b=bump(age,.48)*strength*mix;p.sx=1+.07*b;p.sy=1-.05*b
    elseif tag=='hovershake' then p.x=4*strength*math.sin(6*math.pi*age/.38)*bump(age,.38)*mix
    elseif tag=='hovericon' then p.scale=1+.14*strength*mix*bump(age,.5)
    elseif tag=='hoverspot' then p.spot=math.min(.7,.38*strength)*mix
    elseif tag=='hoverstamp' then local b=bump(age,.58)*strength*mix;p.scale=1-.045*b;p.y=3*b
    elseif tag=='hoverbloom' then p.bloom=math.min(.2,.1*strength)*mix end
    return p
end

end)()
local fancyHoverMix=(function()
-- Exact critically damped transition for Foil; continuous through interrupted hovers.
return function(state,tag,hover,dt,speed)
 state.fancyMix=state.fancyMix or {};local value=state.fancyMix[tag] or 0
 if tag=='hoverfoil' then
  local omega=(hover and 16 or 12)*speed;local velocity=state.foilVelocity or 0;local delta=value-(hover and 1 or 0);local term=velocity+omega*delta;local decay=math.exp(-omega*dt)
  value=(hover and 1 or 0)+(delta+term*dt)*decay;state.foilVelocity=(velocity-omega*term*dt)*decay
 else value+=((hover and 1 or 0)-value)*(1-math.exp(-dt*12*speed))end
 state.fancyMix[tag]=math.clamp(value,0,1);return state.fancyMix[tag]
end

end)()
local fancyHoverSprites=(function()
-- Geometry is in source design pixels; Foil's colour and phase are preserved.
return function(tag,t,mix,strength,px,py,w,h)
 local out,s,a={},math.min(w,h),mix*math.min(1.5,strength)
 local function add(kind,x,y,width,height,alpha,c,r,extra)
  local p={kind=kind,x=x,y=y,w=width,h=height,a=math.clamp(alpha,0,1),c=c or 0xffffff,r=r or 0};for k,v in pairs(extra or {})do p[k]=v end;out[#out+1]=p
 end
 if tag=='hoverfoil' then add('foil',w/2,h/2,w,h,.48*a,0xffffff,0,{sweep=math.clamp(px/w,-.5,.5)*.65+.12*math.sin(t*1.4),half=0})
 elseif tag=='hoverstars' then
  for j=0,1 do
   local angle=t*1.65+j*math.pi;local x,y=w/2+math.cos(angle)*(w/2+s*.08),h/2+math.sin(angle)*(h/2+s*.08);local size=s*.21
   add('dot',x,y,size*1.6,size*1.6,.2*a,j>0 and 0xffdfae or 0xbbf4ff)
   add('spark',x,y,size,size,a,0xfff7e5,12*math.sin(t*.65+j))
   for k=1,5 do local theta=angle-k*.115;local diameter=s*(.042-k*.005);add('dot',w/2+math.cos(theta)*(w/2+s*.08),h/2+math.sin(theta)*(h/2+s*.08),diameter,diameter,a*(.45-k*.065),j>0 and 0xffe6bc or 0xd2f5ff)end
  end
 elseif tag=='hoverglass' then
  local q=(t/2.8)%1;local center=q*1.4-.2+math.clamp(px/w,-.5,.5)*.12
  add('band',w/2,h/2,w,h,.48*a,0xffffff,0,{sweep=center,half=.11,angle=28})
  add('band',w/2,h/2,w,h,.17*a,0xc6edff,0,{sweep=center-.18,half=.035,angle=28})
 elseif tag=='hoveraurora' then
  local colors={0x5ff2e6,0x8b87ff,0xf593dd}
  for j=0,2 do add('band',w/2,h/2,w,h,.25*a,colors[j+1],0,{sweep=.25+j*.25+math.sin(t*.9+j*1.8)*.18,half=.22,angle=36+math.sin(t*.6+j)*12})end
 elseif tag=='hovercomet' then
  for k=12,0,-1 do local q=(t/2-k*.012)%1;local x,y=(-.12+1.24*q)*w,h*.44-math.sin(q*math.pi)*h*.72;local fade=(1-k/13)*math.sin(q*math.pi);local size=s*(k>0 and .07 or .14)
   add(k>0 and 'dot' or 'spark',x,y,size,size,a*fade,k>0 and 0x8be7ff or 0xffffff,-22)
  end
 elseif tag=='hovercorners' then
  local d=s*(.055+.1*(1-mix));local arm,line=s*.2,s*.016;local colors={0xc0efff,0xffffff,0xdacbff,0xffffff}
  for j=0,3 do local right,bottom=j%2==1,j>=2;local x,y=right and w+d or -d,bottom and h+d or -d;local dx,dy=right and -1 or 1,bottom and -1 or 1
   add('rect',x+dx*arm/2,y,arm,line,a*.85,colors[j+1]);add('rect',x,y+dy*arm/2,line,arm,a*.85,colors[j+1])
   add('rect',x+dx*arm*(.5+.35*math.sin(t*2+j)),y,arm*.18,line*1.8,a*.65,0xffffff)
  end
 elseif tag=='hoverlens' then
  local radius=math.min(s*.34,w*.24,h*.42);local cx,cy=math.clamp(w/2+px,radius,w-radius),math.clamp(h/2+py,radius,h-radius);local zoom=1+.55*math.min(1.5,strength)
  add('lens',cx,cy,radius*2,radius*2,mix,0xffffff,0,{crop={x=(cx-radius/zoom)/w,y=(cy-radius/zoom)/h,w=radius*2/zoom/w,h=radius*2/zoom/h},thickness=s*.013})
 elseif tag=='hoverripple' then
  local cx,cy=math.clamp(w/2+px,0,w),math.clamp(h/2+py,0,h)
  for j=0,2 do local q=(t-j*.18)%2.2;if q>=1.25 then continue end;local p=q/1.25;local r=s*(.05+.65*p)
   add('circle',cx,cy,r*2,r*2,a*.38*math.sin(math.pi*p)*(1-p),0x092a44,0,{thickness=s*.024,clip=1})
   add('circle',cx,cy,r*2,r*2,a*.9*math.sin(math.pi*p)*(1-p),j>0 and 0xa6dfff or 0xffffff,0,{thickness=s*.012,clip=1})
  end
 elseif tag=='hoverfan' then
  local amount=mix*math.min(1.5,strength)
  for j=0,1 do local side=j>0 and 1 or -1;add('copy',w/2+side*s*.13*amount,h/2+s*.07*amount,w,h,.62*amount,0xffffff,side*6*amount,{layer=-1})end
 elseif tag=='hoveraccordion' then
  local amount=mix*math.min(1.5,strength)
  for j=3,1,-1 do add('copy',w/2-s*.12*j*amount,h/2+s*.02*j*amount,w*(1-.025*j*amount),h*(1-.025*j*amount),.52*amount,0xffffff,-.8*j*amount,{layer=-1})end
 elseif tag=='hoverstack' then
  local amount=mix*math.min(1.5,strength)
  for j=3,1,-1 do add('copy',w/2,h/2+s*(.065*j+.012*math.sin(t*2-j))*amount,w*(1-.025*j*amount),h*(1-.025*j*amount),.5*amount,0xffffff,0,{layer=-1})end
 elseif tag=='hoverstamp' then
  local p=math.clamp(t/.58,0,1);local b=math.sin(math.pi*p)^2*mix*math.min(1.5,strength)
  add('copy',w/2,h/2,w*(1+.035*b),h*(1+.035*b),.32*b,0xffffff,0,{layer=-1})
 elseif tag=='hoverflame' then
  for side=-1,1,2 do for edge=0,1 do for j=0,2 do
   local spread=mix*(1+.025*math.sin(t*1.4+j));local height=s*(.66-j*.12);local x=side<0 and w*.13 or w*.87;local y=(edge>0 and h or 0)+(edge>0 and 1 or -1)*s*.035*spread
   add('flame',x,y,s*.19*spread,height*spread,a*(.9-j*.14),0xffffff,(edge>0 and 180 or 0)+side*(25+j*23)*spread,{layer=-1})
  end end end
 elseif tag=='hoverfrost' then
  local q=(t*.34)%1;local scan=-.15+q*1.3
  add('band',w/2,h/2,w,h,.35*a,0x70ecff,0,{sweep=scan,half=.045,angle=90})
  add('band',w/2,h/2,w,h,.55*a,0xffffff,0,{sweep=scan,half=.006,angle=90})
  for j=0,1 do local x=j>0 and w+s*.045 or -s*.045;local cy=h/2+math.sin(t*1.4)*s*.06
   add('rect',x,cy,s*.013,h*.52,a*.75,0x72ebff)
   for k=-1,1,2 do add('rect',x+(j>0 and -1 or 1)*s*.045,cy+k*h*.26,s*.09,s*.013,a*.9,0xe5ffff)end
  end
 elseif tag=='hoverseal' then
  local growth=.9+.1*mix
  add('seal',w/2,h/2,(w+s*.44)*growth,(h+s*.58)*growth,a*.9,0xffffff,2*math.sin(t*.75),{layer=-1})
  add('seal',w/2,h/2,(w+s*.64)*growth,(h+s*.76)*growth,a*.3,0xffffff,-3*math.sin(t*.6),{layer=-1})
 elseif tag=='hoverdraw' then



  local pad=s*.035;local ww,hh=w+2*pad,h+2*pad;local perimeter=2*(ww+hh);local remaining=math.min(1,t/.75)*perimeter;local line=math.max(.8,s*.018)
  for j=0,3 do local length=j%2==1 and hh or ww;local draw=math.max(0,math.min(length,remaining));remaining-=length
   local x=j==0 and (-pad+draw/2) or (j==1 and w+pad or (j==2 and w+pad-draw/2 or -pad))
   local y=j==0 and -pad or (j==1 and -pad+draw/2 or (j==2 and h+pad or h+pad-draw/2))
   add('rect',x,y,j%2==1 and line or draw,j%2==1 and draw or line,a*.8,j<2 and 0xcaf7ff or 0xdbd6ff)
  end
 elseif tag=='hovertarget' then
  local distance=s*(.065+.19*(1-mix));local arm,line=s*.16,math.max(.8,s*.015)
  for j=0,3 do local right,bottom=j%2==1,j>=2;local x,y=right and w+distance or -distance,bottom and h+distance or -distance;local dx,dy=right and -1 or 1,bottom and -1 or 1
   add('rect',x+dx*arm/2,y,arm,line,a*.85,0xb9f6ff);add('rect',x,y+dy*arm/2,line,arm,a*.85,0xb9f6ff)
   add('rect',x+dx*arm*.52,y+dy*arm*.52,arm*.48,line,a*.8,0xffffff,right==bottom and -45 or 45)
   add('rect',x+dx*arm*1.5,y,arm*.15,line,a*.45,0xffffff)
  end
 elseif tag=='hoverrunners' then
  local pad=s*.025;local ww,hh=w+2*pad,h+2*pad;local r=s*.12;local lx,ly=ww-2*r,hh-2*r;local arc=math.pi*r/2;local total=2*(lx+ly)+4*arc
  local function point(p)
   local d=(p%1)*total
   local function arcPoint(cx,cy,start)return cx+r*math.cos(start+d/r)-pad,cy+r*math.sin(start+d/r)-pad end
   if d<lx then return r+d-pad,-pad end;d-=lx;if d<arc then return arcPoint(ww-r,r,-math.pi/2)end;d-=arc
   if d<ly then return ww-pad,r+d-pad end;d-=ly;if d<arc then return arcPoint(ww-r,hh-r,0)end;d-=arc
   if d<lx then return ww-r-d-pad,hh-pad end;d-=lx;if d<arc then return arcPoint(r,hh-r,math.pi/2)end;d-=arc
   if d<ly then return -pad,hh-r-d-pad end;d-=ly;return arcPoint(r,r,math.pi)
  end
  local step=s*.78/12/total
  for j=0,1 do
   for k=11,0,-1 do local q=t*.18+j*.5-k*step;local x,y=point(q);local x2,y2=point(q-step);local head,tail=(1-k/12)^1.6,(1-(k+1)/12)^1.6;local thick=s*.021*(.25+.75*(head+tail)/2);local length=math.sqrt((x-x2)^2+(y-y2)^2)+.7;local rotation=math.atan2(y-y2,x-x2)*180/math.pi;local color=j>0 and 0xdcd9ff or 0xa2edff
    add('edgebeam',(x+x2)/2,(y+y2)/2,length,thick*3.2,a*.12,color,rotation,{tail=tail,head=head})
    add('edgebeam',(x+x2)/2,(y+y2)/2,length,thick,a*.88,color,rotation,{tail=tail,head=head})
   end
   local x,y=point(t*.18+j*.5);add('edgebeam',x,y,s*.027,s*.027,a*.95,0xffffff,0,{tail=1,head=1,rounded=1})
  end
 elseif tag=='hoversplit' then
  local p=math.min(1,(t%2.7)/1.1);local fade=math.sin(math.pi*p)
  add('band',w/2,h/2,w,h,a*.52*fade,0xffffff,0,{sweep=.5-p*.85,half=.07,angle=28})
  add('band',w/2,h/2,w,h,a*.4*fade,0xb5f2ff,0,{sweep=.5+p*.85,half=.07,angle=28})
 elseif tag=='hoverdiamonds' then
  for j=0,7 do local p=(t*.3+j/8)%1;local left=j%2==0;local x=(left and -1 or 1)*s*(.05+.07*math.sin(p*math.pi))+(left and 0 or w);local y=h*(1.1-1.2*p);local size=s*(.065+.055*math.sin(p*math.pi))
   add('diamond',x,y,size,size,a*math.sin(p*math.pi)*.8,j%3~=0 and 0xe0efff or 0xffd99b,12*math.sin(t+j))
  end
 elseif tag=='hoverribbon' then
  for j=0,1 do for k=0,17 do local theta=t*1.1+j*math.pi-k*.045;local next=theta-.045;local rx,ry=w/2+s*.07,h/2+s*.07;local x,y=w/2+math.cos(theta)*rx,h/2+math.sin(theta)*ry;local x2,y2=w/2+math.cos(next)*rx,h/2+math.sin(next)*ry
   add('rect',(x+x2)/2,(y+y2)/2,math.sqrt((x2-x)^2+(y2-y)^2)+.6,s*.018,a*(1-k/18)*.75,j>0 and 0xe3adff or 0x8eefff,math.atan2(y2-y,x2-x)*180/math.pi)
  end end
 end
 return out
end

end)()
local createFancyHover=(function()
-- Render pooled decorations without changing the target's size, position or text.
return function(visual,image,source,mask,atlas,atlasVersion,contentProvider)
 local host=Instance.new('Frame');host.Name='BloxFigFancyHover';host.BackgroundTransparency=1;host.BorderSizePixel=0;host.Size=UDim2.fromScale(1,1);host.Active=false;host.Interactable=false;host.ClipsDescendants=false;host.ZIndex=math.min(10000,visual.ZIndex+1);host.Parent=visual
 source=type(source)=='string' and source or '';mask=type(mask)=='string' and mask or source
 local pool={};local backHost,clipHost
 local groupTarget=image:GetAttribute('BloxFigContainer')==true
 local fanAsset=image:GetAttribute('BloxFigFanAssetId')
 local flatFan=type(fanAsset)=='string' and fanAsset~=''
 local fanReady=flatFan and contentProvider==nil
 local wholeButton=groupTarget and not fanReady
 if flatFan and contentProvider then
  -- Request on setup, not first hover. Native snapshots remain usable while
  -- the new texture is loading or if its fetch fails.
  task.spawn(function()
   local fetched=false
   local ok=pcall(function()contentProvider:PreloadAsync({fanAsset},function(_,status)fetched=status==Enum.AssetFetchStatus.Success end)end)
   fanReady=ok and fetched
  end)
 end
 local function buttonCopy(slot)
  -- Snapshot artwork, never another running button/effect. Sanitize while
  -- detached so DescendantAdded cannot register the copies as new targets.
  local copy=visual:Clone()
  local discard={BloxFigFancyHover=true,BloxFigFancyBack=true,BloxFigFancyClip=true,BloxFigLight=true,BloxFigGleamText=true,BloxFigGleamMask=true,BloxFigLetterShimmer=true,BloxFigHoverSpot=true,BloxFigHoverBloom=true,BloxFigGlow=true,BloxFigGlowShadow=true}
  for _,child in ipairs(copy:GetDescendants())do
   if discard[child.Name] or child:IsA('LuaSourceContainer') or child:IsA('Sound') or (child.Parent==copy and child:IsA('UIScale')) then child:Destroy() end
  end
  local nodes={copy}
  for _,child in ipairs(copy:GetDescendants())do nodes[#nodes+1]=child end
  local levels,seen,paint={},{},{}
  for _,child in ipairs(nodes)do
   for key in pairs(child:GetAttributes())do child:SetAttribute(key,nil)end
   if child:IsA('GuiObject') then
    child.Active=false;child.Interactable=false;child.Selectable=false
    if not seen[child.ZIndex] then seen[child.ZIndex]=true;levels[#levels+1]=child.ZIndex end
   end
   local function remember(property)paint[#paint+1]={node=child,property=property,alpha=child[property]}end
   if child:IsA('GuiObject')then remember('BackgroundTransparency')end
   if child:IsA('ImageLabel')or child:IsA('ImageButton')then remember('ImageTransparency')end
   if child:IsA('TextLabel')or child:IsA('TextBox')or child:IsA('TextButton')then remember('TextTransparency');remember('TextStrokeTransparency')end
   if child:IsA('UIStroke')then remember('Transparency')end
  end
  table.sort(levels)
  local ranks={};for i,z in ipairs(levels)do ranks[z]=i-1 end
  local span=tonumber(image:GetAttribute('BloxFigFanBackSpan')) or #levels
  local base=(tonumber(image:GetAttribute('BloxFigFanBackZ')) or math.max(1,visual.ZIndex-span*2))+(slot-1)*span
  for _,child in ipairs(nodes)do if child:IsA('GuiObject')then child.ZIndex=base+ranks[child.ZIndex]end end
  return copy,paint
 end
 local function extraHost(name,z,clip)
  local frame=Instance.new('Frame');frame.Name=name;frame.BackgroundTransparency=1;frame.BorderSizePixel=0;frame.Size=UDim2.fromScale(1,1);frame.Active=false;frame.Interactable=false;frame.ClipsDescendants=clip;frame.ZIndex=z;frame.Parent=visual;return frame
 end
 local function colour(c)return Color3.fromRGB(math.floor(c/65536)%256,math.floor(c/256)%256,c%256)end
 local function make(kind,slot)
  local item={kind=kind};local atlasTile=({flame=0,crystal=1,seal=2,rewardCoin=0,rewardStar=1,rewardSpark=2,glossStar=0,comicBurst=1,smokePuff=3})[kind];if kind=='glossStar' and atlasVersion~=74 then atlasTile=2 end;item.atlasTile=atlasTile;local textured=atlasTile~=nil or kind=='copy' or kind=='lens' or kind=='mask' or kind=='band' or kind=='foil'
  local node
  if kind=='copy' and wholeButton then node,item.paint=buttonCopy(slot);item.wholeButton=true;item.slot=slot else node=Instance.new(textured and 'ImageLabel' or 'Frame')end
  item.node=node;node.Name='Decoration';if not item.wholeButton then node.BackgroundTransparency=1 end;node.BorderSizePixel=0;node.Active=false;node.Interactable=false;node.AnchorPoint=Vector2.new(.5,.5);if not item.wholeButton then node.ZIndex=host.ZIndex end;node.Parent=host
  if textured and not item.wholeButton then node.Image=(kind=='copy' and flatFan) and fanAsset or atlasTile~=nil and (atlas or '') or ((kind=='copy' or kind=='lens') and source or (mask or source));node.ScaleType=Enum.ScaleType.Stretch;node.ResampleMode=Enum.ResamplerMode.Default end
  if kind=='band' or kind=='foil' then item.gradient=Instance.new('UIGradient');item.gradient.Parent=node end
  if kind=='band' then item.gradient.Color=ColorSequence.new(Color3.new(1,1,1));item.gradient.Rotation=90;item.gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.42,1),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(.58,1),NumberSequenceKeypoint.new(1,1)})end
  if kind=='foil' then item.gradient.Rotation=25;item.gradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,colour(0xff73dc)),ColorSequenceKeypoint.new(.2,colour(0xffd978)),ColorSequenceKeypoint.new(.4,colour(0x8dffca)),ColorSequenceKeypoint.new(.6,colour(0x5edcff)),ColorSequenceKeypoint.new(.8,colour(0xb091ff)),ColorSequenceKeypoint.new(1,colour(0xff73dc))})end
  if kind=='star' then item.rays={};for j=1,3 do local ray=Instance.new('Frame');ray.BorderSizePixel=0;ray.AnchorPoint=Vector2.new(.5,.5);ray.Position=UDim2.fromScale(.5,.5);ray.Size=j==1 and UDim2.fromScale(.16,1) or (j==2 and UDim2.fromScale(1,.16) or UDim2.fromScale(.32,.32));ray.Rotation=45;ray.Active=false;ray.Interactable=false;ray.ZIndex=host.ZIndex;ray.Parent=node;item.rays[j]=ray end end
  if kind=='edgebeam' then local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,0);corner.Parent=node;item.edgeCorner=corner;item.edgeGradient=Instance.new('UIGradient');item.edgeGradient.Parent=node end
  if kind=='lens' then local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(.5,0);corner.Parent=node;item.lensStroke=Instance.new('UIStroke');item.lensStroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;item.lensStroke.Color=Color3.new(1,1,1);item.lensStroke.Parent=node end
  if kind=='ring' or kind=='circle' then local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(kind=='circle' and .5 or .08,0);corner.Parent=node;item.stroke=Instance.new('UIStroke');item.stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;item.stroke.Parent=node end
  return item
 end
 return function(sprites,w,h)
  if not host.Parent then return end
  host.ZIndex=math.min(10000,visual.ZIndex+1)
  wholeButton=groupTarget and not fanReady
  local copySlot=0
  for i,p in ipairs(sprites)do
   if p.kind=='copy' then copySlot+=1 end
   local item=pool[i];if not item or item.kind~=p.kind or (p.kind=='copy' and (item.wholeButton==true)~=wholeButton) or (item.wholeButton and (item.slot~=copySlot or (p.a>.001 and not item.node.Visible))) then if item then item.node:Destroy()end;item=make(p.kind,copySlot);pool[i]=item end
   local node,c=item.node,colour(p.c);local drawZ=host.ZIndex
   if p.layer==-1 then
    if not backHost then
     backHost=extraHost('BloxFigFancyBack',math.max(1,visual.ZIndex-1),false)
     if groupTarget then
      -- A sibling escapes the button's own clip, but retains outer panel clips.
      backHost.Parent=visual.Parent
      visual.Destroying:Connect(function()backHost:Destroy()end)
      visual:GetPropertyChangedSignal('Visible'):Connect(function()backHost.Visible=visual.Visible end)
     end
    end
    if groupTarget then
     backHost.Parent=visual.Parent;backHost.Position=visual.Position;backHost.Size=visual.Size;backHost.AnchorPoint=visual.AnchorPoint;backHost.Rotation=visual.Rotation;backHost.Visible=visual.Visible
     local modifier=visual:FindFirstChildOfClass('UIScale');local scale=backHost:FindFirstChildOfClass('UIScale')
     if modifier and not scale then scale=Instance.new('UIScale');scale.Parent=backHost end
     if scale then scale.Scale=modifier and modifier.Scale or 1 end
    end
    drawZ=math.max(1,visual.ZIndex-1)
    if flatFan then drawZ=(tonumber(image:GetAttribute('BloxFigFanBackZ')) or drawZ)+(copySlot-1)*(tonumber(image:GetAttribute('BloxFigFanBackSpan')) or 0)end
    backHost.ZIndex=drawZ;node.Parent=backHost;node.Name='BloxFigBackDecoration'
   elseif p.clip==1 then if not clipHost then clipHost=extraHost('BloxFigFancyClip',host.ZIndex,true)end;clipHost.ZIndex=host.ZIndex;node.Parent=clipHost;node.Name='Decoration'
   else node.Parent=host;node.Name='Decoration' end
   node.Visible=p.a>.001;node.Position=UDim2.fromScale(p.x/w,p.y/h);node.Size=UDim2.fromScale(p.w/w,p.h/h);node.Rotation=p.r
   if item.wholeButton then
    for _,entry in ipairs(item.paint)do entry.node[entry.property]=1-(1-entry.alpha)*p.a end
    continue
   end
   node.ZIndex=drawZ
   if node:IsA('ImageLabel') then
    node.ImageTransparency=1-p.a;node.ImageColor3=c
    if item.lensStroke then item.lensStroke.Transparency=1-p.a*.65;local ancestor,scale=visual,1;while ancestor do local modifier=ancestor:FindFirstChildOfClass('UIScale');if modifier then scale*=modifier.Scale end;ancestor=ancestor.Parent end;item.lensStroke.Thickness=p.thickness*visual.AbsoluteSize.Y/h/math.max(.001,scale)end
    local crop=p.crop
    if item.atlasTile~=nil then node.ImageRectOffset=Vector2.new(item.atlasTile*256,0);node.ImageRectSize=Vector2.new(256,256) elseif crop then local pw=tonumber(image:GetAttribute('BloxFigImageWidth')) or w*2;local ph=tonumber(image:GetAttribute('BloxFigImageHeight')) or h*2;node.ImageRectOffset=Vector2.new(crop.x*pw,crop.y*ph);node.ImageRectSize=Vector2.new(crop.w*pw,crop.h*ph)else node.ImageRectOffset=Vector2.zero;node.ImageRectSize=Vector2.zero end
    if p.kind=='band' then item.gradient.Rotation=p.angle or 90;if item.half~=p.half then item.gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5-p.half,1),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(.5+p.half,1),NumberSequenceKeypoint.new(1,1)});item.half=p.half end;item.gradient.Offset=Vector2.new(0,p.sweep-.5)elseif p.kind=='foil' then item.gradient.Offset=Vector2.new(p.sweep,0)end
   elseif item.rays then for _,ray in ipairs(item.rays)do ray.BackgroundColor3=c;ray.BackgroundTransparency=1-p.a;ray.ZIndex=host.ZIndex end
   elseif item.stroke then
    item.stroke.Color=c;item.stroke.Transparency=1-p.a
    -- Stroke offsets are logical pixels; remove ancestor UIScale once.
    local ancestor,scale=visual,1;while ancestor do local modifier=ancestor:FindFirstChildOfClass('UIScale');if modifier then scale*=modifier.Scale end;ancestor=ancestor.Parent end
    item.stroke.Thickness=p.thickness*visual.AbsoluteSize.Y/h/math.max(.001,scale)
   elseif item.edgeGradient then item.edgeCorner.CornerRadius=UDim.new(p.rounded==1 and .5 or 0,0);node.BackgroundColor3=c;node.BackgroundTransparency=1-p.a;if item.edgeTail~=p.tail or item.edgeHead~=p.head then item.edgeGradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1-p.tail),NumberSequenceKeypoint.new(1,1-p.head)});item.edgeTail,item.edgeHead=p.tail,p.head end
   else node.BackgroundColor3=c;node.BackgroundTransparency=1-p.a end
  end
  for i=#sprites+1,#pool do pool[i].node.Visible=false end
 end,host
end

end)()
-- END BLOXFIG NEW HOVER
local function motionSpring(position,velocity,target,dt)
    local decay,frequency=math.exp(-8.5*dt),math.sqrt(210-8.5*8.5)
    local c,s,delta=math.cos(frequency*dt),math.sin(frequency*dt),position-target
    return target+decay*(delta*c+(velocity+8.5*delta)/frequency*s),decay*(velocity*c-(8.5*velocity+210*delta)/frequency*s)
end
local function motionOffset(state,x,y)
    local image=state.image
    local width=math.max(1,state.designWidth or tonumber(image:GetAttribute('BloxFigBoundsWidth')) or image.AbsoluteSize.X)
    local height=math.max(1,state.designHeight or tonumber(image:GetAttribute('BloxFigBoundsHeight')) or image.AbsoluteSize.Y)
    local box=state.pressFxActive and state.size or image.Size
    local parent=image.Parent
    if parent and (typeof(parent)=='Instance' or type(parent)=='table') and parent.AbsoluteSize then
        local extent=parent:IsA('ScrollingFrame') and parent.AbsoluteCanvasSize or parent.AbsoluteSize
        if state.pressFxActive and state.size then
            local ancestor,ancestorScale=parent,1
            while ancestor do local modifier=ancestor:FindFirstChildOfClass('UIScale');if modifier then ancestorScale*=modifier.Scale end;ancestor=ancestor.Parent end
            local logicalWidth,logicalHeight=extent.X/math.max(.001,ancestorScale),extent.Y/math.max(.001,ancestorScale)
            if logicalWidth>0 and logicalHeight>0 then return UDim2.fromScale((box.X.Scale+box.X.Offset/logicalWidth)*x/width,(box.Y.Scale+box.Y.Offset/logicalHeight)*y/height) end
        end
        local ownScale=state.scale and state.scale.Parent==image and state.scale.Scale or 1
        if extent.X>0 and extent.Y>0 then
            -- UDim.Offset is an integer. Express the complete animated delta in
            -- floating-point Scale, including layers originally placed in pixels.
            return UDim2.fromScale(image.AbsoluteSize.X/ownScale/extent.X*x/width,image.AbsoluteSize.Y/ownScale/extent.Y*y/height)
        end
    end
    return UDim2.new(box.X.Scale*x/width,box.X.Offset*x/width,box.Y.Scale*y/height,box.Y.Offset*y/height)
end
local function prepareStretchChildren(image)
    if image:IsA('ScrollingFrame') then return end
    if Enum.AutomaticSize and image.AutomaticSize and image.AutomaticSize~=Enum.AutomaticSize.None then return end
    for _,kind in ipairs({'UIListLayout','UIGridLayout','UITableLayout','UIPageLayout'})do if image:FindFirstChildOfClass(kind)then return end end
    local scale,node=1,image
    while node do local modifier=node:FindFirstChildOfClass('UIScale');if modifier then scale*=modifier.Scale end;node=node.Parent end
    local w,h=image.AbsoluteSize.X/math.max(.001,scale),image.AbsoluteSize.Y/math.max(.001,scale)
    if w<=0 or h<=0 then return end
    -- Only the running clone is adjusted. Even with device scaling disabled,
    -- imported offset children must stretch with the artwork during rubber
    -- hover rather than remain fixed while the button changes beneath them.
    for _,child in ipairs(image:GetChildren())do
        if child:IsA('GuiObject') and (child:GetAttribute('BloxFigImport')==true or child:GetAttribute('BloxFigContainer')==true or child:GetAttribute('BloxFigNativeText')==true)then
            prepareStretchChildren(child)
            local p,s=child.Position,child.Size
            local motion
            for _,state in ipairs(states)do if state.image==child then motion=state;p,s=state.position,state.size;break end end
            child.Position=UDim2.fromScale(p.X.Scale+p.X.Offset/w,p.Y.Scale+p.Y.Offset/h)
            child.Size=UDim2.fromScale(s.X.Scale+s.X.Offset/w,s.Y.Scale+s.Y.Offset/h)
            if motion then
                motion.position,motion.size=child.Position,child.Size
                if motion.scale then child:SetAttribute('BloxFigMotionBaseSize',child.Size)end
            end
        end
    end
end
local function motionSize(state,stretchX,stretchY)
    local base=state.size
    local parent=state.image.Parent
    if not parent then return base end
    local extent=parent:IsA('ScrollingFrame') and parent.AbsoluteCanvasSize or parent.AbsoluteSize
    if not extent or extent.X<=0 or extent.Y<=0 then return base end
    local scale,node=1,parent
    while node do local modifier=node:FindFirstChildOfClass('UIScale');if modifier then scale*=modifier.Scale end;node=node.Parent end
    local w,h=extent.X/math.max(.001,scale),extent.Y/math.max(.001,scale)
    -- Keep the pixel baseline and put the animated delta in floating Scale.
    return UDim2.new(base.X.Scale+(base.X.Scale+base.X.Offset/w)*(stretchX-1),base.X.Offset,
        base.Y.Scale+(base.Y.Scale+base.Y.Offset/h)*(stretchY-1),base.Y.Offset)
end
local function motionPointer(state,pointer)
    local image,input=state.image,state.input
    if state.hoverInput and state.hoverInput~=input then
        local node=state.hoverInput;local at,box=node.AbsolutePosition,node.AbsoluteSize
        local width=math.max(1,tonumber(image:GetAttribute('BloxFigBoundsWidth')) or image.AbsoluteSize.X)
        local height=math.max(1,tonumber(image:GetAttribute('BloxFigBoundsHeight')) or image.AbsoluteSize.Y)
        return (pointer.X-at.X-box.X/2)*width/math.max(.001,box.X),(pointer.Y-at.Y-box.Y/2)*height/math.max(.001,box.Y),width
    end
    local width=math.max(1,tonumber(image:GetAttribute('BloxFigBoundsWidth')) or image.AbsoluteSize.X)
    local height=math.max(1,tonumber(image:GetAttribute('BloxFigBoundsHeight')) or image.AbsoluteSize.Y)
    local modifier=state.scale and state.scale.Scale or 1
    local physicalWidth,physicalHeight=image.AbsoluteSize.X/modifier,image.AbsoluteSize.Y/modifier
    local centreX,centreY=input.AbsolutePosition.X+input.AbsoluteSize.X/2,input.AbsolutePosition.Y+input.AbsoluteSize.Y/2
    if input==image then
        centreX-=(state.motionX or 0)*physicalWidth/width
        centreY-=(state.motionY or 0)*physicalHeight/height
    end
    return (pointer.X-centreX)*width/math.max(.001,physicalWidth),(pointer.Y-centreY)*height/math.max(.001,physicalHeight),width
end
-- BEGIN BLOXFIG GROUP HOVER
local function groupHoverTarget(root,image,input)
    -- A group is already a complete hover target. Only its child artwork
    -- inherits a group hitbox; climbing again makes sibling buttons share
    -- the whole panel's hover region.
    if image:GetAttribute('BloxFigContainer')==true then return input end
    local parent=image.Parent
    while parent and parent~=root do
        if parent:IsA('ScrollingFrame') then break end
        if parent:IsA('GuiObject') and parent:GetAttribute('BloxFigContainer')==true then return parent end
        parent=parent.Parent
    end
    return input
end
local function groupHoverContains(root,node,pointer)
    local at,size=node.AbsolutePosition,node.AbsoluteSize
    if pointer.X<at.X or pointer.X>=at.X+size.X or pointer.Y<at.Y or pointer.Y>=at.Y+size.Y then return false end
    local parent=node.Parent
    while parent and parent~=root do
        if parent:IsA('GuiObject') then
            if not parent.Visible then return false end
            if parent.ClipsDescendants then
                local p,s=parent.AbsolutePosition,parent.AbsoluteSize
                if pointer.X<p.X or pointer.X>=p.X+s.X or pointer.Y<p.Y or pointer.Y>=p.Y+s.Y then return false end
            end
        end
        parent=parent.Parent
    end
    return true
end
-- END BLOXFIG GROUP HOVER
local function motionWakeDuration(state)
    local duration=1
    for tag,speed in pairs(state.speeds) do
        duration=math.max(duration,1.2/math.max(.001,speed/((tag:sub(1,4)=='text' or tag=='rainbowtextshimmer' or tag=='idlefall') and 1 or motionTempo)))
    end
    return duration
end
local function textMotionAmount(image,letter)
    local font=tonumber(image:GetAttribute('BloxFigTextFontSize')) or tonumber(image:GetAttribute('BloxFigResponsiveFont')) or 24
    local height=tonumber(image:GetAttribute('BloxFigTextDesignHeight')) or tonumber(image:GetAttribute('BloxFigResponsiveHeight')) or tonumber(image:GetAttribute('BloxFigBoundsHeight')) or font
    return font*(letter and .045 or .025)/math.max(1,height)
end
local function prepareTextSampling(node,resets)
    -- Use the transformed-image sampling path for slow subpixel motion. A
    -- hundredth of a degree is visually negligible (under .02px at 114px wide),
    -- but avoids relying on axis-aligned image-quad sampling during the tween.
    -- Rotations can disable ancestor clipping on older clients. Never apply
    -- this to artwork within a clipping hierarchy, and never rotate its layout.
    local ancestor=node
    while ancestor do
        if ancestor:IsA('GuiObject') and ancestor.ClipsDescendants then return false end
        ancestor=ancestor.Parent
    end
    local rotation=node.Rotation
    if rotation%90==0 then
        node.Rotation=rotation+.01
        resets[#resets+1]=function()node.Rotation=rotation end
    end
    node.ResampleMode=Enum.ResamplerMode.Default
    return true
end
local function startEngineTextMotion(state)
    local tag=state.engineTextTag
    if not tag or state.engineMotion then return end
    state.engineMotion=tag
    local tweens,connections,resets={},{},{}
    local active=true
    state.stopEngineMotion=function()
        active=false
        for _,connection in ipairs(connections)do connection:Disconnect()end
        for _,animation in ipairs(tweens)do animation:Cancel()end
        for _,reset in ipairs(resets)do reset()end
        state.engineMotion=nil
        state.stopEngineMotion=nil
    end
    local visual=state.visual
    if tag=='textjelly' then
        for _,part in ipairs(state.waveSlices)do prepareTextSampling(part.visual,resets)end
    else
        prepareTextSampling(visual,resets)
    end
    local speed,strength=state.speeds[tag],state.strengths[tag]
    local clock=Instance.new('NumberValue')
    clock.Name='BloxFigTextPhase'
    local period=tag=='textfloat' and 3.2 or (tag=='textpulse' and 3.6 or tau/2.4)
    local basePosition,baseSize=visual.Position,visual.Size
    resets[#resets+1]=function()visual.Position=basePosition;visual.Size=baseSize;clock:Destroy()end
    if state.scale then state.scale.Scale=1 end
    if tag=='textjelly' then
        for _,part in ipairs(state.waveSlices)do
            local base=UDim2.fromScale(part.x,part.y or 0)
            resets[#resets+1]=function()part.image.Position=base end
        end
    end
    local function pose(phase)
        if not active then return end
        local angle=phase*tau
        if tag=='textfloat' then
            visual.Position=basePosition+UDim2.fromScale(0,-textMotionAmount(state.image,false)*strength*(1-math.cos(angle)))
        elseif tag=='textpulse' then
            local factor=1-.015*strength*math.cos(angle)
            visual.Size=UDim2.fromScale(factor,factor)
        else
            local amplitude=textMotionAmount(state.image,true)*strength
            for _,part in ipairs(state.waveSlices)do
                part.image.Position=UDim2.fromScale(part.x,(part.y or 0)+math.sin(angle-part.phase)*amplitude)
            end
        end
    end
    -- One linear phase for the complete word. The preview uses these same
    -- sine/cosine equations; no approximate startup segments or per-letter clocks.
    connections[#connections+1]=clock.Changed:Connect(pose)
    pose(0)
    local animation=TweenService:Create(clock,TweenInfo.new(period/speed,Enum.EasingStyle.Linear,Enum.EasingDirection.InOut,-1,false),{Value=1})
    tweens[#tweens+1]=animation
    animation:Play()
    if state.image.Destroying then connections[#connections+1]=state.image.Destroying:Connect(function()if state.stopEngineMotion then state.stopEngineMotion()end end)end
end
local function completeTextGlyphs(image,visual)
    local encoded=image:GetAttribute('BloxFigTextGlyphs');if type(encoded)~='string' then return nil end
    local ok,data=pcall(function()return HttpService:JSONDecode(encoded)end);if not ok or type(data)~='table' or type(data.glyphs)~='table' then return nil end
    local width,height=tonumber(image:GetAttribute('BloxFigImageWidth')),tonumber(image:GetAttribute('BloxFigImageHeight'));if not width or not height then return nil end
    local old=visual:FindFirstChild('BloxFigTextWave');if old then old:Destroy()end
    local wave=Instance.new('Frame');wave.Name='BloxFigTextWave';wave.Size=UDim2.fromScale(1,1);wave.BackgroundTransparency=1;wave.BorderSizePixel=0;wave.ClipsDescendants=false;wave.Active=false;wave.ZIndex=visual.ZIndex;wave.Parent=visual
    local parts={}
    local counts,ranks={},{}
    for _,glyph in ipairs(data.glyphs)do local line=glyph.line or 0;counts[line]=(counts[line] or 0)+1 end
    local tracking=(tonumber(data.fontSize) or tonumber(image:GetAttribute('BloxFigTextFontSize')) or 24)*.02
    for i,glyph in ipairs(data.glyphs)do
        local b,r=glyph.bounds,glyph.atlas
        local line=glyph.line or 0;local rank=ranks[line] or 0;ranks[line]=rank+1
        local glyphX=b.x+tracking*(rank-(counts[line]-1)/2)
        -- Crop the source texture, rather than scrolling a large atlas behind
        -- a pixel-snapped clipping Frame on every letter and every frame.
        local ink=Instance.new('ImageLabel');ink.Name='Letter '..i;ink.BackgroundTransparency=1;ink.BorderSizePixel=0;ink.Active=false;ink.Image=visual.Image;ink.ImageColor3=visual.ImageColor3;ink.ImageTransparency=0;ink.ResampleMode=Enum.ResamplerMode.Default;ink.Size=UDim2.fromScale(b.width/data.width,b.height/data.height);ink.Position=UDim2.fromScale(glyphX/data.width,b.y/data.height);ink.ImageRectOffset=Vector2.new(r.x,r.y);ink.ImageRectSize=Vector2.new(r.width,r.height);ink.ZIndex=visual.ZIndex;ink.Parent=wave
        parts[i]={image=ink,visual=ink,x=glyphX/data.width,y=b.y/data.height,phase=(i-1)*.5,lastOffset=0,lastTransparency=0}
    end
    return #parts>0 and parts or nil
end
local function textWaveSlices(image,visual)
    local complete=completeTextGlyphs(image,visual);if complete then return complete end
    local encoded = image:GetAttribute('BloxFigTextSlices')
    local width = tonumber(image:GetAttribute('BloxFigImageWidth'))
    local height = tonumber(image:GetAttribute('BloxFigImageHeight'))
    if type(encoded) ~= 'string' or not width or not height or width < 1 or height < 1 then return nil end
    local ok, slices = pcall(function() return HttpService:JSONDecode(encoded) end)
    if not ok or type(slices) ~= 'table' or #slices < 1 or #slices > 32 then return nil end
    -- Old exports used guessed cuts. Never revive those seams.
    slices = {{0,width}}
    local old = visual:FindFirstChild('BloxFigTextWave')
    if old then old:Destroy() end
    local wave = Instance.new('Frame')
    wave.Name = 'BloxFigTextWave'
    wave.BackgroundTransparency = 1
    wave.BorderSizePixel = 0
    wave.Size = UDim2.fromScale(1,1)
    wave.ClipsDescendants = false
    wave.Active = false
    wave.ZIndex = visual.ZIndex
    wave.Parent = visual
    local parts = {}
    for index,rect in ipairs(slices) do
        local x,w = tonumber(rect[1]),tonumber(rect[2])
        if not x or not w or x < 0 or w < 1 or x+w > width then wave:Destroy();return nil end
        local part = Instance.new('Frame')
        part.Name = 'Letter '..index
        part.BackgroundTransparency = 1
        part.BorderSizePixel = 0
        part.Active = false
        part.ClipsDescendants = true
        part.Size = UDim2.new(w/width,0,1,0)
        part.Position = UDim2.new(x/width,0,0,0)
        part.ZIndex = visual.ZIndex
        part.Parent = wave
        local glyph = Instance.new('ImageLabel')
        glyph.BackgroundTransparency = 1
        glyph.BorderSizePixel = 0
        glyph.Size = UDim2.fromScale(width/w,1)
        glyph.Position = UDim2.fromScale(-x/w,0)
        glyph.Image = visual.Image
        glyph.ImageColor3 = visual.ImageColor3
        glyph.ImageTransparency = 0
        glyph.ResampleMode = Enum.ResamplerMode.Default
        glyph.ZIndex = visual.ZIndex
        glyph.Active = false
        glyph.Parent = part
        parts[index] = {image=part,visual=glyph,x=x/width,phase=(index-1)*.5,lastOffset=0,lastTransparency=0}
    end
    return parts
end
local function startClose(state)
    if closing or not gui.Enabled then return end
    local effects = state.effects
    local tag = effects.closezoom and 'closezoom' or (effects.closeleft and 'closeleft' or (effects.closeshrink and 'closeshrink' or (effects.closeslide and 'closeslide' or (effects.closefade and 'closefade' or nil))))
    if not tag then return end
    local roots, visuals = {}, {}
    for _, child in gui:GetChildren() do
        if child:IsA('GuiObject') and (child:GetAttribute('BloxFigImport') == true or child:GetAttribute('BloxFigContainer') == true) then
            local scale = child:FindFirstChildOfClass('UIScale')
            if not scale then
                scale = Instance.new('UIScale')
                scale.Name = 'BloxFigCloseScale'
                scale.Parent = child
            end
            roots[#roots+1] = {node=child, position=child.Position, size=child.Size, anchor=child.AnchorPoint, scale=scale, scaleValue=scale.Scale, designWidth=gui:GetAttribute('ReferenceWidth') or child.AbsoluteSize.X,designHeight=gui:GetAttribute('ReferenceHeight') or child.AbsoluteSize.Y,image=child}
            local function capture(node)
                if node:IsA('ImageLabel') or node:IsA('ImageButton') then
                    visuals[#visuals+1] = {node=node, transparency=node.ImageTransparency, property='ImageTransparency'}
                elseif node:IsA('UIStroke') then
                    visuals[#visuals+1] = {node=node, transparency=node.Transparency, property='Transparency'}
                elseif node:IsA('TextLabel') or node:IsA('TextBox') then
                    visuals[#visuals+1] = {node=node, transparency=node.TextTransparency, property='TextTransparency'}
                end
            end
            capture(child)
            for _, descendant in child:GetDescendants() do capture(descendant) end
        end
    end
    closing = {tag=tag, started=os.clock(), duration=.38/math.max(.01,state.speeds[tag] or motionTempo), strength=state.strengths[tag] or 1, roots=roots, visuals=visuals}
end
local function renderClose(now)
    local exit = closing
    if not exit then return false end
    local progress = clamp01((now-exit.started)/exit.duration)
    local eased = 1-(1-progress)^3
    for _, entry in exit.roots do
        local node = entry.node
        if node.Parent then
            if exit.tag == 'closeleft' then
                node.Position = entry.position + motionOffset(entry,-32*eased*exit.strength,0)
            elseif exit.tag == 'closeslide' then
                node.Position = entry.position + motionOffset(entry,0,42*eased*exit.strength)
            elseif exit.tag == 'closeshrink' or exit.tag == 'closezoom' then
                local factor = exit.tag == 'closezoom' and (1+.08*eased*exit.strength) or (1-.25*eased*exit.strength)
                local size = entry.size
                entry.scale.Scale = entry.scaleValue * factor
                local ax, ay = .5-entry.anchor.X, .5-entry.anchor.Y
                node.Position = entry.position + UDim2.new(size.X.Scale*(1-factor)*ax,size.X.Offset*(1-factor)*ax,size.Y.Scale*(1-factor)*ay,size.Y.Offset*(1-factor)*ay)
            end
        end
    end
    for _, entry in exit.visuals do
        if entry.node.Parent then entry.node[entry.property] = entry.transparency + (1-entry.transparency)*eased end
    end
    if progress >= 1 then
        for _, entry in exit.roots do
            if entry.node.Parent then entry.node.Position = entry.position; entry.node.Size = entry.size; entry.scale.Scale = entry.scaleValue end
        end
        for _, entry in exit.visuals do
            if entry.node.Parent then entry.node[entry.property] = entry.transparency end
        end
        closing = nil
        gui.Enabled = false
    end
    return true
end
local function sourceTypographyMatches(image)
    local key, color = image:GetAttribute('BloxFigSourceFontKey'), image:GetAttribute('BloxFigSourceColor')
    if key then
        local font=image.FontFace
        if font.Family..':'..tostring(font.Weight)..':'..tostring(font.Style)~=key then return false end
    end
    return color==nil or image.TextColor3==color
end
local function createIdleFall(image,config)
    local old=image:FindFirstChild('BloxFigFall');if old then old:Destroy()end
    local host=Instance.new('Frame');host.Name='BloxFigFall';host.BackgroundTransparency=1;host.BorderSizePixel=0;host.Size=UDim2.fromScale(1,1);host.Active=false;host.Interactable=false;host.ClipsDescendants=true;host.ZIndex=image.ZIndex;host.Parent=image
    local corner=image:FindFirstChildOfClass('UICorner');if corner then corner:Clone().Parent=host end
    local floor=image.ZIndex;local floorTarget;for _,child in ipairs(image:GetChildren())do if child:IsA('GuiObject') then local id=child:GetAttribute('FigmaNodeId');if child:GetAttribute('BloxFigFallFloor')==true or (type(id)=='string' and (id:match(':backdrop$') or id:match(':background$'))) then if child.ZIndex>=floor then floor=child.ZIndex;floorTarget=child end end end end;host.ZIndex=floor
    local pool={}
    local function rawSeed(i)local n=math.sin(i*127.1+311.7)*43758.5453;return n-math.floor(n)end
    local randomness=math.clamp(config.randomness or 1,0,1);local sizeScale=math.clamp(config.size or 1,.25,2)
    local function seed(i)return .5+(rawSeed(i)-.5)*randomness end
    local sources=config.sources or {};task.spawn(function()local assets={};for _,source in ipairs(sources)do if source.assetId then assets[#assets+1]=source.assetId end end;pcall(function()ContentProvider:PreloadAsync(assets)end)end);local count=math.clamp(math.floor(config.count or 12),1,40)
    for i=1,(#sources>0 and count or 0)do
        local source=sources[(i-1)%#sources+1];local ink=Instance.new('ImageLabel');ink.Name='Fall picture';ink.BackgroundTransparency=1;ink.BorderSizePixel=0;ink.AnchorPoint=Vector2.new(.5,.5);ink.Active=false;ink.Interactable=false;ink.Image=source.assetId or '';ink.ScaleType=Enum.ScaleType.Stretch;ink.ZIndex=host.ZIndex;ink.Parent=host;pool[i]=ink
    end
    local function update(time,strength)
        if not host.Parent then return end
        local outerW=math.max(1,image.AbsoluteSize.X);local outerH=math.max(1,image.AbsoluteSize.Y);local areaW=floorTarget and floorTarget.AbsoluteSize.X or outerW;local areaH=floorTarget and floorTarget.AbsoluteSize.Y or outerH;local inset=math.min(areaW,areaH)*.08
        local offsetX=floorTarget and floorTarget.AbsolutePosition.X-image.AbsolutePosition.X or 0;local offsetY=floorTarget and floorTarget.AbsolutePosition.Y-image.AbsolutePosition.Y or 0
        local width=math.max(1,areaW-2*inset);local height=math.max(1,areaH-2*inset);host.Position=UDim2.fromScale((offsetX+inset)/outerW,(offsetY+inset)/outerH);host.Size=UDim2.fromScale(width/outerW,height/outerH);local extent=math.min(width,height)
        local seconds=math.clamp(config.seconds or 6,1,30);local minimum=math.clamp(config.min or .09,.02,.8);local maximum=math.max(minimum,math.clamp(config.max or .15,.02,.8))
        for index,ink in ipairs(pool)do
            local i=index-1;local period=seconds*1.8
            local progress=time/period+(i+.5+(rawSeed(i+31)-.5)*.5*randomness)/count;local cycle=math.floor(progress);local p=progress-cycle
            local function random(salt)return rawSeed(i*97+cycle*1009+salt)end
            local source=sources[math.floor(random(19)*#sources)%#sources+1];if ink.Image~=source.assetId then ink.Image=source.assetId end
            local sizeSeed=.5+(random(11)-.5)*randomness;local size=sizeScale*extent*(minimum+(maximum-minimum)*sizeSeed)*(1+(random(71)*2-1)*.35*randomness);local ratio=source.width/math.max(1,source.height)
            local w=ratio>=1 and size or size*ratio;local h=ratio>=1 and size/ratio or size
            local columns=math.min(count,math.max(1,math.floor(math.sqrt(count*width/math.max(1,height))+.5)));local start=((i%columns)+.5+(random(7)-.5)*.8*randomness)/columns
            local x=width*start
            local rotation=(rawSeed(i*97+53)*2-1)*(config.tilt or 18)*randomness
            ink.Size=UDim2.fromScale(w/width,h/height);ink.Position=UDim2.fromScale(x/width,-.4+1.8*p);ink.Rotation=rotation
            ink.ImageTransparency=1-math.clamp((1-(config.fade or .75))*strength*math.min(1,p/.12,(1-p)/.18),0,1)
        end
    end
    image.Destroying:Connect(function()host:Destroy()end)
    script.Destroying:Connect(function()host:Destroy()end)
    return update
end

local function setup(image)
    if not (image:IsA('ImageLabel') or image:IsA('ImageButton') or image:IsA('ScrollingFrame') or image:IsA('TextLabel') or image:IsA('TextBox')
        or (image:IsA('Frame') and image:GetAttribute('BloxFigTextFrame') == true)
        or (image:IsA('Frame') and image:GetAttribute('BloxFigContainer') == true)) then return end
    if tracked[image] then return end
    if image:GetAttribute('BloxFigImport') ~= true or image:GetAttribute('BloxFigMissing') == true then return end
    -- Retired outline effects may have left generated decorations in old UIs.
    for _, child in ipairs(image:GetDescendants()) do
        if child.Name == 'BloxFigGlow' or child.Name == 'BloxFigGlowShadow' or child.Name == 'BloxFigFancyHover' or child.Name == 'BloxFigFancyBack' or child.Name == 'BloxFigFancyClip' then child:Destroy() end
    end
    -- Static and animated source labels must use the same glyph pixels.
    -- Otherwise enabling an effect changes typography before any motion starts.
    local hasSourceArtwork = image:IsA('TextLabel') and image:GetAttribute('BloxFigNativeText')~=true and sourceTypographyMatches(image) and image:GetAttribute('BloxFigTextGlyphs') == nil
        and type(image:GetAttribute('BloxFigImageAssetId')) == 'string'
        and (image:GetAttribute('BloxFigSourceText') == nil or image:GetAttribute('BloxFigSourceText') == image.Text)
    local names = image:GetAttribute('BloxFigEffects')
    local soundPreset = image:GetAttribute('BloxFigClickSound')
    if (type(names) ~= 'string' or names == '') and type(soundPreset) ~= 'string' and not hasSourceArtwork then return end
    local effects = {}
    for name in (type(names) == 'string' and names or ''):gmatch('[^,]+') do if supported[name] and name~='gleam' then effects[name] = true end end
    local savedTuning = {}
    local encodedTuning = image:GetAttribute('BloxFigEffectTuning')
    if type(encodedTuning) == 'string' then
        local ok, decoded = pcall(function() return HttpService:JSONDecode(encodedTuning) end)
        if ok and type(decoded) == 'table' then savedTuning = decoded end
    end
    local defaultSpeed = math.clamp(tonumber(image:GetAttribute('BloxFigEffectSpeed')) or 1, 0, 2)
    local defaultStrength = math.clamp(tonumber(image:GetAttribute('BloxFigEffectStrength')) or 1, 0, 1.5)
    local speeds, strengths = {}, {}
    for tag in effects do
        local tuning = type(savedTuning[tag]) == 'table' and savedTuning[tag] or nil
        speeds[tag] = math.clamp(tonumber(tuning and tuning.speed) or defaultSpeed, 0, 2)*((tag:sub(1,4) == 'text' or tag=='rainbowtextshimmer' or tag=='idlefall') and 1 or motionTempo)
        strengths[tag] = math.clamp(tonumber(tuning and tuning.strength) or defaultStrength, 0, 1.5)
        if speeds[tag] == 0 or strengths[tag] == 0 then effects[tag] = nil end
    end
    resolveRainbowLights(effects,speeds,strengths)
    if not next(effects) and type(soundPreset) ~= 'string' and not hasSourceArtwork then return end
    local hasIdleEffects=false
    for tag in pairs(effects) do if idleEffects[tag] then hasIdleEffects=true;break end end
    local visualMotion = next(effects) ~= nil
    local visual = image:IsA('ScrollingFrame') and image:FindFirstChild('BloxFigArtwork') or image
    if not visual or not (visual:IsA('ImageLabel') or visual:IsA('ImageButton') or visual:IsA('TextLabel') or visual:IsA('TextBox')
        or (visual:IsA('Frame') and image:GetAttribute('BloxFigTextFrame') == true)
        or (visual:IsA('Frame') and image:GetAttribute('BloxFigContainer') == true)) then return end
    tracked[image] = true
    local nativeText = (image:IsA('TextLabel') or image:IsA('TextBox')) and image or image:FindFirstChild('BloxFigText')
    if nativeText and not (nativeText:IsA('TextLabel') or nativeText:IsA('TextBox')) then nativeText = nil end
    local rasterAssetId = image:GetAttribute('BloxFigImageAssetId')
    local rasterVisual = visual
    -- Legacy Letter Wave assets contain a glyph atlas, not a whole text image.
    -- Keep those labels native when another supported effect remains.
    local sourceRaster=image:GetAttribute('BloxFigNativeText')~=true and image:GetAttribute('BloxFigTextGlyphs')==nil and visual:IsA('TextLabel') and sourceTypographyMatches(image) and type(rasterAssetId)=='string' and (image:GetAttribute('BloxFigSourceText')==nil or image:GetAttribute('BloxFigSourceText')==visual.Text)
    local nativeAlpha=nativeText and (tonumber(nativeText:GetAttribute('BloxFigNativeTextTransparency')) or nativeText.TextTransparency) or 0
    if sourceRaster then nativeText:SetAttribute('BloxFigNativeTextTransparency',nativeAlpha) end
    if (sourceRaster or ((visual:IsA('Frame') or visual:IsA('TextLabel') or visual:IsA('TextBox')) and effects.textjelly and type(rasterAssetId) == 'string')) then
        rasterVisual = visual:FindFirstChild('BloxFigTextRaster')
        if not rasterVisual or not rasterVisual:IsA('ImageLabel') then
            if rasterVisual then rasterVisual:Destroy() end
            rasterVisual = Instance.new('ImageLabel')
            rasterVisual.Name = 'BloxFigTextRaster'
            rasterVisual.Parent = visual
        end
        rasterVisual.BackgroundTransparency = 1
        rasterVisual.BorderSizePixel = 0
        rasterVisual.Size = UDim2.fromScale(1,1)
        rasterVisual.Position = UDim2.fromScale(0,0)
        rasterVisual.Image = rasterAssetId
        rasterVisual.ImageTransparency = 0
        rasterVisual.ResampleMode = Enum.ResamplerMode.Default
        rasterVisual.Active = false
        rasterVisual.Interactable = false
        rasterVisual.ZIndex = visual.ZIndex
    end
    if sourceRaster then
        for _,name in ipairs({'BloxFigGleamText','BloxFigGleamMask'})do local old=image:FindFirstChild(name);if old then old:Destroy() end end
        visual=rasterVisual
    end
    local waveSlices = effects.textjelly and rasterVisual:IsA('ImageLabel') and textWaveSlices(image,rasterVisual) or nil
    if rasterVisual ~= visual then rasterVisual.ImageTransparency = 1 end
    local pressClick = effects.clickpressure or effects.clicksquash or effects.clickhinge or effects.clickrelease
    local artworkClick = effects.clicksmooth or effects.clickrubber or effects.clickrock or effects.clickhop or effects.clickrecoil or effects.clickdouble or effects.clickpinch
    local artworkHover = effects.hoverspring or effects.hoverswing or effects.hoverroll or effects.hoverlean or effects.hoverdouble
    if effects.hoverstretch or effects.clicksquash or effects.clickrubber or effects.clickpinch then prepareStretchChildren(image)end
    local originalAnchor = image.AnchorPoint
    local originalPosition = image.Position
    if pressClick or artworkClick or artworkHover or effects.hoverstamp or effects.hovericon or effects.hoverstretch or effects.hoversmooth or effects.smooth or effects.pulse or effects.pop or effects.breath or effects.jelly or effects.hoverzoom or effects.clickpop or effects.idleheartbeat or effects.textpulse or effects.clickbounce or effects.clicksoft or effects.clicksettle or effects.openzoom or effects.openflip or effects.openbloom or effects.opensettle then
        image.AnchorPoint = Vector2.new(.5, .5)
        image.Position = originalPosition + UDim2.new(
            (.5 - originalAnchor.X) * image.Size.X.Scale, (.5 - originalAnchor.X) * image.Size.X.Offset,
            (.5 - originalAnchor.Y) * image.Size.Y.Scale, (.5 - originalAnchor.Y) * image.Size.Y.Offset
        )
    end
    local scale = image:FindFirstChild('BloxFigScale')
    if (pressClick or artworkClick or artworkHover or effects.hoverstamp or effects.hovericon or effects.hoverstretch or effects.hoversmooth or effects.smooth or effects.pulse or effects.pop or effects.breath or effects.jelly or effects.hoverzoom or effects.clickpop or effects.idleheartbeat or effects.textpulse or effects.clickbounce or effects.clicksoft or effects.clicksettle or effects.openzoom or effects.openflip or effects.openbloom or effects.opensettle) and not scale then
        scale = Instance.new('UIScale')
        scale.Name = 'BloxFigScale'
        scale.Parent = image
    end
    local rasterPulse=sourceRaster and effects.textpulse and not (pressClick or artworkClick or artworkHover or effects.hoverstamp or effects.hovericon or effects.hoverstretch or effects.hoversmooth or effects.smooth or effects.pulse or effects.pop or effects.breath or effects.jelly or effects.hoverzoom or effects.clickpop or effects.idleheartbeat or effects.clickbounce or effects.clicksoft or effects.clicksettle or effects.openzoom or effects.openflip or effects.openbloom or effects.opensettle)
    if rasterPulse then
        -- Keep the text/layout box fixed. Scale the bitmap around its own centre
        -- so native font/layout invalidation cannot fight the pulse each frame.
        rasterVisual.AnchorPoint=Vector2.new(.5,.5)
        rasterVisual.Position=UDim2.fromScale(.5,.5)
        scale.Parent=rasterVisual
    end
    local lightAssetId = image:GetAttribute('BloxFigLightAssetId')
    if effects.textjelly and type(lightAssetId) == 'string' then
        -- The stationary atlas mask is deliberately hidden. Request its texture
        -- explicitly so per-letter shimmer does not depend on visibility loading.
        task.spawn(function() pcall(function() ContentProvider:PreloadAsync({lightAssetId}) end) end)
    end
    local textMask = (visual:IsA('TextLabel') or visual:IsA('TextBox')) and not effects.textjelly
    if type(lightAssetId) == 'string' and not textMask then
        local oldTextMask = visual:FindFirstChild('BloxFigGleamText')
        if oldTextMask then oldTextMask:Destroy() end
    end
    local mask = visual:FindFirstChild(textMask and 'BloxFigGleamText' or 'BloxFigGleamMask')
    if mask and not mask:IsA(textMask and 'TextLabel' or 'ImageLabel') then mask:Destroy(); mask = nil end
    local gradient = mask and mask:FindFirstChild('BloxFigGleam')
    local rasterSource = lightAssetId or rasterAssetId
    if not lightAssetId and (visual:IsA('ImageLabel') or visual:IsA('ImageButton')) then rasterSource = visual.Image end
    local hasLight = effects.gleam or effects.shiny or effects.glint or effects.textshimmer
    if not mask and hasLight and (textMask or type(rasterSource) == 'string') then
        mask = Instance.new(textMask and 'TextLabel' or 'ImageLabel')
        mask.Name = textMask and 'BloxFigGleamText' or 'BloxFigGleamMask'
        mask.BackgroundTransparency = 1
        mask.Size = UDim2.fromScale(1,1)
        if not textMask then
            mask.Image = rasterSource
            mask.ImageColor3 = Color3.new(1,1,1)
        end
        mask.ZIndex = math.min(10000, visual.ZIndex + 1)
        mask.Active = false
        mask.Interactable = false
        mask.Selectable = false
        mask.Visible = false
        mask.Parent = visual
    end
    if mask and textMask then
        local oldOutline=mask:FindFirstChild('BloxFigGleamOutline');if oldOutline then oldOutline:Destroy() end
        local function syncTextMask()
            mask.Text = visual.Text
            mask.TextSize = visual.TextSize
            mask.FontFace = visual.FontFace
            mask.TextXAlignment = visual.TextXAlignment
            mask.TextYAlignment = visual.TextYAlignment
            mask.TextWrapped = visual.TextWrapped
            mask.TextScaled = visual.TextScaled
            mask.TextTruncate = visual.TextTruncate
            mask.LineHeight = visual.LineHeight
            mask.RichText = visual.RichText
            mask.TextColor3 = Color3.new(1,1,1)
            mask.TextTransparency = visual.TextTransparency
            mask.TextStrokeTransparency = 1
        end
        local sourcePadding=visual:FindFirstChild('BloxFigTextPadding')
        if sourcePadding and sourcePadding:IsA('UIPadding')then
            local padding=mask:FindFirstChild('BloxFigTextPadding')
            if not padding then padding=Instance.new('UIPadding');padding.Name='BloxFigTextPadding';padding.Parent=mask end
            local function syncPadding()
                for _,property in ipairs({'PaddingLeft','PaddingRight','PaddingTop','PaddingBottom'})do padding[property]=sourcePadding[property]end
            end
            syncPadding()
            for _,property in ipairs({'PaddingLeft','PaddingRight','PaddingTop','PaddingBottom'})do sourcePadding:GetPropertyChangedSignal(property):Connect(syncPadding)end
        end
        syncTextMask()
        for _, property in ipairs({'Text','TextSize','FontFace','TextXAlignment','TextYAlignment','TextWrapped','TextScaled','TextTruncate','LineHeight','RichText'}) do
            visual:GetPropertyChangedSignal(property):Connect(syncTextMask)
        end
        visual:GetPropertyChangedSignal('TextTransparency'):Connect(function()
            mask.TextTransparency = visual.TextTransparency
        end)
    end
    if mask and not textMask and hasLight then
        task.spawn(function() pcall(function() ContentProvider:PreloadAsync({rasterSource}) end) end)
    end
    if mask then
        mask.ZIndex = math.min(10000, visual.ZIndex + 1)
        if not textMask then mask.Image=rasterSource;mask.ImageColor3=Color3.new(1,1,1);mask.ImageTransparency=0 end
    end
    if mask and (effects.gleam or effects.shiny or effects.glint or effects.textshimmer) and not gradient then
        gradient = Instance.new('UIGradient')
        gradient.Name = 'BloxFigGleam'
        -- Figma's 300%-wide gradient makes the visible band three times
        -- wider than its percentage stops within the gradient image.
        local halfWidth = effects.textshimmer and .27 or (effects.shiny and .48 or (effects.glint and .18 or .27))
        gradient.Color = ColorSequence.new(Color3.new(1, 1, 1))
        gradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(.5-halfWidth, 1),
            NumberSequenceKeypoint.new(.5, effects.textshimmer and (1-math.min(.94,.67*(strengths.textshimmer or 1))) or .16),
            NumberSequenceKeypoint.new(.5+halfWidth, 1),
            NumberSequenceKeypoint.new(1, 1),
        })
        gradient.Rotation = (effects.textshimmer or effects.textjelly) and 0 or 20
        gradient.Parent = mask
    end
    local oldFallback = visual:FindFirstChild('BloxFigLightFallback')
    if oldFallback then oldFallback:Destroy() end
    local shadow = visual:FindFirstChild('BloxFigGlowShadow')
    if shadow and shadow.ClassName ~= 'UIShadow' then shadow = nil end
    if (effects.glow or effects.hoverglow) and not shadow then
        local ok, created = pcall(function()
            local effect = Instance.new('UIShadow')
            effect.Name = 'BloxFigGlowShadow'
            effect.Color = Color3.fromRGB(102, 201, 255)
            effect.Offset = UDim2.fromOffset(0, 0)
            effect.BlurRadius = UDim.new(0, 8)
            effect.Transparency = .15
            effect.Enabled = false
            effect.Parent = visual
            return effect
        end)
        if ok then
            shadow = created
        end
    end
    local stroke = image:FindFirstChild('BloxFigGlow')
    if (effects.glow or effects.hoverglow) and not shadow and not stroke then
        stroke = Instance.new('UIStroke')
        stroke.Name = 'BloxFigGlow'
        stroke.Color = Color3.fromRGB(83, 196, 255)
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = image
    end
    if gradient then
        local lightTag = effects.textshimmer and 'textshimmer' or (effects.shiny and 'shiny' or (effects.gleam and 'gleam' or 'glint'))
        local opacity = math.min(.94,(lightTag=='textshimmer' and .67 or (lightTag=='shiny' and .6 or (lightTag=='glint' and (effects.rainbowglint and .9 or .67) or .8))) * (strengths[lightTag] or 1))
        local halfWidth = effects.textshimmer and .27 or (effects.shiny and .48 or (effects.glint and .18 or .27))
        local redesign=rainbowLightRedesign(effects)
        if redesign then halfWidth=redesign.halfWidth;opacity=math.min(.94,(lightTag=='glint' and .9 or .8)*(strengths[lightTag] or 1)*redesign.opacityScale) end
        local rainbow=effects[rainbowLightTags[lightTag]]
        gradient.Color=effects[rainbowLightTags[lightTag]] and rainbowLightSequence(halfWidth) or ColorSequence.new(Color3.new(1,1,1))
        gradient.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(.5-halfWidth, 1),
            NumberSequenceKeypoint.new(.5, 1-opacity),
            NumberSequenceKeypoint.new(.5+halfWidth, 1),
            NumberSequenceKeypoint.new(1, 1),
        })
        if lightTag=='glint' and not rainbow then
            halfWidth=.27
            gradient.Transparency=NumberSequence.new({
                NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5-halfWidth,1),
                NumberSequenceKeypoint.new(.5,1-opacity),NumberSequenceKeypoint.new(.5+halfWidth,1),NumberSequenceKeypoint.new(1,1),
            })
        end
        if rainbow then gradient.Transparency=rainbowLightTransparency(halfWidth,opacity) end
        gradient.Rotation = redesign and redesign.angle or ((effects.textshimmer or effects.textjelly) and 0 or (lightTag=='glint' and not rainbow) and 15 or 20)
    end
    local lightStrokeGradient
    if effects.textshimmer and textMask and mask and gradient then
        local sourceOutline=visual:FindFirstChild('BloxFigTextOutline')
        if sourceOutline and sourceOutline:IsA('UIStroke') then
            local shineOutline=Instance.new('UIStroke')
            shineOutline.Name='BloxFigGleamOutline'
            shineOutline.Color=Color3.new(1,1,1)
            shineOutline.Parent=mask
            local function syncOutline()
                shineOutline.Thickness=sourceOutline.Thickness
                shineOutline.Transparency=sourceOutline.Transparency
                shineOutline.ApplyStrokeMode=sourceOutline.ApplyStrokeMode
                shineOutline.LineJoinMode=sourceOutline.LineJoinMode
                shineOutline.Enabled=sourceOutline.Enabled
            end
            syncOutline()
            for _,property in ipairs({'Thickness','Transparency','ApplyStrokeMode','LineJoinMode','Enabled'})do
                sourceOutline:GetPropertyChangedSignal(property):Connect(syncOutline)
            end
            lightStrokeGradient=Instance.new('UIGradient')
            lightStrokeGradient.Color=gradient.Color
            lightStrokeGradient.Transparency=gradient.Transparency
            lightStrokeGradient.Rotation=gradient.Rotation
            lightStrokeGradient.Parent=shineOutline
        end
    end
    local state = {
        image=image, visual=visual, nativeText=nativeText, effects=effects, scale=scale, mask=mask, gradient=gradient, lightStrokeGradient=lightStrokeGradient, shadow=shadow, stroke=stroke, waveSlices=waveSlices,
        position=image.Position, size=image.Size, rotation=image.Rotation,
        designHeight=math.max(1,tonumber(image:GetAttribute('BloxFigBoundsHeight')) or image.AbsoluteSize.Y),
        transparency=sourceRaster and 0 or (nativeText and nativeText.TextTransparency or (visual:IsA('Frame') and 0 or visual.ImageTransparency)), started=os.clock(),
        speeds=speeds, strengths=strengths, phases={},hasArtworkHover=artworkHover,hasIdleEffects=hasIdleEffects,idleOnHover=image:GetAttribute('BloxFigIdleOnHover')==true,
        hover=false, pressed=false, smoothScale=scale and scale.Scale or 1,
        hoverLift=0, tilt=0, glintAt=-100, clickedAt=-100, lastFxClickAt=-100, pressArmed=false,
        jellyScale=1, jellyVelocity=0, hoverZoom=1, hoverFade=1, hoverWobble=0,
        magnetX=0, magnetY=0, visualMotion=visualMotion,
        dirtyUntil=os.clock()+.05, continuousMotion=false,
    }
    if scale then image:SetAttribute('BloxFigMotionBaseSize',state.size)end
    if image.GetAttributeChangedSignal then
        image:GetAttributeChangedSignal('BloxFigDeviceSize'):Connect(function()
            local size=image:GetAttribute('BloxFigDeviceSize')
            if typeof(size)=='UDim2' then state.size=size;if state.scale then image:SetAttribute('BloxFigMotionBaseSize',size)end end
        end)
        image:GetAttributeChangedSignal('BloxFigDevicePosition'):Connect(function()
            local baseline = image:GetAttribute('BloxFigDevicePosition')
            if typeof(baseline) == 'UDim2' then state.position = baseline end
        end)
    end
    if sourceRaster then
        state.nativeText=nil
        nativeText.TextTransparency=1
        local outline=nativeText:FindFirstChild('BloxFigTextOutline');local outlineEnabled=nativeText:GetAttribute('BloxFigNativeOutlineEnabled')
        if outlineEnabled==nil then outlineEnabled=outline and outline.Enabled;nativeText:SetAttribute('BloxFigNativeOutlineEnabled',outlineEnabled) end
        if outline then outline.Enabled=false end
        local originalText,originalFont,originalColor=nativeText.Text,nativeText.FontFace,nativeText.TextColor3
        local function edited()
            if nativeText.Text==originalText and nativeText.FontFace==originalFont and nativeText.TextColor3==originalColor then return end
            state.engineTextTag=nil
            if state.stopEngineMotion then state.stopEngineMotion()end
            rasterVisual.Visible=false
            if rasterPulse then scale.Parent=image end
            if state.mask then state.mask.Visible=false end
            state.gradient,state.waveSlices,state.texture=nil,nil,nil
            state.waitingForArtwork=false
            state.visual,state.nativeText,state.transparency=nativeText,nativeText,nativeAlpha
            nativeText.TextTransparency=nativeAlpha
            if outline then outline.Enabled=outlineEnabled;state.textOutline=outline;state.outlineTransparency=outline.Transparency end
        end
        for _,property in ipairs({'Text','FontFace','TextColor3'})do nativeText:GetPropertyChangedSignal(property):Connect(edited)end
    end
    state.texture=waveSlices and waveSlices[1].visual or ((visual:IsA('ImageLabel') or visual:IsA('ImageButton')) and visual or nil)
    -- Split buttons may own only live children, with no image of their own.
    -- An empty Image never loads; waiting for it freezes the whole container.
    if state.texture and state.texture.Image == '' then state.texture=nil end
    if image:GetAttribute('BloxFigLightOnly')==true then state.texture=nil end
    state.waitingForArtwork=state.texture~=nil and not state.texture.IsLoaded and image:GetAttribute('BloxFigContainer')~=true
    if not sourceRaster then state.textOutline=nativeText and nativeText:FindFirstChild('BloxFigTextOutline') end
    state.outlineTransparency=state.textOutline and state.textOutline.Transparency or 1
    if sourceRaster then
        local candidate,count=nil,0
        local compatible=true
        for tag in effects do
            if tag=='textfloat' or tag=='textpulse' or tag=='textjelly' then candidate=tag;count+=1
            elseif tag~='textshimmer' then compatible=false end
        end
        if compatible and count==1 then
            state.engineTextTag=candidate
            if candidate=='textjelly' and (not waveSlices or waveSlices[1].image~=waveSlices[1].visual)then state.engineTextTag=nil end
        end
    end
    if waveSlices then
        if mask then
            for _, part in ipairs(waveSlices) do
                local light = mask:Clone()
                light.Name = 'BloxFigLetterShimmer'
                light.Size = part.visual.Size
                light.Position = part.visual.Position
                light.AnchorPoint = part.visual.AnchorPoint
                light.ImageRectOffset = part.visual.ImageRectOffset
                light.ImageRectSize = part.visual.ImageRectSize
                if part.image==part.visual then light.Position=UDim2.fromScale(0,0);light.Size=UDim2.fromScale(1,1);light.AnchorPoint=Vector2.new(0,0) end
                light.Parent = part.image
                part.mask = light
                part.gradient = light:FindFirstChild('BloxFigGleam')
            end
        end
        -- The letter wave needs the exported glyph pixels so that Figma's
        -- font, outline, and italics remain identical during animation.
        if visual:IsA('ImageLabel') or visual:IsA('ImageButton') then visual.ImageTransparency = 1 end
        if nativeText then
            nativeText.Visible = true
            nativeText.TextTransparency = 1
            local outline = nativeText:FindFirstChild('BloxFigTextOutline')
            if outline then outline.Enabled = false end
        end
    end
    if sourceRaster and state.waitingForArtwork then
        -- Keep readable native text until the source image is available.
        -- IsLoaded stays false for invisible ImageLabels in the real engine,
        -- even after PreloadAsync. Keep the render instance visible so Roblox
        -- can resolve it; the native fallback is removed on the first loaded frame.
        nativeText.TextTransparency=nativeAlpha
        local outline=nativeText:FindFirstChild('BloxFigTextOutline')
        if outline then outline.Enabled=nativeText:GetAttribute('BloxFigNativeOutlineEnabled')~=false end
        rasterVisual.Visible=true
        state.revealArtwork=function()
            nativeText.TextTransparency=1
            if outline then outline.Enabled=false end
            rasterVisual.Visible=true
        end
        task.spawn(function()pcall(function()ContentProvider:PreloadAsync({rasterVisual})end)end)
    end
    if effects.hoverspot or effects.hoverbloom then
        local lightSource=lightAssetId or rasterAssetId or ((visual:IsA('ImageLabel') or visual:IsA('ImageButton')) and visual.Image)
        if type(lightSource)=='string' then
            local function light(name)
                local old=visual:FindFirstChild(name);if old then old:Destroy()end
                local node=Instance.new('ImageLabel');node.Name=name;node.Image=lightSource;node.BackgroundTransparency=1;node.BorderSizePixel=0
                node.Size=UDim2.fromScale(1,1);node.ImageColor3=Color3.new(1,1,1);node.ImageTransparency=1
                node.Active=false;node.Interactable=false;node.ZIndex=math.min(10000,visual.ZIndex+1);node.Parent=visual;return node
            end
            if effects.hoverbloom then state.hoverBloom=light('BloxFigHoverBloom') end
            if effects.hoverspot then
                state.hoverSpot=light('BloxFigHoverSpot')
                local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(.5,0);corner.Parent=state.hoverSpot
                local fade=Instance.new('UIGradient');fade.Rotation=90
                fade.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(1,1)});fade.Parent=state.hoverSpot
            end
        end
    end
    for _,tag in ipairs({'hoverfoil','hovercorners','hoverfan'})do
        if effects[tag] then
            state.renderFancy,state.fancyHost=createFancyHover(visual,image,(rasterVisual:IsA('ImageLabel') or rasterVisual:IsA('ImageButton')) and rasterVisual.Image or rasterAssetId,lightAssetId,gui:GetAttribute('BloxFigDecorationAssetId'),gui:GetAttribute('BloxFigDecorationVersion'),ContentProvider)
            script.Destroying:Connect(function()
                if state.fancySourceHidden and state.visual.Parent and (state.visual:IsA('ImageLabel') or state.visual:IsA('ImageButton')) then state.visual.ImageTransparency=state.transparency end
            end)
            state.hasFancy=true;break
        end
    end
    if effects.idlefall then
        local encoded=image:GetAttribute('BloxFigFall');local ok,config=pcall(function()return HttpService:JSONDecode(encoded or '{}')end)
        if ok and type(config)=='table' then state.renderFall=createIdleFall(image,config) end
    end
    state.continuousMotion = effects.idlefall or effects.idleorbit or effects.idleheartbeat or effects.shake or effects.textjelly
        or effects.gleam or effects.shiny or effects.glint or effects.textshimmer or effects.blink or effects.flicker
        or effects.idletwinkle or effects.glow or effects.spin or effects.wiggle or effects.sway
        or effects.idlependulum or effects.pulse or effects.breath or effects.float or effects.textfloat
        or effects.bounce or effects.textpulse
    if effects.fadein or effects.pop or effects.slidein or effects.textrise or effects.openzoom or effects.opendrop or effects.openrise or effects.openflip or effects.openbloom or effects.opensettle then
        state.dirtyUntil = state.started+motionWakeDuration(state)
    end
    if pressClick or artworkHover or state.hasFancy or effects.hoverspot or effects.hovermagnet or effects.tilt or effects.gleam or effects.glint or (hasIdleEffects and not state.idleOnHover) then usesPointer = true end
    if state.visualMotion or sourceRaster then states[#states + 1] = state end
    local input = image
    local imageId = image:GetAttribute('FigmaNodeId')
    if inputsByTarget[imageId] then input = inputsByTarget[imageId] end
    -- ImageLabels can still receive hover input; only Activated and press
    -- callbacks below require an ImageButton.
    state.interactive = input:IsA('GuiObject')
    state.input = input
    state.hoverInput=groupHoverTarget(gui,image,input)
    if state.hoverInput~=input or image:GetAttribute('BloxFigContainer')==true then usesPointer=true end
    local clickSound
    if state.interactive and type(soundPreset) == 'string' then
        local spec = clickSounds[soundPreset]
        local customId = image:GetAttribute('BloxFigClickSoundAssetId')
        local soundId = spec and spec[1]
        if not soundId and soundPreset == 'custom' and type(customId) == 'string' and string.match(customId, '^%d+$') then
            soundId = customId
        end
        if soundId then
            clickSound = Instance.new('Sound')
            clickSound.Name = 'BloxFigClickAudio'
            clickSound.SoundId = 'rbxassetid://'..soundId
            clickSound.PlaybackSpeed = spec and spec[2] or 1
            clickSound.Volume = math.clamp(tonumber(image:GetAttribute('BloxFigClickSoundVolume')) or (spec and spec[3] or .5),0,1)
            clickSound.Parent = SoundService
            gui.Destroying:Connect(function() clickSound:Destroy() end)
        end
    end
    state.hoverInput.MouseEnter:Connect(function()
        if (state.hoverInput~=state.input and UserInputService.MouseEnabled) or state.effects.hoverstamp or (state.hasArtworkHover and UserInputService.MouseEnabled) then return end
        if state.hover then return end
        state.hover = true
        state.wobbleStopped=false
        state.glintAt = os.clock()
        local lightSpeed = state.speeds.gleam or state.speeds.glint or 1
        state.dirtyUntil = state.glintAt + math.max(motionWakeDuration(state), .8/math.max(.001,lightSpeed)+.15)
    end)
    state.hoverInput.MouseLeave:Connect(function()
        if (state.hoverInput~=state.input and UserInputService.MouseEnabled) or state.effects.hoverstamp or (state.hasArtworkHover and UserInputService.MouseEnabled) then return end
        state.hover = false; state.pressed = false; state.wobbleStopped=false
        state.dirtyUntil = os.clock()+motionWakeDuration(state)
    end)
    if input:IsA('ImageButton') then
        input.InputBegan:Connect(function(event)
            if event.UserInputType == Enum.UserInputType.MouseButton1 or event.UserInputType == Enum.UserInputType.Touch then
                local now = os.clock()
                state.wobbleStopped=true;state.wobbleResumeAt=os.clock()+.75;state.hoverWobble=0
                if pressClick then
                    state.pressKeyboardClick=false;state.pressTouchPoint=nil
                    if event.UserInputType==Enum.UserInputType.Touch then
                        local point=Vector2.new(event.Position.X,event.Position.Y)
                        if not gui.IgnoreGuiInset then local inset=GuiService:GetGuiInset();point-=inset end
                        state.pressTouchPoint=point
                    end
                end
                state.pressArmed = true
                state.pressed = true
                if now - state.lastFxClickAt >= clickCooldown then
                    state.lastFxClickAt = now
                    state.clickedAt = now
                    state.dirtyUntil = now+motionWakeDuration(state)
                end
            end
        end)
        input.InputEnded:Connect(function(event)
            if event.UserInputType == Enum.UserInputType.MouseButton1 or event.UserInputType == Enum.UserInputType.Touch then
                if state.wobbleStopped then state.wobbleResumeAt=os.clock()+.75 end
                state.pressed = false
                state.dirtyUntil = os.clock()+motionWakeDuration(state)
            end
        end)
        input.Activated:Connect(function(event)
            state.wobbleStopped=true;state.wobbleResumeAt=os.clock()+.75;state.hoverWobble=0
            local now = os.clock()
            if clickSound then
                clickSound.TimePosition = 0
                clickSound:Play()
            end
            -- InputBegan already started this pointer click. Activated must
            -- not restart it after a long hold or after MouseLeave.
            -- Releasing a pointer outside the button may never fire Activated.
            -- Its saved arm must not swallow a later keyboard/controller click.
            local pointerActivation=event==nil or event.UserInputType==Enum.UserInputType.MouseButton1 or event.UserInputType==Enum.UserInputType.Touch
            if (not state.pressArmed or not pointerActivation) and now - state.lastFxClickAt >= clickCooldown then
                if pressClick then state.pressKeyboardClick=true;state.pressTouchPoint=nil end
                state.lastFxClickAt = now
                state.clickedAt = now
                state.dirtyUntil = now+motionWakeDuration(state)
            end
            state.pressArmed = false
            state.pressed = false
            startClose(state)
        end)
    end
end
local function safeSetup(descendant)
    local ok, problem = pcall(setup, descendant)
    if not ok then warn('BloxFig Motion could not prepare '..descendant:GetFullName()..': '..tostring(problem)) end
end
RunService.RenderStepped:Wait()
local initialDescendants = gui:GetDescendants()
for _, descendant in initialDescendants do
    if descendant:IsA('ImageButton') then
        local targetId = descendant:GetAttribute('BloxFigMotionTargetId')
        if type(targetId) == 'string' then inputsByTarget[targetId] = descendant end
    end
end
for _, descendant in initialDescendants do safeSetup(descendant) end
-- BEGIN BLOXFIG STABLE TEXT
-- Native glyph splitting retired; preview artwork handles scale motion.
-- END BLOXFIG STABLE TEXT
-- BEGIN BLOXFIG PRESS TEXT
local updatePressText,stopPressText=(function()
-- Keep source pixels stable for every font during parent scale animation.
-- The editable TextLabel remains the source of truth; edits restore native text.
return function(root, states, contentProvider)
    local controllers,entriesByLabel,stopped={},{},false
    local canvasEntries,existingPaints={},{}
    for _,node in ipairs(root:GetDescendants())do
        if node:IsA('ImageLabel')then
            local id=node:GetAttribute('BloxFigPressTextSource')
            if type(id)=='string' then existingPaints[id]=node end
        end
    end
    local scaleEffects={hoversmooth=true,smooth=true,jelly=true,hoverzoom=true,hoverlift=true,hovertilt=true,tilt=true,hoverwobble=true,hovermagnet=true,hoverfoil=true,hovercorners=true,hoverfan=true,pulse=true,breath=true,idleheartbeat=true,textpulse=true,
        clicksmooth=true,clickpop=true,clicksoft=true,clicksettle=true,clickbounce=true}
    local function scalesText(state)
        for tag in pairs(scaleEffects)do if state.effects[tag]then return true end end
        return false
    end
    local function pressing(state,now)
        if state.pressed then return true end
        for _,tag in ipairs({'clicksmooth','clickpop','clicksoft','clicksettle','clickbounce'})do
            if state.effects[tag]then local age=(now-state.clickedAt)*(state.speeds[tag] or 0);if age>=0 and age<.54 then return true end end
        end
        return false
    end
    local function scaleOf(node)
        local scale=1
        while node do
            local modifier=node:FindFirstChildOfClass('UIScale')
            if modifier then scale*=modifier.Scale end
            node=node.Parent
        end
        return math.max(.001,scale)
    end
    local function logicalParentExtent(entry,parent,extent)
        local geometry,node,dynamic={},parent,false
        while node do
            if node:IsA('GuiObject')then
                geometry[#geometry+1]=tostring(node.Size)..tostring(node.SizeConstraint)
                local modifier=node:FindFirstChildOfClass('UIScale')
                if modifier and modifier.Name~='BloxFigScale' then geometry[#geometry+1]=tostring(modifier.Scale)end
                for _,kind in ipairs({'UIAspectRatioConstraint','UISizeConstraint'})do
                    local constraint=node:FindFirstChildOfClass(kind)
                    if constraint then
                        if kind=='UIAspectRatioConstraint' then
                            geometry[#geometry+1]=tostring(constraint.AspectRatio)..tostring(constraint.AspectType)..tostring(constraint.DominantAxis)
                        else
                            geometry[#geometry+1]=tostring(constraint.MinSize)..tostring(constraint.MaxSize)
                        end
                    end
                end
                if Enum.AutomaticSize and node.AutomaticSize and node.AutomaticSize~=Enum.AutomaticSize.None then dynamic=true end
                if node.Parent then for _,kind in ipairs({'UIListLayout','UIGridLayout','UITableLayout','UIPageLayout'})do if node.Parent:FindFirstChildOfClass(kind)then dynamic=true;break end end end
                if node:IsA('ScrollingFrame')then
                    geometry[#geometry+1]=tostring(node.CanvasSize)
                    if Enum.AutomaticSize and node.AutomaticCanvasSize and node.AutomaticCanvasSize~=Enum.AutomaticSize.None then dynamic=true end
                end
            elseif node:IsA('ScreenGui')then geometry[#geometry+1]=tostring(node.AbsoluteSize);break end
            node=node.Parent
        end
        local key=table.concat(geometry,'|')
        if not dynamic and entry.geometryParent==parent and entry.geometryKey==key then return entry.parentWidth,entry.parentHeight end
        local inherited=scaleOf(parent)
        local w,h=extent.X/inherited,extent.Y/inherited
        entry.geometryParent,entry.geometryKey,entry.parentWidth,entry.parentHeight=parent,key,w,h
        return w,h
    end
    local function sharedCanvas(entry)
        local owner=entry.canvasOwner
        if not owner or not owner.Parent then return nil end
        local node=entry.label
        for _,saved in ipairs(entry.canvasPath)do
            if node~=saved.node or node.Position~=saved.position or node.Size~=saved.size
                or node.AnchorPoint~=saved.anchor or node.Rotation~=saved.rotation
                or node.ClipsDescendants then return nil end
            local modifier=node:FindFirstChildOfClass('UIScale')
            if (modifier and modifier.Scale or 1)~=saved.scale then return nil end
            node=node.Parent
        end
        return node==owner and owner or nil
    end
    local function place(entry)
        local label=entry.label
        local parent=label.Parent
        -- A valid owner canvas already supplies the final rectangle. Only the
        -- fallback projection needs layout/constraint checks and parent extents.
        local canvas=sharedCanvas(entry)
        local project=not canvas and parent and (parent:IsA('GuiObject') or parent:IsA('ScreenGui')) and not label.ClipsDescendants
        -- A sibling must not become a new participant in a creator's layout,
        -- auto-sizing container, or the label's own constrained geometry.
        if project then
            for _,kind in ipairs({'UIListLayout','UIGridLayout','UITableLayout','UIPageLayout'})do
                if parent:FindFirstChildOfClass(kind)then project=false;break end
            end
            for _,kind in ipairs({'UIAspectRatioConstraint','UISizeConstraint'})do
                if label:FindFirstChildOfClass(kind)then project=false;break end
            end
            if Enum.AutomaticSize then
                for _,node in ipairs({parent,label})do
                    if node:IsA('GuiObject') and node.AutomaticSize and node.AutomaticSize~=Enum.AutomaticSize.None then project=false end
                end
                if parent:IsA('ScrollingFrame') and parent.AutomaticCanvasSize and parent.AutomaticCanvasSize~=Enum.AutomaticSize.None then project=false end
            end
            if Enum.SizeConstraint and label.SizeConstraint and label.SizeConstraint~=Enum.SizeConstraint.RelativeXY then project=false end
        end
        local extent=project and (parent:IsA('ScrollingFrame') and parent.AbsoluteCanvasSize or parent.AbsoluteSize)
        if not extent or extent.X<=0 or extent.Y<=0 then project=false end
        local position,size,anchor,rotation,host
        if canvas then
            -- The text PNG has the owner's exact transparent canvas. No second
            -- rounded paint rectangle or per-frame reconstruction is involved.
            position=UDim2.fromScale(0,0);size=UDim2.fromScale(1,1)
            anchor=Vector2.zero;rotation=0;host=canvas
        elseif project then
            -- Compose the label and paint rectangles BEFORE Roblox rounds the
            -- label's rectangle. A second child layout can add an independent
            -- pixel step during motion even when the font itself stays fixed.
            -- Do not divide rounded AbsoluteSize by a changing motion scale
            -- again every frame. That makes an unchanged logical parent appear
            -- to grow/shrink fractionally and shifts all offset-sized captions.
            local w,h=logicalParentExtent(entry,parent,extent)
            local own=label:FindFirstChildOfClass('UIScale')
            local zoom=own and own.Scale or 1
            local p,s,a=label.Position,label.Size,label.AnchorPoint
            local bw,bh=(s.X.Scale*w+s.X.Offset)*zoom,(s.Y.Scale*h+s.Y.Offset)*zoom
            local angle=math.rad(label.Rotation or 0)
            local c,sine=math.cos(angle),math.sin(angle)
            local dx,dy=(entry.px+entry.sx/2-.5)*bw,(entry.py+entry.sy/2-.5)*bh
            position=UDim2.fromScale(p.X.Scale+(p.X.Offset+(.5-a.X)*bw+dx*c-dy*sine)/w,
                p.Y.Scale+(p.Y.Offset+(.5-a.Y)*bh+dx*sine+dy*c)/h)
            size=UDim2.fromScale(entry.sx*bw/w,entry.sy*bh/h)
            position=UDim2.fromScale(position.X.Scale-size.X.Scale/2,position.Y.Scale-size.Y.Scale/2)
            anchor=Vector2.zero;rotation=label.Rotation or 0;host=parent
        else
            position=UDim2.fromScale(entry.px,entry.py);size=UDim2.fromScale(entry.sx,entry.sy)
            anchor=Vector2.zero;rotation=0;host=label
        end
        for _,node in ipairs(entry.light and {entry.image,entry.light} or {entry.image})do
            if node.Parent~=host then node.Parent=host end
            if node.AnchorPoint~=anchor then node.AnchorPoint=anchor end
            if node.Position~=position then node.Position=position end
            if node.Size~=size then node.Size=size end
            if node.Rotation~=rotation then node.Rotation=rotation end
            if node.ZIndex~=label.ZIndex then node.ZIndex=label.ZIndex end
            if node.Visible~=label.Visible then node.Visible=label.Visible end
        end
        entry.projected=project
    end
    local function makeEntry(label)
        local asset=label:GetAttribute('BloxFigImageAssetId')
        local sourceText=label:GetAttribute('BloxFigSourceText')
        local width,height=label:GetAttribute('BloxFigResponsiveWidth'),label:GetAttribute('BloxFigResponsiveHeight')
        local pixelsX,pixelsY=label:GetAttribute('BloxFigImageWidth'),label:GetAttribute('BloxFigImageHeight')
        local exportScale=root:GetAttribute('ExportScale')
        local inkX,inkY=label:GetAttribute('BloxFigSourceInkX'),label:GetAttribute('BloxFigSourceInkY')
        if label:GetAttribute('BloxFigTextArtworkCompatible')==false then return end
        if type(asset)~='string' or label.Text~=sourceText
            or type(width)~='number' or type(height)~='number' or width<=0 or height<=0 then
            label:SetAttribute('BloxFigTextRenderMode','native-missing-preview-metadata');return
        end
        local ax,ay=label:GetAttribute('BloxFigTextArtwork_x'),label:GetAttribute('BloxFigTextArtwork_y')
        local aw,ah=label:GetAttribute('BloxFigTextArtwork_width'),label:GetAttribute('BloxFigTextArtwork_height')
        local canvasOwner,canvasPath
        local ownerId=label:GetAttribute('BloxFigTextCanvasOwner')
        if type(ownerId)=='string' then
            -- Even without its original owner, the PNG still has the full
            -- transparent canvas. Cropped paint bounds describe another image
            -- and would shrink the letters when the runtime image loads.
            local cx,cy=label:GetAttribute('BloxFigTextCanvas_x'),label:GetAttribute('BloxFigTextCanvas_y')
            local cw,ch=label:GetAttribute('BloxFigTextCanvas_width'),label:GetAttribute('BloxFigTextCanvas_height')
            if type(cx)=='number' and type(cy)=='number' and type(cw)=='number' and type(ch)=='number' and cw>0 and ch>0 then
                ax,ay,aw,ah=cx,cy,cw,ch
            end
            local node=label.Parent
            while node and node~=root do
                if node:IsA('ScrollingFrame')then break end
                if node:GetAttribute('FigmaNodeId')==ownerId then canvasOwner=node;break end
                node=node.Parent
            end
            if canvasOwner then
                canvasPath={};node=label
                while node and node~=canvasOwner do
                    local modifier=node:FindFirstChildOfClass('UIScale')
                    canvasPath[#canvasPath+1]={node=node,position=node.Position,size=node.Size,anchor=node.AnchorPoint,rotation=node.Rotation,scale=modifier and modifier.Scale or 1}
                    node=node.Parent
                end
            end
        end
        local px,py,sx,sy
        if type(ax)=='number' and type(ay)=='number' and type(aw)=='number' and type(ah)=='number' and aw>0 and ah>0 then
            -- Exact Figma paint bounds include bearings, italics, stroke and shadow.
            -- Undo the *applied* native alignment, not a font-specific estimate.
            px=(ax-(label:GetAttribute('BloxFigNativeAppliedX') or 0))/width
            py=(ay-(label:GetAttribute('BloxFigNativeAppliedY') or 0))/height
            sx,sy=aw/width,ah/height
        else
            -- Existing imports already contain source ink and PNG dimensions.
            -- Preserve the proven Press Start compatibility path for older ROLL.
            if inkX==nil and sourceText=='ROLL' and label.FontFace.Family:match('/PressStart2P%.json$')then inkX,inkY=0,0 end
            if type(pixelsX)~='number' or type(pixelsY)~='number' or pixelsX<=0 or pixelsY<=0 or type(exportScale)~='number' or exportScale<=0
                or type(inkX)~='number' or type(inkY)~='number' then
                label:SetAttribute('BloxFigTextRenderMode','native-missing-preview-metadata');return
            end
            local stroke=label:GetAttribute('BloxFigResponsiveStroke') or 0
            local bearing=label:GetAttribute('BloxFigNativeAppliedX')
            local baseline=label:GetAttribute('BloxFigNativeAppliedY')
            if bearing==nil then bearing=math.floor((label:GetAttribute('BloxFigNativeBearingOffset') or 0)+.5)end
            if baseline==nil then baseline=math.floor((label:GetAttribute('BloxFigNativeBaselineOffset') or 0)+.5)end
            px,py=(inkX-stroke-bearing)/width,(inkY-stroke-baseline)/height
            sx,sy=pixelsX/exportScale/width,pixelsY/exportScale/height
        end
        for _,child in ipairs(label:GetChildren())do if child:IsA('UIPadding') and child.Name~='BloxFigTextPadding' then return end end
        local padding=label:FindFirstChild('BloxFigTextPadding')
        if padding and padding:IsA('UIPadding')then
            for _,side in ipairs({'Left','Right','Top','Bottom'})do
                if padding['Padding'..side]~=label:GetAttribute('BloxFigSourcePadding'..side)then return end
            end
        end
        local outline=label:FindFirstChild('BloxFigTextOutline')
        local entry={label=label,source=sourceText,font=label.FontFace,color=label.TextColor3,
            canvasOwner=canvasOwner,canvasPath=canvasPath,outlineEnabled=outline and outline.Enabled,
            outline=outline,padding=padding,strokeColor=outline and outline.Color,active=false,px=px,py=py,sx=sx,sy=sy,width=width,height=height,maximum=label.MaxVisibleGraphemes,
            fontSize=label:GetAttribute('BloxFigResponsiveFont'),alignX=label.TextXAlignment,alignY=label.TextYAlignment,
            lineHeight=label.LineHeight,wrapped=label.TextWrapped,truncated=label.TextTruncate,rich=label.RichText}
        local function image(parent,id,name)
            local node=Instance.new('ImageLabel');node.Name=name
            node.BackgroundTransparency=1;node.BorderSizePixel=0
            node.Active=false;node.Interactable=false;node.Selectable=false
            node.Position=UDim2.fromScale(px,py);node.Size=UDim2.fromScale(sx,sy)
            node.Image=id;node.ImageColor3=Color3.new(1,1,1);node.ImageTransparency=1
            node.ResampleMode=Enum.ResamplerMode.Default;node.ZIndex=parent.ZIndex
            -- Keep render instances visible while transparent for loading.
            node.Visible=true;node.Parent=label
            return node
        end
        local sourceId=label:GetAttribute('FigmaNodeId')
        local existing=sourceId and existingPaints[sourceId]
        if existing and existing.Image==asset then
            entry.image=existing;existingPaints[sourceId]=nil
            local maximum=existing:GetAttribute('BloxFigNativeMaximum')
            if type(maximum)=='number' then
                entry.maximum=maximum;entry.active=true
                local originalOutline=existing:GetAttribute('BloxFigNativeOutlineEnabled')
                if type(originalOutline)=='boolean' then entry.outlineEnabled=originalOutline end
            end
        else
            if existing then existing:Destroy();existingPaints[sourceId]=nil end
            entry.image=image(label,asset,'BloxFigPressArtwork')
        end
        if type(sourceId)=='string' then entry.image:SetAttribute('BloxFigPressTextSource',sourceId)end
        local mask=label:FindFirstChild('BloxFigGleamText')
        local light=label:GetAttribute('BloxFigLightAssetId')
        if mask and mask:IsA('TextLabel') then
            entry.mask=mask;entry.maskMaximum=mask.MaxVisibleGraphemes;entry.gradient=mask:FindFirstChild('BloxFigGleam')
            entry.maskOutline=mask:FindFirstChild('BloxFigGleamOutline');entry.maskOutlineEnabled=entry.maskOutline and entry.maskOutline.Enabled
            if type(light)=='string' and entry.gradient then
                entry.light=image(mask,light,'BloxFigPressShimmer')
                entry.lightGradient=entry.gradient:Clone();entry.lightGradient.Parent=entry.light
            end
        end
        if label.Destroying then entry.destroySignal=label.Destroying:Connect(function()
            entry.image:Destroy();if entry.light then entry.light:Destroy()end
        end)end
        entry.sizeSignal=label:GetPropertyChangedSignal('TextSize'):Connect(function()
            if label:GetAttribute('BloxFigManagedTextWrite')==true then return end
            local expected=entry.fontSize and entry.fontSize*(label:GetAttribute('BloxFigResponsiveTextRatio') or 1)
            entry.sizeEdited=expected==nil or math.abs(label.TextSize-expected)>.001
        end)
        local assets={entry.image};if entry.light then assets[#assets+1]=entry.light end
        task.spawn(function()pcall(function()contentProvider:PreloadAsync(assets,function(_,status)
            if label.Parent then label:SetAttribute('BloxFigPreviewFetchStatus',tostring(status)) end
        end)end)end)
        return entry
    end
    local function valid(entry)
        local label=entry.label
        local key=label:GetAttribute('BloxFigSourceFontKey')
        local font=label.FontFace
        if entry.padding then for _,side in ipairs({'Left','Right','Top','Bottom'})do if entry.padding['Padding'..side]~=label:GetAttribute('BloxFigSourcePadding'..side)then return false end end end
        if entry.active and label.MaxVisibleGraphemes~=0 then entry.maximum=label.MaxVisibleGraphemes end
        if not entry.active then entry.maximum=label.MaxVisibleGraphemes end
        return label.Parent and label.Text==entry.source and font.Family==entry.font.Family and font.Weight==entry.font.Weight and font.Style==entry.font.Style and label.TextColor3==entry.color and entry.maximum<0
            and (not key or font.Family..':'..tostring(font.Weight)..':'..tostring(font.Style)==key)
            and (label:GetAttribute('BloxFigSourceColor')==nil or label.TextColor3==label:GetAttribute('BloxFigSourceColor'))
            and not label.RichText and not label.TextScaled
            and label.TextXAlignment==entry.alignX and label.TextYAlignment==entry.alignY and label.LineHeight==entry.lineHeight
            and label.TextWrapped==entry.wrapped and label.TextTruncate==entry.truncated
            and label:GetAttribute('BloxFigResponsiveFont')==entry.fontSize
            and not entry.sizeEdited
            and not label:FindFirstChildOfClass('UIGradient')
            and (not entry.outline or entry.outline.Color==entry.strokeColor)
    end
    local function restore(entry)
        if entry.active then
            entry.label.MaxVisibleGraphemes=entry.maximum
            if entry.outline then entry.outline.Enabled=entry.outlineEnabled end
            if entry.maskOutline then entry.maskOutline.Enabled=entry.maskOutlineEnabled end
            if entry.mask and entry.mask.Parent then entry.mask.MaxVisibleGraphemes=entry.maskMaximum end
        end
        if entry.image.ImageTransparency~=1 then entry.image.ImageTransparency=1 end
        if entry.light and entry.light.ImageTransparency~=1 then entry.light.ImageTransparency=1 end
        if entry.image:GetAttribute('BloxFigNativeMaximum')~=nil then entry.image:SetAttribute('BloxFigNativeMaximum',nil)end
        if entry.image:GetAttribute('BloxFigNativeOutlineEnabled')~=nil then entry.image:SetAttribute('BloxFigNativeOutlineEnabled',nil)end
        entry.active=false
    end
    local function alphaAt(keys,t)
        if t<=keys[1].Time then return keys[1].Value end
        for i=2,#keys do
            if t<=keys[i].Time then
                local a,b=keys[i-1],keys[i]
                return a.Value+(b.Value-a.Value)*(t-a.Time)/(b.Time-a.Time)
            end
        end
        return keys[#keys].Value
    end
    local function render(entry)
        if not entry.active then
            entry.outlineEnabled=entry.outline and entry.outline.Enabled
            entry.maskOutlineEnabled=entry.maskOutline and entry.maskOutline.Enabled
        end
        if entry.outline and entry.outline.Enabled then entry.outline.Enabled=false end
        if entry.maskOutline and entry.maskOutline.Enabled then entry.maskOutline.Enabled=false end
        if entry.label.MaxVisibleGraphemes~=0 then entry.label.MaxVisibleGraphemes=0 end
        if entry.mask and entry.mask.MaxVisibleGraphemes~=0 then entry.mask.MaxVisibleGraphemes=0 end
        if entry.image:GetAttribute('BloxFigNativeMaximum')~=entry.maximum then entry.image:SetAttribute('BloxFigNativeMaximum',entry.maximum)end
        if entry.image:GetAttribute('BloxFigNativeOutlineEnabled')~=entry.outlineEnabled then entry.image:SetAttribute('BloxFigNativeOutlineEnabled',entry.outlineEnabled)end
        entry.active=true
        local base=entry.label:GetAttribute('BloxFigNativeTextTransparency') or 0
        local fade=math.clamp((entry.label.TextTransparency-base)/math.max(.0001,1-base),0,1)
        if entry.image.ImageTransparency~=fade then entry.image.ImageTransparency=fade end
        if entry.light then
            local source,copy=entry.gradient,entry.lightGradient
            -- Project the native gradient field into the paint rectangle,
            -- including diagonal hover light masks. The 0-degree case is the
            -- same mapping as the original Press Start shimmer path.
            local transparency,offset,angleDegrees=source.Transparency,source.Offset,source.Rotation
            -- NumberSequences are immutable values. Reproject only when the
            -- source field changes; idle/disabled lights keep the exact result.
            if entry.lightSourceTransparency~=transparency or entry.lightSourceRotation~=angleDegrees
                or entry.lightSourceOffsetX~=offset.X or entry.lightSourceOffsetY~=offset.Y then
                local keys=transparency.Keypoints
                local angle=math.rad(angleDegrees)
                local c,s=math.cos(angle),math.sin(angle)
                local width,height=entry.width,entry.height
                local span=math.max(.001,math.abs(c)*width+math.abs(s)*height)
                local paintSpan=math.abs(c)*entry.sx*width+math.abs(s)*entry.sy*height
                local dx=(entry.px+entry.sx/2-.5-offset.X)*width
                local dy=(entry.py+entry.sy/2-.5-(offset.Y or 0))*height
                local start=.5+(dx*c+dy*s-paintSpan/2)/span
                local range=paintSpan/span
                local points={NumberSequenceKeypoint.new(0,alphaAt(keys,start))}
                for _,key in ipairs(keys)do
                    local at=(key.Time-start)/range
                    if at>.000001 and at<.999999 then points[#points+1]=NumberSequenceKeypoint.new(at,key.Value)end
                end
                points[#points+1]=NumberSequenceKeypoint.new(1,alphaAt(keys,start+range))
                entry.lightMappedTransparency=NumberSequence.new(points)
                entry.lightSourceTransparency,entry.lightSourceRotation=transparency,angleDegrees
                entry.lightSourceOffsetX,entry.lightSourceOffsetY=offset.X,offset.Y
            end
            if copy.Rotation~=angleDegrees then copy.Rotation=angleDegrees end
            if copy.Transparency~=entry.lightMappedTransparency then copy.Transparency=entry.lightMappedTransparency end
            if copy.Color~=source.Color then copy.Color=source.Color end
            if copy.Offset~=Vector2.zero then copy.Offset=Vector2.zero end
            if copy.Enabled~=source.Enabled then copy.Enabled=source.Enabled end
            local alpha=entry.mask.Visible and source.Enabled and fade or 1
            if entry.light.ImageTransparency~=alpha then entry.light.ImageTransparency=alpha end
        end
        if entry.label:GetAttribute('BloxFigTextRenderMode')~='preview-artwork' then entry.label:SetAttribute('BloxFigTextRenderMode','preview-artwork') end
    end
    local requested={}
    local function update(now,enabled)
        if stopped then return end
        table.clear(requested)
        for _,entry in ipairs(canvasEntries)do
            requested[entry]=true;entry.wantsEnabled=enabled and entry.label.Parent~=nil;entry.wantsPress=false
        end
        for _,state in ipairs(states)do if scalesText(state)then
            local controller=controllers[state]
            if not controller then
                controller={entries={}};controllers[state]=controller
                local nodes=state.image:GetDescendants()
                if state.image:IsA('TextLabel')then nodes[#nodes+1]=state.image end
                for _,label in ipairs(nodes)do if label:IsA('TextLabel') and label:GetAttribute('BloxFigNativeText')==true then
                    local entry=entriesByLabel[label]
                    if not entry then entry=makeEntry(label);if entry then entriesByLabel[label]=entry end end
                    if entry then controller.entries[#controller.entries+1]=entry end
                end end
            end
            for _,entry in ipairs(controller.entries)do
                if not requested[entry]then requested[entry]=true;entry.wantsEnabled=false;entry.wantsPress=false end
                entry.wantsEnabled=entry.wantsEnabled or enabled and state.image.Parent~=nil
                entry.wantsPress=entry.wantsPress or pressing(state,now)
            end
        end end
        -- One renderer per label, even when both parent and child have effects.
        for entry in pairs(requested)do
            local eligible=entry.wantsEnabled and valid(entry)
            if entry.label.Parent then place(entry)end
            local ready=entry.image.IsLoaded and (not entry.mask or entry.light and entry.light.IsLoaded)
            if eligible and (entry.active or ready and not entry.wantsPress)then render(entry)
            else
                restore(entry)
                local mode='native-edited-or-unsupported'
                if eligible and (not entry.mask or entry.light)then
                    -- Request rendering while the readable native fallback stays visible.
                    if entry.image.ImageTransparency~=.999 then entry.image.ImageTransparency=.999 end
                    if entry.light then
                        if entry.lightGradient.Enabled then entry.lightGradient.Enabled=false end
                        if entry.light.ImageTransparency~=.999 then entry.light.ImageTransparency=.999 end
                    end
                    mode='warming-preview-artwork'
                elseif not enabled then mode='native-disabled' end
                if entry.label:GetAttribute('BloxFigTextRenderMode')~=mode then entry.label:SetAttribute('BloxFigTextRenderMode',mode)end
            end
        end
    end
    local function stop()
        if stopped then return end
        stopped=true
        for _,entry in pairs(entriesByLabel)do
            restore(entry);if entry.sizeSignal then entry.sizeSignal:Disconnect()end;if entry.destroySignal then entry.destroySignal:Disconnect()end;entry.label:SetAttribute('BloxFigTextRenderMode','native-runtime-stopped')
            entry.image:Destroy();if entry.light then entry.light:Destroy() end
        end
        table.clear(entriesByLabel);table.clear(controllers);table.clear(requested)
        table.clear(canvasEntries);table.clear(existingPaints)
    end
    -- Full owner canvases also reproduce source strokes/shadows at rest and in
    -- Studio edit mode. Both environments use this exact renderer; a cloned
    -- edit preview is adopted instead of drawing a second copy in PlayerGui.
    for _,label in ipairs(root:GetDescendants())do
        if label:IsA('TextLabel') and label:GetAttribute('BloxFigNativeText')==true
            and type(label:GetAttribute('BloxFigTextCanvasOwner'))=='string' then
            local entry=makeEntry(label)
            if entry then entriesByLabel[label]=entry;canvasEntries[#canvasEntries+1]=entry end
        end
    end
    -- Warm textures and capture rest geometry before the first hover pose.
    update(os.clock(),root.Enabled~=false)
    return update,stop
end

end)()(gui,states,ContentProvider)
script.Destroying:Connect(stopPressText)
-- END BLOXFIG PRESS TEXT
gui.DescendantAdded:Connect(function(descendant)
    if descendant:IsA('ImageButton') then
        local targetId = descendant:GetAttribute('BloxFigMotionTargetId')
        if type(targetId) == 'string' then inputsByTarget[targetId] = descendant end
    end
    safeSetup(descendant)
end)
gui:GetPropertyChangedSignal('Enabled'):Connect(function()
    for _,state in states do if state.stopEngineMotion then state.stopEngineMotion()end end
    if gui.Enabled then
        local now=os.clock()
        for _, state in states do
            state.started=now
            state.dirtyUntil=now+motionWakeDuration(state)
            state.clickedAt=-100
            state.hover=false
            state.wobbleStopped=false
            state.pressed=false
            state.pressArmed=false
            state.smoothScale,state.hoverZoom,state.jellyScale,state.jellyVelocity=1,1,1,0
            state.hoverLift,state.magnetX,state.magnetY,state.tilt,state.hoverWobble,state.hoverFade=0,0,0,0,0,1
            state.rewardClicks={};state.rewardLast=-1
            state.pressFx={}
            state.pressKeyboardClick=false;state.pressTouchPoint=nil
            state.newHoverMix={}
            state.fancyMix={}
            state.foilVelocity=0
            state.motionX,state.motionY=0,0
            state.motionStretchX,state.motionStretchY=1,1
            state.glintAt,state.lastFxClickAt=-100,-100
        end
    end
end)
local function hasAncestorHoverSweep(image,owners)
    if next(owners)==nil then return false end
    local node=image.Parent
    while node and node~=gui do
        if owners[node] then return true end
        node=node.Parent
    end
    return false
end
local hoverLightOwners={}
RunService.RenderStepped:Connect(function(dt)
    if not gui.Enabled then updatePressText(os.clock(),false);return end
    local now = os.clock()
    if renderClose(now) then return end
    local pointer = usesPointer and UserInputService:GetMouseLocation() or zeroPointer
    if usesPointer and not gui.IgnoreGuiInset then
        local inset = GuiService:GetGuiInset()
        pointer -= inset
    end
    local frameDt = math.min(dt, .05)
    table.clear(hoverLightOwners)
    for _,light in ipairs(states) do
        if light.image:GetAttribute('BloxFigLightOnly')==true and light.image.Parent and visibleInGui(light.image) then
            local owner=light.image.Parent
            local hovering=light.hover
            if UserInputService.MouseEnabled then hovering=groupHoverContains(gui,owner,pointer) end
            if light.effects.gleam or light.effects.shiny or (light.effects.glint and hovering) then hoverLightOwners[owner]=true end
        end
    end
    for _, state in states do
        local image = state.image
        if not image.Parent or not visibleInGui(image) then continue end
        local fx = state.effects
        if image.Parent:IsA('ScreenGui') then
            local layoutPosition=image:GetAttribute('BloxFigDevicePosition')
            if typeof(layoutPosition)=='UDim2' then state.position=layoutPosition end
        end
        if state.waitingForArtwork then
            if not state.texture.IsLoaded then continue end
            state.waitingForArtwork=false
            if state.revealArtwork then state.revealArtwork();state.revealArtwork=nil end
            state.started=now
            state.dirtyUntil=now+motionWakeDuration(state)
        end
        if state.engineTextTag and not state.engineMotion then startEngineTextMotion(state)end
        if state.engineMotion and not state.gradient then continue end
        if UserInputService.MouseEnabled and ((state.hoverInput and state.hoverInput~=state.input) or image:GetAttribute('BloxFigContainer')==true or state.hasArtworkHover or fx.hoverstamp or fx.gleam or fx.glint or (state.hasIdleEffects and not state.idleOnHover)) then
            local hoverInput=state.hoverInput or state.input
            local at, box = hoverInput.AbsolutePosition, hoverInput.AbsoluteSize
            local inside = pointer.X >= at.X and pointer.X < at.X + box.X and pointer.Y >= at.Y and pointer.Y < at.Y + box.Y
            if state.hoverInput and (state.hoverInput~=state.input or image:GetAttribute('BloxFigContainer')==true) then
                inside=groupHoverContains(gui,hoverInput,pointer)
            elseif state.hasArtworkHover then
                local node=state.input
                local cx,cy=node.AbsolutePosition.X+node.AbsoluteSize.X/2,node.AbsolutePosition.Y+node.AbsoluteSize.Y/2
                local bw,bh=node.AbsoluteSize.X,node.AbsoluteSize.Y
                if node==image then
                    local own=state.scale and state.scale.Scale or 1
                    local pw,ph=bw/own,bh/own
                    local dw=math.max(1,tonumber(image:GetAttribute('BloxFigBoundsWidth')) or bw)
                    local dh=math.max(1,tonumber(image:GetAttribute('BloxFigBoundsHeight')) or state.designHeight)
                    cx-=(state.motionX or 0)*pw/dw;cy-=(state.motionY or 0)*ph/dh
                    bw=pw/(state.motionStretchX or 1);bh=ph/(state.motionStretchY or 1)
                end
                inside=math.abs(pointer.X-cx)<bw/2 and math.abs(pointer.Y-cy)<bh/2
            elseif fx.hoverstamp then local dx,dy,width=motionPointer(state,pointer);local height=math.max(1,tonumber(image:GetAttribute('BloxFigBoundsHeight')) or state.designHeight);inside=math.abs(dx)<width/2 and math.abs(dy)<height/2 end
            if inside and not state.hover then
                state.hover = true
                state.wobbleStopped=false
                state.glintAt = now
                local lightSpeed = state.speeds.gleam or state.speeds.glint or 1
                state.dirtyUntil = now + math.max(motionWakeDuration(state), .8/math.max(.001,lightSpeed)+.15)
            elseif not inside and state.hover then
                state.hover = false
                state.wobbleStopped=false
                state.pressed = false
                state.dirtyUntil = now + motionWakeDuration(state)
            end
        end
        if now > state.dirtyUntil and not state.continuousMotion
            and not state.pressed and not (state.hover and (state.hasArtworkHover or state.hasFancy or fx.hoverspot or fx.hovermagnet or fx.tilt or fx.hoverwobble)) then continue end
        local elapsedTime = now - state.started
        local clickTime = now - state.clickedAt
        local speed, strength, elapsed = state.speeds, state.strengths, state.phases
        local idleTime=idleTimeline(state,now)
        for tag in fx do elapsed[tag] = (idleEffects[tag] and idleTime or elapsedTime) * speed[tag] end
        if state.renderFall then state.renderFall(elapsed.idlefall,strength.idlefall) end
        local x, y, rotation, factor, textFloatY = 0, 0, state.rotation, 1, 0
        if state.renderFancy then
            local width=math.max(1,tonumber(image:GetAttribute('BloxFigBoundsWidth')) or image.AbsoluteSize.X)
            local height=math.max(1,tonumber(image:GetAttribute('BloxFigBoundsHeight')) or image.AbsoluteSize.Y)
            local px,py=motionPointer(state,pointer)
            local sprites={};state.fancyMix=state.fancyMix or {}
            for _,tag in ipairs({'hoverfoil','hovercorners','hoverfan'})do if fx[tag] then
                local rate=speed[tag]/motionTempo
                local mix=fancyHoverMix(state,tag,state.hover,frameDt,rate)
                for _,part in ipairs(fancyHoverSprites(tag,math.max(0,now-state.glintAt)*rate,mix,strength[tag],px,py,width,height))do sprites[#sprites+1]=part end
            end end
            state.rewardClicks=state.rewardClicks or {}
            if state.clickedAt>=0 and state.rewardLast~=state.clickedAt then state.rewardLast=state.clickedAt;table.insert(state.rewardClicks,state.clickedAt);if #state.rewardClicks>3 then table.remove(state.rewardClicks,1)end end
            for _,at in ipairs(state.rewardClicks)do for _,tag in ipairs({})do if fx[tag] then
                for _,part in ipairs(fancyHoverSprites(tag,(now-at)*speed[tag],1,strength[tag],px,py,width,height))do sprites[#sprites+1]=part end
            end end end
            state.fancyReplacement=false
            for _,part in ipairs(sprites)do if part.replace==1 and part.a>0 then state.fancyReplacement=true;part.a*=1-state.transparency end end
            if state.fancyReplacement then
                state.fancySprites,state.fancyWidth,state.fancyHeight=sprites,width,height
            else
                state.fancySprites=nil
                state.renderFancy(sprites,width,height)
            end
        end
        local stretchX,stretchY=1,1
        local spotAlpha,bloomAlpha=0,0
        state.newHoverMix=state.newHoverMix or {}
        for _, tag in ipairs({'hoversmooth','hovertilt','hoverhop','hoverstretch','hovershake','hovericon','hoverspot','hoverbloom','hoverstamp'}) do
            if fx[tag] then
                local rate=speed[tag]/motionTempo
                local mix=state.newHoverMix[tag] or 0
                local target=state.hover and 1 or 0
                mix+=(target-mix)*(1-math.exp(-frameDt*12*rate))
                if math.abs(target-mix)<.0001 then mix=target end
                state.newHoverMix[tag]=mix
                local pose=newHoverPose(tag,(now-state.glintAt)*rate,mix,strength[tag])
                rotation+=pose.rotation;x+=pose.x;y+=pose.y;factor*=pose.scale;stretchX*=pose.sx;stretchY*=pose.sy
                spotAlpha+=pose.spot;bloomAlpha+=pose.bloom
            end
        end
        for _,tag in ipairs({'clicksmooth'})do
            if fx[tag] then
                local pose=clickMotionPose(tag,clickTime*speed[tag],strength[tag])
                x+=pose.x;y+=pose.y;rotation+=pose.rotation;factor*=pose.scale;stretchX*=pose.sx;stretchY*=pose.sy
                break -- Shared button punch is applied once when reward bursts are combined.
            end
        end
        -- BEGIN BLOXFIG PRESS POSE
        -- Most layers have no legacy press deformation. Keep their neutral
        -- pose without allocating a result or reading unused design bounds.
        state.pressFxActive=false
        if fx.clickpressure or fx.clicksquash or fx.clickhinge or fx.clickrelease then
            local pressWidth=math.max(1,tonumber(image:GetAttribute('BloxFigBoundsWidth')) or image.AbsoluteSize.X)
            local pressHeight=math.max(1,tonumber(image:GetAttribute('BloxFigBoundsHeight')) or state.designHeight)
            local pressX,pressY=0,0
            if not state.pressKeyboardClick then pressX,pressY=motionPointer(state,state.pressTouchPoint or pointer) end
            local pressPose=pressClickPose(state,fx,state.pressed,now,state.clickedAt,frameDt,speed,strength,pressX,pressY,pressWidth,pressHeight)
            state.pressFxActive=pressPose.active
            x+=pressPose.x;y+=pressPose.y;rotation+=pressPose.rotation;factor*=pressPose.scale;stretchX*=pressPose.sx;stretchY*=pressPose.sy
        end
        -- END BLOXFIG PRESS POSE
        if fx.clickpressure or fx.clicksquash or fx.clickhinge or fx.clickrelease or fx.hoverstretch or fx.clickrubber or fx.clickrock or fx.clickhop or fx.clickrecoil or fx.clickdouble or fx.clickpinch then
            local base=state.size
            image:SetAttribute('BloxFigMotionStretchX',stretchX);image:SetAttribute('BloxFigMotionStretchY',stretchY)
            image.Size=motionSize(state,stretchX,stretchY)
        end
        if state.hoverBloom then state.hoverBloom.ImageTransparency=1-bloomAlpha end
        if state.hoverSpot then
            local width=math.max(1,tonumber(image:GetAttribute('BloxFigBoundsWidth')) or image.AbsoluteSize.X)
            local height=math.max(1,tonumber(image:GetAttribute('BloxFigBoundsHeight')) or image.AbsoluteSize.Y)
            local px,py=motionPointer(state,pointer)
            local r=math.min(width,height)*.28
            local cx,cy=math.clamp(width/2+px,r,width-r),math.clamp(height/2+py,r,height-r)
            local pixelWidth=tonumber(image:GetAttribute('BloxFigImageWidth')) or width*(gui:GetAttribute('ExportScale') or 2)
            local pixelHeight=tonumber(image:GetAttribute('BloxFigImageHeight')) or height*(gui:GetAttribute('ExportScale') or 2)
            state.hoverSpot.Position=UDim2.fromScale((cx-r)/width,(cy-r)/height)
            state.hoverSpot.Size=UDim2.fromScale(2*r/width,2*r/height)
            state.hoverSpot.ImageRectOffset=Vector2.new((cx-r)/width*pixelWidth,(cy-r)/height*pixelHeight)
            state.hoverSpot.ImageRectSize=Vector2.new(2*r/width*pixelWidth,2*r/height*pixelHeight)
            state.hoverSpot.ImageTransparency=1-spotAlpha
        end
        if fx.smooth and state.interactive then
            local wanted = state.pressed and (1 - .055 * strength.smooth) or (state.hover and (1 + .065 * strength.smooth) or 1)
            state.smoothScale += (wanted - state.smoothScale) * (1 - math.exp(-frameDt * 18 * speed.smooth/motionTempo))
            factor *= state.smoothScale
        end
        if fx.hoverzoom and state.interactive then
            local wanted = state.hover and (1 + .11 * strength.hoverzoom) or 1
            state.hoverZoom += (wanted - state.hoverZoom) * (1 - math.exp(-frameDt * 12 * speed.hoverzoom/motionTempo))
            factor *= state.hoverZoom
        end
        if fx.jelly and state.interactive then
            local wanted = state.pressed and (1 - .065 * strength.jelly) or 1
            local step = frameDt * speed.jelly/motionTempo
            state.jellyScale,state.jellyVelocity = motionSpring(state.jellyScale,state.jellyVelocity,wanted,step)
            factor *= state.jellyScale
        end
        if fx.pulse then factor *= 1 + .038 * strength.pulse * (1 - math.cos(elapsed.pulse * tau / 1.35)) / 2 end
        if fx.idleheartbeat then
            local phase = elapsed.idleheartbeat % 2.1
            factor *= heartbeatPulse(elapsed.idleheartbeat,strength.idleheartbeat)
        end
        if fx.breath then factor *= 1 - .025 * strength.breath * math.cos(elapsed.breath * tau / 2.6) end
        if fx.textpulse and state.engineMotion~='textpulse' then factor *= 1 - .015 * strength.textpulse * math.cos(elapsed.textpulse * tau / 3.6) end
        if fx.pop then factor *= 1 - .3 * strength.pop * (1 - easeOutBack(clamp01(elapsed.pop / .55))) end
        if fx.openzoom then factor *= 1-.3*strength.openzoom*(1-easeOutCubic(elapsed.openzoom/.7)) end
        if fx.openbloom then factor *= 1+.09*strength.openbloom*(1-easeOutCubic(elapsed.openbloom/.7)) end
        if fx.opensettle then factor *= 1-.12*strength.opensettle*(1-easeOutBack(clamp01(elapsed.opensettle/.7))) end
        if fx.openflip then factor *= 1-.16*strength.openflip*(1-easeOutCubic(elapsed.openflip/.7)) end
        if fx.clickbounce then
            local click = clickTime * speed.clickbounce
            if click >= 0 and click < .28 then factor *= 1 + .13 * strength.clickbounce * math.sin(click/.28*tau)*math.exp(-2*click/.28) end
        end
        if fx.clickpop then
            local click = clickTime * speed.clickpop
            if click >= 0 and click < .28 then
                local phase = click / .28
                factor *= 1 + .16 * strength.clickpop * math.sin(phase * tau) * math.exp(-2.5 * phase)
            end
        end
        if fx.clicksoft then
            local click = clickTime * speed.clicksoft
            if click >= 0 and click < .24 then factor *= 1-.045*strength.clicksoft*math.sin(math.pi*click/.24)^2 end
        end
        if fx.clicksettle then
            local click = clickTime * speed.clicksettle
            if click >= 0 and click < .26 then
                local phase = click/.26
                factor *= 1-.045*strength.clicksettle*math.sin(phase*math.pi)^2*math.exp(-1.5*phase)
            end
        end
        if fx.hoverlift and state.interactive then
            state.hoverLift += ((state.hover and -7 * strength.hoverlift or 0) - state.hoverLift) * (1 - math.exp(-frameDt * 13 * speed.hoverlift/motionTempo))
            y += state.hoverLift
        end
        if fx.hovermagnet and state.interactive then
            local pointerX,pointerY=motionPointer(state,pointer)
            local targetX = state.hover and math.clamp(pointerX*.11*strength.hovermagnet,-10,10) or 0
            local targetY = state.hover and math.clamp(pointerY*.11*strength.hovermagnet,-8,8) or 0
            local magnetResponse = 1 - math.exp(-frameDt * 13 * speed.hovermagnet/motionTempo)
            state.magnetX += (targetX-state.magnetX)*magnetResponse
            state.magnetY += (targetY-state.magnetY)*magnetResponse
            x += state.magnetX; y += state.magnetY
        end
        if fx.float then y -= 4 * (1 - math.cos(elapsed.float * tau / 2.8)) * strength.float end
        if fx.textfloat and state.engineMotion~='textfloat' then y -= textMotionAmount(image,false)*state.designHeight * (1 - math.cos(elapsed.textfloat * tau / 3.2)) * strength.textfloat end
        if fx.idleorbit then
            x += math.cos(elapsed.idleorbit * tau / 3.6) * 4 * strength.idleorbit
            y += math.sin(elapsed.idleorbit * tau / 3.6) * 3 * strength.idleorbit
        end
        if fx.bounce then y -= 3.5 * (1 - math.cos(elapsed.bounce * tau / 1.8)) * strength.bounce end
        if fx.clicknudge then
            local click = clickTime * speed.clicknudge
            if click >= 0 and click < .22 then y += 6 * strength.clicknudge * math.sin(click / .22 * math.pi) end
        end
        if fx.opendrop then y -= 38*strength.opendrop*(1-easeOutCubic(elapsed.opendrop/.7)) end
        if fx.openrise then y += 36*strength.openrise*(1-easeOutCubic(elapsed.openrise/.7)) end
        if fx.shake then
            local phase = elapsed.shake % 3.3
            if phase < .38 then x += math.sin(phase * 65) * (1 - phase / .38) * 4 * strength.shake end
        end
        if fx.spin then rotation += (elapsed.spin * 90) % 360 end
        if fx.wiggle then rotation += 1.5 * (1 - math.cos(elapsed.wiggle * tau / 1.25)) * strength.wiggle end
        if fx.sway then rotation += 1.5 * (1 - math.cos(elapsed.sway * tau / 3.4)) * strength.sway end
        if fx.openflip then rotation -= 13*strength.openflip*(1-easeOutCubic(elapsed.openflip/.7)) end
        if fx.idlependulum then rotation += 3 * (1 - math.cos(elapsed.idlependulum * tau / 2.5)) * strength.idlependulum end
        if fx.hoverwobble and state.interactive then
            if state.wobbleStopped and not state.pressed and now >= state.wobbleResumeAt then state.wobbleStopped=false end
            state.hoverWobble += ((state.hover and not state.wobbleStopped and 1 or 0) - state.hoverWobble) * (1 - math.exp(-frameDt * 11 * speed.hoverwobble/motionTempo))
            rotation += state.hoverWobble * math.sin(elapsed.hoverwobble * 9) * 2.6 * strength.hoverwobble
        end
        if fx.clickspin then
            local click = clickTime * speed.clickspin
            if click >= 0 and click < .30 then
                local phase = click / .30
                rotation += 360 * (1 - (1 - phase) ^ (2 + strength.clickspin))
            end
        end
        if fx.tilt and state.interactive then
            local target = 0
            if state.hover and image.AbsoluteSize.X > 0 then
                local pointerX,_,width=motionPointer(state,pointer)
                target = math.clamp(pointerX / (width / 2), -1, 1) * 6 * strength.tilt
            end
            state.tilt += (target - state.tilt) * (1 - math.exp(-frameDt * 13 * speed.tilt/motionTempo))
            rotation += state.tilt
        end
        if state.scale and (fx.clicksmooth or fx.clickpressure or fx.clicksquash or fx.clickhinge or fx.clickrelease or fx.clickrubber or fx.clickrock or fx.clickhop or fx.clickrecoil or fx.clickdouble or fx.clickpinch or fx.hoverspring or fx.hoverswing or fx.hoverroll or fx.hoverlean or fx.hoverdouble or fx.hoverstamp or fx.hovericon or fx.hoversmooth or fx.smooth or fx.hoverzoom or fx.jelly or fx.pulse or fx.idleheartbeat or fx.breath or fx.textpulse or fx.pop or fx.clickbounce or fx.clickpop or fx.clicksoft or fx.clicksettle or fx.openzoom or fx.openflip or fx.openbloom or fx.opensettle) then
            local wantedScale = math.clamp(factor, .65, 1.65)
            if state.scale.Scale ~= wantedScale then state.scale.Scale = wantedScale end
        end
        if fx.clickpressure or fx.clicksquash or fx.clickhinge or fx.clickrelease or fx.clickrubber or fx.clickrock or fx.clickhop or fx.clickrecoil or fx.clickdouble or fx.clickpinch or fx.hoverspring or fx.hoverswing or fx.hoverroll or fx.hoverlean or fx.hoverdouble or fx.hoverstamp or fx.hoverhop or fx.hovershake or fx.hoverlift or fx.hovermagnet or fx.float or fx.textfloat or fx.bounce or fx.shake or fx.clicknudge or fx.idleorbit or fx.slidein or fx.textrise or fx.opendrop or fx.openrise then
            local wantedPosition = state.position + motionOffset(state,x,y)
            if image.Position ~= wantedPosition then image.Position = wantedPosition end
        end
        if fx.clickpressure or fx.clicksquash or fx.clickhinge or fx.clickrelease or fx.clickrubber or fx.clickrock or fx.clickhop or fx.clickrecoil or fx.clickdouble or fx.clickpinch or fx.hoverspring or fx.hoverswing or fx.hoverroll or fx.hoverlean or fx.hoverdouble or fx.hovertilt or fx.spin or fx.wiggle or fx.tilt or fx.sway or fx.idlependulum or fx.hoverwobble or fx.clickspin or fx.openflip then
            if image.Rotation ~= rotation then image.Rotation = rotation end
        end
        state.motionX,state.motionY=x,y
        state.motionStretchX,state.motionStretchY=stretchX,stretchY
        local transparency = state.transparency
        if fx.fadein then transparency += (1 - transparency) * (1 - clamp01(elapsed.fadein / .7) ^ strength.fadein) end
        for _, tag in openEffects do
            if fx[tag] then transparency += (1-transparency)*(1-easeOutCubic(elapsed[tag]/.7)) end
        end
        if fx.blink then transparency += (1 - transparency) * .48 * strength.blink * ((1 + math.sin(elapsed.blink * tau / 1.65)) / 2) ^ 8 end
        if fx.breath then transparency += (1 - transparency) * .12 * strength.breath * ((1 - math.cos(elapsed.breath * tau / 2.6)) / 2) end
        if fx.hoverfade and state.interactive then
            state.hoverFade += ((state.hover and (1 - .28 * strength.hoverfade) or 1) - state.hoverFade) * (1 - math.exp(-frameDt * 12 * speed.hoverfade/motionTempo))
            transparency += (1 - transparency) * (1 - state.hoverFade)
        end
        if fx.idletwinkle then transparency += (1 - transparency) * (.09 * strength.idletwinkle * (1 - math.sin(elapsed.idletwinkle * tau / 2.9) ^ 2)) end
        if fx.slidein then
            local phase = clamp01(elapsed.slidein / .65)
            image.Position = state.position + motionOffset(state,x - 36 * strength.slidein * (1 - phase) ^ 2,y)
            transparency += (1 - transparency) * (1 - phase)
        end
        if fx.textrise then
            local phase = clamp01(elapsed.textrise / .9)
            image.Position = state.position + UDim2.fromOffset(x,y) + UDim2.fromScale(0,textFloatY+.18*strength.textrise*(1-phase)^3)
            transparency += (1-transparency)*(1-phase*phase*(3-2*phase))
        end
        if fx.flicker then transparency += (1 - transparency) * .14 * strength.flicker * math.max(0, math.sin(elapsed.flicker * 17) * math.sin(elapsed.flicker * 6)) end
        if fx.fadein or fx.blink or fx.breath or fx.slidein or fx.textrise or fx.flicker or fx.hoverfade or fx.idletwinkle or fx.openzoom or fx.opendrop or fx.openrise or fx.openflip or fx.openbloom or fx.opensettle then
            local wantedTransparency = math.clamp(transparency, 0, 1)
            local fade = math.clamp((wantedTransparency-state.transparency)/math.max(.0001,1-state.transparency),0,1)
            if state.textOutline then state.textOutline.Transparency=state.outlineTransparency+(1-state.outlineTransparency)*fade end
            if state.mask and state.mask:IsA('TextLabel') then
                local outline=state.mask:FindFirstChild('BloxFigGleamOutline');if outline then outline.Transparency=state.outlineTransparency+(1-state.outlineTransparency)*fade end
            end
            if state.nativeText and not state.waveSlices and state.nativeText.TextTransparency ~= wantedTransparency then
                state.nativeText.TextTransparency = wantedTransparency
            elseif not state.waveSlices and (state.visual:IsA('ImageLabel') or state.visual:IsA('ImageButton'))
                and state.visual.ImageTransparency ~= wantedTransparency then
                state.visual.ImageTransparency = wantedTransparency
            end
            if state.mask and state.mask:IsA('TextLabel') and state.mask.TextTransparency ~= wantedTransparency then
                state.mask.TextTransparency = wantedTransparency
            elseif state.mask and state.mask:IsA('ImageLabel') and state.mask.ImageTransparency ~= wantedTransparency then
                state.mask.ImageTransparency = wantedTransparency
            end
        end
        if state.waveSlices and fx.textjelly then
            local letterTransparency = math.clamp((transparency-state.transparency)/math.max(.0001,1-state.transparency),0,1)
            for _,part in ipairs(state.waveSlices) do
                local offset = math.sin(elapsed.textjelly * 2.4 - part.phase) * textMotionAmount(image,true) * strength.textjelly
                if state.engineMotion~='textjelly' and offset ~= part.lastOffset then
                    part.image.Position = UDim2.new(part.x,0,(part.y or 0)+offset,0)
                    part.lastOffset = offset
                end
                if letterTransparency ~= part.lastTransparency then
                    part.visual.ImageTransparency = letterTransparency
                    part.lastTransparency = letterTransparency
                end
            end
        end
        if state.visual:IsA('ImageLabel') or state.visual:IsA('ImageButton') then
            if state.fancyReplacement then
                local opacity=math.clamp((1-transparency)/math.max(.0001,1-state.transparency),0,1)
                for _,part in ipairs(state.fancySprites or {})do if part.replace==1 then part.a*=opacity end end
                state.renderFancy(state.fancySprites or {},state.fancyWidth,state.fancyHeight)
                state.visual.ImageTransparency=1
            elseif state.fancySourceHidden then state.visual.ImageTransparency=math.clamp(transparency,0,1) end
            state.fancySourceHidden=state.fancyReplacement==true
        end
        if state.gradient then
            if fx.glint and not (fx.shiny or fx.textshimmer) and fx.gleam then
                local halfWidth=state.hover and .18 or .27
                local redesign=rainbowLightRedesign(fx)
                if redesign then halfWidth=redesign.halfWidth end
                if halfWidth~=state.lightBandWidth then
                    local opacity=math.min(.94,.8*(strength.gleam or 1))
                    if redesign then opacity=math.min(.94,.8*(strength.gleam or 1)*redesign.opacityScale) end
                    state.gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5-halfWidth,1),NumberSequenceKeypoint.new(.5,1-opacity),NumberSequenceKeypoint.new(.5+halfWidth,1),NumberSequenceKeypoint.new(1,1)})
                    if state.lightStrokeGradient then state.lightStrokeGradient.Transparency=state.gradient.Transparency end
                    if state.waveSlices then for _,part in ipairs(state.waveSlices)do if part.gradient then part.gradient.Transparency=state.gradient.Transparency end end end
                    state.lightBandWidth=halfWidth
                end
            end
            local phase
            local lightEnabled
            if fx.glint and not (fx.gleam or fx.shiny or fx.textshimmer) then
                local hoverProgress=(now-state.glintAt)*speed.glint
                local duration=fx.rainbowglint and 1.2 or 4/3
                phase=hoverProgress/duration
                lightEnabled=state.hover and hoverProgress>=0 and hoverProgress<duration
            elseif state.hover and fx.gleam and now-state.glintAt < .8/math.max(.01,speed.gleam or 1) then
                phase = (now-state.glintAt) * speed.gleam / .8
                lightEnabled = phase >= 0 and phase <= 1
            else
                local cycle = fx.shiny and 2.5 or (fx.textshimmer and 2.1 or 3.2)
                local sweep = fx.shiny and 1.25 or (fx.textshimmer and 1.1 or .9)
                local tag = fx.shiny and 'shiny' or (fx.textshimmer and 'textshimmer' or 'gleam')
                -- A missing or disabled light tag must never stop the shared
                -- RenderStepped loop for every imported layer.
                local progress = (elapsed[tag] or 0) % cycle
                phase = progress / sweep
                lightEnabled = fx[tag] == true and progress < sweep
            end
            local redesignedTag='glint'
            local redesigned=rainbowRedesignPhase(fx,elapsed[redesignedTag] or 0,(now-state.glintAt)*(speed[redesignedTag] or 1),state.hover)
            if redesigned~=nil then phase=redesigned;lightEnabled=redesigned>=0 end
            if fx.textshimmer and hoverLightOwners and hasAncestorHoverSweep(image,hoverLightOwners) then lightEnabled=false end
            local maskLoaded = state.mask:IsA('TextLabel') or state.mask.IsLoaded
            local lightMode = maskLoaded and 'mask' or 'waiting'
            if state.lightMode ~= lightMode then
                state.lightMode = lightMode
                image:SetAttribute('BloxFigLightMode', lightMode)
            end
            -- An unloaded ImageLabel draws no pixels. Show the active sweep
            -- immediately so the renderer requests it; never gate visibility
            -- on IsLoaded, which itself needs a visible render instance.
            local maskVisible = lightEnabled
            if state.gradient.Enabled ~= lightEnabled then state.gradient.Enabled = lightEnabled end
            state.mask.Visible = maskVisible and not state.waveSlices
            if maskVisible then
                local targetX = -1 + phase * 2
                if state.gradient.Offset.X ~= targetX then
                    state.gradient.Offset = Vector2.new(targetX, 0)
                end
            end
        end
        if state.waveSlices and state.gradient then
            for _, part in ipairs(state.waveSlices) do
                if part.mask and part.gradient then
                    part.mask.Visible = state.gradient.Enabled
                    part.gradient.Enabled = state.gradient.Enabled
                    part.gradient.Offset = state.gradient.Offset
                    if part.mask:IsA('ImageLabel') then part.mask.ImageTransparency = math.clamp((transparency-state.transparency)/math.max(.0001,1-state.transparency),0,1) end
                end
            end
        end
        if state.lightStrokeGradient then
            state.lightStrokeGradient.Enabled = state.gradient.Enabled
            state.lightStrokeGradient.Offset = state.gradient.Offset
        end
        if state.shadow and (fx.glow or fx.hoverglow) then
            local glow = fx.glow and (7 + (1 + math.sin(elapsed.glow * math.pi)) * 4) * strength.glow or 0
            if fx.hoverglow and state.hover then glow = math.max(glow, 14 * strength.hoverglow) end
            local active = glow > .5
            if state.shadow.Enabled ~= active then state.shadow.Enabled = active end
            if active and math.abs(state.shadow.BlurRadius.Offset - glow) > .5 then
                state.shadow.BlurRadius = UDim.new(0, glow)
            end
        elseif state.stroke and (fx.glow or fx.hoverglow) then
            local hoverGlow = fx.hoverglow and state.hover
            state.stroke.Thickness = hoverGlow and 3 * strength.hoverglow or (fx.glow and (1.4 + (1 + math.sin(elapsed.glow * tau / 2)) * .7 * strength.glow) or 0)
            state.stroke.Transparency = hoverGlow and .15 or (fx.glow and (.55 + .2 * math.sin(elapsed.glow * tau / 2)) or 1)
        end
    end
    updatePressText(now,true)
end)

