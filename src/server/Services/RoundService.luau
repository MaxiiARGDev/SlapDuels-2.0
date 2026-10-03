--!strict
-- RoundService
-- En fases posteriores manejara la maquina de estados de las partidas.
-- En esta fase solo existe su estructura publica (Init/Start) sin logica de rondas.

local RoundService = {}

RoundService.Name = "RoundService"

-- Referencia controlada al estado actual (aun sin maquina de estados).
RoundService._state = nil

function RoundService:Init(context)
	self._state = nil
end

function RoundService:Start(context)
end

return RoundService
