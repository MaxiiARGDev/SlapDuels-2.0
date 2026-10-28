# Slap Duels 2.0 — Datos e inventario

> Documento de referencia para desarrollo.
> Antes de modificar o crear sistemas relacionados con estadísticas o inventario,
> consultar este documento.

---

## Fuente de verdad

Las estadísticas persistentes del jugador son:

- Coins
- Wins
- Losses
- Kills

La fuente autoritativa en runtime es:

`PlayerService._data[player]`

La persistencia está gestionada por:

`PlayerDataService`

No existen fuentes paralelas de verdad.

---

## Arquitectura

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

## Schema V2 — PlayerData & Inventory

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

## Migración V1 → V2

La migración es **automática, determinista e idempotente**, gestionada dentro de `PlayerDataService:ValidatePlayerData(raw)`.

- **Registros Versión 1:** Carecen de la tabla `Inventory`. Al cargarse, `PlayerDataService` crea la estructura por defecto:
  - `Owned.PointEffects["Basic"] = true`
  - `Equipped.PointEffects = "Basic"`
  - Preserva intactos: `Coins`, `Wins`, `Losses`, `Kills` y `LastSaved`.
  - Promociona la versión a `Version = 2`.
- **Registros Versión 2:** Si ya contienen `Inventory`, se valida profundamente y se sanitiza sin resetear posesiones existentes.

---

## Regla de Basic, Categorías Futuras y Protección contra Corrupción

1. **Persistencia Explícita de `Basic`:**
   `Basic` (`PointEffectDefinitions.DefaultEffectId`) es de posesión universal. En `Inventory.Owned.PointEffects`, siempre debe estar presente `["Basic"] = true`.
   Si `Equipped.PointEffects` es `nil`, está corrupto o apunta a un ítem no poseído, el validador y `PlayerService` ejecutan fallback seguro e inmediato a `"Basic"`.
2. **Preservación de Categorías Desconocidas:**
   `PlayerDataService` es agnóstico del catálogo. Si en el DataStore se encuentran categorías futuras (ej. `Trails`, `Slaps`, `Auras`), la sanitización las **preserva intactas** siempre que cumplan con la estructura de diccionario válida.
3. **Protección contra Pérdida de Datos (`DataNotLoaded` e `IncompatibleVersion`):**
   - Si la carga de datos del jugador falla durante el inicio de sesión, `PlayerDataService:SavePlayer` **rechaza estrictamente cualquier guardado** para ese jugador (`DataNotLoaded`), impidiendo sobreescribir datos preexistentes con valores iniciales.
   - Si un registro en el DataStore posee una versión superior a la soportada (`raw.Version > CurrentVersion`), `ValidatePlayerData` y `LoadPlayer` rechazan la normalización silenciosa para no degradar el esquema a V2 y activan el estado `IncompatibleVersion`. Todo guardado subsiguiente es **bloqueado de forma explícita** tanto en la verificación de estado como en la callback atómica de `UpdateAsync`.

---

## Única Fuente de Verdad en Runtime: `PlayerService`

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

## Configuración y validación del registro

El nombre de DataStore permanece estable: `SlapDuels_PlayerData_v1`; el sufijo del nombre no es la versión del esquema. `Config.DataStore.CurrentVersion = 2`. No se cambia de DataStore para migrar V1→V2.

Las estadísticas se validan como enteros finitos no negativos. Los campos ausentes o corruptos se normalizan según el schema, sin sustituir una carga fallida por un perfil guardable. MaxRetries=3, InitialRetryDelay=1.0 y RetryBackoffMultiplier=2.0 definen los reintentos. Una versión futura se rechaza y bloquea el guardado; no se normaliza a V2.

### Ciclo de Vida: Carga (Load) y Prevención de Flicker
- **Flujo al entrar el jugador (`PlayerAdded`):**
  1. `PlayerService:_register(player)` inicia el registro runtime.
  2. Estado marcado como `DataLoadState[player] = "Loading"`.
  3. `PlayerDataService:LoadPlayer(player)` consulta el DataStore (`GetAsync`) usando la clave `Player_<UserId>`.
  4. **Retries controlados:** Hasta 3 intentos con retroceso exponencial (`1.0s`, `2.0s`, etc.) protegidos por `pcall`.
  5. Al recibir respuesta válida:
     - Se valida la integridad con `ValidatePlayerData`.
     - Se marca `DataLoadState[player] = "Loaded"`.
     - `PlayerService` aplica los valores directamente a su estado runtime (`_data[player]`).
     - Se emite `Remotes.Player.DataUpdated` al cliente.
  6. **Eliminación del parpadeo (Zero-Flicker):** El cliente recibe los datos persistidos reales en su primera emisión; el HUD nunca muestra un `0` temporal antes de reemplazarlo.

### Política de Seguridad ante Fallos de Carga (Safe Session Policy)
> [!CAUTION]
> **POLÍTICA CRÍTICA CONTRA PÉRDIDA DE DATOS:**
> Si `DataStoreService` falla tras agotar todos los reintentos:
> - `DataLoadState[player]` queda marcado como `"Failed"`.
> - **NUNCA** se sobrescriben los datos del jugador en DataStore con valores predeterminados (ceros).
> - `PlayerDataService:SavePlayer` **RECHAZA EXPRESAMENTE** cualquier intento de guardado para ese jugador durante toda la sesión (`loadState ~= "Loaded"`).
> - Se documenta el incidente en los logs del servidor (`[PlayerData] RECHAZO DE GUARDADO: Protección contra pérdida de datos activada`).

### Ciclo de Vida: Guardado (Save) y Concurrencia
- **Estrategia de Escritura Controlada:**
  - **NO** se ejecuta `SetAsync` ni `UpdateAsync` en cada `AddCoins()` (los puntos de partida son frecuentes y agotarían la cuota de DataStore).
  - Los cambios se acumulan de forma autoritativa en memoria (`PlayerService._data[player]`).
  - El guardado se ejecuta de forma controlada en:
    1. `PlayerRemoving` (salida del jugador).
    2. `game:BindToClose` (cierre o migración del servidor).
- **UpdateAsync y Concurrencia:**
  - Se utiliza `UpdateAsync` garantizando lecturas/escrituras atómicas.
  - La función de transformación combina los datos anteriores preservando atributos externos y actualizando `Coins`, `Wins`, `Losses`, `Kills`, `Inventory`, `Version` y `LastSaved`.
  - **Protección contra doble guardado simultáneo:** Se bloquea la concurrencia mediante `_saving[player] = true`. Llamadas concurrentes esperan activamente a que finalice el guardado en curso sin duplicar peticiones I/O.

### Cierre del Servidor (`BindToClose`)
- Conectado en `PlayerDataService:Init()`.
- Ejecuta `SaveAllPlayers()`:
  - Filtra a los jugadores con `DataLoadState == "Loaded"`.
  - Dispara el guardado de cada jugador en corutinas paralelas (`task.spawn`).
  - Utiliza un mecanismo de sincronización que cede el hilo principal (`task.wait(0.1)`) hasta que todas las tareas finalizan o hasta alcanzar un límite defensivo de 25 segundos (por debajo del límite de 30s de Roblox).

### Session Safety y Limitaciones Actuales
- **Evaluación de Session Locking:** El contrato actual no incluye leases ni candados distribuidos con heartbeat entre servidores. La incorporación de session locking requiere una decisión de diseño y validación específica.
- **Riesgo residual:** Si un jugador entra en otro servidor antes de finalizar el guardado del anterior, los snapshots pueden competir. No se define una ventana temporal segura sin un mecanismo de exclusión entre servidores. UpdateAsync es atómico por operación, pero no sustituye un bloqueo de sesión ni evita por sí solo sobrescrituras de snapshots de servidores distintos. Migraciones con token de sesión podrán añadirse en fases avanzadas de producción.

El HUD es una vista reactiva de estos datos; su contrato está en [UI](../presentation/UI.md). El inventario genérico no requiere otro DataStore.
