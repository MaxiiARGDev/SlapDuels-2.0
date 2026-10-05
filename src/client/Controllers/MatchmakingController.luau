--!strict
-- MatchmakingController
-- Controlador del HUD de matchmaking genérico (1v1, 2v2, 3v3).
-- Controla la visualización de PlayerGui.MatchmakingHUD basándose en los QueueSnapshots
-- emitidos autoritativamente por el servidor. NO crea la interfaz mediante código.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

type QueueSnapshot = Types.QueueSnapshot

local localPlayer = Players.LocalPlayer

local MatchmakingController = {}
MatchmakingController.Name = "MatchmakingController"

-- Referencias a instancias de PlayerGui.MatchmakingHUD
MatchmakingController._hud = nil :: ScreenGui?
MatchmakingController._queueFrame = nil :: Frame?
MatchmakingController._title = nil :: TextLabel?
MatchmakingController._statusBadge = nil :: TextLabel?
MatchmakingController._redTeamHeader = nil :: TextLabel?
MatchmakingController._blueTeamHeader = nil :: TextLabel?
MatchmakingController._redSlotsContainer = nil :: Frame?
MatchmakingController._blueSlotsContainer = nil :: Frame?
MatchmakingController._slotTemplate = nil :: Frame?

MatchmakingController._redSlotClones = {} :: { Frame }
MatchmakingController._blueSlotClones = {} :: { Frame }
MatchmakingController._currentZone = nil :: string?
MatchmakingController._context = nil :: any
MatchmakingController._isInQueue = false

function MatchmakingController:Init(context)
	self._context = context
	self:_cleanupLegacyPadMusic()
	self:_bindHUD()
end

function MatchmakingController:IsInQueue(): boolean
	return self._isInQueue
end

function MatchmakingController:Start(context)
	self._context = context
	self:_connectRemotes()
	print("[MatchmakingController] Controlador de matchmaking iniciado y enlazado a PlayerGui.MatchmakingHUD")
end

function MatchmakingController:_bindHUD()
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("MatchmakingHUD", 15) :: ScreenGui?
	if not hud then
		warn("[MatchmakingController] No se encontro MatchmakingHUD en PlayerGui")
		return
	end
	self._hud = hud

	local queueFrame = hud:WaitForChild("QueueFrame", 10) :: Frame?
	if not queueFrame then
		warn("[MatchmakingController] No se encontro QueueFrame en MatchmakingHUD")
		return
	end
	self._queueFrame = queueFrame
	queueFrame.Visible = false

	local header = queueFrame:FindFirstChild("Header") :: Frame?
	if header then
		self._title = header:FindFirstChild("Title") :: TextLabel?
		self._statusBadge = header:FindFirstChild("StatusBadge") :: TextLabel?
	end

	local content = queueFrame:FindFirstChild("Content") or queueFrame
	local redSide = content:FindFirstChild("RedTeam") or content:FindFirstChild("LocalTeam")
	local blueSide = content:FindFirstChild("BlueTeam") or content:FindFirstChild("OpponentTeam")

	if redSide then
		local header = redSide:FindFirstChild("TeamLabel") or redSide:FindFirstChild("TeamHeader")
		if header and header:IsA("TextLabel") then
			header.Visible = false
		end
		self._redTeamHeader = nil
		self._redSlotsContainer = redSide:FindFirstChild("SlotsContainer") :: Frame?
	end

	if blueSide then
		local header = blueSide:FindFirstChild("TeamLabel") or blueSide:FindFirstChild("TeamHeader")
		if header and header:IsA("TextLabel") then
			header.Visible = false
		end
		self._blueTeamHeader = nil
		self._blueSlotsContainer = blueSide:FindFirstChild("SlotsContainer") :: Frame?
	end

	local template = queueFrame:FindFirstChild("PlayerSlotTemplate", true) :: Frame?
	if template then
		self._slotTemplate = template
		template.Visible = false
	end
end

function MatchmakingController:_connectRemotes()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 10)
	if not remotes then return end

	local mmFolder = remotes:WaitForChild("Matchmaking", 10)
	if mmFolder then
		local queueRemote = mmFolder:WaitForChild("QueueStatus", 10) :: RemoteEvent?
		if queueRemote then
			queueRemote.OnClientEvent:Connect(function(snapshot: QueueSnapshot)
				self:_handleQueueStatus(snapshot)
			end)
		end
	end

	-- Ocultar el HUD de matchmaking cuando la partida pasa a fases activas
	local matchFolder = remotes:WaitForChild("Match", 10)
	if matchFolder then
		local stateChanged = matchFolder:WaitForChild("StateChanged", 10) :: RemoteEvent?
		if stateChanged then
			stateChanged.OnClientEvent:Connect(function(newState: string)
				if newState ~= "Waiting" then
					if self._queueFrame then
						self._queueFrame.Visible = false
					end
					self._isInQueue = false
				end
			end)
		end
	end
end

-- Limpia los slots clonados previos
function MatchmakingController:_clearSlots()
	for _, slot in ipairs(self._redSlotClones) do
		slot:Destroy()
	end
	self._redSlotClones = {}

	for _, slot in ipairs(self._blueSlotClones) do
		slot:Destroy()
	end
	self._blueSlotClones = {}
end

-- Limpieza defensiva de cualquier audio de pad residual en SoundService
function MatchmakingController:_cleanupLegacyPadMusic()
	local SoundService = game:GetService("SoundService")
	local old = SoundService:FindFirstChild("LocalMatchmakingPadMusic")
	if old then
		if old:IsA("Sound") and old.IsPlaying then
			old:Stop()
		end
		old:Destroy()
	end
end

-- Determina si el jugador local forma parte de la lista de un equipo
local function isPlayerInList(player: Player, list: { Player }): boolean
	for _, p in ipairs(list) do
		if p == player then return true end
	end
	return false
end

function MatchmakingController:_handleQueueStatus(snapshot: QueueSnapshot)
	if not self._queueFrame or not self._slotTemplate then
		self:_bindHUD()
		if not self._queueFrame or not self._slotTemplate then return end
	end

	local inRed = isPlayerInList(localPlayer, snapshot.Red)
	local inBlue = isPlayerInList(localPlayer, snapshot.Blue)
	local isParticipant = inRed or inBlue
	local snapshotZoneId = snapshot.ZoneId or snapshot.ZoneName

	if isParticipant then
		self._currentZone = snapshotZoneId
		self._queueFrame.Visible = true

		if not self._isInQueue then
			self._isInQueue = true
			local musicController = self._context and self._context:GetController("MusicController")
			if musicController then
				musicController:PlayMatchmaking()
			end
		end
	else
		-- El jugador no es participante de este snapshot recibido.
		-- ÚNICAMENTE cerramos el HUD si el snapshot proviene de la zona que el jugador estaba siguiendo actualmente.
		if self._currentZone ~= nil and self._currentZone == snapshotZoneId then
			self._queueFrame.Visible = false
			self:_clearSlots()
			self._currentZone = nil

			if self._isInQueue then
				self._isInQueue = false
				local matchController = self._context and self._context:GetController("MatchController")
				local inMatch = matchController and typeof(matchController.IsParticipant) == "function" and matchController:IsParticipant()
				if not inMatch then
					local musicController = self._context and self._context:GetController("MusicController")
					if musicController then
						musicController:PlayLobby()
					end
				end
			end
		end
		-- Si el snapshot pertenece a otra zona diferente donde el jugador no está, se ignora completamente
		return
	end

	-- 1. Actualizar Título y Estado
	if self._title then
		self._title.Text = string.format("COLA %s", string.upper(snapshot.Mode))
	end

	if self._statusBadge then
		if snapshot.State == "READY" then
			self._statusBadge.Text = "¡PARTIDA LISTA!"
			self._statusBadge.TextColor3 = Color3.fromRGB(120, 255, 160)
			self._statusBadge.BackgroundColor3 = Color3.fromRGB(20, 50, 30)
		else
			local currentTotal = #snapshot.Red + #snapshot.Blue
			self._statusBadge.Text = string.format("ESPERANDO (%d/%d)", currentTotal, snapshot.TotalPlayers)
			self._statusBadge.TextColor3 = Color3.fromRGB(180, 205, 255)
			self._statusBadge.BackgroundColor3 = Color3.fromRGB(30, 40, 60)
		end
	end

	-- 2. Renderizar Slots de cada lado (Lado Izquierdo = Red, Lado Derecho = Blue)
	self:_clearSlots()

	if self._redSlotsContainer then
		for i = 1, snapshot.TeamSize do
			local player = snapshot.Red[i]
			local slot = self:_createSlotInstance(player, "Red")
			slot.Parent = self._redSlotsContainer
			table.insert(self._redSlotClones, slot)
		end
	end

	if self._blueSlotsContainer then
		for i = 1, snapshot.TeamSize do
			local player = snapshot.Blue[i]
			local slot = self:_createSlotInstance(player, "Blue")
			slot.Parent = self._blueSlotsContainer
			table.insert(self._blueSlotClones, slot)
		end
	end
end

-- Clona y configura una instancia del template de slot de jugador
function MatchmakingController:_createSlotInstance(player: Player?, teamName: string): Frame
	local slot = self._slotTemplate:Clone() :: Frame
	slot.Name = "Slot_" .. (player and player.Name or "Empty")

	local nameLabel = slot:FindFirstChild("NameLabel", true) :: TextLabel?
	local body = slot:FindFirstChild("Body") or slot
	local occupied = body:FindFirstChild("Occupied") :: Frame?
	local empty = body:FindFirstChild("Empty") :: Frame?

	local avatarImg = (occupied and occupied:FindFirstChild("Avatar", true)) :: ImageLabel?
		or (slot:FindFirstChild("Avatar", true) :: ImageLabel?)
	local displayName = (occupied and occupied:FindFirstChild("DisplayName", true)) :: TextLabel?
		or (slot:FindFirstChild("DisplayName", true) :: TextLabel?)
	local username = (occupied and occupied:FindFirstChild("Username", true)) :: TextLabel?
		or (slot:FindFirstChild("Username", true) :: TextLabel?)
	local occupiedStroke = (occupied and occupied:FindFirstChildOfClass("UIStroke"))
		or slot:FindFirstChildOfClass("UIStroke")
	local emptyStroke = empty and empty:FindFirstChildOfClass("UIStroke")
	local questionMark = empty and empty:FindFirstChild("QuestionMark", true) :: TextLabel?

	local teamColor = if teamName == "Red"
		then Color3.fromRGB(235, 65, 80)
		else Color3.fromRGB(65, 140, 245)

	-- Creación defensiva de NameLabel si no existe en el template
	if not nameLabel then
		local newLabel = Instance.new("TextLabel")
		newLabel.Name = "NameLabel"
		newLabel.Size = UDim2.new(1.3, 0, 0, 16)
		newLabel.Position = UDim2.new(0.5, 0, 0, -4)
		newLabel.AnchorPoint = Vector2.new(0.5, 1)
		newLabel.BackgroundTransparency = 1
		newLabel.Font = Enum.Font.GothamBold
		newLabel.TextScaled = true
		newLabel.ZIndex = 5

		local tc = Instance.new("UITextSizeConstraint")
		tc.MaxTextSize = 14
		tc.MinTextSize = 9
		tc.Parent = newLabel

		local st = Instance.new("UIStroke")
		st.Color = Color3.fromRGB(0, 0, 0)
		st.Thickness = 1.2
		st.Transparency = 0.2
		st.Parent = newLabel

		newLabel.Parent = slot
		nameLabel = newLabel
	end

	-- Creación defensiva de QuestionMark en Empty si no existe
	if empty and not questionMark then
		local qm = Instance.new("TextLabel")
		qm.Name = "QuestionMark"
		qm.Size = UDim2.new(0.6, 0, 0.6, 0)
		qm.Position = UDim2.new(0.5, 0, 0.5, 0)
		qm.AnchorPoint = Vector2.new(0.5, 0.5)
		qm.BackgroundTransparency = 1
		qm.Font = Enum.Font.GothamBold
		qm.Text = "?"
		qm.TextColor3 = Color3.fromRGB(80, 95, 125)
		qm.TextScaled = true
		qm.ZIndex = 3
		qm.Parent = empty
		questionMark = qm
	end

	if player then
		if occupied then occupied.Visible = true end
		if empty then empty.Visible = false end

		local pDisplayName = if player.DisplayName and player.DisplayName ~= "" then player.DisplayName else player.Name
		local pUsername = "@" .. player.Name

		-- Nombre visible encima del recuadro
		if nameLabel then
			nameLabel.Text = pDisplayName
			nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			nameLabel.Visible = true
		end

		if displayName then
			displayName.Text = pDisplayName
			displayName.Visible = false -- Nombre principal está arriba del recuadro
		end

		if username then
			username.Text = pUsername
			username.Visible = false
		end

		if avatarImg then
			-- Avatar real del jugador mediante thumbnail oficial de Roblox
			avatarImg.Image = string.format("rbxthumb://type=AvatarBust&id=%d&w=150&h=150", player.UserId)
			avatarImg.Visible = true
		end

		if occupiedStroke then
			occupiedStroke.Color = teamColor
			occupiedStroke.Thickness = 1.5
		end
	else
		-- Estado cuando todavía no hay rival o slot vacío
		if occupied then occupied.Visible = false end
		if empty then empty.Visible = true end

		if nameLabel then
			nameLabel.Text = "ESPERANDO..."
			nameLabel.TextColor3 = Color3.fromRGB(130, 145, 175)
			nameLabel.Visible = true
		end

		if displayName then
			displayName.Text = "ESPERANDO..."
			displayName.TextColor3 = Color3.fromRGB(130, 145, 175)
			displayName.Visible = false
		end

		if username then
			username.Visible = false
		end

		if avatarImg then
			avatarImg.Visible = false
		end

		if questionMark then
			questionMark.Text = "?"
			questionMark.Visible = true
		end

		local spinner = empty and empty:FindFirstChild("Spinner")
		if spinner then
			spinner.Visible = false
		end

		if emptyStroke then
			emptyStroke.Color = Color3.fromRGB(45, 55, 75)
			emptyStroke.Thickness = 1
		end
	end

	slot.Visible = true
	return slot
end

return MatchmakingController
