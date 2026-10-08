--!strict
-- PointEffectProvider
-- Adaptador entre el catálogo y estado de Point Effects y el Shop Framework.
-- Implementa estrictamente el contrato ProductProvider de Types.luau.
-- Reutiliza PointEffectDefinitions y PlayerService sin crear inventarios ni economías paralelas.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Types = require(ReplicatedStorage.Shared.Types)
local PointEffectDefinitions = require(ReplicatedStorage.Shared.PointEffectDefinitions)

type ProductDefinition = Types.ProductDefinition
type ProductProvider = Types.ProductProvider

local PointEffectProvider = {}

local _cachedProducts: { ProductDefinition }? = nil
local _playerService: any = nil

local function getPlayerService(): any
	if _playerService then
		return _playerService
	end

	local servicesFolder = ServerScriptService:FindFirstChild("Services")
	local mod = servicesFolder and servicesFolder:FindFirstChild("PlayerService")
	if mod and mod:IsA("ModuleScript") then
		local ok, result = pcall(require, mod)
		if ok and result then
			_playerService = result
			return result
		end
	end

	return nil
end

-- ==================================================
-- CONTRATO PRODUCT PROVIDER
-- ==================================================

function PointEffectProvider:GetCategory(): string
	return "PointEffects"
end

function PointEffectProvider:GetProducts(): { ProductDefinition }
	if _cachedProducts then
		return _cachedProducts
	end

	local products: { ProductDefinition } = {}
	local allDefs = PointEffectDefinitions.GetAll()

	for _, def in pairs(allDefs) do
		local prod: ProductDefinition = {
			Id = def.Id,
			Category = "PointEffects",
			ProductType = "Cosmetic",
			DisplayName = def.DisplayName,
			Description = def.Description,
			Price = def.Price,
			Currency = "Coins",
			IsAvailable = true,
			Rarity = def.Rarity,
			Metadata = {
				Rarity = def.Rarity,
			},
		}
		table.insert(products, prod)
	end

	-- Ordenar alfabéticamente o por precio para consistencia
	table.sort(products, function(a, b)
		if a.Price == b.Price then
			return a.Id < b.Id
		end
		return a.Price < b.Price
	end)

	_cachedProducts = products
	return products
end

function PointEffectProvider:GetProduct(productId: string): ProductDefinition?
	if type(productId) ~= "string" or productId == "" then
		return nil
	end

	local def = PointEffectDefinitions.Get(productId)
	if not def then
		return nil
	end

	return {
		Id = def.Id,
		Category = "PointEffects",
		ProductType = "Cosmetic",
		DisplayName = def.DisplayName,
		Description = def.Description,
		Price = def.Price,
		Currency = "Coins",
		IsAvailable = true,
		Rarity = def.Rarity,
		Metadata = {
			Rarity = def.Rarity,
		},
	}
end

function PointEffectProvider:CanPurchase(player: Player, product: ProductDefinition): (boolean, string?)
	if not player then
		return false, "InvalidPlayer"
	end

	if product.Category ~= "PointEffects" then
		return false, "InvalidCategory"
	end

	if not product.IsAvailable then
		return false, "ProductUnavailable"
	end

	local ps = getPlayerService()
	if not ps then
		return false, "PlayerServiceNotAvailable"
	end

	-- Si el jugador ya posee este cosmético, se rechaza la recompra
	if ps:HasPointEffect(player, product.Id) then
		return false, "AlreadyOwned"
	end

	return true, nil
end

function PointEffectProvider:CanEquip(player: Player, product: ProductDefinition): (boolean, string?)
	if not player then
		return false, "InvalidPlayer"
	end

	if product.Category ~= "PointEffects" then
		return false, "InvalidCategory"
	end

	if product.ProductType ~= "Cosmetic" then
		return false, "NotEquippable"
	end

	local ps = getPlayerService()
	if not ps then
		return false, "PlayerServiceNotAvailable"
	end

	-- Verificar si el jugador posee el efecto
	if not ps:HasPointEffect(player, product.Id) then
		return false, "NotOwned"
	end

	-- Verificar si ya está equipado actualmente
	if ps:GetEquippedPointEffect(player) == product.Id then
		return false, "AlreadyEquipped"
	end

	return true, nil
end

function PointEffectProvider:OnPurchased(player: Player, product: ProductDefinition): (boolean, string?)
	local ps = getPlayerService()
	if not ps then
		return false, "PlayerServiceNotAvailable"
	end

	local ok, err = ps:AddOwnedPointEffect(player, product.Id)
	if not ok then
		return false, err or "FailedToAddOwnership"
	end

	return true, nil
end

function PointEffectProvider:OnEquipped(player: Player, product: ProductDefinition): (boolean, string?)
	local ps = getPlayerService()
	if not ps then
		return false, "PlayerServiceNotAvailable"
	end

	local ok, err = ps:SetEquippedPointEffect(player, product.Id)
	if not ok then
		return false, err or "FailedToEquip"
	end

	return true, nil
end

function PointEffectProvider:OnUnequipped(player: Player, _product: ProductDefinition?): (boolean, string?)
	local ps = getPlayerService()
	if not ps then
		return false, "PlayerServiceNotAvailable"
	end

	-- Al desequipar un PointEffect, se restablece al efecto base universal (Basic)
	local ok, err = ps:SetEquippedPointEffect(player, PointEffectDefinitions.DefaultEffectId)
	if not ok then
		return false, err or "FailedToUnequip"
	end

	return true, nil
end

return PointEffectProvider
