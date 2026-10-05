# Slap Duels 2.0 — POINT_EFFECTS

> Este documento conserva contenido del `GAME_SDD.md` original suministrado, redistribuido por dominio para reducir el contexto necesario para agentes de IA.

## 14. Arquitectura de Feedback Cinematográfico y Cosméticos de Punto (`PointFeedbackService` y `PointEffect`)

Para elevar el impacto visual y auditivo de cada anotación sin comprometer la estabilidad ni el equilibrio del juego, se introduce el sistema de **Point Effects** operado por `PointFeedbackService`.

> [!IMPORTANT]
> **Point Effects are cosmetic-only:**
> Un `PointEffect` es estrictamente estético. **PROHIBIDO** alterar daño, knockback base, velocidad, score, recompensas, duración de la partida o cualquier ventaja competitiva mediante efectos de punto.

### 1. Separación Conceptual: Jugador (Efecto) vs Zona (Origen Físico)
- **El jugador anotador (`ScoringPlayer`) determina el efecto:** Cada jugador posee su propio `EquippedPointEffect` (ej. "Inferno", "Frost", "Basic").
- **La zona donde anota (`ScoringZone`) determina el origen físico:** El efecto se manifiesta física y espacialmente en el `BasePart` de gol:
  - Anotación de **Red** $\rightarrow$ el efecto del jugador aparece en `session.InstanceInfo.RedWin`.
  - Anotación de **Blue** $\rightarrow$ el efecto del jugador aparece en `session.InstanceInfo.BlueWin`.
- **Prohibido:** Ubicar el efecto sobre el personaje del jugador, en el spawn o en el centro de la arena. El origen es siempre el `ScoringZone` físico.

### 2. Separación Estricta de Responsabilidades
- **`ScoreService` (Autoridad de Dominio y Gameplay):**
  - Detección espacial y física de contacto en zonas de gol.
  - Validación de elegibilidad del jugador y estado de la partida (`Playing`).
  - Determinación del equipo anotador (`Red` / `Blue`) y del jugador anotador (`ScoringPlayer`).
  - Incremento del puntaje autoritativo.
  - Otorgamiento de recompensas de economía (+50 Coins).
  - Emisión de actualización de marcador (`ScoreUpdated`) y aviso de `LastPoint`.
  - Determinación de punto final o programación de reinicio de punto (`PointResetDelay`).
  - Generación de `PointId` único determinista.
  - **No conoce:** Partículas, sonidos, explosiones ni Camera Shake.
- **`PointEffectDefinitions` (Catálogo Compartido de Definiciones):**
  - Define identidad, `DisplayName`, `Rarity` ("Common", "Rare", "Epic", "Legendary"), precio futuro y metadatos.
  - No contiene lógica de gameplay ni física.
- **`PlayerService` (Propiedad y Equipamiento - Player Ownership):**
  - Mantiene `OwnedPointEffects` (colección de efectos desbloqueados) y `EquippedPointEffect`.
  - **Fallback universal:** Todo jugador posee `"Basic"` por defecto.
  - **Autoridad del servidor:** El servidor valida existencia y propiedad antes de permitir equipar cualquier cosmético.
- **`PointFeedbackService` (Lifecycle, Origen Físico y Despacho):**
  - **Exclusivamente responsable** de orquestar el ciclo de vida del punto anotado.
  - Resuelve `ScoringPlayer` $\rightarrow$ `EquippedPointEffect` $\rightarrow$ `PointEffectDefinitions`. Si es nulo o inválido, aplica fallback seguro a `"Basic"`.
  - Valida defensivamente que `ScoringZone` pertenezca a la instancia activa y al equipo anotador.
  - Localiza el template en `ServerStorage.PointEffects[EffectId]` (editable desde Studio) y lo clona en `ScoringZone`.
  - Despacha la ejecución al `EffectController` registrado (`PointEffectRegistry.GetController(effectId)`).
  - Gestiona los handles activos y el cleanup por `Duration` o cancelación de partida (`CleanupMatch`).
  - Notifica a clientes vía RemoteEvent `Remotes.Match.PointFeedback`.
- **`PointEffectRegistry` & `EffectController` (Coreografía Visual y Sonora Específica):**
  - Cada efecto cuenta con su propio controller (ej. `BasicController`).
  - El controller gobierna la secuencia temporal de flashes, dispersión de partículas, expansión con `TweenService` y capas de SFX.
  - Retorna un `EffectHandle` con métodos `:Stop()` y `:Destroy()` para cancelación segura en cualquier momento.
  - **PROHIBIDO** modificar gameplay, daño, velocidad, scores o economía dentro de los controllers.
  - Permite añadir nuevos efectos (`InfernoController`, `FrostController`, `ThunderController`, `VoidController`) sin alterar una sola línea de `PointFeedbackService`.

### 3. Flujo Futuro de Tienda (Point Effect Shop)
La arquitectura queda desacoplada y lista para la integración posterior de la tienda:
```
PointEffectShop
  ↓ (Gasto de Coins autoritativo en Servidor)
Comprar PointEffect
  ↓
PlayerService:AddOwnedPointEffect(player, effectId)
  ↓
PlayerService:SetEquippedPointEffect(player, effectId)
  ↓
EquippedPointEffect = effectId
```
Precios proyectados en definiciones: `Basic` (0 / Gratuito), `Inferno` (500 Coins), `Frost` (750 Coins), `Thunder` (1500 Coins), `Void` (3000 Coins).

### 4. Soporte Multijugador (1v1, 2v2, 3v3)
- En partidas de múltiples jugadores por equipo, cada jugador conserva su propio cosmético equipado de forma independiente.
- Si el Jugador A (equipado con "Basic") anota para Red, se reproduce "Basic" en `RedWin`.
- Si el Jugador B (equipado con "Inferno") anota para Red, se reproduce "Inferno" en `RedWin`.
- Todos los clientes reciben el evento de feedback para sincronización global.

### 5. Prevención de Duplicación, Camera Shake y Limpieza (Cleanup)
- **De-duplicación:** Se genera un identificador único por punto (`PointId`). `PointFeedbackService` mantiene el registro `_processedPoints` y descarta invocaciones repetidas de forma atómica.
- **Camera Shake:** El cliente recibe `PointFeedback` (`MatchId`, `ScoringTeam`, `ScoringPlayerName`, `ScoringZonePosition`, `EffectId`, `IsFinalPoint`) y ejecuta la reacción local de cámara de manera puramente pasiva.
- **Cleanup:** Al finalizar la partida o reiniciarse la sesión (`ScoreService:CleanupSession`), se invoca `PointFeedbackService:CleanupMatch(matchId)`, invocando `:Destroy()` en todos los handles de controllers activos y destruyendo cualquier clon residual con garantía de residuo cero.

### 6. Herramienta de Testing y Desarrollo (`PointEffectTestService`)
Para permitir pruebas rápidas de cosméticos en Roblox Studio sin necesidad de iniciar una partida real, se incorpora `PointEffectTestService`:
- **Ubicación Física:** `Workspace.PointEffectTest.TestPart` (BasePart editable directamente desde Studio, con material Neon llamativo y ubicado en el Lobby).
- **Attributes Editables en Studio:**
  - `EffectId` (string, default `"Basic"`): Determina qué cosmético probar. Puede cambiarse en vivo desde Properties para probar cualquier efecto registrado.
  - `Cooldown` (number, default `1`): Intervalo mínimo en segundos entre activaciones consecutivas para prevenir spam.
  - `IsFinalPoint` (boolean, default `false`): Permite simular un punto definitivo de victoria para probar el multiplicador de partículas/volumen y la sacudida de cámara intensificada.
- **Métodos de Activación:**
  - `Touched`: Contacto directo de cualquier personaje o part.
  - `ProximityPrompt`: Activación manual interactiva ("Probar efecto" / "Point Effect Test").
- **Integración con Feedback de Pantalla (`PointCameraFX`):**
  - Al activarse, emite el `RemoteEvent` `PointFeedback` con `ScoringZonePosition = TestPart.Position`, permitiendo validar el camera shake, bloom, flash y FOV kick del cliente según la distancia del jugador.
- **Aislamiento Total del Gameplay:**
  - **NO** interactúa con `ScoreService`.
  - **NO** genera puntos reales ni altera `MatchScore`.
  - **NO** otorga Coins ni afecta la economía.
  - **NO** inicia `RoundService` ni afecta el matchmaking o respawn.
  - Reutiliza directamente `PointEffectRegistry` y los controllers correspondientes (`BasicController`), proveyendo un contexto mínimo de prueba (`MatchId = "TEST"` y `OriginPart = TestPart`).

### 7. Sistema de Ragdoll y Física de Onda Expansiva (`RagdollService`)
Para brindar máximo impacto visual y cómico al anotar un punto y al probar cosméticos en el `TestPart`, se implementa `RagdollService`:
- **Arquitectura Universal (R15 y R6):**
  - Deshabilita temporalmente los `Motor6D` de las extremidades preservando el `RootJoint` (evitando desincronización de cámara).
  - Genera automáticamente articulaciones `BallSocketConstraint` con límites angulares realistas a partir de los offsets `C0` y `C1` exactos de cada motor.
  - Pasa el `Humanoid` a estado `Ragdoll` con `PlatformStand = true` y colisiones activas en extremidades.
- **Física de Lanzamiento:**
  - `LaunchCharacter(character, originPos, force, upwardRatio)` aplica un impulso vectorial de despegue con elevación vertical (65% por defecto) y dispersión radial away from the blast center, agregando torque rotacional aleatorio para giros en el aire.
- **Integración con Point Effects:**
  - **Partida Real (`PointFeedbackService`):** Al detonar un punto en `ScoringZone`, `BlastZone` arroja por los aires en ragdoll a todos los jugadores dentro del radio de explosión (25 studs por defecto).
  - **Herramienta de Testing (`PointEffectTestService`):** Al pisar o activar `TestPart`, el personaje sale eyectado por los aires con ragdoll inmediato. Los atributos `RagdollForce`, `RagdollRadius` y `RagdollDuration` son editables desde Studio.
- **Auto-Recuperación y Reseteo Seguro:**
  - Tras expirar la duración configurable (`DefaultDuration = 2.0s`), el servicio restaura automáticamente las colisiones, destruye los constraints y reincorpora el personaje de pie (`GettingUp`).
  - Al resetearse una ronda en partida (`SpawnService:TeleportCharacterToSpawn`), se invoca `RemoveRagdoll` de forma preventiva para asegurar que los jugadores siempre comiencen la siguiente ronda de pie en sus spawns.

### 8. Arquitectura de Matchmaking y Múltiples Zonas Físicas (`MatchmakingService` & `MatchmakingFeedbackService`)

> [!IMPORTANT]
> **Regla de Identidad de Zona vs Modalidad:**
> Multiple physical matchmaking zones may share the same Mode. Mode defines matchmaking rules; Zone Instance defines queue identity.

- **Definición de Términos:**
  - **`Mode`:** Define exclusivamente las reglas y configuración de la modalidad (ej. `"1v1"`, `"2v2"`, `"3v3"`, `TeamSize`, `MaxPlayersPerTeam`, `TotalPlayers`).
  - **`Instance` (`zoneFolder`):** La carpeta física dentro de `Workspace.ZoneMatchmaking` es la identidad primaria interna para separar colas, estados de ocupación, pads y recursos audiovisuales (`_zones[zoneFolder] = zoneState`).
  - **`ZoneName`:** Nombre de la carpeta física (ej. `"1v1"`, `"1v1_2"`, `"1v1_3"`, `"Ranked1v1"`) para identificación legible y depuración.
  - **`ZoneId`:** Identificador único por instancia (ej. `"Zone_1v1"`, `"Zone_1v1_2"`) transportado en `QueueSnapshot` y hacia `RoundService`.

- **Múltiples Zonas del Mismo Modo:**
  - Es completamente válido clonar `Workspace.ZoneMatchmaking["1v1"]` a `Workspace.ZoneMatchmaking["1v1_2"]` y `Workspace.ZoneMatchmaking["1v1_3"]`.
  - Todas comparten `Mode = "1v1"`, pero cada una opera de manera estrictamente independiente:
    - **Pads independientes:** Sus pads `Red` y `Blue` dentro de `joins-parts` detectan únicamente los jugadores parados en esa zona física.
    - **Feedback audiovisual independiente:** Cada zona tiene su propia carpeta `effects`. Los sonidos `SoundJoin`/`SoundLeave`, música espacial y partículas se disparan y limpian exclusivamente en la instancia que los originó (`SetPadOccupied(zoneFolder, teamName, isOccupied, occupant)`).
    - **Snapshots y HUD independientes:** Cada snapshot contiene `ZoneId`, `ZoneName` y `Mode`. El HUD del cliente (`MatchmakingController`) únicamente muestra la cola donde está el jugador y no se oculta ni interfiere por snapshots de otras zonas.
    - **Preparación simultánea y MATCH_READY:** Dos o más zonas pueden estar en `WAITING` o `READY` al mismo tiempo con jugadores distintos.

- **Ciclo de Vida Dinámico (Runtime Discovery & Cleanup):**
  - `MatchmakingService` detecta automáticamente cualquier carpeta nueva añadida a `Workspace.ZoneMatchmaking` en tiempo de ejecución vía `ChildAdded`.
  - Si una zona es eliminada (`ChildRemoved`), se realiza un cleanup exhaustivo: desconexión de eventos, desregistro en `MatchmakingFeedbackService:UnregisterZone(zoneFolder)` (destrucción de partículas, beams, música y restauración de materiales) y vaciado de caché de snapshots sin dejar fugas de memoria.

---

### 9.1 Arquitectura de Tres Capas y Regla Server-Authoritative
El sistema de datos económicos y estadísticas del jugador está desacoplado estrictamente en tres capas con responsabilidades delimitadas:
1. **`PlayerService` (Runtime Authority):** Fuente de la verdad en memoria durante la sesión del servidor (`PlayerService._data[player]`). Gestiona reglas de negocio (`AddCoins`, `AddWin`, `AddLoss`) y cosméticos (`PointEffects`).
2. **`PlayerDataService` (Persistence Layer):** Capa dedicada exclusivamente a la comunicación I/O con `DataStoreService`, validación de schemas, retries controlados, `BindToClose` y políticas de prevención de pérdida de datos.
3. **`PlayerHUD` & `PlayerHUDController` (Presentation Only):** Vista reactiva en el cliente. Únicamente renderiza datos autorizados recibidos mediante `Remotes.Player.DataUpdated`. El cliente **NO** tiene acceso a `DataStoreService` ni canales de escritura de datos.

### 9.2 DataStore Name y Configuración
- Centralizado en `Config.DataStore`:
  ```luau
  Config.DataStore = {
      Name = "SlapDuels_PlayerData_v1", -- Nombre estable y explícito entre sesiones
      CurrentVersion = 1,
      MaxRetries = 3,
      InitialRetryDelay = 1.0,
      RetryBackoffMultiplier = 2.0,
  }
  ```

### 9.3 Schema Persistido (Version 1) y Validación
- **Estructura en DataStore:**
  ```luau
  {
      Version = 1,      -- Identificador de schema numérico
      Coins = number,   -- Entero no negativo (>= 0)
      Wins = number,    -- Entero no negativo (>= 0)
      Losses = number,  -- Entero no negativo (>= 0)
      LastSaved = number, -- Unix timestamp (os.time())
  }
  ```
- **Función Central de Validación (`ValidatePlayerData`):**
  - Garantiza `type(raw) == "table"`.
  - Verifica que cada atributo sea un número finito no-NaN (`typeof(x) == "number"` y `x == x` y `math.abs(x) ~= math.huge`).
  - Aplica fallback seguro si algún valor viniese `nil` o corrupto (`Coins = 0`, `Wins = 0`, `Losses = 0`).
  - **Estrategia ante versiones futuras:** Si `Version` es desconocida o superior a la actual, **NO** se destruyen los datos; se preservan los valores numéricos válidos y se emite un warning para migraciones controladas en fases posteriores.

### 9.4 Ciclo de Vida: Carga (Load) y Prevención de Flicker
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

### 9.5 Política de Seguridad ante Fallos de Carga (Safe Session Policy)
> [!CAUTION]
> **POLÍTICA CRÍTICA CONTRA PÉRDIDA DE DATOS:**
> Si `DataStoreService` falla tras agotar todos los reintentos:
> - `DataLoadState[player]` queda marcado como `"Failed"`.
> - **NUNCA** se sobrescriben los datos del jugador en DataStore con valores predeterminados (ceros).
> - `PlayerDataService:SavePlayer` **RECHAZA EXPRESAMENTE** cualquier intento de guardado para ese jugador durante toda la sesión (`loadState ~= "Loaded"`).
> - Se documenta el incidente en los logs del servidor (`[PlayerData] RECHAZO DE GUARDADO: Protección contra pérdida de datos activada`).

### 9.6 Ciclo de Vida: Guardado (Save) y Concurrencia
- **Estrategia de Escritura Controlada:**
  - **NO** se ejecuta `SetAsync` ni `UpdateAsync` en cada `AddCoins()` (los puntos de partida son frecuentes y agotarían la cuota de DataStore).
  - Los cambios se acumulan de forma autoritativa en memoria (`PlayerService._data[player]`).
  - El guardado se ejecuta de forma controlada en:
    1. `PlayerRemoving` (salida del jugador).
    2. `game:BindToClose` (cierre o migración del servidor).
- **UpdateAsync y Concurrencia:**
  - Se utiliza `UpdateAsync` garantizando lecturas/escrituras atómicas.
  - La función de transformación combina los datos anteriores preservando atributos externos y actualizando `Coins`, `Wins`, `Losses` y `LastSaved`.
  - **Protección contra doble guardado simultáneo:** Se bloquea la concurrencia mediante `_saving[player] = true`. Llamadas concurrentes esperan activamente a que finalice el guardado en curso sin duplicar peticiones I/O.

### 9.7 Cierre del Servidor (`BindToClose`)
- Conectado en `PlayerDataService:Init()`.
- Ejecuta `SaveAllPlayers()`:
  - Filtra a los jugadores con `DataLoadState == "Loaded"`.
  - Dispara el guardado de cada jugador en corutinas paralelas (`task.spawn`).
  - Utiliza un mecanismo de sincronización que cede el hilo principal (`task.wait(0.1)`) hasta que todas las tareas finalizan o hasta alcanzar un límite defensivo de 25 segundos (por debajo del límite de 30s de Roblox).

### 9.8 Session Safety y Limitaciones Actuales
- **Evaluación de Session Locking:** En esta fase no se implementa un sistema complejo de leases o candados distribuidos con heartbeat entre servidores múltiples, dado que los duelos operan con sesiones secuenciales de entrada/salida.
- **Riesgo residual:** Si un jugador saliese de un servidor e ingresara a otro en un intervalo menor a 1 segundo durante un micro-corte de red, existe un riesgo residual menor de colisión de escritura si el primer servidor tardase en volcar `PlayerRemoving`. La estrategia de `UpdateAsync` mitiga la corrupción garantizando consistencia a nivel de registro. Migraciones con token de sesión podrán añadirse en fases avanzadas de producción.

### 9.9 Global Player HUD (`PlayerHUD`)
- **Independencia Total de MatchHUD:**
  - `PlayerHUD` es un `ScreenGui` permanente en `StarterGui` (replicado a `PlayerGui`).
  - `ResetOnSpawn = false` y `DisplayOrder = 10`.
  - Permanece visible tanto en el Lobby como durante la partida (`Playing`), sin interferir con `MatchHUD` ni con `MatchmakingHUD`.
- **Diseño Responsive:**
  - Anclado en `TopLeft` (`Position = UDim2.new(0, 16, 0, 16)`).
  - Controlado por `UISizeConstraint` (`MinSize = (220, 60)`, `MaxSize = (320, 80)`).
- **Componentes Nativos Editables:**
  - `ProfileCard`: Tarjeta horizontal moderna con fondo degradado azul/violeta oscuro (`UIGradient`, `UICorner`, `UIStroke`).
  - `Avatar`: Imagen circular con borde brillante cargada dinámicamente con `Players:GetUserThumbnailAsync(userId, HeadShot)`.
  - `PlayerName`: Muestra el `DisplayName` o `Name` del jugador.
  - `WinsLabel` & `LossesLabel`: Etiquetas informativas de récord con colores verde y rojo suave.
  - `CoinsContainer`: Contenedor elegante en la esquina superior derecha con icono dorado (`CoinIcon`) y cantidad de monedas (`CoinsLabel`).

### 9.10 Controlador Cliente (`PlayerHUDController`)
- Ubicación: `src/client/Controllers/PlayerHUDController.luau`.
- Enlaza dinámicamente con `PlayerGui.PlayerHUD`.
- Escucha `Remotes.Player.DataUpdated` para actualizar los labels.
- **Animación:** Al incrementarse el valor de `Coins`, interpola visualmente el número mediante `TweenService` (0.25 segundos) y aplica un sutil efecto de escala/pulse en `CoinsContainer`.

---
