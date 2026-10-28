local Players = game:GetService('Players')
local ServerStorage = game:GetService('ServerStorage')
local ragdollModule = nil -- call ragdoll module here

local function main(v: Humanoid?)
	if not v:IsA('Humanoid') or not v.Parent then return end
	local character = v.Parent
	local player = Players:GetPlayerFromCharacter(character)
	if not script:GetAttribute('NPCs') and not player then return end
	character:SetAttribute('Ragdoll', false)
	local function onGetAttributeChangedSignal()
		if character:GetAttribute('Ragdoll') then
			if ragdollModule then ragdollModule.ragdoll(character) end
		else
			if ragdollModule then ragdollModule.unRagdoll(character) end
		end
	end
	character:GetAttributeChangedSignal('Ragdoll'):Connect(onGetAttributeChangedSignal)
	v.BreakJointsOnDeath = false
	local function onDied()
		-- ragdoll
	end
	v.Died:Once(onDied)
end

workspace.DescendantAdded:Connect(main)

for _, v in workspace:GetDescendants() do
	main(v)
end
