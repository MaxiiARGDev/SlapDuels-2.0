--!strict
-- ShopRemotes
-- Puente cliente-servidor del Shop Framework (Remote API definida en docs/SHOP_SYSTEM.md).
-- Expone en ReplicatedStorage.Remotes.Shop los RemoteFunctions:
--   GetCatalog()                  -> { ProductDefinition }   (vista pública, sin Metadata)
--   PurchaseProduct(productId)    -> (boolean, string?)
--   EquipProduct(productId)       -> (boolean, string?)
--   UnequipProduct(category)      -> (boolean, string?)
-- No contiene lógica de negocio: valida tipos, aplica rate-limit y delega en la API pública de ShopService.
-- Las actualizaciones de Coins e Inventory llegan al cliente por el contrato existente Remotes.Player.DataUpdated.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ShopRemotes = {}

local MAX_ARG_LENGTH = 64
local MIN_REQUEST_INTERVAL = 0.3 -- segundos entre operaciones mutantes por jugador

local _initialized = false
local _shopService: any = nil
local _lastRequest: { [Player]: number } = {}
local _connections: { RBXScriptConnection } = {}

local function ensureChild(parent: Instance, name: string, className: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = parent
	return inst
end

local function isValidArg(value: any): boolean
	return type(value) == "string" and value ~= "" and #value <= MAX_ARG_LENGTH
end

-- Rate-limit por jugador para operaciones que modifican estado
local function consumeRequest(player: Player): boolean
	local now = os.clock()
	local last = _lastRequest[player]
	if last and (now - last) < MIN_REQUEST_INTERVAL then
		return false
	end
	_lastRequest[player] = now
	return true
end

-- Ejecuta una operación de ShopService protegida contra errores internos
local function safeCall(fn: () -> (boolean, string?)): (boolean, string?)
	local ok, success, err = pcall(fn)
	if not ok then
		warn(string.format("[ShopRemotes] Error interno: %s", tostring(success)))
		return false, "InternalError"
	end
	return success == true, if success == true then nil else (err or "Failed")
end

-- Vista pública y serializable de un producto (whitelist de campos de ProductDefinition)
local function toPublicProduct(product: any): { [string]: any }
	return {
		Id = product.Id,
		Category = product.Category,
		ProductType = product.ProductType,
		DisplayName = product.DisplayName,
		Description = product.Description,
		Price = product.Price,
		Currency = product.Currency,
		IsAvailable = product.IsAvailable == true,
		Rarity = product.Rarity,
		Icon = product.Icon,
	}
end

-- Resuelve PlayerService por el contexto del Bootstrap (o la carpeta Services como respaldo)
local function getPlayerService(): any
	local context = _shopService and _shopService._context
	if context and type(context.GetService) == "function" then
		local s = context:GetService("PlayerService")
		if s then return s end
	end
	local servicesFolder = ServerScriptService:FindFirstChild("Services")
	local mod = servicesFolder and servicesFolder:FindFirstChild("PlayerService")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok then return result end
	end
	return nil
end

-- Reenvía el snapshot autoritativo de PlayerData por el contrato existente DataUpdated.
-- Permite que la tienda conozca Coins/Inventory al abrirse aunque el evento inicial ya se haya consumido.
local function pushDataSnapshot(player: Player)
	if not player.Parent then return end
	local playerService = getPlayerService()
	if not playerService or type(playerService.GetPlayerData) ~= "function" then return end

	local remotes = ReplicatedStorage:FindFirstChild("Remotes")
	local playerFolder = remotes and remotes:FindFirstChild("Player")
	local dataUpdated = playerFolder and playerFolder:FindFirstChild("DataUpdated")
	if dataUpdated and dataUpdated:IsA("RemoteEvent") then
		dataUpdated:FireClient(player, playerService:GetPlayerData(player))
	end
end

function ShopRemotes:Init(shopService: any)
	if _initialized then return end
	-- No crear remotes en el DataModel de edición (evita contaminar el place al ejecutar tests en Edit Mode)
	if not RunService:IsRunning() then return end
	_initialized = true
	_shopService = shopService

	local remotesFolder = ensureChild(ReplicatedStorage, "Remotes", "Folder")
	local shopFolder = ensureChild(remotesFolder, "Shop", "Folder")

	local getCatalog = ensureChild(shopFolder, "GetCatalog", "RemoteFunction") :: RemoteFunction
	local purchase = ensureChild(shopFolder, "PurchaseProduct", "RemoteFunction") :: RemoteFunction
	local equip = ensureChild(shopFolder, "EquipProduct", "RemoteFunction") :: RemoteFunction
	local unequip = ensureChild(shopFolder, "UnequipProduct", "RemoteFunction") :: RemoteFunction

	getCatalog.OnServerInvoke = function(player: Player, category: any)
		local filter: string? = if isValidArg(category) then category else nil
		local ok, catalog = pcall(function()
			return _shopService:GetCatalog(filter)
		end)
		local result = {}
		if ok and type(catalog) == "table" then
			for _, product in ipairs(catalog) do
				table.insert(result, toPublicProduct(product))
			end
		else
			warn(string.format("[ShopRemotes] GetCatalog falló: %s", tostring(catalog)))
		end
		task.defer(pushDataSnapshot, player)
		return result
	end

	purchase.OnServerInvoke = function(player: Player, productId: any, category: any)
		if not isValidArg(productId) then return false, "InvalidProductId" end
		if category ~= nil and not isValidArg(category) then return false, "InvalidCategory" end
		if not consumeRequest(player) then return false, "RateLimited" end
		return safeCall(function()
			return _shopService:PurchaseProduct(player, productId, category)
		end)
	end

	equip.OnServerInvoke = function(player: Player, productId: any, category: any)
		if not isValidArg(productId) then return false, "InvalidProductId" end
		if category ~= nil and not isValidArg(category) then return false, "InvalidCategory" end
		if not consumeRequest(player) then return false, "RateLimited" end
		return safeCall(function()
			return _shopService:EquipProduct(player, productId, category)
		end)
	end

	unequip.OnServerInvoke = function(player: Player, category: any)
		if not isValidArg(category) then return false, "InvalidCategory" end
		if not consumeRequest(player) then return false, "RateLimited" end
		return safeCall(function()
			return _shopService:UnequipProduct(player, category)
		end)
	end

	table.insert(_connections, Players.PlayerRemoving:Connect(function(player)
		_lastRequest[player] = nil
	end))

	print("[ShopRemotes] Remote API de tienda lista (GetCatalog, PurchaseProduct, EquipProduct, UnequipProduct)")
end

return ShopRemotes
