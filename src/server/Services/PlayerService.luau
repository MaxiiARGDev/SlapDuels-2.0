--!strict
-- PlayerService
-- Ciclo de vida de jugadores: registro/desregistro y preparacion para futuras estadisticas.
-- NO implementa DataStore en esta fase.

local Players = game:GetService("Players")

local PlayerService = {}

PlayerService.Name = "PlayerService"

PlayerService._registered = {}
PlayerService._connections = {}

function PlayerService:Init(context)
	self._registered = {}
	self._connections = {}
end

function PlayerService:_register(player: Player)
	self._registered[player] = {}
	print(string.format("[PlayerService] Registrado: %s", player.Name))
end

function PlayerService:_unregister(player: Player)
	self._registered[player] = nil
	print(string.format("[PlayerService] Desregistrado: %s", player.Name))
end

function PlayerService:Start(context)
	table.insert(self._connections, Players.PlayerAdded:Connect(function(player)
		self:_register(player)
	end))
	table.insert(self._connections, Players.PlayerRemoving:Connect(function(player)
		self:_unregister(player)
	end))

	for _, player in ipairs(Players:GetPlayers()) do
		self:_register(player)
	end
end

return PlayerService
