--!nonstrict
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local RS=game:GetService("ReplicatedStorage")
local Config=require(RS.Shared.SlapCrates.OpeningConfig)
local Timeline=require(RS.Shared.SlapCrates.OpeningTimeline)
local Ledger=require(script.Parent.StandOpeningLedger)
local Batch=require(RS.Shared.SlapCrates.BatchOpening)
local Service={};Service.__index=Service
function Service.new(owner)
 local plan,errorCode=Timeline.Build(Config)
 return setmetatable({Owner=owner,Plan=plan,Error=errorCode,Connections={},Prompts={},
  Ledger=plan and Ledger.new(Config,plan,os.clock),Active={},AccessRate={}},Service)
end
function Service:IsStandMode()return Config.Mode=="StandCinematic"end
function Service:Context()return {Mode=if self.Error then "Disabled"else Config.Mode,AllowedOpenQuantities=Config.AllowedOpenQuantities}end
function Service:FindStand(id)
 if type(id)~="string"or #id>64 then return nil end
 local folder=workspace:FindFirstChild("CrateStands");local found
 for _,model in ipairs(folder and folder:GetChildren()or {})do
  if model:IsA("Model")and model:GetAttribute("StandId")==id then if found then return nil end;found=model end
 end
 if not found or found:GetAttribute("Enabled")==false then return nil end
 for _,name in ipairs({"InteractionPart","SpawnPoint","CameraPoint","RewardPoint"})do
  local part=found:FindFirstChild(name);if not part or not part:IsA("BasePart")then return nil end
 end
 return found
end
function Service:Validate(player,id)
 if self.Error then return nil,self.Error end
 if not self:IsStandMode()or not Config.Stand.Enabled then return nil,"StandDisabled"end
 if not self.Owner:_lobby(player)then return nil,"LobbyOnly"end
 local model=self:FindStand(id);if not model then return nil,"InvalidStandId"end
 local char=player.Character;local root=char and char:FindFirstChild("HumanoidRootPart")
 local hum=char and char:FindFirstChildOfClass("Humanoid")
 if not root or not hum or hum.Health<=0 then return nil,"CharacterUnavailable"end
 local distance=(root.Position-model.InteractionPart.Position).Magnitude
 if distance~=distance or distance>Config.Stand.MaxActivationDistance then return nil,"StandTooFar"end
 return model
end
function Service:Release(userId,reason)
 local row=self.Ledger and self.Ledger:Release(userId)
 local visual=self.Active[userId];self.Active[userId]=nil
 if visual then
  for _,observer in ipairs(visual.Audience)do if observer.Parent==Players then
   local untilAt=self.Ledger.Cooldowns[tostring(userId)..":"..visual.Packet.StandId]
   self.Remote:FireClient(observer,{Kind="Cancel",OpeningId=visual.Packet.OpeningId,StandId=visual.Packet.StandId,Reason=reason,
    CooldownUntil=if observer.UserId==userId and untilAt then workspace:GetServerTimeNow()+math.max(0,untilAt-os.clock())else nil})
  end end
 end
 return row
end
function Service:Open(player,args,callback)
 if self.Error then return {Ok=false,Code=self.Error}end
 if not self:IsStandMode()then return callback()end
 local model,why=self:Validate(player,args.StandId);if not model then return {Ok=false,Code=why}end
 local quantity=Batch.Quantity(args.Quantity);if not quantity then return {Ok=false,Code="InvalidQuantity"}end
 local plan,planError=Timeline.Build(Config,quantity);if not plan then return {Ok=false,Code=planError}end
 local row,code=self.Ledger:Acquire(player.UserId,args.StandId,args.OperationId,plan)
 if not row then return {Ok=false,Code=code}end
 if not row.Player then row.Player=player;row.Character=player.Character end
 local ok,result=pcall(callback)
 if not ok then self:Release(player.UserId,"TransactionError");error(result)end
 -- Eligibility may yield. Present revalidates the lease, character, stand and distance.
 if not result.Ok or(result.Replay and not row.Committed)then self:Release(player.UserId,"NoNewPresentation")end
 result.Presentation={Mode="StandCinematic",OpeningId=result.Operation and result.Operation.UnitId}
 return result
end
function Service:Cancel(player,openingId)
 local visual=self.Active[player.UserId]
 if not visual then return {Ok=true}end
 if visual.Packet.OpeningId~=openingId then return {Ok=false,Code="OpeningMismatch"}end
 self:Release(player.UserId,"ClientCancelled")
 return {Ok=true}
end
function Service:Present(player,crate,op)
 local row=self.Ledger.Players[player.UserId]
 if not row or row.OperationId~=op.OperationId then return end
 -- This method is called after the existing economic commit, even if visuals cannot start.
 if not self.Ledger:Commit(row,op.UnitId)then return end
 local model=self:Validate(player,row and row.StandId)
 if row.Character~=player.Character or not model then
  self:Release(player.UserId,"PresentationUnavailable");return
 end
 local packet={Kind="Opening",Mode="StandCinematic",StandId=row.StandId,OpeningId=op.UnitId,
  Operation={RewardId=op.RewardId,CrateId=crate.CrateId,SlapId=op.SlapId,VariationId=op.VariationId,Quantity=op.Quantity or 1,Rewards=op.Rewards and table.clone(op.Rewards)},
  StartedAt=workspace:GetServerTimeNow(),Duration=row.Plan.Duration,BuyerUserId=player.UserId,
  Exclusive=Config.Stand.ExclusiveOpening,Model=crate.Model}
 local audience={player}
 if Config.Stand.ExclusiveOpening then for _,other in ipairs(Players:GetPlayers())do
  local root=other.Character and other.Character:FindFirstChild("HumanoidRootPart")
  if other~=player and root and self.Owner:_lobby(other)and(root.Position-model.InteractionPart.Position).Magnitude<=Config.Stand.SpectatorRadius then table.insert(audience,other)end
 end end
 self.Active[player.UserId]={Packet=packet,Audience=audience,Character=player.Character}
 for _,other in ipairs(audience)do self.Remote:FireClient(other,packet)end
end
function Service:SyncStands()
 local folder=workspace:FindFirstChild("CrateStands")
 for _,model in ipairs(folder and folder:GetChildren()or {})do
  local id=model:GetAttribute("StandId");local valid=self:FindStand(id)==model
  local part=model:FindFirstChild("InteractionPart");local prompt=part and part:FindFirstChildWhichIsA("ProximityPrompt")
  if prompt then
   prompt.Enabled=valid and not self.Error and self:IsStandMode()and Config.Stand.Enabled
   if not self.Prompts[prompt]then
    self.Prompts[prompt]=prompt.Triggered:Connect(function(player)
     local now=os.clock();if now<(self.AccessRate[player]or 0)then return end;self.AccessRate[player]=now+.5
     local stand=self:Validate(player,model:GetAttribute("StandId"));if not stand then return end
     self.Remote:FireClient(player,{Kind="Access",StandId=model:GetAttribute("StandId"),Mode=Config.Mode})
    end)
   end
  end
  local lease=self.Ledger and self.Ledger.Stands[id]
  local state=lease and lease.State or "Idle"
  if model:GetAttribute("OpeningState")~=state then model:SetAttribute("OpeningState",state)end
  local anchor=model:FindFirstChild("BillboardAnchor");local gui=anchor and anchor:FindFirstChild("BillboardGui")
  local status=gui and gui:FindFirstChild("Status",true)
  local title=gui and gui:FindFirstChild("Title",true);local subtitle=gui and gui:FindFirstChild("Price",true)
  if title then title.Text=if state~="Idle"then "APERTURA EN CURSO"else "CAJAS"end
  if subtitle then subtitle.Text=if state~="Idle"then "Esperá tu turno"else "Abrí cajas y conseguí slaps exclusivos"end
  if status then status.Text=if state~="Idle"then "EN USO"elseif not valid then "STAND NO DISPONIBLE"else "VER PRECIOS Y PROBABILIDADES"end
 end
 for prompt,connection in pairs(self.Prompts)do if not prompt:IsDescendantOf(workspace)then connection:Disconnect();self.Prompts[prompt]=nil end end
end
function Service:Start(remote)
 self.Remote=remote;self:SyncStands()
 local last=0
 table.insert(self.Connections,RunService.Heartbeat:Connect(function()
  if os.clock()-last<.25 then return end;last=os.clock()
  if self.Ledger then
   for _,row in ipairs(self.Ledger:Step())do self:Release(row.UserId,"Completed")end
   for id,row in pairs(self.Ledger.Players)do
    if not row.Player or row.Player.Character~=row.Character or not self:Validate(row.Player,row.StandId)then self:Release(id,"ContextChanged")end
   end
   for _,visual in pairs(self.Active)do
    if visual.Packet.Exclusive then
     local model=self:FindStand(visual.Packet.StandId)
     if model then for _,other in ipairs(Players:GetPlayers())do
      local root=other.Character and other.Character:FindFirstChild("HumanoidRootPart")
      if root and self.Owner:_lobby(other)and(root.Position-model.InteractionPart.Position).Magnitude<=Config.Stand.SpectatorRadius
       and not table.find(visual.Audience,other)then
       table.insert(visual.Audience,other);self.Remote:FireClient(other,visual.Packet)
      end
     end end
    end
   end
  end
  self:SyncStands()
 end))
 table.insert(self.Connections,Players.PlayerRemoving:Connect(function(player)self:Release(player.UserId,"Disconnected");self.AccessRate[player]=nil end))
end
return Service
