Viewed RagdollService.luau:1-100
Viewed RagdollService.luau:150-210
Viewed MatchInstanceService.luau:1-120
Viewed MatchInstanceService.luau:120-210
Viewed Types.luau:1-100
Viewed Types.luau:100-190

# AUDITORÍA ARQUITECTÓNICA: REEMPLAZO DE MUERTE/RESPAWN POR REPOSICIONAMIENTO SERVER-AUTHORITATIVE
**Proyecto:** SlapDuels 2.0  
**Fecha:** 2026-10-05  
**Modalidad:** READ-ONLY / AUDITORÍA TÉCNICA PURA (Sin modificaciones a código ni archivos)  
**Fuente de Verdad:** Repositorio en GitHub sincronizado (`master` limpio).

---

## 1. VEREDICTO ARQUITECTÓNICO

### **RECOMENDACIÓN CATEGÓRICA: SÍ, SE RECOMIENDA ADOPTAR EL NUEVO MODELO DE REPOSICIONAMIENTO SERVER-AUTHORITATIVE.**

### Fundamento Técnico basado en el Código Actual:
El modelo tradicional de Roblox (`Humanoid.Health = 0` $\rightarrow$ `Died` $\rightarrow$ `RespawnTime = 3s` $\rightarrow$ `CharacterAutoLoads` $\rightarrow$ `LoadCharacter` $\rightarrow$ `CharacterAdded`) es la **fuente directa de todas las carreras e inconsistencias** del juego:

1. **Elimina de raíz la carrera del Lobby Spawn:** Si el `Character` nunca es destruido ni entra en el pipeline nativo de respawn de Roblox, el motor **jamás** consultará `Workspace.Lobby.SpawnLocation`. La aparición en el Lobby se vuelve matemáticamente imposible durante el match.
2. **Elimina la latencia de 3 segundos (`RespawnTime`):** En un juego de combate dinámico y competitivo con resets tras cada punto, esperar 3 segundos a que Roblox regenere el rig provoca que `PointResetDelay` (1.5s) choque contra un personaje inexistente.
3. **Preserva el estado del personaje:** No se pierden accesorios, animaciones locales cargadas, referencias de cámara ni scripts del cliente (`StarterCharacterScripts`).
4. **Resuelve `PointScoreDeath` con elegancia sin parches:** El jugador que marca un punto y cae al vacío simplemente es detectado por debajo del límite, se congela su física y se reposiciona en su base sin morir, sin disparar `Humanoid.Died`, sin registrar Kill accidental y sin trucos de invulnerabilidad.
5. **Aislamiento Multi-Match garantizado:** Al reposicionar directamente dentro de la `MatchInstance` vía `MatchInstanceInfo.RedSpawn` o `BlueSpawn`, no hay búsqueda global ambigua de spawns.

---

## 2. FLUJO PROPUESTO (Pipeline Server-Authoritative)

```
                       [Jugador en Match Activo]
                                   │
              ┌────────────────────┴────────────────────┐
              ▼                                         ▼
   [Toca KillPart de Arena]                  [Cae fuera de Arena]
              │                              (Y < BoundaryThreshold)
              │                                         │
              └────────────────────┬────────────────────┘
                                   │
                                   ▼
                 [EliminationService / FallDetector]
                                   │
                     ¿PlayerFallDebounce[player]?
                     ├── SÍ ──> (Descartar evento duplicado)
                     └── NO ──> Activar Debounce
                                   │
                                   ▼
                    ¿session.PointInProgress == true?
                     ├── SÍ ──> [CASO D: POINT SCORE]
                     │          - NO es Kill
                     │          - Congelar física temporalmente
                     │          - Esperar PointRestartCountdown
                     │          - Reposicionar ambos en TeamSpawns
                     │
                     └── NO ──> [EVALUACIÓN DE COMBATE]
                                   │
                         ¿Existe LastAttacker válido?
                         (Mismo MatchId, attacker ~= victim, < 10s)
                                   │
                    ┌──────────────┴──────────────┐
                    ▼ (SÍ)                        ▼ (NO)
           [CASO B: COMBAT ELIM]           [CASO A: NORMAL FALL]
           - +1 Kill a Atacante            - NO Kill
           - Consumir CombatTag            - Conservar Score
           - Emitir KillFeed               - Conservar Match
                    │                             │
                    └──────────────┬──────────────┘
                                   │
                                   ▼
                       [SpawnService:ResetCharacterInArena]
                       - NO matar Humanoid (Health intacto)
                       - RagdollService:RemoveRagdoll(character)
                       - AssemblyLinearVelocity = Vector3.zero
                       - AssemblyAngularVelocity = Vector3.zero
                       - character:PivotTo(TeamSpawn.CFrame + Offset)
                       - Reactivar locomoción
                       - Liberar Debounce
```

---

## 3. RESPONSABILIDADES (Tabla Actual $\rightarrow$ Propuesta)

| Servicio | Responsabilidad Actual | Responsabilidad Propuesta en el Nuevo Modelo | Justificación del Cambio |
| :--- | :--- | :--- | :--- |
| **`RoundService`** | Ciclo de estados y temporizadores. Trataba de parchar respawns llamando a `SpawnService`. | **Autoridad Suprema de Estados:** Gobierna `MatchReady` $\rightarrow$ `Playing` $\rightarrow$ `PointRestartCountdown` $\rightarrow$ `Ending` $\rightarrow$ `ReturningToLobby`. Decide **cuándo** se autoriza el retorno al Lobby. | Mantiene separación limpia: lógica de match vs física. |
| **`SpawnService`** | Teletransporte inicial y corrección reactiva mediante `CharacterAdded`. Llamaba a `LoadCharacter()`. | **Manipulador Físico Exclusivo:** <br>1) `ResetCharacterInArena(player, matchId)`: Reposiciona el mismo rig, anula inercia, quita ragdoll.<br>2) `ReturnPlayersToLobby(matchId)`: Reposiciona el mismo rig en `Lobby.SpawnLocation`. | **Se elimina toda llamada a `LoadCharacter()` y listeners de `CharacterAdded`.** |
| **`EliminationService`** | Escuchaba `KillPart.Touched` y `Humanoid.Died`. Forzaba `Health = 0`. | **Detector y Evaluador de Salida:** <br>1) Detecta salida por `KillPart` o `Boundary`.<br>2) **NO toca la vida del Humanoid**.<br>3) Resuelve si es Normal Fall o Combat Elimination.<br>4) Otorga Kill y solicita reposicionamiento a `SpawnService`. | La "eliminación" pasa a ser una regla lógica de combate, no una muerte física del motor. |
| **`ScoreService`** | Registra goles, marca `PointScorer` y levanta `PointInProgress`. | **Mantiene exactamente su función:** Detecta gol en `WinZone`, activa `PointInProgress`, otorga monedas y notifica a `RoundService` para el momento cinematográfico. | Su diseño actual ya es atómico y compatible con el nuevo modelo. |
| **`CombatService`** | Registra `CombatTag` (slaps) y resuelve `LastAttacker`. | **Mantiene su función:** Registra y consulta atacantes con TTL de 10s. Agrega método explícito de consumo/purga atómica de tag. | No requiere cambios conceptuales. |
| **`MatchInstanceService`** | Clona mapas y expone spawns/partes. | **Proveedor Geométrico de Arena:** Provee `RedSpawn`, `BlueSpawn`, `Origin` y define el **`FallThresholdY`** (límite inferior de caída) de la arena activa. | Garantiza límites geométricos aislados por slot. |
| **`RagdollService`** | Aplica y remueve ragdoll físico (R15 constraints / R6 welds). | **Exposición de API de Restauración Inmediata:** Expone `ResetRagdollImmediate(character)` para cancelar timers de ragdoll y forzar retorno a locomoción al reposicionar. | Evita que el jugador aparezca en su spawn tirado en el suelo o con constraints rotos. |

---

## 4. ARCHIVOS AFECTADOS

### 1. [EliminationService.luau](file:///h:/repos-github/SlapDuels-2.0/src/server/Services/EliminationService.luau)
- **Función:** `BindMatch`, `OnPlayerEliminated`, `_bindKillParts` y nueva `_bindArenaFallBoundary`.
- **Cambio Propuesto:** 
  - **Eliminar:** `humanoid.Health = 0`, `humanoid:TakeDamage()`, listeners de `humanoid.Died`.
  - **Modificar:** Convertir el contacto con `KillPart` o el cruce del boundary en una llamada a `ResolveFall(player, reason)`.
  - **Agregar:** Comprobación de `session.PointInProgress`: si es true, no procesar eliminación. Si es false, resolver `LastAttacker`, registrar Kill, limpiar tag y ordenar reposicionamiento a `SpawnService`.
- **Motivo:** El Humanoid ya no debe morir.

### 2. [SpawnService.luau](file:///h:/repos-github/SlapDuels-2.0/src/server/Services/SpawnService.luau)
- **Función:** `TeleportCharacterToSpawn`, `StartMatchRespawnTracking`, `StopMatchRespawnTracking`, nueva función `ResetCharacterInArena`.
- **Cambio Propuesto:** 
  - **Eliminar:** Toda llamada a `player:LoadCharacter()`.
  - **Eliminar:** La escucha reactiva de `player.CharacterAdded` para matches en curso.
  - **Modificar:** En `ResetCharacterInArena`, tomar el `player.Character` existente, asegurar que `Humanoid.Health > 0`, llamar a `RagdollService:ResetRagdollImmediate`, anular `AssemblyLinearVelocity` y `AssemblyAngularVelocity`, y posicionar con `PivotTo`.
- **Motivo:** Responsable directo del reposicionamiento server-authoritative del mismo rig.

### 3. [MatchInstanceService.luau](file:///h:/repos-github/SlapDuels-2.0/src/server/Services/MatchInstanceService.luau)
- **Función:** `CreateInstance`, `Types.MatchInstanceInfo`.
- **Cambio Propuesto:** 
  - Calcular y guardar en `MatchInstanceInfo` el plano de caída:
    ```luau
    FallThresholdY = origin.Y - 50 -- o 40 studs debajo del spawn más bajo
    ```
  - Exponer `GetFallThresholdY(matchId)` o crear un volumen físico detector transparente `VoidBoundaryPart` dentro del modelo clonado de la arena.
- **Motivo:** Evitar que dependa de `KillParts` puntuales o del global `-500`.

### 4. [RoundService.luau](file:///h:/repos-github/SlapDuels-2.0/src/server/Services/RoundService.luau)
- **Función:** `_runSession`, `TriggerPointRestart`, `_handlePlayerLeaving`.
- **Cambio Propuesto:** 
  - No llamar a `StartMatchRespawnTracking`.
  - En `TriggerPointRestart`, al expirar el delay cinematográfico (1.5s), ordenar a `SpawnService:ResetCharacterInArena` para ambos jugadores y correr el countdown (3, 2, 1, GO).
  - En `ReturningToLobby`, ordenar a `SpawnService:ReturnPlayersToLobby` (reposicionando los mismos personajes en `Lobby.SpawnLocation`).
- **Motivo:** Orquesta los momentos exactos de reposicionamiento sin involucrar recreación de rigs.

### 5. [RagdollService.luau](file:///h:/repos-github/SlapDuels-2.0/src/server/Services/RagdollService.luau)
- **Función:** `RemoveRagdoll`, nueva `ResetRagdollImmediate`.
- **Cambio Propuesto:** 
  - Crear un método síncrono que cancele el timer del ragdoll, restaure los `AnimationConstraints` / `Motor6D`, limpie colliders R6, ponga `humanoid.PlatformStand = false` y cambie el estado a `GettingUp` / `Running`.
- **Motivo:** Garantizar que al llegar al spawn el jugador pueda moverse inmediatamente sin inercia ni deformaciones.

### 6. [Shared/Types.luau](file:///h:/repos-github/SlapDuels-2.0/src/shared/Types.luau)
- **Cambio Propuesto:**
  - Agregar tipos:
    ```luau
    export type FallReason = "NormalFall" | "CombatElimination" | "PointScoreFall"
    ```
  - Agregar `FallThresholdY: number` a `MatchInstanceInfo`.

---

## 5. ARCHIVOS QUE NO DEBEN TOCARSE

- **[CombatService.luau](file:///h:/repos-github/SlapDuels-2.0/src/server/Services/CombatService.luau):** Su lógica de `CombatTag`, `RegisterHit`, `GetLastAttacker` y expiración por `LastHitLifetime` es 100% limpia y adecuada. Solo será consumido por `EliminationService`.
- **[ScoreService.luau](file:///h:/repos-github/SlapDuels-2.0/src/server/Services/ScoreService.luau):** La detección de cruce de `WinZone` y el marcado de `PointInProgress` y `PointScorer` funcionan a la perfección.
- **[PlayerDataService.luau](file:///h:/repos-github/SlapDuels-2.0/src/server/Services/PlayerDataService.luau) / [PlayerService.luau](file:///h:/repos-github/SlapDuels-2.0/src/server/Services/PlayerService.luau):** Los métodos `AddKills`, `AddCoins`, `AddWins` no cambian.
- **[KnockbackService.luau](file:///h:/repos-github/SlapDuels-2.0/src/server/Services/KnockbackService.luau):** La física del slap se mantiene idéntica.
- **Controllers de Cliente (`MatchController.luau`, `MusicController.luau`, UI):** No necesitan cambios ya que los Remotes de estado (`StateChanged`, `Countdown`, `ScoreUpdated`) siguen emitiéndose en los mismos momentos.

---

## 6. SISTEMA DE DETECCIÓN DE CAÍDA (Recomendación Concreta)

### Evaluación de Alternativas:

1. **Solo KillParts físicas:** *Frágil.* Si un jugador es golpeado con un slap potente con trayectoria parabólica hacia afuera, puede sobrevolar las KillParts y caer al infinito sin tocarlas.
2. **Heartbeat / Polling de Posición $Y$ de todos los jugadores:** *Seguro pero innecesariamente costoso si se hace con bucles globales.*
3. **Volumen Físico Detector de Fondo (`VoidBoundaryPart`) en cada Arena:** *Altamente eficiente y nativo de Roblox.*

### Estrategia Recomendada: HÍBRIDA (Doble Capa de Detección)

```
                       ARENA DE JUEGO (Y = 500)
             ══════════════════════════════════════════
                                │ (Caída)
                                ▼
         [CAPA 1: KillParts existentes en el mapa (Touched)]
                                │
                                ▼
         [CAPA 2: VoidBoundaryPart (BasePart gigante e invisible)]
                  (Size = Vector3.new(500, 10, 500))
                  (Position = Origin - Vector3.new(0, 40, 0))
                  (CanCollide = false, Transparency = 1)
```

1. **Capa 1 (Inmediata):** Los `KillParts` existentes en el modelo del mapa disparan `Touched` al instante.
2. **Capa 2 (Malla de Seguridad Absoluta):** Al clonar el mapa en `MatchInstanceService`, se genera automáticamente una parte plana horizontal invisible (`VoidBoundaryPart`) a $Y = \text{Origin.Y} - 40$ que cubre un radio de $500 \times 500$ studs con `Touched` conectado.
3. **Garantía:** Es físicamente imposible que un personaje caiga a $Y = -500$ (`FallenPartsDestroyHeight`). El servidor siempre lo intercepta $460$ studs antes de que el motor de Roblox intente destruirlo.

---

## 7. SISTEMA DE ELIMINACIÓN (Normal Fall vs Combat Elimination)

Cuando la detección de caída se activa para un jugador $V$ en el match $M$:

```luau
function EliminationService:ProcessArenaFall(victim: Player, reason: string)
    -- 1. Anti-Duplicate Lock
    if self._fallDebounce[victim] then return end
    self._fallDebounce[victim] = true

    local session = RoundService:GetSessionForPlayer(victim)
    if not session or session.State ~= "Playing" then
        self:ClearDebounce(victim)
        return
    end

    -- 2. CASO D: Si hay gol en progreso, es PointScoreFall -> NO procesar eliminación
    if session.PointInProgress then
        self:ClearDebounce(victim)
        return
    end

    -- 3. Consultar atacante en CombatService
    local attacker, attackerMatchId = CombatService:GetLastAttacker(victim, Config.Combat.LastHitLifetime)
    
    if attacker and attacker ~= victim and attackerMatchId == session.Id then
        -- CASO B: COMBAT ELIMINATION
        PlayerService:AddKills(attacker, 1, "CombatSlap")
        CombatService:ClearCombatTag(victim) -- Consumir tag
        self:_broadcastElimination(session.Id, victim, attacker, "CombatElimination")
    else
        -- CASO A: NORMAL FALL
        self:_broadcastElimination(session.Id, victim, nil, "NormalFall")
    end

    -- 4. Reposicionamiento Server-Authoritative inmediato
    SpawnService:ResetCharacterInArena(victim, session.Id)
    
    task.delay(0.5, function()
        self._fallDebounce[victim] = nil
    end)
end
```

---

## 8. SISTEMA DE POINT (Preservación Cinematográfica)

Para cumplir el requisito de no reposicionar de inmediato al anotador y preservar el momento cinematográfico:

1. **Gol anotado:** `ScoreService` detecta la entrada en `WinZone`.
2. **Marcado atómico:**
   ```luau
   session.PointInProgress = true
   session.PointScorer = scoringPlayer
   ```
3. **Si el anotador cae al vacío durante el festejo/explosión:**
   - La Capa de Detección de Caída evalúa `session.PointInProgress == true`.
   - **Acción:** No procesa eliminación. En lugar de teletransportarlo inmediatamente a su spawn, lo "congela" en el aire o lo suspende momentáneamente con `HumanoidRootPart.Anchored = true` fuera de la vista de la cámara mientras corre la cinemática de `PointFeedbackService` (1.5 segundos).
4. **Al expirar el delay cinematográfico:**
   - `RoundService:TriggerPointRestart` llama a `SpawnService:ResetCharacterInArena` para **ambos jugadores**.
   - Se desactivan anclajes, se restaura la locomoción y se inicia la cuenta regresiva 3, 2, 1, GO.
5. **Resultado:** Se elimina totalmente la lógica de "ignorar muerte", porque el personaje **nunca muere ni respawnea**.

---

## 9. TEAM IDENTIFICATION (Resolución sin Ambigüedad Multi-Match)

Para garantizar que `SpawnService` y `EliminationService` resuelvan con precisión absoluta a qué equipo y a qué arena física pertenece cada jugador:

### Propuesta: Atributos en el `Player` + `MatchInstanceInfo` Cacheados

Al iniciar la partida en `MatchReady` ([RoundService.luau:450](file:///h:/repos-github/SlapDuels-2.0/src/server/Services/RoundService.luau#L450)):
```luau
player:SetAttribute("MatchId", session.Id)
player:SetAttribute("MatchTeam", teamName) -- "Red" | "Blue"
```

Al concluir definitivamente en `ReturningToLobby`:
```luau
player:SetAttribute("MatchId", nil)
player:SetAttribute("MatchTeam", nil)
```

### Resolución en `SpawnService`:
```luau
function SpawnService:GetArenaSpawnForPlayer(player: Player): BasePart?
    local matchId = player:GetAttribute("MatchId") :: string?
    local team = player:GetAttribute("MatchTeam") :: string?
    if not matchId or not team then return nil end

    local instanceInfo = MatchInstanceService:GetInstance(matchId)
    if not instanceInfo then return nil end

    return if team == "Red" then instanceInfo.RedSpawn else instanceInfo.BlueSpawn
end
```
*Ventaja:* Cero colisiones entre partidas concurrentes (Match A y Match B). Cada jugador va estrictamente a la parte clonada de su slot de arena.

---

## 10. RAGDOLL INTEGRATION

Actualmente [RagdollService.luau:167](file:///h:/repos-github/SlapDuels-2.0/src/server/Services/RagdollService.luau#L167) programa la recuperación del ragdoll mediante `task.delay(ragDuration)`.

### Problema Potencial:
Si el jugador es golpeado, entra en ragdoll (duración 2s), cae de la arena en 0.4s y es reposicionado en 0.5s:
- Si no se limpia el ragdoll, el jugador reaparecerá en su spawn **desparramado en el suelo durante 1.5 segundos más**, con la cámara desalineada y sin poder moverse.

### Solución Arquitectónica:
Agregar a `RagdollService` el método:
```luau
function RagdollService:ResetRagdollImmediate(character: Model)
    -- 1. Cancelar el timer activo en _activeTimers
    -- 2. Reactivar AnimationConstraints (R15) o Motor6D (R6)
    -- 3. Destruir colliders temporales de R6
    -- 4. humanoid.PlatformStand = false
    -- 5. Disparar StateEvent al cliente para apagar RagdollStatesHandler
    -- 6. humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
end
```
`SpawnService:ResetCharacterInArena` llamará siempre a `ResetRagdollImmediate(character)` antes de hacer `character:PivotTo(spawnCFrame)`. El jugador reaparecerá de pie y con control total.

---

## 11. ANTI-DUPLICATE & CONCURRENCY

Para evitar que múltiples eventos simultáneos (ejemplo: tocar un `KillPart` y cruzar el `VoidBoundaryPart` en el mismo tick de física) provoquen dobles Kills o dobles reposicionamientos:

### Candado por Jugador en `EliminationService`:
```luau
EliminationService._fallDebounce = {} :: { [Player]: boolean }
```
1. Al dispararse cualquier trigger de caída, se comprueba:
   `if self._fallDebounce[player] then return end`
2. Se activa `self._fallDebounce[player] = true`.
3. Se realiza la resolución atómica (Kill + Reposicionamiento).
4. El debounce se libera con un margen de seguridad de `task.delay(0.5, ...)`.

---

## 12. ESTADOS DEL MATCH AFECTADOS

| Estado | ¿Debe actuar el Reposicionamiento de Arena? | Comportamiento del Personaje |
| :--- | :---: | :--- |
| `Waiting` | **NO** | En Lobby. Si cae en Lobby, Roblox respawnea en Lobby. |
| `MatchReady` | **SÍ** | Teletransportado a la arena. Atributos asignados. Inmune a caída (congelado o reposicionado). |
| `MatchCountdown` / `MapSelection` | **SÍ** | En arena. |
| `StartCountdown` | **SÍ (CASO E)** | Si salta al vacío durante los 5s del countdown, es reposicionado inmediatamente a su TeamSpawn sin matar ni cancelar el countdown. |
| `Playing` | **SÍ (CASOS A y B)** | Reposicionamiento inmediato (Normal Fall o Combat Elimination). |
| `PointRestartCountdown` | **SÍ (CASO D)** | Reposicionamiento coordinado de ambos equipos al terminar el delay cinematográfico. |
| `Ending` | **SÍ (CASO F)** | Durante los 4 segundos de pantalla de victoria, si un jugador cae, es reposicionado a su spawn de arena. **JAMÁS va al Lobby.** |
| `ReturningToLobby` | **TRANSICIÓN** | Se remueven atributos. `SpawnService` reposiciona los mismos personajes en `Lobby.SpawnLocation`. |

---

## 13. QUÉ PARTE DEL SISTEMA ACTUAL QUEDA OBSOLETA

| Componente / Código Actual | Clasificación | Justificación |
| :--- | :---: | :--- |
| `Humanoid.Died` en `EliminationService` | **DEPRECATE** | Ya no se utiliza para resolver eliminaciones dentro de la arena. |
| `player:LoadCharacter()` en `SpawnService` | **REMOVE LATER** | Era la fuente de regeneraciones duplicadas y reseteos lentos. |
| `StartMatchRespawnTracking` / `CharacterAdded` | **DEPRECATE** | Ya no es necesario escuchar `CharacterAdded` en partidas activas porque los personajes no se recargan. |
| `Players.RespawnTime` (3s) | **NO IMPACTA** | Deja de tener efecto en matches porque el Humanoid nunca muere. |
| `FallenPartsDestroyHeight` ($-500$) | **KEEP GLOBAL** | Se deja intacto en $-500$ como fail-safe del engine; la arena lo intercepta a $Y \approx 450$ antes de llegar allí. |
| `KillPart` con daño letal / `BreakJoints` | **MODIFY** | El `KillPart` ya no debe matar al Humanoid; solo actúa como detector `Touched`. |

---

## 14. RIESGOS Y MEDIDAS DE CONTROL

| Riesgo Técnico | Severidad | Mitigación Arquitectónica |
| :--- | :---: | :--- |
| **Inercia residual tras reposicionamiento:** El personaje reaparece en el spawn pero sale disparado por la velocidad que traía de la caída. | Alta | Forzar estrictamente `rootPart.AssemblyLinearVelocity = Vector3.zero` y `AssemblyAngularVelocity = Vector3.zero` justo después de `character:PivotTo()`. |
| **Pérdida de la herramienta (Slap Tool):** Al reposicionar o resetear ragdoll, el Tool equipado podría desequiparse o caerse. | Media | Los Slap Tools residen en `Backpack` o `Character`. Al no llamar a `LoadCharacter()`, los Tools nunca se eliminan. Se fuerza `humanoid:EquipTool()` si quedó desequipado. |
| **Desconexión (`PlayerRemoving`) en pleno reposicionamiento:** El jugador sale del server justo cuando cruza el boundary. | Baja | Comprobar `if not player:IsDescendantOf(Players) or not character.Parent then return end` al inicio de cada función. |
| **Player retenido en `Anchored` tras PointScore:** Si falla un script durante la cinemática, el jugador queda congelado para siempre. | Media | Usar un bloque `task.delay(3, ...)` de seguridad para forzar `Anchored = false`. |

---

## 15. MATRIZ DE TESTS (Para Validación Post-Implementación)

1. **Test Caída Propia (Normal Fall):**
   - Red camina hacia el vacío y cae.
   - *Resultado esperado:* Red reaparece en `RedSpawn` de pie y sin inercia en < 0.1s. Blue no recibe Kill. Score intacto.
2. **Test Slap + Caída (Combat Elimination):**
   - Blue golpea a Red con Slap. Red vuela y cruza el boundary de caída.
   - *Resultado esperado:* Blue recibe +1 Kill. Red reaparece en `RedSpawn`. Red no tiene ragdoll residual.
3. **Test Salto Alto sobre KillParts (Boundary Check):**
   - Red es lanzado muy lejos evitando las KillParts del mapa.
   - *Resultado esperado:* `VoidBoundaryPart` lo intercepta en $Y = \text{Origin.Y} - 40$. Se procesa la eliminación normalmente.
4. **Test Gol y Festejo en Caída (PointScore):**
   - Red marca en `BlueWin` y cae al vacío durante el festejo.
   - *Resultado esperado:* No se le da Kill a Blue. Red no va al Lobby. Red y Blue son reposicionados juntos al terminar la cinemática e inicia el countdown 3, 2, 1.
5. **Test Caída en `StartCountdown`:**
   - Durante la cuenta inicial de 5s, Red salta al vacío.
   - *Resultado esperado:* Red reaparece en `RedSpawn`. La cuenta regresiva no se interrumpe ni se envía al Lobby.
6. **Test Caída en `Ending`:**
   - Termina la partida (Red 5 - Blue 3). Durante los 4s de Ending, Blue cae al vacío.
   - *Resultado esperado:* Blue reaparece en `BlueSpawn`. No aparece en el Lobby hasta la transición formal `ReturningToLobby`.

---

## 16. ORDEN RECOMENDADO DE IMPLEMENTACIÓN (Fases Posteriores)

Una vez que des tu aprobación para comenzar, el orden de implementación sin riesgo de regresión será:

1. **Fase 1 (Infraestructura de Arena y Spawns):**
   - Agregar el boundary detector (`VoidBoundaryPart`) en `MatchInstanceService`.
   - Implementar `player:SetAttribute("MatchId")` y `"MatchTeam"` en `RoundService`.
2. **Fase 2 (Física y Reposicionamiento Seguro):**
   - Implementar `RagdollService:ResetRagdollImmediate`.
   - Implementar `SpawnService:ResetCharacterInArena` (PivotTo + reseteo de velocidades + limpieza de ragdoll, sin `LoadCharacter`).
3. **Fase 3 (Eliminación no Letal):**
   - Modificar `EliminationService` para convertir `KillParts` y `VoidBoundary` en llamadas a reposicionamiento en lugar de matar al Humanoid.
4. **Fase 4 (Coordinación de Punto y Cuenta Regresiva):**
   - Conectar el flujo no letal de gol en `ScoreService` y `RoundService:TriggerPointRestart`.
5. **Fase 5 (Deprecación de Código Viejo y Pruebas Reales):**
   - Desconectar listeners obsoletos de `CharacterAdded` y `Humanoid.Died`.
   - Ejecutar la batería de pruebas en Roblox Studio.

---

*Fin del informe de auditoría arquitectónica. El repositorio permanece 100% intacto, sin archivos modificados ni código alterado.*