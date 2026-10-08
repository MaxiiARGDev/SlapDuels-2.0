--!strict
-- ShopService
-- Orquestador transaccional central del Shop Framework.
-- Responsabilidades:
-- - Registro y resolución desacoplada de ProductProviders vía ShopRegistry.
-- - Validación autoritativa de productos, disponibilidad y bloqueos transaccionales.
-- - Enrutamiento de divisas (Coins vs Robux) sin acoplamiento a categorías de productos.
-- - Preparación de la API de compra (PurchaseProduct), equipamiento (EquipProduct) y desequipamiento (UnequipProduct).
-- Nota: En Fase 2 la infraestructura central queda completamente tipada y validada; la deducción/persistencia de inventario
-- se implementa en la Fase 4 y la integración de MarketplaceService en la Fase 6.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Types = require(ReplicatedStorage.Shared.Types)

type ProductDefinition = Types.ProductDefinition
type ProductProvider = Types.ProductProvider

local ShopService = {}
ShopService.Name = "ShopService"

ShopService._context = nil :: any
ShopService._registry = nil :: any
ShopService._playerService = nil :: any
ShopService._inProgressPurchases = {} :: { [any]: boolean }

-- Utilidad para garantizar carpetas en la jerarquía
local function ensureFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- ==================================================
-- INICIALIZACIÓN DEL SERVICIO
-- ==================================================

function ShopService:Init(context: any)
	self._context = context
	self._inProgressPurchases = {}

	-- Asegurar la existencia del namespace de remotes para la tienda
	local remotesFolder = ensureFolder(ReplicatedStorage, "Remotes")
	ensureFolder(remotesFolder, "Shop")

	-- Resolver ShopRegistry
	self:_getRegistryInternal()
end

function ShopService:Start(context: any)
	self._context = context
	print("[ShopService] Orquestador transaccional de tienda iniciado y listo")
end

-- ==================================================
-- RESOLUCIÓN DE DEPENDENCIAS
-- ==================================================

function ShopService:_getRegistryInternal(): any
	if self._registry then
		return self._registry
	end

	-- 1. Intentar resolver mediante ServerScriptService.Shop.ShopRegistry
	local shopFolder = ServerScriptService:FindFirstChild("Shop")
	if shopFolder then
		local regMod = shopFolder:FindFirstChild("ShopRegistry")
		if regMod and regMod:IsA("ModuleScript") then
			local ok, mod = pcall(require, regMod)
			if ok and mod then
				self._registry = mod
				return mod
			end
		end
	end

	-- 2. Fallback de resolución relativa directa para tests / bootstrap
	local ok, mod = pcall(function()
		return require(script.Parent.Parent.Shop.ShopRegistry)
	end)
	if ok and mod then
		self._registry = mod
		return mod
	end

	warn("[ShopService] No se pudo resolver ShopRegistry automáticamente")
	return nil
end

function ShopService:GetRegistry(): any
	return self:_getRegistryInternal()
end

function ShopService:SetRegistry(registry: any)
	self._registry = registry
end

function ShopService:_getPlayerService(): any
	if self._playerService then
		return self._playerService
	end
	if self._context and type(self._context.GetService) == "function" then
		local s = self._context:GetService("PlayerService")
		if s then
			self._playerService = s
			return s
		end
	end
	local servicesFolder = ServerScriptService:FindFirstChild("Services")
	local mod = servicesFolder and servicesFolder:FindFirstChild("PlayerService")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok and result then
			self._playerService = result
			return result
		end
	end
	return nil
end

-- ==================================================
-- API DEL REGISTRO (DELEGACIÓN)
-- ==================================================

-- Registra un ProductProvider delegando en ShopRegistry
function ShopService:RegisterProvider(provider: ProductProvider)
	local registry = self:GetRegistry()
	assert(registry, "[ShopService] Registry no disponible para registrar provider")
	registry:Register(provider)
end

-- Obtiene el ProductProvider correspondiente a una categoría
function ShopService:GetProvider(category: string): ProductProvider?
	local registry = self:GetRegistry()
	if not registry then return nil end
	return registry:GetProvider(category)
end

-- Obtiene el catálogo completo unificado de productos
function ShopService:GetCatalog(): { ProductDefinition }
	local registry = self:GetRegistry()
	if not registry then return {} end
	return registry:GetCatalog()
end

-- Obtiene un producto por su Id
function ShopService:GetProduct(productId: string): ProductDefinition?
	local registry = self:GetRegistry()
	if not registry then return nil end
	return registry:GetProduct(productId)
end

-- Obtiene un producto por su RobloxProductId
function ShopService:GetProductByRobloxId(robloxId: number): ProductDefinition?
	local registry = self:GetRegistry()
	if not registry then return nil end
	return registry:GetProductByRobloxId(robloxId)
end

-- ==================================================
-- GESTIÓN DE BLOQUEOS TRANSACCIONALES (IN-FLIGHT LOCKS)
-- ==================================================

function ShopService:IsTransactionInProgress(player: any): boolean
	return self._inProgressPurchases[player] == true
end

function ShopService:_setTransactionLock(player: any, locked: boolean)
	if locked then
		self._inProgressPurchases[player] = true
	else
		self._inProgressPurchases[player] = nil
	end
end

-- ==================================================
-- ORQUESTACIÓN DE COMPRAS (PURCHASE API)
-- ==================================================

-- Solicita la compra autoritativa de un producto.
-- Valida existencia, disponibilidad, locks transaccionales y enruta según Currency.
function ShopService:PurchaseProduct(player: any, productId: string): (boolean, string?)
	if not player then
		return false, "InvalidPlayer"
	end
	if type(productId) ~= "string" or productId == "" then
		return false, "InvalidProductId"
	end

	-- Verificar si el jugador ya tiene una transacción activa
	if self:IsTransactionInProgress(player) then
		return false, "TransactionInProgress"
	end

	local registry = self:GetRegistry()
	if not registry then
		return false, "RegistryNotAvailable"
	end

	local product = registry:GetProduct(productId)
	if not product then
		return false, "ProductNotFound"
	end

	if not product.IsAvailable then
		return false, "ProductUnavailable"
	end

	local provider = registry:GetProvider(product.Category)
	if not provider then
		return false, "ProviderNotFound"
	end

	-- Validación de dominio por el ProductProvider (ej: ya poseído, nivel insuficiente, etc.)
	local canPurchase, canPurchaseErr = provider:CanPurchase(player, product)
	if not canPurchase then
		return false, canPurchaseErr or "CannotPurchase"
	end

	-- Enrutamiento autoritativo según la divisa del producto
	if product.Currency == "Coins" then
		return self:_processCoinsPurchase(player, product, provider)
	elseif product.Currency == "Robux" then
		return self:_processRobuxPurchase(player, product, provider)
	else
		return false, "UnsupportedCurrency"
	end
end

-- Procesa compras con moneda interna (Coins)
function ShopService:_processCoinsPurchase(player: any, product: ProductDefinition, provider: ProductProvider): (boolean, string?)
	local playerService = self:_getPlayerService()
	if not playerService then
		return false, "PlayerServiceNotAvailable"
	end

	-- Verificación autoritativa de fondos vía API pública de PlayerService (sin acceder a tablas privadas)
	local currentCoins = playerService:GetCoins(player)
	if currentCoins < product.Price then
		return false, "InsufficientFunds"
	end

	-- En Fase 2 (Core Framework): el flujo y validaciones están completamente establecidos.
	-- La deducción atómica de monedas y la asignación al inventario genérico se conectan en Fase 4.
	return false, "PurchaseExecutionPendingPhase4"
end

-- Procesa compras con moneda de plataforma (Robux)
function ShopService:_processRobuxPurchase(player: any, product: ProductDefinition, provider: ProductProvider): (boolean, string?)
	if not product.RobloxProductId or product.RobloxProductId <= 0 then
		return false, "MissingRobloxProductId"
	end

	-- En Fase 2 (Core Framework): la definición y validación de Robux/RobloxProductId están establecidas.
	-- La integración con el prompt y ProcessReceipt de MarketplaceService se conecta en Fase 6.
	return false, "MarketplaceIntegrationPendingPhase6"
end

-- ==================================================
-- ORQUESTACIÓN DE EQUIPAMIENTO (EQUIP / UNEQUIP API)
-- ==================================================

-- Solicita equipar un cosmético
function ShopService:EquipProduct(player: any, productId: string): (boolean, string?)
	if not player then
		return false, "InvalidPlayer"
	end
	if type(productId) ~= "string" or productId == "" then
		return false, "InvalidProductId"
	end

	local registry = self:GetRegistry()
	if not registry then
		return false, "RegistryNotAvailable"
	end

	local product = registry:GetProduct(productId)
	if not product then
		return false, "ProductNotFound"
	end

	if product.ProductType ~= "Cosmetic" then
		return false, "NotEquippable"
	end

	local provider = registry:GetProvider(product.Category)
	if not provider then
		return false, "ProviderNotFound"
	end

	local canEquip, canEquipErr = provider:CanEquip(player, product)
	if not canEquip then
		return false, canEquipErr or "CannotEquip"
	end

	-- En Fase 2: Equip execution pertenece a la Fase 5 (Equip System)
	return false, "EquipExecutionPendingPhase5"
end

-- Solicita desequipar el cosmético activo de una categoría
function ShopService:UnequipProduct(player: any, category: string): (boolean, string?)
	if not player then
		return false, "InvalidPlayer"
	end
	if type(category) ~= "string" or category == "" then
		return false, "InvalidCategory"
	end

	local registry = self:GetRegistry()
	if not registry then
		return false, "RegistryNotAvailable"
	end

	local provider = registry:GetProvider(category)
	if not provider then
		return false, "ProviderNotFound"
	end

	-- En Fase 2: Unequip execution pertenece a la Fase 5 (Equip System)
	return false, "UnequipExecutionPendingPhase5"
end

return ShopService
