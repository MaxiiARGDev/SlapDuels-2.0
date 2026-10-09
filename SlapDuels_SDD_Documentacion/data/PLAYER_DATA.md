# PLAYER STATS — Coins / Wins / Kills

> Documento de referencia para desarrollo.
> Antes de modificar o crear sistemas relacionados con Coins, Wins o Kills,
> consultar este documento.

---

## 1. Fuente de verdad

Las estadísticas persistentes del jugador son:

- Coins
- Wins
- Kills

La fuente autoritativa en runtime es:

`PlayerService._data[player]`

La persistencia está gestionada por:

`PlayerDataService`

No existen fuentes paralelas de verdad.

---

## 2. Arquitectura

```text
PlayerDataService
       │
       │ carga / guarda
       ▼
PlayerService._data[player]
       │
       ├──────────────► Player HUD
       │                DataUpdated
       │
       ├──────────────► leaderstats
       │                 │
       │                 ▼
       │            Roblox PlayerList
       │
       └──────────────► Inventory API (Shop / Providers)
                         │
                         ▼
                    Generic Cosmetics
```

---

## 3. Schema V2 — PlayerData & Inventory

A partir de la Versión 2 del DataStore (`Config.DataStore.CurrentVersion = 2`), el `PlayerData` y su registro persistente `PlayerDataRecord` incluyen formalmente el subsistema genérico de `Inventory`.

### Estructura de Datos (Schema V2)

```luau
export type PlayerInventory = {
    -- Diccionario genérico: Category -> ProductId -> boolean
    Owned: {
        [string]: { [string]: boolean },
    },

    -- Diccionario genérico: Category -> ProductId activo
    Equipped: {
        [string]: string?,
    },
}

export type PlayerData = {
    Coins: number,
    Wins: number,
    Losses: number,
    Kills: number,
    Inventory: PlayerInventory,
}

export type PlayerDataRecord = {
    Version: number, -- 2
    Coins: number,
    Wins: number,
    Losses: number,
    Kills: number,
    Inventory: PlayerInventory,
    LastSaved: number?,
}
```

---

## 4. Migración V1 → V2

La migración es **automática, determinista e idempotente**, gestionada dentro de `PlayerDataService:ValidatePlayerData(raw)`.

- **Registros Versión 1:** Carecen de la tabla `Inventory`. Al cargarse, `PlayerDataService` crea la estructura por defecto:
  - `Owned.PointEffects["Basic"] = true`
  - `Equipped.PointEffects = "Basic"`
  - Preserva intactos: `Coins`, `Wins`, `Losses`, `Kills` y `LastSaved`.
  - Promociona la versión a `Version = 2`.
- **Registros Versión 2:** Si ya contienen `Inventory`, se valida profundamente y se sanitiza sin resetear posesiones existentes.

---

## 5. Regla de Basic, Categorías Futuras y Protección contra Corrupción

1. **Persistencia Explícita de `Basic`:**
   `Basic` (`PointEffectDefinitions.DefaultEffectId`) es de posesión universal. En `Inventory.Owned.PointEffects`, siempre debe estar presente `["Basic"] = true`.
   Si `Equipped.PointEffects` es `nil`, está corrupto o apunta a un ítem no poseído, el validador y `PlayerService` ejecutan fallback seguro e inmediato a `"Basic"`.
2. **Preservación de Categorías Desconocidas:**
   `PlayerDataService` es agnóstico del catálogo. Si en el DataStore se encuentran categorías futuras (ej. `Trails`, `Slaps`, `Auras`), la sanitización las **preserva intactas** siempre que cumplan con la estructura de diccionario válida.
3. **Protección contra Pérdida de Datos (`DataNotLoaded` e `IncompatibleVersion`):**
   - Si la carga de datos del jugador falla durante el inicio de sesión, `PlayerDataService:SavePlayer` **rechaza estrictamente cualquier guardado** para ese jugador (`DataNotLoaded`), impidiendo sobreescribir datos preexistentes con valores iniciales.
   - Si un registro en el DataStore posee una versión superior a la soportada (`raw.Version > CurrentVersion`), `ValidatePlayerData` y `LoadPlayer` rechazan la normalización silenciosa para no degradar el esquema a V2 y activan el estado `IncompatibleVersion`. Todo guardado subsiguiente es **bloqueado de forma explícita** tanto en la verificación de estado como en la callback atómica de `UpdateAsync`.

---

## 6. Única Fuente de Verdad en Runtime: `PlayerService`

`PlayerService._data[player].Inventory` es la **única fuente de verdad** en memoria durante la partida.
No existen tablas de inventario paralelas ni DataStores adicionales.

### API Genérica de Inventario (`PlayerService`)
- `PlayerService:GetInventory(player)`
- `PlayerService:HasItem(player, category, productId)`
- `PlayerService:AddItem(player, category, productId)`
- `PlayerService:GetEquippedItem(player, category)`
- `PlayerService:SetEquippedItem(player, category, productId)`
- `PlayerService:UnequipItem(player, category)`

Los métodos específicos preexistentes (`HasPointEffect`, `AddOwnedPointEffect`, `GetEquippedPointEffect`, `SetEquippedPointEffect`) operan como wrappers directos sobre esta API genérica para mantener compatibilidad total con `PointFeedbackService`.
