Viewed RoundService.luau:1-180
Viewed RoundService.luau:580-680
Viewed SpawnService.luau:150-250
Viewed SpawnService.luau:245-340
Viewed ScoreService.luau:60-160
Viewed ScoreService.luau:520-640
Viewed ScoreService.luau:420-520
Viewed RoundService.luau:780-850
Viewed RoundService.luau:720-780
Viewed EliminationService.luau:1-140
Viewed EliminationService.luau:190-260
Viewed EliminationService.luau:260-320
Viewed CombatService.luau:1-80
Viewed Bootstrap.server.luau:1-100
Viewed RoundService.luau:890-950
Viewed RoundService.luau:430-480
Viewed RoundService.luau:360-430
Viewed RoundService.luau:300-360
Viewed RoundService.luau:190-250

# INFORME TÉCNICO PROFUNDO: LIFECYCLE, RESPAWN Y ELIMINACIONES
**Proyecto:** SlapDuels 2.0  
**Fecha:** 2026-10-05  
**Estado:** Inspección & Análisis Arquitectónico Read-Only (Sin modificaciones a código ni archivos)  
**Fuente de Verdad:** Repositorio en GitHub sincronizado (`master` limpio).

---

## 1. FLUJO EXACTO ACTUAL DE RESPAWN

En la arquitectura actual conviven dos mecánicas de respawn que colisionan entre sí:

```
[Muerte o Caída a FallenPartsDestroyHeight (-500)]
                     │
                     ▼
           [Engine de Roblox]
   (CharacterAutoLoads = true, RespawnTime = 3)
                     │
         Espera 3s internamente
                     │
                     ▼
          [Llamada a LoadCharacter]
    ¿Existe player.RespawnLocation?
            NO (es nil)
                     │
                     ▼
   Busca SpawnLocation en Workspace
    Encuentra: Workspace.Lobby.SpawnLocation (ÚNICO en el juego)
                     │
                     ▼
  [Personaje aparece físicamente en el LOBBY]
                     │
     Se dispara player.CharacterAdded
                     │
        ┌────────────┴────────────┐
        ▼                         ▼
   [Fuera de Match]        [En Match Activo]
   Permanece en Lobby      SpawnService recibe CharacterAdded
                           task.defer()
                           Evalúa isAlive (Race condition!)
                           Si falla -> Llama a LoadCharacter() OTRA VEZ
                           Si pasa  -> PivotTo(ArenaSpawn)
```

1. **Destrucción o Muerte:** El personaje cae por debajo de `workspace.FallenPartsDestroyHeight` ($-500$) o su `Humanoid.Health` llega a 0.
2. **Activación Nativa:** El motor de Roblox toma el control absoluto mediante `Players.CharacterAutoLoads = true` con una cuenta regresiva fija de `Players.RespawnTime = 3`.
3. **Generación en Lobby:** Al terminar los 3 segundos, Roblox crea el nuevo modelo del personaje y, al no existir `player.RespawnLocation` asignado, busca el único `SpawnLocation` neutro activo: `game.Workspace.Lobby.SpawnLocation`.
4. **Reacción Tardía de `SpawnService`:** `SpawnService:StartMatchRespawnTracking` escucha `player.CharacterAdded`. Cuando el evento dispara, el personaje ya fue posicionado físicamente por Roblox en el Lobby.
5. **Corrección vía `task.defer`:** `SpawnService` intenta ejecutar `self:SpawnPlayerInMatch(session, player)` para hacer `character:PivotTo(arenaSpawn)`.

---

## 2. QUÉ COMPONENTE ES RESPONSABLE DE CADA TRANSICIÓN

| Transición / Evento | Componente Responsable Actual | Estado de la Partida | Problema o Defecto Observado |
| :--- | :--- | :--- | :--- |
| **Generación inicial en Lobby** | Roblox Engine (`CharacterAutoLoads`) | `Waiting` | Correcto. El lobby es el spawn por defecto para jugadores libres. |
| **Teletransporte a la Arena** | `SpawnService:SpawnMatchPlayers` / `RoundService` | `StartCountdown` | Funciona, pero si el personaje muere durante `StartCountdown`, el tracking de respawn de la arena aún **no está activo**. |
| **Tracking de Respawn en Arena** | `SpawnService:StartMatchRespawnTracking` | Solo en `Playing` | **Falla:** Inicia recién en `Playing` (RoundService:612) y se corta de inmediato en `Ending` (RoundService:670). Ignora `StartCountdown` y `Ending`. |
| **Muerte física / Caída al vacío** | Roblox Physics Engine ($-500$) | Cualquiera | Incondicional. Destruye el rig y gatilla `LoadCharacter` nativo hacia el Lobby. |
| **Atribución de Kill** | `EliminationService:OnPlayerEliminated` | `Playing` | Correcto en atribución, pero **no maneja el respawn** de la víctima. |
| **Detección de Gol (Point)** | `ScoreService:_handleZoneScoring` | `Playing` | Registra el punto y marca `session.PointInProgress = true` y `session.PointScorer = player`. |
| **Reset tras Gol** | `RoundService:TriggerPointRestart` | `PointRestartCountdown` | Espera 1.5s, llama a `SpawnService:SpawnMatchPlayers` y corre countdown de 3s. Si el scorer murió a $-500$, compite con el timer de 3s de Roblox. |
| **Retorno al Lobby** | `RoundService:_runSession` / `SpawnService:ReturnPlayersToLobby` | `ReturningToLobby` | Correcto, teletransporta a los jugadores de vuelta al Lobby Spawn y limpia la arena. |

---

## 3. TODAS LAS POSIBLES CARRERAS ENTRE ROBLOX RESPAWN Y SPAWNSERVICE

Se han detectado cuatro condiciones de carrera críticas:

### Carrera 1: La brecha temporal de `RespawnTime` (3s) vs `PointResetDelay` (1.5s)
- **Escenario:** El jugador anota a $t = 0$ y cae al vacío alcanzando $-500$ a $t = 0.5$.
- A $t = 0.5$, el engine inicia su timer de respawn de **3 segundos** (respawnearía a $t = 3.5$).
- A $t = 1.5$ (`PointResetDelay`), `RoundService` invoca `SpawnService:SpawnMatchPlayers(session)`.
- **Conflicto:** A $t = 1.5$, el personaje anotador está **muerto o en proceso de ser destruido**. `SpawnService` detecta `isAlive == false` y fuerza un `player:LoadCharacter()` imperativo. Ambos llamados a `LoadCharacter` colisionan.

### Carrera 2: Race Condition en `CharacterAdded` e `isAlive`
- En [SpawnService.luau:150-170](file:///h:/repos-github/SlapDuels-2.0/src/server/Services/SpawnService.luau#L150-L170), dentro de `TeleportCharacterToSpawn`:
  ```luau
  local isAlive = character and character.Parent and humanoid and humanoid.Health > 0 and rootPart and ...
  if not isAlive then
      player:LoadCharacter() -- ¡RECARGA RECURSIVA!
  end
  ```
- Cuando Roblox dispara `CharacterAdded`, `HumanoidRootPart` frecuentemente **no está instanciado en el primer frame**. `rootPart` es `nil`, `isAlive` evalúa a `false`, y `SpawnService` ordena una segunda recarga completa del personaje.

### Carrera 3: Muerte durante `StartCountdown` (5 segundos)
- `SpawnService:StartMatchRespawnTracking` solo se conecta al entrar a `Playing` ([RoundService.luau:612](file:///h:/repos-github/SlapDuels-2.0/src/server/Services/RoundService.luau#L612)).
- Si un jugador cae o muere durante los 5 segundos de `StartCountdown`, el evento `CharacterAdded` no tiene listener de arena: **el jugador respawnea en el Lobby y se queda allí toda la partida.**

### Carrera 4: Muerte durante `Ending` (4 segundos)
- En [RoundService.luau:670](file:///h:/repos-github/SlapDuels-2.0/src/server/Services/RoundService.luau#L670), al definirse el ganador se ejecuta inmediatamente:
  ```luau
  spawnService:StopMatchRespawnTracking(session.Id)
  ```
- La partida permanece 4 segundos mostrando la pantalla de victoria antes de `ReturningToLobby`. Si un jugador cae al vacío durante estos 4 segundos, como el tracking se apagó, respawnea de inmediato en el Lobby antes de tiempo.

---

## 4. QUÉ OCURRE EXACTAMENTE EN `PointScoreDeath`

1. **Entrada a Zona de Gol:** El jugador cruza `RedWin` o `BlueWin`.
2. **Registro de Scorer:** [ScoreService.luau:421-425](file:///h:/repos-github/SlapDuels-2.0/src/server/Services/ScoreService.luau#L421-L425) marca atómicamente:
   ```luau
   session.PointInProgress = true
   session.PointScorer = player
   session.PointScorerTeam = team
   session.PointScoreTimestamp = os.clock()
   ```
3. **Caída y Muerte:** El jugador cae al vacío hacia $-500$ o toca una killpart posterior.
4. **Protección en Eliminaciones:** `EliminationService:OnPlayerEliminated` intercepta la muerte:
   ```luau
   if session.PointInProgress and session.PointScorer == victim then
       combatService:ClearCombatTag(victim)
       return false, nil -- NO genera kill ni eliminación
   end
   ```
5. **El Fallo Actual:** Aunque `EliminationService` no le da la kill al rival, **no puede detener la física de Roblox**. El personaje muere a $-500$, Roblox llama a `LoadCharacter()` y el jugador es colocado en `Workspace.Lobby.SpawnLocation`.
6. **Desconexión con `PointRestartCountdown`:** Cuando `RoundService` finaliza la cuenta de 3 segundos, asume que los jugadores están vivos en sus spawns, pero el anotador quedó varado en el Lobby si su respawn ocurrió desfasado.

---

## 5. QUÉ OCURRE EXACTAMENTE EN `CombatElimination`

1. **Golpe Válido:** Un jugador recibe un slap; `CombatService` almacena el `CombatTag` con `Attacker = rival`, `MatchId` y timestamp.
2. **Caída al Vacío:** El jugador cae y toca un `KillPart` o muere al alcanzar $-500$.
3. **Resolución:** `EliminationService:OnPlayerEliminated` valida que `session.PointInProgress == false` (o `session.PointScorer ~= victim`), verifica `Anti-Duplicate`, comprueba la ventana `LastHitLifetime` (10s) y otorga autoritativamente $+1$ Kill al atacante vía `PlayerService:AddKills()`.
4. **Respawn:** `EliminationService` dispara el BindableEvent `PlayerEliminated`. **Ningún servicio escucha este bindable.** La víctima depende enteramente del respawn automático de 3 segundos de Roblox, reapareciendo en el Lobby y dependiendo de que el `CharacterAdded` de `SpawnService` intercepte y lo teletransporte de nuevo a la arena.

---

## 6. QUÉ OCURRE DURANTE `Ending`

1. Se determina el ganador (por alcanzar 5 puntos o por timer agotado).
2. [RoundService.luau:670](file:///h:/repos-github/SlapDuels-2.0/src/server/Services/RoundService.luau#L670) ejecuta `spawnService:StopMatchRespawnTracking(session.Id)`.
3. Se detiene el scoring y se limpian los combat tags.
4. Se procesan las recompensas (`_processReward`).
5. Se muestra la pantalla de victoria durante `Config.Round.EndingDisplayTime` (4 segundos).
6. **Vulnerabilidad:** Si durante estos 4 segundos un jugador es empujado al vacío por inercia o física residual, al no haber tracking de arena, su personaje carga directamente en `Workspace.Lobby.SpawnLocation`, rompiendo la presentación de victoria.

---

## 7. QUÉ OCURRE DURANTE `PlayerRemoving`

En [RoundService.luau:905-933](file:///h:/repos-github/SlapDuels-2.0/src/server/Services/RoundService.luau#L905-L933):
```luau
function RoundService:_handlePlayerLeaving(player: Player)
    local session = self._currentSession
    if not session then return end
    if player ~= session.RedPlayer and player ~= session.BluePlayer then return end

    if self._state == Constants.RoundState.Playing or self._state == Constants.RoundState.PointRestartCountdown then
        local winner: MatchResultName = if player == session.RedPlayer
            then Constants.MatchResult.Blue
            else Constants.MatchResult.Red
        session.Result = winner
        -- ...
```
1. **Acoplamiento 1v1 Estricto:** Comprueba directamente `player ~= session.RedPlayer and player ~= session.BluePlayer`. No itera sobre listas de equipo (`session.RedTeam`, `session.BlueTeam`).
2. **Ignora el Marcador (0-0 vs Puntuado):** Otorga la victoria incondicional al jugador que se queda, incluso si la partida recién empezaba y el marcador estaba 0-0.
3. **Fase Pre-Playing:** Si el abandono ocurre en `MatchReady`, `MatchCountdown`, `MapSelection`, `MapLoading` o `StartCountdown`, cancela la partida limpiamente vía `_cancelSession("PlayerDisconnected")`.

---

## 8. RESPONSABILIDADES DE `SpawnService`

`SpawnService` debe ser el **brazo ejecutor de posicionamiento físico y teletransporte**, pero NO el decisor de estados:

- Obtener y validar las coordenadas físicas de spawns de arena (`_getSpawnPoints`).
- Teletransportar personajes de forma segura (`TeleportCharacterToSpawn`, asegurando `AssemblyLinearVelocity = 0`, orientación y elevación).
- Teletransportar a todos los jugadores de un match a sus spawns de equipo (`SpawnMatchPlayers`).
- Configurar y limpiar la propiedad nativa de destino de respawn del jugador (`player.RespawnLocation`).
- Retornar a los jugadores al Lobby al concluir la sesión (`ReturnPlayersToLobby`).

---

## 9. RESPONSABILIDADES DE `RoundService`

`RoundService` debe ser la **ÚNICA AUTORIDAD de Lifecycle y Estado**:

- Orquestar la máquina de estados completa (`MatchReady` -> ... -> `ReturningToLobby`).
- Indicar a `SpawnService` **cuándo** un jugador entra a la arena y **cuándo** se le permite volver al Lobby.
- Controlar el ciclo de vida del match: iniciar y cancelar tracking de respawns en el momento exacto (desde `MatchReady` hasta `ReturningToLobby`).
- Controlar la pausa, reanudación y conteos de reinicio de punto (`TriggerPointRestart`).
- Evaluar las reglas de abandono de partida (`_handlePlayerLeaving`) basadas en la población restante y el marcador.

---

## 10. CAMBIOS MÍNIMOS PARA ELIMINAR EL LOBBY SPAWN DURANTE MATCH

Para erradicar de raíz la aparición en el Lobby sin crear sistemas paralelos ni alterar la física global, se requiere implementar **dos mecanismos estándar de Roblox**:

### Mecanismo A: Asignación Nativa de `player.RespawnLocation`
Roblox Engine respeta nativamente la propiedad `Player.RespawnLocation` (que acepta un `SpawnLocation`).
- Las arenas de combate deben contener una instancia `SpawnLocation` para cada equipo (`RedSpawn` y `BlueSpawn`), con `Enabled = true` y `Neutral = false` (o `Duration = 0`).
- Al iniciar la partida en `MatchReady`, `SpawnService` asigna:
  ```luau
  player.RespawnLocation = targetArenaSpawnLocation
  ```
- Al finalizar completamente en `ReturningToLobby`, `SpawnService` restaura:
  ```luau
  player.RespawnLocation = workspace.Lobby.SpawnLocation
  ```
*Resultado:* Si el jugador muere o cae a $-500$ en cualquier momento durante la partida, el motor nativo de Roblox **lo genera automáticamente en la arena**, sin pasar jamás por el Lobby.

### Mecanismo B: Ampliar la Ventana de Cobertura de Tracking
En [RoundService.luau](file:///h:/repos-github/SlapDuels-2.0/src/server/Services/RoundService.luau):
- Iniciar `SpawnService:StartMatchRespawnTracking(session)` en **`MatchReady`** (en lugar de esperar a `Playing`).
- Mantener activo el tracking durante `StartCountdown`, `Playing`, `PointRestartCountdown` y **`Ending`**.
- Detener el tracking **únicamente al ingresar a `ReturningToLobby`**.

---

## 11. CÓMO EVITAR MÚLTIPLES LLAMADAS CONCURRENTES A `LoadCharacter()`

1. **Eliminar llamadas recursivas a `LoadCharacter` dentro de `CharacterAdded`:**
   En `SpawnService.luau`, dentro del handler de `CharacterAdded`, está terminantemente prohibido llamar a `player:LoadCharacter()`. Si el personaje ya disparó `CharacterAdded`, el personaje **ya está cargando**.
2. **Debounce / Lock de Recarga por Jugador:**
   Implementar un mapa `_loadingPlayers[player] = true` con un candado de tiempo mínimo (3 segundos). Si un proceso solicita recargar el personaje mientras `_loadingPlayers[player]` está activo, la solicitud se descarta inmediatamente.
3. **Esperar a `HumanoidRootPart` con timeout en lugar de fallar de inmediato:**
   En lugar de comprobar `character:FindFirstChild("HumanoidRootPart")` síncronamente y asumir que el personaje está muerto si no existe en ese frame, esperar asíncronamente:
   ```luau
   local root = character:WaitForChild("HumanoidRootPart", 3)
   ```

---

## 12. CÓMO EVITAR `CharacterAdded` DUPLICADOS

1. **Desconexión Limpia Centralizada:**
   `SpawnService._matchRespawnConnections[matchId]` debe almacenar todas las conexiones de `CharacterAdded`. Antes de enlazar un nuevo listener para un jugador, verificar y desconectar el listener anterior.
2. **Filtro de Estado de Sesión:**
   Al dispararse `CharacterAdded`, lo primero que debe hacer el callback es validar que el match siga activo y que la sesión pertenezca al jugador:
   ```luau
   if session.State == Constants.RoundState.Waiting or session.State == Constants.RoundState.ReturningToLobby then
       return
   end
   ```

---

## 13. CÓMO PRESERVAR EL ACTUAL SISTEMA `PointScoreDeath`

El diseño actual en `ScoreService` y `EliminationService` es correcto conceptualmente y debe preservarse intacto:
1. `ScoreService` marca atómicamente al jugador como `PointScorer` y levanta `PointInProgress = true`.
2. `EliminationService` comprueba `if session.PointInProgress and session.PointScorer == victim` y aborta la atribución de kill.
3. **Mejora requerida para robustez:** Al momento exacto de marcar el gol en `ScoreService:_handleZoneScoring`, invocar inmediatamente `CombatService:ClearCombatTag(player)`. De esta forma, cualquier golpe recibido antes de anotar queda purgado y no se atribuirá erróneamente si el jugador muere tras cruzar la meta.
4. Al activarse `RespawnLocation` en la arena, si el anotador cae y muere tras cruzar la meta, reaparece directamente en su base de la arena mientras transcurre la cuenta de reinicio.

---

## 14. CÓMO PRESERVAR `LastAttacker` / ATRIBUCIÓN DE KILLS

1. `CombatService` sigue gestionando `CombatTag` con su ventana `LastHitLifetime = 10s`.
2. Cuando ocurra una eliminación normal en `Playing` (que no sea `PointScorer`):
   - `EliminationService:OnPlayerEliminated` resuelve el atacante.
   - Otorga la kill y estadísticas.
   - Limpia el `CombatTag` consumido.
3. La víctima respawnea automáticamente en su spawn de la arena gracias a `player.RespawnLocation`.

---

## 15. TESTS AUTOMATIZADOS Y MANUALES REQUERIDOS

1. **Test PointScoreDeath en Caída Profunda:**
   - Red anota cruzando `RedWin`.
   - Red se lanza al vacío superando $-500$.
   - *Criterio de Éxito:* Red reaparece en `RedSpawn` de la arena. Blue no recibe Kill. El score se mantiene 1-0. Se ejecuta `PointRestartCountdown` y la ronda se reanuda en la arena.
2. **Test Combat Elimination por Vacío:**
   - Blue golpea a Red con un Slap.
   - Red cae al vacío sin tocar KillPart y muere a $-500$.
   - *Criterio de Éxito:* Blue recibe +1 Kill. Red reaparece en `RedSpawn` de la arena. El match continúa en `Playing`.
3. **Test Caída durante `StartCountdown`:**
   - Durante la cuenta de 5 segundos previa al inicio, un jugador cae al vacío.
   - *Criterio de Éxito:* El jugador reaparece en su spawn de arena y no en el Lobby.
4. **Test Caída durante `Ending`:**
   - Red alcanza 5 puntos. La partida entra en `Ending` (pantalla de victoria).
   - Blue cae al vacío durante los 4 segundos de `Ending`.
   - *Criterio de Éxito:* Blue no aparece en el Lobby hasta que el estado transiciona formalmente a `ReturningToLobby`.
5. **Test Abandono con Score 0-0:**
   - Inicia partida 1v1. Marcador 0-0.
   - Red se desconecta del servidor.
   - *Criterio de Éxito:* La partida se cancela / invalida (`InvalidMatch`). Blue no recibe victoria ni stats.
6. **Test Abandono con Score Mayor a 0:**
   - Red tiene 2, Blue tiene 1.
   - Blue se desconecta.
   - *Criterio de Éxito:* Red gana por abandono. El score final se preserva (2-1). Se otorgan recompensas legítimas.

---

## CONCLUSIONES Y HOJA DE RUTA

### Root Cause (Causa Raíz Resumida)
1. **Falta de `RespawnLocation`:** Roblox ejecuta el respawn nativo incondicional tras una caída a $-500$ y, al no tener configurado `player.RespawnLocation`, utiliza la única `SpawnLocation` física existente en el juego: `Workspace.Lobby.SpawnLocation`.
2. **Brecha en el ciclo de tracking:** `SpawnService` solo intentaba corregir la posición durante el estado `Playing`, dejando desprotegidos los estados `MatchReady`, `MatchCountdown`, `MapSelection`, `MapLoading`, `StartCountdown` y `Ending`.
3. **Race Condition en `CharacterAdded`:** Al escuchar `CharacterAdded`, `SpawnService` verificaba la existencia inmediata de `HumanoidRootPart`. Al no existir en el primer frame de carga, evaluaba que el personaje no estaba vivo y ejecutaba un segundo `player:LoadCharacter()` concurrente.

---

### Arquitectura Propuesta

```
                        [MatchSession Lifecycle]
               (Gobernado exclusivamente por RoundService)
                                   │
      ┌────────────────────────────┴────────────────────────────┐
      ▼ (MatchReady -> Start -> Playing -> PointRestart -> Ending)▼ (ReturningToLobby / Waiting)
[Arena Authority]                                         [Lobby Authority]
- player.RespawnLocation = ArenaSpawn                     - player.RespawnLocation = LobbySpawn
- Tracking CharacterAdded activo                          - Tracking arena desconectado
- Caída a -500 respawnea en Arena                         - Respawn nativo en Lobby
- PointScoreDeath protegido                               - Arena eliminada
```

---

### Lista Exacta de Archivos a Modificar (Para la futura fase de implementación)

1. **[SpawnService.luau](file:///h:/repos-github/SlapDuels-2.0/src/server/Services/SpawnService.luau)**
   - Asignar `player.RespawnLocation = targetSpawnLocation` al ingresar al match y restaurarlo a `Lobby.SpawnLocation` al volver al lobby.
   - Convertir los spawns de las arenas clonadas en instancias `SpawnLocation` funcionales.
   - Corregir el callback de `CharacterAdded` eliminando la llamada recursiva a `player:LoadCharacter()` y esperando asíncronamente con `WaitForChild("HumanoidRootPart", 3)`.
2. **[RoundService.luau](file:///h:/repos-github/SlapDuels-2.0/src/server/Services/RoundService.luau)**
   - Iniciar el tracking de respawn de la arena en `MatchReady` y mantenerlo hasta `ReturningToLobby`.
   - Modificar `_handlePlayerLeaving` para desacoplarlo de la estructura rígida de 1v1 y aplicar la regla de validación de score (`0-0` invalida, `>0` otorga victoria al equipo restante).
3. **[ScoreService.luau](file:///h:/repos-github/SlapDuels-2.0/src/server/Services/ScoreService.luau)**
   - Invocar explícitamente la limpieza de `CombatTag` en `CombatService` en el instante exacto en que se anota el punto.
4. **[EliminationService.luau](file:///h:/repos-github/SlapDuels-2.0/src/server/Services/EliminationService.luau)**
   - Conectar la resolución de eliminaciones válidas con el respawn de la arena de `SpawnService`.

---

### Riesgos Principales a Controlar
- **Colisión de Spawns si `RespawnLocation` no se limpia al salir:** Si el jugador vuelve al Lobby pero su `RespawnLocation` sigue apuntando a una arena que fue destruida con `Destroy()`, Roblox arrojará error de spawn o lo dejará en el origen $(0,0,0)$. *Mitigación:* Siempre reasignar `player.RespawnLocation = lobbySpawn` en el cleanup de `ReturningToLobby` y en `PlayerRemoving`.
- **Desconexión de jugador durante `LoadCharacter`:** Si el jugador abandona mientras se ejecuta una recarga de personaje, `player.Character` puede ser `nil`. *Mitigación:* Validar siempre `player:IsDescendantOf(Players)` antes de operar sobre su personaje.

---

### Orden Recomendado de Implementación
1. **Paso 1:** Convertir spawns de arena a `SpawnLocation` y gestionar `player.RespawnLocation` en `SpawnService`.
2. **Paso 2:** Corregir race condition de `CharacterAdded` en `SpawnService`.
3. **Paso 3:** Extender la ventana de tracking en `RoundService` (`MatchReady` hasta `ReturningToLobby`).
4. **Paso 4:** Limpiar `CombatTag` al anotar gol en `ScoreService`.
5. **Paso 5:** Desacoplar `PlayerRemoving` en `RoundService` e implementar la regla de score 0-0.
6. **Paso 6:** Ejecución de matriz de pruebas en Roblox Studio.