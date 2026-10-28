--!nonstrict
-- =========================================================================
-- CONFIGURACIÓN DE LOS 4 PAQUETES DE MONEDAS (CREATOR HUB)
-- Pegá aquí el DeveloperProductId numérico de cada paquete creado en Roblox:
-- =========================================================================
local CONFIG = {
	{
		Id = "Coins_1000",
		Coins = 1000,
		Robux = 50,
		DeveloperProductId = 0, -- ← Pegar ID de Creator Hub aquí
	},
	{
		Id = "Coins_10000",
		Coins = 10000,
		Robux = 450,
		DeveloperProductId = 0, -- ← Pegar ID de Creator Hub aquí
	},
	{
		Id = "Coins_35000",
		Coins = 35000,
		Robux = 1250,
		DeveloperProductId = 0, -- ← Pegar ID de Creator Hub aquí
	},
	{
		Id = "Coins_100000",
		Coins = 100000,
		Robux = 3500,
		DeveloperProductId = 0, -- ← Pegar ID de Creator Hub aquí
	},
}

-- Construcción automática para el sistema comercial y el HUD:
local products = {}
for i, item in ipairs(CONFIG) do
	local isReal = type(item.DeveloperProductId) == "number" and item.DeveloperProductId > 0
	table.insert(products, {
		Id = item.Id,
		PackageId = item.Id,
		Category = "Coins",
		DisplayName = string.format("%d Coins", item.Coins),
		Description = "Coins para usar en la tienda del juego.",
		DeveloperProductId = if isReal then item.DeveloperProductId else (123456000 + i),
		IsPlaceholder = not isReal,
		SuggestedRobux = item.Robux,
		Coins = item.Coins,
		Rewards = { Coins = item.Coins, Crates = {}, Slaps = {}, KillEffects = {} },
		Icon = "",
		SortOrder = i * 10,
		Enabled = true,
		PurchaseApproved = isReal,
		ContentsApproved = true,
		DuplicatePolicy = "RepeatableNoCompensation",
		ContractVersion = "CoinsV1",
	})
end

return products
