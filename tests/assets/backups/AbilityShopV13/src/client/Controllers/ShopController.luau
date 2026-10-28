--!strict
-- ShopController
-- Controlador cliente de la tienda (docs/SHOP_SYSTEM.md → ShopController / ShopUI).
-- - Enlaza las instancias existentes de PlayerGui.ShopHUD (creadas en Studio). No construye UI por código:
--   solo clona ProductCardTemplate por producto y modifica propiedades de instancias existentes.
-- - Obtiene el catálogo y solicita compra/equipamiento mediante Remotes.Shop (RemoteFunctions de ShopRemotes).
-- - Coins e Inventory se reflejan exclusivamente desde Remotes.Player.DataUpdated (fuente autoritativa).
-- - Sin operaciones optimistas: la UI solo cambia de estado cuando el servidor lo confirma.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer

local ShopController = {}
ShopController.Name = "ShopController"

local DEFAULT_CATEGORY = "PointEffects"
local REMOTE_TIMEOUT = 15

-- Mensajes legibles para los códigos de error reales devueltos por ShopService / Providers / ShopRemotes
local ERROR_MESSAGES: { [string]: string } = {
	InsufficientFunds = "No tenés Coins suficientes.",
	AlreadyOwned = "Ya tenés este producto.",
	AlreadyEquipped = "Este producto ya está equipado.",
	NotOwned = "Todavía no tenés este producto.",
	TransactionInProgress = "Ya hay una compra en curso.",
	RateLimited = "Esperá un momento antes de reintentar.",
	ProductNotFound = "El producto no existe.",
	ProductUnavailable = "El producto no está disponible.",
	ProviderNotFound = "Esta categoría todavía no está disponible.",
	NotEquippable = "Este producto no se puede equipar.",
	MarketplaceIntegrationPendingPhase6 = "Las compras con Robux todavía no están disponibles.",
	MissingRobloxProductId = "Las compras con Robux todavía no están disponibles.",
	UnsupportedCurrency = "Moneda no soportada.",
	PlayerServiceNotAvailable = "El servidor no está listo. Reintentá en unos segundos.",
	InternalError = "Error del servidor. Reintentá.",
	NoResponse = "Sin respuesta del servidor. Reintentá.",
	DataNotLoaded = "Tus datos todavía no están disponibles. Reintentá cuando terminen de cargar.",
	PurchasesNotEnabled = "Las compras de esta categoría todavía no están habilitadas.",
}

type UIRefs = {
	Hud: ScreenGui,
	OpenButton: GuiButton?,
	Main: Frame,
	OpenScale: UIScale?,
	CloseButton: GuiButton?,
	CoinsLabel: TextLabel?,
	Tabs: Frame?,
	Catalog: ScrollingFrame,
	CardTemplate: GuiButton,
	EmptyState: GuiObject?,
	LoadingLabel: GuiObject?,
	MessageLabel: TextLabel?,
	Detail: {
		Frame: Frame,
		PreviewLabel: TextLabel?,
		PreviewIcon: ImageLabel?,
		NameLabel: TextLabel?,
		RarityLabel: TextLabel?,
		DescriptionLabel: TextLabel?,
		PriceRow: GuiObject?,
		PriceLabel: TextLabel?,
		StatusLabel: TextLabel?,
		ActionButton: TextButton?,
		SecondaryButton: TextButton?,
	},
}

ShopController._context = nil :: any
ShopController._ui = nil :: UIRefs?
ShopController._remotes = {} :: { [string]: RemoteFunction }
ShopController._dataUpdated = nil :: RemoteEvent?
ShopController._dataConnection = nil :: RBXScriptConnection?
ShopController._connections = {} :: { RBXScriptConnection }
ShopController._cardConnections = {} :: { RBXScriptConnection }
ShopController._tabs = {} :: { [string]: GuiButton }
ShopController._tabBaseColors = {} :: { [GuiButton]: Color3 }
ShopController._tabBaseImageColors = {} :: { [ImageButton]: Color3 }
ShopController._cards = {} :: { [string]: GuiButton }
ShopController._cardBaseStroke = nil :: { Color: Color3, Thickness: number }?

ShopController._catalog = nil :: { any }?
ShopController._catalogLoading = false
ShopController._playerData = nil :: any
ShopController._category = DEFAULT_CATEGORY
ShopController._selectedId = nil :: string?
ShopController._busy = false
ShopController._isOpen = false
ShopController._messageToken = 0

--------------------------------------------------------------------------------
-- Utilidades
--------------------------------------------------------------------------------

local function attrColor(inst: Instance?, name: string, default: Color3): Color3
	local v = inst and inst:GetAttribute(name)
	if typeof(v) == "Color3" then
		return v
	end
	return default
end

local function find(parent: Instance?, path: { string }): Instance?
	local current = parent
	for _, name in ipairs(path) do
		if not current then return nil end
		current = current:FindFirstChild(name)
	end
	return current
end

local function formatNumber(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1."):reverse()
	return (formatted:gsub("^%.", ""))
end

--------------------------------------------------------------------------------
-- Enlace de UI
--------------------------------------------------------------------------------

function ShopController:_bindHUD(): boolean
	local playerGui = localPlayer:WaitForChild("PlayerGui")
	local hud = playerGui:WaitForChild("ShopHUD", REMOTE_TIMEOUT) :: ScreenGui?
	if not hud then
		warn("[ShopController] No se encontró ShopHUD en PlayerGui")
		return false
	end

	local main = hud:FindFirstChild("MainFrame") :: Frame?
	local catalog = find(main, { "Body", "Catalog" }) :: ScrollingFrame?
	local template = catalog and catalog:FindFirstChild("ProductCardTemplate") :: GuiButton?
	local detailFrame = find(main, { "Body", "DetailPanel" }) :: Frame?
	if not main or not catalog or not template or not detailFrame then
		warn("[ShopController] Estructura de ShopHUD incompleta (MainFrame/Body/Catalog/ProductCardTemplate/DetailPanel)")
		return false
	end

	template.Visible = false
	main.Visible = false

	self._ui = {
		Hud = hud,
		OpenButton = hud:FindFirstChild("ShopButton") :: GuiButton?,
		Main = main,
		OpenScale = main:FindFirstChild("OpenScale") :: UIScale?,
		CloseButton = find(main, { "Header", "CloseButton" }) :: GuiButton?,
		CoinsLabel = find(main, { "Header", "CoinsContainer", "CoinsLabel" }) :: TextLabel?,
		Tabs = main:FindFirstChild("Tabs") :: Frame?,
		Catalog = catalog,
		CardTemplate = template,
		EmptyState = find(main, { "Body", "EmptyState" }) :: GuiObject?,
		LoadingLabel = find(main, { "Body", "LoadingLabel" }) :: GuiObject?,
		MessageLabel = main:FindFirstChild("MessageLabel") :: TextLabel?,
		Detail = {
			Frame = detailFrame,
			PreviewLabel = find(detailFrame, { "Preview", "PreviewLabel" }) :: TextLabel?,
			PreviewIcon = find(detailFrame, { "Preview", "PreviewIcon" }) :: ImageLabel?,
			NameLabel = detailFrame:FindFirstChild("NameLabel") :: TextLabel?,
			RarityLabel = detailFrame:FindFirstChild("RarityLabel") :: TextLabel?,
			DescriptionLabel = detailFrame:FindFirstChild("DescriptionLabel") :: TextLabel?,
			PriceRow = detailFrame:FindFirstChild("PriceRow") :: GuiObject?,
			PriceLabel = find(detailFrame, { "PriceRow", "PriceLabel" }) :: TextLabel?,
			StatusLabel = detailFrame:FindFirstChild("StatusLabel") :: TextLabel?,
			ActionButton = detailFrame:FindFirstChild("ActionButton") :: TextButton?,
			SecondaryButton = detailFrame:FindFirstChild("SecondaryButton") :: TextButton?,
		},
	}

	local templateStroke = template:FindFirstChildOfClass("UIStroke")
	if templateStroke then
		self._cardBaseStroke = { Color = templateStroke.Color, Thickness = templateStroke.Thickness }
	end

	-- Pestañas: cualquier GuiButton dentro de Tabs con atributo Category
	local tabsFrame = self._ui.Tabs
	if tabsFrame then
		for _, child in ipairs(tabsFrame:GetChildren()) do
			local category = child:GetAttribute("Category")
			if child:IsA("GuiButton") and typeof(category) == "string" then
				self._tabs[category] = child
				self._tabBaseColors[child] = child.BackgroundColor3
				if child:IsA("ImageButton") then self._tabBaseImageColors[child] = child.ImageColor3 end
				table.insert(self._connections, child.Activated:Connect(function()
					self:_selectCategory(category)
				end))
			end
		end
	end

	local ui = self._ui
	if ui.OpenButton then
		table.insert(self._connections, ui.OpenButton.Activated:Connect(function()
			self:Toggle()
		end))
	end
	if ui.CloseButton then
		table.insert(self._connections, ui.CloseButton.Activated:Connect(function()
			self:Close()
		end))
	end
	if ui.Detail.ActionButton then
		table.insert(self._connections, ui.Detail.ActionButton.Activated:Connect(function()
			self:_onActionPressed()
		end))
	end
	if ui.Detail.SecondaryButton then
		table.insert(self._connections, ui.Detail.SecondaryButton.Activated:Connect(function()
			self:_onSecondaryPressed()
		end))
	end

	return true
end

function ShopController:_bindRemotes()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", REMOTE_TIMEOUT)
	local shopFolder = remotes and remotes:WaitForChild("Shop", REMOTE_TIMEOUT)
	if shopFolder then
		for _, name in ipairs({ "GetCatalog", "PurchaseProduct", "EquipProduct", "UnequipProduct" }) do
			local rf = shopFolder:WaitForChild(name, REMOTE_TIMEOUT)
			if rf and rf:IsA("RemoteFunction") then
				self._remotes[name] = rf
			else
				warn(string.format("[ShopController] RemoteFunction Shop.%s no disponible", name))
			end
		end
	end

	local playerFolder = remotes and remotes:WaitForChild("Player", REMOTE_TIMEOUT)
	local dataUpdated = playerFolder and playerFolder:WaitForChild("DataUpdated", REMOTE_TIMEOUT)
	if dataUpdated and dataUpdated:IsA("RemoteEvent") then
		-- Se conecta de forma diferida en la primera apertura (ver _ensureDataListener)
		self._dataUpdated = dataUpdated
	else
		warn("[ShopController] RemoteEvent Player.DataUpdated no disponible")
	end
end

-- Conecta DataUpdated recién cuando el jugador abre la tienda.
-- Motivo: los eventos disparados antes de que exista un listener quedan encolados y se entregan al primer
-- handler que se conecta; conectar aquí evita robarle el snapshot inicial a PlayerHUDController.
-- El snapshot para la tienda lo reenvía el servidor al invocar GetCatalog.
function ShopController:_ensureDataListener()
	if self._dataConnection or not self._dataUpdated then return end
	self._dataConnection = self._dataUpdated.OnClientEvent:Connect(function(data: any)
		if type(data) == "table" then
			self._playerData = data
			self:_refresh()
		end
	end)
end

--------------------------------------------------------------------------------
-- Estado derivado (siempre desde datos del servidor)
--------------------------------------------------------------------------------

function ShopController:_isOwned(product: any): boolean
	local inv = self._playerData and self._playerData.Inventory
	local owned = inv and inv.Owned and inv.Owned[product.Category]
	return type(owned) == "table" and owned[product.Id] == true
end

function ShopController:_isEquipped(product: any): boolean
	local inv = self._playerData and self._playerData.Inventory
	return inv ~= nil and inv.Equipped ~= nil and inv.Equipped[product.Category] == product.Id
end

function ShopController:_getProducts(category: string): { any }
	local list = {}
	for _, product in ipairs(self._catalog or {}) do
		if product.Category == category then
			table.insert(list, product)
		end
	end
	table.sort(list, function(a, b)
		if a.Price == b.Price then return tostring(a.Id) < tostring(b.Id) end
		return (a.Price or 0) < (b.Price or 0)
	end)
	return list
end

function ShopController:_getProduct(productId: string?): any
	if not productId then return nil end
	for _, product in ipairs(self._catalog or {}) do
		if product.Id == productId and product.Category == self._category then return product end
	end
	return nil
end

-- Una categoría está activa si el servidor expone productos para ella (proveedor registrado)
function ShopController:_isCategoryActive(category: string): boolean
	return #self:_getProducts(category) > 0
end

--------------------------------------------------------------------------------
-- Render
--------------------------------------------------------------------------------

function ShopController:_showMessage(text: string, kind: string?)
	local ui = self._ui
	if not ui or not ui.MessageLabel then return end
	local colorName = "MessageColor_" .. (kind or "Info")
	ui.MessageLabel.TextColor3 = attrColor(ui.Main, colorName, ui.MessageLabel.TextColor3)
	ui.MessageLabel.Text = text

	self._messageToken += 1
	local token = self._messageToken
	if text ~= "" then
		task.delay(4, function()
			if self._messageToken == token and self._ui and self._ui.MessageLabel then
				self._ui.MessageLabel.Text = ""
			end
		end)
	end
end

function ShopController:_renderCoins()
	local ui = self._ui
	if not ui or not ui.CoinsLabel then return end
	local coins = self._playerData and self._playerData.Coins
	ui.CoinsLabel.Text = if typeof(coins) == "number" then formatNumber(coins) else "—"
end

function ShopController:_renderTabs()
	local ui = self._ui
	if not ui then return end
	local activeColor = attrColor(ui.Tabs, "ActiveColor", Color3.fromRGB(0, 120, 215))
	for category, tab in pairs(self._tabs) do
		local isSelected = category == self._category
		local isActive = self._catalog ~= nil and self:_isCategoryActive(category)
		tab.BackgroundColor3 = if isSelected then activeColor else (self._tabBaseColors[tab] or tab.BackgroundColor3)
		if tab:IsA("ImageButton") then
			tab.ImageColor3 = if isSelected then activeColor else (self._tabBaseImageColors[tab] or tab.ImageColor3)
		end
		local badge = tab:FindFirstChild("SoonBadge")
		if badge and badge:IsA("GuiObject") then
			badge.Visible = self._catalog ~= nil and not isActive
		end
	end
end

function ShopController:_clearCards()
	for _, conn in ipairs(self._cardConnections) do
		conn:Disconnect()
	end
	table.clear(self._cardConnections)
	for _, card in pairs(self._cards) do
		card:Destroy()
	end
	table.clear(self._cards)
end

function ShopController:_rarityColor(rarity: string?): Color3
	local ui = self._ui
	return attrColor(ui and ui.Main, "RarityColor_" .. tostring(rarity), Color3.fromRGB(170, 180, 200))
end

function ShopController:_applyCardState(card: GuiButton, product: any)
	local ui = self._ui
	if not ui then return end
	local owned = self:_isOwned(product)
	local equipped = self:_isEquipped(product)

	local badge = card:FindFirstChild("StateBadge") :: TextLabel?
	if badge then
		if not product.IsAvailable then
			badge.Visible = true
			badge.Text = "NO DISPONIBLE"
			badge.BackgroundColor3 = attrColor(badge, "Color_Unavailable", badge.BackgroundColor3)
		elseif equipped then
			badge.Visible = true
			badge.Text = if product.Category == "Abilities" then "PREFERIDA" else "EQUIPADO"
			badge.BackgroundColor3 = attrColor(badge, "Color_Equipped", badge.BackgroundColor3)
		elseif owned then
			badge.Visible = true
			badge.Text = "TUYO"
			badge.BackgroundColor3 = attrColor(badge, "Color_Owned", badge.BackgroundColor3)
		else
			badge.Visible = false
		end
	end

	local priceLabel = card:FindFirstChild("PriceLabel") :: TextLabel?
	local coinIcon = card:FindFirstChild("CoinIcon") :: GuiObject?
	local showPrice = not owned and product.Currency == "Coins"
	if priceLabel then
		priceLabel.Visible = not owned
		priceLabel.Text = if product.Category == "Abilities" and product.Metadata and product.Metadata.PricePending then "PRECIO PENDIENTE" elseif product.Currency == "Coins" then formatNumber(product.Price or 0)
			else string.format("%s R$", formatNumber(product.Price or 0))
	end
	if coinIcon then coinIcon.Visible = showPrice end

	local cardStroke = card:FindFirstChildOfClass("UIStroke")
	if cardStroke and self._cardBaseStroke then
		local selected = product.Id == self._selectedId
		cardStroke.Color = if selected then attrColor(ui.Main, "SelectedStrokeColor", self._cardBaseStroke.Color) else self._cardBaseStroke.Color
		cardStroke.Thickness = if selected then self._cardBaseStroke.Thickness + 1 else self._cardBaseStroke.Thickness
	end
end

function ShopController:_renderCatalog()
	local ui = self._ui
	if not ui then return end
	self:_clearCards()

	local loading = self._catalog == nil
	if ui.LoadingLabel then ui.LoadingLabel.Visible = loading end

	local products = if loading then {} else self:_getProducts(self._category)
	local isEmpty = not loading and #products == 0
	if ui.EmptyState then ui.EmptyState.Visible = isEmpty end
	ui.Catalog.Visible = not loading and not isEmpty
	ui.Detail.Frame.Visible = not loading and not isEmpty

	for index, product in ipairs(products) do
		local card = ui.CardTemplate:Clone()
		card.Name = "Card_" .. tostring(product.Id)
		card.LayoutOrder = index
		card.Visible = true

		local nameLabel = card:FindFirstChild("NameLabel") :: TextLabel?
		if nameLabel then nameLabel.Text = product.DisplayName or product.Id end
		local rarityLabel = card:FindFirstChild("RarityLabel") :: TextLabel?
		if rarityLabel then
			rarityLabel.Text = product.Rarity or ""
			rarityLabel.TextColor3 = self:_rarityColor(product.Rarity)
		end
		local preview = card:FindFirstChild("Preview")
		local previewStroke = preview and preview:FindFirstChildOfClass("UIStroke")
		if previewStroke then previewStroke.Color = self:_rarityColor(product.Rarity) end
		local icon = preview and preview:FindFirstChild("PreviewIcon") :: ImageLabel?
		if icon and type(product.Icon) == "string" and product.Icon ~= "" then
			icon.Image = product.Icon
			icon.Visible = true
			local placeholder = preview and preview:FindFirstChild("PreviewLabel") :: GuiObject?
			if placeholder then placeholder.Visible = false end
		end

		self:_applyCardState(card, product)
		card.Parent = ui.Catalog
		self._cards[product.Id] = card

		local productId = product.Id
		table.insert(self._cardConnections, card.Activated:Connect(function()
			self._selectedId = productId
			self:_refreshStates()
		end))
	end

	-- Mantener selección válida dentro de la categoría
	if not self:_getProduct(self._selectedId) or (self:_getProduct(self._selectedId).Category ~= self._category) then
		self._selectedId = if #products > 0 then products[1].Id else nil
	end
	self:_refreshStates()
end

function ShopController:_renderDetail()
	local ui = self._ui
	if not ui then return end
	local d = ui.Detail
	local product = self:_getProduct(self._selectedId)

	if not product then
		if d.NameLabel then d.NameLabel.Text = "Seleccioná un producto" end
		if d.RarityLabel then d.RarityLabel.Text = "" end
		if d.DescriptionLabel then d.DescriptionLabel.Text = "" end
		if d.PriceRow then d.PriceRow.Visible = false end
		if d.StatusLabel then d.StatusLabel.Text = "" end
		if d.ActionButton then d.ActionButton.Visible = false end
		if d.SecondaryButton then d.SecondaryButton.Visible = false end
		return
	end

	local owned = self:_isOwned(product)
	local equipped = self:_isEquipped(product)
	local rarityColor = self:_rarityColor(product.Rarity)

	if d.NameLabel then d.NameLabel.Text = product.DisplayName or product.Id end
	if d.RarityLabel then
		d.RarityLabel.Text = product.Rarity or ""
		d.RarityLabel.TextColor3 = rarityColor
	end
	if d.DescriptionLabel then d.DescriptionLabel.Text = product.Description or "" end
	if d.PreviewIcon and d.PreviewLabel then
		local hasIcon = type(product.Icon) == "string" and product.Icon ~= ""
		d.PreviewIcon.Image = if hasIcon then product.Icon else ""
		d.PreviewIcon.Visible = hasIcon
		d.PreviewLabel.Visible = not hasIcon
	end
	if d.PriceRow then d.PriceRow.Visible = not owned end
		if d.PriceLabel then
			d.PriceLabel.Text = if product.Category == "Abilities" and product.Metadata and product.Metadata.PricePending then "Precio pendiente de aprobación" elseif product.Currency == "Coins" then string.format("%s Coins", formatNumber(product.Price or 0))
			else string.format("%s Robux", formatNumber(product.Price or 0))
	end

	local status, actionText, actionKind, actionEnabled
	if not product.IsAvailable then
		status, actionText, actionKind, actionEnabled = "Producto no disponible", "NO DISPONIBLE", "Disabled", false
	elseif equipped then
			status, actionText, actionKind, actionEnabled = if product.Category == "Abilities" then "Preferencia para la próxima ronda" else "Equipado actualmente", if product.Category == "Abilities" then "PREFERIDA" else "EQUIPADO", "Disabled", false
	elseif owned then
			status, actionText, actionKind, actionEnabled = "Ya es tuyo", if product.Category == "Abilities" then "PREFERIR" else "EQUIPAR", "Equip", true
		elseif product.Category == "Abilities" and (not product.Metadata or not product.Metadata.PurchaseEnabled) then
			status, actionText, actionKind, actionEnabled = "Precio pendiente de aprobación", "PRÓXIMAMENTE", "Disabled", false
	elseif product.Currency ~= "Coins" then
		status, actionText, actionKind, actionEnabled = "Compras con Robux próximamente", "PRÓXIMAMENTE", "Disabled", false
	else
		local coins = self._playerData and self._playerData.Coins
		local canAfford = typeof(coins) == "number" and coins >= (product.Price or 0)
		status = if canAfford then "Disponible para comprar" else "Coins insuficientes"
		actionText, actionKind, actionEnabled = "COMPRAR", "Buy", true
	end

	if self._busy then
		actionText, actionEnabled = "PROCESANDO…", false
	end

	if d.StatusLabel then d.StatusLabel.Text = status end
	if d.ActionButton then
		local btn = d.ActionButton
		btn.Visible = true
		btn.Text = actionText
		btn.Active = actionEnabled
		btn.AutoButtonColor = actionEnabled
		btn.BackgroundColor3 = attrColor(btn, "Color_" .. actionKind, btn.BackgroundColor3)
	end
	if d.SecondaryButton then
		-- Desequipar solo tiene sentido si el producto equipado no es el gratuito por defecto de la categoría
		d.SecondaryButton.Visible = equipped and (product.Price or 0) > 0
		d.SecondaryButton.Active = not self._busy
	end
end

-- Recalcula estados (cards + detalle + saldo) sin reconstruir las tarjetas
function ShopController:_refreshStates()
	for productId, card in pairs(self._cards) do
		local product = self:_getProduct(productId)
		if product then
			self:_applyCardState(card, product)
		end
	end
	self:_renderDetail()
	self:_renderCoins()
end

function ShopController:_refresh()
	if not self._ui then return end
	self:_renderCoins()
	if self._isOpen then
		self:_renderTabs()
		self:_refreshStates()
	end
end

--------------------------------------------------------------------------------
-- Interacción
--------------------------------------------------------------------------------

function ShopController:_selectCategory(category: string)
	if self._category == category then return end
	self._category = category
	self._selectedId = nil
	self:_renderTabs()
	self:_renderCatalog()
	if self._catalog and not self:_isCategoryActive(category) then
		self:_showMessage("Esta categoría estará disponible próximamente.", "Info")
	end
end

function ShopController:_loadCatalog()
	if self._catalogLoading then return end
	local rf = self._remotes.GetCatalog
	if not rf then
		self:_showMessage("La tienda no está disponible en este momento.", "Error")
		return
	end
	self._catalogLoading = true
	task.spawn(function()
		local ok, result = pcall(function()
			return rf:InvokeServer()
		end)
		self._catalogLoading = false
		if ok and type(result) == "table" then
			self._catalog = result
		else
			warn(string.format("[ShopController] GetCatalog falló: %s", tostring(result)))
			self:_showMessage("No se pudo cargar el catálogo. Cerrá y volvé a abrir la tienda.", "Error")
		end
		if self._isOpen then
			self:_renderTabs()
			self:_renderCatalog()
		end
	end)
end

-- Ejecuta una operación del servidor bloqueando acciones repetidas hasta obtener respuesta
function ShopController:_request(remoteName: string, arg: string, successText: string, category: string?)
	if self._busy then return end
	local rf = self._remotes[remoteName]
	if not rf then
		self:_showMessage("La tienda no está disponible en este momento.", "Error")
		return
	end
	self._busy = true
	self:_renderDetail()

	task.spawn(function()
		local ok, success, code = pcall(function()
			return rf:InvokeServer(arg, category)
		end)
		self._busy = false
		if not ok then
			warn(string.format("[ShopController] %s falló: %s", remoteName, tostring(success)))
			self:_showMessage(ERROR_MESSAGES.NoResponse, "Error")
		elseif success == true then
			self:_showMessage(successText, "Success")
		else
			local key = tostring(code)
			self:_showMessage(ERROR_MESSAGES[key] or string.format("No se pudo completar la operación (%s).", key), "Error")
		end
		self:_refreshStates()
	end)
end

function ShopController:_onActionPressed()
	local product = self:_getProduct(self._selectedId)
	if not product or self._busy or not product.IsAvailable then return end
	if self:_isEquipped(product) then return end

	if self:_isOwned(product) then
			self:_request("EquipProduct", product.Id, if product.Category == "Abilities" then "Preferencia guardada para la próxima ronda." else string.format("%s equipado.", product.DisplayName or product.Id), product.Category)
	elseif product.Currency == "Coins" then
		self:_request("PurchaseProduct", product.Id, string.format("¡Compraste %s!", product.DisplayName or product.Id), product.Category)
	end
end

function ShopController:_onSecondaryPressed()
	local product = self:_getProduct(self._selectedId)
	if not product or self._busy or not self:_isEquipped(product) then return end
	self:_request("UnequipProduct", product.Category, "Producto desequipado.")
end

--------------------------------------------------------------------------------
-- Apertura / cierre
--------------------------------------------------------------------------------

function ShopController:Open()
	local ui = self._ui
	if not ui or self._isOpen then return end
	self._isOpen = true
	ui.Main.Visible = true

	if ui.OpenScale then
		ui.OpenScale.Scale = 0.92
		TweenService:Create(ui.OpenScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end

	self:_renderTabs()
	self:_renderCatalog()
	-- El catálogo se solicita en cada apertura; GetCatalog también reenvía el snapshot de DataUpdated
	self:_ensureDataListener()
	self:_loadCatalog()
end

function ShopController:Close()
	local ui = self._ui
	if not ui or not self._isOpen then return end
	self._isOpen = false
	-- Las operaciones en curso continúan en el servidor; su resultado llegará por DataUpdated
	self:_clearCards()
	ui.Main.Visible = false
	if ui.OpenScale then ui.OpenScale.Scale = 1 end
end

function ShopController:Toggle()
	if self._isOpen then self:Close() else self:Open() end
end

--------------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------------

function ShopController:Init(context)
	self._context = context
end

function ShopController:Start(context)
	self._context = context
	task.spawn(function()
		if not self:_bindHUD() then return end
		self:_bindRemotes()
		self:_renderCoins()
		print("[ShopController] Tienda enlazada y lista")
	end)
end

function ShopController:Destroy()
	self:Close()
	self:_clearCards()
	for _, conn in ipairs(self._connections) do
		conn:Disconnect()
	end
	table.clear(self._connections)
	if self._dataConnection then
		self._dataConnection:Disconnect()
		self._dataConnection = nil
	end
	table.clear(self._tabs)
	table.clear(self._tabBaseColors)
	table.clear(self._tabBaseImageColors)
	self._ui = nil
end

return ShopController
