--!strict
-- Types
-- Definiciones de tipos Luau compartidas para tipado progresivo.

export type RoundStateName = "Waiting" | "Intermission" | "Starting" | "Playing" | "Ending"

export type PlayerStats = {
	wins: number,
	losses: number,
	eliminations: number,
}

export type Service = {
	Name: string?,
	Init: (self: Service, context: { [string]: any }?) -> (),
	Start: (self: Service, context: { [string]: any }?) -> (),
}

return {}
