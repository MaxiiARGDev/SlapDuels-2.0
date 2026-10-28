--!nonstrict
local Players=game:GetService("Players");local RS=game:GetService("ReplicatedStorage")
local Config=require(RS.Shared.PremiumShop.PremiumShopConfig)
local Service={Name="CoinShopAccessService"}
function Service:Init(context)self.Context=context;self.Connections={};self.Rate={}end
function Service:Validate(player,part,prompt)
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 local rounds=self.Context:GetService("RoundService")
 return player.Parent==Players and part==self.Part and prompt==self.Prompt and part:IsDescendantOf(workspace)
  and prompt.Parent==part and prompt.Enabled and root and hum and hum.Health>0 and (root.Position-part.Position).Magnitude<=math.min(Config.CoinShopDistance,prompt.MaxActivationDistance)
  and not player:GetAttribute("MatchId")and not player:GetAttribute("ResultsSessionId")and rounds and not rounds:GetSessionForPlayer(player)
end
function Service:Start()
 local shops=workspace:FindFirstChild("Shops");local shop=shops and shops:FindFirstChild("CoinShop")
 self.Part=shop and shop:FindFirstChild("InteractionPart");self.Prompt=self.Part and self.Part:FindFirstChildWhichIsA("ProximityPrompt")
 if not self.Prompt then warn("[CoinShop] Missing Edit shop");return end
 local remotes=RS:WaitForChild("Remotes"):WaitForChild("Shop")
 local remote=remotes:FindFirstChild("CoinShopAccess")or Instance.new("RemoteEvent");remote.Name="CoinShopAccess";remote.Parent=remotes
 table.insert(self.Connections,self.Prompt.Triggered:Connect(function(player)
  if os.clock()<(self.Rate[player]or 0)or not self:Validate(player,self.Part,self.Prompt)then return end
  self.Rate[player]=os.clock()+.5;remote:FireClient(player)
 end))
 table.insert(self.Connections,Players.PlayerRemoving:Connect(function(p)self.Rate[p]=nil end))
end
return Service
