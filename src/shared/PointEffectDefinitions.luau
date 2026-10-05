--!strict
-- PointEffectDefinitions
-- Catalogo centralizado de definiciones de Point Effects (cosmeticos equipables).
-- Define la identidad, visuales, rareza y metadatos de cada efecto.
-- No contiene logica de gameplay ni fisica.

export type PointEffectRarity = "Common" | "Rare" | "Epic" | "Legendary"

export type PointEffectDefinition = {
	Id: string,
	DisplayName: string,
	Rarity: PointEffectRarity,
	Price: number,
	Description: string?,
}

local PointEffectDefinitions = {}

PointEffectDefinitions.DefaultEffectId = "Basic"

PointEffectDefinitions.Registry = {
	["Basic"] = {
		Id = "Basic",
		DisplayName = "Básico",
		Rarity = "Common",
		Price = 0,
		Description = "Efecto clásico y directo por defecto.",
	},
	-- Efectos preparados para futuras etapas (editables en Studio):
	["Inferno"] = {
		Id = "Inferno",
		DisplayName = "Inferno",
		Rarity = "Rare",
		Price = 500,
		Description = "Llamaradas ardientes y estallido ígneo.",
	},
	["Frost"] = {
		Id = "Frost",
		DisplayName = "Frost",
		Rarity = "Rare",
		Price = 750,
		Description = "Onda glacial y fragmentos de hielo.",
	},
	["Thunder"] = {
		Id = "Thunder",
		DisplayName = "Thunder",
		Rarity = "Epic",
		Price = 1500,
		Description = "Descarga de relámpagos de alto voltaje.",
	},
	["Void"] = {
		Id = "Void",
		DisplayName = "Void",
		Rarity = "Legendary",
		Price = 3000,
		Description = "Colapso gravitacional y resonancia sombría.",
	},
} :: { [string]: PointEffectDefinition }

-- Obtiene la definicion de un efecto por su Id
function PointEffectDefinitions.Get(effectId: string?): PointEffectDefinition?
	if not effectId or typeof(effectId) ~= "string" then
		return nil
	end
	return PointEffectDefinitions.Registry[effectId]
end

-- Verifica si un effectId existe y es valido
function PointEffectDefinitions.IsValid(effectId: string?): boolean
	return PointEffectDefinitions.Get(effectId) ~= nil
end

-- Retorna la definicion obligatoria por defecto (Basic)
function PointEffectDefinitions.GetDefault(): PointEffectDefinition
	return PointEffectDefinitions.Registry[PointEffectDefinitions.DefaultEffectId]
end

-- Retorna todas las definiciones disponibles
function PointEffectDefinitions.GetAll(): { [string]: PointEffectDefinition }
	return PointEffectDefinitions.Registry
end

return PointEffectDefinitions
