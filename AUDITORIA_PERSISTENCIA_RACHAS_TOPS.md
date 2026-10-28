# AUDITORÍA TÉCNICA: PERSISTENCIA DE JUGADORES, RACHAS Y LEADERBOARDS GLOBALES
**Proyecto:** SlapDuels 2.0  
**Fecha:** 26 de Octubre de 2026  
**Objetivo:** Análisis autoritativo de datos persistentes (`Wins`, `Kills`, `Rachas`) y arquitectura para las tres pantallas físicas de Tops en el Lobby.

---

## 1. ARQUITECTURA DE PERSISTENCIA ACTUAL

### 1.1 Proveedores y Entornos (`PersistenceEnvironment.luau`)
El juego cuenta con un discriminador autoritativo de entornos de persistencia:
* **Entorno Studio (`RunService:IsStudio() == true`):**
  * Utiliza `InMemoryDataStore.new()`.
  * No escribe en DataStores reales de Roblox Cloud para evitar contaminación de perfiles de prueba.
* **Entorno Producción:**
  * Valida que el `game.GameId` coincida con el Universe ID aprobado (`10769217377`).
  * Utiliza `RobloxDataStoreAdapter.new("SlapDuels_PlayerData_v1")` conectado a `DataStoreService`.
  * Emplea control de concurrencia y session locking mediante `ProfileSessions.luau` con heartbeats periódicos (cada 45–55s) y `BindToClose`.

### 1.2 Estructura y Esquema del Perfil (`PlayerDataRecord`)
Cada jugador se almacena bajo la clave: `Player_<UserId>` con el siguiente esquema validado en [PlayerDataService.luau](file:///h:/repos-github/SlapDuels-2.0/src/server/Services/PlayerDataService.luau):

```luau
export type PlayerDataRecord = {
    Version: number,            -- Versión actual del esquema (2)
    Coins: number,              -- Monedas del jugador
    Wins: number,               -- Total acumulado histórico de victorias
    Losses: number,             -- Total acumulado histórico de derrotas
    Kills: number,              -- Total acumulado histórico de eliminaciones
    WinStreak: WinStreakRecord, -- Objeto con estado y contador de rachas
    Progression: any,           -- Pase de batalla y progreso de temporada
    Preferences: any,           -- Ajustes (música, volumen, etc.)
    Inventory: PlayerInventory, -- Efectos, Slaps, Cajas, Habilidades
    LastSaved: number,          -- Timestamp os.time() del último guardado
}
```

---

## 2. AUDITORÍA DE VICTORIAS (`Wins`) Y ELIMINACIONES (`Kills`)

### 2.1 Victorias (`Wins`)
* **Mutación autoritativa:** Se gestiona en `PlayerService:AddWin(player, reason)`.
  * Se incrementa en `+1` al ganar una partida de duelo en `RoundService` tras declarar victoria.
  * Se refleja en tiempo real en la carpeta `player.leaderstats.Wins.Value`.
  * Se notifica al cliente mediante `PlayerService:_sendDataUpdate(player)`.
* **Persistencia:** En `PlayerDataService:SavePlayer`, el campo se persiste de forma sanitizada:
  ```luau
  Wins = math.max(0, math.floor(runtimeData.Wins or 0))
  ```

### 2.2 Eliminaciones (`Kills`)
* **Mutación autoritativa:** Se gestiona en `PlayerService:AddKill(player, amount, reason)`.
  * Se dispara desde `EliminationService` cuando un jugador elimina a su rival en combate.
  * Se refleja en tiempo real en la carpeta `player.leaderstats.Kills.Value`.
  * Se notifica al cliente mediante `PlayerService:_sendDataUpdate(player)`.
* **Persistencia:** En `PlayerDataService:SavePlayer`, el campo se persiste sanitizado:
  ```luau
  Kills = math.max(0, math.floor(runtimeData.Kills or 0))
  ```

---

## 3. AUDITORÍA DE RACHAS (`WinStreak` / `Racha`)

### 3.1 Regla Autoritativa de Racha
En SlapDuels 2.0 rige la regla oficial:
$$\mathbf{3 \text{ Victorias Consecutivas}} = \mathbf{1 \text{ Racha Acumulada}}$$

Esta regla está configurada en [SocialPlayConfig.luau](file:///h:/repos-github/SlapDuels-2.0/src/shared/SocialPlayConfig.luau):
```luau
WinBlockSize = 3
```

### 3.2 Estructura de Datos de Racha (`WinStreakRecord`)
Definida en [Types.luau](file:///h:/repos-github/SlapDuels-2.0/src/shared/Types.luau) y normalizada en [WinStreak.luau](file:///h:/repos-github/SlapDuels-2.0/src/server/Services/Gameplay/WinStreak.luau):
```luau
export type WinStreakRecord = {
    Total: number,         -- Cantidad total de rachas completadas (permanentes)
    Progress: number,      -- Progreso actual de victorias consecutivas (0, 1 o 2)
    LastMatchId: string?,  -- Idempotencia para evitar contar dos veces la misma partida
}
```

### 3.3 Mecánica de Transición de Estados
Al finalizar una partida, `RoundService` invoca `PlayerService:RecordStreakResult(player, matchId, outcome)`:
* **Si el jugador GANA (`outcome == 'Win'`):**
  * `stats.Progress += 1`
  * Si `stats.Progress == 3`:
    * `stats.Total += 1` (acredita una racha completa permanente).
    * `stats.Progress = 0` (inicia el conteo para el siguiente bloque de 3).
* **Si el jugador PIERDE o EMPATA (`outcome == 'Loss'` o `'Draw'`):**
  * `stats.Progress = 0` (se pierde el progreso inconcluso hacia la próxima racha).
  * `stats.Total` **SE MANTIENE INTACTO** (las rachas ganadas son permanentes y no se restan).
* **Consumo en la UI y Perfil:**
  * En `PlayerProfileHUD`, `PublicInventory` y `SocialController`, la estadística denominada **"RACHAS"** corresponde exactamente al valor entero de:
    $$\text{Rachas} = \mathbf{data.WinStreak.Total}$$

---

## 4. ANÁLISIS DE REQUERIMIENTOS PARA LAS 3 TABLAS FÍSICAS

### 4.1 Mapeo de Pantallas en `game.Workspace.stands["TOPS-SCREENS"]`
El modelo de pantallas físicas en el Workspace ya tiene nombradas y ubicadas las 3 estructuras:

| Pantalla Física | Modelo Padre | Estadística Asociada | Campo Autoritativo | Ícono Puestos 4 al 50 |
| :--- | :--- | :--- | :--- | :--- |
| **`Screen_TopWins`** | `TopWins` | **Victorias** | `PlayerData.Wins` | `Assets.Icons.Top_All_Wins` |
| **`Screen_TopKills`** | `TopKills` | **Kills** | `PlayerData.Kills` | `Assets.Icons.Top_All_Kills` |
| **`Screen_TopRachas`** | `TopRachas` | **Rachas** | `PlayerData.WinStreak.Total` | `Assets.Icons.Top_All_Streak` |

*Para los puestos 1, 2 y 3, las tres tablas consumen los íconos únicos de podio: `Top_1`, `Top_2` y `Top_3`.*

### 4.2 Necesidad Técnica de `OrderedDataStore`
* El `DataStore` normal (`SlapDuels_PlayerData_v1`) guarda el diccionario completo por jugador y **no permite ordenar o extraer los 50 mayores puntajes globales** (`GetSortedAsync` no existe en DataStore común).
* Por lo tanto, para soportar un Top 50 global entre todos los servidores de Roblox, se implementarán **3 `OrderedDataStore` específicos**:
  1. `SlapDuels_TopWins_v1`
  2. `SlapDuels_TopKills_v1`
  3. `SlapDuels_TopRachas_v1`
* **Manejo en Studio / Testing:**
  * Al igual que `PlayerDataService`, si estamos en Studio (donde las llamadas Cloud están desactivadas), el nuevo servicio tendrá un **Mock/Fallback de datos realistas** para que las 3 pantallas se rendericen y scrolleen fluidamente sin errores.

---

## 5. CONCLUSIÓN Y PRÓXIMOS PASOS

1. **Datos listos y autoritativos:** La persistencia de `Wins`, `Kills` y `Rachas` (`WinStreak.Total`) está totalmente identificada y documentada.
2. **Listo para implementar:**
   * Crear el servicio autoritativo de actualización de leaderboards (`LeaderboardService`).
   * Aplicar el diseño probado y sincronizado en las 3 pantallas (`Screen_TopWins`, `Screen_TopKills`, `Screen_TopRachas`).
   * Habilitar la interacción física (scroll) para los jugadores frente a cada pantalla.
