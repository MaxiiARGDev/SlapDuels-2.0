--!strict
-- LeaderboardService
-- Servicio autoritativo para gestionar y sincronizar las 3 pantallas de Tops en el Lobby:
-- 1. Top Wins (Screen_TopWins)
-- 2. Top Kills (Screen_TopKills)
-- 3. Top Rachas (Screen_TopRachas)
-- Utiliza OrderedDataStore en producción y sincroniza estadísticas reales al entrar/salir.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local DataStoreService = game:GetService("DataStoreService")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local LeaderboardService = {}
LeaderboardService.Name = "LeaderboardService"

LeaderboardService._context = nil :: any
LeaderboardService._playerService = nil :: any
LeaderboardService._playerDataService = nil :: any
LeaderboardService._isStudio = true
LeaderboardService._usernameCache = {} :: { [number]: string }
LeaderboardService._stores = {} :: { [string]: any }
LeaderboardService._refreshInterval = 60

local ORDERED_STORE_NAMES = {
	Wins = "SlapDuels_TopWins_v1",
	Kills = "SlapDuels_TopKills_v1",
	Rachas = "SlapDuels_TopRachas_v1",
}

local SCREEN_MAPPING = {
	Wins = {
		ModelName = "TopWins",
		PartName = "Screen_TopWins",
		GuiName = "SurfaceGui_TopWins",
		IconAllName = "Top_All_Wins",
		Title = "🏆 TOP VICTORIAS",
		Subtitle = "TOP 50 GLOBAL - WINS",
		StatCol = "VICTORIAS",
		SampleBase = 2500,
	},
	Kills = {
		ModelName = "TopKills",
		PartName = "Screen_TopKills",
		GuiName = "SurfaceGui_TopKills",
		IconAllName = "Top_All_Kills",
		Title = "💀 TOP ELIMINACIONES",
		Subtitle = "TOP 50 GLOBAL - KILLS",
		StatCol = "ELIMINACIONES",
		SampleBase = 8400,
	},
	Rachas = {
		ModelName = "TopRachas",
		PartName = "Screen_TopRachas",
		GuiName = "SurfaceGui_TopRachas",
		IconAllName = "Top_All_Streak",
		Title = "🔥 TOP RACHAS",
		Subtitle = "3 VICTORIAS = 1 RACHA",
		StatCol = "RACHAS",
		SampleBase = 450,
	},
}

local MOCK_NAMES = {
	"MaxiiDJ4K", "SlapMaster_99", "Nexus_Vortex", "ShadowNinja", "GhostRecon",
	"TitanSlayer", "BlazeGamer", "CyberWolf", "FrostByte", "EchoStrike",
	"RoguePhantom", "DarkMatter", "SolarFlare", "QuantumLeap", "ViperStrike",
	"ThunderBolt", "IronClad", "VelocityX", "StormRider", "PhoenixRise"
}

-- Función para resolver nombre de usuario con cache para evitar saturar rate limits
function LeaderboardService:_getPlayerName(userId: number): string
	if self._usernameCache[userId] then
		return self._usernameCache[userId]
	end

	local localPlayer = Players:GetPlayerByUserId(userId)
	if localPlayer then
		self._usernameCache[userId] = localPlayer.Name
		return localPlayer.Name
	end

	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)

	if ok and type(name) == "string" and name ~= "" then
		self._usernameCache[userId] = name
		return name
	end

	local fallback = "Player_" .. tostring(userId)
	self._usernameCache[userId] = fallback
	return fallback
end

function LeaderboardService:_formatNumber(val: number): string
	local formatted = tostring(math.floor(val))
	while true do
		local k
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then break end
	end
	return formatted
end

function LeaderboardService:_getIcons()
	local iconsFolder = ServerStorage:FindFirstChild("Assets") and ServerStorage.Assets:FindFirstChild("Icons")
	if not iconsFolder then return nil end
	return {
		Top_1 = iconsFolder:FindFirstChild("Top_1"),
		Top_2 = iconsFolder:FindFirstChild("Top_2"),
		Top_3 = iconsFolder:FindFirstChild("Top_3"),
		Top_All_Wins = iconsFolder:FindFirstChild("Top_All_Wins"),
		Top_All_Kills = iconsFolder:FindFirstChild("Top_All_Kills"),
		Top_All_Streak = iconsFolder:FindFirstChild("Top_All_Streak"),
	}
end

-- ==================================================
-- INICIALIZACIÓN Y CICLO DE VIDA
-- ==================================================

function LeaderboardService:Init(context: any)
	self._context = context
	self._isStudio = RunService:IsStudio()
	self._usernameCache = {}
	self._stores = {}

	-- Inicializar OrderedDataStores
	for statKey, storeName in pairs(ORDERED_STORE_NAMES) do
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(storeName)
		end)
		if ok and store then
			self._stores[statKey] = store
		else
			warn(string.format("[LeaderboardService] No se pudo inicializar OrderedDataStore '%s'", storeName))
		end
	end
end

function LeaderboardService:Start(context: any)
	self._playerService = context and context.PlayerService or nil
	self._playerDataService = context and context.PlayerDataService or nil

	-- 1. Al entrar un jugador: esperar sus datos y sincronizar su récord real
	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			local ps = self._playerService or (self._context and self._context.PlayerService)
			local attempts = 0
			while attempts < 25 and (not ps or not ps._data or not ps._data[player]) do
				attempts += 1
				task.wait(1)
				if not self._playerService and self._context then
					self._playerService = self._context.PlayerService
				end
				ps = self._playerService
			end

			if player.Parent then
				self:UpdatePlayerRecords(player)
				task.wait(2)
				self:RefreshAllLeaderboards()
			end
		end)
	end)

	-- 2. Al salir un jugador: guardar su récord final
	Players.PlayerRemoving:Connect(function(player)
		self:UpdatePlayerRecords(player)
	end)

	-- 3. Registrar jugadores que ya estén presentes
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:UpdatePlayerRecords(player)
		end)
	end

	-- 4. Tarea periódica de guardado y refresco de pantallas
	task.spawn(function()
		task.wait(3)
		self:UpdateAllConnectedPlayers()
		self:RefreshAllLeaderboards()

		while true do
			task.wait(self._refreshInterval)
			self:UpdateAllConnectedPlayers()
			self:RefreshAllLeaderboards()
		end
	end)

	print("[LeaderboardService] Servicio de Leaderboards físicos activo y listo.")
end

-- Actualiza todos los jugadores conectados en el servidor
function LeaderboardService:UpdateAllConnectedPlayers()
	for _, player in ipairs(Players:GetPlayers()) do
		self:UpdatePlayerRecords(player)
	end
end

-- Actualiza los 3 puntajes del jugador en los OrderedDataStore
function LeaderboardService:UpdatePlayerRecords(player: Player)
	if not player or not player.UserId or player.UserId <= 0 then
		return
	end

	local ps = self._playerService or (self._context and self._context.PlayerService)
	if not ps then return end

	local wins = 0
	local kills = 0
	local racha = 0

	pcall(function()
		wins = ps:GetWins(player)
		kills = ps:GetKills(player)
		local data = ps._data and ps._data[player]
		racha = (data and data.WinStreak and data.WinStreak.Total) or 0
	end)

	local userIdStr = tostring(player.UserId)

	task.spawn(function()
		if self._stores.Wins then
			pcall(function() self._stores.Wins:SetAsync(userIdStr, math.max(0, wins)) end)
		end
		if self._stores.Kills then
			pcall(function() self._stores.Kills:SetAsync(userIdStr, math.max(0, kills)) end)
		end
		if self._stores.Rachas then
			pcall(function() self._stores.Rachas:SetAsync(userIdStr, math.max(0, racha)) end)
		end
	end)
end

-- Refresca las 3 pantallas
function LeaderboardService:RefreshAllLeaderboards()
	self:RefreshLeaderboard("Wins")
	self:RefreshLeaderboard("Kills")
	self:RefreshLeaderboard("Rachas")
end

-- Refresca una pantalla específica
function LeaderboardService:RefreshLeaderboard(statKey: string)
	local cfg = SCREEN_MAPPING[statKey]
	if not cfg then return end

	local stands = Workspace:FindFirstChild("stands") and Workspace.stands:FindFirstChild("TOPS-SCREENS")
	if not stands then return end

	local subModel = stands:FindFirstChild(cfg.ModelName)
	local screenPart = subModel and subModel:FindFirstChild(cfg.PartName)
	if not screenPart then return end

	local surfaceGui = screenPart:FindFirstChild(cfg.GuiName)
	if not surfaceGui then return end

	local mainFrame = surfaceGui:FindFirstChild("MainFrame")
	local scroll = mainFrame and mainFrame:FindFirstChild("ScrollList")
	if not scroll then return end

	local icons = self:_getIcons()
	local iconAll = (icons and icons[cfg.IconAllName]) or (icons and icons.Top_All_Wins)

	-- Obtener entradas ordenadas (Top 50)
	local entries: { { PlayerName: string, Value: number } } = {}
	local store = self._stores[statKey]

	if store then
		local ok, pages = pcall(function()
			return store:GetSortedAsync(false, 50, 1)
		end)

		if ok and pages then
			local current = pages:GetCurrentPage()
			for _, item in ipairs(current) do
				local uid = tonumber(item.key)
				if uid then
					local pName = self:_getPlayerName(uid)
					table.insert(entries, {
						PlayerName = pName,
						Value = item.value,
					})
				end
			end
		end
	end

	-- Si es servidor público y no hay registros en la tienda aún, incorporar jugadores activos conectados con sus datos REALES
	local existingNames = {}
	for _, entry in ipairs(entries) do
		existingNames[entry.PlayerName] = true
	end

	local activePlayers = Players:GetPlayers()
	for _, p in ipairs(activePlayers) do
		if not existingNames[p.Name] then
			local val = 0
			if self._playerService then
				if statKey == "Wins" then val = self._playerService:GetWins(p)
				elseif statKey == "Kills" then val = self._playerService:GetKills(p)
				elseif statKey == "Rachas" then
					local d = self._playerService._data and self._playerService._data[p]
					val = (d and d.WinStreak and d.WinStreak.Total) or 0
				end
			end
			table.insert(entries, { PlayerName = p.Name, Value = val })
			existingNames[p.Name] = true
		end
	end

	-- Ordenar de mayor a menor
	table.sort(entries, function(a, b)
		return a.Value > b.Value
	end)

	-- En Studio únicamente (offline): Si está completamente vacío, mostrar preview
	if self._isStudio and #entries == 0 then
		for i = 1, 50 do
			local mockName = (i <= #MOCK_NAMES and MOCK_NAMES[i]) or ("Player_" .. tostring(i))
			local statVal = math.max(1, math.floor(cfg.SampleBase * (1 - (i - 1) * 0.018)))
			table.insert(entries, { PlayerName = mockName, Value = statVal })
		end
	end

	-- Rellenar las 50 filas en el ScrollingFrame
	for rank = 1, 50 do
		local row = scroll:FindFirstChild("Rank_" .. rank)
		local data = entries[rank]
		if row then
			local nameLbl = row:FindFirstChild("PlayerName") :: TextLabel?
			local statLbl = row:FindFirstChild("StatNumber") :: TextLabel?
			local iconImg = row:FindFirstChild("IconTop") :: ImageLabel?

			if data then
				-- Fila con jugador real
				if nameLbl then
					nameLbl.Text = data.PlayerName
					nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
				end

				if statLbl then
					statLbl.Text = self:_formatNumber(data.Value)
					statLbl.TextColor3 = (rank == 1 and Color3.fromRGB(255, 215, 0))
						or (rank == 2 and Color3.fromRGB(240, 240, 240))
						or (rank == 3 and Color3.fromRGB(235, 145, 60))
						or Color3.fromRGB(210, 210, 210)
				end

				local targetIcon = iconAll
				if rank == 1 and icons and icons.Top_1 then targetIcon = icons.Top_1
				elseif rank == 2 and icons and icons.Top_2 then targetIcon = icons.Top_2
				elseif rank == 3 and icons and icons.Top_3 then targetIcon = icons.Top_3
				end

				if iconImg and targetIcon then
					iconImg.Visible = true
					iconImg.Image = targetIcon.Image
					iconImg.ImageColor3 = targetIcon.ImageColor3
					iconImg.ImageRectOffset = targetIcon.ImageRectOffset
					iconImg.ImageRectSize = targetIcon.ImageRectSize
				end
			else
				-- Fila vacía (sin jugador aún en este puesto)
				if nameLbl then
					nameLbl.Text = "---"
					nameLbl.TextColor3 = Color3.fromRGB(120, 130, 150)
				end

				if statLbl then
					statLbl.Text = "-"
					statLbl.TextColor3 = Color3.fromRGB(120, 130, 150)
				end

				if iconImg then
					iconImg.Visible = false
				end
			end
		end
	end
end

return LeaderboardService
