local Players = game:GetService("Players")

local NametagBillboard = script:WaitForChild("Nametag")
local NametagText = NametagBillboard:WaitForChild("Username")

NametagText.TextColor3 = Color3.fromRGB(255, 255, 255)
NametagText.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

local function onCharacterAdded(character)
	local player = Players:GetPlayerFromCharacter(character)
	if not player then return end

	local head = character:WaitForChild("Head")
	local newTag = NametagBillboard:Clone()

	newTag.Username.Text = player.DisplayName
	newTag.Parent = head
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(onCharacterAdded)
	if player.Character then
		onCharacterAdded(player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end
