--!strict
-- ShopRegistry
-- Registro en memoria de ProductProviders y resolución desacoplada de catálogos.
-- Completamente agnóstico respecto a categorías concretas (no contiene lógica hardcodeada).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)

type ProductDefinition = Types.ProductDefinition
type ProductProvider = Types.ProductProvider

local ShopRegistry = {}

ShopRegistry._providers = {} :: { [string]: ProductProvider }
ShopRegistry._productsById = {} :: { [string]: ProductDefinition }
ShopRegistry._productsByRobloxId = {} :: { [number]: ProductDefinition }

-- ==================================================
-- VALIDACIÓN Y REGISTRO DE PROVIDERS
-- ==================================================

-- Registra un ProductProvider e indexa sus productos en el catálogo unificado
function ShopRegistry:Register(provider: ProductProvider)
	assert(type(provider) == "table", "[ShopRegistry] El proveedor debe ser una tabla")

	-- Validación estricta del contrato de métodos de ProductProvider
	assert(type(provider.GetCategory) == "function", "[ShopRegistry] Proveedor no implementa GetCategory()")
	assert(type(provider.GetProducts) == "function", "[ShopRegistry] Proveedor no implementa GetProducts()")
	assert(type(provider.GetProduct) == "function", "[ShopRegistry] Proveedor no implementa GetProduct()")
	assert(type(provider.CanPurchase) == "function", "[ShopRegistry] Proveedor no implementa CanPurchase()")
	assert(type(provider.CanEquip) == "function", "[ShopRegistry] Proveedor no implementa CanEquip()")
	assert(type(provider.OnPurchased) == "function", "[ShopRegistry] Proveedor no implementa OnPurchased()")
	assert(type(provider.OnEquipped) == "function", "[ShopRegistry] Proveedor no implementa OnEquipped()")
	assert(type(provider.OnUnequipped) == "function", "[ShopRegistry] Proveedor no implementa OnUnequipped()")

	local category = provider:GetCategory()
	assert(type(category) == "string" and category ~= "", "[ShopRegistry] GetCategory() debe retornar un string no vacío")
	assert(self._providers[category] == nil, string.format("[ShopRegistry] Categoría duplicada: el proveedor para '%s' ya está registrado", category))

	local products = provider:GetProducts()
	assert(type(products) == "table", string.format("[ShopRegistry] GetProducts() para '%s' debe retornar una tabla", category))

	-- Validación e indexación de cada producto del proveedor
	for _, product in ipairs(products) do
		assert(type(product) == "table", string.format("[ShopRegistry] Producto inválido encontrado en la categoría '%s'", category))
		assert(type(product.Id) == "string" and product.Id ~= "", string.format("[ShopRegistry] Producto sin Id válido en la categoría '%s'", category))
		assert(product.Category == category, string.format("[ShopRegistry] Category del producto '%s' ('%s') no coincide con la categoría del provider ('%s')", product.Id, tostring(product.Category), category))
		assert(product.ProductType == "Cosmetic" or product.ProductType == "Consumable", string.format("[ShopRegistry] ProductType inválido ('%s') en el producto '%s'. Debe ser 'Cosmetic' o 'Consumable'", tostring(product.ProductType), product.Id))
		assert(type(product.DisplayName) == "string" and product.DisplayName ~= "", string.format("[ShopRegistry] DisplayName inválido en el producto '%s'", product.Id))
		assert(type(product.Price) == "number" and product.Price >= 0 and product.Price < math.huge and product.Price % 1 == 0, string.format("[ShopRegistry] Price inválido (debe ser >= 0) en el producto '%s'", product.Id))
		assert(product.Currency == "Coins" or product.Currency == "Robux", string.format("[ShopRegistry] Currency inválido ('%s') en el producto '%s'. Debe ser 'Coins' o 'Robux'", tostring(product.Currency), product.Id))
		assert(type(product.IsAvailable) == "boolean", string.format("[ShopRegistry] IsAvailable debe ser booleano en el producto '%s'", product.Id))

		if product.Currency == "Robux" then
			assert(type(product.RobloxProductId) == "number" and product.RobloxProductId > 0, string.format("[ShopRegistry] Producto Robux '%s' requiere un RobloxProductId numérico positivo obligatorio", product.Id))
		end

		local key = category .. ":" .. product.Id
			assert(self._productsById[key] == nil, string.format("[ShopRegistry] Id de producto duplicado detectado: '%s'", product.Id))

		self._productsById[key] = product
		if product.RobloxProductId then
			self._productsByRobloxId[product.RobloxProductId] = product
		end
	end

	self._providers[category] = provider
	print(string.format("[ShopRegistry] Proveedor registrado exitosamente para la categoría '%s' (%d productos indexados)", category, #products))
end

-- ==================================================
-- CONSULTA Y RESOLUCIÓN
-- ==================================================

-- Retorna el ProductProvider registrado para una categoría
function ShopRegistry:GetProvider(category: string): ProductProvider?
	if type(category) ~= "string" or category == "" then
		return nil
	end
	return self._providers[category]
end

-- Retorna todos los proveedores registrados en un diccionario por categoría
function ShopRegistry:GetProviders(): { [string]: ProductProvider }
	local copy: { [string]: ProductProvider } = {}
	for category, provider in pairs(self._providers) do
		copy[category] = provider
	end
	return copy
end

-- Identity is (Category, Id). An ambiguous legacy Id alone is rejected.
function ShopRegistry:GetProduct(productId: string, category: string?): ProductDefinition?
 if type(productId) ~= "string" or productId == "" then return nil end
 if category ~= nil then
  if type(category) ~= "string" or category == "" then return nil end
  if not self._productsById[category .. ":" .. productId] then return nil end
  local provider = self:GetProvider(category)
  return if provider then provider:GetProduct(productId) else nil
 end
 -- Legacy one-argument API remains valid only for unambiguous IDs.
 local result: ProductDefinition? = nil
 for _, product in pairs(self._productsById) do
  if product.Id == productId then
   if result then return nil end
   result = product
  end
 end
 return if result then self:GetProduct(result.Id,result.Category) else nil
end

-- Retorna la definición de un producto por su RobloxProductId oficial
function ShopRegistry:GetProductByRobloxId(robloxId: number): ProductDefinition?
	if type(robloxId) ~= "number" or robloxId <= 0 then
		return nil
	end
	return self._productsByRobloxId[robloxId]
end

-- Retorna el catálogo completo unificado de todos los productos registrados
function ShopRegistry:GetCatalog(): { ProductDefinition }
	local catalog: { ProductDefinition } = {}
	for _, product in pairs(self._productsById) do
		local current = self:GetProduct(product.Id, product.Category)
		if current then table.insert(catalog, current) end
	end
	return catalog
end

-- Retorna los productos pertenecientes a una categoría específica
function ShopRegistry:GetCategoryProducts(category: string): { ProductDefinition }
	local provider = self:GetProvider(category)
	if not provider then
		return {}
	end
	return provider:GetProducts()
end

-- Verifica si existe un proveedor registrado para una categoría
function ShopRegistry:HasCategory(category: string): boolean
	return self._providers[category] ~= nil
end

-- Verifica si existe un producto registrado por su Id
function ShopRegistry:HasProduct(productId: string): boolean
	return self:GetProduct(productId) ~= nil
end

-- Limpia todos los proveedores y productos registrados (útil para pruebas o reinicialización)
function ShopRegistry:Clear()
	self._providers = {}
	self._productsById = {}
	self._productsByRobloxId = {}
end

return ShopRegistry
